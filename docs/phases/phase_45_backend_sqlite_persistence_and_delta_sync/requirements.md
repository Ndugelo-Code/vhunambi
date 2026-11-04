# Requirements Document: Phase 45 Backend SQLite Persistence & Delta Sync

## Introduction

Phase 45 introduces durable SQLite persistence, delta synchronization, and the missing production REST endpoints for the Vhunambi API (`apps/vhunambi_api`). This feature ensures that all creator profiles, kinetic posts, social endorsements, audio tracks, marketplace assets, and sovereign wallet transactions are permanently stored in an ACID-compliant database and synchronized seamlessly with edge mobile clients.

---

## Glossary

- **SQLite_WAL**: Write-Ahead Logging mode in SQLite (`PRAGMA journal_mode = WAL;`) allowing concurrent read transactions without blocking write transactions.
- **Vhunambi_Database**: The core persistence driver class in `apps/vhunambi_api/src/db/vhunambi_db.ts` managing the SQLite connection, schema migrations, and queries.
- **Monotonic_Sequence_Counter**: An auto-incrementing integer (`seq`) assigned to each committed state mutation, establishing total ordering across all backend events.
- **Sync_Mutation_Log**: System table storing every entity mutation alongside its `seq`, `idempotencyKey`, `entityType`, `entityId`, `action`, and JSON payload diff.
- **Delta_Sync**: Synchronization protocol returning only entities modified after a given client sequence cursor (`since=<seq>`).
- **ETag_Caching**: HTTP header caching mechanism (`ETag: "cursor-<latestSeq>"`) enabling clients to receive `304 Not Modified` when no new mutations have occurred.
- **Idempotency_Deduplication**: Mechanism ensuring that retried network requests bearing the same `idempotencyKey` return success without re-applying state changes.
- **Discovery_Rank_Score**: Multi-factor scoring algorithm ranking explore posts based on Recency, Co-Signs, Play Count, Bantu Language weighting, and Viral Velocity.
- **Co_Sign_Threshold**: Milestone of 25 verified co-signs that automatically promotes a post from `freshCrate` to `risingBreakout` stage.
- **Marketplace_Split**: Sovereign creator revenue model allocating 85% of beat/sample sales directly to the producer and 15% platform infrastructure fee.
- **Remix_Split**: Revenue sharing agreement allocating 70% to remixer and 30% to original stem copyright holders.

---

## Requirements

### Requirement 1: Zero-Configuration SQLite WAL Persistence Engine

**User Story:** As a system administrator, I want the backend API to automatically initialize and maintain a durable SQLite database file with WAL mode, so that data persists across container restarts with zero manual configuration.

#### Acceptance Criteria

1. **REQ-P45-DB-01**: `VhunambiDatabase` SHALL automatically create and open `apps/vhunambi_api/data/vhunambi_api.sqlite3` on boot (or use `:memory:` if `NODE_ENV === 'test'`).
2. **REQ-P45-DB-02**: THE database connection SHALL execute `PRAGMA journal_mode = WAL;` and `PRAGMA foreign_keys = ON;` upon initialization.
3. **REQ-P45-DB-03**: `VhunambiDatabase` SHALL execute schema migrations creating the following 10 domain tables plus the mutation log:
   - `creators`
   - `explore_tracks`
   - `kinetic_posts`
   - `published_clips`
   - `reel_comments`
   - `marketplace_assets`
   - `sound_signatures`
   - `user_library_sync`
   - `wallet_ledger`
   - `bank_accounts`
   - `sync_mutation_log`
4. **REQ-P45-DB-04**: EACH domain table SHALL contain `id TEXT PRIMARY KEY`, `created_at TEXT`, `updated_at TEXT`, and a `data_json TEXT` column for polymorphic entity fields.
5. **REQ-P45-DB-05**: THE `sync_mutation_log` table SHALL contain `seq INTEGER PRIMARY KEY AUTOINCREMENT`, `idempotency_key TEXT UNIQUE`, `entity_type TEXT`, `entity_id TEXT`, `action TEXT`, `payload_json TEXT`, and `created_at TEXT`.
6. **REQ-P45-DB-06**: ALL write transactions SHALL commit atomically. IF any operation within a transaction fails, the entire transaction SHALL roll back.

---

### Requirement 2: Discovery Feed & Social Promotion REST Endpoints

**User Story:** As a mobile user browsing the Explore tab, I want to fetch ranked posts filtered by stage and genre, and co-sign tracks to help them break out, so that community-driven talent discovery is reflected on the backend.

#### Acceptance Criteria

1. **REQ-P45-EXP-01**: `GET /api/explore/feed` SHALL accept optional query parameters `stage` (`mainstage`, `risingBreakout`, `freshCrate`, `following`), `genre`, `limit`, and `offset`.
2. **REQ-P45-EXP-02**: `GET /api/explore/feed` SHALL sort returned posts by `DiscoveryRankScore` descending.
3. **REQ-P45-EXP-03**: `POST /api/explore/posts` SHALL validate and persist new `KineticPost` records into `kinetic_posts` and append an entry to `sync_mutation_log`.
4. **REQ-P45-EXP-04**: `POST /api/explore/posts/:id/cosign` SHALL increment `cosign_count` on the targeted post.
5. **REQ-P45-EXP-05**: WHEN `cosign_count >= 25` AND current stage is `'freshCrate'`, `POST /api/explore/posts/:id/cosign` SHALL automatically graduate the post's `discovery_stage` to `'risingBreakout'`.
6. **REQ-P45-EXP-06**: `POST /api/explore/posts/:id/repost` SHALL increment `repost_count` and log the viral distribution event.

---

### Requirement 3: Library Vault Synchronization Endpoints

**User Story:** As a creator switching devices, I want my saved tracks, stem arrangements, and split-sheets to sync with the cloud vault, so that my studio projects are accessible anywhere.

#### Acceptance Criteria

1. **REQ-P45-LIB-01**: `GET /api/library/sync` SHALL return the complete snapshot of the user's saved tracks, playlists, and split-sheets associated with their creator ID.
2. **REQ-P45-LIB-02**: `POST /api/library/sync` SHALL accept an array of library items and upsert them into `user_library_sync`.
3. **REQ-P45-LIB-03**: `POST /api/library/sync` SHALL log all upserted items in `sync_mutation_log` within a single database transaction.
4. **REQ-P45-LIB-04**: IF an incoming item has a newer `updated_at` timestamp than the database copy, the database record SHALL be updated; otherwise, the database copy SHALL be preserved (last-write-wins).

---

### Requirement 4: Sovereign Creator Wallet Ledger & Payout Endpoints

**User Story:** As a producer earning from beat licenses and tips, I want to view my balance in ZAR and Cultural Coins, and request payouts to my South African bank account, so that I can monetize my musical creations.

#### Acceptance Criteria

1. **REQ-P45-WAL-01**: `GET /api/wallet/:creatorId` SHALL return the creator's current ZAR balance, Cultural Coin balance, pending escrow balance, and transaction history.
2. **REQ-P45-WAL-02**: `POST /api/wallet/topup` SHALL credit Cultural Coins or ZAR to the creator's wallet and record a transaction in `wallet_ledger`.
3. **REQ-P45-WAL-03**: `POST /api/wallet/payout` SHALL validate that requested payout amount $\le$ available ZAR balance.
4. **REQ-P45-WAL-04**: `POST /api/wallet/payout` SHALL validate South African bank details (Bank Name in `['ABSA', 'FNB', 'Standard Bank', 'Capitec', 'Nedbank', 'TymeBank']`, Account Number 8-11 digits, Branch Code 6 digits).
5. **REQ-P45-WAL-05**: UPON successful payout validation, `POST /api/wallet/payout` SHALL deduct the amount from available balance, create a pending payout record, and append a transaction to `wallet_ledger`.

---

### Requirement 5: Delta Synchronization & Idempotent Mutation Ingestion

**User Story:** As an edge client synchronizing state, I want to send queued mutations with idempotency keys and receive only changes that occurred since my last sequence cursor, so that network transfer is minimal and reliable.

#### Acceptance Criteria

1. **REQ-P45-SYNC-01**: `POST /api/sync/mutations` SHALL accept a JSON body containing `mutations: Array<SyncMutationRecord>`.
2. **REQ-P45-SYNC-02**: FOR EACH mutation in the batch, THE server SHALL check if `idempotencyKey` already exists in `sync_mutation_log`.
3. **REQ-P45-SYNC-03**: IF `idempotencyKey` exists, THE server SHALL skip re-execution of the mutation and include the key in the returned `skipped: []` list.
4. **REQ-P45-SYNC-04**: IF `idempotencyKey` does NOT exist, THE server SHALL execute the state modification, append to `sync_mutation_log`, and include the key in the `applied: []` list.
5. **REQ-P45-SYNC-05**: `GET /api/sync/delta?since=<seq>` SHALL query `sync_mutation_log` for all records where `seq > since` and return `{ mutations: [...], latestSeq: number }`.
6. **REQ-P45-SYNC-06**: `GET /api/sync/delta` SHALL include an `ETag` header formatted as `"cursor-<latestSeq>"`. IF `req.headers['if-none-match'] === "cursor-<latestSeq>"`, THE server SHALL respond with HTTP status `304 Not Modified` and an empty response body.

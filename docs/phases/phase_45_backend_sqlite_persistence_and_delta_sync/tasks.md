# Tasks Document: Phase 45 Backend SQLite Persistence & Delta Sync

## Implementation Checklist

### Track B: Zero-Config SQLite WAL Database Engine

- [ ] **Task 1: Implement Vhunambi Database Driver & WAL Mode**
  - [ ] 1.1 Create `apps/vhunambi_api/src/db/vhunambi_db.ts` utilizing SQLite driver.
  - [ ] 1.2 Implement automatic path resolution: `data/vhunambi_api.sqlite3` with fallback to `:memory:` in test environment (`NODE_ENV === 'test'`).
  - [ ] 1.3 Configure pragmas: `PRAGMA journal_mode = WAL;` and `PRAGMA foreign_keys = ON;`.
  - [ ] 1.4 Implement schema migrations creating 10 domain tables plus `sync_mutation_log` with `seq INTEGER PRIMARY KEY AUTOINCREMENT`.
  - [ ] 1.5 Implement atomic transaction wrapper `transaction<T>(fn: () => T): T`.
  - _Requirements: REQ-P45-DB-01, REQ-P45-DB-02, REQ-P45-DB-03, REQ-P45-DB-04, REQ-P45-DB-05, REQ-P45-DB-06_

---

### Track C: Production REST Endpoints

- [ ] **Task 2: Implement Explore & Social Promotion Endpoints**
  - [ ] 2.1 Create `apps/vhunambi_api/src/routes/explore_routes.ts`.
  - [ ] 2.2 Implement `GET /api/explore/feed` with stage filtering, genre filtering, and 5-factor `DiscoveryRankScore` sorting.
  - [ ] 2.3 Implement `POST /api/explore/posts` to create kinetic posts and write to `sync_mutation_log`.
  - [ ] 2.4 Implement `POST /api/explore/posts/:id/cosign` incrementing co-signs and auto-promoting to `risingBreakout` when count $\ge 25$.
  - [ ] 2.5 Implement `POST /api/explore/posts/:id/repost` for viral distribution tracking.
  - _Requirements: REQ-P45-EXP-01, REQ-P45-EXP-02, REQ-P45-EXP-03, REQ-P45-EXP-04, REQ-P45-EXP-05, REQ-P45-EXP-06_

- [ ] **Task 3: Implement Cloud Vault Library Sync Endpoints**
  - [ ] 3.1 Create `apps/vhunambi_api/src/routes/library_routes.ts`.
  - [ ] 3.2 Implement `GET /api/library/sync` returning complete user snapshot.
  - [ ] 3.3 Implement `POST /api/library/sync` with last-write-wins timestamp conflict resolution.
  - [ ] 3.4 Wire library mutations into `sync_mutation_log`.
  - _Requirements: REQ-P45-LIB-01, REQ-P45-LIB-02, REQ-P45-LIB-03, REQ-P45-LIB-04_

- [ ] **Task 4: Implement Sovereign Creator Wallet Ledger & Payout Endpoints**
  - [ ] 4.1 Create `apps/vhunambi_api/src/routes/wallet_routes.ts`.
  - [ ] 4.2 Implement `GET /api/wallet/:creatorId` returning ZAR, Coins, escrow, and transaction history.
  - [ ] 4.3 Implement `POST /api/wallet/topup` crediting Coins or ZAR.
  - [ ] 4.4 Implement `POST /api/wallet/payout` with South African bank account validation (ABSA, FNB, Standard Bank, Capitec, Nedbank).
  - [ ] 4.5 Enforce 85/15 and 70/30 split ledger recording.
  - _Requirements: REQ-P45-WAL-01, REQ-P45-WAL-02, REQ-P45-WAL-03, REQ-P45-WAL-04, REQ-P45-WAL-05_

---

### Track D: Edge-to-Cloud Delta Sync Gateway

- [ ] **Task 5: Implement Delta Sync & Idempotent Mutation Gateway**
  - [ ] 5.1 Create `apps/vhunambi_api/src/routes/sync_routes.ts`.
  - [ ] 5.2 Implement `POST /api/sync/mutations` with UUIDv4 `idempotencyKey` deduplication.
  - [ ] 5.3 Implement `GET /api/sync/delta?since=<seq>` returning mutations after `seq`.
  - [ ] 5.4 Add `ETag: "cursor-<latestSeq>"` header support returning `304 Not Modified` on cache hits.
  - _Requirements: REQ-P45-SYNC-01, REQ-P45-SYNC-02, REQ-P45-SYNC-03, REQ-P45-SYNC-04, REQ-P45-SYNC-05, REQ-P45-SYNC-06_

- [ ] **Task 6: Wire Routes & Server Configuration**
  - [ ] 6.1 Register all new routes in `apps/vhunambi_api/src/index.ts` / server entry.
  - [ ] 6.2 Ensure database initializes cleanly on server boot.

---

### Verification & Testing Tasks

- [ ] **Task 7: Backend Persistence & Sync Test Suite**
  - [ ] 7.1 Author `apps/vhunambi_api/tests/persistence_and_sync.test.ts` testing:
    - SQLite WAL table creation and data persistence
    - Monotonic sequence cursor advancement
    - Idempotency deduplication on `POST /api/sync/mutations`
    - Delta query filtering and ETag 304 response
    - Co-sign threshold promotion from `freshCrate` to `risingBreakout`
    - Payout validation for South African banks
  - [ ] 7.2 Run `pnpm test` in `apps/vhunambi_api` $\rightarrow$ 100% green.

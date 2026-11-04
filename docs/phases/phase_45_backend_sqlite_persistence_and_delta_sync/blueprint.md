# Phase 45 Blueprint: Backend SQLite Persistence & Delta Sync

## 1. Executive Summary

Phase 45 establishes a durable, production-ready persistence engine and real-time edge synchronization tier for the Vhunambi API (`apps/vhunambi_api`). Prior to this phase, API services relied on transient in-memory maps that lost state across container or server restarts. Furthermore, several critical production endpoints required by the mobile client (explore feed discovery ranking, library vault synchronization, creator sovereign wallet ledger, and edge mutation ingestion) were missing.

This phase implements a zero-configuration **SQLite WAL (Write-Ahead Logging)** storage engine with transactional durability across all 10 core domain collections, pairs it with an idempotent mutation processor, and delivers high-performance delta synchronization with monotonic sequence tracking and HTTP 304 caching.

```
┌───────────────────────────────────────────────────────────────────────────────────┐
│                           VHUNAMBI BACKEND ARCHITECTURE                           │
├───────────────────────────────────────────────────────────────────────────────────┤
│                                                                                   │
│  [ Fastify / Express REST API Layer ]                                             │
│  ┌───────────────────────┐ ┌───────────────────────┐ ┌─────────────────────────┐  │
│  │  /api/explore/*       │ │  /api/library/*       │ │  /api/wallet/*          │  │
│  │  Feed & Co-Signs      │ │  Cloud Vault Sync     │ │  Ledger & Payouts       │  │
│  └───────────┬───────────┘ └───────────┬───────────┘ └────────────┬────────────┘  │
│              │                         │                          │               │
│              └─────────────────────────┼──────────────────────────┘               │
│                                        │                                          │
│  [ Edge-to-Cloud Delta Sync Gateway ]  │                                          │
│  ┌─────────────────────────────────────▼───────────────────────────────────────┐  │
│  │  POST /api/sync/mutations (Idempotency Key Deduplication + Batch Apply)    │  │
│  │  GET  /api/sync/delta?since=<seq> (Cursor-based events + ETag: "cursor-N") │  │
│  └─────────────────────────────────────┬───────────────────────────────────────┘  │
│                                        │                                          │
│  [ SQLite WAL Persistence Engine ]     │                                          │
│  ┌─────────────────────────────────────▼───────────────────────────────────────┐  │
│  │  File: vhunambi_api.sqlite3 (or :memory: in CI/Test)                       │  │
│  │  PRAGMA journal_mode = WAL; PRAGMA foreign_keys = ON;                      │  │
│  │  10 Domain Tables + sync_mutation_log (seq INTEGER PRIMARY KEY)            │  │
│  └─────────────────────────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Problem Statement & Architectural Need

1. **State Volatility Across Restarts**: Previously, in-memory arrays meant that restarting the server reset all newly published Kinetic Posts, Co-Signs, Wallet balances, and Beats back to hardcoded seeds.
2. **Missing Production REST Contracts**: The mobile client's advanced features—such as the 4-Pillar Talent Marketplace, Co-Sign promotion, Cloud Vault sync, and Payout sheets—lacked backing production REST endpoints on the Node/TypeScript API.
3. **Absence of Offline Synchronization Support**: Mobile creators composing music in low-bandwidth rural environments could not queue mutations offline and safely sync them without data loss or duplicate records.
4. **Bandwidth Inefficiency**: Without delta synchronization and ETag caching, clients were forced to fetch entire datasets repeatedly, depleting user mobile data bundles.

---

## 3. Core Architectural Pillars

### 3.1 Zero-Configuration SQLite WAL Engine (`vhunambi_db.ts`)
- Utilizes `better-sqlite3` (or Node `sqlite3` driver) targeting a single file: `apps/vhunambi_api/data/vhunambi_api.sqlite3`.
- Automatically activates Write-Ahead Logging (`PRAGMA journal_mode = WAL;`) for high concurrency (concurrent readers do not block writers).
- Provides an automated switch to `:memory:` mode when running in test/CI environments (`NODE_ENV === 'test'`).
- Executes atomic schema migrations on boot, creating all 10 domain tables if not present.

### 3.2 Monotonic Sequence (`seq`) & Mutation Log
- The `sync_mutation_log` table maintains an auto-incrementing integer primary key `seq`.
- Every creation, modification, or deletion across any of the 10 domain tables writes a log entry with the entity type, entity ID, operation, timestamp, and payload diff inside the same database transaction.
- The `serverCursorSeq` guarantees strict total ordering of all state transitions across the platform.

### 3.3 High-Performance Delta Sync Protocol
- **Client Push**: `POST /api/sync/mutations` accepts a batch of client mutations. Each record contains an `idempotencyKey`. If an idempotency key is already recorded in the mutation log, the engine gracefully skips it, preventing duplicate records or duplicate wallet charges.
- **Client Pull**: `GET /api/sync/delta?since=<seq>` queries the mutation log for all changes where `seq > since`.
- **Cache Header Optimization**: The server generates an `ETag` computed as `"cursor-<latestSeq>"`. If the client passes `If-None-Match: "cursor-<latestSeq>"`, the server immediately responds with `304 Not Modified` and zero payload bytes.

### 3.4 Missing Domain REST Endpoints
- **Explore & Social**:
  - `GET /api/explore/feed`: Multi-tier discovery filtering (`mainstage`, `risingBreakout`, `freshCrate`, `following`) ranked by 5-factor `DiscoveryRankScore`.
  - `POST /api/explore/posts`: Publish Kinetic Posts with multi-vault media attachments.
  - `POST /api/explore/posts/:id/cosign`: Peer endorsement endpoint; automatically promotes posts to `risingBreakout` upon reaching 25 co-signs.
  - `POST /api/explore/posts/:id/repost`: Social viral distribution endpoint.
- **Library & Cloud Vault**:
  - `GET /api/library/sync`: Full snapshot of user tracks, stems, playlists, and split-sheets.
  - `POST /api/library/sync`: Ingest local track creations and split-sheet updates.
- **Sovereign Creator Wallet**:
  - `GET /api/wallet/:creatorId`: Retrieve creator balance (ZAR and Cultural Coins), pending payouts, and transaction history.
  - `POST /api/wallet/topup`: Deposit funds into creator wallet.
  - `POST /api/wallet/payout`: Request payout to South African banks (ABSA, FNB, Standard Bank, Capitec, Nedbank) with 85/15 and 70/30 split verification.

---

## 4. Invariants & Non-Negotiable Engineering Rules

1. **Transactional Integrity**: All mutation operations and their corresponding `sync_mutation_log` entries must execute within an explicit database transaction (`BEGIN TRANSACTION` ... `COMMIT`). If any step fails, the entire transaction rolls back.
2. **Deterministic Idempotency**: No financial debit or state modification may occur without verifying the absence of the client's `idempotencyKey` in the persistent log.
3. **Zero Native Build Dependencies in Memory Mode**: In-memory test execution must run cleanly in continuous integration without requiring pre-compiled binary drivers.
4. **Strict HTTP Semantic Compliance**: Delta endpoints must properly handle conditional requests (`If-None-Match`) and respond with `304 Not Modified` when the sequence cursor has not advanced.
5. **Schema Backwards Compatibility**: All table schemas must include default values and non-destructive column types so that existing test fixtures and mock datasets run without regression.

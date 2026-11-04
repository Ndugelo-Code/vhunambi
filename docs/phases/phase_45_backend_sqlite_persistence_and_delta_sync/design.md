# Technical Design Document: Phase 45 Backend SQLite Persistence & Delta Sync

## 1. Overview & System Context

Phase 45 equips `apps/vhunambi_api` with an ACID-compliant, zero-configuration persistence layer using **SQLite with Write-Ahead Logging (WAL)**. It exposes the missing domain REST endpoints required by the mobile client and implements a production-grade Delta Sync gateway that enables edge clients to synchronize offline mutations idempotently.

---

## 2. Architecture & Database Design

```
┌────────────────────────────────────────────────────────────────────────┐
│                        VHUNAMBI API HTTP SERVER                        │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  Fastify / Express HTTP Router                                         │
│  ├── /api/explore (Feed, Co-Sign, Repost)                              │
│  ├── /api/library (Cloud Vault Snapshot & Upsert)                      │
│  ├── /api/wallet  (Ledger, Top-up, South African Bank Payouts)         │
│  └── /api/sync    (POST /mutations, GET /delta?since=<seq>)            │
│                                                                        │
├────────────────────────────────────────────────────────────────────────┤
│                          PERSISTENCE ADAPTER                           │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  VhunambiDatabase (src/db/vhunambi_db.ts)                              │
│  ├── Driver: better-sqlite3 (or sqlite3 native binding)               │
│  ├── File: apps/vhunambi_api/data/vhunambi_api.sqlite3                 │
│  ├── Fallback: ':memory:' when NODE_ENV === 'test'                     │
│  └── Pragmas: PRAGMA journal_mode = WAL; PRAGMA foreign_keys = ON;     │
│                                                                        │
├────────────────────────────────────────────────────────────────────────┤
│                          TABLE SCHEMAS (10 + 1)                        │
├────────────────────────────────────────────────────────────────────────┤
│  creators              │ explore_tracks         │ kinetic_posts        │
│  published_clips       │ reel_comments          │ marketplace_assets   │
│  sound_signatures      │ user_library_sync      │ wallet_ledger        │
│  bank_accounts         │ sync_mutation_log (seq PRIMARY KEY AUTOINC)   │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. SQLite DDL Schema Specifications

```sql
-- 1. System Mutation Log (Total Ordering & Idempotency)
CREATE TABLE IF NOT EXISTS sync_mutation_log (
  seq INTEGER PRIMARY KEY AUTOINCREMENT,
  idempotency_key TEXT UNIQUE,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  action TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  created_at TEXT NOT NULL
);

-- Index for high-speed delta queries
CREATE INDEX IF NOT EXISTS idx_mutation_seq ON sync_mutation_log(seq);
CREATE INDEX IF NOT EXISTS idx_mutation_idempotency ON sync_mutation_log(idempotency_key);

-- 2. Creators Domain Table
CREATE TABLE IF NOT EXISTS creators (
  id TEXT PRIMARY KEY,
  handle TEXT UNIQUE NOT NULL,
  display_name TEXT NOT NULL,
  avatar_url TEXT,
  archetype TEXT NOT NULL,
  tier TEXT NOT NULL DEFAULT 'emerging',
  reputation_score INTEGER DEFAULT 100,
  data_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

-- 3. Explore Tracks
CREATE TABLE IF NOT EXISTS explore_tracks (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  artist_id TEXT NOT NULL,
  artist_name TEXT NOT NULL,
  genre TEXT NOT NULL,
  audio_url TEXT NOT NULL,
  bpm INTEGER,
  play_count INTEGER DEFAULT 0,
  like_count INTEGER DEFAULT 0,
  cosign_count INTEGER DEFAULT 0,
  discovery_stage TEXT NOT NULL DEFAULT 'freshCrate',
  data_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

-- 4. Kinetic Posts
CREATE TABLE IF NOT EXISTS kinetic_posts (
  id TEXT PRIMARY KEY,
  creator_id TEXT NOT NULL,
  creator_handle TEXT NOT NULL,
  caption TEXT NOT NULL,
  media_type TEXT NOT NULL,
  attachment_id TEXT,
  cosign_count INTEGER DEFAULT 0,
  cosign_target INTEGER DEFAULT 25,
  discovery_stage TEXT NOT NULL DEFAULT 'freshCrate',
  data_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

-- 5. Published Clips (9:16 Kinetic Reels)
CREATE TABLE IF NOT EXISTS published_clips (
  id TEXT PRIMARY KEY,
  creator_id TEXT NOT NULL,
  creator_handle TEXT NOT NULL,
  video_url TEXT NOT NULL,
  audio_title TEXT NOT NULL,
  bantu_language TEXT,
  views_count INTEGER DEFAULT 0,
  likes_count INTEGER DEFAULT 0,
  data_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

-- 6. Reel Comments
CREATE TABLE IF NOT EXISTS reel_comments (
  id TEXT PRIMARY KEY,
  reel_id TEXT NOT NULL,
  creator_id TEXT NOT NULL,
  content TEXT NOT NULL,
  language_code TEXT,
  created_at TEXT NOT NULL
);

-- 7. Marketplace Assets (Beats, Vocal Hooks, Instrument Loops)
CREATE TABLE IF NOT EXISTS marketplace_assets (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  producer_id TEXT NOT NULL,
  asset_category TEXT NOT NULL,
  price_zar REAL NOT NULL,
  price_coins INTEGER NOT NULL,
  data_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

-- 8. Sound Signatures (Voice DNA Presets)
CREATE TABLE IF NOT EXISTS sound_signatures (
  id TEXT PRIMARY KEY,
  creator_id TEXT NOT NULL,
  timbre_name TEXT NOT NULL,
  match_confidence INTEGER NOT NULL,
  data_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

-- 9. User Library Sync (Cloud Vault)
CREATE TABLE IF NOT EXISTS user_library_sync (
  id TEXT PRIMARY KEY,
  creator_id TEXT NOT NULL,
  item_type TEXT NOT NULL,
  title TEXT NOT NULL,
  data_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

-- 10. Sovereign Wallet Ledger
CREATE TABLE IF NOT EXISTS wallet_ledger (
  id TEXT PRIMARY KEY,
  creator_id TEXT NOT NULL,
  type TEXT NOT NULL, -- 'topup' | 'tip' | 'license_sale' | 'payout'
  amount_zar REAL NOT NULL DEFAULT 0.0,
  amount_coins INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL, -- 'pending' | 'completed' | 'failed'
  reference TEXT,
  data_json TEXT NOT NULL,
  created_at TEXT NOT NULL
);

-- 11. Bank Accounts (South African Payout Profiles)
CREATE TABLE IF NOT EXISTS bank_accounts (
  id TEXT PRIMARY KEY,
  creator_id TEXT NOT NULL,
  bank_name TEXT NOT NULL,
  account_number TEXT NOT NULL,
  branch_code TEXT NOT NULL,
  account_type TEXT NOT NULL,
  is_verified INTEGER DEFAULT 1,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
```

---

## 4. REST API Endpoint Specifications

### 4.1 Explore & Feed Endpoints

#### `GET /api/explore/feed`
- **Query Parameters**:
  - `stage`: `'mainstage' | 'risingBreakout' | 'freshCrate' | 'following'`
  - `genre`: string (e.g. `'Amapiano'`, `'Venda Folk'`)
  - `limit`: number (default: 20)
  - `offset`: number (default: 0)
- **Response `200 OK`**:
```json
{
  "posts": [
    {
      "id": "post_101",
      "creatorId": "creator_cern",
      "creatorHandle": "@cern",
      "caption": "Late night studio session testing Venda Folk LoRA slide 🔥",
      "discoveryStage": "risingBreakout",
      "cosignCount": 26,
      "cosignTarget": 25,
      "createdAt": "2026-11-04T10:00:00Z"
    }
  ],
  "total": 42
}
```

#### `POST /api/explore/posts/:id/cosign`
- **Request Body**: `{ "creatorId": "creator_sigwa" }`
- **Logic**:
  1. Increment `cosign_count = cosign_count + 1`.
  2. If `cosign_count >= 25` and current `discovery_stage == 'freshCrate'`, update `discovery_stage = 'risingBreakout'`.
  3. Append to `sync_mutation_log` with action `'cosign'`.
- **Response `200 OK`**:
```json
{
  "success": true,
  "postId": "post_101",
  "cosignCount": 26,
  "discoveryStage": "risingBreakout",
  "promoted": true
}
```

---

### 4.2 Library Vault Endpoints

#### `GET /api/library/sync?creatorId=creator_cern`
- **Response `200 OK`**:
```json
{
  "creatorId": "creator_cern",
  "items": [
    {
      "id": "trk_vault_01",
      "itemType": "track",
      "title": "Ndo Mufuna Matibe",
      "updatedAt": "2026-11-04T08:15:00Z"
    }
  ]
}
```

#### `POST /api/library/sync`
- **Request Body**:
```json
{
  "creatorId": "creator_cern",
  "items": [
    {
      "id": "trk_vault_02",
      "itemType": "track",
      "title": "Midnight Log Drum",
      "dataJson": "{...}",
      "updatedAt": "2026-11-04T11:00:00Z"
    }
  ]
}
```
- **Response `200 OK`**: `{ "upserted": 1, "status": "synced" }`

---

### 4.3 Sovereign Creator Wallet Endpoints

#### `GET /api/wallet/:creatorId`
- **Response `200 OK`**:
```json
{
  "creatorId": "creator_cern",
  "balanceZar": 1420.00,
  "balanceCoins": 4750,
  "pendingPayoutZar": 0.00,
  "recentTransactions": [
    {
      "id": "tx_01",
      "type": "tip",
      "amountZar": 50.00,
      "amountCoins": 250,
      "status": "completed",
      "createdAt": "2026-11-04T09:30:00Z"
    }
  ]
}
```

#### `POST /api/wallet/payout`
- **Request Body**:
```json
{
  "creatorId": "creator_cern",
  "amountZar": 500.00,
  "bankName": "Capitec",
  "accountNumber": "1234567890",
  "branchCode": "470010"
}
```
- **Validation**:
  - `amountZar > 0` and `amountZar <= currentBalanceZar`.
  - `bankName` in allowed South African institutions.
- **Response `200 OK`**:
```json
{
  "success": true,
  "payoutId": "pay_982",
  "deductedZar": 500.00,
  "remainingBalanceZar": 920.00,
  "status": "processing"
}
```

---

### 4.4 Delta Sync Endpoints

#### `POST /api/sync/mutations`
- **Request Body**:
```json
{
  "mutations": [
    {
      "idempotencyKey": "a9f8b2c1-d4e5-4f6a-8b9c-0d1e2f3a4b5c",
      "entityType": "post",
      "action": "create",
      "payload": { "id": "post_102", "caption": "Testing offline sync" },
      "createdAt": "2026-11-04T11:20:00Z"
    }
  ]
}
```
- **Response `200 OK`**:
```json
{
  "applied": ["a9f8b2c1-d4e5-4f6a-8b9c-0d1e2f3a4b5c"],
  "skipped": [],
  "latestSeq": 105
}
```

#### `GET /api/sync/delta?since=104`
- **Request Headers**: `If-None-Match: "cursor-105"`
- **Response `304 Not Modified`** (if no changes since `seq = 105`).
- **Response `200 OK`** (if changes exist):
  - **Header**: `ETag: "cursor-108"`
  - **Body**:
```json
{
  "mutations": [
    {
      "seq": 106,
      "idempotencyKey": "b1...",
      "entityType": "post",
      "entityId": "post_102",
      "action": "cosign",
      "payload": { "cosignCount": 15 },
      "createdAt": "2026-11-04T11:25:00Z"
    }
  ],
  "latestSeq": 108
}
```

---

## 5. Algorithmic Specifications

### 5.1 Discovery Rank Score Calculation
For each post evaluated in `GET /api/explore/feed`:
$$\text{Score} = (\text{CoSigns} \times 4.0) + (\text{Likes} \times 1.0) + (\text{Reposts} \times 2.5) + \text{BantuBonus} - (\text{HoursOld} \times 0.5)$$
Where:
- $\text{BantuBonus} = 15.0$ if the post contains verified Bantu lyrics or heritage tags.
- Posts with $\text{CoSigns} \ge 25$ receive an additional $+50.0$ tier promotion bonus.

### 5.2 Idempotency Deduplication Algorithm
```typescript
function processMutationBatch(mutations: SyncMutationRecord[]): SyncResult {
  return db.transaction(() => {
    const applied: string[] = [];
    const skipped: string[] = [];

    for (const m of mutations) {
      const existing = db.prepare('SELECT seq FROM sync_mutation_log WHERE idempotency_key = ?').get(m.idempotencyKey);
      if (existing) {
        skipped.push(m.idempotencyKey);
        continue;
      }

      // Apply entity change
      applyEntityMutation(m);

      // Record in log
      db.prepare(`
        INSERT INTO sync_mutation_log (idempotency_key, entity_type, entity_id, action, payload_json, created_at)
        VALUES (?, ?, ?, ?, ?, ?)
      `).run(m.idempotencyKey, m.entityType, m.payload.id || 'unknown', m.action, JSON.stringify(m.payload), m.createdAt);

      applied.push(m.idempotencyKey);
    }

    const latestSeq = db.prepare('SELECT MAX(seq) as maxSeq FROM sync_mutation_log').get().maxSeq || 0;
    return { applied, skipped, latestSeq };
  })();
}
```

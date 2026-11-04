# Phase 48 Requirements: Edge Sync Production Hardening

## Introduction

Phase 48 upgrades the offline-first mutation outbox and bi-directional delta sync (Phases 44/46) into a production-grade synchronization engine suitable for African creators on intermittent connectivity. It introduces priority queueing (financial transactions never wait behind social likes), per-item partial-failure recovery, paginated delta sync, schema v2 migration, outbox compaction, dead-letter handling, auto-reconnect on app resume, and an in-memory telemetry ring buffer.

Standard: RFC 2119 & EARS compliant. Traceable IDs: `REQ-P48-XXX-##`.

## Glossary

- **SyncPriority**: `critical` | `normal` | `background` — drain ordering for outbox mutations.
- **SyncRecordStatus**: `pending` | `failedRetryable` | `deadLetter` — lifecycle status of an outbox record.
- **baseSeq**: The server `seq` value observed when the mutation was created; used for optimistic concurrency on versioned entity edits.
- **schemaVersion**: Integer in `toJson()`/`fromJson()` enabling graceful v1 → v2 migration without `@HiveType` code generation.
- **Commutative Counter**: `like`, `cosign`, `repost`, `tip` — atomic `count + 1` updates, never overwrite.
- **Versioned Entity Edit**: `post` caption, profile bio, etc. — rejected with `conflict` if `baseSeq` is stale.
- **Dead-Letter**: Records exceeding `maxRetries = 5` or `ttlDays = 7`; excluded from active flushes.
- **Telemetry Ring Buffer**: Bounded 50-event `List<SyncTelemetryEvent>` inside `EdgeSyncState`.

---

### Requirement 1: Priority Queueing & Schema v2 Migration

**User Story:** As a creator, I want my wallet top-up and payout mutations to sync before my casual likes, so financial actions are never delayed by social engagement noise.

1. **REQ-P48-PQ-01**: `SyncMutationRecord` SHALL include `SyncPriority priority` field (default `background`).
2. **REQ-P48-PQ-02**: `SyncMutationRecord` SHALL include `int? baseSeq` field for optimistic concurrency.
3. **REQ-P48-PQ-03**: `SyncMutationRecord` SHALL include `int schemaVersion = 2` field.
4. **REQ-P48-PQ-04**: `SyncMutationRecord.toJson()` SHALL serialize `schemaVersion`, `priority`, and `baseSeq`.
5. **REQ-P48-PQ-05**: `SyncMutationRecord.fromJson()` SHALL gracefully migrate v1 records (missing `priority`, `baseSeq`, `schemaVersion`) to v2 defaults without throwing.
6. **REQ-P48-PQ-06**: `SyncOutboxService.getPendingBatch({int maxBatchSize = 50})` SHALL return records sorted ascending by `SyncPriority` (critical → normal → background), then by `createdAt` chronological.
7. **REQ-P48-PQ-07**: `SyncOutboxService.pendingCount` SHALL reflect only records with `status == pending` or `status == failedRetryable` (excluding `deadLetter`).

---

### Requirement 2: Outbox Compaction, Size Cap & Dead-Letter

**User Story:** As a mobile user on a budget phone, I want the outbox to self-bound its storage so it never fills my device with unsynced records.

1. **REQ-P48-OC-01**: `SyncOutboxService` SHALL enforce `maxOutboxSize = 1000` records.
2. **REQ-P48-OC-02**: When full, eviction SHALL remove the oldest `background` record first; `critical` records SHALL never be evicted.
3. **REQ-P48-OC-03**: Records with `retryCount >= maxRetries (5)` SHALL transition to `SyncRecordStatus.deadLetter`.
4. **REQ-P48-OC-04**: Records older than `ttlDays (7)` SHALL transition to `deadLetter`.
5. **REQ-P48-OC-05**: `deadLetterRecords` getter SHALL return all `deadLetter` records for inspection/clearing.
6. **REQ-P48-OC-06**: Upon flush acknowledgment, `applied` and `skipped` records SHALL be removed from the outbox immediately.
7. **REQ-P48-OC-07**: `flush()` SHALL accept partial-failure results and increment `retryCount` on `failed` retryable items, or move non-retryable items to `deadLetter`.

---

### Requirement 3: Per-Item Partial-Failure Contract

**User Story:** As a backend operator, I want a batch of 20 mutations where item #3 fails validation to still apply items #1, #2, and #4–#20, rather than rolling back the entire batch.

1. **REQ-P48-PF-01**: `POST /api/v1/sync/mutations` SHALL process each mutation inside an individual SQLite `SAVEPOINT`.
2. **REQ-P48-PF-02**: A validation error on one mutation SHALL NOT abort sibling mutations in the same batch.
3. **REQ-P48-PF-03**: Commutative counter operations (`like`, `cosign`, `repost`, `tip`) SHALL execute `SET count = count + 1` atomically — never overwrite.
4. **REQ-P48-PF-04**: Versioned entity edits carrying `baseSeq` SHALL be rejected with `conflict` if the stored `seq` is newer than `baseSeq` (no lost updates).
5. **REQ-P48-PF-05**: Response SHALL include `{ applied: string[], skipped: string[], failed: [{idempotencyKey, code, message, retryable}], latestSeq: number }`.
6. **REQ-P48-PF-06**: Existing response fields `appliedCount` / `skippedCount` SHALL be preserved for backward compatibility with Phase 45/46 tests.

---

### Requirement 4: Paginated Delta Sync

**User Story:** As an edge client returning from days offline, I want delta sync to return changes in bounded pages rather than one massive JSON payload.

1. **REQ-P48-PD-01**: `GET /api/v1/sync/delta` SHALL support `?since_seq=<seq>&limit=<1..200>` (default `100`).
2. **REQ-P48-PD-02**: Response SHALL include `{ changes: [...], latestSeq, nextCursorSeq, hasMore: boolean }`.
3. **REQ-P48-PD-03**: Existing response fields `mutations`, `latestSeq`, `latest_seq` SHALL be preserved for backward compatibility.
4. **REQ-P48-PD-04**: `ETag: "cursor-<latestSeq>"` and HTTP `304 Not Modified` behavior SHALL be preserved exactly as in Phase 45.

---

### Requirement 5: Multi-Page Delta Drain & Telemetry

**User Story:** As a client, I want `syncNow()` to drain all delta pages automatically and expose live sync metrics in the settings drawer.

1. **REQ-P48-MP-01**: `EdgeSyncCoordinator.syncNow()` SHALL loop through `GET /api/v1/sync/delta?since_seq=<cursor>&limit=100` pages while `hasMore == true`, up to a safety cap of 10 pages per sync cycle.
2. **REQ-P48-MP-02**: `EdgeSyncCoordinator` SHALL accept an injectable `Stream<bool> connectivityStream` (defaulting to `const Stream.empty()` in headless tests).
3. **REQ-P48-MP-03**: `onAppResumed()` SHALL flush pending mutations when `pendingCount > 0` (called from `AppLifecycleState.resumed`).
4. **REQ-P48-MP-04**: `EdgeSyncState` SHALL include a bounded 50-item `List<SyncTelemetryEvent>` ring buffer.
5. **REQ-P48-MP-05**: Telemetry events SHALL include: `enqueued`, `batchFlushed`, `partialFailure`, `deltaHydrated`, `deadLetterMoved`.
6. **REQ-P48-MP-06**: `EdgeSyncState` SHALL expose `lastSyncLatencyMs`.

---

### Requirement 6: Non-Negotiable Invariants

1. **REQ-P48-NI-01**: NO `pubspec.yaml` changes. NO `connectivity_plus` plugin. NO `Timer.periodic`.
2. **REQ-P48-NI-02**: NO `@HiveType` binary TypeAdapters. Use versioned JSON serialization (`schemaVersion`) inside Hive boxes.
3. **REQ-P48-NI-03**: NO touching `lib/features/onboarding/`, `lib/main.dart`, `mini_player_host.dart`, or `docs/AGENT_HANDOFF_BIBLE.md` (Antigravity Phase 47 isolation).
4. **REQ-P48-NI-04**: `dart analyze lib/core/sync test/core/sync` MUST report `0 issues found!`.
5. **REQ-P48-NI-05**: `flutter test test/core/sync/ test/features/social/phase44_video_fixes_and_edge_outbox_test.dart test/features/social/phase46_reels_v3_and_edge_sync_test.dart` MUST be 100% green.
6. **REQ-P48-NI-06**: `pnpm test` in `apps/vhunambi_api` MUST be 100% green across all suites.

---

## 7. Traceability Matrix

| Requirement ID | Description | Tasks | Verification Test |
|---|---|---|---|
| `REQ-P48-PQ-01..05` | Schema v2 model with priority & baseSeq | T1.1, T1.2 | `phase48_sync_hardening_test.dart` (Schema v2 Migration) |
| `REQ-P48-PQ-06..07` | Priority queueing (critical > normal > background) | T1.4 | `phase48_sync_hardening_test.dart` (Priority Ordering) |
| `REQ-P48-OC-01..07` | Outbox size cap (1000), compaction & dead-letter | T1.5, T1.6 | `phase48_sync_hardening_test.dart` (Outbox Compaction) |
| `REQ-P48-PF-01..06` | Per-item SAVEPOINT, commutative counters, conflict | T3.1..T3.3 | `phase48_sync_hardening.test.ts` (Partial Failure & Counters) |
| `REQ-P48-PD-01..04` | Paginated delta sync (`limit`, `hasMore`, ETag 304) | T3.4 | `phase48_sync_hardening.test.ts` (Paginated Delta) |
| `REQ-P48-MP-01..06` | Multi-page delta drain loop & telemetry ring buffer | T2.1..T2.5 | `phase48_sync_hardening_test.dart` (Multi-Page Drain & Telemetry) |
| `REQ-P48-NI-01..06` | Zero new plugins, zero analyzer issues, test green | Pre-flight | `dart analyze` & `pnpm test` CI gates |

# Phase 48 Implementation Tasks: Edge Sync Production Hardening

> **Dual-Agent Isolation Law:** DO NOT touch `pubspec.yaml`, `lib/features/onboarding/`, `lib/main.dart`, `mini_player_host.dart`, or `docs/AGENT_HANDOFF_BIBLE.md`.
> **Forbidden:** `@HiveType` binary TypeAdapters, `connectivity_plus`, `Timer.periodic`.

## Pre-Flight Verification Checklist

- [x] Baseline: `dart analyze lib/core/sync` → 0 issues
- [x] Baseline: `flutter test test/core/sync/` → passing
- [x] Baseline: `pnpm test` in `apps/vhunambi_api` → 14/14 suites green

## Track 1: SyncOutboxService — Priority, Schema v2, Compaction, Dead-Letter

### T1.1 Add `SyncPriority` and `SyncRecordStatus` enums

- [ ] Add `enum SyncPriority { critical, normal, background }` to `sync_outbox_service.dart`
- [ ] Add `enum SyncRecordStatus { pending, failedRetryable, deadLetter }` to `sync_outbox_service.dart`

### T1.2 Upgrade `SyncMutationRecord` to schema v2

- [ ] Add `SyncPriority priority` field (default `background`)
- [ ] Add `int? baseSeq` field
- [ ] Add `int schemaVersion = 2` field
- [ ] Update `copyWith()` to include new fields
- [ ] Update `toJson()` to serialize `priority`, `baseSeq`, `schemaVersion`
- [ ] Update `fromJson()` with graceful v1 → v2 migration (defaults for missing fields)

### T1.3 Add `SyncFlushResult.failed` and `SyncFailedItem`

- [ ] Add `SyncFailedItem` class (`idempotencyKey`, `code`, `message`, `retryable`)
- [ ] Add `failed: List<SyncFailedItem>` to `SyncFlushResult`
- [ ] Add backward-compatible `appliedCount` / `skippedCount` getters

### T1.4 Priority-ordered batch retrieval

- [ ] Implement `getPendingBatch({int maxBatchSize = 50})` — sorts by `SyncPriority` then `createdAt`
- [ ] Exclude `deadLetter` records from pending batches
- [ ] Update `pendingCount` getter to count only `pending` + `failedRetryable`

### T1.5 Compaction, size cap, and dead-letter

- [ ] Enforce `maxOutboxSize = 1000` — evict oldest `background` first, never evict `critical`
- [ ] Move records with `retryCount >= 5` to `deadLetter`
- [ ] Move records older than `ttlDays = 7` to `deadLetter`
- [ ] Add `deadLetterRecords` getter
- [ ] On flush: remove `applied` and `skipped` records immediately

### T1.6 Flush with partial-failure handling

- [ ] Update `flush()` to accept `SyncFlushResult` with `failed` items
- [ ] Increment `retryCount` on retryable failures
- [ ] Move non-retryable failures to `deadLetter`

## Track 2: EdgeSyncCoordinator — Multi-Page Delta, Auto-Reconnect, Telemetry

### T2.1 Extend `EdgeSyncState` with telemetry

- [ ] Add `deadLetterCount`, `lastSyncLatencyMs`, `List<SyncTelemetryEvent> telemetry` to `EdgeSyncState`
- [ ] Add `copyWith()` support for new fields

### T2.2 Add `SyncTelemetryEvent` and ring buffer

- [ ] Add `SyncTelemetryEventType` enum
- [ ] Add `SyncTelemetryEvent` class
- [ ] Add `SyncTelemetryRingBuffer` (bounded 50 items)

### T2.3 Multi-page delta drain in `syncNow()`

- [ ] After flushing outbox, loop `GET /api/v1/sync/delta?since_seq=<cursor>&limit=100`
- [ ] Continue while `hasMore == true`, max 10 pages per sync cycle
- [ ] Update `lastServerSeq` to `nextCursorSeq` / `latestSeq` after each page

### T2.4 Auto-reconnect on app resume

- [ ] Add injectable `Stream<bool> connectivityStream` (default `const Stream.empty()`)
- [ ] Add `onAppResumed()` method — flushes when `pendingCount > 0`
- [ ] No `connectivity_plus`, no `Timer.periodic`

### T2.5 Telemetry recording

- [ ] Record `enqueued`, `batchFlushed`, `partialFailure`, `deltaHydrated`, `deadLetterMoved` events
- [ ] Track `lastSyncLatencyMs` on state

## Track 3: Backend — Per-Item SAVEPOINT, Commutative Counters, Paginated Delta

### T3.1 Per-item SAVEPOINT in `applyMutationsBatch`

- [ ] Wrap each mutation in SQLite `SAVEPOINT` / `RELEASE` / `ROLLBACK TO`
- [ ] Validation error on item #3 never aborts items #1, #2, #4–#10

### T3.2 Commutative counter atomicity

- [ ] `like`, `cosign`, `repost`, `tip` → `SET count = count + 1` (never overwrite)
- [ ] Versioned entity edits with `baseSeq`: reject with `conflict` if stored `seq` is newer

### T3.3 Partial-failure response

- [ ] Return `{ applied, skipped, failed: [{idempotencyKey, code, message, retryable}], latestSeq }`
- [ ] Preserve `appliedCount` / `skippedCount` for backward compatibility

### T3.4 Paginated delta sync

- [ ] `GET /api/v1/sync/delta?since_seq=X&limit=Y` (limit 1..200, default 100)
- [ ] Return `{ changes, latestSeq, nextCursorSeq, hasMore }`
- [ ] Preserve `mutations`, `latestSeq`, `latest_seq`, ETag / 304 behavior

## Track 4: ProfileSettingsDrawer UI Enhancement

### T4.1 Display dead-letter count and telemetry

- [ ] Add dead-letter count chip (`Key('settings_dead_letter_count')`)
- [ ] Add sync latency text (`Key('settings_sync_latency_ms')`)
- [ ] Wire to `edgeSyncCoordinatorProvider` state

## Track 5: Verification & Testing

### T5.1 Client unit tests (`phase48_sync_hardening_test.dart`)

- [ ] Priority ordering: `critical` wallet payout drained before `background` likes
- [ ] Partial-failure batch: valid items removed, retryable failure increments `retryCount`, non-retryable → `deadLetter`
- [ ] Outbox size cap (1000) protecting `critical` over `background`
- [ ] Schema v1 → v2 JSON migration
- [ ] Multi-page delta drain loop with `hasMore`

### T5.2 Backend tests (`phase48_sync_hardening.test.ts`)

- [ ] Partial-failure batch: valid items applied, failed item returns `failed[]`
- [ ] Commutative counter: `cosign` increments atomically, never overwrites
- [ ] Versioned edit conflict: stale `baseSeq` → `conflict`, no overwrite
- [ ] Paginated delta: `limit` + `hasMore` loop returns all changes
- [ ] ETag / 304 preserved

### T5.3 Verification Gates

- [ ] `dart analyze lib/core/sync test/core/sync` → `0 issues found!`
- [ ] `flutter test test/core/sync/ test/features/social/phase44_video_fixes_and_edge_outbox_test.dart test/features/social/phase46_reels_v3_and_edge_sync_test.dart` → 100% green
- [ ] `pnpm test` in `apps/vhunambi_api` → 100% green across all suites

## Known Traps & Mitigations

| Trap | Root Cause | Mandatory Defense |
|---|---|---|
| `@HiveType` double-registration crash | `build_runner` adapters crash if `registerAdapter` called twice across parallel test suites | Use `schemaVersion` JSON migration inside `fromJson()` — no code generation |
| `connectivity_plus` Gradle lock | Adding native plugin while Antigravity builds locks Gradle | Use injectable `Stream<bool>` + `onAppResumed()` from `AppLifecycleState.resumed` |
| `Timer.periodic` test crash | Pending timer assertions fail `flutter test` | No background timers; sync triggered only by user action or app resume |
| Whole-batch rollback | Single validation error aborts all 20 items | Per-item SQLite `SAVEPOINT` |
| Unbounded Hive growth | No compaction or TTL | `maxOutboxSize=1000`, `deadLetter` at retryCount>=5 or ttlDays>=7 |
| Lost updates on concurrent edits | Two clients overwrite each other's edits | `baseSeq` optimistic concurrency → `conflict` on stale |
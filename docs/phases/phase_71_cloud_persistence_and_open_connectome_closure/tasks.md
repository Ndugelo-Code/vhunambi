# Phase 71 — Deterministic Two-Pass Implementation Tasks & Verification Roadmap

**Document ID:** `VHUNAMBI-SPEC-P71-TASKS-V1`  
**Phase:** `71` — Cloudflare Worker Supabase Read/Write-Through Durability, `OPEN` Connectome Closure (`EP-P67`, `EP-P69`, `EP-P37`, `EP-P68`) & 100% Green Test Baseline  
**Date:** `2026-11-20`  
**Status:** `READY FOR STAGE 4 EXECUTION`  
**Companion Documents:** [`blueprint.md`](./blueprint.md) · [`requirements.md`](./requirements.md) · [`design.md`](./design.md) · [`memory.md`](./memory.md)

---

## 1. Master Two-Pass Milestone Roadmap & Dependency Graph

```text
+======================================================================================+
| OVERHAUL PASS 1 — BACKEND & SUPABASE SQL (`supabase/` + `apps/vhunambi_api/`)        |
| Zero Dart edits; independent compile & test boundary (`npx tsc --noEmit`, 27/27 API) |
+======================================================================================+
   [M71.1] Schema Parity, Atomic Quota RPC & Domain-Scoped SWR Read/Write-Through
      |-- Task 1.1: supabase/migrations/20261120000001_phase71_schema_parity_and_rpcs.sql
      |-- Task 1.2: job_types.ts + edge_persistence_bridge.ts (SWR, failure ring, RPC, fixes)
      |-- Task 1.3: vhunambi_db.ts (SQLite parity methods + visionMeta persistence)
      |-- Task 1.4: server.ts + 6 route modules (notifications, wallet, explore, gen, webhook, vision)
      v
   [M71.2] Backend Test Hygiene & Cross-Isolate Simulation Suite (`27/27` API Green)
      |-- Task 2.1: Move src/phase67_notifications_quota.test.ts -> test/phase67_notifications_quota.test.ts
      |-- Task 2.2: Author test/phase71_worker_supabase_readthrough.test.ts (Isolate A <-> Isolate B)
      |-- Task 2.3: Register phase65, phase67, phase71 in package.json (`27/27` suites)
      v
+======================================================================================+
| OVERHAUL PASS 2 — FLUTTER CLIENT & CONNECTOME CLOSURE (`apps/vhunambi_client/`)      |
| Zero TS/SQL edits; independent compile & test boundary (`flutter analyze`, tests)    |
+======================================================================================+
   [M71.3] Close EP-P67, EP-P69, EP-P37 & Extend EP-P68 (`CON-01` – `CON-04`)
      |-- Task 3.1: HttpNotificationRepository + NotificationsNotifier bidirectional sync (`CON-01`)
      |-- Task 3.2: HttpExploreRepository + SocialFeedPostsNotifier + ReelsCommentsNotifier (`CON-02`)
      |-- Task 3.3: ISocialRepository + HttpSocialRepository + RemixLineageTreeSheet (`CON-03`)
      |-- Task 3.4: StudioActionBar + GenerationPipelineNotifier + SubscriptionUpgradeModal (`CON-04`)
      v
   [M71.4] Repair 5 Stale Client Test Files, New Phase 71 Tests & SLEEP Consolidation
      |-- Task 4.1: Repair 5 stale test files (9 assertions) in core/network, social, player
      |-- Task 4.2: Author test/features/phase71_connectome_closure_test.dart
      |-- Task 4.3: Run full verification gates, mark memory.md completed, run consolidate_memory.mjs
```

| Milestone | Pass | Scope | Gate |
| :--- | :---: | :--- | :--- |
| **`M71.1`** | Pass 1 | Supabase SQL migration + Worker SWR read/write-through + Vision durability | `npx tsc --noEmit` (0 errors) |
| **`M71.2`** | Pass 1 | API test hygiene + Cross-isolate simulation suite | `npm test` (`27/27` suites green) |
| **`M71.3`** | Pass 2 | 4 Connectome closures (`EP-P67`, `EP-P69`, `EP-P37`, `EP-P68`) + `STD-UIUX-001` | `flutter analyze --no-pub` (0 issues) |
| **`M71.4`** | Pass 2 | 5 stale client test repairs + Phase 71 client suite + `SLEEP` consolidation | `flutter test` green + `consolidate_memory.mjs` |

---

## 2. Milestone `M71.1`: Postgres Schema Parity, Atomic Quota RPC & Worker SWR Durability

### Task `1.1` — Author Supabase Migration (`REQ-P71-SQL-01..03`)
- **Target File:** `supabase/migrations/20261120000001_phase71_schema_parity_and_rpcs.sql`
- **Implementation:** Implement the exact idempotent SQL from `design.md` §1:
  - Add `mood`, `language`, `discovery_stage`, `data_json`, `created_at` to `public.explore_tracks` + `idx_explore_tracks_stage_updated`.
  - Add `item_type`, `created_at` to `public.user_library_sync`.
  - Define `public.consume_free_monthly_song_quota_atomic(p_user_id TEXT) RETURNS JSONB` with `FOR UPDATE` row locking and 30-day cycle rollover.
- **Acceptance Criteria:** Migration is strictly idempotent (`ADD COLUMN IF NOT EXISTS`, `CREATE OR REPLACE FUNCTION`, `ON CONFLICT DO NOTHING`) and returns all 8 camelCase JSONB fields (`userId`, `planTier`, `freeMonthlySongsLimit`, `freeMonthlySongsUsed`, `freeMonthlySongsRemaining`, `cycleResetAt`, `updatedAt`, `allowed`).

### Task `1.2` — Upgrade `GenerationJob` & `EdgeIsolateDatabaseEngine` (`REQ-P71-SWR-01..03`, `REQ-P71-WRT-01..05`)
- **Target Files:**
  - `apps/vhunambi_api/src/modules/jobs/job_types.ts`
  - `apps/vhunambi_api/src/db/edge_persistence_bridge.ts`
- **Implementation:** Per `design.md` §2.1–§2.2:
  - Add `visionMeta?: Record<string, unknown>;` to `GenerationJob`.
  - Replace `coldStartHydrated` lock with `domainHydratedAtMs`, `domainInFlightPromises`, `DEFAULT_SWR_TTL_MS = 12_000`, `withTimeoutResult`, and optional constructor `injectedDriver?: SupabaseCloudDriver`.
  - Upgrade `mirrorWriteThrough` to log `console.error` + record into bounded 100-item `writeThroughFailures` ring (`getWriteThroughFailures()`); add `awaitWriteThrough`.
  - Implement `syncNotificationsFromCloud`, `syncCreatorQuotaFromCloud`, `syncGenerationJobFromCloud`, `syncExploreFromCloud`, `syncCreatorWalletFromCloud`, `consumeFreeMonthlySongQuotaAsync`, `upsertNotificationAsync`, and `upsertGenerationJobAsync`.
  - Fix `applyMutationsBatch` track `like` write-through (`explore_tracks.likes_count`), `upsertExploreTrack` & `syncLibraryTracks` parity columns, and `hydrateReelCommentRows` / `mapReelCommentRow` (`likes_count`, `username`, `display_name`, `avatar_url`, `is_creator`).
- **Acceptance Criteria:** No `.catch(() => {})` inside `mirrorWriteThrough`; timeout or error never sets `domainHydratedAtMs`; `reel_comments` preserves all 5 fields even when `data_json` is `{}`.

### Task `1.3` — Add Matching Methods to `VhunambiDatabase` (`REQ-P71-SWR-03`)
- **Target File:** `apps/vhunambi_api/src/db/vhunambi_db.ts`
- **Implementation:** Per `design.md` §2.3, export `AtomicQuotaConsumeResult` and `WriteThroughFailureRecord`, add SQLite-backed matching methods (`syncNotificationsFromCloud`, `syncCreatorQuotaFromCloud`, `syncGenerationJobFromCloud`, `syncExploreFromCloud`, `syncCreatorWalletFromCloud`, `consumeFreeMonthlySongQuotaAsync`, `upsertNotificationAsync`, `upsertGenerationJobAsync`, `getWriteThroughFailures`), and persist/restore `visionMeta` in `generation_jobs.manifest_json`.
- **Acceptance Criteria:** `npx tsc --noEmit` passes with zero missing-property errors on `vhunambiDb`.

### Task `1.4` — Wire Domain Read/Write-Through & Vision Durability Across Routes (`REQ-P71-SWR-04`, `REQ-P71-WRT-06`)
- **Target Files:**
  - `apps/vhunambi_api/src/server.ts`
  - `apps/vhunambi_api/src/routes/notification_routes.ts`
  - `apps/vhunambi_api/src/routes/wallet_routes.ts`
  - `apps/vhunambi_api/src/routes/explore_routes.ts`
  - `apps/vhunambi_api/src/routes/generation_routes.ts`
  - `apps/vhunambi_api/src/routes/webhook_routes.ts`
  - `apps/vhunambi_api/src/routes/vision_routes.ts`
- **Implementation:** Per `design.md` §3.1–§3.6:
  - Bypass monolithic 21-table cold-start wall in `server.ts` for routes that perform targeted domain sync.
  - Wire `syncNotificationsFromCloud`, `syncCreatorQuotaFromCloud`, `syncCreatorWalletFromCloud`, `syncExploreFromCloud`, `syncGenerationJobFromCloud`, `consumeFreeMonthlySongQuotaAsync`, `upsertNotificationAsync`, and `upsertGenerationJobAsync` across the 6 route files.
  - Remove `visionMetaFallbackStore` in `vision_routes.ts` and read/write `visionMeta` through `generation_jobs`.
- **Acceptance Criteria:** `npx tsc --noEmit` exits `0`; zero module-level `visionMetaFallbackStore` RAM Map remains in `vision_routes.ts`.

---

## 3. Milestone `M71.2`: Backend Test Hygiene & Cross-Isolate Simulation Suite

### Task `2.1` — Relocate `phase67_notifications_quota.test.ts` (`REQ-P71-API-TST-01`)
- **Target Files:** Remove `apps/vhunambi_api/src/phase67_notifications_quota.test.ts`; create `apps/vhunambi_api/test/phase67_notifications_quota.test.ts`.
- **Implementation:** Update imports to `../src/...` and run all 4 test cases inside a standalone `async function runPhase67Tests()` matching the other `test/*.test.ts` suites.
- **Acceptance Criteria:** `tsx test/phase67_notifications_quota.test.ts` exits `0`; zero `*.test.ts` files exist inside `apps/vhunambi_api/src/`.

### Task `2.2` — Author Cross-Isolate Durability Suite (`REQ-P71-API-TST-02`)
- **Target File:** `apps/vhunambi_api/test/phase71_worker_supabase_readthrough.test.ts`
- **Implementation:** Implement `design.md` §4.2 verifying cross-isolate notifications, Kinetic Posts, `reel_comments` projection, RunPod webhook visibility, 12-request concurrent atomic 10-song quota race, timeout non-pinning, failure ring capture, and `applyMutationsBatch` track-like mirror.
- **Acceptance Criteria:** `tsx test/phase71_worker_supabase_readthrough.test.ts` exits `0`.

### Task `2.3` — Register All 27 Suites in `package.json` (`REQ-P71-API-TST-03`)
- **Target File:** `apps/vhunambi_api/package.json`
- **Implementation:** Append `phase65_foundation_resilience.test.ts`, `phase67_notifications_quota.test.ts`, and `phase71_worker_supabase_readthrough.test.ts` to `scripts.test`.
- **Acceptance Criteria:** `npx tsc --noEmit` exits `0` AND `npm test` executes and passes all `27/27` suites!

---

## 4. Milestone `M71.3`: Client `OPEN` Connectome Closure (`CON-01` – `CON-04`)

### Task `3.1` — Close `EP-P67-NOTIF-API` (`REQ-P71-CON01-01..02`)
- **Target Files:**
  - `apps/vhunambi_client/lib/features/notifications/data/repositories/http_notification_repository.dart` (NEW)
  - `apps/vhunambi_client/lib/features/notifications/presentation/providers/notifications_provider.dart`
- **Implementation:** Implement `HttpNotificationRepository` + `httpNotificationRepositoryProvider` per `design.md` §5.1, and wire `syncFromCloud()` + non-blocking mutation mirroring into `NotificationsNotifier` + `notificationsProvider` per `design.md` §5.2.
- **Acceptance Criteria:** Hive hydrates at 0ms, `syncFromCloud()` merges remote alerts preserving local `isRead`, and offline/test mode never opens sockets.

### Task `3.2` — Close `EP-P69-POST-COSIGN-REPOST-HTTP` (`REQ-P71-CON02-01..04`)
- **Target Files:**
  - `apps/vhunambi_client/lib/features/explore/data/repositories/http_explore_repository.dart`
  - `apps/vhunambi_client/lib/features/explore/presentation/providers/explore_providers.dart`
  - `apps/vhunambi_client/lib/features/social/presentation/providers/reels_comments_provider.dart`
- **Implementation:** Per `design.md` §6:
  - Add `fetchExploreFeed`, `cosignPost`, `repostPost`, `likeComment`, and `shouldSkipNetwork` getter to `HttpExploreRepository`.
  - Update `SocialFeedPostsNotifier` (`toggleLike`, `addPost`, `repostPost`, `cosignPost`) to run direct HTTP first and enqueue to `_outbox` ONLY when offline/failed; update `refreshFromCloud()` to hydrate `likeCount` & `commentCount`.
  - Update `ReelsCommentsNotifier.toggleCommentLike` so `post_*` / `kpost_*` comment likes call `exploreRepositoryProvider.likeComment(commentId)`.
- **Acceptance Criteria:** Direct HTTP success enqueues `0` outbox records (zero double-increment); offline failure enqueues `1` outbox record; `refreshFromCloud()` updates `likeCount` & `commentCount`.

### Task `3.3` — Close `EP-P37-REMIX-TREE-API` (`REQ-P71-CON03-01..02`)
- **Target Files:**
  - `apps/vhunambi_client/lib/features/social/domain/repositories/i_social_repository.dart`
  - `apps/vhunambi_client/lib/features/social/data/repositories/http_social_repository.dart`
  - `apps/vhunambi_client/lib/features/social/presentation/providers/remix_lineage_provider.dart`
  - `apps/vhunambi_client/lib/features/social/presentation/widgets/remix_lineage_tree_sheet.dart`
- **Implementation:** Per `design.md` §7, add `getClipRemixes(String clipId)`, `remixNodeFromPublishedClip`, `mergeRemoteRemixChildren`, and `remixLineageRemoteChildrenProvider`, merging remote children onto the synchronous root node inside `RemixLineageTreeSheet`.
- **Acceptance Criteria:** Existing synchronous lineage tests stay green; remote remix children appear merged and deduplicated when returned by `/api/social/clips/:id/remixes`.

### Task `3.4` — Extend `EP-P68-CREATOR-ALLOWANCE` & Fix `STD-UIUX-001` Violations (`REQ-P71-CON04-01..03`)
- **Target Files:**
  - `apps/vhunambi_client/lib/features/studio/presentation/widgets/studio_action_bar.dart`
  - `apps/vhunambi_client/lib/features/studio/presentation/providers/generation_pipeline_providers.dart`
  - `apps/vhunambi_client/lib/features/home/presentation/widgets/subscription_upgrade_modal.dart`
- **Implementation:** Per `design.md` §8:
  - Mount `Key('studio_allowance_chip')` in `StudioActionBar` and replace stock `Icons.check_circle_rounded` with `PhosphorIcon(PhosphorIconsFill.checkCircle)`.
  - Call `_ref.read(creatorAllowanceProvider.notifier).consumeOneSongOptimistically()` in `GenerationPipelineNotifier.submitAndStartGeneration` right after `submitGeneration(...)` succeeds.
  - Embed `Key('upgrade_modal_allowance_card')` in `SubscriptionUpgradeModal` and replace hardcoded `Colors.white` (`#L304`) with `AppColors.brandContrast`.
- **Acceptance Criteria:** `flutter analyze --no-pub` reports `0` issues; zero stock `Icons.*` or hardcoded `Colors.white` in modified regions.

---

## 5. Milestone `M71.4`: Stale Client Test Repairs, Phase 71 Test Suite & `SLEEP` Consolidation

### Task `4.1` — Repair All 5 Stale Client Test Files (`REQ-P71-CLI-TST-01..05`)
- **Target Files:**
  1. `apps/vhunambi_client/test/core/network/phase63_e2e_cloud_pipeline_test.dart`
  2. `apps/vhunambi_client/test/features/social/reel_audio_pool_and_kinetic_canvas_test.dart`
  3. `apps/vhunambi_client/test/features/player/audio_source_resolver_test.dart`
  4. `apps/vhunambi_client/test/features/player/phase35_drag_dismiss_bin_test.dart`
  5. `apps/vhunambi_client/test/features/player/player_hardware_bridge_test.dart`
- **Implementation:** Apply the exact surgical updates specified in `design.md` §9.1.
- **Acceptance Criteria:** All 5 test files pass 100% under `flutter test --no-pub --timeout=60s`.

### Task `4.2` — Author Phase 71 Client Connectome Closure Suite (`REQ-P71-CLI-TST-06`)
- **Target File:** `apps/vhunambi_client/test/features/phase71_connectome_closure_test.dart`
- **Implementation:** Implement all 4 test groups specified in `design.md` §9.2 (plain `test()` for `Dio` / `http.MockClient`, bounded `pump()` for widget tests).
- **Acceptance Criteria:** `flutter test --no-pub --timeout=60s test/features/phase71_connectome_closure_test.dart` passes 100%.

### Task `4.3` — Final Verification & `SLEEP` Connectome Promotion (`G-71-04..06`)
- **Target File:** `docs/phases/phase_71_cloud_persistence_and_open_connectome_closure/memory.md`
- **Implementation:** Only AFTER all Pass 1 & Pass 2 verification gates pass, update `"status": "completed"` and `"completed_at"` in `memory.md`, then run `node .agents/skills/vhunambi-memory/scripts/consolidate_memory.mjs`.
- **Acceptance Criteria:** `EP-P67-NOTIF-API`, `EP-P69-POST-COSIGN-REPOST-HTTP`, and `EP-P37-REMIX-TREE-API` automatically promote from `OPEN` -> `CONNECTED_EXTENSIBLE` in `CONNECTOME_GRAPH.json` and `CORTEX_INDEX.md`.

---

## 6. Stage 4 Anti-Trap Checklist & PowerShell Verification Commands

### Anti-Trap Execution Checklist
- [x] Pass 1 (`M71.1`–`M71.2`) and Pass 2 (`M71.3`–`M71.4`) executed cleanly in order with independent gate checks.
- [x] `SocialFeedPostsNotifier` (`explore_providers.dart`) updated in place without renaming class/provider symbols.
- [x] `VhunambiDatabase` (`vhunambi_db.ts`) implements matching signatures for every new async/sync method on `EdgeIsolateDatabaseEngine`.
- [x] `mirrorWriteThrough` never silently swallows errors; `domainHydratedAtMs` is never stamped on timeout/exception.
- [x] Zero raw Unicode emojis or stock `Icons.*` introduced (`STD-UIUX-001`).
- [x] All widget tests use bounded `pump` loops and `--timeout=60s` (never unbounded `pumpAndSettle` on repeating tickers).
- [x] `memory.md` marked `"completed"` and `consolidate_memory.mjs` executed ONLY after every analyzer and test command passes.

### Exact Stage 4 Verification Commands (PowerShell)

```powershell
# Pass 1 Verification (apps/vhunambi_api/)
Push-Location apps/vhunambi_api
npx tsc --noEmit
npm test
Pop-Location

# Pass 2 Verification (apps/vhunambi_client/)
Push-Location apps/vhunambi_client
flutter analyze --no-pub
flutter test --no-pub --timeout=60s test/features/phase71_connectome_closure_test.dart
flutter test --no-pub --timeout=60s test/core/network/phase63_e2e_cloud_pipeline_test.dart test/features/social/reel_audio_pool_and_kinetic_canvas_test.dart test/features/player/audio_source_resolver_test.dart test/features/player/phase35_drag_dismiss_bin_test.dart test/features/player/player_hardware_bridge_test.dart
flutter test --no-pub --timeout=60s test/features/notifications/ test/features/explore/ test/features/studio/ test/features/home/
Pop-Location

# SLEEP Consolidation (repo root — ONLY after all checks above exit 0)
node .agents/skills/vhunambi-memory/scripts/consolidate_memory.mjs
node .agents/skills/vhunambi-memory/scripts/query_connectome.mjs --open
```

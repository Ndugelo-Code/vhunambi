# Phase 71 — Functional, Non-Functional & Verification Requirements Specification

**Document ID:** `VHUNAMBI-SPEC-P71-REQUIREMENTS-V1`  
**Phase:** `71` — Cloudflare Worker Supabase Read/Write-Through Durability, `OPEN` Connectome Closure & 100% Green Test Baseline  
**Date:** `2026-11-20`  
**Status:** `SPECIFICATION HARDENED (STAGE 2 & 3)`  
**Companion Documents:** [`blueprint.md`](./blueprint.md) · [`design.md`](./design.md) · [`tasks.md`](./tasks.md) · [`memory.md`](./memory.md)

---

## 1. Document Scope & EARS / RFC-2119 Conventions

This specification defines every verifiable behavioral, schema, concurrency, UI/UX, and CI baseline requirement for Phase 71 using **EARS** (Easy Approach to Requirements Syntax) and **RFC-2119** keywords:

- **SHALL / MUST:** Mandatory invariant enforced by static analysis, unit/widget tests, or SQL migration constraints.
- **WHEN `<trigger>`:** Event-driven behavior executed on a specific HTTP request, user gesture, or isolate lifecycle transition.
- **WHILE `<state>`:** Continuous invariant holding during an active operating state (e.g., offline mode, warm Cloudflare Worker isolate, or test VM execution).
- **IF `<condition>` THEN:** Defensive fallback or fault-containment branch.
- **WHERE `<scope>`:** Feature- or runtime-scoped behavior (e.g., `workerd` without `node:sqlite` vs. Node 24 local SQLite).

**Canonical Class-Name Grounding:**
- The Explore Kinetic Posts state notifier in [`apps/vhunambi_client/lib/features/explore/presentation/providers/explore_providers.dart`](../../../apps/vhunambi_client/lib/features/explore/presentation/providers/explore_providers.dart) is named **`SocialFeedPostsNotifier`** (`socialFeedPostsProvider`). All requirements referencing Explore post state mutations target `SocialFeedPostsNotifier`.

---

## 2. Pass 1 — Supabase Schema Parity, Atomic Quota RPC & Worker Durability (`M71.1`)

### 2.1 PostgreSQL Schema Parity & Atomic Quota RPC (`REQ-P71-SQL-*`)

- **`REQ-P71-SQL-01` (`explore_tracks` Parity Columns):**  
  `supabase/migrations/20261120000001_phase71_schema_parity_and_rpcs.sql` SHALL idempotently alter `public.explore_tracks` via `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` to ensure presence of:
  - `mood TEXT NOT NULL DEFAULT 'Vibrant'`
  - `language TEXT NOT NULL DEFAULT 'isiZulu'`
  - `discovery_stage TEXT NOT NULL DEFAULT 'freshCrate'`
  - `data_json JSONB NOT NULL DEFAULT '{}'::jsonb`
  - `created_at BIGINT NOT NULL DEFAULT (EXTRACT(EPOCH FROM now()) * 1000)::BIGINT`
- **`REQ-P71-SQL-02` (`user_library_sync` Parity Columns):**  
  The migration SHALL idempotently alter `public.user_library_sync` to ensure presence of:
  - `item_type TEXT NOT NULL DEFAULT 'track'`
  - `created_at BIGINT NOT NULL DEFAULT (EXTRACT(EPOCH FROM now()) * 1000)::BIGINT`
- **`REQ-P71-SQL-03` (Atomic Monthly Quota RPC — `EP-P71-ATOMIC-QUOTA-RPC`):**  
  The migration SHALL define `CREATE OR REPLACE FUNCTION public.consume_free_monthly_song_quota_atomic(p_user_id TEXT) RETURNS JSONB` (`LANGUAGE plpgsql SECURITY DEFINER`) which:
  1. Upserts a default `'free'` row (`free_monthly_songs_limit = 10`, `free_monthly_songs_used = 0`, `cycle_reset_at = now() + INTERVAL '30 days'`) if `p_user_id` does not yet exist (`ON CONFLICT (user_id) DO NOTHING`).
  2. Locks the creator's row via `SELECT ... FROM public.creator_quotas WHERE user_id = p_user_id FOR UPDATE`.
  3. Resets `free_monthly_songs_used = 0` and advances `cycle_reset_at = now() + INTERVAL '30 days'` IF `now() >= v_row.cycle_reset_at`.
  4. IF `LOWER(v_row.plan_tier) <> 'free'` OR `v_row.free_monthly_songs_limit < 0`, returns `allowed = true` without incrementing `free_monthly_songs_used`.
  5. Otherwise, IF `v_used < v_row.free_monthly_songs_limit`, increments `free_monthly_songs_used = v_used + 1` and sets `allowed = true`; ELSE preserves `v_used` and sets `allowed = false`.
  6. Persists `free_monthly_songs_used`, `cycle_reset_at`, and `updated_at = now()`, returning JSONB with exact camelCase keys: `userId`, `planTier`, `freeMonthlySongsLimit`, `freeMonthlySongsUsed`, `freeMonthlySongsRemaining`, `cycleResetAt`, `updatedAt`, and `allowed`.

### 2.2 Domain-Scoped SWR Read-Through & Non-Pinning Hydration (`REQ-P71-SWR-*`)

- **`REQ-P71-SWR-01` (Elimination of Monolithic Single-Shot `coldStartHydrated` Lock):**  
  WHERE `EdgeIsolateDatabaseEngine` runs with a configured `SupabaseCloudDriver`, the engine SHALL track freshness per domain/tenant scope in `private readonly domainHydratedAtMs = new Map<string, number>()` with default SWR TTL `12_000 ms` (`EXPLORE_SWR_TTL_MS = 12_000`) instead of permanently pinning a global `coldStartHydrated = true` flag.
- **`REQ-P71-SWR-02` (Zero Freshness Seal on Timeout or Error):**  
  IF any PostgREST `selectRows` call inside a domain sync throws OR exceeds its timeout (`3000 ms` – `4500 ms`), THEN `EdgeIsolateDatabaseEngine` SHALL NOT record `Date.now()` in `domainHydratedAtMs` for that domain key, guaranteeing the next request retries Supabase cleanly.
- **`REQ-P71-SWR-03` (Targeted Domain Read-Through Helpers — `EP-P71-EDGE-SWR-READTHROUGH`):**  
  `EdgeIsolateDatabaseEngine` SHALL expose five targeted cloud read-through helpers (each returning cleanly as a safe no-op when `SupabaseCloudDriver.isConfigured()` is `false`, and each mirrored as a no-op/local method on `VhunambiDatabase` in `vhunambi_db.ts` for TypeScript parity):
  1. `syncNotificationsFromCloud(userId: string, cOrEnv?: unknown): Promise<NotificationRecord[]>` — invoked by `GET /api/notifications`.
  2. `syncCreatorQuotaFromCloud(userId: string, cOrEnv?: unknown): Promise<CreatorQuotaRecord>` — invoked by `GET /api/wallet/allowance` and `POST /v1/generations`.
  3. `syncGenerationJobFromCloud(genId: string, cOrEnv?: unknown): Promise<GenerationJob | null>` — invoked by `GET /v1/generations/:id`, `GET /v1/generations/:id/manifest`, `GET /v1/vision/:id`, and `GET /v1/vision/render-video/:id`, guaranteeing RunPod webhook completions on Isolate A are immediately visible to polling Isolate B.
  4. `syncExploreFromCloud(force?: boolean, cOrEnv?: unknown): Promise<boolean>` — 12s SWR TTL (`force = true` bypasses TTL), invoked by `GET /api/explore`, `GET /api/explore/tracks`, `GET /api/explore/feed`, `GET /api/explore/posts/:id`, and `GET /api/explore/posts/:id/comments`.
  5. `syncCreatorWalletFromCloud(creatorId: string, cOrEnv?: unknown): Promise<boolean>` — invoked by `GET /api/wallet/:creatorId`, `POST /api/wallet/payout`, and `GET /api/creators/:id/wallet`.
- **`REQ-P71-SWR-04` (Scoped Middleware Dispatch in `server.ts`):**  
  `server.ts` SHALL bind `EdgePersistenceBridge.setActiveContext(c)` for every request without blocking every `/api` or `/v1` route on a monolithic 21-table cold-start wall; `ensureColdStartHydrated(c)` MAY remain available for explicit/legacy callers and initial auth/catalog bootstrap, but SHALL NOT permanently seal `coldStartHydrated = true` when any table query fails or times out.

### 2.3 Durable Write-Through, Telemetry Ring & Projection Fixes (`REQ-P71-WRT-*`)

- **`REQ-P71-WRT-01` (Structured Failure Diagnostics & Bounded Telemetry Ring):**  
  WHEN a PostgREST or RPC operation inside `mirrorWriteThrough(label, op)` throws, `EdgeIsolateDatabaseEngine` SHALL log a structured `console.error('[EdgeWriteThroughError]', ...)` entry AND append a `WriteThroughFailureRecord` (`{ id, label, error, timestamp }`) to an in-isolate bounded ring buffer (`MAX_WRITE_THROUGH_FAILURES = 100`) exposed via `getWriteThroughFailures(): WriteThroughFailureRecord[]` (and cleared in `resetForTesting()`). Silent `.catch(() => {})` swallowing is FORBIDDEN.
- **`REQ-P71-WRT-02` (Awaited Critical Write-Through Path):**  
  `EdgeIsolateDatabaseEngine` SHALL provide `awaitWriteThrough(label, op, cOrEnv?)` and use it for:
  - `consumeFreeMonthlySongQuotaAsync(userId, cOrEnv?)` (calls `driver.callRpc('consume_free_monthly_song_quota_atomic', { p_user_id: cid })` when Supabase is configured, reconciling local isolate cache from the authoritative RPC result, with local fallback if unconfigured or RPC unavailable).
  - `upsertNotificationAsync(input, cOrEnv?)` (used by `POST /api/notifications` and `POST /v1/generations`).
  - `upsertGenerationJobAsync(job, creatorId, jobKind, cOrEnv?)` / `completeJobAsync(...)` (used by `POST /v1/webhooks/ace-step` so completed jobs hit Postgres before returning `200 { received: true }`).
- **`REQ-P71-WRT-03` (`applyMutationsBatch` Track Like Write-Through):**  
  WHEN `applyMutationsBatch` processes `entityType === 'track'` and `action === 'like'`, `EdgeIsolateDatabaseEngine` SHALL increment `t.like_count` AND call `mirrorWriteThrough('explore_tracks.like', ...)` to `patchRows('explore_tracks', 'id=eq.<id>', { likes_count: t.like_count, updated_at: Date.now() })`.
- **`REQ-P71-WRT-04` (`explore_tracks` & `user_library_sync` Write-Through Parity):**  
  `upsertExploreTrack` SHALL mirror `mood`, `language`, `discovery_stage`, `data_json`, and `created_at` to Postgres `explore_tracks`, and `syncLibraryTracks` SHALL mirror `item_type` and `created_at` to Postgres `user_library_sync`.
- **`REQ-P71-WRT-05` (`reel_comments` Hydration & Mapping Fidelity):**  
  Both `hydrateReelCommentRows` (`edge_persistence_bridge.ts`) and `mapReelCommentRow` SHALL preserve `likes_count` (mapped to `likeCount`), `username`, `display_name` (`displayName`), `avatar_url` (`avatarUrl`), and `is_creator` (`isCreator`) directly from SQL columns even when omitted from `data_json`.
- **`REQ-P71-WRT-06` (Vision Metadata Durability in `generation_jobs`):**  
  `vision_routes.ts` SHALL persist `VisionJobMeta` (`kind`, `promptText`, `seed`, `width`, `height`, `outputImageUrl`, `videoUrl`, `resolution`, `fps`, `preset`, `engine`, `renderedAt`) inside `generation_jobs.manifest_json` (under a namespaced `visionMeta` envelope alongside `jobKind = 'vision' | 'render-video'`) and read it back via `vhunambiDb.syncGenerationJobFromCloud(id, c)` + `getJob(id)` on `GET /v1/vision/:id` and `GET /v1/vision/render-video/:id`, eliminating volatile dependence on module-RAM `visionMetaFallbackStore`.

---

## 3. Pass 1 — Backend Test Hygiene & Cross-Isolate Proof (`M71.2`)

- **`REQ-P71-API-TST-01` (Relocate Misplaced `src/` Test File):**  
  `apps/vhunambi_api/src/phase67_notifications_quota.test.ts` SHALL be moved to `apps/vhunambi_api/test/phase67_notifications_quota.test.ts`, with imports updated from `./...` to `../src/...` and assertions refactored to the standalone top-level `async function runPhase67Tests()` pattern used by the other `test/*.test.ts` suites so `tsc` never compiles test files into `dist/`.
- **`REQ-P71-API-TST-02` (Cross-Isolate Simulation Suite):**  
  `apps/vhunambi_api/test/phase71_worker_supabase_readthrough.test.ts` SHALL instantiate **two completely separate** `EdgeIsolateDatabaseEngine` instances (`isolateA`, `isolateB`) sharing a single in-memory mocked `SupabaseCloudDriver` (intercepted via a clean mock driver factory / `globalThis.fetch` PostgREST simulator) and assert:
  1. Notifications written on `isolateA` become visible on warm `isolateB` via `syncNotificationsFromCloud`.
  2. Kinetic posts and threaded comments written on `isolateA` become visible on warm `isolateB` via `syncExploreFromCloud(true)` with `likes_count`, `username`, `display_name`, `avatar_url`, and `is_creator` preserved intact.
  3. A RunPod webhook generation completion written on `isolateA` becomes visible immediately on warm `isolateB` via `syncGenerationJobFromCloud`.
  4. Concurrent `consumeFreeMonthlySongQuotaAsync` calls across `isolateA` and `isolateB` execute `consume_free_monthly_song_quota_atomic` without double-spending past `10/10`.
  5. A simulated Supabase timeout/error on `syncExploreFromCloud` does NOT seal freshness, and a failed `mirrorWriteThrough` appends to `getWriteThroughFailures()`.
  6. `applyMutationsBatch` track `like` mirrors `likes_count` to `explore_tracks`.
- **`REQ-P71-API-TST-03` (`npm test` Registration — 27/27 Suites):**  
  `apps/vhunambi_api/package.json` `scripts.test` SHALL execute `test/phase65_foundation_resilience.test.ts`, `test/phase67_notifications_quota.test.ts`, and `test/phase71_worker_supabase_readthrough.test.ts` alongside all 24 existing suites (`27/27` total).

---

## 4. Pass 2 — Client `OPEN` Connectome Closure (`M71.3`)

### 4.1 `EP-P67-NOTIF-API` — Cloud Notification Sync (`REQ-P71-CON01-*`)

- **`REQ-P71-CON01-01` (`HttpNotificationRepository`):**  
  `apps/vhunambi_client/lib/features/notifications/data/repositories/http_notification_repository.dart` SHALL implement `HttpNotificationRepository` backed by `SovereignApiClient` with a test-safe `_shouldSkipNetwork` guard (`isTestMode && !_hasCustomClient`) and expose:
  - `Future<List<NotificationEntity>?> fetchNotifications()` -> `GET $_apiRestBaseUrl/notifications` (normalizing `body` -> `message` when needed; returns `null` when skipped/offline so caller preserves Hive state).
  - `Future<bool> upsertNotification(NotificationEntity entity)` -> `POST $_apiRestBaseUrl/notifications` (sending both `message` and `body`).
  - `Future<bool> markRead(String id)` -> `PATCH $_apiRestBaseUrl/notifications/$id/read`.
  - `Future<bool> markAllRead()` -> `POST $_apiRestBaseUrl/notifications/mark-all-read`.
  - `Future<bool> deleteNotification(String id)` -> `DELETE $_apiRestBaseUrl/notifications/$id`.
- **`REQ-P71-CON01-02` (`NotificationsNotifier` Bidirectional Sync):**  
  `NotificationsNotifier` SHALL accept an optional `HttpNotificationRepository? remoteRepo` (injected by `notificationsProvider` via `httpNotificationRepositoryProvider`) and:
  - Hydrate Hive synchronously/immediately (`0ms` cold-start UI).
  - Expose `Future<void> syncFromCloud()` (called automatically after `hydrateFromStorage()` when authenticated/online) that fetches server-emitted notifications (`notif_gen_*`, `notif_quota_low_*`), merges them with Hive preserving `local.isRead || remote.isRead`, filters legacy demo mock IDs, sorts newest-first, and saves merged records to Hive.
  - Mirror `addNotification`, `upsertNotification`, `markAsRead`, `markAllAsRead`, and `removeNotification` non-blockingly via `unawaited(_remoteRepo?.<op>())` while preserving 100% offline Hive operation.

### 4.2 `EP-P69-POST-COSIGN-REPOST-HTTP` — Direct Explore HTTP + Offline-Only Outbox (`REQ-P71-CON02-*`)

- **`REQ-P71-CON02-01` (`HttpExploreRepository` 4 Missing Endpoints):**  
  `HttpExploreRepository` SHALL add:
  - `Future<List<Map<String, dynamic>>> fetchExploreFeed({String? stage, String? genre, int limit = 20, int offset = 0})` -> `GET $_baseUrl/explore/feed`.
  - `Future<({int cosignCount, String? discoveryStage, bool graduated})?> cosignPost(String postId, {String? creatorId})` -> `POST $_baseUrl/explore/posts/$postId/cosign`.
  - `Future<({int repostCount, Map<String, dynamic>? repost})?> repostPost(String postId, {Map<String, dynamic>? repost})` -> `POST $_baseUrl/explore/posts/$postId/repost`.
  - `Future<({bool liked, int likeCount})?> likeComment(String commentId)` -> `POST $_baseUrl/explore/comments/$commentId/like`.
- **`REQ-P71-CON02-02` (Direct HTTP with Offline-Only Outbox Fallback — Zero Double-Increment):**  
  In `SocialFeedPostsNotifier` (`explore_providers.dart`), `toggleLike`, `cosignPost`, `repostPost`, and `addPost` SHALL update local state + Hive cache immediately, then dispatch the direct HTTP call on `repository`:
  - IF direct HTTP returns a non-null server result, reconcile authoritative server counts (`likeCount`, `cosignCount`, `repostCount`) into state and **SHALL NOT** enqueue a duplicate mutation to `_outbox`.
  - IF `repository == null` OR direct HTTP returns `null` (offline/error/skipped), THEN enqueue the mutation to `_outbox?.enqueue(...)` for offline replay.
- **`REQ-P71-CON02-03` (`refreshFromCloud` Full Count Hydration):**  
  `SocialFeedPostsNotifier.refreshFromCloud()` SHALL hydrate `likeCount` and `commentCount` alongside `cosignCount` and `repostCount` for both existing posts (`existing.copyWith(...)`) and newly discovered cloud posts.
- **`REQ-P71-CON02-04` (Kinetic Post Comment Like Routing):**  
  `ReelsCommentsNotifier.toggleCommentLike({required String clipId, required String commentId})` SHALL detect Kinetic Post IDs (`clipId.startsWith('post_') || clipId.startsWith('kpost_')`) and dispatch `_ref!.read(exploreRepositoryProvider).likeComment(commentId)` (`POST /api/explore/comments/:id/like`), falling back to `_repo?.toggleLikeComment(commentId)` for reel clips.

### 4.3 `EP-P37-REMIX-TREE-API` — Live Genealogical Remix Graph (`REQ-P71-CON03-*`)

- **`REQ-P71-CON03-01` (`ISocialRepository` & `HttpSocialRepository`):**  
  `ISocialRepository` SHALL declare `Future<List<PublishedClip>> getClipRemixes(String clipId);` and `HttpSocialRepository` SHALL implement it via `GET $_baseUrl/social/clips/$clipId/remixes`, decoding `response.data['remixes']` defensively via `JsonSafe.asList` / `JsonSafe.asMap` and returning `const <PublishedClip>[]` when `_shouldSkipNetwork` or offline.
- **`REQ-P71-CON03-02` (`remixLineageRemoteChildrenProvider` & `RemixLineageTreeSheet` Merge):**  
  `remix_lineage_provider.dart` SHALL export:
  - `RemixNode remixNodeFromPublishedClip(PublishedClip clip, {int depth = 1})` helper.
  - `mergeRemoteRemixChildren(RemixNode root, List<PublishedClip> remoteRemixes)` pure merge function that deduplicates by `id` and appends remote children onto `root.children`.
  - `remixLineageRemoteChildrenProvider = FutureProvider.family<List<PublishedClip>, String>((ref, clipId) => ref.watch(socialRepositoryProvider).getClipRemixes(clipId))`.
  `RemixLineageTreeSheet` SHALL watch both `remixLineageTreeProvider(trackOrClipId)` (synchronous fallback) and `remixLineageRemoteChildrenProvider(trackOrClipId)`, merging live remote children smoothly onto `rootNode` without blocking initial render or breaking synchronous widget tests.

### 4.4 `EP-P68-CREATOR-ALLOWANCE` Extension & `STD-UIUX-001` Polish (`REQ-P71-CON04-*`)

- **`REQ-P71-CON04-01` (`StudioActionBar` Live Allowance Chip & Phosphor Compliance):**  
  `StudioActionBar` SHALL:
  - Watch `creatorAllowanceProvider` and render an interactive allowance chip with `Key('studio_allowance_chip')` showing `Pro Unlimited` (if `isPaidUnlimited`) or `${allowance.freeMonthlySongsRemaining}/${allowance.freeMonthlySongsLimit} Free Songs` (with low/exhausted visual cue using `AppColors.coinGold` / `AppColors.error`). Tapping opens `SubscriptionUpgradeModal.show(context)`.
  - Replace stock `const Icon(Icons.check_circle_rounded, ...)` (`#L169`) with `const PhosphorIcon(PhosphorIconsFill.checkCircle, color: AppColors.brandPrimary, size: 18)` (`STD-UIUX-001`).
- **`REQ-P71-CON04-02` (Optimistic Quota Decrement on Generation Dispatch):**  
  `GenerationPipelineNotifier.submitAndStartGeneration` (`generation_pipeline_providers.dart`) SHALL invoke `_ref.read(creatorAllowanceProvider.notifier).consumeOneSongOptimistically()` immediately after `submissionService.submitGeneration(...)` succeeds and `if (!mounted) return;` passes.
- **`REQ-P71-CON04-03` (`SubscriptionUpgradeModal` Allowance Card & Dual-Theme Tokens):**  
  `SubscriptionUpgradeModal` SHALL:
  - Watch `creatorAllowanceProvider` and embed a live Monthly Allowance status card with `Key('upgrade_modal_allowance_card')` displaying remaining songs, usage bar (`LinearProgressIndicator`), and plan tier label using `AppColors.surfaceSecondaryOf(context)`, `AppColors.borderSubtleOf(context)`, `AppColors.textPrimaryOf(context)`, and `AppColors.textSecondaryOf(context)`.
  - Replace hardcoded `color: Colors.white` (`#L304`) with `AppColors.brandContrast`.

---

## 5. Pass 2 — Stale Client Test Repairs & New Phase 71 Test Suite (`M71.4`)

- **`REQ-P71-CLI-TST-01` (`test/core/network/phase63_e2e_cloud_pipeline_test.dart#L491`):**  
  Align with Phase 65 (`REQ-P65-L2-02`) lazy stem loading: assert `stemMixerProvider.activeTrackId == completed.id`, then explicitly trigger `recordingEngine.loadFromManifest(mmo)` (or `stemMixerProvider.notifier` playback/load) before asserting `recordingEngine.hasRealStems == true` and `recordingEngine.loadedMasterUrl == expectedMasterUrl`.
- **`REQ-P71-CLI-TST-02` (`test/features/social/reel_audio_pool_and_kinetic_canvas_test.dart#L121-L143`):**  
  Align with cold-start `PlaybackStatus.paused`: verify initial `paused` state, start playback via `container.read(playerStateProvider.notifier).togglePlayPause()`, verify `playing`, call `enterReelsSession`, verify ducked `paused`, call `exitReelsSession`, verify restored `playing`.
- **`REQ-P71-CLI-TST-03` (`test/features/player/audio_source_resolver_test.dart#L55-L83`):**  
  Align URL expectations on lines `#L55`, `#L67`, and `#L82` with `AppConstants.normalizeCloudMediaUrl(...)` and `Uri.parse(AppConstants.resolveMediaBaseUrl()).scheme`.
- **`REQ-P71-CLI-TST-04` (`test/features/player/phase35_drag_dismiss_bin_test.dart#L175`):**  
  Replace obsolete Material `IconButton` type lookup on `Key('mini_player_prev')`, `Key('mini_player_next')`, and `Key('mini_player_play_pause')` with `find.byKey(...)`, `tester.getSize(...)` (`>= 44x44`), `find.descendant(..., matching: find.byType(PhosphorIcon))`, and tap verification.
- **`REQ-P71-CLI-TST-05` (`test/features/player/player_hardware_bridge_test.dart#L47-L148`):**  
  Update cold-start seed assertions at `#L47-L49` to `PlaybackStatus.paused`, `Duration.zero`, `const Duration(seconds: 24)`; materialize `container.read(playerStateProvider.notifier);` before `await handler.playTrack(_track());` at `#L86` and `#L145`.
- **`REQ-P71-CLI-TST-06` (`test/features/phase71_connectome_closure_test.dart`):**  
  Author a comprehensive unit + widget suite verifying:
  1. `HttpNotificationRepository` + `NotificationsNotifier.syncFromCloud()` merges server studio/quota alerts preserving local `isRead` and mirrors mutations cleanly.
  2. `SocialFeedPostsNotifier` executes direct HTTP for `toggleLike`, `cosignPost`, `repostPost`, `addPost` with **zero** outbox double-enqueue on success, and falls back to outbox ONLY on HTTP failure; `refreshFromCloud()` hydrates `likeCount` & `commentCount`.
  3. `ReelsCommentsNotifier.toggleCommentLike` routes `post_*` comments to `/api/explore/comments/:id/like`.
  4. `HttpSocialRepository.getClipRemixes` + `RemixLineageTreeSheet` renders merged live remote remix children.
  5. `StudioActionBar` displays `Key('studio_allowance_chip')` with zero stock `Icons.*`, `GenerationPipelineNotifier` calls `consumeOneSongOptimistically()`, and `SubscriptionUpgradeModal` renders `Key('upgrade_modal_allowance_card')`.

---

## 6. Non-Functional Requirements (`REQ-P71-NFR-*`)

- **`REQ-P71-NFR-01` (Zero Unnecessary Subrequests in `workerd`):**  
  Explore SWR caching (`12_000 ms` TTL) SHALL prevent redundant PostgREST fan-outs during rapid feed scrolling while guaranteeing cross-isolate visibility within $\le 12\text{s}$ (or $0\text{ms}$ on `force = true` / strict-fresh domains).
- **`REQ-P71-NFR-02` (Zero Raw Emojis & Authentic Tokens — `STD-UIUX-001`):**  
  Zero raw Unicode emojis or stock `Icons.*` in any touched Dart widget; all icons use `PhosphorIcon(PhosphorIcons*.*)` from `package:phosphor_icons/phosphor_icons.dart`; all adaptive surfaces use `AppColors.*Of(context)` and valid `AppTypography.*` getters.
- **`REQ-P71-NFR-03` (Offline-First & Headless Test Determinism):**  
  All new HTTP repositories SHALL guard network I/O with `_shouldSkipNetwork` so existing headless `flutter test` suites never open real sockets or hang `FakeAsync`. Widget tests SHALL use bounded `pump` loops (`<= 60s` timeout) instead of unbounded `pumpAndSettle()` when repeating animations exist.
- **`REQ-P71-NFR-04` (SafeNotifierMixin / Mounted Discipline):**  
  Every `async` method on `NotificationsNotifier`, `SocialFeedPostsNotifier`, and `GenerationPipelineNotifier` SHALL check `if (!mounted) return;` after every `await` before mutating `state`.

---

## 7. Granular Requirement-to-Test Traceability Matrix

```text
+-----------------------+-----------------------------------------------+----------------------------------------------------+
| Requirement ID        | Primary Implementation File(s)                | Verification Test / Gate                           |
+-----------------------+-----------------------------------------------+----------------------------------------------------+
| REQ-P71-SQL-01..03    | supabase/migrations/20261120000001_*.sql      | G-71-01 + phase71_worker_supabase_readthrough.test |
| REQ-P71-SWR-01..04    | edge_persistence_bridge.ts, vhunambi_db.ts,   | phase71_worker_supabase_readthrough.test.ts        |
|                       | server.ts, notification/explore/wallet/gen    | (Isolate A -> Isolate B read-through + timeout)    |
| REQ-P71-WRT-01..06    | edge_persistence_bridge.ts, vision_routes.ts, | phase71_worker_supabase_readthrough.test.ts        |
|                       | webhook_routes.ts, generation_routes.ts       | (Failure ring, atomic RPC, reel_comments, vision)  |
| REQ-P71-API-TST-01..03| test/phase67_notifications_quota.test.ts,     | npm test (27/27) & npx tsc --noEmit (0 errors)     |
|                       | package.json                                  |                                                    |
| REQ-P71-CON01-01..02  | http_notification_repository.dart,            | phase71_connectome_closure_test.dart (Group 1)     |
|                       | notifications_provider.dart                   |                                                    |
| REQ-P71-CON02-01..04  | http_explore_repository.dart,                 | phase71_connectome_closure_test.dart (Group 2)     |
|                       | explore_providers.dart, reels_comments_prov   |                                                    |
| REQ-P71-CON03-01..02  | i_social_repository.dart, http_social_repo,   | phase71_connectome_closure_test.dart (Group 3)     |
|                       | remix_lineage_provider.dart, tree_sheet.dart  |                                                    |
| REQ-P71-CON04-01..03  | studio_action_bar.dart, generation_pipeline,  | phase71_connectome_closure_test.dart (Group 4)     |
|                       | subscription_upgrade_modal.dart               |                                                    |
| REQ-P71-CLI-TST-01..05| 5 legacy test files in core/network, social,  | flutter test --no-pub --timeout=60s (100% pass)    |
|                       | and features/player                           |                                                    |
+-----------------------+-----------------------------------------------+----------------------------------------------------+
```

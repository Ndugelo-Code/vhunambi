# Phase 71 — Cloudflare Worker Supabase Persistence, `OPEN` Connectome Closure & Green Test Baseline Forensic Audit

**Document ID:** `AUDIT-P71-CLOUD-CONNECTOME-BASELINE-001`  
**Date:** 2026-11-19  
**Branch:** `fix/studio-cockpit-bugs-vh001-vh006` (post-Phase 70 completion)  
**Audit Scope:** Read-only static + diagnostic audit across `apps/vhunambi_api/src/`, `supabase/migrations/`, `docs/memory/`, `apps/vhunambi_client/lib/`, and `apps/vhunambi_client/test/`.  
**Related Specs & Memory:** [`docs/memory/CORTEX_INDEX.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/memory/CORTEX_INDEX.md) · [`docs/audits/VHUNAMBI_REPO_TOPOLOGY_AND_MEMORY_READINESS_AUDIT.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/audits/VHUNAMBI_REPO_TOPOLOGY_AND_MEMORY_READINESS_AUDIT.md) · [`docs/phases/phase_67_notifications_center_two_pass_overhaul/`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_67_notifications_center_two_pass_overhaul/memory.md) · [`docs/phases/phase_69_kinetic_post_focus_and_threading_overhaul/`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_69_kinetic_post_focus_and_threading_overhaul/memory.md) · [`docs/phases/phase_70_song_cockpit_and_visitor_profile_glass_overhaul/`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_70_song_cockpit_and_visitor_profile_glass_overhaul/memory.md)

---

## 1. Executive Summary & Volatility Risk Matrix

Following Phases 67–70, Vhunambi's client UI loop (`Splash -> Home Main Room -> Notifications -> Explore Kinetic Posts -> Song Cockpit -> Visitor Profile`) is visually unified and Phase 70 promoted `EP-P58-MKT-VERIFY-PRODUCER` to `CONNECTED_EXTENSIBLE`. Inspecting the live server, database, and client repositories line-by-line reveals three structural blockers preventing true multi-user cloud durability and a 100% green CI baseline:

1. **Cloudflare Worker Isolate Desync & Silent Write-Through Loss (`workerd`):** Contrary to the initial assumption that non-auth Worker routes never talk to Supabase, [`EdgeIsolateDatabaseEngine`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/db/edge_persistence_bridge.ts#L384) *already* wires [`ensureColdStartHydrated`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/db/edge_persistence_bridge.ts#L550-L1086) (21 tables) and 27 `mirrorWriteThrough(...)` PostgREST calls. However, **five critical concurrency and schema flaws** still cause multi-user data invisibility and silent data loss across Cloudflare Worker isolates:
   - **Single-Shot Cold-Start Lock (`coldStartHydrated = true`):** Every warm Worker isolate returns early at `edge_persistence_bridge.ts#L551` and never re-queries Supabase when another isolate mutates `kinetic_posts`, `reel_comments`, `notifications`, `creator_quotas`, `explore_tracks`, or `wallet_ledger`. Worse, a 4.5s timeout (`#L610`) or partial `.catch(() => [])` sets `coldStartHydrated = true` in `finally` (`#L1079`), permanently pinning that isolate to incomplete/seed data.
   - **Swallowed Write Failures (`.catch(() => {})`):** `mirrorWriteThrough` (`#L502`) drops PostgREST/RPC errors without logging, telemetry, or retry, masking constraint or column mismatches.
   - **Missing Write-Throughs & Hydration Projection Drops:** `POST /api/sync/mutations` track `like` (`#L1777-L1780`) mutates RAM only (`exploreTracks`) with zero `mirrorWriteThrough`; `reel_comments` cold-start hydration (`#L780-L809`) + `mapReelCommentRow` (`#L5524`) drop `likes_count`, `username`, `display_name`, `avatar_url`, and `is_creator` when absent from `data_json`; `explore_tracks` Postgres DDL lacks `mood`, `language`, `discovery_stage`, and `data_json`; `vision_routes.ts` keeps `visionMetaFallbackStore` in module RAM (`#L93`).
   - **Un-awaited Quota & Multi-Isolate Drift:** `consumeFreeMonthlySongQuota` (`#L5861-L5890`) increments RAM counters and mirrors async (`upsertRow('creator_quotas', ...)`) without awaiting or reading fresh Supabase state, letting parallel isolates reset or double-spend the `10 Free Monthly Songs` quota.
   - **Unbounded 21-Table Cold-Start Fan-Out:** Pulling 21 full tables (`limit=200..1000`) on first request (`server.ts#L56`) silently drops older creator records as tables grow and risks exceeding the `4500ms` cold-start ceiling.
2. **High-Value `OPEN` Connectome Endpoints With Zero Client Callers:** Out of 8 `OPEN` endpoints reported by `query_connectome.mjs --open`, 4 map directly onto the active user journey:
   - `EP-P67-NOTIF-API` (`/api/notifications*` — `0` HTTP callers in `features/notifications/`)
   - `EP-P69-POST-COSIGN-REPOST-HTTP` (`/api/explore/posts/:id/cosign`, `/repost`, `/comments/:id/like`, `/explore/feed` — bypassed by `ExplorePostsNotifier` & `ReelsCommentsNotifier`)
   - `EP-P37-REMIX-TREE-API` (`GET /api/social/clips/:id/remixes` — `remix_lineage_provider.dart` returns hardcoded `kSeedMakhadziRemixTree`)
   - `EP-P68-CREATOR-ALLOWANCE` Extension (`creatorAllowanceProvider` only mounted in `MainRoomHeader`; `StudioActionBar`, `GenerationPipelineNotifier`, and `SubscriptionUpgradeModal` ignore it, and `consumeOneSongOptimistically()` has `0` callers).
3. **Stale Client & API Test Hygiene:** Direct diagnostic runs across `test/core/network/`, `test/features/player/`, `test/features/studio/`, `test/features/track/`, `test/features/profile/`, and `reel_audio_pool_and_kinetic_canvas_test.dart` show `track/` (`5/5` files), `profile/` (`11/11` files), and `studio/` (`38/38` files) are already `100%` green after Phase 70, leaving **5 failing client test files (9 failing test cases)** concentrated in `core/network`, `player`, and `social/reel_audio_pool_and_kinetic_canvas_test.dart`, plus **2 unregistered/misplaced API test files** (`test/phase65_foundation_resilience.test.ts` omitted from `package.json`, `src/phase67_notifications_quota.test.ts` misplaced in `src/`).

### Executive Volatility, Connectome & Test Severity Matrix

| ID | Sev | Area | Symptom / Defect | Primary Root Cause & File/Line Proof |
| :--- | :---: | :--- | :--- | :--- |
| **VLT-01** | `P0` | Worker Reads | User A's posts, replies, notifications & quota deductions invisible to User B on another Worker isolate; partial cold starts stick forever | [`server.ts#L52-L57`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/server.ts#L52-L57) & [`edge_persistence_bridge.ts#L550-L612`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/db/edge_persistence_bridge.ts#L550-L612), [`#L1079`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/db/edge_persistence_bridge.ts#L1079) set `coldStartHydrated = true` permanently after one 21-table fan-out |
| **VLT-02** | `P0` | Quota / Writes | Concurrent generations on separate isolates bypass 10-song limit; Supabase HTTP errors disappear silently | [`edge_persistence_bridge.ts#L493-L514`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/db/edge_persistence_bridge.ts#L493-L514) swallows `.catch(() => {})`; [`#L5861-L5890`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/db/edge_persistence_bridge.ts#L5861-L5890) mutates RAM quota and mirrors non-atomically |
| **VLT-03** | `P1` | Sync & Schema | `sync/mutations` track `like` lost on restart; `reel_comments` loses `likes_count`/author fields; `explore_tracks` drops `mood`/`language`/`discovery_stage` | [`edge_persistence_bridge.ts#L1777-L1780`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/db/edge_persistence_bridge.ts#L1777-L1780) (no write-through); [`#L780-L809`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/db/edge_persistence_bridge.ts#L780-L809) & [`#L5524`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/db/edge_persistence_bridge.ts#L5524); [`20261110000001#L110-L129`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/supabase/migrations/20261110000001_phase62_hybrid_cloud_schema.sql#L110-L129) |
| **VLT-04** | `P1` | Vision Metadata | `/v1/vision/:id` job prompt/seed metadata lost on Worker recycle | [`vision_routes.ts#L93`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/routes/vision_routes.ts#L93) stores `VisionJobMeta` in module-scoped `Map` only |
| **CON-01** | `P1` | `EP-P67-NOTIF-API` | Notifications never sync across devices or surface server-generated studio/quota alerts | [`notification_repository.dart#L15-L300`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/notifications/data/repositories/notification_repository.dart#L15-L300) & [`notifications_provider.dart#L14-L166`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/notifications/presentation/providers/notifications_provider.dart#L14-L166) are Hive-only |
| **CON-02** | `P1` | `EP-P69-POST-COSIGN-REPOST-HTTP` | Feed pagination, post like/cosign/repost, and Explore comment likes never invoke direct HTTP endpoints | [`http_explore_repository.dart#L62-L370`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/explore/data/repositories/http_explore_repository.dart#L62-L370) omits `/feed`, `/cosign`, `/repost`, `/comments/:id/like`; [`explore_providers.dart#L869-L1029`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/explore/presentation/providers/explore_providers.dart#L869-L1029) queues outbox only |
| **CON-03** | `P1` | `EP-P37-REMIX-TREE-API` | `RemixLineageTreeSheet` always displays static Makhadzi mock or 1-node fallback | [`remix_lineage_provider.dart#L248-L272`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/social/presentation/providers/remix_lineage_provider.dart#L248-L272) never queries `/api/social/clips/:id/remixes` |
| **CON-04** | `P2` | `EP-P68-CREATOR-ALLOWANCE` | Studio Compose & Upgrade Sheet do not show or decrement monthly free song quota; `StudioActionBar` has stock `Icons.*` | [`studio_action_bar.dart#L169-L215`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/studio/presentation/widgets/studio_action_bar.dart#L169-L215), [`generation_pipeline_providers.dart#L193-L234`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/studio/presentation/providers/generation_pipeline_providers.dart#L193-L234), [`subscription_upgrade_modal.dart#L14-L125`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/home/presentation/widgets/subscription_upgrade_modal.dart#L14-L125) |
| **TST-01** | `P1` | Client Baseline | 5 client test files (9 cases) fail due to post-Phase 63/64/65 behavioral refactors | Legacy assertions in `phase63_e2e_cloud_pipeline_test.dart`, `reel_audio_pool_and_kinetic_canvas_test.dart`, `audio_source_resolver_test.dart`, `phase35_drag_dismiss_bin_test.dart`, `player_hardware_bridge_test.dart` |
| **TST-02** | `P2` | API Baseline | 2 API test suites excluded from `npm test`; 1 placed inside `src/` | [`package.json#L10`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/package.json#L10) omits `phase65_foundation_resilience.test.ts` & [`src/phase67_notifications_quota.test.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/phase67_notifications_quota.test.ts#L1-L178) |

### End-to-End Breakpoint & Isolation Topology

```text
  [Mobile Device A (User 1)]                          [Mobile Device B (User 2)]
        |                                                       |
        | 1. POST /api/explore/posts                            | 2. GET /api/explore
        v                                                       v
  [Cloudflare Isolate #1 (warm)]                      [Cloudflare Isolate #2 (warm)]
   |-- coldStartHydrated === true (skip fetch!)        |-- coldStartHydrated === true (SKIP FETCH!)
   |-- updates local RAM Map                           |-- returns stale RAM Map (misses User 1 post!)
   |-- mirrorWriteThrough (waitUntil, .catch(()=>{}))
        v
  [Supabase Postgres]  <--- auth_routes.ts ONLY reads/writes directly on cache miss!
                            All other domain routes read stale isolate RAM after cold start.
```

---

## 2. Pillar 1 — Cloudflare Worker Isolate vs. Supabase PostgreSQL Forensic Audit

### 2.1 Domain Table Parity & Persistence Census (`apps/vhunambi_api/src/db/` vs. `supabase/migrations/*.sql`)

| Domain Table / Store | Worker Read Source (`workerd`) | Worker Write Behavior (`edge_persistence_bridge.ts`) | Verified Schema / Projection Gaps |
| :--- | :--- | :--- | :--- |
| **`users` & `creators`** | `auth_routes.ts` queries Supabase directly on cache miss ([`#L207-L234`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/routes/auth_routes.ts#L207-L234)) + cold start ([`#L588-L589`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/db/edge_persistence_bridge.ts#L588-L589)) | `auth_routes` awaits `mirrorBundleToSupabase` (`#L146-L195`); `ensureCreatorRowInSupabase` best-effort FK guard | Seed creators exist, but non-auth writes to FK-constrained tables (`wallet_ledger`, `bank_accounts`, `payment_topups`) fail silently if creator upsert races or fails inside `mirrorWriteThrough` |
| **`auth_sessions`** | Direct Supabase fallback on refresh ([`auth_routes.ts#L237-L273`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/routes/auth_routes.ts#L237-L273)) & JWT verification ([`auth_middleware.ts#L107`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/middleware/auth_middleware.ts#L107)) | Direct `driver.upsertRow`/`patchRows` in `auth_routes.ts` | Cold start pulls `limit=300` unrevoked rows; works best because `auth_routes` bypasses single-shot cache on misses |
| **`kinetic_posts`** | Stale warm RAM Map after single cold-start `limit=200` pull (`#L592`) | `upsertKineticPost` (`#L2696`), `cosignPost` (`#L2579`), `likeKineticPost` (`#L2740`), `repostPost` (`#L2766`), `addKineticPostComment` (`#L2896`) | Phase 69 `20261118000001` added `like_count` & `comment_count`; if `SELECT` fails on un-migrated DB, `.catch(() => [])` seals empty Map forever; warm isolates never see new posts from other isolates |
| **`reel_comments`** | Stale warm RAM Map (`limit=400`, `#L594`) | `insertReelComment` (`#L5481`) + `likeCommentById` (`#L2906`) | **3 bugs:** (1) [`hydrateFromCloudDriver#L780-L809`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/db/edge_persistence_bridge.ts#L780-L809) omits `rc.likes_count`, `rc.username`, `rc.display_name`, `rc.avatar_url`, `rc.is_creator`; (2) [`mapReelCommentRow#L5524`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/db/edge_persistence_bridge.ts#L5524) ignores `r.likes_count`; (3) Cross-isolate comment replies stay invisible to warm isolates |
| **`notifications`** | Stale warm RAM Map (`limit=500`, `#L607`) | `upsertNotification` (`#L5743`), `markNotificationRead` (`#L5775`), `markAllNotificationsRead` (`#L5795`), `deleteNotification` (`#L5813`) | `20261116000001#L4-L18` columns match, **but** server-side notifications generated on Isolate A (`notif_gen_*`, `notif_quota_low_*`) are unseen on Isolate B when polled by `GET /api/notifications` |
| **`creator_quotas`** | Stale warm RAM Map (`limit=300`, `#L608`) | `getCreatorQuota` (`#L5842`) & `consumeFreeMonthlySongQuota` (`#L5875`) | **Critical (`P0`):** Read-modify-write happens on local isolate RAM without Supabase `SELECT` refresh or atomic SQL increment (`UPDATE ... SET free_monthly_songs_used = LEAST(limit, used + 1)`), allowing free-tier bypass across isolates |
| **`explore_tracks`** | Stale warm RAM Map (`limit=200`, `#L591`) | `upsertExploreTrack` (`#L2474`) | **3 bugs:** (1) `20261110000001#L110-L129` lacks `mood`, `language`, `discovery_stage`, `data_json` (`20261119000001` added `mood_id`, `description`, `allow_open_stems_remix`); (2) [`applyMutationsBatch#L1777-L1780`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/db/edge_persistence_bridge.ts#L1777-L1780) track `like` has **zero** `mirrorWriteThrough`; (3) `created_at` absent in PG `explore_tracks` table |
| **`user_library_sync`** | Stale warm RAM Map (`limit=500`, `#L598`) | `syncLibraryTracks` (`#L3095`), `deleteLibraryTrack` (`#L2968`) | Composite PK `(id, creator_id)` matches `onConflict: 'id,creator_id'`, **but** `user_library_sync` PG DDL (`20261110000001#L261-L283`) lacks `item_type` & `created_at` columns that SQLite stores; `normalizeLibrarySyncRow#L185` defaults to `'track'` |
| **`marketplace_assets` & `beat_licenses`** | Stale warm RAM Map (`limit=200` / `300`, `#L595-L596`) | `upsertMarketplaceBeat` (`#L5220`), `deleteMarketplaceBeat` (`#L5324`), `recordBeatLicense` (`#L4410` RPC + `#L4429` fallback) | Exclusive buyout race across two warm isolates can pass isolate Map check before `record_beat_license_atomic` RPC rejects on PG; fallback `beat_licenses` upsert skips ledger credit if RPC throws |
| **`social_interactions`** | Stale warm `Set<string>` (`limit=1000`, `#L602`) | `setSocialInteraction` (`#L5565-L5583`) | Un-scoped `limit=1000` truncates follow/like state globally once >1,000 interactions exist in Postgres |
| **`wallet_ledger`, `bank_accounts`, `payment_topups`** | Stale warm RAM Map (`#L603-L605`) | `sendCulturalTipAtomic` (`#L3683`), `requestPayout` (`#L4124`), `createPayFastCheckout` (`#L3779`), `settlePayFastTopup` (`#L3906`, `#L3916`), `topupWallet` (`#L3970`) | Multi-isolate wallet spend (`tip` vs `license` vs `payout`) relies on async `mirrorWriteThrough` RPCs **after** returning HTTP 200 based on potentially stale isolate RAM |
| **`playlists` & `published_clips`** | Stale warm RAM Map (`limit=200`, `#L593`, `#L599`) | `upsertPlaylist`/`sharePlaylist` (`#L3269, #L3358`), `upsertPublishedClip` (`#L5382`) | `published_clips` & `playlists` match base PG columns; cross-isolate reads still stale until isolate recycles |
| **`generation_jobs`, `voice_clones`, `sound_signatures`** | Stale warm RAM Map (`limit=200`, `#L597, #L600, #L601`) | `upsertGenerationJob` (`#L5116`), `upsertVoiceClone` (`#L5642`), `upsertSoundSignature` (`#L5668`) | Async RunPod webhook (`POST /v1/webhooks/ace-step`) often lands on a *different* Worker isolate than the client's polling `GET /v1/generations/:id` request; if the polling isolate already hydrated earlier, it never sees the completed job in Supabase! |
| **`visionMetaFallbackStore` & `inMemoryR2Objects`** | Pure module-level RAM `Map`s (`vision_routes.ts#L93`, `r2_storage.ts#L128`) | Zero Postgres write-through | Vision prompt/seed/resolution metadata in [`vision_routes.ts#L194-L203`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/routes/vision_routes.ts#L194-L203) is volatile on isolate recycle |

### 2.2 Supabase Read-Through / Write-Through Target Architecture Plan

To guarantee multi-user consistency across Worker isolates **without** blowing Cloudflare `workerd` CPU/subrequest limits:

```text
  Request -> Hono Route (passes Context `c` or per-tenant creatorId)
               |
               +--> [Auth / Wallet / Quotas / Generation Poll / Notifications] (Strict Fresh Read-Through)
               |      1. Direct targeted PostgREST `selectRows` filtered by `creator_id`/`id` (when Supabase configured)
               |      2. Hydrate into EdgeIsolate cache on hit; execute atomic Supabase RPC (`await`, not swallowed)
               |
               +--> [Explore Feed / Tracks / Clips / Comments] (Tenant/Feed Stale-While-Revalidate Cache, TTL <= 15s)
               |      1. Replace global 21-table cold-start nuke (`#L586-L612`) with per-domain lazy TTL hydration
               |      2. `coldStartHydrated` tracked PER-DOMAIN with `hydratedAtMs`, never sealed permanently on timeout/error
               |
               +--> [Durable Write-Through]
                      1. `await` critical mutations (`quotas`, `wallet`, `generation_jobs`, `explore`, `notifications`) OR surface error telemetry in `mirrorWriteThrough` (structured `console.error` + pending retry ring, never silent `.catch(()=>{})`)
                      2. Atomic RPC `consume_free_monthly_song_quota_atomic(p_user_id)` in Postgres
```

Concrete backend schema & engine additions required in **Pass 1 (`M71.1`)**:
1. **Migration `supabase/migrations/20261120000001_phase71_schema_parity_and_rpcs.sql`:**
   - Add missing parity columns to `public.explore_tracks`: `mood TEXT NOT NULL DEFAULT 'Vibrant'`, `language TEXT NOT NULL DEFAULT 'isiZulu'`, `discovery_stage TEXT NOT NULL DEFAULT 'freshCrate'`, `data_json JSONB NOT NULL DEFAULT '{}'::jsonb`, `created_at BIGINT`.
   - Add `item_type TEXT NOT NULL DEFAULT 'track'` and `created_at BIGINT` to `public.user_library_sync`.
   - Add atomic `public.consume_free_monthly_song_quota_atomic(p_user_id TEXT)` PL/pgSQL RPC (resets expired 30-day cycle `now() >= cycle_reset_at`, locks row `FOR UPDATE`, increments `free_monthly_songs_used` safely, returns `CreatorQuotaRecord` JSON).
2. **`EdgeIsolateDatabaseEngine` & Routes Overhaul (`edge_persistence_bridge.ts`, `vhunambi_db.ts`, `server.ts`, `vision_routes.ts`):**
   - Replace the monolithic 21-table cold-start wall in `server.ts#L56` / `edge_persistence_bridge.ts#L550-L612` with **domain-scoped read-through helpers** (`syncNotificationsFromCloud(userId)`, `syncCreatorQuotaFromCloud(userId)`, `syncExploreFromCloud()`, `syncGenerationJobFromCloud(genId)`, `syncCreatorWalletFromCloud(creatorId)`) using a short `10–15s` SWR freshness window + immediate bypass on `miss`!
   - Fix `applyMutationsBatch` track `like` (`#L1777-L1780`) to call `mirrorWriteThrough(patchRows('explore_tracks', ...))`.
   - Fix `reel_comments` hydration (`#L780-L809`) & `mapReelCommentRow` (`#L5524`) to preserve `likes_count`, `username`, `display_name`, `avatar_url`, and `is_creator`.
   - Persist `vision_routes.ts` prompt/resolution metadata inside `generation_jobs.manifest_json` instead of volatile `visionMetaFallbackStore` (`#L93`).

---

## 3. Pillar 2 — `OPEN` Connectome Endpoint Closure Map (`apps/vhunambi_client/`)

### 3.1 `EP-P67-NOTIF-API`: Bidirectional Cloud Notifications (`GET/POST /api/notifications`, `PATCH /:id/read`, `POST /mark-all-read`, `DELETE /:id`)
- **Current Break:**
  - Backend [`notification_routes.ts#L35-L108`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/routes/notification_routes.ts#L35-L108) is fully implemented and authenticated (`resolveEffectiveCreatorId`).
  - Client [`NotificationRepository`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/notifications/data/repositories/notification_repository.dart#L15-L300) only reads/writes local Hive box `notifications_v1` (with in-memory map fallback in tests). [`NotificationsNotifier`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/notifications/presentation/providers/notifications_provider.dart#L14-L166) has zero HTTP dependency, so backend-emitted studio/low-quota notifications (`generation_routes.ts#L135-L175`) never reach the phone and read/delete state never syncs across devices.
- **Closure Design (`M71.3`):**
  1. Add `HttpNotificationRepository` (under `features/notifications/data/repositories/http_notification_repository.dart`, using `SovereignApiClient` or auth-injected `Dio` + `_shouldSkipNetwork` test guard):
     - `fetchNotifications()` -> `GET /api/notifications`
     - `upsertNotification(NotificationEntity)` -> `POST /api/notifications` (mapping `message` + `body`)
     - `markRead(String id)` -> `PATCH /api/notifications/$id/read`
     - `markAllRead()` -> `POST /api/notifications/mark-all-read`
     - `deleteNotification(String id)` -> `DELETE /api/notifications/$id`
  2. Wire `HttpNotificationRepository` into `notificationsProvider` (`notifications_provider.dart#L169-L175`): `hydrateFromStorage()` reads Hive immediately for instant render, then fetches `/api/notifications`, merges preserving local `isRead` & new items, pushes local-only notifications if any, and mirrors `addNotification` / `markAsRead` / `markAllAsRead` / `removeNotification` via non-blocking cloud calls (preserving offline Hive resilience).
  3. Update `CONNECTOME_GRAPH.json` (`EP-P67-NOTIF-API` -> `CONNECTED_EXTENSIBLE`).

### 3.2 `EP-P69-POST-COSIGN-REPOST-HTTP`: Direct Explore Cloud Feedback (`/explore/feed`, `/posts/:id/cosign`, `/posts/:id/repost`, `/comments/:id/like`)
- **Current Break:**
  - [`explore_routes.ts#L93-L142`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/routes/explore_routes.ts#L93-L142) exposes `GET /api/explore/feed`, `POST /api/explore/posts/:id/cosign`, `POST /api/explore/posts/:id/repost`, and [`#L236-L244`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/routes/explore_routes.ts#L236-L244) exposes `POST /api/explore/comments/:id/like`.
  - [`HttpExploreRepository`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/explore/data/repositories/http_explore_repository.dart#L62-L370) defines none of those 4 methods.
  - [`ExplorePostsNotifier`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/explore/presentation/providers/explore_providers.dart#L814-L1029) calls `_outbox?.enqueue(...)` only for `toggleLike`, `addPost`, `repostPost`, and `cosignPost` (never invoking `repository?.togglePostLike`, `cosignPost`, `repostPost`, or `publishPost` directly, and `refreshFromCloud()` skips updating `likeCount`/`commentCount` at `#L828-L833`).
  - [`ReelsCommentsNotifier.toggleCommentLike`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/social/presentation/providers/reels_comments_provider.dart#L394-L415) always calls `_repo?.toggleLikeComment` (`/api/social/comments/:id/like`) even when `clipId` is a Kinetic Post (`post_*` / `kpost_*`) instead of calling `exploreRepositoryProvider.likeComment(commentId)` (`/api/explore/comments/:id/like`).
- **Closure Design (`M71.3`):**
  1. Add `fetchExploreFeed({stage, genre, limit, offset})`, `cosignPost(postId, {creatorId})`, `repostPost(postId, {repost})`, and `likeComment(commentId)` to `HttpExploreRepository`.
  2. Update `ExplorePostsNotifier` (`toggleLike`, `repostPost`, `cosignPost`, `addPost`) to fire direct HTTP calls optimistically via `repository` (reconciling returned `cosignCount` / `repostCount` / `likeCount` / `discoveryStage`), falling back to `EdgeSyncCoordinator` outbox ONLY when offline/HTTP fails (preventing double-increment bugs!).
  3. Update `ExplorePostsNotifier.refreshFromCloud` to also hydrate `likeCount` & `commentCount` (`#L828-L834`), and pass `isKineticPost` in `ReelsCommentsNotifier.toggleCommentLike` so Kinetic Post comment likes hit `/api/explore/comments/:id/like`.

### 3.3 `EP-P37-REMIX-TREE-API`: Live Genealogical Remix Graph (`GET /api/social/clips/:id/remixes`)
- **Current Break:**
  - Backend [`social_routes.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/routes/social_routes.ts) + [`getClipRemixes`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/modules/social/social_service.ts#L828-L838) serve live remix children from `published_clips`.
  - Client [`ISocialRepository`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/social/domain/repositories/i_social_repository.dart#L9-L94) & `HttpSocialRepository` have no `getClipRemixes(String clipId)` method, and [`remixLineageTreeProvider`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/social/presentation/providers/remix_lineage_provider.dart#L248-L272) synchronously returns hardcoded `kSeedMakhadziRemixTree` or a single-node `'Original Track'`.
- **Closure Design (`M71.3`):**
  1. Add `Future<List<PublishedClip>> getClipRemixes(String clipId)` to `ISocialRepository` and `HttpSocialRepository` (`GET $_baseUrl/social/clips/$clipId/remixes` with `_shouldSkipNetwork` graceful empty fallback).
  2. Upgrade [`remix_lineage_provider.dart`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/social/presentation/providers/remix_lineage_provider.dart#L248-L272) with `remixLineageRemoteChildrenProvider` (`FutureProvider.family`) consuming `socialRepositoryProvider.getClipRemixes(id)` and merging remote children onto the resolved root node cleanly inside `RemixLineageTreeSheet` (keeping synchronous fallback so existing widget tests stay 100% green).

### 3.4 `EP-P68-CREATOR-ALLOWANCE` Extension to Studio & Upgrade Sheet
- **Current Break:**
  - `creatorAllowanceProvider` is read solely in [`main_room_header.dart#L38`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/home/presentation/widgets/main_room_header.dart#L38); `consumeOneSongOptimistically()` ([`creator_allowance_provider.dart#L139`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/home/presentation/providers/creator_allowance_provider.dart#L139)) has **0 callers**.
  - [`StudioActionBar`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/studio/presentation/widgets/studio_action_bar.dart#L23-L234) shows no monthly free-song counter, does not guard or prompt upgrade cleanly if exhausted (`freeMonthlySongsRemaining <= 0` when free tier), and still contains stock `const Icon(Icons.check_circle_rounded)` (`#L169`) instead of `PhosphorIcon` (`STD-UIUX-001`).
  - [`GenerationPipelineNotifier.submitAndStartGeneration`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/studio/presentation/providers/generation_pipeline_providers.dart#L193-L234) never invokes `creatorAllowanceProvider.notifier.consumeOneSongOptimistically()`.
  - [`SubscriptionUpgradeModal`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/home/presentation/widgets/subscription_upgrade_modal.dart#L27-L124) does not display the user's current `freeMonthlySongsRemaining / freeMonthlySongsLimit` allowance banner (and also has hardcoded `color: Colors.white` at `#L304`).
- **Closure Design (`M71.3`):**
  1. Surface compact allowance chip (`$freeMonthlySongsRemaining / $freeMonthlySongsLimit Free` or `Pro Unlimited`) in `StudioActionBar` (tapping opens `SubscriptionUpgradeModal`) + replace `Icons.check_circle_rounded` (`#L169`) with `PhosphorIconsFill.checkCircle`.
  2. Call `creatorAllowanceProvider.notifier.consumeOneSongOptimistically()` in `GenerationPipelineNotifier.submitAndStartGeneration` right after `submitGeneration(...)` succeeds (`#L210`).
  3. Embed an Allowance Summary Card inside `SubscriptionUpgradeModal` watching `creatorAllowanceProvider`.

---

## 4. Pillar 3 — Test Baseline Hygiene Audit (`apps/vhunambi_api/` & `apps/vhunambi_client/`)

### 4.1 Backend Test Hygiene (`apps/vhunambi_api/`)
1. **Misplaced Test in `src/`:** [`apps/vhunambi_api/src/phase67_notifications_quota.test.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/phase67_notifications_quota.test.ts#L1-L178) lives inside `src/` (matched by [`tsconfig.json#L15`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/tsconfig.json#L15) `"include": ["src/**/*"]`), meaning `tsc` compiles test code into production `dist/`, AND it is missing from [`package.json#L10`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/package.json#L10). Note also that it uses `node:test` (`describe`, `it`) — convert or run with `tsx --test` once moved to `test/phase67_notifications_quota.test.ts`!
2. **Omitted Resilience Suite:** [`apps/vhunambi_api/test/phase65_foundation_resilience.test.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/test/phase65_foundation_resilience.test.ts#L1-L89) is valid and standalone (`runPhase65Tests()`), but omitted from `package.json#L10`.
- **Repair:** Move `src/phase67_notifications_quota.test.ts` $\to$ `test/phase67_notifications_quota.test.ts` (update relative imports `./` $\to$ `../src/`), convert `describe`/`it` to top-level `async` assertions matching the other 24 `test/*.test.ts` files (or invoke `tsx --test`), and append both `phase65_foundation_resilience.test.ts` and `phase67_notifications_quota.test.ts` to `package.json` `test` script (`26/26` total).

### 4.2 Client Pre-Existing Failure Census (Verified by Direct Suite Execution)

Sequential `flutter test --no-pub --reporter=compact --timeout=45s` runs across `test/core/network/` (`6` files), `test/features/player/` (`21` files), `test/features/studio/` (`38` files), `test/features/social/reel_audio_pool_and_kinetic_canvas_test.dart` (`1` file), plus Phase 70's verified `test/features/track/` (`5` files) and `test/features/profile/` (`11` files) confirmed that `track/`, `profile/`, and `studio/` are **100% passing today**, narrowing all active pre-existing failures to **5 files (9 test cases)**:

| Failing Test File | Failing Count | Exact Failing Line(s) & Exception | Verified Root Cause & Exact Fix |
| :--- | :---: | :--- | :--- |
| [`test/core/network/phase63_e2e_cloud_pipeline_test.dart`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/test/core/network/phase63_e2e_cloud_pipeline_test.dart#L491) | `1` (`+8 -1`) | `#L491`: `expect(recordingEngine.hasRealStems, isTrue)` $\to$ `false` | Phase 65 (`REQ-P65-L2-02`) intentionally removed eager `multiStemAudioEngineProvider.loadFromManifest` from [`generation_pipeline_providers.dart#L469-L471`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/studio/presentation/providers/generation_pipeline_providers.dart#L469-L471) so stems lazy-load when opening `StemMixerDeck`. Update test to assert `stemMixerProvider` hydrated + `recordingEngine` only loads once `StemMixerNotifier` / `MultiStemAudioEngine` is explicitly loaded! |
| [`test/features/social/reel_audio_pool_and_kinetic_canvas_test.dart`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/test/features/social/reel_audio_pool_and_kinetic_canvas_test.dart#L121-L143) | `1` (`+3 -1`) | `#L121`: `Expected: playing, Actual: paused` | [`player_provider.dart#L79`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/player/presentation/providers/player_provider.dart#L79) now initializes `PlaybackStatus.paused` on cold boot so audio never auto-blasts. Update test to start playback via `togglePlayPause()` / `playTrack(...)` before `enterReelsSession(...)`, then verify pause + restore on exit. |
| [`test/features/player/audio_source_resolver_test.dart`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/test/features/player/audio_source_resolver_test.dart#L55-L83) | `3` (`+6 -3`) | `#L55`, `#L67`, `#L82`: Expected `https://vhunambi.com/audio/...`, Actual `http://10.0.2.2:3000/r2/audio/...` | [`audio_source_resolver.dart#L147`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/player/data/services/audio_source_resolver.dart#L147) calls [`AppConstants.normalizeCloudMediaUrl`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/core/constants/app_constants.dart#L89-L113), which rewrites legacy `vhunambi.com` / `/r2/` URLs to `AppConstants.resolveMediaBaseUrl()`. Realign test expectations to `AppConstants.normalizeCloudMediaUrl(...)` / `Uri.parse(AppConstants.resolveMediaBaseUrl()).scheme`. |
| [`test/features/player/phase35_drag_dismiss_bin_test.dart`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/test/features/player/phase35_drag_dismiss_bin_test.dart#L175) | `1` (`+3 -1`) | `#L175`: `Bad element / TypeError` looking up `IconButton` on `Key('mini_player_prev')` | [`mobile_mini_player.dart#L222-L274`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/player/presentation/widgets/mobile_mini_player.dart#L222-L274) refactored skip buttons to `_SoftIconButton` (`GestureDetector` + `Container` with `12px` rounded border + `PhosphorIcon`), not Material `IconButton`. Update test to verify `find.byKey(...)`, `44x44` hit size / `GestureDetector` tap, and `PhosphorIcon` presence. |
| [`test/features/player/player_hardware_bridge_test.dart`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/test/features/player/player_hardware_bridge_test.dart#L47-L148) | `3` (`+5 -3`) | `#L47` (`paused` vs `playing`, `0:00` vs `0:13`, `0:24` vs `3:29`), `#L87`, `#L146` | **2 root causes:** (1) [`player_provider.dart#L79-L81`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/player/presentation/providers/player_provider.dart#L79-L81) updated cold-start seed to `PlaybackStatus.paused`, `Duration.zero`, `24s`; (2) `#L86` & `#L145` invoke `await handler.playTrack(_track())` *before* materializing `container.read(playerStateProvider.notifier)`, missing the synchronous broadcast event on [`vhunambi_audio_handler.dart#L224`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/player/data/services/vhunambi_audio_handler.dart#L224). Update initial state expectations + materialize `container.read(playerStateProvider.notifier)` before calling `handler.playTrack(...)` as line `#L109` already does. |

---

## 5. Two-Pass Remediation Roadmap (`M71.1` – `M71.4`)

### Pass 1 (`M71.1` – `M71.2`): Cloudflare Worker Supabase Persistence & API Baseline (`apps/vhunambi_api` + `supabase/`)
- **Milestone `M71.1` — Postgres Schema Parity, Atomic Quotas & Worker Read/Write-Through:**
  1. Author `supabase/migrations/20261120000001_phase71_schema_parity_and_rpcs.sql` (`explore_tracks` parity columns `mood`, `language`, `discovery_stage`, `data_json`, `created_at`; `user_library_sync` `item_type`, `created_at`; `consume_free_monthly_song_quota_atomic` RPC).
  2. Replace single-shot `coldStartHydrated` lock in `EdgeIsolateDatabaseEngine` & `server.ts` with scoped per-domain SWR read-through hydration (`syncNotificationsFromCloud`, `syncCreatorQuotaFromCloud`, `syncExploreFromCloud`, `syncGenerationJobFromCloud`, `syncCreatorWalletFromCloud`), awaited critical writes + failure logging in `mirrorWriteThrough`, and `applyMutationsBatch` track-like write-through.
  3. Fix `reel_comments` hydration (`#L780-L809`) + `mapReelCommentRow` (`#L5524`) and persist Vision metadata in `generation_jobs` instead of `visionMetaFallbackStore` (`vision_routes.ts#L93`).
- **Milestone `M71.2` — API Test Baseline Closure & Cross-Isolate Simulation Tests:**
  1. Move `apps/vhunambi_api/src/phase67_notifications_quota.test.ts` $\to$ `apps/vhunambi_api/test/phase67_notifications_quota.test.ts`.
  2. Add `phase65_foundation_resilience.test.ts` & `phase67_notifications_quota.test.ts` + new `phase71_worker_supabase_readthrough.test.ts` (simulating two isolated Worker restarts sharing a mocked `SupabaseCloudDriver`) to `package.json` `npm test` (`27/27` suites).
  3. **Pass 1 Gate:** `npx tsc --noEmit` exits `0`; `npm test` (`27/27`) passes 100%.

### Pass 2 (`M71.3` – `M71.4`): Client `OPEN` Connectome Closure & 100% Green Client Baseline (`apps/vhunambi_client/`)
- **Milestone `M71.3` — Close `EP-P67-NOTIF-API`, `EP-P69-POST-COSIGN-REPOST-HTTP`, `EP-P37-REMIX-TREE-API`, and Extend `EP-P68-CREATOR-ALLOWANCE`:**
  1. Create `HttpNotificationRepository` and wire bidirectional Hive + `/api/notifications*` sync inside `NotificationsNotifier`.
  2. Add `/api/explore/feed`, `/posts/:id/cosign`, `/posts/:id/repost`, and `/comments/:id/like` callers in `HttpExploreRepository` and wire `ExplorePostsNotifier` + `ReelsCommentsNotifier.toggleCommentLike` (with offline `EdgeSyncCoordinator` fallback).
  3. Add `getClipRemixes(clipId)` to `ISocialRepository` / `HttpSocialRepository` and wire `remixLineageTreeProvider` / `RemixLineageTreeSheet` to live `/api/social/clips/:id/remixes`.
  4. Mount live allowance counter in `StudioActionBar` (and fix stock `Icons.check_circle_rounded` `#L169`) + `SubscriptionUpgradeModal`, and call `creatorAllowanceProvider.notifier.consumeOneSongOptimistically()` in `GenerationPipelineNotifier`.
- **Milestone `M71.4` — Green Baseline Repair, Full Verification & `SLEEP` Connectome Promotion:**
  1. Write unit/widget tests for all 4 newly wired endpoints (`phase71_connectome_closure_test.dart`).
  2. Repair all 5 stale client test files (`phase63_e2e_cloud_pipeline_test.dart`, `reel_audio_pool_and_kinetic_canvas_test.dart`, `audio_source_resolver_test.dart`, `phase35_drag_dismiss_bin_test.dart`, `player_hardware_bridge_test.dart`) and verify `flutter test` across the full suite + `flutter analyze --no-pub` (`0` issues).
  3. Update Phase 71 `memory.md` (`"status": "completed"`) and run `consolidate_memory.mjs` to promote `EP-P67-NOTIF-API`, `EP-P69-POST-COSIGN-REPOST-HTTP`, and `EP-P37-REMIX-TREE-API` from `OPEN` $\to$ `CONNECTED_EXTENSIBLE`.

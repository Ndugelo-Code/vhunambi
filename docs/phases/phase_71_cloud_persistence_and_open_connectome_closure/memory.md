```json vhunambi-memory
{
  "phase_id": "P71",
  "memory_key": "MEM-P71-CLOUD-SPINE-CONNECTOME-CLOSURE",
  "title": "Cloudflare Worker Supabase Read/Write-Through Durability, OPEN Connectome Closure (EP-P67, EP-P69, EP-P37, EP-P68) & 100% Green Test Baseline",
  "status": "completed",
  "completed_at": "2026-11-20",
  "predecessor_keys": [
    "MEM-P67-NOTIFICATIONS-QUOTA",
    "MEM-P68-HOME-MAIN-ROOM",
    "MEM-P69-KINETIC-POST-FOCUS",
    "MEM-P70-SONG-COCKPIT-VISITOR-PROFILE"
  ],
  "concept_hubs": [
    "sync_outbox",
    "notifications_bus",
    "social_graph",
    "quota_economy",
    "ui_surface_std"
  ],
  "consumes": [
    "EP-P67-NOTIF-API",
    "EP-P69-POST-COSIGN-REPOST-HTTP",
    "EP-P37-REMIX-TREE-API",
    "EP-P68-CREATOR-ALLOWANCE"
  ],
  "endpoints": [
    {
      "id": "EP-P71-EDGE-SWR-READTHROUGH",
      "kind": "backend_persistence",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["sync_outbox", "notifications_bus", "social_graph"],
      "spec_anchor": "docs/phases/phase_71_cloud_persistence_and_open_connectome_closure/design.md#2-overhaul-pass-1-m711-edge-swr-readwrite-through--database-parity",
      "code_anchor": "apps/vhunambi_api/src/db/edge_persistence_bridge.ts",
      "summary": "Domain-scoped SWR freshness tracker (12s TTL, never sealed on timeout/error), targeted cloud read-through helpers (syncNotificationsFromCloud, syncCreatorQuotaFromCloud, syncGenerationJobFromCloud, syncExploreFromCloud, syncCreatorWalletFromCloud), awaited critical write-throughs, and bounded 100-entry write-through failure telemetry ring.",
      "consumers": [
        "P71:notification_routes",
        "P71:wallet_routes",
        "P71:explore_routes",
        "P71:generation_routes",
        "P71:webhook_routes",
        "P71:vision_routes"
      ],
      "open_opportunities": "Adopt domain-scoped SWR sync helpers in marketplace_routes, playlist_routes, library_routes, and voice_routes for full multi-isolate durability across every Cloudflare Worker endpoint"
    },
    {
      "id": "EP-P71-ATOMIC-QUOTA-RPC",
      "kind": "sql_rpc",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["quota_economy", "sync_outbox"],
      "spec_anchor": "docs/phases/phase_71_cloud_persistence_and_open_connectome_closure/design.md#1-overhaul-pass-1-m711-postgresql-migration--atomic-quota-rpc",
      "code_anchor": "supabase/migrations/20261120000001_phase71_schema_parity_and_rpcs.sql",
      "summary": "Row-locked PL/pgSQL RPC public.consume_free_monthly_song_quota_atomic(p_user_id TEXT) with 30-day cycle rollover and FOR UPDATE serialization preventing multi-isolate double-spend of the 10 Free Monthly Songs quota.",
      "consumers": [
        "P71:EdgeIsolateDatabaseEngine.consumeFreeMonthlySongQuotaAsync",
        "P71:generation_routes"
      ],
      "open_opportunities": "Reuse for future subscription tier quota enforcement (Vision renders, Stem Separation credits) and PayFast upgrade tier unlocks"
    }
  ],
  "edges": [
    {
      "from": "apps/vhunambi_client/lib/features/notifications/data/repositories/http_notification_repository.dart",
      "relation": "CONSUMES",
      "to": "EP-P67-NOTIF-API",
      "note": "Wires bidirectional GET/POST/PATCH/DELETE /api/notifications* sync into NotificationsNotifier alongside 0ms Hive cache"
    },
    {
      "from": "apps/vhunambi_client/lib/features/explore/data/repositories/http_explore_repository.dart",
      "relation": "CONSUMES",
      "to": "EP-P69-POST-COSIGN-REPOST-HTTP",
      "note": "Adds direct HTTP callers for /explore/feed, /posts/:id/cosign, /posts/:id/repost, and /comments/:id/like with offline-only outbox fallback in SocialFeedPostsNotifier"
    },
    {
      "from": "apps/vhunambi_client/lib/features/social/data/repositories/http_social_repository.dart",
      "relation": "CONSUMES",
      "to": "EP-P37-REMIX-TREE-API",
      "note": "Calls GET /api/social/clips/:id/remixes and merges live remix children onto RemixLineageTreeSheet via remixLineageRemoteChildrenProvider"
    },
    {
      "from": "apps/vhunambi_client/lib/features/studio/presentation/widgets/studio_action_bar.dart",
      "relation": "CONSUMES",
      "to": "EP-P68-CREATOR-ALLOWANCE",
      "note": "Displays live monthly free song allowance chip (studio_allowance_chip) and pairs with GenerationPipelineNotifier optimistic decrement and SubscriptionUpgradeModal status card"
    },
    {
      "from": "apps/vhunambi_api/src/routes/generation_routes.ts",
      "relation": "CONSUMES",
      "to": "EP-P71-ATOMIC-QUOTA-RPC",
      "note": "Executes row-locked Postgres quota decrement via consumeFreeMonthlySongQuotaAsync across Cloudflare Worker isolates"
    },
    {
      "from": "apps/vhunambi_api/src/routes/webhook_routes.ts",
      "relation": "PROVIDES",
      "to": "EP-P71-EDGE-SWR-READTHROUGH",
      "note": "Awaits durable generation_jobs upsert on RunPod webhook completion so polling isolates see finished audio immediately"
    },
    {
      "from": "apps/vhunambi_client/lib/core/design_system/tokens/vhunambi_mood.dart",
      "relation": "PROVIDES",
      "to": "EP-P70-MOOD-TAXONOMY",
      "note": "Adds VhunambiMood.tryNormalize(String? raw) so filterExploreTracks matches unmapped mood chips ('Angry', 'Mysterious') literally instead of aliasing to 'uplifting'"
    }
  ],
  "breakthroughs": [
    "Replacing the monolithic 21-table coldStartHydrated=true lock with domain-scoped SWR freshness tracking (12s TTL, never marked fresh on timeout/error) eliminates silent cross-isolate staleness for notifications, Kinetic Posts, threaded comments, RunPod webhook completions, and wallets.",
    "Routing SocialFeedPostsNotifier mutations through direct HTTP first and falling back to EdgeSyncCoordinator outbox ONLY on offline/error closes EP-P69-POST-COSIGN-REPOST-HTTP with zero double-increment bugs."
  ],
  "gotchas": [
    "The live Explore posts notifier in explore_providers.dart is named SocialFeedPostsNotifier (socialFeedPostsProvider), not ExplorePostsNotifier; preserve the authentic symbol name to avoid breaking existing callers and tests.",
    "Because vhunambiDb in vhunambi_db.ts is typed as VhunambiDatabase (proxying EdgeIsolateDatabaseEngine in workerd), every new async/sync helper added to EdgeIsolateDatabaseEngine must also have a matching method on VhunambiDatabase for tsc --noEmit parity.",
    "Postgres explore_tracks uses likes_count (plural) while EdgeIsolateDatabaseEngine RAM rows use like_count (singular); always patch likes_count in PostgREST write-throughs.",
    "applyMutationsBatch previously ignored m.payload?.trackId and m.entityId when deriving entityId; include both so track like outbox syncs resolve and mirror to Supabase.",
    "GenerationPipelineNotifier.submitAndStartGeneration returns early when socket is! GenerationSocketService (test harness); invoke consumeOneSongOptimistically() in both the fake-socket and production-socket branches.",
    "VhunambiMood.normalize falls back to 'uplifting' for unrecognized strings; filterExploreTracks must call VhunambiMood.tryNormalize so unmapped exploreMoodCatalog chips ('Angry', 'Mysterious') return exact literal matches instead of uplifting tracks.",
    "Every new Supabase public table or SECURITY DEFINER RPC must enable RLS (ENABLE ROW LEVEL SECURITY), pin SET search_path = public, pg_temp, and restrict server-only RPC EXECUTE grants to service_role (verified via supabase_mcp get_advisors). Note: 3 Phase 62 RPCs (execute_atomic_payout, record_beat_license_atomic, send_cultural_tip_atomic) still appear in security advisors for future hardening.",
    "Always apply pending Supabase Cloud migrations via supabase_mcp BEFORE deploying vhunambi-api to Cloudflare Workers (ensureColdStartHydrated queries synced tables in Promise.all and selectRows throws on 404 PGRST205).",
    "On Windows PowerShell in this workspace, npx wrangler and npx supabase can hang; invoke apps/vhunambi_api/node_modules/.bin/wrangler.cmd directly for Worker deploys and use supabase_mcp (list_migrations, apply_migration, execute_sql, get_advisors) for Supabase Cloud DDL and diagnostics."
  ]
}
```

# Phase 71 Session Memory & Verification Summary

- **Specification Status:** `completed` (Stage 4 Pass 1 `M71.1`–`M71.2`, Pass 2 `M71.3`–`M71.4`, live cloud rollout, and device install verified on `2026-11-20`).
- **Verification Gates:**
  - Backend: `apps/vhunambi_api/node_modules/.bin/tsc.cmd --noEmit` (`0` errors) and `npm test` (`27/27` suites passed including `phase71_worker_supabase_readthrough.test.ts` after fixing `upsertExploreTrack` `dataJson.language` and `applyMutationsBatch` `trackId`/`entityId` resolution).
  - Client: `flutter analyze --no-pub` (`0` issues), `test/features/explore/` + `test/features/track/phase70_song_cockpit_and_glass_test.dart` (`89/89` passed including `explore_notifier_test.dart:163` and `VhunambiMood.tryNormalize`), `phase71_connectome_closure_test.dart` (`7/7`), 5 repaired client test files, `test/features/notifications/`, `test/features/home/`, `test/features/social/` (`103/103`), and `test/features/studio/` (`284/284`).
- **Live Cloud & Physical Device Rollout (`2026-11-20`):**
  - **Supabase Cloud (`cbnruevwrqwjnnoscgsz`):** Applied `phase67_notifications_and_quotas`, `phase69_kinetic_posts_and_threaded_comments`, `phase70_track_mood_and_metadata`, `phase71_schema_parity_and_rpcs`, and `phase71_rls_and_rpc_hardening` via `supabase_mcp` (synced to `supabase/migrations/20261120000001_phase71_schema_parity_and_rpcs.sql`). Verified `200 OK` across all probed PostgREST endpoints and `0` `rls_disabled_in_public` advisor errors.
  - **Cloudflare Worker (`vhunambi-api`):** Deployed to `https://vhunambi-api.ndugelosigwadi.workers.dev` (`Version ID: aaaaa1c0-9d22-45de-91e9-82e62e1bb1da`); verified `/health` and `/v1/health` (`200 OK`) and strict `401 AUTH_REQUIRED` on `/api/system/preflight` and `/api/explore/tracks`.
  - **Android Release APK & USB Device:** Built `arm64` release APK (`45,349,059` bytes) wired to production Worker + R2 URLs and verified running on `Huawei JNY_LX1` (`EPHUT20917014649`, PID `3506`).
- **Upstream Audit:** [`docs/audits/PHASE71_CLOUD_PERSISTENCE_AND_OPEN_CONNECTOME_AUDIT.md`](../../audits/PHASE71_CLOUD_PERSISTENCE_AND_OPEN_CONNECTOME_AUDIT.md).
- **Connectome Promotions Verified:**
  - `EP-P67-NOTIF-API` (`OPEN` -> `CONNECTED_EXTENSIBLE`) via `HttpNotificationRepository` + `NotificationsNotifier`
  - `EP-P69-POST-COSIGN-REPOST-HTTP` (`OPEN` -> `CONNECTED_EXTENSIBLE`) via `HttpExploreRepository` + `SocialFeedPostsNotifier` + `ReelsCommentsNotifier`
  - `EP-P37-REMIX-TREE-API` (`OPEN` -> `CONNECTED_EXTENSIBLE`) via `ISocialRepository.getClipRemixes` + `RemixLineageTreeSheet`
  - `EP-P68-CREATOR-ALLOWANCE` extended to `StudioActionBar`, `GenerationPipelineNotifier`, and `SubscriptionUpgradeModal`
  - New endpoints registered: `EP-P71-EDGE-SWR-READTHROUGH`, `EP-P71-ATOMIC-QUOTA-RPC`.

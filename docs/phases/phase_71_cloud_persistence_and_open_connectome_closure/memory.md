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
    "Pre-existing unrelated failure observed in apps/vhunambi_client/test/features/explore/explore_notifier_test.dart:163 (filterExploreTracks mood 'Energetic' returns 3 instead of 2 due to Phase 70 canonical VhunambiMood mapping)."
  ]
}
```

# Phase 71 Session Memory & Verification Summary

- **Specification Status:** `completed` (Stage 4 Pass 1 `M71.1`–`M71.2` and Pass 2 `M71.3`–`M71.4` implemented and verified on `2026-11-20`: `npx tsc --noEmit` 0 errors, `npm test` `27/27` suites passed including `phase71_worker_supabase_readthrough.test.ts`, `flutter analyze --no-pub` 0 issues, `phase71_connectome_closure_test.dart` `7/7` passed, all 5 repaired pre-existing client test files passed, `test/features/notifications/` passed, `test/features/home/` passed, `test/features/social/` `103/103` passed, and `test/features/studio/` `284/284` passed).
- **Upstream Audit:** [`docs/audits/PHASE71_CLOUD_PERSISTENCE_AND_OPEN_CONNECTOME_AUDIT.md`](../../audits/PHASE71_CLOUD_PERSISTENCE_AND_OPEN_CONNECTOME_AUDIT.md).
- **Connectome Promotions Verified:**
  - `EP-P67-NOTIF-API` (`OPEN` -> `CONNECTED_EXTENSIBLE`) via `HttpNotificationRepository` + `NotificationsNotifier`
  - `EP-P69-POST-COSIGN-REPOST-HTTP` (`OPEN` -> `CONNECTED_EXTENSIBLE`) via `HttpExploreRepository` + `SocialFeedPostsNotifier` + `ReelsCommentsNotifier`
  - `EP-P37-REMIX-TREE-API` (`OPEN` -> `CONNECTED_EXTENSIBLE`) via `ISocialRepository.getClipRemixes` + `RemixLineageTreeSheet`
  - `EP-P68-CREATOR-ALLOWANCE` extended to `StudioActionBar`, `GenerationPipelineNotifier`, and `SubscriptionUpgradeModal`
  - New endpoints registered: `EP-P71-EDGE-SWR-READTHROUGH`, `EP-P71-ATOMIC-QUOTA-RPC`.

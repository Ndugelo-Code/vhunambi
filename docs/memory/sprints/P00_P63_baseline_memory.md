```json vhunambi-memory
{
  "phase_id": "P00_P63",
  "memory_key": "MEM-P00-P63-FOUNDATION-BASELINE",
  "title": "Foundation Baseline & Pre-P64 Open/Shared Endpoints Census",
  "status": "completed",
  "completed_at": "2026-11-12",
  "predecessor_keys": [],
  "concept_hubs": [
    "identity_role",
    "quota_economy",
    "sync_outbox",
    "ui_surface_std",
    "social_graph",
    "ai_synthesis_gpu",
    "audio_transport"
  ],
  "consumes": [],
  "endpoints": [
    {
      "id": "EP-P61-IDENTITY-UTILS",
      "kind": "domain_utility",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["identity_role"],
      "spec_anchor": "docs/phases/phase_61_sovereign_identity_auth_and_security_convergence/design.md",
      "code_anchor": "apps/vhunambi_client/lib/core/utils/creator_id_utils.dart",
      "summary": "Canonical creator ID normalizer & handle utilities shared across auth, marketplace, playlists, and profiles.",
      "consumers": [
        "P61:auth_providers",
        "P61:sovereign_auth_repository",
        "P61:marketplace_providers",
        "P61:profile_providers",
        "P61:artist_profile_view"
      ],
      "open_opportunities": "Pair with formal ViewerRole owner-vs-visitor boundary across TrackDetailView & ArtistProfileView (Phase 70)"
    },
    {
      "id": "EP-P60-HIVE-SYNC-CORE",
      "kind": "persistence_engine",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["sync_outbox"],
      "spec_anchor": "docs/phases/phase_60_sovereign_hive_brain_and_persistence_convergence/design.md",
      "code_anchor": "apps/vhunambi_client/lib/core/storage/sovereign_hive_bootstrap_service.dart",
      "summary": "26-box AES-256 Sovereign Hive vault bootstrap + EdgeSyncCoordinator (/api/v1/sync/mutations, /delta) + SovereignApiClient.",
      "consumers": [
        "P60:main.dart",
        "P60:sovereign_hive_account_sanitizer",
        "P60:offline_providers",
        "P60:hive_brain_telemetry_card"
      ],
      "open_opportunities": "Wire Worker routes beyond auth_routes.ts to SupabaseCloudDriver instead of volatile EdgeIsolateDatabaseEngine memory"
    },
    {
      "id": "EP-P58-MKT-VERIFY-PRODUCER",
      "kind": "backend_api",
      "state": "OPEN",
      "hubs": ["quota_economy", "identity_role"],
      "spec_anchor": "docs/phases/phase_58_sovereign_beatstore_licensing/design.md",
      "code_anchor": "apps/vhunambi_api/src/routes/marketplace_routes.ts",
      "summary": "GET /api/marketplace/licenses/verify/:certificateId, GET /licenses/:buyerId, GET /producers/:producerId/beats.",
      "consumers": [],
      "open_opportunities": "Wire GET /producers/:producerId/beats into ArtistProfileView Beatstore tab & certificate verification UI (Phase 70)"
    },
    {
      "id": "EP-P37-REMIX-TREE-API",
      "kind": "backend_api",
      "state": "OPEN",
      "hubs": ["social_graph"],
      "spec_anchor": "docs/phases/phase_37_open_verse_and_stem_remix_chains/design.md",
      "code_anchor": "apps/vhunambi_api/src/routes/social_routes.ts",
      "summary": "GET /api/social/clips/:id/remixes lineage endpoint.",
      "consumers": [],
      "open_opportunities": "Connect RemixLineageTreeSheet to live backend remix graph instead of local-only mock tree"
    },
    {
      "id": "EP-P41-WALLET-DIRECT",
      "kind": "backend_api",
      "state": "OPEN",
      "hubs": ["quota_economy"],
      "spec_anchor": "docs/phases/phase_41_creator_sovereign_payouts_and_banking/design.md",
      "code_anchor": "apps/vhunambi_api/src/routes/wallet_routes.ts",
      "summary": "GET /api/wallet/:creatorId & POST /api/wallet/topup direct routes.",
      "consumers": [],
      "open_opportunities": "Consolidate with /api/creators/:id/wallet or wire direct topup/balance callers cleanly"
    },
    {
      "id": "EP-P27-MELODY-PRESETS-PACKS",
      "kind": "backend_api",
      "state": "OPEN",
      "hubs": ["audio_transport", "ai_synthesis_gpu"],
      "spec_anchor": "docs/phases/phase_27_melody_logdrum_sketchpad/design.md",
      "code_anchor": "apps/vhunambi_api/src/routes/melody_routes.ts",
      "summary": "GET /v1/melodies/presets & GET /v1/melodies/sound-packs.",
      "consumers": [],
      "open_opportunities": "Hydrate Groove Sketchpad sound pack catalog dynamically from backend API"
    },
    {
      "id": "EP-P26-VOICE-CALIBRATION-RECIPE",
      "kind": "backend_api",
      "state": "OPEN",
      "hubs": ["ai_synthesis_gpu", "identity_role"],
      "spec_anchor": "docs/phases/phase_26_vocal_identity_cloning/design.md",
      "code_anchor": "apps/vhunambi_api/src/routes/voice_routes.ts",
      "summary": "POST /v1/voices/extract-calibration & PATCH /v1/voices/signatures/:id/recipe.",
      "consumers": [],
      "open_opportunities": "Wire voice calibration & DSP signature recipe updates from Sound Signature intake flow"
    },
    {
      "id": "EP-P25-GEN-MASTER-PRESETS",
      "kind": "backend_api",
      "state": "OPEN",
      "hubs": ["ai_synthesis_gpu", "audio_transport"],
      "spec_anchor": "docs/phases/phase_25_stem_mastering_suite/design.md",
      "code_anchor": "apps/vhunambi_api/src/routes/generation_routes.ts",
      "summary": "GET /v1/generations/mastering/presets & GET /v1/generations/:id/manifest.",
      "consumers": [],
      "open_opportunities": "Sync server mastering presets & 4-stem MMO manifest directly into Mastering Studio & TrackDetailView"
    },
    {
      "id": "EP-P63-R2-SEEDER",
      "kind": "ops_api",
      "state": "SEALED",
      "hubs": ["media_artwork", "sync_outbox"],
      "spec_anchor": "docs/phases/phase_63_e2e_cloud_pipeline_and_preflight_convergence/design.md",
      "code_anchor": "apps/vhunambi_api/src/routes/system_routes.ts",
      "summary": "POST /api/system/seed-r2-media operator-only bucket seeder.",
      "consumers": ["ops:cli"],
      "open_opportunities": null
    },
    {
      "id": "EP-P62-RUNPOD-WEBHOOK",
      "kind": "webhook",
      "state": "SEALED",
      "hubs": ["ai_synthesis_gpu"],
      "spec_anchor": "docs/phases/phase_62_hybrid_cloud_stack_topology_convergence/design.md",
      "code_anchor": "apps/vhunambi_api/src/routes/webhook_routes.ts",
      "summary": "POST /v1/webhooks/ace-step HMAC-verified server-to-server RunPod GPU callback.",
      "consumers": ["runpod:zr-studio-gpu"],
      "open_opportunities": null
    }
  ],
  "edges": [
    {
      "from": "apps/vhunambi_client/lib/core/widgets/vhunambi_top_bar_kit.dart",
      "relation": "PROVIDES",
      "to": "apps/vhunambi_client/lib/features/track/presentation/views/track_detail_view.dart",
      "note": "Shared top bar kit consumed by 16 screens"
    },
    {
      "from": "apps/vhunambi_client/lib/core/widgets/vhunambi_bottom_dock_kit.dart",
      "relation": "PROVIDES",
      "to": "apps/vhunambi_client/lib/main.dart",
      "note": "Shared bottom dock clearance metrics consumed by 11 screens"
    }
  ],
  "breakthroughs": [
    "26-box AES-256 Sovereign Hive bootstrap (P60), dual-gate ES256/HS256 auth (P61), and Cloudflare Worker + GenerationSessionDO hybrid stack (P62-P63) form the production baseline.",
    "Audit VHUNAMBI_REPO_TOPOLOGY_AND_MEMORY_READINESS_AUDIT.md inventoried 6 pre-P64 backend route groups sitting OPEN with zero direct Dart client HTTP callers."
  ],
  "gotchas": [
    "SovereignAuthRepository.clearSession() must delete only sessionStorageKey, never tokenBox.clear(), or onboarding_state_v1 is wiped.",
    "Never call bare top-level function names inside CreatorIdUtils static methods (Dart lexical scope infinite recursion)."
  ]
}
```

# Phases 0–63 Foundation Baseline Memory

Seeded from [`docs/audits/VHUNAMBI_REPO_TOPOLOGY_AND_MEMORY_READINESS_AUDIT.md`](../../audits/VHUNAMBI_REPO_TOPOLOGY_AND_MEMORY_READINESS_AUDIT.md) so all legacy `OPEN` backend routes and core shared utilities are queryable via `query_connectome.mjs`.

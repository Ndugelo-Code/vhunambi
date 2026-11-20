```json vhunambi-memory
{
  "phase_id": "P67",
  "memory_key": "MEM-P67-NOTIFICATIONS-QUOTA",
  "title": "Notifications Center Two-Pass Overhaul & 10 Free Monthly Songs Engine",
  "status": "completed",
  "completed_at": "2026-11-16",
  "predecessor_keys": ["MEM-P66-AUDIO-PROMPT-HYGIENE-V3"],
  "concept_hubs": ["notifications_bus", "quota_economy", "ui_surface_std", "sync_outbox"],
  "consumes": ["EP-P65-CRASH-AUDIO-SHIELD", "EP-P60-HIVE-SYNC-CORE"],
  "endpoints": [
    {
      "id": "EP-P67-NOTIF-API",
      "kind": "backend_api",
      "state": "OPEN",
      "hubs": ["notifications_bus", "sync_outbox"],
      "spec_anchor": "docs/phases/phase_67_notifications_center_two_pass_overhaul/design.md",
      "code_anchor": "apps/vhunambi_api/src/routes/notification_routes.ts",
      "summary": "5 REST routes: GET/POST /api/notifications, PATCH /:id/read, POST /mark-all-read, DELETE /:id backed by 20261116000001 migration.",
      "consumers": [],
      "open_opportunities": "Zero Dart client HTTP callers yet (NotificationRepository uses local Hive only); wire cross-device cloud notification sync"
    },
    {
      "id": "EP-P67-QUOTA-API",
      "kind": "backend_api",
      "state": "OPEN",
      "hubs": ["quota_economy"],
      "spec_anchor": "docs/phases/phase_67_notifications_center_two_pass_overhaul/design.md",
      "code_anchor": "apps/vhunambi_api/src/routes/wallet_routes.ts",
      "summary": "GET /api/wallet/allowance returning 10 free monthly songs quota balance & monthly reset cycle.",
      "consumers": [],
      "open_opportunities": "Expose live monthly quota allowance in Studio Compose & SubscriptionUpgradeModal in addition to Home"
    },
    {
      "id": "EP-P67-NOTIF-BELL",
      "kind": "ui_primitive",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["notifications_bus", "ui_surface_std"],
      "spec_anchor": "docs/phases/phase_67_notifications_center_two_pass_overhaul/design.md",
      "code_anchor": "apps/vhunambi_client/lib/features/notifications/presentation/widgets/notification_bell_button.dart",
      "summary": "Unified unread badge bell button rendered across all top-level navigation app bars.",
      "consumers": [
        "P67:vhunambi_app_bar",
        "P67:explore_top_bar",
        "P67:library_app_bar",
        "P67:marketplace_top_bar"
      ],
      "open_opportunities": "Back unread count with EP-P67-NOTIF-API once cloud notification sync is wired"
    },
    {
      "id": "EP-P67-DEEPLINK-ROUTER",
      "kind": "navigation_router",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["notifications_bus", "social_graph"],
      "spec_anchor": "docs/phases/phase_67_notifications_center_two_pass_overhaul/design.md",
      "code_anchor": "apps/vhunambi_client/lib/features/notifications/presentation/utils/notification_deep_link_router.dart",
      "summary": "Central notification deep-link dispatcher supporting /track/:id, /post/:id, /studio, /profile/:id, and /wallet routes.",
      "consumers": [
        "P67:notifications_view",
        "P67:notification_detail_bottom_sheet"
      ],
      "open_opportunities": "Extend for Beatstore license deeds and Visitor Creator Profile tabs in Phase 70+"
    },
    {
      "id": "EP-P67-ONBOARDING-NOTIFS",
      "kind": "domain_service",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["notifications_bus", "quota_economy"],
      "spec_anchor": "docs/phases/phase_67_notifications_center_two_pass_overhaul/design.md",
      "code_anchor": "apps/vhunambi_client/lib/features/notifications/domain/services/onboarding_notifications_service.dart",
      "summary": "Idempotent beginner milestone seeder (Welcome, Creator DNA 6-10%, 10 Free Monthly Songs).",
      "consumers": ["P67:onboarding_view", "P67:main.dart"],
      "open_opportunities": "Sync starter milestones with backend EP-P67-NOTIF-API on fresh sign-in"
    },
    {
      "id": "EP-P67-SCRUB-LEGACY-NOTIFS",
      "kind": "internal_migration",
      "state": "SEALED",
      "hubs": ["notifications_bus", "sync_outbox"],
      "spec_anchor": "docs/phases/phase_67_notifications_center_two_pass_overhaul/design.md",
      "code_anchor": "apps/vhunambi_client/lib/features/notifications/data/repositories/notification_repository.dart",
      "summary": "One-off Hive scrubber purging legacy phase40SeededNotifications demo mocks (isLegacyDemoMockId).",
      "consumers": ["P67:notification_repository"],
      "open_opportunities": null
    }
  ],
  "edges": [
    {
      "from": "apps/vhunambi_client/lib/features/notifications/presentation/views/notifications_view.dart",
      "relation": "ROUTES_TO",
      "to": "EP-P67-DEEPLINK-ROUTER",
      "note": "Dispatches tapped notification alerts into track, post, profile, or studio destinations"
    }
  ],
  "breakthroughs": [
    "Purged fake Phase 40 demo alerts, calibrated starter Creator DNA completeness to 6-10%, and fixed Unknown Melody lookup in track_providers.dart by searching libraryTracksProvider & exploreTracksProvider.",
    "Shipped 20261116000001_phase67_notifications_and_quotas.sql and 10 Free Monthly Songs tracking on /api/wallet/allowance + /v1/generations."
  ],
  "gotchas": [
    "apps/vhunambi_api/src/phase67_notifications_quota.test.ts was placed inside src/ instead of test/; keep in mind during API test cleanup.",
    "All 5 /api/notifications* backend routes remain OPEN until a client HTTP notification sync repository is added."
  ]
}
```

# Phase 67 Session Memory & Breakthroughs

- **Tasks Standing:** `15/15` tasks `[x]` in [`tasks.md`](./tasks.md).
- **Open Hook Left Behind:** `EP-P67-NOTIF-API` (`notification_routes.ts`) awaits client HTTP integration; `EP-P67-QUOTA-API` was subsequently claimed by Phase 68.

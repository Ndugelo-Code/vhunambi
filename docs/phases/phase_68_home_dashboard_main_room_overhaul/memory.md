```json vhunambi-memory
{
  "phase_id": "P68",
  "memory_key": "MEM-P68-HOME-MAIN-ROOM",
  "title": "Home Dashboard Main Room & Studio Utility Overhaul",
  "status": "completed",
  "completed_at": "2026-11-17",
  "predecessor_keys": ["MEM-P67-NOTIFICATIONS-QUOTA"],
  "concept_hubs": [
    "media_artwork",
    "quota_economy",
    "audio_transport",
    "mood_taxonomy",
    "ui_surface_std"
  ],
  "consumes": [
    "EP-P67-QUOTA-API",
    "EP-P67-NOTIF-BELL",
    "EP-P65-CRASH-AUDIO-SHIELD"
  ],
  "endpoints": [
    {
      "id": "EP-P68-TRACK-ARTWORK",
      "kind": "ui_primitive",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["media_artwork", "ui_surface_std"],
      "spec_anchor": "docs/phases/phase_68_home_dashboard_main_room_overhaul/design.md",
      "code_anchor": "apps/vhunambi_client/lib/core/widgets/vhunambi_track_artwork.dart",
      "summary": "Unified track cover renderer backed by 10 bundled studio PNGs and AppAssets.resolveGenreCoverAsset deterministic fallback.",
      "consumers": [
        "P68:horizontal_genre_track_shelf",
        "P68:now_playing_home_card"
      ],
      "open_opportunities": "Not yet adopted in TrackDetailView (936 lines, 6 stock Icons.*) or ArtistProfileView (803 lines, 10 stock Icons.*) — prime Phase 70 upgrade"
    },
    {
      "id": "EP-P68-CREATOR-ALLOWANCE",
      "kind": "state_provider",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["quota_economy", "sync_outbox"],
      "spec_anchor": "docs/phases/phase_68_home_dashboard_main_room_overhaul/design.md",
      "code_anchor": "apps/vhunambi_client/lib/features/home/presentation/providers/creator_allowance_provider.dart",
      "summary": "CreatorAllowanceNotifier consuming GET /api/wallet/allowance with per-tenant Hive prefsBoxKey caching.",
      "consumers": ["P68:main_room_header"],
      "open_opportunities": "Mount live 10/10 quota pill inside Studio Compose header and SubscriptionUpgradeModal"
    },
    {
      "id": "EP-P68-MINIPLAYER-SUPPRESS",
      "kind": "state_contract",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["audio_transport", "ui_surface_std"],
      "spec_anchor": "docs/phases/phase_68_home_dashboard_main_room_overhaul/design.md",
      "code_anchor": "apps/vhunambi_client/lib/core/navigation/navigation_providers.dart",
      "summary": "homeInlineNowPlayingMountedProvider coordinating floating MiniPlayerHost suppression whenever Tab-0 NowPlayingHomeCard is visible.",
      "consumers": ["P68:mini_player_host", "P68:home_dashboard_view"],
      "open_opportunities": "Reuse inline-player suppression contract for future full-screen focus players (e.g. Song Cockpit) to avoid duplicate transports"
    },
    {
      "id": "EP-P68-MOOD-FRAGMENTED",
      "kind": "data_contract",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["mood_taxonomy", "ai_synthesis_gpu", "social_graph"],
      "spec_anchor": "docs/audits/VHUNAMBI_REPO_TOPOLOGY_AND_MEMORY_READINESS_AUDIT.md",
      "code_anchor": "apps/vhunambi_client/lib/core/design_system/tokens/design_enums.dart#L33-L48",
      "summary": "Fragmented mood representation: 5-value enum Mood in design_enums.dart vs free strings in StudioFormNotifier vs Explore exploreMoodFilterProvider.",
      "consumers": [
        "P68:studio_form_provider",
        "P68:explore_providers"
      ],
      "open_opportunities": "Unify into a canonical VhunambiMood / moodId taxonomy across Studio, TrackDetailView, Explore mood filters, and Home curated mixes (Phase 70+)"
    }
  ],
  "edges": [
    {
      "from": "apps/vhunambi_client/lib/features/home/presentation/widgets/main_room_header.dart",
      "relation": "CONSUMES",
      "to": "EP-P68-CREATOR-ALLOWANCE",
      "note": "Renders live 10/10 monthly songs allowance pill"
    },
    {
      "from": "apps/vhunambi_client/lib/features/home/presentation/views/home_dashboard_view.dart",
      "relation": "MUTATES",
      "to": "EP-P68-MINIPLAYER-SUPPRESS",
      "note": "Suppresses floating MiniPlayerHost on Tab 0 while NowPlayingHomeCard is mounted"
    }
  ],
  "breakthroughs": [
    "Replaced orange-placeholder covers with 10 registered studio PNGs via AppAssets.resolveGenreCoverAsset and VhunambiTrackArtwork.",
    "Wired GET /api/wallet/allowance (EP-P67-QUOTA-API) into CreatorAllowanceNotifier + MainRoomHeader and added Tab-0 MiniPlayerHost suppression."
  ],
  "gotchas": [
    "Keep standalone MiniPlayerHost tests working by defaulting homeInlineNowPlayingMountedProvider to false when HomeDashboardView is not mounted.",
    "Purged raw emojis from african_greeting_resolver.dart, dna_insight_card.dart, cross_module_synergy_deck.dart, and subscription_upgrade_modal.dart per STD-UIUX-001."
  ]
}
```

# Phase 68 Session Memory & Breakthroughs

- **Tasks Standing:** `22/22` tasks `[x]` in [`tasks.md`](./tasks.md).
- **Connections Claimed:** Claimed `EP-P67-QUOTA-API` from Phase 67 into `CreatorAllowanceNotifier`.

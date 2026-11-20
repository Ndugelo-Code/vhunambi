```json vhunambi-memory
{
  "phase_id": "P70",
  "memory_key": "MEM-P70-SONG-COCKPIT-VISITOR-PROFILE",
  "title": "Role-Aware Song Cockpit, Facebook-Benchmark Public Visitor Profile, Canonical VhunambiMood & VhunambiGlassSurface Overhaul",
  "status": "completed",
  "completed_at": "2026-11-19",
  "predecessor_keys": [
    "MEM-P68-HOME-MAIN-ROOM",
    "MEM-P69-KINETIC-POST-FOCUS"
  ],
  "concept_hubs": [
    "identity_role",
    "media_artwork",
    "mood_taxonomy",
    "social_graph",
    "audio_transport",
    "ui_surface_std",
    "quota_economy"
  ],
  "consumes": [
    "EP-P58-MKT-VERIFY-PRODUCER",
    "EP-P68-TRACK-ARTWORK",
    "EP-P69-THREADED-COMMENTS",
    "EP-P69-KPOST-FOCUS-ROUTE",
    "EP-P68-MINIPLAYER-SUPPRESS",
    "EP-P61-IDENTITY-UTILS",
    "EP-P68-MOOD-FRAGMENTED"
  ],
  "endpoints": [
    {
      "id": "EP-P70-GLASS-SURFACE",
      "kind": "ui_primitive",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["ui_surface_std", "media_artwork"],
      "spec_anchor": "docs/phases/phase_70_song_cockpit_and_visitor_profile_glass_overhaul/design.md#1-vhunambiglasssurface-ep-p70-glass-surface",
      "code_anchor": "apps/vhunambi_client/lib/core/widgets/vhunambi_glass_surface.dart",
      "summary": "Dual-theme 3-layer VhunambiGlassSurface & RepaintBoundary-protected VhunambiAmbientMeshBackdrop calibrated for Warm African Daylight (Morning Mist) and Obsidian Night with 60 FPS Android blur guardrails (enableLiveBlur: false default, sigma <= 16.0 opt-in).",
      "consumers": [
        "P70:TrackDetailView",
        "P70:ArtistProfileView"
      ],
      "open_opportunities": "Adopt VhunambiGlassSurface across Home dashboard cards, Explore headers, Notifications drawer, and OwnerProfileView"
    },
    {
      "id": "EP-P70-MOOD-TAXONOMY",
      "kind": "domain_contract",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["mood_taxonomy", "social_graph"],
      "spec_anchor": "docs/phases/phase_70_song_cockpit_and_visitor_profile_glass_overhaul/design.md#3-canonical-vhunambimood-ep-p70-mood-taxonomy",
      "code_anchor": "apps/vhunambi_client/lib/core/design_system/tokens/vhunambi_mood.dart",
      "summary": "Canonical 6-mood wire taxonomy (uplifting, soulful, energetic, chill, hypnotic, romantic) with lossless normalize() bridging design_enums.dart, StudioFormState, Explore filters, TrackDetailEntity, and apps/vhunambi_api.",
      "consumers": [
        "P70:TrackSonicTelemetryCard",
        "P70:explore_providers",
        "P70:explore_routes"
      ],
      "open_opportunities": "Power Mood Radio stations, interactive Explore mood pill cross-filtering from TrackDetailView, and Studio mood selector migration"
    },
    {
      "id": "EP-P70-VIEWER-ROLE",
      "kind": "domain_policy",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["identity_role", "quota_economy"],
      "spec_anchor": "docs/phases/phase_70_song_cockpit_and_visitor_profile_glass_overhaul/design.md#4-deterministic-viewerrole-policy-ep-p70-viewer-role",
      "code_anchor": "apps/vhunambi_client/lib/core/auth/viewer_role.dart",
      "summary": "Fail-closed ViewerRole { owner, visitor } resolver backed by EP-P61-IDENTITY-UTILS isolating paid creator studio controls and personal ownership deeds from outside listeners.",
      "consumers": [
        "P70:TrackDetailView",
        "P70:TrackHeroSection"
      ],
      "open_opportunities": "Reuse ViewerRole across KineticPostFocusView creator moderation actions, Beatstore producer edit gates, and Playlists ownership guards"
    }
  ],
  "edges": [
    {
      "from": "apps/vhunambi_client/lib/features/track/presentation/views/track_detail_view.dart",
      "relation": "CONSUMES",
      "to": "EP-P70-VIEWER-ROLE",
      "note": "Gates StemSeparationLab, StemMixerDeck (List in Beatstore), Mastering, PromptAttributionCard, and Ownership Deed strictly on ViewerRole.owner"
    },
    {
      "from": "apps/vhunambi_client/lib/features/track/presentation/views/track_detail_view.dart",
      "relation": "CONSUMES",
      "to": "EP-P69-THREADED-COMMENTS",
      "note": "Replaces legacy flat CommentsSection with shared ThreadedCommentsSection + sticky StudioReactionComposerBar"
    },
    {
      "from": "apps/vhunambi_client/lib/features/track/presentation/widgets/track_hero_section.dart",
      "relation": "CONSUMES",
      "to": "EP-P68-TRACK-ARTWORK",
      "note": "Replaces flat genre gradient box with unified VhunambiTrackArtwork"
    },
    {
      "from": "apps/vhunambi_client/lib/features/profile/presentation/views/artist_profile_view.dart",
      "relation": "ROUTES_TO",
      "to": "EP-P69-KPOST-FOCUS-ROUTE",
      "note": "Opens KineticPostFocusView from Overview and Posts & Reels tabs on public visitor creator profiles"
    },
    {
      "from": "apps/vhunambi_client/lib/features/marketplace/data/repositories/http_marketplace_repository.dart",
      "relation": "CONSUMES",
      "to": "EP-P58-MKT-VERIFY-PRODUCER",
      "note": "Calls GET /api/marketplace/producers/:producerId/beats to hydrate Visitor Profile Beats tab"
    },
    {
      "from": "apps/vhunambi_client/lib/features/player/presentation/widgets/mini_player_host.dart",
      "relation": "CONSUMES",
      "to": "EP-P68-MINIPLAYER-SUPPRESS",
      "note": "Generalizes inline/pushed route suppression via trackDetailInlinePlayerMountedProvider and pushedFullScreenOverlayCountProvider"
    }
  ],
  "breakthroughs": [
    "Drafted two-pass architecture cleanly isolating Pass 1 (Glass system, VhunambiMood, ViewerRole, Role-Aware TrackDetailView) from Pass 2 (5-tab Facebook-benchmark ArtistProfileView, EP-P58 producer beats HTTP wiring, backend mood_id parity)."
  ],
  "gotchas": [
    "AppColors.surfaceElevated resolves to #FFFFFF in Light Mode; never pair it with hardcoded Colors.white foregrounds (root cause of TrackActionsBar and ProfileBannerHeader ghost pills).",
    "Never put BackdropFilter inside repeating ListView/CustomScrollView cards on Android; keep VhunambiGlassSurface.enableLiveBlur = false by default and wrap VhunambiAmbientMeshBackdrop in RepaintBoundary.",
    "In Flutter widget tests using FakeAsync, Dio ResponseBody.fromString streams can stall; test HttpClientAdapter HTTP calls in plain test() blocks and override FutureProvider families in testWidgets() with bounded pump()."
  ]
}
```

# Phase 70 Session Memory & Verification Summary

- **Specification Status:** `completed` (Stage 4 Pass 1 `M70.1`–`M70.2` and Pass 2 `M70.3`–`M70.4` implemented and verified on `2026-11-19`: `flutter analyze --no-pub` 0 issues, sequential Flutter tests across `test/features/track/`, `test/features/profile/`, `test/features/player/` passing, `npx tsc --noEmit` 0 errors, and all 24 `apps/vhunambi_api` test suites passing).
- **Upstream Audit:** [`docs/audits/PHASE70_SONG_COCKPIT_AND_VISITOR_PROFILE_GLASS_OVERHAUL_AUDIT.md`](../../audits/PHASE70_SONG_COCKPIT_AND_VISITOR_PROFILE_GLASS_OVERHAUL_AUDIT.md).
- **Connectome Promotions Verified:** `EP-P58-MKT-VERIFY-PRODUCER` promoted from `OPEN` -> `CONNECTED_EXTENSIBLE` via `HttpMarketplaceRepository.getProducerBeats` + `producerBeatsFamilyProvider`, and `EP-P68-MOOD-FRAGMENTED` consolidated via `EP-P70-MOOD-TAXONOMY`.

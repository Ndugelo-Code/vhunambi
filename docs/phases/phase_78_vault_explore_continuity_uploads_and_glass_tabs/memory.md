```json vhunambi-memory
{
  "phase_id": "P78",
  "memory_key": "MEM-P78-VAULT-EXPLORE-CONTINUITY-UPLOADS-GLASS-TABS",
  "title": "Vault, Explore & Profile Continuity, Real Audio/Video Uploads & Unified Glass Tabs",
  "status": "completed",
  "completed_at": "2026-11-23T04:17:00Z",
  "predecessor_keys": [
    "MEM-P68-HOME-MAIN-ROOM",
    "MEM-P70-SONG-COCKPIT-VISITOR-PROFILE",
    "MEM-P74-KINETIC-REELS-STUDIO-V4",
    "MEM-P75-STUDIO-COCKPIT-V5-CONNECTOME-CLOSURE",
    "MEM-P76-POST-RELEASE-AUTH-ONBOARDING-DEEPLINK-POLISH",
    "MEM-P77-CHROMATIC-PLAYER-LYRICS-R2-UPLOADS"
  ],
  "concept_hubs": [
    "social_graph",
    "media_artwork",
    "ui_surface_std",
    "identity_role",
    "audio_transport",
    "mood_taxonomy"
  ],
  "consumes": [
    "EP-P68-TRACK-ARTWORK",
    "EP-P70-GLASS-SURFACE",
    "EP-P70-VIEWER-ROLE",
    "EP-P74-KARAOKE-LYRIC-SANITIZER",
    "EP-P74-REELS-STUDIO-PIPELINE",
    "EP-P74-SOCIAL-MEDIA-R2-UPLOAD",
    "EP-P77-UNIFIED-R2-IMAGE-UPLOAD"
  ],
  "endpoints": [
    {
      "id": "EP-P78-GLASS-TAB-BAR",
      "kind": "ui_primitive",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["ui_surface_std"],
      "spec_anchor": "docs/phases/phase_78_vault_explore_continuity_uploads_and_glass_tabs/design.md#41-new-appsvhunambi_clientlibcorewidgetsvhunambi_glass_tab_bardart",
      "code_anchor": "apps/vhunambi_client/lib/core/widgets/vhunambi_glass_tab_bar.dart",
      "summary": "Unified frosted glass tab strip (VhunambiGlassTabBar + VhunambiGlassTabBarHeaderDelegate) with animated translucent active capsule, specular rim, optional count badge, and Light/Dark WCAG AA parity adopted across OwnerProfileView, ArtistProfileView, ExploreView, and LibraryCategoryRail.",
      "consumers": [
        "P78:OwnerProfileView",
        "P78:ArtistProfileView",
        "P78:ExploreView",
        "P78:LibraryCategoryRail"
      ],
      "open_opportunities": "Adopt VhunambiGlassTabBar inside ReelAudioPickerSheet, StudioView sub-modes, and MarketplaceView category headers in Phase 79"
    },
    {
      "id": "EP-P78-CREATOR-REELS-HUB",
      "kind": "domain_and_ui_primitive",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["social_graph", "media_artwork", "identity_role"],
      "spec_anchor": "docs/phases/phase_78_vault_explore_continuity_uploads_and_glass_tabs/design.md#3-pass-2--m783-explore--library--owner-profile-continuity-va-01",
      "code_anchor": "apps/vhunambi_client/lib/features/library/presentation/views/reels_vault_view.dart",
      "summary": "Unified Explore <-> Library (LibraryCategory.reels + ReelsVaultView) <-> OwnerProfileView Reel continuity hub with index-0 fresh publish pinning in trendingReelsProvider and VhunambiTrackArtwork cards.",
      "consumers": [
        "P78:LibraryView",
        "P78:TrendingReelsShelf",
        "P78:OwnerProfileView"
      ],
      "open_opportunities": "Bind Phase 79 Hold-for-Quick-Actions context menu and Pin-to-Profile controls onto ReelsVaultView and CreatorReelThumbnailCard"
    },
    {
      "id": "EP-P78-REAL-AUDIO-VIDEO-INGEST",
      "kind": "client_and_api_pipeline",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["media_artwork", "audio_transport", "social_graph"],
      "spec_anchor": "docs/phases/phase_78_vault_explore_continuity_uploads_and_glass_tabs/design.md#1-pass-1--m781-real-audio-upload--cameragallery-video-capture-va-02",
      "code_anchor": "apps/vhunambi_client/lib/features/studio/presentation/widgets/direct_daw_vocal_upload_sheet.dart",
      "summary": "End-to-end real FilePicker audio import (WAV/MP3/M4A/AAC/OGG via /api/social/media/upload) and live CameraController video recording + Stage 2 VideoPlayerController + offline-safe localVideoPath handoff in KineticReelStudioView.",
      "consumers": [
        "P78:DirectDawVocalUploadSheet",
        "P78:KineticReelStudioView",
        "P78:KineticReelPublishView",
        "P78:KineticReelsModal"
      ],
      "open_opportunities": "Feed uploaded/recorded image & video keyframes directly into Phase 80 VhunambiVisualDnaMatcher for automatic song & chorus cue recommendations"
    }
  ],
  "edges": [
    {
      "from": "apps/vhunambi_client/lib/features/studio/presentation/widgets/direct_daw_vocal_upload_sheet.dart",
      "relation": "CONSUMES",
      "to": "EP-P74-SOCIAL-MEDIA-R2-UPLOAD",
      "note": "Uploads real picked DAW/Vocal audio bytes (MP3/M4A/WAV/AAC/OGG) to R2 and persists localAudioFilePath into libraryTracksProvider"
    },
    {
      "from": "apps/vhunambi_client/lib/features/content_studio/presentation/views/kinetic_reel_studio_view.dart",
      "relation": "MUTATES",
      "to": "EP-P74-REELS-STUDIO-PIPELINE",
      "note": "Adds real CameraController video recording, Stage 2 VideoPlayerController preview, localVideoPath handoff, and unobstructed top Audio pill"
    },
    {
      "from": "apps/vhunambi_client/lib/features/social/presentation/widgets/creator_reel_thumbnail_card.dart",
      "relation": "CONSUMES",
      "to": "EP-P68-TRACK-ARTWORK",
      "note": "Replaces raw Image.network + AppGradients.forGenre + Icons.* with VhunambiTrackArtwork + PhosphorIcon"
    },
    {
      "from": "apps/vhunambi_client/lib/features/explore/presentation/widgets/track_list_tile.dart",
      "relation": "CONSUMES",
      "to": "EP-P68-TRACK-ARTWORK",
      "note": "Replaces orange genre glyph squares in Fastest Growing Tracks with VhunambiTrackArtwork"
    },
    {
      "from": "apps/vhunambi_client/lib/features/profile/presentation/views/owner_profile_view.dart",
      "relation": "CONSUMES",
      "to": "EP-P78-GLASS-TAB-BAR",
      "note": "Replaces solid-orange blocky tabs with VhunambiGlassTabBar and removes duplicate _OwnerReelsShelf from Songs tab"
    },
    {
      "from": "apps/vhunambi_client/lib/features/profile/presentation/views/artist_profile_view.dart",
      "relation": "CONSUMES",
      "to": "EP-P78-GLASS-TAB-BAR",
      "note": "Replaces flat Material 2 underline TabBar with VhunambiGlassTabBarHeaderDelegate"
    }
  ],
  "breakthroughs": [
    "Established a unified Creator Published Hub across Explore (index-0 non-seed Reel pin in trendingReelsProvider), Library Asset Vault (LibraryCategory.reels + ReelsVaultView), and OwnerProfileView (VhunambiTrackArtwork on CreatorReelThumbnailCard + zero duplicate shelf under Songs).",
    "Standardized 4 fragmented tab bars (OwnerProfileView, ArtistProfileView, ExploreView, LibraryCategoryRail) onto VhunambiGlassTabBar and VhunambiGlassTabBarHeaderDelegate with 44dp touch targets, adaptive Light/Dark glass styling, and compact segment geometry that prevents desktop/mobile horizontal clipping.",
    "Closed real audio/video ingest (WAV/AAC/OGG in apps/vhunambi_api + FilePicker/R2 + CameraController recording/Stage 2 VideoPlayerController + localVideoPath propagation), killed the 39x SnackBar storm via ephemeral in-place pill, suppressed MiniPlayerHost during KineticReelsModal, and rescued @aistudio ownership + unclosed-paren/[INTRO] lyric tags."
  ],
  "gotchas": [
    "DirectDawVocalUploadSheet previously stamped isInstrumental: true on DAW Master uploads, which caused BOTH LibraryCategory.songs (library_providers.dart#L493) and OwnerProfileView._resolveOwnerSongs (#L250) to hide uploaded songs because BeatsVaultView reads marketplaceBeatsProvider instead of libraryTracksProvider.",
    "apps/vhunambi_api/src/routes/social_routes.ts ALLOWED_SOCIAL_MEDIA_MIMES must include audio/wav, audio/x-wav, audio/wave, audio/aac, and audio/ogg so producer WAV uploads do not hit 415 UNSUPPORTED_MEDIA_TYPE.",
    "Preserve [Verse 1] and [Chorus] inside LyricKaraokeSanitizer.cleanLyricsForTeleprompter (tested by phase75_studio_connectome_closure_test.dart#L554 and expanded_cockpit_modal_test.dart#L83); strip non-sung [INTRO]/[OUTRO] cues via cleanLyricsForPlayback and strip unclosed '(' cue fragments in cleanLyricTextForKaraoke.",
    "Adding LibraryCategory.reels requires updating all 5 UI/provider files: library_models.dart, library_providers.dart, library_view.dart, library_category_rail.dart, and library_empty_state.dart.",
    "Seeded demo Reels in SocialFeedNotifier use clip_pub_* IDs (not clip_seed_*), so trendingReelsProvider must check SocialFeedNotifier.isSeedClipId(c.id) rather than a prefix guess to avoid promoting a seed above virality-sorted peers.",
    "SocialMusicPost.fromJson must treat creator_current_user alongside current_user and user_current as legacy aliases, since canonicalizeCreatorId preserves creator_current_user and otherwise emits @current_user."
  ]
}
```

# Phase 78 Session Memory (Completed)

> Executed and verified by `/vhunambi-executioner` across Pass 1 (`M78.1`–`M78.2`) and Pass 2 (`M78.3`–`M78.4`): `dart analyze` (`0` issues), `STD-UIUX-001` (`0` `Icons.*` violations), `apps/vhunambi_api` (`npx tsc --noEmit` + 31/31 test suites), and 830 Flutter regression tests passing.

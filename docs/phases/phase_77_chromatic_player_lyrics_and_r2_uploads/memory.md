```json vhunambi-memory
{
  "phase_id": "P77",
  "memory_key": "MEM-P77-CHROMATIC-PLAYER-LYRICS-R2-UPLOADS",
  "title": "Chromatic Full-Screen Player, Synced 9-Language Bantu Sing-Along Lyrics & Unified R2 Media Uploads",
  "status": "completed",
  "completed_at": "2026-11-23T01:47:00Z",
  "predecessor_keys": [
    "MEM-P68-HOME-MAIN-ROOM",
    "MEM-P70-SONG-COCKPIT-VISITOR-PROFILE",
    "MEM-P73-KPOST-CHROMATIC-REACTIONS-HYGIENE",
    "MEM-P74-KINETIC-REELS-STUDIO-V4",
    "MEM-P75-STUDIO-COCKPIT-V5-CONNECTOME-CLOSURE",
    "MEM-P76-POST-RELEASE-AUTH-ONBOARDING-DEEPLINK-POLISH"
  ],
  "concept_hubs": [
    "media_artwork",
    "audio_transport",
    "mood_taxonomy",
    "social_graph",
    "ui_surface_std",
    "identity_role"
  ],
  "consumes": [
    "EP-P68-TRACK-ARTWORK",
    "EP-P70-GLASS-SURFACE",
    "EP-P73-POST-CHROMATIC-SYNTH",
    "EP-P74-KARAOKE-LYRIC-SANITIZER",
    "EP-P74-SOCIAL-MEDIA-R2-UPLOAD",
    "EP-P74-REELS-STUDIO-PIPELINE"
  ],
  "endpoints": [
    {
      "id": "EP-P77-CHROMATIC-PLAYER-CHROME",
      "kind": "ui_primitive",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["media_artwork", "audio_transport", "mood_taxonomy", "ui_surface_std"],
      "spec_anchor": "docs/phases/phase_77_chromatic_player_lyrics_and_r2_uploads/design.md#21-new-appsvhunambi_clientlibfeaturesplayerpresentationwidgetsplayer_chromatic_resolver_mixindart",
      "code_anchor": "apps/vhunambi_client/lib/features/player/presentation/widgets/player_chromatic_resolver_mixin.dart",
      "summary": "Shared sync-first + async-refined PostChromaticPaletteMixin powering ExpandedCockpitModal, MobileMiniPlayer, PillForm, DesktopTransportBar, and VhunambiFloatingTransportSurface with real VhunambiTrackArtwork and Light/Dark WCAG AA parity.",
      "consumers": [
        "P77:ExpandedCockpitModal",
        "P77:MobileMiniPlayer",
        "P77:PillForm",
        "P77:DesktopTransportBar"
      ],
      "open_opportunities": "Adopt PlayerChromaticPaletteMixin on TrackHeroSection and PlaylistDetailView headers for unified album-art ambient staging"
    },
    {
      "id": "EP-P77-SYNCED-BANTU-KARAOKE",
      "kind": "domain_and_ui_primitive",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["audio_transport", "ui_surface_std"],
      "spec_anchor": "docs/phases/phase_77_chromatic_player_lyrics_and_r2_uploads/design.md#3-pass-1--m772-synced-clean-karaoke--9-language-bantu-word-glossary",
      "code_anchor": "apps/vhunambi_client/lib/features/track/domain/utils/synced_lyric_timeline.dart",
      "summary": "Live playback-synced clean karaoke engine combining LyricKaraokeSanitizer, SyncedLyricTimeline (auto-scroll + tap-to-seek), and 9-language Southern Bantu word glossary popovers (BantuWordGlossarySheet) shared across TrackDetailView and ExpandedCockpitModal.",
      "consumers": [
        "P77:LyricsTeleprompter",
        "P77:ExpandedCockpitModal",
        "P77:BantuWordGlossarySheet"
      ],
      "open_opportunities": "Upgrade SyncedLyricTimeline to prefer per-word Whisper/MFA LyricWordTimestamp arrays whenever server alignment metadata is attached to a track"
    },
    {
      "id": "EP-P77-UNIFIED-R2-IMAGE-UPLOAD",
      "kind": "client_media_service",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["media_artwork", "social_graph", "ui_surface_std"],
      "spec_anchor": "docs/phases/phase_77_chromatic_player_lyrics_and_r2_uploads/design.md#41-new-appsvhunambi_clientlibcoremediavhunambi_media_upload_servicedart",
      "code_anchor": "apps/vhunambi_client/lib/core/media/vhunambi_media_upload_service.dart",
      "summary": "Reusable ImagePicker + MIME/25MB validator + FLUTTER_TEST-safe R2 uploader routing through POST /api/social/media/upload for Explore Kinetic Posts, Playlist custom covers, and Collections.",
      "consumers": [
        "P77:CreateKineticPostSheet",
        "P77:PlaylistsVaultView",
        "P77:PlaylistDetailView"
      ],
      "open_opportunities": "Reuse VhunambiMediaUploadService for OwnerProfileView avatar & banner cover uploads and Studio custom single artwork uploads"
    }
  ],
  "edges": [
    {
      "from": "apps/vhunambi_client/lib/features/player/presentation/widgets/expanded_cockpit_modal.dart",
      "relation": "CONSUMES",
      "to": "EP-P73-POST-CHROMATIC-SYNTH",
      "note": "Renders WCAG AA Light/Dark chromatic backdrop and aura shadows via PlayerChromaticPaletteMixin"
    },
    {
      "from": "apps/vhunambi_client/lib/features/player/presentation/widgets/expanded_cockpit_modal.dart",
      "relation": "CONSUMES",
      "to": "EP-P74-KARAOKE-LYRIC-SANITIZER",
      "note": "Embeds synced LyricsTeleprompter with LyricKaraokeSanitizer and 9-language BantuWordGlossarySheet"
    },
    {
      "from": "apps/vhunambi_client/lib/features/explore/presentation/widgets/create_kinetic_post_sheet.dart",
      "relation": "CONSUMES",
      "to": "EP-P74-SOCIAL-MEDIA-R2-UPLOAD",
      "note": "Replaces _mockPickImage with real gallery image uploads via VhunambiMediaUploadService -> uploadReelMedia"
    },
    {
      "from": "apps/vhunambi_client/lib/features/playlists/presentation/views/playlists_vault_view.dart",
      "relation": "CONSUMES",
      "to": "EP-P74-SOCIAL-MEDIA-R2-UPLOAD",
      "note": "Uploads custom playlist covers to R2 and persists coverImageUrl through PlaylistsNotifier -> PUT/POST /api/playlists"
    },
    {
      "from": "apps/vhunambi_client/lib/features/track/presentation/widgets/track_actions_bar.dart",
      "relation": "ROUTES_TO",
      "to": "EP-P74-REELS-STUDIO-PIPELINE",
      "note": "Exposes visitor-accessible 'Reel' pill launching KineticReelStudioView.show(context, initialTrack: libTrack)"
    }
  ],
  "breakthroughs": [
    "Replaced legacy PaletteGenerator/NetworkImage 4s timer in PillForm and static placeholder genre art across MobileMiniPlayer, DesktopTransportBar, and ExpandedCockpitModal with a unified sync-first PostChromaticPaletteMixin + VhunambiTrackArtwork chromatic stage.",
    "Synced LyricsTeleprompter with playerStateProvider via pure-Dart SyncedLyricTimeline (live highlighting, auto-scroll, tap-to-seek) paired with 9-language BantuLyricTranslationService.lookupWord + Light/Dark glass BantuWordGlossarySheet.",
    "Eliminated CreateKineticPostSheet's _mockPickImage stub and wired unified VhunambiMediaUploadService (EP-P74-SOCIAL-MEDIA-R2-UPLOAD) across Kinetic Posts, Playlists, and Collections, plus visitor-accessible Share as Reel on TrackDetailView.",
    "Cleared all stock Material Icons.* and raw Unicode emojis across player/, track/, playlists/, collections/, and explore/, verified by static analysis and 400/400 passing Flutter tests."
  ],
  "gotchas": [
    "KineticReelStudioView.show accepts named parameters ({LibraryTrack? initialTrack, PublishedClip? initialClip}) — always construct/pass LibraryTrack matching TrackDetailView._openVideoExport.",
    "AppColors defines 7 dynamic *Of(context) helpers (surfaceCanvasOf, surfaceElevatedOf, surfaceSecondaryOf, surfaceModalOf, borderSubtleOf, textPrimaryOf, textSecondaryOf); there is NO textTertiaryOf(context) — use textSecondaryOf(context).withValues(alpha: 0.72).",
    "ExpandedCockpitModal resolves Track lyrics from libraryTracksProvider first and falls back to trackDetailFamilyProvider(track.id) for Explore/Search tracks not saved in the local library vault.",
    "LyricKaraokeSanitizer.cleanLyricsForTeleprompter intentionally preserves structural stanza markers ([Verse 1], [Chorus]) tested in Phase 74/75 while stripping metadata labels and studio cue brackets ([Crisp soft shakers]); use cleanLyricTextForKaraoke for single-line caption playback."
  ]
}
```

# Phase 77 Session Memory (Draft Specification)

- **Stage 2/3 Status:** 5-document specification suite drafted from `docs/audits/PHASE77_CHROMATIC_PLAYER_LYRICS_AND_R2_UPLOADS_AUDIT.md`.
- **Stage 4 Execution Pending:** Run `Pass 1 (M77.1–M77.2)` then `Pass 2 (M77.3–M77.4)` under `/vhunambi-executioner`, verify `G77-01`–`G77-06`, update `"status": "completed"`, and execute `consolidate_memory.mjs`.

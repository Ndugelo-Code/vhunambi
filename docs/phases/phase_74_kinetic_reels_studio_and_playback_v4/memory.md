```json vhunambi-memory
{
  "phase_id": "P74",
  "memory_key": "MEM-P74-KINETIC-REELS-STUDIO-V4",
  "title": "Instagram-Benchmark Full-Screen Kinetic Reels Studio (KineticReelStudioView), Reels Playback V4, Karaoke Lyric Sanitizer & Social Cloud SWR / R2 Media Upload",
  "status": "completed",
  "completed_at": "2026-11-21T09:53:00Z",
  "predecessor_keys": [
    "MEM-P68-HOME-MAIN-ROOM",
    "MEM-P69-KINETIC-POST-FOCUS",
    "MEM-P70-SONG-COCKPIT-VISITOR-PROFILE",
    "MEM-P71-CLOUD-SPINE-CONNECTOME-CLOSURE",
    "MEM-P72-ASSET-VAULT-OWNER-PROFILE-GLASS",
    "MEM-P73-KPOST-CHROMATIC-REACTIONS-HYGIENE"
  ],
  "concept_hubs": [
    "social_graph",
    "media_artwork",
    "mood_taxonomy",
    "ui_surface_std",
    "identity_role",
    "audio_transport",
    "sync_outbox"
  ],
  "consumes": [
    "EP-P70-GLASS-SURFACE",
    "EP-P70-MOOD-TAXONOMY",
    "EP-P68-TRACK-ARTWORK",
    "EP-P68-MINIPLAYER-SUPPRESS",
    "EP-P71-EDGE-SWR-READTHROUGH",
    "EP-P73-POST-CHROMATIC-SYNTH",
    "EP-P73-MULTI-REACTIONS-API",
    "EP-P73-GIF-STICKER-MEDIA",
    "EP-P73-PROFILE-ROUTER"
  ],
  "endpoints": [
    {
      "id": "EP-P74-REELS-STUDIO-PIPELINE",
      "kind": "ui_flow_and_state",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["social_graph", "media_artwork", "audio_transport", "ui_surface_std"],
      "spec_anchor": "docs/phases/phase_74_kinetic_reels_studio_and_playback_v4/design.md#4-pass-2-m743--instagram-benchmark-4-stage-kineticreelstudioview",
      "code_anchor": "apps/vhunambi_client/lib/features/content_studio/presentation/views/kinetic_reel_studio_view.dart",
      "summary": "Full-screen 4-stage Instagram-benchmark Reels Creation Studio unifying Live Camera, Gallery Photo/Video, Vault Song Chromatic Art, Vision AI 9:16 backdrops, ReelAudioPickerSheet, ReelAudioTrimmerSheet, KineticPreviewCanvas, Sovereign Stickers, and opt-in Explore cross-posting.",
      "consumers": [
        "P74:TrendingReelsShelf",
        "P74:ContentStudioDockView",
        "P74:KineticReelsModal"
      ],
      "open_opportunities": "Connect Studio DAW finish flow and TrackDetailView Share-as-Reel directly into KineticReelStudioView.show()"
    },
    {
      "id": "EP-P74-SOCIAL-MEDIA-R2-UPLOAD",
      "kind": "backend_rest_and_client_repo",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["media_artwork", "sync_outbox", "social_graph"],
      "spec_anchor": "docs/phases/phase_74_kinetic_reels_studio_and_playback_v4/design.md#23-worker-rest-routes-social_routests--serverts",
      "code_anchor": "apps/vhunambi_api/src/routes/social_routes.ts",
      "summary": "Authenticated POST /api/social/media/upload endpoint validating MIME allowlist and 25 MB ceiling, persisting camera/gallery video, photo, and audio bytes to Cloudflare R2 (VHUNAMBI_VAULT) under social/<canonicalCreatorId>/ and returning normalized /r2/social/... URLs.",
      "consumers": [
        "P74:HttpSocialRepository",
        "P74:KineticReelPublishView"
      ],
      "open_opportunities": "Reuse POST /api/social/media/upload for CreateKineticPostSheet custom device photo uploads and custom playlist cover uploads"
    },
    {
      "id": "EP-P74-SOCIAL-SWR-READTHROUGH",
      "kind": "backend_persistence",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["sync_outbox", "social_graph"],
      "spec_anchor": "docs/phases/phase_74_kinetic_reels_studio_and_playback_v4/design.md#22-sqlite-vhunambi_dbts--edge-swr-edge_persistence_bridgets-11-parity",
      "code_anchor": "apps/vhunambi_api/src/db/edge_persistence_bridge.ts",
      "summary": "12-second domain-scoped SWR read-through (syncSocialFromCloud) and awaited write-through (upsertPublishedClipAsync, reactToClipAsync) across published_clips, reel_comments, and social_interactions with timestamp-sorted feed projection.",
      "consumers": [
        "P74:social_routes",
        "P74:server_scoped_bypass"
      ],
      "open_opportunities": "Extend scoped SWR read-through to voice_routes (voice_clones/sound_signatures) for 100% Worker route isolation"
    },
    {
      "id": "EP-P74-KARAOKE-LYRIC-SANITIZER",
      "kind": "domain_utility",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["audio_transport", "ui_surface_std"],
      "spec_anchor": "docs/phases/phase_74_kinetic_reels_studio_and_playback_v4/design.md#32-karaoke-lyric-bracket-sanitizer-lyric_karaoke_sanitizerdart",
      "code_anchor": "apps/vhunambi_client/lib/features/content_studio/domain/utils/lyric_karaoke_sanitizer.dart",
      "summary": "Pure Dart lyric sanitizer stripping [Intro], [Verse], [instrument cues], and parenthetical stage directions before word-timestamp tokenization in SongMetadataDna.fromTrackInfo and PublishedClip.effectiveLyrics.",
      "consumers": [
        "P74:SongMetadataDna",
        "P74:PublishedClip",
        "P74:KineticPreviewCanvas"
      ],
      "open_opportunities": "Reuse LyricKaraokeSanitizer in TrackDetailView synchronized lyric sheet and BantuLyricTranslationService"
    }
  ],
  "edges": [
    {
      "from": "apps/vhunambi_client/lib/features/content_studio/presentation/views/kinetic_reel_studio_view.dart",
      "relation": "CONSUMES",
      "to": "EP-P73-POST-CHROMATIC-SYNTH",
      "note": "Synthesizes 9:16 ambient backdrop and glass accent in Stage 1/2 from selected track mood and cover art"
    },
    {
      "from": "apps/vhunambi_client/lib/features/content_studio/presentation/views/kinetic_reel_studio_view.dart",
      "relation": "CONSUMES",
      "to": "EP-P73-GIF-STICKER-MEDIA",
      "note": "Overlays SovereignStickerGraphic onto the 9:16 Reel editor stage and persists stickerId on PublishedClip"
    },
    {
      "from": "apps/vhunambi_client/lib/features/content_studio/presentation/views/kinetic_reel_studio_view.dart",
      "relation": "MUTATES",
      "to": "EP-P68-MINIPLAYER-SUPPRESS",
      "note": "Ref-counts pushedFullScreenOverlayCountProvider so MiniPlayerHost never overlaps the full-screen Reel Studio"
    },
    {
      "from": "apps/vhunambi_client/lib/features/social/presentation/widgets/kinetic_reels_modal.dart",
      "relation": "CONSUMES",
      "to": "EP-P73-MULTI-REACTIONS-API",
      "note": "Wires long-press ReactionTrayOverlay and POST /api/social/clips/:id/react onto the Reels action rail"
    },
    {
      "from": "apps/vhunambi_client/lib/features/social/presentation/widgets/kinetic_reels_modal.dart",
      "relation": "CONSUMES",
      "to": "EP-P73-PROFILE-ROUTER",
      "note": "Routes self creator handle taps to OwnerProfileView and external creators to ArtistProfileView"
    }
  ],
  "breakthroughs": [
    "Unified the orphaned ContentStudioDockView engines (KineticPreviewCanvas, DurationTrimScrubber, AtmosphericEffectsDeck, TypographyPresetPicker) with native camera, image_picker, and video_player inside a 4-stage full-screen KineticReelStudioView while keeping the arm64 APK ~50.5 MiB (no FFmpeg bloat).",
    "Eliminated the 65-second frozen Publish SnackBar and forced 'New track drop' Explore spam by removing SnackBarAction in favor of a 2.5s auto-dismissing glass toast and making 'Also share to Explore Feed' opt-in (false by default).",
    "Hardened pre-existing SECURITY DEFINER financial RPCs (execute_atomic_payout, record_beat_license_atomic, send_cultural_tip_atomic) via dynamic pg_proc regprocedure search_path pinning and service_role EXECUTE restriction."
  ],
  "gotchas": [
    "In Flutter Material 3, passing a SnackBarAction causes ScaffoldMessenger to treat the SnackBar as an interactive accessibility surface that ignores short durations and stays pinned for ~65 seconds; celebratory toasts must omit SnackBarAction.",
    "EdgeIsolateDatabaseEngine.listPublishedClipRows() previously called Array.from(this.publishedClips.values()).reverse() without timestamp sorting, which reverses DESC-ordered Supabase rows after syncSocialFromCloud unless sorted by created_at DESC.",
    "CameraController, VideoPlayerController, and just_audio AudioPlayer invoke native platform MethodChannels that hang or throw in headless flutter test runs unless guarded by an explicit FLUTTER_TEST environment check.",
    "Updating KineticPreviewCanvas's fallback from 'VHUNAMBI 9:16 COVER' to VhunambiTrackArtwork requires realigning kinetic_preview_canvas_test.dart#L32, and purging the raw musical-note emoji from KineticReelsModal's remix toast requires realigning kinetic_reels_modal_test.dart#L144."
  ]
}
```

# Phase 74 Session Memory & Breakthroughs (DRAFT — Stage 2/3)

## 1. Planned Architectural Breakthroughs
- **Full-Screen 4-Stage `KineticReelStudioView` (`EP-P74-REELS-STUDIO-PIPELINE`):** Connects Vhunambi's existing 60 FPS `KineticPreviewCanvas`, `DurationTrimScrubber`, `AtmosphericEffectsDeck`, and `TypographyPresetPicker` into an Instagram-grade creation pipeline with Live Camera, Gallery Photo/Video, Vault Song Audio Trimmer, Sovereign Cultural Stickers, and dedicated Stage 3 Publish screen.
- **Multi-Isolate Social Cloud SWR & Authenticated R2 Upload (`EP-P74-SOCIAL-SWR-READTHROUGH`, `EP-P74-SOCIAL-MEDIA-R2-UPLOAD`):** Brings `social_routes.ts` onto the 12-second domain-scoped Supabase SWR standard (`syncSocialFromCloud`), adds `POST /api/social/clips/:id/react` with legacy `likeCount` preservation, and gates `POST /api/social/media/upload` (`25 MB` max, MIME allowlist) with `sovereignAuthMiddleware`.
- **Karaoke Lyric Sanitizer & Zero-Warning Supabase Hardening (`EP-P74-KARAOKE-LYRIC-SANITIZER`):** Strips `[Intro]` and studio instrument cues before word-timestamp tokenization, fixes Light-Mode dark-on-dark tabs in `KineticReelsModal`, and clears Supabase security/performance linter advisories on the Phase 71 atomic RPCs and `auth_sessions` FK.

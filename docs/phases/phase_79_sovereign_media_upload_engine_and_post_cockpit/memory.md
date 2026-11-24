```json vhunambi-memory
{
  "phase_id": "P79",
  "memory_key": "MEM-P79-SOVEREIGN-MEDIA-UPLOAD-ENGINE",
  "title": "Sovereign Media Upload & Reuse Engine (VhunambiMediaVault), Local-First R2 Sync Queue, CreateKineticPostSheet Glass Cockpit v2 & Reels Studio Layout Repairs",
  "status": "completed",
  "completed_at": "2026-11-24T10:22:00+02:00",
  "predecessor_keys": [
    "MEM-P65-FOUNDATION-CRASH-IMMUNITY",
    "MEM-P68-HOME-MAIN-ROOM",
    "MEM-P70-SONG-COCKPIT-VISITOR-PROFILE",
    "MEM-P74-KINETIC-REELS-STUDIO-V4",
    "MEM-P77-CHROMATIC-PLAYER-LYRICS-R2-UPLOADS",
    "MEM-P78-VAULT-EXPLORE-CONTINUITY-UPLOADS-GLASS-TABS"
  ],
  "concept_hubs": [
    "media_artwork",
    "sync_outbox",
    "social_graph",
    "audio_transport",
    "ui_surface_std",
    "identity_role"
  ],
  "consumes": [
    "EP-P60-HIVE-SYNC-CORE",
    "EP-P65-CRASH-AUDIO-SHIELD",
    "EP-P68-TRACK-ARTWORK",
    "EP-P70-GLASS-SURFACE",
    "EP-P71-EDGE-SWR-READTHROUGH",
    "EP-P74-SOCIAL-MEDIA-R2-UPLOAD",
    "EP-P77-UNIFIED-R2-IMAGE-UPLOAD",
    "EP-P78-CREATOR-REELS-HUB",
    "EP-P78-GLASS-TAB-BAR",
    "EP-P78-REAL-AUDIO-VIDEO-INGEST"
  ],
  "endpoints": [
    {
      "id": "EP-P79-USER-MEDIA-REGISTRY-API",
      "kind": "backend_api_and_schema",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["media_artwork", "sync_outbox", "identity_role"],
      "spec_anchor": "docs/phases/phase_79_sovereign_media_upload_engine_and_post_cockpit/design.md#1-pass-1-m791--backend-durable-media-asset-registry-supabase--appsvhunambi_api",
      "code_anchor": "apps/vhunambi_api/src/routes/media_routes.ts",
      "summary": "Durable Supabase public.user_media_uploads registry + 12s Edge SWR + POST /api/media/upload, GET /api/media/uploads, and owner-isolated DELETE /api/media/uploads/:id backed by Cloudflare R2 VHUNAMBI_VAULT.",
      "consumers": [
        "P79:HttpMediaUploadRepository",
        "P79:MediaUploadQueueNotifier",
        "P79:social_routes.ts"
      ],
      "open_opportunities": "Connect Phase 80 VhunambiVisualDnaMatcher to GET /api/media/uploads?kind=image,video for automatic chorus mood matching"
    },
    {
      "id": "EP-P79-MEDIA-UPLOAD-ENGINE",
      "kind": "client_vault_and_queue",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["media_artwork", "sync_outbox", "audio_transport"],
      "spec_anchor": "docs/phases/phase_79_sovereign_media_upload_engine_and_post_cockpit/design.md#2-pass-1-m792--client-vhunambimediavault-resumable-sync-queue--studio-real-time-playback",
      "code_anchor": "apps/vhunambi_client/lib/features/media/presentation/providers/media_upload_queue_provider.dart",
      "summary": "Local-first SovereignMediaStorageService + multi-tenant Hive vhunambi_uploads_v1 + resumable MediaUploadQueueNotifier with Dio onSendProgress (0-100%), cellular drop failure preservation (zero fake /r2/social/local/ 404 URLs), local VhunambiTrackArtwork/AudioSourceResolver priority, and SafeAudioOrchestrator studio playback.",
      "consumers": [
        "P79:UploadsVaultView",
        "P79:CreateKineticPostSheet",
        "P79:ReelAudioPickerSheet",
        "P79:DirectDawVocalUploadSheet",
        "P79:KineticReelStudioView",
        "P79:KineticReelPublishView"
      ],
      "open_opportunities": "Wire voice clone raw mic takes and custom ArtistProfileView banner uploads into mediaUploadQueueProvider"
    },
    {
      "id": "EP-P79-POST-COCKPIT-V2",
      "kind": "ui_surface",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["social_graph", "media_artwork", "ui_surface_std"],
      "spec_anchor": "docs/phases/phase_79_sovereign_media_upload_engine_and_post_cockpit/design.md#31-createkineticpostsheet-glass-cockpit-v2-create_kinetic_post_sheetdart",
      "code_anchor": "apps/vhunambi_client/lib/features/explore/presentation/widgets/create_kinetic_post_sheet.dart",
      "summary": "Glassmorphic CreateKineticPostSheet v2 with above-the-fold live Image.file preview carousel, upload progress/retry ring, From My Uploads picker, VhunambiGlassTabBar sound tabs, and SafeAudioOrchestrator audio auditioning.",
      "consumers": [
        "P79:ExploreView",
        "P79:KineticPostComposerBar",
        "P79:UploadsVaultView"
      ],
      "open_opportunities": "Support multi-photo carousel swipe-reorder and crop focal-point pinning in Phase 80"
    }
  ],
  "edges": [
    {
      "from": "apps/vhunambi_client/lib/features/media/presentation/providers/media_upload_queue_provider.dart",
      "relation": "CONSUMES",
      "to": "EP-P79-USER-MEDIA-REGISTRY-API",
      "note": "Streams staged local media to POST /api/media/upload with 90s sendTimeout and syncs cross-device uploads via GET /api/media/uploads"
    },
    {
      "from": "apps/vhunambi_client/lib/features/content_studio/presentation/views/kinetic_reel_studio_view.dart",
      "relation": "CONSUMES",
      "to": "EP-P65-CRASH-AUDIO-SHIELD",
      "note": "Acquires AudioEngineSlot.studioPreview on SafeAudioOrchestrator for real-time looped studio audio playback and releases in dispose()"
    },
    {
      "from": "apps/vhunambi_client/lib/features/explore/presentation/widgets/create_kinetic_post_sheet.dart",
      "relation": "CONSUMES",
      "to": "EP-P79-MEDIA-UPLOAD-ENGINE",
      "note": "Stages picked photos locally for instant above-the-fold preview and reuses audio/images from My Uploads"
    },
    {
      "from": "apps/vhunambi_client/lib/features/library/presentation/views/uploads_vault_view.dart",
      "relation": "CONSUMES",
      "to": "EP-P78-GLASS-TAB-BAR",
      "note": "Renders All | Audio | Video | Images filter strip and surfaces LibraryCategory.uploads in LibraryCategoryRail"
    }
  ],
  "breakthroughs": [
    "Shipped durable Supabase public.user_media_uploads DDL/RLS + 1:1 SQLite/EdgeIsolateDatabaseEngine 12s SWR proxy + /api/media/* routes (and backward-compatible /api/social/media/upload indexing), verified by 32/32 backend suites (npx tsc --noEmit + npm test).",
    "Shipped local-first SovereignMediaStorageService (27th Hive box vhunambi_uploads_v1 with per-creator tenant keys) + MediaUploadQueueNotifier (90s sendTimeout, Dio onSendProgress, zero fake /r2/social/local/ URL masking on cellular drops) + local FileImage/Uri.file priority across VhunambiTrackArtwork and AudioSourceResolver + SafeAudioOrchestrator studio playback.",
    "Shipped CreateKineticPostSheet Glass Cockpit v2 (above-the-fold live preview carousel, From My Uploads reuse sheet, VhunambiGlassTabBar audio deck & audition player), LibraryCategory.uploads + UploadsVaultView, 5-tab ReelAudioPickerSheet with legacy 'AI Studio' scrubbing, Dark Mode _PostKineticReelCard, bounded tool rail, SafeArea dual-handle trimmer, and <=34% Stage 2 drawer with draggable stickers (+687 regression tests + Phase 79 suite green, 0 flutter analyze issues, 0 STD-UIUX-001 violations)."
  ],
  "gotchas": [
    "Registering vhunambi_uploads_v1 in SovereignHiveBootstrapService.tier1BoxKeys increments tier1BoxKeys from 17 to 18 and totalDeclaredBoxes from 26 to 27; update test/features/storage/sovereign_hive_bootstrap_test.dart in Pass 1.",
    "Never use PhosphorIconsRegular.sparkle as the category icon for LibraryCategory.uploads in LibraryCategoryRail because library_view_test.dart#L79 asserts find.byIcon(PhosphorIconsRegular.sparkle) findsOneWidget on mobile; use AppIcons.upload (uploadSimple).",
    "Under FLUTTER_TEST (FakeAsync), async dart:io file writes (await file.writeAsBytes / await file.readAsBytes) stall pumpAndSettle() indefinitely because FakeAsync does not pump IO isolates; always use writeAsBytesSync / readAsBytesSync / deleteSync when SovereignMediaStorageService.isTestEnv is true.",
    "EdgeIsolateDatabaseEngine uses awaitWriteThrough(label, async (driver) => ..., cOrEnv) (not awaitCloudWrite), PlayerStateNotifier.pause() returns void (never await it), and CreateKineticPostSheet's 3-button visual strip must use Wrap instead of Row+Expanded to avoid 1.9px overflow at 360dp.",
    "Always apply 20261124000001_phase79_user_media_uploads.sql to Supabase Cloud via supabase_mcp BEFORE deploying vhunambi-api to Cloudflare Workers so PostgREST never returns 404 PGRST205.",
    "Supabase Performance Advisor 0003_auth_rls_initplan requires wrapping ONLY auth.jwt() in SELECT — use ((SELECT auth.jwt()) ->> 'creator_id') = creator_id rather than (SELECT auth.jwt() ->> 'creator_id') = creator_id so all RLS policies pass with 0 warnings."
  ]
}
```

# Phase 79 Session Memory (Completed)

> Stage 4 executed and verified 100% across Pass 1 (`M79.1–M79.2`) and Pass 2 (`M79.3–M79.4`): `apps/vhunambi_api` (`npx tsc --noEmit` + `32/32` suites), `apps/vhunambi_client` (`flutter analyze` `0` issues, `STD-UIUX-001` `0` violations, `+687` full domain regression sweep + `storage`/`library`/`phase74`/`phase77`/`phase78` green). Deployed to Supabase Cloud (`public.user_media_uploads`, 4 RLS policies, 0 security/performance advisor warnings) and Cloudflare Workers (`vhunambi-api`).

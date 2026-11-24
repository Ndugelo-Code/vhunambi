# Phase 79 Requirements Specification (`requirements.md`)

**Document ID:** `VHUNAMBI-SPEC-P79-REQUIREMENTS-V1`  
**Phase ID:** `P79` — Sovereign Media Upload & Reuse Engine (`VhunambiMediaVault`), Local-First R2 Sync Queue, `CreateKineticPostSheet` Glass Cockpit v2 & Reels Studio Layout Repairs  
**Methodology:** EARS (Easy Approach to Requirements Syntax) & RFC-2119 (`SHALL`, `MUST`, `WHEN`, `WHILE`, `IF...THEN`, `WHERE`)  
**Audit Trace:** [`PHASE79_SOVEREIGN_MEDIA_UPLOAD_ENGINE_AND_POST_COCKPIT_AUDIT.md`](../../audits/PHASE79_SOVEREIGN_MEDIA_UPLOAD_ENGINE_AND_POST_COCKPIT_AUDIT.md) (`AUDIT-CLIENT-079`)

---

## 1. Document Scope & Consumed Connectome Primitives

Phase 79 builds directly upon ten verified `CONNECTED_EXTENSIBLE` primitives from the Vhunambi Connectome:
- `EP-P74-SOCIAL-MEDIA-R2-UPLOAD` (`apps/vhunambi_api/src/routes/social_routes.ts`)
- `EP-P77-UNIFIED-R2-IMAGE-UPLOAD` (`apps/vhunambi_client/lib/core/media/vhunambi_media_upload_service.dart`)
- `EP-P78-REAL-AUDIO-VIDEO-INGEST` (`direct_daw_vocal_upload_sheet.dart`, `kinetic_reel_studio_view.dart`)
- `EP-P78-GLASS-TAB-BAR` (`apps/vhunambi_client/lib/core/widgets/vhunambi_glass_tab_bar.dart`)
- `EP-P78-CREATOR-REELS-HUB` (`apps/vhunambi_client/lib/features/library/presentation/views/reels_vault_view.dart`)
- `EP-P68-TRACK-ARTWORK` (`apps/vhunambi_client/lib/core/widgets/vhunambi_track_artwork.dart`)
- `EP-P70-GLASS-SURFACE` (`apps/vhunambi_client/lib/core/widgets/vhunambi_glass_surface.dart`)
- `EP-P65-CRASH-AUDIO-SHIELD` (`apps/vhunambi_client/lib/core/resilience/safe_audio_orchestrator.dart`)
- `EP-P60-HIVE-SYNC-CORE` (`apps/vhunambi_client/lib/core/storage/sovereign_hive_bootstrap_service.dart`)
- `EP-P71-EDGE-SWR-READTHROUGH` (`apps/vhunambi_api/src/db/edge_persistence_bridge.ts`)

---

## 2. Pillar 1 — Backend Durable Media Asset Registry (`REQ-P79-BE-*`)

### `REQ-P79-BE-01` — Supabase `public.user_media_uploads` DDL & RLS Hardening
- **THE SYSTEM SHALL** ship idempotent migration `supabase/migrations/20261124000001_phase79_user_media_uploads.sql` creating `public.user_media_uploads` with columns:
  - `id TEXT PRIMARY KEY`, `creator_id TEXT NOT NULL`, `media_kind TEXT NOT NULL CHECK (media_kind IN ('audio', 'video', 'image'))`, `title TEXT NOT NULL`, `filename TEXT NOT NULL`, `mime_type TEXT NOT NULL`, `size_bytes BIGINT NOT NULL`, `duration_ms INTEGER`, `width INTEGER`, `height INTEGER`, `r2_key TEXT NOT NULL`, `remote_url TEXT NOT NULL`, `thumbnail_url TEXT`, `source_surface TEXT NOT NULL DEFAULT 'vault'`, `created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()`, `deleted_at TIMESTAMPTZ`.
- **THE SYSTEM SHALL** create partial index `idx_user_media_uploads_creator_created ON public.user_media_uploads (creator_id, created_at DESC) WHERE deleted_at IS NULL` and execute `ALTER TABLE public.user_media_uploads ENABLE ROW LEVEL SECURITY;` with owner-scoped read/write policies and zero `anon` write grants (`0` Supabase Security Advisor warnings).

### `REQ-P79-BE-02` — 1:1 `EdgeIsolateDatabaseEngine` & `VhunambiDatabase` SWR Parity
- **THE SYSTEM SHALL** create the matching `user_media_uploads` SQLite table in `vhunambi_db.ts` and implement identical 1:1 method signatures across both `EdgeIsolateDatabaseEngine` (`edge_persistence_bridge.ts`) and `VhunambiDatabase` (`vhunambi_db.ts`):
  - `recordUserMediaUpload(row: UserMediaUploadRecord, skipMirror = false): UserMediaUploadRecord`
  - `recordUserMediaUploadAsync(row: UserMediaUploadRecord, cOrEnv?: unknown): Promise<UserMediaUploadRecord>`
  - `listUserMediaUploads(creatorId: string, kind?: 'audio' | 'video' | 'image'): UserMediaUploadRecord[]`
  - `getUserMediaUploadById(id: string): UserMediaUploadRecord | null`
  - `syncUserMediaUploadsFromCloud(creatorId: string, cOrEnv?: unknown, force = false): Promise<UserMediaUploadRecord[]>` (`12_000 ms` SWR TTL keyed by `media_uploads:${cid}`, bounded by `withTimeoutResult(..., 3500)`, **never** stamping `domainHydratedAtMs` on timeout or error)
  - `deleteUserMediaUpload(id: string, creatorId?: string, skipMirror = false): boolean`
  - `deleteUserMediaUploadAsync(id: string, creatorId?: string, cOrEnv?: unknown): Promise<boolean>`

### `REQ-P79-BE-03` — `/api/media/*` REST Contract & `/api/social/media/upload` Compatibility
- **THE SYSTEM SHALL** mount `mediaRoutes` (`apps/vhunambi_api/src/routes/media_routes.ts`) at `/api/media` and `/api/v1/media` in `server.ts` and add both prefixes to `hasScopedReadThrough`.
- **WHEN** `POST /api/media/upload` receives an authenticated multipart or raw binary upload (`<= 25 MB`, MIME in `audio/{mpeg,mp4,wav,x-wav,wave,aac,ogg}`, `video/{mp4,quicktime,webm}`, `image/{jpeg,png,webp}`), **THE SYSTEM SHALL** write bytes to R2 (`VHUNAMBI_VAULT`), await `recordUserMediaUploadAsync`, and return `201` `{ success: true, asset, key, url, contentType, size }`.
- **WHEN** `GET /api/media/uploads` is called (with optional `?creatorId=...&kind=audio|video|image`), **THE SYSTEM SHALL** enforce `assertTenantCreatorAccess`, await `syncUserMediaUploadsFromCloud`, and return `200` `{ success: true, creatorId, uploads, count }`.
- **WHEN** `DELETE /api/media/uploads/:id` is called by a non-owner tenant, **THE SYSTEM SHALL** return `403` `{ error: ..., code: 'TENANT_FORBIDDEN' }`; when called by the owner, **THE SYSTEM SHALL** await `deleteUserMediaUploadAsync` and return `200` `{ success: true, id }`.
- **WHEN** legacy `POST /api/social/media/upload` is called, **THE SYSTEM SHALL** preserve its existing `201` response shape while also recording the uploaded asset via `recordUserMediaUploadAsync` (`sourceSurface: 'social'`) so Reel and Post uploads automatically populate `My Uploads`.

---

## 3. Pillar 2 — Local-First `VhunambiMediaVault`, Resumable Queue & Studio Playback (`REQ-P79-VLT-*`, `REQ-P79-AUD-*`)

### `REQ-P79-VLT-01` — Multi-Tenant `vhunambi_uploads_v1` Hive Box & Local Sandbox Staging
- **THE SYSTEM SHALL** register `AppConstants.mediaUploadsBoxKey = 'vhunambi_uploads_v1'` in `SovereignHiveBootstrapService.tier1BoxKeys` (`18` Tier-1 boxes, `27` total boxes) and clear tenant L1 upload memory inside `SovereignDomainStorageMode.clearTenantMemory()`.
- **WHEN** a user selects or records audio, video, or image media, `SovereignMediaStorageService` **SHALL** copy the payload into `getApplicationDocumentsDirectory()/vhunambi_media/{audio,video,images}/<assetId>.<ext>` (using a deterministic non-blocking temp/memory directory when `FLUTTER_TEST` is active) and persist an `UploadedMediaAsset` scoped strictly to `canonicalCreatorId`.

### `REQ-P79-VLT-02` — Resumable `MediaUploadQueueNotifier` with Progress & Zero Fake-URL Masking
- **WHEN** `mediaUploadQueueProvider.notifier` stages a media file, **THE SYSTEM SHALL** immediately emit the `UploadedMediaAsset` with `status: MediaUploadStatus.queued` and a valid `localFilePath`, then stream `POST /api/media/upload` via `Dio` with `connectTimeout: 15s`, `sendTimeout: 90s`, `receiveTimeout: 30s`, and live `onSendProgress` updating `asset.progress` (`0.0 .. 1.0`).
- **IF** cellular connectivity drops, times out, or returns `>= 400`, **THE SYSTEM SHALL** transition the asset to `MediaUploadStatus.failed` with `remoteUrl: null` (NEVER fabricating a fake `/r2/social/local/...` URL!), retain the staged local file in `vhunambi_uploads_v1`, and expose `retryUpload(assetId)`, `retryAllPending()`, `deleteUpload(assetId)`, and `syncFromCloud()`.
- **THE SYSTEM SHALL** also update `HttpSocialRepository.uploadReelMedia` to use `sendTimeout: 90s`, `receiveTimeout: 30s`, optional `onSendProgress`, and stop masking real network failures into `/r2/social/local/...` URLs (retaining synthetic URLs strictly when `_shouldSkipNetwork` is `true` in `FLUTTER_TEST`).

### `REQ-P79-AUD-01` — Local File Priority in `VhunambiTrackArtwork` & `AudioSourceResolver`
- **WHEN** `VhunambiTrackArtwork` receives a `coverUrl` starting with `file://` or matching an existing local filesystem path (`!kIsWeb && File(path).existsSync()`), **THE SYSTEM SHALL** render `Image.file(File(path), fit: BoxFit.cover)` immediately before attempting `Image.network` or genre asset fallbacks.
- **WHEN** `AudioSourceResolver.resolveSource(track)` evaluates a track whose `audioUrl` (or matched `LibraryTrack.localAudioFilePath`) points to an existing readable unencrypted local file (`file://` or absolute path), **THE SYSTEM SHALL** return `ResolvedAudioSource(uri: Uri.file(path), isLocalFile: true, localFilePath: path)` *before* forced-offline checks or remote HTTPS fallback.

### `REQ-P79-AUD-02` — Real-Time Studio Audio Playback & Auto-Vaulting of Imported Audio
- **WHEN** a user imports audio in `ReelAudioPickerSheet` (`['mp3', 'm4a', 'wav', 'aac', 'ogg']`) or `DirectDawVocalUploadSheet`, **THE SYSTEM SHALL** stage and enqueue the file via `mediaUploadQueueProvider` AND upsert a playable `LibraryTrack` (`localAudioFilePath = asset.localFilePath`, `creatorId = activeOwner`, `isInstrumental: false`) into `libraryTracksProvider` so the song is immediately playable offline and reusable in both `My Vault` and `My Uploads`.
- **WHILE** `KineticReelStudioView` is in Stage 1 (`capture`) or Stage 2 (`editor`) and `!_isTestEnv`, **THE SYSTEM SHALL** acquire `AudioEngineSlot.studioPreview` via `SafeAudioOrchestrator.instance` (pausing `playerStateProvider` if playing), load `_audio.localFilePath ?? _audio.audioUrl` into a `just_audio` `AudioPlayer`, loop `[audioStartMs, audioEndMs]`, feed live `isPlaying` and `playbackPositionSec` into `KineticPreviewCanvas`, pause on modal sheets/Stage 3, and release/dispose cleanly in `dispose()`.

### `REQ-P79-AUD-03` — Stage 3 Real Video Poster / Photo Preview, Progress Bar & Cellular Drop Recovery
- **WHEN** `KineticReelPublishView` mounts with `mediaKind` in `{'camera_video', 'gallery_video'}` and a local video path, **THE SYSTEM SHALL** render a paused first-frame `VideoPlayerController` preview (`Key('publish_video_poster_preview')`, with deterministic `FLUTTER_TEST` widget fallback); when `mediaKind == 'gallery_photo'`, it **SHALL** render `Image.file` / `Image.memory` (`Key('publish_photo_poster_preview')`).
- **WHILE** `_isPublishing` is `true`, `KineticReelPublishView` **SHALL** display a live percentage progress indicator (`Key('reel_publish_progress_bar')`, `0% -> 100%`). **IF** upload/publish fails due to network drop, **THE SYSTEM SHALL** keep the recorded media staged in `mediaUploadQueueProvider`, surface a non-destructive error banner with a `Retry Publish` button (`Key('reel_publish_retry_btn')`), and never discard the recording.

---

## 4. Pillar 3 — `CreateKineticPostSheet` Glass Cockpit v2 & Universal `My Uploads` Hub (`REQ-P79-KPOST-*`, `REQ-P79-HUB-*`)

### `REQ-P79-KPOST-01` — `CreateKineticPostSheet` Glass Cockpit v2 & Above-the-Fold Media Carousel
- **THE SYSTEM SHALL** migrate `CreateKineticPostSheet` fully onto `VhunambiGlassSurface(enableLiveBlur: false)` and `AppColors.*Of(context)` tokens while preserving legacy test keys (`kpost_pick_photo_btn`, `kpost_upload_photo_btn`, `kpost_max_images_badge`, `kpost_aspect_ratio_selector`, `kpost_publish_submit_btn`, `kpost_caption_input`, `kpost_vision_ai_btn`, `kpost_vision_prompt_input`, `kpost_trim_*`).
- **WHEN** `_attachedImages.isNotEmpty`, **THE SYSTEM SHALL** mount `Key('kpost_media_preview_carousel')` **immediately below the caption input** (above the scroll fold!), rendering each attached photo via local `Image.file` / `VhunambiTrackArtwork`, aspect-ratio framing (`1:1`, `4:5`, `16:9`), live upload progress ring (`0%–100%`) or Retry badge, `×` remove button, plus a `From My Uploads` picker trigger (`Key('kpost_pick_from_uploads_btn')`).

### `REQ-P79-KPOST-02` — Interactive Audio Attachment Card & Audition Player
- **THE SYSTEM SHALL** replace the bare `PopupMenuButton` sound dropdown in `CreateKineticPostSheet` with `VhunambiGlassTabBar` (`My Uploads | My Vault | Trending | Grooves`) and an interactive frosted `Key('kpost_audio_attachment_card')` featuring `VhunambiTrackArtwork`, track/creator metadata, a `SafeAudioOrchestrator`-guarded play/pause audition button (`Key('kpost_audio_audition_btn')`, `FLUTTER_TEST` safe), hook trim pills, and an inline track selector list/sheet.

### `REQ-P79-HUB-01` — `LibraryCategory.uploads` & `UploadsVaultView`
- **THE SYSTEM SHALL** add `LibraryCategory.uploads` across all 5 coupled library files (`library_models.dart`, `library_providers.dart`, `library_view.dart`, `library_category_rail.dart` using `AppIcons.upload`, and `library_empty_state.dart`) and mount `UploadsVaultView` (`Key('library_uploads_vault_view')`) with `All | Audio | Video | Images` filter pills, live status badges (`Synced`, `Uploading %`, `Retry`), play/preview, `Use in Reel`, `Use in Post`, and `Delete`.

### `REQ-P79-HUB-02` — `ReelAudioPickerSheet` `VhunambiGlassTabBar` & Legacy `'AI Studio'` Purge
- **THE SYSTEM SHALL** replace the truncating 4-tab `TabBar` in `ReelAudioPickerSheet` with scrollable `VhunambiGlassTabBar` (`My Vault | My Uploads | Trending | Saved | Vibes`), render `VhunambiTrackArtwork` on every row, and sanitize persisted `'AI Studio'` / `'@aistudio'` creator strings inside both `LibraryTracksNotifier.hydrateFromLocalBox` and `ReelStudioAudioSelection.fromLibraryTrack` to the active creator's display name/handle.

---

## 5. Pillar 4 — Reels Studio & Dark-Mode Polish (`REQ-P79-STU-*`) & NFRs (`REQ-P79-NFR-*`)

### `REQ-P79-STU-01` — Dark-Mode `_PostKineticReelCard` Contrast (`UPL-04`)
- **THE SYSTEM SHALL** replace static `AppColors.surfaceElevated` / `surfaceCanvas` on `_PostKineticReelCard` in `trending_reels_shelf.dart` with `VhunambiGlassSurface(variant: VhunambiGlassVariant.card, enableLiveBlur: false, tintAccent: AppColors.brandPrimary)` and migrate all `AppColors.*` usages in `trending_reels_shelf.dart` to `*Of(context)`.

### `REQ-P79-STU-02` — Bounded Scrollable Right Rail & SafeArea Dual-Handle Trimmer (`UPL-03`)
- **THE SYSTEM SHALL** bound `KineticReelStudioView`'s tool rail inside `Positioned(top: 76, bottom: 156, right: ..., left: ...)` with `SingleChildScrollView(physics: BouncingScrollPhysics())` so bottom rail buttons never collide with `_buildCaptureBottomDeck`.
- **THE SYSTEM SHALL** open `ReelAudioTrimmerSheet` with `isScrollControlled: true`, wrap its content in `SafeArea(top: false)` + `SingleChildScrollView`, provide interactive dual start/end range handles (`RangeSlider` + `Key('reel_audio_trim_range_slider')` alongside backward-compatible `Key('reel_audio_trim_slider')`), and keep `Key('reel_audio_trimmer_done_btn')` (`Use Hook Segment`) 100% unclipped on `360x740` viewports.

### `REQ-P79-STU-03` — Compact `<= 34%` Stage 2 Glass Drawer & Draggable Canvas Sticker (`UPL-06`)
- **THE SYSTEM SHALL** constrain `KineticReelStudioView._buildEditorBottomDeck()` inside `ConstrainedBox(constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.34))` styled with `VhunambiGlassSurface`, compact horizontal scrolling in `TypographyPresetPicker` and `AtmosphericEffectsDeck`, and wrap the Stage 2 `SovereignStickerGraphic` in a pan-enabled `GestureDetector` updating normalized/pixel `_stickerOffset` clamped within the safe canvas area.

### `REQ-P79-NFR-01..04` — Non-Functional Invariants
- **`REQ-P79-NFR-01` (`STD-UIUX-001`):** Zero stock `Icons.*` and zero raw Unicode emojis in any new or touched file.
- **`REQ-P79-NFR-02` (60 FPS Glass):** `enableLiveBlur: false` on all list/carousel/rail `VhunambiGlassSurface` instances.
- **`REQ-P79-NFR-03` (Zero Native Bloat):** Zero FFmpeg or native C++ media plugins added to `pubspec.yaml`.
- **`REQ-P79-NFR-04` (`FLUTTER_TEST` Isolation):** Zero unguarded platform channel calls or dangling timers in widget tests.

---

## 6. Granular Requirement-to-Test Traceability Matrix

| Requirement ID | Target File(s) | Automated Verification Test Case |
| :--- | :--- | :--- |
| `REQ-P79-BE-01..03` | `20261124000001_phase79_user_media_uploads.sql`, `vhunambi_db.ts`, `edge_persistence_bridge.ts`, `media_routes.ts`, `social_routes.ts`, `server.ts` | `apps/vhunambi_api/test/phase79_media_uploads_registry.test.ts` (upload, SWR list, kind filter, `403 TENANT_FORBIDDEN`, `413`/`415`, `/api/social/media/upload` parity) |
| `REQ-P79-VLT-01..02` | `uploaded_media_asset.dart`, `sovereign_media_storage_service.dart`, `media_upload_queue_provider.dart`, `sovereign_hive_bootstrap_service.dart` | `phase79_media_upload_engine_and_post_cockpit_test.dart`: local staging, tenant isolation, `0.0->1.0` progress, cellular failure (`remoteUrl == null`, zero `/r2/social/local/`), `retryUpload` -> `synced` |
| `REQ-P79-AUD-01..03` | `vhunambi_track_artwork.dart`, `audio_source_resolver.dart`, `kinetic_reel_studio_view.dart`, `kinetic_reel_publish_view.dart` | `phase79_media_upload_engine_and_post_cockpit_test.dart`: local `AudioSourceResolver` file URI priority, `VhunambiTrackArtwork` local `Image.file`, Stage 3 poster preview + progress + `Retry Publish` |
| `REQ-P79-KPOST-01..02` | `create_kinetic_post_sheet.dart` | `phase79_media_upload_engine_and_post_cockpit_test.dart` + `phase73` + `phase77`: `kpost_media_preview_carousel` above fold, `From My Uploads`, `kpost_audio_attachment_card` |
| `REQ-P79-HUB-01..02` | `library_*.dart`, `uploads_vault_view.dart`, `reel_audio_picker_sheet.dart` | `phase79_media_upload_engine_and_post_cockpit_test.dart` + `library_view_test.dart`: `LibraryCategory.uploads`, `UploadsVaultView`, 5-tab `ReelAudioPickerSheet` & `'AI Studio'` scrub |
| `REQ-P79-STU-01..03` | `trending_reels_shelf.dart`, `kinetic_reel_studio_view.dart`, `reel_audio_trimmer_sheet.dart`, `typography_preset_picker.dart`, `atmospheric_effects_deck.dart` | `phase79_media_upload_engine_and_post_cockpit_test.dart`: Dark Mode `_PostKineticReelCard`, bounded rail, `360x740` trimmer clearance + dual handles, Stage 2 `<= 34%` height + sticker drag |

# Phase 79 Execution Plan (`tasks.md`)

**Document ID:** `VHUNAMBI-SPEC-P79-TASKS-V1`  
**Phase ID:** `P79` — Sovereign Media Upload & Reuse Engine (`VhunambiMediaVault`), Local-First R2 Sync Queue, `CreateKineticPostSheet` Glass Cockpit v2 & Reels Studio Layout Repairs  
**Execution Cadence:** Strictly two self-contained sequential passes (`Pass 1: M79.1–M79.2`, verify Pass 1 gates 100%, then `Pass 2: M79.3–M79.4`, verify full gates `G79-01`–`G79-06` + `memory.md` SLEEP). Zero cross-pass compile dependencies.

---

## 1. Master Milestone Roadmap

```text
PASS 1 (Durable Backend Media Registry + Local-First VhunambiMediaVault & Studio Playback)
 ├── M79.1: Supabase `user_media_uploads` DDL/RLS, 12s SWR 1:1 DB Proxy & `/api/media/*` Routes
 └── M79.2: Client `VhunambiMediaVault` (Hive 27th Box), Resumable `MediaUploadQueue`, Local Art/Audio & Studio Player
       │
       ▼ [PASS 1 GATE: `npx tsc --noEmit` + 32/32 API suites + `dart analyze` + Storage & Pass 1 Flutter suites 100% GREEN]
       │
PASS 2 (`CreateKineticPostSheet` Glass Cockpit v2, `Uploads` Vault Hub & Reels Studio Layout Repairs)
 ├── M79.3: `CreateKineticPostSheet` Glass Cockpit v2, `LibraryCategory.uploads` (5 files + View) & 5-Tab Audio Picker
 └── M79.4: Dark-Mode Post Reel Card, Bounded Rail, Dual-Handle SafeArea Trimmer, <=34% Stage 2 Drawer & Full Regression
       │
       ▼ [PASS 2 GATE: `G79-01`..`G79-06` + `memory.md` `"completed"` + `consolidate_memory.mjs` (`0 OPEN`)]
```

---

## 2. Pass 1 — `M79.1`: Backend Durable Media Asset Registry (`REQ-P79-BE-01..03`)

- [x] **T79.1.1 — Author Supabase Migration `20261124000001_phase79_user_media_uploads.sql` (`REQ-P79-BE-01`)**
  - **Target:** `supabase/migrations/20261124000001_phase79_user_media_uploads.sql` (new)
  - **Action:** Create idempotent `public.user_media_uploads` table, partial index `idx_user_media_uploads_creator_created`, `ENABLE ROW LEVEL SECURITY`, and owner-scoped `authenticated` policies (`(SELECT auth.jwt() ->> 'creator_id') = creator_id`) with zero `anon` write grants.
  - **Acceptance:** Valid SQL DDL with `0` Supabase Security/Performance Advisor warnings when applied.

- [x] **T79.1.2 — Implement 1:1 SQLite & Edge SWR Media Upload Methods (`REQ-P79-BE-02`)**
  - **Target:** `apps/vhunambi_api/src/db/edge_persistence_bridge.ts`, `apps/vhunambi_api/src/db/vhunambi_db.ts`
  - **Action:** Add `UserMediaUploadRecord`, `normalizeUserMediaUploadRow`, SQLite `CREATE TABLE IF NOT EXISTS user_media_uploads`, and 1:1 matching methods (`recordUserMediaUpload`, `recordUserMediaUploadAsync`, `getUserMediaUploadById`, `listUserMediaUploads`, `syncUserMediaUploadsFromCloud` with `12_000 ms` SWR TTL & `3500 ms` timeout guard, `deleteUserMediaUpload`, `deleteUserMediaUploadAsync`) on both `EdgeIsolateDatabaseEngine` and `VhunambiDatabase`.
  - **Acceptance:** `npx tsc --noEmit` passes with `0` errors across Node SQLite and simulated `workerd` Edge modes.

- [x] **T79.1.3 — Ship `/api/media/*` Router & Backward-Compatible `/api/social/media/upload` Indexing (`REQ-P79-BE-03`)**
  - **Target:** `apps/vhunambi_api/src/routes/media_routes.ts` (new), `apps/vhunambi_api/src/routes/social_routes.ts`, `apps/vhunambi_api/src/server.ts`
  - **Action:** Implement `POST /api/media/upload`, `GET /api/media/uploads` (`?kind=audio|video|image`), and `DELETE /api/media/uploads/:id` (`403 TENANT_FORBIDDEN` on cross-tenant delete); mount at `/api/media` and `/api/v1/media` in `server.ts` + add to `hasScopedReadThrough`; record social uploads into `user_media_uploads` inside `social_routes.ts` while preserving its `201` response contract.
  - **Acceptance:** Both `/api/media/*` and `/api/social/media/upload` persist durable upload records backed by R2 `VHUNAMBI_VAULT`.

- [x] **T79.1.4 — Add Backend Verification Suite `phase79_media_uploads_registry.test.ts` (`G79-02`)**
  - **Target:** `apps/vhunambi_api/test/phase79_media_uploads_registry.test.ts` (new), `apps/vhunambi_api/package.json`
  - **Action:** Test multipart + binary uploads (`audio/wav`, `video/mp4`, `image/png`), cross-isolate `syncUserMediaUploadsFromCloud`, `kind` filtering, `403 TENANT_FORBIDDEN` delete guard, `413`/`415` rejections, and `/api/social/media/upload` indexing; append to `package.json` `test` script (`32/32`).
  - **Acceptance:** `cd apps/vhunambi_api && npx tsc --noEmit && npm test` passes 100%.

---

## 3. Pass 1 — `M79.2`: Client Local-First `VhunambiMediaVault`, Sync Queue & Studio Real-Time Playback (`REQ-P79-VLT-*`, `REQ-P79-AUD-*`)

- [x] **T79.2.1 — Register Multi-Tenant `vhunambi_uploads_v1` Hive Box & `SovereignMediaStorageService` (`REQ-P79-VLT-01`)**
  - **Target:** `apps/vhunambi_client/lib/features/media/domain/models/uploaded_media_asset.dart` (new), `apps/vhunambi_client/lib/core/media/sovereign_media_storage_service.dart` (new), `apps/vhunambi_client/lib/core/constants/app_constants.dart`, `apps/vhunambi_client/lib/core/storage/sovereign_hive_bootstrap_service.dart`, `apps/vhunambi_client/lib/core/storage/sovereign_domain_repositories.dart`, `apps/vhunambi_client/test/features/storage/sovereign_hive_bootstrap_test.dart`
  - **Action:** Create `UploadedMediaAsset` and `SovereignMediaStorageService` (`AppDocs/vhunambi_media/{audio,video,images}/<id>.<ext>`, `FLUTTER_TEST`-safe temp staging, `${canonicalCreatorId}::${id}` Hive partitioning); register `AppConstants.mediaUploadsBoxKey` in `tier1BoxKeys` (`18` Tier-1, `27` total boxes); wire `clearTenantSessionMemory()` into `SovereignDomainStorageMode`; update box count assertions (`17 -> 18`, `26 -> 27`) in `sovereign_hive_bootstrap_test.dart`.
  - **Acceptance:** `flutter test test/features/storage/sovereign_hive_bootstrap_test.dart --no-pub` passes 100%.

- [x] **T79.2.2 — Build Resumable `MediaUploadQueueNotifier` & Fix `HttpSocialRepository` Fake-URL Masking (`REQ-P79-VLT-02`)**
  - **Target:** `apps/vhunambi_client/lib/features/media/data/repositories/http_media_upload_repository.dart` (new), `apps/vhunambi_client/lib/features/media/presentation/providers/media_upload_queue_provider.dart` (new), `apps/vhunambi_client/lib/core/media/vhunambi_media_upload_service.dart`, `apps/vhunambi_client/lib/features/social/data/repositories/http_social_repository.dart`
  - **Action:** Implement `HttpMediaUploadRepository` (`sendTimeout: 90s`, `receiveTimeout: 30s`, `onSendProgress`) and `MediaUploadQueueNotifier` (`stageAndEnqueue`, `0.0..1.0` progress, `MediaUploadStatus.failed` with `remoteUrl: null` on cellular drop, `retryUpload`, `deleteUpload`, `syncFromCloud`, plus `FLUTTER_TEST` fallback bridge to `socialRepositoryProvider` when `mediaUploadRepositoryProvider` is un-overridden); return `localFilePath` on `VhunambiUploadedMedia`; remove non-test `/r2/social/local/...` error masking in `HttpSocialRepository.uploadReelMedia`.
  - **Acceptance:** Local staging returns in `< 50ms`; network failures preserve local files as `failed` without fake 404 URLs; `phase77_chromatic_player_lyrics_r2_test.dart` remains 100% green.

- [x] **T79.2.3 — Add Local File Priority in `VhunambiTrackArtwork` & `AudioSourceResolver` (`REQ-P79-AUD-01`)**
  - **Target:** `apps/vhunambi_client/lib/core/widgets/vhunambi_track_artwork.dart`, `apps/vhunambi_client/lib/features/player/data/services/audio_source_resolver.dart`, `apps/vhunambi_client/lib/core/resilience/safe_audio_orchestrator.dart`
  - **Action:** Add `Image.file(File(localPath))` priority branch to `VhunambiTrackArtwork` (`!kIsWeb`); add unencrypted local file resolution (`file://` or readable path) to `AudioSourceResolver.resolveSource` prior to remote HTTPS fallback; add `AudioEngineSlot.studioPreview` to `SafeAudioOrchestrator`.
  - **Acceptance:** Picked local photos render immediately before R2 upload finishes; local imported audio resolves to `Uri.file(...)` even offline.

- [x] **T79.2.4 — Wire Auto-Vaulting Audio Import, Studio Real-Time `AudioPlayer` & Stage 3 Video Poster/Retry (`REQ-P79-AUD-02..03`)**
  - **Target:** `apps/vhunambi_client/lib/features/content_studio/presentation/widgets/reel_audio_picker_sheet.dart`, `apps/vhunambi_client/lib/features/studio/presentation/widgets/direct_daw_vocal_upload_sheet.dart`, `apps/vhunambi_client/lib/features/content_studio/presentation/views/kinetic_reel_studio_view.dart`, `apps/vhunambi_client/lib/features/content_studio/presentation/views/kinetic_reel_publish_view.dart`
  - **Action:** Expand `ReelAudioPickerSheet._importLocalAudio` to `['mp3','m4a','wav','aac','ogg']`, stage via `mediaUploadQueueProvider`, and upsert into `libraryTracksProvider`; route `DirectDawVocalUploadSheet` through `mediaUploadQueueProvider`; wire `SafeAudioOrchestrator`-guarded `just_audio` `AudioPlayer` in `KineticReelStudioView` (`!_isTestEnv`) looping `[audioStartMs, audioEndMs]` and driving `KineticPreviewCanvas`; render Stage 3 `publish_video_poster_preview` / `publish_photo_poster_preview`, `reel_publish_progress_bar` (`0%..100%`), and `reel_publish_retry_btn` on cellular drop.
  - **Acceptance:** Pass 1 Gate (`dart analyze` + `npx tsc --noEmit && npm test` + storage/studio/social/player/phase74/phase77/phase78 tests) passes 100% BEFORE starting Pass 2.

---

## 4. Pass 2 — `M79.3`: `CreateKineticPostSheet` Glass Cockpit v2 & `Library` `Uploads` Reuse Hub (`REQ-P79-KPOST-*`, `REQ-P79-HUB-*`)

- [x] **T79.3.1 — Upgrade `CreateKineticPostSheet` to Glass Cockpit v2 (`REQ-P79-KPOST-01..02`)**
  - **Target:** `apps/vhunambi_client/lib/features/explore/domain/models/social_music_post.dart`, `apps/vhunambi_client/lib/features/explore/presentation/widgets/create_kinetic_post_sheet.dart`
  - **Action:** Add optional `localFilePath` / `uploadAssetId` to `KineticPostImageAttachment`; mount above-the-fold `Key('kpost_media_preview_carousel')` right below `kpost_caption_input` with instant `Image.file` preview, progress ring, Retry chip, `×` remove, and `Key('kpost_pick_from_uploads_btn')` (`From My Uploads` sheet); replace dropdown with `VhunambiGlassTabBar` (`My Uploads | My Vault | Trending | Grooves`), `Key('kpost_audio_attachment_card')`, and `SafeAudioOrchestrator`-guarded `Key('kpost_audio_audition_btn')`; migrate all legacy `AppColors.*` tokens to `*Of(context)` while preserving every existing `kpost_*` key.
  - **Acceptance:** Attached photos appear immediately above the fold; `phase38`, `phase69`, `phase73`, and `phase77` tests remain 100% green.

- [x] **T79.3.2 — Add `LibraryCategory.uploads` Across All 5 Library Files & Build `UploadsVaultView` (`REQ-P79-HUB-01`)**
  - **Target:** `apps/vhunambi_client/lib/features/library/domain/models/library_models.dart`, `apps/vhunambi_client/lib/features/library/presentation/providers/library_providers.dart`, `apps/vhunambi_client/lib/features/library/presentation/widgets/library_category_rail.dart`, `apps/vhunambi_client/lib/features/library/presentation/widgets/library_empty_state.dart`, `apps/vhunambi_client/lib/features/library/presentation/views/library_view.dart`, `apps/vhunambi_client/lib/features/library/presentation/views/uploads_vault_view.dart` (new)
  - **Action:** Add `LibraryCategory.uploads` (`AppIcons.upload`, never `PhosphorIconsRegular.sparkle`!), `ownerMediaUploadsProvider`, and `UploadsVaultView` (`Key('library_uploads_vault_view')`, `All | Audio | Video | Images` filter, status/progress/Retry pill, audition/preview, `Use in Reel`, `Use in Post`, `Delete`).
  - **Acceptance:** All exhaustive `LibraryCategory` switches compile cleanly; `library_notifier_test.dart` and `library_view_test.dart` pass 100%.

- [x] **T79.3.3 — Upgrade `ReelAudioPickerSheet` to 5-Tab `VhunambiGlassTabBar` & Scrub Legacy `'AI Studio'` (`REQ-P79-HUB-02`)**
  - **Target:** `apps/vhunambi_client/lib/features/content_studio/presentation/widgets/reel_audio_picker_sheet.dart`, `apps/vhunambi_client/lib/features/library/presentation/providers/library_providers.dart`
  - **Action:** Replace non-scrollable 4-tab `TabBar` with scrollable `VhunambiGlassTabBar` (`My Vault | My Uploads | Trending | Saved | Vibes`); populate `My Uploads` from `mediaUploadQueueProvider` (`audio`); normalize `'AI Studio'` / `'@aistudio'` in `LibraryTracksNotifier.hydrateFromLocalBox` and `ReelStudioAudioSelection.fromLibraryTrack`.
  - **Acceptance:** Zero `'Trendin...'` truncation on `360dp`; stale Hive `'AI Studio'` tracks display active creator handle.

---

## 5. Pass 2 — `M79.4`: Reels Studio & Dark-Mode Polish, Regression Suite & Memory SLEEP (`REQ-P79-STU-*`)

- [x] **T79.4.1 — Fix Dark-Mode `_PostKineticReelCard`, Bounded Rail, SafeArea Dual-Handle Trimmer & Compact Stage 2 Drawer (`REQ-P79-STU-01..03`)**
  - **Target:** `apps/vhunambi_client/lib/features/social/presentation/widgets/trending_reels_shelf.dart`, `apps/vhunambi_client/lib/features/content_studio/presentation/views/kinetic_reel_studio_view.dart`, `apps/vhunambi_client/lib/features/content_studio/presentation/widgets/reel_audio_trimmer_sheet.dart`, `apps/vhunambi_client/lib/features/content_studio/presentation/widgets/typography_preset_picker.dart`, `apps/vhunambi_client/lib/features/content_studio/presentation/widgets/atmospheric_effects_deck.dart`
  - **Action:** Migrate `_PostKineticReelCard` + `trending_reels_shelf.dart` to `VhunambiGlassSurface` and `*Of(context)`; bound right tool rail in `Positioned(top: 76, bottom: 156)` + `SingleChildScrollView`; add `isScrollControlled: true` + `SafeArea(top: false)` + `SingleChildScrollView` + dual-handle `RangeSlider` (`Key('reel_audio_trim_range_slider')`) in `ReelAudioTrimmerSheet`; cap Stage 2 bottom drawer to `<= 34%` viewport height with horizontal preset/FX strips and pan-draggable canvas sticker (`_stickerOffset`).
  - **Acceptance:** Zero white card in Dark Mode, zero rail/trimmer clipping at `360x740`, Stage 2 lyric banner completely unobstructed, and `phase74` tests 100% green.

- [x] **T79.4.2 — Author `phase79_media_upload_engine_and_post_cockpit_test.dart` & Execute Full Gates (`G79-01` – `G79-05`)**
  - **Target:** `apps/vhunambi_client/test/features/phase79_media_upload_engine_and_post_cockpit_test.dart` (new)
  - **Action:** Write comprehensive unit + widget tests covering every `REQ-P79-*` requirement (local-first staging, tenant isolation, `0.0 -> 1.0` progress, cellular drop `failed` state with zero `/r2/social/local/...` URL, `retryUpload` -> `synced`, `AudioSourceResolver` local file priority, `VhunambiTrackArtwork` `Image.file`, Stage 3 poster + progress + retry, `CreateKineticPostSheet` above-the-fold carousel + `From My Uploads` + audio card, `LibraryCategory.uploads` + `UploadsVaultView`, Dark Mode `_PostKineticReelCard`, 5-tab `ReelAudioPickerSheet` + `'AI Studio'` scrub, `360x740` trimmer + rail + `<=34%` Stage 2 drawer + draggable sticker).
  - **Acceptance:** `dart analyze` (`0` issues), `STD-UIUX-001` (`0` violations), `32/32` backend suites, and all Flutter regression suites pass 100%.

- [x] **T79.4.3 — Promote Phase 79 `memory.md` & Run Connectome SLEEP Consolidation (`G79-06`)**
  - **Target:** `docs/phases/phase_79_sovereign_media_upload_engine_and_post_cockpit/memory.md`
  - **Action:** Promote `"status": "completed"` and `"completed_at"` with verified breakthroughs/gotchas ONLY after `G79-01`–`G79-05` pass 100%, then run `node .agents/skills/vhunambi-memory/scripts/consolidate_memory.mjs` and `query_connectome.mjs --open` confirming `0 OPEN` endpoints.

---

## 6. Pre-Audited Existing Test Impact Matrix

| Existing Test File | Potential Trap Identified | Phase 79 Design Mitigation |
| :--- | :--- | :--- |
| `test/features/storage/sovereign_hive_bootstrap_test.dart` (`#L33,37,115,118`) | Asserts `tier1BoxKeys.length == 17` and `totalDeclaredBoxes == 26`. | Explicitly update to `18` Tier-1 boxes and `27` total boxes in `T79.2.1`. |
| `test/features/library/library_view_test.dart` (`#L79,L104`) | Asserts `find.byIcon(PhosphorIconsRegular.sparkle)` finds `1` widget on mobile and taps `'Trash'` at `1280x1024`. | Use `AppIcons.upload` (`uploadSimple`, never `sparkle`) on `LibraryCategory.uploads`; compact `VhunambiGlassTabBar` keeps all 8 tabs `< 800px` wide at `1280`. |
| `test/features/phase77_chromatic_player_lyrics_r2_test.dart` (`#L302-L336`) | Overrides `socialRepositoryProvider` and asserts `fakeSocialRepo.uploadCalls == 2` on `kpost_pick_photo_btn`. | `MediaUploadQueueNotifier` falls back to `socialRepositoryProvider.uploadReelMedia` in `FLUTTER_TEST` when `mediaUploadRepositoryProvider` is not overridden. |
| `test/features/phase73_kinetic_post_chromatic_reactions_test.dart` (`#L433-L487`) | Taps `kpost_upload_photo_btn` 4x, checks `kpost_max_images_badge`, taps `16:9 Wide`, taps `kpost_publish_submit_btn`. | Preserve all exact `Key('kpost_*')` identifiers and aspect-ratio labels in `CreateKineticPostSheet` v2. |
| `test/features/phase74_reels_studio_and_playback_v4_test.dart` (`#L116-L185`) | Checks `reel_studio_audio_pill`, `ReelAudioPickerSheet`, `reel_studio_canvas_sticker_*`, `reel_publish_submit_btn`. | Bypass native `just_audio` / `VideoPlayerController` channels under `_isTestEnv` and preserve every Stage 1–3 `Key`. |

---

## 7. Stage 4 Verification Commands

```powershell
# G79-01: Client Static Analysis
Set-Location c:\Users\Ndugelo\VHUNAMBI\monorepo\apps\vhunambi_client
dart analyze

# G79-02: Backend Typecheck & 32-Suite Test Gate
Set-Location c:\Users\Ndugelo\VHUNAMBI\monorepo\apps\vhunambi_api
npx tsc --noEmit
npm test

# G79-03: STD-UIUX-001 Icon & Raw Emoji Audit
Set-Location c:\Users\Ndugelo\VHUNAMBI\monorepo\apps\vhunambi_client
$files = @(
  'lib/core/media/sovereign_media_storage_service.dart',
  'lib/core/media/vhunambi_media_upload_service.dart',
  'lib/core/widgets/vhunambi_track_artwork.dart',
  'lib/features/media/domain/models/uploaded_media_asset.dart',
  'lib/features/media/data/repositories/http_media_upload_repository.dart',
  'lib/features/media/presentation/providers/media_upload_queue_provider.dart',
  'lib/features/library/presentation/views/uploads_vault_view.dart',
  'lib/features/library/presentation/widgets/library_category_rail.dart',
  'lib/features/library/presentation/widgets/library_empty_state.dart',
  'lib/features/explore/presentation/widgets/create_kinetic_post_sheet.dart',
  'lib/features/content_studio/presentation/widgets/reel_audio_picker_sheet.dart',
  'lib/features/content_studio/presentation/widgets/reel_audio_trimmer_sheet.dart',
  'lib/features/content_studio/presentation/widgets/typography_preset_picker.dart',
  'lib/features/content_studio/presentation/widgets/atmospheric_effects_deck.dart',
  'lib/features/content_studio/presentation/views/kinetic_reel_studio_view.dart',
  'lib/features/content_studio/presentation/views/kinetic_reel_publish_view.dart',
  'lib/features/social/presentation/widgets/trending_reels_shelf.dart'
)
Select-String -Path $files -Pattern '\bIcons\.' -CaseSensitive
Select-String -Path $files -Pattern '[\u2600-\u27BF]|[\uD83C-\uDBFF][\uDC00-\uDFFF]' | Where-Object { $_.Line -notmatch '^\s*//' }

# G79-04 & G79-05: Bounded Flutter Regression Gate
flutter test test/features/phase79_media_upload_engine_and_post_cockpit_test.dart test/features/storage/sovereign_hive_bootstrap_test.dart test/features/phase73_kinetic_post_chromatic_reactions_test.dart test/features/phase74_reels_studio_and_playback_v4_test.dart test/features/phase77_chromatic_player_lyrics_r2_test.dart test/features/phase78_vault_explore_continuity_uploads_glass_tabs_test.dart test/features/library test/features/explore test/features/content_studio test/features/social test/features/studio test/features/player --no-pub --timeout=60s

# G79-06: Memory SLEEP Consolidation
Set-Location c:\Users\Ndugelo\VHUNAMBI\monorepo
node .agents/skills/vhunambi-memory/scripts/consolidate_memory.mjs
node .agents/skills/vhunambi-memory/scripts/query_connectome.mjs --open
```

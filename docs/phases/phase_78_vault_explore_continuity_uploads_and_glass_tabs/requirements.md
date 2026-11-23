# Phase 78 Requirements Specification (`requirements.md`)

**Phase ID:** `P78` — Vault, Explore & Profile Continuity, Real Audio/Video Uploads & Unified Glass Tabs  
**Methodology:** EARS (Easy Approach to Requirements Syntax) & RFC-2119 (`SHALL`, `MUST`, `WHEN`, `WHILE`, `IF...THEN`)  
**Audit Trace:** [`PHASE78_VAULT_EXPLORE_CONTINUITY_UPLOADS_AND_GLASS_TABS_AUDIT.md`](../../audits/PHASE78_VAULT_EXPLORE_CONTINUITY_UPLOADS_AND_GLASS_TABS_AUDIT.md)

---

## 1. Document Scope & Consumed Connectome Primitives

Phase 78 consumes existing `CONNECTED_EXTENSIBLE` primitives cleanly without duplicating infrastructure:
- `EP-P77-UNIFIED-R2-IMAGE-UPLOAD` (`lib/core/media/vhunambi_media_upload_service.dart`)
- `EP-P74-SOCIAL-MEDIA-R2-UPLOAD` (`apps/vhunambi_api/src/routes/social_routes.ts` & `HttpSocialRepository.uploadReelMedia`)
- `EP-P74-REELS-STUDIO-PIPELINE` (`lib/features/content_studio/presentation/views/kinetic_reel_studio_view.dart`)
- `EP-P74-KARAOKE-LYRIC-SANITIZER` (`lib/features/content_studio/domain/utils/lyric_karaoke_sanitizer.dart`)
- `EP-P68-TRACK-ARTWORK` (`lib/core/widgets/vhunambi_track_artwork.dart`)
- `EP-P70-VIEWER-ROLE` (`lib/core/auth/viewer_role.dart`)
- `EP-P70-GLASS-SURFACE` (`lib/core/widgets/vhunambi_glass_surface.dart`)

---

## 2. Pillar 1 — Real Audio Upload & Camera/Gallery Video Capture (`REQ-P78-UPL-*`, `REQ-P78-CAM-*`)

### `REQ-P78-UPL-01` — Interactive File Picker & Local Persistence in `DirectDawVocalUploadSheet`
- **WHEN** the user taps the file import dropzone (`Key('direct_upload_pick_file_btn')`) inside `DirectDawVocalUploadSheet`, **THE SYSTEM SHALL** open native `FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['mp3', 'm4a', 'wav', 'aac', 'ogg'], withData: true)` (with a deterministic `FLUTTER_TEST` synthetic audio bypass).
- **WHEN** a file is chosen, **THE SYSTEM SHALL** display its real filename and byte size, auto-populate `_titleController` when untouched, validate non-empty payload `<= 25 MB`, and persist a local copy (`localAudioFilePath`) when possible so offline playback works immediately.

### `REQ-P78-UPL-02` — Real R2 Audio Upload, Visibility in Vault/Profile & Studio Camera Routing
- **WHEN** the user taps `Key('direct_upload_submit_btn')` on `DAW Master` or `Vocal / Stem`, **THE SYSTEM SHALL** upload the selected audio bytes through `ISocialRepository.uploadReelMedia` (`POST /api/social/media/upload`) while displaying an inline loading state, and register the resulting `LibraryTrack` into `libraryTracksProvider` with:
  - `creatorId: resolvedCreatorId` (canonical active owner ID),
  - `creatorHandle: resolvedHandle`,
  - `localAudioFilePath` (when persisted locally),
  - `remoteAudioUrl` (normalized R2 URL), and
  - `isInstrumental: false` for full song/vocal masters so the uploaded song **immediately appears** in both `LibraryView` (`Songs` tab) and `OwnerProfileView` (`Your Songs`).
- **WHEN** the user submits from the `Dance Reel` workflow tab (`_UploadWorkflow.cameraReel`), **THE SYSTEM SHALL** pop the sheet and launch `KineticReelStudioView.show(context, initialCameraMode: true)` (never `KineticReelsModal`).

### `REQ-P78-UPL-03` — Backend R2 Audio MIME Parity (`social_routes.ts`)
- **THE SYSTEM SHALL** accept `'audio/wav'`, `'audio/x-wav'`, `'audio/wave'`, `'audio/aac'`, and `'audio/ogg'` in `ALLOWED_SOCIAL_MEDIA_MIMES` inside `apps/vhunambi_api/src/routes/social_routes.ts` alongside existing MP3/M4A/image/video MIME types under the `25 MB` cap.

### `REQ-P78-CAM-01` — Real Camera Video Recording in `KineticReelStudioView`
- **WHEN** `KineticReelStudioView` is in Camera mode and `_cameraController.value.isInitialized` is `true`, tapping `Key('reel_studio_shutter_btn')` **SHALL** start real video recording (`startVideoRecording()`), display a visible recording indicator (`Key('reel_studio_recording_indicator')`) with elapsed seconds, and on second tap (or reaching `_lengthSteps[_lengthIdx]`) call `stopVideoRecording()`, store `_customMediaLocalPath = captured.path` and `_customMediaBytes = await captured.readAsBytes()`, set `_mediaKind = 'camera_video'`, `_customMediaMime = 'video/mp4'`, initialize the Stage 2 `VideoPlayerController`, and transition to `_ReelStudioStage.editor`.
- **WHERE** `KineticReelStudioView` runs in headless `FLUTTER_TEST` or without hardware cameras, tapping `Key('reel_studio_shutter_btn')` **SHALL** gracefully retain deterministic artwork fallback without throwing.

### `REQ-P78-CAM-02` — Stage 2 Editor Video & Photo Preview + Local Path Propagation
- **WHEN** `_stage == _ReelStudioStage.editor` and the user recorded a camera video or picked a gallery video (`_mediaKind == 'camera_video'` or `'gallery_video'`), **THE SYSTEM SHALL** initialize and loop a `VideoPlayerController.file(File(path))` (`Key('reel_studio_stage2_video_preview')`) beneath transparent `KineticPreviewCanvas` (with `VhunambiTrackArtwork` fallback while loading/in tests).
- **WHEN** `_mediaKind == 'gallery_photo'` and `_customMediaBytes != null`, **THE SYSTEM SHALL** render `Image.memory` (`Key('reel_studio_stage2_photo_preview')`) beneath the lyric/sticker layers in Stage 2.
- **THE SYSTEM SHALL** add optional `final String? localVideoPath` to `PublishedClip` (serialized in `toJson`/`fromJson`, copied in `copyWith`) and pass `_customMediaLocalPath` through `KineticReelPublishView` into `PublishedClip` so newly published camera/gallery Reels play locally even when offline or while R2 upload falls back.

### `REQ-P78-CAM-03` — Unobstructed Top Audio Pill in `KineticReelStudioView`
- **THE SYSTEM SHALL** declutter the top header row of `KineticReelStudioView` so it contains ONLY `Close` (`left`), a generously sized centered `Key('reel_studio_audio_pill')` (`minWidth: 168`, `maxWidth: 240`), and `Rail Side Flip` (`right`), relocating `Flash`, `Speed`, and `Timer` cleanly onto the collapsible vertical tool rail while preserving every existing widget `Key`.

---

## 3. Pillar 2 — Overlay Discipline, Ephemeral Reactions & `@aistudio` Ownership (`REQ-P78-HUD-*`, `REQ-P78-OWN-*`)

### `REQ-P78-HUD-01` — Zero SnackBar Queue Storm on Rapid Reel Loves (`VA-03`)
- **WHEN** a user taps or double-taps Love on a Reel inside `KineticReelsModal`, **THE SYSTEM SHALL NOT** call `ScaffoldMessenger.of(context).showSnackBar(...)`.
- **THE SYSTEM SHALL** instead display a single in-place ephemeral floating glass pill (`Key('reel_ephemeral_love_pill')`) anchored near the right reaction rail showing `Loved ${count}x`, updating in place on rapid taps and auto-hiding `800ms` after the last tap with zero queue buildup.

### `REQ-P78-HUD-02` — `MiniPlayerHost` Suppression in `KineticReelsModal` & Tab-Switch Auto-Dock (`VA-05`)
- **WHILE** `KineticReelsModal` is mounted, **THE SYSTEM SHALL** increment `pushedFullScreenOverlayCountProvider` in `initState` and decrement it cleanly in `dispose` so `MiniPlayerHost` is completely hidden during full-screen Reels playback and Comments.
- **WHEN** the user switches primary bottom navigation tabs in `RootShell._switchTab` (`lib/main.dart`), **IF** `miniPlayerControllerProvider.mode == PlayerMode.manual`, **THE SYSTEM SHALL** call `resetToDock(MediaQuery.maybeSizeOf(context))` so a dragged MiniPlayer pill never remains stranded mid-screen across Library, Explore, or Home tabs.

### `REQ-P78-OWN-01` — Authenticated Creator Stamping & Legacy `@aistudio` Owner Rescue (`VA-06`)
- **WHEN** `GenerationPipelineNotifier` adds a newly synthesized song into `libraryTracksProvider`, **THE SYSTEM SHALL** stamp the active authenticated creator's `creatorId`, `creatorHandle`, and `creatorName` (never `creatorName: 'AI Studio'` with `null` `creatorId`).
- **WHEN** `resolveViewerRole` (`viewer_role.dart`), `_lookupInitialTrack` (`track_providers.dart`), or `OwnerProfileView._resolveOwnerSongs` (`owner_profile_view.dart`) evaluates a legacy local track stamped with `'AI Studio'`, `'ai_studio'`, `'creator_ai_studio'`, or `'@aistudio'`, **THE SYSTEM SHALL** treat it as owned by the active signed-in creator (`ViewerRole.owner`) and display the active creator's handle so the creator is never locked out of their own Stem Lab, Mastering, or Owner Cockpit.

### `REQ-P78-OWN-02` — Lyric Sanitizer Hardening for Unclosed Parentheses & `[INTRO]` (`VA-06`, `VA-09`)
- **THE SYSTEM SHALL** harden `LyricKaraokeSanitizer.cleanLyricTextForKaraoke` and `sanitizeAlignment` to strip both balanced parenthetical stage/instrument cues and unclosed leading parenthetical fragments (e.g. `(Sacred drum;`, `(Li-ste-en`) as well as stray unmatched `(` or `)` characters.
- **THE SYSTEM SHALL** strip non-sung `[INTRO]` and `[OUTRO]` instrumental headers in `LyricsTeleprompter` playback display while keeping `[Verse 1]` / `[Chorus]` structural stanza badges intact so existing Phase 75 and `expanded_cockpit_modal_test.dart` contracts remain 100% green.

---

## 4. Pillar 3 — Explore $\leftrightarrow$ Library $\leftrightarrow$ Owner Profile Continuity (`REQ-P78-CONT-*`)

### `REQ-P78-CONT-01` — Instant Index-0 Surfacing of Newly Published Reels on Explore (`VA-01`)
- **WHEN** a creator publishes a new Reel via `KineticReelPublishView` (`socialFeedProvider.notifier.prependClip`), `trendingReelsProvider` **SHALL** pin newly published non-seed / active-owner Reels (ordered newest-first) ahead of virality-sorted catalog clips at index `0` of Explore's `Kinetic Reels` shelf (`All` and matching genre pills), guaranteeing immediate visibility without swiping through 8+ clips.

### `REQ-P78-CONT-02` — First-Class `Reels` Category in `LibraryView` Asset Vault (`VA-01`)
- **THE SYSTEM SHALL** extend `LibraryCategory` with `LibraryCategory.reels`, expose it in `LibraryCategoryRail` with `AppIcons.reels` and live owner-clip count badge (`libraryCategoryCountsProvider`), handle every exhaustive `switch (category)`, and render `ReelsVaultView` (`Key('library_reels_vault_view')`) displaying the active owner's published Reels with `CreatorReelThumbnailCard` (`VhunambiTrackArtwork`), play-in-`KineticReelsModal` on tap, share link, delete action (`SocialFeedNotifier.deleteClip`), and a `+ Create Reel` CTA (`Key('library_reels_create_btn')`).

### `REQ-P78-CONT-03` — `CreatorReelThumbnailCard` Artwork Parity & Owner Profile Tab Deduplication (`VA-01`)
- **THE SYSTEM SHALL** replace `CreatorReelThumbnailCard._CoverArt`'s `AppGradients.forGenre` + raw `Image.network` + stock `Icons.music_note_rounded` / `Icons.play_arrow_rounded` with `VhunambiTrackArtwork` and `PhosphorIcon(PhosphorIconsFill.play)` so `OwnerProfileView`'s `My Clips & Reels` renders real artwork with zero blank orange slabs and `0` stock `Icons.*`.
- **THE SYSTEM SHALL** remove the redundant `_OwnerReelsShelf()` from `OwnerStudioTab.songs` inside `OwnerProfileView` so `Songs` focuses cleanly on `Your Songs` + `My Kinetic Posts`, while `Reels` owns `_OwnerReelsShelf()`.

---

## 5. Pillar 4 — Unified `VhunambiGlassTabBar`, Explore Mood Rail & Polish Seams (`REQ-P78-TAB-*`, `REQ-P78-UIUX-*`)

### `REQ-P78-TAB-01` — Shared `VhunambiGlassTabBar` (`EP-P78-GLASS-TAB-BAR`)
- **THE SYSTEM SHALL** provide `VhunambiGlassTabBar` (`lib/core/widgets/vhunambi_glass_tab_bar.dart`) featuring a continuous frosted `VhunambiGlassSurface` outer track (`enableLiveBlur: false`), an animated translucent active glass capsule with specular rim, optional icon & numeric badge, `44dp` minimum touch targets, `HapticsService().selectionClick()`, and Light/Dark contrast parity.
- **THE SYSTEM SHALL** adopt `VhunambiGlassTabBar` across:
  1. `OwnerProfileView` (`owner_profile_view.dart`), preserving `Key('owner_studio_tab_${tab.name}')`,
  2. `ArtistProfileView` (`artist_profile_view.dart`, via `VhunambiGlassTabBarHeaderDelegate`), preserving `Key('visitor_tab_*')`,
  3. `ExploreView` (`For You`, `Following`, `All Songs` primary switcher), and
  4. `LibraryCategoryRail` (`library_category_rail.dart`) with badge parity.

### `REQ-P78-UIUX-01` — Explore `All Songs` Horizontal `VhunambiMood` Rail & `TrackListTile` Artwork (`VA-04`)
- **THE SYSTEM SHALL** replace the multi-row vertical mood `Wrap` in `CatalogFilterBar` with a single-row horizontally scrollable frosted `VhunambiMood` pill rail (`Key('catalog_mood_rail')`, `44dp` height, `PhosphorIcon(mood.icon)` + label) using `AppColors.*Of(context)` tokens across both Light and Dark themes.
- **THE SYSTEM SHALL** replace the `48x48` orange `AppGradients.forGenre` glyph square in `TrackListTile` (`Fastest Growing Tracks`) with `VhunambiTrackArtwork` (`Key('track_list_tile_artwork_${track.id}')`) and `AppColors.*Of(context)` tokens.

### `REQ-P78-UIUX-02` — Polish Seams (`VA-09`)
- **THE SYSTEM SHALL** replace the bare gold coin `IconButton` (`Key('kpost_focus_tip_btn')`) in `KineticPostFocusView` with a labeled frosted `'Tip'` glass pill (`AppIcons.coin` + `'Tip'`, `minHeight: 44`).
- **THE SYSTEM SHALL** normalize legacy `'@current_user'` / `'current_user'` handles inside `SocialMusicPost.fromJson` so cached reposts never display `You (@current_user)`.
- **THE SYSTEM SHALL** diversify offline Vision AI fallback artwork in `CreateKineticPostSheet` across distinct registered genre/mood cover assets (`AppAssets.resolveGenreCoverAsset`) rather than returning a dead `cdn.vhunambi.com` URL.
- **THE SYSTEM SHALL** keep `VhunambiTrackArtwork` rendered beneath `_ReelVideoBackingLayer` in `KineticReelsModal` until the video controller finishes initializing (`_initialized == true`), ensuring zero blank black Reel frames.

---

## 6. Non-Functional & Traceability Matrix (`REQ-P78-NFR-*`)

- **`REQ-P78-NFR-01` (`STD-UIUX-001`):** Zero stock Material `Icons.*` and zero raw Unicode emojis in all touched modules.
- **`REQ-P78-NFR-02` (Headless Test Safety):** All `FilePicker`, `CameraController`, `VideoPlayerController`, and `ImagePicker` paths MUST guard `FLUTTER_TEST` cleanly with zero hanging timers or platform-channel crashes under `flutter test --no-pub --timeout=60s`.
- **`REQ-P78-NFR-03` (Dual-Theme WCAG AA):** Every modified and new surface MUST use `AppColors.*Of(context)` and pass Light & Dark widget verification.

| Requirement ID | Primary Implementation Target | Verification Test Case |
| :--- | :--- | :--- |
| `REQ-P78-UPL-01..02` | `DirectDawVocalUploadSheet` | `phase78_*_test.dart`: picks file, uploads to R2, lands in `LibraryCategory.songs` & `OwnerProfileView` |
| `REQ-P78-UPL-03` | `apps/vhunambi_api/src/routes/social_routes.ts` | `apps/vhunambi_api/test/*`: accepts `audio/wav`, `audio/aac`, `audio/ogg` |
| `REQ-P78-CAM-01..03` | `KineticReelStudioView`, `KineticReelPublishView`, `PublishedClip` | `phase78_*_test.dart`: localVideoPath propagation, unobstructed audio pill, Stage 2 photo/video hook |
| `REQ-P78-HUD-01..02` | `KineticReelsModal`, `RootShell` (`main.dart`) | `phase78_*_test.dart`: zero SnackBar on rapid love + `reel_ephemeral_love_pill`; overlay ref-count + `resetToDock` |
| `REQ-P78-OWN-01..02` | `GenerationPipelineNotifier`, `viewer_role.dart`, `track_providers.dart`, `LyricKaraokeSanitizer` | `phase78_*_test.dart`: generated track owns `ViewerRole.owner`; legacy `@aistudio` rescued; `(Sacred drum;` & `[INTRO]` stripped |
| `REQ-P78-CONT-01..03` | `trendingReelsProvider`, `LibraryCategory.reels`, `ReelsVaultView`, `CreatorReelThumbnailCard`, `OwnerProfileView` | `phase78_*_test.dart`: new Reel at index 0; Library Reels tab shows owner clips; `VhunambiTrackArtwork` on cards; zero Songs tab duplication |
| `REQ-P78-TAB-01` & `UIUX-01..02` | `VhunambiGlassTabBar`, `CatalogFilterBar`, `TrackListTile`, `KineticPostFocusView`, `SocialMusicPost` | `phase78_*_test.dart`: Dark/Light `VhunambiGlassTabBar`, horizontal mood rail, `TrackListTile` artwork, Tip pill, `@current_user` normalization |

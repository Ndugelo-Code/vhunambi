# Phase 77 Requirements Specification (`requirements.md`)

**Phase ID:** `P77` — Chromatic Full-Screen Player, Synced Sing-Along Lyrics & Unified R2 Media Uploads  
**Methodology:** EARS (Easy Approach to Requirements Syntax) & RFC-2119 (`SHALL`, `MUST`, `WHEN`, `WHILE`, `IF...THEN`)  
**Audit Trace:** [`PHASE77_CHROMATIC_PLAYER_LYRICS_AND_R2_UPLOADS_AUDIT.md`](../../audits/PHASE77_CHROMATIC_PLAYER_LYRICS_AND_R2_UPLOADS_AUDIT.md)

---

## 1. Document Scope & Consumed Connectome Primitives

Phase 77 consumes six existing `CONNECTED_EXTENSIBLE` primitives without inventing duplicate parallel services:
- `EP-P73-POST-CHROMATIC-SYNTH` (`lib/core/theme/post_chromatic_palette_resolver.dart`)
- `EP-P74-KARAOKE-LYRIC-SANITIZER` (`lib/features/content_studio/domain/utils/lyric_karaoke_sanitizer.dart`)
- `EP-P74-SOCIAL-MEDIA-R2-UPLOAD` (`apps/vhunambi_api/src/routes/social_routes.ts` & `HttpSocialRepository.uploadReelMedia`)
- `EP-P74-REELS-STUDIO-PIPELINE` (`KineticReelStudioView.show`)
- `EP-P68-TRACK-ARTWORK` (`lib/core/widgets/vhunambi_track_artwork.dart`)
- `EP-P70-GLASS-SURFACE` (`lib/core/widgets/vhunambi_glass_surface.dart`)

---

## 2. Pillar 1 — Living Chromatic Player & Surface Parity (`REQ-P77-CHROM-*`)

### `REQ-P77-CHROM-01` — Unified Player Chromatic Resolution
- **WHEN** `ExpandedCockpitModal`, `MobileMiniPlayer`, `PillForm`, or `DesktopTransportBar` renders an active `Track`, **THE SYSTEM SHALL** compute an immediate first-frame `PostChromaticPalette` via `PostChromaticPaletteResolver.resolveSync(brightness:, rawMood: track.mood, artworkUrl: track.coverUrl, hasAudioAttachment: true)` and asynchronously refine it via `PostChromaticPaletteResolver.resolveAsync(...)` guarded by a signature check (`brightness|mood|coverUrl`) so stale completions are discarded.

### `REQ-P77-CHROM-02` — Full-Screen Chromatic Stage & Real Artwork (`ExpandedCockpitModal`)
- **THE SYSTEM SHALL** paint `ExpandedCockpitModal` with an adaptive backdrop (`Key('cockpit_chromatic_backdrop')`) blending `palette.primaryGlow` and `palette.secondaryGlow` over `AppColors.surfaceModalOf(context)` at Light/Dark-safe alphas (`0.28`/`0.14` Dark, `0.14`/`0.07` Light).
- **THE SYSTEM SHALL** replace the placeholder `AppGradients.forGenre` + `AppIcons.piano` hero box (`expanded_cockpit_modal.dart#L379-399`) with `VhunambiTrackArtwork` (`Key('cockpit_hero_artwork')`) displaying `track.coverUrl` framed by a `palette.primaryGlow` ambient shadow.
- **THE SYSTEM SHALL** replace all static Dark tokens (`AppColors.surfaceModal`, `AppColors.darkSurfaceSecondary`, `AppColors.textSecondary`, `AppColors.borderSubtle`, raw `Colors.white` chrome icons) in `ExpandedCockpitModal` with `AppColors.*Of(context)` and `palette.accent` / `palette.onAccent`.

### `REQ-P77-CHROM-03` — `PillForm` Legacy `PaletteGenerator` Elimination
- **THE SYSTEM SHALL** remove the un-guarded `PaletteGenerator.fromImageProvider(NetworkImage(...)).timeout(4s)` extraction from `pill_form.dart` (`#L106-127`) and delegate exclusively to `PostChromaticPaletteResolver` (`Key('pill_chromatic_surface')`), guaranteeing zero network timers in headless `flutter test` and WCAG AA contrast clamping in Light and Dark themes.

### `REQ-P77-CHROM-04` — Adaptive Mini-Player, Desktop Transport & Floating Dock Surface
- **THE SYSTEM SHALL** upgrade `VhunambiFloatingTransportSurface` and `VhunambiBottomDockSurface` (`lib/core/widgets/vhunambi_bottom_dock_kit.dart`) to resolve surface/border colors via `AppColors.surfaceModalOf(context)`, `AppColors.surfaceCanvasOf(context)`, and `AppColors.borderSubtleOf(context)`, and accept an optional `Color? borderTint` from `palette.glassBorderTint`.
- **THE SYSTEM SHALL** replace `AppGradients.forGenre` + `AppIcons.piano` thumbnails in `MobileMiniPlayer` (`Key('mini_player_artwork')`) and `DesktopTransportBar` (`Key('desktop_transport_artwork')`) with `VhunambiTrackArtwork(coverUrl: track.coverUrl, genre: track.genre, trackId: track.id)`.

### `REQ-P77-CHROM-05` — Light/Dark Surface Parity for Player & Track Modals
- **THE SYSTEM SHALL** migrate `QueueDrawer` (`queue_drawer.dart`) and `_FrostedStemMixerSheet` + `_StickyTrackTitle` (`track_detail_view.dart#L1060-1120`) from static `AppColors.surfaceModal` / `AppColors.borderSubtle` / `AppColors.textPrimary` / `AppColors.textSecondary` to `AppColors.*Of(context)`.

---

## 3. Pillar 2 — Clean Synced Karaoke & 9-Language Bantu Word Glossary (`REQ-P77-LYR-*`)

### `REQ-P77-LYR-01` — Zero Bracket Cue Leaks Across Player & Track Detail
- **WHEN** lyrics are rendered in `ExpandedCockpitModal._buildLyricsCard` or `LyricsTeleprompter`, **THE SYSTEM SHALL** sanitize raw lyric text via `LyricKaraokeSanitizer.cleanLyricsForTeleprompter(rawLyrics)` so AI stage cues (`[Intro]`, `[Verse 1]`, `[Crisp soft shakers, airy synth pads]`) NEVER appear on screen.
- **THE SYSTEM SHALL** replace `AppIcons.edit` on `ExpandedCockpitModal`'s Copy lyrics button (`Key('cockpit_copy_lyrics')`) with `PhosphorIconsRegular.copy` and copy the sanitized lyrics text.

### `REQ-P77-LYR-02` — Live Playback Synchronization & Tap-to-Seek
- **WHILE** `playerStateProvider` is playing or paused on the displayed track (`playerState.currentTrack?.id == trackId` and `playerState.duration > Duration.zero`), **THE SYSTEM SHALL** compute the active lyric line index via `SyncedLyricTimeline.resolveActiveLineIndex(lineCount:, position:, duration:)` and render that line with an elevated accent highlight (`Key('synced_lyrics_active_line')`).
- **WHEN** the active lyric line changes during playback, **THE SYSTEM SHALL** smoothly scroll the active line into view using `Scrollable.ensureVisible` when its `BuildContext` is mounted.
- **WHEN** a user taps a lyric line row, **THE SYSTEM SHALL** seek playback to `SyncedLyricTimeline.seekTargetForLine(index:, lineCount:, duration:)` via `ref.read(playerStateProvider.notifier).seek(...)` (starting the track if not currently active).

### `REQ-P77-LYR-03` — Nine-Language Southern Bantu Cognate Default
- **THE SYSTEM SHALL** define `BantuLyricTranslationService.allBantuLanguageCodes = ['zu', 'xh', 'ss', 'nr', 'nso', 'tn', 'st', 've', 'ts']` and use all 9 languages as the default `targetCognateLanguages` in `processLyrics` and `translateLine`.

### `REQ-P77-LYR-04` — Interactive Per-Word Bantu Glossary Lookup & Popover
- **THE SYSTEM SHALL** add `BantuLyricTranslationService.lookupWord(String word, {String baseLanguageCode = 'zu'})` returning a `BantuWordDefinition` containing:
  - `normalizedWord`, `sourceLanguage` (`BantuLanguage`), `branchLabel` (`Nguni`, `Sotho-Tswana`, `Tshivenda`, `Tswa-Ronga`),
  - `syllabifiedPhonetic` (penultimate stress via `syllabifyAndMarkPenultimate`),
  - `meaning` (curated glossary definition or `kMeaningUnavailable`), and
  - `cognates` (`List<BantuSimilarityResult>` across the other 8 Southern Bantu languages).
- **WHEN** Sing-Along / Bantu mode is enabled (`Key('synced_lyrics_bantu_toggle')`) in `LyricsTeleprompter` or `ExpandedCockpitModal`, **THE SYSTEM SHALL** render lyric words as tappable tokens that open `BantuWordGlossarySheet` (`Key('bantu_word_glossary_sheet')`) built with `VhunambiGlassSurface(enableLiveBlur: false)` displaying the word's meaning, branch, penultimate-stress pronunciation, and cross-language cognates.

### `REQ-P77-LYR-05` — Full-Screen Player Lyric Resolution Fallback
- **WHEN** `ExpandedCockpitModal` opens its Lyrics panel, **THE SYSTEM SHALL** resolve lyrics from `libraryTracksProvider` first and fall back to `trackDetailProvider(track.id)` when the track originated from Explore or Search, passing the track's language code and `PostChromaticPalette.accent` directly into the shared synced `LyricsTeleprompter`.

---

## 4. Pillar 3 — Unified R2 Media Uploads & Visitor "Share as Reel" (`REQ-P77-R2-*` / `REQ-P77-REEL-*`)

### `REQ-P77-R2-01` — Shared `VhunambiMediaUploadService` (`EP-P74-SOCIAL-MEDIA-R2-UPLOAD`)
- **THE SYSTEM SHALL** provide `VhunambiMediaUploadService` (`lib/core/media/vhunambi_media_upload_service.dart`) encapsulating:
  - `ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 88)` on live devices,
  - deterministic `FLUTTER_TEST` bypass returning synthetic JPEG bytes without platform channel calls,
  - MIME inference (`image/jpeg`, `image/png`, `image/webp`) and strict `<= 25 MB` validation matching `apps/vhunambi_api/src/routes/social_routes.ts#L126-136`,
  - upload dispatch through `ISocialRepository.uploadReelMedia(bytes:, filename:, mimeType:)` returning a normalized R2 URL (`/r2/social/...` or configured cloud URL).

### `REQ-P77-R2-02` — Real Device Photo Uploads in `CreateKineticPostSheet`
- **THE SYSTEM SHALL** delete `_mockPickImage` (`create_kinetic_post_sheet.dart#L113-139`) and its hardcoded `'https://cdn.vhunambi.com/covers/custom_post_art.jpg'` URL + duplicate ternary.
- **WHEN** the user taps the photo upload action (`Key('kpost_pick_photo_btn')`), **THE SYSTEM SHALL** invoke `VhunambiMediaUploadService.pickAndUploadImage(...)`, display an inline upload indicator while uploading, append the returned R2 URL to `_attachedImages`, and surface clear error feedback on failure.
- **THE SYSTEM SHALL** replace static Dark tokens in `CreateKineticPostSheet` with `AppColors.*Of(context)` and replace the hardcoded `'Limpopo / Polokwane'` location string with the active creator's profile location fallback (`owner.location` or `'South Africa'`).

### `REQ-P77-R2-03` — Custom R2 Playlist Cover Uploads (`PlaylistsVaultView` & `PlaylistDetailView`)
- **THE SYSTEM SHALL** extend `PlaylistEntity.copyWith` with `bool clearCoverImage = false` and extend `PlaylistsNotifier.createPlaylist` and `PlaylistsNotifier.updatePlaylist` to accept `String? coverImageUrl` (and `bool clearCoverImage = false`), persisting `cover_image_url` through `PlaylistRepository` -> `PUT/POST /api/playlists` -> D1 (`vhunambi_db.ts#L3129-3134`).
- **THE SYSTEM SHALL** add a custom cover picker & preview tile (`Key('playlist_pick_cover_btn')`, plus reset-to-collage `Key('playlist_clear_cover_btn')`) backed by `VhunambiMediaUploadService` inside `_CreatePlaylistDialog`, `_RenamePlaylistDialog`, and `PlaylistDetailView` (including a `'Change Cover'` menu option `Key('playlist_detail_edit_cover_item')`).

### `REQ-P77-R2-04` — Collections Custom Cover Parity (Optional Local Model Extension)
- **WHERE** `CollectionsNotifier` creates or updates a `CollectionEntity`, **THE SYSTEM SHALL** accept optional `String? coverImageUrl` so `CollectionEntity.coverImageUrl` (`collection_entity.dart#L157`) can be updated cleanly alongside `PlaylistsNotifier` without breaking existing Hive persistence.

### `REQ-P77-REEL-01` — Visitor-Accessible One-Tap "Share as Reel" on `TrackDetailView`
- **THE SYSTEM SHALL** add an optional `VoidCallback? onShareAsReel` parameter and pill (`Key('track_reel_pill')`, `AppIcons.reels` (`PhosphorIconsRegular.filmStrip`), label `'Reel'`, `minHeight: 44`) to `TrackActionsBar` (`track_actions_bar.dart`).
- **THE SYSTEM SHALL** wire `onShareAsReel: () => _openVideoExport(track)` inside `TrackDetailView` for **both** `ViewerRole.visitor` and `ViewerRole.owner`, launching `KineticReelStudioView.show(context, initialTrack: libTrack)` in one tap while keeping owner-only Mastering/Stems/Licensing tools inside `if (isTrackOwner)`.

---

## 5. Pillar 4 — `STD-UIUX-001` & Dual-Theme Contrast Sweep (`REQ-P77-UIUX-*`)

### `REQ-P77-UIUX-01` — Zero Stock Material `Icons.*` Across Audited Modules
- **THE SYSTEM SHALL** replace all **68** stock `Icons.*` references and **5** raw `Icon(PhosphorIcons...)` wrappers identified in `PHASE77_CHROMATIC_PLAYER_LYRICS_AND_R2_UPLOADS_AUDIT.md` §4 across `player/`, `track/`, `playlists/`, `collections/`, and `explore/` with `PhosphorIcon(PhosphorIconsRegular.* / PhosphorIconsFill.* / AppIcons.*)`.

### `REQ-P77-UIUX-02` — Zero Raw Unicode Emojis in UI/Domain Labels
- **THE SYSTEM SHALL** eliminate all **19** raw Unicode emoji lines across `stem_mix_bounce_service.dart` (`4`), `stem_mixer_state.dart` (`4`), `collection_detail_view.dart` (`2`), `split_sheet_modal.dart` (`1`), and `explore_models.dart` (`8`), using Phosphor icon tokens or plain clean text labels.

### `REQ-P77-UIUX-03` — Light & Dark Theme Parity
- **THE SYSTEM SHALL** migrate static dark surface/text/border tokens (`AppColors.surfaceModal`, `AppColors.surfaceElevated`, `AppColors.textPrimary`, `AppColors.textSecondary`, `AppColors.borderSubtle`) inside all Phase 77 touched views (`ExpandedCockpitModal`, `MobileMiniPlayer`, `DesktopTransportBar`, `QueueDrawer`, `VhunambiFloatingTransportSurface`, `LyricsTeleprompter`, `CreateKineticPostSheet`, `PlaylistsVaultView`, `PlaylistDetailView`, `CollectionDetailView`, `CollectionFormDialog`) to `AppColors.*Of(context)`.

---

## 6. Non-Functional & Performance Requirements (`REQ-P77-NFR-*`)

- **`REQ-P77-NFR-01` (60 FPS Frame Budget):** Synced lyric index calculation and chromatic first-frame resolution MUST execute in $< 1\text{ms}$ per frame with zero unbounded allocations inside `build()`.
- **`REQ-P77-NFR-02` (Test Determinism & Anti-Hang):** All async image extraction and media pickers MUST bypass live network/platform calls under `FLUTTER_TEST` and finish cleanly under `--timeout=60s`.
- **`REQ-P77-NFR-03` (Zero New Native Dependencies):** Phase 77 MUST NOT add new native Android/iOS plugins to `pubspec.yaml`.
- **`REQ-P77-NFR-04` (Pure Dart Domain Testability):** `SyncedLyricTimeline` and `BantuLyricTranslationService.lookupWord` MUST remain pure Dart (zero `dart:io` or network dependencies) and pass headless unit tests.

---

## 7. Requirement-to-Test Traceability Matrix

```text
┌───────────────────┬────────────────────────────────────────────┬──────────────────────────────────────────────────────┐
│ Requirement ID    │ Target Implementation File                 │ Verification Test / Gate                             │
├───────────────────┼────────────────────────────────────────────┼──────────────────────────────────────────────────────┤
│ REQ-P77-CHROM-01  │ player_chromatic_resolver_mixin.dart       │ phase77 test: sync+async palette & stale sig guard   │
│ REQ-P77-CHROM-02  │ expanded_cockpit_modal.dart                │ phase77 test: Light+Dark backdrop & VhunambiArtwork  │
│ REQ-P77-CHROM-03  │ pill_form.dart                             │ phase77 test: PillForm renders cleanly w/o network   │
│ REQ-P77-CHROM-04  │ mobile_mini_player.dart, bottom_dock_kit   │ phase77 test: Light/Dark dock & artwork thumbnails   │
│ REQ-P77-CHROM-05  │ queue_drawer.dart, track_detail_view.dart  │ phase77 test: QueueDrawer Light/Dark + 0 Icons.*     │
│ REQ-P77-LYR-01    │ expanded_cockpit_modal.dart, teleprompter  │ phase77 test: [Intro]/[shakers] stripped + Copy icon │
│ REQ-P77-LYR-02    │ synced_lyric_timeline.dart, teleprompter   │ phase77 test: active line index & tap-to-seek        │
│ REQ-P77-LYR-03/04 │ bantu_lyric_translation_service.dart,sheet │ phase77 test: 9-lang lookupWord + glossary popover   │
│ REQ-P77-LYR-05    │ expanded_cockpit_modal.dart                │ phase77 test: player resolves lyrics from detail     │
│ REQ-P77-R2-01     │ vhunambi_media_upload_service.dart         │ phase77 test: MIME/25MB guard + uploadReelMedia      │
│ REQ-P77-R2-02     │ create_kinetic_post_sheet.dart             │ phase77 test: photo upload attaches /r2/social/...   │
│ REQ-P77-R2-03/04  │ playlists_provider.dart, vault/detail      │ phase77 test: playlist cover R2 upload + persistence │
│ REQ-P77-REEL-01   │ track_actions_bar.dart, track_detail_view  │ phase77 test: visitor taps track_reel_pill -> Studio │
│ REQ-P77-UIUX-01/3 │ Audited player/track/playlists/explore     │ G77-05 regex scan (0 Icons.*, 0 emojis) + G77-01     │
└───────────────────┴────────────────────────────────────────────┴──────────────────────────────────────────────────────┘
```

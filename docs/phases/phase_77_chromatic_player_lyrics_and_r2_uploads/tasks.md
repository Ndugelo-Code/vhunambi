# Phase 77 Execution Tasks (`tasks.md`)

**Phase ID:** `P77` — Chromatic Full-Screen Player, Synced Sing-Along Lyrics & Unified R2 Media Uploads  
**Execution Protocol:** Execute strictly in **two sequential passes** (`Pass 1: M77.1–M77.2`, verify `G77-01`–`G77-03`, then `Pass 2: M77.3–M77.4`, verify `G77-01`–`G77-06`, update `memory.md` to `"completed"`, and run `consolidate_memory.mjs`).

---

## 1. Master Milestone Roadmap & Dependency Graph

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ PASS 1: LIVING CHROMATIC PLAYER & SYNCED 9-LANGUAGE BANTU KARAOKE            │
│   [M77.1] Chromatic Player Chrome + Dock Kit Light/Dark + PillForm Cleanup   │
│      └──► [M77.2] SyncedLyricTimeline + 9-Lang Bantu Glossary + Player Sync  │
│      └──► GATE CHECK: dart analyze + player/track tests pass 100%            │
├──────────────────────────────────────────────────────────────────────────────┤
│ PASS 2: UNIFIED R2 MEDIA UPLOADS, VISITOR REEL SHARE & STD-UIUX-001 SWEEP    │
│   [M77.3] VhunambiMediaUploadService + Explore Posts + Playlist R2 Covers +  │
│           TrackActionsBar Visitor 'Reel' Pill                                │
│      └──► [M77.4] STD-UIUX-001 Sweep + Phase 77 Regression Suite + SLEEP     │
│      └──► FINAL GATES: G77-01 through G77-06 + consolidate_memory.mjs        │
└──────────────────────────────────────────────────────────────────────────────┘
```

| Milestone | Pass | Task IDs | Primary Targets |
| :--- | :---: | :--- | :--- |
| **`M77.1`** | Pass 1 | `T77.1.1` – `T77.1.4` | `player_chromatic_resolver_mixin.dart`, `vhunambi_bottom_dock_kit.dart`, `pill_form.dart`, `mobile_mini_player.dart`, `desktop_transport_bar.dart`, `expanded_cockpit_modal.dart`, `queue_drawer.dart`, `track_detail_view.dart` |
| **`M77.2`** | Pass 1 | `T77.2.1` – `T77.2.4` | `synced_lyric_timeline.dart`, `bantu_lyric_translation_service.dart`, `bantu_word_glossary_sheet.dart`, `lyrics_teleprompter.dart`, `expanded_cockpit_modal.dart` |
| **`M77.3`** | Pass 2 | `T77.3.1` – `T77.3.4` | `vhunambi_media_upload_service.dart`, `create_kinetic_post_sheet.dart`, `playlist_entity.dart`, `playlists_provider.dart`, `playlists_vault_view.dart`, `playlist_detail_view.dart`, `collections_provider.dart`, `track_actions_bar.dart`, `track_detail_view.dart` |
| **`M77.4`** | Pass 2 | `T77.4.1` – `T77.4.4` | Remaining `STD-UIUX-001` files in `player/`, `playlists/`, `collections/`, `explore/`, `phase77_chromatic_player_lyrics_r2_test.dart`, `memory.md` SLEEP |

---

## 2. Pass 1 — `M77.1`: Living Chromatic Player & Surface Parity

- [x] **T77.1.1 — Create `PlayerChromaticPaletteMixin` (`REQ-P77-CHROM-01`)**
  - **Target:** `apps/vhunambi_client/lib/features/player/presentation/widgets/player_chromatic_resolver_mixin.dart`
  - **Action:** Implement `resolvePlayerChromaticPalette(BuildContext, Track?)` (wrapping `PostChromaticPaletteResolver.resolveSync` + signature-guarded `resolveAsync`) and `buildChromaticStageDecoration(...)` per `design.md` §2.1.
  - **Acceptance:** First-frame palette resolves synchronously with zero network timers in `FLUTTER_TEST`; stale async replies are ignored on track/theme switches.

- [x] **T77.1.2 — Adapt `VhunambiFloatingTransportSurface` & Clean `PillForm` (`REQ-P77-CHROM-03`, `REQ-P77-CHROM-04`)**
  - **Target:** `apps/vhunambi_client/lib/core/widgets/vhunambi_bottom_dock_kit.dart`, `apps/vhunambi_client/lib/features/player/presentation/widgets/pill_form.dart`
  - **Action:** Migrate dock kit surfaces/borders to `AppColors.*Of(context)` + optional `borderTint`; delete `PaletteGenerator.fromImageProvider(NetworkImage(...))` from `pill_form.dart` and wire `PlayerChromaticPaletteMixin` (`Key('pill_chromatic_surface')`).
  - **Acceptance:** `pill_form.dart` has `0` imports of `palette_generator`; Light and Dark renders maintain crisp borders and contrast.

- [x] **T77.1.3 — Upgrade `MobileMiniPlayer` & `DesktopTransportBar` (`REQ-P77-CHROM-04`, `REQ-P77-UIUX-01`)**
  - **Target:** `apps/vhunambi_client/lib/features/player/presentation/widgets/mobile_mini_player.dart`, `apps/vhunambi_client/lib/features/player/presentation/widgets/desktop_transport_bar.dart`
  - **Action:** Wire `PlayerChromaticPaletteMixin`, replace `AppGradients.forGenre` + `AppIcons.piano` thumbnails with `VhunambiTrackArtwork` (`Key('mini_player_artwork')`, `Key('desktop_transport_artwork')`), migrate static dark tokens to `Of(context)`, and replace 3 `Icons.*` + raw `Icon(...)` calls in `DesktopTransportBar` with `PhosphorIcon`.
  - **Acceptance:** Both bars display real track artwork + chromatic accent in Light & Dark modes with `0` stock `Icons.*`.

- [x] **T77.1.4 — Upgrade `ExpandedCockpitModal` Stage, `QueueDrawer` & `_FrostedStemMixerSheet` (`REQ-P77-CHROM-02`, `REQ-P77-CHROM-05`)**
  - **Target:** `apps/vhunambi_client/lib/features/player/presentation/widgets/expanded_cockpit_modal.dart`, `apps/vhunambi_client/lib/features/player/presentation/widgets/queue_drawer.dart`, `apps/vhunambi_client/lib/features/track/presentation/views/track_detail_view.dart`
  - **Action:** Paint `ExpandedCockpitModal` (`Key('cockpit_chromatic_backdrop')`) with `buildChromaticStageDecoration`, swap hero box (`#L379-399`) to `VhunambiTrackArtwork(key: const Key('cockpit_hero_artwork'))` + chromatic aura shadow, convert static Dark tokens to `Of(context)`, replace raw `Icon(...)` (`#L593,638,673`) with `PhosphorIcon`, and migrate `QueueDrawer` (8 `Icons.*` + dark tokens) + `_FrostedStemMixerSheet`/`_StickyTrackTitle` to `Of(context)` + `PhosphorIcon`.
  - **Acceptance:** Full-screen player and queue/stem modals adapt seamlessly in Light and Dark themes.

---

## 3. Pass 1 — `M77.2`: Clean Synced Karaoke & 9-Language Bantu Glossary

- [x] **T77.2.1 — Create Pure-Dart `SyncedLyricTimeline` (`REQ-P77-LYR-02`, `REQ-P77-NFR-04`)**
  - **Target:** `apps/vhunambi_client/lib/features/track/domain/utils/synced_lyric_timeline.dart`
  - **Action:** Implement `extractLines`, `resolveActiveLineIndex`, and `seekTargetForLine` per `design.md` §3.1.
  - **Acceptance:** Exact monotonic round-trip for any valid `lineCount` and `duration`; returns `-1` for empty lines or zero duration.

- [x] **T77.2.2 — Upgrade `BantuLyricTranslationService` to 9 Languages + `lookupWord` (`REQ-P77-LYR-03`, `REQ-P77-LYR-04`)**
  - **Target:** `apps/vhunambi_client/lib/features/studio/domain/services/bantu_lyric_translation_service.dart`
  - **Action:** Add `allBantuLanguageCodes` (all 9 ISO codes), `BantuWordDefinition`, `lookupWord(...)`, and `resolveLanguageCode(...)`; update default `targetCognateLanguages` in `processLyrics` and `translateLine` to `allBantuLanguageCodes`.
  - **Acceptance:** `lookupWord` resolves curated meanings, branch labels, penultimate-stress syllables, and cross-branch cognates across all 9 Southern Bantu languages.

- [x] **T77.2.3 — Create `BantuWordGlossarySheet` (`REQ-P77-LYR-04`)**
  - **Target:** `apps/vhunambi_client/lib/features/track/presentation/widgets/bantu_word_glossary_sheet.dart`
  - **Action:** Implement `VhunambiGlassSurface(enableLiveBlur: false)` modal (`Key('bantu_word_glossary_sheet')`) showing word, language/branch badge, styled penultimate-stress phonetic breakdown, meaning, and cognate chips.
  - **Acceptance:** Renders cleanly in Light & Dark modes with `44x44` close button and zero raw emojis.

- [x] **T77.2.4 — Upgrade `LyricsTeleprompter` & Wire into `ExpandedCockpitModal._buildLyricsCard` (`REQ-P77-LYR-01`, `REQ-P77-LYR-02`, `REQ-P77-LYR-05`)**
  - **Target:** `apps/vhunambi_client/lib/features/track/presentation/widgets/lyrics_teleprompter.dart`, `apps/vhunambi_client/lib/features/player/presentation/widgets/expanded_cockpit_modal.dart`
  - **Action:** Convert `LyricsTeleprompter` to `ConsumerStatefulWidget`, watch `playerStateProvider` for live active-line highlight (`Key('synced_lyrics_active_line')`), auto-scroll via `Scrollable.ensureVisible`, tap-to-seek, tappable Bantu word tokens -> `BantuWordGlossarySheet`, `AppColors.*Of(context)`, and `PhosphorIcon`; embed inside `ExpandedCockpitModal._buildLyricsCard` (with `libraryTracksProvider` + `trackDetailProvider` fallback and `PhosphorIconsRegular.copy` on `Key('cockpit_copy_lyrics')`).
  - **Acceptance:** Zero `[Intro]`/`[Crisp soft shakers]` leaks in player or track view; Pass 1 gates (`dart analyze` + player/track tests) pass 100%.

---

## 4. Pass 2 — `M77.3`: Unified R2 Media Uploads & Visitor "Share as Reel"

- [x] **T77.3.1 — Create `VhunambiMediaUploadService` (`REQ-P77-R2-01`)**
  - **Target:** `apps/vhunambi_client/lib/core/media/vhunambi_media_upload_service.dart`
  - **Action:** Implement `pickAndUploadImage` with `ImagePicker`, `FLUTTER_TEST` deterministic bypass, MIME (`jpeg`/`png`/`webp`) & `<= 25 MB` validation, and `ISocialRepository.uploadReelMedia` delegation per `design.md` §4.1.
  - **Acceptance:** Unit-testable without platform channels; rejects oversized/invalid payloads cleanly.

- [x] **T77.3.2 — Wire Real R2 Photo Uploads into `CreateKineticPostSheet` (`REQ-P77-R2-02`)**
  - **Target:** `apps/vhunambi_client/lib/features/explore/presentation/widgets/create_kinetic_post_sheet.dart`
  - **Action:** Delete `_mockPickImage` and hardcoded CDN URL; bind `Key('kpost_pick_photo_btn')` to `VhunambiMediaUploadService.pickAndUploadImage` with inline loading state; migrate sheet surfaces/controls to `VhunambiGlassSurface` + `AppColors.*Of(context)` and remove hardcoded `'Limpopo / Polokwane'`.
  - **Acceptance:** Uploaded photo attaches `/r2/social/...` URL to `SocialMusicPost` and persists cleanly via `socialFeedPostsProvider.notifier.addPost`.

- [x] **T77.3.3 — Wire Custom R2 Cover Uploads into Playlists & Collections (`REQ-P77-R2-03`, `REQ-P77-R2-04`)**
  - **Target:** `apps/vhunambi_client/lib/features/playlists/domain/models/playlist_entity.dart`, `playlists_provider.dart`, `playlists_vault_view.dart`, `playlist_detail_view.dart`, `apps/vhunambi_client/lib/features/collections/domain/models/collection_entity.dart`, `collections_provider.dart`
  - **Action:** Add `clearCoverImage` to `copyWith`, accept `coverImageUrl` in `createPlaylist` / `updatePlaylist` (and `createCollection` / `updateCollection`), add cover preview + `Key('playlist_pick_cover_btn')` + `Key('playlist_clear_cover_btn')` in playlist dialogs, and add `Key('playlist_detail_edit_cover_item')` to `PlaylistDetailView`.
  - **Acceptance:** Custom uploaded cover URL persists to Hive + `/api/playlists` and renders immediately in `PlaylistCoverArt`.

- [x] **T77.3.4 — Expose Visitor-Accessible "Share as Reel" on `TrackDetailView` (`REQ-P77-REEL-01`)**
  - **Target:** `apps/vhunambi_client/lib/features/track/presentation/widgets/track_actions_bar.dart`, `apps/vhunambi_client/lib/features/track/presentation/views/track_detail_view.dart`
  - **Action:** Add `onShareAsReel` + `Key('track_reel_pill')` (`AppIcons.reels`, `'Reel'`) to `TrackActionsBar` and wire `onShareAsReel: () => _openVideoExport(track)` in `TrackDetailView` for both visitors and owners.
  - **Acceptance:** Visitor tapping `Key('track_reel_pill')` opens `KineticReelStudioView` preloaded with the track.

---

## 5. Pass 2 — `M77.4`: `STD-UIUX-001` Sweep, Regression Suite & Memory SLEEP

- [x] **T77.4.1 — Clear Remaining `Icons.*`, Raw Emojis & Dark Tokens (`REQ-P77-UIUX-01..03`)**
  - **Target:** `playlist_detail_view.dart`, `add_to_playlist_sheet.dart`, `collection_detail_view.dart`, `collection_form_dialog.dart`, `collection_type_badge.dart`, `add_to_collection_sheet.dart`, `split_sheet_modal.dart`, `stem_mix_bounce_service.dart`, `stem_mixer_state.dart`, `explore_models.dart`, `explore_search_view.dart`, `african_charts_banner.dart`, `catalog_filter_bar.dart`, `explore_empty_state.dart`, `genre_glyph.dart`, `track_card.dart`, `track_list_tile.dart`
  - **Action:** Execute every replacement in `design.md` §5 without breaking existing tests (update any unit test asserting old emoji strings if applicable).
  - **Acceptance:** `G77-05` regex scan returns `0` stock `Icons.*` and `0` raw Unicode emojis across audited modules.

- [x] **T77.4.2 — Author Dedicated Phase 77 Regression Suite (`G77-02..G77-06`)**
  - **Target:** `apps/vhunambi_client/test/features/phase77_chromatic_player_lyrics_r2_test.dart`
  - **Action:** Write headless unit + widget tests covering:
    1. `SyncedLyricTimeline` monotonic active-line & tap-to-seek round-trip.
    2. `BantuLyricTranslationService.lookupWord` across all 9 Bantu languages + `BantuWordGlossarySheet` render.
    3. `ExpandedCockpitModal` + `MobileMiniPlayer` + `PillForm` chromatic Light/Dark rendering + `[Intro]` sanitization + `PhosphorIconsRegular.copy`.
    4. `VhunambiMediaUploadService` MIME/25MB validation + `CreateKineticPostSheet` R2 photo upload + `PlaylistsNotifier` custom R2 cover upload.
    5. `TrackDetailView` visitor `Key('track_reel_pill')` -> `KineticReelStudioView`.
  - **Acceptance:** 100% pass under `flutter test --no-pub --timeout=60s`.

- [x] **T77.4.3 — Execute Full Verification Gates (`G77-01` – `G77-06`)**
  - **Action:** Run all commands in §6 below and confirm zero regressions.

- [x] **T77.4.4 — Finalize Phase 77 Memory & Connectome Consolidation (SLEEP)**
  - **Target:** `docs/phases/phase_77_chromatic_player_lyrics_and_r2_uploads/memory.md`
  - **Action:** Update `"status": "completed"`, `"completed_at"`, verified `code_anchor`s, breakthroughs, and gotchas ONLY after all gates pass; run `node .agents/skills/vhunambi-memory/scripts/consolidate_memory.mjs` and confirm `0 OPEN` endpoints.

---

## 6. Stage 4 Execution Verification Commands

```powershell
# G77-01: Dart Static Analysis
Set-Location apps/vhunambi_client
dart analyze

# G77-05: STD-UIUX-001 Icon & Raw Emoji Scan across Phase 77 scope
Set-Location c:\Users\Ndugelo\VHUNAMBI\monorepo
Select-String -Path (Get-ChildItem -Recurse apps/vhunambi_client/lib/features/player,apps/vhunambi_client/lib/features/track,apps/vhunambi_client/lib/features/playlists,apps/vhunambi_client/lib/features/collections,apps/vhunambi_client/lib/features/explore -Filter *.dart) -Pattern "Icons\."

# G77-06: Targeted Flutter Test Suites (Anti-Hang --no-pub --timeout=60s)
Set-Location apps/vhunambi_client
flutter test test/features/phase77_chromatic_player_lyrics_r2_test.dart test/features/player test/features/track test/features/playlists test/features/collections test/features/explore --no-pub --timeout=60s

# SLEEP: Consolidate Vhunambi Codebase Brain
Set-Location c:\Users\Ndugelo\VHUNAMBI\monorepo
node .agents/skills/vhunambi-memory/scripts/consolidate_memory.mjs
```

# Phase 12 · Tasks — Studio Lyrics Review Cockpit & Playlists Queue Management

> **Phase:** 12  
> **Codename:** `lyrics-and-playlists`  
> **Baseline Gate:** `dart analyze .` = 0 issues · `flutter test` = all baseline tests passing  
> **Target:** ≥ 35 new automated unit and widget tests (target total: ≥ 380 passing tests)  

---

## Task Breakdown

### T12.1 — Domain Models & Entity Unit Tests
- [ ] Create `lib/features/studio/domain/models/lyrics_review_models.dart`:
  - `LyricsSectionType` enum (`intro`, `verse`, `chorus`, `hook`, `bridge`, `outro`)
  - `LyricsSection` class with `id`, `type`, `header`, `lines`, `rhymeNotes`, `copyWith`, `toFormattedString()`
  - `LyricsReviewDraft` class with `prompt`, `genre`, `language`, `sections`, `culturalIdioms`, `isRawEditorMode`, `rawText`
- [ ] Create `lib/features/playlists/domain/models/playlist_entity.dart`:
  - `PlaylistEntity` class with `id`, `title`, `description`, `coverImageUrl`, `trackIds`, `createdAt`, `updatedAt`, `isPublic`, `copyWith`, `toJson`, `fromJson`
- [ ] Create `test/features/studio/domain/models/lyrics_review_models_test.dart` (≥ 6 tests)
- [ ] Create `test/features/playlists/domain/models/playlist_entity_test.dart` (≥ 6 tests)
- [ ] **Gate:** `flutter test test/features/studio/domain/models/lyrics_review_models_test.dart test/features/playlists/domain/models/playlist_entity_test.dart`

---

### T12.2 — Services & Test Doubles
- [ ] Create `lib/features/studio/domain/services/i_lyrics_generation_service.dart`
- [ ] Create `lib/features/studio/data/services/fake_lyrics_generation_service.dart` with deterministic generation for Tshivenḓa, isiZulu, Sepedi, Swahili, and Amapiano presets
- [ ] Create `lib/features/playlists/domain/repositories/i_playlist_repository.dart`
- [ ] Create `lib/features/playlists/data/repositories/in_memory_playlist_repository.dart` (headless test safe)
- [ ] Create `test/features/studio/data/services/fake_lyrics_generation_service_test.dart` (≥ 5 tests)
- [ ] Create `test/features/playlists/data/repositories/playlist_repository_test.dart` (≥ 6 tests)
- [ ] **Gate:** `flutter test test/features/studio/data/services/ test/features/playlists/data/repositories/`

---

### T12.3 — Riverpod State Notifiers (Lyrics Review & Playlists)
- [ ] Create `lib/features/studio/presentation/providers/lyrics_review_provider.dart`:
  - `lyricsGenerationServiceProvider`
  - `lyricsReviewProvider` (`LyricsReviewNotifier`)
  - Methods: `loadGeneratedLyrics`, `updateSectionLines`, `insertIdiom`, `toggleEditorMode`, `updateRawText`, `clear`
- [ ] Create `lib/features/playlists/presentation/providers/playlists_provider.dart`:
  - `playlistRepositoryProvider`
  - `playlistsProvider` (`PlaylistsNotifier`)
  - Methods: `loadPlaylists`, `createPlaylist`, `deletePlaylist`, `toggleTrackInPlaylist`
- [ ] Create `test/features/studio/presentation/providers/lyrics_review_provider_test.dart` (≥ 6 tests)
- [ ] Create `test/features/playlists/presentation/providers/playlists_provider_test.dart` (≥ 6 tests)
- [ ] **Gate:** `flutter test test/features/studio/presentation/providers/ test/features/playlists/presentation/providers/`

---

### T12.4 — PlayerNotifier Queue Enhancements
- [ ] Update `lib/features/player/presentation/providers/player_provider.dart` with queue management:
  - `addToQueue(Track track)`
  - `playNext(Track track)`
  - `removeFromQueue(int index)`
  - `reorderQueue(int oldIndex, int newIndex)`
  - `clearUpcomingQueue()`
  - `playPlaylist(PlaylistEntity playlist, List<Track> tracks)`
- [ ] Create `test/features/player/player_queue_management_test.dart` (≥ 8 tests verifying queue mutation, reordering, active index calculation, and edge cases)
- [ ] **Gate:** `flutter test test/features/player/player_queue_management_test.dart`

---

### T12.5 — Studio Lyrics Review Modal Widget & Studio Integration
- [ ] Create `lib/features/studio/presentation/widgets/lyrics_review_modal.dart`:
  - Responsive dialog (Desktop) vs expandable bottom sheet (Mobile)
  - Section Stanza cards (`_LyricsSectionCard`) with line editors
  - Cultural Idiom tray (`_CulturalIdiomsRail`) with one-tap insertion chips
  - Raw editor toggle (`_RawLyricsEditor`)
  - Primary CTA `"Approve & Produce Beat ➔"` transitioning form to `GenerationPhase.queued` and triggering `generationProgressProvider`
- [ ] Wire `StudioActionBar`: when `lyricsMode == aiWrite`, tapping CTA generates lyrics and opens `LyricsReviewModal`
- [ ] Create `test/features/studio/presentation/widgets/lyrics_review_modal_test.dart` (≥ 6 widget tests)
- [ ] **Gate:** `flutter test test/features/studio/presentation/widgets/lyrics_review_modal_test.dart`

---

### T12.6 — Playback Queue Drawer Widget
- [ ] Create `lib/features/player/presentation/widgets/queue_drawer.dart`:
  - Header with track count badge, `"Clear"` button, and dismiss icon
  - Now Playing card with live equalizer animation
  - `ReorderableListView` for upcoming tracks with drag handles and remove triggers
- [ ] Wire queue button (`📑`) in `DesktopTransportBar` and `ExpandedCockpitModal` to trigger `QueueDrawer.show(context)`
- [ ] Create `test/features/player/widgets/queue_drawer_test.dart` (≥ 6 widget tests)
- [ ] **Gate:** `flutter test test/features/player/widgets/queue_drawer_test.dart`

---

### T12.7 — Add to Playlist Sheet & Library Vault Integration
- [ ] Create `lib/features/playlists/presentation/widgets/add_to_playlist_sheet.dart`:
  - Search field, user playlist checkboxes, inline new playlist creator
- [ ] Update `DesktopTransportBar` (`➕`) and `TrackActionsSheet` to invoke `AddToPlaylistSheet.show(context, track)`
- [ ] Create `lib/features/playlists/presentation/views/playlists_vault_view.dart` mounted at `/library?tab=playlists`
- [ ] Create `lib/features/playlists/presentation/views/playlist_detail_view.dart` with Play All, Shuffle, and track management
- [ ] Create `test/features/playlists/presentation/widgets/add_to_playlist_sheet_test.dart` (≥ 5 widget tests)
- [ ] **Gate:** `flutter test test/features/playlists/presentation/widgets/add_to_playlist_sheet_test.dart`

---

### T12.8 — Phase 12 Final Gate & Documentation
- [ ] Run `dart analyze .` (0 issues)
- [ ] Run full `flutter test` suite (≥ 380 total passing tests, 0 regressions)
- [ ] Update `docs/AGENT_HANDOFF_BIBLE.md` with Phase 12 completion
- [ ] Update `README.md` status table
- [ ] Generate `docs/phases/phase_12_lyrics_and_playlists/walkthrough.md`

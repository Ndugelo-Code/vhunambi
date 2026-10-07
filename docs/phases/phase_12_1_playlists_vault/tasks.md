# Phase 12.1 · Tasks — Playlists Vault Views & Hive Persistence

> **Phase:** 12.1  
> **Codename:** `playlists-vault`  
> **Baseline Gate:** `dart analyze .` = 0 issues · `flutter test` = **460/460 passing**  
> **Target:** ≥ 15 new automated unit and widget tests (target total: ≥ 475 passing tests)  

---

## Task Breakdown

### T12.1.1 — Constant & Production Hive Repository
- [ ] Add `static const String playlistsBoxKey = 'vhunambi_playlists';` to `lib/core/constants/app_constants.dart`
- [ ] Create `lib/features/playlists/data/repositories/playlist_repository.dart` implementing `IPlaylistRepository` with Hive box and in-memory test fallback
- [ ] Update `playlistRepositoryProvider` in `lib/features/playlists/presentation/providers/playlists_provider.dart` to default to `PlaylistRepository()`
- [ ] Create `test/features/playlists/data/repositories/hive_playlist_repository_test.dart` (≥ 6 tests verifying Hive/in-memory fallback CRUD)
- [ ] **Gate:** `flutter test test/features/playlists/data/repositories/hive_playlist_repository_test.dart`

---

### T12.1.2 — Playlists Vault View & Cards
- [ ] Create `lib/features/playlists/presentation/views/playlists_vault_view.dart`:
  - Empty state with `LibraryEmptyState` and `CreatePlaylistDialog` trigger
  - Responsive 2-to-4 col grid and list views
  - `PlaylistCard` with 4-track artwork mosaic / gradient fallback, metadata, and context menu (Rename, Delete)
- [ ] Create `test/features/playlists/presentation/views/playlists_vault_view_test.dart` (≥ 5 widget tests)
- [ ] **Gate:** `flutter test test/features/playlists/presentation/views/playlists_vault_view_test.dart`

---

### T12.1.3 — Playlist Detail View
- [ ] Create `lib/features/playlists/presentation/views/playlist_detail_view.dart`:
  - Hero header with cover artwork mosaic, title, description, track count, formatted cumulative duration
  - `"▶ Play All"` calling `ref.read(playerStateProvider.notifier).playPlaylist(...)`
  - `"🔀 Shuffle"` calling `playPlaylist` with shuffled tracks
  - Track list rows with index, metadata, and removal action (`removeTrackFromPlaylist`)
- [ ] Create `test/features/playlists/presentation/views/playlist_detail_view_test.dart` (≥ 5 widget tests)
- [ ] **Gate:** `flutter test test/features/playlists/presentation/views/playlist_detail_view_test.dart`

---

### T12.1.4 — Library View Wiring
- [ ] Update `lib/features/library/presentation/views/library_view.dart`:
  - When `category == LibraryCategory.playlists`, render `PlaylistsVaultView(onCreateRequested: onCreateRequested)`
- [ ] Verify existing `library_view_test.dart` passes without regressions

---

### T12.1.5 — Phase 12.1 Final Gate & Documentation
- [ ] Run `dart analyze .` (0 issues)
- [ ] Run full `flutter test` suite (≥ 475 total passing tests, 0 regressions)
- [ ] Create `docs/phases/phase_12_1_playlists_vault/walkthrough.md`
- [ ] Update `docs/AGENT_HANDOFF_BIBLE.md` and `README.md`

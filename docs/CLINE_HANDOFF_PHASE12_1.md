# Phase 12.1 Master Handoff: Playlists Vault Views & Hive Persistence

> **Document Purpose:** Single authoritative handoff guide for any agent (Antigravity / Cline / Cursor) implementing Phase 12.1. Read this first — it captures exact requirements, architectural invariants, full class designs, and the execution checklist.
>
> **Generated At:** 2026-09-27T01:02:00+02:00  
> **Lead Architect:** Antigravity (Dual-Agent Symbiosis Protocol)  
> **Repository Root:** `c:\Users\Ndugelo\VHUNAMBI\monorepo\`  
> **Client Workspace:** `apps/vhunambi_client/`  
> **Current Baseline:** `dart analyze .` = **0 issues** | `flutter test` = **460/460 passing (100%)**  
> **Target Test Count:** **≥ 475 tests (≥ 15 new tests)**

---

## 1. Phase 12.1 Objectives & Scope

Phase 12.1 closes the remaining deferred items from Subsystem B (Playlists & Queue Management):

1. **Hive-backed `PlaylistRepository`:**
   - Add `AppConstants.playlistsBoxKey = 'vhunambi_playlists'` in `lib/core/constants/app_constants.dart`.
   - Implement `PlaylistRepository` in `lib/features/playlists/data/repositories/playlist_repository.dart` backed by Hive box with headless in-memory fallback.
   - Wire `playlistRepositoryProvider` to default to `PlaylistRepository()`.
2. **`PlaylistsVaultView`:**
   - Mounted inside `LibraryView` when `category == LibraryCategory.playlists`.
   - Empty state using `LibraryEmptyState(category: LibraryCategory.playlists)` with create CTA.
   - Populated state rendering `PlaylistCard`s in 2/3/4-col grid or list with 4-track mosaic artwork, track count, playtime, and rename/delete menu.
3. **`PlaylistDetailView`:**
   - Dedicated playlist detail route displaying cover mosaic, title, description, and metadata.
   - `"▶ Play All"` and `"🔀 Shuffle"` calling `PlayerNotifier.playPlaylist(...)`.
   - Table of tracks in the playlist with individual track remove action.
4. **Library Integration:**
   - Wire `LibraryView` to render `PlaylistsVaultView` when category is `playlists`.
5. **Zero-Regression Guarantee:**
   - Pass all 460 baseline tests with 0 analyzer issues and add $\ge 15$ new tests.

---

## 2. Specification Documents (Single Source of Truth)

Read and adhere to all 4 documents in `docs/phases/phase_12_1_playlists_vault/`:

- [`blueprint.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_12_1_playlists_vault/blueprint.md)
- [`requirements.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_12_1_playlists_vault/requirements.md)
- [`design.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_12_1_playlists_vault/design.md)
- [`tasks.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_12_1_playlists_vault/tasks.md)

---

## 3. Codebase Invariants (NEVER BREAK THESE)

1. **Zero Raw Hex Values:** Always use `AppColors.*`, `AppTypography.*`, `AppRadius.*`, `AppSpacing.*`.
2. **Riverpod 2.x only:** `StateNotifierProvider`, `Provider`.
3. **Headless Test Safety:** `PlaylistRepository` must catch Hive initialization exceptions when headless and seamlessly fallback to in-memory backing so unit/widget tests never throw missing plugin / directory errors.
4. **Zero Regressions:** All 460 baseline tests must continue to pass cleanly.

---

## 4. File Map

### New Files to CREATE

```
lib/features/playlists/
  data/repositories/playlist_repository.dart                ← T12.1.1
  presentation/views/
    playlists_vault_view.dart                               ← T12.1.2
    playlist_detail_view.dart                               ← T12.1.3

test/features/playlists/
  data/repositories/hive_playlist_repository_test.dart     ← T12.1.1
  presentation/views/
    playlists_vault_view_test.dart                          ← T12.1.2
    playlist_detail_view_test.dart                          ← T12.1.3
```

### Existing Files to MODIFY

```
lib/core/constants/app_constants.dart                       ← T12.1.1 (add playlistsBoxKey)
lib/features/playlists/presentation/providers/playlists_provider.dart ← T12.1.1 (default to PlaylistRepository)
lib/features/library/presentation/views/library_view.dart   ← T12.1.4 (mount PlaylistsVaultView)
```

---

## 5. Verification Gates

```powershell
cd apps/vhunambi_client

flutter test test/features/playlists/data/repositories/hive_playlist_repository_test.dart
flutter test test/features/playlists/presentation/views/playlists_vault_view_test.dart
flutter test test/features/playlists/presentation/views/playlist_detail_view_test.dart

# Final Phase 12.1 verification gates
dart analyze .
flutter test
```

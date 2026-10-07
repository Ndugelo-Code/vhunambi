# Phase 4 Tasks & Verification Plan: Library & User Asset Vault (`/library`)

> **Status:** ✅ Executed & Verified — 2026-09-22 (0 analysis issues, 47/47 automated tests passing)
> **Target:** `apps/vhunambi_client`  
> **Parent Spec:** `docs/phases/phase_04_library_vault/`

---

## 1. Pre-Flight Codebase Anchors

- [x] Baseline verification: `dart analyze .` reports `0 issues`.
- [x] Automated tests: All 14 existing tests pass cleanly (`flutter test`).
- [x] Token verification: `AppColors`, `AppGradients`, `AppTypography`, `AppRadius`, and `AppSpacing` available in `package:vhunambi_client/core/theme/`.
- [x] Enum safety: No conflicts with `RepeatMode` (use `AudioRepeatMode`).

---

## 2. Sequenced Implementation Tasks

- [x] **Task 4.1: Domain Models & Enums**
  - Path: `lib/features/library/domain/models/library_models.dart`
  - Implement enums: `LibraryCategory`, `LibraryViewMode`, `TrackSyncStatus`.
  - Implement immutable `LibraryTrack` with `copyWith`, `==`, `hashCode`, and formatting getters.

- [x] **Task 4.2: Riverpod State Providers**
  - Path: `lib/features/library/presentation/providers/library_providers.dart`
  - Implement `libraryCategoryProvider`, `librarySearchQueryProvider`, `libraryViewModeProvider`.
  - Implement `LibraryTracksNotifier` and `libraryTracksProvider` with seed production records.
  - Implement filtered selector provider returning tracks matching category and search query.

- [x] **Task 4.3: Header & Category Rail Widgets**
  - Path: `lib/features/library/presentation/widgets/library_app_bar.dart`
    - Responsive layout (Mobile < 768px vs Desktop > 1024px).
    - Brand emblem, credit token badge (`⚡ 10 songs left`), notifications bell, and `✨ Create` CTA.
  - Path: `lib/features/library/presentation/widgets/library_category_rail.dart`
    - Horizontal pill rail with 6 categories: `♪ Songs`, `≡♪ Playlists`, `💿 Collections`, `🛍️ Beats`, `⚖️ Licensing`, `🗑️ Trash`.

- [x] **Task 4.4: Empty State Widget**
  - Path: `lib/features/library/presentation/widgets/library_empty_state.dart`
    - Centered 48x48px squircle container (`#141418`, border `#2D2D38`, radius 14px).
    - Headline, helper copy, and solid orange pill CTA `✨ Create your first song`.

- [x] **Task 4.5: Vault Item Widgets & Contextual Action Sheet**
  - Path: `lib/features/library/presentation/widgets/library_track_tile.dart`
    - Dense list row with cover art, title, artist, duration, offline badge, and `⋮` button.
  - Path: `lib/features/library/presentation/widgets/library_track_grid_card.dart`
    - 2-column square card format.
  - Path: `lib/features/library/presentation/widgets/track_actions_sheet.dart`
    - Modal bottom sheet with actions: Play, Add to Playlist, Stems, Download, Licensing, Trash.

- [x] **Task 4.6: Screen Assembly & RootShell Wiring**
  - Path: `lib/features/library/presentation/views/library_view.dart`
    - Assembles top bar, category rail, search strip, list/grid views, and empty state.
  - In `lib/main.dart`: Replace tab index 3 in `RootShell` with `const LibraryView()`.

- [x] **Task 4.7: Automated Tests & Verification**
  - Write unit tests: `test/features/library/library_notifier_test.dart`.
  - Write widget tests: `test/features/library/library_view_test.dart`.
  - Run `dart analyze .` (must report 0 issues).
  - Run `flutter test` (must report 100% pass rate).

---

## 3. Verification Commands & Gate Thresholds

```powershell
cd apps/vhunambi_client
dart analyze .
flutter test
```

---

## 4. Execution Results (2026-09-22)

### Gate Output
```powershell
cd apps/vhunambi_client
dart analyze .
# Result: Analyzing .... No issues found! (0 issues)

flutter test
# Result: 47 of 47 tests passed! (100%)
```

### Delivered Files
| Artifact | Path |
| :--- | :--- |
| Domain models | `lib/features/library/domain/models/library_models.dart` |
| Riverpod state | `lib/features/library/presentation/providers/library_providers.dart` |
| Responsive header | `lib/features/library/presentation/widgets/library_app_bar.dart` |
| Category rail | `lib/features/library/presentation/widgets/library_category_rail.dart` |
| Universal empty state | `lib/features/library/presentation/widgets/library_empty_state.dart` |
| Vault list row | `lib/features/library/presentation/widgets/library_track_tile.dart` |
| Vault grid card | `lib/features/library/presentation/widgets/library_track_grid_card.dart` |
| Contextual action sheet | `lib/features/library/presentation/widgets/track_actions_sheet.dart` |
| Shared badges / artwork | `lib/features/library/presentation/widgets/library_badges.dart`, `library_cover_art.dart` |
| Screen assembly | `lib/features/library/presentation/views/library_view.dart` |
| Shell wiring | `lib/main.dart` → `RootShell` tab index 3 |
| Unit tests (26) | `test/features/library/library_notifier_test.dart` |
| Widget tests (7) | `test/features/library/library_view_test.dart` |

### Additive Token / Constant Extensions
* `AppRadius.squircle` (14px squircle for the empty-state glyph container).
* `AppConstants.vaultBoxKey` (`library_tracks`) and `AppConstants.vaultAudioDirectory` (`vhunambi_vault/audio`).

### Deferred to Later Phases
* Binary offline audio download/write (Phase 8) — `Download Offline` currently records `localAudioFilePath` + `cachedLocally`.
* Playlist/collection/aggregate asset models — those categories render their universal empty state until their phases land.

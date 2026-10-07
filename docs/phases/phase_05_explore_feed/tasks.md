# Phase 5 Tasks & Verification Plan: Explore Feed & Music Discovery (`/explore`)

> **Status:** ✅ Executed & Verified — 2026-09-23 (0 analysis issues, 78/78 automated tests passing)
> **Target:** `apps/vhunambi_client`  
> **Parent Spec:** `docs/phases/phase_05_explore_feed/`  
> **Source Origin:** [`docs/foundation_blueprints/01_EXPLORE_PAGE_SPEC.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/foundation_blueprints/01_EXPLORE_PAGE_SPEC.md)

---

## 1. Pre-Flight Codebase Anchors

- [x] Baseline verification: `dart analyze .` reports `0 issues`.
- [x] Automated tests: All 47 existing tests pass cleanly (`flutter test`).
- [x] Token verification: `AppColors`, `AppGradients`, `AppTypography`, `AppRadius`, and `AppSpacing` available in `package:vhunambi_client/core/theme/`.
- [x] Enum safety: Audio repeat enum is `AudioRepeatMode` (never `RepeatMode`).
- [x] Shell integration anchor: `RootShell` in `lib/main.dart` mounts `ExploreView` at tab index 1.

---

## 2. Sequenced Implementation Tasks

- [x] **Task 5.1: Domain Models & Enums**
  - Path: `lib/features/explore/domain/models/explore_models.dart`
  - Enums: `ExploreTab` (`discover`, `forYou`, `following`), `ExploreSortBy` (`newest`, `mostLiked`).
  - Immutable `CreatorProfile` entity with `id`, `name`, `handle`, `initials`, `trackCount`, `avatarUrl`, `primaryGenres`, `isVerified`.
  - Ensure compatibility with `Track` model in `lib/shared/models/track.dart` (support optional `mood` or genre tags).

- [x] **Task 5.2: Riverpod State Providers**
  - Path: `lib/features/explore/presentation/providers/explore_providers.dart`
  - State providers: `exploreTabProvider`, `exploreSearchQueryProvider`, `exploreGenreFilterProvider`, `exploreMoodFilterProvider`, `exploreLanguageFilterProvider`, `exploreSortByProvider`.
  - `exploreCreatorsProvider` providing seeded creator profiles (`Sigwa & Inaf`, `Ndugelo`, `DJ Vibe`, `Fifi`, `Sipho`, `Lerato`).
  - `ExploreTracksNotifier` and `exploreTracksProvider` with rich seeded demo tracks reflecting African heritage (Amapiano, Gqom, Kwaito, Maskandi, Afro House, Afrobeats).
  - Computed `filteredExploreTracksProvider` applying real-time search, genre, mood, language, and sorting.
  - Bridge helper `playExploreTrack(WidgetRef ref, Track track)` to route audio playback into `playerStateProvider`.

- [x] **Task 5.3: Top App Bar & Header Widgets**
  - Path: `lib/features/explore/presentation/widgets/explore_top_bar.dart`
    - Responsive header: Desktop 68px top bar with breadcrumb, wide search (`Ctrl+K`), credit token badge (`⚡ 10 songs left`), notifications bell, user avatar, and `+ Create` CTA.
    - Mobile 56px sticky app bar with back/brand emblem, centered search input pill, and compact `+ Create` button.
  - Path: `lib/features/explore/presentation/widgets/explore_header_section.dart`
    - Display title `"Explore"`, subtitle `"Discover AI music from creators around the world"`.
    - Horizontal pill segmented tab bar (`Discover`, `For You`, `Following`).
    - Gamification streak badge chip (`🔥 2 Streak`).

- [x] **Task 5.4: Hero Banner & Featured Creators**
  - Path: `lib/features/explore/presentation/widgets/african_charts_banner.dart`
    - Terracotta-to-tangerine gradient card (`AppGradients.africanChartsBanner`, 16px radius).
    - Trendline icon, headline, subtitle, white action pill `"View ->"`.
  - Path: `lib/features/explore/presentation/widgets/creator_card.dart`
    - Monogram avatar container with uppercase initials (`SI`, `ND`, `DJ`), artist name, track count (`"96 songs"`), and `"View profile ->"` action link.

- [x] **Task 5.5: Track Feed & List Components**
  - Path: `lib/features/explore/presentation/widgets/track_card.dart`
    - 1:1 artwork cover container with `AppGradients.forGenre(genre)`, vector instrument glyph.
    - Badges: Cyan `✨ NEW` pill or Orange `#1` trending rank pill.
    - Track title (single line, ellipsis) and sub-metadata (`[Genre] • [Language] • [Duration]`).
    - Footer row with like count, play count, creator handle, and instant audio playback trigger into `playerStateProvider`.
  - Path: `lib/features/explore/presentation/widgets/track_list_tile.dart`
    - 48×48px leading genre gradient thumbnail, title, creator, genre, duration, like count, and 36×36px orange circular play button reflecting live playback state.

- [x] **Task 5.6: 12-Genre Radio & Catalog Filter Engine**
  - Path: `lib/features/explore/presentation/widgets/genre_radio_tile.dart`
    - 12 curated African heritage genres with `AppGradients.forGenre` and glassmorphic `((•)) Play Radio` overlay button.
  - Path: `lib/features/explore/presentation/widgets/catalog_filter_bar.dart`
    - Horizontal genre filter pill rail.
    - Mood filter chips flex wrap (10 emoji moods: `😊 Uplifting`, `🌧️ Melancholic`, `⚡ Energetic`, etc.).
    - Language dropdown selector covering South African official languages.
    - Sorting controls (`🔥 Newest` | `❤️ Most Liked`).
  - Path: `lib/features/explore/presentation/widgets/explore_empty_state.dart`
    - `Icons.music_off_rounded`, `"No songs match these filters"`, description, dual action buttons (`✕ Clear filters` and `✨ Create a song`).

- [x] **Task 5.7: Screen Assembly & RootShell Integration**
  - Path: `lib/features/explore/presentation/views/explore_view.dart`
    - Complete `CustomScrollView` with Slivers composing top bar, header, charts banner, new drops grid, rising tracks matrix, creator deck, genre radio mosaic, catalog filter bar, catalog grid, and load more button.
    - Wire `onCreateRequested` callback to switch root shell to Studio tab (index 2).
  - In `lib/main.dart`:
    - Ensure `RootShell` mounts `ExploreView(onCreateRequested: _openStudio)` at tab index 1.

- [x] **Task 5.8: Automated Tests & Verification**
  - Write unit tests: `test/features/explore/explore_notifier_test.dart` (testing filter logic, search matching, sorting, state transitions).
  - Write widget tests: `test/features/explore/explore_view_test.dart` (testing responsive layouts, tab selection, play actions, create navigation).
  - Run `dart analyze .` (must report 0 issues).
  - Run `flutter test` (must pass 100% of all tests with zero regressions).

---

## 3. Verification Commands & Gate Thresholds

```powershell
cd c:\Users\Ndugelo\VHUNAMBI\monorepo\apps\vhunambi_client
dart analyze .
flutter test
```

- Static Analysis Gate: `Analyzing .... No issues found!` (0 issues).
- Test Gate: `All tests passed!` (>= 47 baseline + new explore unit and widget tests).

---

## 4. Execution Results (2026-09-23)

### Gate Output
```powershell
cd apps/vhunambi_client
dart analyze .
# Result: Analyzing .... No issues found! (0 issues)

flutter test
# Result: 78 of 78 tests passed! (100%)
```

### Delivered Files
| Artifact | Path |
| :--- | :--- |
| Domain models | `lib/features/explore/domain/models/explore_models.dart` |
| Riverpod state | `lib/features/explore/presentation/providers/explore_providers.dart` |
| Responsive top bars | `lib/features/explore/presentation/widgets/explore_top_bar.dart` |
| Header + tabs + streak | `lib/features/explore/presentation/widgets/explore_header_section.dart` |
| Charts banner | `lib/features/explore/presentation/widgets/african_charts_banner.dart` |
| Track card / list tile | `lib/features/explore/presentation/widgets/track_card.dart`, `track_list_tile.dart` |
| Creator deck + genre radio | `lib/features/explore/presentation/widgets/creator_card.dart`, `genre_radio_tile.dart` |
| Filter engine + empty state | `lib/features/explore/presentation/widgets/catalog_filter_bar.dart`, `explore_empty_state.dart` |
| Shared genre glyphs | `lib/features/explore/presentation/widgets/genre_glyph.dart` |
| Screen assembly | `lib/features/explore/presentation/views/explore_view.dart` |
| Shared model extensions | `lib/shared/models/track.dart` (`mood`, `creatorHandle`, `handleLabel`) |
| Shell wiring | `lib/main.dart` → `RootShell` tab index 1 (`ExploreView(onCreateRequested: _openStudio)`) |
| Unit tests (22) | `test/features/explore/explore_notifier_test.dart` |
| Widget tests (9) | `test/features/explore/explore_view_test.dart` |
| Boot smoke test | `test/widget_test.dart` (assertion retargeted to the Phase 5 mobile header contract) |

### Deferred to Later Phases
* Charts leaderboard drill-down, creator profile routes, playlist/licensing flows and the `For You` / `Following` tab feeds — these require the social graph and commerce backends.
* Genre radio and charts CTAs surface informational feedback meanwhile.

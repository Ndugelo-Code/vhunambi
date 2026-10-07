# Master Handoff Prompt: Phase 5 — Explore Feed & Music Discovery (`/explore`)

> **To be executed by:** Cline (DeepSeek V4 Flash / 1M Context Window) OR Antigravity IDE  
> **Working Directory:** `apps/vhunambi_client/`  
> **Source Blueprint:** `docs/foundation_blueprints/01_EXPLORE_PAGE_SPEC.md`  
> **Phase 4-Doc Suite:** `docs/phases/phase_05_explore_feed/` (`blueprint.md`, `requirements.md`, `design.md`, `tasks.md`)  
> **Architecture Standard:** `docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md`

---

## Pre-Flight Status & Guardrails

1. **Baseline Status:** `dart analyze .` reports **0 issues**. `flutter test` reports **47 of 47 tests passing cleanly (100%)**.
2. **Brand Identity:** Name is strictly **`vhunambi`** (with an **i**, from Tshivenḓa for *"the talent or ability to sing"*). Never use `vhunamba`.
3. **Design Tokens:** Strictly utilize `AppColors`, `AppGradients`, `AppTypography`, `AppRadius`, and `AppSpacing` from `package:vhunambi_client/core/theme/`. **NEVER hardcode raw hex values or ad-hoc border radii.**
4. **Collision Safety:** Do NOT import `RepeatMode` from Flutter; our audio repeat enum is `AudioRepeatMode`.
5. **Responsive Utilities:** Use `ResponsiveUtils.isDesktop(context)` (> 1024px) vs `ResponsiveUtils.isMobile(context)` (< 768px).
6. **Layer Hygiene:** Presentation widgets depend on Riverpod providers; providers manipulate immutable domain state models; UI never mutates state directly.
7. **Audio Player Integration:** Use `ref.read(playerStateProvider.notifier)` to set the queue and trigger playback when users tap track cards or play buttons so audio persists in the bottom transport dock.

---

## Phase 5 Implementation Goal

Replace the Phase 2 early stub in `lib/features/explore/presentation/views/explore_view.dart` with the complete, production-grade **Explore Feed & Music Discovery (`ExploreView`)** conforming to Blueprint 01, mounted at tab index 1 of `RootShell` in `lib/main.dart`.

---

## Step-by-Step Task Sequence

### 1. Domain Models
Path: `lib/features/explore/domain/models/explore_models.dart`
- Enums:
  - `ExploreTab` (`discover`, `forYou`, `following`)
  - `ExploreSortBy` (`newest`, `mostLiked`)
- Immutable `CreatorProfile` entity:
  - `id`, `name`, `handle`, `initials`, `trackCount`, `avatarUrl`, `primaryGenres` (list of strings), `isVerified` (bool).
  - Getter: `String get trackCountLabel => '$trackCount songs';`.
- Verify compatibility with `Track` in `lib/shared/models/track.dart` (ensure `Track` can support optional `mood` for mood filtering, or handle mood tags gracefully).

### 2. Riverpod State Providers
Path: `lib/features/explore/presentation/providers/explore_providers.dart`
- State providers:
  - `exploreTabProvider` (`StateProvider<ExploreTab>`) defaulting to `ExploreTab.discover`.
  - `exploreSearchQueryProvider` (`StateProvider<String>`) defaulting to `''`.
  - `exploreGenreFilterProvider` (`StateProvider<String>`) defaulting to `'All'`.
  - `exploreMoodFilterProvider` (`StateProvider<String?>`) defaulting to `null`.
  - `exploreLanguageFilterProvider` (`StateProvider<String>`) defaulting to `'All'`.
  - `exploreSortByProvider` (`StateProvider<ExploreSortBy>`) defaulting to `ExploreSortBy.newest`.
- Data providers:
  - `exploreCreatorsProvider`: Provides 6 seeded creator profiles:
    - `"Sigwa & Inaf"`, `@sigwa_inaf`, `SI`, 96 songs, `['Amapiano']`
    - `"Ndugelo"`, `@ndugelo`, `ND`, 21 songs, `['Maskandi']`
    - `"DJ Vibe"`, `@djvibe`, `DJ`, 45 songs, `['Gqom']`
    - `"Fifi"`, `@fifi`, `FI`, 32 songs, `['Amapiano']`
    - `"Sipho"`, `@sipho`, `SP`, 18 songs, `['Kwaito']`
    - `"Lerato"`, `@lerato`, `LR`, 64 songs, `['Afro House']`
  - `ExploreTracksNotifier` and `exploreTracksProvider`:
    - Seed rich production tracks:
      - `"Grateful in the Light"`, Amapiano, English, 216s, creator `"Sigwa & Inaf"`, 1002 likes, 3420 plays, `isNew: true`.
      - `"Ndo Mufuna Matibe"`, Amapiano, Tshivenḓa, 198s, creator `"Fifi"`, 840 likes, 2800 plays, `trendingRank: 1`.
      - `"Township Log Drum Heat"`, Amapiano, instrumental, 180s, creator `"Sipho"`, 620 likes, 1950 plays, `trendingRank: 2`.
      - `"Durban Midnight Bass"`, Gqom, instrumental, 150s, creator `"DJ Vibe"`, 950 likes, 4100 plays, `trendingRank: 3`.
      - `"Kwaito Renaissance"`, Kwaito, isiZulu, 210s, creator `"Muzi"`, 430 likes, 1200 plays.
      - `"Maskandi Strings of Natal"`, Maskandi, isiZulu, 240s, creator `"Ndugelo"`, 780 likes, 2600 plays.
      - `"Afro Sunset Melodies"`, Afro House, English, 225s, creator `"Lerato"`, 890 likes, 3100 plays.
      - `"Lagos Pulse"`, Afrobeats, Yoruba, 190s, creator `"Ade"`, 1120 likes, 4800 plays.
- Selectors & Helpers:
  - `filteredExploreTracksProvider`: Computes filtered tracks matching active search query, genre, mood, language, and sorting.
  - `playExploreTrack(WidgetRef ref, Track track)` helper: Sets the queue on `playerStateProvider.notifier` and triggers playback.

### 3. Explore UI Components (under `lib/features/explore/presentation/widgets/`)
- **`explore_top_bar.dart`**:
  - `DesktopExploreTopBar` (68px, brand emblem, wordmark, `/ Explore` breadcrumb, wide search bar with `Ctrl + K` badge, `⚡ 10 songs left` chip, notification bell, user avatar, and `+ Create` CTA).
  - `MobileExploreTopBar` (56px, back/brand emblem, centered search input pill, compact `+ Create` button).
- **`explore_header_section.dart`**:
  - Title `"Explore"`, subtitle `"Discover AI music from creators around the world"`.
  - Horizontal pill segmented tab bar: `Discover`, `For You`, `Following`.
  - Gamification streak badge chip: `🔥 2 Streak` (`AppColors.surfaceSecondary`, border `AppColors.borderSubtle`).
- **`african_charts_banner.dart`**:
  - Full-width card with `AppGradients.africanChartsBanner` (`#C2410C` to `#EA580C`, 16px radius).
  - Trendline icon (`Icons.trending_up_rounded`), headline `"African Music Charts"`, subtitle, and white action pill `"View ->"`.
- **`track_card.dart`**:
  - 1:1 artwork cover with `AppGradients.forGenre(track.genre)`.
  - Centered instrument vector glyph (`Icons.piano_rounded`, `Icons.graphic_eq_rounded`, etc.).
  - Status badge: Cyan `✨ NEW` pill or Orange `#1` trending rank pill.
  - Title (single line bold, ellipsis) and sub-metadata (`[Genre] • [Language] • [Duration]`).
  - Footer row: Like count (`❤️`), play count (`▶`), creator handle (`@handle`).
  - Tapping card plays track via `playExploreTrack`.
- **`track_list_tile.dart`**:
  - Dense list row: 48×48px leading genre gradient thumbnail, title, creator, genre, duration, like count, and 36×36px orange circular play button reflecting live playback state.
- **`creator_card.dart`**:
  - 48×48px monogram avatar with initials, artist name, track count (`"96 songs"`), and `"View profile ->"` action link.
- **`genre_radio_tile.dart`**:
  - 12 curated African heritage genres with `AppGradients.forGenre` and glassmorphic `((•)) Play Radio` overlay button.
- **`catalog_filter_bar.dart`**:
  - Horizontal genre filter pill rail.
  - Mood filter chips flex wrap (10 emoji moods: `😊 Uplifting`, `🌧️ Melancholic`, `⚡ Energetic`, etc.).
  - Language dropdown selector covering South African official languages.
  - Sorting pills (`🔥 Newest` | `❤️ Most Liked`).
- **`explore_empty_state.dart`**:
  - Empty search/filter state: `Icons.music_off_rounded`, `"No songs match these filters"`, description, dual action buttons (`✕ Clear filters` and `✨ Create a song`).

### 4. Screen Assembly & Shell Wiring
- Path: `lib/features/explore/presentation/views/explore_view.dart`:
  - Compose sections inside a `CustomScrollView` with Slivers:
    1. Top navigation header (responsive desktop vs mobile).
    2. Header section (title, segmented tabs, streak badge).
    3. African Music Charts banner.
    4. New This Week grid (6-col Desktop / 2-col Mobile).
    5. Rising tracks (2-col balanced split matrix on Desktop / 1-col on Mobile).
    6. Featured Creators deck (6-col single row on Desktop / 2-col on Mobile).
    7. Genre Radio mosaic (6x2 on Desktop / 2x6 on Mobile).
    8. Catalog filter bar.
    9. Catalog track cards grid or `ExploreEmptyState`.
    10. Desktop `"Load more"` centered button.
  - Accept `VoidCallback? onCreateRequested` to route `+ Create` and empty-state CTA to tab index 2 (`StudioView`).
- In `lib/main.dart`:
  - Mount `ExploreView(onCreateRequested: _openStudio)` at tab index 1 of `RootShell`.

### 5. Automated Tests
- Unit tests: `test/features/explore/explore_notifier_test.dart`
  - Test initial seeded tracks and creators.
  - Test text search query filtering.
  - Test genre, mood, and language filtering.
  - Test sorting by newest vs most liked.
  - Test tab switching.
- Widget tests: `test/features/explore/explore_view_test.dart`
  - Verify desktop vs mobile layout rendering.
  - Verify banner, grids, and genre radio tiles render.
  - Verify tapping `+ Create` invokes `onCreateRequested`.
  - Verify tapping a track card triggers playback on `playerStateProvider`.

---

## Verification Criteria
- `dart analyze .` must report `No issues found!`.
- `flutter test` must pass all test cases without regression (all 47 baseline tests + new explore tests).

---

## Execution Record — 2026-09-23 ✅

**Status:** Phase 5 complete and verified. `dart analyze .` → `No issues found!` (0 issues). `flutter test` → `78 of 78 tests passed!` (47 Phase 4 baseline + 22 new explore unit tests + 9 new explore widget tests).

### Delivered Under `apps/vhunambi_client/`
* `lib/features/explore/domain/models/explore_models.dart` — `ExploreTab`, `ExploreSortBy`, immutable `CreatorProfile` (`copyWith`, `==`/`hashCode`, `trackCountLabel`, `primaryGenreLabel`), `ExploreMoodOption`, and the 12-genre / 10-mood / 10-language taxonomy catalogs.
* `lib/features/explore/presentation/providers/explore_providers.dart` — tab/search/genre/mood/language/sort state providers, `exploreCreatorsProvider` (6 seeded profiles), `ExploreTracksNotifier` + `exploreTracksProvider` (8 seeded tracks), pure `filterExploreTracks()`, `filteredExploreTracksProvider`, `newThisWeekTracksProvider`, `risingTracksProvider`, `visibleExploreTracksProvider` / `hasMoreExploreTracksProvider`, `loadMoreExploreTracks()`, `resetExploreCatalogCursor()`, `clearExploreFilters()`, `exploreQueueFor()`, `playExploreTrack()`, `playExploreGenreRadio()`.
* `lib/features/explore/presentation/widgets/` — `explore_top_bar.dart` (`DesktopExploreTopBar` 68px / `MobileExploreTopBar` 56px, `Ctrl + K` shortcut + badge), `explore_header_section.dart`, `african_charts_banner.dart`, `track_card.dart`, `track_list_tile.dart`, `creator_card.dart`, `genre_radio_tile.dart`, `catalog_filter_bar.dart`, `explore_empty_state.dart`, `genre_glyph.dart`.
* `lib/features/explore/presentation/views/explore_view.dart` — 10-slice `CustomScrollView` with the mobile/tablet/desktop breakpoint matrix helpers.
* `lib/shared/models/track.dart` — additive `mood` + `creatorHandle` fields and the `handleLabel` fallback getter.
* `lib/main.dart` — `RootShell` tab index 1 renders `ExploreView(onCreateRequested: _openStudio)`.
* `test/features/explore/explore_notifier_test.dart` (22 tests), `test/features/explore/explore_view_test.dart` (9 tests), `test/widget_test.dart` (boot assertion retargeted — see deviation 8).

### Spec Deviations / Additions (documented for the auditor)
1. **Player bridge API:** `design.md` §2.1 calls `playerNotifier.setQueue(...)` + `playerNotifier.play()`; the shipped `PlayerNotifier` exposes `playTrack(track, queue: ...)` instead, so `playExploreTrack()` / `playExploreGenreRadio()` route through that real API (guardrail 7: state the queue and start playback in the persistent dock).
2. **`Track` extensions:** additive `mood` (required by the mood filter engine, design.md §1.3) and `creatorHandle` + `handleLabel` fallback (the track-card footer requires an `@handle` that `Track` did not model).
3. **Pagination cursor:** `exploreCatalogPageSize` (6) + `exploreVisibleCountProvider` + `loadMoreExploreTracks()` were added to give the mandated desktop `Load more` pill real behaviour; the cursor resets whenever a filter or the search query changes.
4. **`New This Week` projection:** the leading 6 curated drops, because the shared `Track` entity has no publication timestamp (same reason `ExploreSortBy.newest` preserves the curated seed order).
5. **Tabs:** `Discover` / `For You` / `Following` update Riverpod state (REQ-EXP-02); their distinct feeds require the Phase 7 social graph, so the feed sections stay tab-agnostic for now.
6. **Informational CTAs:** the charts `View ->` pill and an empty genre radio surface SnackBar feedback until the marketplace/leaderboard phases land.
7. **Layout robustness found by the test suite:** the glassmorphic `((•)) Play Radio` pill label and the catalog title/count row use `Flexible` + ellipsis (wide font metrics overflowed the 2-column mobile tiles), and `TrackCard` / `TrackListTile` subscribe via `playerStateProvider.select(...)` so the 1-second playback ticker never forces feed rebuilds.
8. **Baseline test expectation change:** `test/widget_test.dart` asserted `find.text('VHUNAMBI')` at boot. Blueprint 01 §1.1 defines the mobile/tablet header as brand emblem + search + create (no wordmark), so the smoke test now asserts the booted discovery chrome (`MobileExploreTopBar`, header `Explore`, `Discover`). The 47 pre-existing tests otherwise pass unchanged.
9. **Tablet top bar:** the blueprint's dedicated 64px tablet bar is deferred; tablet widths reuse the 56px mobile bar while the grids already follow the tablet column matrix (4-col cards, 3-col creators, 3-col radio).

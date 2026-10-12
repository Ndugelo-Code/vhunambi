# 🏛️ AUDIT BRIEF & PROMPT: The Explore & Heritage Discovery Feed
**Target Agent:** Antigravity / Cline (Audit & Implementation Mode)  
**Target Codebase:** `apps/vhunambi_client` (Flutter / Dart)  
**Scope:** Explore Feed (`ExploreView`), Desktop & Mobile Discovery Top Bars (`DesktopExploreTopBar`, `MobileExploreTopBar`), Catalog Filter Engine (`CatalogFilterBar`), African Charts Banner (`AfricanChartsBanner`), Discovery Cards (`TrackCard`, `TrackListTile`, `CreatorCard`, `GenreRadioTile`), and Pagination  

---

## 🎯 Mission Statement & Purpose
You are acting as an **independent, unbiased Principal Mobile Discovery Architect and Design Systems Lead**.

Your objective is to audit and modernize **The Explore & Heritage Discovery Feed (`lib/features/explore`)** in the Vhunambi codebase.

Vhunambi is a high-performance African AI Music Workstation and Social Creator Network built for 2026 mobile standards. The **Top Bar Navigation System**, **Bottom Navigation Dock & Universal Audio Transport**, **Studio AI Generation Cockpit & MPC Chopper**, and **Track Details Cockpit & Audio Stem Separation Lab** have all been modernized into high-performance frosted surfaces with mathematical geometry, tabbed progressive disclosure, and 44px touch compliance.

Now we target the primary music discovery engine of the app: **The Explore & Heritage Discovery Feed (`ExploreView`)**.

Currently, `ExploreView` features clean responsive architecture (2/4/6 columns across mobile/tablet/desktop, live player state synchronization, genre radio generation, search debounce, and cursor pagination). However, **the touch targets across the discovery feed suffer from pervasive HIG/WCAG violations: filter pills (~28px height), language dropdown pill (~28px height), search input field (42px height), rising tile play/pause button (36×36px), tab pills (~37px height), and charts banner CTA (~34px height)**.

---

## 📂 Primary Code Files Audited

### 1. Root Feed & Pagination
* [`apps/vhunambi_client/lib/features/explore/presentation/views/explore_view.dart`](file:///apps/vhunambi_client/lib/features/explore/presentation/views/explore_view.dart):
  * `ExploreView`: CustomScrollView hosting 10 modular discovery slivers.
  * `_LoadMoreButton`: Catalog pagination cursor advancement pill.

### 2. Desktop & Mobile Discovery Top Bars
* [`apps/vhunambi_client/lib/features/explore/presentation/widgets/explore_top_bar.dart`](file:///apps/vhunambi_client/lib/features/explore/presentation/widgets/explore_top_bar.dart):
  * `DesktopExploreTopBar` & `MobileExploreTopBar`: Frosted top bar with search, notifications, credits, and `+ Create` CTA.
  * `_ExploreSearchField`: 42px height container (needs 44px HIG compliance).

### 3. Header Section & Discovery Tabs
* [`apps/vhunambi_client/lib/features/explore/presentation/widgets/explore_header_section.dart`](file:///apps/vhunambi_client/lib/features/explore/presentation/widgets/explore_header_section.dart):
  * `_TabPill`: Discover / For You / Following discovery segment pills (~37px touch height).

### 4. African Charts Hero Banner
* [`apps/vhunambi_client/lib/features/explore/presentation/widgets/african_charts_banner.dart`](file:///apps/vhunambi_client/lib/features/explore/presentation/widgets/african_charts_banner.dart):
  * `cta`: `View ->` elevated button (~34px height).

### 5. Catalog Filter Engine
* [`apps/vhunambi_client/lib/features/explore/presentation/widgets/catalog_filter_bar.dart`](file:///apps/vhunambi_client/lib/features/explore/presentation/widgets/catalog_filter_bar.dart):
  * `_FilterPill`: Genre, mood, and sorting pills (vertical: 6, ~28px height).
  * `_LanguageDropdown`: Language selector trigger pill (vertical: 6, ~28px height).
  * `Clear filters`: Action link touch bounds.

### 6. Discovery Tiles & Creator Decks
* [`apps/vhunambi_client/lib/features/explore/presentation/widgets/track_list_tile.dart`](file:///apps/vhunambi_client/lib/features/explore/presentation/widgets/track_list_tile.dart):
  * Play/pause trigger button: 36×36px circle (violates 44×44px hit bounds).
* [`apps/vhunambi_client/lib/features/explore/presentation/widgets/creator_card.dart`](file:///apps/vhunambi_client/lib/features/explore/presentation/widgets/creator_card.dart):
  * `View profile ->` text action hit bounds.
* [`apps/vhunambi_client/lib/features/explore/presentation/widgets/genre_radio_tile.dart`](file:///apps/vhunambi_client/lib/features/explore/presentation/widgets/genre_radio_tile.dart):
  * 12-genre radio mosaic tiles.

---

## 🔒 Rigid Test Guardrails (Must Never Break)
* **Pin 1 — Discovery Feed Structure**: All 10 feed sections must render (`DesktopExploreTopBar`, `MobileExploreTopBar`, `ExploreHeaderSection`, `AfricanChartsBanner`, `New This Week`, `Rising`, `Featured Creators`, `Genre Radio`, `All Songs`, `TrendingReelsShelf`).
* **Pin 2 — Card & Tile Counts**: 12 `TrackCard`s on desktop (6 New This Week + 6 Catalog), 3 `TrackListTile`s, 6 `CreatorCard`s, 12 `GenreRadioTile`s.
* **Pin 3 — Badges**: `✨ NEW` (2) and `#1`, `#2`, `#3` badges must match exactly.
* **Pin 4 — Filter & Search Contracts**: `exploreSearchQueryProvider`, `exploreGenreFilterProvider`, `exploreMoodFilterProvider`, `exploreLanguageFilterProvider`, `exploreSortByProvider` must preserve exact filter strings (`'Language: All'`, `'Language: isiZulu'`, `'🔥 Newest'`, `'❤️ Most Liked'`).
* **Pin 5 — Playback & Audio Routing**: Tapping `TrackCard`, `TrackListTile`, or `GenreRadioTile` must correctly route into `playerStateProvider`.

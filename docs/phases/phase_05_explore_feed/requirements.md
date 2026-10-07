# Phase 5 Requirements: Explore Feed & Music Discovery (`/explore`)

> **Specification Standard:** EARS (Easy Approach to Requirements Syntax) & RFC 2119 (`MUST`, `SHALL`, `MAY`)  
> **Traceability Root:** `REQ-EXP`

---

## 1. Top Bar & Navigation Header Requirements

- **REQ-EXP-01 (Responsive Navigation Header):**
  - The Explore view **MUST** render a top navigation header adhering to the responsive layout contract:
    - On Mobile (< 768px): Sticky 56px app bar displaying back button / brand emblem, centered search input pill (`"Search songs..."`), and primary orange `+ Create` button.
    - On Desktop (> 1024px): 68px top bar with brand emblem, wordmark, breadcrumb `"/ Explore"`, centered integrated search bar (`height: 42px`, max-width `560px`, `Ctrl + K` badge), credit badge (`⚡ 10 songs left`), notification bell button, user profile avatar, and primary `+ Create` button.
  - Tapping the `+ Create` button **MUST** switch the root shell navigation to the Studio Creation Cockpit (tab index 2).

- **REQ-EXP-02 (Sub-Navigation Tabs & Gamification Streak):**
  - The Explore header section **MUST** provide a 3-way segmented pill selector: `Discover` (default active), `For You`, and `Following`.
  - Selecting a tab **MUST** update the active explore tab in Riverpod state.
  - The header **MUST** display a gamification streak badge (`🔥 2 Streak` / `🔥 2 Day Streak`) in `AppColors.surfaceSecondary` with `AppColors.borderSubtle` border.

---

## 2. Banner & Multi-Column Discovery Feeds

- **REQ-EXP-03 (African Music Charts Banner):**
  - The view **MUST** render the African Music Charts hero banner using `AppGradients.africanChartsBanner` (`#C2410C` to `#EA580C`) with `16px` border radius.
  - The banner **MUST** include trendline icon (`Icons.trending_up_rounded`), headline `"African Music Charts"`, subtitle `"Top songs across All Africa, South Africa, West & East Africa"`, and white pill CTA `"View ->"`.

- **REQ-EXP-04 (Responsive Track Grids — New This Week & Trending):**
  - The track feed sections (`New This Week`, `Trending`) **MUST** render as:
    - Exactly 2 columns on Mobile (< 768px) with child aspect ratio `0.75` and `12px` spacing.
    - Exactly 6 columns on Desktop Ultrawide (> 1024px) with child aspect ratio `0.72` and `16px` spacing.
  - Each `TrackCard` **MUST** display:
    - 1:1 square artwork container styled with `AppGradients.forGenre(track.genre)`.
    - Centered vector instrument glyph.
    - Status badge: Cyan `✨ NEW` pill for newly dropped tracks, or Orange `#1`, `#2`, `#3` pill for trending tracks.
    - Track title (single-line, ellipsis) and sub-metadata (`[Genre] • [Language] • [Duration]`).
    - Footer row with like count (`❤️`), play count (`▶`), and creator username handle (`@username`).
  - Tapping a track card **MUST** trigger playback of that track through `playerStateProvider`, persisting in the bottom transport bar.

---

## 3. Rising Tracks, Creators & Genre Radios

- **REQ-EXP-05 (Rising Tracks Split-Matrix List):**
  - The `Rising` tracks section **MUST** dynamically adapt:
    - On Mobile (< 768px): Render as a single-column vertical list of `TrackListTile` items.
    - On Desktop (> 1024px): Render as a balanced 2-column side-by-side grid matrix (child aspect ratio `4.8`, spacing `16px`).
  - Each `TrackListTile` **MUST** include a 48×48px leading genre gradient thumbnail, title, creator, genre, duration, like count, and a 36×36px orange circular play/pause button reflecting live playback state.

- **REQ-EXP-06 (Featured Creators Showcase):**
  - The `Featured Creators` section **MUST** render:
    - Exactly 2 columns on Mobile (< 768px) with child aspect ratio `2.2`.
    - Exactly 6 columns on Desktop (> 1024px) forming a single-row creator avatar deck (child aspect ratio `1.8`).
  - Each `CreatorCard` **MUST** display a 48×48px circular monogram avatar with initials, artist name, track count (`"96 songs"`), and `"View profile ->"` action link.

- **REQ-EXP-07 (12-Genre Radio Grid & Live Audio Bridge):**
  - The `Genre Radio` section **MUST** display the 12 curated African musical heritage genres:
    - `Amapiano`, `Kwaito`, `Gqom`, `Maskandi`, `Mbaqanga`, `Marabi`, `Bubblegum`, `Afro House`, `Afrobeats`, `Afro Jazz`, `Afro Soul`, `Afro-Arabic`.
  - Layout **MUST** be:
    - 2 columns × 6 rows on Mobile (< 768px).
    - Exactly 6 columns × 2 rows on Desktop (> 1024px).
  - Each genre radio tile **MUST** use `AppGradients.forGenre` and display a centered glassmorphic `((•)) Play Radio` overlay button.
  - Tapping `Play Radio` **MUST** queue or start continuous playback of tracks in that genre.

---

## 4. Catalog Filter Engine, Sorting & State

- **REQ-EXP-08 (Catalog Filter Engine & Empty State):**
  - The catalog section ("All Songs") **MUST** provide a multifaceted filter engine:
    1. Horizontal genre filter pill rail (`[ All ]`, `[ Amapiano ]`, `[ Kwaito ]`, etc.).
    2. Mood filter chips wrap with 10 emoji options (`😊 Uplifting`, `🌧️ Melancholic`, `⚡ Energetic`, `❤️ Romantic`, `🕊️ Peaceful`, `🔥 Angry`, `📻 Nostalgic`, `🌙 Mysterious`, `🎉 Party`, `🖤 Dark`).
    3. Language dropdown selector supporting South African official languages (`All`, `isiZulu`, `isiXhosa`, `Afrikaans`, `English`, `Sepedi`, `Setswana`, `Sesotho`, `Xitsonga`, `siSwati`, `Tshivenḓa`).
    4. Sorting controls: `🔥 Newest` and `❤️ Most Liked`.
  - Desktop **MUST** provide a centered `"Load more"` pill button.
  - When the combination of filters and search query yields 0 tracks, the UI **MUST** display an empty state (`Icons.music_off_rounded`, `"No songs match these filters"`, subtext, and dual action buttons: `✕ Clear filters` and `✨ Create a song`).

- **REQ-EXP-09 (Riverpod Reactive State Management):**
  - State management **MUST** expose Riverpod providers for:
    - `exploreTabProvider` (`ExploreTab`: `discover`, `forYou`, `following`)
    - `exploreSearchQueryProvider` (`String`)
    - `exploreGenreFilterProvider` (`String`, default `'All'`)
    - `exploreMoodFilterProvider` (`String?`)
    - `exploreLanguageFilterProvider` (`String`, default `'All'`)
    - `exploreSortByProvider` (`ExploreSortBy`: `newest`, `mostLiked`)
    - `exploreTracksProvider` (`ExploreTracksNotifier`) providing seeded demo tracks with rich metadata
    - `filteredExploreTracksProvider` (computed selector reflecting all active filter dimensions)
    - `exploreCreatorsProvider` providing seeded creator profiles.

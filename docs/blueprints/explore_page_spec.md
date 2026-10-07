# Blueprint: Explore Page (`/explore`)

## 1. Design Tokens & Styling Primitives

* **Surfaces:**
  * Background Canvas: `#0A0A0C` (Pitch Black)
  * Elevated Card Background: `#141418` (Dark Charcoal)
  * Secondary Surface / Inset: `#1B1B22`
  * Modal / Sheet Surface: `#16161C`

* **Brand Accents:**
  * Primary Accent: `#F97316` (Vibrant Orange / Amber)
  * Primary Contrast Text: `#000000` (Pure Black text on Orange buttons)
  * New Badge Accent: `#06B6D4` / `#22D3EE` (Cyan pill `#0E3842` background)

* **Text Colors:**
  * Primary: `#FFFFFF`
  * Secondary / Muted: `#9CA3AF` (Neutral Slate)
  * Tertiary / Borders: `#2D2D38`

* **Layout Radii:**
  * Cards / Containers: `16px` (`RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))`)
  * Buttons / Chips / Badges: `9999px` (Full Pill)
  * Inputs: `12px`

---

## 2. Global Navigation Scaffolding

### Top App Bar (Sticky Header)
* **Back Button:** Circular icon button (`Icons.arrow_back_ios_new_rounded`, `size: 18`).
* **Leading Icon:** Pill container containing musical note icon (`#F97316`).
* **Search Bar:** Centered pill input (`TextField`), hint: `"Search songs..."`, prefix icon: `Icons.search_rounded`.
* **Action Button:** Solid orange pill button `+ Create` (`Icons.auto_awesome` / Sparkle icon + label).

### Bottom Persistent Navigation Bar
* **Items (5 Tabs):**
  1. `Home` (`Icons.home_outlined` / `Icons.home_filled`)
  2. `Explore` (Active: `#F97316`, `Icons.explore_rounded`)
  3. `Create` (Center action with sparkle badge)
  4. `Library` (`Icons.library_music_outlined`)
  5. `Market` (`Icons.storefront_outlined`)

---

## 3. Page Segmented Control & User Context

* **Header Title:** `Explore` (`fontSize: 28, fontWeight: FontWeight.bold`).
* **Subtitle:** `Discover AI music from creators around the world` (`fontSize: 14, color: #9CA3AF`).
* **View Selector Tabs (Horizontal Pill Selector):**
  * `Discover` (Active: Orange background `#F97316`, black text).
  * `For You` (Inactive: Transparent, muted text).
  * `Following` (Inactive: Transparent, muted text).
* **Gamification / Streak Chip:** Left-aligned pill badge `🔥 2` (`#1B1B22` background, orange fire icon).

---

## 4. Section-by-Section Content Hierarchy

### Section A: Banner — African Music Charts
* **Layout:** Full-width gradient card (`#C2410C` $\rightarrow$ `#EA580C`).
* **Content:** Trendline icon (`Icons.trending_up`), Title: `"African Music Charts"`, Subtitle: `"Top songs across All Africa, South Africa, West & East Africa"`, Trailing button: `"View ->"`.

---

### Section B: 2-Column Grid Sections (`Recently Played`, `New This Week`, `Trending`, `For You`)
Used across horizontal carousels or 2-column staggered wrap grids:
* **Item Card Structure:**
  * Aspect Ratio: `1:1` square cover container.
  * Cover Backgrounds: Vibrant dynamic gradients/solids (Yellow, Hot Pink, Cyan, Blue, Charcoal).
  * Graphic Asset: Centered vector icon/artwork (Piano keyboard, electric guitar, violin, mic, rock hand sign).
  * Badges (Top-Left):
    * New Drops: Cyan badge `✨ NEW`.
    * Trending: Orange pill rank `#1`, `#2`, `#3`.
  * Track Title: Bold single-line ellipsis (e.g., `Grateful in the Light`, `Leaving Jo'burg`).
  * Sub-metadata: `[Genre] • [Language] • [Duration]` (e.g., `Amapiano • English • 3:36`).
  * Footer Row:
    * Like count (`Icons.favorite_border` + number).
    * Play count (`Icons.play_arrow_rounded` + number).
    * Creator username (e.g., `Sigwa & Inaf`, `Ndugelo`).

---

### Section C: Vertical Track List (`Because you make Amapiano`, `Rising`)
* **Header:** Title + contextual subtitle (e.g., `"Fastest growing songs in the last 48 hours"`).
* **Track Row Component (`TrackListTile`):**
  * **Leading:** Rounded square thumbnail (`48x48px`) with genre instrument icon.
  * **Title Column:** Track title (`fontWeight: FontWeight.w600`) over Creator name, genre, and duration (`#9CA3AF`).
  * **Social Stat:** Heart icon + Like count (e.g., `❤️ 1002`).
  * **Trailing Action:** Circular orange play button (`36x36px`, filled `#F97316` or outline with play glyph).

---

### Section D: Featured Creators Grid
* **Header:** Title + Subtitle (`"Most active musicians on VHUNAMBI"`).
* **Card Structure (2-Column Grid):**
  * Container: Rounded dark card with inner border.
  * Avatar: Circular monogram container (`48x48px`, `#EA580C` or `#4F46E5` background, 2-letter uppercase initials like `SI`, `ND`, `DJ`).
  * Name: Bold display (e.g., `Sigwa & Inaf`, `Ndugelo`).
  * Output Stat: Muted track count (e.g., `96 songs`, `21 songs`).
  * CTA: Text link `"View profile ->"` with arrow icon.

---

### Section E: Genre Radio Grid
* **Header:** Icon + Title `"Genre Radio"` + Subtitle `"Pick a genre and listen non-stop"`.
* **Grid Items (2 Columns):**
  * Genres: Amapiano, Kwaito, Gqom, Maskandi, Mbaqanga, Marabi, Bubblegum, Afro House, Afrobeats, Afro Jazz, Afro Soul, Afro-Arabic.
  * Backgrounds: High-saturation regional gradients (Deep Green, Burnt Amber, Royal Violet, Mustard Yellow).
  * CTA Overlay: Glassmorphic pill button `((•)) Play Radio`.

---

### Section F: Filter Engine & Catalog Browser ("All Songs")
1. **Genre Filter Rail:** Horizontally scrollable pill group (`All`, `Amapiano`, `Kwaito`, `Gqom`, `Maskandi`, etc.).
2. **Mood Filter Wrap:** Emoji-tagged chips:
   * `😊 Uplifting`, `🌧️ Melancholic`, `⚡ Energetic`, `❤️ Romantic`, `😡 Angry`, `🕊️ Peaceful`, `📷 Nostalgic`, `💪 Motivational`, `🎉 Party`, `🌑 Dark`.
3. **Language Selector Dropdown:**
   * Bottom sheet / select modal containing native languages: `All languages`, `Zulu`, `Xhosa`, `Afrikaans`, `English`, `Northern Sotho`, `Tswana`, `Sotho`, `Tsonga`, `Swati`, `Venda`.
4. **Sorting Controls:** `🔥 Newest`, `❤️ Most Liked`, and dynamic `✕ Clear all filters`.
5. **Empty Search State:**
   * Centered icon: Outlined music note (`#6B7280`).
   * Primary Text: `"No songs match these filters"`.
   * Body Text: `"Try a different genre, language, or mood, or clear your filters to browse everything"`.
   * Dual Action Buttons: `✕ Clear filters` (ghost/border) and `✨ Create a song` (solid orange).

---

## 5. State Tree Requirements for Riverpod

```dart
// State models needed for this view:
final exploreTabProvider = StateProvider<ExploreTab>((ref) => ExploreTab.discover);
final activeGenreFilterProvider = StateProvider<String>((ref) => 'All');
final activeMoodFilterProvider = StateProvider<String?>((ref) => null);
final activeLanguageFilterProvider = StateProvider<String>((ref) => 'All');
final sortByProvider = StateProvider<SortBy>((ref) => SortBy.newest);
final currentPlayingTrackIdProvider = StateProvider<String?>((ref) => null);
```

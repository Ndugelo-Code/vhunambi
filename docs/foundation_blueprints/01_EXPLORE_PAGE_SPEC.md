# Blueprint 01: Explore Page Specification (`/explore`)

> **Target Platform:** Flutter 3.x+ / Dart 3.x+ (Windows, macOS, Android, iOS, Web)  
> **Route Path:** `/explore`  
> **State Management:** Flutter Riverpod 2.x+  
> **Source Origin:** Production Web Client (`https://vhunambi.com/explore`)  
> **Viewport Matrix:** Mobile Portrait (< 768px) vs Desktop Ultrawide (> 1024px)

---

## 1. Route Scope & Architecture Overview

The Explore view (`/explore`) serves as Vhunambi's discovery engine, aggregating trending tracks, curated African genre radios, rising creator profiles, and a multifaceted search and filter catalog browser.

### Key Performance Constraints
* Must employ **Slivers (`CustomScrollView`)** for seamless scroll virtualization across high-density music feeds.
* Layout must dynamically adapt between a **2-column touch flow on Mobile (< 768px)** and an expansive **6-column mosaic on Desktop Ultrawide (> 1024px)**.
* Images and album artwork must use disk caching with memory-bounded thumbnails (`cached_network_image`).
* Audio playback states must reactively update all play/pause buttons via Riverpod without rebuilding unimpacted tiles.

---

## 2. Responsive Breakpoint Matrix & Multi-Column Geometry

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│ Section                          Mobile Viewport (< 768px)        Desktop Ultrawide (> 1024px)  │
├─────────────────────────────────────────────────────────────────────────────────────────────────┤
│ New Drops / Trending / For You   2-Column Grid (Ratio 0.75)       6-Column Grid (Ratio 0.72)    │
│ Rising / Contextual Lists        1-Column Dense Vertical Rows     2-Column Split Matrix (L / R) │
│ Featured Creators                2-Column Monogram Cards          6-Column Single Row Deck      │
│ Genre Radio                      2-Column Vertical Flow (6x2)     6-Column Mosaic (2 rows of 6) │
│ Catalog Browser ("All Songs")    2-Column Grid + Pagination       6-Column Grid + "Load more"   │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

### 2.1 Geometry Specifications

#### A. Mobile Viewport (< 768px)
* **Track Cards (`New This Week`, `Trending`, `For You`):**
  ```dart
  SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    crossAxisSpacing: 12,
    mainAxisSpacing: 12,
    childAspectRatio: 0.75, // Accommodates 1:1 artwork + title + metadata + stats
  )
  ```
* **Vertical Lists (`Rising`, `Because you make Amapiano`):**
  * Single-column vertical list using `SliverList.builder`.
* **Featured Creators:**
  * 2-column square monogram cards (`childAspectRatio: 2.2`).
* **Genre Radios:**
  * 2-column grid (`crossAxisCount: 2`, `childAspectRatio: 1.5`, 6 vertical rows).
* **Catalog Grid ("All Songs"):**
  * 2-column card grid with bottom pagination indicator.

#### B. Desktop / Ultrawide Viewport (> 1024px)
* **Track Cards (`New This Week`, `Trending`, `For You`):**
  ```dart
  SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 6,
    crossAxisSpacing: 16,
    mainAxisSpacing: 16,
    childAspectRatio: 0.72,
  )
  ```
* **Vertical Lists (`Rising`):**
  * Split into a balanced **2-column side-by-side tile matrix** (left and right columns evenly splitting the 6–10 tracks to utilize horizontal screen width without excessive whitespace).
* **Featured Creators:**
  * Exactly **6-column horizontal creator avatar deck** forming a clean single row (`crossAxisCount: 6`, `childAspectRatio: 1.8`).
* **Genre Radios:**
  * Exactly **6 columns × 2 rows** forming a 12-genre unified mosaic.
* **Catalog Grid ("All Songs"):**
  * 6-column extensive audio vault grid followed by a centered `"Load more"` solid/ghost pill button.

---

## 3. Global Navigation Scaffolding (Mobile vs Desktop)

### 3.1 Desktop Top Bar Header (> 1024px)

```
┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
│ (🎵) VHUNAMBI  / Explore     [ 🔍 Search songs or artists...  Ctrl+K ]   [⚡ 10 songs] [🔔] [👤] [+ Create] │
└──────────────────────────────────────────────────────────────────────────────────────────────────┘
```

* **Height:** `68px`, background `#0A0A0C` with 1px bottom divider `#2D2D38`.
* **Left Section:**
  * Circular brand emblem (`#F97316` circle with music note).
  * Bold wordmark `"VHUNAMBI"`.
  * Context breadcrumb: `/ Explore` (`color: #9CA3AF`, `fontSize: 14`).
* **Center Section (Integrated Wide Search Bar):**
  * Container: Pill input (`height: 42px`, max-width: `560px`, background `#141418`, border `1px solid #2D2D38`).
  * Prefix: `Icons.search_rounded` (`#9CA3AF`, `size: 18`).
  * Placeholder: `"Search songs or artists..."` (`color: #6B7280`, `fontSize: 14`).
  * Suffix Keyboard Shortcut Badge: Pill container with label `Ctrl + K` or `/` (`background: #1B1B22`, border `#2D2D38`, `fontSize: 11`, `color: #9CA3AF`).
* **Right Utility Strip:**
  * Credit Badge: `⚡ 10 songs left` (`background: #1B1B22`, border `#2D2D38`, `fontSize: 13`).
  * Notification Bell: `Icons.notifications_none_rounded` with unread dot.
  * User Profile Avatar: Circular avatar (`36x36px`, border `1.5px solid #F97316`).
  * Action CTA: Solid orange pill button `+ Create` (`Icons.auto_awesome` + label, `#F97316`, text `#000000`).

---

### 3.2 Mobile Sticky Top App Bar (< 768px)

```
┌────────────────────────────────────────────────────────────────────────┐
│ [ < ]  [🎵]  [  🔍 Search songs...                             ] [+ Create] │
└────────────────────────────────────────────────────────────────────────┘
```

* **Height:** `56px` + top safe area.
* **Components:** Back button (`Icons.arrow_back_ios_new_rounded`), brand badge, centered search pill, and compact orange `+ Create` button.
* **Bottom Navigation Dock:** 5 destinations (`Home`, `Explore` active `#F97316`, `Create`, `Library`, `Market`) with 64px persistent height.

---

## 4. Page Header, Sub-Navigation & Gamification Context

```
┌────────────────────────────────────────────────────────────────────────┐
│ Explore                                                                │
│ Discover AI music from creators around the world                       │
│                                                                        │
│ [ Discover ]  [ For You ]  [ Following ]              [ 🔥 2 Streak ]  │
└────────────────────────────────────────────────────────────────────────┘
```

* **Header Title:** `"Explore"` (`fontSize: 32` desktop / `28` mobile, `fontWeight: FontWeight.bold`, `#FFFFFF`).
* **Subtitle:** `"Discover AI music from creators around the world"` (`fontSize: 14`, `color: #9CA3AF`).
* **View Selector Tabs (Horizontal Pill Selector):**
  * `Discover` (Active): Background `#F97316`, Text `#000000`, `fontWeight: FontWeight.bold`.
  * `For You` (Inactive): Background `transparent`, Text `#9CA3AF`, hover `#FFFFFF`.
  * `Following` (Inactive): Background `transparent`, Text `#9CA3AF`, hover `#FFFFFF`.
* **Gamification Streak Chip:**
  * Background: `#1B1B22`, border `1px solid #2D2D38`, border-radius `9999px`, padding `6px 14px`.
  * Icon: `🔥` Flame emoji / `Icons.local_fire_department_rounded` (`color: #EA580C`).
  * Label: `"2"` / `"2 Day Streak"` (`fontSize: 13`, `fontWeight: FontWeight.w600`, `#FFFFFF`).

---

## 5. Section-by-Section Content Hierarchy

### Section A: Banner — African Music Charts
* **Layout:** Full-width rounded card (`BorderRadius.circular(16)`), padding `24px`.
* **Background:** Smooth gradient from `#C2410C` (Deep Terracotta) to `#EA580C` (Vibrant Tangerine) at 135 degrees.
* **Content:**
  * Top-Left Icon: Trendline glyph (`Icons.trending_up_rounded`, `size: 28`, `color: #FFFFFF`).
  * Headline: `"African Music Charts"` (`fontSize: 22`, `fontWeight: FontWeight.bold`, `color: #FFFFFF`).
  * Subtitle: `"Top songs across All Africa, South Africa, West & East Africa"` (`fontSize: 14`, `color: #FFFFFF` at 90% opacity).
  * Trailing Action: White pill button with dark text (`"View ->"`, background `#FFFFFF`, text `#000000`, `fontWeight: FontWeight.bold`).

---

### Section B: Multi-Column Track Grids (`New This Week`, `Trending`, `For You`)

```
Mobile (2-Column Grid):                 Desktop (6-Column Grid):
┌──────────────┐ ┌──────────────┐       ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐
│ [✨ NEW]     │ │ [✨ NEW]     │       │[1]│ │[2]│ │[3]│ │   │ │   │ │   │
│   [ 🎹 ]     │ │   [ 🎵 ]     │       │🎹 │ │🎸 │ │🎤 │ │🎻 │ │🥁 │ │🎺 │
├──────────────┤ ├──────────────┤       ├───┤ ├───┤ ├───┤ ├───┤ ├───┤ ├───┤
│ Title Text   │ │ Title Text   │       │...│ │...│ │...│ │...│ │...│ │...│
│ Amapiano...  │ │ Maskandi...  │       └───┘ └───┘ └───┘ └───┘ └───┘ └───┘
│ ❤️ 342  ▶1.2k │ │ ❤️ 512  ▶3.4k │
└──────────────┘ └──────────────┘
```

#### Item Card Structure:
1. **Aspect Ratio:** `1:1` square cover container with `16px` rounded corners.
2. **Cover Background:** Dynamic African genre gradient or curated solid (e.g., Gold/Amber, Electric Indigo, Emerald, Terracotta).
3. **Graphic Artwork / Vector Glyph:** Centered vector icon (Grand piano keyboard, electric guitar, violin, studio microphone, synth wave).
4. **Top Badges:**
   * **New Drops:** Cyan pill badge (`background: #0E3842`, `border: 1px solid #22D3EE`, text: `✨ NEW`, `color: #22D3EE`, `fontSize: 10`).
   * **Trending Rank:** Orange pill badge (`background: #F97316`, text: `#1`, `#2`, `#3`, `color: #000000`, `fontWeight: FontWeight.bold`).
5. **Title:** Single-line bold text with ellipsis (`fontSize: 14`, `fontWeight: FontWeight.w600`, `color: #FFFFFF`).
6. **Sub-Metadata:** `[Genre] • [Language] • [Duration]` (e.g., `Amapiano • English • 3:36`, `fontSize: 12`, `color: #9CA3AF`).
7. **Footer Row:**
   * Like Count: `Icons.favorite_border_rounded` (`size: 14`, `color: #9CA3AF`) + count.
   * Play Count: `Icons.play_arrow_rounded` (`size: 16`, `color: #9CA3AF`) + count.
   * Creator Username: `@sigwa_inaf`, `@ndugelo` (`color: #9CA3AF`, `fontSize: 12`).

---

### Section C: Vertical Track Lists (`Rising`, `Because you make Amapiano`)

```
Mobile (1-Column Vertical):
┌────┬───────────────────────────────────────────────┬───────┬─────┐
│ 🎵 │ Grateful in the Light                         │ ❤️1002│ (▶) │
│48px│ Sigwa & Inaf • Amapiano • 3:36                │       │36px │
└────┴───────────────────────────────────────────────┴───────┴─────┘

Desktop (2-Column Side-by-Side Matrix):
┌───────────────────────────────┬─────┐ ┌───────────────────────────────┬─────┐
│ 🎵 Grateful in the Light      │ (▶) │ │ 🎵 Township Sunset            │ (▶) │
│    Sigwa & Inaf • Amapiano    │     │ │    Ndugelo • Maskandi         │     │
└───────────────────────────────┴─────┘ └───────────────────────────────┴─────┘
```

* **Header:** Section title + contextual subtitle (e.g., `"Fastest growing songs in the last 48 hours"`).
* **Track Row Component (`TrackListTile`):**
  * **Leading (`48x48px`):** Rounded container (`12px` radius), genre gradient background, instrument vector icon.
  * **Title Column:** Track Title (`fontSize: 15`, `fontWeight: FontWeight.w600`, `#FFFFFF`) over Creator Name, Genre, and Duration (`fontSize: 13`, `#9CA3AF`).
  * **Social Stat:** Heart icon + Like count (`❤️ 1002`, `fontSize: 13`, `#9CA3AF`).
  * **Trailing Action:** Circular orange play button (`36x36px`, filled `#F97316` with black play glyph, or active pause glyph when currently playing).

---

### Section D: Featured Creators Grid

```
Mobile (2-Column Grid):                 Desktop (6-Column Single Horizontal Row):
┌──────────────┐ ┌──────────────┐       ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐
│ (SI) Sigwa   │ │ (ND) Ndugelo │       │SI │ │ND │ │DJ │ │TB │ │SA │ │KM │
│ 96 songs     │ │ 21 songs     │       │96s│ │21s│ │45s│ │12s│ │88s│ │34s│
└──────────────┘ └──────────────┘       └───┘ └───┘ └───┘ └───┘ └───┘ └───┘
```

* **Header:** Title `"Featured Creators"` + Subtitle `"Most active musicians on VHUNAMBI"`.
* **Card Structure:**
  * **Container:** Background `#141418`, border `1px solid #2D2D38`, border-radius `16px`, padding `16px`.
  * **Avatar (`48x48px`):** Circular monogram container (`#EA580C` or `#4F46E5`), 2-letter uppercase initials (`SI`, `ND`, `DJ`, `color: #FFFFFF`, `fontWeight: FontWeight.bold`).
  * **Name:** Bold text (`fontSize: 15`, `fontWeight: FontWeight.w600`, `#FFFFFF`).
  * **Output Stat:** Muted track count (`"96 songs"`, `"21 songs"`, `color: #9CA3AF`, `fontSize: 13`).
  * **CTA:** Text link `"View profile ->"` with `Icons.arrow_forward_rounded` (`color: #F97316`, `fontSize: 13`).

---

### Section E: Genre Radio Grid (12 African Genres)

```
Desktop Layout: Exactly 6 Columns × 2 Rows (Unified 12-Genre Mosaic)
Row 1: [ Amapiano ]  [ Kwaito ]     [ Gqom ]      [ Maskandi ]  [ Mbaqanga ]  [ Marabi ]
Row 2: [ Bubblegum ] [ Afro House ] [ Afrobeats ] [ Afro Jazz ] [ Afro Soul ] [ Afro-Arabic ]

Mobile Layout: 2 Columns × 6 Rows
```

* **Header:** `Icons.radio_rounded` + Title `"Genre Radio"` + Subtitle `"Pick a genre and listen non-stop"`.
* **The 12 Curated Genres & Gradients:**
  1. `Amapiano` (Warm Ochre / Gold `#D97706` $\rightarrow$ `#F59E0B`)
  2. `Kwaito` (Brick Red `#991B1B` $\rightarrow$ `#DC2626`)
  3. `Gqom` (Electric Ultraviolet `#312E81` $\rightarrow$ `#4F46E5`)
  4. `Maskandi` (Deep Forest Green `#065F46` $\rightarrow$ `#059669`)
  5. `Mbaqanga` (Bronze Ochre `#78350F` $\rightarrow$ `#B45309`)
  6. `Marabi` (Royal Shebeen Violet `#581C87` $\rightarrow$ `#7E22CE`)
  7. `Bubblegum` (Hot 80s Pink `#BE185D` $\rightarrow$ `#F43F5E`)
  8. `Afro House` (Sunburst Amber `#C2410C` $\rightarrow$ `#EA580C`)
  9. `Afrobeats` (Warm Saffron `#B45309` $\rightarrow$ `#F59E0B`)
  10. `Afro Jazz` (Sapphire Blue `#1E3A8A` $\rightarrow$ `#2563EB`)
  11. `Afro Soul` (Deep Burgundy `#831843` $\rightarrow$ `#DB2777`)
  12. `Afro-Arabic` (Jade Green `#047857` $\rightarrow$ `#0D9488`)
* **Card Overlay CTA:** Centered glassmorphic pill button:
  * Label: `((•)) Play Radio` (`background: rgba(0,0,0,0.6)`, `backdrop-filter: blur(8px)`, `color: #FFFFFF`, `border: 1px solid rgba(255,255,255,0.2)`).

---

### Section F: Filter Engine & Catalog Browser ("All Songs")

#### 1. Genre Filter Rail
Horizontally scrolling pill chips:
`[ All ]  [ Amapiano ]  [ Kwaito ]  [ Gqom ]  [ Maskandi ]  [ Afro House ]  [ Afrobeats ] ...`

#### 2. Mood Filter Wrap
10 emoji-tagged mood chips displayed in a flex wrap:
`😊 Uplifting`, `🌧️ Melancholic`, `⚡ Energetic`, `❤️ Romantic`, `😡 Angry`, `🕊️ Peaceful`, `📷 Nostalgic`, `💪 Motivational`, `🎉 Party`, `🌑 Dark`.

#### 3. Language Selector Dropdown
Modal select covering South African official languages:
`All languages`, `isiZulu`, `isiXhosa`, `Afrikaans`, `English`, `Sepedi`, `Setswana`, `Sesotho`, `Xitsonga`, `siSwati`, `Tshivenḓa`.

#### 4. Sorting & Pagination Controls
* Sorting Pills: `🔥 Newest` | `❤️ Most Liked` | `✕ Clear all filters`.
* **Desktop "Load more" Button:** Centered full pill button (`background: #141418`, border `1px solid #2D2D38`, text `#FFFFFF`, `fontSize: 14`, padding `12px 32px`).

#### 5. Empty Search & Filter State
Displayed when the query/filter combination yields 0 results:
* **Icon:** Outlined music note (`Icons.music_off_rounded`, `size: 56`, `color: #6B7280`).
* **Title:** `"No songs match these filters"`.
* **Description:** `"Try a different genre, language, or mood, or clear your filters to browse everything"`.
* **Dual Action Buttons:** `✕ Clear filters` (ghost/border) and `✨ Create a song` (solid orange).

---

## 6. State Tree Requirements for Riverpod

```dart
// lib/features/explore/presentation/providers/explore_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ExploreTab { discover, forYou, following }
enum SortBy { newest, mostLiked }

final exploreTabProvider = StateProvider<ExploreTab>((ref) => ExploreTab.discover);
final activeGenreFilterProvider = StateProvider<String>((ref) => 'All');
final activeMoodFilterProvider = StateProvider<String?>((ref) => null);
final activeLanguageFilterProvider = StateProvider<String>((ref) => 'All');
final sortByProvider = StateProvider<SortBy>((ref) => SortBy.newest);
final searchQueryProvider = StateProvider<String>((ref) => '');

// Audio Engine Hook
final currentPlayingTrackIdProvider = StateProvider<String?>((ref) => null);
final isAudioPlayingProvider = StateProvider<bool>((ref) => false);
```

---

## 7. Responsive Flutter Implementation Blueprint

```dart
// lib/features/explore/presentation/views/explore_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';

class ExploreView extends ConsumerWidget {
  const ExploreView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 1024;
        final trackGridColumns = isDesktop ? 6 : 2;
        final trackAspectRatio = isDesktop ? 0.72 : 0.75;
        final radioColumns = isDesktop ? 6 : 2;
        final creatorColumns = isDesktop ? 6 : 2;

        return Scaffold(
          backgroundColor: AppColors.surfaceCanvas,
          body: CustomScrollView(
            slivers: [
              // 1. Sticky Navigation Header (Responsive Desktop vs Mobile)
              if (isDesktop)
                const SliverToBoxAdapter(child: DesktopExploreTopBar())
              else
                const ExploreStickyAppBar(),

              // 2. Header, Sub-navigation Tabs & Streak Badge
              const SliverToBoxAdapter(child: ExploreHeaderSection()),

              // 3. Section A: African Music Charts Banner
              const SliverToBoxAdapter(child: AfricanChartsBanner()),

              // 4. Section B: New Drops Grid (6-col Desktop / 2-col Mobile)
              const SliverToBoxAdapter(child: SectionHeader(title: 'New This Week')),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: trackGridColumns,
                    crossAxisSpacing: isDesktop ? 16 : 12,
                    mainAxisSpacing: isDesktop ? 16 : 12,
                    childAspectRatio: trackAspectRatio,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => TrackCard(track: newDrops[index]),
                    childCount: newDrops.length,
                  ),
                ),
              ),

              // 5. Section C: Rising Tracks (Split 2-col Matrix on Desktop / 1-col on Mobile)
              const SliverToBoxAdapter(child: SectionHeader(title: 'Rising')),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: isDesktop
                    ? SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 12,
                          childAspectRatio: 4.8,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => TrackListTile(track: risingTracks[index]),
                          childCount: risingTracks.length,
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => TrackListTile(track: risingTracks[index]),
                          childCount: risingTracks.length,
                        ),
                      ),
              ),

              // 6. Section D: Featured Creators (6-col single row on Desktop / 2-col on Mobile)
              const SliverToBoxAdapter(child: SectionHeader(title: 'Featured Creators')),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: creatorColumns,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: isDesktop ? 1.8 : 2.2,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => CreatorCard(creator: creators[index]),
                    childCount: isDesktop ? 6 : creators.length,
                  ),
                ),
              ),

              // 7. Section E: Genre Radio (6x2 Mosaic on Desktop / 2x6 on Mobile)
              const SliverToBoxAdapter(child: SectionHeader(title: 'Genre Radio')),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: radioColumns,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.4,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => GenreRadioTile(genre: radioGenres[index]),
                    childCount: 12,
                  ),
                ),
              ),

              // 8. Section F: Filter Engine & Catalog Grid
              const SliverToBoxAdapter(child: CatalogFilterBar()),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: trackGridColumns,
                    crossAxisSpacing: isDesktop ? 16 : 12,
                    mainAxisSpacing: isDesktop ? 16 : 12,
                    childAspectRatio: trackAspectRatio,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => TrackCard(track: catalogTracks[index]),
                    childCount: catalogTracks.length,
                  ),
                ),
              ),

              // Desktop "Load more" button
              if (isDesktop)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: LoadMorePillButton()),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
          bottomNavigationBar: isDesktop
              ? null
              : const VhunambiBottomNavDock(activeTab: NavTab.explore),
        );
      },
    );
  }
}
```

# Phase 5 Blueprint: Explore Feed & Music Discovery (`/explore`)

> **Target Platform:** Flutter 3.x+ / Dart 3.x+ (Cross-Platform)  
> **Route Path:** `/explore` (Mounted in Tab Index 1 of `RootShell`)  
> **State Management:** Flutter Riverpod 2.x+  
> **Source Origin:** Production Web Client (`https://vhunambi.com/explore`)  
> **Parent Blueprint:** [`docs/foundation_blueprints/01_EXPLORE_PAGE_SPEC.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/foundation_blueprints/01_EXPLORE_PAGE_SPEC.md)

---

## 1. Visual Architecture & Responsive Viewport Geometry

The Explore view (`/explore`) is Vhunambi's primary discovery engine, aggregating trending tracks, curated African genre radios, rising creator profiles, and a multifaceted search and filter catalog browser. The view employs **Slivers (`CustomScrollView`)** for seamless scroll virtualization and dynamically adapts across mobile and desktop viewports:

```
Desktop Scaffolding (> 1024px):
┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
│ (🎵) VHUNAMBI  / Explore     [ 🔍 Search songs or artists...  Ctrl+K ]   [⚡ 10 songs] [🔔] [👤] [+ Create] │
├──────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Explore                                                                                          │
│ Discover AI music from creators around the world                                                 │
│ [ Discover ]  [ For You ]  [ Following ]                                        [ 🔥 2 Streak ]  │
│                                                                                                  │
│ ┌──────────────────────────────────────────────────────────────────────────────────────────────┐ │
│ │ 📈 African Music Charts                                                          [ View -> ] │ │
│ │    Top songs across All Africa, South Africa, West & East Africa                             │ │
│ └──────────────────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                                  │
│ New This Week                                                                                    │
│ ┌─────┐  ┌─────┐  ┌─────┐  ┌─────┐  ┌─────┐  ┌─────┐   <-- 6-Column Grid (Ratio 0.72)            │
│ │[✨] │  │[✨] │  │     │  │     │  │     │  │     │                                             │
│ │ 🎹  │  │ 🎵  │  │ 🎸  │  │ 🎤  │  │ 🥁  │  │ 🎺  │                                             │
│ └─────┘  └─────┘  └─────┘  └─────┘  └─────┘  └─────┘                                             │
│                                                                                                  │
│ Rising                                                                                           │
│ ┌─────────────────────────────┬───┐  ┌─────────────────────────────┬───┐                         │
│ │ 🎵 Track 1                  │(▶)│  │ 🎵 Track 2                  │(▶)│  <-- 2-Column Split     │
│ └─────────────────────────────┴───┘  └─────────────────────────────┴───┘                         │
│                                                                                                  │
│ Featured Creators                                                                                │
│ ┌───────┐  ┌───────┐  ┌───────┐  ┌───────┐  ┌───────┐  ┌───────┐                                 │
│ │(SI) 96│  │(ND) 21│  │(DJ) 45│  │(TB) 12│  │(SA) 88│  │(KM) 34│   <-- 6-Column Single Row Deck │
│ └───────┘  └───────┘  └───────┘  └───────┘  └───────┘  └───────┘                                 │
│                                                                                                  │
│ Genre Radio                                                                                      │
│ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐                    │
│ │ Amapiano │ │ Kwaito   │ │ Gqom     │ │ Maskandi │ │ Mbaqanga │ │ Marabi   │  <-- 6x2 Mosaic    │
│ └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘                    │
│ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐                    │
│ │Bubblegum │ │Afro House│ │Afrobeats │ │Afro Jazz │ │Afro Soul │ │Afro-Arab │                    │
│ └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘                    │
│                                                                                                  │
│ [ All ] [ Amapiano ] [ Kwaito ] [ Gqom ] [ Maskandi ] [ Afro House ] ...  <-- Filter Rail        │
│ [ 😊 Uplifting ] [ ⚡ Energetic ] [ ❤️ Romantic ] ... [ Language: All ▾ ]                         │
│ ┌─────┐  ┌─────┐  ┌─────┐  ┌─────┐  ┌─────┐  ┌─────┐                                             │
│ └─────┘  └─────┘  └─────┘  └─────┘  └─────┘  └─────┘   <-- 6-Column Catalog Grid                 │
│                                     [ Load more ]                                                │
└──────────────────────────────────────────────────────────────────────────────────────────────────┘
```

```
Mobile Scaffolding (< 768px):
┌────────────────────────────────────────────────────────────────────────┐
│ [ < ]  (🎵)  [ 🔍 Search songs...                             ] [✨]    │ <-- 56px Sticky Top Bar
├────────────────────────────────────────────────────────────────────────┤
│ Explore                                                                │
│ Discover AI music from creators around the world                       │
│ [ Discover ]  [ For You ]  [ Following ]              [ 🔥 2 Streak ]  │
│                                                                        │
│ ┌────────────────────────────────────────────────────────────────────┐ │
│ │ 📈 African Music Charts                                 [View ->]  │ │ <-- Hero Banner
│ └────────────────────────────────────────────────────────────────────┘ │
│                                                                        │
│ New This Week                                                          │
│ ┌──────────────┐  ┌──────────────┐                                     │
│ │ [✨ NEW]     │  │ [✨ NEW]     │   <-- 2-Column Grid (Ratio 0.75)     │
│ │     🎹       │  │     🎵       │                                     │
│ └──────────────┘  └──────────────┘                                     │
│                                                                        │
│ Rising                                                                 │
│ ┌────┬───────────────────────────────────────────────────────┬───────┐ │
│ │ 🎵 │ Grateful in the Light                                 │  (▶)  │ │ <-- 1-Column Dense Rows
│ └────┴───────────────────────────────────────────────────────┴───────┘ │
│                                                                        │
│ Featured Creators                                                      │
│ ┌──────────────┐  ┌──────────────┐                                     │
│ │ (SI) Sigwa   │  │ (ND) Ndugelo │   <-- 2-Column Grid                 │
│ └──────────────┘  └──────────────┘                                     │
│                                                                        │
│ Genre Radio                                                            │
│ ┌──────────────┐  ┌──────────────┐                                     │
│ │ Amapiano     │  │ Kwaito       │   <-- 2x6 Column Grid               │
│ └──────────────┘  └──────────────┘                                     │
│                                                                        │
│ Catalog Browser & Filter Chips                                         │
│ ┌──────────────┐  ┌──────────────┐                                     │
│ └──────────────┘  └──────────────┘                                     │
├────────────────────────────────────────────────────────────────────────┤
│    [Home]       ─[Explore]─       [✨ Create]      [Library]    [Market] │ <-- 64px Mobile Dock
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Breakpoint Matrix & Multi-Column Rules

| Content Section | Mobile (< 768px) | Tablet (768px - 1024px) | Desktop (> 1024px) |
|:---|:---|:---|:---|
| **Top App Bar** | 56px sticky, compact search + brand + square ✨ | 64px bar with search pill | 68px bar, wide search (`Ctrl+K`), breadcrumb, credit chip, bell, avatar, `+ Create` pill |
| **Hero Banner** | Full width, stacked text, compact button | Full width, row layout | Full width, row layout, 24px padding |
| **Track Cards (`New This Week`)** | 2 columns, ratio `0.75`, spacing `12px` | 3–4 columns, ratio `0.74` | 6 columns, ratio `0.72`, spacing `16px` |
| **Rising Tracks** | 1 column vertical list rows (`SliverList`) | 1 column or 2 columns | 2 columns balanced split matrix (`SliverGrid`, ratio `4.8`) |
| **Featured Creators** | 2 columns monogram cards (ratio `2.2`) | 3 columns cards | 6 columns single row deck (ratio `1.8`) |
| **Genre Radio** | 2 columns × 6 rows (ratio `1.4`) | 3 columns × 4 rows | 6 columns × 2 rows unified mosaic (ratio `1.4`) |
| **Catalog Browser** | 2 columns + load more / pagination | 3–4 columns | 6 columns + centered `"Load more"` pill |

---

## 3. Visual Components & Styling Specifications

### 3.1 Global Discovery Navigation Header
- **Desktop Header (> 1024px):**
  - Container: Height `68px`, surface `AppColors.surfaceCanvas` (`#0A0A0C`), bottom border `1px solid AppColors.borderSubtle` (`#2D2D38`).
  - Left: Brand emblem (`#F97316` circle with white music note, `32x32px`), wordmark `"VHUNAMBI"`, breadcrumb `"/ Explore"` (`AppColors.textSecondary`, `fontSize: 14`).
  - Center: Pill search input (`height: 42px`, max-width `560px`, `AppColors.surfaceElevated`, border `1px solid AppColors.borderSubtle`, prefix `Icons.search_rounded`, hint `"Search songs or artists..."`, suffix `Ctrl + K` pill badge).
  - Right: Credit badge (`⚡ 10 songs left`), notification bell button (`Icons.notifications_none_rounded`), circular user avatar (`36x36px`, border `1.5px solid AppColors.brandPrimary`), and primary `+ Create` CTA (`AppColors.brandPrimary`, text `AppColors.brandContrast`, bold).
- **Mobile Header (< 768px):**
  - Height `56px`, brand emblem, centered search input, and compact square/pill `+ Create` button (`AppColors.brandPrimary`).

### 3.2 Page Header & Segmented View Tabs
- Title: `"Explore"` (`AppTypography.displayLarge`, `#FFFFFF`).
- Subtitle: `"Discover AI music from creators around the world"` (`AppTypography.bodyMuted`, `#9CA3AF`).
- Pill Selector Tabs:
  - `Discover` (Default active): `AppColors.brandPrimary` background, `AppColors.brandContrast` text, bold.
  - `For You`: Transparent, `AppColors.textSecondary`.
  - `Following`: Transparent, `AppColors.textSecondary`.
- Gamification Streak Chip:
  - Container: `AppColors.surfaceSecondary`, border `AppColors.borderSubtle`, pill border radius.
  - Icon: Flame `🔥` (`#EA580C`).
  - Label: `"2 Streak"` / `"2 Day Streak"` (`AppColors.textPrimary`, bold).

### 3.3 African Music Charts Banner
- Background: Gradient from `#C2410C` (Deep Terracotta) to `#EA580C` (Vibrant Tangerine) at 135 degrees (`AppGradients.africanChartsBanner`).
- Border Radius: `AppRadius.cardBorder` (`16px`).
- Icon: `Icons.trending_up_rounded` (`#FFFFFF`, size `28`).
- Headline: `"African Music Charts"` (`AppTypography.titleLarge`, bold, white).
- Subtitle: `"Top songs across All Africa, South Africa, West & East Africa"` (white at 90% opacity).
- Trailing CTA: White pill button with pure black text `[ View -> ]`.

### 3.4 Track Card Component (`TrackCard`)
- 1:1 Aspect Ratio Cover Container with `16px` rounded corners.
- Dynamic African genre gradient (`AppGradients.forGenre(track.genre)`) or cached network image.
- Centered instrument vector glyph (`Icons.piano_rounded`, `Icons.graphic_eq_rounded`, `Icons.music_note_rounded`).
- Badges:
  - New Drops: Cyan pill (`background: #0E3842`, `border: 1px solid #22D3EE`, text: `✨ NEW`, `color: #22D3EE`, `fontSize: 10`).
  - Trending: Orange pill (`background: #F97316`, text: `#1`, `#2`, `#3`, `color: #000000`, `fontWeight: FontWeight.bold`).
- Title: Single-line bold text (`AppTypography.bodyLarge`, ellipsis).
- Metadata: `[Genre] • [Language] • [Duration]` (e.g. `Amapiano • English • 3:36`).
- Footer Row: Heart icon + like count, play icon + play count, creator handle (`@sigwa_inaf`).
- Hover/Tap Action: Triggers instant playback via `playerStateProvider`.

### 3.5 Rising Tracks Matrix (`TrackListTile`)
- Leading square: `48x48px`, `12px` rounded corners, genre gradient background, instrument icon.
- Title column: Track title (white, bold) over creator, genre, and duration.
- Social stat: Heart icon + like count (`❤️ 1002`).
- Play trigger: Circular orange button (`36x36px`, `AppColors.brandPrimary`, black play/pause glyph).

### 3.6 Featured Creators Deck (`CreatorCard`)
- Background: `AppColors.surfaceElevated` (`#141418`), border `AppColors.borderSubtle`, `16px` radius.
- Avatar (`48x48px`): Circular monogram container (`#EA580C` or `#4F46E5`), 2-letter uppercase initials (`SI`, `ND`, `DJ`).
- Name: Bold text (`AppTypography.titleMedium`).
- Output stat: Muted track count (`"96 songs"`).
- Action link: `"View profile ->"` (`AppColors.brandPrimary`).

### 3.7 12-Genre Radio Grid (`GenreRadioTile`)
- Exact 12 curated African musical heritage genres:
  1. `Amapiano` (Warm Ochre / Gold `#D97706` → `#F59E0B`)
  2. `Kwaito` (Brick Red `#991B1B` → `#DC2626`)
  3. `Gqom` (Electric Ultraviolet `#312E81` → `#4F46E5`)
  4. `Maskandi` (Deep Forest Green `#065F46` → `#059669`)
  5. `Mbaqanga` (Bronze Ochre `#78350F` → `#B45309`)
  6. `Marabi` (Royal Shebeen Violet `#581C87` → `#7E22CE`)
  7. `Bubblegum` (Hot 80s Pink `#BE185D` → `#F43F5E`)
  8. `Afro House` (Sunburst Amber `#C2410C` → `#EA580C`)
  9. `Afrobeats` (Warm Saffron `#B45309` → `#F59E0B`)
  10. `Afro Jazz` (Sapphire Blue `#1E3A8A` → `#2563EB`)
  11. `Afro Soul` (Deep Burgundy `#831843` → `#DB2777`)
  12. `Afro-Arabic` (Jade Green `#047857` → `#0D9488`)
- Centered glassmorphic pill button overlay: `((•)) Play Radio`.

### 3.8 Catalog Filter Engine & Empty State
- Genre Filter Rail: Horizontal pill rail `[ All ] [ Amapiano ] [ Kwaito ] [ Gqom ] [ Maskandi ] ...`.
- Mood Chips Flex Wrap: 10 emoji chips (`😊 Uplifting`, `🌧️ Melancholic`, `⚡ Energetic`, `❤️ Romantic`, `🕊️ Peaceful`, `🔥 Angry`, `📻 Nostalgic`, `🌙 Mysterious`, `🎉 Party`, `🖤 Dark`).
- Language Dropdown: Modal sheet / dropdown covering South African official languages (`All languages`, `isiZulu`, `isiXhosa`, `Afrikaans`, `English`, `Sepedi`, `Setswana`, `Sesotho`, `Xitsonga`, `siSwati`, `Tshivenḓa`).
- Sorting & Pagination: `🔥 Newest` | `❤️ Most Liked` | `✕ Clear filters`. Centered `"Load more"` button.
- Empty State: `Icons.music_off_rounded`, `"No songs match these filters"`, dual actions (`✕ Clear filters` and `✨ Create a song`).

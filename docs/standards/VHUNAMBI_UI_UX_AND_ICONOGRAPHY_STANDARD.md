# 🎨 Vhunambi UI/UX, Touch Physics & Iconography Standard

**Document ID:** `STD-UIUX-001`  
**Target Platform:** Mobile, Tablet & Desktop (`apps/vhunambi_client`)  
**Standard Status:** Canonical Architecture Standard (V4.1+)  
**Originating Sprints:** Phase 29 (Explore Decluttering), Phase 30 (Creator Profile), Phase 31 (Home Dashboard), Phase 34 (Mobile Nav & Phosphor Iconography)

---

## 1. Executive Summary & Core Philosophy

Vhunambi’s visual language is celebrated for its **organic, soft, rounded, Afro-futuristic aesthetic**. Our design avoids cold, sharp industrial edges, visual clutter, and tacky emoji-based interfaces. 

This standard codifies four foundational UI/UX pillars that must be strictly adhered to across all current and future screens, tabs, modals, sheets, and components:

1. **Sovereign Phosphor Vector Iconography (`AppIcons`)**: Elimination of blocky stock icons and raw UI emojis.
2. **Viewport Decluttering & Progressive Disclosure**: 56dp minimalist top chrome, transient auto-collapsing titles, and sheet-based exploration.
3. **Touch Physics & Frosted Glass Bleed Prevention**: Elimination of the "cracked screen" ink bleed defect and double-haptic vibration jitter.
4. **Narrow Viewport Resilience & Fluid Typography**: Safeguards preventing `RenderFlex overflow` down to 360dp phone screens.

---

## 2. Standard 1: Sovereign Phosphor Vector Iconography

```
                    ┌───────────────────────────────────────────────┐
                    │               AppIcons Registry               │
                    │   (core/design_system/tokens/app_icons.dart)  │
                    └───────────────────────┬───────────────────────┘
                                            │
               ┌────────────────────────────┼────────────────────────────┐
               ▼                            ▼                            ▼
     PhosphorIconsRegular            PhosphorIconsFill            PhosphorIconsDuotone
     (Outline / Inactive)             (Solid / Active)           (Layered Hero Visuals)
        ~10.7 KB font                   ~5.5 KB font                 (Tree-shaken)
```

### 2.1 The Strict Emoji Ban in UI Controls
- **PROHIBITED:** Using literal emojis (`🔥`, `🪙`, `⚡`, `🧬`, `🏆`, `🎵`, `💿`, `🎛️`, `✨`, `❤️`, `💰`) as buttons, navigation labels, stat badges, or metric indicators. Emojis render inconsistently across Android, iOS, and desktop, have jagged unrounded contours, and break brand color consistency.
- **PERMITTED EXCEPTIONS:** Emojis are reserved **exclusively** for:
  1. Genuine User-Generated Content (chat messages, reels comment threads).
  2. The authenticated cultural gifts catalog (`kCulturalGifts` e.g., 🐮 Cowrie Shell, 👑 Khare Crown, 🥁 Ngoma Drum).

### 2.2 Style-Specific Import Rules & Font Tree-Shaking
To prevent font bloat in release APKs, never use generic runtime icon factories. Always reference compile-time constants from `PhosphorIconsRegular` or `PhosphorIconsFill` via `AppIcons`:

```dart
// ❌ WRONG: Hardcoded stock Material icon or emoji
Icon(Icons.play_circle_fill_rounded);
Text('🔥 12');

// ❌ WRONG: Non-tree-shaken dynamic Phosphor lookup
PhosphorIcon(PhosphorIcons.getIcon('fire'));

// ✅ CORRECT: Centralized design token with automatic tree-shaking
PhosphorIcon(AppIcons.play);
Row(
  children: [
    PhosphorIcon(AppIcons.flame, color: AppColors.brandPrimary, size: 14),
    SizedBox(width: 4),
    Text('12', style: AppTypography.caption),
  ],
);
```

### 2.3 Semantic Token Matrix

| UI Domain | Inactive / Outline Token | Active / Solid Token | Color Token | Replaces |
| :--- | :--- | :--- | :--- | :--- |
| **Home Nav** | `AppIcons.navHome` | `AppIcons.navHomeActive` | `AppColors.brandPrimary` | Sharp Material `home` |
| **Explore Nav** | `AppIcons.navExplore` | `AppIcons.navExploreActive` | `AppColors.brandPrimary` | Stock `explore` |
| **Create Nav** | `AppIcons.navCreate` | `AppIcons.navCreateActive` | `AppGradients.primaryButton` | Stock `add_circle` |
| **Library Nav** | `AppIcons.navLibrary` | `AppIcons.navLibraryActive` | `AppColors.brandPrimary` | Stock `library_music` |
| **Market Nav** | `AppIcons.navMarket` | `AppIcons.navMarketActive` | `AppColors.brandPrimary` | Stock `storefront` |
| **Day Streak** | `AppIcons.flameOutline` | `AppIcons.flame` | `AppColors.brandPrimary` | Literal `'🔥'` emoji |
| **Coins Balance** | `AppIcons.coin` | `AppIcons.coins` | `AppColors.coinGold` | Literal `'🪙'` emoji |
| **AI Generation**| `AppIcons.sparkleOutline`| `AppIcons.sparkle` | `AppColors.brandPrimary` | Literal `'✨'` emoji |
| **Audio Stems** | `AppIcons.songs` / `drums` | `AppIcons.piano` / `guitar` | `AppColors.brandPrimary` | Literal stem emojis |
| **Verification** | `AppIcons.verified` | `AppIcons.verified` | `AppColors.brandPrimary` | Jagged Material badge |

---

## 3. Standard 2: Viewport Decluttering & Progressive Disclosure

### 3.1 56dp Minimalist Mobile Top Chrome
Dense multi-row headers waste up to 25% of mobile screen height before the user sees content. All root tabs must standardize on the **56dp minimalist top bar pattern**:
- **Anchor (Far Left):** 30×30dp circular brand monogram (`vhunambiGlyph`).
- **Brand Title:** Bold tracked typography (`VHUNAMBI`), coupled with an auto-collapsing transient label.
- **Action Triad (Far Right):** Maximum of 3 compact actions ($\le 40\text{dp}$ each):
  1. Discovery / Filters (`AppIcons.beatstore` or `PhosphorIconsRegular.squaresFour`).
  2. Search (`AppIcons.search`).
  3. Single-step Notification Bell (`NotificationBellButton`).
  4. Compact 26dp Profile Avatar (`OwnerProfileView` shortcut).

### 3.2 Transient Title Auto-Collapse Pattern
To allow users to immediately identify which tab they are on without permanently wasting vertical space:
1. Render a compact transient pill next to the brand logo (e.g., `_TransientExploreTitlePill`).
2. Keep it visible for 3.5 to 4.0 seconds on initial entry.
3. Automatically fade out (`Curves.easeInOut`, 300ms) and collapse width to `0.0`, returning the entire header width to content and actions.

```dart
// Standard Transient Header Transition
AnimatedOpacity(
  duration: const Duration(milliseconds: 300),
  opacity: _isVisible ? 1.0 : 0.0,
  child: AnimatedSize(
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeOutCubic,
    child: _isVisible ? _buildTitlePill() : const SizedBox.shrink(),
  ),
);
```

### 3.3 Progressive Disclosure via Slide-Up Sheets
Never dump dozens of filter chips, genre tags, and sorting options as permanent sticky strips above scrollable feeds.
- **Surface Level:** Show the primary feed (e.g. Stories Rail, Trending Shelf, Social Post Cards).
- **Secondary Discovery:** One tap on the discovery icon opens a dedicated, frosted bottom sheet (`ExploreDiscoveryDrawerSheet` or `MarketplaceFilterModal`) with structured categorical navigation.

---

## 4. Standard 3: Touch Physics & Frosted Glass Bleed Prevention

```
                     ╔═══════════════════════════════════════════╗
                     ║   Frosted Glass BackdropFilter (σ ≥ 16)   ║
                     ╚═══════════════════════════════════════════╝
                                           │
                ┌──────────────────────────┴──────────────────────────┐
                ▼                                                     ▼
     ❌ DEFAULT MATERIAL INK                               ✅ ZERO-BLEED TOUCH
  - InkResponse with default white/grey                  - splashColor: transparent
  - Highlight expands across blur                        - highlightColor: transparent
  - Causes "cracked screen" milky glow                   - Smooth capsule slide animation
```

### 4.1 Eradicating the "Cracked Screen Glow" Defect
When interactive controls are rendered over a blurred background (`BackdropFilter` with $\sigma \ge 16$, e.g., in `VhunambiBottomDockSurface`), standard Flutter `InkResponse` highlight spreads a diffuse white bloom that looks like pressing against cracked liquid crystal.

**Mandatory Rule:** All interactive navigation, drawer, and dock items placed over frosted glass must explicitly zero out splash and highlight colors:

```dart
// Mandatory Zero-Bleed Configuration
InkResponse(
  splashColor: Colors.transparent,
  highlightColor: Colors.transparent,
  hoverColor: Colors.transparent,
  focusColor: Colors.transparent,
  onTap: onTap,
  child: widget,
);
```

### 4.2 Single-Channel Tactile Haptics
Stock Flutter navigation widgets (like `BottomNavigationBar`) trigger automatic OS feedback on Android (`Feedback.forTap`), causing a double-click collision when combined with custom haptic services.

**Mandatory Rule:** Disable platform auto-feedback and invoke a single, curated haptic channel:
- **Tab Change / Filter Toggle:** `HapticsService().selectionClick()`
- **Secondary Actions (Like, Share):** `HapticsService().lightImpact()`
- **Hero Actions (Play, Remix, Buy):** `HapticsService().mediumImpact()`

### 4.3 Ambient Sliding Capsule Indicator
Active states must never snap instantly. Use physics-based sliding interpolation:
- **Duration:** 200ms to 240ms (optimal perceptual responsiveness).
- **Easing Curve:** `Curves.easeOutCubic` (natural human decelerating motion).
- **Container:** Rounded pill (`BorderRadius.circular(24)`), tinted with `AppColors.brandPrimary.withAlpha(28)` or frosted glass border.

---

## 5. Standard 4: Narrow Viewport & Hydration Safety Defenses

### 5.1 The 360dp Narrow Viewport Defense
Many entry-level and compact Android devices have viewports of 360×800dp. Multi-segment switchers (e.g. Songs / Releases / Beatstore) will overflow if fixed padding and font sizes are used.

**Mandatory Rule:** All horizontal segmented switchers, action button bars, and metric cards must wrap their child rows in `FittedBox(fit: BoxFit.scaleDown)`:

```dart
// Mandatory Defensive Row Layout
Expanded(
  child: Center(
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PhosphorIcon(AppIcons.songs, size: 14),
          const SizedBox(width: 5),
          Text('Songs', maxLines: 1),
        ],
      ),
    ),
  ),
);
```

### 5.2 Two-Line Compact Metric & Greeting Layout
Never render single-line unbounded greetings like `"Good Morning, Ndugelo!"` next to coin and streak pills on mobile headers.
- **Line 1:** Micro-caption in uppercase (`WELCOME BACK`).
- **Line 2:** Dynamic greeting with `maxLines: 1` and `TextOverflow.ellipsis`.

---

## 6. Implementation Checklist for Future Phases

Every new screen, modal, or feature PR must pass this QA gate:

- [ ] **Icon Token Check:** Zero instances of `Icons.*` from Material and zero raw UI emojis; all icons reference `AppIcons.*` or `PhosphorIconsRegular` / `PhosphorIconsFill`.
- [ ] **Touch Target Check:** Every tappable button or icon tile has a minimum bounding box of $44 \times 44\text{dp}$.
- [ ] **Bleed Check:** Any button over frosted glass or blurred containers sets `splashColor: Colors.transparent` and `highlightColor: Colors.transparent`.
- [ ] **Haptics Check:** Only curated `HapticsService()` single-channel triggers are fired on tap.
- [ ] **Narrow Device Check:** Tested or simulated at $360\text{dp}$ width with zero `RenderFlex` overflows.
- [ ] **Tree-Shaking Check:** Release build logs show $>95\%$ font asset reduction for Phosphor font files.

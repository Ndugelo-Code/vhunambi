# Phase 35 Requirements: Adaptive Mini-Player, Freeform Drag & Bin Dismiss

## Functional Requirements (FR)

### FR-01: 2-Form Mini-Player State System
- **FR-01.1**: The `PlayerForm` enum MUST contain exactly two forms: `PlayerForm.bar` and `PlayerForm.pill`.
- **FR-01.2**: `PlayerForm.card` and `card_form.dart` MUST be deprecated and removed.
- **FR-01.3**: SharedPreferences state loading MUST gracefully migrate any legacy persisted `formIndex >= 2` or `card` index to `PlayerForm.pill`.

### FR-02: Universal Shell Scroll-Driven Morphing
- **FR-02.1**: Vertical scrolling on ANY root tab (`HomeDashboardView`, `ExploreView`, `LibraryView`, `MarketplaceView`) MUST bubble to `RootShell` and trigger mini-player morphing.
- **FR-02.2**: Downward scroll exploration (`scrollDelta > 2` and `pixels > 40`) while in `PlayerForm.bar` and `PlayerMode.auto` MUST morph the mini-player to `PlayerForm.pill`.
- **FR-02.3**: Scrolling back to the top of the feed (`pixels <= 10`) while in `PlayerForm.pill` and `PlayerMode.auto` MUST restore the mini-player to `PlayerForm.bar`.
- **FR-02.4**: Horizontal scroll notifications (e.g. carousels, genre chips) MUST be ignored (`notification.metrics.axis == Axis.vertical`).
- **FR-02.5**: If the player is in `PlayerMode.manual` (user explicitly repositioned it), scroll-driven auto-morphing MUST NOT override user placement.

### FR-03: Fluid Freeform Drag Physics Engine
- **FR-03.1**: Holding or panning the mini-player MUST instantly activate drag mode (`isDragging = true`, `mode = PlayerMode.manual`) without latency.
- **FR-03.2**: Touch tracking MUST calculate grab-point anchor offset ($\Delta = \text{touch} - \text{widgetTopLeft}$) to prevent visual jumping.
- **FR-03.3**: During active drag, `AnimatedPositioned` animation duration MUST be `Duration.zero` for direct 60/120fps tracking.
- **FR-03.4**: Position MUST be clamped within screen safe margins:
  - $X \in [8.0, \text{screenWidth} - \text{width} - 8.0]$
  - $Y \in [\text{topSafeArea} + 8.0, \text{screenHeight} - \text{height} - \text{bottomSafeArea} - 8.0]$

### FR-04: Drag to Bin Dismiss Mechanics
- **FR-04.1**: Whenever `isDragging == true`, an animated Bin Target (`_BinDismissTarget`) MUST appear at the bottom-center of the screen above the bottom dock.
- **FR-04.2**: The Bin Target MUST feature Phosphor `AppIcons.trash` inside a circular frosted orb ($\ge 56 \times 56\text{dp}$).
- **FR-04.3**: When the mini-player center enters within $R \le 64\text{dp}$ of the bin center:
  - Bin target MUST expand ($1.25\times$) and glow bright crimson (`AppColors.error`).
  - Mini-player MUST magnetize toward bin center and scale down ($0.85\times$, `0.7` opacity).
  - A tactile heavy impact haptic MUST fire (`HapticsService().heavyImpact()`).
- **FR-04.4**: If the user releases inside the bin boundary:
  - Mini-player MUST shrink to zero ($0 \times 0$) toward bin center.
  - Audio playback MUST stop, and player state MUST be dismissed (`playerStateProvider.notifier.dismiss()`).
  - Controller MUST reset to docked Bar in Auto mode.
- **FR-04.5**: If released outside the bin, the bin MUST fade out, and the mini-player MUST snap to the nearest screen edge.

### FR-05: Rounded, Fun Vector Iconography
- **FR-05.1**: All transport buttons in `mobile_mini_player.dart` and `pill_form.dart` MUST use Phosphor icons (`AppIcons.play`, `AppIcons.pause`, `AppIcons.skipBack`, `AppIcons.skipForward`).
- **FR-05.2**: Legacy Material Icons (`Icons.music_note_rounded`, `Icons.pause_rounded`, `Icons.play_arrow_rounded`) MUST be completely removed.
- **FR-05.3**: All button containers MUST have circular shapes (`BoxDecoration(shape: BoxShape.circle)`) and circular ink boundaries (`IconButton.styleFrom(shape: const CircleBorder())`).

---

## Non-Functional Requirements (NFR)
- **NFR-01 (Performance):** Zero jank during drag tracking (maintains 60/120fps).
- **NFR-02 (Safety):** RAM consumption of release APK stays under 45MB.
- **NFR-03 (Standards):** Strictly complies with `STD-UIUX-001`.
- **NFR-04 (Quality):** 0 issues with `dart analyze lib test`.


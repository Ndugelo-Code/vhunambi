# Phase 35 Design: Adaptive Mini-Player, Freeform Drag & Bin Dismiss

## 1. System Architecture & Component Interactions

```
+---------------------------------------------------------------------------------+
|                                    RootShell                                    |
|   NotificationListener<ScrollNotification> (Filters Axis.vertical)              |
|        │                                                                        |
|        ▼                                                                        |
|   MiniPlayerController                                                          |
|        │  - form: PlayerForm (bar | pill)                                       |
|        │  - mode: PlayerMode (auto | manual)                                    |
|        │  - isDragging: bool                                                    |
|        │  - dragPosition: Offset                                                |
|        │  - isOverBin: bool                                                     |
|        │                                                                        |
|        ▼                                                                        |
|   MiniPlayerHost (Overlay in MaterialApp.builder)                               |
|   ├── _BinDismissTarget (Bottom-center animated trash orb)                      |
|   └── AnimatedPositioned (Duration: isDragging ? 0ms : 200ms)                   |
|        └── GestureDetector (Pan/LongPress tracking + grab anchor offset)         |
|             ├── MobileMiniPlayer (Bar Form with circular Phosphor buttons)      |
|             └── PillForm (Floating Pill with circular Phosphor buttons)         |
+---------------------------------------------------------------------------------+
```

---

## 2. Gesture Physics & Collision Engine

### 2.1 Anchor Grab Calculation
When touch begins at `globalPosition`:
$$\text{grabOffset} = \text{globalPosition} - \text{currentWidgetPosition}$$
During drag:
$$\text{rawPosition} = \text{globalPosition} - \text{grabOffset}$$

### 2.2 Boundary Clamping
$$\text{clampedX} = \text{clamp}(8.0, \text{screenWidth} - \text{formWidth} - 8.0)$$
$$\text{clampedY} = \text{clamp}(\text{topSafeArea} + 8.0, \text{screenHeight} - \text{formHeight} - \text{bottomSafeArea} - 8.0)$$

### 2.3 Collision Detection Math
With bin center $C_b = (X_b, Y_b)$ and player center $C_p = (X_p + W_p/2, Y_p + H_p/2)$:
$$d = \sqrt{(C_{px} - C_{bx})^2 + (C_{py} - C_{by})^2}$$
$$\text{isOverBin} = d \le 64.0\text{dp}$$

---

## 3. Visual Specifications

### 3.1 Bin Target (`_BinDismissTarget`)
- **Dimensions:** $64 \times 64\text{dp}$ circular container.
- **Position:** Bottom center:
  - `left = (screenWidth - 64) / 2`
  - `bottom = 56 + bottomSafeArea + 16`
- **Idle Drag State:**
  - Background: `Colors.black.withOpacity(0.65)` with frosted 18-sigma backdrop blur.
  - Border: $1.5\text{dp}$ subtle red hairline (`AppColors.error.withOpacity(0.4)`).
  - Icon: Phosphor `AppIcons.trash` ($28\text{dp}$, white).
- **Hovered State ($d \le 64\text{dp}$):**
  - Transform: $1.25\times$ scale expansion.
  - Background: `AppColors.error` ($0xFFEF4444$) with $24\text{dp}$ crimson glow.
  - Icon: Pulsing `AppIcons.trash` ($30\text{dp}$, pure white).
  - Tactile Feedback: Heavy impact pulse.

### 3.2 Transport Controls Rounding
- **Pill Form:**
  - Center disc: 32dp circular cover art with `PhosphorIcon(AppIcons.songs)`.
  - Play/Pause orb: 36dp circular elevated capsule (`shape: BoxShape.circle`), `PhosphorIcon(AppIcons.play / pause, size: 18)`.
- **Bar Form (`MobileMiniPlayer`):**
  - Previous / Next buttons: `IconButton` with `shape: const CircleBorder()`, size 44x44dp.
  - Play/Pause orb: 44x44dp circular orb (`shape: BoxShape.circle`), `PhosphorIcon(AppIcons.play / pause, size: 22)`.


# Phase 35 Blueprint: Adaptive Mini-Player, Freeform Drag & Bin Dismiss

## Phase Goal
Deliver a unified, responsive, and delightful mobile audio transport experience by standardizing on a clean 2-form mini-player architecture (docked **Bar** and floating **Pill**), fixing freeform drag gesture physics with 60fps tracking, introducing an animated **Drag-to-Bin close/dismiss mechanic**, unifying scroll-driven morphing across all root tabs in `RootShell`, and applying soft, rounded Phosphor vector iconography to all transport controls.

## Success Metrics
1. **Unified Root Tab Morphing:** Scrolling on any root tab (Home, Explore, Library, Market) smoothly morphs the mini-player between docked Bar and floating Pill.
2. **2-Form System (`bar` & `pill`):** `PlayerForm.card` completely deprecated and removed with zero residual compile or runtime errors.
3. **Fluid Freeform Dragging:** Dragging tracks the user's finger at 60/120fps with zero latency, correct grab-anchor offsets, and screen boundary clamping.
4. **Drag to Bin Dismiss:** Dragging reveals an animated bottom-center trash bin target; dragging into its boundary ($R \le 64\text{dp}$) and releasing instantly kills/dismisses the player with heavy tactile haptics.
5. **Soft Rounded Phosphor Iconography:** All transport buttons and badges feature soft rounded Phosphor vector glyphs housed in circular, organic touch targets ($\ge 44 \times 44\text{dp}$).
6. **Code Quality & Test Rigor:** `dart analyze lib test` produces 0 issues; all unit and widget tests pass.


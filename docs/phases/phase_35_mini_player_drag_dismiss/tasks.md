# Phase 35 Tasks: Adaptive Mini-Player, Freeform Drag & Bin Dismiss

## Task Breakdown

- [x] **Task 1: Deprecate `PlayerForm.card` & Simplify Controller to 2-Form Architecture**
  - [x] Refactor `PlayerForm` enum in `mini_player_controller.dart` to `{ bar, pill }`.
  - [x] Remove `PlayerForm.card` calculations from `clampedPosition`, `calculateAutoPosition`, and `reservedBottom`.
  - [x] Add migration handling in `loadState()` for legacy index values.
  - [x] Remove `card_form.dart` and its import from `mini_player_host.dart`.
  - [x] Verify test suite runs with 0 compile errors on the 2-form enum.

- [x] **Task 2: Fix Freeform Drag Physics & Zero-Latency Direct Tracking**
  - [x] Update `MiniPlayerController`: ensure `startDrag` switches to `PlayerMode.manual` and tracks grab anchor offset.
  - [x] Update `MiniPlayerHost`: set `duration: Duration.zero` on `AnimatedPositioned` when `isDragging == true`.
  - [x] Implement grab offset compensation so the mini-player doesn't jump to the finger on pick-up.
  - [x] Implement screen boundary clamping during manual drag.

- [x] **Task 3: Implement Bottom-Center Bin Dismiss Target & Destroy Mechanics**
  - [x] Create `_BinDismissTarget` widget inside `MiniPlayerHost` with animated entrance/exit.
  - [x] Add collision detection logic ($d \le 64\text{dp}$) comparing player center to bin center.
  - [x] Add visual feedback: bin expands ($1.25\times$) and glows crimson when hovered; mini-player magnetizes and shrinks.
  - [x] Add single-channel haptic trigger when crossing the bin threshold (`HapticsService().heavyImpact()`).
  - [x] On drop inside bin: execute collapse animation $\rightarrow$ call `playerNotifier.dismiss()` $\rightarrow$ reset controller.

- [x] **Task 4: Implement Shell-Wide Scroll-Driven Morphing in RootShell**
  - [x] Wrap `IndexedStack` / `Scaffold.body` in `RootShell` (`main.dart`) in `NotificationListener<ScrollNotification>`.
  - [x] Filter strictly by `notification.metrics.axis == Axis.vertical`.
  - [x] Downward scroll (`pixels > 40 & delta > 2`) morphs to `PlayerForm.pill`.
  - [x] Scroll to top (`pixels <= 10`) restores `PlayerForm.bar`.
  - [x] Unify bidirectional scroll handling in `explore_view.dart` and `RootShell`.

- [x] **Task 5: Upgrade Mini-Player Button Iconography to Soft Rounded Phosphor Icons**
  - [x] Replace Material icons in `pill_form.dart` (`Icons.music_note_rounded`, `Icons.pause_rounded`, `Icons.play_arrow_rounded`) with `AppIcons.songs`, `AppIcons.play`, `AppIcons.pause`.
  - [x] Add circular orb styling (`BoxShape.circle`) to Pill form buttons.
  - [x] Update `mobile_mini_player.dart` play/pause button to use `PhosphorIcon` instead of `Icon`.
  - [x] Add `IconButton.styleFrom(shape: const CircleBorder())` to previous and next buttons.
  - [x] Modernized `expanded_cockpit_modal.dart` with Phosphor icons (`AppIcons.disc`, `AppIcons.mic`, `AppIcons.heart`, `AppIcons.sparkle`, `AppIcons.lightning`, `AppIcons.playlist`).

- [x] **Task 6: Verification & Test Suite Execution**
  - [x] Update unit and widget tests in `test/features/player/` for 2-form system and bin dismiss.
  - [x] Create and pass `phase35_drag_dismiss_bin_test.dart` (4/4 tests passed).
  - [x] Verify complete player and root shell test suites pass (29/29 player tests passed, 11/11 home/explore tests passed).

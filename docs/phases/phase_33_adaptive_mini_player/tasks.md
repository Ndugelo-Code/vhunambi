# Phase 33: Adaptive Mini Player & Expanded Cockpit V4.1 Convergence — Tasks Checklist

**Phase:** 33  
**Status:** Approved & Ready for Execution  
**Target:** `apps/vhunambi_client/lib/features/player/` & `apps/vhunambi_client/lib/features/explore/`

---

## Track A: Core Visibility, Docking & Obstacle Avoidance

- [ ] **Task 33.1**: Fix `MiniPlayerHost._shouldHide()` in `apps/vhunambi_client/lib/features/player/presentation/widgets/mini_player_host.dart`
  - Remove fatal `if (route == null) return true;` check.
  - Rely on explicit `ResponsiveUtils.isDesktop(context)`, `!playerState.hasActiveTrack`, `controller.isNowPlayingOpen`, and `viewInsets.bottom > 0`.
  - Tag `MiniPlayerHost` with `Key('mini_player_host')`.
  - Wire `onExpand: () => ExpandedCockpitModal.show(context)` across Bar, Card, and Pill forms.

- [ ] **Task 33.2**: Upgrade `MiniPlayerController` auto-docking and obstacle collision engine in `apps/vhunambi_client/lib/features/player/presentation/providers/mini_player_controller.dart`
  - Implement real obstacle collision math: iterate `_obstacles.values`, detect bottom-dock collisions (`obstacle.bottom > screenSize.height - 240`), and elevate the player 8dp above the highest obstacle.
  - Add safe coordinate clamping helper `clampedPosition(Size screenSize, double bottomSafeArea)` to bound manual drag gestures within visible viewport boundaries.
  - Ensure `reservedBottom` returns `VhunambiBottomDockMetrics.miniPlayerHeight + 8.0` in Bar form and `0.0` in Pill/Card forms.

- [ ] **Task 33.3**: Calibrate layout math in `MiniPlayerHost`
  - Dynamically calculate active position via `_resolveActivePosition(...)` using `screenSize`, `bottomSafeArea`, and obstacle heights.
  - Use `left: 8.0, right: 8.0` for full-width Bar form (`screenSize.width - 16`) to prevent horizontal overflow on right screen edge.

---

## Track B: 3-Form Morphing & Touch Ergonomics

- [ ] **Task 33.4**: Tag and calibrate `MobileMiniPlayer` (Bar Form) in `apps/vhunambi_client/lib/features/player/presentation/widgets/mobile_mini_player.dart`
  - Tag widget with `Key('mini_player_bar')`.
  - Verify all touch targets (previous, play/pause, next) are $\ge 44 \times 44\text{dp}$.
  - Ensure Hero tag `'now_playing_art_${track.id}'` matches `ExpandedCockpitModal`.

- [ ] **Task 33.5**: Tag and calibrate `CardForm` in `apps/vhunambi_client/lib/features/player/presentation/widgets/card_form.dart`
  - Tag widget with `Key('mini_player_card')`.
  - Ensure entire 128×128dp square card has tap-to-expand hit target.

- [ ] **Task 33.6**: Throttle and calibrate `PillForm` in `apps/vhunambi_client/lib/features/player/presentation/widgets/pill_form.dart`
  - Tag widget with `Key('mini_player_pill')`.
  - Pause 33ms timer when `!playerState.isPlaying`.
  - Immediately stop timer and clear glow spreads when `reduceMotion` is enabled.

---

## Track C: Phase 29 Social Explore Feed Auto-Pill Collapse

- [ ] **Task 33.7**: Integrate scroll listener into `ExploreView` (`apps/vhunambi_client/lib/features/explore/presentation/views/explore_view.dart`)
  - Attach `NotificationListener<ScrollNotification>` to the social reels post list.
  - Morph player to `PlayerForm.pill` when vertical feed scrolling begins.

- [ ] **Task 33.8**: Tab navigation restore in `RootShell` (`apps/vhunambi_client/lib/main.dart`)
  - When switching away from Explore tab (e.g. to Home, Studio, Library, or Market), automatically restore player to `PlayerForm.bar` if in Auto mode.

---

## Track D: Expanded Cockpit V4.1 Studio Convergence

- [ ] **Task 33.9**: Wire authentic 60 Hz `masterRmsBytes` waveform visualizer into `apps/vhunambi_client/lib/features/player/presentation/widgets/expanded_cockpit_modal.dart`
  - Read `masterMediaObjectProvider(dna)` using `SongMetadataDna.fromTrackInfo(...)`.
  - Render 60 vertical bars sampled from `masterRmsBytes` with active progress tinting and drag scrubbing.

- [ ] **Task 33.10**: Implement 1-tap `[ 🎚️ Master A/B ]` audio auditioning chip
  - Add `Key('cockpit_master_ab_btn')` in utility tray.
  - Toggles between raw and mastered DSP chain with active amber glow indicator.

- [ ] **Task 33.11**: Implement `[ 🔁 Remix in Studio ]` action chip
  - Add `Key('cockpit_remix_studio_btn')` in utility tray.
  - Pre-populates `studioFormProvider` with the active track's genre and prompt.
  - Closes cockpit and navigates to the Studio tab (`_openStudio()`).

---

## Track E: Comprehensive Testing & Verification Gates

- [ ] **Task 33.12**: Author comprehensive verification test suite `apps/vhunambi_client/test/features/player/phase33_adaptive_mini_player_test.dart`
  - Test 1: `MiniPlayerHost` renders in `MaterialApp.builder` without route trapping.
  - Test 2: Form switching (Bar ➔ Card ➔ Pill) via `controller.setForm(...)`.
  - Test 3: Obstacle avoidance lifts Bar form 8dp above bottom obstacles.
  - Test 4: Tapping any player form launches `ExpandedCockpitModal`.
  - Test 5: Scrolling social feed in Explore triggers auto-pill collapse.
  - Test 6: `ExpandedCockpitModal` renders 60-bar `masterRmsBytes` waveform and scrubber.
  - Test 7: Master A/B and Remix in Studio action chips mount and trigger callbacks.
  - Test 8: Compact 360×800dp viewport renders without RenderFlex overflows.

- [ ] **Task 33.13**: Run existing player test suite
  - `flutter test test/features/player` (all 140+ tests passing).

- [ ] **Task 33.14**: Run static analyzer
  - `dart analyze lib test` (0 issues).

- [ ] **Task 33.15**: Cross-feature regression and backend tests
  - `flutter test test/features/home test/features/explore test/features/profile test/features/marketplace`.
  - `pnpm test` in `apps/vhunambi_api`.


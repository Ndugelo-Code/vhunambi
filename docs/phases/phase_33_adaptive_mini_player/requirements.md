# Phase 33: Adaptive Mini Player & Expanded Cockpit V4.1 Convergence — Requirements

**Phase:** 33  
**Status:** Approved & Ready for Execution  
**Target:** `apps/vhunambi_client/lib/features/player/` & `apps/vhunambi_client/lib/features/explore/`

---

## 1. Functional Requirements

### Track A: Global MiniPlayerHost Lifecycle & Safe Rendering
- **REQ-AMP-HOST-01**: `MiniPlayerHost` MUST be mounted in `MaterialApp.builder` as a global transparent overlay (`MaterialType.transparency`), persisting across all client routes.
- **REQ-AMP-HOST-02**: `_shouldHide()` MUST NOT hide when `ModalRoute.of(context)` returns `null`. It MUST only hide when:
  1. `ResponsiveUtils.isDesktop(context)` is `true` (Desktop is managed by `DesktopTransportBar`).
  2. `!playerState.hasActiveTrack` is `true` (No active track is loaded).
  3. `controller.isNowPlayingOpen` is `true` (`ExpandedCockpitModal` is already open).
  4. `MediaQuery.of(context).viewInsets.bottom > 0` (Virtual keyboard is visible).
  5. `route?.settings.name` explicitly matches `'/onboarding'`, `'/splash'`, or `'/auth'`.
- **REQ-AMP-HOST-03**: `MiniPlayerHost` MUST be tagged with `Key('mini_player_host')`.
- **REQ-AMP-HOST-04**: Tapping the mini player in any of its 3 forms MUST invoke `ExpandedCockpitModal.show(context)`.

### Track B: Auto-Docking Math & Obstacle Avoidance
- **REQ-AMP-DOCK-01**: When `PlayerMode.auto` is active and `PlayerForm.bar` is selected, `MiniPlayerController` MUST position the bar above the bottom navigation dock:
  - Base Y = `screenSize.height - (VhunambiBottomDockMetrics.navBarHeight + bottomSafeArea + VhunambiBottomDockMetrics.floatingMargin + VhunambiBottomDockMetrics.miniPlayerHeight)`.
  - Horizontal bounds: `left: 8.0, right: 8.0`.
- **REQ-AMP-DOCK-02**: When a `PlayerObstacle` is registered in the dock zone (`obstacle.bottom > screenSize.height - 240`), `MiniPlayerController` MUST elevate the bar 8dp above the highest obstacle:
  - `elevatedY = highestObstacleTop - VhunambiBottomDockMetrics.miniPlayerHeight - 8.0`.
- **REQ-AMP-DOCK-03**: When obstacles change or unregister, position transitions MUST animate smoothly using `_positionController` (200ms duration, `Curves.easeOutCubic`).
- **REQ-AMP-DOCK-04**: `MiniPlayerController.reservedBottom` MUST return `VhunambiBottomDockMetrics.miniPlayerHeight + 8.0` when in `PlayerMode.auto` and `PlayerForm.bar`, and return `0.0` when in `PlayerForm.card` or `PlayerForm.pill`.

### Track C: 3-Form Morphing & Touch Ergonomics
- **REQ-AMP-FORM-01**: `MobileMiniPlayer` (Bar Form) MUST be tagged with `Key('mini_player_bar')`. All interactive controls (previous, play/pause, next) MUST maintain touch targets $\ge 44 \times 44\text{dp}$.
- **REQ-AMP-FORM-02**: `CardForm` MUST be tagged with `Key('mini_player_card')`. It MUST render a 128×128dp square card with genre-themed cover art gradient and a bottom percentage progress pill.
- **REQ-AMP-FORM-03**: `PillForm` MUST be tagged with `Key('mini_player_pill')`. It MUST render a compact 160×48dp frosted island with 32dp circular cover art, play/pause icon, and cover-art reactive glow.
- **REQ-AMP-FORM-04**: Switching forms via `controller.setForm(...)` MUST animate smoothly over 280ms (`Curves.easeInOutCubic`) via `_morphController`.
- **REQ-AMP-FORM-05**: Long-press hold gesture (350ms) MUST enter `PlayerMode.manual` and scale the player to `1.03x` with haptic feedback.
- **REQ-AMP-FORM-06**: Horizontal fling gesture with velocity $> 250\text{ px/s}$ MUST trigger fling dismiss, calling `playerStateNotifier.dismiss()` with haptic feedback.

### Track D: Phase 29 Social Explore Auto-Pill Collapse
- **REQ-AMP-EXPLORE-01**: In `ExploreView`, vertical scrolling in the `ExploreSocialPostCard` feed MUST automatically transition the player into `PlayerForm.pill` so it does not block post captions or actions.
- **REQ-AMP-EXPLORE-02**: Tapping the collapsed `PillForm` in the feed MUST expand the cockpit or restore to `PlayerForm.bar`.
- **REQ-AMP-EXPLORE-03**: Switching away from the Explore tab (e.g. to Home, Library, or Market) MUST restore the player to `PlayerForm.bar`.

### Track E: Expanded Cockpit V4.1 Studio Convergence
- **REQ-AMP-COCKPIT-01**: The waveform visualizer in `ExpandedCockpitModal` MUST sample the 60 Hz `masterRmsBytes` curve from `masterMediaObjectProvider(dna)` to render an authentic 60-bar amplitude waveform.
- **REQ-AMP-COCKPIT-02**: Horizontal drag scrubbing on the waveform visualizer MUST seek playback position smoothly (`notifier.seekByRatio(...)`).
- **REQ-AMP-COCKPIT-03**: `ExpandedCockpitModal` MUST expose a 1-tap `[ 🎚️ Master A/B ]` chip (`Key('cockpit_master_ab_btn')`) in the utility tray that toggles master DSP auditioning.
- **REQ-AMP-COCKPIT-04**: `ExpandedCockpitModal` MUST expose a `[ 🔁 Remix in Studio ]` chip (`Key('cockpit_remix_studio_btn')`) in the utility tray that pre-populates `studioFormProvider` with the active track's genre and prompt and navigates to the Studio tab.

### Track F: Performance & Backward Compatibility
- **REQ-AMP-PERF-01**: `PillForm` amplitude timer MUST pause when `!playerState.isPlaying` and MUST NOT run when `MediaQuery.maybeOf(context)?.disableAnimations == true` (respecting reduce-motion).
- **REQ-AMP-COMPAT-01**: All existing 141 player unit and widget tests MUST continue to pass without regression.
- **REQ-AMP-COMPAT-02**: Static analysis `dart analyze lib test` MUST report 0 issues.


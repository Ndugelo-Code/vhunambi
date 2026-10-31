# Phase 33: Adaptive Mini Player & Expanded Cockpit V4.1 Convergence — Technical Design

**Phase:** 33  
**Status:** Approved & Ready for Execution  
**Target:** `apps/vhunambi_client/lib/features/player/` & `apps/vhunambi_client/lib/features/explore/`

---

## 1. Architecture & Component Hierarchy

```
MaterialApp
└── MaterialApp.builder
    └── Stack
        ├── child (Route tree / RootShell)
        └── MiniPlayerHost (Key: 'mini_player_host')
            └── Material (type: MaterialType.transparency)
                └── AnimatedPositioned (Auto/Manual X & Y)
                    └── GestureDetector (Hold to Drag / Tap to Expand / Fling Dismiss)
                        ├── AnimatedBuilder (_morphController: 280ms)
                        │   ├── BarForm (MobileMiniPlayer, Key: 'mini_player_bar')
                        │   ├── CardForm (Key: 'mini_player_card')
                        │   └── PillForm (Key: 'mini_player_pill')
                        └── Extreme Zone Drag Highlights
```

---

## 2. Component Design & Code Calibrations

### 2.1. `MiniPlayerHost` Overhaul (`mini_player_host.dart`)

#### A. Resolution of the `_shouldHide` Route Trap
```dart
bool _shouldHide(BuildContext context, MiniPlayerController controller, PlayerState playerState) {
  // Hide on desktop (DesktopTransportBar handles desktop layout).
  if (ResponsiveUtils.isDesktop(context)) return true;

  // Hide when no active track.
  if (!playerState.hasActiveTrack) return true;

  // Hide when Now Playing cockpit is already open.
  if (controller.isNowPlayingOpen) return true;

  // Hide when software keyboard is open.
  final viewInsets = MediaQuery.of(context).viewInsets;
  if (viewInsets.bottom > 0) return true;

  // Safe route inspection: only hide if a route actually exists AND is an auth/splash route
  final route = ModalRoute.of(context);
  if (route != null) {
    final routeName = route.settings.name;
    if (routeName == '/onboarding' || routeName == '/splash' || routeName == '/auth') {
      return true;
    }
  }

  return false;
}
```

#### B. Dynamic Layout & Positioning Math
Instead of placing `AnimatedPositioned` at a raw uninitialized `(0, 0)`, `MiniPlayerHost` computes the active position dynamically when in `PlayerMode.auto`:

```dart
Offset _resolveActivePosition({
  required Size screenSize,
  required double bottomSafeArea,
  required MiniPlayerController controller,
}) {
  if (controller.mode == PlayerMode.manual) {
    // Clamped manual user drag coordinates
    return controller.clampedPosition(screenSize, bottomSafeArea);
  }

  // Auto-Mode Positioning based on Form
  switch (controller.form) {
    case PlayerForm.bar:
      // Base docked position: 8dp above bottom navigation bar
      final defaultDockBottom = VhunambiBottomDockMetrics.navBarHeight +
          bottomSafeArea +
          VhunambiBottomDockMetrics.floatingMargin;
      double targetY = screenSize.height - defaultDockBottom - VhunambiBottomDockMetrics.miniPlayerHeight;

      // Obstacle avoidance: if any registered obstacle intersects the bottom area
      final obstacles = controller.obstacles.values.where(
        (rect) => rect.bottom > screenSize.height - 240,
      );
      if (obstacles.isNotEmpty) {
        final highestTop = obstacles.map((o) => o.top).reduce(min);
        targetY = min(targetY, highestTop - VhunambiBottomDockMetrics.miniPlayerHeight - 8.0);
      }

      return Offset(VhunambiBottomDockMetrics.floatingMargin, targetY);

    case PlayerForm.card:
      // Snapped to bottom right edge
      return Offset(
        screenSize.width - 128 - 16,
        screenSize.height - (VhunambiBottomDockMetrics.navBarHeight + bottomSafeArea + 16 + 128),
      );

    case PlayerForm.pill:
      // Floating pill centered horizontally above the dock or top-right in manual
      return Offset(
        (screenSize.width - 160) / 2,
        screenSize.height - (VhunambiBottomDockMetrics.navBarHeight + bottomSafeArea + 12 + 48),
      );
  }
}
```

#### C. Full Cockpit Launch Wiring
```dart
Widget _buildPlayerForm(
  BuildContext context,
  MiniPlayerController controller,
  PlayerState playerState,
) {
  final track = playerState.currentTrack;
  if (track == null) return const SizedBox.shrink();

  void openCockpit() {
    HapticsService().lightImpact();
    ExpandedCockpitModal.show(context);
  }

  switch (controller.form) {
    case PlayerForm.bar:
      return MobileMiniPlayer(
        key: const Key('mini_player_bar'),
        onExpand: openCockpit,
      );
    case PlayerForm.card:
      return CardForm(
        key: const Key('mini_player_card'),
        onExpand: openCockpit,
      );
    case PlayerForm.pill:
      return PillForm(
        key: const Key('mini_player_pill'),
        onExpand: openCockpit,
      );
  }
}
```

---

### 2.2. `MiniPlayerController` Calibrations (`mini_player_controller.dart`)

1. **Obstacle Collision Engine**:
   - `registerObstacle(String id, Rect rect)` and `unregisterObstacle(String id)` notify listeners and update target coordinates.
2. **Safe Clamping**:
   - `clampedPosition(Size screenSize, double bottomSafeArea)` ensures drag gestures never push the mini player off-screen or behind system cutouts.
3. **Reserved Bottom Math**:
   - `reservedBottom`: Returns `VhunambiBottomDockMetrics.miniPlayerHeight + 8.0` in Bar form + Auto mode; returns `0.0` in Pill or Card form.

---

### 2.3. Phase 29 Social Explore Feed Auto-Pill Collapse (`explore_view.dart`)

In `apps/vhunambi_client/lib/features/explore/presentation/views/explore_view.dart`:
```dart
NotificationListener<ScrollNotification>(
  onNotification: (notification) {
    if (notification is ScrollUpdateNotification) {
      if (notification.scrollDelta != null && notification.scrollDelta!.abs() > 2) {
        // Morph to Pill while user scrolls through vertical social reels
        final controller = ref.read(miniPlayerControllerProvider);
        if (controller.form == PlayerForm.bar && controller.mode == PlayerMode.auto) {
          ref.read(miniPlayerControllerProvider.notifier).setForm(PlayerForm.pill);
        }
      }
    }
    return false;
  },
  child: ...,
)
```

In `RootShell._switchTab(int index)` (`lib/main.dart`):
When switching away from Explore (index != 1), if the player is in `PlayerMode.auto` and `PlayerForm.pill`, automatically restore to `PlayerForm.bar`.

---

### 2.4. Expanded Cockpit V4.1 Studio Convergence (`expanded_cockpit_modal.dart`)

#### A. Authentic 60 Hz `masterRmsBytes` Waveform Visualizer
Replace lines 369–387 with dynamic amplitude sampling:
```dart
Widget _buildWaveformVisualizer(
  BuildContext context,
  PlayerState playerState,
  Track track,
  Color accent,
  PlayerNotifier notifier,
) {
  final dna = SongMetadataDna.fromTrackInfo(
    id: track.id,
    title: track.title,
    genre: track.genre,
    language: track.language,
    durationSec: track.duration.inSeconds,
    coverUrl: track.coverUrl,
  );

  final mmo = ref.watch(masterMediaObjectProvider(dna));
  final rmsBytes = mmo.modulationBus.masterRmsBytes;

  return GestureDetector(
    onHorizontalDragUpdate: (details) {
      final box = context.findRenderObject() as RenderBox?;
      if (box != null) {
        final ratio = (details.localPosition.dx / box.size.width).clamp(0.0, 1.0);
        notifier.seekByRatio(ratio);
      }
    },
    child: Container(
      height: 48,
      alignment: Alignment.center,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(60, (index) {
          final barRatio = index / 60.0;
          final isElapsed = barRatio <= playerState.progressRatio;

          // Sample quantized Uint8 amplitude (0..255)
          double amplitude = 0.3;
          if (rmsBytes.isNotEmpty) {
            final sampleIndex = (barRatio * (rmsBytes.length - 1)).toInt().clamp(0, rmsBytes.length - 1);
            amplitude = (rmsBytes[sampleIndex] / 255.0).clamp(0.15, 1.0);
          }

          final barHeight = 8.0 + (amplitude * 36.0);

          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.0),
              height: barHeight,
              decoration: BoxDecoration(
                color: isElapsed ? accent : AppColors.borderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    ),
  );
}
```

#### B. 1-Tap Studio Master A/B & Remix Chips
In the `Track Utility Tray` (`Wrap` children):
1. `[ 🎚️ Master A/B ]` (`Key('cockpit_master_ab_btn')`):
   - Auditions active track with or without Phase 25 mastering DSP.
   - Shows active amber glow when mastering mode is enabled.
2. `[ 🔁 Remix ]` (`Key('cockpit_remix_studio_btn')`):
   - Injects track genre, sample prompt, and tempo into `studioFormProvider`.
   - Closes the modal and navigates to the Studio tab (`_openStudio()`).

---

### 2.5. `PillForm` Performance & Reduce-Motion Hygiene (`pill_form.dart`)

```dart
void _startAmplitudeSampling() {
  _amplitudeTimer?.cancel();
  final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  if (reduceMotion) return; // Completely idle on reduce motion

  _amplitudeTimer = Timer.periodic(
    const Duration(milliseconds: 50), // 20fps is ample for smooth ambient glow
    (_) {
      final isPlaying = ref.read(playerStateProvider).isPlaying;
      if (!isPlaying) return; // Do not calculate math or trigger setState when paused
      _sampleAmplitude();
    },
  );
}
```

---

## 3. Test Guardrails & Verification Matrices

| Test Identifier | Test Case Scope | Target Component |
| :--- | :--- | :--- |
| **TEST-AMP-01** | `MiniPlayerHost` mounts in `MaterialApp.builder` and renders without route trapping | `mini_player_host.dart` |
| **TEST-AMP-02** | Form switching (Bar ➔ Card ➔ Pill) via `MiniPlayerController.setForm` | `mini_player_controller.dart` |
| **TEST-AMP-03** | Obstacle avoidance calculation lifts Bar form 8dp above registered bottom UI | `player_obstacle.dart` |
| **TEST-AMP-04** | Tapping mini player in Bar, Card, and Pill forms opens `ExpandedCockpitModal` | `mini_player_host.dart` |
| **TEST-AMP-05** | Scrolling `ExploreSocialPostCard` list collapses player into `PlayerForm.pill` | `explore_view.dart` |
| **TEST-AMP-06** | `ExpandedCockpitModal` renders 60 Hz `masterRmsBytes` waveform and scrubber | `expanded_cockpit_modal.dart` |
| **TEST-AMP-07** | `[ 🎚️ Master A/B ]` and `[ 🔁 Remix in Studio ]` buttons mount and execute callbacks | `expanded_cockpit_modal.dart` |
| **TEST-AMP-08** | 360×800dp compact mobile viewport layout passes with 0 RenderFlex overflows | All player widgets |


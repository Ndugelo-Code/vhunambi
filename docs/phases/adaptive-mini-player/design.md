# Phase Spec: Adaptive Mini Player & Now Playing Cockpit (`design.md`)

> **Platform:** African AI Music Synthesis & Commercial Licensing Platform (`VHUNAMBI`)  
> **Phase Codename:** Adaptive Mini Player & Now Playing Cockpit (Spec 3 / VH-014 through VH-017)  
> **Status:** 🟡 SPECIFICATION & HANDOFF  
> **Target Apps:** `apps/vhunambi_client`  
> **Target Language:** Dart 3.x / Flutter 3.44+ / Riverpod 2.x  

---

## 1. Domain Models & Immutable Entities

### 1.1 Form, Mode & Direction Enums

```dart
/// Visual representation forms for the Adaptive Mini Player.
enum PlayerForm {
  bar,  // Full-width docked or floating bar
  card, // 128×128dp square floating card
  pill, // 160×48dp minimal capsule with amplitude reactive glow
}

/// Positioning modes for the mini player.
enum PlayerMode {
  auto,   // Automatically avoids registered UI obstacles (studio dock, etc.)
  manual, // User-positioned via hold-drag gesture
}

/// Gesture drag classification directions.
enum DragDirection {
  vertical,
  diagonalUpLeft,
  diagonalUpRight,
  horizontal,
}
```

### 1.2 Persisted Player Form State

```dart
@immutable
class PlayerFormState {
  final PlayerForm form;
  final PlayerMode mode;
  final Offset position;

  const PlayerFormState({
    required this.form,
    required this.mode,
    required this.position,
  });

  PlayerFormState copyWith({
    PlayerForm? form,
    PlayerMode? mode,
    Offset? position,
  }) {
    return PlayerFormState(
      form: form ?? this.form,
      mode: mode ?? this.mode,
      position: position ?? this.position,
    );
  }
}
```

---

## 2. State Management: `MiniPlayerController`

```dart
class MiniPlayerController extends ChangeNotifier {
  static const String keyForm = 'player_form';
  static const String keyMode = 'player_mode';
  static const String keyPosX = 'player_position_x';
  static const String keyPosY = 'player_position_y';

  PlayerForm _form = PlayerForm.bar;
  PlayerMode _mode = PlayerMode.auto;
  Offset _position = Offset.zero;
  final Map<String, Rect> _obstacles = {};
  bool _isDragging = false;
  bool _isNowPlayingOpen = false;

  PlayerForm get form => _form;
  PlayerMode get mode => _mode;
  Offset get position => _position;
  Map<String, Rect> get obstacles => Map.unmodifiable(_obstacles);
  bool get isDragging => _isDragging;
  bool get isNowPlayingOpen => _isNowPlayingOpen;

  double get reservedBottom {
    if (_form != PlayerForm.bar) return 0.0;
    if (_mode == PlayerMode.manual) return 0.0;
    return 68.0 + 8.0; // Standard mini player height + padding
  }

  void setForm(PlayerForm form);
  void setMode(PlayerMode mode);
  void setDragging(bool dragging);
  void setNowPlayingOpen(bool open);
  void registerObstacle(String id, Rect rect);
  void unregisterObstacle(String id);
  void startDrag(Offset globalPosition);
  void updateDrag(Offset globalPosition);
  void endDrag(Offset velocity);
  Future<void> loadState();
  Future<void> _persistState();
}

final miniPlayerControllerProvider =
    ChangeNotifierProvider<MiniPlayerController>((ref) {
  return MiniPlayerController();
});
```

---

## 3. Widget Decomposition & Architecture

### 3.1 `MiniPlayerHost` Global Overlay

- **File:** `lib/features/player/presentation/widgets/mini_player_host.dart`
- **Mount Point:** `MaterialApp.builder` in `lib/main.dart`
- **Key:** `const Key('mini_player_host')`
- **Route Visibility Fix:** Because `MaterialApp.builder` context resides above the navigator, route detection must observe the root navigation observer or listen to route changes rather than checking `ModalRoute.of(context)` directly.
- **Root Element:** `Material(type: MaterialType.transparency, child: ...)`

### 3.2 `MobileMiniPlayer` (Bar Form Enhancement)

- **File:** `lib/features/player/presentation/widgets/mobile_mini_player.dart`
- **Key:** `const Key('mini_player_bar')`
- **Controls & Keys:**
  - Play/Pause: `Key('mini_player_play_pause')` (44×44dp hit area)
  - Previous: `Key('mini_player_prev')` (44×44dp hit area, disabled if at queue start)
  - Next: `Key('mini_player_next')` (44×44dp hit area, disabled if at queue end)
  - Genre Chip: `GenreColorChip` binding from Spec 4

### 3.3 `CardForm` (128×128dp Square Floating Card)

- **File:** `lib/features/player/presentation/widgets/card_form.dart`
- **Key:** `const Key('mini_player_card')`
- **Styling:**
  - Width: 128dp, Height: 128dp
  - Radius: `AppRadius.cardBorder` (12dp)
  - Border: 2px solid `accent.withAlpha(0.3)`
  - Shadow: `BoxShadow(color: accent.withAlpha(0.4), blurRadius: 24, offset: Offset(0, 8))`
  - Snap Bounds: 16dp from left or right screen edge

### 3.4 `PillForm` (160×48dp Glowing Capsule)

- **File:** `lib/features/player/presentation/widgets/pill_form.dart`
- **Key:** `const Key('mini_player_pill')`
- **Styling & Dynamics:**
  - Dimensions: 160dp width × 48dp height
  - Avatar: 32×32dp circular cover art thumbnail
  - Reactive Glow: 30fps amplitude modulation via `PaletteGenerator`
  - Reduce-motion fallback: Static ambient shadow when `AccessibilityService.isReduceMotionEnabled` is true

### 3.5 `PlayerObstacle` (Widget Registry Molecule)

- **File:** `lib/features/player/presentation/widgets/player_obstacle.dart`
- **Usage:**
  ```dart
  PlayerObstacle(
    id: 'content_studio_dock',
    child: ContentStudioDock(...),
  )
  ```

### 3.6 `ExpandedCockpitModal` Hardening

- **File:** `lib/features/player/presentation/widgets/expanded_cockpit_modal.dart`
- **Fixes:**
  1. Material transparency wrapper preventing yellow underlines (`Material(type: MaterialType.transparency)`).
  2. Complete wiring of 12 controls:
     - Repeat mode toggling (`AudioRepeatMode.off` → `all` → `one`)
     - Shuffle toggling
     - Stem mixer invocation
     - System share sheet bridge
     - Like button optimism
  3. Action strip responsive wrapping to eliminate overflow on 360dp mobile viewports.

---

## 4. Responsive Breakpoint Strategy

| Viewport | Bar Form Behavior | Card / Pill Behavior | Transport Placement |
|---|---|---|---|
| **Mobile (< 768px)** | Floats 8dp above obstacle or bottom nav bar | 128dp card snaps left/right; 160dp pill anchors top | Overlaid via `MiniPlayerHost` |
| **Tablet (768–1024px)** | Floats with max-width 640dp centered | Floating anywhere within safe canvas | Overlaid via `MiniPlayerHost` |
| **Desktop (> 1024px)** | Persistent 72px `DesktopTransportBar` at bottom | Card/Pill available via floating gesture | Pinned to bottom DAW console |

---

## 5. Error Recovery & Technical Traps

1. **ModalRoute Lookup in `MaterialApp.builder`:**  
   *Trap:* `ModalRoute.of(context)` returns `null` when invoked in `MaterialApp.builder`.  
   *Mitigation:* Use a `NavigatorObserver` (e.g. `MiniPlayerRouteObserver`) or inspect route state via a Riverpod route provider to determine when onboarding/splash screens are visible.
2. **Animation Timer Leak in `PillForm`:**  
   *Trap:* 30fps `Timer.periodic` or `AnimationController` leaking when unmounted or during widget tests.  
   *Mitigation:* Cancel `_amplitudeTimer` in `dispose()` and check `if (!mounted) return;` before calling `setState()`.
3. **Yellow Underlines on Text:**  
   *Trap:* Text rendered outside a `Scaffold` or without a `Material` ancestor defaults to yellow underline styling.  
   *Mitigation:* Explicit `Material(type: MaterialType.transparency)` wrapping in `MiniPlayerHost` and `ExpandedCockpitModal`.

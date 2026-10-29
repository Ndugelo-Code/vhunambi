# Phase Spec: Adaptive Mini Player & Now Playing Cockpit (`tasks.md`)

> **Platform:** African AI Music Synthesis & Commercial Licensing Platform (`VHUNAMBI`)  
> **Phase Codename:** Adaptive Mini Player & Now Playing Cockpit (Spec 3 / VH-014 through VH-017)  
> **Status:** 🟡 SPECIFICATION & HANDOFF  
> **Target Apps:** `apps/vhunambi_client`  
> **Test Baseline:** 1,030+ tests passing (Zero regressions permitted)  

---

## 1. Pre-Flight Verification Checklist

- [x] **0.1 Baseline Static Analysis**: `flutter analyze` reports 0 issues.
- [x] **0.2 Baseline Test Suites**:
  - `test/features/onboarding/` + `test/features/creator_dna/` = 71/71 passing.
  - `test/core/design_system/` = 39/39 passing.
  - `test/features/studio/` = 196/196 passing.
  - `test/features/player/` = 98/98 passing.
- [ ] **0.3 Architecture Alignment**: Design system tokens from Spec 4 sealed in `main.dart`.

---

## 2. Sequenced Implementation Tracks

### Track A: Core State & Persistence Engine (VH-014)

- [ ] **T1.1 (modify):** Enhance `MiniPlayerController` (`lib/features/player/presentation/providers/mini_player_controller.dart`)
  - Ensure safe default initial coordinates clamped within safe area.
  - Implement rotation-safe fraction calculation (`_positionToScreenFraction()`).
  - Add `loadState()` and `_persistState()` with graceful error handling.
  - Add explicit getters: `form`, `mode`, `position`, `reservedBottom`, `isDragging`, `isNowPlayingOpen`.
- [ ] **T1.2 (new):** Unit test suite for controller (`test/features/player/mini_player_controller_test.dart`)
  - Test initial values match defaults.
  - Test `setForm` and `setMode` trigger notifications and persist.
  - Test `registerObstacle` recalculates auto position and updates `reservedBottom`.

---

### Track B: Global Host & Overlay Architecture (VH-014, VH-015)

- [ ] **T2.1 (modify):** Route-aware `MiniPlayerHost` (`lib/features/player/presentation/widgets/mini_player_host.dart`)
  - Replace broken `ModalRoute.of(context)` check with a safe `NavigatorObserver` or Riverpod route provider to detect `/splash`, `/onboarding`, `/auth`.
  - Wrap root in `Material(type: MaterialType.transparency)` with `key: const Key('mini_player_host')`.
  - Ensure player unmounts/hides when `viewInsets.bottom > 0` (keyboard open).
- [ ] **T2.2 (modify):** `lib/main.dart` clean-up
  - Ensure `MiniPlayerHost` overlay is mounted in `MaterialApp.builder`.
  - Coordinate with `RootShell` so `MobileMiniPlayer` does not render twice.

---

### Track C: The Three Player Forms (VH-014, VH-015)

- [ ] **T3.1 (modify):** `MobileMiniPlayer` (`lib/features/player/presentation/widgets/mobile_mini_player.dart`)
  - Bind `Key('mini_player_bar')`.
  - Ensure 44×44dp touch targets on play/pause, prev, next.
  - Disable prev/next with opacity 0.38 at queue boundaries when repeat is off.
  - Display genre accent from `VhunambiThemeExtension.of(context)`.
- [ ] **T3.2 (new/modify):** `CardForm` (`lib/features/player/presentation/widgets/card_form.dart`)
  - Bind `Key('mini_player_card')`.
  - 128×128dp square container with `AppRadius.cardBorder` (12dp).
  - Snap to left or right margin (16dp inset) on drag release.
  - Tap expands Now Playing cockpit.
- [ ] **T3.3 (new/modify):** `PillForm` (`lib/features/player/presentation/widgets/pill_form.dart`)
  - Bind `Key('mini_player_pill')`.
  - 160×48dp capsule layout with 32dp circular avatar.
  - Dynamic 30fps amplitude glow with `PaletteGenerator`.
  - Respect `AccessibilityService.isReduceMotionEnabled`: fallback to static ambient shadow.
  - Cancel `Timer.periodic` safely in `dispose()` to prevent fake timer leaks.

---

### Track D: Gestures & Obstacle Avoidance (VH-014)

- [ ] **T4.1 (new):** `PlayerObstacle` widget (`lib/features/player/presentation/widgets/player_obstacle.dart`)
  - Measure rendered `Rect` via `addPostFrameCallback` and register with `MiniPlayerController`.
  - Unregister on widget disposal.
- [ ] **T4.2 (modify):** Gesture handling in `MiniPlayerHost`
  - Hold gesture (350ms) triggers `HapticsService.mediumImpact()`, scale 1.03, manual mode.
  - Drag direction classification (vertical vs. diagonal ↖ / ↗).
  - Extreme zone detection:
    - Top 72dp zone: morphs to `PillForm`.
    - Bottom 120dp zone: returns to `BarForm` & auto mode.
  - Horizontal fling dismiss (velocity > 250 px/s): 180ms slide animation, stop audio, clear track.

---

### Track E: Now Playing Cockpit Hardening (VH-016, VH-017)

- [ ] **T5.1 (modify):** `ExpandedCockpitModal` (`lib/features/player/presentation/widgets/expanded_cockpit_modal.dart`)
  - Root wrapped in `Material(type: MaterialType.transparency)` to eliminate yellow underlines.
  - Wire all 12 controls:
    - Repeat button toggles `AudioRepeatMode.off` → `all` → `one`.
    - Shuffle button toggles queue shuffle.
    - Stem mixer opens `StemMixerDeck`.
    - Share button triggers native share sheet.
    - Lyrics toggle swaps hero artwork with `LyricsTeleprompter`.
  - Resolve horizontal action row overflow on 360dp mobile viewports.

---

### Track F: Automated Test Suites & Verification Gates

- [ ] **T6.1 (new):** `test/features/player/widgets/mini_player_host_test.dart`
  - Verify host renders transparent Material wrapper.
  - Verify host switches between Bar, Card, and Pill forms based on controller.
- [ ] **T6.2 (new):** `test/features/player/widgets/pill_form_test.dart`
  - Verify 30fps glow runs without timer leaks.
  - Verify reduce-motion renders static shadow.
- [ ] **T6.3 (modify):** `test/features/player/widgets/expanded_cockpit_modal_test.dart`
  - Verify zero yellow underlines.
  - Verify repeat, shuffle, and share button interactions.
- [ ] **T6.4 (gate):** Run full test suite & analyzer gate:
  ```powershell
  cd apps/vhunambi_client
  flutter analyze
  flutter test test/features/player/
  ```

---

## 3. Known Traps & Mitigations Matrix

| Trap ID | Symptom / Error | Root Cause | Mandatory Mitigation |
|---|---|---|---|
| **TRAP-AMP-01** | `ModalRoute.of(context) == null` | Context inside `MaterialApp.builder` is above the Navigator | Use a navigation observer or app route provider to check current screen |
| **TRAP-AMP-02** | Yellow underlines on text | Text rendered without a `Material` ancestor | Wrap root of `MiniPlayerHost` and `ExpandedCockpitModal` in `Material(type: MaterialType.transparency)` |
| **TRAP-AMP-03** | `A Timer is still pending` in tests | Uncancelled 30fps periodic timer in `PillForm` | Store `Timer? _amplitudeTimer`, cancel in `dispose()`, and use deterministic mock in tests |
| **TRAP-AMP-04** | Dual player rendering | `MobileMiniPlayer` rendered in `RootShell` AND `MiniPlayerHost` | Let `MiniPlayerHost` be the single authority for mobile mini player rendering |
| **TRAP-AMP-05** | Enum collision with Flutter 3.44 | `RepeatMode` collision with Flutter SDK | Strictly use `AudioRepeatMode` (`off`, `all`, `one`), never `RepeatMode` |

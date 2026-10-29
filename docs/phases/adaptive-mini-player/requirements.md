# Phase Spec: Adaptive Mini Player & Now Playing Cockpit (`requirements.md`)

> **Platform:** African AI Music Synthesis & Commercial Licensing Platform (`VHUNAMBI`)  
> **Phase Codename:** Adaptive Mini Player & Now Playing Cockpit (Spec 3 / VH-014 through VH-017)  
> **Status:** 🟡 SPECIFICATION & HANDOFF  
> **Standard:** RFC 2119 & EARS (Easy Approach to Requirements Syntax)  
> **Target Apps:** `apps/vhunambi_client`  

---

## 1. Traceable Requirements Inventory

### 1.1 Global Player Architecture & Overlay Mount (REQ-AMP-ARCH)

- **REQ-AMP-ARCH-01 (Ubiquitous):**  
  The system SHALL instantiate `MiniPlayerHost` exactly once via `MaterialApp.builder` Stack overlay, ensuring the player persists across all route navigation without unmounting.
- **REQ-AMP-ARCH-02 (State-Driven):**  
  WHILE the active route is `/splash`, `/onboarding`, `/auth`, OR the full-screen `ExpandedCockpitModal` is open, the system SHALL hide `MiniPlayerHost` (`SizedBox.shrink()`).
- **REQ-AMP-ARCH-03 (State-Driven):**  
  WHILE no active track is loaded (`playerState.hasActiveTrack == false`), the system SHALL hide `MiniPlayerHost`.
- **REQ-AMP-ARCH-04 (Event-Driven):**  
  WHEN the software keyboard opens (`MediaQuery.viewInsets.bottom > 0`), the system SHALL immediately hide the mini player to prevent occlusion of text fields.
- **REQ-AMP-ARCH-05 (Ubiquitous):**  
  The root container of `MiniPlayerHost` and `ExpandedCockpitModal` MUST be wrapped in `Material(type: MaterialType.transparency)` to eliminate Flutter yellow underline artifacts.

---

### 1.2 Auto-Mode Obstacle Avoidance (REQ-AMP-AUTO)

- **REQ-AMP-AUTO-01 (State-Driven):**  
  WHILE `PlayerMode.auto` is active AND `PlayerForm.bar` is displayed, the system SHALL position the bar 8dp above the highest registered `PlayerObstacle` that intersects the bottom dock area.
- **REQ-AMP-AUTO-02 (Event-Driven):**  
  WHEN any widget wrapped in `PlayerObstacle` is mounted, the widget SHALL register its global bounding `Rect` with `MiniPlayerController`.
- **REQ-AMP-AUTO-03 (Event-Driven):**  
  WHEN a `PlayerObstacle` widget is disposed, the widget SHALL unregister its ID from `MiniPlayerController`.
- **REQ-AMP-AUTO-04 (Event-Driven):**  
  WHEN obstacle registrations change, the system SHALL animate the bar to its newly calculated position over 200ms using `Curves.easeOutCubic`.
- **REQ-AMP-AUTO-05 (Ubiquitous):**  
  `MiniPlayerController.reservedBottom` SHALL return `barHeight + 8dp` WHILE `PlayerForm.bar` is visible in `PlayerMode.auto`, and return `0.0` when in `CardForm`, `PillForm`, or hidden.

---

### 1.3 Bar Form Transport Controls (REQ-AMP-BAR)

- **REQ-AMP-BAR-01 (Ubiquitous):**  
  `BarForm` SHALL display full viewport width minus safe-area horizontal insets, featuring cover artwork, title, artist, genre color chip, progress line, and transport buttons.
- **REQ-AMP-BAR-02 (Event-Driven):**  
  WHEN the user taps the `BarForm` body (excluding control buttons), the system SHALL open `ExpandedCockpitModal`.
- **REQ-AMP-BAR-03 (Event-Driven):**  
  WHEN the user taps the previous button, the system SHALL restart the current track IF playback position exceeds 3 seconds, ELSE skip to the previous track in the queue.
- **REQ-AMP-BAR-04 (State-Driven):**  
  WHILE the current track is first in the queue AND repeat mode is `AudioRepeatMode.off`, the previous button SHALL be visually disabled with opacity 0.38 and non-interactive.
- **REQ-AMP-BAR-05 (Event-Driven):**  
  WHEN the user taps the play/pause button, the system SHALL toggle playback state, emit medium haptic impact, and update the icon within 100ms.
- **REQ-AMP-BAR-06 (Ubiquitous):**  
  All interactive controls in `BarForm` MUST provide a minimum touch bounding box of 44×44dp.

---

### 1.4 Card Form Geometry & Gestures (REQ-AMP-CARD)

- **REQ-AMP-CARD-01 (Ubiquitous):**  
  `CardForm` SHALL render as a 128×128dp square floating card with `AppRadius.cardBorder` (12dp), genre gradient background, and a glowing border derived from `VhunambiThemeExtension.genreAccent`.
- **REQ-AMP-CARD-02 (Event-Driven):**  
  WHEN dragging a `CardForm` horizontally, the card SHALL snap to either the left or right margin (16dp inset from safe-area edge) upon gesture release.
- **REQ-AMP-CARD-03 (Event-Driven):**  
  WHEN the user taps the `CardForm`, the system SHALL open `ExpandedCockpitModal`.
- **REQ-AMP-CARD-04 (Ubiquitous):**  
  `CardForm` SHALL display a circular or arc progress overlay indicating elapsed percentage.

---

### 1.5 Pill Form & Cover-Art Reactive Glow (REQ-AMP-PILL)

- **REQ-AMP-PILL-01 (Ubiquitous):**  
  `PillForm` SHALL render as a 160×48dp capsule with a 32dp circular cover thumbnail and a play/pause trigger.
- **REQ-AMP-PILL-02 (State-Driven):**  
  WHILE audio is playing, the system SHALL sample simulated waveform amplitude at 30fps and modulate the surrounding glow blur (8dp to 24dp) and opacity (0.2 to 0.7).
- **REQ-AMP-PILL-03 (State-Driven):**  
  WHILE audio is paused, the system SHALL display a gentle 1000ms breathing animation instead of 30fps amplitude modulation.
- **REQ-AMP-PILL-04 (State-Driven):**  
  WHILE `AccessibilityService.isReduceMotionEnabled` is true, the system SHALL disable dynamic glow pulsing and render a static ambient shadow.

---

### 1.6 Gesture System & Form Morphing (REQ-AMP-GEST)

- **REQ-AMP-GEST-01 (Event-Driven):**  
  WHEN the user holds any player form for 350ms, the system SHALL emit `HapticsService.mediumImpact()`, scale the form to 1.03, and activate manual positioning mode.
- **REQ-AMP-GEST-02 (Event-Driven):**  
  WHEN dragging diagonally upward (angle between 25° and 65°), the system SHALL morph the form between `BarForm` and `CardForm` over 280ms.
- **REQ-AMP-GEST-03 (Event-Driven):**  
  WHEN dragging into the Top Extreme Zone (within 72dp of top safe area), the system SHALL emit heavy haptics and morph the player into `PillForm`.
- **REQ-AMP-GEST-04 (Event-Driven):**  
  WHEN dragging into the Bottom Extreme Zone (within 120dp of bottom screen edge), the system SHALL emit medium haptics, return the player to `BarForm`, and re-engage `PlayerMode.auto`.
- **REQ-AMP-GEST-05 (Event-Driven):**  
  WHEN a horizontal fling gesture exceeds 250 px/s velocity, the system SHALL animate the player off-screen in the fling direction over 180ms, stop playback, and clear the active track.

---

### 1.7 State Persistence (REQ-AMP-PERSIST)

- **REQ-AMP-PERSIST-01 (Event-Driven):**  
  WHEN form, mode, or position changes, the system SHALL persist the updated state to `SharedPreferences` (`player_form`, `player_mode`, `player_position_x`, `player_position_y`).
- **REQ-AMP-PERSIST-02 (Event-Driven):**  
  WHEN the application launches, `MiniPlayerController` SHALL asynchronously restore the persisted form, mode, and position, clamping position to safe-area bounds.

---

### 1.8 Now Playing Cockpit Hardening (REQ-AMP-NOWP)

- **REQ-AMP-NOWP-01 (Ubiquitous):**  
  `ExpandedCockpitModal` MUST NOT exhibit yellow underline text artifacts, guaranteed by an internal `Material(type: MaterialType.transparency)` wrapper.
- **REQ-AMP-NOWP-02 (Ubiquitous):**  
  All 12 Now Playing controls (Dismiss, Options, Artwork Hero, Lyrics Toggle, Title, Artist, Like, Share, Scrubber, Repeat, Shuffle, Stem Mixer) MUST be wired to functioning actions or providers.
- **REQ-AMP-NOWP-03 (Ubiquitous):**  
  The secondary action strip (Share, Stems, Details, More) MUST NOT overflow on 360dp mobile viewports, using a wrapping row or scrollable horizontal strip with 44×44dp touch targets.

---

## 2. Requirements Traceability Matrix

| Requirement ID | Target File | Test Suite | Verification Command |
|---|---|---|---|
| `REQ-AMP-ARCH-01..05` | `lib/main.dart`, `mini_player_host.dart` | `mini_player_host_test.dart` | `flutter test test/features/player/widgets/mini_player_host_test.dart` |
| `REQ-AMP-AUTO-01..05` | `mini_player_controller.dart`, `player_obstacle.dart` | `mini_player_controller_test.dart` | `flutter test test/features/player/mini_player_controller_test.dart` |
| `REQ-AMP-BAR-01..06` | `mobile_mini_player.dart` | `mobile_mini_player_test.dart` | `flutter test test/features/player/widgets/mobile_mini_player_test.dart` |
| `REQ-AMP-CARD-01..04` | `card_form.dart` | `card_form_test.dart` | `flutter test test/features/player/widgets/card_form_test.dart` |
| `REQ-AMP-PILL-01..04` | `pill_form.dart` | `pill_form_test.dart` | `flutter test test/features/player/widgets/pill_form_test.dart` |
| `REQ-AMP-GEST-01..05` | `mini_player_host.dart`, `mini_player_controller.dart` | `mini_player_gesture_test.dart` | `flutter test test/features/player/widgets/mini_player_gesture_test.dart` |
| `REQ-AMP-PERSIST-01..02` | `mini_player_controller.dart` | `mini_player_controller_test.dart` | `flutter test test/features/player/mini_player_controller_test.dart` |
| `REQ-AMP-NOWP-01..03` | `expanded_cockpit_modal.dart` | `expanded_cockpit_modal_test.dart` | `flutter test test/features/player/widgets/expanded_cockpit_modal_test.dart` |

# Phase 42 Requirements: Cockpit Hardware Player Studio Bridge

## Track A: Player-to-Studio Navigation Bridge
- **REQ-BRIDGE-NAV-01**: `RootShellState` must listen to `appNavigationTabProvider` and execute `_switchTab(next)` whenever its value changes.
- **REQ-BRIDGE-REMIX-02**: Tapping `[ 🎛️ Remix in Studio ]` (`Key('cockpit_remix_in_studio_btn')`) in `ExpandedCockpitModal` must:
  - Populate `studioFormProvider` with the active track's genre and prompt.
  - Set `appNavigationTabProvider` to `2` (Studio Cockpit).
  - Dismiss the modal sheet.
  - Add a receipt notification to `notificationsProvider`.

## Track B: Illuminated Hardware LED Indicator
- **REQ-LED-TOGGLE-01**: Tapping `A/B Bypass` in `ExpandedCockpitModal` must update `masteringSessionProvider` and toggle the on-deck illuminated LED indicator (`Key('cockpit_dsp_led_indicator')`) without emitting disruptive SnackBars.
- **REQ-LED-UI-02**: The LED indicator must visually distinguish active state (`isMasteredPreviewActive == true`) with high-contrast emerald/primary glow, and bypassed state with muted slate styling.

## Track C: Quality & Verification
- **REQ-VERIF-01**: Test suite `test/features/player/phase42_cockpit_studio_bridge_test.dart` passes 100%.
- **REQ-VERIF-02**: Full static analysis reports 0 issues.


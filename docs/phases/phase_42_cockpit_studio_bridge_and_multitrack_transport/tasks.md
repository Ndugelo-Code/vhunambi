# Phase 42 Tasks: Cockpit Hardware Player Studio Bridge

- [ ] **Track A: Navigation & Shell Synchronization**
  - [ ] **T-A1**: Bind `appNavigationTabProvider` in `_RootShellState` in `lib/main.dart`.
  - [ ] **T-A2**: Update `_remixInStudio` in `expanded_cockpit_modal.dart` to set `appNavigationTabProvider` to 2 and add receipt notification.

- [ ] **Track B: Hardware Illuminated LED Toggles**
  - [ ] **T-B1**: Mount `Key('cockpit_dsp_led_indicator')` in `expanded_cockpit_modal.dart` faceplate.
  - [ ] **T-B2**: Refactor `_toggleMasterAB` to avoid disruptive SnackBars.

- [ ] **Track C: Verification & Quality**
  - [ ] **T-C1**: Author and pass `test/features/player/phase42_cockpit_studio_bridge_test.dart`.
  - [ ] **T-C2**: Run `dart analyze lib test` → 0 issues.


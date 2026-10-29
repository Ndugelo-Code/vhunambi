# Studio Cockpit Bugs & UX Fixes — Implementation Tasks

## Overview

This document specifies the implementation tasks for fixing 6 critical defects (VH-001 through VH-006) in the Studio AI Cockpit and Persistent Audio Player. These defects affect revenue generation, user privacy, screen real estate efficiency, accessibility compliance, and brand identity.

**Feature Name:** `studio-cockpit-fixes`

**Spec ID:** `b93e9741-089f-4d15-8075-44d97ae47805`

**Workflow:** Bugfix Requirements-First

**Target Platform:** Flutter 3.44+ / Dart 3.x / Riverpod 2.x

**Test Baseline:** 991 passing tests (must remain green)

---

## Pre-Flight Checklist

- [ ] 0.1 Verify development environment
  - Flutter version ≥ 3.44
  - Dart version ≥ 3.x
  - All dependencies up to date (`flutter pub get`)
  - _Verification: `flutter --version`, `flutter doctor`_

- [ ] 0.2 Establish baseline test status
  - Run full test suite: `flutter test`
  - Confirm 991 tests passing
  - Document any pre-existing failures
  - _Verification: All tests green before starting_

- [ ] 0.3 Run static analysis baseline
  - Execute: `flutter analyze`
  - Confirm 0 errors, 0 warnings
  - _Verification: Clean analyzer output_

- [ ] 0.4 Create feature branch
  - Branch name: `fix/studio-cockpit-bugs-vh001-vh006`
  - Base: `main` or current development branch
  - _Verification: Git branch created_

- [ ] 0.5 Review design documents
  - Read `bugfix.md` (requirements)
  - Read `design.md` (technical design)
  - Understand bug conditions and properties
  - _Verification: Team alignment on approach_

---

# Implementation Plan:

This bugfix follows the **Bug Condition Methodology** with a phased approach designed to validate bugs before fixing them:

### Approach Overview

1. **Explore First**: Write property-based tests that encode expected behavior BEFORE implementing fixes. These tests will fail on unfixed code, confirming the bugs exist.
2. **Preserve Existing Behavior**: Write preservation tests to ensure non-buggy functionality remains unchanged.
3. **Implement Fixes**: Apply targeted fixes to each bug condition.
4. **Validate**: Confirm exploration tests now pass (bug fixed) and preservation tests still pass (no regressions).

### Phase Breakdown

**Phase 1: Bug Condition Exploration Tests (Tasks 1-6)**
- Write property-based tests for all 6 bugs
- Run tests on UNFIXED code to confirm bugs exist
- Document counterexamples found
- Duration: 1-2 days

**Phase 2: Preservation Property Tests (Task 7)**
- Write tests to capture existing behavior that must not break
- Run tests on UNFIXED code to establish baseline
- Duration: 1 day

**Phase 3: Implementation (Tasks 8-19)**
- Fix each bug with targeted changes
- Verify exploration tests now pass
- Verify preservation tests still pass
- Can be parallelized: VH-001, VH-003, VH-004, VH-006 independent
- VH-005 depends on VH-002 (visibility field)
- Duration: 7-10 days

**Phase 4: Cross-Cutting Tasks (Tasks 20-24)**
- Analytics integration
- Design system updates
- Documentation
- Duration: 2-3 days

**Phase 5: Final Integration & Testing (Tasks 25-35)**
- Full test suite validation
- Manual testing across viewports and font scales
- Accessibility audit
- Performance profiling
- Duration: 3-4 days

### Critical Path

```
Pre-Flight → Exploration Tests → Preservation Tests → VH-002 Implementation → VH-005 Implementation → Cross-Cutting → Final Testing
```

The critical path runs through VH-002 (visibility toggle) because VH-005 (progress tracker) derives slot states from the updated visibility field. All other bugs can be fixed in parallel.

### Risk Mitigation Strategy

**Breaking Changes (RISK-BC-01, RISK-BC-02)**
- Use 3-phase migration for `isPublic` → `visibility` field
- Legal review of ToS notice removal before implementing VH-003

**Privacy Compliance (RISK-PL-01, RISK-PL-02)**
- Privacy impact assessment for default visibility setting
- Document consent mechanism for legal approval

**Performance (RISK-PF-01, RISK-PF-02)**
- Profile progress tracker updates at 60fps
- Test gesture recognition on mid-range devices
- Use RepaintBoundary and const constructors

**Accessibility (RISK-AC-01, RISK-AC-02)**
- Provide button alternative to swipe gestures
- Ensure 44×44px touch targets at 200% font scale
- Test with VoiceOver and TalkBack

### Success Criteria

- ✅ All 991 baseline tests remain passing
- ✅ All 32 new tests passing (exploration + preservation)
- ✅ Zero analyzer errors/warnings
- ✅ All 6 bugs validated against acceptance criteria
- ✅ Manual testing complete across viewports (360dp-768dp) and font scales (100%-200%)
- ✅ Accessibility audit passed (WCAG 2.1 Level AA minimum)
- ✅ Performance profiling passed (60fps, <16ms updates)

---

## Tasks

### Phase 1: Bug Condition Exploration Tests

| Task ID | Description | File | Requirements |
|---------|-------------|------|--------------|
| 1 | Write VH-001 bug exploration test (mini player dismissal) | `mobile_mini_player_dismiss_exploration_test.dart` | 1.1, 1.2, 1.3, 2.1, 2.2 |
| 2 | Write VH-002 bug exploration test (visibility toggle) | `studio_form_visibility_exploration_test.dart` | 1.4, 1.5, 1.6, 2.5, 2.6 |
| 3 | Write VH-003 bug exploration test (description text space) | `studio_action_bar_height_exploration_test.dart` | 1.7, 1.8, 1.9, 2.14, 2.15 |
| 4 | Write VH-004 bug exploration test (CTA overflow) | `onboarding_cta_overflow_exploration_test.dart` | 1.10, 1.11, 1.12, 2.16, 2.17 |
| 5 | Write VH-005 bug exploration test (no progress tracker) | `progress_tracker_missing_exploration_test.dart` | 1.13, 1.14, 1.15, 2.20, 2.21 |
| 6 | Write VH-006 bug exploration test (generic branding) | `vhunambi_app_bar_branding_exploration_test.dart` | 1.16, 1.17, 1.18, 2.29, 2.30 |

### Phase 2: Preservation Property Tests

| Task ID | Description | File | Requirements |
|---------|-------------|------|--------------|
| 7 | Write preservation tests for all 6 bugs | Multiple test files | 3.1-3.19 |

### Phase 3: Implementation

**VH-001: Mini Player Dismiss Control (Tasks 8-9)**

| Task ID | Description | File | Requirements |
|---------|-------------|------|--------------|
| 8.1 | Add close button to mini player | `mobile_mini_player.dart` | 2.1, 2.2, REQ-A11Y-01 |
| 8.2 | Implement swipe-down dismiss gesture | `mobile_mini_player.dart` | 2.1, 2.2, REQ-A11Y-02 |
| 8.3 | Add keyboard visibility detection | `mobile_mini_player.dart` | 2.4, REQ-RWD-03 |
| 8.4 | Implement player removal animation | Parent scaffold | 2.2 |
| 8.5 | Verify PlayerNotifier.dismiss() implementation | `player_provider.dart` | 2.1, 2.2, 2.3 |
| 8.6 | Verify exploration test passes | Test file | Expected Behavior |
| 8.7 | Verify preservation tests pass | Test file | Preservation |

**VH-002: Visibility Toggle Functionality (Tasks 10-11)**

| Task ID | Description | File | Requirements |
|---------|-------------|------|--------------|
| 10.1 | Add visibility field to StudioFormState | `studio_form_state.dart` | 2.5, 2.6, REQ-STM-02, REQ-STM-03 |
| 10.2 | Add setVisibility() method to notifier | `studio_form_provider.dart` | 2.5, 2.6, REQ-STM-04 |
| 10.3 | Update StudioActionBar toggle binding | `studio_action_bar.dart` | 2.5, 2.6 |
| 10.4 | Implement dynamic icon, title, subtitle | `studio_action_bar.dart` | 2.10 |
| 10.5 | Add visibility to generation request | `generation_request.dart` | 2.5-2.8 |
| 10.6 | Preserve visibility across lyrics flow | `studio_form_provider.dart` | 2.9, REQ-STM-05 |
| 10.7 | Verify exploration test passes | Test file | Expected Behavior |
| 10.8 | Verify preservation tests pass | Test file | Preservation |

**VH-003: Description Text Removal (Tasks 12-13)**

| Task ID | Description | File | Requirements |
|---------|-------------|------|--------------|
| 12.1 | Remove explanation paragraph | `studio_action_bar.dart` | 2.11, 2.15 |
| 12.2 | Evaluate and implement ToS strategy | `studio_action_bar.dart` or modal | 2.12, 2.13, RISK-BC-02 |
| 12.3 | Update action bar layout constraints | `studio_action_bar.dart` | 2.14, 2.15 |
| 12.4 | Verify viewport visibility at 360×640dp | Test file | 2.14 |
| 12.5 | Verify exploration test passes | Test file | Expected Behavior |
| 12.6 | Verify preservation tests pass | Test file | Preservation |

**VH-004: DNA CTA Responsive Layout (Tasks 14-15)**

| Task ID | Description | File | Requirements |
|---------|-------------|------|--------------|
| 14.1 | Wrap CTA button in flexible container | `onboarding_view.dart` | 2.16, 2.17 |
| 14.2 | Implement max width calculation | `onboarding_view.dart` | 2.17 |
| 14.3 | Add FittedBox for text scaling | `onboarding_view.dart` | 2.18, REQ-A11Y-04 |
| 14.4 | Test at multiple viewports and font scales | Test file | 2.16-2.19, REQ-RWD-01 |
| 14.5 | Verify exploration test passes | Test file | Expected Behavior |
| 14.6 | Verify preservation tests pass | Test file | Preservation |

**VH-005: Real-Time Progress Tracker (Tasks 16-17)**

| Task ID | Description | File | Requirements |
|---------|-------------|------|--------------|
| 16.1 | Create ProgressTrackerState model | `progress_tracker_state.dart` (new) | 2.20-2.23 |
| 16.2 | Implement fromStudioForm() derivation | `progress_tracker_state.dart` | 2.21-2.23, REQ-STM-01 |
| 16.3 | Create progressTrackerProvider | `progress_tracker_provider.dart` (new) | 2.20, REQ-STM-01 |
| 16.4 | Build StudioProgressTracker widget (collapsed) | `studio_progress_tracker.dart` (new) | 2.27 |
| 16.5 | Build expanded slot list view | `studio_progress_tracker.dart` | 2.28 |
| 16.6 | Implement tap-to-scroll navigation | `studio_view.dart` | 2.24 |
| 16.7 | Add haptic feedback on slot changes | `studio_progress_tracker.dart` | 2.21, REQ-A11Y-05 |
| 16.8 | Add progress tracker to cockpit layout | `studio_view.dart` | 2.20, 2.27 |
| 16.9 | Verify exploration test passes | Test file | Expected Behavior |
| 16.10 | Verify preservation tests pass | Test file | Preservation |

**VH-006: Studio Branding (Tasks 18-19)**

| Task ID | Description | File | Requirements |
|---------|-------------|------|--------------|
| 18.1 | Create logo assets (SVG, PNG, launcher icons) | `assets/branding/` (new) | 2.29-2.34 |
| 18.2 | Add asset paths to AppAssets | `app_assets.dart` | 2.29 |
| 18.3 | Update pubspec.yaml for assets | `pubspec.yaml` | 2.29 |
| 18.4 | Update VhunambiAppBar to use logo | `vhunambi_app_bar.dart` | 2.29, 2.30 |
| 18.5 | Test light/dark mode variants | Test file | 2.30 |
| 18.6 | Verify horizontal clearance | Test file | 2.29 |
| 18.7 | Verify exploration test passes | Test file | Expected Behavior |
| 18.8 | Verify preservation tests pass | Test file | Preservation |

### Phase 4: Cross-Cutting Tasks

| Task ID | Description | File | Requirements |
|---------|-------------|------|--------------|
| 20.1 | Add studio_player_dismissed event | `mobile_mini_player.dart` | REQ-ANL-01 |
| 20.2 | Add studio_visibility_toggled event | `studio_action_bar.dart` | REQ-ANL-02 |
| 20.3 | Add studio_progress_slot_tapped event | `studio_progress_tracker.dart` | REQ-ANL-03 |
| 20.4 | Add studio_cta_overflow_detected event | `onboarding_view.dart` | REQ-ANL-04 |
| 21.1 | Audit AppColors for missing tokens | `app_colors.dart` | REQ-DST-01 |
| 21.2 | Audit AppSpacing for missing tokens | `app_spacing.dart` | REQ-DST-02 |
| 21.3 | Audit AppTypography for missing styles | `app_typography.dart` | REQ-DST-03 |
| 21.4 | Audit AppRadius for missing values | `app_radius.dart` | REQ-DST-04 |
| 22 | Create migration guide for visibility field | `docs/migration/` (new) | RISK-BC-01 |
| 23 | Configure SVG asset loading | `pubspec.yaml`, widgets | 2.29, 2.30 |
| 24 | Ensure haptics respect system settings | All widgets with HapticFeedback | REQ-A11Y-05 |

### Phase 5: Final Integration & Testing

| Task ID | Description | Requirements |
|---------|-------------|--------------|
| 25 | Run complete test suite (991+ tests) | Zero failures |
| 26 | Run static analysis (flutter analyze) | Zero errors/warnings |
| 27.1-27.4 | Test on multiple viewport sizes | REQ-RWD-01, REQ-RWD-02 |
| 28.1-28.3 | Test at multiple font scales | REQ-A11Y-04 |
| 29.1-29.5 | Test complete user flows | All acceptance criteria |
| 30 | Visual regression testing for logo | 2.30 |
| 31.1-31.2 | Performance profiling | REQ-PF-01, RISK-PF-02 |
| 32.1-32.3 | Accessibility audit | REQ-A11Y-01-05 |
| 33 | Privacy impact assessment | RISK-PL-01 |
| 34 | Legal review of ToS strategy | RISK-PL-02 |
| 35.1-35.6 | Verify all acceptance criteria | Final validation |

---

## Phase 1: Bug Condition Exploration Tests (BEFORE Implementation)

These tests MUST be written and run on the UNFIXED code to confirm the bugs exist.

### VH-001: Bug Condition Exploration Test

- [ ] 1. Write bug condition exploration test
  - **Property 1: Bug Condition** - Mini Player Cannot Be Dismissed
  - **CRITICAL**: This test MUST FAIL on unfixed code - failure confirms the bug exists
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: This test encodes the expected behavior - it will validate the fix when it passes after implementation
  - **GOAL**: Surface counterexamples that demonstrate the bug exists
  - **Test Details**:
    - Test that mini player remains visible when `hasActiveTrack == true` AND no dismiss control exists
    - Test that mini player consumes ~90px space permanently
    - Test that mini player overlaps keyboard when `viewInsets.bottom > 0`
  - **File**: `test/features/player/presentation/widgets/mobile_mini_player_dismiss_exploration_test.dart`
  - Run test on UNFIXED code
  - **EXPECTED OUTCOME**: Test FAILS (this is correct - it proves the bug exists)
  - Document counterexamples found (e.g., "Player with active track cannot be dismissed, consumes 90px permanently")
  - Mark task complete when test is written, run, and failure is documented
  - _Requirements: 1.1, 1.2, 1.3, 2.1, 2.2_

### VH-002: Bug Condition Exploration Test

- [ ] 2. Write bug condition exploration test
  - **Property 1: Bug Condition** - Visibility Toggle Non-Functional
  - **CRITICAL**: This test MUST FAIL on unfixed code - failure confirms the bug exists
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: This test encodes the expected behavior - it will validate the fix when it passes after implementation
  - **GOAL**: Surface counterexamples that demonstrate the bug exists
  - **Test Details**:
    - Test that toggling visibility to "private" does not persist to generation request
    - Test that visibility field is undefined or defaults to "public" in payload
    - Test that visibility resets during lyrics review flow
  - **File**: `test/features/studio/presentation/providers/studio_form_visibility_exploration_test.dart`
  - Run test on UNFIXED code
  - **EXPECTED OUTCOME**: Test FAILS (this is correct - it proves the bug exists)
  - Document counterexamples found (e.g., "Toggle set to private, but generation request has visibility: undefined")
  - Mark task complete when test is written, run, and failure is documented
  - _Requirements: 1.4, 1.5, 1.6, 2.5, 2.6_

### VH-003: Bug Condition Exploration Test

- [ ] 3. Write bug condition exploration test
  - **Property 1: Bug Condition** - Description Text Wastes Vertical Space
  - **CRITICAL**: This test MUST FAIL on unfixed code - failure confirms the bug exists
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: This test encodes the expected behavior - it will validate the fix when it passes after implementation
  - **GOAL**: Surface counterexamples that demonstrate the bug exists
  - **Test Details**:
    - Test that `StudioActionBar` height exceeds 144px due to description paragraphs
    - Test that prompt field, toggle, and CTA button require scroll at 360×640dp viewport
  - **File**: `test/features/studio/presentation/widgets/studio_action_bar_height_exploration_test.dart`
  - Run test on UNFIXED code
  - **EXPECTED OUTCOME**: Test FAILS (this is correct - it proves the bug exists)
  - Document counterexamples found (e.g., "Action bar height is 236px, controls below fold at 360×640dp")
  - Mark task complete when test is written, run, and failure is documented
  - _Requirements: 1.7, 1.8, 1.9, 2.14, 2.15_

### VH-004: Bug Condition Exploration Test

- [ ] 4. Write bug condition exploration test
  - **Property 1: Bug Condition** - CTA Button Overflows Screen Edge
  - **CRITICAL**: This test MUST FAIL on unfixed code - failure confirms the bug exists
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: This test encodes the expected behavior - it will validate the fix when it passes after implementation
  - **GOAL**: Surface counterexamples that demonstrate the bug exists
  - **Test Details**:
    - Test that "Activate Creator DNA ✨ →" button extends past right edge at 360dp width
    - Test that button is clipped at 130% font scale
    - Test that button touch target is inaccessible when clipped
  - **File**: `test/features/onboarding/presentation/views/onboarding_cta_overflow_exploration_test.dart`
  - Run test on UNFIXED code
  - **EXPECTED OUTCOME**: Test FAILS (this is correct - it proves the bug exists)
  - Document counterexamples found (e.g., "Button width 320dp exceeds viewport 360dp, clipped by 32dp at 130% scale")
  - Mark task complete when test is written, run, and failure is documented
  - _Requirements: 1.10, 1.11, 1.12, 2.16, 2.17_

### VH-005: Bug Condition Exploration Test

- [ ] 5. Write bug condition exploration test
  - **Property 1: Bug Condition** - No Real-Time Progress Tracker
  - **CRITICAL**: This test MUST FAIL on unfixed code - failure confirms the bug exists
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: This test encodes the expected behavior - it will validate the fix when it passes after implementation
  - **GOAL**: Surface counterexamples that demonstrate the bug exists
  - **Test Details**:
    - Test that no progress tracker component exists in studio cockpit
    - Test that users have no visibility into parameter completeness
    - Test that slot states (Empty/Set/Auto) are not exposed
  - **File**: `test/features/studio/presentation/widgets/progress_tracker_missing_exploration_test.dart`
  - Run test on UNFIXED code
  - **EXPECTED OUTCOME**: Test FAILS (this is correct - it proves the bug exists)
  - Document counterexamples found (e.g., "No progress tracker widget found in widget tree, no completeness feedback")
  - Mark task complete when test is written, run, and failure is documented
  - _Requirements: 1.13, 1.14, 1.15, 2.20, 2.21_

### VH-006: Bug Condition Exploration Test

- [ ] 6. Write bug condition exploration test
  - **Property 1: Bug Condition** - Generic Text Title Lacks Brand Identity
  - **CRITICAL**: This test MUST FAIL on unfixed code - failure confirms the bug exists
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: This test encodes the expected behavior - it will validate the fix when it passes after implementation
  - **GOAL**: Surface counterexamples that demonstrate the bug exists
  - **Test Details**:
    - Test that header shows text "VHUNAMBI Studio" instead of logo
    - Test that text title consumes ~160-180px horizontal space
    - Test that credits chip collides with text title at 360dp width
  - **File**: `test/core/widgets/vhunambi_app_bar_branding_exploration_test.dart`
  - Run test on UNFIXED code
  - **EXPECTED OUTCOME**: Test FAILS (this is correct - it proves the bug exists)
  - Document counterexamples found (e.g., "Header contains Text widget 'VHUNAMBI Studio', no SVG logo, credits chip within 8px of title")
  - Mark task complete when test is written, run, and failure is documented
  - _Requirements: 1.16, 1.17, 1.18, 2.29, 2.30_

---

## Phase 2: Preservation Property Tests (BEFORE Implementation)

These tests verify that existing behavior must remain unchanged by the fixes.

- [ ] 7. Write preservation property tests (BEFORE implementing fixes)
  - **Property 2: Preservation** - Existing Functionality Must Not Break
  - **IMPORTANT**: Follow observation-first methodology
  - **Preservation Areas**:
    - VH-001: Player transport controls (play/pause, skip, swipe gestures, tap-to-expand)
    - VH-002: Studio generation flow (lyrics review, instrumental mode, CTA triggers)
    - VH-003: Action bar button behavior (generation trigger, haptic feedback)
    - VH-004: Onboarding flow (DNA activation, page navigation, page dots)
    - VH-005: Studio parameter management (defaults, tab switching, form persistence)
    - VH-006: Header navigation (credits chip, tap actions)
  - **Methodology**:
    1. Observe behavior on UNFIXED code for non-buggy inputs
    2. Document observed behavior patterns
    3. Write property-based tests capturing observed behavior
    4. Run tests on UNFIXED code
  - **Files**:
    - `test/features/player/presentation/widgets/mobile_mini_player_preservation_test.dart`
    - `test/features/studio/presentation/widgets/studio_action_bar_preservation_test.dart`
    - `test/features/onboarding/presentation/views/onboarding_preservation_test.dart`
    - `test/core/widgets/vhunambi_app_bar_preservation_test.dart`
  - **EXPECTED OUTCOME**: Tests PASS (this confirms baseline behavior to preserve)
  - Mark task complete when tests are written, run, and passing on unfixed code
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 3.10, 3.11, 3.12, 3.13, 3.14, 3.15, 3.16, 3.17, 3.18, 3.19_

---

## Phase 3: Implementation

### VH-001: Mini Player Dismiss Control

- [ ] 8. Fix for mini player dismissal

  - [ ] 8.1 Add close button to `MobileMiniPlayer` widget
    - Add leading `IconButton` with `Icons.close_rounded` icon
    - Position: left side, before album art
    - Size: 44×44px touch target, 20px icon
    - Color: `AppColors.textSecondary`
    - Tooltip: "Dismiss player"
    - Haptic feedback: `HapticFeedback.mediumImpact()` on tap
    - Action: calls `ref.read(playerStateProvider.notifier).dismiss()`
    - **File**: `lib/features/player/presentation/widgets/mobile_mini_player.dart`
    - _Bug_Condition: isBugCondition(X) where X.hasActiveTrack == true AND dismissControl == null_
    - _Expected_Behavior: hasDismissControl == true AND dismissAction.stopsPlayback == true_
    - _Preservation: Transport controls, expand action, skip gestures remain functional_
    - _Requirements: 2.1, 2.2, REQ-A11Y-01_

  - [ ] 8.2 Implement swipe-down dismiss gesture
    - Add `onVerticalDragEnd` handler to `GestureDetector`
    - Velocity threshold: `> 250` pixels/second
    - Direction: downward (positive dy)
    - Haptic feedback: `HapticFeedback.mediumImpact()` on dismiss
    - Action: calls `notifier.dismiss()`
    - Ensure no conflict with horizontal skip swipes
    - **File**: `lib/features/player/presentation/widgets/mobile_mini_player.dart`
    - _Requirements: 2.1, 2.2, REQ-A11Y-02_

  - [ ] 8.3 Add keyboard visibility detection
    - Read `MediaQuery.of(context).viewInsets.bottom`
    - Condition: when `viewInsets.bottom > 0`, render `SizedBox.shrink()`
    - Condition: when `viewInsets.bottom == 0`, render normal player
    - Preserves existing functionality when keyboard closed
    - **File**: `lib/features/player/presentation/widgets/mobile_mini_player.dart`
    - _Requirements: 2.4, REQ-RWD-03_

  - [ ] 8.4 Implement player removal animation
    - Wrap `MobileMiniPlayer` in parent scaffold with `AnimatedSwitcher`
    - Duration: 200ms
    - Curve: `Curves.easeOut` (in), `Curves.easeIn` (out)
    - Transition: `SlideTransition` with `Offset(0, 1)` → `Offset.zero`
    - Key: `ValueKey('player')` when visible, `ValueKey('empty')` when hidden
    - **File**: Parent scaffold where `MobileMiniPlayer` is rendered
    - _Requirements: 2.2_

  - [ ] 8.5 Verify `PlayerNotifier.dismiss()` implementation
    - Confirm method stops playback: sets `playbackStatus` to `PlaybackStatus.idle`
    - Confirm method clears state: sets `currentTrack` to null, `position` to zero
    - Confirm method releases audio session: calls `_audioHandler.stop()`
    - Confirm error handling: uses `_dispatchSafely()` wrapper
    - **File**: `lib/features/player/presentation/providers/player_provider.dart`
    - _Requirements: 2.1, 2.2, 2.3_

  - [ ] 8.6 Verify bug condition exploration test now passes
    - **Property 1: Expected Behavior** - Dismiss Stops Playback
    - **IMPORTANT**: Re-run the SAME test from task 1 - do NOT write a new test
    - The test from task 1 encodes the expected behavior
    - When this test passes, it confirms the expected behavior is satisfied
    - Run bug condition exploration test from Phase 1
    - **EXPECTED OUTCOME**: Test PASSES (confirms bug is fixed)
    - _Requirements: Expected Behavior Properties from design_

  - [ ] 8.7 Verify preservation tests still pass
    - **Property 2: Preservation** - Transport Controls Unchanged
    - **IMPORTANT**: Re-run the SAME tests from task 7 - do NOT write new tests
    - Run preservation property tests from Phase 2
    - **EXPECTED OUTCOME**: Tests PASS (confirms no regressions)
    - Confirm transport controls still work (play/pause, skip, swipe gestures)
    - Confirm tap-to-expand still opens Now Playing cockpit
    - Confirm horizontal swipes still skip tracks

- [ ] 9. Checkpoint - Ensure all VH-001 tests pass
  - Run all player-related tests
  - Verify no regressions in test suite
  - Confirm acceptance criteria met
  - _Verification: `flutter test test/features/player/`_

### VH-002: Visibility Toggle Functionality

- [ ] 10. Fix for visibility toggle (Phase 1: Add visibility field)

  - [ ] 10.1 Add `visibility` field to `StudioFormState`
    - Add field: `final String visibility;`
    - Add default value in constructor: `this.visibility = 'public',`
    - Add to `copyWith`: `String? visibility,`
    - Sync with deprecated `isPublic`: `isPublic = (visibility == "public")`
    - Mark `isPublic` as `@Deprecated('Use visibility field instead. Removed in v2.1.0')`
    - **File**: `lib/features/studio/domain/models/studio_form_state.dart`
    - _Bug_Condition: isBugCondition(X) where X.isPublic == false AND generationRequest.visibility == undefined_
    - _Expected_Behavior: request.visibility == "private" AND track.excludedFromExplore == true_
    - _Preservation: Lyrics flow, generation trigger, haptic feedback remain functional_
    - _Requirements: 2.5, 2.6, REQ-STM-02, REQ-STM-03_

  - [ ] 10.2 Add `setVisibility(String)` method to `StudioFormNotifier`
    - Method signature: `void setVisibility(String visibility)`
    - Assertion: `assert(visibility == 'public' || visibility == 'private')`
    - Updates state: `state = state.copyWith(visibility: visibility);`
    - Deprecated wrapper: `togglePublic(bool)` calls `setVisibility()`
    - **File**: `lib/features/studio/presentation/providers/studio_form_provider.dart`
    - _Requirements: 2.5, 2.6, REQ-STM-04_

  - [ ] 10.3 Update `StudioActionBar` toggle binding
    - Replace `state.isPublic` with `state.visibility`
    - Calculate: `final isPublic = state.visibility == 'public';`
    - Switch binding: `onChanged: (val) => notifier.setVisibility(val ? 'public' : 'private')`
    - Haptic feedback: `HapticFeedback.selectionClick()` on change
    - **File**: `lib/features/studio/presentation/widgets/studio_action_bar.dart`
    - _Requirements: 2.5, 2.6_

  - [ ] 10.4 Implement dynamic icon, title, and subtitle
    - Icon: `isPublic ? Icons.public_rounded : Icons.lock_outline_rounded`
    - Icon color: `isPublic ? AppColors.brandPrimary : AppColors.textSecondary`
    - Title: `isPublic ? 'Public' : 'Private'`
    - Subtitle: `isPublic ? 'Visible on Explore & your profile' : 'Only you can see this'`
    - **File**: `lib/features/studio/presentation/widgets/studio_action_bar.dart`
    - _Requirements: 2.10_

  - [ ] 10.5 Add visibility to generation request payload
    - Update `GenerationRequest.toJson()` to include `'visibility': visibility`
    - Ensure field is sent with API request
    - **File**: `lib/features/studio/data/models/generation_request.dart` (or equivalent)
    - _Requirements: 2.5, 2.6, 2.7, 2.8_

  - [ ] 10.6 Preserve visibility across lyrics review flow
    - Verify `approveLyrics()` does NOT reset visibility to default
    - Ensure `copyWith` in lyrics flow preserves visibility field
    - **File**: `lib/features/studio/presentation/providers/studio_form_provider.dart`
    - _Requirements: 2.9, REQ-STM-05_

  - [ ] 10.7 Verify bug condition exploration test now passes
    - **Property 1: Expected Behavior** - Visibility Persists to Backend
    - **IMPORTANT**: Re-run the SAME test from task 2 - do NOT write a new test
    - Run bug condition exploration test from Phase 1
    - **EXPECTED OUTCOME**: Test PASSES (confirms bug is fixed)
    - _Requirements: Expected Behavior Properties from design_

  - [ ] 10.8 Verify preservation tests still pass
    - **Property 2: Preservation** - Studio Generation Flow Unchanged
    - **IMPORTANT**: Re-run the SAME tests from task 7 - do NOT write new tests
    - Run preservation property tests from Phase 2
    - **EXPECTED OUTCOME**: Tests PASS (confirms no regressions)
    - Confirm lyrics review flow still works
    - Confirm generation triggers correctly
    - Confirm haptic feedback fires

- [ ] 11. Checkpoint - Ensure all VH-002 tests pass
  - Run all studio form tests
  - Verify visibility field works correctly
  - Confirm acceptance criteria met
  - _Verification: `flutter test test/features/studio/`_

### VH-003: Description Text Removal

- [ ] 12. Fix for description text removal

  - [ ] 12.1 Remove explanation paragraph from `StudioActionBar`
    - Remove text: "AI writes the lyrics → you review & edit → then the beat is produced"
    - Remove spacing and container associated with paragraph
    - **File**: `lib/features/studio/presentation/widgets/studio_action_bar.dart`
    - _Bug_Condition: isBugCondition(X) where X.height == 640dp AND descriptionParagraphsHeight == 190px_
    - _Expected_Behavior: promptFieldVisible == true AND noScrollRequired(result, X.height)_
    - _Preservation: CTA action, toggle action, lyrics flow logic remain functional_
    - _Requirements: 2.11, 2.15_

  - [ ] 12.2 Evaluate and implement ToS acceptance strategy
    - **Decision Required**: Confirm with product/legal whether ToS notice is required
    - **Option A (Recommended)**: Move to one-time acceptance modal on first generation
    - **Option B**: Retain as single compact footer line (10sp, tertiary color)
    - **Option C**: Remove entirely, link from Settings
    - Implement chosen strategy
    - **Files**: `lib/features/studio/presentation/widgets/studio_action_bar.dart`, possibly `lib/features/studio/presentation/widgets/generation_tos_modal.dart`
    - _Requirements: 2.12, 2.13, RISK-BC-02, RISK-PL-02_

  - [ ] 12.3 Update action bar layout constraints
    - Remove spacing associated with removed paragraphs
    - Verify column height: toggle (56px) + spacing (16px) + button (52px) + optional footer (24px)
    - Target height: ~120-144px
    - **File**: `lib/features/studio/presentation/widgets/studio_action_bar.dart`
    - _Requirements: 2.14, 2.15_

  - [ ] 12.4 Verify viewport visibility at 360×640dp
    - Test at 360×640dp with mini player dismissed
    - Confirm prompt field, toggle, and CTA button visible without scroll
    - Use widget test with `MediaQuery` override
    - **File**: `test/features/studio/presentation/widgets/studio_action_bar_viewport_test.dart`
    - _Requirements: 2.14_

  - [ ] 12.5 Verify bug condition exploration test now passes
    - **Property 1: Expected Behavior** - Reduced Height, No Scroll Required
    - **IMPORTANT**: Re-run the SAME test from task 3 - do NOT write a new test
    - Run bug condition exploration test from Phase 1
    - **EXPECTED OUTCOME**: Test PASSES (confirms bug is fixed)
    - _Requirements: Expected Behavior Properties from design_

  - [ ] 12.6 Verify preservation tests still pass
    - **Property 2: Preservation** - Action Bar Behavior Unchanged
    - **IMPORTANT**: Re-run the SAME tests from task 7 - do NOT write new tests
    - Run preservation property tests from Phase 2
    - **EXPECTED OUTCOME**: Tests PASS (confirms no regressions)
    - Confirm CTA button triggers generation correctly
    - Confirm toggle updates state

- [ ] 13. Checkpoint - Ensure all VH-003 tests pass
  - Run all action bar tests
  - Verify reduced height
  - Confirm acceptance criteria met
  - _Verification: `flutter test test/features/studio/presentation/widgets/studio_action_bar*`_

### VH-004: DNA CTA Responsive Layout

- [ ] 14. Fix for Creator DNA CTA overflow

  - [ ] 14.1 Wrap CTA button in flexible container
    - Wrap button in `Expanded` widget
    - Add `ConstrainedBox` with `maxWidth` and `minHeight: 52`
    - **File**: `lib/features/onboarding/presentation/views/onboarding_view.dart`
    - _Bug_Condition: isBugCondition(X) where X.viewportWidth == 360dp AND pageDotsWidth + buttonWidth + margins > X.viewportWidth_
    - _Expected_Behavior: buttonRightEdge <= (X.viewportWidth - 16dp) AND buttonHitTargetArea >= 44×44_
    - _Preservation: CTA action, page indicators, page navigation remain functional_
    - _Requirements: 2.16, 2.17_

  - [ ] 14.2 Implement max width calculation
    - Add method: `double _calculateMaxButtonWidth(BuildContext context)`
    - Formula: `max(screenWidth - pageDotsWidth - horizontalMargins, 240.0)`
    - Constants: `pageDotsWidth = 48.0`, `horizontalMargins = AppSpacing.md * 3`
    - **File**: `lib/features/onboarding/presentation/views/onboarding_view.dart`
    - _Requirements: 2.17_

  - [ ] 14.3 Add FittedBox for text scaling
    - Wrap button text in `FittedBox(fit: BoxFit.scaleDown)`
    - Set `maxLines: 1` and `overflow: TextOverflow.ellipsis`
    - Consider removing emoji: "Activate Creator DNA →" (saves ~20dp)
    - **File**: `lib/features/onboarding/presentation/views/onboarding_view.dart`
    - _Requirements: 2.18, REQ-A11Y-04_

  - [ ] 14.4 Test at multiple viewport widths and font scales
    - Test at 360dp, 375dp, 414dp, 768dp widths
    - Test at 100%, 130%, 200% font scales
    - Verify 16-24dp right margin in all cases
    - Verify 44×44px minimum touch target
    - **File**: `test/features/onboarding/presentation/views/onboarding_responsive_test.dart`
    - _Requirements: 2.16, 2.17, 2.19, REQ-RWD-01, REQ-A11Y-04_

  - [ ] 14.5 Verify bug condition exploration test now passes
    - **Property 1: Expected Behavior** - No Overflow, Accessible Touch Target
    - **IMPORTANT**: Re-run the SAME test from task 4 - do NOT write a new test
    - Run bug condition exploration test from Phase 1
    - **EXPECTED OUTCOME**: Test PASSES (confirms bug is fixed)
    - _Requirements: Expected Behavior Properties from design_

  - [ ] 14.6 Verify preservation tests still pass
    - **Property 2: Preservation** - Onboarding Flow Unchanged
    - **IMPORTANT**: Re-run the SAME tests from task 7 - do NOT write new tests
    - Run preservation property tests from Phase 2
    - **EXPECTED OUTCOME**: Tests PASS (confirms no regressions)
    - Confirm CTA activates DNA profile
    - Confirm page navigation works

- [ ] 15. Checkpoint - Ensure all VH-004 tests pass
  - Run all onboarding tests
  - Verify responsive layout
  - Confirm acceptance criteria met
  - _Verification: `flutter test test/features/onboarding/`_

### VH-005: Real-Time Progress Tracker

- [ ] 16. Fix for real-time progress tracker (NEW FEATURE)

  - [ ] 16.1 Create `ProgressTrackerState` model
    - Define fields: `filledCount`, `totalCount`, `slots`
    - Add computed properties: `completenessRatio`, `completenessLabel`
    - Define `ParameterSlot` class: `name`, `state`, `value`
    - Define `SlotState` enum: `empty`, `set`, `auto`
    - **File**: `lib/features/studio/domain/models/progress_tracker_state.dart` (new file)
    - _Bug_Condition: isBugCondition(X) where progressTracker == null AND noCompletnessFeedback_
    - _Expected_Behavior: progressTrackerExists == true AND slotsVisible == true AND updatesRealTime == true_
    - _Preservation: Studio parameter management (defaults, tab switching, form persistence) remains functional_
    - _Requirements: 2.20, 2.21, 2.22, 2.23_

  - [ ] 16.2 Implement `ProgressTrackerState.fromStudioForm()` derivation
    - Factory constructor: `factory ProgressTrackerState.fromStudioForm(StudioFormState form)`
    - Derive 9 slot states from form fields: Prompt, Genre, Mood, Tempo, Vocal Energy, Language, Lyrics, DNA Usage, Visibility
    - Logic for slot states:
      - Empty: field is null or empty string
      - Set: user-configured (non-default value)
      - Auto: DNA-suggested or default value
    - Calculate `filledCount` from slot states
    - Include null-safe error handling with fallback state
    - **File**: `lib/features/studio/domain/models/progress_tracker_state.dart`
    - _Requirements: 2.21, 2.22, 2.23, REQ-STM-01_

  - [ ] 16.3 Create `progressTrackerProvider`
    - Define provider: `final progressTrackerProvider = Provider<ProgressTrackerState>((ref) { ... })`
    - Watch `studioFormProvider` and derive tracker state
    - Return `ProgressTrackerState.fromStudioForm(formState)`
    - Define expansion state provider: `final _isExpandedProvider = StateProvider<bool>((ref) => false)`
    - **File**: `lib/features/studio/presentation/providers/progress_tracker_provider.dart` (new file)
    - _Requirements: 2.20, REQ-STM-01_

  - [ ] 16.4 Build `StudioProgressTracker` widget (collapsed bar)
    - Create `StudioProgressTracker extends ConsumerWidget`
    - Add optional callback: `void Function(String slotName)? onSlotTapped`
    - Implement collapsed bar view: segmented progress bar, completeness label, DNA % chip, expand chevron
    - Height: 48dp (collapsed)
    - Tap: toggles expansion state
    - **File**: `lib/features/studio/presentation/widgets/studio_progress_tracker.dart` (new file)
    - _Requirements: 2.27_

  - [ ] 16.5 Build expanded slot list view
    - Create `_ExpandedView` widget
    - Height: 320dp (expanded)
    - Header row: title, completeness label, collapse button
    - Scrollable slot list: `ListView.separated` with `_SlotTile` items
    - Each slot shows: state icon, name, value, state badge
    - **File**: `lib/features/studio/presentation/widgets/studio_progress_tracker.dart`
    - _Requirements: 2.28_

  - [ ] 16.6 Implement tap-to-scroll navigation
    - On slot tap: fire `onSlotTapped(slotName)` callback
    - In parent (StudioView): `_scrollController.animateTo(_getSlotOffset(slotName))`
    - Duration: 300ms, curve: `Curves.easeOut`
    - Haptic feedback: `HapticFeedback.lightImpact()` on tap
    - **File**: `lib/features/studio/presentation/views/studio_view.dart` (or equivalent)
    - _Requirements: 2.24_

  - [ ] 16.7 Add haptic feedback on slot changes
    - Listen to `progressTrackerProvider` for state changes
    - Fire `HapticFeedback.lightImpact()` when `filledCount` increases
    - Respect system haptics setting
    - **File**: `lib/features/studio/presentation/widgets/studio_progress_tracker.dart`
    - _Requirements: 2.21, REQ-A11Y-05_

  - [ ] 16.8 Add progress tracker to cockpit layout
    - Place `StudioProgressTracker` pinned under Compose/Voice/Crate tabs
    - Above scrollable form fields
    - Pass `onSlotTapped` callback for navigation
    - Wrap in `RepaintBoundary` for performance
    - **File**: `lib/features/studio/presentation/views/studio_view.dart` (or equivalent)
    - _Requirements: 2.20, 2.27_

  - [ ] 16.9 Verify bug condition exploration test now passes
    - **Property 1: Expected Behavior** - Progress Tracker Exists and Updates
    - **IMPORTANT**: Re-run the SAME test from task 5 - do NOT write a new test
    - Run bug condition exploration test from Phase 1
    - **EXPECTED OUTCOME**: Test PASSES (confirms feature is implemented)
    - _Requirements: Expected Behavior Properties from design_

  - [ ] 16.10 Verify preservation tests still pass
    - **Property 2: Preservation** - Studio Parameter Management Unchanged
    - **IMPORTANT**: Re-run the SAME tests from task 7 - do NOT write new tests
    - Run preservation property tests from Phase 2
    - **EXPECTED OUTCOME**: Tests PASS (confirms no regressions)
    - Confirm parameter defaults still apply
    - Confirm tab switching preserves state
    - Confirm form state is single source of truth

- [ ] 17. Checkpoint - Ensure all VH-005 tests pass
  - Run all progress tracker tests
  - Verify real-time updates
  - Verify state derivation correctness
  - Confirm acceptance criteria met
  - _Verification: `flutter test test/features/studio/presentation/widgets/progress_tracker*`_

### VH-006: Studio Branding

- [ ] 18. Fix for studio branding (logo assets)

  - [ ] 18.1 Create logo assets
    - **Compact mark SVG** (header): 90×32dp, single path, light/dark variants
    - **Full lockup SVG** (splash/onboarding): 240-320dp width, wordmark + icon
    - **Adaptive launcher icon** (Android): 108×108dp canvas, 72×72dp safe zone, 56-64dp icon
    - **PNG fallbacks**: @1x, @2x, @3x for all SVG assets
    - **Colors**: Primary `#F97316` (orange), dark mode full color, light mode black
    - **Trademark search**: Complete before finalizing design
    - **Files**: 
      - `assets/branding/vhunambi_compact_mark.svg` (new file)
      - `assets/branding/vhunambi_full_lockup.svg` (new file)
      - `android/app/src/main/res/mipmap-*/ic_launcher_foreground.png` (new files)
    - _Bug_Condition: isBugCondition(X) where header.containsText("VHUNAMBI Studio") AND noLogoSvg_
    - _Expected_Behavior: header.containsSvgLogo == true AND horizontalSpace <= 100px_
    - _Preservation: Header navigation (credits chip, tap actions) remains functional_
    - _Requirements: 2.29, 2.30, 2.31, 2.32, 2.33, 2.34_

  - [ ] 18.2 Add asset paths to `AppAssets`
    - Add constant: `static const String vhunambiCompactMark = 'assets/branding/vhunambi_compact_mark.svg';`
    - Add constant: `static const String vhunambiFullLockup = 'assets/branding/vhunambi_full_lockup.svg';`
    - Add PNG fallback if needed
    - **File**: `lib/core/constants/app_assets.dart`
    - _Requirements: 2.29_

  - [ ] 18.3 Update `pubspec.yaml` for assets
    - Add `flutter_svg: ^2.0.9` to dependencies (if not present)
    - Add asset paths:
      ```yaml
      flutter:
        assets:
          - assets/branding/
          - assets/branding/vhunambi_compact_mark.svg
          - assets/branding/vhunambi_full_lockup.svg
      ```
    - Run `flutter pub get`
    - **File**: `pubspec.yaml`
    - _Requirements: 2.29_

  - [ ] 18.4 Update `VhunambiAppBar` to use logo
    - Replace `Text('VHUNAMBI Studio')` with `SvgPicture.asset(AppAssets.vhunambiCompactMark)`
    - Set width: 90px, height: 32px
    - Add `colorFilter`: `ColorFilter.mode(_logoColor(context), BlendMode.srcIn)`
    - Implement `_logoColor()`: dark mode = `AppColors.brandPrimary`, light mode = `AppColors.textPrimary`
    - Add error handling / placeholder for missing asset
    - **File**: `lib/core/widgets/vhunambi_app_bar.dart`
    - _Requirements: 2.29, 2.30_

  - [ ] 18.5 Test light/dark mode variants
    - Test logo rendering in dark mode (orange)
    - Test logo rendering in light mode (black)
    - Verify color filter applies correctly
    - **File**: `test/core/widgets/vhunambi_app_bar_theme_test.dart`
    - _Requirements: 2.30_

  - [ ] 18.6 Verify horizontal clearance
    - Measure header width at 360dp viewport
    - Confirm logo + credits chip have ≥60px clearance
    - Logo should consume ~90px, leaving ~270px for credits chip + margins
    - **File**: `test/core/widgets/vhunambi_app_bar_layout_test.dart`
    - _Requirements: 2.29_

  - [ ] 18.7 Verify bug condition exploration test now passes
    - **Property 1: Expected Behavior** - Logo Replaces Text, Clearance Maintained
    - **IMPORTANT**: Re-run the SAME test from task 6 - do NOT write a new test
    - Run bug condition exploration test from Phase 1
    - **EXPECTED OUTCOME**: Test PASSES (confirms bug is fixed)
    - _Requirements: Expected Behavior Properties from design_

  - [ ] 18.8 Verify preservation tests still pass
    - **Property 2: Preservation** - Header Navigation Unchanged
    - **IMPORTANT**: Re-run the SAME tests from task 7 - do NOT write new tests
    - Run preservation property tests from Phase 2
    - **EXPECTED OUTCOME**: Tests PASS (confirms no regressions)
    - Confirm credits chip tap opens purchase flow
    - Confirm header spacing responsive on desktop

- [ ] 19. Checkpoint - Ensure all VH-006 tests pass
  - Run all app bar tests
  - Verify logo renders correctly
  - Verify no pixelation at multiple densities
  - Confirm acceptance criteria met
  - _Verification: `flutter test test/core/widgets/vhunambi_app_bar*`_

---

## Phase 4: Cross-Cutting Tasks

### Analytics Integration

- [ ] 20. Implement analytics events
  - [ ] 20.1 Add `studio_player_dismissed` event
    - Fire when user dismisses mini player
    - Parameters: `track_id`, `playback_position_sec`, `dismiss_method` ("button" | "swipe_down")
    - **File**: `lib/features/player/presentation/widgets/mobile_mini_player.dart`
    - _Requirements: REQ-ANL-01_

  - [ ] 20.2 Add `studio_visibility_toggled` event
    - Fire when user changes visibility toggle
    - Parameters: `visibility` ("public" | "private"), `lyrics_mode`, `genre`
    - **File**: `lib/features/studio/presentation/widgets/studio_action_bar.dart`
    - _Requirements: REQ-ANL-02_

  - [ ] 20.3 Add `studio_progress_slot_tapped` event
    - Fire when user taps a slot in progress tracker
    - Parameters: `slot_name`, `slot_state` ("empty" | "set" | "auto"), `completeness_ratio`
    - **File**: `lib/features/studio/presentation/widgets/studio_progress_tracker.dart`
    - _Requirements: REQ-ANL-03_

  - [ ] 20.4 Add `studio_cta_overflow_detected` event
    - Fire if onboarding CTA button width exceeds viewport bounds
    - Parameters: `viewport_width`, `button_width`, `font_scale`
    - Fire on build: use `WidgetsBinding.instance.addPostFrameCallback()`
    - **File**: `lib/features/onboarding/presentation/views/onboarding_view.dart`
    - _Requirements: REQ-ANL-04_

### Design System Updates

- [ ] 21. Verify design tokens
  - [ ] 21.1 Audit `AppColors` for missing tokens
    - Verify `brandPrimary`, `textSecondary`, `surfaceElevated`, etc. exist
    - Add any missing colors referenced in design
    - **File**: `lib/core/design_system/app_colors.dart`
    - _Requirements: REQ-DST-01_

  - [ ] 21.2 Audit `AppSpacing` for missing tokens
    - Verify `xs`, `sm`, `md`, `lg` exist
    - Add any missing spacing values
    - **File**: `lib/core/design_system/app_spacing.dart`
    - _Requirements: REQ-DST-02_

  - [ ] 21.3 Audit `AppTypography` for missing styles
    - Verify `bodyLarge`, `caption`, `titleMedium`, etc. exist
    - Add any missing typography styles
    - **File**: `lib/core/design_system/app_typography.dart`
    - _Requirements: REQ-DST-03_

  - [ ] 21.4 Audit `AppRadius` for missing values
    - Verify `cardBorder`, `pillBorder`, `sm` exist
    - Add any missing radius values
    - **File**: `lib/core/design_system/app_radius.dart`
    - _Requirements: REQ-DST-04_

### Migration Documentation

- [ ] 22. Create migration guide for `isPublic` → `visibility`
  - Document 3-phase migration strategy
  - Provide code examples for updating call sites
  - List all files that need updates
  - **File**: `docs/migration/studio_form_visibility_migration.md` (new file)
  - _Requirements: RISK-BC-01_

### Asset Pipeline

- [ ] 23. Configure SVG asset loading
  - Verify `flutter_svg` package is installed and up to date
  - Test SVG loading on Android and iOS
  - Add error handling for missing assets
  - **File**: `pubspec.yaml`, various widget files
  - _Requirements: 2.29, 2.30_

### Haptics Service

- [ ] 24. Ensure haptics respect system settings
  - Verify all haptic calls respect platform settings
  - Test on Android (vibration permission) and iOS (haptics setting)
  - Ensure no crashes when haptics unavailable
  - **Files**: All widgets using `HapticFeedback`
  - _Requirements: REQ-A11Y-05_

---

## Phase 5: Final Integration & Testing

### Full Test Suite

- [ ] 25. Run complete test suite
  - Execute: `flutter test`
  - Confirm all 991+ tests passing (baseline + new tests)
  - Document any failures and fix
  - _Verification: Zero test failures_

### Static Analysis

- [ ] 26. Run static analysis
  - Execute: `flutter analyze`
  - Confirm 0 errors, 0 warnings
  - Fix any analyzer issues
  - _Verification: Clean analyzer output_

### Manual Testing - Viewport Sizes

- [ ] 27. Test on multiple viewport sizes
  - [ ] 27.1 Test at 360×640dp (small phone)
    - Verify all controls visible without scroll
    - Verify CTA button no overflow
    - Verify mini player dismisses correctly
    - _Requirements: REQ-RWD-01_

  - [ ] 27.2 Test at 375×812dp (iPhone SE/13 mini)
    - Verify responsive layout
    - Verify logo and credits chip clearance
    - _Requirements: REQ-RWD-01_

  - [ ] 27.3 Test at 414×896dp (iPhone 11/12/13)
    - Verify responsive layout
    - Verify progress tracker visible
    - _Requirements: REQ-RWD-01_

  - [ ] 27.4 Test at 768×1024dp (iPad)
    - Verify responsive layout
    - Consider progress tracker sidebar (optional)
    - _Requirements: REQ-RWD-01, REQ-RWD-02_

### Manual Testing - Font Scales

- [ ] 28. Test at multiple font scales
  - [ ] 28.1 Test at 100% font scale
    - Verify all text legible
    - Verify no overflow
    - _Requirements: REQ-A11Y-04_

  - [ ] 28.2 Test at 130% font scale
    - Verify CTA button accessible
    - Verify no text clipping
    - _Requirements: REQ-A11Y-04_

  - [ ] 28.3 Test at 200% font scale
    - Verify FittedBox scales correctly
    - Verify 44×44px touch targets maintained
    - _Requirements: REQ-A11Y-04_

### Manual Testing - User Flows

- [ ] 29. Test complete user flows
  - [ ] 29.1 Test mini player dismissal flow
    - Play track → mini player appears → dismiss via button → verify playback stops
    - Play track → mini player appears → dismiss via swipe-down → verify playback stops
    - Open keyboard on Create screen → verify mini player hides

  - [ ] 29.2 Test visibility toggle flow
    - Set visibility to Private → generate song → verify track not in Explore
    - Set visibility to Public → generate song → verify track in Explore
    - Set visibility to Private → enter lyrics review → approve lyrics → verify visibility still Private

  - [ ] 29.3 Test progress tracker flow
    - Configure parameters → verify progress updates in real-time
    - Tap slot → verify scroll to corresponding control
    - Expand tracker → verify slot list shows correct states

  - [ ] 29.4 Test onboarding CTA flow
    - Complete onboarding → reach DNA page → verify CTA button fully visible
    - Test at 360dp and 130% font scale → verify button accessible

  - [ ] 29.5 Test header logo flow
    - Navigate to Studio → verify logo renders correctly
    - Switch to light mode → verify logo color changes
    - Verify credits chip has clearance

### Visual Regression Testing

- [ ] 30. Visual regression testing for logo assets
  - Compare logo rendering across screen densities (1x, 2x, 3x)
  - Verify no pixelation or aliasing
  - Verify light/dark mode variants render correctly
  - _Requirements: 2.30_

### Performance Testing

- [ ] 31. Performance profiling
  - [ ] 31.1 Profile progress tracker updates
    - Verify updates within 16ms (60fps)
    - Check for unnecessary rebuilds
    - Use `flutter run --profile` and DevTools
    - _Requirements: REQ-PF-01_

  - [ ] 31.2 Profile mini player gesture recognition
    - Verify swipe gestures respond at 60fps
    - Check for gesture conflicts
    - Test on mid-range device
    - _Requirements: RISK-PF-02_

### Accessibility Testing

- [ ] 32. Accessibility audit
  - [ ] 32.1 Test with screen reader
    - iOS VoiceOver: verify progress tracker slots have semantic labels
    - Android TalkBack: verify all controls announced correctly
    - _Requirements: REQ-A11Y-03_

  - [ ] 32.2 Verify touch target sizes
    - Measure all interactive controls
    - Confirm minimum 44×44px
    - _Requirements: REQ-A11Y-01, REQ-A11Y-04_

  - [ ] 32.3 Test gesture alternatives
    - Verify close button as alternative to swipe-down
    - Verify tap-to-scroll as alternative to manual scroll
    - _Requirements: REQ-A11Y-02_

### Risk Mitigation Validation

- [ ] 33. Privacy impact assessment
  - Review default visibility setting (Public vs Private)
  - Confirm alignment with GDPR/CCPA requirements
  - Document decision and rationale
  - _Requirements: RISK-PL-01_

- [ ] 34. Legal review of ToS strategy
  - Confirm ToS acceptance strategy with legal team
  - Verify consent mechanism is compliant
  - Document approval
  - _Requirements: RISK-PL-02_

### Final Acceptance Criteria Verification

- [ ] 35. Verify all acceptance criteria met
  - [ ] 35.1 VH-001: Mini Player Dismissal
    - ✅ Tapping close button stops playback and removes player within 200ms
    - ✅ Swipe-down gesture (velocity > 250) dismisses player
    - ✅ Player hides when keyboard opens (`viewInsets.bottom > 0`)
    - ✅ Player reappears when `playTrack()` called after dismissal
    - ✅ No audio continues after dismiss
    - ✅ Close button has 44×44px touch target
    - ✅ Haptic feedback fires on dismiss action

  - [ ] 35.2 VH-002: Visibility Toggle
    - ✅ Toggle updates `state.visibility` to "public" or "private"
    - ✅ Subtitle text changes dynamically based on visibility
    - ✅ Icon changes from `public_rounded` to `lock_outline_rounded`
    - ✅ Generation request includes `visibility` field
    - ✅ Visibility persists across "Write Lyrics First" flow
    - ✅ Private tracks excluded from Explore feed (backend enforcement)
    - ✅ Haptic feedback fires on toggle

  - [ ] 35.3 VH-003: Description Text Removal
    - ✅ Card contains only toggle row and button
    - ✅ Prompt field, toggle, and primary button all visible without scrolling at 360×640dp with mini player closed

  - [ ] 35.4 VH-004: CTA Responsive Layout
    - ✅ Button fully visible with 16–24dp right margin on every tested device
    - ✅ Button accessible at 130% font scale with 44×44px touch target

  - [ ] 35.5 VH-005: Progress Tracker
    - ✅ Collapsed bar shows 9 segmented progress indicators (filled/empty)
    - ✅ Completeness label updates in real-time ("6/9")
    - ✅ DNA percentage chip displays current DNA usage
    - ✅ Tapping collapsed bar expands to slot list
    - ✅ Expanded view shows all 9 slots with name, value, and state badge
    - ✅ Tapping slot scrolls to corresponding cockpit control
    - ✅ Haptic tick fires on slot state transition
    - ✅ Progress updates within one frame (<16ms at 60fps)
    - ✅ State derived from `StudioFormState` (no duplicate state)
    - ✅ Slot states correct: Empty (unconfigured), Set (user), Auto (DNA)

  - [ ] 35.6 VH-006: Logo Integration
    - ✅ Compact mark replaces "VHUNAMBI Studio" text
    - ✅ Header width reduced from ~180px to ~90px
    - ✅ Credits chip has 70-90px clearance at 360dp (no collision)
    - ✅ Logo renders correctly in dark and light modes
    - ✅ SVG scales without pixelation at 1x, 2x, 3x densities
    - ✅ Full lockup appears on splash and onboarding screens
    - ✅ Adaptive launcher icon exported at all densities
    - ✅ Trademark search completed and documented

---

## Delivery Summary

### Test Coverage

| Category | Baseline | Added | Total | Status |
|----------|----------|-------|-------|--------|
| Unit Tests | ~400 | +12 | ~412 | ⬜ |
| Widget Tests | ~300 | +18 | ~318 | ⬜ |
| Integration Tests | ~20 | +2 | ~22 | ⬜ |
| **Total** | **991** | **+32** | **1023** | ⬜ |

### Files Modified

| File Type | Count | Details |
|-----------|-------|---------|
| Widgets | 5 | MobileMiniPlayer, StudioActionBar, OnboardingView, VhunambiAppBar, StudioProgressTracker (new) |
| Models | 2 | StudioFormState, ProgressTrackerState (new) |
| Providers | 3 | StudioFormNotifier, PlayerNotifier, ProgressTrackerProvider (new) |
| Assets | 6 | Logo SVGs, PNGs, launcher icons |
| Tests | 32 | Unit, widget, integration tests |

### Code Changes Summary

| Bug ID | Lines Added | Lines Removed | Files Modified | Test Files |
|--------|-------------|---------------|----------------|------------|
| VH-001 | ~150 | ~20 | 3 | 3 |
| VH-002 | ~80 | ~30 | 4 | 3 |
| VH-003 | ~20 | ~100 | 2 | 2 |
| VH-004 | ~60 | ~20 | 2 | 2 |
| VH-005 | ~400 | ~0 | 4 | 4 |
| VH-006 | ~50 | ~30 | 3 | 2 |
| **Total** | **~760** | **~200** | **18** | **16** |

### Analytics Events Added

1. `studio_player_dismissed` (VH-001)
2. `studio_visibility_toggled` (VH-002)
3. `studio_progress_slot_tapped` (VH-005)
4. `studio_cta_overflow_detected` (VH-004)

### Risk Mitigation Outcomes

| Risk ID | Mitigation | Status |
|---------|------------|--------|
| RISK-BC-01 | 3-phase migration for `isPublic` → `visibility` | ⬜ Planned |
| RISK-BC-02 | Legal review of ToS notice removal | ⬜ Pending |
| RISK-PL-01 | Privacy impact assessment for default visibility | ⬜ Pending |
| RISK-PL-02 | ToS acceptance strategy confirmed | ⬜ Pending |
| RISK-PF-01 | Progress tracker performance profiled | ⬜ Planned |
| RISK-PF-02 | Gesture conflict testing completed | ⬜ Planned |
| RISK-AC-01 | Close button provides gesture alternative | ✅ Implemented |
| RISK-AC-02 | Flexible layout ensures 44×44px touch target | ✅ Implemented |

---

## Task Dependency Graph

```json
{
  "waves": [
    {
      "name": "Wave 1: Pre-Flight Setup",
      "tasks": ["0.1", "0.2", "0.3", "0.4", "0.5"],
      "parallelizable": false,
      "description": "Environment setup and baseline validation"
    },
    {
      "name": "Wave 2: Bug Condition Exploration Tests",
      "tasks": ["1", "2", "3", "4", "5", "6"],
      "dependencies": ["0.5"],
      "parallelizable": true,
      "description": "Write property-based tests that fail on unfixed code to confirm bugs exist"
    },
    {
      "name": "Wave 3: Preservation Property Tests",
      "tasks": ["7"],
      "dependencies": ["1", "2", "3", "4", "5", "6"],
      "parallelizable": false,
      "description": "Write tests to capture existing behavior that must not break"
    },
    {
      "name": "Wave 4A: VH-002 Implementation (Critical Path)",
      "tasks": ["10.1", "10.2", "10.3", "10.4", "10.5", "10.6", "10.7", "10.8", "11"],
      "dependencies": ["7"],
      "parallelizable": false,
      "description": "Visibility toggle fix - blocks VH-005"
    },
    {
      "name": "Wave 4B: Parallel Bug Fixes",
      "tasks": ["8.1", "8.2", "8.3", "8.4", "8.5", "8.6", "8.7", "9", "12.1", "12.2", "12.3", "12.4", "12.5", "12.6", "13", "14.1", "14.2", "14.3", "14.4", "14.5", "14.6", "15", "18.1", "18.2", "18.3", "18.4", "18.5", "18.6", "18.7", "18.8", "19"],
      "dependencies": ["7"],
      "parallelizable": true,
      "description": "VH-001 (mini player), VH-003 (description), VH-004 (CTA), VH-006 (branding) - independent fixes"
    },
    {
      "name": "Wave 5: VH-005 Implementation (Depends on VH-002)",
      "tasks": ["16.1", "16.2", "16.3", "16.4", "16.5", "16.6", "16.7", "16.8", "16.9", "16.10", "17"],
      "dependencies": ["11"],
      "parallelizable": false,
      "description": "Progress tracker - requires visibility field from VH-002"
    },
    {
      "name": "Wave 6: Cross-Cutting Tasks",
      "tasks": ["20.1", "20.2", "20.3", "20.4", "21.1", "21.2", "21.3", "21.4", "22", "23", "24"],
      "dependencies": ["9", "11", "13", "15", "17", "19"],
      "parallelizable": true,
      "description": "Analytics, design tokens, documentation, asset configuration"
    },
    {
      "name": "Wave 7: Full Test Suite & Static Analysis",
      "tasks": ["25", "26"],
      "dependencies": ["20.1", "20.2", "20.3", "20.4", "21.1", "21.2", "21.3", "21.4", "22", "23", "24"],
      "parallelizable": false,
      "description": "Validate all 1023 tests passing and zero analyzer warnings"
    },
    {
      "name": "Wave 8: Manual Testing - Viewports & Font Scales",
      "tasks": ["27.1", "27.2", "27.3", "27.4", "28.1", "28.2", "28.3"],
      "dependencies": ["25", "26"],
      "parallelizable": true,
      "description": "Test on multiple device sizes and accessibility font scales"
    },
    {
      "name": "Wave 9: Manual Testing - User Flows",
      "tasks": ["29.1", "29.2", "29.3", "29.4", "29.5"],
      "dependencies": ["27.1", "27.2", "27.3", "27.4", "28.1", "28.2", "28.3"],
      "parallelizable": true,
      "description": "End-to-end user flow validation"
    },
    {
      "name": "Wave 10: Performance & Accessibility Audits",
      "tasks": ["30", "31.1", "31.2", "32.1", "32.2", "32.3"],
      "dependencies": ["29.1", "29.2", "29.3", "29.4", "29.5"],
      "parallelizable": true,
      "description": "Visual regression, performance profiling, accessibility compliance"
    },
    {
      "name": "Wave 11: Risk Mitigation & Compliance",
      "tasks": ["33", "34"],
      "dependencies": ["30", "31.1", "31.2", "32.1", "32.2", "32.3"],
      "parallelizable": false,
      "description": "Privacy impact assessment and legal reviews"
    },
    {
      "name": "Wave 12: Final Acceptance Verification",
      "tasks": ["35.1", "35.2", "35.3", "35.4", "35.5", "35.6"],
      "dependencies": ["33", "34"],
      "parallelizable": false,
      "description": "Verify all 6 bugfixes meet acceptance criteria"
    }
  ],
  "criticalPath": [
    "Pre-Flight (0.1-0.5)",
    "Exploration Tests (1-6)",
    "Preservation Tests (7)",
    "VH-002 Implementation (10.1-11)",
    "VH-005 Implementation (16.1-17)",
    "Cross-Cutting (20-24)",
    "Full Test Suite (25-26)",
    "Manual Testing (27-29)",
    "Audits (30-32)",
    "Risk Mitigation (33-34)",
    "Final Verification (35)"
  ],
  "parallelTracks": {
    "afterWave3": [
      "VH-001 (mini player dismiss)",
      "VH-003 (description text)",
      "VH-004 (CTA overflow)",
      "VH-006 (branding)"
    ],
    "note": "VH-002 must complete before VH-005 can start due to visibility field dependency"
  }
}
```

**Critical Path:**
1. Pre-Flight → Phase 1 Exploration → Phase 2 Preservation → VH-002 (visibility) → VH-005 (progress tracker) → Cross-Cutting → Final Testing

**Parallel Tracks:**
- VH-001, VH-003, VH-004, VH-006 can be implemented in parallel after Phase 2
- VH-005 depends on VH-002 Phase 1 (visibility field)
- VH-003 ToS strategy decision gates implementation

---

## Verification Gates

### Pre-Task Gate (Before Each Task)
- [ ] Baseline tests passing
- [ ] No pending analyzer warnings
- [ ] Working branch up to date

### Per-Task Gate (After Each Task)
- [ ] Task implementation complete
- [ ] Affected tests passing
- [ ] No new analyzer warnings
- [ ] Code reviewed (if pair programming)

### Phase Gate (After Each Phase)
- [ ] All phase tasks complete
- [ ] All phase tests passing
- [ ] Integration smoke test passing
- [ ] Performance acceptable

### Final Gate (Before Merge)
- [ ] All 1023 tests passing (991 baseline + 32 new)
- [ ] Zero analyzer errors, zero warnings
- [ ] All 6 bugfixes verified against acceptance criteria
- [ ] Analytics events firing correctly
- [ ] Manual testing complete (viewport sizes, font scales, user flows)
- [ ] Visual regression testing passed
- [ ] Performance profiling passed
- [ ] Accessibility audit passed
- [ ] Risk mitigation validations complete
- [ ] Documentation updated (migration guide, changelog)
- [ ] Code review approved
- [ ] Product owner sign-off

---

## Open Questions & Decisions Required

| ID | Question | Owner | Status | Blocker For |
|----|----------|-------|--------|-------------|
| OQ-01 | Default visibility: Public or Private? | Product | ⬜ Open | VH-002, RISK-PL-01 |
| OQ-02 | ToS notice legally required or can be moved? | Legal | ⬜ Open | VH-003, Task 12.2 |
| OQ-03 | Logo assets available or need generation? | Design | ⬜ Open | VH-006, Task 18.1 |
| OQ-04 | DNA % static or dynamic from profile? | Engineering | ⬜ Open | VH-005 (nice-to-have) |
| OQ-05 | Progress tracker placement: bar or sheet? | Design | ✅ Decided: Bar | VH-005 |

---

## Document Metadata

**Version:** 1.0.0  
**Created:** 2026-10-20  
**Status:** Ready for Implementation  
**Estimated Effort:** 5-7 sprints (2-3 weeks)  
**Team:** Studio Team  
**Next Review:** After Phase 1 completion


---

## Notes

### Known Issues & Caveats

1. **VH-002 Visibility Field Migration**: The migration from `isPublic: bool` to `visibility: String` is a breaking change. The 3-phase migration strategy (add, migrate, remove) is designed to minimize risk but will require coordination across the codebase.

2. **VH-003 ToS Strategy Decision Blocker**: Implementation of VH-003 (Task 12.2) is blocked until legal/product confirms whether the ToS/licensing notice is required for consent. This decision gates the completion of VH-003.

3. **VH-005 Dependency on VH-002**: The progress tracker (VH-005) cannot be implemented until VH-002 Phase 1 is complete because it derives slot states from the `visibility` field. Ensure VH-002 tasks 10.1-10.2 complete before starting VH-005.

4. **VH-006 Logo Asset Generation**: If logo assets are not already available from the design team, Task 18.1 will require additional time for generation, vectorization, and trademark clearance. This could extend the timeline by 3-5 days.

### Follow-Up Items

1. **Backend Visibility Enforcement**: The frontend visibility toggle (VH-002) requires corresponding backend API changes to enforce `visibility: "private"` exclusion from Explore feeds and public profile endpoints. Coordinate with backend team to ensure API changes are deployed simultaneously.

2. **Privacy Impact Assessment**: Complete privacy impact assessment (Task 33) to determine if default visibility should be "public" (current) or "private" (privacy-by-design). This decision affects GDPR/CCPA compliance.

3. **Performance Baseline**: Establish performance baseline metrics (frame render time, gesture response latency) before implementing VH-005 progress tracker to validate that real-time updates meet the <16ms target.

4. **Accessibility Compliance Certification**: After passing internal accessibility audit (Task 32), consider third-party WCAG 2.1 Level AA certification to validate compliance claims.

5. **Analytics Dashboard Setup**: After implementing analytics events (Tasks 20.1-20.4), create dashboard views in Firebase Analytics or equivalent to track dismissal rates, visibility preferences, and progress tracker engagement.

### Technical Debt

1. **Deprecated `isPublic` Field**: The `isPublic` field will remain in `StudioFormState` with `@Deprecated` annotation until Phase 3 of the migration (Week 4). Document removal date in migration guide (Task 22).

2. **ToS Acceptance Storage**: If ToS acceptance modal is implemented (VH-003 Option A), consider migrating from `SharedPreferences` to a more robust user settings storage system in a future iteration.

3. **DNA Percentage Hardcoded**: Task 16.4 includes a hardcoded "25%" DNA usage value. Replace with dynamic value from `CreatorDnaProfile.strength` in a follow-up ticket.

4. **Progress Tracker Slot Definitions**: The 9 parameter slots in `ProgressTrackerState.fromStudioForm()` are hardcoded. Consider extracting to a configuration system if slot definitions change frequently.

### Reference Links

- **Bug Condition Methodology**: See `bugfix.md` Appendix A for formal specification of bug conditions (C), properties (P), and preservation goals (¬C)
- **Design System Tokens**: See `design.md` Appendix A for complete list of `AppColors`, `AppSpacing`, `AppTypography`, `AppRadius`
- **WCAG 2.1 Guidelines**: [https://www.w3.org/WAI/WCAG21/quickref/](https://www.w3.org/WAI/WCAG21/quickref/)
- **Flutter Accessibility**: [https://docs.flutter.dev/development/accessibility-and-localization/accessibility](https://docs.flutter.dev/development/accessibility-and-localization/accessibility)
- **Property-Based Testing**: See design.md for correctness properties that guide test implementation

### Open Questions Requiring Resolution

| ID | Question | Owner | Blocks Task | Target Resolution |
|----|----------|-------|-------------|-------------------|
| OQ-01 | Default visibility: Public or Private? | Product | 10.1 (VH-002) | Before Wave 4A |
| OQ-02 | ToS notice legally required? | Legal | 12.2 (VH-003) | Before Wave 4B |
| OQ-03 | Logo assets available or need generation? | Design | 18.1 (VH-006) | Before Wave 4B |
| OQ-04 | DNA % dynamic from profile? | Engineering | 16.4 (VH-005) | Nice-to-have, not blocking |

### Success Metrics

Track these metrics post-deployment to validate bugfixes:

- **VH-001**: Mini player dismiss rate, keyboard collision incidents (expect 0)
- **VH-002**: Private track creation rate, Explore feed privacy complaints (expect 0)
- **VH-003**: Scroll-to-generate rate on 360×640dp devices (expect <5%)
- **VH-004**: Onboarding completion rate at 360dp (expect >90%)
- **VH-005**: Progress tracker interaction rate, slot tap-to-scroll usage
- **VH-006**: App store listing CTR (logo should improve brand perception)

### Post-Deployment Monitoring

- Monitor Firebase Crashlytics for crashes related to:
  - `PlayerNotifier.dismiss()` audio handler failures
  - `ProgressTrackerState.fromStudioForm()` derivation errors
  - SVG logo loading failures
- Monitor analytics events for:
  - Unusually high `studio_cta_overflow_detected` event volume (indicates responsive layout failure)
  - Low `studio_progress_slot_tapped` event volume (indicates poor discoverability)
  - High `studio_player_dismissed` rate immediately after playback start (indicates unwanted auto-play)

### Rollback Plan

If critical issues are discovered post-deployment:

1. **Severity 1 (Crash/Data Loss)**: Immediate rollback via feature flag or hotfix deployment
2. **Severity 2 (UX Blocker)**: Deploy workaround within 24 hours, schedule proper fix for next sprint
3. **Severity 3 (Minor Issue)**: Document in backlog, address in next release

Feature flags for gradual rollout:

- `enable_mini_player_dismiss` (VH-001)
- `enable_visibility_toggle` (VH-002)
- `enable_progress_tracker` (VH-005)

---

**End of Implementation Tasks Document**

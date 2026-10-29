# Bugfix Requirements Document

## Introduction

This document specifies requirements for fixing 6 critical defects in the **Studio AI Cockpit** and **Persistent Audio Player** identified during field testing on 19 October 2026. These defects affect revenue generation, user privacy, screen real estate efficiency, accessibility compliance, and brand identity.

**Feature Name:** `studio-cockpit-fixes`

**Scope:** Studio cockpit UI/UX, audio transport controls, onboarding Creator DNA flow, and brand identity elements.

**Platform:** Flutter 3.44+ / Dart 3.x / Riverpod state management

**Business Impact:**
- **Revenue Blocker (P0):** Non-functional Public/Private toggle exposes users to unintended visibility, undermining trust in a credit-based platform.
- **Usability Crisis (P0):** Persistent mini player consumes 8% of vertical screen space on the revenue surface (cockpit) with no dismiss mechanism.
- **Accessibility Violation (P0):** CTA button overflow at 360dp width fails WCAG 2.1 Success Criterion 2.5.5 (Target Size).
- **Professional Brand Gap (P1):** Generic "VHUNAMBI Studio" text title crowds header, collides with credits chip, lacks brand identity.
- **Feature Discovery Gap (P1):** No progress tracking or generation completeness feedback creates oversight and abandoned generations.

**Test Preservation Requirements:**
- **991 passing tests** across all features MUST remain green.
- **11 studio unit tests + 2 widget tests** MUST NOT regress.
- **Existing player state tests** MUST NOT break.

---

## Bug Inventory

| Bug ID | Severity | Title | Trigger Condition | Impact | Status |
|--------|----------|-------|-------------------|--------|--------|
| **VH-001** | P0 | Bottom player cannot be closed | Mini player visible AND no dismiss action available | Permanent 90px space loss, keyboard occlusion, layout collision on Create screen | Open |
| **VH-002** | P0 | Public/Private toggle non-functional | Toggle rendered AND `onChanged` handler does not persist visibility to track record | Privacy risk, discovery visibility mismatch, consent violation | Open |
| **VH-003** | P0 | Description text wastes vertical space | Action bar rendered AND two description paragraphs push controls below fold | Cockpit unusable on 360×640dp devices, prompt field requires scroll | Open |
| **VH-004** | P0 | Creator DNA CTA overflows screen edge | Onboarding final page rendered at 360dp width AND page dots + unbounded button exceed viewport | Button clipped, CTA inaccessible, WCAG 2.5.5 violation | Open |
| **VH-005** | P1 | No real-time song progress tracker | User configuring generation parameters AND no visual feedback on completeness | Oversight errors, incomplete generations, abandoned sessions | Open |
| **VH-006** | P1 | Studio branding lacks logo asset | Header rendered with text title "VHUNAMBI Studio" AND generic music-note icon | Non-professional appearance, credits chip collision at 360dp, brand identity gap | Open |

---

## Bug Analysis

### Current Behavior (Defect)

**VH-001: Bottom Player Cannot Be Closed**

1.1 WHEN a track is playing OR paused AND the mini player is visible THEN the system renders a persistent 90px dock above the bottom navigation with no dismiss control

1.2 WHEN the user is on the Create screen AND the mini player is docked AND the keyboard opens THEN the system does not hide the player, causing layout collision and obscuring the prompt input field

1.3 WHEN the user attempts to interact with cockpit controls near the bottom 25% of the viewport AND the mini player is docked THEN the available scrollable area is reduced from ~67% to ~33% of screen height

**VH-002: Public/Private Toggle Non-Functional**

1.4 WHEN the user toggles the "Public" switch in `StudioActionBar` THEN the system updates `StudioFormState.isPublic` in memory but does not persist the visibility field to the generation request or track record

1.5 WHEN a track is generated with the toggle in the OFF state (Private) THEN the system generates the track with undefined or default visibility, and the track may appear on Explore feeds and public profiles contrary to user intent

1.6 WHEN the user enters "Write Lyrics First" flow AND returns to the cockpit THEN the system MAY reset the toggle state to default (Public), losing the user's privacy selection

**VH-003: Description Text Wastes Vertical Space**

1.7 WHEN `StudioActionBar` is rendered AND lyrics mode is "AI Write" THEN the system displays two description paragraphs totaling ~190px (~8% of a 2310px screen): (a) "AI writes the lyrics → you review & edit → then the beat is produced" and (b) "By generating, you agree to our Terms of Service. You own 100% of what you create on paid plans. See licensing →"

1.8 WHEN the device viewport is 360×640dp AND the mini player is docked AND the description paragraphs are visible THEN the prompt input field, genre/mood controls, and primary CTA button are pushed below the fold, requiring vertical scroll to access

1.9 WHEN the user attempts to configure generation parameters on a small device THEN the effective usable cockpit area is reduced to ~33% of screen height due to the combined space consumption of the mini player (90px) and description text (190px)

**VH-004: Creator DNA CTA Overflows Screen Edge**

1.10 WHEN the user navigates to the final onboarding page ("Creator DNA") at 360dp viewport width AND the page indicator dots are rendered on the left AND the "Activate Creator DNA ✨ →" button is rendered THEN the button extends past the right edge of the screen and is clipped

1.11 WHEN the system font scale is set to 130% (large text accessibility setting) AND the CTA button is rendered THEN the button label overflows its container and becomes partially or fully inaccessible

1.12 WHEN the button is clipped THEN tap targets fail WCAG 2.1 Success Criterion 2.5.5 (Target Size — Enhanced, Level AAA: minimum 44×44 CSS pixels) because the visible and interactive area is reduced below the minimum accessible target size

**VH-005: No Real-Time Song Progress Tracker**

1.13 WHEN the user is configuring generation parameters in the studio cockpit AND multiple optional fields are available (prompt, genre, mood, tempo, vocal energy, language, lyrics mode, DNA usage percentage, visibility) THEN the system provides no visual feedback indicating which parameters have been set, which are empty, and which are auto-filled by Creator DNA

1.14 WHEN the user leaves optional parameters empty (e.g., no mood selected, default tempo, no custom lyrics) AND taps "Generate Song" THEN the system accepts the generation request without warning or completeness indicator, potentially resulting in generic output that does not match user intent

1.15 WHEN the user has configured 6 out of 9 parameters AND has not interacted with mood, language, or lyrics THEN the system provides no signal that additional options are available to refine the generation

**VH-006: Studio Branding Lacks Logo Asset**

1.16 WHEN the studio cockpit header is rendered THEN the system displays the text "VHUNAMBI Studio" next to a generic music-note icon (`Icons.music_note`), consuming ~160-180px of horizontal space

1.17 WHEN the viewport width is 360dp AND the header contains the text title, generic icon, AND credits chip THEN the credits chip is positioned within 8-12px of the text title, creating visual collision and crowding

1.18 WHEN the app is viewed by first-time users or in app store screenshots THEN the generic text title lacks professional brand identity, diminishing perceived product quality and trustworthiness

### Expected Behavior (Correct)

**VH-001: Bottom Player Dismiss Control**

2.1 WHEN a track is playing or paused AND the mini player is visible THEN the system SHALL provide a dismiss control (close button or swipe-down gesture) that stops playback, releases the audio session, clears player state, and removes the mini player within one frame

2.2 WHEN the user dismisses the player THEN the system SHALL animate the mini player out, reflow the cockpit layout to reclaim the freed vertical space, and persist the dismissed state until the next playback action

2.3 WHEN the user starts playback of any track after dismissal THEN the system SHALL re-render the mini player in its default docked position

2.4 WHEN the keyboard opens on the Create screen AND the mini player is visible THEN the system SHALL temporarily hide the mini player until the keyboard closes

**VH-002: Public/Private Toggle Functionality**

2.5 WHEN the user toggles the "Public" switch to ON THEN the system SHALL update `StudioFormState.isPublic` to `true`, persist the selection across navigation, and include `visibility: "public"` in the generation request payload

2.6 WHEN the user toggles the "Public" switch to OFF THEN the system SHALL update `StudioFormState.isPublic` to `false`, update the subtitle text to "Only you can see this", persist the selection, and include `visibility: "private"` in the generation request payload

2.7 WHEN a track is generated with `visibility: "private"` THEN the backend API SHALL enforce exclusion of the track from Explore feeds, public profile endpoints, and social discovery surfaces

2.8 WHEN a track is generated with `visibility: "public"` THEN the backend API SHALL include the track in Explore feeds and the creator's public profile endpoint

2.9 WHEN the user enters "Write Lyrics First" flow AND approves lyrics AND returns to beat generation THEN the system SHALL preserve the original visibility toggle state without resetting to default

2.10 WHEN the system renders the toggle subtitle THEN it SHALL display "Visible on Explore & your profile" when `isPublic == true` OR "Only you can see this" when `isPublic == false`

**VH-003: Description Text Removal**

2.11 WHEN `StudioActionBar` is rendered THEN the system SHALL remove the AI lyrics flow explanation paragraph ("AI writes the lyrics → you review & edit → then the beat is produced") as the button label "Write Lyrics First" is self-explanatory

2.12 WHEN the ToS/licensing notice is legally required for generation consent THEN the system SHALL retain it as a single compact footer line with reduced font size (10sp) and tertiary text color, OR move it to a one-time acceptance flow at first generation, OR display it in a dismissible tooltip on first cockpit entry

2.13 WHEN the ToS/licensing notice is not legally required for consent THEN the system SHALL remove it entirely and link to Terms from the app footer or Settings

2.14 WHEN `StudioActionBar` is rendered on a 360×640dp device with the mini player dismissed THEN the prompt field, Public toggle, and primary CTA button SHALL be fully visible without requiring vertical scroll

2.15 WHEN the description paragraphs are removed THEN the `StudioActionBar` column height SHALL shrink to contain only: (a) Public toggle card (~56px), (b) spacing (12px), (c) primary CTA button (52px), (d) optional ToS footer (single line, ~24px if retained)

**VH-004: Creator DNA CTA Responsive Layout**

2.16 WHEN the final onboarding page is rendered at any viewport width (360dp to 1920dp) AND at any system font scale (100% to 200%) THEN the "Activate Creator DNA" CTA button SHALL be fully visible with a minimum right margin of 16dp to 24dp from the screen edge

2.17 WHEN the CTA button is rendered THEN its container SHALL apply a flexible/expanded constraint with a bounded maximum width calculated as: `max(screenWidth - pageDotsWidth - leftMargin - rightMargin, 280dp)` to ensure horizontal containment

2.18 WHEN the button label text exceeds the available width at large font scales THEN the system SHALL either: (a) shorten the label to "Activate Creator DNA →" (remove emoji), OR (b) allow the text to wrap to two lines with centered alignment and increased button height

2.19 WHEN the button is rendered at 360dp width and 130% font scale THEN the full button SHALL be tappable with a minimum 44×44 CSS pixel hit target area

**VH-005: Real-Time Progress Tracker**

2.20 WHEN the studio cockpit is rendered THEN the system SHALL display a compact, always-visible progress element that tracks the completeness of 9 parameter slots: (a) Description/prompt, (b) Genre/heritage, (c) Mood, (d) Tempo feel, (e) Vocal energy, (f) Language/dialect, (g) Lyrics (written or skipped), (h) DNA usage percentage, (i) Visibility (public/private)

2.21 WHEN a parameter slot is configured THEN the system SHALL mark it as **Set** (user-configured) with a visual indicator (e.g., filled circle, checkmark, or progress segment), fire a light haptic tick on state transition, and update the overall completeness ratio (e.g., "6/9" or "67%")

2.22 WHEN a parameter slot is auto-filled by Creator DNA presets THEN the system SHALL mark it as **Auto** (DNA-suggested) with a distinct visual indicator (e.g., filled circle with DNA icon, or tinted color), and include it in the filled count

2.23 WHEN a parameter slot is empty (not set by user or DNA) THEN the system SHALL mark it as **Empty** with a visual indicator (e.g., empty circle or greyed segment)

2.24 WHEN the user taps a slot in the progress tracker THEN the system SHALL scroll to or expand the corresponding parameter control in the cockpit (e.g., tapping "Mood" opens the mood selector)

2.25 WHEN the user configures or clears a parameter THEN the progress tracker SHALL update within one frame (<16ms at 60fps) to reflect the new state

2.26 WHEN the user taps "Generate Song" AND fewer than 9 slots are filled THEN the primary CTA button MAY display a soft hint (e.g., "3 options still open") to raise awareness of available refinements without blocking generation

2.27 WHEN the progress element is collapsed THEN it SHALL render as a slim segmented bar pinned under the Compose/Voice/Crate tabs, ~8-12dp tall, showing the filled/total ratio and a DNA % chip

2.28 WHEN the progress element is expanded (user taps the bar) THEN it SHALL display a scrollable list of all 9 slots with slot name, current value, and state indicator (Empty/Set/Auto)

**VH-006: Professional Brand Identity**

2.29 WHEN the studio cockpit header is rendered THEN the system SHALL replace the text "VHUNAMBI Studio" with a compact brand mark (logo) asset, reducing horizontal space consumption to ~80-100px and providing 60-80px of additional clearance for the credits chip

2.30 WHEN the compact brand mark is rendered in the header THEN it SHALL be an SVG vector asset with light and dark mode variants, using the orange brand accent (#F97316 or `AppColors.brandPrimary`) as the primary color

2.31 WHEN the full lockup logo (wordmark + icon) is rendered on splash screen or onboarding pages THEN it SHALL use the complete Vhunambi wordmark with clear spacing and legibility at 240-320px width

2.32 WHEN the adaptive launcher icon is generated for Android THEN it SHALL provide foreground and background layers at 108×108dp safe zone (72×72dp visible) with the logo centered and scaled to 56-64dp, and a solid or gradient background using `AppColors.backgroundPrimary` or `AppGradients.amapiano`

2.33 WHEN the logo assets are delivered THEN they SHALL include: (a) compact mark SVG (header), (b) full lockup SVG (splash/onboarding), (c) PNG @1x/2x/3x for legacy compatibility, (d) adaptive launcher icon (foreground + background XML), and (e) light/dark variants for each

2.34 WHEN the logo is finalized THEN it SHALL pass a trademark conflict search and be cleared for commercial use in app store listings, marketing materials, and in-app branding

### Unchanged Behavior (Regression Prevention)

**VH-001: Player Transport Controls**

3.1 WHEN the user taps the mini player body THEN the system SHALL CONTINUE TO open the expanded Now Playing cockpit modal

3.2 WHEN the user taps skip-previous, play/pause, or skip-next controls THEN the system SHALL CONTINUE TO execute the respective transport action with haptic feedback

3.3 WHEN the user swipes horizontally on the mini player body THEN the system SHALL CONTINUE TO skip to previous (swipe right with velocity > 250) or next (swipe left with velocity < -250) track

3.4 WHEN the mini player is visible AND a track is playing THEN the system SHALL CONTINUE TO update the progress bar and time labels in real-time

**VH-002: Studio Generation Flow**

3.5 WHEN the user taps the "Write Lyrics First" button THEN the system SHALL CONTINUE TO initiate lyrics generation, open the `LyricsReviewModal`, and queue beat production after approval

3.6 WHEN the user taps the "Generate Song" button (instrumental or custom lyrics mode) THEN the system SHALL CONTINUE TO trigger direct beat generation without lyrics review

3.7 WHEN the user interacts with the toggle switch THEN the system SHALL CONTINUE TO fire `HapticFeedback.selectionClick()` on state change

**VH-003: Action Bar Behavior**

3.8 WHEN the user taps the primary CTA button THEN the system SHALL CONTINUE TO trigger lyrics generation or beat generation based on the selected lyrics mode

3.9 WHEN the Public toggle is interacted with THEN the system SHALL CONTINUE TO update `isPublic` state and persist the selection (per VH-002 fix)

3.10 WHEN the action bar is rendered in instrumental mode OR "My Own Lyrics" mode THEN the system SHALL CONTINUE TO display the "Generate Song" label instead of "Write Lyrics First"

**VH-004: Onboarding Flow**

3.11 WHEN the user taps the "Activate Creator DNA" button THEN the system SHALL CONTINUE TO complete onboarding, persist the user's DNA profile (role, genres, tempo, vocal feel, mood), and navigate to the main app shell

3.12 WHEN the page indicator dots are rendered THEN they SHALL CONTINUE TO show the current page position (6 total pages) and remain visible on the left side of the footer

3.13 WHEN the user swipes horizontally on the onboarding page content (outside the CTA button bounds) THEN the system SHALL CONTINUE TO navigate between onboarding pages

**VH-005: Studio Parameter Management**

3.14 WHEN the user taps "Generate Song" with empty slots THEN the system SHALL CONTINUE TO accept the generation request and apply default or DNA-suggested values for unfilled parameters (generation is never blocked by empty slots)

3.15 WHEN the user switches between Compose, Voice, and Crate tabs THEN the system SHALL CONTINUE TO preserve all configured parameter values and persist them in `StudioFormState`

3.16 WHEN the progress tracker state updates THEN the system SHALL derive its values from `StudioFormState` (single source of truth) without duplicating or caching parameter state in a separate notifier

**VH-006: Header Navigation**

3.17 WHEN the header is rendered THEN the system SHALL CONTINUE TO display the credits chip on the trailing side (right) with current balance and a CTA to purchase credits

3.18 WHEN the user taps the credits chip THEN the system SHALL CONTINUE TO open the subscription upgrade modal or credits purchase flow

3.19 WHEN the header is rendered on desktop viewports (>1024dp) THEN the system SHALL CONTINUE TO apply responsive spacing and scale the logo appropriately for larger screens

---

## Cross-Cutting Requirements

### Design System Compliance

**REQ-DST-01:** All color values SHALL use tokens from `AppColors` (e.g., `AppColors.brandPrimary`, `AppColors.textSecondary`, `AppColors.surfaceElevated`). No hardcoded hex colors are permitted.

**REQ-DST-02:** All spacing values SHALL use tokens from `AppSpacing` (e.g., `AppSpacing.sm`, `AppSpacing.md`, `AppSpacing.lg`). No hardcoded pixel values are permitted except for component-specific constraints (e.g., 44px minimum touch targets).

**REQ-DST-03:** All typography SHALL use styles from `AppTypography` (e.g., `AppTypography.bodyLarge`, `AppTypography.caption`, `AppTypography.titleMedium`) with explicit color overrides via `.copyWith(color: ...)` when needed.

**REQ-DST-04:** All border radii SHALL use tokens from `AppRadius` (e.g., `AppRadius.cardBorder`, `AppRadius.pillBorder`).

### State Management Invariants

**REQ-STM-01:** `StudioFormState` SHALL remain the single source of truth for all cockpit parameter values. The progress tracker (VH-005) SHALL derive its slot states by inspecting `StudioFormState` fields, not by maintaining duplicate state.

**REQ-STM-02:** The `visibility` field SHALL be added to `StudioFormState` as a `String` enum with values `"public"` or `"private"`, defaulting to `"public"` (subject to product review per VH-002 open question).

**REQ-STM-03:** The `isPublic` boolean field in `StudioFormState` SHALL be replaced with `visibility` to align with backend API schema and prevent boolean-to-string mapping errors.

**REQ-STM-04:** The `StudioFormNotifier.togglePublic(bool)` method SHALL be renamed to `setVisibility(String)` to accept `"public"` or `"private"` values directly.

**REQ-STM-05:** When the user approves lyrics via `StudioFormNotifier.approveLyrics(String lyrics)`, the visibility field SHALL be preserved from the current state without resetting to default.

### Analytics Events

**REQ-ANL-01:** A new analytics event `studio_player_dismissed` SHALL be fired when the user dismisses the mini player (VH-001), including fields: `track_id`, `playback_position_sec`, `dismiss_method` ("swipe_down" | "button").

**REQ-ANL-02:** A new analytics event `studio_visibility_toggled` SHALL be fired when the user changes the Public/Private toggle (VH-002), including fields: `visibility` ("public" | "private"), `lyrics_mode`, `genre`.

**REQ-ANL-03:** A new analytics event `studio_progress_slot_tapped` SHALL be fired when the user taps a slot in the progress tracker (VH-005), including fields: `slot_name`, `slot_state` ("empty" | "set" | "auto"), `completeness_ratio`.

**REQ-ANL-04:** A new analytics event `studio_cta_overflow_detected` SHALL be fired if the onboarding CTA button's rendered width exceeds the viewport bounds (VH-004), including fields: `viewport_width`, `button_width`, `font_scale`.

### Accessibility Requirements

**REQ-A11Y-01:** All interactive controls (buttons, toggles, IconButtons) SHALL have a minimum touch target size of 44×44 CSS pixels per WCAG 2.1 SC 2.5.5 (Level AAA).

**REQ-A11Y-02:** The mini player dismiss gesture (swipe-down) SHALL be supplemented with a visible close button or semantic action (`Semantics.customSemanticsActions`) for users who cannot perform gestures.

**REQ-A11Y-03:** The progress tracker slots (VH-005) SHALL expose semantic labels via `Semantics` widget (e.g., "Prompt: Set", "Mood: Empty", "Lyrics: Auto from DNA") for screen readers.

**REQ-A11Y-04:** The onboarding CTA button SHALL remain fully tappable and legible at 200% system font scale without clipping or overflow.

**REQ-A11Y-05:** All haptic feedback calls (`HapticFeedback.lightImpact()`, `HapticFeedback.mediumImpact()`, `HapticFeedback.selectionClick()`) SHALL respect the system haptics setting and degrade gracefully when haptics are disabled.

### Responsive Breakpoints

**REQ-RWD-01:** The studio cockpit layout SHALL be tested and verified at the following viewport sizes: 360×640dp (small phone), 375×812dp (iPhone SE/13 mini), 414×896dp (iPhone 11/12/13), 768×1024dp (iPad), 1280×720dp (desktop).

**REQ-RWD-02:** On viewports ≥ 768dp width, the progress tracker (VH-005) MAY render as a persistent sidebar instead of a collapsible bar, providing always-visible completeness feedback on larger screens.

**REQ-RWD-03:** The mini player (VH-001) SHALL hide when the keyboard is visible (`MediaQuery.of(context).viewInsets.bottom > 0`) to prevent layout collision, and reappear when the keyboard dismisses.

---

## Verification Strategy

### Unit Test Requirements

**REQ-UT-01:** A new unit test `studio_form_notifier_test.dart::test_setVisibility_persistsState()` SHALL verify that calling `setVisibility("private")` updates `StudioFormState.visibility` to `"private"` and the state change is emitted to listeners.

**REQ-UT-02:** A new unit test `studio_form_notifier_test.dart::test_approveLyrics_preservesVisibility()` SHALL verify that approving lyrics does not reset the visibility field to default.

**REQ-UT-03:** A new unit test `player_provider_test.dart::test_dismiss_stopsPlaybackAndClearsState()` SHALL verify that calling `PlayerStateNotifier.dismiss()` sets `isPlaying` to false, clears `currentTrack`, and emits a state with `hasActiveTrack == false`.

**REQ-UT-04:** A new unit test `progress_tracker_test.dart::test_slotState_derivedFromStudioForm()` SHALL verify that the progress tracker's slot states (Empty/Set/Auto) are correctly derived from `StudioFormState` field values without duplicating state.

### Widget Test Requirements

**REQ-WT-01:** A new widget test `studio_action_bar_test.dart::test_publicToggle_updatesVisibility()` SHALL verify that tapping the Public toggle calls `StudioFormNotifier.setVisibility()` with the correct value and the subtitle text updates to match the new state.

**REQ-WT-02:** A new widget test `studio_action_bar_test.dart::test_descriptionText_removed()` SHALL verify that the AI lyrics flow explanation paragraph is not rendered in the widget tree, and the action bar height is reduced accordingly.

**REQ-WT-03:** A new widget test `mobile_mini_player_test.dart::test_swipeDown_dismissesPlayer()` SHALL verify that a vertical swipe-down gesture with velocity > 250 calls `PlayerStateNotifier.dismiss()` and the player widget is removed from the tree.

**REQ-WT-04:** A new widget test `mobile_mini_player_test.dart::test_keyboard_hidesPlayer()` SHALL simulate keyboard opening by setting `MediaQuery.viewInsets.bottom` to 300 and verify the player is hidden.

**REQ-WT-05:** A new widget test `onboarding_view_test.dart::test_dnaCta_noOverflow_360dp()` SHALL render the final onboarding page at 360dp width and verify the "Activate Creator DNA" button's right edge is at least 16dp from the screen edge.

**REQ-WT-06:** A new widget test `onboarding_view_test.dart::test_dnaCta_accessible_largeFontScale()` SHALL render the final onboarding page at 130% font scale and verify the button remains fully tappable with a 44×44 hit target.

**REQ-WT-07:** A new widget test `progress_tracker_test.dart::test_slotTap_scrollsToControl()` SHALL verify that tapping a slot in the progress tracker calls a scroll or focus callback to navigate to the corresponding parameter control.

### Integration Test Requirements

**REQ-IT-01:** A new integration test `studio_to_player_flow_test.dart` SHALL verify the complete flow: (1) configure studio parameters, (2) set visibility to Private, (3) trigger generation, (4) verify the mini player appears with the generated track, (5) swipe down to dismiss, (6) verify the player is removed and the cockpit layout reflows.

**REQ-IT-02:** A new integration test `lyrics_review_preserves_visibility_test.dart` SHALL verify: (1) set visibility to Private, (2) tap "Write Lyrics First", (3) approve generated lyrics, (4) verify visibility remains Private in the final generation request.

### Regression Prevention

**REQ-RGN-01:** The full test suite (991 tests) SHALL be executed after implementing each bug fix, and zero test failures are permitted before merging.

**REQ-RGN-02:** The `flutter analyze` gate SHALL report zero errors and zero warnings after implementing all fixes.

**REQ-RGN-03:** Existing widget tests for `StudioActionBar`, `MobileMiniPlayer`, and `OnboardingView` SHALL NOT require modification unless they explicitly test defective behavior that is being corrected.

---

## Risk & Compliance Assessment

### Breaking Changes

**RISK-BC-01:** Replacing `StudioFormState.isPublic: bool` with `visibility: String` is a breaking change to the state model. Migration strategy: (a) add `visibility` field alongside `isPublic` in phase 1, (b) update all call sites to use `visibility` in phase 2, (c) deprecate and remove `isPublic` in phase 3.

**RISK-BC-02:** Removing the description text (VH-003) may violate legal consent requirements if the ToS/licensing notice is the user's only exposure to terms before credit-consuming generation. **MITIGATION:** Confirm with legal/product whether the notice is required, and if so, retain it as a single compact line or move to a one-time acceptance modal.

### Privacy & Legal Compliance

**RISK-PL-01:** The Public/Private toggle (VH-002) defaults to Public, which may violate GDPR, CCPA, or regional privacy laws if users expect generated content to be private by default. **MITIGATION:** Conduct a privacy impact assessment and consider defaulting to Private with an explicit opt-in to Public visibility.

**RISK-PL-02:** The Creator DNA onboarding page claims "100% on-device sovereignty (zero cloud tracking)" (per source spec VH-013). This claim is inconsistent with server-side generation, analytics, and credit tracking. **MITIGATION:** Audit actual data flows and reword the claim to accurately reflect what is stored on-device versus sent to the server (e.g., "Your DNA profile is stored on your device").

### Performance Impact

**RISK-PF-01:** The real-time progress tracker (VH-005) updates on every parameter change, potentially triggering 9-slot UI rebuilds at 60fps. **MITIGATION:** Use `const` constructors for static slot widgets, wrap the tracker in a `RepaintBoundary`, and throttle updates to 30fps if performance degrades on mid-range devices.

**RISK-PF-02:** Adding a vertical swipe-down dismiss gesture to the mini player (VH-001) introduces a new gesture arena that must disambiguate from horizontal skip swipes and the page-level scroll gesture. **MITIGATION:** Use `GestureDetector.onVerticalDragEnd` with velocity threshold (> 250) and direction locking after 24dp travel to prevent false positives.

### Accessibility Compliance

**RISK-AC-01:** Relying solely on a swipe-down gesture to dismiss the player (VH-001) violates WCAG 2.1 SC 2.1.1 (Keyboard) and SC 2.5.1 (Pointer Gestures) for users who cannot perform gestures. **MITIGATION:** Provide an alternative dismiss mechanism via a visible close button or semantic action.

**RISK-AC-02:** The onboarding CTA button (VH-004) failing to meet 44×44 minimum touch target size at 130% font scale violates WCAG 2.1 SC 2.5.5. **MITIGATION:** Apply flexible layout constraints and test at 200% font scale to ensure compliance.

---

## Open Questions & Product Decisions

**OQ-01:** Should the default visibility for new tracks be Public or Private? Current implementation defaults to Public (`isPublic: true` in `StudioFormState`), which may not align with user privacy expectations.

**OQ-02:** Is the ToS/licensing notice in `StudioActionBar` legally required as a consent mechanism before credit-consuming generation, or can it be moved to a one-time acceptance flow or Settings link?

**OQ-03:** Should the mini player dismiss gesture (VH-001) be a swipe-down gesture, a visible close button, or both? Swipe-down saves horizontal space for 44×44 transport controls, but a button provides better accessibility.

**OQ-04:** What is the desired placement for the progress tracker (VH-005): a slim bar pinned under the Compose/Voice/Crate tabs (recommended), or a collapsible bottom sheet? The slim bar provides always-visible feedback without obscuring controls.

**OQ-05:** Are logo assets (VH-006) already available in the design system, or do they need to be generated/vectorized? If generation is required, should the wordmark use a specific typeface or geometric construction?

**OQ-06:** Should the progress tracker (VH-005) distinguish between "Auto" (DNA-suggested) and "Set" (user-configured) slots with different colors or icons, or is a single "Filled" state sufficient?

---

## Appendix A: Bug Condition Formalization

### VH-001: Bottom Player Dismiss

**Bug Condition C(X):**
```pascal
FUNCTION isBugCondition(X)
  INPUT: X of type PlayerState
  OUTPUT: boolean
  
  RETURN (X.hasActiveTrack == true) AND (dismissControl == null)
END FUNCTION
```

**Property Specification P(result):**
```pascal
// Property: Fix Checking
FOR ALL X WHERE isBugCondition(X) DO
  result ← PlayerWithDismiss'(X)
  ASSERT result.hasDismissControl == true AND 
         dismissAction.stopsPlayback == true AND
         dismissAction.releasesSes == true AND
         dismissAction.clearsState == true
END FOR
```

**Preservation Goal:**
```pascal
// Property: Preservation Checking
FOR ALL X WHERE NOT isBugCondition(X) DO
  ASSERT PlayerState.transportControls(X) == PlayerState.transportControls(X')
  ASSERT PlayerState.expandAction(X) == PlayerState.expandAction(X')
  ASSERT PlayerState.skipGestures(X) == PlayerState.skipGestures(X')
END FOR
```

**Concrete Counterexample:**
- **Input:** User generates a track, playback starts, mini player appears, user navigates to Create screen, keyboard opens
- **Current (F):** Mini player remains visible, obscures prompt field, no dismiss action available
- **Expected (F'):** Mini player hides when keyboard opens, reappears when keyboard closes, swipe-down gesture dismisses player and stops playback

---

### VH-002: Public/Private Toggle

**Bug Condition C(X):**
```pascal
FUNCTION isBugCondition(X)
  INPUT: X of type StudioFormState
  OUTPUT: boolean
  
  RETURN (X.isPublic == false) AND (generationRequest.visibility == undefined OR generationRequest.visibility == "public")
END FUNCTION
```

**Property Specification P(result):**
```pascal
// Property: Fix Checking
FOR ALL X WHERE isBugCondition(X) DO
  result ← GenerationWithVisibility'(X)
  ASSERT result.request.visibility == "private" AND
         result.track.excludedFromExplore == true AND
         result.track.excludedFromPublicProfile == true
END FOR
```

**Preservation Goal:**
```pascal
// Property: Preservation Checking
FOR ALL X WHERE NOT isBugCondition(X) DO
  ASSERT StudioFormState.lyricsFlow(X) == StudioFormState.lyricsFlow(X')
  ASSERT StudioFormState.generationTrigger(X) == StudioFormState.generationTrigger(X')
  ASSERT StudioFormState.hapticFeedback(X) == StudioFormState.hapticFeedback(X')
END FOR
```

**Concrete Counterexample:**
- **Input:** User toggles Public switch to OFF, sets visibility to Private, taps "Generate Song"
- **Current (F):** Toggle updates UI state but does not persist to generation request, track appears on Explore feed
- **Expected (F'):** Toggle updates `visibility: "private"`, backend enforces exclusion, track only visible in Library

---

### VH-003: Description Text Space Consumption

**Bug Condition C(X):**
```pascal
FUNCTION isBugCondition(X)
  INPUT: X of type ViewportConstraints
  OUTPUT: boolean
  
  RETURN (X.height == 640dp) AND (miniPlayerHeight == 90dp) AND (descriptionParagraphsHeight == 190px) AND (usableCockpitArea < 50%)
END FUNCTION
```

**Property Specification P(result):**
```pascal
// Property: Fix Checking
FOR ALL X WHERE isBugCondition(X) DO
  result ← ActionBarWithoutDescription'(X)
  ASSERT result.promptFieldVisible == true AND
         result.toggleVisible == true AND
         result.ctaButtonVisible == true AND
         noScrollRequired(result, X.height)
END FOR
```

**Preservation Goal:**
```pascal
// Property: Preservation Checking
FOR ALL X WHERE NOT isBugCondition(X) DO
  ASSERT StudioActionBar.ctaAction(X) == StudioActionBar.ctaAction(X')
  ASSERT StudioActionBar.toggleAction(X) == StudioActionBar.toggleAction(X')
  ASSERT StudioActionBar.lyricsFlowLogic(X) == StudioActionBar.lyricsFlowLogic(X')
END FOR
```

**Concrete Counterexample:**
- **Input:** Device viewport 360×640dp, mini player docked (90px), description paragraphs visible (190px)
- **Current (F):** Prompt field and CTA button below fold, requires scroll, usable area ~33%
- **Expected (F'):** Description removed, usable area ~59%, all controls visible without scroll

---

### VH-004: CTA Button Overflow

**Bug Condition C(X):**
```pascal
FUNCTION isBugCondition(X)
  INPUT: X of type OnboardingPageConstraints
  OUTPUT: boolean
  
  RETURN (X.viewportWidth == 360dp) AND (pageDotsWidth + buttonWidth + margins > X.viewportWidth)
END FUNCTION
```

**Property Specification P(result):**
```pascal
// Property: Fix Checking
FOR ALL X WHERE isBugCondition(X) DO
  result ← ButtonWithFlexConstraint'(X)
  ASSERT result.buttonRightEdge <= (X.viewportWidth - 16dp) AND
         result.buttonHitTargetArea >= (44 * 44) AND
         noOverflow(result.buttonLabel)
END FOR
```

**Preservation Goal:**
```pascal
// Property: Preservation Checking
FOR ALL X WHERE NOT isBugCondition(X) DO
  ASSERT OnboardingView.ctaAction(X) == OnboardingView.ctaAction(X')
  ASSERT OnboardingView.pageIndicators(X) == OnboardingView.pageIndicators(X')
  ASSERT OnboardingView.pageNavigation(X) == OnboardingView.pageNavigation(X')
END FOR
```

**Concrete Counterexample:**
- **Input:** Viewport 360dp, font scale 130%, page dots 48dp, button label "Activate Creator DNA ✨ →" 280dp
- **Current (F):** Button extends to 328dp, clipped at 360dp, right 32dp inaccessible
- **Expected (F'):** Button constrained to max 280dp, right margin 16dp, full button tappable

---

## Appendix B: Affected Files

| File Path | Change Type | Bug ID |
|-----------|-------------|--------|
| `lib/features/player/presentation/widgets/mobile_mini_player.dart` | Modify | VH-001 |
| `lib/features/player/presentation/providers/player_provider.dart` | Modify | VH-001 |
| `lib/features/studio/domain/models/studio_form_state.dart` | Modify | VH-002 |
| `lib/features/studio/presentation/providers/studio_form_provider.dart` | Modify | VH-002 |
| `lib/features/studio/presentation/widgets/studio_action_bar.dart` | Modify | VH-002, VH-003 |
| `lib/features/onboarding/presentation/views/onboarding_view.dart` | Modify | VH-004 |
| `lib/features/studio/presentation/widgets/progress_tracker.dart` | Create | VH-005 |
| `lib/features/studio/presentation/providers/progress_tracker_provider.dart` | Create | VH-005 |
| `lib/core/widgets/vhunambi_app_bar.dart` | Modify | VH-006 |
| `assets/logos/vhunambi_compact_mark.svg` | Create | VH-006 |
| `assets/logos/vhunambi_full_lockup.svg` | Create | VH-006 |
| `android/app/src/main/res/mipmap-*/ic_launcher_foreground.png` | Create | VH-006 |
| `test/features/studio/presentation/widgets/studio_action_bar_test.dart` | Modify | VH-002, VH-003 |
| `test/features/player/presentation/widgets/mobile_mini_player_test.dart` | Modify | VH-001 |
| `test/features/onboarding/presentation/views/onboarding_view_test.dart` | Modify | VH-004 |
| `test/features/studio/presentation/widgets/progress_tracker_test.dart` | Create | VH-005 |

---

**Document Version:** 1.0.0  
**Last Updated:** 2026-10-20  
**Status:** Ready for Design Phase  
**Next Phase:** Design Document (design.md) — Technical architecture, component specifications, and implementation strategy

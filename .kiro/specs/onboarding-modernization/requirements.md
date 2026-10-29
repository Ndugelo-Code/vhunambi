# Requirements Document

## Introduction

**Feature Name:** Onboarding Experience Modernization  
**Feature ID:** `onboarding-modernization`  
**Document Version:** 1.0.0  
**Status:** Draft  
**Author:** Principal Mobile Systems Architect  
**Date:** 2025-01-19

### Purpose & Business Impact

The Onboarding Experience Modernization addresses 7 critical UX enhancements (VH-007 through VH-013) identified during field testing on 2026-10-19. These enhancements focus on increasing user activation, engagement, and legal compliance by transforming the onboarding flow from a functional questionnaire into an immersive, visually rich brand experience that educates users about Vhunambi's unique capabilities.

**Business Metrics Targeted:**
- **Activation Rate:** Increase percentage of users completing onboarding from current baseline to >85%
- **Time to First Generation:** Reduce friction by improving feature discoverability through the app tour
- **Brand Recall:** Strengthen emotional connection through genre/mood color systems and DNA visualization
- **Legal Risk:** Eliminate misleading privacy claims that pose store review and compliance risk

**User Value Proposition:**
- Intuitive gesture-rich UI (horizontal carousel, haptic feedback)
- Natural language descriptions (replace technical BPM jargon)
- Visual understanding of Creator DNA's role in personalization
- Upfront feature awareness (no hidden capabilities)
- Trust through honest, accurate privacy statements

### Scope & Deliverables

This specification covers:

1. **VH-007 (P1):** Creative Identity horizontal card carousel with haptic feedback
2. **VH-008 (P2):** Genre Heritage per-genre color token system
3. **VH-009 (P1):** Sound Signature natural language copy with genre references
4. **VH-010 (P2):** Mood per-mood color token system
5. **VH-011 (P1):** Creator DNA animated visualization with growth path explanation
6. **VH-012 (P1):** Onboarding app tour (3–5 cards) and contextual coach marks
7. **VH-013 (P0):** Privacy claim audit and accurate rewording

**Out of Scope:**
- Studio cockpit UX enhancements (VH-001 through VH-006) — tracked separately in `studio-cockpit-fixes` spec
- Backend DNA algorithm changes
- Post-onboarding analytics dashboard

### System Context

**Platform:** Flutter 3.44+ / Dart 3.x / Riverpod  
**Current Test Health:** 991 tests passing, 0 analyzer warnings  
**Design System:** Strict AppColors, AppTypography, AppSpacing token usage  
**Affected Modules:**
- `lib/features/onboarding/presentation/views/onboarding_view.dart`
- `lib/features/onboarding/domain/models/onboarding_models.dart`
- `lib/features/onboarding/presentation/providers/onboarding_providers.dart`
- `lib/features/creator_dna/presentation/widgets/*` (new visualization widgets)
- `lib/core/theme/app_colors.dart` (genre/mood color tokens)
- `lib/core/theme/app_gradients.dart` (genre-aware gradient extensions)

---

## Glossary

- **Onboarding_View**: The 6-screen PageView flow that collects user preferences (role, genres, languages, tempo, mood) and seeds the Creator DNA profile.
- **Creator_DNA**: Adaptive personalization profile derived from onboarding choices that pre-fills studio parameters and steers generation toward the user's aesthetic.
- **EARS**: Easy Approach to Requirements Syntax — structured requirement format using trigger-response patterns.
- **BPM**: Beats Per Minute — technical tempo measurement unfamiliar to most users.
- **Genre_Heritage**: User's selected musical genres (Amapiano, Kwaito, Gqom, etc.) that define regional and rhythmic identity.
- **Sound_Signature**: Combined tempo preference, vocal energy preference, and mood selections that shape sonic output.
- **Carousel**: Horizontal swipeable card interface with center emphasis and scaled neighbors.
- **Haptic_Feedback**: Tactile vibration responses on user interactions (light impact, selection click, medium impact).
- **Reduce_Motion**: System accessibility setting that disables animations for users with motion sensitivity.
- **Coach_Mark**: Contextual tooltip overlay that highlights a UI element and explains its function on first use.
- **App_Tour**: Multi-card educational overlay shown once to explain key features.
- **On_Device_Sovereignty**: Privacy claim stating data is stored locally without cloud transmission.

---

## Requirements

### Requirement 1: Creative Identity Horizontal Card Carousel (VH-007)

**User Story:** As a new creator, I want to swipe through creative roles in a visually engaging carousel, so that I can quickly identify my identity without reading a long list.

#### Acceptance Criteria

**REQ-VH007-01:** THE Onboarding_View SHALL replace the vertical role list with a horizontal card carousel on the Creative Identity screen.

**REQ-VH007-02:** WHEN the user swipes horizontally on the carousel, THE Onboarding_View SHALL scroll between role cards without triggering the PageView page transition.

**REQ-VH007-03:** THE Carousel SHALL emphasize the center card with scale factor 1.0 and full opacity, while neighbor cards SHALL render at scale factor 0.88 and opacity 0.6.

**REQ-VH007-04:** WHEN the user taps a role card, THE Onboarding_View SHALL animate a check mark into view within 200 milliseconds and scale the card to 1.03 for 150 milliseconds.

**REQ-VH007-05:** WHEN the user taps a role card, THE Onboarding_View SHALL fire a light impact haptic on select (iOS: `UIImpactFeedbackStyle.light`, Android: `HapticFeedbackConstants.KEYBOARD_TAP`).

**REQ-VH007-06:** WHEN the carousel snaps to a new card during scroll, THE Onboarding_View SHALL fire a selection tick haptic (iOS: `UIImpactFeedbackStyle.selection`, Android: `HapticFeedbackConstants.CLOCK_TICK`).

**REQ-VH007-07:** THE Carousel SHALL respect the system reduce-motion setting and disable scroll snap animation when reduce-motion is enabled.

**REQ-VH007-08:** WHEN the user navigates backward from a subsequent screen, THE Onboarding_View SHALL restore the selected role card in the carousel to the center position.

**REQ-VH007-09:** THE Carousel SHALL display each role card with an illustration or animated icon, title, and one-line description.

**REQ-VH007-10:** THE Experience_Level chips SHALL remain visible below the carousel without requiring scroll on devices with viewport height ≥ 640dp.

---

### Requirement 2: Genre Heritage Per-Genre Color Token System (VH-008)

**User Story:** As a producer selecting genres, I want each genre to have a distinct visual identity through color, so that I can quickly recognize genres across the app and feel emotional connection to my selections.

#### Acceptance Criteria

**REQ-VH008-01:** THE App_Colors class SHALL define a color token map for each genre with properties: accent, surface-tint, and glow.

**REQ-VH008-02:** THE Genre color map SHALL include tokens for: Amapiano, Afro House, Gqom, Kwaito, Afro Pop, Maskandi, Hip-Hop, and Gospel.

**REQ-VH008-03:** WHEN a genre chip is in selected state, THE Genre_Chip SHALL apply the genre's accent color to border, text, and check mark.

**REQ-VH008-04:** WHEN a genre chip is in selected state, THE Genre_Chip SHALL apply a tinted surface using the genre's surface-tint color with alpha 0.15.

**REQ-VH008-05:** THE Genre color tokens SHALL be reused consistently in: Studio cockpit genre dropdown, Progress tracker (VH-005), Explore feed track cards, and Library vault track cards.

**REQ-VH008-06:** THE Genre_Chip selected state SHALL maintain a contrast ratio ≥ 4.5:1 between text and tinted surface background, measured via WCAG color contrast analyzer.

**REQ-VH008-07:** THE Genre_Chip SHALL display a check mark icon in addition to color change, ensuring accessibility does not rely on color alone.

**REQ-VH008-08:** THE App_Gradients class SHALL extend `forGenre()` method to return gradients derived from genre accent colors for consistent visual branding.

---

### Requirement 3: Sound Signature Natural Language Copy (VH-009)

**User Story:** As a music enthusiast unfamiliar with production terminology, I want tempo and vocal energy described in relatable terms with genre references, so that I can make informed choices without technical knowledge.

#### Acceptance Criteria

**REQ-VH009-01:** THE Sound_Signature_Picker SHALL replace BPM range labels with natural language tempo descriptions:
- "Laid back" (replaces "Slow (70–95 BPM)")
- "Easy groove" (replaces "Medium (100–118 BPM)")
- "Driving" (replaces "Fast (120–135 BPM)")
- "Full speed" (replaces "Hyperspeed (140+ BPM)")

**REQ-VH009-02:** THE Tempo cards SHALL display a secondary reference line formatted as "Feels like [Genre1] and [Genre2]: [descriptive phrase]":
- "Laid back": "Feels like Deep House and Kizomba: slow, smooth, swaying"
- "Easy groove": "Feels like Amapiano and Afro Pop: relaxed but danceable"
- "Driving": "Feels like Afro Tech and Gqom: heads nod, floor fills"
- "Full speed": "Feels like Singeli and Shangaan: fast, frantic, high energy"

**REQ-VH009-03:** THE Sound_Signature_Picker SHALL replace technical vocal energy labels with natural language descriptions:
- "Smooth and tender" (replaces "Soft & Intimate")
- "Easy and melodic" (replaces "Balanced & Melodic")
- "Raw and aggressive" (new option for Rap/Drill)
- "Loud and gritty" (new option for Rock)

**REQ-VH009-04:** THE Vocal_Energy cards SHALL display a secondary reference line formatted as "Like [Genre/Style]: [descriptive phrase]":
- "Smooth and tender": "Like a love song: soft, close, warm voice"
- "Easy and melodic": "Like Afro Pop and R&B: natural, singable"
- "Raw and aggressive": "Like Rap and Drill: punchy, hard-hitting delivery"
- "Loud and gritty": "Like Rock: raw, strained, big voice"

**REQ-VH009-05:** THE Tempo and Vocal_Energy cards SHALL display a tiny genre-color chip next to each referenced genre, using color tokens from REQ-VH008-01.

**REQ-VH009-06:** THE Onboarding_State internal enum values and BPM/vocal parameter mappings SHALL remain unchanged, ensuring backward compatibility with saved Creator DNA profiles.

**REQ-VH009-07:** THE Natural language copy SHALL be stored in localized string resource files (`lib/l10n/`) to support future translation into Tshivenḓa, isiZulu, and other African languages.

---

### Requirement 4: Mood Per-Mood Color Token System (VH-010)

**User Story:** As a songwriter selecting moods, I want each mood to have a distinct color that reflects its emotional tone, so that I can visually differentiate moods from genres and feel the emotional intent of my choices.

#### Acceptance Criteria

**REQ-VH010-01:** THE App_Colors class SHALL define a color token for each mood with properties: accent and glow.

**REQ-VH010-02:** THE Mood color map SHALL include tokens for: Joyful (warm yellow #FBBF24), Melancholic (deep blue #3B82F6), Energetic (red-orange #F97316), Calm (teal #14B8A6), and Romantic (pink #EC4899).

**REQ-VH010-03:** WHEN a mood chip is in selected state, THE Mood_Chip SHALL apply the mood's accent color to border and text.

**REQ-VH010-04:** WHEN a mood chip is in selected state, THE Mood_Chip SHALL apply a tinted surface using the mood's accent color with alpha 0.12.

**REQ-VH010-05:** THE Mood color palette SHALL be visually distinct from the Genre color palette by using chip styling (small, rounded) versus card accent styling (large, prominent borders).

**REQ-VH010-06:** THE Mood color tokens SHALL be reused in: Studio cockpit mood selector, Progress tracker (VH-005), and Track detail mood badges.

**REQ-VH010-07:** THE Mood_Chip selected state SHALL maintain a contrast ratio ≥ 4.5:1 between text and tinted surface background.

**REQ-VH010-08:** THE Mood_Chip SHALL display a check mark icon in addition to color change, ensuring accessibility does not rely on color alone.

---

### Requirement 5: Creator DNA Animated Visualization (VH-011)

**User Story:** As a first-time user activating Creator DNA, I want to see a visually stunning animation that shows what DNA is built from and how it grows, so that I understand the product's differentiator and feel excited to start creating.

#### Acceptance Criteria

**REQ-VH011-01:** THE DNA_Activation screen SHALL display an animated visualization using either a double-helix or radial/orbital graphic design pattern.

**REQ-VH011-02:** THE DNA_Visualization SHALL derive node colors from the user's onboarding selections:
- Genre colors from REQ-VH008-01
- Mood colors from REQ-VH010-01
- Role-specific accent color from Creative Identity selection

**REQ-VH011-03:** WHEN the DNA_Activation screen enters view, THE DNA_Visualization SHALL animate a build-up sequence where nodes light up one by one over 1800 milliseconds.

**REQ-VH011-04:** THE DNA_Visualization animation SHALL render at 60fps on mid-range Android devices (Snapdragon 720G or equivalent) and iOS devices (A12 Bionic or equivalent).

**REQ-VH011-05:** WHEN the system reduce-motion setting is enabled, THE DNA_Visualization SHALL display a static version with all nodes illuminated and no animation.

**REQ-VH011-06:** THE DNA_Activation screen SHALL display three explanation beats below the visualization:
1. "Built from your choices: your roles, genres, tempo, vocal feel, mood"
2. "Shapes every song: pre-fills the cockpit and steers generation toward your sound"
3. "Grows with you: every song you make, keep, or edit sharpens it"

**REQ-VH011-07:** THE DNA_Activation screen SHALL replace the "Initial Model Strength" linear bar with a circular strength ring displaying 25%.

**REQ-VH011-08:** THE DNA_Activation screen SHALL display a growth path visualization showing milestones: 25% → 50% → 75% → 100%.

**REQ-VH011-09:** THE DNA_Activation screen SHALL display a text description of what unlocks at each strength milestone (to be defined by product team).

**REQ-VH011-10:** THE DNA_Visualization SHALL reflect the user's actual onboarding selections and SHALL NOT display a static placeholder image.

---

### Requirement 6: Onboarding App Tour and Contextual Coach Marks (VH-012)

**User Story:** As a new user completing onboarding, I want a brief tour explaining what I can do in the app, so that I discover features quickly and don't waste credits on trial-and-error.

#### Acceptance Criteria

**REQ-VH012-01:** THE Onboarding_View SHALL display a short app tour consisting of 3 to 5 cards immediately after the Creator DNA activation step, before navigating to the Root_Shell.

**REQ-VH012-02:** THE App_Tour SHALL cover features in the following priority order:
1. Compose (describe a song and generate it)
2. Write Lyrics First (AI drafts, you edit, then the beat)
3. Voice (vocal synthesis)
4. Crate & MPC (sample crate and pad production)
5. Library, Explore, Market (store, discover, publish)
6. Credits (10 free credits, generation cost)

**REQ-VH012-03:** THE App_Tour SHALL display one feature concept per card with: feature icon, title, one-sentence description, and visual illustration.

**REQ-VH012-04:** THE App_Tour SHALL include a "Skip Tour" button visible on every card that immediately dismisses the tour and navigates to the Root_Shell.

**REQ-VH012-05:** THE App_Tour SHALL include a dot indicator showing current position (e.g., "2 of 5") and "Continue" / "Get Started" CTA on the final card.

**REQ-VH012-06:** WHEN the user completes the App_Tour, THE App SHALL persist a completion flag in shared preferences to prevent showing the tour again on subsequent launches.

**REQ-VH012-07:** THE App SHALL provide a "Replay Onboarding Tour" option in Settings that resets the completion flag and replays the App_Tour on next app launch.

**REQ-VH012-08:** WHEN the user enters the Studio cockpit for the first time after onboarding, THE Studio_View SHALL display contextual coach marks on the top 2 to 3 controls (e.g., Prompt field, Genre selector, Generate CTA).

**REQ-VH012-09:** THE Coach_Marks SHALL display once per user account and SHALL NOT reappear after dismissal or interaction with the highlighted control.

**REQ-VH012-10:** THE App SHALL track App_Tour analytics events:
- `app_tour_started` (timestamp)
- `app_tour_card_viewed` (card_index, card_title)
- `app_tour_completed` (duration_sec)
- `app_tour_skipped` (skipped_at_card_index)

---

### Requirement 7: Privacy Claim Audit and Accurate Rewording (VH-013)

**User Story:** As a privacy-conscious creator, I want honest and accurate privacy statements in the app, so that I trust Vhunambi and avoid legal risks from misleading claims.

#### Acceptance Criteria

**REQ-VH013-01:** THE Engineering_Team SHALL audit all data flows in the Creator DNA and generation pipeline to determine:
- What data is stored on-device in Hive boxes
- What data is transmitted to backend API endpoints
- What data is logged to analytics services
- What data is stored in cloud databases

**REQ-VH013-02:** THE DNA_Activation screen current claim "100% on-device sovereignty (zero cloud tracking)" SHALL be removed if audit reveals any cloud transmission of DNA profile data, prompts, analytics events, or generation metadata.

**REQ-VH013-03:** IF the audit confirms DNA profiles are stored exclusively in local Hive storage and never transmitted, THEN THE DNA_Activation screen SHALL reword the claim to: "Your DNA profile is stored on your device".

**REQ-VH013-04:** IF the audit confirms analytics or generation prompts are transmitted to cloud services, THEN THE DNA_Activation screen SHALL reword the claim to: "Your DNA profile stays on your device. Generation prompts are sent securely to our servers to create your music."

**REQ-VH013-05:** THE Engineering_Team SHALL document audit findings in a Privacy_Data_Flow document stored in `docs/compliance/PRIVACY_DATA_FLOW.md`.

**REQ-VH013-06:** THE Product_Team SHALL review and approve final privacy claim wording before deployment to production.

**REQ-VH013-07:** THE Onboarding_View SHALL display the approved privacy claim as a benefit row with a lock icon on the DNA_Activation screen.

**REQ-VH013-08:** THE App SHALL track a `privacy_claim_displayed` analytics event with property `claim_text` set to the displayed claim verbatim, enabling A/B testing and compliance verification.

---

## Non-Functional Requirements

### Performance Requirements

**NFR-PERF-01:** WHEN the Creative Identity carousel is swiped, THE Onboarding_View SHALL maintain 60fps scroll performance on mid-range devices (Snapdragon 720G, A12 Bionic).

**NFR-PERF-02:** WHEN the DNA_Visualization animation plays, THE Onboarding_View SHALL maintain 60fps animation performance and SHALL NOT block the main UI thread.

**NFR-PERF-03:** WHEN the user completes onboarding, THE App SHALL seed the Creator DNA profile and navigate to Root_Shell within 800 milliseconds on 4G network conditions.

**NFR-PERF-04:** THE Onboarding_View SHALL lazy-load App_Tour card illustrations to reduce initial bundle size by at least 200KB.

### Accessibility Requirements

**NFR-A11Y-01:** THE Carousel SHALL support keyboard navigation (Tab to focus, Arrow keys to scroll) on desktop and tablet form factors.

**NFR-A11Y-02:** THE Carousel cards SHALL include semantic labels (`Semantics` widget) describing role, title, and selection state for screen readers.

**NFR-A11Y-03:** THE Genre and Mood chips SHALL NOT rely solely on color to indicate selected state; check marks and border width SHALL also indicate selection.

**NFR-A11Y-04:** THE DNA_Visualization animation SHALL respect the system reduce-motion accessibility setting and display a static version when enabled.

**NFR-A11Y-05:** THE App_Tour cards SHALL support font scaling up to 200% system font size without text truncation or layout overflow.

**NFR-A11Y-06:** THE Haptic feedback SHALL respect the system haptics setting (iOS: `UIFeedbackGenerator.prepare()` check, Android: `Settings.System.HAPTIC_FEEDBACK_ENABLED`) and degrade gracefully when disabled.

### UX Requirements

**NFR-UX-01:** THE Onboarding flow SHALL be completable in under 2 minutes for users making deliberate selections without rushing.

**NFR-UX-02:** THE Onboarding_View SHALL allow users to skip every step (Skip button on app bar) to respect user autonomy and reduce activation friction.

**NFR-UX-03:** THE App_Tour SHALL be skippable on any card, and SHALL NOT force users to complete all 5 cards.

**NFR-UX-04:** THE Coach_Marks SHALL be dismissible with a single tap on the overlay or the "Got it" CTA, and SHALL NOT reappear after dismissal.

**NFR-UX-05:** THE DNA_Activation screen SHALL maintain the "Activate Creator DNA ✨ →" button fully visible with 16–24dp right margin on viewports as narrow as 360dp width.

### Localization Requirements

**NFR-L10N-01:** THE Natural language copy for tempo and vocal energy descriptions (REQ-VH009) SHALL be stored in `lib/l10n/app_en.arb` and other locale files for future translation.

**NFR-L10N-02:** THE App_Tour card titles and descriptions SHALL be stored in localized string resource files.

**NFR-L10N-03:** THE DNA growth path milestone descriptions SHALL be stored in localized string resource files.

### Analytics Requirements

**NFR-ANALYTICS-01:** THE App SHALL log the following analytics events during onboarding:

| Event Name | Properties | Trigger |
|------------|-----------|---------|
| `onboarding_step_completed` | `step_name: String`, `duration_sec: int` | User taps Continue on any onboarding screen |
| `onboarding_step_skipped` | `step_name: String` | User taps Skip button |
| `carousel_card_selected` | `role: String`, `selection_method: "swipe" \| "tap"` | User selects a role card in carousel |
| `genre_selected` | `genre: String`, `color_displayed: String` | User taps a genre chip |
| `mood_selected` | `mood: String`, `color_displayed: String` | User taps a mood chip |
| `dna_visualization_viewed` | `view_duration_sec: int`, `animation_completed: bool` | User views DNA activation screen |
| `app_tour_started` | `timestamp: DateTime` | App tour first card displayed |
| `app_tour_card_viewed` | `card_index: int`, `card_title: String` | User views a tour card |
| `app_tour_completed` | `duration_sec: int` | User reaches final tour card and taps "Get Started" |
| `app_tour_skipped` | `skipped_at_card_index: int` | User taps "Skip Tour" |
| `privacy_claim_displayed` | `claim_text: String` | DNA activation screen displays privacy claim |

---

## Cross-Cutting Concerns

### Design Token System

**CCC-TOKEN-01:** ALL new color tokens for genres and moods SHALL be defined in `lib/core/theme/app_colors.dart` as static const Color properties with descriptive names (e.g., `genreAmapianoPrimary`, `moodJoyfulAccent`).

**CCC-TOKEN-02:** THE App_Gradients class SHALL be extended with a `forGenre(String genreName)` method that returns a LinearGradient derived from genre accent colors.

**CCC-TOKEN-03:** THE Genre and Mood color tokens SHALL be documented in `docs/foundation_blueprints/00_SYSTEM_DESIGN_TOKENS.md` with visual swatches and hex values.

**CCC-TOKEN-04:** ZERO hardcoded hex color values SHALL appear in onboarding presentation widgets; all colors SHALL reference AppColors constants.

### Haptic Feedback Service

**CCC-HAPTIC-01:** A reusable `HapticService` utility class SHALL be created in `lib/core/utils/haptic_service.dart` to centralize haptic intensity and system setting checks.

**CCC-HAPTIC-02:** THE HapticService SHALL expose methods: `lightImpact()`, `mediumImpact()`, `selectionClick()`, and `tick()`.

**CCC-HAPTIC-03:** THE HapticService SHALL check the system haptics setting before firing any vibration and gracefully no-op when disabled.

### State Persistence

**CCC-STATE-01:** THE Onboarding_State SHALL be persisted to Hive `preferencesBox` after each screen completion to support resume-after-crash scenarios.

**CCC-STATE-02:** THE App_Tour completion flag SHALL be stored in `SharedPreferences` with key `has_completed_app_tour`.

**CCC-STATE-03:** THE Coach_Marks dismissal state SHALL be stored in `SharedPreferences` with key `has_dismissed_studio_coach_marks`.

### Test Preservation

**CCC-TEST-01:** ALL existing onboarding widget tests SHALL continue passing after implementation (6 unit tests + 4 widget tests).

**CCC-TEST-02:** NEW widget tests SHALL be added for:
- Carousel gesture detection and scroll behavior
- Haptic feedback firing on interactions
- Genre/Mood chip color application
- DNA visualization animation playback
- App tour navigation and skip behavior

**CCC-TEST-03:** THE Test suite SHALL verify reduce-motion compliance by mocking `AccessibilityFeatures.reduceMotion` and asserting static rendering.

---

## Constraints & Assumptions

### Constraints

1. **Backward Compatibility:** Internal `OnboardingState` enum values and Creator DNA field mappings MUST remain unchanged to support users with existing DNA profiles.
2. **Test Regression Prevention:** 991 existing tests MUST continue passing; zero test breakage is tolerated.
3. **Design System Strictness:** All UI changes MUST use existing AppColors, AppTypography, and AppSpacing tokens; no ad-hoc styling.
4. **Performance Budget:** Onboarding screens MUST render in <16ms per frame (60fps) on mid-range devices; animations cannot degrade performance.
5. **Legal Compliance:** Privacy claims MUST be audited and approved by product/legal teams before shipping.

### Assumptions

1. **Device Capabilities:** Target devices support HapticFeedback API and vibration hardware.
2. **Network Conditions:** Onboarding completes offline; no network requests block user progress.
3. **Localization Resources:** String resource files (`app_en.arb`) are in place for English; translations for Tshivenḓa, isiZulu, etc. are planned post-launch.
4. **Analytics Infrastructure:** Firebase Analytics or equivalent is configured and event logging does not block UI thread.
5. **Product Input:** DNA growth path milestone unlocks (25% → 50% → 75% → 100%) will be defined by product team before design phase.
6. **Screen Reader Usage:** Screen reader support is tested manually on iOS VoiceOver and Android TalkBack; automated a11y tests are best-effort.

---

## Dependencies & Integration Points

### Internal Dependencies

1. **Creator DNA Module:** Onboarding seeds `CreatorDnaProfile` via `creatorDnaProvider.notifier.seedFromOnboarding()`.
2. **Studio Cockpit Module:** DNA profile pre-fills studio parameters via `studioFormProvider` on first generation.
3. **Analytics Module:** Onboarding events logged via `AnalyticsService.logEvent()`.
4. **Shared Preferences:** Tour and coach mark completion flags stored via `SharedPreferencesService`.
5. **Hive Storage:** Onboarding state persisted to `preferencesBox`.

### External Dependencies

1. **Flutter Framework:** Requires Flutter 3.44+ for `Semantics`, `HapticFeedback`, and `AccessibilityFeatures` APIs.
2. **Riverpod:** State management via `StateNotifierProvider`.
3. **Shared Preferences Plugin:** `shared_preferences: ^2.0.15` for flag persistence.
4. **Hive Plugin:** `hive_flutter: ^1.1.0` for local storage.
5. **Firebase Analytics:** (Optional) For event tracking in production.

---

## Success Criteria & Validation

### Acceptance Validation

This feature is considered complete when:

1. ✅ All 7 VH requirements (VH-007 through VH-013) are implemented and verified.
2. ✅ All 63 acceptance criteria pass manual QA on iOS and Android devices.
3. ✅ 991+ tests pass (`flutter test` returns 0 failures).
4. ✅ `flutter analyze` returns 0 errors, 0 warnings.
5. ✅ Privacy audit document (`docs/compliance/PRIVACY_DATA_FLOW.md`) is completed and reviewed.
6. ✅ App tour completion rate is tracked in analytics and baseline is established.

### User Acceptance Criteria

1. **VH-007:** User can swipe carousel horizontally without triggering page navigation; haptics fire on selection.
2. **VH-008:** Genre chips display distinct colors in selected state; colors appear consistently in Studio, Explore, Library.
3. **VH-009:** Tempo and vocal energy cards use natural language ("Laid back", "Smooth and tender") with genre references.
4. **VH-010:** Mood chips display distinct colors separate from genre colors.
5. **VH-011:** DNA visualization animates on entry with colored nodes; growth path is explained in 3 sentences.
6. **VH-012:** App tour displays 3–5 cards; tour is skippable; coach marks appear once in Studio.
7. **VH-013:** Privacy claim is accurate and approved; no misleading "zero cloud tracking" statement unless verified.

### Performance Validation

1. Carousel scrolls at 60fps on Pixel 5 and iPhone 12 Mini.
2. DNA animation renders at 60fps and completes in <2 seconds.
3. Onboarding completion + navigation to Root_Shell takes <1 second.

---

## Appendices

### Appendix A: Genre Color Token Reference

| Genre | Accent Color | Surface Tint | Glow Color | Hex Value |
|-------|-------------|--------------|------------|-----------|
| Amapiano | Vibrant Amber | Amber Inset | Amber Glow | `#F97316` |
| Afro House | Electric Purple | Purple Inset | Purple Glow | `#A855F7` |
| Gqom | Neon Cyan | Cyan Inset | Cyan Glow | `#22D3EE` |
| Kwaito | Sunset Orange | Orange Inset | Orange Glow | `#FB923C` |
| Afro Pop | Rose Pink | Pink Inset | Pink Glow | `#F472B6` |
| Maskandi | Earth Brown | Brown Inset | Brown Glow | `#A16207` |
| Hip-Hop | Steel Blue | Blue Inset | Blue Glow | `#3B82F6` |
| Gospel | Gold Yellow | Gold Inset | Gold Glow | `#FBBF24` |

*(Note: Final hex values to be calibrated in design phase for 4.5:1 contrast compliance.)*

### Appendix B: Mood Color Token Reference

| Mood | Accent Color | Hex Value | Emotional Association |
|------|-------------|-----------|----------------------|
| Joyful | Warm Yellow | `#FBBF24` | Bright, uplifting, celebratory |
| Melancholic | Deep Blue | `#3B82F6` | Reflective, somber, introspective |
| Energetic | Red-Orange | `#F97316` | High-energy, explosive, intense |
| Calm | Teal | `#14B8A6` | Serene, peaceful, relaxed |
| Romantic | Pink | `#EC4899` | Tender, loving, intimate |

### Appendix C: Tempo Natural Language Mapping

| Internal Enum | BPM Range | Natural Label | Genre References | Description |
|--------------|-----------|---------------|------------------|-------------|
| `slow` | 70–95 | Laid back | Deep House, Kizomba | slow, smooth, swaying |
| `medium` | 100–118 | Easy groove | Amapiano, Afro Pop | relaxed but danceable |
| `fast` | 120–135 | Driving | Afro Tech, Gqom | heads nod, floor fills |
| `hyperspeed` | 140+ | Full speed | Singeli, Shangaan | fast, frantic, high energy |

### Appendix D: Vocal Energy Natural Language Mapping

| Internal Enum | Natural Label | Genre/Style References | Description |
|--------------|---------------|------------------------|-------------|
| `soft` | Smooth and tender | Love songs | soft, close, warm voice |
| `balanced` | Easy and melodic | Afro Pop, R&B | natural, singable |
| `aggressive` | Raw and aggressive | Rap, Drill | punchy, hard-hitting delivery |
| `loud` | Loud and gritty | Rock | raw, strained, big voice |

### Appendix E: App Tour Card Content

| Card # | Title | Description | Visual |
|--------|-------|-------------|--------|
| 1 | Compose | Describe a song idea in plain language and generate a full track with vocals, beat, and mix in under 2 minutes. | Illustration: Text prompt → AI waveform → Play button |
| 2 | Write Lyrics First | Let AI draft lyrics in your dialect, edit them line-by-line, then generate the beat to match your words. | Illustration: Lyric sheet → Edit pencil → Beat generation |
| 3 | Voice | Choose from 25+ African vocal timbres and dialects to bring authentic regional flavor to your music. | Illustration: Microphone icon + dialect flags |
| 4 | Crate & MPC | Dig through indigenous instrument samples (Mbira, Kora, Talking Drum) and slice beats on the MPC pad. | Illustration: Spinning vinyl + 8-pad grid |
| 5 | Credits & Library | Start with 10 free credits. Every generation is yours to keep, download stems, and license commercially. | Illustration: Coin icon + folder + download arrow |

---

**Document End**

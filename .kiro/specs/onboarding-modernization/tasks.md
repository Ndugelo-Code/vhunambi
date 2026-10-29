# Onboarding Experience Modernization — Implementation Tasks

## Overview

This document specifies the implementation tasks for the **Onboarding Experience Modernization** feature, which transforms VHUNAMBI's 6-screen onboarding flow from a functional questionnaire into an immersive, visually rich brand experience. This implementation covers 7 critical UX enhancements (VH-007 through VH-013) identified during field testing.

**Feature Name:** `onboarding-modernization`

**Spec ID:** `e1ba6a93-9f2f-4c4b-b125-473a821cd967`

**Workflow:** Feature Requirements-First

**Target Platform:** Flutter 3.44+ / Dart 3.x / Riverpod 2.x

**Test Baseline:** 991 passing tests (must remain green)

**Design Principles:**
- Tactile Delight: Haptic feedback on interactions
- Progressive Disclosure: Reveal complexity gradually
- Consistency: Genre/mood colors throughout app
- Cultural Relevance: African music context
- Performance: 60fps on mid-range devices
- Backward Compatibility: Preserve internal enum values

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
  - Branch name: `feat/onboarding-modernization-vh007-vh013`
  - Base: `main` or current development branch
  - _Verification: Git branch created_

- [ ] 0.5 Review design documents
  - Read `requirements.md` (detailed requirements)
  - Read `design.md` (technical design)
  - Understand architecture and correctness properties
  - _Verification: Team alignment on approach_

---

# Implementation Plan:

This feature follows a **phased implementation approach** designed to maintain stability while adding enhancements:

### Approach Overview

1. **Foundation First**: Establish core utilities (HapticService, color tokens, localization) that all enhancements depend on
2. **Incremental Enhancement**: Implement each VH requirement independently with full testing
3. **Integration**: Wire all components together and validate full onboarding flow
4. **Polish**: Performance profiling, accessibility audit, analytics integration

### Phase Breakdown

**Phase 1: Foundation & Cross-Cutting (Tasks 1-6)**
- Create HapticService utility
- Define genre and mood color token systems
- Set up localization infrastructure
- Create base design token documentation
- Duration: 2-3 days

**Phase 2: VH-007 Creative Identity Carousel (Tasks 7-10)**
- Implement horizontal card carousel
- Add center emphasis and scroll snap
- Integrate haptic feedback
- Write carousel tests
- Duration: 3-4 days

**Phase 3: VH-008 & VH-010 Color Systems (Tasks 11-16)**
- Implement GenreColorChip with 8 genre colors
- Implement MoodColorChip with 5 mood colors
- Apply colors across Studio, Explore, Library
- Write color consistency tests
- Duration: 3-4 days

**Phase 4: VH-009 Natural Language Copy (Tasks 17-20)**
- Create localized string resources
- Update TempoVocalCard widgets
- Add genre reference chips
- Write localization tests
- Duration: 2-3 days

**Phase 5: VH-011 DNA Visualization (Tasks 21-26)**
- Create DNAVisualizationWidget with CustomPainter
- Implement animation sequence
- Build growth path UI
- Add reduce-motion fallback
- Write animation performance tests
- Duration: 4-5 days

**Phase 6: VH-012 App Tour & Coach Marks (Tasks 27-32)**
- Build AppTourOverlay with 3-5 cards
- Implement skip/continue navigation
- Create CoachMarkOverlay for Studio
- Add SharedPreferences persistence
- Write tour flow tests
- Duration: 3-4 days

**Phase 7: VH-013 Privacy Claim Audit (Tasks 33-36)**
- Audit data flows
- Create PRIVACY_DATA_FLOW.md
- Update privacy claim wording
- Add analytics tracking
- Duration: 2-3 days

**Phase 8: Integration & Polish (Tasks 37-45)**
- End-to-end onboarding flow testing
- Performance profiling (60fps validation)
- Accessibility audit
- Analytics event integration
- Final acceptance criteria validation
- Duration: 4-5 days

### Critical Path

```
Pre-Flight → Foundation (Phase 1) → VH-007/008/009/010/011 (Parallel) → VH-012 → VH-013 → Integration
```

All VH requirements except VH-012 and VH-013 can be implemented in parallel after foundation is complete. VH-012 (app tour) requires VH-011 (DNA visualization) to be complete. VH-013 (privacy audit) can run independently.

### Success Criteria

- ✅ All 991 baseline tests remain passing
- ✅ All 63 acceptance criteria verified
- ✅ Zero analyzer errors/warnings
- ✅ 60fps performance on mid-range devices
- ✅ All animations respect reduce-motion setting
- ✅ WCAG 2.1 Level AA accessibility compliance
- ✅ Privacy audit complete and approved

---

## Tasks

### Phase 1: Foundation & Cross-Cutting

- [ ] 1. Create HapticService utility class
  - Create `lib/core/utils/haptic_service.dart`
  - Implement methods: `lightImpact()`, `mediumImpact()`, `selectionClick()`, `tick()`
  - Add system settings check: iOS `UIFeedbackGenerator.prepare()`, Android `Settings.System.HAPTIC_FEEDBACK_ENABLED`
  - Gracefully no-op when haptics disabled
  - Add unit tests for each method
  - _Requirements: CCC-HAPTIC-01, CCC-HAPTIC-02, CCC-HAPTIC-03, NFR-A11Y-06_
  - _Files: `lib/core/utils/haptic_service.dart`, `test/core/utils/haptic_service_test.dart`_

- [ ] 2. Define genre color token system in AppColors
  - Add `GenreColorScheme` model class
  - Define 8 genre color maps in `AppColors` extension:
    - Amapiano: Vibrant Amber (#F97316)
    - Afro House: Electric Purple (#A855F7)
    - Gqom: Neon Cyan (#22D3EE)
    - Kwaito: Sunset Orange (#FB923C)
    - Afro Pop: Rose Pink (#F472B6)
    - Maskandi: Earth Brown (#A16207)
    - Hip-Hop: Steel Blue (#3B82F6)
    - Gospel: Gold Yellow (#FBBF24)
  - Each scheme includes: accent, surfaceTint, glow colors
  - Verify WCAG 4.5:1 contrast for each color on tinted surfaces
  - Add unit tests for color token retrieval
  - _Requirements: REQ-VH008-01, REQ-VH008-02, CCC-TOKEN-01, CCC-TOKEN-03_
  - _Files: `lib/core/theme/app_colors.dart`, `test/core/theme/app_colors_test.dart`_

- [ ] 3. Define mood color token system in AppColors
  - Add `MoodColorScheme` model class
  - Define 5 mood color maps in `AppColors` extension:
    - Joyful: Warm Yellow (#FBBF24)
    - Melancholic: Deep Blue (#3B82F6)
    - Energetic: Red-Orange (#F97316)
    - Calm: Teal (#14B8A6)
    - Romantic: Pink (#EC4899)
  - Each scheme includes: accent, glow colors
  - Verify WCAG 4.5:1 contrast for each color on tinted surfaces
  - Add unit tests for color token retrieval
  - _Requirements: REQ-VH010-01, REQ-VH010-02, CCC-TOKEN-01, CCC-TOKEN-03_
  - _Files: `lib/core/theme/app_colors.dart`, `test/core/theme/app_colors_test.dart`_

- [ ] 4. Extend AppGradients with genre-aware gradients
  - Add `forGenre(String genreName)` method to `AppGradients` class
  - Returns `LinearGradient` derived from genre accent colors
  - Fallback to default gradient for unknown genres
  - Add unit tests for gradient generation
  - _Requirements: REQ-VH008-08, CCC-TOKEN-02_
  - _Files: `lib/core/theme/app_gradients.dart`, `test/core/theme/app_gradients_test.dart`_

- [ ] 5. Set up localization infrastructure for natural language copy
  - Create `lib/l10n/app_en.arb` with tempo and vocal energy labels
  - Add keys: `tempoLaidBack`, `tempoEasyGroove`, `tempoDriving`, `tempoFullSpeed`
  - Add keys: `vocalSmoothTender`, `vocalEasyMelodic`, `vocalRawAggressive`, `vocalLoudGritty`
  - Add genre reference strings with placeholders
  - Run `flutter gen-l10n` to generate localization classes
  - Add unit tests for localization retrieval
  - _Requirements: REQ-VH009-01, REQ-VH009-03, REQ-VH009-07, NFR-L10N-01_
  - _Files: `lib/l10n/app_en.arb`, `test/l10n/localizations_test.dart`_

- [ ] 6. Document design tokens in system documentation
  - Create/update `docs/foundation_blueprints/00_SYSTEM_DESIGN_TOKENS.md`
  - Document genre color tokens with hex values and swatches
  - Document mood color tokens with hex values and swatches
  - Include contrast ratio verification results
  - Add usage guidelines for genre/mood colors
  - _Requirements: CCC-TOKEN-03, CCC-TOKEN-04_
  - _Files: `docs/foundation_blueprints/00_SYSTEM_DESIGN_TOKENS.md`_

---

### Phase 2: VH-007 Creative Identity Carousel

- [ ] 7. Create RoleCarouselWidget structure
  - Create `lib/features/onboarding/presentation/widgets/role_carousel_widget.dart`
  - Implement `ConsumerWidget` with `PageView.builder` as base
  - Add `PageController` with `viewportFraction: 0.8`
  - Create `_RoleCard` stateless widget for individual cards
  - Add role data models: role name, description, icon
  - Wire to `onboardingProvider` for selected role state
  - _Requirements: REQ-VH007-01, REQ-VH007-09_
  - _Files: `lib/features/onboarding/presentation/widgets/role_carousel_widget.dart`_

- [ ] 8. Implement carousel center emphasis and scroll snap
  - Calculate center card index from `PageController.page`
  - Apply scale transform: center card 1.0, neighbors 0.88
  - Apply opacity: center card 1.0, neighbors 0.6
  - Implement snap behavior on scroll end: snap to nearest card
  - Add curve animation: `Curves.easeOutCubic`, 200ms duration
  - Fire selection tick haptic on snap completion
  - _Requirements: REQ-VH007-03, REQ-VH007-06_
  - _Files: `lib/features/onboarding/presentation/widgets/role_carousel_widget.dart`_

- [ ] 9. Implement gesture detection and haptic feedback
  - Add `GestureDetector` to handle horizontal swipes
  - Prevent PageView page transition on carousel swipe
  - Lock PageView scrolling when carousel is being dragged
  - Add tap handler for role card selection
  - Fire light impact haptic on card tap
  - Animate check mark into view: scale 0.8 → 1.0, 200ms
  - Animate card scale on tap: 1.0 → 1.03 → 1.0, 150ms total
  - Add reduce-motion fallback: disable scroll snap animation
  - _Requirements: REQ-VH007-02, REQ-VH007-04, REQ-VH007-05, REQ-VH007-07_
  - _Files: `lib/features/onboarding/presentation/widgets/role_carousel_widget.dart`_

- [ ] 10. Write carousel tests
  - **Unit tests**: Center card calculation, scale/opacity calculation
  - **Widget tests**: 
    - Carousel snaps to center on scroll end
    - Selected card shows check mark
    - Haptic service called on tap and snap
    - Horizontal swipe does not trigger PageView transition
    - Reduce-motion disables snap animation
    - Selected role restored when navigating backward
  - **Property test**: ∀ carousel swipes: page transition NOT triggered ∧ center card emphasized
  - _Requirements: Property 1, Property 2, Property 7, CCC-TEST-02_
  - _Files: `test/features/onboarding/presentation/widgets/role_carousel_widget_test.dart`_

---

### Phase 3: VH-008 & VH-010 Color Systems

- [ ] 11. Create GenreColorChip widget
  - Create `lib/features/onboarding/presentation/widgets/genre_color_chip.dart`
  - Implement stateless widget accepting: genre, isSelected, onTap
  - Retrieve `GenreColorScheme` from `AppColors.genreColorMap[genre]`
  - **Unselected state**: Gray border 2px, no background, gray text
  - **Selected state**: 
    - Genre accent border 3px
    - Tinted surface (surfaceTint with alpha 0.15)
    - Accent text color
    - Check mark icon (`Icons.check_circle`)
  - Handle missing genre: fallback to gray color scheme
  - Fire light impact haptic on tap
  - Add `Semantics` widget with label for screen readers
  - _Requirements: REQ-VH008-03, REQ-VH008-04, REQ-VH008-07, NFR-A11Y-03_
  - _Files: `lib/features/onboarding/presentation/widgets/genre_color_chip.dart`_

- [ ] 12. Update Genre Heritage screen to use GenreColorChip
  - Replace existing genre selection UI in `onboarding_view.dart`
  - Use `GenreColorChip` for all 8 genres
  - Wire to `onboardingProvider` for selected genres list
  - Maintain multi-select behavior
  - Verify layout on 360dp width devices
  - _Requirements: REQ-VH008-01, REQ-VH008-03_
  - _Files: `lib/features/onboarding/presentation/views/onboarding_view.dart`_

- [ ] 13. Apply genre colors across Studio, Explore, Library modules
  - **Studio cockpit**: Update genre dropdown to use genre accent colors
  - **Explore feed**: Apply genre colors to track card genre badges
  - **Library vault**: Apply genre colors to track card genre badges
  - Verify consistency: all genre displays use same color tokens
  - _Requirements: REQ-VH008-05, Property 3_
  - _Files: 
    - `lib/features/studio/presentation/widgets/genre_selector.dart`
    - `lib/features/explore/presentation/widgets/track_card.dart`
    - `lib/features/library/presentation/widgets/vault_track_card.dart`_

- [ ] 14. Create MoodColorChip widget
  - Create `lib/features/onboarding/presentation/widgets/mood_color_chip.dart`
  - Implement stateless widget accepting: mood, isSelected, onTap
  - Retrieve `MoodColorScheme` from `AppColors.moodColorMap[mood]`
  - **Unselected state**: Gray border 2px, no background, gray text
  - **Selected state**: 
    - Mood accent border 3px
    - Tinted surface (accent with alpha 0.12)
    - Accent text color
    - Check mark icon
  - Handle missing mood: fallback to gray color scheme
  - Fire light impact haptic on tap
  - Add `Semantics` widget with label for screen readers
  - Ensure visual distinction from GenreColorChip (smaller, rounded)
  - _Requirements: REQ-VH010-03, REQ-VH010-04, REQ-VH010-08, NFR-A11Y-03_
  - _Files: `lib/features/onboarding/presentation/widgets/mood_color_chip.dart`_

- [ ] 15. Update Mood Selection screen to use MoodColorChip
  - Replace existing mood selection UI in `onboarding_view.dart`
  - Use `MoodColorChip` for all 5 moods
  - Wire to `onboardingProvider` for selected moods list
  - Maintain multi-select behavior
  - Verify layout on 360dp width devices
  - _Requirements: REQ-VH010-03, REQ-VH010-04_
  - _Files: `lib/features/onboarding/presentation/views/onboarding_view.dart`_

- [ ] 16. Write color system tests
  - **Unit tests**: 
    - Color scheme retrieval for all genres
    - Color scheme retrieval for all moods
    - Fallback color for missing tokens
    - Contrast ratio calculation for each color scheme (≥ 4.5:1)
  - **Widget tests**:
    - GenreColorChip selected state applies correct colors
    - MoodColorChip selected state applies correct colors
    - Check mark appears in selected state
    - Haptic feedback fires on tap
    - Semantic labels present for screen readers
  - **Property test**: ∀ genres/moods: selected state applies correct accent color with 4.5:1 contrast
  - _Requirements: Property 3, Property 4, REQ-VH008-06, REQ-VH010-07, CCC-TEST-02_
  - _Files: 
    - `test/features/onboarding/presentation/widgets/genre_color_chip_test.dart`
    - `test/features/onboarding/presentation/widgets/mood_color_chip_test.dart`_

---

### Phase 4: VH-009 Natural Language Copy

- [ ] 17. Create natural language tempo mapping
  - Map internal tempo enums to natural language labels:
    - `slow` (70-95 BPM) → "Laid back"
    - `medium` (100-118 BPM) → "Easy groove"
    - `fast` (120-135 BPM) → "Driving"
    - `hyperspeed` (140+ BPM) → "Full speed"
  - Add genre reference strings:
    - "Laid back": "Feels like Deep House and Kizomba: slow, smooth, swaying"
    - "Easy groove": "Feels like Amapiano and Afro Pop: relaxed but danceable"
    - "Driving": "Feels like Afro Tech and Gqom: heads nod, floor fills"
    - "Full speed": "Feels like Singeli and Shangaan: fast, frantic, high energy"
  - Store in localized ARB files
  - Ensure internal enum values remain unchanged for backward compatibility
  - _Requirements: REQ-VH009-01, REQ-VH009-02, REQ-VH009-06, Property 5_
  - _Files: `lib/l10n/app_en.arb`_

- [ ] 18. Create natural language vocal energy mapping
  - Map internal vocal energy enums to natural language labels:
    - `soft` → "Smooth and tender"
    - `balanced` → "Easy and melodic"
    - `aggressive` → "Raw and aggressive" (new option)
    - `loud` → "Loud and gritty" (new option)
  - Add style reference strings:
    - "Smooth and tender": "Like a love song: soft, close, warm voice"
    - "Easy and melodic": "Like Afro Pop and R&B: natural, singable"
    - "Raw and aggressive": "Like Rap and Drill: punchy, hard-hitting delivery"
    - "Loud and gritty": "Like Rock: raw, strained, big voice"
  - Store in localized ARB files
  - Ensure internal enum values remain unchanged for backward compatibility
  - _Requirements: REQ-VH009-03, REQ-VH009-04, REQ-VH009-06, Property 5_
  - _Files: `lib/l10n/app_en.arb`_

- [ ] 19. Update TempoVocalCard widgets with natural language copy
  - Create `TempoCard` and `VocalEnergyCard` widgets
  - Display natural language label as primary text
  - Display genre/style reference as secondary text
  - Add tiny genre-color chips next to referenced genres
  - Use localized string resources for all text
  - Maintain existing selection behavior and haptic feedback
  - Replace existing tempo/vocal UI in Sound Signature screen
  - _Requirements: REQ-VH009-01, REQ-VH009-03, REQ-VH009-05_
  - _Files: 
    - `lib/features/onboarding/presentation/widgets/tempo_card.dart`
    - `lib/features/onboarding/presentation/widgets/vocal_energy_card.dart`
    - `lib/features/onboarding/presentation/views/onboarding_view.dart`_

- [ ] 20. Write natural language copy tests
  - **Unit tests**:
    - Tempo enum → natural label mapping
    - Vocal enum → natural label mapping
    - Localization string retrieval
    - Fallback to enum key when localization missing
  - **Widget tests**:
    - Tempo cards display natural language labels
    - Vocal cards display style references
    - Genre-color chips appear next to referenced genres
  - **Property test**: ∀ tempo/vocal values: natural language displayed ∧ genre chips shown ∧ internal enum unchanged
  - _Requirements: Property 5, REQ-VH009-06, CCC-TEST-02_
  - _Files: 
    - `test/features/onboarding/presentation/widgets/tempo_card_test.dart`
    - `test/features/onboarding/presentation/widgets/vocal_energy_card_test.dart`_

---

### Phase 5: VH-011 DNA Visualization

- [ ] 21. Create DNAVisualizationWidget structure
  - Create `lib/features/creator_dna/presentation/widgets/dna_visualization_widget.dart`
  - Implement `ConsumerStatefulWidget` with `SingleTickerProviderStateMixin`
  - Add `AnimationController`: duration 1800ms, curve `Curves.easeOutCubic`
  - Create `DNANode` model: id, position, color, label, type
  - Derive node colors from user's onboarding selections:
    - Genre nodes: use `AppColors.genreColorMap[genre].accent`
    - Mood nodes: use `AppColors.moodColorMap[mood].accent`
    - Role node: use role-specific accent color
  - Check reduce-motion: `MediaQuery.accessibilityFeaturesOf(context).reduceMotion`
  - _Requirements: REQ-VH011-01, REQ-VH011-02, REQ-VH011-05, Property 7_
  - _Files: 
    - `lib/features/creator_dna/presentation/widgets/dna_visualization_widget.dart`
    - `lib/features/creator_dna/domain/models/dna_node.dart`_

- [ ] 22. Implement DNACustomPainter for double-helix or radial layout
  - Create `DNACustomPainter extends CustomPainter`
  - Calculate node positions: double-helix or radial/orbital pattern
  - Implement `paint()` method:
    - Draw connecting lines between nodes (faint glow effect)
    - Draw node circles with derived colors
    - Apply animation progress: nodes light up sequentially
  - Implement `shouldRepaint()`: repaint when animation progress changes
  - Optimize for 60fps: use `RepaintBoundary`, cache paint objects
  - _Requirements: REQ-VH011-01, REQ-VH011-03, Property 6_
  - _Files: `lib/features/creator_dna/presentation/painters/dna_custom_painter.dart`_

- [ ] 23. Implement DNA animation sequence
  - Start animation on widget `initState()`
  - Animate node light-up: 18 nodes × 100ms delay each (1800ms total)
  - Use `CurvedAnimation` with `Curves.easeOutCubic`
  - Interpolate node opacity: 0.0 → 1.0 based on animation progress
  - Add glow effect: nodes pulse slightly at full brightness
  - Dispose controller on widget disposal
  - Check frame times: add post-frame callback to detect dropped frames
  - If frame time > 32ms, reduce animation complexity
  - _Requirements: REQ-VH011-03, REQ-VH011-04, Property 6_
  - _Files: `lib/features/creator_dna/presentation/widgets/dna_visualization_widget.dart`_

- [ ] 24. Add reduce-motion fallback
  - Check `AccessibilityFeatures.reduceMotion` in `initState()`
  - If true: skip animation, display static visualization with all nodes illuminated
  - If false: play full animation sequence
  - Update DNA activation screen to respect reduce-motion
  - _Requirements: REQ-VH011-05, Property 7, NFR-A11Y-04_
  - _Files: `lib/features/creator_dna/presentation/widgets/dna_visualization_widget.dart`_

- [ ] 25. Create DNA growth path UI
  - Replace linear "Initial Model Strength" bar with circular strength ring
  - Display 25% current strength with progress ring
  - Create growth path visualization: 25% → 50% → 75% → 100% milestones
  - Add explanation text below visualization:
    1. "Built from your choices: your roles, genres, tempo, vocal feel, mood"
    2. "Shapes every song: pre-fills the cockpit and steers generation toward your sound"
    3. "Grows with you: every song you make, keep, or edit sharpens it"
  - Add milestone unlock descriptions (product team to define)
  - Store milestone text in localized ARB files
  - _Requirements: REQ-VH011-06, REQ-VH011-07, REQ-VH011-08, REQ-VH011-09, NFR-L10N-03_
  - _Files: 
    - `lib/features/creator_dna/presentation/widgets/growth_path_widget.dart`
    - `lib/features/onboarding/presentation/views/onboarding_view.dart`
    - `lib/l10n/app_en.arb`_

- [ ] 26. Write DNA visualization tests
  - **Unit tests**:
    - Node color derivation from user selections
    - Node position calculation for double-helix layout
    - Animation progress interpolation
  - **Widget tests**:
    - DNA visualization renders with derived colors
    - Animation plays for 1800ms
    - Reduce-motion displays static version
    - Growth path shows 25% with milestones
  - **Performance test**:
    - Animation maintains 60fps on mid-range devices
    - Frame times < 16ms during animation
  - **Property test**: ∀ animation frames: 60fps maintained ∧ nodes colored from user choices
  - _Requirements: Property 6, Property 7, REQ-VH011-04, REQ-VH011-10, CCC-TEST-02, CCC-TEST-03_
  - _Files: `test/features/creator_dna/presentation/widgets/dna_visualization_widget_test.dart`_

---

### Phase 6: VH-012 App Tour & Coach Marks

- [ ] 27. Create AppTourState model and provider
  - Create `lib/features/onboarding/domain/models/app_tour_state.dart`
  - Add fields: `hasCompletedTour`, `lastViewedCardIndex`, `completedAt`
  - Implement `copyWith()` method
  - Create `app_tour_provider.dart` with `StateNotifierProvider`
  - Add methods: `viewCard(int index)`, `skipTour()`, `completeTour()`
  - Persist completion flag to SharedPreferences: `has_completed_app_tour`
  - _Requirements: REQ-VH012-06, CCC-STATE-02_
  - _Files: 
    - `lib/features/onboarding/domain/models/app_tour_state.dart`
    - `lib/features/onboarding/presentation/providers/app_tour_provider.dart`_

- [ ] 28. Create TourCard widget
  - Create `lib/features/onboarding/presentation/widgets/tour_card.dart`
  - Implement stateless widget accepting: title, description, icon, illustration
  - Display feature icon (large, 48px)
  - Display title in `AppTypography.headline6`
  - Display description in `AppTypography.bodyMedium`
  - Display illustration widget (optional, custom per card)
  - Add card padding and border radius
  - Support font scaling up to 200% without overflow
  - _Requirements: REQ-VH012-03, NFR-A11Y-05_
  - _Files: `lib/features/onboarding/presentation/widgets/tour_card.dart`_

- [ ] 29. Build AppTourOverlay with 3-5 cards
  - Create `lib/features/onboarding/presentation/overlays/app_tour_overlay.dart`
  - Implement `ConsumerStatefulWidget` with `PageController`
  - Create 5 tour cards:
    1. **Compose**: "Describe a song and generate a full track in under 2 minutes"
    2. **Write Lyrics First**: "AI drafts lyrics, you edit, then the beat"
    3. **Voice**: "Choose from 25+ African vocal timbres and dialects"
    4. **Crate & MPC**: "Dig through indigenous instruments and slice beats"
    5. **Library & Market**: "Start with 10 free credits, download stems, license commercially"
  - Add dot indicator showing position (e.g., "2 of 5")
  - Add "Skip Tour" button visible on every card
  - Add "Continue" button on cards 1-4, "Get Started" on card 5
  - Lazy-load card illustrations to reduce bundle size
  - _Requirements: REQ-VH012-01, REQ-VH012-02, REQ-VH012-03, REQ-VH012-04, REQ-VH012-05, NFR-PERF-04_
  - _Files: `lib/features/onboarding/presentation/overlays/app_tour_overlay.dart`_

- [ ] 30. Implement tour navigation and completion
  - Wire "Skip Tour" to `appTourProvider.notifier.skipTour()`
  - Wire "Continue" to advance PageView to next card
  - Wire "Get Started" on final card to `appTourProvider.notifier.completeTour()`
  - On completion/skip: dismiss overlay, navigate to Root_Shell
  - Persist completion flag to SharedPreferences
  - Check completion flag on app launch: skip tour if already completed
  - Add "Replay Onboarding Tour" option in Settings to reset flag
  - _Requirements: REQ-VH012-04, REQ-VH012-05, REQ-VH012-06, REQ-VH012-07_
  - _Files: `lib/features/onboarding/presentation/overlays/app_tour_overlay.dart`_

- [ ] 31. Create CoachMarkOverlay for Studio
  - Create `lib/features/studio/presentation/overlays/coach_mark_overlay.dart`
  - Implement overlay showing 2-3 contextual tooltips on first Studio visit:
    1. Prompt field: "Describe your song idea here"
    2. Genre selector: "Pick genres that fit your vibe"
    3. Generate CTA: "Tap to create your track"
  - Add dismissal behavior: tap overlay or "Got it" CTA
  - Persist dismissal flag to SharedPreferences: `has_dismissed_studio_coach_marks`
  - Show once per user account, never reappear after dismissal
  - _Requirements: REQ-VH012-08, REQ-VH012-09, CCC-STATE-03, NFR-UX-04_
  - _Files: `lib/features/studio/presentation/overlays/coach_mark_overlay.dart`_

- [ ] 32. Write app tour and coach mark tests
  - **Unit tests**:
    - Tour state management: viewCard, skipTour, completeTour
    - SharedPreferences persistence
  - **Widget tests**:
    - Tour overlay displays 5 cards
    - Skip button dismisses tour immediately
    - Continue advances to next card
    - Get Started completes tour
    - Tour does not reappear after completion
    - Coach marks display once on first Studio visit
    - Coach marks dismissible
  - **Property test**: ∀ tour interactions: skippable ∧ completion persisted
  - _Requirements: Property 8, Property 9, REQ-VH012-10, CCC-TEST-02_
  - _Files: 
    - `test/features/onboarding/presentation/overlays/app_tour_overlay_test.dart`
    - `test/features/studio/presentation/overlays/coach_mark_overlay_test.dart`_

---

### Phase 7: VH-013 Privacy Claim Audit

- [ ] 33. Conduct privacy data flow audit
  - Audit all data flows in Creator DNA and generation pipeline:
    - **On-device storage**: Check what data stored in Hive boxes
    - **Backend transmission**: Check what data sent to API endpoints
    - **Analytics**: Check what events/properties logged
    - **Cloud storage**: Check what data persisted in cloud databases
  - Document findings: what data goes where, when, why
  - Determine if DNA profiles are stored exclusively locally or transmitted
  - Determine if generation prompts are sent to backend
  - Determine if analytics events contain DNA profile data
  - _Requirements: REQ-VH013-01_

- [ ] 34. Create PRIVACY_DATA_FLOW.md documentation
  - Create `docs/compliance/PRIVACY_DATA_FLOW.md`
  - Document audit findings:
    - Data stored on-device (Hive storage)
    - Data transmitted to backend (API requests)
    - Data logged to analytics (events, properties)
    - Data retention policies
  - Include data flow diagrams (optional)
  - Add timestamp and audit author
  - Get product/legal team review and approval
  - _Requirements: REQ-VH013-05_
  - _Files: `docs/compliance/PRIVACY_DATA_FLOW.md`_

- [ ] 35. Update privacy claim wording
  - Remove current claim: "100% on-device sovereignty (zero cloud tracking)"
  - Based on audit findings, use approved wording:
    - **If DNA profile is local-only**: "Your DNA profile is stored on your device"
    - **If prompts sent to backend**: "Your DNA profile stays on your device. Generation prompts are sent securely to our servers to create your music."
  - Update `PrivacyClaimRow` widget with new claim text
  - Display as benefit row with lock icon on DNA activation screen
  - Get product team approval before deployment
  - _Requirements: REQ-VH013-02, REQ-VH013-03, REQ-VH013-04, REQ-VH013-06, REQ-VH013-07_
  - _Files: 
    - `lib/features/onboarding/presentation/views/onboarding_view.dart`
    - `lib/features/onboarding/presentation/widgets/privacy_claim_row.dart`_

- [ ] 36. Add privacy claim analytics tracking
  - Log `privacy_claim_displayed` event when DNA activation screen shown
  - Include property: `claim_text` set to displayed claim verbatim
  - Add to `AnalyticsService` if not already present
  - Enable A/B testing and compliance verification
  - _Requirements: REQ-VH013-08, Property 10_
  - _Files: `lib/features/onboarding/presentation/views/onboarding_view.dart`_

---

### Phase 8: Integration, Analytics & Final Testing

- [ ] 37. Integrate all analytics events for onboarding flow
  - Add analytics events to `AnalyticsService`:
    - `onboarding_step_completed` (step_name, duration_sec)
    - `onboarding_step_skipped` (step_name)
    - `carousel_card_selected` (role, selection_method)
    - `genre_selected` (genre, color_displayed)
    - `mood_selected` (mood, color_displayed)
    - `dna_visualization_viewed` (view_duration_sec, animation_completed)
    - `app_tour_started` (timestamp)
    - `app_tour_card_viewed` (card_index, card_title)
    - `app_tour_completed` (duration_sec)
    - `app_tour_skipped` (skipped_at_card_index)
    - `privacy_claim_displayed` (claim_text)
  - Wire events to appropriate UI interactions
  - Ensure events do not block UI thread
  - _Requirements: NFR-ANALYTICS-01, REQ-VH012-10_
  - _Files: 
    - `lib/core/services/analytics_service.dart`
    - All onboarding widgets_

- [ ] 38. Write end-to-end onboarding flow test
  - Create integration test covering complete flow:
    1. VH-007: Select role from carousel
    2. VH-008: Select genres with color chips
    3. Skip languages screen
    4. VH-009: Select tempo/vocal with natural language
    5. VH-010: Select moods with color chips
    6. VH-011: View DNA visualization animation
    7. VH-012: Complete or skip app tour
  - Verify navigation to Root_Shell
  - Verify analytics events fired
  - Verify DNA profile seeded correctly
  - _Requirements: CCC-TEST-02_
  - _Files: `test/features/onboarding/onboarding_flow_integration_test.dart`_

- [ ] 39. Performance profiling and optimization
  - **Carousel scroll performance**:
    - Profile scroll FPS at 60fps target
    - Measure frame times during continuous scroll
    - Optimize with `RepaintBoundary` if needed
  - **DNA animation performance**:
    - Profile animation FPS at 60fps target
    - Measure paint times for `CustomPainter`
    - Reduce complexity if frame drops detected
  - **App tour lazy loading**:
    - Verify illustrations loaded only when card visible
    - Measure bundle size reduction (target: 200KB saved)
  - Test on mid-range devices: Snapdragon 720G, A12 Bionic
  - _Requirements: NFR-PERF-01, NFR-PERF-02, NFR-PERF-04, Property 6_

- [ ] 40. Accessibility audit
  - **Screen reader support**:
    - Test carousel cards with VoiceOver (iOS) and TalkBack (Android)
    - Verify semantic labels describe role, title, selection state
    - Verify genre/mood chips have labels
  - **Keyboard navigation** (desktop/tablet):
    - Test Tab to focus, Arrow keys to scroll carousel
    - Verify focus indicators visible
  - **Reduce-motion compliance**:
    - Enable system reduce-motion setting
    - Verify carousel snap animation disabled
    - Verify DNA visualization static
    - Verify app tour transitions simplified
  - **Color independence**:
    - Verify genre/mood chips use check marks, not just color
    - Test with color blindness simulator
  - **Font scaling**:
    - Test at 100%, 130%, 150%, 200% system font size
    - Verify no text truncation or layout overflow
  - **Touch targets**:
    - Verify all interactive elements ≥ 44×44px
  - _Requirements: NFR-A11Y-01, NFR-A11Y-02, NFR-A11Y-03, NFR-A11Y-04, NFR-A11Y-05, NFR-A11Y-06, Property 7_

- [ ] 41. Responsive layout testing
  - Test onboarding screens at multiple viewport sizes:
    - **360×640dp**: Small phone (critical baseline)
    - **375×667dp**: iPhone SE
    - **414×896dp**: Large phone
    - **768×1024dp**: Tablet
  - Verify carousel visible and scrollable
  - Verify genre/mood chips wrap correctly
  - Verify DNA visualization scales appropriately
  - Verify app tour cards readable
  - Verify DNA CTA button does not overflow
  - _Requirements: NFR-UX-01, NFR-RWD-01 (implied), REQ-VH007-10_

- [ ] 42. Test onboarding state persistence
  - Verify `OnboardingState` persisted to Hive after each screen
  - Force app crash mid-onboarding, relaunch, verify resume
  - Test backward navigation: restore selected role, genres, moods
  - Verify app tour completion flag persists across app restarts
  - Verify coach mark dismissal flag persists
  - _Requirements: CCC-STATE-01, CCC-STATE-02, CCC-STATE-03_

- [ ] 43. Verify backward compatibility with existing DNA profiles
  - Load app with existing DNA profile from previous version
  - Verify internal enum values unchanged (tempo, vocal, mood)
  - Verify DNA profile fields map correctly
  - Verify no data loss or corruption
  - Test migration: old profile → new onboarding flow → update profile
  - _Requirements: REQ-VH009-06, Property 5_

- [ ] 44. Run complete test suite and static analysis
  - Execute: `flutter test` — verify 991+ tests passing
  - Execute: `flutter analyze` — verify 0 errors, 0 warnings
  - Execute: `flutter test --coverage` — verify coverage ≥ 80%
  - Review any new warnings or deprecations
  - Fix any test failures or analyzer issues
  - _Requirements: CCC-TEST-01_

- [ ] 45. Final acceptance criteria validation
  - Manually verify all 63 acceptance criteria:
    - REQ-VH007-01 through REQ-VH007-10 (10 criteria)
    - REQ-VH008-01 through REQ-VH008-08 (8 criteria)
    - REQ-VH009-01 through REQ-VH009-07 (7 criteria)
    - REQ-VH010-01 through REQ-VH010-08 (8 criteria)
    - REQ-VH011-01 through REQ-VH011-10 (10 criteria)
    - REQ-VH012-01 through REQ-VH012-10 (10 criteria)
    - REQ-VH013-01 through REQ-VH013-08 (8 criteria)
  - Document pass/fail for each criterion
  - Address any failures before deployment
  - Get product team sign-off
  - _Requirements: All acceptance criteria_

---

## Notes

### Design Token Guidelines

- **ZERO hardcoded hex colors** in presentation widgets — all colors MUST reference `AppColors` constants
- Genre and mood color tokens are the source of truth for all color usage across the app
- Haptic feedback MUST respect system settings and gracefully no-op when disabled
- All new color tokens MUST pass WCAG 4.5:1 contrast ratio check

### Testing Strategy

- **Property-based tests** validate universal correctness properties from design document
- **Widget tests** verify UI behavior and user interactions
- **Integration tests** validate end-to-end flows
- **Performance tests** ensure 60fps on mid-range devices
- **Accessibility tests** ensure WCAG 2.1 Level AA compliance

### Performance Budget

- Carousel scroll: 60fps (< 16ms per frame)
- DNA animation: 60fps (< 16ms per frame)
- Onboarding completion + navigation: < 800ms on 4G
- App tour illustration bundle: < 200KB reduction via lazy loading

### Accessibility Requirements

- All animations MUST respect reduce-motion setting
- All interactive elements MUST have ≥ 44×44px touch targets
- All color-coded states MUST include non-color indicators (icons, borders)
- All widgets MUST include semantic labels for screen readers
- All layouts MUST support font scaling up to 200%

### Privacy Compliance

- Privacy audit MUST be completed before production deployment
- Privacy claim wording MUST be approved by product/legal teams
- NO misleading claims allowed ("zero cloud tracking" if data transmitted)
- Analytics events MUST track privacy claim display for compliance verification

### Backward Compatibility

- Internal `OnboardingState` enum values MUST remain unchanged
- Creator DNA field mappings MUST remain unchanged
- Existing DNA profiles MUST continue working without migration
- New natural language copy MUST map to existing internal enums

### Follow-Up Tasks

- **Localization**: Translate natural language copy to Tshivenḓa, isiZulu, other African languages
- **Analytics Dashboard**: Create dashboard to track app tour completion rates, skip rates, card-level engagement
- **DNA Growth Path**: Define milestone unlock descriptions (25% → 50% → 75% → 100%) with product team
- **Advanced Haptics**: Consider more nuanced haptic patterns for carousel snap and DNA animation
- **Illustrations**: Commission custom illustrations for app tour cards (currently using icons + placeholders)

---

## Task Dependency Graph

```json
{
  "waves": [
    {
      "id": 0,
      "tasks": ["1", "2", "3", "4", "5", "6"]
    },
    {
      "id": 1,
      "tasks": ["7", "11", "14", "17", "18", "21", "27", "28", "33"]
    },
    {
      "id": 2,
      "tasks": ["8", "12", "15", "19", "22", "29"]
    },
    {
      "id": 3,
      "tasks": ["9", "13", "16", "20", "23", "30", "34"]
    },
    {
      "id": 4,
      "tasks": ["10", "24", "31", "35"]
    },
    {
      "id": 5,
      "tasks": ["25", "32", "36"]
    },
    {
      "id": 6,
      "tasks": ["26", "37"]
    },
    {
      "id": 7,
      "tasks": ["38", "39", "40", "41", "42", "43"]
    },
    {
      "id": 8,
      "tasks": ["44", "45"]
    }
  ]
}
```

**Dependency Graph Explanation:**

- **Wave 0**: Foundation tasks (HapticService, color tokens, localization) — all independent, run in parallel
- **Wave 1**: Core widget creation for each VH requirement — can run in parallel after foundation
- **Wave 2**: Widget integration into onboarding screens — depends on widget creation
- **Wave 3**: Gesture handling, animations, navigation — depends on widget integration
- **Wave 4**: Testing and fallbacks — depends on feature implementation
- **Wave 5**: Growth path, coach marks, analytics — depends on core features
- **Wave 6**: DNA tests and analytics integration — depends on growth path
- **Wave 7**: Integration testing, profiling, audits — depends on all features complete
- **Wave 8**: Final validation and sign-off — depends on all testing complete

**Parallelization Opportunities:**

After foundation (Wave 0), most VH requirements can be developed in parallel:
- VH-007 (carousel) tasks 7-10
- VH-008/010 (colors) tasks 11-16
- VH-009 (natural language) tasks 17-20
- VH-011 (DNA viz) tasks 21-26
- VH-012 (app tour) tasks 27-32
- VH-013 (privacy) tasks 33-36

This allows a team of 3-4 developers to work concurrently with minimal coordination overhead after foundation is established.

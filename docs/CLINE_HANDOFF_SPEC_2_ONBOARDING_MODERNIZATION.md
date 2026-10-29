# 🚀 CLINE HANDOFF: Spec 2 — Onboarding Experience Modernization (VH-007 to VH-013)

> **Document Type:** Master Implementation Handoff & Prompt Contract  
> **Target Agent:** Cline / DeepSeek V4 Flash (1M Context Headroom)  
> **Architect & QA Gatekeeper:** Antigravity IDE  
> **Status:** Ready for Execution  
> **Baseline Health:** `flutter analyze` = **0 issues (100% clean)** | `flutter test` = **1,030 / 1,030 passing (100%)**  
> **Target Workspace:** `apps/vhunambi_client`  
> **Authoritative Specs:**  
> - `.kiro/specs/onboarding-modernization/requirements.md` (63 Acceptance Criteria)  
> - `.kiro/specs/onboarding-modernization/design.md` (Component Architecture & Models)  
> - `.kiro/specs/onboarding-modernization/tasks.md` (Implementation Checklist & Dependency Waves)  

---

## 1. Executive Summary & Mission

You are implementing **Spec 2: Onboarding Experience Modernization** for VHUNAMBI. This feature transforms the 6-screen onboarding flow from a functional questionnaire into an immersive, visually rich brand experience that educates users about Creator DNA and African musical heritage.

### Deliverables Covered (VH-007 through VH-013):
1. **VH-007 (P1):** Creative Identity horizontal card carousel with haptic feedback & gesture isolation
2. **VH-008 (P2):** Genre Heritage per-genre color token system & `GenreColorChip`
3. **VH-009 (P1):** Sound Signature plain-language tempo & vocal copy with African genre references
4. **VH-010 (P2):** Mood per-mood color token system & `MoodColorChip`
5. **VH-011 (P1):** Creator DNA animated visualization with growth path explanation
6. **VH-012 (P1):** Onboarding app tour (3–5 cards) and contextual coach marks
7. **VH-013 (P0):** Privacy claim audit and accurate rewording (`docs/PRIVACY_DATA_FLOW.md`)

---

## 2. Verified Foundations Implemented by Chief Architect (Antigravity)

Before this handoff, Antigravity established and verified the core infrastructure from Spec 4 (Cross-Cutting Design System):

1. **`DesignTokenRegistry` & `TokenRegistration`**:
   - Location: `lib/core/design_system/tokens/`
   - 8 Genre tokens (Amapiano, Afro House, Gqom, Kwaito, Afro Pop, Maskandi, Hip-Hop, Gospel)
   - 5 Mood tokens (Joyful, Melancholic, Energetic, Calm, Romantic)
   - Each token provides `accent`, `surfaceTint`, `glow`, and WCAG AA compliant `textColor`.
2. **`VhunambiThemeExtension`**:
   - Location: `lib/core/design_system/theme/vhunambi_theme_extension.dart`
   - Access via `VhunambiThemeExtension.of(context)`
   - Methods: `genreAccent(genre)`, `genreSurfaceTint(genre)`, `genreGlow(genre)`, `genreTextColor(genre)`
   - Mood methods: `moodAccent(mood)`, `moodSurfaceTint(mood)`, `moodGlow(mood)`, `moodTextColor(mood)`
   - Built-in safe fallbacks ensure widgets never throw `TokenNotFoundException`.
3. **`HapticsService`**:
   - Location: `lib/core/design_system/services/haptics_service.dart`
   - Methods: `lightImpact()`, `mediumImpact()`, `heavyImpact()`, `selectionTick()`, `vibrate()`
4. **`AccessibilityService`**:
   - Location: `lib/core/design_system/services/accessibility_service.dart`
   - Methods: `isReduceMotionEnabled(context)`, `getTextScaleFactor(context)`, `ensureTouchTarget(...)`, `genreChipLabel(...)`, etc.
5. **`AnalyticsService`**:
   - Location: `lib/core/design_system/services/analytics_service.dart`
   - Methods: `recordEvent(name, parameters)`, `flush()`

---

## 3. Strict Codebase Invariants & Non-Negotiable Rules

When authoring Dart code, you **MUST ALWAYS** follow these rules without exception:

1. **Zero Raw Hex Colors**:
   - Never use `Color(0xFF...)` or raw hex values in UI widgets.
   - Always use `AppColors.*` or `VhunambiThemeExtension.of(context).*`.
2. **Zero Raw Typography**:
   - Never use ad-hoc `TextStyle(...)`. Use `AppTypography.*` from `lib/core/theme/app_typography.dart`.
3. **Touch Targets (WCAG 2.5.5 / Apple HIG)**:
   - Every tap target (card, chip, button, icon trigger) must be at least **44×44dp**.
   - Use `BoxConstraints(minWidth: 44, minHeight: 44)` or `AccessibilityService.ensureTouchTarget(...)`.
4. **Hydration & Animation Safety**:
   - Respect `AccessibilityService.isReduceMotionEnabled(context)`. If true, bypass animated curves and render completed states.
5. **Deterministic Testing & Mandatory Widget Keys**:
   - Every interactive element and new component must specify an explicit `Key`:
     - `Key('role_carousel')`
     - `Key('role_card_${role.name}')`
     - `Key('genre_chip_${genre.name}')`
     - `Key('mood_chip_${mood.name}')`
     - `Key('sound_tempo_${tempo.name}')`
     - `Key('sound_vocal_${energy.name}')`
     - `Key('dna_visualization')`
     - `Key('dna_growth_path_card')`
     - `Key('app_tour_overlay')`
     - `Key('tour_skip_btn')`
     - `Key('tour_next_btn')`
     - `Key('tour_finish_btn')`
6. **Test Baseline Protection**:
   - The starting baseline is **1,030 / 1,030 passing tests**.
   - All existing tests in `test/features/onboarding/` and `test/features/creator_dna/` must remain **100% green**.

---

## 4. Implementation Tracks (Step-by-Step)

### Track A: Interactive Components & Atoms

#### A1. Role Carousel Widget (VH-007)
* **File:** `lib/features/onboarding/presentation/widgets/role_carousel_widget.dart` (NEW)
* **Requirements:** `REQ-VH007-01` through `REQ-VH007-08`
* **Details:**
  - Build a horizontal carousel using `PageView.builder` with `controller: PageController(viewportFraction: 0.72)`.
  - **Gesture Conflict Resolution (Critical):** The onboarding flow itself is inside a parent horizontal `PageView`. To prevent horizontal card swipes from flipping the parent onboarding screen, wrap the carousel in a `GestureDetector` with `behavior: HitTestBehavior.opaque` or use a dedicated nested scroll controller with physics that consumes horizontal drags.
  - Scale center card to `1.0` (opacity `1.0`); scale adjacent cards to `0.88` (opacity `0.6`).
  - Tapping a role card triggers a check mark animation (200ms), slight bounce/scale (`1.03` for 150ms), and calls `HapticsService().lightImpact()`.
  - Snapping to a new card during scroll calls `HapticsService().selectionTick()`.
  - Binds to `CreativeRole` values (`producer`, `vocalist`, `instrumentalist`, `songwriter`, `curator`).

#### A2. Genre Color Chip (VH-008)
* **File:** `lib/features/onboarding/presentation/widgets/genre_color_chip.dart` (NEW)
* **Requirements:** `REQ-VH008-01` through `REQ-VH008-06`
* **Details:**
  - Displays a musical genre with its distinct brand color from `VhunambiThemeExtension.of(context).genreAccent(genre)`.
  - When selected: tinted surface background (`genreSurfaceTint`), colored border, soft glow, and checkmark.
  - Text color guarantees WCAG AA (4.5:1) contrast.
  - Minimum hit area: 44×44dp.
  - Tapping calls `HapticsService().selectionTick()`.

#### A3. Plain-Language Sound Signature Cards (VH-009)
* **File:** `lib/features/onboarding/presentation/widgets/sound_signature_tempo_card.dart` and `sound_signature_vocal_card.dart` (NEW or update `sound_signature_picker.dart`)
* **Requirements:** `REQ-VH009-01` through `REQ-VH009-08`
* **Details:**
  - Replace raw BPM text with human-friendly descriptors and African genre anchors:
    - **Laid Back** (80–100 BPM: Slow Amapiano, Afro R&B)
    - **Steady Groove** (100–115 BPM: Medium Amapiano, Afro Pop)
    - **Upbeat & Driving** (115–125 BPM: Classic House, Kwaito)
    - **Fast & Frenetic** (125–135+ BPM: Gqom, Fast Afro Tech)
  - Replace vocal technical terms:
    - **Subtle & Atmospheric** (ambient textures, soft whispers)
    - **Balanced & Melodic** (lead melodic singing, vocal harmonies)
    - **Dominant & Raw** (energetic chants, spoken word, anthems)
  - **Backward Compatibility:** Internal state must store the original enum / string values (`slow`, `medium`, `fast`, `subtle`, `balanced`, `high`) so existing profiles and synthesis models do not break.

#### A4. Mood Color Chip (VH-010)
* **File:** `lib/features/onboarding/presentation/widgets/mood_color_chip.dart` (NEW)
* **Requirements:** `REQ-VH010-01` through `REQ-VH010-06`
* **Details:**
  - Renders the 5 core moods: Joyful, Melancholic, Energetic, Calm, Romantic.
  - Uses `VhunambiThemeExtension.of(context).moodAccent(mood)`.
  - Minimum 1 mood required (prevents empty selection).
  - Minimum 44×44dp touch target with haptic tick on selection.

#### A5. Creator DNA Visualization Widget (VH-011)
* **File:** `lib/features/creator_dna/presentation/widgets/dna_visualization_widget.dart` (NEW)
* **Requirements:** `REQ-VH011-01` through `REQ-VH011-08`
* **Details:**
  - Animated visual representation of the user's Creator DNA built using a custom painter (`DnaPainter`).
  - Visualizes the 4 DNA layers: Creative Role, Genre Heritage, Sound Signature, Language Sovereignty.
  - Sequential reveal animation (1.2 seconds total):
    1. Base concentric audio rings emerge
    2. Genre color spectrum glows along the rings
    3. Rhythm pulse reflects tempo selection
    4. Completeness meter advances to 50%
  - Growth path card below the animation:
    - "Your DNA begins calibrated at 50% from onboarding choices."
    - "As you generate and refine tracks in the Studio, your DNA learns your exact sonic fingerprint and deepens personalization."
  - Reduce-motion: If `AccessibilityService.isReduceMotionEnabled(context)` is true, render static final state immediately without animation controller looping.

---

### Track B: Onboarding View Screen Integration

#### B1. Integrate into `OnboardingView` (`lib/features/onboarding/presentation/views/onboarding_view.dart`)
* **Slide 1 (Creative Identity):** Replace the static vertical column with `RoleCarouselWidget`.
* **Slide 2 (Genre Heritage):** Use `GenreColorChip` for genre selection with regional groupings.
* **Slide 3 (Language Sovereignty):** Keep 25+ indigenous African languages with 44px pill chips.
* **Slide 4 (Sound Signature):** Replace technical BPM inputs with the natural-language tempo and vocal energy cards.
* **Slide 5 (Mood Palette):** Use `MoodColorChip` for mood selection with glowing selection states.
* **Slide 6 (Creator DNA Activation):** Integrate `DnaVisualizationWidget` and the DNA growth path card.
* **Slide Transitions:** Ensure smooth forward/back navigation while keeping state synced with `onboardingNotifierProvider`.

---

### Track C: App Tour & Privacy Audit

#### C1. App Tour Overlay (VH-012)
* **File:** `lib/features/onboarding/presentation/widgets/app_tour_overlay.dart` (NEW)
* **Requirements:** `REQ-VH012-01` through `REQ-VH012-08`
* **Details:**
  - Modal overlay shown upon completing the 6th slide or on first arrival at the main shell.
  - 4 high-impact tour slides:
    1. **Explore:** Discover trending African AI music and remix community sounds.
    2. **Studio Cockpit:** Synthesize complete songs with indigenous language lyrics and regional log drums.
    3. **Asset Vault:** Stem separation, lossless WAV downloads, and blockchain licensing certificates.
    4. **Marketplace:** Buy and sell commercial beats with instant license agreements.
  - "Skip" (top-right) and "Next" / "Get Started" (bottom) actions.
  - Persist `has_completed_app_tour` boolean in `SharedPreferences`.
  - Replayable on demand via `AppTourOverlay.show(context)`.

#### C2. Privacy Claim Audit & Documentation (VH-013)
* **File:** `docs/PRIVACY_DATA_FLOW.md` (NEW)
* **Requirements:** `REQ-VH013-01` through `REQ-VH013-04`
* **Details:**
  - Review all privacy strings on Slide 6 and across the app.
  - Remove any misleading claims like *"Zero data ever leaves your device"* (audio synthesis requires cloud GPU inference).
  - Replace with audited, accurate claim:
    > *"Your creator profile, DNA preferences, and session history remain sovereign on your device. Audio generation is processed via private, encrypted GPU clusters with zero model training on your unreleased prompts."*
  - Document client vs. server data flows in `docs/PRIVACY_DATA_FLOW.md`.

---

### Track D: Comprehensive Test Suite

Create and run automated tests:
1. `test/features/onboarding/widgets/role_carousel_widget_test.dart`
   - Test horizontal swipe, center card scale factor, selection haptic, reduce-motion respect.
2. `test/features/onboarding/widgets/genre_color_chip_test.dart`
   - Test 8 genre colors, selected state, contrast ratio, selection callback.
3. `test/features/onboarding/widgets/mood_color_chip_test.dart`
   - Test 5 mood colors, minimum 1 selection preservation.
4. `test/features/creator_dna/widgets/dna_visualization_widget_test.dart`
   - Test painter render, growth path card copy, reduce-motion static render.
5. `test/features/onboarding/widgets/app_tour_overlay_test.dart`
   - Test slide navigation, skip button, SharedPreferences persistence flag.
6. Verify full regression:
   - `test/features/onboarding/onboarding_view_test.dart`
   - `test/features/onboarding/onboarding_notifier_test.dart`

---

## 5. Verification Commands for Cline

Execute these commands before declaring completion:

```powershell
# 1. Analyze for zero errors, warnings, and infos
cd apps/vhunambi_client
flutter analyze

# 2. Run onboarding and creator DNA tests
flutter test test/features/onboarding/ test/features/creator_dna/

# 3. Run the complete test suite to ensure NO regressions (1,030+ passing tests)
flutter test
```

---

## 6. Copy-Paste Prompt for Cline

Copy and paste the exact prompt below into Cline to begin work:

```markdown
You are the implementation workhorse for VHUNAMBI under the Dual-Agent Pair Programming Standard.
Antigravity (Chief Architect) has verified the repository health:
- flutter analyze: 0 issues (100% clean)
- flutter test: 1,030 / 1,030 tests passing (100%)
- DesignTokenRegistry, VhunambiThemeExtension, HapticsService, and AccessibilityService are fully operational.

Please execute Spec 2: Onboarding Experience Modernization (VH-007 through VH-013) according to:
- docs/CLINE_HANDOFF_SPEC_2_ONBOARDING_MODERNIZATION.md
- .kiro/specs/onboarding-modernization/requirements.md
- .kiro/specs/onboarding-modernization/design.md
- .kiro/specs/onboarding-modernization/tasks.md

Follow all architectural rules strictly:
1. Zero raw hex colors (use AppColors and VhunambiThemeExtension).
2. 44x44 minimum touch targets on all interactive elements.
3. Explicit Keys on every new interactive widget.
4. Gesture conflict isolation on the RoleCarouselWidget so horizontal carousel swipes do not trigger the parent PageView.
5. Accurate privacy wording (VH-013) and create docs/PRIVACY_DATA_FLOW.md.
6. All 1,030 baseline tests must remain green + add new widget tests for all new components.

Begin with Track A (RoleCarouselWidget, GenreColorChip, SoundSignature cards, MoodColorChip, DnaVisualizationWidget), proceed through Track B (OnboardingView integration), Track C (AppTourOverlay & Privacy), and verify with Track D.
```

# Implementation Plan: Creator DNA & Adaptive Intelligence

> **System:** M9 / `creator-dna-adaptive-intelligence`  
> **Pre-flight Baseline:** `dart analyze lib test` = **0 issues** | `flutter test` = **813/813 passing**  
> **Target:** ≥ 845 tests (≥ 32 new), 0 regressions  
> **Architecture Rules:** Zero `build_runner`, zero `@HiveType`, zero raw hex colors, 44×44px touch bounds

---

## Pre-Flight Verification

Before touching any code, verify the baseline is clean:

```powershell
cd apps/vhunambi_client
dart analyze lib test        # Must report: No issues found!
flutter test                 # Must report: 813 tests passed
git status                   # Must report: clean working tree
```

---

## Track A: New Directory Structure & Constants

- [x] **T1.1** — Register DNA box key in [app_constants.dart](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/core/constants/app_constants.dart) *(modify)*
  - Add: `static const String creatorDnaBoxKey = 'vhunambi_creator_dna';`
  - _Requirements: REQ-DNA-OB-11_

- [x] **T1.2** — Create directory skeleton *(new directories)*
  ```
  lib/features/creator_dna/
    domain/
      entities/
      models/
      services/
    data/
      repositories/
    presentation/
      providers/
      widgets/
  test/features/creator_dna/
    domain/
      data/
      presentation/
  ```

---

## Track B: Domain Entities & Models

- [x] **T2.1** — Create `CreatorDnaProfile` entity *(new)*
  - File: `lib/features/creator_dna/domain/entities/creator_dna_profile.dart`
  - Implement `DnaLifecycleState`, `CreativeRole`, `ExperienceLevel` enums.
  - Implement full `CreatorDnaProfile` class with `toJson()`, `fromJson()`, `copyWith()`, `strengthPercent` getter, and `topGenres(n)` method.
  - Widget keys: n/a (domain model)
  - _Requirements: REQ-DNA-CAP-04, REQ-DNA-CAP-05_

- [x] **T2.2** — Create `BehaviorEvent` model *(new)*
  - File: `lib/features/creator_dna/domain/models/behavior_event.dart`
  - Implement all `BehaviorEventType` values and named factory constructors (`trackPlay`, `trackLike`, `trackSkip`, `generationSubmit`, `genreFilterTap`).
  - Implement `toJson()` / `fromJson()`.
  - _Requirements: REQ-DNA-CAP-03_

- [x] **T2.3** — Create `StudioDnaDefaults` model *(new)*
  - File: `lib/features/creator_dna/domain/models/studio_dna_defaults.dart`
  - Implement with `hasDnaDefaults` flag, `genre`, `language`, `tempo`, `vocalEnergy`, `mood` fields.
  - _Requirements: REQ-DNA-STU-01_

- [x] **T2.4** — Create `DnaExploreRanker` service *(new)*
  - File: `lib/features/creator_dna/domain/services/dna_explore_ranker.dart`
  - Implement static `rank(List<Map<String, dynamic>> tracks, CreatorDnaProfile dna)` method.
  - Pure synchronous Dart — zero async, zero network.
  - _Requirements: REQ-DNA-EXP-01_

- [x] **T2.5** — Write domain unit tests *(new)*
  - File: `test/features/creator_dna/domain/creator_dna_profile_test.dart`
  - Test: `strengthPercent` computation at 0 events, 50 events, 200+ events.
  - Test: `fromJson(toJson(entity)) == entity` round-trip fidelity.
  - Test: `topGenres(2)` returns highest-weighted 2 genres.
  - Test: `_computeNewLifecycle` transitions: seeded → learning → calibrated → attuned.
  - File: `test/features/creator_dna/domain/dna_explore_ranker_test.dart`
  - Test: rank boosts DNA-matching genre tracks to top.
  - Test: no-op when `!dna.onboardingCompleted`.
  - _Requirements: REQ-DNA-CAP-04, REQ-DNA-CAP-05, REQ-DNA-EXP-01_

---

## Track C: Data Repository

- [x] **T3.1** — Create `CreatorDnaRepository` *(new)*
  - File: `lib/features/creator_dna/data/repositories/creator_dna_repository.dart`
  - Implement: `loadProfile()`, `saveProfile()`, `loadEventLog()`, `appendEvent()`, `clearAll()`.
  - Untyped `Box? _box` with lazy open.
  - In-memory fallback: all operations silently no-op when `_box == null`.
  - 500-event FIFO sliding window in `appendEvent()`.
  - _Requirements: REQ-DNA-OB-11, REQ-DNA-NFR-03_

- [x] **T3.2** — Write repository unit tests *(new)*
  - File: `test/features/creator_dna/data/creator_dna_repository_test.dart`
  - Test: `loadProfile()` returns `CreatorDnaProfile.initial()` when box is empty.
  - Test: `saveProfile()` → `loadProfile()` round-trip preserves all fields.
  - Test: `appendEvent()` respects 500-event cap.
  - Test: All methods no-op gracefully when Hive box fails to open (in-memory mode).
  - _Requirements: REQ-DNA-NFR-03_

---

## Track D: State Management — DNA Provider

- [x] **T4.1** — Create `CreatorDnaNotifier` and `creatorDnaProvider` *(new)*
  - File: `lib/features/creator_dna/presentation/providers/creator_dna_provider.dart`
  - Implement `CreatorDnaNotifier extends StateNotifier<CreatorDnaProfile>`.
  - Implement: `seedFromOnboarding(...)`, `recordEvent(BehaviorEvent)`, `dismissInsightCard()`, `resetDna()`.
  - Implement: `_applyEventToWeights()` private method with all weight deltas.
  - Implement: `_computeLifecycle()` private method.
  - Provide: `creatorDnaRepositoryProvider` and `creatorDnaProvider`.
  - _Requirements: REQ-DNA-CAP-01, REQ-DNA-CAP-02, REQ-DNA-CAP-04_

- [x] **T4.2** — Create `dnaStudioDefaultsProvider` *(new)*
  - File: `lib/features/creator_dna/presentation/providers/dna_studio_defaults_provider.dart`
  - Implement derived `Provider<StudioDnaDefaults>` watching `creatorDnaProvider`.
  - Map `dna.tempoPreference` → `TempoBracket`, `dna.vocalEnergyPreference` → `VocalEnergy`.
  - _Requirements: REQ-DNA-STU-01, REQ-DNA-STU-02_

- [x] **T4.3** — Write provider unit tests *(new)*
  - File: `test/features/creator_dna/presentation/providers/creator_dna_provider_test.dart`
  - Test: Initial state is `CreatorDnaProfile.initial()`.
  - Test: `seedFromOnboarding` sets `genreWeights`, `primaryLanguage`, `lifecycleState = seeded`.
  - Test: `recordEvent(BehaviorEvent.trackLike(...))` increments genre weight by +0.30.
  - Test: `recordEvent(BehaviorEvent.trackSkip(secondsBeforeSkip: 3))` decrements genre weight by -0.10.
  - Test: `recordEvent` triggers lifecycle transition from `seeded` → `learning` after >0 events.
  - Test: `resetDna()` resets state to `CreatorDnaProfile.initial()`.
  - Test: `dnaStudioDefaultsProvider` maps top genre and primary language correctly.
  - Test: `dnaStudioDefaultsProvider.hasDnaDefaults == false` when DNA is uninitialized.
  - _Requirements: REQ-DNA-CAP-01, REQ-DNA-CAP-04, REQ-DNA-STU-01_

---

## Track E: Onboarding Enhancement

- [x] **T5.1** — Extend `OnboardingState` with new fields *(modify)*
  - File: `lib/features/onboarding/domain/models/onboarding_models.dart`
  - Add fields: `creativeRole`, `experienceLevel`, `primaryLanguage`, `selectedMoods`, `tempoPreference`, `vocalEnergyPreference`, `onboardingCompleteness`.
  - All fields additive with backward-compatible defaults.
  - Extend `copyWith()` and update `==`/`hashCode`.
  - _Requirements: REQ-DNA-OB-12_

- [x] **T5.2** — Extend `OnboardingNotifier` *(modify)*
  - File: `lib/features/onboarding/presentation/providers/onboarding_providers.dart`
  - Add methods: `setCreativeRole()`, `setExperienceLevel()`, `setPrimaryLanguage()`, `toggleMood()`, `setTempoPreference()`, `setVocalEnergyPreference()`.
  - Preserve existing `toggleGenre()`, `toggleLanguage()`, `setUserRole()`, `completeOnboarding()`, `resetOnboarding()`.
  - _Requirements: REQ-DNA-OB-12_

- [x] **T5.3** — Expand `OnboardingView` to 6 slides *(modify)*
  - File: `lib/features/onboarding/presentation/views/onboarding_view.dart`
  - Expand `PageController` from 3 to 6 pages.
  - Add `_buildIdentitySlide()`, `_buildGenreSlide()` (replaces old), `_buildLanguageSlide()` (replaces old), `_buildSoundSignatureSlide()`, `_buildDnaActivationSlide()`.
  - Update step indicator from 3 dots to 6 dots.
  - Replace `completeOnboarding()` call with: `creatorDnaProvider.notifier.seedFromOnboarding(...)` then `onboardingStateProvider.notifier.completeOnboarding()`.
  - **Widget Keys added:**
    - `Key('onboarding_role_card_producer')`, `Key('onboarding_role_card_vocalist')`, `Key('onboarding_role_card_songwriter')`, `Key('onboarding_role_card_multi_hyphenate')`, `Key('onboarding_role_card_music_lover')`
    - `Key('onboarding_experience_newbie')`, `Key('onboarding_experience_growing')`, `Key('onboarding_experience_pro')`
    - `Key('onboarding_genre_chip_$genre')` for each genre
    - `Key('onboarding_primary_language_$lang')` for each language
    - `Key('onboarding_tempo_slow')`, `Key('onboarding_tempo_medium')`, `Key('onboarding_tempo_fast')`, `Key('onboarding_tempo_hyperspeed')`
    - `Key('onboarding_dna_activate_cta')`
  - _Requirements: REQ-DNA-OB-01 through REQ-DNA-OB-10_

---

## Track F: Presentation Widgets

- [x] **T6.1** — Create `DnaStrengthMeter` *(new)*
  - File: `lib/features/creator_dna/presentation/widgets/dna_strength_meter.dart`
  - Animated `LinearProgressIndicator`-style bar.
  - Color zones: 0–40% `AppColors.accentElectric`, 40–70% `AppColors.accentGold`, 70–100% `AppColors.accentSuccess`.
  - `animated: bool` flag — when `false`, no `AnimationController` (headless test safe).
  - Key: `Key('dna_strength_meter')`
  - _Requirements: REQ-DNA-OB-10, REQ-DNA-HOME-01_

- [x] **T6.2** — Create `DnaGenreBadge` *(new)*
  - File: `lib/features/creator_dna/presentation/widgets/dna_genre_badge.dart`
  - Key: `Key('dna_genre_badge_${genre.toLowerCase()}')`
  - _Requirements: REQ-DNA-HOME-01, REQ-DNA-NFR-01_

- [x] **T6.3** — Create `CreativeRoleCard` *(new)*
  - File: `lib/features/creator_dna/presentation/widgets/creative_role_card.dart`
  - Minimum `BoxConstraints(minHeight: 56, minWidth: double.infinity)` for mobile.
  - _Requirements: REQ-DNA-OB-05, REQ-DNA-NFR-02_

- [x] **T6.4** — Create `SoundSignaturePicker` *(new)*
  - File: `lib/features/creator_dna/presentation/widgets/sound_signature_picker.dart`
  - Contains 3 sub-sections: Tempo Feel, Vocal Energy, Mood Palette.
  - All toggle chips: minimum 44×44px.
  - Keys: `Key('tempo_picker')`, `Key('energy_picker')`, `Key('mood_picker')`
  - _Requirements: REQ-DNA-OB-09, REQ-DNA-NFR-02_

- [x] **T6.5** — Create `DnaInsightCard` *(new)*
  - File: `lib/features/creator_dna/presentation/widgets/dna_insight_card.dart`
  - Dismiss button: `Key('dna_insight_card_dismiss_button')`, 44×44px.
  - Contextual tip string driven by `lifecycleState`.
  - _Requirements: REQ-DNA-HOME-01, REQ-DNA-HOME-02, REQ-DNA-HOME-03_

- [x] **T6.6** — Wire `DnaInsightCard` into `HomeDashboardView` *(modify)*
  - File: `lib/features/home/presentation/views/home_dashboard_view.dart`
  - Conditionally render `DnaInsightCard` as first content card when `!dna.dnaInsightCardDismissed && dna.strengthPercent > 0`.
  - Watch `creatorDnaProvider`.
  - _Requirements: REQ-DNA-HOME-01, REQ-DNA-HOME-02_

- [x] **T6.7** — Wire `BehaviorEvent.trackPlay` in player *(modify)*
  - File: `lib/features/player/presentation/providers/player_provider.dart`
  - On track completion (>80% listened), call: `ref.read(creatorDnaProvider.notifier).recordEvent(BehaviorEvent.trackPlay(...))`
  - On early close (<30%), same call with lower `listenRatioPercent`.
  - _Requirements: REQ-DNA-CAP-01, REQ-DNA-CAP-03_

- [x] **T6.8** — Wire `BehaviorEvent.generationSubmit` in Studio *(modify)*
  - File: `lib/features/studio/presentation/providers/generation_pipeline_providers.dart`
  - After successful generation submission, call: `ref.read(creatorDnaProvider.notifier).recordEvent(BehaviorEvent.generationSubmit(...))`
  - _Requirements: REQ-DNA-CAP-03_

- [x] **T6.9** — Wire `BehaviorEvent.genreFilterTap` in Explore *(modify)*
  - File: `lib/features/explore/presentation/widgets/catalog_filter_bar.dart`
  - On filter chip tap, call: `ref.read(creatorDnaProvider.notifier).recordEvent(BehaviorEvent.genreFilterTap(genre))`
  - _Requirements: REQ-DNA-CAP-03_

- [x] **T6.10** — Apply `dnaStudioDefaultsProvider` pre-fill in Studio *(modify)*
  - File: `lib/features/studio/presentation/views/studio_view.dart`
  - On first mount (when no prior session state), read `dnaStudioDefaultsProvider` and apply fields to initial `StudioFormState`.
  - Show `DnaSuggestionChip` banner (`Key('dna_studio_suggestion_chip')`) when `hasDnaDefaults == true`.
  - _Requirements: REQ-DNA-STU-01, REQ-DNA-STU-02, REQ-DNA-STU-03_

---

## Track G: Test Suites

- [x] **T7.1** — Update `onboarding_notifier_test.dart` *(modify)*
  - File: `test/features/onboarding/onboarding_notifier_test.dart`
  - Add tests for new methods: `setCreativeRole()`, `setExperienceLevel()`, `setPrimaryLanguage()`, `toggleMood()`.
  - Ensure all original test assertions still pass.
  - _Requirements: REQ-DNA-OB-12, REQ-DNA-NFR-05_

- [x] **T7.2** — Update `onboarding_view_test.dart` *(modify)*
  - File: `test/features/onboarding/onboarding_view_test.dart`
  - Update page count assertion from 3 to 6.
  - Add: tap `Key('onboarding_role_card_producer')` → verify state sets producer role.
  - Add: tap `Key('onboarding_dna_activate_cta')` → verify `creatorDnaProvider` state is `seeded`.
  - _Requirements: REQ-DNA-OB-01, REQ-DNA-OB-05_

- [x] **T7.3** — Write DNA widget tests *(new)*
  - File: `test/features/creator_dna/presentation/widgets/dna_strength_meter_test.dart`
  - Test: renders with `animated: false` without timer leaks.
  - Test: `strengthPercent: 0` → `AppColors.accentElectric` fill zone.
  - Test: `strengthPercent: 85` → `AppColors.accentSuccess` fill zone.
  - File: `test/features/creator_dna/presentation/widgets/dna_insight_card_test.dart`
  - Test: renders with lifecycle `seeded` → shows 'Keep exploring' tip text.
  - Test: tap `Key('dna_insight_card_dismiss_button')` → `dismissInsightCard()` called.
  - _Requirements: REQ-DNA-HOME-01, REQ-DNA-HOME-03_

---

## Track H: Final Verification Gates

- [x] **Gate 1: Static analysis** — `flutter analyze`: **0 issues found**
- [x] **Gate 2: Domain unit tests** — `flutter test test/features/creator_dna/domain/`: **6/6 passed**
- [x] **Gate 3: Repository tests** — `flutter test test/features/creator_dna/data/`: **5/5 passed**
- [x] **Gate 4: Provider tests** — `flutter test test/features/creator_dna/presentation/providers/`: **5/5 passed**
- [x] **Gate 5: Widget tests** — `flutter test test/features/onboarding/` & `test/features/creator_dna/presentation/widgets/`: **27/27 passed**
- [x] **Gate 6: Zero-regression full suite** — `flutter test`: **911/911 passed** (0 failures, 0 regressions)

---

## Known Traps & Mitigations

| Trap | Risk | Mitigation |
|---|---|---|
| Hive box not initialized in widget tests | All widget tests that use `CreatorDnaRepository` will crash. | Repository uses in-memory fallback (`Box? _box`). Tests never call `Hive.initFlutter()`. |
| `AnimationController` leaks in DNA Activation screen | Headless widget tests will fail with timer leak warnings. | All `AnimationController` instances are disposed in `dispose()`. Onboarding widget tests use `tester.pumpAndSettle()` with timeout or pass `animated: false`. |
| `creatorDnaProvider` rebuilding entire tree | Watching DNA provider in top-level widgets triggers excessive rebuilds. | Only `DnaInsightCard`, `DnaStrengthMeter`, and `DnaGenreBadge` watch the provider. Studio and Explore read it at point of use only. |
| Breaking `StudioFormState` API | DNA pre-fill accidentally modifies `StudioFormState` fields permanently. | DNA defaults are applied only as initial values on first mount. All form edits continue to use `StudioNotifier` methods exclusively. |
| Extending `OnboardingState` breaks existing tests | New fields added to `OnboardingState` may cause `==` / `hashCode` failures in existing tests. | All new fields have backward-compatible defaults. Existing test assertions remain valid. |
| Weight map mutation (shared reference) | `copyWith` passing the same `Map<String, double>` reference causes silent state mutation bugs. | All weight maps are copied with `Map.from()` before modification in `_applyEventToWeights`. |

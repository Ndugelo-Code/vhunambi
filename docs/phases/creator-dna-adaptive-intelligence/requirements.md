# Requirements: Creator DNA & Adaptive Intelligence

> **System:** M9 / `creator-dna-adaptive-intelligence`  
> **Status:** 🟡 SPECIFICATION  
> **Baseline Tests:** 813 passing, 0 regressions allowed  
> **Standard:** WCAG 2.1 AA / Apple HIG / Vhunambi Codebase Architecture

---

## Glossary

| Term | Definition |
|---|---|
| **Creator DNA Profile** (`CreatorDnaProfile`) | The persistent, on-device model of a user's musical identity. Seeded at onboarding, continuously enriched by passive behaviour events. Persisted in `AppConstants.creatorDnaBoxKey` via hand-rolled JSON. |
| **DNA Strength** | A 0–100% scalar derived from the number and quality of behavior events accumulated since onboarding. The higher the value, the more confident Vhunambi's personalization layer is. |
| **Behavior Event** (`BehaviorEvent`) | An immutable, timestamped record of a user interaction (play, like, skip, generation submit, filter tap) that carries a genre, language, or mood signal used to update DNA weights. |
| **DNA Signal Weight** (`DnaSignalWeight`) | A floating-point weight (0.0–∞, clamped to display at 0–100%) per genre/language/mood dimension that represents accumulated affinity evidence. |
| **DNA-Seeded Defaults** | Pre-filled values suggested (not forced) by the DNA engine in `StudioFormState` whenever a user opens the music creation studio. The user can override any field. |
| **Onboarding Seed** | The initial batch of DNA signal weights captured from explicit user choices during the 5-step onboarding flow. Provides non-zero starting weights before any passive behaviour is recorded. |
| **DNA Lifecycle State** | One of: `uninitialized`, `seeded`, `learning`, `calibrated`, `attuned` — reflecting the DNA maturity level. |
| **Creative Role** | A creator's self-declared primary activity: `producer`, `vocalist`, `songwriter`, `multiHyphenate`, `musicLover`. Influences studio UI emphasis. |
| **Experience Level** | `newbie`, `growing`, `pro` — affects onboarding complexity hints and home dashboard coaching tips. |
| **`creatorDnaProvider`** | Riverpod `StateNotifierProvider` emitting `CreatorDnaProfile`. Provides DNA state to all consuming widgets. |
| **`dnaStudioDefaultsProvider`** | Riverpod `Provider<StudioDnaDefaults>` derived from `creatorDnaProvider`. Provides pre-fill values for studio form without coupling to `StudioFormState`. |

---

## Part 1: Onboarding Enhancement Requirements

### REQ-DNA-OB-01 — 5-Step Flow Architecture
The system SHALL replace the existing 3-step onboarding flow with a 5-step progressive DNA seeding flow:
- **Step 0**: Welcome & Companion Promise
- **Step 1**: Creative Identity & Role
- **Step 2**: Genre DNA Selection
- **Step 3**: Language & Cultural Roots
- **Step 4**: Sound Signature Seed
- **Step 5**: DNA Activation & Credit Gift

### REQ-DNA-OB-02 — Progressive Navigation
The system SHALL support forward (`Continue`), backward (`←`), and skip (`Skip`) navigation at every step. Tapping `Skip` at any step SHALL write a `skippedStep` flag to the onboarding state and proceed directly to the DNA Activation screen, ensuring the user always exits with a partially seeded DNA profile rather than nothing.

### REQ-DNA-OB-03 — Step Dots & Progress Indicator
WHILE navigating onboarding steps, the system SHALL display animated step-dot indicators (6 dots corresponding to steps 0–5) with the active step showing an expanded pill (24px wide) and inactive steps showing 8px circles. Colors SHALL use `AppColors.brandPrimary` (active) and `AppColors.surfaceSecondary` (inactive).

### REQ-DNA-OB-04 — Haptic Feedback
The system SHALL trigger `HapticFeedback.lightImpact()` on step navigation and `HapticFeedback.mediumImpact()` on DNA activation completion, consistent with existing onboarding feedback.

### REQ-DNA-OB-05 — Creative Role Cards (Step 1)
The system SHALL display 5 role selection cards: `Producer 🎹`, `Vocalist 🎤`, `Songwriter ✍️`, `Multi-hyphenate 🎧`, `Music Lover / Fan 👂`. Each card SHALL satisfy a minimum 44×44px touch target and use a selected state highlighting `AppColors.brandPrimary` border with `AppColors.surfaceElevated` fill.

### REQ-DNA-OB-06 — Experience Level Picker (Step 1)
WHEN selecting creative role, the system SHALL present a 3-option experience level toggle: `Newbie`, `Growing`, `Pro`. Only one option may be selected at a time. All toggle buttons SHALL satisfy 44×44px minimum touch bounds.

### REQ-DNA-OB-07 — Genre DNA Multi-Select (Step 2)
The system SHALL offer at minimum 18 genre options across 3 regional groups:
1. **South African**: Amapiano, Gqom, Kwaito, Maskandi, Afro House, Bubblegum Soul
2. **Pan-African**: Afrobeats, Highlife, Bongo Flava, Afropop, Coupé-Décalé, Azonto
3. **Global Influences**: Gospel, R&B / Soul, Hip Hop, Electronic, Jazz, Alternative

WHEN a genre chip is tapped, its DNA seed weight SHALL be set to 1.0. At least 1 genre SHALL remain selected at all times. All filter chips SHALL satisfy 44×44px minimum touch bounds with `AppColors.brandPrimary` selected state.

### REQ-DNA-OB-08 — Language & Primary Designation (Step 3)
The system SHALL offer at minimum 14 language options across 3 regional groups. The user SHALL designate exactly one language as their **primary** language (used as the AI vocal generation default). All other selected languages are treated as secondary influences. The primary designation SHALL be visually distinguished with a `⭐` or `PRIMARY` badge chip.

### REQ-DNA-OB-09 — Sound Signature Seed (Step 4)
The system SHALL present 3 audio personality dimensions on Step 4:
1. **Tempo Feel**: `Slow (60–80 BPM)`, `Medium (80–120 BPM)`, `Fast (120–145 BPM)`, `Hyperspeed (145+ BPM)` — maps to `TempoBracket` enum in `studio_form_state.dart`.
2. **Vocal Energy**: `Intimate / Soft`, `Balanced`, `High Intensity` — maps to `VocalEnergy` enum.
3. **Mood Palette**: `🌅 Uplifting`, `🌙 Reflective`, `🔥 Energetic`, `💫 Spiritual`, `🎭 Raw / Gritty`, `🌊 Chill` — up to 3 moods selectable simultaneously.

### REQ-DNA-OB-10 — DNA Activation Screen (Step 5)
The DNA Activation screen SHALL display:
- An animated 100×100px DNA emblem with `AppColors.accentSuccess`-tinted pulse rings.
- A `DnaStrengthMeter` widget showing the initial DNA strength percentage (computed from onboarding completeness, typically 15–25%).
- A DNA Snapshot summary card showing: top 2 genres, primary language, creative role, tempo preference.
- The existing `'10 Free Song Credits Loaded'` gift badge from the legacy ready screen.
- A primary `'Start Creating ✨'` CTA button (44×44px minimum, `AppColors.brandPrimary`).

### REQ-DNA-OB-11 — Persistence on Completion
WHEN the user completes or skips onboarding, the system SHALL persist the `CreatorDnaProfile` entity to Hive using `AppConstants.creatorDnaBoxKey` via hand-rolled `toJson()`. IF the Hive box cannot be opened, the entity SHALL remain in memory and all subsequent reads SHALL degrade gracefully to `CreatorDnaProfile.initial()` defaults.

### REQ-DNA-OB-12 — Backward Compatibility
The system SHALL preserve the existing `OnboardingState` and `OnboardingNotifier` public API. New fields SHALL be additive. The existing `toggleGenre()`, `toggleLanguage()`, `setUserRole()`, and `completeOnboarding()` methods SHALL continue to function. Tests in `onboarding_notifier_test.dart` and `onboarding_view_test.dart` SHALL pass with zero regressions.

---

## Part 2: DNA Capture Engine Requirements

### REQ-DNA-CAP-01 — Behavior Event Recording
The system SHALL provide a `recordEvent(BehaviorEvent event)` method on `CreatorDnaNotifier`. WHEN a behavior event is recorded, the system SHALL immediately recompute affected DNA signal weights and persist the updated `CreatorDnaProfile` to Hive.

### REQ-DNA-CAP-02 — Event Log Limit
The system SHALL maintain a sliding event log of the last 500 behavior events. WHEN the log exceeds 500 events, the oldest events SHALL be evicted using a FIFO strategy. This prevents unbounded Hive storage growth.

### REQ-DNA-CAP-03 — Supported Event Types
The system SHALL support the following `BehaviorEventType` values:
- `trackPlay` — payload: `trackId`, `genreHint`, `languageHint`, `listenRatioPercent`
- `trackLike` — payload: `trackId`, `genreHint`, `languageHint`, `moodHint`
- `trackSkip` — payload: `trackId`, `genreHint`, `secondsBeforeSkip`
- `generationSubmit` — payload: `genre`, `language`, `tempo`, `vocalEnergy`, `mood`
- `genreFilterTap` — payload: `genre`
- `exploreScrollDepth` — payload: `genre`, `depthPercent`
- `trackShare` — payload: `trackId`, `genreHint`, `moodHint`

### REQ-DNA-CAP-04 — Weight Computation Rules
WHEN updating DNA weights from a behavior event, the system SHALL apply the signal weight deltas defined in the blueprint (Section 6). Genre, language, and mood weights SHALL be clamped between 0.0 and a maximum of 20.0 before normalizing to display percentages. A weight of 0.0 SHALL mean no affinity evidence; negative weights from skip events SHALL floor at 0.0.

### REQ-DNA-CAP-05 — DNA Strength Computation
`CreatorDnaProfile.strengthPercent` SHALL be computed as:
```
totalEvents = min(behaviorLog.length, 500)
diversity = uniqueGenresWeighted / totalPossibleGenres
rawStrength = (totalEvents / 200.0) * 0.60 + diversity * 0.25 + onboardingCompleteness * 0.15
strengthPercent = (rawStrength * 100).clamp(0, 100).round()
```
The strength SHALL be displayed to the user as a whole number percentage.

### REQ-DNA-CAP-06 — Privacy Guarantee
The system SHALL NOT transmit raw behavior event logs, raw DNA weights, or `CreatorDnaProfile` data to any backend server. WHEN the user account syncs to the API, only aggregate inferences (e.g., top genre) MAY be included in profile metadata — and this is reserved for future M10 implementation. M9 is 100% on-device.

### REQ-DNA-CAP-07 — DNA Reset
The system SHALL provide a `resetDna()` method accessible from the Profile → Settings section that clears the Hive box entry, resets all weights to 0.0, and resets the lifecycle state to `uninitialized`. A confirmation dialog SHALL be displayed before resetting with `AppColors.error`-tinted destructive action button.

---

## Part 3: DNA-Powered Surface Requirements

### REQ-DNA-STU-01 — Studio Auto-Fill Provider
The system SHALL expose `dnaStudioDefaultsProvider` as a `Provider<StudioDnaDefaults>` that derives pre-fill values from `creatorDnaProvider`. This provider SHALL be read (not watched) by the Studio view to populate initial `StudioFormState` values when the Studio screen is first mounted.

### REQ-DNA-STU-02 — Non-Blocking Defaults
DNA-seeded studio defaults SHALL be applied only if no prior studio session state exists. The user SHALL be able to freely override any pre-filled field without any DNA re-computation being triggered by form edits.

### REQ-DNA-STU-03 — Studio DNA Suggestion Chip
WHEN the Studio form is opened with DNA-seeded defaults, the system SHALL display a subtle dismissable chip near the form header reading: `"Pre-filled from your DNA ✨"` using `AppColors.accentGold` token styling and `AppTypography.caption`. The chip SHALL be dismissable via a `×` icon with a 44×44px hit target.

### REQ-DNA-HOME-01 — Home Dashboard DNA Insight Card
The system SHALL display a `DnaInsightCard` widget in the Home Dashboard when `strengthPercent > 0`. It SHALL show:
- DNA strength as an animated fill bar using `AppColors.accentSuccess` fill and `AppColors.surfaceSecondary` track.
- Top 2 genre badges using `AppColors.brandPrimary` and `AppColors.accentElectric` tints respectively.
- A contextual tip string that updates based on lifecycle state (e.g., `"Play 5 more Amapiano tracks to grow your DNA"` for `learning` state).

### REQ-DNA-HOME-02 — DNA Insight Card Placement
The `DnaInsightCard` SHALL be placed as the first card in the Home Dashboard content scroll area, directly below the creator greeting section. It SHALL NOT overlap the top bar or mini player.

### REQ-DNA-HOME-03 — DNA Insight Card Dismissal
The `DnaInsightCard` SHALL be permanently dismissable by tapping a `×` button (44×44px hit target). Once dismissed, a Hive flag (`dnaCardDismissed: true`) SHALL suppress future display. The user can re-enable it from Profile settings.

### REQ-DNA-EXP-01 — Explore Feed DNA Ranking
The system SHALL implement a pure Dart `DnaExploreRanker` class with a `rank(List<Track> tracks, CreatorDnaProfile dna)` method that applies a DNA affinity score boost to tracks. Tracks matching DNA top-2 genres receive a `+0.30` score boost. Tracks matching `primaryLanguage` receive a `+0.15` boost. This is applied client-side after the API response is received.

### REQ-DNA-NOTIF-01 — Notification DNA Priority
WHEN displaying algorithmic notification items in `NotificationsView` (System M7), the system SHALL sort `algorithmic` category notifications so that those whose genre metadata matches the DNA top-2 genres appear first in the algorithmic category section.

---

## Part 4: Non-Functional Requirements

### REQ-DNA-NFR-01 — Design Token Compliance
All new UI components (DNA strength meter, genre badges, role cards, sound signature picker, DNA activation screen) SHALL use only `AppColors.*`, `AppTypography.*`, `AppRadius.*`, and `AppSpacing.*` tokens. Zero raw hex values. Zero raw `TextStyle(fontSize: N)` declarations.

### REQ-DNA-NFR-02 — Touch Ergonomics
Every interactive element introduced in this system SHALL satisfy a minimum 44×44px touch bounding box (`BoxConstraints(minHeight: 44, minWidth: 44)` or `minimumSize: const Size(44, 44)`).

### REQ-DNA-NFR-03 — Headless Test Safety
`CreatorDnaRepository` SHALL open the Hive box lazily and SHALL catch all Hive exceptions, falling back to in-memory `CreatorDnaProfile.initial()` without throwing. This ensures all widget tests and unit tests pass in CI without Hive path initialization.

### REQ-DNA-NFR-04 — Animation Controller Safety
All onboarding slide animations and DNA activation animations SHALL use explicitly disposed `AnimationController` instances. No indefinite animations SHALL remain active in headless widget test environments without test bypass.

### REQ-DNA-NFR-05 — Zero Regressions
All 813+ existing tests SHALL continue to pass. The onboarding extension SHALL be backward-compatible with all assertions in `onboarding_notifier_test.dart`, `onboarding_view_test.dart`, and `splash_view_test.dart`.

### REQ-DNA-NFR-06 — Performance Budget
DNA weight recomputation on each behavior event SHALL complete in under 1ms (pure Dart arithmetic). Hive writes SHALL be async and non-blocking to the UI thread. DNA provider rebuilds SHALL be scoped to only the widgets that consume `creatorDnaProvider`.

---

## Requirements Traceability Matrix

| Requirement ID | Target File | Test Type | Verification Command |
|---|---|---|---|
| REQ-DNA-OB-01 | `onboarding_view.dart` | Widget | `flutter test test/features/onboarding/` |
| REQ-DNA-OB-05 | `creative_role_card.dart` | Widget | `flutter test test/features/onboarding/` |
| REQ-DNA-OB-09 | `sound_signature_picker.dart` | Widget | `flutter test test/features/onboarding/` |
| REQ-DNA-OB-11 | `creator_dna_repository.dart` | Unit | `flutter test test/features/creator_dna/` |
| REQ-DNA-CAP-01 | `creator_dna_provider.dart` | Unit | `flutter test test/features/creator_dna/` |
| REQ-DNA-CAP-04 | `creator_dna_profile.dart` | Unit | `flutter test test/features/creator_dna/` |
| REQ-DNA-CAP-05 | `creator_dna_profile.dart` | Unit | `flutter test test/features/creator_dna/` |
| REQ-DNA-STU-01 | `dna_studio_defaults_provider.dart` | Unit | `flutter test test/features/creator_dna/` |
| REQ-DNA-HOME-01 | `dna_insight_card.dart` | Widget | `flutter test test/features/home/` |
| REQ-DNA-EXP-01 | `dna_explore_ranker.dart` | Unit | `flutter test test/features/creator_dna/` |
| REQ-DNA-NFR-03 | `creator_dna_repository.dart` | Unit | `flutter test test/features/creator_dna/` |

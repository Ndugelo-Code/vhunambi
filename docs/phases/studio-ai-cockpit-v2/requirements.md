# Requirements: Studio AI Cockpit v2

> **System:** M10 / `studio-ai-cockpit-v2`  
> **Status:** 🟡 SPECIFICATION  
> **Baseline Tests:** 845 passing (post-M9), 0 regressions allowed  
> **Standard:** WCAG 2.1 AA / Apple HIG / Vhunambi Codebase Architecture

---

## Glossary

| Term | Definition |
|---|---|
| **Ghost Session** | A `StudioSessionDraft` persisted to Hive that captures all non-ephemeral studio form state between app launches, enabling session recovery. |
| **Session Recovery Banner** | A non-intrusive top-of-screen banner in `StudioView` that alerts the user to a recovered unsaved session and offers Resume / Start Fresh options. |
| **Prompt Intelligence** | The `StudioPromptIntelligence` service that parses natural language song descriptions, merges them with Creator DNA signals, and returns an enriched prompt plus suggested `StudioFormState` field overrides. |
| **Option Preview Descriptor** (`OptionPreviewDescriptor`) | An immutable constant data class describing a selectable studio option (tempo, vocal mode, etc.) with a human-readable explanation, genre affinity list, and optional sample clip reference. |
| **OptionPreviewChip** | A standardized widget wrapping a selectable option with an `ⓘ` preview trigger that shows a non-blocking overlay card with the `OptionPreviewDescriptor` content. |
| **Guided Lyrics Composer** | A structured section-by-section lyric authoring flow that guides users through Intro → Verse → Chorus → Outro, offering genre-aware atmosphere suggestions, AI line improvements, grammar hints, and frisson cues at each step. |
| **Genre Atmosphere Library** | A compiled Dart constant map (`kGenreAtmosphereLibrary`) of genre → section type → atmosphere descriptor strings and melody suggestions. No network call required. |
| **Bantu Language Switcher** | A chip row within the Guided Lyrics Composer that enables one-tap full lyrics translation between the 8 supported Bantu languages via `BantuTranslationService`. |
| **Genre Atmosphere Sample Deck** | A new widget in the Compose tab below the Genre Selector that presents curated 3-second audio clips of drums, melodic elements, and ambiances organized by the selected genre. |
| **`studioSessionBoxKey`** | New `AppConstants` Hive box key: `'vhunambi_studio_session'`. Used exclusively by `StudioSessionRepository`. |

---

## Part 1: Session Persistence Requirements

### REQ-SES-01 — Auto-Save on Every Form Change
WHEN any `StudioFormNotifier` method mutates state, the system SHALL schedule a debounced Hive write (800ms debounce) via `StudioSessionNotifier.scheduleAutoSave()`. WHEN `setCustomLyrics()` is called, the debounce SHALL be bypassed and the save SHALL occur immediately (no debounce), because custom lyrics are the most irreplaceable user data.

### REQ-SES-02 — Persisted Fields
The system SHALL persist the following `StudioFormState` fields in the `StudioSessionDraft` entity:
- `prompt`, `genre`, `region`, `language`, `isInstrumental`
- `durationSeconds`, `lyricsMode`, `customLyrics`
- `mood`, `tempo`, `vocalVoices`, `vocalGender`, `vocalMode`, `vocalEnergy`, `songStructure`
- `isAutoTitle`, `customTitle`, `isPublic`
- `referenceAudioPath`, `selectedVoiceProfile` (as JSON), `dialectInflection`
- `sessionId` (UUID, generated once per session), `savedAt` (ISO8601 DateTime)

The following fields SHALL NOT be persisted (ephemeral):
- `phase`, `generationProgress`, `errorMessage` — always restored to `GenerationPhase.idle`

### REQ-SES-03 — Recovery Detection on Studio Mount
WHEN `StudioView` mounts (or resumes from `IndexedStack` visibility), the system SHALL check `StudioSessionRepository.hasSavedSession()`. IF a saved session exists AND `phase == GenerationPhase.idle`, the system SHALL display `StudioSessionRecoveryBanner` at the top of the Compose tab content.

### REQ-SES-04 — Session Recovery Banner
The `StudioSessionRecoveryBanner` SHALL display:
- Genre and a truncated prompt excerpt (max 40 chars) from the saved session
- Time elapsed since last save (e.g., "2 hours ago")
- `[Resume Session]` button (44×44px, `AppColors.brandPrimary` fill)
- `[Start Fresh]` button (44×44px, `AppColors.textSecondary` text-only)
- A `×` dismiss button (44×44px) that suppresses the banner for this app session but keeps the Hive data

Key: `Key('studio_session_recovery_banner')`  
Resume button key: `Key('studio_session_resume_btn')`  
Start fresh key: `Key('studio_session_start_fresh_btn')`

### REQ-SES-05 — Session Clear on Generate
WHEN the user triggers `StudioActionBar` → Generate and the pipeline reaches `GenerationPhase.queued`, the system SHALL call `StudioSessionRepository.clearSession()` to prevent the completed session from being offered as "unfinished" on the next app open.

### REQ-SES-06 — Hive Fallback
IF the Hive box (`studioSessionBoxKey`) fails to open, the system SHALL silently fall back to in-memory mode. All auto-saves SHALL be no-ops. The `StudioSessionRecoveryBanner` SHALL never appear in this mode. Zero errors shown to the user.

### REQ-SES-07 — New `AppConstants` Key
ADD to `app_constants.dart`:
```dart
static const String studioSessionBoxKey = 'vhunambi_studio_session';
```

---

## Part 2: Prompt Intelligence Requirements

### REQ-PRI-01 — Conversational Input Acceptance
The `PromptInputBox` SHALL accept casual, grammatically imperfect, emotionally phrased descriptions in plain language (e.g., `"i want a female zulu amapiano song with deep log drums called mehlo"`). The input field SHALL have NO character count pressure, NO format enforcement, and NO grammar validation at the input level.

### REQ-PRI-02 — DNA Pre-Fill Button
WHEN `CreatorDnaProfile.onboardingCompleted == true` AND `strengthPercent > 0`, the system SHALL display a `[🧬 DNA Pre-fill]` chip in the `PromptInputBox` header row. Tapping it SHALL populate the prompt field with a DNA-derived template using the top genre and language from the DNA profile, AND call `studioFormProvider.notifier.setGenre()`, `setLanguage()`, `setMood()` with DNA top signals.

Key: `Key('studio_dna_prefill_btn')`

### REQ-PRI-03 — Typing Pause Enhancement Trigger
WHEN the user pauses typing for ≥1500ms AND the prompt contains ≥10 characters, the system SHALL call `StudioPromptIntelligence.enhance(prompt, dna)` and display the result in a `PromptIntelligenceOverlay` panel below the text field.

### REQ-PRI-04 — Enhancement Panel Content
The `PromptIntelligenceOverlay` SHALL display:
- An enhanced version of the user's prompt in a distinct `AppColors.surfaceSecondary` container
- A row of `AutoFillChip` widgets for each detected/suggested field override (genre, language, vocal gender, tempo, mood)
- An `[Apply All]` button (44×44px, `AppColors.brandPrimary`) that applies the enhanced prompt + all non-dismissed field overrides
- Individual `×` dismiss buttons per `AutoFillChip` (44×44px)
- A dismiss `×` for the entire overlay

Key: `Key('prompt_intelligence_overlay')`  
Apply all key: `Key('prompt_intelligence_apply_all')`

### REQ-PRI-05 — Parsing Logic (Client-Side, No Network)
`StudioPromptIntelligence.enhance()` SHALL be a pure Dart synchronous function that:
- Scans the prompt for genre keywords (`amapiano`, `gqom`, `maskandi`, etc.)
- Scans for language keywords (`zulu`, `venda`, `tshivenḓa`, `xhosa`, etc.)
- Scans for gender keywords (`female`, `male`, `female singer`, `male voice`)
- Scans for mood keywords (`sad`, `happy`, `dark`, `uplifting`, `spiritual`)
- Scans for instrument keywords (`log drum`, `piano`, `guitar`, `bass`)
- Merges parsed entities with DNA profile top signals (DNA signals override blanks only)
- Returns `PromptEnhancementResult`: `enhancedPrompt`, `suggestedOverrides: Map<String, dynamic>`

### REQ-PRI-06 — Inspiration Seeds DNA-Routing
The existing 3 preset chips in `PromptInputBox` SHALL be expanded to 9 seeds. The 3 shown at any time SHALL be selected based on DNA top genre:
- IF `dna.topGenres(1).first == 'Amapiano'` → show Amapiano-specific seeds
- IF `dna.topGenres(1).first == 'Gqom'` → show Gqom-specific seeds
- IF DNA is uninitialized → show the existing 3 generic seeds
Seeds rotate through 9 total options. Key prefix: `Key('studio_preset_chip_$index')`.

---

## Part 3: Option Preview System Requirements

### REQ-OPT-01 — `OptionPreviewDescriptor` Constant Map
The system SHALL define `kStudioOptionPreviews` as a compile-time constant `Map<String, OptionPreviewDescriptor>` covering all values of:
- `TempoBracket` (4 values): `slow`, `medium`, `fast`, `veryFast`
- `VocalMode` (5 values): `auto`, `melodic`, `rap`, `spokenWord`, `choir`
- `VocalEnergy` (3 values): `soft`, `mid`, `intense`
- `SongStructure` (4 values): `standard`, `extended`, `freestyle`, `loop`
- `LyricsMode` (4 values): `aiWrite`, `myOwn`, `fromPhoto`, `instrumental`

Each entry SHALL have: `title`, `description` (2 sentences max), `bestForGenres` (List of 2-3 strings), `emoji`.

### REQ-OPT-02 — `OptionPreviewChip` Widget
The system SHALL provide a reusable `OptionPreviewChip` widget that:
- Displays the option label and an `ⓘ` icon button (44×44px hit target)
- On `ⓘ` tap: shows a non-modal `OptionPreviewCard` overlay using `OverlayEntry` anchored to the chip's position
- The `OptionPreviewCard` shows: emoji, title, description, best-for genre badges
- The card is dismissed by tapping anywhere outside it or pressing a `[Got It]` button (44×44px)

Key pattern: `Key('option_preview_chip_$optionKey')`  
Info button key: `Key('option_preview_info_$optionKey')`  
Got it key: `Key('option_preview_got_it_$optionKey')`

### REQ-OPT-03 — Non-Intrusive Default State
WHEN the user has NEVER tapped any `ⓘ` button, the studio SHALL look and behave identically to its current state. The `ⓘ` icons SHALL be subtle (`AppColors.textTertiary`, 14px) and not compete visually with the option label itself.

### REQ-OPT-04 — Integration Points
The `OptionPreviewChip` SHALL be integrated at the following locations in `AdvancedOptionsAccordion`:
- Each `TempoBracket` chip row
- Each `VocalMode` chip row
- Each `VocalEnergy` chip row
- Each `SongStructure` chip row
- Each `LyricsMode` selection card

---

## Part 4: Guided Lyrics Composer Requirements

### REQ-GLC-01 — Activation
WHEN the user selects `LyricsMode.myOwn` in the Advanced Options AND taps `[Write with Guide]` (a new companion CTA alongside the existing raw textarea), the system SHALL open the `GuidedLyricsComposer` as a full-screen modal (identical routing pattern to `LyricsReviewModal`).

### REQ-GLC-02 — Section Sequence
The `GuidedLyricsComposer` SHALL present sections in this fixed sequence:
1. `LyricsSectionType.intro`
2. `LyricsSectionType.verse` (Verse 1)
3. `LyricsSectionType.chorus`
4. `LyricsSectionType.verse` (Verse 2, optional — user can skip)
5. `LyricsSectionType.bridge` (optional — user can skip)
6. `LyricsSectionType.outro`

Navigation: Forward `[Next →]` / Backward `[← Back]` / Skip `[Skip Section]` buttons. All 44×44px.

### REQ-GLC-03 — Genre Atmosphere Library
WHEN a user is on any section, the system SHALL display atmosphere descriptors from `kGenreAtmosphereLibrary[selectedGenre][sectionType]`. WHEN the selected genre has no entry in the library, fall back to `kGenreAtmosphereLibrary['Amapiano'][sectionType]`.

### REQ-GLC-04 — Atmosphere Descriptor Chips
Each atmosphere descriptor SHALL appear as a tappable chip. WHEN tapped, the descriptor text SHALL be appended as a stage direction comment `// [descriptor]` to the section's lines (visible in the raw editor, stripped before synthesis).

### REQ-GLC-05 — Grammar & Improvement Hints
WHEN the user types in a section editor AND pauses for ≥2000ms, the system SHALL show a maximum of 1 inline hint below the text field. Hints are sourced from:
- **Grammar**: Simple pattern-based detection (e.g., duplicate words, obvious capitalization issues)
- **Vocal run suggestion**: WHEN the last word ends in a vowel and the section is a chorus, suggest "Try ending on a sustained vowel run"
- **Frisson cue**: Randomly (20% probability) suggest a pause/timing technique appropriate to the section

Hints are dismissable with a `×` button. They are suggestions only — the user can ignore them with zero consequence.

### REQ-GLC-06 — Section Progress Indicator
The `GuidedLyricsComposer` SHALL display a linear step indicator at the top showing the current section out of total sections (e.g., `2 / 6`). Each step dot is 8×8px (inactive) or a 24px pill (active) using `AppColors.brandPrimary`.

### REQ-GLC-07 — Completion Handoff
WHEN all sections are completed (or skipped), the `GuidedLyricsComposer` SHALL assemble all section lines into the standard `LyricsSection` format compatible with `LyricsReviewDraft` and pre-populate the `LyricsReviewModal` with the authored content. The existing `LyricsReviewNotifier.updateSectionLines()` method is used directly — no new API needed.

### REQ-GLC-08 — Backwards Compatibility with `LyricsMode.myOwn`
The existing raw `TextField` for custom lyrics in `AdvancedOptionsAccordion` SHALL be preserved. The `[Write with Guide]` CTA is additive. Users who prefer the raw pane can continue using it unchanged.

---

## Part 5: Bantu Language Switcher Requirements

### REQ-BLS-01 — Switcher Placement
The `BantuLanguageSwitcher` SHALL appear as a chip row at the top of the `GuidedLyricsComposer` header and within the `LyricsReviewModal` header row (beside the existing Copy button).

### REQ-BLS-02 — Supported Languages
The switcher SHALL expose 8 Bantu language targets:
`Tshivenḓa`, `isiZulu`, `isiXhosa`, `Sepedi`, `Setswana`, `Afrikaans`, `Xitsonga`, `siSwati`

### REQ-BLS-03 — Translation Confirmation Dialog
WHEN the user selects a target language different from the current lyrics language, the system SHALL display a confirmation `AlertDialog` with:
- Title: `"Translate lyrics to [TargetLang]?"`
- Body: `"Your current lyrics will be replaced with the translated version. This cannot be undone."`
- `[Translate]` confirm button (`AppColors.brandPrimary`, 44×44px)
- `[Cancel]` dismiss button

### REQ-BLS-04 — Translation Service Interface
`BantuTranslationService.translate(String text, String fromLang, String toLang)` SHALL be defined as an interface `IBantuTranslationService` with:
- `HttpBantuTranslationService` — production implementation calling the Vhunambi API translation endpoint
- `FakeBantuTranslationService` — test stub that returns `"[Translated: $text]"` for any input

### REQ-BLS-05 — Translation Loading State
WHILE translation is in progress, the `GuidedLyricsComposer` / `LyricsReviewModal` SHALL show a full-section loading overlay with a `CircularProgressIndicator` in `AppColors.brandPrimary` and the text `"Translating to [TargetLang]..."`. The section content SHALL be blurred (blur radius 4) during this state.

### REQ-BLS-06 — Translation Badge
AFTER successful translation, the section header SHALL display a `🌐 Translated` badge chip in `AppColors.accentElectric` styling, indicating the content was machine-translated (so the user knows to review it).

---

## Part 6: Genre Atmosphere Sample Deck Requirements

### REQ-SMP-01 — Placement
The `GenreAtmosphereSampleDeck` SHALL be rendered in the `Compose` tab, between `RegionalGenreSelector` and `AdvancedOptionsAccordion`. It SHALL update in real-time when the selected genre changes.

### REQ-SMP-02 — Sample Categories
The deck SHALL present samples in 3 categories for each genre:
1. **Drums & Percussion** — 3-5 sample clips
2. **Melodic Elements** — 2-4 sample clips
3. **Atmosphere** — 2-3 sample clips

### REQ-SMP-03 — Sample Clip Playback
Each sample clip button SHALL:
- Display a play icon `▶` (44×44px hit target)
- Show the sample name (e.g., "Log Drum Deep")
- On tap: play a 3-second preview clip using the existing `just_audio` player integration
- On tap while playing: stop playback
- Show a pulsing `AppColors.brandPrimary` indicator while playing

### REQ-SMP-04 — Sample Palette Addition
WHEN the user taps a `[+]` add button on a sample clip, that sample SHALL be added to a "Generation Palette" list displayed at the bottom of the deck. The palette contents SHALL be serialized and appended to the generation prompt as instrument descriptors.

### REQ-SMP-05 — Accordion Behavior
The `GenreAtmosphereSampleDeck` SHALL be collapsed by default (showing only the header + genre badge). Expanding it reveals the sample categories. This preserves the existing scroll experience for users who don't need it.

---

## Part 8: Kinetic Fluidity, Haptic Choreography & Micro-Interactions Requirements

### REQ-KIN-01 — Platform-Safe Haptic Engine (`StudioHaptics`)
The system SHALL provide a centralized `StudioHaptics` service that invokes `HapticFeedback` methods based on semantic interaction categories:
- `ignitionThump()`: Heavy impact (`HapticFeedback.heavyImpact()`) when initiating audio generation, stem bouncing, or MPC slicing.
- `deckSwitch()`: Medium crisp impact (`HapticFeedback.mediumImpact()`) on tab changes between Compose, Voice, and Crate & MPC.
- `chipSnap()` / `optionSelect()`: Light crisp impact (`HapticFeedback.lightImpact()`) on option chip selection, stanza addition, or language change.
- `sliderTick()`: Selection click (`HapticFeedback.selectionClick()`) on BPM, tempo, or slider detent adjustments.
- `successPulse()`: Double-tick or success notification on ghost session recovery.
All methods SHALL check `!kIsWeb` and catch any `PlatformException` or `MissingPluginException` silently to ensure zero crashes in headless tests, web browsers, or unsupported desktop environments.

### REQ-KIN-02 — Elastic Micro-Interactions (`TactilePressable`)
The system SHALL provide a universal `TactilePressable` widget wrapper that animates child scale to `0.96` over 80ms (`Curves.easeInOut`) upon pointer down, and springs back to `1.0` over 220ms (`Curves.easeOutBack`) upon pointer up or cancel. The widget SHALL automatically trigger the designated `StudioHaptics` call on tap.

### REQ-KIN-03 — Fluid Deck / Tab Transitions
WHEN switching tabs in `StudioView` (Compose, Voice, Crate & MPC), the tab navigation rail SHALL render a sliding active pill indicator that translates horizontally with `Curves.easeOutCubic` over 240ms. The content switch SHALL execute a smooth cross-fade with a subtle 10px directional slide.

### REQ-KIN-04 — Dynamic Breathing Aura
The `PromptInputBox` and `PromptIntelligenceOverlay` SHALL be enveloped by an animated breathing gradient aura (`AppColors.brandPrimary.withOpacity(0.25)`) that pulses in luminosity using an oscillating sine curve (1.5s period) whenever prompt enhancement is active or audio generation is in progress.

### REQ-KIN-05 — Kinetic Accordion Expansion
WHEN expanding or collapsing `AdvancedOptionsAccordion` or `GenreAtmosphereSampleDeck`, the chevron indicator SHALL smoothly rotate 180 degrees using `AnimatedRotation(turns: isExpanded ? 0.5 : 0.0, duration: Duration(milliseconds: 240), curve: Curves.easeOutCubic)`. Content expansion SHALL use `AnimatedSize` with `Curves.easeOutCubic`.

### REQ-KIN-06 — Kinetic Sliders with Floating Badges
All sliders for acoustic parameters (tempo, duration, volume) SHALL render a floating value pill badge above the slider thumb that springs into view (`scale: 0.0` → `1.0` with `Curves.easeOutBack`) during active drag and emits `HapticFeedback.selectionClick()` on every discrete step change.

### REQ-KIN-07 — Bouncing Rails & Magnetic Snapping
All horizontal scrolling lists (`GenreAtmosphereSampleDeck`, option preview chips, atmosphere suggestions) SHALL use `BouncingScrollPhysics()` with subtle magnetic centering when a card is tapped.

### REQ-KIN-08 — Reduced Motion & Accessibility Safeguard
WHEN `MediaQuery.of(context).disableAnimations == true`, all spring physics and breathing aura animations SHALL be disabled, falling back to instantaneous state transitions and static border styling.

---

## Part 9: Non-Functional Requirements

### REQ-NFR-01 — Debounce Safety
All debounced auto-saves SHALL be implemented with a `Timer` that is cancelled on `dispose()` to prevent setState-after-dispose crashes.

### REQ-NFR-02 — Provider Scope Isolation
`StudioSessionNotifier` SHALL be a separate `StateNotifierProvider` from `studioFormProvider`. It SHALL only watch `studioFormProvider` via `ref.listen()` — never via `ref.watch()` — to avoid circular dependency rebuilds.

### REQ-NFR-03 — Overlay Safety
`OptionPreviewCard` overlays built with `OverlayEntry` SHALL always call `overlay.remove()` in the animation completion callback AND `dispose()`. Widget tests SHALL verify the overlay is removed after `[Got It]` is tapped.

### REQ-NFR-04 — Zero Regression Gate
All 911+ existing tests SHALL remain green. No changes to `StudioFormState`'s `const StudioFormState()` constructor default values are allowed — new fields must have backward-compatible defaults.

### REQ-NFR-05 — Token Compliance
All new widgets SHALL use only `AppColors.*`, `AppTypography.*`, `AppRadius.*`, and `AppSpacing.*` tokens. The `GenreAtmosphereSampleDeck` and `GuidedLyricsComposer` SHALL use `AppColors.surfaceElevated` as card background and `AppColors.borderSubtle` as card border — matching the existing `RegionalGenreSelector` visual language.

---

## Traceability Matrix

| Requirement | Target File | Test File | Gate |
|---|---|---|---|
| REQ-SES-01 | `studio_session_provider.dart` | `studio_session_provider_test.dart` | Unit |
| REQ-SES-03 | `studio_view.dart` | `studio_view_test.dart` | Widget |
| REQ-SES-04 | `studio_session_recovery_banner.dart` | `studio_session_recovery_banner_test.dart` | Widget |
| REQ-PRI-02 | `prompt_input_box.dart` | `prompt_input_box_test.dart` | Widget |
| REQ-PRI-05 | `studio_prompt_intelligence.dart` | `studio_prompt_intelligence_test.dart` | Unit |
| REQ-OPT-01 | `option_preview_descriptor.dart` | `option_preview_descriptor_test.dart` | Unit |
| REQ-OPT-02 | `option_preview_chip.dart` | `option_preview_chip_test.dart` | Widget |
| REQ-GLC-01 | `guided_lyrics_composer.dart` | `guided_lyrics_composer_test.dart` | Widget |
| REQ-GLC-03 | `genre_atmosphere_library.dart` | `genre_atmosphere_library_test.dart` | Unit |
| REQ-GLC-07 | `lyrics_review_modal.dart` | existing + extend | Widget |
| REQ-BLS-04 | `bantu_translation_service.dart` | `bantu_translation_service_test.dart` | Unit |
| REQ-SMP-01 | `genre_atmosphere_sample_deck.dart` | `genre_atmosphere_sample_deck_test.dart` | Widget |
| REQ-KIN-01 | `studio_haptics.dart` | `studio_haptics_test.dart` | Unit |
| REQ-KIN-02 | `tactile_pressable.dart` | `tactile_pressable_test.dart` | Widget |


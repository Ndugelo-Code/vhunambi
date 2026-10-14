# Implementation Plan: Studio AI Cockpit v2

> **System:** M10 / `studio-ai-cockpit-v2`  
> **Pre-flight Baseline:** `dart analyze lib test` = **0 issues** | `flutter test` = **845/845 passing** (post-M9)  
> **Target:** ≥ 882 tests (≥ 37 new), 0 regressions  
> **Architecture Rules:** Zero `build_runner`, zero `@HiveType`, zero raw hex colors, 44×44px touch bounds  
> **Execution Order:** Tracks A → B → C → D → E → F → G → H (sequential, each track depends on previous)

---

## Pre-Flight Verification

```powershell
cd apps/vhunambi_client
dart analyze lib test        # Must report: No issues found!
flutter test                 # Must report: 845 tests passed
git status                   # Must report: clean working tree
```

---

## Track A: Foundation — Constants, Directory Structure & Domain Models

- [ ] **T1.1** — Add `studioSessionBoxKey` to `app_constants.dart` *(modify)*
  - File: `lib/core/constants/app_constants.dart`
  - Add: `static const String studioSessionBoxKey = 'vhunambi_studio_session';`
  - _Requirements: REQ-SES-07_

- [ ] **T1.2** — Create new domain model files *(new)*
  - `lib/features/studio/domain/models/studio_session_draft.dart` — `StudioSessionDraft` with `toJson()`/`fromJson()`
  - `lib/features/studio/domain/models/option_preview_descriptor.dart` — `OptionPreviewDescriptor` + `kStudioOptionPreviews` map (all 21 entries)
  - `lib/features/studio/domain/models/prompt_enhancement_result.dart` — `PromptEnhancementResult`
  - `lib/features/studio/domain/models/lyrics_section_scaffold.dart` — `LyricsSectionScaffold`, `AtmosphereDescriptor`, `kGuidedComposerScaffold`, `kGenreAtmosphereLibrary`
  - _Requirements: REQ-SES-02, REQ-OPT-01, REQ-PRI-05, REQ-GLC-03_

- [ ] **T1.3** — Unit tests for domain models *(new)*
  - File: `test/features/studio/domain/studio_session_draft_test.dart`
  - Test: `fromJson(toJson(draft))` round-trip fidelity
  - Test: `hasContent == false` for default empty draft
  - Test: `hasContent == true` when `prompt.isNotEmpty`
  - File: `test/features/studio/domain/option_preview_descriptor_test.dart`
  - Test: All 21 `kStudioOptionPreviews` entries have non-empty `title`, `description`, `bestForGenres`
  - Test: `kStudioOptionPreviews['tempo_slow']` returns correct descriptor
  - File: `test/features/studio/domain/lyrics_section_scaffold_test.dart`
  - Test: `kGuidedComposerScaffold.length == 6`
  - Test: `kGuidedComposerScaffold[3].isOptional == true` (Verse 2)
  - Test: `kGenreAtmosphereLibrary['Amapiano']` has entries for `intro`, `verse`, `chorus`, `outro`
  - _Requirements: REQ-OPT-01, REQ-GLC-02, REQ-GLC-03_

---

## Track B: Session Persistence Infrastructure

- [ ] **T2.1** — Create `StudioSessionRepository` *(new)*
  - File: `lib/features/studio/data/services/studio_session_repository.dart`
  - Implement: `hasSavedSession()`, `loadSession()`, `saveSession()`, `clearSession()`
  - Untyped `Box? _box` with lazy open + in-memory fallback on exception
  - _Requirements: REQ-SES-01, REQ-SES-06_

- [ ] **T2.2** — Create `StudioSessionNotifier` and `studioSessionProvider` *(new)*
  - File: `lib/features/studio/presentation/providers/studio_session_provider.dart`
  - Implement `StudioSessionState`, `SessionRecoveryState` enum
  - Implement debounced `scheduleAutoSave()` (800ms `Timer`)
  - Implement `immediateSave()` (no debounce)
  - Implement `resumeSession()`, `dismissRecovery()`, `clearSession()`
  - Wire `ref.listen(studioFormProvider, ...)` to trigger auto-save — **use `ref.listen`, NOT `ref.watch`**
  - Ensure `_debounceTimer?.cancel()` in `dispose()`
  - _Requirements: REQ-SES-01, REQ-NFR-01, REQ-NFR-02_

- [ ] **T2.3** — Wire session clear on generation *(modify)*
  - File: `lib/features/studio/presentation/providers/generation_pipeline_providers.dart`
  - After `submitAndStartGeneration()` reaches `GenerationPhase.queued`, call: `ref.read(studioSessionProvider.notifier).clearSession()`
  - _Requirements: REQ-SES-05_

- [ ] **T2.4** — Write session provider tests *(new)*
  - File: `test/features/studio/data/studio_session_repository_test.dart`
  - Test: `hasSavedSession() == false` when box is empty
  - Test: `saveSession()` → `loadSession()` preserves all fields
  - Test: `clearSession()` → `hasSavedSession() == false`
  - Test: All methods no-op gracefully when Hive fails (in-memory mode)
  - File: `test/features/studio/presentation/providers/studio_session_provider_test.dart`
  - Test: `recoveryState == SessionRecoveryState.none` on fresh init
  - Test: `resumeSession(draft)` applies prompt + genre to `studioFormProvider`
  - Test: `dismissRecovery()` sets state to `dismissed`
  - Test: `dispose()` cancels `_debounceTimer` without crashing
  - _Requirements: REQ-SES-06, REQ-NFR-01_

---

## Track C: Prompt Intelligence

- [ ] **T3.1** — Create `StudioPromptIntelligence` service *(new)*
  - File: `lib/features/studio/domain/services/studio_prompt_intelligence.dart`
  - Implement all keyword maps: `_genreKeywords`, `_languageKeywords`, `_femaleKeywords`, `_maleKeywords`, `_moodUplifting`, `_moodDark`, `_moodSpiritual`
  - Implement `static PromptEnhancementResult enhance(String rawPrompt)`
  - Implement `_buildEnhancedPrompt()` helper
  - Pure Dart, synchronous, zero network, zero async
  - _Requirements: REQ-PRI-05_

- [ ] **T3.2** — Write prompt intelligence unit tests *(new)*
  - File: `test/features/studio/domain/studio_prompt_intelligence_test.dart`
  - Test: `"i want a female zulu amapiano song"` → `genre: 'Amapiano'`, `language: 'isiZulu'`, `vocalGender: 'female'`
  - Test: `"dark gqom banger"` → `genre: 'Gqom'`, `mood: 'Melancholic'`
  - Test: `"gospel choir song"` → `vocalMode suggestion: 'choir'`, `mood: 'Peaceful'`
  - Test: Empty prompt → `PromptEnhancementResult(enhancedPrompt: '', suggestedOverrides: {})`
  - Test: `hasOverrides == false` when no keywords detected
  - _Requirements: REQ-PRI-05_

- [ ] **T3.3** — Create `PromptIntelligenceOverlay` widget *(new)*
  - File: `lib/features/studio/presentation/widgets/prompt_intelligence_overlay.dart`
  - `AnimatedSize` container with `duration: 300ms`
  - `AutoFillChip` sub-widget: Key pattern `Key('autofill_chip_$fieldName')`
  - Apply All: Key `Key('prompt_intelligence_apply_all')`, 44×44px
  - Dismiss: Key `Key('prompt_intelligence_dismiss')`
  - _Requirements: REQ-PRI-04_

- [ ] **T3.4** — Modify `PromptInputBox` *(modify)*
  - File: `lib/features/studio/presentation/widgets/prompt_input_box.dart`
  - Add DNA pre-fill button: Key `Key('studio_dna_prefill_btn')` in header row — shown when `dna.onboardingCompleted && dna.strengthPercent > 0`
  - Add 1500ms typing debounce that calls `StudioPromptIntelligence.enhance()`
  - Integrate `PromptIntelligenceOverlay` below text field
  - Expand preset chips from 3 to 9, DNA-routed (show 3 from matched genre pool)
  - Seed keys: `Key('studio_preset_chip_0')` through `Key('studio_preset_chip_8')`
  - _Requirements: REQ-PRI-01, REQ-PRI-02, REQ-PRI-03, REQ-PRI-06_

- [ ] **T3.5** — Write prompt input box widget tests *(new)*
  - File: `test/features/studio/presentation/widgets/prompt_input_box_test.dart`
  - Test: `Key('studio_dna_prefill_btn')` appears when DNA is seeded
  - Test: `Key('studio_dna_prefill_btn')` does NOT appear when `!dna.onboardingCompleted`
  - Test: 3 preset chips rendered initially
  - Test: `Key('prompt_intelligence_overlay')` NOT visible on fresh mount
  - _Requirements: REQ-PRI-02, REQ-PRI-06_

---

## Track D: Option Preview System

- [ ] **T4.1** — Create `OptionPreviewChip` widget *(new)*
  - File: `lib/features/studio/presentation/widgets/option_preview_chip.dart`
  - Key: `Key('option_preview_chip_$optionKey')`
  - ⓘ button: `Key('option_preview_info_$optionKey')`, `BoxConstraints(minWidth: 44, minHeight: 44)`
  - OverlayEntry-based `OptionPreviewCard` overlay with `AnimatedOpacity` (200ms)
  - Card key: `Key('option_preview_card_$optionKey')`
  - Got It key: `Key('option_preview_got_it_$optionKey')`, 44×44px
  - `OverlayEntry.remove()` called in animation complete callback AND dispose
  - _Requirements: REQ-OPT-02, REQ-OPT-03, REQ-NFR-03_

- [ ] **T4.2** — Integrate `OptionPreviewChip` in `AdvancedOptionsAccordion` *(modify)*
  - File: `lib/features/studio/presentation/widgets/advanced_options_accordion.dart`
  - Replace `TempoBracket` chip row items → `OptionPreviewChip` with key `'tempo_$bracketName'`
  - Replace `VocalMode` chip row items → `OptionPreviewChip` with key `'vocalMode_$modeName'`
  - Replace `VocalEnergy` chips → `OptionPreviewChip` with key `'vocalEnergy_$energyName'`
  - Replace `SongStructure` chips → `OptionPreviewChip` with key `'structure_$structureName'`
  - Replace `LyricsMode` cards → `OptionPreviewChip` with key `'lyricsMode_$modeName'`
  - ALL existing functionality (selection state, `onTap` notifier calls) preserved exactly
  - _Requirements: REQ-OPT-04_

- [ ] **T4.3** — Write option preview widget tests *(new)*
  - File: `test/features/studio/presentation/widgets/option_preview_chip_test.dart`
  - Test: `Key('option_preview_chip_tempo_slow')` renders with 'Slow' label
  - Test: `Key('option_preview_info_tempo_slow')` tap shows overlay card
  - Test: `Key('option_preview_got_it_tempo_slow')` dismisses overlay
  - Test: Overlay is removed from OverlayEntry (no widget in tree after dismiss)
  - Test: Tapping main chip still calls the selection callback
  - _Requirements: REQ-OPT-02, REQ-NFR-03_

---

## Track E: Session Recovery Banner

- [ ] **T5.1** — Create `StudioSessionRecoveryBanner` *(new)*
  - File: `lib/features/studio/presentation/widgets/studio_session_recovery_banner.dart`
  - Key: `Key('studio_session_recovery_banner')`
  - Background: `AppColors.accentGold.withAlpha(15)`, border `AppColors.accentGold`
  - Resume: `Key('studio_session_resume_btn')`, 44×44px, `AppColors.brandPrimary`
  - Start Fresh: `Key('studio_session_start_fresh_btn')`, 44×44px, text-only
  - Dismiss ×: `Key('studio_session_dismiss_banner')`, 44×44px
  - Show prompt excerpt: first 40 chars of `savedDraft.prompt` + genre
  - Show time elapsed: human-readable since `savedDraft.savedAt`
  - _Requirements: REQ-SES-04_

- [ ] **T5.2** — Integrate `StudioSessionRecoveryBanner` into `studio_view.dart` *(modify)*
  - File: `lib/features/studio/presentation/views/studio_view.dart`
  - In Compose tab `_tabScroll()` children list: prepend `StudioSessionRecoveryBanner()` conditionally when `recoveryState == SessionRecoveryState.available`
  - Watch `studioSessionProvider.select((s) => s.recoveryState)` — narrow rebuild scope
  - _Requirements: REQ-SES-03_

- [ ] **T5.3** — Write recovery banner widget tests *(new)*
  - File: `test/features/studio/presentation/widgets/studio_session_recovery_banner_test.dart`
  - Test: `Key('studio_session_recovery_banner')` visible when `recoveryState == available`
  - Test: Banner NOT visible when `recoveryState == none`
  - Test: Tapping `Key('studio_session_resume_btn')` calls `resumeSession()`
  - Test: Tapping `Key('studio_session_start_fresh_btn')` calls `clearSession()`
  - Test: Tapping `Key('studio_session_dismiss_banner')` calls `dismissRecovery()`
  - _Requirements: REQ-SES-04_

---

## Track F: Guided Lyrics Composer + Language Switcher

- [ ] **T6.1** — Create `IBantuTranslationService` + `FakeBantuTranslationService` *(new)*
  - File: `lib/features/studio/domain/services/i_bantu_translation_service.dart`
  - File: `lib/features/studio/data/services/fake_bantu_translation_service.dart`
  - `FakeBantuTranslationService.translate()`: 300ms artificial delay, returns `'[Translated to $toLanguage]: $text'`
  - _Requirements: REQ-BLS-04_

- [ ] **T6.2** — Create `BantuLanguageSwitcher` widget *(new)*
  - File: `lib/features/studio/presentation/widgets/bantu_language_switcher.dart`
  - Key: `Key('bantu_language_switcher')`
  - 8 language chips: `Key('bantu_lang_chip_$language')` for each
  - Confirmation dialog on language change
  - Translate confirm: `Key('bantu_translate_confirm_btn')`, 44×44px
  - Loading overlay with blur on translation in progress
  - 🌐 badge after successful translation
  - _Requirements: REQ-BLS-01, REQ-BLS-02, REQ-BLS-03, REQ-BLS-05, REQ-BLS-06_

- [ ] **T6.3** — Create `GuidedLyricsComposer` *(new)*
  - File: `lib/features/studio/presentation/widgets/guided_lyrics_composer.dart`
  - Key: `Key('guided_lyrics_composer')`
  - Section step indicator: `Key('guided_composer_step_indicator')`
  - Per-section TextArea: `Key('guided_composer_section_$sectionTypeIndex')`
  - Atmosphere chips: `Key('atmosphere_chip_$index')`
  - AI hint panel (1500ms debounce, 1 hint max)
  - Navigation: `Key('guided_composer_next_btn')`, `Key('guided_composer_back_btn')`, `Key('guided_composer_skip_btn')`
  - Done: `Key('guided_composer_done_btn')`
  - Integrates `BantuLanguageSwitcher`
  - On done: assembles `List<LyricsSection>` → pre-populates via `lyricsReviewProvider.notifier.updateSectionLines()`
  - _Requirements: REQ-GLC-01 through REQ-GLC-07_

- [ ] **T6.4** — Add `[Write with Guide]` CTA to `AdvancedOptionsAccordion` *(modify)*
  - File: `lib/features/studio/presentation/widgets/advanced_options_accordion.dart`
  - In the `LyricsMode.myOwn` section, add `[Write with Guide ✍️]` button alongside existing raw textarea
  - On tap: `GuidedLyricsComposer.show(context)`
  - Button key: `Key('studio_write_with_guide_btn')`, 44×44px
  - _Requirements: REQ-GLC-01, REQ-GLC-08_

- [ ] **T6.5** — Add `BantuLanguageSwitcher` to `LyricsReviewModal` header *(modify)*
  - File: `lib/features/studio/presentation/widgets/lyrics_review_modal.dart`
  - In `_LyricsReviewHeader`, add `BantuLanguageSwitcher` beside the Copy button
  - Pass current `draft.genre` language context to the switcher
  - _Requirements: REQ-BLS-01_

- [ ] **T6.6** — Write Guided Lyrics Composer tests *(new)*
  - File: `test/features/studio/presentation/widgets/guided_lyrics_composer_test.dart`
  - Test: `Key('guided_lyrics_composer')` mounts with Step 1 (Intro) active
  - Test: Step indicator shows `1 / 6`
  - Test: `Key('guided_composer_next_btn')` advances to Step 2 (Verse 1)
  - Test: `Key('guided_composer_skip_btn')` skips optional section (Verse 2)
  - Test: `Key('guided_composer_done_btn')` visible on last section
  - Test: Atmosphere chips rendered from `kGenreAtmosphereLibrary['Amapiano']['intro']`
  - File: `test/features/studio/presentation/widgets/bantu_language_switcher_test.dart`
  - Test: 8 language chips rendered
  - Test: Tapping different language shows confirmation dialog
  - Test: `Key('bantu_translate_confirm_btn')` triggers translation
  - Test: 🌐 badge visible after translation
  - _Requirements: REQ-GLC-02, REQ-GLC-04, REQ-BLS-02, REQ-BLS-03_

---

## Track G: Genre Atmosphere Sample Deck

- [ ] **T7.1** — Create `GenreAtmosphereSampleDeck` *(new)*
  - File: `lib/features/studio/presentation/widgets/genre_atmosphere_sample_deck.dart`
  - Key: `Key('genre_atmosphere_sample_deck')`
  - Accordion pattern: collapsed by default (header only), expand on tap
  - 3 categories: Drums & Percussion, Melodic Elements, Atmosphere
  - Sample play button: `Key('sample_play_btn_$sampleId')`, 44×44px, `AppColors.brandPrimary` pulse animation while playing
  - Add to palette: `Key('sample_add_palette_$sampleId')`, 44×44px
  - Palette row: `Key('generation_palette_row')`
  - Responds to `studioFormProvider.select((s) => s.genre)` — updates genre without expanding
  - _Requirements: REQ-SMP-01 through REQ-SMP-05_

- [ ] **T7.2** — Integrate `GenreAtmosphereSampleDeck` into Compose tab *(modify)*
  - File: `lib/features/studio/presentation/views/studio_view.dart`
  - In Compose tab `_tabScroll()` children: insert `GenreAtmosphereSampleDeck()` between `RegionalGenreSelector()` and `AdvancedOptionsAccordion()`
  - _Requirements: REQ-SMP-01_

- [ ] **T7.3** — Write sample deck tests *(new)*
  - File: `test/features/studio/presentation/widgets/genre_atmosphere_sample_deck_test.dart`
  - Test: `Key('genre_atmosphere_sample_deck')` renders collapsed by default
  - Test: Tapping header expands the deck
  - Test: `Key('sample_play_btn_amapiano_log_drum_deep')` renders in Amapiano mode
  - Test: `Key('sample_add_palette_amapiano_log_drum_deep')` adds to palette
  - Test: `Key('generation_palette_row')` visible after adding 1+ samples
  - _Requirements: REQ-SMP-01, REQ-SMP-05_

---

## Track H: Final Verification

```powershell
cd apps/vhunambi_client

# Gate 1: Static analysis (must be 0 issues)
dart analyze lib test

# Gate 2: New domain model tests
flutter test test/features/studio/domain/

# Gate 3: Session infrastructure
flutter test test/features/studio/data/
flutter test test/features/studio/presentation/providers/studio_session_provider_test.dart

# Gate 4: Widget tests
flutter test test/features/studio/presentation/widgets/

# Gate 5: Existing studio suite (zero regressions)
flutter test test/features/studio/

# Gate 6: Full regression suite
flutter test
# ✅ Must report: ≥ 882 tests passed, 0 failures, 0 errors
```

---

## Known Traps & Mitigations

| Trap | Risk | Mitigation |
|---|---|---|
| `ref.watch()` in `StudioSessionNotifier` | Creates circular dependency: session watches form which triggers session | Use `ref.listen()` to observe `studioFormProvider` and schedule save. Never `ref.watch()`. |
| `Timer` in `StudioSessionNotifier` leaks | If `dispose()` is not called before GC, the `Timer` fires after the widget tree is unmounted | Always `_debounceTimer?.cancel()` in `dispose()`. Covered by tests. |
| `OverlayEntry` leak in `OptionPreviewChip` | If user navigates away while overlay is visible, entry remains in the overlay stack | Attach `WidgetsBindingObserver` or use `LifecycleEventHandler` to call `overlay.remove()` on route pop. |
| `AdvancedOptionsAccordion` test regressions | Replacing chip widgets with `OptionPreviewChip` may break `find.text('Slow')` finders | All existing text labels preserved as `label` parameter of `OptionPreviewChip`. `find.text('Slow')` continues to work. |
| `IndexedStack` viewport culling | Adding `GenreAtmosphereSampleDeck` to Compose tab may push content below test viewport | Use `skipOffstage: false` in test finders for elements in non-visible stack pages. Sample deck accordion is collapsed by default, minimizing height impact. |
| `GuidedLyricsComposer` timer leaks | 1500ms hint debounce timer not cancelled on modal close | `Timer` is stored in `State.dispose()` — always cancel on widget dispose. Test: pump widget → dispose → verify no pending timers. |
| Session recovery banner scroll offset | Banner shifts `PromptInputBox` down; existing tests that `find.byKey(Key('prompt_input_box'))` and then `tap` may fail if the tap is off-screen | Session recovery state defaults to `none` in test ProviderContainers. No banner renders in existing tests. |

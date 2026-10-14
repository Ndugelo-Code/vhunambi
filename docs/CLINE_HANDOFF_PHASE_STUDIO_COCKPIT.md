# Dual-Agent Master Handoff — Phase 4: Studio AI Cockpit v2 (System M10)

> **Document Purpose:** Single authoritative handoff guide for Cline (or Cursor/Antigravity) implementing Phase 4.
>
> **Generated At:** October 2026  
> **Lead Architect:** Antigravity (Dual-Agent Symbiosis Protocol)  
> **Repository Root:** `c:\Users\Ndugelo\VHUNAMBI\monorepo\`  
> **Client Workspace:** `apps/vhunambi_client/`  
> **Baseline Health (Post-Phase 3):** `flutter analyze` = **0 issues** | `flutter test` = **≥ 935 passing (100%)**  
> **Target Test Count:** **≥ 970 tests (≥ 35 new tests, 0 regressions)**  
> **Governing Spec Suite:** `docs/phases/studio-ai-cockpit-v2/` ([blueprint.md](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/studio-ai-cockpit-v2/blueprint.md), [requirements.md](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/studio-ai-cockpit-v2/requirements.md), [design.md](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/studio-ai-cockpit-v2/design.md), [tasks.md](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/studio-ai-cockpit-v2/tasks.md))  
> **Roadmap Context:** [SYNTHESIS_AND_SEQUENCE.md](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/SYNTHESIS_AND_SEQUENCE.md)

---

## 1. Executive Summary & Vision

Phase 4 ("The Crown Jewel") elevates the music creation workbench in `StudioView` into an intelligent, crash-proof **Studio AI Cockpit** that feeds and is fed by the rest of the Vhunambi ecosystem.

### The 5 Core Pain Points Solved:
1. **Blank Prompt Paralysis** ➔ **Conversational Prompt Intelligence**: Natural language input is automatically refined and enriched using Creator DNA signals (`StudioPromptIntelligence`).
2. **Session Loss Frustration** ➔ **Ghost Session Auto-Save & Recovery**: Form inputs, slider tweaks, and stanza drafts are silently auto-saved in Hive (`AppConstants.studioSessionBoxKey`) with an 800ms debounce. An unobtrusive banner allows 1-tap restore if the app restarts or navigates away.
3. **Blind Option Selection** ➔ **Option Preview System**: Standardized text and audio micro-previews (`OptionPreviewDescriptor`) anchored to complex acoustic settings (tempo brackets, vocal modes, audio stems).
4. **Unguided Custom Lyrics** ➔ **Guided Lyrics Composer**: Sequential section-by-section authoring scaffold (Intro, Verse 1, Chorus, Verse 2, Bridge, Outro) with genre-aware stanza suggestions.
5. **Locked Language** ➔ **Bantu Lyrics Language Switcher**: 1-tap translation between African languages (isiZulu, Tshivenḓa, Sesotho, Xhosa, Swahili, Shona) while preserving rhyming structure.

---

## 2. Foundations Already Implemented & Verified by Chief Architect

Phase 4 relies directly on the architectural assets completed in Phase 1, Phase 2, and Phase 3:
1. **Creator DNA Intelligence (Phase 2)**:
   - `creatorDnaProvider` (`CreatorDnaProfile`) and `dnaStudioDefaultsProvider` (`StudioDnaDefaults`) are live.
   - Studio pre-fills its starting genre, tempo bracket, and mood from `dnaStudioDefaultsProvider`.
2. **Closing the Telemetry Loop (Bidirectional Synergy)**:
   - When a user submits a track generation or adjusts studio parameters, Cline must dispatch a `BehaviorEvent` into `ref.read(creatorDnaProvider.notifier).recordEvent(...)`:
     - Event: `BehaviorEvent.generationSubmit(genre: state.genre, prompt: state.prompt)`
     - This automatically evolves the user's taste vector and increases DNA strength!
3. **Notification Integration (Phase 3)**:
   - When audio generation completes in `GenerationPipelineNotifier`, it dispatches a notification to `notificationsProvider`, allowing 1-tap audition.
4. **Existing Studio Subsystems to PRESERVE**:
   - 3-tab `IndexedStack` layout (`0: Compose`, `1: Voice`, `2: Crate & MPC`).
   - `StudioFormState` immutable model & `StudioFormNotifier`.
   - `GenerationPipelineNotifier` FSM with WebSocket progress streaming.
   - `BantuVoiceDeck`, `CrateBrowserDeck`, and `MpcSlicerDeck`.

---

## 3. Codebase Invariants (NEVER BREAK THESE)

1. **Zero Code Generation:** Never run `build_runner` or introduce `@HiveType` / `@HiveField`. Use hand-rolled `toJson()`/`fromJson()` map serialization.
2. **Preserve Studio Layout:** Do not remove the 3-tab `IndexedStack` in `StudioView`. Keep `Compose`, `Voice`, and `Crate & MPC` tabs functional.
3. **Headless Test Safety:** Session persistence must strictly use the safe pattern:
   ```dart
   if (!kIsWeb && Hive.isBoxOpen(AppConstants.studioSessionBoxKey)) {
     _box = Hive.box(AppConstants.studioSessionBoxKey);
   }
   ```
   If Hive is not initialized, seamlessly fall back to an in-memory draft so tests never crash.
4. **Design Tokens Only:** Zero raw hex values. Always map colors through `AppColors.*` (`surfaceCanvas`, `surfaceElevated`, `brandPrimary`, `accentGold`, `textPrimary`, etc.).
5. **Ergonomic 44×44px Touch Targets:** Every chip, button, slider thumb, and modal trigger must satisfy the 44×44px minimum hit bounds.
6. **Zero Regressions:** All baseline tests (≥ 935) must stay 100% green.

---

## 4. Key Target Files & Implementation Guide for Cline

### Track A: Domain Models
1. **`lib/core/constants/app_constants.dart`** (modify):
   - Add: `static const String studioSessionBoxKey = 'vhunambi_studio_session';`
2. **`lib/features/studio/domain/models/studio_session_draft.dart`** (new):
   - Snapshot of current studio form (prompt, genre, lyrics, parameters, timestamp).
   - Hand-rolled `toJson()` and `fromJson()`.
3. **`lib/features/studio/domain/models/option_preview_descriptor.dart`** (new):
   - `OptionPreviewDescriptor(title, description, bestForGenres, audioSamplePath)`.
   - `kStudioOptionPreviews`: Map of 21 standard studio parameter previews.
4. **`lib/features/studio/domain/models/lyrics_section_scaffold.dart`** (new):
   - `LyricsSectionScaffold(sectionType, placeholder, suggestionBank)`.
   - `kGuidedComposerScaffold`: 6-part scaffold (Intro, Verse 1, Chorus, Verse 2, Bridge, Outro).
   - `kGenreAtmosphereLibrary`: Pre-seeded suggestions for Amapiano, Afrobeats, Maskandi, etc.
5. **`lib/features/studio/domain/models/prompt_enhancement_result.dart`** (new):
   - Holds enhanced prompt, extracted genre, detected mood, and suggestion chips.

### Track B: Ghost Session Persistence
1. **`lib/features/studio/data/services/studio_session_repository.dart`** (new):
   - Methods: `hasSavedSession()`, `loadSession()`, `saveSession(draft)`, `clearSession()`.
   - Untyped Hive box with headless in-memory fallback.
2. **`lib/features/studio/presentation/providers/studio_session_provider.dart`** (new):
   - `StudioSessionNotifier` managing `StudioSessionDraft?`.
   - Listens to `studioFormProvider` changes using `ref.listen` with an 800ms debounce timer.
   - Clears session when generation is successfully submitted in `GenerationPipelineNotifier`.
3. **`lib/features/studio/presentation/widgets/studio_session_recovery_banner.dart`** (new):
   - Dismissible banner shown at the top of `StudioView` when a recovered session exists:
     - "Restore previous session from [time ago]?"
     - [Restore] button (`key: const Key('session_restore_btn')`) -> applies draft to `studioFormProvider`.
     - [Discard] button (`key: const Key('session_discard_btn')`) -> clears session.

### Track C: Conversational Prompt Intelligence
1. **`lib/features/studio/domain/services/studio_prompt_intelligence.dart`** (new):
   - Pure Dart service: `PromptEnhancementResult enhance(String rawPrompt, {CreatorDnaProfile? dna})`.
   - Enriches prompt with African instruments, BPM recommendations, and dialect nuances.
2. **`lib/features/studio/presentation/widgets/prompt_intelligence_overlay.dart`** (new):
   - Triggered from `PromptInputBox`. Displays AI-refined prompt and suggestion chips for quick insertion.

### Track D: Option Previews & Guided Lyrics
1. **`lib/features/studio/presentation/widgets/option_preview_chip.dart`** (new):
   - Tactile chip that shows description tooltip and plays audition audio on tap.
2. **`lib/features/studio/presentation/widgets/guided_lyrics_composer.dart`** (new):
   - Multi-step accordion or tabbed view for stanzas (Intro, Verse, Chorus, Outro).
   - Genre atmosphere suggestions inject stanzas with 1 tap.
3. **`lib/features/studio/presentation/widgets/bantu_language_switcher.dart`** (new):
   - Dropdown/chip selector to switch lyrics language between isiZulu, Tshivenḓa, Sesotho, Xhosa, and Swahili.
4. **`lib/features/studio/data/services/bantu_translation_service.dart`** (new):
   - Translates or converts lyric stanzas with phonetic preservation.

### Track E: Bidirectional Telemetry Hookup
**File:** `apps/vhunambi_client/lib/features/studio/presentation/providers/generation_pipeline_providers.dart`
- In `submitAndStartGeneration()`:
  ```dart
  ref.read(creatorDnaProvider.notifier).recordEvent(
    BehaviorEvent.generationSubmit(
      genre: formState.genre,
      prompt: formState.prompt,
    ),
  );
  ```

---

## 5. Verification Commands

```powershell
cd apps/vhunambi_client
flutter analyze
flutter test test/features/studio/
flutter test
```

- `flutter analyze` MUST return: **No issues found!**
- `flutter test` MUST report: **≥ 970 tests passed (0 failures, 0 regressions)**.

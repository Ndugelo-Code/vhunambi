# Phase 17 · Tasks Execution Plan — Song Metadata DNA & Lyric Video Content Engine

> **Phase:** 17  
> **Codename:** `song-dna-content-dock`  
> **Status:** ✅ COMPLETE (All Parts A, B, C, D Implemented & Verified)  
> **Repository Root:** `c:\Users\Ndugelo\VHUNAMBI\monorepo\`  
> **Target Apps:** `apps/vhunambi_client` & `apps/vhunambi_api`  
> **Standard:** Dual-Agent Pair Programming Standard ([`docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md))  

---

## 1. Pre-Flight Checklist

- [x] Blueprint codified on disk: [`docs/phases/phase_17_song_dna_content_engine/blueprint.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_17_song_dna_content_engine/blueprint.md).
- [x] Requirements codified on disk: [`docs/phases/phase_17_song_dna_content_engine/requirements.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_17_song_dna_content_engine/requirements.md).
- [x] Design codified on disk: [`docs/phases/phase_17_song_dna_content_engine/design.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_17_song_dna_content_engine/design.md).
- [x] Verify baseline tests in `apps/vhunambi_client` (`flutter test` passes 17/17 Content Studio tests).
- [x] Verify baseline build in `apps/vhunambi_api` (`pnpm build` succeeds with zero errors).

---

## 2. Sequenced Implementation Tasks

### Part A: Foundation Domain & Song DNA Models (Antigravity Architect)

- [x] **T1: Dart Domain Models for Song Metadata DNA**
  - Create `apps/vhunambi_client/lib/features/content_studio/domain/models/song_metadata_dna.dart`.
  - Create `apps/vhunambi_client/lib/features/content_studio/domain/models/lyric_word_timestamp.dart`.
  - Create `apps/vhunambi_client/lib/features/content_studio/domain/models/content_studio_preset.dart`.
  - *Verification*: Pure unit tests verify JSON serialization/deserialization (`song_metadata_dna_test.dart` passes 5/5).

- [x] **T2: Studio Form State & Wizard DNA Bridge**
  - Update `StudioFormState` in `apps/vhunambi_client/lib/features/studio/domain/models/studio_form_state.dart` to compile into `SongMetadataDna`.
  - Add 4 preset profiles to `StudioFormNotifier`: "Private School Piano", "Durban Dark Gqom", "Venda Traditional Soul", "Lagos Afro-Pop".
  - *Verification*: `flutter test test/features/studio/` passes (13/13 passed).

- [x] **T3: API Gateway DNA Compiler & Types**
  - Add `src/modules/dna/dna_types.ts` and `dna_compiler.ts` in `apps/vhunambi_api`.
  - Ensure canonical metadata is passed into RunPod synthesis jobs.
  - *Verification*: `pnpm test` (all 5 test suites pass) & `pnpm build` succeeds with zero TypeScript errors.

---

### Part B: RunPod ComfyUI 9:16 Vision Adapter (`apps/vhunambi_api`)

- [x] **T4: Headless ComfyUI 9:16 Dispatcher**
  - Implement `comfyui_adapter.ts` targeting RunPod ComfyUI API endpoint (`POST /prompt`).
  - Configure Node `5` for 9:16 vertical resolution (`width: 768`, `height: 1344`).
  - Target Node `6` for positive prompt, Node `7` for negative, Node `10` for random seed.
  - *Verification*: `pnpm test` executes `test/vision.test.ts` verifying node state machine graph and simulation fallback.

- [x] **T5: LLM Vision Prompt Synthesizer**
  - Implement `prompt_synthesizer.ts` wrapping song DNA into a single-paragraph vertical album cover prompt.
  - *Verification*: `test/vision.test.ts` verifies African genre aesthetics (Amapiano, Gqom, Maskandi) compiled into 9:16 diffusion prompt.

---

### Part C: Flutter Content Studio Dock Presentation

- [x] **T6: Riverpod Content Studio State & Notifier**
  - Implement `ContentStudioState` and `ContentStudioNotifier` in `content_studio_provider.dart`.
  - Support preset selection, duration trimming bounds, and effect toggling.
  - *Verification*: Riverpod state tests verify state transitions and bounds clamping (`content_studio_provider_test.dart` passes 8/8).

- [x] **T7: 60 FPS Kinetic Preview Canvas**
  - Implement `kinetic_preview_canvas.dart` using `CustomPainter`.
  - Draw 9:16 cover art with smooth Ken Burns matrix drift.
  - Render active karaoke word animation according to selected preset (`Kinetic Bounce`, `Luminous Glow`, `Minimal Subtitle`, `Bantu Calligraphy`).
  - *Verification*: Widget test verifies rendering across timestamp increments (`kinetic_preview_canvas_test.dart` passes 2/2).

- [x] **T8: Controls & Scrubber Panels**
  - Implement `typography_preset_picker.dart`.
  - Implement `duration_trim_scrubber.dart` (15s Hook, 30s Reel, Full Track).
  - Implement `atmospheric_effects_deck.dart` (Film grain, bass pulse, Ken Burns toggles).
  - *Verification*: Widget interactions properly mutate Riverpod state with flex-safe layouts.

- [x] **T9: Content Studio Dock Responsive View**
  - Implement `content_studio_dock_view.dart`.
  - Desktop layout: split-screen cockpit ($> 1024\text{px}$).
  - Mobile layout: single-column with sticky preview ($< 768\text{px}$).
  - *Verification*: Widget tests verify responsive rendering at 1200px and 400px widths (`content_studio_dock_view_test.dart` passes 2/2).

---

### Part D: Export Engine & Verification (Dual-Agent QA Gate)

- [x] **T10: Local & Cloud Export Service Bridge**
  - Implement `IVideoExportService`, `LocalVideoExportService` (native muxer), and `CloudVideoExportService`.
  - Provide platform share sheet trigger and bottom sheet export view (`export_action_sheet.dart`).
  - *Verification*: Export service handles progress callbacks and returns pristine 1080x1920 MP4 file path.

- [x] **T11: End-to-End Test Suite & Pre-Flight Gate**
  - Full suite of Flutter unit and widget tests for the Content Studio.
  - Verify static analysis: `flutter analyze lib/features/content_studio test/features/content_studio` (No issues found!).
  - Verify test suite: `flutter test test/features/content_studio` (17/17 passed, 100% green).
  - Verify API build: `pnpm test` (5/5 suites passed) and `pnpm build` (`tsc` succeeded).

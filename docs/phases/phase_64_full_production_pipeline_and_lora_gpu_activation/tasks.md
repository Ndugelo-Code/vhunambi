# VHUNAMBI PHASE 64: FULL PRODUCTION PIPELINE ACTIVATION, HARDWARE AUDIO BOOTSTRAP, LIVE SUPABASE PERSISTENCE & SOVEREIGN RUNPOD OPEN-SOURCE AI ENGINE — DETERMINISTIC EXECUTION TASKS

- **Document ID**: `VHUNAMBI-SPEC-P64-TASKS-V1`
- **Phase**: `Phase 64`
- **Status**: `STAGE 3 EXECUTION ROADMAP — READY FOR /vhunambi-executioner`
- **Execution Engine**: `/vhunambi-executioner` (Stage 4 Deterministic Code Execution)
- **Companion Documents**:
  - [`blueprint.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_64_full_production_pipeline_and_lora_gpu_activation/blueprint.md)
  - [`requirements.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_64_full_production_pipeline_and_lora_gpu_activation/requirements.md)
  - [`design.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_64_full_production_pipeline_and_lora_gpu_activation/design.md)

---

## 1. Master Milestone Overview

| Milestone | Title | Target Workspace(s) | Verification Gate(s) |
| :--- | :--- | :--- | :--- |
| **`M64.1`** | **Resilient Sovereign Auth, Studio Scroll Fix, Hardware Speaker Bootstrap & R2 Media Synthesizer** | `apps/vhunambi_api/`, `apps/vhunambi_client/` | `G-64-01`, `G-64-02`, `G-64-03` |
| **`M64.2`** | **19-Table Supabase PostgreSQL Cold-Start Hydration & Write-Through Bridge** | `apps/vhunambi_api/` | `G-64-04` |
| **`M64.3`** | **RunPod `model_utils.py` (`bf16`, 45 Steps, R2 LoRA Hot-Swap) & Smart Queue-Zero 4-Stem Synthesis** | `tools/zr-studio-gpu/`, `apps/vhunambi_api/`, `apps/vhunambi_client/` | `G-64-05` |
| **`M64.4`** | **Sovereign Open-Source RunPod LLM Musical Planner & Dynamic Bantu Lyric Engine** | `apps/vhunambi_api/`, `tools/zr-studio-gpu/` | `G-64-06` |
| **`M64.5`** | **Procedural Genre Cover Artwork, End-to-End Regression Suite & Cloud Verification** | `apps/vhunambi_api/`, `apps/vhunambi_client/` | `G-64-07` |

---

## 2. Granular Implementation Tasks

### Milestone `M64.1`: Resilient Sovereign Auth, Studio Scroll Fix, Hardware Speaker Bootstrap & R2 Media Synthesizer

- [x] **Task `T64.1.1` — Resilient Sovereign Auth Registration & Login on Cloudflare Workers (`REQ-P64-AUTH-01..03`)**
  - **Files**:
    - [`apps/vhunambi_api/src/db/supabase_cloud_driver.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/db/supabase_cloud_driver.ts)
    - [`apps/vhunambi_api/src/routes/auth_routes.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/routes/auth_routes.ts)
    - [`apps/vhunambi_client/lib/core/auth/sovereign_auth_repository.dart`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/core/auth/sovereign_auth_repository.dart)
  - **Actions**:
    1. Add `goTrueAdminCreateUser` (`POST /auth/v1/admin/users` with `email_confirm: true`) to `SupabaseCloudDriver`.
    2. In `auth_routes.ts`, update `POST /register` and `POST /login` so they never throw or return a tokenless `202` when Supabase GoTrue requires email confirmation or fails on `workerd`: always register/verify via `vhunambiDb` (`EdgeIsolateDatabaseEngine` / SQLite) + PostgREST `public.users` & `public.creators`, and return HTTP `201` / `200` with a complete `AuthTokenBundle`.
    3. In `sovereign_auth_repository.dart`, increase `register` and `login` HTTP timeouts from `6s` to `15s` and accept `200`/`201`/`202` responses containing a valid `accessToken`.

- [x] **Task `T64.1.2` — Fix `GenerationPipelineCard` Post-Completion Scroll Freeze in `StudioView` (`REQ-P64-UI-01`)**
  - **Files**:
    - [`apps/vhunambi_client/lib/features/studio/presentation/views/studio_view.dart`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/studio/presentation/views/studio_view.dart)
    - [`apps/vhunambi_client/lib/features/studio/presentation/widgets/generation_pipeline_card.dart`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/studio/presentation/widgets/generation_pipeline_card.dart)
  - **Actions**:
    1. In `studio_view.dart`, move `if (isPipelineVisible) GenerationPipelineCard(...)` from the fixed outer `Column` into the top of the Compose tab's `_tabScroll` widget list so the entire Compose workspace scrolls smoothly as a single `SingleChildScrollView`.
    2. In `generation_pipeline_card.dart`, add `physics: const ClampingScrollPhysics()` to `_LyricsPanel`'s `SingleChildScrollView`.

- [x] **Task `T64.1.3` — Bootstrap Hardware Speaker Audio in `main.dart` & Normalize Cloud URLs (`REQ-P64-AUD-01..02`)**
  - **Files**:
    - [`apps/vhunambi_client/lib/main.dart`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/main.dart)
    - [`apps/vhunambi_client/lib/features/player/data/services/vhunambi_audio_handler.dart`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/player/data/services/vhunambi_audio_handler.dart)
    - [`apps/vhunambi_client/lib/features/player/data/services/audio_source_resolver.dart`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/player/data/services/audio_source_resolver.dart)
  - **Actions**:
    1. Provide default `AudioPlayer()`, `AudioSessionManager()`, and normalizing `IAudioSourceResolver` parameters on `bootstrapPlatformAudioHandler()` in `vhunambi_audio_handler.dart`, and normalize remote URIs in `VhunambiAudioHandler.playTrack` and `AudioSourceResolver.resolveSource`.
    2. Call `final audioHandler = await bootstrapPlatformAudioHandler();` in `main.dart` and add `audioHandlerProvider.overrideWithValue(audioHandler)` to `ProviderScope.overrides`.

- [x] **Task `T64.1.4` — Build Read-Through R2 Media Synthesizer & Seeder (`REQ-P64-R2-01..02`)**
  - **Files**:
    - [`apps/vhunambi_api/src/modules/synthesis/r2_media_synthesizer.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/modules/synthesis/r2_media_synthesizer.ts) *(new file)*
    - [`apps/vhunambi_api/src/server.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/server.ts)
    - [`apps/vhunambi_api/src/routes/system_routes.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/routes/system_routes.ts)
  - **Actions**:
    1. Implement `synthesizeStereoWavBytes`, `synthesizeCoverArtworkBytes`, `synthesizeAndCacheMissingR2Object`, and `seedCoreCatalogMediaToR2` in `r2_media_synthesizer.ts`.
    2. Wire read-through synthesis + HTTP `Range` support into `GET /r2/:key{.*}` in `server.ts` so no audio or image request ever 404s.
    3. Add `POST /api/system/seed-r2-media` to `system_routes.ts`.

---

### Milestone `M64.2`: 19-Table Supabase PostgreSQL Cold-Start Hydration & Write-Through Bridge

- [x] **Task `T64.2.1` — Cold-Start Hydration & Non-Blocking PostgREST Write-Through (`REQ-P64-DB-01..02`)**
  - **Files**:
    - [`apps/vhunambi_api/src/db/edge_persistence_bridge.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/db/edge_persistence_bridge.ts)
    - [`apps/vhunambi_api/src/db/supabase_cloud_driver.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/db/supabase_cloud_driver.ts)
    - [`apps/vhunambi_api/src/server.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/server.ts)
  - **Actions**:
    1. Add `ensureColdStartHydrated` to `EdgeIsolateDatabaseEngine` and invoke it via non-blocking middleware in `server.ts`.
    2. Wire non-blocking `SupabaseCloudDriver` write-through upserts and RPC calls (`execute_atomic_payout`, `record_beat_license_atomic`, `send_cultural_tip_atomic`) into `EdgeIsolateDatabaseEngine` domain mutations.

---

### Milestone `M64.3`: RunPod `model_utils.py` (`bf16`, 45 Steps, R2 LoRA Hot-Swap) & Smart Queue-Zero 4-Stem Synthesis

- [x] **Task `T64.3.1` — Author `tools/zr-studio-gpu/model_utils.py` (`REQ-P64-GPU-01`)**
  - **Files**:
    - [`tools/zr-studio-gpu/model_utils.py`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/tools/zr-studio-gpu/model_utils.py) *(new file)*
    - [`tools/zr-studio-gpu/handler.py`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/tools/zr-studio-gpu/handler.py)
  - **Actions**:
    1. Implement `ZRModelManager` in `tools/zr-studio-gpu/model_utils.py` with ACE-Step 1.5 `bf16` (`infer_steps = 45`), dynamic R2 `.safetensors` LoRA caching & hot-swapping, and `synthesize_structured_song_wav` multi-stem fallback.
    2. Update `handler.py` Stage 1 to record `ZRModelManager` telemetry (`engine`, `precision`, `infer_steps`, `active_lora`, `lora_weight`) in `stage_metrics`.

- [x] **Task `T64.3.2` — Smart RunPod Queue-Zero Detection & Real 4-Stem R2 Synthesis (`REQ-P64-GPU-02`)**
  - **Files**:
    - [`apps/vhunambi_api/src/modules/synthesis/runpod_adapter.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/modules/synthesis/runpod_adapter.ts)
    - [`apps/vhunambi_api/src/modules/synthesis/mock_worker.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/modules/synthesis/mock_worker.ts)
    - [`apps/vhunambi_api/src/routes/generation_routes.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/routes/generation_routes.ts)
  - **Actions**:
    1. Upgrade `mock_worker.ts` (`simulateSynthesisPipeline`) to synthesize and upload 4 real stem WAVs (`vocals`, `drums`, `bass`, `melodic`), master audio, and cover artwork to R2 before completing the job.
    2. Upgrade `runpod_adapter.ts` to attach `loras` and `infer_steps: 45` on dispatch, check RunPod worker availability (`workersIdle + workersRunning`), and automatically fall back to `simulateSynthesisPipeline` when 0 GPU workers are active so phone generations never hang or return empty audio.

---

### Milestone `M64.4`: Sovereign Open-Source RunPod LLM Musical Planner & Dynamic Bantu Lyric Engine

- [x] **Task `T64.4.1` — Open-Source RunPod LLM Dispatcher (`Qwen2.5-7B-Instruct` / `Llama-3.1-8B-Instruct`) & Dynamic Bantu Lyric Composer (`REQ-P64-LLM-01`)**
  - **Files**:
    - [`apps/vhunambi_api/src/modules/lyrics/llm_handler.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/modules/lyrics/llm_handler.ts)
    - [`apps/vhunambi_api/src/modules/synthesis/prompt_compiler.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/modules/synthesis/prompt_compiler.ts)
    - [`apps/vhunambi_api/src/config/env.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/config/env.ts)
  - **Actions**:
    1. Add optional `RUNPOD_LLM_ENDPOINT_ID`, `RUNPOD_LLM_URL`, and `RUNPOD_LLM_MODEL` (default `'Qwen/Qwen2.5-7B-Instruct'`) to `env.ts`.
    2. Upgrade `generateLyricsFromLLM` and `refineLyricsWithLLM` in `llm_handler.ts` to call the Open-Source RunPod vLLM endpoint first, and upgrade `generateLocalMockLyrics` + `planSonicArrangementFromPrompt` so prompt-specific multi-section Bantu/English lyrics and sonic tags are generated deterministically when GPU workers are cold.
    3. Wire `planSonicArrangementFromPrompt` and automatic lyric generation into `compileSongSpec` in `prompt_compiler.ts`.

---

### Milestone `M64.5`: Procedural Genre Cover Artwork, End-to-End Regression Suite & Cloud Verification

- [x] **Task `T64.5.1` — Procedural Cover Artwork in `vision_routes.ts` (`REQ-P64-VIS-01`)**
  - **Files**:
    - [`apps/vhunambi_api/src/routes/vision_routes.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/routes/vision_routes.ts)
  - **Actions**:
    1. Replace `buildDeterministicMinimalPngBytes()` in `vision_routes.ts` with `synthesizeCoverArtworkBytes(...)` from `r2_media_synthesizer.ts` so every generated track and reel has high-contrast genre-keyed cover artwork in `zr-studio-audio` R2.

- [x] **Task `T64.5.2` — Author Phase 64 Backend & Flutter Verification Suites (`G-64-01..07`)**
  - **Files**:
    - [`apps/vhunambi_api/test/phase64_production_pipeline.test.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/test/phase64_production_pipeline.test.ts) *(new file)*
    - [`apps/vhunambi_client/test/features/studio/phase64_studio_scroll_and_audio_test.dart`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/test/features/studio/phase64_studio_scroll_and_audio_test.dart) *(new file)*
  - **Actions**:
    1. Verify resilient auth registration/login, read-through `GET /r2/:key` audio/artwork synthesis, `POST /api/system/seed-r2-media`, Open-Source LLM & prompt-reactive Bantu lyrics, Two-Stage Prompt Expansion with LoRA attachment, and 4-stem R2 synthesis in `phase64_production_pipeline.test.ts`.
    2. Verify `StudioView` unified scroll with completed `GenerationPipelineCard`, `bootstrapPlatformAudioHandler` default wiring, and URL normalization in `phase64_studio_scroll_and_audio_test.dart`.


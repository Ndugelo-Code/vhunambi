# VHUNAMBI PHASE 64: FULL PRODUCTION PIPELINE ACTIVATION, HARDWARE AUDIO BOOTSTRAP, LIVE SUPABASE PERSISTENCE & SOVEREIGN RUNPOD OPEN-SOURCE AI ENGINE — FORMAL REQUIREMENTS

- **Document ID**: `VHUNAMBI-SPEC-P64-REQUIREMENTS-V1`
- **Phase**: `Phase 64`
- **Status**: `STAGE 2 REQUIREMENTS — APPROVED FOR STAGE 4 EXECUTION`
- **Syntax Standard**: `EARS (Easy Approach to Requirements Syntax) + RFC-2119`
- **Companion Documents**:
  - [`blueprint.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_64_full_production_pipeline_and_lora_gpu_activation/blueprint.md)
  - [`design.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_64_full_production_pipeline_and_lora_gpu_activation/design.md)
  - [`tasks.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_64_full_production_pipeline_and_lora_gpu_activation/tasks.md)

---

## 1. Functional Requirements — Sovereign Authentication & Session Resilience (`REQ-P64-AUTH-*`)

### `REQ-P64-AUTH-01`: Admin Auto-Confirm & Edge Isolate Fallback on Registration
- **WHEN** a client submits `POST /api/auth/register` (or `/v1/auth/register`) with a valid `handle`, `email`, and `password`, **THE SYSTEM SHALL**:
  1. Check handle and email uniqueness in `vhunambiDb` (`EdgeIsolateDatabaseEngine` or SQLite) and, when Supabase is configured, in PostgREST `public.users`.
  2. Attempt user creation via `SupabaseCloudDriver.goTrueAdminCreateUser` (`POST /auth/v1/admin/users` with `email_confirm: true` using `SUPABASE_SERVICE_ROLE_KEY`) so new accounts are auto-confirmed immediately without blocking on email verification links.
  3. Always register the user in `vhunambiDb.registerUser(...)`, persist the creator profile (`public.creators`), user row (`public.users`), and session row (`public.auth_sessions`) to Supabase PostgREST, and return HTTP `201` with a complete `AuthTokenBundle` (`user`, `session`, `accessToken`, `refreshToken`, `expiresAt`) even if Supabase GoTrue `/auth/v1/signup` returns `access_token: null` or is unreachable.

### `REQ-P64-AUTH-02`: Multi-Tier Login Verification on Cloudflare Workers
- **WHEN** a client submits `POST /api/auth/login` (or `/v1/auth/login`) with `identifier` (email or `@handle`) and `password`, **THE SYSTEM SHALL**:
  1. Attempt GoTrue password authentication when `identifier` is an email and Supabase is configured, **AND** if GoTrue fails or returns an error on Cloudflare Workers (`!isNodeSqliteAvailable()`), **SHALL NOT** rethrow the GoTrue error; instead, **THE SYSTEM SHALL** fall back to verifying credentials against `vhunambiDb.authenticateUser(...)` and PostgREST `public.users` (`password_hash`).
  2. Upon successful verification, issue a signed `HS256` `AuthTokenBundle` (`status 200`) and asynchronously upsert the session into `public.auth_sessions`.

### `REQ-P64-AUTH-03`: Client Auth Timeout & Status Code Resilience
- **WHEN** [`SovereignAuthRepository.register`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/core/auth/sovereign_auth_repository.dart#L136-L181) or [`SovereignAuthRepository.login`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/core/auth/sovereign_auth_repository.dart#L184-L224) communicates with the cloud API, **THE CLIENT SHALL** allow a 15-second network timeout (accommodating Worker cold start + Supabase round-trip) and accept HTTP `200`, `201`, or `202` responses containing a valid `accessToken`.

---

## 2. Functional Requirements — Studio Pipeline Scroll Continuity & Hardware Audio Bootstrap (`REQ-P64-UI-*`, `REQ-P64-AUD-*`, `REQ-P64-R2-*`)

### `REQ-P64-UI-01`: Unified Scrollable Compose Workspace (`StudioView` & `GenerationPipelineCard`)
- **WHILE** `isPipelineVisible` is `true` on the Compose tab of [`StudioView`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/studio/presentation/views/studio_view.dart), **THE CLIENT SHALL** render [`GenerationPipelineCard`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/studio/presentation/widgets/generation_pipeline_card.dart) inside the Compose tab's primary `SingleChildScrollView` (`_tabScroll`) rather than as a fixed non-scrollable header above the `IndexedStack`, and **SHALL** configure `_LyricsPanel`'s inner `SingleChildScrollView` with `ClampingScrollPhysics()` so vertical touch-scroll gestures never freeze after generation completes.

### `REQ-P64-AUD-01`: Platform Hardware Speaker Bootstrap in `main.dart`
- **WHEN** the Flutter application boots in [`main.dart`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/main.dart), **THE CLIENT SHALL** invoke `await bootstrapPlatformAudioHandler()` prior to `runApp(...)` and inject the returned `IVhunambiAudioHandler` into `ProviderScope` via `audioHandlerProvider.overrideWithValue(audioHandler)`.

### `REQ-P64-AUD-02`: Cloud Media URL Normalization in `VhunambiAudioHandler` & `AudioSourceResolver`
- **WHEN** `VhunambiAudioHandler.playTrack(track)` or `AudioSourceResolver.resolveSource(track)` resolves a remote stream URI, **THE CLIENT SHALL** normalize any relative `/r2/...`, `/mock-storage/...`, or legacy `https://r2.vhunambi.com/...` / `https://cdn.vhunambi.co.za/...` URL via `AppConstants.normalizeCloudMediaUrl(...)` before passing the URI to `just_audio`, and **SHALL** use `resolved.streamSource` when playing local encrypted `.vmf` vault files.

### `REQ-P64-R2-01`: Read-Through R2 Media Synthesizer & Zero-404 Streaming (`GET /r2/:key`)
- **WHEN** `GET /r2/:key` is requested on [`server.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/server.ts) and the requested key is absent from `VHUNAMBI_VAULT` (and S3 fallback), **THE SYSTEM SHALL**:
  1. Dynamically synthesize a valid, multi-bar 44.1 kHz (or 22.05 kHz) stereo 16-bit PCM RIFF/WAVE audio payload for `.mp3` / `.wav` / `.m4a` keys, a valid 256x256 RGB BMP/PNG image for `.png` / `.jpg` / `.bmp` keys, or a valid JSON manifest for `.json` keys via `synthesizeMediaForR2Key(cleanKey)`.
  2. Persist the synthesized bytes into `VHUNAMBI_VAULT` (`uploadBytesToR2`) via `ctx.waitUntil` so subsequent requests are served from Cloudflare R2 edge cache.
  3. Support HTTP `Range: bytes=start-end` partial-content requests (`206 Partial Content`) required by Android `ExoPlayer` / iOS `AVPlayer` (`just_audio`).

### `REQ-P64-R2-02`: System R2 Catalog Seeder Endpoint (`POST /api/system/seed-r2-media`)
- **WHEN** `POST /api/system/seed-r2-media` is called on [`system_routes.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/routes/system_routes.ts), **THE SYSTEM SHALL** synthesize and upload all seeded Explore tracks, Marketplace beat previews, Voice archetype previews, and default cover artwork into `zr-studio-audio` R2 and return a JSON manifest of seeded object keys and byte sizes.

---

## 3. Functional Requirements — 19-Table Supabase PostgreSQL Persistence (`REQ-P64-DB-*`)

### `REQ-P64-DB-01`: Cold-Start Hydration from Supabase PostgREST
- **WHEN** a Cloudflare Worker isolate handles its first request and `SupabaseCloudDriver.isConfigured()` is `true`, **THE SYSTEM SHALL** asynchronously hydrate `EdgeIsolateDatabaseEngine` from Supabase PostgREST (`creators`, `users`, `tracks`, `kinetic_posts`, `marketplace_assets`, `beat_licenses`, `playlists`, `library_items`, `wallet_ledger`, and `generation_jobs`) so isolate recycling never wipes user or catalog state.

### `REQ-P64-DB-02`: Non-Blocking Write-Through & Atomic RPC Wiring
- **WHEN** any domain mutation occurs in `EdgeIsolateDatabaseEngine` (track publish, like/cosign, post creation, library sync, playlist mutation, job creation/completion, wallet tip, payout, or beat license purchase), **THE SYSTEM SHALL** mirror the write to Supabase PostgREST or invoke the corresponding PL/pgSQL RPC (`execute_atomic_payout`, `record_beat_license_atomic`, `send_cultural_tip_atomic`) via `SupabaseCloudDriver`.

---

## 4. Functional Requirements — RunPod `zr-studio-gpu` & Open-Source LLM Engine (`REQ-P64-GPU-*`, `REQ-P64-LLM-*`, `REQ-P64-VIS-*`)

### `REQ-P64-GPU-01`: `model_utils.py` (`ZRModelManager` with `bf16`, 45 Steps & R2 LoRA Hot-Swapping)
- **THE GPU WORKER** (`tools/zr-studio-gpu/model_utils.py`) **SHALL** provide `ZRModelManager.get_instance()` supporting:
  1. ACE-Step 1.5 pipeline loading in `torch.bfloat16` (`bf16`) on CUDA (`float32` on CPU) with `infer_steps = 45` (configurable 35–50 steps) and 44.1 kHz stereo output.
  2. Dynamic downloading, local `/tmp/zr_lora_cache` caching, and hot-swapping of `.safetensors` LoRA adapters (`amapiano_logdrum_v1`, `gqom_durban_v1`, `maskandi_picking_v1`, `venda_malende_v1`, `afrobeats_lagos_v1`, plus custom vocal LoRAs) from Cloudflare R2 (`zr-studio-audio`).
  3. A multi-stem 44.1 kHz stereo harmonic/percussive synthesis fallback (`synthesize_structured_song_wav`) when ACE-Step model weights are not mounted on the container volume, eliminating the 55Hz sine-wave fallback.

### `REQ-P64-GPU-02`: Smart RunPod Queue-Zero Detection & Real 4-Stem R2 Synthesis
- **WHEN** `dispatchSynthesisJob` or `checkRunPodJobStatus` detects that RunPod endpoint `e7wt9pgo7djv55` has `0` active/idle workers (`workersIdle === 0 && workersRunning === 0`) or a job remains stuck in `IN_QUEUE` beyond the fast-fail threshold, **THE SYSTEM SHALL** trigger `simulateSynthesisPipeline` in [`mock_worker.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/modules/synthesis/mock_worker.ts) which **SHALL** synthesize and upload four distinct 44.1 kHz stem WAVs (`vocals`, `drums`, `bass`, `melodic`), a mastered stereo track, cover artwork, and a measured MMO v2.0 manifest into `zr-studio-audio` R2 before broadcasting `step: 'ready'`.

### `REQ-P64-LLM-01`: Sovereign Open-Source RunPod LLM Dispatcher (`Qwen2.5-7B-Instruct` / `Llama-3.1-8B-Instruct`)
- **WHEN** `generateLyricsFromLLM`, `refineLyricsWithLLM`, or `expandPromptWithOpenSourceLLM` is invoked, **THE SYSTEM SHALL**:
  1. Prioritize open-source LLM inference hosted on RunPod (`RUNPOD_LLM_URL` or `RUNPOD_LLM_ENDPOINT_ID` serving OpenAI-compatible vLLM / `Qwen/Qwen2.5-7B-Instruct` or `meta-llama/Llama-3.1-8B-Instruct` with `RUNPOD_API_KEY`) without requiring proprietary Anthropic or Grok API keys.
  2. Fall back seamlessly to a deterministic, prompt-reactive Bantu & English multi-section lyric composer (`[INTRO]`, `[VERSE 1]`, `[CHORUS]`, `[VERSE 2]`, `[BRIDGE]`, `[OUTRO]`) and Two-Stage Musical Tag Planner that incorporates the user's exact prompt keywords, genre instrumentation, BPM, musical key, and indigenous Bantu idioms (`Tshivenda`, `isiZulu`, `isiXhosa`, `Sesotho`, `Sepedi`, `Xitsonga`).

### `REQ-P64-VIS-01`: Procedural Genre-Keyed Cover Artwork & Valid Video Containers
- **WHEN** [`vision_routes.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/routes/vision_routes.ts) generates fallback cover artwork or video reels, **THE SYSTEM SHALL** generate a valid, high-contrast procedural BMP/PNG image (`>= 16 KB`) using genre-keyed color gradients and upload it to `zr-studio-audio` R2.

---

## 5. Requirement-to-Verification Traceability Matrix

| Requirement ID | Primary Implementation Files | Verification Test / Gate |
| :--- | :--- | :--- |
| `REQ-P64-AUTH-01..03` | `apps/vhunambi_api/src/routes/auth_routes.ts`, `apps/vhunambi_api/src/db/supabase_cloud_driver.ts`, `apps/vhunambi_client/lib/core/auth/sovereign_auth_repository.dart` | `apps/vhunambi_api/src/__tests__/phase64_production_pipeline.test.ts` (`G-64-01`) |
| `REQ-P64-UI-01` | `apps/vhunambi_client/lib/features/studio/presentation/views/studio_view.dart`, `apps/vhunambi_client/lib/features/studio/presentation/widgets/generation_pipeline_card.dart` | `apps/vhunambi_client/test/features/studio/phase64_studio_scroll_and_audio_test.dart` (`G-64-02`) |
| `REQ-P64-AUD-01..02` | `apps/vhunambi_client/lib/main.dart`, `apps/vhunambi_client/lib/features/player/data/services/vhunambi_audio_handler.dart`, `apps/vhunambi_client/lib/features/player/data/services/audio_source_resolver.dart` | `apps/vhunambi_client/test/features/studio/phase64_studio_scroll_and_audio_test.dart` (`G-64-03`) |
| `REQ-P64-R2-01..02` | `apps/vhunambi_api/src/modules/synthesis/r2_media_synthesizer.ts`, `apps/vhunambi_api/src/server.ts`, `apps/vhunambi_api/src/routes/system_routes.ts` | `apps/vhunambi_api/src/__tests__/phase64_production_pipeline.test.ts` (`G-64-03`) |
| `REQ-P64-DB-01..02` | `apps/vhunambi_api/src/db/edge_persistence_bridge.ts`, `apps/vhunambi_api/src/db/supabase_cloud_driver.ts` | `apps/vhunambi_api/src/__tests__/phase64_production_pipeline.test.ts` (`G-64-04`) |
| `REQ-P64-GPU-01..02` | `tools/zr-studio-gpu/model_utils.py`, `apps/vhunambi_api/src/modules/synthesis/runpod_adapter.ts`, `apps/vhunambi_api/src/modules/synthesis/mock_worker.ts` | `apps/vhunambi_api/src/__tests__/phase64_production_pipeline.test.ts` (`G-64-05`) |
| `REQ-P64-LLM-01` | `apps/vhunambi_api/src/modules/lyrics/llm_handler.ts`, `apps/vhunambi_api/src/modules/synthesis/prompt_compiler.ts` | `apps/vhunambi_api/src/__tests__/phase64_production_pipeline.test.ts` (`G-64-06`) |
| `REQ-P64-VIS-01` | `apps/vhunambi_api/src/routes/vision_routes.ts`, `apps/vhunambi_api/src/modules/synthesis/r2_media_synthesizer.ts` | `apps/vhunambi_api/src/__tests__/phase64_production_pipeline.test.ts` (`G-64-07`) |


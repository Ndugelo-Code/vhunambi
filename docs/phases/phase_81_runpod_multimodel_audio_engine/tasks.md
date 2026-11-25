# Phase 81 Tasks — RunPod Multi-Model Audio Engine (`MiniMax Music 3.0` + `ACE-Step 1.5 XL`) & Multi-Take A&R Baking

> **Document ID:** `TASKS-PHASE-81`  
> **Phase Folder:** `docs/phases/phase_81_runpod_multimodel_audio_engine/`  
> **Execution Strategy:** Two-Pass Deterministic Stage 4 (`/vhunambi-executioner`) — **Pass 1 (`M81.1`–`M81.2`)** closes all Worker wire/polling/DO blindspots and builds the Python `ZRMultiModelRouter`, duet lyric sanitizer, `360s` duration lift, `32 kHz -> 44.1 kHz` resampler, and Multi-Take A&R scorer with full automated tests; **Pass 2 (`M81.3`–`M81.4`)** upgrades the Flutter multi-take A&R UI, updates `:vhunambi-v4` Docker manifests, configures RunPod `L40S 48GB` + Cloudflare Worker deployment, and runs `SLEEP` memory consolidation.

---

## 1. Master Milestone Roadmap

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ PASS 1 — WORKER EDGE SYNC & PYTHON MULTI-MODEL A&R ENGINE                    │
│  M81.1: Worker is_instrumental, MiniMax Casing, Multi-Take Polling & DO Sync │
│         [T81.1.1 -> T81.1.4]                                                 │
│  M81.2: Python ZRMultiModelRouter, 64-Bit Seeds, 360s, 32k->44.1k & A&R      │
│         [T81.2.1 -> T81.2.4]                                                 │
├──────────────────────────────────────────────────────────────────────────────┤
│ PASS 2 — CLIENT MULTI-TAKE UI, CONTAINER/RUNPOD DEPLOY & MEMORY SLEEP        │
│  M81.3: Flutter Scored 44dp Take Chips, Vault Promotion & Dockerfile v4      │
│         [T81.3.1 -> T81.3.3]                                                 │
│  M81.4: RunPod L40S 48GB + Worker Deploy, E2E Verification & Memory Sleep    │
│         [T81.4.1 -> T81.4.3]                                                 │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Pass 1 — Milestone `M81.1`: Cloudflare Worker Wire, Polling, Webhook & DO Sync

- [x] **`T81.1.1` — Duet/Drop Sanitizer Alignment & `formatLyricsForEngine` (`REQ-P81-ROUTER-03`, `REQ-P81-WIRE-01`)**
  - **Targets:** `apps/vhunambi_api/src/modules/lyrics/lyrics_sanitizer.ts`, `apps/vhunambi_api/src/modules/synthesis/prompt_compiler.ts`
  - **Scope:** Add `log\s*drum\s*drop`, `piano\s*solo`, `drum\s*solo`, and `solo` to `ALLOWED_SECTION`; export `formatLyricsForEngine(rawLyrics, resolvedEngine)` preserving Title-Case `[Voice A]` / `[Voice B]` / `[Guitar Solo]` / `[Log Drum Drop]` for `minimax_music_3`; add `isInstrumental: boolean` to `CompiledSynthesisPrompt` and reject `yue2` in `resolveTargetAudioEngine`.
  - **Acceptance:** `formatLyricsForEngine('[Voice A]\nSing\n[Log Drum Drop]', 'minimax_music_3')` preserves `[Voice A]` and `[Log Drum Drop]`.

- [x] **`T81.1.2` — `runpod_adapter.ts` `is_instrumental` Dispatch & Multi-Take `/status/:id` Sync (`REQ-P81-WIRE-01`, `REQ-P81-WIRE-02`)**
  - **Targets:** `apps/vhunambi_api/src/modules/synthesis/runpod_adapter.ts`, `apps/vhunambi_api/src/routes/generation_routes.ts`
  - **Scope:** Include `is_instrumental` on both `input` and `input.song_spec` and format lyrics with `formatLyricsForEngine` in `dispatchSynthesisJob`. Extend `RunPodJobStatusResult` and `checkRunPodJobStatus` to extract `takes`, `resolvedEngine`, `attributionTag`, `stage`, and `progress`, and wire them into `GET /v1/generations/:id` (`completeJob` + `upsertGenerationJobAsync` + `updateJobProgress`).
  - **Acceptance:** Active polling of a `COMPLETED` 3-take RunPod job preserves all 3 takes, seeds, scores, and `MiniMax-Music3` attribution without collapsing to a 1-take `seed: 1` stub.

- [x] **`T81.1.3` — Edge Webhook Cloud Progress Sync & `GenerationSessionDO` Stage Mapping (`REQ-P81-WIRE-03`)**
  - **Targets:** `apps/vhunambi_api/src/routes/webhook_routes.ts`, `apps/vhunambi_api/src/modules/realtime/generation_session_do.ts`
  - **Scope:** Persist intermediate webhook stage transitions (`planning_lyrics`, `synthesizing`, `separating_stems`, `converting_vocals`, `mastering`, `uploading`) to Supabase/Edge DB via guarded `waitUntil(vhunambiDb.updateGenerationJobAsync(...))` in `webhook_routes.ts`. Map `planning_lyrics` $\to$ `stepIndex: 2` and `converting_vocals` $\to$ `stepIndex: 3` and include `resolved_engine`, `attribution_tag`, and `takes` on `completed_track` in `generation_session_do.ts`.
  - **Acceptance:** Cold Edge isolate `GET /v1/generations/:id` reflects intermediate webhook `step` & `progressPct`; DO frames emit `step_index == 2` for `planning_lyrics` and `step_index == 3` for `converting_vocals`.

- [x] **`T81.1.4` — Backend Phase 81 Test Suite (`G81-03`)**
  - **Targets:** `apps/vhunambi_api/test/phase81_runpod_multimodel_pipeline.test.ts` (new), `apps/vhunambi_api/package.json`
  - **Scope:** Test `is_instrumental` & MiniMax Title-Case `[Voice A]`/`[Log Drum Drop]` in RunPod `/run` payload, multi-take `/status/:id` polling settlement, simulated Edge isolate intermediate webhook persistence, and `GenerationSessionDO` `planning_lyrics` / `converting_vocals` / `takes` frames. Register in `package.json` `test` script.
  - **Acceptance:** `cd apps/vhunambi_api && .\node_modules\.bin\tsc.cmd --noEmit && npm test` passes `100%` (`34/34` suites).

---

## 3. Pass 1 — Milestone `M81.2`: Python Multi-Model Router, 360s Ceiling & Multi-Take A&R Engine

- [x] **`T81.2.1` — `ZRMultiModelRouter`, `MiniMax3Backend`, `32k -> 44.1k` Resampler & A&R Scorer (`REQ-P81-ROUTER-01..02`, `REQ-P81-AR-01..02`)**
  - **Target:** `tools/zr-studio-gpu/model_router.py` (new)
  - **Scope:** Implement `ZRMultiModelRouter` (`minimax_music_3` vs `ace_step_xl_{turbo,sft,base}`, instrumental/ref-audio HTTP `400` shield, strict `YuE2` ban, CUDA VRAM offload guard), `ensure_unique_take_seeds` (non-zero 64-bit unique integers), `MiniMax3Backend` (`sglang-omni` `/v1/audio/speech` client + truthful fallback attribution clearing), `normalize_wav_to_44k1` (`soxr` VHQ / `scipy.signal.resample_poly` `441/320`), and `score_take_ar_quality` ($Q_{\text{take}} \in [0.05, 0.99]$).
  - **Acceptance:** Pure Python + NumPy/SciPy/SoundFile execution passes offline without requiring GPU hardware.

- [x] **`T81.2.2` — Upgrade `model_utils.py` for Duet Tags, `10–360s`, `12-step` Turbo, Seeded Audio & Volume LoRAs (`REQ-P81-INFRA-01`, `REQ-P81-ROUTER-02..03`)**
  - **Target:** `tools/zr-studio-gpu/model_utils.py`
  - **Scope:** Sync `_ALLOWED_SECTION_RE` with all duet/choir/solo/drop tags + `format_lyrics_for_engine`; lift duration clamp from `240` to `360` (`max(10, min(360, ...))`); allow `infer_steps >= 8` for `ace_step_xl_turbo`; prefer `/runpod-volume/lora_cache` with `20s` timeout; forward `seed` and `variant` through `generate_audio` and `synthesize_structured_song_wav`.
  - **Acceptance:** Distinct `seed` values yield distinct stereo waveforms (`SHA-256` differs across takes); `300s` & `360s` durations are preserved; `[Voice A]` and `[Log Drum Drop]` survive sanitization.

- [x] **`T81.2.3` — Multi-Take `handler.py` & Per-Take R2 Uploads in `mmo_extractor.py` (`REQ-P81-AR-02`)**
  - **Targets:** `tools/zr-studio-gpu/mmo_extractor.py`, `tools/zr-studio-gpu/handler.py`
  - **Scope:** Add `upload_take_mp3_to_r2(job_id, take_index, wav_path)` in `mmo_extractor.py`. Refactor `handler.py` to consume all V6 `job_input` fields, emit `planning_lyrics` $\to$ `synthesizing` $\to$ `separating_stems` $\to$ `converting_vocals` $\to$ `mastering` $\to$ `uploading` $\to$ `completed` HMAC webhooks, loop `1..batch_count` with unique seeds, normalize `32 kHz -> 44.1 kHz`, rank takes via `score_take_ar_quality`, master all takes to `-14.0 LUFS`, run Demucs + 60Hz MMO on the top-scoring take, upload `take_{i}.mp3` + canonical `master.mp3`, and return `takes`, `resolved_engine`, and `attribution_tag`.
  - **Acceptance:** `runpod_handler({"input": {"job_id": "vhunambi_t1", "batch_count": 3, ...}})` returns `3` takes ordered highest-score-first with unique seeds, distinct audio hashes, and matching `audio_url == takes[0]["audio_url"]`.

- [x] **`T81.2.4` — Python GPU Unit Test Suite (`G81-01`, `G81-02`)**
  - **Target:** `tools/zr-studio-gpu/test_phase81_multimodel_router.py` (new)
  - **Scope:** Comprehensive `unittest` / `pytest` suite covering routing matrix, instrumental MiniMax shield, `YuE2` `ValueError`, unique 64-bit seeds, `[Voice A]`/`[Voice B]`/`[Guitar Solo]`/`[Log Drum Drop]` preservation, `360s` duration support, `32 kHz -> 44.1 kHz` exact frame count & sample rate, A&R quality scoring (clean harmonic take beats clipped/silent take), and end-to-end 3-take `runpod_handler` execution with HMAC webhook capture.
  - **Acceptance:** `python -m py_compile tools/zr-studio-gpu/*.py` and `python -m unittest tools/zr-studio-gpu/test_phase81_multimodel_router.py` pass `100%`.

---

## 4. Pass 2 — Milestone `M81.3`: Flutter Scored Take Switcher, Vault Promotion & `:vhunambi-v4` Docker Manifests

- [x] **`T81.3.1` — `GenerationTake` Metadata, Vault Promotion & `44dp` Scored Take Chips (`REQ-P81-CLIENT-01`)**
  - **Targets:** `apps/vhunambi_client/lib/features/studio/domain/models/generation_pipeline_state.dart`, `apps/vhunambi_client/lib/features/studio/data/services/http_generation_submission_service.dart`, `apps/vhunambi_client/lib/features/studio/presentation/providers/generation_pipeline_providers.dart`, `apps/vhunambi_client/lib/features/studio/presentation/widgets/generation_pipeline_card.dart`
  - **Scope:** Add `engineUsed`, `score`, and `attribution` to `GenerationTake`; update `LibraryTrack.remoteAudioUrl` when `selectActiveTake(index)` switches takes; enforce `minHeight: 44` on `Key('pipeline_take_chip_$i')`, render `PhosphorIconsFill.sparkle` + compact `'${(score * 100).round()}%'` badge alongside `'Take ${i + 1}'`, and replace remaining static dark colors in `GenerationPipelineCard` with `AppColors.*Of(context)`.
  - **Acceptance:** `STD-UIUX-001` (`0` stock `Icons.*`, `0` raw emojis); `phase80_studio_cockpit_v6_test.dart` remains 100% green.

- [x] **`T81.3.2` — Flutter Phase 81 Multi-Take A&R Widget Test (`G81-04`)**
  - **Target:** `apps/vhunambi_client/test/features/studio/phase81_multitake_ar_pipeline_test.dart` (new)
  - **Scope:** Verify `GenerationTake.fromJson` parses `score`, `engineUsed`, and `attribution`, `GenerationPipelineCard` renders `>= 44dp` take pills with score percentages in Light & Dark modes without overflow at `360x800`, and `selectActiveTake(1)` updates both `playerStateProvider` and `libraryTracksProvider`.
  - **Acceptance:** `flutter test --no-pub --timeout=60s test/features/studio/phase80_studio_cockpit_v6_test.dart test/features/studio/phase81_multitake_ar_pipeline_test.dart` passes `100%`.

- [x] **`T81.3.3` — Upgrade `Dockerfile`, `Dockerfile.delta`, `requirements.txt` & `README.md` (`REQ-P81-INFRA-01`, `03`)**
  - **Targets:** `tools/zr-studio-gpu/Dockerfile`, `tools/zr-studio-gpu/Dockerfile.delta`, `tools/zr-studio-gpu/requirements.txt`, `tools/zr-studio-gpu/README.md`
  - **Scope:** Add `soxr>=0.4.0`, copy `model_router.py`, default `HF_HOME=/runpod-volume/hf_cache` and `ZR_LORA_CACHE_DIR=/runpod-volume/lora_cache`, run build-time `py_compile` across all 6 Python modules, and document `:vhunambi-v4` `L40S 48GB` + `100 GB` `/runpod-volume` deployment topology in `README.md`.
  - **Acceptance:** Zero `YuE2` references anywhere in `tools/zr-studio-gpu/`.

---

## 5. Pass 2 — Milestone `M81.4`: Cloud / RunPod Configuration & Memory Consolidation (`SLEEP`)

- [x] **`T81.4.1` — RunPod `zr-studio-prod` (`e7wt9pgo7djv55`) & Cloudflare Worker Deployment (`G81-05`)**
  - **Scope:** Updated `e7wt9pgo7djv55` (v8) GPU pools (`ADA_48_PRO`, `AMPERE_48`, `AMPERE_80`), `disk: 40`, and `timeout: 1200000` cleanly via RunPod MCP without clobbering secrets; updated `.github/workflows/push_gpu_worker.yml` to build `:vhunambi-v4`; deployed updated `vhunambi-api` (`86c1a475-d1dd-4ece-b11e-489ad9bd2991`) to Cloudflare Workers. *(Note: `100 GB` `/runpod-volume` [`$7/mo` recurring on `$13.57` prepaid balance] and endpoint `image` flip to `:vhunambi-v4` intentionally held until user pushes on night data to trigger GitHub Actions Docker Hub push.)*
- [x] **`T81.4.2` — Finalize `memory.md`, Update Master Tracker & Run `consolidate_memory.mjs` (`G81-06`)**
  - **Targets:** `docs/phases/phase_81_runpod_multimodel_audio_engine/memory.md`, `docs/phases/PHASE_80_PLUS_STUDIO_AND_RUNPOD_MASTER_TRACKER.md`, `docs/memory/*`
  - **Scope:** Promoted `memory.md` to `"status": "completed"`, updated Master Tracker, and ran `node .agents/skills/vhunambi-memory/scripts/consolidate_memory.mjs`.

---

## 6. Stage 4 Anti-Trap Checklist & Verification Commands

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ STAGE 4 EXECUTION INVARIANTS (/vhunambi-executioner)                         │
│  [x] Zero YuE2 (CC BY-NC 4.0) strings, packages, or routes                   │
│  [x] Truthful MiniMax-Music3 attribution (cleared on ACE-Step/synth fallback)│
│  [x] infer_steps floor lowered to 8 so 12-step ace_step_xl_turbo is fast     │
│  [x] Sibling Text('Take ${i + 1}') preserved for Phase 80 finder parity      │
│  [x] Guarded c.executionCtx.waitUntil in webhook_routes.ts for Node tests    │
│  [x] Direct .\node_modules\.bin\tsc.cmd (never npx) on Windows PowerShell    │
│  [x] Never run two concurrent flutter commands                               │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Exact Verification Gate Commands
```powershell
# Gate G81-01 & G81-02: Python Bytecode & Multi-Model Router / A&R Unit Tests
python -m py_compile tools/zr-studio-gpu/model_router.py tools/zr-studio-gpu/model_utils.py tools/zr-studio-gpu/mmo_extractor.py tools/zr-studio-gpu/stem_mastering_worker.py tools/zr-studio-gpu/seed_vc_worker.py tools/zr-studio-gpu/handler.py
python -m unittest discover -s tools/zr-studio-gpu -p "test_*.py" -v

# Gate G81-03: Cloudflare Worker TypeScript & All 34 API Suites
cd apps/vhunambi_api; .\node_modules\.bin\tsc.cmd --noEmit && npm test

# Gate G81-04: Flutter Multi-Take A&R & Studio V6 Regression
cd apps/vhunambi_client; flutter test --no-pub --timeout=60s test/features/studio/phase80_studio_cockpit_v6_test.dart test/features/studio/phase81_multitake_ar_pipeline_test.dart test/features/studio/widgets/generation_pipeline_card_test.dart

# Gate G81-06: Codebase Brain Sleep Consolidation
node .agents/skills/vhunambi-memory/scripts/consolidate_memory.mjs
```

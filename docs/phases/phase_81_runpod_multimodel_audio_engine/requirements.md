# Phase 81 Requirements — RunPod Multi-Model Audio Engine (`MiniMax Music 3.0` + `ACE-Step 1.5 XL`) & Multi-Take A&R Baking

> **Document ID:** `REQ-PHASE-81`  
> **Phase Folder:** `docs/phases/phase_81_runpod_multimodel_audio_engine/`  
> **Predecessor Audit:** [`PHASE81_RUNPOD_MULTIMODEL_AUDIO_ENGINE_AUDIT.md`](../../audits/PHASE81_RUNPOD_MULTIMODEL_AUDIO_ENGINE_AUDIT.md)  
> **Conventions:** EARS (`WHEN`, `WHILE`, `IF...THEN`, `WHERE`) and RFC-2119 (`SHALL`, `MUST`, `SHOULD`, `MAY`).

---

## 1. Document Scope & Core Legal / Architectural Invariants

1. **Commercial Licensing Invariant:**
   - **`YuE2` (`CC BY-NC 4.0`) Prohibition:** `YuE2` SHALL NOT be installed, imported, downloaded, or routed anywhere in `tools/zr-studio-gpu/`, `apps/vhunambi_api/`, or `apps/vhunambi_client/`. Any explicit request attempting `resolved_engine = 'yue2'` SHALL raise a deterministic `ValueError` in Python and fail schema validation in TypeScript.
   - **`MiniMax Music 3.0` Attribution & Cap Guardrail:** Every take synthesized by `minimax_music_3` MUST carry `attribution: 'MiniMax-Music3'` in `takes_json`, MMO `manifest_payload`, webhook payloads, and `GET /v1/generations/:id` responses so `GenerationPipelineCard` renders `Key('pipeline_minimax_attribution_badge')`.
   - **GPL-3.0 Server-Side Isolation:** `Pedalboard` (and Phase 82 `Seed-VC` / `Matchering 2.0`) SHALL execute strictly server-side inside `tools/zr-studio-gpu/`; zero GPL code or binaries SHALL be linked into `apps/vhunambi_client/`.
2. **Zero-OOM & Persistent Cache Invariant:** Multi-model weights (`MiniMaxAI/MiniMax-Music3` + `ACE-Step 1.5 XL`) SHALL reside on a persistent RunPod Network Volume (`/runpod-volume/hf_cache`) attached to `48 GB+` VRAM GPU pools (`ADA_48_PRO` / `AMPERE_48` / `AMPERE_80`), never re-downloading onto a `30 GB` ephemeral root disk on cold start.
3. **Graceful Degradation Invariant:** In unit-test, CPU, or unprovisioned-weight environments, `ZRMultiModelRouter` SHALL fall back cleanly from `minimax_music_3` to `ACE-Step 1.5 XL-SFT` (if loaded) and finally to `synthesize_structured_song_wav()` (varying deterministically per `seed`), never crashing the worker or emitting identical multi-take waveforms.

---

## 2. RunPod Container & Infrastructure Requirements (`REQ-P81-INFRA-*`)

### `REQ-P81-INFRA-01` — Persistent `/runpod-volume` Cache & LoRA Directory
1. `Dockerfile` (`:vhunambi-v4`), `model_utils.py`, and `model_router.py` **SHALL** resolve `HF_HOME` to `/runpod-volume/hf_cache` and `ZR_LORA_CACHE_DIR` to `/runpod-volume/lora_cache` whenever `/runpod-volume` is mounted (falling back to `/tmp/hf_cache` and `/tmp/zr_lora_cache` only in local/ephemeral tests).
2. A RunPod Network Volume (`>= 100 GB`) **SHALL** be provisioned and attached to endpoint `e7wt9pgo7djv55` (`zr-studio-prod`) in an `ADA_48_PRO`-capable datacenter.

### `REQ-P81-INFRA-02` — `48 GB` GPU Pool & Long-Bake Timeout Configuration
Endpoint `e7wt9pgo7djv55` (`zr-studio-prod`) **SHALL** be configured with:
1. GPU pools restricted to `>= 48 GB` VRAM tiers (`ADA_48_PRO` — `NVIDIA L40S 48GB` / `RTX 6000 Ada 48GB`, `AMPERE_48` — `RTX A6000` / `A40`, `AMPERE_80`), removing `AMPERE_16` (`16 GB`) and `24 GB` pools from co-hosted multi-model bakes.
2. Container disk `>= 40 GB` and execution `timeout = 1200000` ms (`20 minutes`) to accommodate `batchCount = 4` × `300s` Studio Bakes plus stem separation and R2 upload.

### `REQ-P81-INFRA-03` — Multi-Model Container Dependencies (`Dockerfile` & `requirements.txt`)
`tools/zr-studio-gpu/Dockerfile` and `requirements.txt` **SHALL** include `soxr>=0.4.0` (with `scipy.signal.resample_poly` fallback), `ACE-Step 1.5 XL` pipeline compatibility, HTTP client support for local co-hosted `sglang-omni` (`MiniMaxAI/MiniMax-Music3` `/v1/audio/speech` server on `127.0.0.1:30000` or direct Python wrapper), `py3langid==0.3.0` pin, and build-time `py_compile` + import verification across all worker modules (`model_router.py`, `model_utils.py`, `mmo_extractor.py`, `stem_mastering_worker.py`, `seed_vc_worker.py`, `handler.py`).

---

## 3. Multi-Model Router, Seeding & Lyric Fidelity Requirements (`REQ-P81-ROUTER-*`)

### `REQ-P81-ROUTER-01` — Deterministic `ZRMultiModelRouter` & MiniMax HTTP `400` Shield
**WHEN** `ZRMultiModelRouter.resolve_route(job_input, song_spec)` evaluates an incoming RunPod job:
1. **IF** `resolved_engine == 'yue2'` or `engine_tier == 'yue2'`, it **SHALL** raise `ValueError("YuE2 (CC BY-NC 4.0) is prohibited in commercial Vhunambi production")`.
2. **IF** `engine_tier == 'fast_draft'` OR `resolved_engine == 'ace_step_xl_turbo'`, it **SHALL** select `'ace_step_xl_turbo'` (`infer_steps = 12`, `attribution_tag = None`).
3. **IF** `is_instrumental == True` AND `not reference_audio_url` AND `engine_tier != 'sovereign_custom'`, it **SHALL** force `'ace_step_xl_sft'` (`attribution_tag = None`) even if `resolved_engine == 'minimax_music_3'` was mistakenly passed — guaranteeing `sglang-omni` `/v1/audio/speech` never receives empty lyrics.
4. **IF** `engine_tier == 'sovereign_custom'` OR `bool(reference_audio_url)` OR `svc_mode == 'zero_shot_clone'`, it **SHALL** select `'ace_step_xl_base'` (`infer_steps = 60`, `attribution_tag = None`).
5. **OTHERWISE** (`studio_bake` vocal/duet track with non-empty lyrics and no reference audio), it **SHALL** select `'minimax_music_3'` with `attribution_tag = 'MiniMax-Music3'`.
6. **VRAM Co-Residency Guard:** Before loading `minimax_music_3` in-process if `ace_step` is resident on CUDA (or vice versa when free VRAM `< 20 GB`), the router **SHALL** offload inactive pipeline weights to CPU / `torch.cuda.empty_cache()` so a `48 GB` L40S never OOMs during mixed workloads.

### `REQ-P81-ROUTER-02` — Cryptographic Per-Take Non-Zero 64-Bit Seeding
1. **WHEN** `batch_count` ($B \in \{1, 2, 3, 4\}$) takes are requested, `handler.py` **SHALL** consume `take_seeds` from `job_input` and fill any missing/zero/duplicate slots using `secrets.randbits(53) | 1` (strictly `> 0`, unique across all $B$ takes).
2. Every engine backend (`minimax_music_3` `sglang-omni` payload, `ACE-Step 1.5 XL` `manual_seeds` / `torch.Generator`, and `synthesize_structured_song_wav` fallback) **MUST** be seeded with that take's exact `seed` so `batch_count > 1` never produces byte-identical audio files.

### `REQ-P81-ROUTER-03` — Duet/Choir/Solo Cue Preservation & `360s` Duration Ceiling
1. `model_utils.py#_ALLOWED_SECTION_RE` and `lyrics_sanitizer.ts#ALLOWED_SECTION` **SHALL** both allow: `intro`, `verse \d*`, `pre-chorus`, `chorus \d*`, `bridge`, `outro`, `instrumental`, `hook`, `voice [a-d]`, `duet`, `choir`, `call`, `response`, `guitar solo`, `sax solo`, `piano solo`, `drum solo`, `log drum drop`, `drop`, and `breakdown`.
2. **WHEN** formatting lyrics for `minimax_music_3`, `format_lyrics_for_engine(raw_lyrics, 'minimax_music_3')` **SHALL** preserve Title-Case voice/arrangement headers (`[Verse 1]`, `[Voice A]`, `[Voice B]`, `[Duet]`, `[Choir]`, `[Guitar Solo]`, `[Log Drum Drop]`) while stripping arbitrary parenthetical stage prose.
3. `model_utils.py` and `model_router.py` **SHALL** lift the duration clamp from `240s` to **`360s`** (`max(10, min(360, int(duration)))`), logging an informational notice when `duration > 300` on `minimax_music_3` (`<= 300s` sweet spot, `360s` hard cap).
4. `_install_latin_language_guard()` **MUST** remain active on `VoiceBpeTokenizer.encode` so Tshivenda, isiZulu, isiXhosa, Sesotho, Setswana, Sepedi, Xitsonga, siSwati, and isiNdebele never misroute to CJK phoneme tokenizers.

---

## 4. Multi-Take A&R Baking & Sample-Rate Normalization Requirements (`REQ-P81-AR-*`)

### `REQ-P81-AR-01` — `32 kHz` $\to$ `44.1 kHz` Normalization
**WHEN** `minimax_music_3` (or any synthesis backend) writes a WAV whose sample rate $f_s \ne 44,100\text{ Hz}$ (specifically MiniMax's native `32,000 Hz` 16-bit stereo WAV), `normalize_wav_to_44k1(wav_path)` **SHALL** resample it to `44,100 Hz` stereo `PCM_24` (`soxr` VHQ or `scipy.signal.resample_poly(x, 441, 320)`) **before** A&R scoring, Demucs stem separation, Seed-VC stem summing, or mastering.

### `REQ-P81-AR-02` — Mathematical A&R Candidate Scoring & Promotion
1. For each rendered take $i \in \{0, \dots, B-1\}$, the worker **SHALL** compute `score_take_ar_quality(wav_path, is_instrumental)` returning `{ score, active_ratio, crest_db, presence_ratio, clip_ratio }` with `score` $\in [0.05, 0.99]$.
2. The worker **SHALL** identify the winning take $i^* = \arg\max_i \text{score}_i$, run Stage 2 Demucs 4-stem separation, Stage 3 optional Seed-VC, Stage 4 MMO 60Hz telemetry, and Stage 5 `-14.0 LUFS` gentle stereo mastering on the winning take, and apply lightweight `-14.0 LUFS` gentle stereo mastering (`master_clean_stereo_gentle`) to each non-winning take so all `1..4` takes play back at consistent loudness!
3. All takes **SHALL** be uploaded to R2 under distinct keys (`audio/{job_id}/take_{i}.mp3`), with the winning take also published as canonical `audio/{job_id}/master.mp3` and placed at index `0` (or marked `isBest: true` / ordered highest-score-first with `takeIndex: 0..B-1`) so `master_mp3_url == takes[0].audio_url`.

---

## 5. Worker API, Webhook, DO & Client Sync Requirements (`REQ-P81-WIRE-*`, `REQ-P81-CLIENT-*`)

### `REQ-P81-WIRE-01` — Lossless `is_instrumental` & MiniMax Duet Casing in `runpod_adapter.ts`
1. `CompiledSynthesisPrompt` (`prompt_compiler.ts`) **SHALL** include `isInstrumental: boolean` and preserve un-lowercased sanitized lyrics (`clientLyrics` / Title-Case `[Voice A]`) alongside `lyrics`.
2. `dispatchSynthesisJob` (`runpod_adapter.ts`) **SHALL** transmit `is_instrumental: prompt.isInstrumental` at both `input.is_instrumental` and `input.song_spec.is_instrumental`, and pass Title-Case `[Voice A]` / `[Voice B]` lyrics when `prompt.resolvedEngine === 'minimax_music_3'`.

### `REQ-P81-WIRE-02` — Multi-Take Active Polling Parity (`checkRunPodJobStatus` & `GET /v1/generations/:id`)
1. `checkRunPodJobStatus` (`runpod_adapter.ts`) **SHALL** parse `takes`, `resolved_engine`, `attribution_tag`, `stage`, and `progress` from RunPod `/status/:id` `output`.
2. `GET /v1/generations/:id` (`generation_routes.ts`) **SHALL** persist real `liveStatus.takes`, `liveStatus.resolvedEngine`, and `liveStatus.attributionTag` into `completeJob()` and `upsertGenerationJobAsync()` when active polling settles a job, never overwriting a multi-take RunPod result with a single dummy `seed: 1` take.

### `REQ-P81-WIRE-03` — Edge Isolate Progress Persistence & Complete `GenerationSessionDO` Stage Mapping
1. `POST /v1/webhooks/ace-step` (`webhook_routes.ts`) **SHALL** schedule `vhunambiDb.updateGenerationJobAsync(generationId, { status: 'running', step, progressPct }, c)` via guarded `executionCtx.waitUntil` (awaited in Node/Edge tests when `waitUntil` is absent or synchronous) on intermediate stage webhooks so cold Cloudflare Worker isolates serving HTTP pollers observe live `step` and `progressPct` updates.
2. `buildDualDialectPipelineEventFrame` (`generation_session_do.ts`) **SHALL** map `'planning_lyrics'` to `stepIndex = 2` (`'Composing authentic dialect lyrics...'`) and `'converting_vocals'` to `stepIndex = 3` (`'Cloning and polishing vocal stems...'`), and include `resolved_engine`, `attribution_tag`, and `takes` inside `completed_track`.

### `REQ-P81-CLIENT-01` — Scored Multi-Take Pills & Vault Take Promotion (`apps/vhunambi_client/`)
1. `GenerationTake` (`generation_pipeline_state.dart`) **SHALL** parse optional `engineUsed` (`String?`), `score` (`double?`), and `attribution` (`String?`).
2. `GenerationPipelineCard` **SHALL** enforce `minHeight: 44` (`STD-UIUX-001` touch target) on `Key('pipeline_take_chip_$i')`, render `PhosphorIconsFill.sparkle` / score percentage (`'Take ${i + 1} · ${(score * 100).round()}%'` when `score != null`, or `'Take ${i + 1}'` when `score == null` so Phase 80 tests remain 100% compatible), and convert any remaining static `AppColors.surfaceSecondary` in `_ReadyTrackCard` / lyrics box to `AppColors.*Of(context)`.
3. `GenerationPipelineNotifier.selectActiveTake(int index)` **SHALL** also update the corresponding track inside `libraryTracksProvider` (`remoteAudioUrl: nextTrack.masterMp3Url`) when already vaulted so selecting Take 2/3/4 persists across player and vault views.

---

## 6. Non-Functional, Performance & Compliance Requirements (`REQ-P81-NFR-*`)

### `REQ-P81-NFR-01` — `STD-UIUX-001` & `>= 44dp` Touch Ergonomics
All Studio multi-take UI elements (`pipeline_take_chip_$i`) **SHALL** enforce `minHeight: 44`, use `PhosphorIcon` glyphs only (`0` stock `Icons.*`, `0` raw Unicode emojis), use theme-adaptive `AppColors.*Of(context)` tokens in Light & Dark modes, and wrap cleanly without `RenderFlex` overflow at `360x800dp`.

### `REQ-P81-NFR-02` — Headless Offline Testability Across All 3 Runtimes
1. `tools/zr-studio-gpu/test_phase81_multimodel_router.py` **SHALL** run deterministically on CPU-only developer hosts in `< 15s` without requiring CUDA, HuggingFace downloads, or live R2 credentials.
2. `apps/vhunambi_api/test/phase81_runpod_multimodel_pipeline.test.ts` **SHALL** mock external RunPod HTTP calls cleanly while testing real Hono routes, `GenerationSessionDO`, and simulated `workerd` Edge isolates.
3. `apps/vhunambi_client/test/features/studio/phase81_multitake_ar_pipeline_test.dart` **SHALL** complete well within `--timeout=60s` with zero open timers or network sockets.

### `REQ-P81-NFR-03` — Truthful Attribution Clearing on Engine Fallback
**IF** a job initially routed to `minimax_music_3` falls back to `ACE-Step 1.5 XL-SFT` or `zr_harmonic_multi_stem_synthesizer` because `sglang-omni` is offline/unreachable, `ZRMultiModelRouter.synthesize_take` **SHALL** set `attribution = None` and `engine = actual_engine_used` so tracks not rendered by MiniMax are never falsely badged `"MiniMax-Music3"`.

---

## 7. Error Resilience & Fault-Containment Requirements (`REQ-P81-ERR-*`)

### `REQ-P81-ERR-01` — Partial Multi-Take Fault Containment
**IF** 1 candidate take out of `batch_count > 1` raises a transient synthesis error while at least 1 other take succeeds, `handler.py` **SHALL** retain and rank all succeeded takes rather than aborting the entire batch; only if `0` takes succeed SHALL `handler.py` emit `status = 'failed'`.

### `REQ-P81-ERR-02` — Edge `executionCtx` Guard Safety
`webhook_routes.ts` **SHALL** wrap `c.executionCtx` access in `try/catch` (matching `mock_worker.ts#L25-L35`) so Hono never throws `Error: This context has no ExecutionContext` in Node.js unit tests.

---

## 8. Requirement-to-Test Traceability Matrix

| Requirement ID | Target File(s) | Automated Verification Test |
| :--- | :--- | :--- |
| `REQ-P81-INFRA-01..03` | `tools/zr-studio-gpu/Dockerfile`, `requirements.txt`, `model_utils.py` | `test_phase81_multimodel_router.py::test_hf_and_lora_volume_paths` + `py_compile` |
| `REQ-P81-ROUTER-01` | `tools/zr-studio-gpu/model_router.py` | `test_phase81_multimodel_router.py::test_routing_matrix_and_yue2_ban` |
| `REQ-P81-ROUTER-02` | `tools/zr-studio-gpu/model_router.py`, `handler.py` | `test_phase81_multimodel_router.py::test_unique_nonzero_64bit_seeds_produce_distinct_waveforms` |
| `REQ-P81-ROUTER-03` | `tools/zr-studio-gpu/model_utils.py`, `lyrics_sanitizer.ts` | `test_phase81_multimodel_router.py::test_duet_tags_and_360s_ceiling` + `phase81_runpod_multimodel_pipeline.test.ts` |
| `REQ-P81-AR-01..02` | `tools/zr-studio-gpu/model_router.py`, `handler.py`, `mmo_extractor.py` | `test_phase81_multimodel_router.py::test_32khz_upsample_and_ar_multitake_promotion` |
| `REQ-P81-WIRE-01..03` | `runpod_adapter.ts`, `generation_routes.ts`, `webhook_routes.ts`, `generation_session_do.ts` | `apps/vhunambi_api/test/phase81_runpod_multimodel_pipeline.test.ts` |
| `REQ-P81-CLIENT-01` | `generation_pipeline_state.dart`, `generation_pipeline_providers.dart`, `generation_pipeline_card.dart` | `apps/vhunambi_client/test/features/studio/phase81_multitake_ar_pipeline_test.dart` |
| `REQ-P81-NFR-01..03`, `ERR-01..02` | All Phase 81 targets | Full Python + Worker + Flutter test gates (`G81-01`..`G81-04`) |

# Phase 82 Tasks — Studio Baking Post-Processing Chain (`BS-RoFormer` + Neural `Seed-VC` + `Matchering 2.0`)

> **Document ID:** `TASKS-PHASE-82`  
> **Phase Folder:** `docs/phases/phase_82_vocal_cloning_and_broadcast_mastering/`  
> **Execution Strategy:** Two-Pass Deterministic Stage 4 (`/vhunambi-executioner`) — **Pass 1 (`M82.1`–`M82.2`)** builds the complete Python GPU vocal isolation (`BS-RoFormer`), neural `Seed-VC` + Bantu click protection + `6.5 kHz` de-ess/room glue, `44.1/48 kHz` upsampling, and `Matchering 2.0` 6-genre SA reference mastering chain with offline unit tests; **Pass 2 (`M82.3`–`M82.4`)** upgrades Cloudflare Worker voice hydration, Tier-B mastering URL safety, MMO v2.0 provenance, Flutter Track Detail LUFS/MiniMax badges, Worker deployment, and `SLEEP` memory consolidation.

---

## 1. Master Milestone Roadmap

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ PASS 1 — PYTHON GPU POST-PROCESSING CHAIN (`tools/zr-studio-gpu/`)           │
│  M82.1: 44.1/48kHz Resampler, BS-RoFormer Isolation & Neural Seed-VC         │
│         [T82.1.1 -> T82.1.3]                                                 │
│  M82.2: Matchering 2.0 SA Reference Mastering, handler.py, Docker & Tests    │
│         [T82.2.1 -> T82.2.3]                                                 │
├──────────────────────────────────────────────────────────────────────────────┤
│ PASS 2 — WORKER WIRE, FLUTTER PROVENANCE BADGES, DEPLOY & MEMORY SLEEP       │
│  M82.3: Cold-Isolate Voice Hydration, Safe /master, MMO Provenance & Tests   │
│         [T82.3.1 -> T82.3.3]                                                 │
│  M82.4: Flutter Track Detail LUFS/MiniMax Badges, Worker Deploy & SLEEP      │
│         [T82.4.1 -> T82.4.3]                                                 │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Pass 1 — Milestone `M82.1`: `44.1/48 kHz` Resampler, `BS-RoFormer` & Neural `Seed-VC`

- [x] **`T82.1.1` — Configurable `44.1 / 48 kHz` Upsampler (`REQ-P82-UPSAMPLE-01`)**
  - **Target:** `tools/zr-studio-gpu/model_router.py`
  - **Scope:** Add `normalize_wav_to_sr(wav_path, target_sr=44100)` supporting `44100` and `48000` Hz stereo `PCM_24` via `soxr` / `scipy.signal.resample_poly` / NumPy fallback; keep `normalize_wav_to_44k1` delegating cleanly.
  - **Acceptance:** Resampling a `32 kHz` 0.5s WAV yields `22050` frames at `44100` Hz and `24000` frames at `48000` Hz.

- [x] **`T82.1.2` — Surgical `BS-RoFormer` Lead-Vocal Isolation (`REQ-P82-STEM-01`)**
  - **Target:** `tools/zr-studio-gpu/mmo_extractor.py`
  - **Scope:** Add `resolve_roformer_cache_dir()` (`/runpod-volume/roformer_cache`) and `separate_lead_vocal_bs_roformer(input_wav_path, output_dir)` using `audio-separator` when installed and phase-complementary mid-band vocal separation fallback offline (so `lead + bed == mix`).
  - **Acceptance:** Returns valid `lead_vocals_path` and `instrumental_bed_path` while preserving `separate_stems_with_demucs` 4-stem export intact.

- [x] **`T82.1.3` — Neural `Seed-VC`, Bantu Transient Protection, De-Esser & Stereo Room Glue (`REQ-P82-SVC-01..02`)**
  - **Target:** `tools/zr-studio-gpu/seed_vc_worker.py`
  - **Scope:** Replace scalar gain/diff stub with 3-tier neural `Seed-VC` + RMVPE F0 pipeline (`_run_neural_seed_vc` GPU path + `_apply_spectral_timbre_transfer` decoding real `temp_ref_path` WAV offline), `preserve_bantu_consonant_transients` ($2.8\text{ kHz}$ $10\text{ ms}$ onset mask), `polish_converted_vocal_stem` (`6.5 kHz` de-ess + `12 ms` `-18 dB` Haas stereo glue), and `read_wav_float32`/`write_wav_float32` I/O.
  - **Acceptance:** `wrote_output_file == True`, `reference_decoded == True`, `similarity_score > 0`, and `bantu_transients_preserved == True` offline without extra pip installs.

---

## 3. Pass 1 — Milestone `M82.2`: `Matchering 2.0` SA Reference Mastering, `handler.py` & Unified Docker

- [x] **`T82.2.1` — 6-Genre SA Reference Registry & `Matchering 2.0` Engine (`REQ-P82-MASTER-01`)**
  - **Target:** `tools/zr-studio-gpu/stem_mastering_worker.py`
  - **Scope:** Add `SA_REFERENCE_MASTER_PROFILES`, `resolve_sa_reference_profile_id(genre)`, `resolve_sa_reference_wav(profile_id, sr)`, and `master_with_sa_reference_matchering(...)` (`Matchering 2.0` + `pyloudnorm` + soft-knee `-1.0 dBTP` ceiling for `-14.0 LUFS` streaming vs. `-9.0 LUFS` club).
  - **Acceptance:** Output true peak `<= -1.0 dBTP`, streaming target `-14.0 LUFS` and club target `-9.0 LUFS` accurately reflected in `mastering_metrics`.

- [x] **`T82.2.2` — Wire `BS-RoFormer` + `Seed-VC` + `Matchering 2.0` in `handler.py` & Docker (`REQ-P82-MASTER-02`, `INFRA-P82-01`)**
  - **Targets:** `tools/zr-studio-gpu/handler.py`, `tools/zr-studio-gpu/Dockerfile`, `tools/zr-studio-gpu/Dockerfile.delta`, `tools/zr-studio-gpu/requirements.txt`, `tools/zr-studio-gpu/README.md`
  - **Scope:** Run `BS-RoFormer` lead isolation before `Seed-VC` (summing converted lead + `instrumental_bed`), apply `master_with_sa_reference_matchering` by default across winning & secondary takes, stamp `mastering_metrics`, `svc_metrics`, and `sample_rate_hz` onto MMO manifest & webhook payloads, and add `matchering>=2.0.6` + `audio-separator>=0.24.0` + `/runpod-volume/{roformer,seed_vc,ref_masters}` env vars in Docker manifests.
  - **Acceptance:** `python -m py_compile tools/zr-studio-gpu/*.py` passes with zero errors; zero `YuE2` references.

- [x] **`T82.2.3` — Python Phase 82 Test Suite (`G82-01`, `G82-02`)**
  - **Target:** `tools/zr-studio-gpu/test_phase82_vocal_mastering.py` (new)
  - **Scope:** Unit and E2E `handler.py` tests covering `32k -> 44.1k / 48k` upsampling, `BS-RoFormer` lead+bed reconstruction, `Seed-VC` reference WAV spectral transfer + Bantu click retention + `6.5 kHz` de-ess/glue, `Matchering 2.0` 6-genre streaming (`-14.0 LUFS`) vs. club (`-9.0 LUFS`) mastering, and truthful `mastering_metrics` + `svc_metrics` emission.
  - **Acceptance:** `python -u -m unittest discover -s tools/zr-studio-gpu -p "test_*.py" -v` passes 100% (both Phase 81 & Phase 82 suites).

---

## 4. Pass 2 — Milestone `M82.3`: Worker Voice Hydration, Safe Tier-B Mastering & MMO v2.0 Provenance

- [x] **`T82.3.1` — `mastering_types.ts`, `mastering_presets.ts` & `dna_types.ts` Upgrades (`REQ-P82-WIRE-01..02`)**
  - **Targets:** `apps/vhunambi_api/src/modules/mastering/mastering_types.ts`, `apps/vhunambi_api/src/modules/mastering/mastering_presets.ts`, `apps/vhunambi_api/src/modules/dna/dna_types.ts`, `apps/vhunambi_api/src/modules/jobs/job_types.ts`
  - **Scope:** Expand `targetLufs` Zod union to `[-9.0, -9.5, -14.0]`; preserve live `https://`/`/r2/` URLs in `enrichManifestWithMasteringRecipe` (keeping `/mock-storage/...` only for mock/seeded tracks so `mastering.test.ts` stays 100% green!); add typed `masteringMetrics` and `svcMetrics` to `MasterMediaObjectManifest` and `GenerationJob`.
  - **Acceptance:** `test/mastering.test.ts` passes unchanged.

- [x] **`T82.3.2` — Cold-Isolate Voice Hydration, RunPod Mastering Params & Enriched Alerts (`REQ-P82-WIRE-01..02`)**
  - **Targets:** `apps/vhunambi_api/src/routes/generation_routes.ts`, `apps/vhunambi_api/src/modules/synthesis/prompt_compiler.ts`, `apps/vhunambi_api/src/modules/synthesis/runpod_adapter.ts`, `apps/vhunambi_api/src/routes/webhook_routes.ts`, `apps/vhunambi_api/src/modules/jobs/job_store.ts`
  - **Scope:** Await `vhunambiDb.syncVoicesFromCloud(false, c)` on cold Edge isolates before `getVoiceCloneProfile`; accept & forward `masteringMode` (`streaming`|`club`) and `sampleRateHz` (`44100`|`48000`); persist `masteringMetrics`/`svcMetrics` from webhooks & polling; enrich `notifyGenerationCompletedOnce` with measured LUFS.
  - **Acceptance:** Cold simulated Edge isolate resolves saved voice clone `r2ReferenceUrl` and persists `masteringMetrics` onto `/v1/generations/:id` and `/manifest`.

- [x] **`T82.3.3` — Worker Phase 82 Test Suite (`G82-03`)**
  - **Targets:** `apps/vhunambi_api/test/phase82_vocal_mastering_provenance.test.ts` (new), `apps/vhunambi_api/package.json`
  - **Scope:** Test `-9.0` Club & `-14.0` Streaming schema validation, live R2 URL preservation on `POST /v1/generations/:id/master`, cold-isolate `syncVoicesFromCloud` clone lookup, RunPod `/run` `mastering_mode`/`target_sample_rate` forwarding, webhook `mastering_metrics` + `svc_metrics` persistence, and enriched LUFS Ready notification. Register in `package.json`.
  - **Acceptance:** `cd apps/vhunambi_api && .\node_modules\.bin\tsc.cmd --noEmit && npm test` passes `100%` (`35/35` suites).

---

## 5. Pass 2 — Milestone `M82.4`: Flutter Track Detail Provenance Badges, Worker Deploy & `SLEEP`

- [x] **`T82.4.1` — `TrackDetailEntity`, `'melodic'` Stem Fix & Provenance Chips (`REQ-P82-CLIENT-01`)**
  - **Targets:** `apps/vhunambi_client/lib/features/track/domain/models/track_detail_models.dart`, `apps/vhunambi_client/lib/features/track/presentation/providers/track_providers.dart`, `apps/vhunambi_client/lib/features/track/presentation/widgets/track_sonic_telemetry_card.dart`
  - **Scope:** Add `integratedLufs`, `masteringProfile`, `attributionTag`, `sampleRateHz`, and `voiceCloneApplied` to `TrackDetailEntity`; hydrate them and `'melodic'` stem inside `loadManifestFromCloud`; render `track_mastering_provenance_chip`, `track_engine_attribution_chip`, and `track_voice_clone_chip` (`PhosphorIcon` + Light/Dark tokens).
  - **Acceptance:** Zero stock `Icons.*`, zero raw emojis (`STD-UIUX-001`), zero overflow at `360x800`.

- [x] **`T82.4.2` — Flutter Phase 82 Track Provenance Widget Test (`G82-04`)**
  - **Target:** `apps/vhunambi_client/test/features/track/phase82_track_provenance_test.dart` (new)
  - **Scope:** Verify `loadManifestFromCloud` hydrates `melodic` stem + `integratedLufs` + `attributionTag` + `voiceCloneApplied` from `/manifest` JSON, and `TrackSonicTelemetryCard` renders `"Mastered · -14.0 LUFS"`, `"MiniMax-Music3"`, and `"Seed-VC Voice"` in Light & Dark modes at `360x800`.
  - **Acceptance:** `flutter test --no-pub --timeout=60s test/features/track/phase82_track_provenance_test.dart` passes `100%`.

- [x] **`T82.4.3` — Deploy Cloudflare Worker, Finalize `memory.md` & Run `consolidate_memory.mjs` (`G82-05`, `G82-06`)**
  - **Targets:** `docs/phases/phase_82_vocal_cloning_and_broadcast_mastering/memory.md`, `docs/phases/PHASE_80_PLUS_STUDIO_AND_RUNPOD_MASTER_TRACKER.md`, `docs/memory/*`
  - **Scope:** Deploy updated `vhunambi-api` via `.\node_modules\.bin\wrangler deploy`, verify live `/health`, promote `memory.md` to `"completed"`, update Master Tracker, and run `node .agents/skills/vhunambi-memory/scripts/consolidate_memory.mjs`.

---

## 6. Stage 4 Anti-Trap Checklist & Verification Commands

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ STAGE 4 EXECUTION INVARIANTS (/vhunambi-executioner)                         │
│  [x] Preserve `/mock-storage/..._mastered.mp3` for mock tracks (mastering.test)│
│  [x] Keep live R2 `https://`/`/r2/` URLs intact on POST /generations/:id/master│
│  [x] Accept `-9.0`, `-9.5`, and `-14.0` in StemMasteringRecipeSchema         │
│  [x] Zero GPL code/packages in `apps/vhunambi_client/` (server-side RunPod)  │
│  [x] `loadManifestFromCloud` checks `instrumental` -> `melodic` -> `other`   │
│  [x] Fast CPU offline fallbacks in Python (`< 15s`, `0 MB` local pip install)│
│  [x] Direct `.\node_modules\.bin\tsc.cmd` & `wrangler` (never `npx` on Win)  │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Exact Verification Gate Commands
```powershell
# Gate G82-01 & G82-02: Python Bytecode & Phase 81+82 GPU DSP Suites
python -u -m py_compile tools/zr-studio-gpu/model_router.py tools/zr-studio-gpu/model_utils.py tools/zr-studio-gpu/mmo_extractor.py tools/zr-studio-gpu/seed_vc_worker.py tools/zr-studio-gpu/stem_mastering_worker.py tools/zr-studio-gpu/handler.py
python -u -m unittest discover -s tools/zr-studio-gpu -p "test_*.py" -v

# Gate G82-03: Cloudflare Worker TypeScript & All 35 API Suites
cd apps/vhunambi_api; .\node_modules\.bin\tsc.cmd --noEmit && npm test

# Gate G82-04: Flutter Track Provenance & Regression
cd apps/vhunambi_client; flutter test --no-pub --timeout=60s test/features/track/phase82_track_provenance_test.dart

# Gate G82-06: Codebase Brain Sleep Consolidation
node .agents/skills/vhunambi-memory/scripts/consolidate_memory.mjs
```

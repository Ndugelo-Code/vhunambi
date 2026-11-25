# Phase 85 Implementation Task Plan — Cloud-Only Zero-Local-RAM LoRA Factory

> **Spec Suite ID:** `SPEC-P85-CLOUD-LORA-FACTORY`  
> **Companion Documents:** [`blueprint.md`](./blueprint.md) · [`requirements.md`](./requirements.md) · [`design.md`](./design.md) · [`memory.md`](./memory.md)  
> **Execution Mode:** Stage 4 Two-Pass Implementation (`/vhunambi-executioner`: Pass 1 = SQL + Worker Edge Orchestrator + Python Cloud Prepper/PEFT Trainer/Loader; Pass 2 = Flutter Factory UI + Full Verification + Cloud Deploy + Memory SLEEP)

---

## §1. Master Milestone Roadmap & Dependency Graph

```text
+---------------------------------------------------------------------------------------------------+
|                             PHASE 85 EXECUTION ROADMAP (M1 -> M6)                                 |
+---------------------------------------------------------------------------------------------------+
|                                                                                                   |
|  [PASS 1: SUPABASE REGISTRY, WORKER ORCHESTRATION & CLOUD PYTHON PEFT FACTORY]                    |
|   M1: Additive Supabase Migration (lora_registry, lora_dataset_tracks, lora_training_jobs)        |
|    |  + Pure Edge Zod Dataset Schema & 10+1 Catalog (bantu_vocals_v1, P83 backward-compat)        |
|    v                                                                                              |
|   M2: Worker Dual-Engine Persistence, RunPod Training Dispatch, Factory Routes & Signed Webhook   |
|    |  (studio_routes.ts, webhook_routes.ts, runpod_adapter.ts, edge_persistence_bridge/vhunambi)  |
|    v                                                                                              |
|   M3: Cloud Python Validator, RunPod Dataset Prepper & Real ACE-Step 1.5 bf16 PEFT Trainer        |
|    |  (tools/zr-studio-training/{validate_dataset,dataset_prep_worker,train_lora}.py + configs/)  |
|    v                                                                                              |
|   M4: Dual-Path Truthful LoRA Loader, Handler Dispatch & Zero-Local-Docker GitHub CI Packaging    |
|    |  (tools/zr-studio-gpu/{model_utils,handler}.py, Dockerfile.delta, push_gpu_worker.yml)       |
|    |                                                                                              |
|  [PASS 2: FLUTTER LIVE REGISTRY UI, REGRESSION SUITES, CLOUD DEPLOY & MEMORY CONSOLIDATION]       |
|    v                                                                                              |
|   M5: Flutter Live LoRA Registry Notifier, LoraFactoryStatusSheet & Repaint Picker Status Pills   |
|    |  (studio_form_state.dart, studio_lora_registry_provider.dart, lora_factory_status_sheet.dart)|
|    v                                                                                              |
|   M6: Python + API + Flutter Verification Suites, Live Supabase/Worker Deploy & Memory SLEEP      |
|                                                                                                   |
+---------------------------------------------------------------------------------------------------+
```

| Milestone | Scope | Primary Files | Gate |
| :---: | :--- | :--- | :---: |
| **`M1`** | Supabase Migration + Edge Dataset Schema + 10+1 Catalog | `20261125000002_phase85_cloud_lora_factory.sql`, `training_dataset_schema.ts`, `lora_catalog.ts` | `G-01`, `G-03` |
| **`M2`** | Dual-Engine DB + RunPod Dispatch + Studio Factory & Training Webhook Routes | `edge_persistence_bridge.ts`, `vhunambi_db.ts`, `runpod_adapter.ts`, `studio_routes.ts`, `webhook_routes.ts` | `G-03` |
| **`M3`** | Cloud Python Dataset Validator, Prepper & Real PyTorch `bf16` PEFT Trainer | `tools/zr-studio-training/{__init__,validate_dataset,dataset_prep_worker,train_lora}.py`, `configs/*.yaml` | `G-02` |
| **`M4`** | Dual-Path PEFT Loader, `handler.py` Routing & GitHub CI Docker Delta | `tools/zr-studio-gpu/{model_utils,handler}.py`, `Dockerfile.delta`, `.github/workflows/push_gpu_worker.yml` | `G-02`, `G-05` |
| **`M5`** | Flutter Live LoRA Status Provider, Factory Sheet & Repaint Status Badges | `studio_form_state.dart`, `studio_lora_registry_provider.dart`, `lora_factory_status_sheet.dart`, `track_section_repaint_sheet.dart` | `G-04` |
| **`M6`** | Full Python/TS/Flutter Test Suites, Live Deploy, Tracker & Memory SLEEP | `test_phase85_lora_factory.py`, `phase85_lora_factory.test.ts`, `phase85_lora_factory_ui_test.dart`, `memory.md` | `G-01..G-06` |

---

## §2. Milestone M1 — Supabase Schema, Edge Dataset Contract & 10+1 Catalog

- [x] **Task 1.1 — Author Additive Supabase Migration for LoRA Factory**
  - **Target File:** `supabase/migrations/20261125000002_phase85_cloud_lora_factory.sql`
  - **Contract:** Create `public.lora_registry`, `public.lora_dataset_tracks`, and `public.lora_training_jobs` with `IF NOT EXISTS`, indexes, RLS enabled + explicit `SELECT` policies, and idempotent seed of all 11 canonical packs (`10` genre + `bantu_vocals_v1`).
  - **Acceptance Criteria:** Zero RLS advisor issues; applies cleanly via `supabase_mcp:apply_migration`.

- [x] **Task 1.2 — Implement Pure Edge Training Dataset Schema & Source Track Selector**
  - **Target File:** `apps/vhunambi_api/src/modules/synthesis/training_dataset_schema.ts`
  - **Exports:** `VhunambiLoraIdSchema`, `TrainingGenreSchema`, `BantuLanguageSchema`, `AudioSpecSchema`, `MusicalKeySchema`, `TrainingTrackMetadataSchema`, `LoraRegistryStatusSchema`, `getTrainingHyperparamDefaults`, `extractR2KeyFromAudioUrl`, `selectSourceTracksForLoraPack`.
  - **Acceptance Criteria:** Zero React/Next/D1/Node-fs imports; maps Phase 84 Zania tracks cleanly onto all 11 packs.

- [x] **Task 1.3 — Extend `lora_catalog.ts` with `LANGUAGE_LORA_PACKS` (`bantu_vocals_v1`)**
  - **Target File:** `apps/vhunambi_api/src/modules/synthesis/lora_catalog.ts`
  - **Acceptance Criteria:** `AFRICAN_LORA_PACKS.length` remains strictly `10` (preserving `phase83_repaint_lora_routes.test.ts:26-28`); `LANGUAGE_LORA_PACKS` exports `bantu_vocals_v1`; `findLoraPackById('bantu_vocals_v1')` resolves cleanly.

---

## §3. Milestone M2 — Worker Persistence, RunPod Dispatch & Signed Training Webhook

- [x] **Task 2.1 — Add LoRA Registry, Dataset Tracks & Training Jobs Persistence Across Dual DB Engines**
  - **Target Files:** `apps/vhunambi_api/src/db/edge_persistence_bridge.ts`, `apps/vhunambi_api/src/db/vhunambi_db.ts`
  - **Methods:** `listLoraRegistryAsync`, `getLoraRegistryEntry`, `upsertLoraRegistryAsync`, `listLoraDatasetTracksAsync`, `upsertLoraDatasetTracksAsync`, `listLoraTrainingJobsAsync`, `getLoraTrainingJobAsync`, `upsertLoraTrainingJobAsync`.
  - **Acceptance Criteria:** All async writers call `awaitWriteThrough`; SQLite schema initializes all 3 tables cleanly in Node test runs.

- [x] **Task 2.2 — Add Cloud Dataset Prep & PEFT Training Dispatchers to `runpod_adapter.ts`**
  - **Target File:** `apps/vhunambi_api/src/modules/synthesis/runpod_adapter.ts`
  - **Exports:** `dispatchLoraDatasetPrepJob`, `dispatchLoraPeftTrainingJob`.
  - **Acceptance Criteria:** Targets `${WEBHOOK_BASE_URL}/v1/webhooks/training`; supports both `serverless` RunPod `/v2/{id}/run` and `pod` CLI launch payload generation.

- [x] **Task 2.3 — Upgrade `studio_routes.ts` with Factory Readiness & Trigger Routes**
  - **Target File:** `apps/vhunambi_api/src/routes/studio_routes.ts`
  - **Routes:** Enriched `GET /v1/studio/loras` (`totalCount === 10` + `languagePacks[]` + live registry fields), `GET /v1/studio/loras/factory`, `POST /v1/studio/loras/datasets/prep`, `POST /v1/studio/loras/train`, `GET /v1/studio/loras/jobs`, `GET /v1/studio/loras/jobs/:jobId`.
  - **Acceptance Criteria:** Authenticated POST endpoints enforce `< 8` track guards (`400 INSUFFICIENT_SOURCE_TRACKS` / `400 DATASET_NOT_READY`) and return `202` on dispatch.

- [x] **Task 2.4 — Add Constant-Time HMAC-SHA256 `POST /v1/webhooks/training`**
  - **Target File:** `apps/vhunambi_api/src/routes/webhook_routes.ts`
  - **Acceptance Criteria:** Verifies `x-zrs-signature` with `crypto.timingSafeEqual` (`401` on mismatch), rejects `completed` callbacks lacking `artifact_bytes > 64` or 64-hex `artifact_sha256` (`422`), promotes `lora_registry.status = 'active'` on valid completion, and preserves previously active packs if a retrain fails.

---

## §4. Milestone M3 — Cloud Python Dataset Validator, Prepper & Real PEFT Trainer

- [x] **Task 3.1 — Port Pure Python Dataset Validator (`validate_dataset.py`)**
  - **Target Files:** `tools/zr-studio-training/__init__.py`, `tools/zr-studio-training/validate_dataset.py`
  - **Acceptance Criteria:** Enforces 44.1/48 kHz, 16/24-bit, mono/stereo WAV, 30–300s duration, required JSON sidecar fields, `MIN_TRACKS = 8`, and all 11 Vhunambi LoRA IDs with zero raw Unicode emojis in logs/JSON.

- [x] **Task 3.2 — Implement Cloud RunPod Dataset Prepper (`dataset_prep_worker.py`)**
  - **Target File:** `tools/zr-studio-training/dataset_prep_worker.py`
  - **Acceptance Criteria:** Downloads R2 source MP3s (or local test audio), transcodes to 44.1 kHz 24-bit stereo WAV, optionally runs Phase 82 `separate_lead_vocal_bs_roformer()` for `bantu_vocals_v1`, extracts BPM + Krumhansl-Schmuckler musical key + duration, preserves NFC Tshivenḓa lyrics, validates with `validate_dataset()`, uploads curated pairs to R2 `training-data/curated/{lora_id}/`, and fires signed `dataset_ready` webhook.

- [x] **Task 3.3 — Implement Real PyTorch `bf16` PEFT ACE-Step Trainer (`train_lora.py`) & YAML Configs**
  - **Target Files:** `tools/zr-studio-training/train_lora.py`, `tools/zr-studio-training/configs/{amapiano_logdrum_v1,amapiano_private_school_v1,afrobeats_lagos_v1,afrohouse_ancestral_v1,bantu_vocals_v1,default_genre_template}.yaml`
  - **Acceptance Criteria:** Zero mock safetensors bytes; dynamically discovers DiT target linear modules; caches VAE latents; runs real rectified flow-matching MSE loss + AdamW + cosine decay + grad clipping; asserts finite tensors & `> 64 bytes` + SHA-256; writes `.safetensors` with embedded PEFT `__metadata__` + `adapter_config.json`; supports both Serverless (`run_cloud_peft_training`) and Pod CLI (`--resume-from-r2`).

---

## §5. Milestone M4 — Dual-Path Loader, Handler Dispatch & Cloud CI Packaging

- [x] **Task 4.1 — Harden `model_utils.py` with `bantu_vocals_v1` & Dual-Path PEFT Loader**
  - **Target File:** `tools/zr-studio-gpu/model_utils.py`
  - **Acceptance Criteria:** Adds `"bantu vocals"` / `"bantu_vocals"` to `GENRE_LORA_REGISTRY`; adds `materialize_peft_dir_from_safetensors()` reconstructing `adapter_config.json` + `adapter_model.safetensors` from `.safetensors` `__metadata__` if single-file `load_lora()` fails; maintains strict SHA-256 & `> 64B` truthful loading.

- [x] **Task 4.2 — Route `lora_dataset_prep` & `lora_train_peft` in `handler.py`**
  - **Target File:** `tools/zr-studio-gpu/handler.py`
  - **Acceptance Criteria:** Early-dispatches `job_type in ("lora_dataset_prep", "lora_train_peft")` cleanly to `training.*` before synthesis routing, reusing `send_webhook` HMAC signing.

- [x] **Task 4.3 — Update Cloud Docker Delta & GitHub Actions Workflow (Zero Local Docker)**
  - **Target Files:** `tools/zr-studio-gpu/Dockerfile.delta`, `.github/workflows/push_gpu_worker.yml`
  - **Acceptance Criteria:** Build context set to `./tools` so `Dockerfile.delta` copies both `zr-studio-gpu/*.py` and `zr-studio-training/` cleanly, installs `peft>=0.13.0`, `safetensors>=0.4.5`, `pyyaml>=6.0.1`, and `py_compile`s every Python module.

---

## §6. Milestone M5 — Flutter Live LoRA Registry UI & Factory Sheet

- [x] **Task 5.1 — Extend `AfricanLoraPackOption` & Create `StudioLoraRegistryNotifier`**
  - **Target Files:** `apps/vhunambi_client/lib/features/studio/domain/models/studio_form_state.dart`, `apps/vhunambi_client/lib/features/studio/presentation/providers/studio_lora_registry_provider.dart`
  - **Acceptance Criteria:** Additive optional registry status fields (`registryStatus`, `readyTrackCount`, `curatedTrackCount`, `minTracks`, `artifactSha256`) + `kBantuVocalsLoraPack` + `kAllSovereignLoraPacks`; offline-safe `refreshFactory()`, `triggerDatasetPrep()`, `triggerCloudTraining()`.

- [x] **Task 5.2 — Implement `LoraFactoryStatusSheet` & Status Pills in `TrackSectionRepaintSheet`**
  - **Target Files:** `apps/vhunambi_client/lib/features/studio/presentation/widgets/lora_factory_status_sheet.dart`, `apps/vhunambi_client/lib/features/track/presentation/widgets/track_section_repaint_sheet.dart`
  - **Acceptance Criteria:** Strict `STD-UIUX-001` compliance (`PhosphorIcon`, `AppColors.*Of(context)`, `AppTypography.*`, `>= 44dp` buttons, `0` `Icons.*`, `0` raw Unicode emojis); explicit test keys `lora_factory_status_sheet`, `lora_factory_filter_*`, `lora_prep_btn_*`, `lora_train_btn_*`, `repaint_open_lora_factory_btn`.

---

## §7. Milestone M6 — Verification Suites, Live Cloud Deploy & Memory Consolidation

- [x] **Task 6.1 — Author Python, API & Flutter Phase 85 Test Suites**
  - **Target Files:**
    - `tools/zr-studio-training/tests/test_phase85_lora_factory.py` (CPU `< 15s`, real PyTorch PEFT + `safetensors` write/read + dual-path `model_utils.py` load + `validate_dataset` + `dataset_prep_worker`)
    - `apps/vhunambi_api/test/phase85_lora_factory.test.ts` (added to `apps/vhunambi_api/package.json` `scripts.test`!)
    - `apps/vhunambi_client/test/features/studio/phase85_lora_factory_ui_test.dart` (`--timeout=60s`, Dark & Light theme, all keys & actions)

- [x] **Task 6.2 — Apply Supabase Migration, Deploy Cloudflare Worker, Update Tracker & Run SLEEP Consolidation**
  - **Acceptance Criteria:** Apply `20261125000002_phase85_cloud_lora_factory.sql` to `cbnruevwrqwjnnoscgsz`, deploy `vhunambi-api`, verify live `GET /v1/studio/loras/factory` reports `186` Zania tracks & `4–5` packs ready, add `P85` DONE row to `PHASE_80_PLUS_STUDIO_AND_RUNPOD_MASTER_TRACKER.md`, finalize `memory.md` `"status": "completed"`, and execute `consolidate_memory.mjs`.

---

## §8. Stage 4 Anti-Trap & Execution Verification Checklist

- [x] **Anti-Trap 1 (Zero Mock Safetensors):** `train_lora.py` executes a genuine PyTorch gradient step and writes real `safetensors` weights (`> 64 bytes`, finite values, SHA-256 verified) — zero `MOCK_SAFETENSORS_DATA`.
- [x] **Anti-Trap 2 (Phase 83 `totalCount === 10` Guard):** `AFRICAN_LORA_PACKS` remains 10 genre packs; `bantu_vocals_v1` lives in `LANGUAGE_LORA_PACKS` / `languagePacks[]` so `phase83_repaint_lora_routes.test.ts:26-28` passes untouched.
- [x] **Anti-Trap 3 (Docker Build Context Guard):** `.github/workflows/push_gpu_worker.yml` uses `context: ./tools` so `Dockerfile.delta` can legally copy both `zr-studio-gpu/` and `zr-studio-training/`.
- [x] **Anti-Trap 4 (Dual-Path PEFT Loader):** `_hot_swap_loras()` in `model_utils.py` reconstructs a local PEFT directory from `.safetensors` `__metadata__` whenever single-file `load_lora()` fails.
- [x] **Anti-Trap 5 (Zero Local RAM / Fast CPU Tests):** All Python tests run on CPU in `< 15s` using tiny synthetic `nn.Module` DiT proxies (no multi-GB checkpoint downloads on the 8 GB RAM workstation).
- [x] **Anti-Trap 6 (`STD-UIUX-001` & Authentic Tokens):** All Dart files use `package:vhunambi_client/...`, `package:phosphor_icons/phosphor_icons.dart`, valid `AppColors.*Of(context)` / `AppTypography.*`, `>= 44dp` touch targets, `0` stock `Icons.*`, and `0` raw Unicode emojis.
- [x] **Anti-Trap 7 (Durable Write-Through & Bounded Tests):** All Worker DB mutations await `awaitWriteThrough`; all Flutter widget tests avoid unbounded `pumpAndSettle()` and pass under `--timeout=60s`.

---

## §9. Exact Verification Gate Commands (PowerShell — Windows Safe)

```powershell
# 1. Python Cloud Prepper, Validator, Real PEFT Trainer & Dual-Path Loader Tests (CPU <15s)
python -m unittest discover -s tools/zr-studio-gpu -p "test_phase8*.py"
python -m unittest discover -s tools/zr-studio-training/tests -p "test_*.py"

# 2. Backend Typecheck & Full Test Suite (includes Phase 83 totalCount===10 + Phase 85)
cd apps\vhunambi_api
.\node_modules\.bin\tsc.cmd --noEmit
npm test

# 3. Flutter Static Analysis & Targeted + Regression Widget Tests (Standalone on 8GB RAM!)
cd ..\vhunambi_client
dart analyze lib/features/studio/domain/models/studio_form_state.dart lib/features/studio/presentation/providers/studio_lora_registry_provider.dart lib/features/studio/presentation/widgets/lora_factory_status_sheet.dart lib/features/track/presentation/widgets/track_section_repaint_sheet.dart test/features/studio/phase85_lora_factory_ui_test.dart
flutter test test/features/studio/phase85_lora_factory_ui_test.dart test/features/track/phase83_repaint_lora_ui_test.dart --no-pub --timeout=60s

# 4. Stage 4 SLEEP Consolidation (ONLY after G-01..G-06 pass & memory.md status="completed")
cd ..\..
node .agents/skills/vhunambi-memory/scripts/consolidate_memory.mjs
```

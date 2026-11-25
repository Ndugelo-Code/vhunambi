# Phase 85 Requirements Specification — Cloud-Only Zero-Local-RAM LoRA Factory

> **Spec Suite ID:** `SPEC-P85-CLOUD-LORA-FACTORY`  
> **Companion Documents:** [`blueprint.md`](./blueprint.md) · [`design.md`](./design.md) · [`tasks.md`](./tasks.md) · [`memory.md`](./memory.md)

---

## §1. Document Scope, EARS & RFC-2119 Conventions

This document defines the verifiable functional and non-functional requirements for **Phase 85: Cloud-Only Zero-Local-RAM LoRA Factory**.
- **RFC-2119 Keywords:** `SHALL` / `MUST` denote mandatory requirements; `SHOULD` denotes strong recommendations; `MAY` denotes optional extensions.
- **EARS Patterns:** Requirements follow `WHEN <trigger>`, `WHILE <state>`, `IF <condition> THEN <response>`, and `WHERE <feature>` clauses.
- **Zero-Mock Rule (`NO-MOCK-LORA`):** Any `.safetensors` artifact written to Cloudflare R2 under `loras/*.safetensors` MUST be produced by a genuine PyTorch PEFT LoRA optimization loop with valid safetensors binary header, finite floating-point tensors, size `> 64 bytes`, and cryptographic SHA-256 verification. Writing placeholder bytes (such as Donor's `b"MOCK_SAFETENSORS_DATA"`) is strictly forbidden.

---

## §2. Supabase Database & Schema Requirements (`REQ-P85-DB-*`)

- **`REQ-P85-DB-01` (Additive LoRA Registry Table):** The system SHALL create `public.lora_registry` via idempotent migration `supabase/migrations/20261125000002_phase85_cloud_lora_factory.sql` storing `lora_id TEXT PRIMARY KEY`, `display_name`, `pack_type` (`'genre' | 'language'`), `genre`, `region`, `r2_key`, `adapter_config_r2_key`, `default_weight`, `lora_rank`, `lora_alpha`, `min_tracks` (default `8`), `recommended_tracks` (default `15`), `status` (`'untrained' | 'preparing' | 'ready_to_train' | 'queued' | 'training' | 'validating' | 'active' | 'failed'`), `artifact_sha256`, `artifact_bytes`, `training_tracks`, `version`, `final_loss`, `trained_at`, `metadata_json`, and timestamps, pre-seeded idempotently with all `11` canonical Vhunambi packs (`10` genre + `bantu_vocals_v1`).
- **`REQ-P85-DB-02` (Curated Dataset Track Manifest Table):** The system SHALL create `public.lora_dataset_tracks` tracking each prepared training track per `lora_id` (`id`, `lora_id` FK -> `lora_registry`, `source_track_id`, `source_r2_key`, `source_sha256`, `curated_wav_r2_key`, `curated_json_r2_key`, `vocal_isolated BOOLEAN`, `duration_sec`, `sample_rate`, `bit_depth`, `bpm`, `musical_key`, `language`, `license`, `validation_status` `'valid' | 'invalid' | 'excluded'`, `validation_errors_json`, `training_weight`), with unique constraint `(lora_id, source_sha256)` so re-running prep never duplicates tracks.
- **`REQ-P85-DB-03` (Training & Prep Job Ledger Table):** The system SHALL create `public.lora_training_jobs` recording asynchronous RunPod dataset-prep and PEFT training runs (`id`, `lora_id`, `job_type` `'dataset_prep' | 'peft_train'`, `runpod_job_id`, `status`, `progress_pct`, `current_epoch`, `total_epochs`, `current_loss`, `best_loss`, `hyperparams_json`, `metrics_json`, `artifact_r2_key`, `artifact_sha256`, `error_message`, `triggered_by`, `created_at`, `updated_at`, `completed_at`).
- **`REQ-P85-DB-04` (RLS & Security Hygiene):** All three tables SHALL have `ROW LEVEL SECURITY` enabled with public/authenticated `SELECT` on `public.lora_registry` and explicit owner/admin policies so Supabase security advisors report `0` `rls_enabled_no_policy` errors.

---

## §3. Pure Edge Dataset Schema & Catalog Requirements (`REQ-P85-SCHEMA-*`)

- **`REQ-P85-SCHEMA-01` (Pure Zod Dataset Contract):** `apps/vhunambi_api/src/modules/synthesis/training_dataset_schema.ts` SHALL port Donor `training-dataset.ts` schemas (`TrainingGenreSchema`, `BantuLanguageSchema`, `AudioSpecSchema`, `MusicalKeySchema`, `TrainingTrackMetadataSchema`, `DatasetManifestSchema`, `LoraRegistryStatusSchema`, `getTrainingDefaults`) with zero React/Next.js/D1 imports, aligned to all 11 Vhunambi LoRA pack IDs (`amapiano_logdrum_v1`, `amapiano_private_school_v1`, `sgija_bacardi_v1`, `gqom_durban_v1`, `maskandi_picking_v1`, `venda_malende_v1`, `afrobeats_lagos_v1`, `kwaito_township_v1`, `afro_gospel_choir_v1`, `afrohouse_ancestral_v1`, `bantu_vocals_v1`).
- **`REQ-P85-SCHEMA-02` (Phase 83 Backward-Compatible 10 + 1 Catalog):** `apps/vhunambi_api/src/modules/synthesis/lora_catalog.ts` SHALL preserve `AFRICAN_LORA_PACKS.length === 10` so existing `phase83_repaint_lora_routes.test.ts` assertions (`totalCount === 10`, `packs.length === 10`) remain 100% green, while exporting `LANGUAGE_LORA_PACKS` containing `bantu_vocals_v1` and resolving `bantu_vocals_v1` in `findLoraPackById()` and `normalizeRequestedLoraSpecs()`.
- **`REQ-P85-SCHEMA-03` (Genre-to-Pack Source Selector):** The backend SHALL provide a deterministic `selectSourceTracksForLoraPack(loraId, exploreTracks, mediaUploads)` mapper matching Phase 84 ingested tracks (`explore_tracks` + `user_media_uploads`) onto each of the 11 packs, guaranteeing that the live 186 Zania Music catalog immediately satisfies `>= 8` tracks for `amapiano_logdrum_v1` (`31`), `amapiano_private_school_v1` (`36`), `afrobeats_lagos_v1` (`49`), `afrohouse_ancestral_v1` (`20`), and `bantu_vocals_v1` (`118` vocal tracks).

---

## §4. Cloud Dataset Prepper & Validator Requirements (`REQ-P85-PREP-*`)

- **`REQ-P85-PREP-01` (Pure Python Dataset Validator):** `tools/zr-studio-training/validate_dataset.py` SHALL validate every curated `.wav` + `.json` pair against: WAV format, sample rate in `{44100, 48000}`, bit depth in `{16, 24}`, channels in `{1, 2}`, duration in `[30, 300]` seconds, required metadata fields (`title`, `genre`, `lora_id`, `bpm` in `[60, 200]`, `language`, `instrumentation`, `mood`, `license`), non-excluded valid active track count `>= 8` (`MIN_TRACKS = 8`), and emit structured JSON reports without relying on raw Unicode emojis for pass/fail parsing.
- **`REQ-P85-PREP-02` (Cloud RunPod Audio Preprocessor):** WHEN RunPod receives `job_type == "lora_dataset_prep"`, `tools/zr-studio-training/dataset_prep_worker.py` SHALL:
  1. Download each source audio file from Cloudflare R2 (`zr-studio-audio`) via `boto3` (or local path in unit tests), skipping files whose `(lora_id, source_sha256)` already exists in curated R2 if `force_reprep` is false.
  2. Transcode compressed MP3/M4A/FLAC into `44100 Hz`, `24-bit PCM`, `2-channel stereo WAV` (`PCM_24`), trimming silence tails and capping duration cleanly at `<= 300s` (or rejecting `< 30s`).
  3. WHERE `extract_vocals == true` (default for `bantu_vocals_v1`), invoke Phase 82 `separate_lead_vocal_bs_roformer()` to isolate clean lead vocals prior to WAV export.
  4. Extract measured BPM (via `librosa.beat.beat_track` with fallback to provided ID3/track BPM), musical key (chroma Krumhansl-Schmuckler profile), duration, and RMS energy; merge `lyrics_text` (Unicode NFC preserved for Tshivenḓa diacritics `ḓ ḽ ṋ ṱ`) and emit a schema-valid `track_XX.json` sidecar.
  5. Run `validate_dataset()` on the prepared directory, upload valid pairs + `_manifest.json` to `zr-studio-audio/training-data/curated/{lora_id}/`, and send an HMAC-SHA256 signed webhook to `POST /v1/webhooks/training`.

---

## §5. Real ACE-Step 1.5 PEFT LoRA Trainer & Loader Requirements (`REQ-P85-TRAIN-*` & `REQ-P85-LOADER-*`)

- **`REQ-P85-TRAIN-01` (Real PyTorch `bf16` PEFT LoRA Training Loop):** WHEN RunPod receives `job_type == "lora_train_peft"` (or when launched via standalone Pod CLI `python -m training.train_lora --config ...`), `tools/zr-studio-training/train_lora.py` SHALL:
  1. Download and validate the curated dataset (`>= 8` valid WAV+JSON pairs) from `zr-studio-audio/training-data/curated/{lora_id}/`.
  2. Discover and attach `peft.LoraConfig(r=rank, lora_alpha=alpha, target_modules=resolved_modules, lora_dropout=dropout, bias="none")` onto the ACE-Step DiT transformer (`ace_step_transformer`), dynamically resolving matching linear attention projections (`linear_q/k/v`, `to_q/k/v/out.0`, `q_proj/k_proj/v_proj/o_proj`) so zero `Target modules not found` crashes occur across ACE-Step checkpoints.
  3. Pre-encode and cache audio VAE latents (`music_dcae`) in `torch.no_grad()` so the training loop stays within `<= 26 GB` VRAM (`bf16` + gradient checkpointing + gradient accumulation).
  4. Optimize genuine rectified flow-matching velocity MSE loss with AdamW, linear warmup + cosine LR decay, gradient norm clipping (`<= 1.0`), per-track `training_weight`, and Latin phonetic tokenizer guard active.
  5. Emit per-epoch progress webhooks (`status="training"`, `current_epoch`, `total_epochs`, `current_loss`, `best_loss`) to `POST /v1/webhooks/training`.
- **`REQ-P85-TRAIN-02` (Cryptographic Artifact Verification & Dual-Format Export):** Before uploading any trained adapter to R2, `train_lora.py` SHALL verify that every saved tensor in the LoRA state dict is finite (`torch.isfinite().all()`), serialize via `safetensors.torch.save_file(..., metadata=peft_meta)` embedding `vhunambi_lora_id`, `lora_rank`, `lora_alpha`, `target_modules`, `base_model`, `training_tracks`, and `final_loss`, assert `file_size > 64 bytes`, compute SHA-256, and upload BOTH:
  - `loras/{lora_id}.safetensors` (exact canonical key read by `model_utils.py:_hot_swap_loras()`)
  - `loras/{lora_id}/adapter_config.json` (PEFT directory companion)
- **`REQ-P85-TRAIN-03` (Dedicated Pod & Checkpoint Resume Support):** `train_lora.py` SHALL support both RunPod Serverless invocation (called from `handler.py`) AND standalone RunPod Pod execution (`--lora-id`, `--config`, `--resume-from-r2`, `--max-steps`) with periodic checkpoint uploads to `training-checkpoints/{lora_id}/` so long multi-hour runs never lose progress on spot preemption.
- **`REQ-P85-LOADER-01` (Dual-Path Truthful LoRA Hot-Swap in `model_utils.py`):** `ZRModelManager._hot_swap_loras()` in `tools/zr-studio-gpu/model_utils.py` SHALL:
  1. Register `bantu_vocals_v1` in `GENRE_LORA_REGISTRY` (`loras/bantu_vocals_v1.safetensors`).
  2. Preserve Phase 83's truthful SHA-256 + `> 64 bytes` verification before setting `_active_lora_key`.
  3. IF `self._pipeline.load_lora(local_path, lora_weight=weight)` raises or is unavailable, automatically reconstruct a local PEFT adapter directory (`{lora_cache_dir}/{lora_id}_peft/` containing `adapter_config.json` extracted from the `.safetensors` `__metadata__` header + `adapter_model.safetensors`) and attach it onto `self._pipeline.ace_step_transformer` via PEFT `load_lora_adapter` / `PeftModel.from_pretrained`, reporting truthful `loaded: true` ONLY when weights actually attach.

---

## §6. Cloudflare Worker Orchestration & Webhook Requirements (`REQ-P85-API-*`)

- **`REQ-P85-API-01` (Enriched Catalog & Factory Readiness Endpoints):**
  - `GET /v1/studio/loras` SHALL continue returning `{ success: true, totalCount: 10, genre, recommended, packs: [...] }` while enriching each pack with live `registryStatus`, `trainingTracks`, `readyTrackCount`, `minTracks`, `artifactSha256`, and `trainedAt`, AND adding `languagePacks: [...]` (`bantu_vocals_v1`).
  - `GET /v1/studio/loras/factory` SHALL return all 11 packs (genre + language), per-pack source track counts from `explore_tracks` + `user_media_uploads`, curated dataset counts from `lora_dataset_tracks`, and recent `lora_training_jobs`.
- **`REQ-P85-API-02` (Cloud Prep & Train Dispatch Endpoints):**
  - `POST /v1/studio/loras/datasets/prep` (authenticated) SHALL validate `loraId`, select matching R2 source tracks (explicit `sourceTrackIds` or auto-selected by genre/vocal filter), reject `< 8` source tracks with HTTP `400 INSUFFICIENT_SOURCE_TRACKS` (unless `allowPartialPrep: true`), persist a `lora_training_jobs` row (`awaitWriteThrough`), dispatch `job_type: "lora_dataset_prep"` to RunPod via `runpod_adapter.ts`, and return HTTP `202`.
  - `POST /v1/studio/loras/train` (authenticated) SHALL validate `loraId`, verify `>= 8` valid curated tracks exist in `lora_dataset_tracks` (returning `400 DATASET_NOT_READY` otherwise), persist a `lora_training_jobs` row (`awaitWriteThrough`), dispatch `job_type: "lora_train_peft"` to RunPod (or return a ready-to-run Pod CLI launch payload when `executionTarget == "pod"`), and return HTTP `202`.
  - `GET /v1/studio/loras/jobs` and `GET /v1/studio/loras/jobs/:jobId` SHALL return live job telemetry (status, epoch, loss, SHA-256, error).
- **`REQ-P85-API-03` (Signed Training Webhook Handler):** `POST /v1/webhooks/training` in `apps/vhunambi_api/src/routes/webhook_routes.ts` SHALL verify `x-zrs-signature` via constant-time HMAC-SHA256 (`ZR_WEBHOOK_SECRET`, rejecting mismatches with `401`), update `lora_training_jobs`, upsert `lora_dataset_tracks` on `dataset_ready`, and promote `lora_registry.status = 'active'` ONLY when `status == 'completed'`, `artifact_bytes > 64`, and a 64-char hex `artifact_sha256` are present.

---

## §7. Flutter Studio LoRA UI Requirements (`REQ-P85-UI-*`)

- **`REQ-P85-UI-01` (Live LoRA Registry Hydration):** `StudioLoraRegistryNotifier` SHALL fetch `GET /v1/studio/loras/factory` (falling back gracefully to `kAfricanLoraPacks` with `registryStatus: 'untrained'` offline) and expose live status for all 11 packs (including `bantu_vocals_v1`).
- **`REQ-P85-UI-02` (Truthful Status Pills in Studio & Repaint Pickers):** `TrackSectionRepaintSheet` and Studio LoRA pickers SHALL render concise, dual-theme (`AppColors.*Of(context)`) status badges (`Active`, `Training`, `Ready`, `Untrained`) using `PhosphorIcon` (zero stock `Icons.*`, zero raw Unicode emojis) so creators never mistake an untrained pack for an active trained adapter.
- **`REQ-P85-UI-03` (Sovereign LoRA Factory Sheet):** `LoraFactoryStatusSheet` (`Key('lora_factory_status_sheet')`) SHALL display all 11 packs, filter pills (`Key('lora_factory_filter_all')`, `Key('lora_factory_filter_ready')`, `Key('lora_factory_filter_active')`), track readiness bars (`readyTrackCount / minTracks`), and `>= 44dp` action buttons (`Key('lora_prep_btn_<loraId>')`, `Key('lora_train_btn_<loraId>')`) that invoke `POST /v1/studio/loras/datasets/prep` and `POST /v1/studio/loras/train` with non-blocking error notices.

---

## §8. Non-Functional & Hygiene Requirements (`REQ-P85-NFR-*`)

- **`REQ-P85-NFR-01` (Zero Local Docker / Zero Local GPU):** All training Docker images MUST build on GitHub Actions (`push_gpu_worker.yml` + `Dockerfile.delta`); all local unit tests in `tools/zr-studio-training/tests/` MUST execute on CPU in `< 15 seconds` using tiny synthetic `nn.Module` DiT proxies (verifying real PyTorch backward gradients + real `safetensors` write/read + SHA-256 without downloading multi-GB weights on the 8 GB laptop).
- **`REQ-P85-NFR-02` (`STD-UIUX-001` Compliance):** `0` stock `Icons.*` references, `0` raw Unicode emojis in any Dart source file or formal UI widget, all interactive buttons `>= 44x44dp`, and full Light/Dark theme token compliance (`AppColors.*Of(context)`).
- **`REQ-P85-NFR-03` (Bounded Flutter Widget Tests):** All new Flutter widget tests MUST pass under `flutter test --timeout=60s` with zero unbounded `pumpAndSettle()` calls on repeating animations.
- **`REQ-P85-NFR-04` (Cloudflare Worker Durability):** Every mutation to `lora_registry`, `lora_dataset_tracks`, and `lora_training_jobs` MUST await Supabase write-through (`awaitWriteThrough`) before returning HTTP `200`/`202` so cold isolate teardown never drops job or registry state.

---

## §9. Granular Requirement-to-Test Traceability Matrix

| Requirement ID | Target File / Symbol | Automated Test Case |
| :--- | :--- | :--- |
| `REQ-P85-DB-01..04` | `supabase/migrations/20261125000002_phase85_cloud_lora_factory.sql` | Live `supabase_mcp:apply_migration` + `get_advisors` (`0` RLS policy gaps) + `phase85_lora_factory.test.ts` |
| `REQ-P85-SCHEMA-01..03` | `training_dataset_schema.ts`, `lora_catalog.ts` | `phase85_lora_factory.test.ts`: Zod schema validation + `bantu_vocals_v1` lookup + Zania genre mapper + `phase83_repaint_lora_routes.test.ts` (`totalCount === 10`) |
| `REQ-P85-PREP-01..02` | `tools/zr-studio-training/validate_dataset.py`, `dataset_prep_worker.py` | `test_phase85_lora_factory.py`: WAV/JSON validation (<8 fail, >=8 pass, bad SR/duration fail), MP3/WAV prep + BPM/Key extraction + curated manifest export |
| `REQ-P85-TRAIN-01..03` | `tools/zr-studio-training/train_lora.py` | `test_phase85_lora_factory.py`: Real PyTorch PEFT LoRA optimization on synthetic DiT -> loss decreases -> finite `.safetensors` (>64B, valid header, embedded PEFT metadata, SHA-256) |
| `REQ-P85-LOADER-01` | `tools/zr-studio-gpu/model_utils.py`, `handler.py` | `test_phase83_repaint_lora.py` + `test_phase85_lora_factory.py`: Dual-path PEFT directory reconstruction from `.safetensors` `__metadata__` + `handler.py` dispatch for `lora_dataset_prep` & `lora_train_peft` |
| `REQ-P85-API-01..03` | `studio_routes.ts`, `webhook_routes.ts`, `runpod_adapter.ts`, `vhunambi_db.ts` | `phase85_lora_factory.test.ts`: `/v1/studio/loras/factory`, `/datasets/prep` (400 <8, 202 >=8), `/train` (400 unprepped, 202 ready), `/v1/webhooks/training` (401 bad HMAC, 200 valid -> promotes `active`) |
| `REQ-P85-UI-01..03` | `studio_lora_registry_provider.dart`, `lora_factory_status_sheet.dart`, `track_section_repaint_sheet.dart` | `phase85_lora_factory_ui_test.dart`: Factory sheet renders 11 packs, filter pills, `>=44dp` Prep/Train triggers, Light & Dark theme, `0` raw emojis, `0` stock `Icons.*` |

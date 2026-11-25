# Phase 83 Requirements: Post-Generation Stem Repaint, Section Inpainting & Sovereign African LoRA Activation

**Phase ID:** `P83`  
**Standard:** EARS (`WHEN`, `WHILE`, `IF...THEN`, `WHERE`, `SHALL`) + RFC-2119 + `STD-UIUX-001`  
**Audit Source:** [`PHASE83_POSTGEN_STEM_REPAINT_AND_LORA_STUDIO_AUDIT.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/audits/PHASE83_POSTGEN_STEM_REPAINT_AND_LORA_STUDIO_AUDIT.md)

---

## 1. Document Scope & Invariants

This specification defines verifiable requirements for closing all **11 findings** (`REPAINT-01..05`, `LORA-01..04`, `UI-P83-01`, `INFRA-P83-01`) across:
- RunPod GPU worker (`tools/zr-studio-gpu/`)
- Cloudflare Worker API (`apps/vhunambi_api/`)
- Flutter mobile/desktop client (`apps/vhunambi_client/`)

**Non-Negotiable Invariants:**
1. **Zero Commercial License Violations:** `YuE2` remains strictly prohibited; all repaint/lego/LoRA inference executes on **MIT-licensed `ACE-Step 1.5 XL-Base`** (`ace_step_xl_base`). GPL-3.0 post-processing (`Seed-VC`, `Matchering 2.0`, `Pedalboard`) remains strictly server-side inside `tools/zr-studio-gpu/`.
2. **Zero Backward Regressions:** All Phase 25 mastering tests, Phase 54 quantum entanglement tests, Phase 66 lyric sanitizer tests, and Phase 80–82 tests MUST continue passing untouched.
3. **Truthful Provenance:** Neither the GPU worker nor the API SHALL claim a LoRA adapter was applied unless the `.safetensors` artifact actually existed on disk/cache (size $> 64$ bytes, SHA-256 computed) and loaded cleanly.

---

## 2. RunPod GPU Repaint & Stem-Lock Requirements (`REQ-P83-GPU-*`)

- **`REQ-P83-GPU-01` (Canonical Stem-Lock Normalization):**  
  `WHEN` `handler.py` receives `pregen_stem_locks` or `stem_locks` containing either canonical stem role keys (`vocals`, `drums`, `bass`, `melodic`) OR legacy 3D DNA node keys (`node_beat_tempo`, `node_branch_beat`, `node_sketchpad_groove`, `node_harmony_chords`, `node_branch_instruments`, `node_vocal_persona`, `node_branch_vocal`, `node_spatial_atmosphere`, `node_drums`, `node_bass`, `node_vocals`, `node_melodic`), the worker `SHALL` normalize them via `normalize_stem_locks()` into a canonical `Dict[str, str]` over `{"vocals", "drums", "bass", "melodic"}` before stem-lock injection or repaint execution.

- **`REQ-P83-GPU-02` (`ACE-Step 1.5 XL-Base` Section Repaint, Lego & Complete):**  
  `WHEN` `job_input["job_type"] == "section_repaint"` (or `repaint_config` is supplied), `ZRMultiModelRouter.resolve_route()` `SHALL` force `resolved_engine = "ace_step_xl_base"` with `attribution_tag = None`. `ZRModelManager.repaint_audio_section()` `SHALL`:
  1. Clamp `start_sec` and `end_sec` within `[0.0, total_duration]` enforcing `end_sec - start_sec >= 2.0`.
  2. When `ACEStepPipeline` is installed on GPU, invoke `self._pipeline(...)` passing `task` (`"repaint"` | `"edit"` | `"extend"` mapped from `"repaint"` | `"lego"` | `"complete"`), `repaint_start=start_sec`, `repaint_end=end_sec`, `src_audio_path=source_wav_path`, and `retake_variance`.
  3. When running in offline/CPU fallback mode, synthesize a phase-aligned replacement span for `[start_sec, end_sec]` and splice it into `source_wav_path` using a raised-cosine crossfade window ($M = \min(\lfloor 0.08 f_s \rfloor, \lfloor (N_1 - N_0)/4 \rfloor)$) so samples outside `[start_sec, end_sec]` remain bit-identical to the source audio.
  4. Preserve locked stems (`lockedPure44k`)—using `BS-RoFormer` lead/bed isolation (`EP-P82-BS-ROFORMER-SEED-VC`) whenever vocals are locked or targeted—and finish with Phase 82 `Matchering 2.0` mastering (`EP-P82-SA-MATCHERING-ENGINE`) and MMO v2.0 60Hz telemetry extraction.

- **`REQ-P83-GPU-03` (Repaint Provenance Emission):**  
  `WHEN` a section repaint job finishes, `handler.py` `SHALL` emit `repaint_metadata` (`parent_job_id`, `task`, `start_sec`, `end_sec`, `target_stem`, `stem_locks`, `crossfade_ms`) and `lora_metrics` in both `manifest_payload` and the signed `completed` webhook payload.

---

## 3. Sovereign African LoRA Pack & Hot-Swap Requirements (`REQ-P83-LORA-*`)

- **`REQ-P83-LORA-01` (Truthful LoRA Loading & SHA-256 Verification):**  
  `WHEN` `ZRModelManager._hot_swap_loras(lora_specs)` activates up to 3 requested adapters, it `SHALL`:
  1. Reset `self._active_lora_key = None`, `self._active_lora_weight = 0.0`, and `self._loaded_loras = []` prior to loading.
  2. Normalize combined weights so $\sum \tilde{w}_i \le 1.35$.
  3. Resolve each `.safetensors` file in order: (a) local `/runpod-volume/lora_cache/<filename>` (`ZR_LORA_CACHE_DIR`), (b) authenticated `boto3` S3 `get_object` from `R2_BUCKET` when `R2_ACCESS_KEY_ID` & `R2_SECRET_ACCESS_KEY` are configured, (c) HTTPS `GET` from `R2_PUBLIC_BASE_URL` when configured.
  4. Validate file size $> 64$ bytes and compute its SHA-256 digest.
  5. Record the adapter in `self._loaded_loras` (and set `self._active_lora_key` / `self._active_lora_weight` from the primary loaded adapter) **ONLY IF** the local file exists and passes verification (and `pipeline.load_lora(...)` succeeds whenever `self._pipeline is not None`).
  6. `IF` a requested LoRA fails download or load, `THEN` log `[ZR-WARN]` and leave `loaded: False` in `lora_metrics` without crashing synthesis or emitting false-positive `active_lora` provenance.

- **`REQ-P83-LORA-02` (Unified 10-Pack African LoRA Registry Covering All 42 Genres):**  
  `apps/vhunambi_api/src/modules/synthesis/lora_catalog.ts` and `tools/zr-studio-gpu/model_utils.py` (`GENRE_LORA_REGISTRY`) `SHALL` expose identical adapter IDs and `r2Key` paths for all 10 sovereign African packs (`amapiano_logdrum_v1`, `amapiano_private_school_v1`, `sgija_bacardi_v1`, `gqom_durban_v1`, `maskandi_picking_v1`, `venda_malende_v1`, `afrobeats_lagos_v1`, `kwaito_township_v1`, `afro_gospel_choir_v1`, `afrohouse_ancestral_v1`) with deterministic alias resolution across all 42 `GENRE_PRESETS` (including `privateschoolamapiano`, `sgija`, `bacardi`, `lekompo`, `malende`, `mbaqanga`, `isicathamiya`, `mbube`, `afrofusion`, `afrosoul`).

- **`REQ-P83-LORA-03` (`ACE-Step 1.5 XL-Base` Checkpoint Resolution & Volume Preflight):**  
  `ZRModelManager` `SHALL` resolve `ACE_STEP_XL_BASE_DIR` / `ACE_STEP_CHECKPOINT_DIR` / `<HF_HOME>/ACE-Step-1.5-XL-Base` before falling back to legacy `<HF_HOME>/ACE-Step-v1-3.5B`, and provide `inspect_volume_lora_inventory()` returning exact cached `.safetensors` filenames, sizes, and SHA-256 hashes under `resolve_lora_cache_dir()`.

---

## 4. Cloudflare Worker API Requirements (`REQ-P83-API-*`)

- **`REQ-P83-API-01` (`GET /v1/studio/loras`):**  
  `apps/vhunambi_api/src/routes/studio_routes.ts` `SHALL` expose `GET /v1/studio/loras` (supporting optional `?genre=` query filter) returning `{ success: true, totalCount, recommended, packs }` from `lora_catalog.ts` with zero SQLite dependency (100% Edge-safe).

- **`REQ-P83-API-02` (Explicit `loras[]` Override on `POST /v1/generations`):**  
  `SubmitGenerationSchema` in `generation_routes.ts` `SHALL` accept optional `loras: z.array(z.object({ loraId: z.string().min(1), path: z.string().optional(), weight: z.number().min(0.1).max(1.2).default(0.85) })).max(3).optional()`, resolve any omitted `path` via `lora_catalog.ts`, and forward them into `compileSongSpec` ➔ `dispatchSynthesisJob` ➔ RunPod `/run`.

- **`REQ-P83-API-03` (`POST /v1/generations/:id/repaint` & Revision Persistence):**  
  `generation_routes.ts` `SHALL` expose `POST /v1/generations/:id/repaint` accepting:
  - `startSec: number >= 0`, `endSec: number` (`endSec - startSec >= 2`)
  - `task: 'repaint' | 'lego' | 'complete'` (default `'repaint'`)
  - `targetStem?: 'full' | 'vocals' | 'drums' | 'bass' | 'melodic'` (default `'full'`)
  - `stemLocks?: Record<string, 'lockedPure44k' | 'harmonicInpaint' | 'elasticResynth'>`
  - `editPrompt?: string`, `editLyrics?: string`, `loras?: Array<...>`, `masteringMode?: 'streaming' | 'club'`, `sampleRateHz?: 44100 | 48000`
  `WHEN` valid, the route `SHALL`:
  1. Hydrate the parent job via `getJob(id)` or `vhunambiDb.syncGenerationJobFromCloud(id, c)` (allowing seeded `trk_*` / `seed_*` tracks in local/test mode, returning `404` for unknown IDs).
  2. Enforce tenant ownership (`creatorId`), create a child `GenerationJob` (`gen_repaint_<ts>_<nanoid>`) with `resolvedEngine: 'ace_step_xl_base'`, `attributionTag: null`, `parentGenerationId: id`, and `repaintSpec`.
  3. Dispatch to RunPod with `job_type: 'section_repaint'`, `repaint_config`, `source_audio_url`, `source_stem_urls`, normalized `stem_locks`, and resolved `loras[]`.
  4. On webhook/poll completion, persist `loraMetrics` & `repaintMetadata` on the child job and append a `RepaintHistoryEntry` onto the parent job's `repaintHistory[]` and MMO manifest (surviving both SQLite and Supabase `manifest_json` read-through without new SQL migrations).

---

## 5. Flutter Client Post-Gen Repaint & LoRA UI Requirements (`REQ-P83-UI-*`)

- **`REQ-P83-UI-01` (Relocated Stem Authority & `TrackSectionRepaintSheet`):**  
  `TrackDetailView` (owner-only studio cockpit section) `SHALL` display a `"Section Repaint & Inpaint"` button (`Key('track_detail_open_repaint_btn')`, `minHeight: 48`) that opens `TrackSectionRepaintSheet` (`Key('track_section_repaint_sheet')`) containing:
  1. BPM-aware section range selector (`RangeSlider`, `Key('repaint_range_slider')`) displaying `Start` / `End` timestamps and bar span.
  2. Task mode selector (`Repaint`, `Stem Lego`, `Extend` via `VhunambiGlassTabBar` or pill chips with `minHeight: 44`).
  3. Refactored `CockpitQuantumEntanglementRack` (`Lock | Inpaint | Resynth` pills with `minHeight: 44`, Light/Dark `AppColors.*Of(context)` tokens — zero hardcoded `0xFF0A1422` hexes).
  4. Sovereign African LoRA Pack picker (`Key('repaint_lora_picker')`) + blend weight slider (`0.10–1.20`).
  5. Optional lyric/direction patch `TextField` (`Key('repaint_edit_lyrics_field')`) and primary CTA (`Key('repaint_submit_btn')`) invoking `TrackDetailNotifier.submitSectionRepaint(...)` (`POST /v1/generations/:id/repaint`).

- **`REQ-P83-UI-02` (Multi-Take Switcher & Repaint History Telemetry):**  
  `TrackDetailEntity` `SHALL` add `takes` (`List<TrackTakeRecord>`) and `repaintHistory` (`List<TrackRepaintEntry>`) + `activeLoras` (`List<String>`), hydrated in `TrackDetailNotifier.loadManifestFromCloud(...)`. `TrackSonicTelemetryCard` `SHALL` display a `"Repainted · N edits"` chip (`Key('track_repaint_history_chip')`) when `repaintHistory.isNotEmpty` and a LoRA badge (`Key('track_lora_provenance_chip')`) when `activeLoras.isNotEmpty`.

- **`REQ-P83-UI-03` (Studio LoRA Picker & Remix Dead-End Elimination):**  
  1. `StudioFormState`, `GenerationPipelineNotifier`, and `HttpGenerationSubmissionService` `SHALL` carry `selectedLoraId` / `selectedLoraWeight` and send `loras: [{ 'loraId': ..., 'weight': ... }]` to `POST /v1/generations` when selected in `Sovereign Custom` tier (preserving all existing calls cleanly).
  2. `TrackDetailView._handleRemix()` `SHALL` invoke `studioFormProvider.notifier.applyPastTrackRemix(...)` preserving `track.id`, `title`, `genre`, `language`, `audioUrl`, and `lyrics`.
  3. `OpenVerseRemixCockpitSheet` Mode A `SHALL` replace the flat `0.45` DC array with an audible harmonic envelope fallback when no mic capture file is present, and Mode B `remix_open_sketchpad_btn` `SHALL` navigate to Studio Crate/Sketchpad (`appNavigationTabProvider` + `studioTabIndexProvider = 2`) instead of a dead-end SnackBar.

- **`REQ-P83-UI-04` (`STD-UIUX-001` & Compact Viewport Compliance):**  
  All new and refactored Flutter files `SHALL` contain `0` stock `Icons.*`, `0` raw Unicode emojis, `>= 44dp` interactive hit heights, authentic `AppColors.*Of(context)` / `AppTypography.*` tokens, and render with zero `RenderFlex` overflow at `360x800` in both Light and Dark themes.

---

## 6. Requirement-to-Test Traceability Matrix

| Req ID | Primary Implementation File | Verification Test Case |
| :--- | :--- | :--- |
| `REQ-P83-GPU-01` | `tools/zr-studio-gpu/handler.py` | `test_phase83_repaint_lora.py::test_canonical_and_legacy_stem_lock_normalization` |
| `REQ-P83-GPU-02..03` | `tools/zr-studio-gpu/model_utils.py`, `handler.py` | `test_phase83_repaint_lora.py::test_section_repaint_raised_cosine_splice_and_e2e_handler` |
| `REQ-P83-LORA-01..03` | `tools/zr-studio-gpu/model_utils.py` | `test_phase83_repaint_lora.py::test_truthful_lora_loading_rejects_missing_and_normalizes_multi_lora` |
| `REQ-P83-API-01` | `apps/vhunambi_api/src/modules/synthesis/lora_catalog.ts`, `studio_routes.ts` | `phase83_repaint_lora_routes.test.ts` (Case 1: `GET /v1/studio/loras` + 42-genre coverage) |
| `REQ-P83-API-02` | `apps/vhunambi_api/src/routes/generation_routes.ts`, `runpod_adapter.ts` | `phase83_repaint_lora_routes.test.ts` (Case 2: explicit `loras[]` forwarding) |
| `REQ-P83-API-03` | `apps/vhunambi_api/src/routes/generation_routes.ts`, `webhook_routes.ts` | `phase83_repaint_lora_routes.test.ts` (Cases 3–4: `POST /:id/repaint` + webhook `repaintHistory` + Edge persistence) |
| `REQ-P83-UI-01..04` | `apps/vhunambi_client/lib/features/track/...`, `lib/features/studio/...` | `phase83_repaint_lora_test.dart` (Light & Dark `360x800`, `loadManifestFromCloud`, `submitSectionRepaint`, `TrackSonicTelemetryCard` badges) |

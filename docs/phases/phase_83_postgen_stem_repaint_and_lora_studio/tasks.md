# Phase 83 Tasks: Post-Generation Stem Repaint, Section Inpainting & Sovereign African LoRA Activation

**Phase ID:** `P83`  
**Execution Engine:** `/vhunambi-executioner` (Stage 4 Two-Pass Deterministic Implementation)  
**Target Branch:** `fix/studio-cockpit-bugs-vh001-vh006`

---

## 1. Master Milestone Roadmap & Dependency Graph

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ PASS 1 · GPU REPAINT & WORKER LORA / REPAINT API                             │
│   M83.1: RunPod GPU Truthful LoRA Loader, Raised-Cosine Splice & handler.py  │
│     └──► Gate G83-01: py_compile + unittest (Phase 81 + 82 + 83 suites)      │
│   M83.2: Worker lora_catalog.ts, GET /v1/studio/loras & POST /:id/repaint    │
│     └──► Gate G83-02: tsc.cmd --noEmit && npm test (36/36 suites)            │
├──────────────────────────────────────────────────────────────────────────────┤
│ PASS 2 · FLUTTER POST-GEN REPAINT SHEET, LORA PICKER, DEPLOY & SLEEP         │
│   M83.3: TrackSectionRepaintSheet, Refactored Quantum Rack & Studio LoRA     │
│     └──► Gate G83-03: flutter test --no-pub --timeout=60s + STD-UIUX-001     │
│   M83.4: Worker Deploy, Night-Data :vhunambi-v4 Push & Memory SLEEP          │
│     └──► Gate G83-04 & G83-05: Live /health 200 + consolidate_memory.mjs     │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Pass 1 — Milestone `M83.1`: RunPod GPU Truthful LoRA & `ACE-Step XL-Base` Repaint Engine

- [x] **`T83.1.1` — Unified 10-Pack Registry, Truthful `_hot_swap_loras` & `splice_repainted_section` (`REQ-P83-LORA-01..03`, `REQ-P83-GPU-02`)**
  - **Target:** `tools/zr-studio-gpu/model_utils.py`
  - **Scope:** Expand `GENRE_LORA_REGISTRY` to all 10 sovereign packs + SA/African aliases; add `normalize_multi_lora_weights`, `verify_safetensors_artifact`, `inspect_volume_lora_inventory`, `splice_repainted_section` (raised-cosine $C^1$ crossfade), and `ZRModelManager.repaint_audio_section(...)`; replace false-positive `_hot_swap_lora` with truthful `_hot_swap_loras` (authenticated `boto3` R2 fallback + `/runpod-volume/lora_cache` + `loaded_loras` only on verified artifact); resolve `ACE-Step-1.5-XL-Base` checkpoint before legacy `ACE-Step-v1-3.5B`.
  - **Acceptance:** Missing `.safetensors` yields `active_lora == None` and `loaded_count == 0`; valid local `.safetensors` yields `loaded == True` with SHA-256; spliced samples outside `[start_sec, end_sec]` are bit-identical to source audio.

- [x] **`T83.1.2` — `model_router.py` Repaint Route & `handler.py` Canonical Stem-Lock Normalizer (`REQ-P83-GPU-01..03`)**
  - **Targets:** `tools/zr-studio-gpu/model_router.py`, `tools/zr-studio-gpu/handler.py`
  - **Scope:** Force `ace_step_xl_base` (`attribution_tag=None`) in `ZRMultiModelRouter.resolve_route` when `job_type == "section_repaint"` or `repaint_config` is present; add `normalize_stem_locks()` mapping both canonical roles (`vocals|drums|bass|melodic`) and legacy 3D DNA node IDs (`node_beat_tempo`, `node_harmony_chords`, `node_vocal_persona`, etc.); wire `section_repaint` path through `repaint_audio_section` ➔ `BS-RoFormer` locked-vocal protection ➔ `Matchering 2.0` ➔ MMO v2.0 ➔ R2 upload emitting `repaint_metadata` & `lora_metrics`.
  - **Acceptance:** `handler.py` executes `section_repaint` E2E offline with `resolved_engine == "ace_step_xl_base"` and emits truthful `repaint_metadata` & `lora_metrics`.

- [x] **`T83.1.3` — Python Phase 83 Test Suite (`G83-01`)**
  - **Target:** `tools/zr-studio-gpu/test_phase83_repaint_lora.py` (new)
  - **Scope:** Test truthful LoRA rejection on missing files vs verified `.safetensors` multi-LoRA weight normalization (`sum <= 1.35`), canonical + legacy `node_*` stem-lock normalization, raised-cosine crossfade bit-preservation outside `[start_sec, end_sec]`, and E2E `handler.py` `section_repaint`.
  - **Acceptance:** `python -u -m py_compile tools/zr-studio-gpu/*.py` and `python -u -m unittest discover -s tools/zr-studio-gpu -p "test_*.py" -v` pass `100%` (Phase 81 + 82 + 83 suites, `0 MB` local `pip install`).

---

## 3. Pass 1 — Milestone `M83.2`: Cloudflare Worker Canonical LoRA Catalog & `/repaint` API

- [x] **`T83.2.1` — Canonical `lora_catalog.ts`, `GET /v1/studio/loras` & De-Duplicated Planner/Adapter (`REQ-P83-LORA-02`, `REQ-P83-API-01..02`)**
  - **Targets:** `apps/vhunambi_api/src/modules/synthesis/lora_catalog.ts` (new), `apps/vhunambi_api/src/modules/lyrics/llm_handler.ts`, `apps/vhunambi_api/src/modules/synthesis/runpod_adapter.ts`, `apps/vhunambi_api/src/modules/synthesis/prompt_compiler.ts`, `apps/vhunambi_api/src/routes/studio_routes.ts`
  - **Scope:** Author `AFRICAN_LORA_PACKS` (10 packs covering all 42 `GENRE_PRESETS`), refactor `llm_handler.ts` & `runpod_adapter.ts` to delegate to `lora_catalog.ts`, add `GET /v1/studio/loras` in `studio_routes.ts`, and accept optional explicit `loras[]` in `compileSongSpec` & `SubmitGenerationSchema`.
  - **Acceptance:** `GET /v1/studio/loras?genre=Private+School+Amapiano` returns `amapiano_private_school_v1`; `Sgija` / `Malende` / `Lekompo` resolve to their authentic packs instead of collapsing blindly to `amapiano_logdrum_v1`.

- [x] **`T83.2.2` — `POST /v1/generations/:id/repaint`, Revision Persistence & Webhook Sync (`REQ-P83-API-03`)**
  - **Targets:** `apps/vhunambi_api/src/modules/dna/dna_types.ts`, `apps/vhunambi_api/src/modules/dna/dna_compiler.ts`, `apps/vhunambi_api/src/modules/jobs/job_types.ts`, `apps/vhunambi_api/src/modules/jobs/job_store.ts`, `apps/vhunambi_api/src/db/vhunambi_db.ts`, `apps/vhunambi_api/src/db/edge_persistence_bridge.ts`, `apps/vhunambi_api/src/routes/generation_routes.ts`, `apps/vhunambi_api/src/routes/webhook_routes.ts`, `apps/vhunambi_api/src/modules/synthesis/runpod_adapter.ts`
  - **Scope:** Add `RepaintHistoryEntry` & `LoraRuntimeMetrics`, add `POST /v1/generations/:id/repaint` (`RepaintGenerationSchema`, `dispatchRepaintJob` -> RunPod `job_type: 'section_repaint'`), persist `parentGenerationId`, `repaintHistory`, `repaintMetadata`, and `loraMetrics` via `manifest_json` / `generation_spec_json` (zero SQL schema changes), and update parent job's `repaintHistory[]` on webhook completion.
  - **Acceptance:** Cold-isolate-safe `/repaint` returns `201`, rejects `< 2s` spans with `400`, returns `404` on unknown IDs, and appends `repaintHistory[]` on webhook completion.

- [x] **`T83.2.3` — Worker Phase 83 Test Suite (`G83-02`)**
  - **Targets:** `apps/vhunambi_api/test/phase83_repaint_lora_routes.test.ts` (new), `apps/vhunambi_api/package.json`
  - **Scope:** Test `GET /v1/studio/loras`, 42-genre resolution, explicit `loras[]` on `POST /v1/generations`, `POST /v1/generations/:id/repaint` (`201`/`400`/`404`), RunPod `section_repaint` payload dispatch, webhook `repaint_metadata` + `lora_metrics` parent history update, and Edge isolate read-through. Register in `package.json`.
  - **Acceptance:** `cd apps/vhunambi_api; .\node_modules\.bin\tsc.cmd --noEmit && npm test` passes `36/36` suites (`0` TS errors).

---

## 4. Pass 2 — Milestone `M83.3`: Flutter Post-Gen `TrackSectionRepaintSheet`, Refactored Quantum Rack & LoRA Picker

- [x] **`T83.3.1` — `TrackDetailEntity` (`takes` / `repaintHistory` / `activeLoras`), `submitSectionRepaint` & Telemetry Chips (`REQ-P83-UI-02`)**
  - **Targets:** `apps/vhunambi_client/lib/features/track/domain/models/track_detail_models.dart`, `apps/vhunambi_client/lib/features/track/presentation/providers/track_providers.dart`, `apps/vhunambi_client/lib/features/track/presentation/widgets/track_sonic_telemetry_card.dart`
  - **Scope:** Add `TrackTakeRecord` & `TrackRepaintEntry`, hydrate `takes`, `repaintHistory`, and `activeLoras` in `loadManifestFromCloud`, implement `selectTake(...)` and `submitSectionRepaint(...)`, and render `track_repaint_history_chip` & `track_lora_provenance_chip` in `TrackSonicTelemetryCard`.
  - **Acceptance:** Manifest JSON hydrates `repaintHistory` & `activeLoras`; chips render with zero overflow at `360x800` Light & Dark.

- [x] **`T83.3.2` — Refactor `CockpitQuantumEntanglementRack` (`STD-UIUX-001`), Build `TrackSectionRepaintSheet`, Wire `TrackDetailView`, Studio LoRA & Remix Fixes (`REQ-P83-UI-01`, `REQ-P83-UI-03..04`)**
  - **Targets:** `apps/vhunambi_client/lib/features/studio/presentation/widgets/cockpit_quantum_entanglement_rack.dart`, `apps/vhunambi_client/lib/features/track/presentation/widgets/track_section_repaint_sheet.dart` (new), `apps/vhunambi_client/lib/features/track/presentation/views/track_detail_view.dart`, `apps/vhunambi_client/lib/features/track/presentation/widgets/stem_separation_lab.dart`, `apps/vhunambi_client/lib/features/studio/domain/models/studio_form_state.dart`, `apps/vhunambi_client/lib/features/studio/presentation/providers/studio_form_provider.dart`, `apps/vhunambi_client/lib/features/studio/presentation/providers/generation_pipeline_providers.dart`, `apps/vhunambi_client/lib/features/studio/data/services/http_generation_submission_service.dart`, `apps/vhunambi_client/lib/features/social/presentation/widgets/open_verse_remix_cockpit_sheet.dart`
  - **Scope:** Upgrade `CockpitQuantumEntanglementRack` to semantic Light/Dark tokens + `>= 44dp` touch height (preserving all Phase 54 test keys); create `TrackSectionRepaintSheet` with bar-range `RangeSlider`, task tabs, stem authority rack, African LoRA pack selector + weight slider, lyric/prompt patch box, and submit CTA; mount `"Section Repaint & Inpaint"` button on `TrackDetailView`; upgrade `_handleRemix()` to `applyPastTrackRemix(...)`; wire `selectedLoraId` / `selectedLoraWeight` through Studio submission; fix `OpenVerseRemixCockpitSheet` DC vocal array and `Open Sketchpad` dead-end.
  - **Acceptance:** `0` stock `Icons.*`, `0` raw emojis, `>= 44dp` targets, `phase54_cockpit_biome_quantum_entanglement_test.dart` passes unchanged.

- [x] **`T83.3.3` — Flutter Phase 83 Widget & Provider Test Suite (`G83-03`)**
  - **Target:** `apps/vhunambi_client/test/features/track/phase83_repaint_lora_test.dart` (new)
  - **Scope:** Test `TrackDetailNotifier.submitSectionRepaint(...)` HTTP POST contract + optimistic `repaintHistory` update, `loadManifestFromCloud` hydration of `repaintHistory` + `activeLoras`, `TrackSectionRepaintSheet` rendering & interaction in Light and Dark `360x800` with zero overflow, and `TrackSonicTelemetryCard` repaint + LoRA provenance chips.
  - **Acceptance:** `flutter test --no-pub --timeout=60s` passes `100%` across `phase83_repaint_lora_test.dart` (5/5), `phase54_cockpit_biome_quantum_entanglement_test.dart` (5/5), `track_detail_view_test.dart` (4/4), `phase82_track_provenance_test.dart` (3/3), `phase37_open_verse_and_remix_chains_test.dart` (7/7), `phase81_multitake_ar_pipeline_test.dart` (4/4), and `phase80_studio_cockpit_v6_test.dart` (8/8).

---

## 5. Pass 2 — Milestone `M83.4`: Cloudflare Worker Deploy, Combined `:vhunambi-v4` Night-Data Push & `SLEEP`

- [x] **`T83.4.1` — Deploy Cloudflare Worker & Verify Live `/v1/studio/loras` (`G83-04`)**
  - **Scope:** Deployed `vhunambi-api` Version `4d131620-95fc-443d-bd8b-0c964b72205c`; verified live `GET https://vhunambi-api.ndugelosigwadi.workers.dev/health` (`200 OK`) and `GET /v1/studio/loras?genre=Amapiano` (`200 OK`, `totalCount: 10`).

- [x] **`T83.4.2` — Finalize `memory.md`, Master Tracker & Run `consolidate_memory.mjs` (`G83-05`)**
  - **Targets:** `docs/phases/phase_83_postgen_stem_repaint_and_lora_studio/memory.md`, `docs/phases/PHASE_80_PLUS_STUDIO_AND_RUNPOD_MASTER_TRACKER.md`, `docs/memory/*`
  - **Scope:** Promoted Phase 83 `memory.md` to `"status": "completed"`, updated Master Tracker, ran `node .agents/skills/vhunambi-memory/scripts/consolidate_memory.mjs`, and documented exact `:vhunambi-v4` GPU push command for the combined `P81+P82+P83` container build.

---

## 6. Stage 4 Anti-Trap Checklist & Verification Commands

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ STAGE 4 EXECUTION INVARIANTS (/vhunambi-executioner)                         │
│  [x] Zero false-positive LoRA claims when .safetensors is missing on disk    │
│  [x] Preserve all Phase 54 keys in CockpitQuantumEntanglementRack            │
│  [x] Preserve Phase 25 mastering.test.ts & Phase 66 lyrics sanitizer tests   │
│  [x] Zero GPL code/packages in apps/vhunambi_client/ (server-side RunPod)    │
│  [x] Zero stock Icons.* & zero raw emojis (STD-UIUX-001), >= 44dp hit height │
│  [x] Direct .\node_modules\.bin\tsc.cmd & wrangler (never npx on Windows)    │
│  [x] Offline Python unit tests pass with 0 MB local pip installs             │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Exact Verification Gate Commands
```powershell
# Gate G83-01: Python Bytecode & Phase 81 + 82 + 83 GPU Suites
python -u -m py_compile tools/zr-studio-gpu/model_router.py tools/zr-studio-gpu/model_utils.py tools/zr-studio-gpu/mmo_extractor.py tools/zr-studio-gpu/seed_vc_worker.py tools/zr-studio-gpu/stem_mastering_worker.py tools/zr-studio-gpu/handler.py
python -u -m unittest discover -s tools/zr-studio-gpu -p "test_*.py" -v

# Gate G83-02: Cloudflare Worker TypeScript & All 36 API Suites
cd apps/vhunambi_api; .\node_modules\.bin\tsc.cmd --noEmit && npm test

# Gate G83-03: Flutter Phase 83 + Regression Track & Quantum Suites
cd apps/vhunambi_client; flutter test --no-pub --timeout=60s test/features/track/phase83_repaint_lora_test.dart test/features/track/phase82_track_provenance_test.dart test/features/studio/phase54_cockpit_biome_quantum_entanglement_test.dart test/features/track/track_detail_view_test.dart
```

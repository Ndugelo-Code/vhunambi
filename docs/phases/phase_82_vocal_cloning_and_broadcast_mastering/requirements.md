# Phase 82 Requirements — Studio Baking Post-Processing Chain (`BS-RoFormer` + Neural `Seed-VC` + `Matchering 2.0`)

> **Document ID:** `REQ-PHASE-82`  
> **Phase Folder:** `docs/phases/phase_82_vocal_cloning_and_broadcast_mastering/`  
> **Predecessor Audit:** [`PHASE82_VOCAL_CLONING_AND_BROADCAST_MASTERING_AUDIT.md`](../../audits/PHASE82_VOCAL_CLONING_AND_BROADCAST_MASTERING_AUDIT.md)  
> **Conventions:** EARS (`WHEN`, `WHILE`, `IF...THEN`, `WHERE`) and RFC-2119 (`SHALL`, `MUST`, `SHOULD`, `MAY`).

---

## 1. Document Scope & Legal / Architectural Invariants

1. **Server-Side GPL-3.0 Isolation Invariant:** `Seed-VC`, `Matchering 2.0`, and `Spotify Pedalboard` **SHALL** execute strictly inside `tools/zr-studio-gpu/` on RunPod Serverless Linux containers. Zero GPL source code, binaries, or Flutter packages **SHALL** be added to `apps/vhunambi_client/`.
2. **Commercial Model Hygiene Invariant:** `BS-RoFormer` / `Mel-Band RoFormer` (`MIT`/`Apache-2.0`) and `pyloudnorm` (`MIT`) are approved; `YuE2` (`CC BY-NC 4.0`) remains strictly prohibited across all files.
3. **Zero-Install Offline Testability Invariant:** Every Phase 82 Python module (`mmo_extractor.py`, `seed_vc_worker.py`, `stem_mastering_worker.py`, `handler.py`) **SHALL** execute its full mathematical verification suite deterministically on CPU-only developer hosts without requiring CUDA, live R2 credentials, or downloading multi-GB weights.

---

## 2. Resampling & Surgical Vocal Isolation Requirements (`REQ-P82-UPSAMPLE-*`, `REQ-P82-STEM-*`)

### `REQ-P82-UPSAMPLE-01` — Configurable `44.1 kHz` / `48 kHz` 24-Bit Upsampling
1. `model_router.py` **SHALL** generalize `normalize_wav_to_44k1(wav_path, target_sr=44100)` via `normalize_wav_to_sr(wav_path, target_sr)` supporting both `44100` Hz (streaming default) and `48000` Hz (broadcast/video master option) stereo `PCM_24` via `soxr` VHQ (`scipy.signal.resample_poly` / NumPy fallback).
2. **WHEN** `MiniMax Music 3.0` emits a `32,000 Hz` 16-bit WAV, `handler.py` **SHALL** upsample it to `target_sample_rate` (`44100` or `48000`) before `BS-RoFormer`, `htdemucs`, `Seed-VC`, or `Matchering 2.0`.

### `REQ-P82-STEM-01` — `BS-RoFormer` Lead-Vocal Isolation With 4-Stem Mixer Retention
1. **WHEN** `svc_config` is present on a generation job (vocal cloning or vocal archetype conversion), `mmo_extractor.py#separate_lead_vocal_bs_roformer(input_wav_path, output_dir)` **SHALL** isolate a clean `lead_vocals.wav` and phase-complementary `instrumental_bed.wav` via `BS-RoFormer` / `Mel-Band RoFormer` (`audio-separator` when installed on RunPod, or spectral mid/harmonic isolation fallback on CPU dev hosts).
2. Regardless of whether `BS-RoFormer` executes, `handler.py` **SHALL** still run `separate_stems_with_demucs` to export the 4 canonical Track Stem Mixer stems (`vocals`, `drums`, `bass`, `melodic`) into `stems.zip` and `stem_urls`.
3. **WHEN** `svc_executed == True`, `handler.py` **SHALL** rebuild the pre-master stereo mix by summing the polished converted lead vocal back into `instrumental_bed.wav` (not by re-summing bleed-prone `htdemucs` stems) and also update `stem_paths["vocals"]` so the Stem Mixer plays the cloned vocal.

---

## 3. Neural `Seed-VC` Singing Voice Conversion Requirements (`REQ-P82-SVC-*`)

### `REQ-P82-SVC-01` — Neural `Seed-VC` Flow-Matching + RMVPE F0 Pitch Locking
1. `seed_vc_worker.py#convert_vocal_stem_with_seed_vc(...)` **SHALL** replace the Phase 26 scalar gain stub (`audio_in * gain_scale + 0.08 * diff`) with a 3-tier execution path:
   - **Tier 1 (RunPod GPU Neural):** Load `Seed-VC` diffusion flow-matching + `RMVPE` F0 extractor (cached under `/runpod-volume/seed_vc_cache`) conditioned on the creator's downloaded 3-line reference WAV (`temp_ref_path`).
   - **Tier 2 (Headless Reference Spectral Transfer Fallback):** When neural `seed_vc` checkpoints are absent (CPU tests / dev), decode `temp_ref_path` into a real spectral envelope (`rfft` formant profile) and apply pitch-preserving spectral timbre matching + F0 envelope lock onto the input vocal rather than discarding `temp_ref_path`.
   - **Tier 3 (Clean Polish-Only Fallback):** When neither neural weights nor reference WAV bytes exist, apply Bantu consonant protection + studio vocal polish cleanly.
2. `seed_vc_worker.py` **SHALL** use `read_wav_float32` / `write_wav_float32` from `model_router.py` so `wrote_output_file == True` on both Linux GPU containers and Windows CPU hosts.
3. The return dictionary **SHALL** include `svc_engine` (`"seed_vc_neural"` | `"seed_vc_spectral_fallback"`), `f0_method` (`"rmvpe"`), `isolation_engine` (`"bs_roformer"` | `"htdemucs"`), `reference_decoded` (`bool`), `similarity_score` (`float` in `[0.0, 1.0]`), and `bantu_transients_preserved` (`bool`).

### `REQ-P82-SVC-02` — Bantu Click/Plosive Preservation, `6.5 kHz` De-Essing & Stereo Room Glue
1. **WHERE** `preserve_bantu_clicks == True` (default), `seed_vc_worker.py` **SHALL** compute the $2.8\text{ kHz}$ high-pass $10\text{ ms}$ transient onset mask (`M[n]`) from the source lead vocal and blend sharp Tshivenda plosives (`ṋ, ḓ, ṱ, ḽ`) and Nguni clicks (`c, q, x`) cleanly back into the converted vocal (`alpha_click <= 0.35`).
2. Immediately following conversion, `polish_converted_vocal_stem(audio, sr)` **SHALL** apply server-side `Pedalboard` `6.5 kHz` de-essing (`PeakFilter(6500 Hz, -2.8 dB, Q=3.2)` + high-pass `85 Hz`) and subtle stereo room glue (`12 ms` decorrelated Haas side tap at `-18 dB`) before re-summing into the instrumental bed.

---

## 4. Broadcast Reference Mastering Requirements (`REQ-P82-MASTER-*`)

### `REQ-P82-MASTER-01` — Curated 6-Genre SA Reference Mastering (`Matchering 2.0` + `pyloudnorm`)
1. `stem_mastering_worker.py` **SHALL** define `SA_REFERENCE_MASTER_PROFILES` mapping genres to the 6 canonical Vhunambi reference WAV keys:
   - `amapiano_club` (`ref_masters/amapiano_club_ref.wav`)
   - `private_school_amapiano` (`ref_masters/private_school_amapiano_ref.wav`)
   - `afro_fusion_radio` (`ref_masters/afro_fusion_radio_ref.wav`)
   - `gospel_choir` (`ref_masters/gospel_choir_ref.wav`)
   - `maskandi_acoustic` (`ref_masters/maskandi_acoustic_ref.wav`)
   - `gqom_durban` (`ref_masters/gqom_durban_ref.wav`)
2. `resolve_sa_reference_wav(genre, cache_dir)` **SHALL** check `/runpod-volume/ref_masters/<filename>`, attempt R2 CDN fetch (`R2_PUBLIC_BASE_URL/ref_masters/<filename>`), and deterministically synthesize a spectrally calibrated royalty-free studio reference WAV on disk when remote storage is unpopulated.
3. `master_with_sa_reference_matchering(wav_path, genre, mastering_mode='streaming', target_lufs=None, true_peak_db=-1.0, target_sr=44100)` **SHALL**:
   - Resolve `target_lufs = -9.0` when `mastering_mode == 'club'` and `-14.0` when `mastering_mode == 'streaming'` (unless explicit `target_lufs` override is passed).
   - Execute `matchering.process(...)` (`GPL-3.0` server-side) when `matchering` is installed, or deterministic multiband spectral/RMS tilt transfer against the reference WAV on offline hosts.
   - Apply final `pyloudnorm` loudness trim + soft-knee true-peak ceiling (`<= -1.0 dBTP`) and return rich `mastering_metrics` (`mode`, `engine`, `reference_profile`, `target_lufs`, `integrated_lufs`, `true_peak_dbtp`, `sample_rate_hz`, `bit_depth: 24`).

### `REQ-P82-MASTER-02` — `handler.py` Integration Across Winning & Secondary Takes
1. **WHEN** `user_recipe` is omitted on a Studio Bake, `handler.py` **SHALL** run `master_with_sa_reference_matchering(...)` on the winning take (and secondary takes at the same `target_lufs` so multi-take loudness matches cleanly).
2. **WHEN** `user_recipe` IS explicitly supplied (Tier-B Mastering Studio), `handler.py` **SHALL** preserve `_execute_mastering_pipeline` 4-stem mastering behavior while normalizing output metrics (`sample_rate_hz`, `integrated_lufs`, `true_peak_dbtp`).
3. `handler.py` **SHALL** stamp `mastering_metrics`, `svc_metrics`, and `sample_rate_hz` onto `manifest_payload`, `final_payload`, and the `completed` HMAC webhook.

---

## 5. Worker API, MMO v2.0 & Flutter Provenance Requirements (`REQ-P82-WIRE-*`, `REQ-P82-CLIENT-*`)

### `REQ-P82-WIRE-01` — Cold-Isolate Voice Clone Hydration & Safe Tier-B Mastering Route
1. `POST /v1/generations` (`generation_routes.ts`) **SHALL** accept optional `masteringMode: 'streaming' | 'club'` (default `'streaming'`) and `sampleRateHz: 44100 | 48000` (default `44100`), forward them to `runpod_adapter.ts`, and await `vhunambiDb.syncVoicesFromCloud(false, c)` when `!isNodeSqliteAvailable()` and `effectiveCloneId` is set before reading `getVoiceCloneProfile(effectiveCloneId)`.
2. `StemMasteringRecipeSchema` (`mastering_types.ts`) **SHALL** accept `targetLufs` in `[-9.0, -9.5, -14.0]` (preserving `-9.5` backward compatibility for Phase 25 tests while supporting `-9.0` Club & `-14.0` Streaming).
3. `POST /v1/generations/:id/master` (`generation_routes.ts`) **SHALL** preserve real R2 asset URLs when `job.masterMp3Url` already points to R2 (never overwriting live HTTPS R2 URLs with dead `/mock-storage/...` paths), attach `masteringMetrics` (`targetLufs`, `integratedLufs`, `truePeakDbtp`, `presetId`, `referenceProfile`) onto the enriched MMO manifest, and optionally dispatch `dispatchMasteringJob` when `job.masterMp3Url` is a live R2 asset and RunPod credentials are configured.

### `REQ-P82-WIRE-02` — MMO v2.0 Mastering/SVC Telemetry & Enriched Deferred Ready Alert
1. `MasterMediaObjectManifest` (`dna_types.ts`) and `GenerationJob` (`job_types.ts`) **SHALL** include optional `masteringMetrics` and `svcMetrics` payloads persisted by `webhook_routes.ts` and `generation_routes.ts` (`GET /v1/generations/:id` and `GET /v1/generations/:id/manifest`).
2. `notifyGenerationCompletedOnce` (`job_store.ts`) **SHALL** include measured loudness & engine provenance in the deferred `"Studio Track Ready"` alert message and metadata (e.g., `"Mastered at -14.0 LUFS · Amapiano (180s) is ready to play."`).

### `REQ-P82-CLIENT-01` — Track Detail `"Mastered · -14 LUFS"` & `"MiniMax-Music3"` Badges (`STD-UIUX-001`)
1. `TrackDetailEntity` (`track_detail_models.dart`) **SHALL** add optional `integratedLufs` (`double?`), `masteringProfile` (`String?`), `attributionTag` (`String?`), `sampleRateHz` (`int?`), and `voiceCloneApplied` (`bool`).
2. `TrackDetailNotifier.loadManifestFromCloud` (`track_providers.dart`) **SHALL** recognize `stemUrls['melodic']` alongside `'instrumental'`/`'other'` AND hydrate `integratedLufs`, `masteringProfile`, `attributionTag`, and `sampleRateHz` from `/v1/generations/:id/manifest` into `state`.
3. `TrackSonicTelemetryCard` (`track_sonic_telemetry_card.dart`) **SHALL** render theme-adaptive provenance chips using `PhosphorIcon` (`0` stock `Icons.*`, `0` raw Unicode emojis):
   - `Key('track_mastering_provenance_chip')` showing `'Mastered · ${lufs.toStringAsFixed(1)} LUFS'` (when `integratedLufs != null`)
   - `Key('track_engine_attribution_chip')` showing `track.attributionTag!` (e.g., `'MiniMax-Music3'`, when non-empty)
   - `Key('track_voice_clone_chip')` showing `'Seed-VC Voice'` (when `voiceCloneApplied == true`)
   All wrapping cleanly without overflow at `360x800dp` in Light & Dark modes.

---

## 6. Non-Functional & Error Containment Requirements (`REQ-P82-NFR-*`, `REQ-P82-ERR-*`)

1. **`REQ-P82-NFR-01` (Zero Client GPL & `STD-UIUX-001`):** Zero GPL dependencies in `apps/vhunambi_client/pubspec.yaml`; zero stock `Icons.*` or raw emojis in Track Detail provenance chips.
2. **`REQ-P82-NFR-02` (Fast Offline Tests):** `tools/zr-studio-gpu/test_phase82_vocal_mastering.py` completes in `< 15s` on CPU-only Windows hosts without `pip` downloads; `phase82_vocal_mastering_provenance.test.ts` runs in `< 5s`; `phase82_track_provenance_test.dart` passes within `--timeout=60s`.
3. **`REQ-P82-ERR-01` (`BS-RoFormer` / `Matchering` Graceful Fallback):** If `audio-separator`, `seed_vc`, or `matchering` raises an OOM/runtime error on GPU, `handler.py` **SHALL** log the failure, fall back cleanly to `htdemucs` / spectral fallback / `master_clean_stereo_gentle`, record the truthful fallback `engine` in `mastering_metrics` / `svc_metrics`, and complete the job without crashing.
4. **`REQ-P82-ERR-02` (Phase 25/66/80/81 Zero Regression):** All existing 34 Worker API suites (including `mastering.test.ts`, `voices.test.ts`, `phase66`, `phase80`, `phase81`), Phase 81 Python router tests (`7/7`), and existing Track Detail / Studio widget tests **SHALL** remain 100% green.

---

## 7. Requirement-to-Test Traceability Matrix

| Requirement ID | Target File(s) | Automated Verification Test |
| :--- | :--- | :--- |
| `REQ-P82-UPSAMPLE-01` | `tools/zr-studio-gpu/model_router.py` | `test_phase82_vocal_mastering.py::test_32khz_to_44k1_and_48khz_upsample` |
| `REQ-P82-STEM-01` | `tools/zr-studio-gpu/mmo_extractor.py`, `handler.py` | `test_phase82_vocal_mastering.py::test_bs_roformer_lead_isolation_and_bed_resum` |
| `REQ-P82-SVC-01..02` | `tools/zr-studio-gpu/seed_vc_worker.py` | `test_phase82_vocal_mastering.py::test_seed_vc_reference_conversion_bantu_transients_and_polish` |
| `REQ-P82-MASTER-01..02` | `tools/zr-studio-gpu/stem_mastering_worker.py`, `handler.py` | `test_phase82_vocal_mastering.py::test_matchering_sa_profiles_streaming_and_club_lufs` |
| `REQ-P82-WIRE-01..02` | `generation_routes.ts`, `mastering_types.ts`, `mastering_presets.ts`, `dna_types.ts`, `webhook_routes.ts`, `job_store.ts` | `apps/vhunambi_api/test/phase82_vocal_mastering_provenance.test.ts` |
| `REQ-P82-CLIENT-01` | `track_detail_models.dart`, `track_providers.dart`, `track_sonic_telemetry_card.dart` | `apps/vhunambi_client/test/features/track/phase82_track_provenance_test.dart` |
| `REQ-P82-NFR-01..02`, `ERR-01..02` | All Phase 82 targets + Docker manifests | Full Python + 35 Worker + Flutter gates (`G82-01`..`G82-06`) |

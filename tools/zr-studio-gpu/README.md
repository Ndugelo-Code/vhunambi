# ZR Studio GPU Worker (`ndugelo/zr-studio-gpu:vhunambi-v5`)

Containerized Runpod Serverless GPU worker executing the Phase 81 Multi-Model Audio Engine (`ZRMultiModelRouter` + 5-stage DSP & MMO telemetry pipeline), Phase 82 Studio Baking Post-Processing Chain (`44.1/48 kHz` upsampling, cached `BS-RoFormer` + `onnxruntime` lead-vocal isolation, neural `Seed-VC` timbre transfer with Bantu plosive/click preservation, and 6-genre SA `Matchering 2.0` + `pyloudnorm` broadcast mastering), Phase 83 Post-Generation Section Repaint & Sovereign African LoRA Activation, and Phase 85 Cloud LoRA Factory (`job_type="lora_dataset_prep"` & `job_type="lora_train_peft"` under `/app/training/`):

0. **Multi-Model Router (`model_router.py` — `:vhunambi-v5` on `48 GB+` GPU Pools)**:
   - **`minimax_music_3` (`MiniMaxAI/MiniMax-Music3`, `<= 300s` sweet spot / `360s` hard cap):** Primary Studio Bake engine for vocal songs, duets (`[Voice A]`/`[Voice B]`), and arrangement tags (`[Log Drum Drop]`, `[Guitar Solo]`), emitting `32 kHz` WAV cleanly upsampled via `soxr` (`441/320` polyphase) to `44.1 kHz` with mandatory `"MiniMax-Music3"` attribution.
   - **`ace_step_xl_sft` / `ace_step_xl_base` / `ace_step_xl_turbo` (`ACE-Step 1.5 XL` — `MIT` License):** Handles instrumentals (shielding `sglang-omni` from HTTP `400`), Reference Audio / Seed-VC voice cloning (`xl-base` + `/runpod-volume/lora_cache`), section repaint/lego/complete, and rapid `12`-step drafts (`xl-turbo`). Strictly **zero `YuE2` (`CC BY-NC 4.0`)**.
   - **Multi-Take A&R Scorer:** Renders `1..4` unique crypto-seeded takes (`audio/{job_id}/take_{i}.mp3`), scores across non-silence, crest-factor pocket, vocal presence, and anti-clipping, and promotes the highest-scoring take to `master.mp3`.
   - **Cloud LoRA Factory (`/app/training/` — Phase 85):** Runs `dataset_prep_worker.py` (with cached `_ROFORMER_SEP_CACHE` + `onnxruntime` BS-RoFormer vocal isolation) and real PyTorch `bf16` PEFT rectified flow-matching `train_lora.py` outputting dual-format `.safetensors` + embedded PEFT metadata to Cloudflare R2 `zr-studio-audio/loras/` (`prefix=None` & `materialize_peft_dir_from_safetensors` reload-verified in `model_utils.py`).

1. **Stage 1 (`ace_step_synthesis`)**: Neural music synthesis via **ACE-Step 1.5** (`bf16` precision) with dynamic genre LoRA adapter hot-loading (`loras/*.safetensors` fetched from Cloudflare R2 to `/tmp/zr_lora_cache`, 6 trained & active packs live), Latin-script Bantu language guard (prevents `LangSegment` CJK misclassification), and ACE-Step lyric sanitizer (strips non-structural brackets). Fallback: `zr_harmonic_multi_stem_synthesizer`.
2. **Stage 2 (`demucs_stem_separation`)**: 4-stem (`bass`, `drums`, `vocals`, `melodic`) separation via Hybrid Demucs (`htdemucs`) with zero-crossing phase alignment. **Used ONLY for Stem Mixer deck — NOT for master re-summing.**
3. **Stage 3 (`seed_vc_voice_conversion`)**: Optional zero-shot vocal timbre transfer via Seed-VC when `voiceModelId` is requested (`executed: false` when omitted).
4. **Stage 4 (`stem_mastering_dsp`)**: Two mastering paths — (a) **SA Reference Matchering 2.0 / Gentle clean path**: 28 Hz high-pass → `−14.0 LUFS` streaming (or `−9.0 LUFS` club) → soft-knee true-peak at `−1.0 dBTP`; (b) **Mastering Studio path**: existing 4-stem EQ + user-recipe DSP chain when `user_recipe` is explicitly provided.
5. **Stage 5 (`mmo_telemetry_extraction`)**: 60 Hz frame-by-frame vectorscope stereo correlation, 32-band FFT, sub-bass mono correlation, crest factor, and dynamic range telemetry uploaded to R2 as `manifests/{stem_prefix}_measured_mmo.json` (`schemaVersion: "2.0"`, `provenance: "measured"`).

> **v5 Key Changes (2026-11-25):** Built via **Docker Build Cloud (`cloud-ndugelo-vhunambi`)** on top of `:vhunambi-v4` using `Dockerfile.delta` — adds `onnxruntime-1.32.0` (for `audio-separator` BS-RoFormer), Phase 85 `/app/training/` (`validate_dataset.py`, `dataset_prep_worker.py`, `train_lora.py`), `model_utils.py` (`prefix=None` + PEFT directory reconstruction), and `mmo_extractor.py` (`_ROFORMER_SEP_CACHE`).

---

## Live Production Deployment (`zr-studio-prod`)

- **Runpod Serverless Endpoint ID**: `e7wt9pgo7djv55` (Release Version `10` — `cmwwbvx3x00pdoobay79034wy`)
- **Docker Hub Image**: `ndugelo/zr-studio-gpu:vhunambi-v5` (`sha256:e80ff29e2295ed8388e0bcd51bb9fc8430be64d75a1b384054ed72c8b62309e7`)
- **Previous Image**: `ndugelo/zr-studio-gpu:vhunambi-v4` (`sha256:08733bfc379c44185b0ee390e6d662c51e12e3f86d1f521ae5eac4c5ecd564be`)
- **Active Sovereign R2 LoRA Packs (6/6 Ready Packs Trained on RunPod `NVIDIA A40` & Promoted Active in Supabase `cbnruevwrqwjnnoscgsz`)**:
  - `amapiano_logdrum_v1`, `amapiano_private_school_v1`, `venda_malende_v1`, `afrohouse_ancestral_v1`, `afrobeats_lagos_v1`, `bantu_vocals_v1`
- **Container Disk**: `40 GB`
- **Workers Configuration**: `min: 0`, `max: 1`, `idleTimeout: 5s`, `timeout: 1200000 ms`, `flashboot: FLASHBOOT`
- **GPU Pools**: `ADA_48_PRO`, `AMPERE_48`, `AMPERE_80`
- **Cloudflare API Worker**: `https://vhunambi-api.ndugelosigwadi.workers.dev`
- **Operational Skill**: `.agents/skills/vhunambi-cloud-gpu-factory/SKILL.md`

### Verified Live E2E Neural Benchmark (2026-11-13, NVIDIA GeForce RTX 4090)

| Metric | Verified Production Value |
| :--- | :--- |
| **Generation ID** | `gen_1794592961751_fYwxtuyf` |
| **Runpod Job ID** | `55e360e7-7b61-427e-af42-802613ca8a60-e2` |
| **Worker / GPU** | `cyzvw06ap66gbw` (`NVIDIA GeForce RTX 4090`, `US-TX-3`) |
| **Queue / Cold-Start Delay** | `110,204 ms` |
| **Total GPU Execution Time** | `76,372 ms` |
| **Stage 1 (`ace_step_synthesis`)** | `40,198 ms` (`engine: "ace_step_1_5_bf16"`, `precision: "bf16"`, `infer_steps: 45`, `active_lora: "loras/amapiano_logdrum_v1.safetensors"`, `lora_weight: 0.85`) |
| **Stage 2 (`demucs_stem_separation`)** | `1,247 ms` (`executed: true`, 4 WAV stems uploaded) |
| **Stage 3 (`seed_vc_voice_conversion`)** | `0 ms` (`executed: false`, `voice_model_id: null`) |
| **Stage 4 (`stem_mastering_dsp`)** | `1,888 ms` (`integrated_lufs: -9.5`, `true_peak_dbtp: -0.8`, `master.mp3`: `481,741` bytes, `stems.zip`: `11,668,980` bytes) |
| **Stage 5 (`mmo_telemetry_extraction`)** | `16,781 ms` (`schemaVersion: "2.0"`, `provenance: "measured"`, `sampleRateHz: 60`, `frameCount: 718`) |

---

## Key Compatibility & Stability Safeguards (`:vhunambi-v2`)

1. **`py3langid==0.3.0` Pin (`Dockerfile`)**:
   - `LangSegment 0.3.5` (imported by `ace_step.models.lyrics_utils.lyric_tokenizer.VoiceBpeTokenizer`) calls `LanguageIdentifier.from_pickled_model(...)`, which was removed in `py3langid 0.4.0`.
   - `Dockerfile` strictly pins `py3langid==0.3.0` after installing `ACE-Step` and runs a build-time smoke test (`from ace_step.models.lyrics_utils.lyric_tokenizer import VoiceBpeTokenizer`) so broken dependency upgrades fail at image build time.
2. **PyTorch 2.10 `torchaudio.save` / `torchaudio.load` Fallback (`model_utils.py`)**:
   - PyTorch `2.10.0+cu128` routes `torchaudio.save` through `torchcodec` by default.
   - `_install_torchaudio_soundfile_compat()` in `model_utils.py` wraps `torchaudio.save` and `torchaudio.load` with a deterministic `soundfile` fallback so `ACEStepPipeline.save_wav_file` succeeds on headless CUDA workers without `torchcodec`.
3. **Cold-Start Queue Resilience (`apps/vhunambi_api/src/routes/generation_routes.ts`)**:
   - When `workers.min = 0`, Runpod Serverless takes ~60–115s to allocate a GPU node and unpack the container before switching from `IN_QUEUE` to `IN_PROGRESS`.
   - `generation_routes.ts` waits up to `240,000 ms` (`4 minutes`) when `workersMax > 0` before triggering simulation fallback.

---

## Required Runtime Environment Variables (Runpod Template / Endpoint)

Configure these on the Runpod template (`b2ll2430dd`) or endpoint (`e7wt9pgo7djv55`):

| Variable | Description | Example / Default |
| :--- | :--- | :--- |
| `R2_BUCKET` | Target Cloudflare R2 bucket name | `zr-studio-audio` |
| `R2_BUCKET_NAME` | Alias for R2 bucket name | `zr-studio-audio` |
| `R2_PUBLIC_BASE_URL` | Public R2 CDN base URL | `https://pub-d22409017abb4dd999327a092c5f06d3.r2.dev` |
| `R2_ACCOUNT_ID` | Cloudflare Account ID | `<cloudflare-account-id>` |
| `R2_ENDPOINT` | S3-compatible Cloudflare R2 endpoint URL | `https://<account-id>.r2.cloudflarestorage.com` |
| `R2_ACCESS_KEY_ID` | R2 S3 Access Key ID | `<r2-access-key-id>` |
| `R2_SECRET_ACCESS_KEY` | R2 S3 Secret Access Key | `<r2-secret-access-key>` |
| `ZR_WEBHOOK_SECRET` | Shared HMAC/Bearer webhook secret for `/v1/webhooks/runpod` | `<webhook-secret>` |
| `ACE_STEP_PRECISION` | Precision mode for ACE-Step 1.5 (`bf16` or `fp16`) | `bf16` |
| `ZR_LORA_CACHE_DIR` | Local ephemeral directory for R2-fetched `.safetensors` LoRAs | `/tmp/zr_lora_cache` |

---

## Building & Pushing Safely (Docker Build Cloud — Primary, Zero Local Pull)

GitHub Actions is bypassed in favor of **Docker Build Cloud** (`cloud-ndugelo-vhunambi`) so the 8 GB RAM / 1 TB HDD Windows workstation only uploads the `~0.59 MB` `./tools` build context while Docker's remote 8-core / 16 GB `linux/amd64` builder layers `Dockerfile.delta` and pushes straight to Docker Hub:

1. Start **Docker Desktop** (signed into `ndugelo`). Ensure the cloud builder is attached once:
   ```powershell
   docker buildx create --use --driver cloud ndugelo/vhunambi
   ```
2. Build & push an **explicit new semantic tag** (`:vhunambi-v6`, never overwrite an active tag because RunPod caches tags per host node) from the monorepo root:
   ```powershell
   docker buildx build --builder cloud-ndugelo-vhunambi --platform=linux/amd64 --provenance=false -f tools/zr-studio-gpu/Dockerfile.delta -t ndugelo/zr-studio-gpu:vhunambi-v6 --push ./tools
   ```
3. Roll out safely on RunPod endpoint `e7wt9pgo7djv55` by PATCHing **only** `{"image": "ndugelo/zr-studio-gpu:vhunambi-v6"}` (omit `env` and `gpu` so live R2/webhook secrets are never overwritten by `[redacted]`).

> **Local Fallback:** If building locally via `--builder desktop-linux`, keep `C:\Users\Ndugelo\.wslconfig` capped (`memory=2GB`, `processors=2`, `swap=4GB`) and always build `Dockerfile.delta` (never the full `Dockerfile`).

---

## Testing Live GPU Generations from the Flutter Client

The Flutter client (`apps/vhunambi_client`) defaults to `http://localhost:8787` in local debug builds unless `API_BASE_URL` is supplied via `--dart-define`. To connect the app directly to the live Cloudflare Worker + Runpod GPU pipeline:

```powershell
cd apps/vhunambi_client
flutter run -d windows --dart-define=API_BASE_URL=https://vhunambi-api.ndugelosigwadi.workers.dev
```

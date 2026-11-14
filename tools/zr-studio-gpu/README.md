# ZR Studio GPU Worker (`ndugelo/zr-studio-gpu:vhunambi-v2`)

Containerized Runpod Serverless GPU worker executing the 5-stage ZR Studio neural audio & MMO telemetry pipeline:

1. **Stage 1 (`ace_step_synthesis`)**: Neural music synthesis via **ACE-Step 1.5 (3.5B)** (`bf16` precision) with dynamic genre LoRA adapter hot-loading (`loras/*.safetensors` fetched from Cloudflare R2 to `/tmp/zr_lora_cache`) and deterministic harmonic multi-stem fallback (`zr_harmonic_multi_stem_synthesizer`) if weights are unavailable.
2. **Stage 2 (`demucs_stem_separation`)**: 4-stem (`bass`, `drums`, `vocals`, `melodic`) separation via Hybrid Demucs (`htdemucs`) with zero-crossing phase alignment.
3. **Stage 3 (`seed_vc_voice_conversion`)**: Optional zero-shot vocal timbre transfer via Seed-VC when `voiceModelId` is requested (`executed: false` when omitted).
4. **Stage 4 (`stem_mastering_dsp`)**: ITU-R BS.1770-4 loudness normalization (`pyloudnorm`) and soft-knee true-peak limiting (`-9.5 LUFS` integrated, `-0.8 dBTP` ceiling) plus 320 kbps CBR MP3 master encoding (`ffmpeg`) and multi-track `.stems.zip` packaging.
5. **Stage 5 (`mmo_telemetry_extraction`)**: 60 Hz frame-by-frame vectorscope stereo correlation, 32-band FFT, sub-bass mono correlation, crest factor, and dynamic range telemetry uploaded to R2 as `manifests/{stem_prefix}_measured_mmo.json` (`schemaVersion: "2.0"`, `provenance: "measured"`).

---

## Live Production Deployment (`zr-studio-prod`)

- **Runpod Serverless Endpoint ID**: `e7wt9pgo7djv55` (Version `6`)
- **Docker Hub Image**: `ndugelo/zr-studio-gpu:vhunambi-v2`
- **Image Digest**: `sha256:c5f35636bee0f9a8283161a6ec868756160679deef1881d5c4a82025fe4cf442`
- **Container Disk**: `30 GB`
- **Workers Configuration**: `min: 0`, `max: 1`, `idleTimeout: 5s`, `executionTimeoutMs: 600000`
- **GPU Pools**: `ADA_24` (RTX 4090), `AMPERE_24` (RTX 3090 / A5000), `AMPERE_16` (RTX A4000 / A4500), `AMPERE_48` (A40 / RTX A6000), `ADA_48_PRO` (RTX 6000 Ada / L40 / L40S)
- **Excluded GPU Types**: `NVIDIA RTX PRO 6000 Blackwell Server Edition MIG 1g.24gb`, `NVIDIA RTX PRO 6000 Blackwell Server Edition MIG 2g.48gb`
- **Cloudflare API Worker**: `https://vhunambi-api.ndugelosigwadi.workers.dev` (Version `89d35faa-ad36-4fdc-843c-126b89f460d4`)

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

## Building & Pushing Safely (Low-RAM / 8 GB Windows Host)

If rebuilding on a constrained 8 GB RAM Windows machine with a mechanical HDD:
1. Keep `.wslconfig` capped (`memory=2GB`, `processors=2`, `swap=4GB`) and Docker Desktop configured with `"max-concurrent-uploads": 1` so the large PyTorch/CUDA layers push sequentially without exhausting RAM or bandwidth.
2. Build and push with provenance disabled (avoids double-manifest uploads):

```powershell
cd tools/zr-studio-gpu
docker buildx build --provenance=false -t ndugelo/zr-studio-gpu:vhunambi-v2 --push .
```

---

## Testing Live GPU Generations from the Flutter Client

The Flutter client (`apps/vhunambi_client`) defaults to `http://localhost:8787` in local debug builds unless `API_BASE_URL` is supplied via `--dart-define`. To connect the app directly to the live Cloudflare Worker + Runpod GPU pipeline:

```powershell
cd apps/vhunambi_client
flutter run -d windows --dart-define=API_BASE_URL=https://vhunambi-api.ndugelosigwadi.workers.dev
```

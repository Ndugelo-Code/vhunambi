# Tier 2 Cloud GPU Worker: `ndugelo/zr-studio-gpu:vhunambi-v1`

> **Role:** RunPod Serverless Audio Synthesis (ACE-Step 1.5), Demucs 4-Stem Separation, 320 kbps MP3 Export, and Measured MMO Manifest Generation.  
> **API Consumer:** `apps/vhunambi_api/src/routes/webhook_routes.ts`  
> **Client Consumer:** `apps/vhunambi_client` (Pocket DAW `StemMixerDeck`, `JustAudioMultiStemEngine`, `KineticPreviewCanvas`).

---

## 1. What Changes in v2?

| Feature | v1 (Legacy) | v2 (Measured Tier) |
|---|---|---|
| **Audio Output** | Master MP3 only | Master MP3 + 4 isolated WAV stems (`vocals`, `drums`, `bass`, `melodic`) |
| **Stems Bundle** | None (`undefined`) | `stems.zip` uploaded to Cloudflare R2 |
| **MMO Provenance** | `synthesized` (BPM grid approximation) | `measured` (True Demucs separation + Librosa spectral RMS) |
| **Drift & Transients** | Estimated | Measured onset detection (`kick`, `log_drum_drop`, `vocal_onset`) |
| **MPC Slices** | Fixed temporal slices | Audio zero-crossing snapped slices (zero pop/click artifacts) |
| **Client DAW Deck** | "Master Only" Mode | **Unlocked 4-Channel Live Pocket DAW** |

---

## 2. Environment Variables Required on RunPod Serverless

Set these in your RunPod Endpoint Environment Variables:

| Variable | Description | Example |
|---|---|---|
| `ZR_WEBHOOK_SECRET` | Shared HMAC-SHA256 secret for signing webhook callbacks (`x-zrs-signature`) | `zr_sec_xxxxxxxxxxxx` |
| `R2_ACCOUNT_ID` | Cloudflare account ID | `xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` |
| `R2_ACCESS_KEY_ID` | Cloudflare R2 access key with Write permissions | `xxxxxxxxxxxxxxxxxxxxxxxx` |
| `R2_SECRET_ACCESS_KEY` | Cloudflare R2 secret key | `xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` |
| `R2_BUCKET_NAME` | Active Cloudflare R2 bucket name | `zr-studio-audio` |
| `R2_PUBLIC_BASE_URL` | Public CDN base URL for R2 bucket | `https://pub-d22409017abb4dd999327a092c5f06d3.r2.dev` |

> **Current Endpoint Standings (2026-11-13):**
> - Active RunPod Serverless Endpoint ID: `e7wt9pgo7djv55` (Scale-to-Zero enabled: `Min Workers = 0`, woken automatically by `POST /v2/e7wt9pgo7djv55/run`).
> - **Cloud Docker Build:** [`Dockerfile`](./Dockerfile) layers onto `ndugelo/zr-studio-gpu:latest`, copies `model_utils.py`, `mmo_extractor.py`, `stem_mastering_worker.py`, `seed_vc_worker.py`, and `handler.py`, and configures `HF_HOME` for `/runpod-volume/hf_cache` (with `/tmp/hf_cache` fallback). Built & pushed automatically to `ndugelo/zr-studio-gpu:vhunambi-v1` via [`push_gpu_worker.yml`](../../.github/workflows/push_gpu_worker.yml).

---

## 3. Build & Deploy Instructions

```bash
cd tools/zr-studio-gpu

# 1. Build the Docker container
docker build -t ndugelo/zr-studio-gpu:v2 .

# 2. Test locally
docker run --gpus all -it --rm -p 8000:8000 ndugelo/zr-studio-gpu:v2

# 3. Push to Docker Hub
docker push ndugelo/zr-studio-gpu:v2

# 4. In RunPod Console (https://runpod.io/console/serverless):
# - Update the Endpoint container image to: ndugelo/zr-studio-gpu:v2
# - Ensure GPU type is set (e.g. RTX 4090 or L4 with >= 16GB VRAM)
```

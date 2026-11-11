# Tier 2 Cloud GPU Worker: `ndugelo/zr-studio-gpu:v2`

> **Role:** RunPod Serverless Audio Synthesis, Demucs 4-Stem Separation, and Measured MMO Manifest Generation.  
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

> **Current Endpoint Standings (2026-11-12):**
> - Active RunPod Serverless Endpoint ID: `e7wt9pgo7djv55` (currently `0` online workers until scaled/enabled in RunPod Console).
> - **Docker Build Note:** [`Dockerfile`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/tools/zr-studio-gpu/Dockerfile#L21-L24) copies `mmo_extractor.py`, `stem_mastering_worker.py`, `seed_vc_worker.py`, and `handler.py`, but does not currently copy `model_utils.py`. Unless the active container image (`ndugelo/zr-studio-gpu:v2`) already packages `model_utils.py` and ACE-Step weights, Stage 1 catches the `ImportError` in [`handler.py`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/tools/zr-studio-gpu/handler.py#L116-L129) and falls back to synthesizing a 55Hz/110Hz sine-wave carrier before running Demucs, mastering, and MMO extraction.

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

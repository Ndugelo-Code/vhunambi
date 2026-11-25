---
name: vhunambi-cloud-gpu-factory
description: >-
  End-to-end operational runbook for Vhunambi's Cloud GPU Audio Engine, Docker
  Build Cloud delta image pipeline, RunPod Serverless rollouts, On-Demand GPU
  Pod PEFT LoRA training, and Multi-Model Audio Architecture (Phases 81-85).
  Use this skill whenever building or pushing `ndugelo/zr-studio-gpu` images
  via Docker Build Cloud (`cloud-ndugelo-vhunambi`), rolling out RunPod
  endpoint `e7wt9pgo7djv55` (`zr-studio-prod`), training or promoting Sovereign
  African `.safetensors` LoRA adapters on RunPod Pods into Cloudflare R2 and
  Supabase, or modifying `tools/zr-studio-gpu/` and `tools/zr-studio-training/`.
---

# Vhunambi Cloud GPU, Docker Build Cloud & LoRA Factory (`vhunambi-cloud-gpu-factory`)

> **Why this skill exists:** The Vhunambi dev workstation is an **8 GB RAM / 1 TB HDD / Intel Iris Xe** Windows host, and GitHub Actions billing is bypassed in favor of **Docker Build Cloud** + **RunPod**. Every command and guardrail below was live-verified across Phases 81–85 so future sessions never thrash local disk/RAM, break RunPod secrets, ship broken LoRA adapters, or violate model licenses.

For full model routing specs, licensing matrices, and LoRA pack inventories, load [references/models_and_lora_playbook.md](./references/models_and_lora_playbook.md).

---

## 1. Canonical Live Production Infrastructure Map

| Layer | Live Identifier | Current Verified State |
| :--- | :--- | :--- |
| **Docker Build Cloud Builder** | `cloud-ndugelo-vhunambi` (`ndugelo/vhunambi`) | Remote `linux/amd64` + `linux/arm64` builder (uploads only `~0.59 MB` `./tools` context; zero local base image pull) |
| **Docker Hub Image** | `ndugelo/zr-studio-gpu:vhunambi-v5` | `sha256:e80ff29e2295ed8388e0bcd51bb9fc8430be64d75a1b384054ed72c8b62309e7` (`Dockerfile.delta` on `:vhunambi-v4`) |
| **RunPod Serverless Endpoint** | `e7wt9pgo7djv55` (`zr-studio-prod`) | Release `v10`, `FLASHBOOT`, `disk: 40 GB`, `timeout: 1200000 ms`, `min: 0 / max: 1`, pools: `ADA_48_PRO`, `AMPERE_48`, `AMPERE_80` |
| **RunPod Registry Link** | `cmm91271y00h6jp07lmi0eepk` | `docker.io` (`ndugelo`) |
| **Cloudflare R2 Bucket** | `zr-studio-audio` | Public CDN `https://pub-d22409017abb4dd999327a092c5f06d3.r2.dev` — stores `loras/*.safetensors`, `training-data/curated/{lora_id}/`, `audio/`, `manifests/` |
| **Supabase Project** | `cbnruevwrqwjnnoscgsz` | Tables `public.lora_registry` (11 seeded packs; 6 active), `public.lora_dataset_tracks`, `public.lora_training_jobs`, `public.generation_jobs` |
| **Cloudflare API Worker** | `vhunambi-api.ndugelosigwadi.workers.dev` | Orchestrates `/v1/generations*`, `/v1/studio/loras*`, `/v1/webhooks/ace-step`, `/v1/webhooks/training` |

---

## 2. Docker Build Cloud Delta Build & Push Workflow (Primary)

**NEVER** run a full build of `tools/zr-studio-gpu/Dockerfile` on the local 8 GB Windows laptop, and **NEVER** reuse an active mutable tag (RunPod hosts cache image tags per node and will silently run stale workers).

### Step 2.1 — Pre-Flight Local Checks (Always Before Building)
1. Ensure Docker Desktop is running (`docker version`) and signed into `ndugelo` (`docker-credential-desktop list`).
2. Confirm the cloud builder is registered:
   ```powershell
   docker buildx ls
   ```
   If `cloud-ndugelo-vhunambi` is not listed, reconnect it (never re-create in dashboard once provisioned):
   ```powershell
   docker buildx create --use --driver cloud ndugelo/vhunambi
   ```
3. Run fast CPU-safe unit tests locally before uploading `./tools`:
   ```powershell
   python -m unittest discover -s tools/zr-studio-training/tests -v
   ```
4. Verify `./tools` has no stray large datasets or checkpoints (should stay `< 5 MB`; currently `~0.59 MB`).

### Step 2.2 — Update `tools/zr-studio-gpu/Dockerfile.delta`
- Keep `ARG BASE_IMAGE=ndugelo/zr-studio-gpu:vhunambi-v5` (pointing at the previous live tag so `pip` skips already-installed wheels).
- Always keep `"onnxruntime>=1.18.0"`, `"peft>=0.13.0"`, `"safetensors>=0.4.5"`, `"pyyaml>=6.0.1"`, `"soxr>=0.4.0"`, `"matchering>=2.0.6"`, and `"audio-separator>=0.24.0"` declared.
- Always keep the `RUN python -m py_compile ...` step covering every copied file in `/app/` and `/app/training/` so syntax errors fail at build time.

### Step 2.3 — Build & Push a New Explicit Tag (`:vhunambi-v<N>`)
Run from the monorepo root (`c:\Users\Ndugelo\VHUNAMBI\monorepo`):
```powershell
docker buildx build `
  --builder cloud-ndugelo-vhunambi `
  --platform=linux/amd64 `
  --provenance=false `
  -f tools/zr-studio-gpu/Dockerfile.delta `
  -t ndugelo/zr-studio-gpu:vhunambi-v6 `
  --push ./tools
```
- `--platform=linux/amd64` is mandatory (RunPod hosts are x86_64 Linux).
- `--provenance=false` prevents multi-manifest bloat and keeps RunPod pulls clean.
- Record the pushed `sha256:...` digest from the build log.

### Local Fallback (Only If Docker Build Cloud Is Unavailable)
`C:\Users\Ndugelo\.wslconfig` caps WSL2 (`memory=2GB`, `processors=2`, `swap=4GB`) so `--builder desktop-linux` will not crash Windows, **but** the first local build pulls multi-GB base layers onto the HDD. Prefer `cloud-ndugelo-vhunambi`.

---

## 3. RunPod Serverless Safe Rollout Protocol (`e7wt9pgo7djv55`)

> **CRITICAL DESTRUCTIVE GOTCHA:** RunPod's `update-endpoint` PATCH replaces the **entire** `env` map if `env` is present in `body`, and `get-endpoint` masks secrets as `"[redacted]"`. Sending `env` back overwrites live R2/webhook secrets with the literal string `"[redacted]"`! Similarly, sending `gpu.pools` without `gpu.excludedTypes` wipes exclusions.

### Safe Image-Only Rollout Sequence
1. Call `runpod:update-endpoint` with **ONLY** `image` in `body`:
   ```json
   {
     "id": "e7wt9pgo7djv55",
     "body": {
       "image": "ndugelo/zr-studio-gpu:vhunambi-v6"
     }
   }
   ```
2. Verify rollout completion & worker health immediately:
   - `runpod:list-endpoint-releases` with `{"id": "e7wt9pgo7djv55"}` → confirm `endpointVersion` incremented, `diff` shows only `template.imageName`, and `rollout.percentOnLatest == 100`.
   - `runpod:endpoint-health` with `{"endpointId": "e7wt9pgo7djv55"}` → confirm `unhealthy == 0`.
   - *(Tool-schema gotcha: `endpoint-health` takes `endpointId`, while `get-endpoint`, `update-endpoint`, and `list-endpoint-releases` take `id`.)*

---

## 4. On-Demand RunPod GPU Pod Training & LoRA Promotion Workflow

Use an on-demand GPU Pod when batch-training multiple Sovereign African LoRA packs (`train_lora.py`) or running heavy BS-RoFormer dataset prep (`dataset_prep_worker.py`) directly against Cloudflare R2 (`zr-studio-audio`) without serverless 20-minute timeouts.

### Step 4.1 — Provision & Cost-Guard Rules
1. Check current spend/state first: `runpod:get-balance` and `runpod:list-pods`.
2. Provision **Secure Cloud** `NVIDIA A40` (`48 GB VRAM`, `~$0.59/hr`) or `L40S` using `ndugelo/zr-studio-gpu:vhunambi-v5` (which already includes `torch 2.10+cu128`, `ace_step`, `peft`, `safetensors`, `pyyaml`, `audio-separator`, and `onnxruntime`).
3. Pass R2 credentials (`R2_ENDPOINT`, `R2_BUCKET`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_PUBLIC_BASE_URL`) as Pod runtime env vars — **never bake secrets into Docker layers or git**.

### Step 4.2 — Dataset Prep, Training & Reload Verification
1. **Prep (`dataset_prep_worker.py`):** Converts R2 catalog MP3/M4A/FLAC tracks into validated `44.1 kHz / 24-bit` stereo WAV + NFC-normalized JSON sidecars in `training-data/curated/{lora_id}/` (using cached `_ROFORMER_SEP_CACHE` BS-RoFormer isolation for `bantu_vocals_v1`).
2. **Train (`train_lora.py`):** Runs genuine PyTorch `bf16` PEFT rectified flow-matching optimization on `ACE-Step/ACE-Step-v1-3.5B` DiT attention modules discovered via `discover_dit_target_modules()`.
   - **Never** accept stub/mock adapters: enforce `size > 64 bytes`, `torch.isfinite()` on all tensors, embedded PEFT metadata inside `.safetensors`, and cryptographic SHA-256 verification.
3. **Reload Gate (`model_utils.py`):** Before promoting any `.safetensors`, verify reload with `load_lora_adapter(local_path, prefix=None)` and confirm `materialize_peft_dir_from_safetensors()` reconstructs a valid PEFT directory (`adapter_config.json` + `adapter_model.safetensors`) cleanly.
4. **Promote in Supabase (`cbnruevwrqwjnnoscgsz`):** Update `public.lora_registry` (`status = 'active'`, `r2_key`, `sha256`, `file_size_bytes`, `trained_at`) and confirm live `GET https://vhunambi-api.ndugelosigwadi.workers.dev/v1/studio/loras/factory` reflects the active status.

### Step 4.3 — Mandatory Teardown (Zero Idle Burn)
Immediately after uploading `.safetensors` to R2 and verifying reload:
1. Call `runpod:delete-pod` on the training Pod.
2. Call `runpod:list-pods` and verify it returns `[]`.
3. Call `runpod:get-balance` and report remaining credit to the user.

---

## 5. Hard-Won Compatibility Traps (Do Not Regress)

1. **`py3langid==0.3.0` pin:** `LangSegment 0.3.5` calls `LanguageIdentifier.from_pickled_model`, removed in `0.4.0`. Never unpin `py3langid==0.3.0`.
2. **PyTorch 2.10 `torchaudio` fallback:** Keep `_install_torchaudio_soundfile_compat()` in `tools/zr-studio-gpu/model_utils.py` so headless containers without `torchcodec` save/load WAVs via `soundfile`.
3. **ACE-Step LoRA `prefix=None` & PEFT reconstruction:** Always pass `prefix=None` to `load_lora_adapter()` and maintain `materialize_peft_dir_from_safetensors()` for loaders requiring a PEFT directory.
4. **Zero-false-positive LoRA provenance (`LORA-01`):** Never assign `_active_lora_key` until `os.path.isfile(local_path)` and `size > 64` bytes + SHA-256 checks succeed.
5. **Cold `torch` import guard on Windows dev host:** Keep `importlib.util.find_spec('acestep')` and `'torch' in sys.modules` guards so local CPU unit tests finish in `< 15s`.
6. **`GET /v1/studio/loras` backward compatibility:** Keep `AFRICAN_LORA_PACKS` at `10` genre packs (`totalCount === 10`) and expose `bantu_vocals_v1` in additive `languagePacks[]` + `findLoraPackById()`.
7. **Strict `YuE2` license ban:** Never add `YuE2` (`CC BY-NC 4.0`) to any Dockerfile, router, or worker.
8. **Update Memory on Every Rollout:** After any image push, LoRA promotion, or endpoint change, update `tools/zr-studio-gpu/README.md` + the active phase/sprint `memory.md` and run `node .agents/skills/vhunambi-memory/scripts/consolidate_memory.mjs`.

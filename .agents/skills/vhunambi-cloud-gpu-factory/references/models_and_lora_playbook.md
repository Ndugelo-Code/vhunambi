# Vhunambi Multi-Model Audio Architecture & Sovereign LoRA Playbook (Phases 81–85)

Detailed reference companion to [`SKILL.md`](../SKILL.md).

---

## 1. Phase 81–83 Multi-Model Routing & Commercial Licensing Matrix

| Engine / Tool | Routing Trigger | License & Legal Boundary | Mandatory Runtime Guardrails |
| :--- | :--- | :--- | :--- |
| **MiniMax Music 3.0** (`MiniMaxAI/MiniMax-Music3`) | `engineTier == 'studio_bake'` **AND** `isInstrumental == false` **AND** `referenceAudioUrl == null` | Commercial allowed up to `$20M` USD revenue; self-hosted on RunPod `48 GB` GPU (`bf16`/`fp16`) | 1. Stamp visible `"MiniMax-Music3"` attribution (clear truthfully on fallback).<br>2. Generate unique random 64-bit `seed` per take (`sglang-omni` defaults `seed=0`).<br>3. `<= 300s` sweet spot (`360s` hard cap).<br>4. Upsample native `32 kHz` WAV → `44.1/48 kHz` via `soxr` before Matchering.<br>5. Never send `isInstrumental` or `referenceAudioUrl` to `sglang-omni` `/v1/audio/speech`. |
| **ACE-Step 1.5 XL / v1-3.5B** (`xl-sft`, `xl-base`, `xl-turbo`) | `isInstrumental == true`, `referenceAudioUrl != null`, `engineTier == 'sovereign_custom'`, `engineTier == 'fast_draft'` (`12` steps), or `POST /v1/generations/:id/repaint` | **MIT License** (unrestricted commercial) | Keep `_install_latin_language_guard`, `py3langid==0.3.0`, `_install_torchaudio_soundfile_compat()`, and `[Log Drum Drop]` stripped in `ALLOWED_SECTION` (preserved only in `ALLOWED_MINIMAX_SECTION`). |
| **BS-RoFormer** (`audio-separator` + `onnxruntime`) | Vocal isolation before Seed-VC, vocal repaint protection, and `bantu_vocals_v1` dataset prep | **MIT / Apache-2.0** | Cache separator instance in `_ROFORMER_SEP_CACHE` inside `tools/zr-studio-gpu/mmo_extractor.py`; require `"onnxruntime>=1.18.0"` in `Dockerfile.delta`. |
| **Seed-VC** (`tools/zr-studio-gpu/seed_vc_worker.py`) | Optional zero-shot singing voice conversion (`clonedVoiceProfileId` / `voiceModelId`) | **`GPL-3.0` (Server-Side Isolated)** | Never bundle GPL binaries in Flutter client (`apps/vhunambi_client/`). Preserve Tshivenda plosives (`ṋ, ḓ, ṱ, ḽ`) and Nguni clicks (`c, q, x`) via 2.8 kHz onset mask + 6.5 kHz de-ess + 12 ms Haas glue. |
| **Matchering 2.0 + Pedalboard + `pyloudnorm`** (`stem_mastering_worker.py`) | Final mastering across winning & secondary takes | **`GPL-3.0` (Server-Side Isolated)** (`Matchering`, `Pedalboard`) + **`MIT`** (`pyloudnorm`) | Curated 6 SA reference WAV profiles in R2; `-14.0 LUFS` streaming default or `-9.0 LUFS` club master at `<= -1.0 dBTP` (`-9.5 LUFS` accepted for Phase 25 compatibility). |
| **Demucs v4 (`htdemucs`)** (`mmo_extractor.py`) | 4-stem export (`vocals`, `drums`, `bass`, `melodic`) for Track Stem Mixer | **MIT** | Export stems for Stem Mixer **only** — do not re-sum Demucs stems to build the master track. |
| **YuE2** | **BANNED** | **`CC BY-NC 4.0`** (Non-Commercial) | Never install, pull, or route to `YuE2` in production. |

---

## 2. Phase 85 Sovereign African LoRA Factory Inventory

Canonical 10 genre packs (`AFRICAN_LORA_PACKS`, `totalCount === 10`) + 1 language pack (`bantu_vocals_v1` in `languagePacks[]`) stored in Cloudflare R2 `zr-studio-audio/loras/` and tracked in Supabase `public.lora_registry`:

### Active Trained Packs (6/6 Ready Packs Trained on RunPod `NVIDIA A40`, Reload-Verified & Active)
1. `amapiano_logdrum_v1` — `loras/amapiano_logdrum_v1.safetensors`
2. `amapiano_private_school_v1` — `loras/amapiano_private_school_v1.safetensors`
3. `venda_malende_v1` — `loras/venda_malende_v1.safetensors`
4. `afrohouse_ancestral_v1` — `loras/afrohouse_ancestral_v1.safetensors`
5. `afrobeats_lagos_v1` — `loras/afrobeats_lagos_v1.safetensors`
6. `bantu_vocals_v1` — `loras/bantu_vocals_v1.safetensors` (vocal-isolated via BS-RoFormer)

### Remaining Seeded Packs (Ready to Train Once Curated Datasets Reach Threshold >= 8 Tracks)
- `sgija_bacardi_v1`
- `gqom_durban_v1`
- `maskandi_acoustic_v1`
- `gospel_sa_choir_v1`
- `kwaito_classic_v1`

---

## 3. End-to-End 5-Stage Serverless Handler Flow (`tools/zr-studio-gpu/handler.py`)

```text
POST /v1/generations (or /repaint, /loras/datasets/prep, /loras/train)
  │
  ├─► job_type == "lora_dataset_prep" ──► training/dataset_prep_worker.py ──► R2 training-data/curated/{lora_id}/
  ├─► job_type == "lora_train_peft"   ──► training/train_lora.py          ──► R2 loras/{lora_id}.safetensors
  │                                                                        └─► HMAC Webhook POST /v1/webhooks/training
  └─► Synthesis / Repaint Job
        1. ZRMultiModelRouter (model_router.py + model_utils.py)
           • 1..4 unique-seeded takes + SHA-256 verified LoRA hot-swap (blend weight <= 1.35)
           • A&R quality scorer promotes winning take to master.mp3
        2. BS-RoFormer (mmo_extractor.py) + Demucs v4 4-stem export
        3. Neural Seed-VC voice conversion (seed_vc_worker.py, optional)
        4. Matchering 2.0 + Pedalboard + pyloudnorm mastering (stem_mastering_worker.py)
        5. MMO v2.0 60Hz measured telemetry + R2 upload + HMAC Webhook POST /v1/webhooks/ace-step
```

---

## 4. Docker Paid Plan vs. GitHub Actions Notes (Decision Context)

- **Why Docker Build Cloud (`cloud-ndugelo-vhunambi`) fits Vhunambi better than paid GitHub Actions:**
  - GitHub Free already covers unlimited git hosting, branches, PRs, and Releases.
  - Docker Build Cloud gives fast remote 8-core / 16 GB `linux/amd64` builds + persistent 50 GiB remote layer cache right inside Docker Desktop (`docker buildx`), pushing straight to `docker.io/ndugelo/zr-studio-gpu` without transferring 15 GB images through a low-RAM Windows laptop.
  - Upgrading Docker (e.g., Docker Pro with Build Cloud minutes + private repos) directly powers the exact container build/deploy bottleneck without needing paid GitHub Actions minutes.

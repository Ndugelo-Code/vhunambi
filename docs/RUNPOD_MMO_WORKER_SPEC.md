# Standalone Tier 2 RunPod Worker Specification (zr-studio-gpu/handler.py v2)

> **Repository:** `ndugelo/zr-studio-gpu`  
> **Target Worker:** `handler.py` & `mmo_extractor.py`  
> **API Consumer:** `apps/vhunambi_api/src/routes/webhook_routes.ts`  
> **Specification Version:** 2.0 (Dual-Provenance Measured Tier)  

---

## 1. Webhook Payload Contract (`POST /v1/webhooks/ace-step`)

The RunPod worker signs the JSON payload using HMAC-SHA256 with `ZR_WEBHOOK_SECRET` and passes the signature in `x-zrs-signature`.

```typescript
export interface AceStepWebhookPayloadV2 {
  job_id: string;
  user_id?: string;
  status: 'processing' | 'uploading' | 'completed' | 'failed';
  progress?: number;
  audio_url?: string;              // Master MP3 presigned/public R2 URL (v1 backward-compat)
  master_wav_url?: string;         // Optional lossless WAV URL
  stems_zip_url?: string;          // Bundled 4-stem ZIP URL
  stem_urls?: {                    // Individual R2 stem URLs for StemMixerDeck
    vocals: string;
    drums: string;
    bass: string;
    melodic: string;
  };
  manifest_url?: string;           // R2 JSON URL containing MasterMediaObjectManifest (provenance: 'measured')
  error?: string;
}
```

---

## 2. Reference Python Extraction Pipeline (`mmo_extractor.py`)

Place this module alongside `handler.py` in the `zr-studio-gpu` worker. When ACE-Step 1.5 finishes rendering, it runs Demucs v4 (`htdemucs`) in GPU memory, extracts 60 Hz `Uint8` Base64 curves, finds zero-crossings for the 8 stratified MPC pads, uploads the manifest to Cloudflare R2 (`vhunambi-audio`), and returns `manifest_url`:

```python
# zr-studio-gpu/mmo_extractor.py
import base64
import json
import numpy as np
import librosa

STEM_ROLES = ("vocals", "drums", "bass", "melodic")  # Demucs 'other' maps to 'melodic'
SAMPLE_RATE_HZ = 60

def quantize_curve_to_base64(signal: np.ndarray, sr: int, duration_ms: int) -> str:
    """Computes 60Hz RMS envelope normalized to 0..255 Uint8 and returns Base64."""
    target_frames = max(1, (duration_ms * SAMPLE_RATE_HZ) // 1000)
    hop_length = max(1, int(sr / SAMPLE_RATE_HZ))
    rms = librosa.feature.rms(y=signal, frame_length=hop_length * 2, hop_length=hop_length)[0]
    if len(rms) < target_frames:
        rms = np.pad(rms, (0, target_frames - len(rms)), mode="edge")
    else:
        rms = rms[:target_frames]
    peak = float(np.percentile(rms, 98)) if np.max(rms) > 1e-6 else 1.0
    normalized = np.clip(rms / max(peak, 1e-6), 0.0, 1.0)
    uint8_bytes = (normalized * 255.0).round().astype(np.uint8).tobytes()
    return base64.b64encode(uint8_bytes).decode("ascii")

def snap_to_zero_crossing(signal: np.ndarray, sr: int, target_sec: float) -> float:
    """Finds the nearest waveform zero-crossing within ±25ms of target_sec to prevent MPC clicks."""
    center = int(np.clip(target_sec * sr, 0, len(signal) - 1))
    window = int(0.025 * sr)
    start = max(0, center - window)
    end = min(len(signal), center + window)
    segment = signal[start:end]
    zc_indices = np.where(np.diff(np.signbit(segment)))[0]
    if len(zc_indices) == 0:
        return round(float(target_sec), 4)
    nearest_offset = zc_indices[np.argmin(np.abs((start + zc_indices) - center))]
    return round(float((start + nearest_offset) / sr), 4)

def extract_measured_mmo_telemetry(
    master_wav: np.ndarray,
    stems_dict: dict[str, np.ndarray],  # keys: 'vocals', 'drums', 'bass', 'melodic'
    sr: int,
    bpm: float,
) -> dict:
    """Builds the 'modulationBus' and 'mpcKitPads' blocks with provenance='measured'."""
    duration_ms = int((len(master_wav) / sr) * 1000)
    frame_count = max(1, (duration_ms * SAMPLE_RATE_HZ) // 1000)

    encoded_curves = {
        "masterRms": quantize_curve_to_base64(master_wav, sr, duration_ms),
        "vocals": quantize_curve_to_base64(stems_dict["vocals"], sr, duration_ms),
        "drums": quantize_curve_to_base64(stems_dict["drums"], sr, duration_ms),
        "bass": quantize_curve_to_base64(stems_dict["bass"], sr, duration_ms),
        "melodic": quantize_curve_to_base64(stems_dict["melodic"], sr, duration_ms),
    }

    # Extract real onset transients from isolated bass & drums stems
    transient_events = []
    for stem_name, ev_type in (("bass", "log_drum_drop"), ("drums", "kick"), ("vocals", "vocal_onset")):
        y_stem = stems_dict[stem_name]
        onset_env = librosa.onset.onset_strength(y=y_stem, sr=sr)
        onset_frames = librosa.onset.onset_detect(onset_envelope=onset_env, sr=sr, backtrack=True)
        onset_times = librosa.frames_to_time(onset_frames, sr=sr)
        max_env = float(np.max(onset_env)) if len(onset_env) > 0 and np.max(onset_env) > 0 else 1.0
        for f_idx, t_sec in zip(onset_frames, onset_times):
            intensity = round(float(np.clip(onset_env[f_idx] / max_env, 0.15, 1.0)), 3)
            if intensity >= 0.45:
                transient_events.append({
                    "timestampMs": int(t_sec * 1000),
                    "type": ev_type,
                    "stem": stem_name,
                    "intensity": intensity,
                    "durationMs": 220 if ev_type == "log_drum_drop" else 160,
                })

    transient_events.sort(key=lambda x: x["timestampMs"])
    return {
        "provenance": "measured",
        "modulationBus": {
            "sampleRateHz": SAMPLE_RATE_HZ,
            "durationMs": duration_ms,
            "frameCount": frame_count,
            "encodedCurvesBase64": encoded_curves,
            "transientEvents": transient_events,
        },
    }
```

---

## 5. Phase 25: Stem-Targeted Studio Mastering Pipeline (`stem_mastering_worker.py`)

In Phase 25, the worker gains a dedicated post-synthesis mastering mode (`task_type: "master_stems"`). It consumes the 4 isolated stems along with the `transientEvents` from the MMO manifest and executes:

1. **Log Drum Sub-Harmonic Synthesis ($35\text{–}55\text{ Hz}$):** Phase-locked sub-octave generation based on the `bass.wav` envelope.
2. **Kick-to-Bass Sidechain Ducking:** Precision dynamic gain reduction ($-3.5\text{ dB}$ for $55\text{ ms}$) on every `kick` transient timestamp so kick and log drum transients never clash.
3. **Mid/Side (M/S) Vocal Pocket Carving:** Cuts $-2.5\text{ dB}$ at $1.8\text{ kHz}$ in the Mid channel of `melodic.wav` to create a dedicated center pocket for vocals, while widening the Side channel by $+30\%$.
4. **Pedalboard EQ/Compression Chains & pyloudnorm True-Peak Limiter:** Sums the 4 polished stems through an SSL-style glue compressor and normalizes to $-9.5\text{ LUFS}$ (Club/TikTok) or $-14.0\text{ LUFS}$ (Streaming) with a $-1.0\text{ dBTP}$ ceiling.

See [`tools/zr-studio-gpu/stem_mastering_worker.py`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/tools/zr-studio-gpu/stem_mastering_worker.py) for the complete implementation.

---

## 6. Phase 26: Zero-Shot Singing Voice Conversion & Bantu Phoneme Alignment (`seed_vc_worker.py`)

When the generation payload includes `svc_config` (`mode: 'catalog_archetype' | 'zero_shot_clone'`), the worker executes `seed_vc_worker.py` on the isolated `vocals.wav` stem immediately after Demucs v4 separation and prior to Phase 25 stem mastering:

1. **RMVPE F0 Pitch Contour Locking (`f0PitchLock: true`):** Extracts the exact fundamental frequency curve from `vocals.wav` so the converted vocal retains 100% pitch accuracy with the song's key.
2. **Bantu Phoneme Cadence Alignment (`preserveBantuClicks: true`):** Preserves dental/aspirated consonant transients (`ṋ, ḓ, ṱ, ḽ`) and Nguni click attacks (`c, q, x`) using the creator's `phonemeCadenceMap` extracted from the 3-line calibration script.
3. **Seed-VC Timbre Transfer & Phase 25 Synergy:** Applies the 256-float speaker timbre embedding (`timbreEmbedding`) or regional voice archetype (`archetypeId`) and recommends `studioCondenser` vocal cleansing in `stem_mastering_worker.py`.

See [`tools/zr-studio-gpu/seed_vc_worker.py`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/tools/zr-studio-gpu/seed_vc_worker.py) for the complete implementation.



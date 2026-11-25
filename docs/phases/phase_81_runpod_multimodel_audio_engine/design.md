# Phase 81 Technical Design — RunPod Multi-Model Audio Engine (`MiniMax Music 3.0` + `ACE-Step 1.5 XL`) & Multi-Take A&R Baking

> **Document ID:** `DESIGN-PHASE-81`  
> **Phase Folder:** `docs/phases/phase_81_runpod_multimodel_audio_engine/`  
> **Compliance:** Authentic `package:vhunambi_client/...`, `package:phosphor_icons/phosphor_icons.dart`, `AppColors.*Of(context)`, `AppTypography.*`, `>= 44dp` touch bounds, zero raw Unicode emojis (`STD-UIUX-001`), mandatory `"MiniMax-Music3"` attribution, zero `YuE2` references.

---

## 1. Pass 1 (`M81.1`) — Cloudflare Worker Wire, Polling, Webhook & DO Sync (`apps/vhunambi_api/`)

### 1.1 Lyric Sanitizer & Engine-Aware Formatter (`apps/vhunambi_api/src/modules/lyrics/lyrics_sanitizer.ts`)

Expand `ALLOWED_SECTION` to preserve `[Log Drum Drop]`, `[Piano Solo]`, `[Drum Solo]`, and `[Solo]`, and export `formatLyricsForEngine(rawLyrics, resolvedEngine)` so `minimax_music_3` receives Title-Case `[Voice A]`, `[Voice B]`, `[Duet]`, `[Choir]`, `[Guitar Solo]`, and `[Log Drum Drop]` markers rather than forced lowercase:

```typescript
const ALLOWED_SECTION =
  /^(intro|verse(?:\s*\d+)?|pre-?chorus|chorus(?:\s*\d+)?|bridge|outro|instrumental|hook|voice\s*[a-d]|duet|choir|call|response|guitar\s*solo|sax\s*solo|piano\s*solo|drum\s*solo|solo|log\s*drum\s*drop|drop|breakdown)$/;

function toTitleCaseTag(label: string): string {
  return label
    .split(/(\s+|-)/)
    .map((part) =>
      /^[a-z]/.test(part)
        ? part.charAt(0).toUpperCase() + part.slice(1)
        : part,
    )
    .join('');
}

export function formatLyricsForEngine(
  rawLyrics: string,
  resolvedEngine?: string,
): string {
  const base = sanitizeLyricsForAceStep(rawLyrics);
  if (resolvedEngine === 'minimax_music_3') {
    return base.replace(
      /^\[([^\]]+)\]$/gm,
      (_m, label: string) => `[${toTitleCaseTag(label)}]`,
    );
  }
  return base;
}
```

### 1.2 `CompiledSynthesisPrompt.isInstrumental` & `YuE2` Guard (`apps/vhunambi_api/src/modules/synthesis/prompt_compiler.ts`)

```typescript
export interface CompiledSynthesisPrompt {
  caption: string;
  richPrompt?: string;
  lyrics: string;
  isInstrumental: boolean;
  // ... existing fields preserved 1:1
}

export function resolveTargetAudioEngine(input: {
  engineTier?: StudioEngineTier | string;
  isInstrumental?: boolean;
  audioMode?: ReferenceAudioMode;
  referenceAudioUrl?: string;
  clonedVoiceProfileId?: string;
}): {
  resolvedEngine: ResolvedAudioEngine;
  attributionTag: string | null;
} {
  const rawTier = String(input.engineTier ?? 'studio_bake').trim().toLowerCase();
  if (rawTier.includes('yue')) {
    throw new Error('YuE2 (CC BY-NC 4.0) is prohibited in commercial Vhunambi production');
  }
  const tier = (rawTier as StudioEngineTier) || 'studio_bake';
  const hasReference =
    Boolean(input.referenceAudioUrl?.trim()) &&
    (input.audioMode ?? 'none') !== 'none';
  const hasVoiceClone = Boolean(input.clonedVoiceProfileId?.trim());

  if (tier === 'fast_draft') {
    return { resolvedEngine: 'ace_step_xl_turbo', attributionTag: null };
  }
  if (tier === 'sovereign_custom' || hasReference || hasVoiceClone) {
    return { resolvedEngine: 'ace_step_xl_base', attributionTag: null };
  }
  if (input.isInstrumental) {
    return { resolvedEngine: 'ace_step_xl_sft', attributionTag: null };
  }
  return { resolvedEngine: 'minimax_music_3', attributionTag: 'MiniMax-Music3' };
}
```

### 1.3 Lossless `runpod_adapter.ts` Dispatch & Multi-Take `/status/:id` Parser

```typescript
// Inside dispatchSynthesisJob (apps/vhunambi_api/src/modules/synthesis/runpod_adapter.ts):
const formattedLyrics = prompt.isInstrumental
  ? ''
  : formatLyricsForEngine(prompt.lyrics, prompt.resolvedEngine);

// Inside body.input:
input: {
  job_id: jobId,
  user_id: userId,
  engine_tier: prompt.engineTier,
  resolved_engine: prompt.resolvedEngine,
  attribution_tag: prompt.attributionTag,
  is_instrumental: Boolean(prompt.isInstrumental),
  batch_count: prompt.batchCount,
  take_seeds: prompt.takeSeeds,
  audio_mode: prompt.audioMode,
  visibility: prompt.visibility,
  song_spec: {
    genre: prompt.metadata.genre,
    region: prompt.metadata.region,
    tempo: prompt.metadata.bpm,
    key: prompt.metadata.key,
    mood: prompt.metadata.mood,
    era: prompt.metadata.era,
    song_structure: prompt.metadata.songStructure,
    duration: prompt.metadata.durationSec,
    is_instrumental: Boolean(prompt.isInstrumental),
    lyrics: formattedLyrics,
    language: prompt.metadata.language,
    caption: prompt.caption,
    ...(prompt.richPrompt ? { rich_prompt: prompt.richPrompt } : {}),
    infer_steps: inferSteps,
    guidance_scale: prompt.inferenceConfig?.guidanceScale ?? 12.0,
    ...(prompt.sonicTags ? { sonic_tags: prompt.sonicTags } : {}),
    ...(prompt.metadata.title ? { title: prompt.metadata.title } : {}),
    ...(prompt.voiceCast ? { voice_cast: prompt.voiceCast } : {}),
  },
  // ... remaining fields unchanged
}
```

And upgrade `checkRunPodJobStatus` so active polling preserves multi-take outputs, scores, and engine attribution:

```typescript
export interface RunPodJobStatusResult {
  status: 'IN_QUEUE' | 'IN_PROGRESS' | 'COMPLETED' | 'FAILED' | 'UNKNOWN';
  stage?: string;
  audioUrl?: string;
  masterWavUrl?: string;
  stemsZipUrl?: string;
  stemUrls?: Record<string, string>;
  manifestUrl?: string;
  resolvedEngine?: string;
  attributionTag?: string | null;
  takes?: Array<Record<string, unknown>>;
  error?: string;
  progress?: number;
}

// Inside checkRunPodJobStatus when statusUpper === 'COMPLETED':
if (statusUpper === 'COMPLETED') {
  return {
    status: 'COMPLETED',
    audioUrl: data.output?.audio_url,
    masterWavUrl: data.output?.master_wav_url,
    stemsZipUrl: data.output?.stems_zip_url,
    stemUrls: data.output?.stem_urls,
    manifestUrl: data.output?.manifest_url,
    resolvedEngine: data.output?.resolved_engine,
    attributionTag: data.output?.attribution_tag,
    takes: Array.isArray(data.output?.takes) ? data.output.takes : undefined,
  };
} else if (statusUpper === 'IN_PROGRESS') {
  return {
    status: 'IN_PROGRESS',
    stage: data.output?.stage ?? data.output?.status,
    progress: typeof data.output?.progress === 'number' ? data.output.progress : 60,
  };
}
```

In `generation_routes.ts` (`GET /v1/generations/:id`), normalize `liveStatus.takes` identically to `webhook_routes.ts`:

```typescript
const resolvedEng = (liveStatus.resolvedEngine ??
  job.resolvedEngine ??
  'minimax_music_3') as ResolvedAudioEngine;
const resolvedAttr =
  liveStatus.attributionTag !== undefined
    ? liveStatus.attributionTag
    : resolvedEng === 'minimax_music_3'
      ? 'MiniMax-Music3'
      : (job.attributionTag ?? null);
const completedTakes: GenerationTakeRecord[] =
  Array.isArray(liveStatus.takes) && liveStatus.takes.length > 0
    ? liveStatus.takes.map((raw, idx) => ({
        takeIndex: Number(raw.takeIndex ?? raw.take_index ?? idx),
        seed: Number(raw.seed ?? idx + 1),
        engineUsed: String(raw.engineUsed ?? raw.engine_used ?? resolvedEng),
        audioUrl: String(raw.audioUrl ?? raw.audio_url ?? liveStatus.audioUrl),
        durationSec:
          raw.durationSec !== undefined
            ? Number(raw.durationSec)
            : (raw.duration_sec !== undefined ? Number(raw.duration_sec) : job!.durationSec),
        score: raw.score !== undefined ? Number(raw.score) : undefined,
        attribution:
          raw.attribution !== undefined
            ? (raw.attribution as string | null)
            : resolvedAttr,
      }))
    : job.takes && job.takes.length > 0
      ? job.takes
      : [
          {
            takeIndex: 0,
            seed: 1,
            engineUsed: resolvedEng,
            audioUrl: liveStatus.audioUrl,
            durationSec: job.durationSec ?? 180,
            score: 1.0,
            attribution: resolvedAttr,
          },
        ];

completeJob(id, {
  masterMp3Url: liveStatus.audioUrl,
  stemsZipUrl: liveStatus.stemsZipUrl,
  stemUrls: liveStatus.stemUrls,
  manifestUrl: liveStatus.manifestUrl,
  takes: completedTakes,
  resolvedEngine: resolvedEng,
  attributionTag: resolvedAttr,
});
```

### 1.4 Edge Isolate Webhook Progress Sync (`webhook_routes.ts`) & DO Stage Mapping (`generation_session_do.ts`)

```typescript
// apps/vhunambi_api/src/routes/webhook_routes.ts
async function syncWebhookProgressAsync(
  c: Context<{ Bindings: VhunambiWorkerEnv }>,
  generationId: string,
  updates: { status: 'running'; step: PipelineStep; progressPct: number },
): Promise<void> {
  const promise = vhunambiDb.updateGenerationJobAsync(generationId, updates, c);
  try {
    const execCtx = c.executionCtx;
    if (execCtx && typeof execCtx.waitUntil === 'function') {
      execCtx.waitUntil(promise);
      return;
    }
  } catch {
    // Hono throws accessing c.executionCtx in Node / simulated-edge tests
  }
  await promise;
}
```

And in `apps/vhunambi_api/src/modules/realtime/generation_session_do.ts`:

```typescript
  let stepIndex = 1;
  let statusMessage = 'Starting synthesis pipeline...';
  if (rawStep === 'writing_lyrics' || rawStep === 'planning_lyrics') {
    stepIndex = 2;
    statusMessage = 'Composing authentic dialect lyrics...';
  } else if (rawStep === 'converting_vocals') {
    stepIndex = 3;
    statusMessage = 'Cloning and polishing vocal stems...';
  } else if (
    rawStep === 'producing_beat' ||
    rawStep === 'synthesizing' ||
    rawStep === 'separating_stems' ||
    rawStep === 'uploading' ||
    rawStep === 'mastering'
  ) {
    stepIndex = 3;
    statusMessage = 'Rendering African rhythm and audio stems...';
  } else if (
    rawStep === 'ready' ||
    rawStep === 'completed' ||
    payload.status === 'succeeded' ||
    payload.status === 'completed'
  ) {
    stepIndex = 4;
    statusMessage = 'Studio Master Ready';
  } else if (rawStep === 'failed' || payload.status === 'failed') {
    stepIndex = 0;
    statusMessage = payload.error || 'Synthesis failed.';
  }
```
Include `resolved_engine: payload.resolvedEngine ?? null`, `attribution_tag: payload.attributionTag ?? null`, and `takes: payload.takes ?? []` inside `completedTrack`.

---

## 2. Pass 1 (`M81.2`) — Python Multi-Model Router, Duet Sanitizer, `360s` Ceiling & Multi-Take A&R Engine (`tools/zr-studio-gpu/`)

### 2.1 Complete New Module: `tools/zr-studio-gpu/model_router.py`

```python
"""
VHUNAMBI Phase 81 — ZRMultiModelRouter, MiniMax Music 3.0 Adapter,
32kHz->44.1kHz Polyphase Resampler & Mathematical Multi-Take A&R Scorer.
"""

from __future__ import annotations

import math
import os
import secrets
from dataclasses import dataclass
from typing import Any, Dict, List, Optional

import numpy as np
import soundfile as sf

TARGET_SAMPLE_RATE = 44100


@dataclass(frozen=True)
class RouteDecision:
    resolved_engine: str
    attribution_tag: Optional[str]
    infer_steps: int
    guidance_scale: float
    reason: str


@dataclass(frozen=True)
class ArTakeScore:
    score: float
    active_ratio: float
    crest_db: float
    presence_ratio: float
    clip_penalty: float

    def to_dict(self) -> Dict[str, float]:
        return {
            "score": self.score,
            "activeRatio": self.active_ratio,
            "crestDb": self.crest_db,
            "presenceRatio": self.presence_ratio,
            "clipPenalty": self.clip_penalty,
        }


def ensure_unique_take_seeds(
    raw_seeds: Optional[List[Any]], batch_count: int = 1
) -> List[int]:
    """Guarantees `batch_count` (1..4) unique positive non-zero 53-bit integer seeds."""
    count = max(1, min(4, int(batch_count or 1)))
    seeds: List[int] = []
    seen: set[int] = set()
    for item in raw_seeds or []:
        try:
            val = int(item)
            if val > 0 and val not in seen:
                seeds.append(val)
                seen.add(val)
        except (TypeError, ValueError):
            continue
        if len(seeds) >= count:
            break
    while len(seeds) < count:
        cand = (secrets.randbits(52) << 1) | 1
        if cand > 0 and cand not in seen:
            seeds.append(cand)
            seen.add(cand)
    return seeds


def normalize_wav_to_44k1(
    wav_path: str, target_sr: int = TARGET_SAMPLE_RATE
) -> Dict[str, Any]:
    """
    Resamples non-44.1kHz WAVs (such as MiniMax Music 3.0's native 32kHz 16-bit WAV)
    to 44.1kHz stereo PCM_24 using soxr VHQ or exact rational polyphase filtering (441/320).
    """
    data, in_sr = sf.read(wav_path, dtype="float32", always_2d=True)
    if data.shape[1] == 1:
        data = np.repeat(data, 2, axis=1)
    elif data.shape[1] > 2:
        data = data[:, :2]

    resampled = False
    if int(in_sr) != int(target_sr):
        resampled = True
        try:
            import soxr  # type: ignore

            data = soxr.resample(data, int(in_sr), int(target_sr), quality="VHQ")
        except ImportError:
            from scipy import signal as sp_signal

            g = math.gcd(int(in_sr), int(target_sr))
            up = int(target_sr) // g
            down = int(in_sr) // g
            data = sp_signal.resample_poly(data, up=up, down=down, axis=0)
        data = np.asarray(data, dtype=np.float32)
        sf.write(wav_path, data, int(target_sr), subtype="PCM_24")

    return {
        "input_sr": int(in_sr),
        "output_sr": int(target_sr),
        "resampled": resampled,
        "frames": int(data.shape[0]),
        "duration_sec": round(float(data.shape[0]) / float(target_sr), 3),
    }


def score_take_ar_quality(
    wav_path: str, is_instrumental: bool = False
) -> ArTakeScore:
    """
    Computes bounded A&R quality score Q_take in [0.05, 0.99] across 4 acoustic axes:
      1. S_active: Non-silence active frame ratio (> -48 dBFS in 50ms windows)
      2. S_crest:  Dynamic crest factor Gaussian centered at 12.5 dB (sigma=5.5 dB)
      3. S_pres:   300..4500 Hz vocal/lead presence energy ratio
      4. P_clip:   Full-scale sample clipping penalty (|x| >= 0.995)
    """
    data, sr = sf.read(wav_path, dtype="float32", always_2d=True)
    if data.size == 0:
        return ArTakeScore(0.05, 0.0, 0.0, 0.0, 0.5)

    mid = np.mean(data[:, :2], axis=1) if data.shape[1] >= 2 else data[:, 0]
    eps = 1e-9

    # 1. Non-silence active ratio in 50ms windows
    win = max(1, int(0.05 * sr))
    n_frames = max(1, len(mid) // win)
    trimmed = mid[: n_frames * win].reshape(n_frames, win)
    frame_rms_db = 20.0 * np.log10(np.sqrt(np.mean(np.square(trimmed), axis=1)) + eps)
    active_frac = float(np.mean(frame_rms_db > -48.0))
    s_active = float(np.clip(active_frac / 0.80, 0.0, 1.0))

    # 2. Crest factor pocket
    peak = float(np.max(np.abs(mid)) + eps)
    rms = float(np.sqrt(np.mean(np.square(mid))) + eps)
    crest_db = float(20.0 * np.log10(peak / rms))
    s_crest = float(math.exp(-((crest_db - 12.5) ** 2) / (2.0 * (5.5 ** 2))))

    # 3. Presence band balance (300 Hz .. 4500 Hz)
    fft_slice = mid[: min(len(mid), sr * 30)]
    spec = np.abs(np.fft.rfft(fft_slice)) ** 2
    freqs = np.fft.rfftfreq(len(fft_slice), d=1.0 / float(sr))
    total_energy = float(np.sum(spec) + eps)
    pres_mask = (freqs >= 300.0) & (freqs <= 4500.0)
    pres_ratio_raw = float(np.sum(spec[pres_mask]) / total_energy)
    target_denom = 0.25 if is_instrumental else 0.35
    s_presence = float(np.clip(pres_ratio_raw / target_denom, 0.0, 1.0))

    # 4. Clipping penalty
    clip_frac = float(np.mean(np.abs(data) >= 0.995))
    p_clip = float(np.clip(50.0 * clip_frac, 0.0, 0.5))

    raw_q = 0.38 * s_active + 0.32 * s_crest + 0.30 * s_presence - p_clip
    final_q = round(float(np.clip(raw_q, 0.05, 0.99)), 4)
    return ArTakeScore(
        score=final_q,
        active_ratio=round(s_active, 4),
        crest_db=round(crest_db, 2),
        presence_ratio=round(s_presence, 4),
        clip_penalty=round(p_clip, 4),
    )


class ZRMultiModelRouter:
    """
    Deterministic router across MiniMax Music 3.0 (sglang-omni) and ACE-Step 1.5 XL
    ({turbo, sft, base}), enforcing legal and serving guardrails.
    """

    @staticmethod
    def resolve_route(
        job_input: Dict[str, Any], song_spec: Dict[str, Any]
    ) -> RouteDecision:
        raw_tier = str(job_input.get("engine_tier") or "studio_bake").strip().lower()
        raw_engine = str(job_input.get("resolved_engine") or "").strip().lower()
        if "yue" in raw_tier or "yue" in raw_engine:
            raise ValueError(
                "YuE2 (CC BY-NC 4.0) is prohibited in commercial Vhunambi production"
            )

        is_instrumental = bool(
            job_input.get("is_instrumental")
            or song_spec.get("is_instrumental")
            or not str(song_spec.get("lyrics") or "").strip()
        )
        ref_audio = str(
            job_input.get("reference_audio_url")
            or song_spec.get("reference_audio_url")
            or ""
        ).strip()
        audio_mode = str(job_input.get("audio_mode") or "none").strip().lower()
        has_ref = bool(ref_audio) and audio_mode != "none"
        svc_cfg = job_input.get("svc_config") or {}
        has_clone = (
            isinstance(svc_cfg, dict) and svc_cfg.get("mode") == "zero_shot_clone"
        )

        if raw_tier == "fast_draft" or raw_engine == "ace_step_xl_turbo":
            return RouteDecision(
                resolved_engine="ace_step_xl_turbo",
                attribution_tag=None,
                infer_steps=12,
                guidance_scale=7.5,
                reason="fast_draft_12_step_turbo",
            )

        if (
            raw_tier == "sovereign_custom"
            or raw_engine == "ace_step_xl_base"
            or has_ref
            or has_clone
        ):
            return RouteDecision(
                resolved_engine="ace_step_xl_base",
                attribution_tag=None,
                infer_steps=int(song_spec.get("infer_steps") or 60),
                guidance_scale=float(song_spec.get("guidance_scale") or 12.0),
                reason="sovereign_custom_or_conditioning",
            )

        if is_instrumental or raw_engine == "ace_step_xl_sft":
            return RouteDecision(
                resolved_engine="ace_step_xl_sft",
                attribution_tag=None,
                infer_steps=int(song_spec.get("infer_steps") or 60),
                guidance_scale=float(song_spec.get("guidance_scale") or 12.0),
                reason="instrumental_sglang_400_shield",
            )

        return RouteDecision(
            resolved_engine="minimax_music_3",
            attribution_tag="MiniMax-Music3",
            infer_steps=int(song_spec.get("infer_steps") or 60),
            guidance_scale=float(song_spec.get("guidance_scale") or 12.0),
            reason="flagship_vocal_studio_bake",
        )

    @staticmethod
    def synthesize_take(
        decision: RouteDecision,
        song_spec: Dict[str, Any],
        output_wav_path: str,
        seed: int,
        loras: Optional[List[Dict[str, Any]]] = None,
    ) -> Dict[str, Any]:
        from model_utils import ZRModelManager, format_lyrics_for_engine

        duration_sec = max(10, min(360, int(song_spec.get("duration", 90))))
        if decision.resolved_engine == "minimax_music_3":
            if duration_sec > 300:
                print(
                    f"[ZR-Router] MiniMax duration {duration_sec}s exceeds 300s sweet spot (capped <=360s)",
                    flush=True,
                )
            sglang_url = os.environ.get(
                "MINIMAX_SGLANG_URL", "http://127.0.0.1:30000/v1/audio/speech"
            ).strip()
            formatted_lyrics = format_lyrics_for_engine(
                str(song_spec.get("lyrics") or ""), "minimax_music_3"
            )
            rich_prompt = str(
                song_spec.get("rich_prompt")
                or song_spec.get("caption")
                or song_spec.get("genre", "Amapiano")
            )
            if sglang_url and formatted_lyrics:
                try:
                    import requests

                    resp = requests.post(
                        sglang_url,
                        json={
                            "model": os.environ.get(
                                "MINIMAX_MODEL_ID", "MiniMaxAI/MiniMax-Music3"
                            ),
                            "input": formatted_lyrics,
                            "prompt": rich_prompt,
                            "seed": int(seed),
                            "duration": duration_sec,
                            "response_format": "wav",
                        },
                        timeout=max(120, duration_sec * 2),
                    )
                    if resp.status_code == 200 and len(resp.content) > 512:
                        with open(output_wav_path, "wb") as f:
                            f.write(resp.content)
                        sr_meta = normalize_wav_to_44k1(output_wav_path)
                        return {
                            "engine": "minimax_music_3",
                            "attribution": "MiniMax-Music3",
                            "seed": int(seed),
                            "duration_sec": duration_sec,
                            **sr_meta,
                        }
                    print(
                        f"[ZR-Router] MiniMax sglang returned {resp.status_code}; falling back to ACE-Step XL-SFT",
                        flush=True,
                    )
                except Exception as mm_err:
                    print(
                        f"[ZR-Router] MiniMax sglang unreachable ({mm_err}); falling back to ACE-Step XL-SFT",
                        flush=True,
                    )

        # ACE-Step 1.5 XL ({turbo, sft, base}) or truthful fallback (clears MiniMax attribution!)
        variant = (
            decision.resolved_engine
            if decision.resolved_engine.startswith("ace_step_")
            else "ace_step_xl_sft"
        )
        spec_copy = dict(song_spec)
        spec_copy["duration"] = duration_sec
        spec_copy["infer_steps"] = decision.infer_steps
        spec_copy["guidance_scale"] = decision.guidance_scale
        mgr = ZRModelManager.get_instance()
        metrics = mgr.generate_audio(
            song_spec=spec_copy,
            output_path=output_wav_path,
            loras=loras if variant == "ace_step_xl_base" else None,
            seed=int(seed),
            variant=variant,
        )
        sr_meta = normalize_wav_to_44k1(output_wav_path)
        return {
            **metrics,
            "attribution": None,
            "seed": int(seed),
            "duration_sec": duration_sec,
            **sr_meta,
        }
```

### 2.2 Upgraded `tools/zr-studio-gpu/model_utils.py`

1. Align `_ALLOWED_SECTION_RE` with all duet/choir/solo/drop markers and add `format_lyrics_for_engine`:
```python
_ALLOWED_SECTION_RE = re.compile(
    r"^(intro|verse(?:\s*\d+)?|pre-?chorus|chorus(?:\s*\d+)?|bridge|outro|instrumental|hook|"
    r"voice\s*[a-d]|duet|choir|call|response|guitar\s*solo|sax\s*solo|piano\s*solo|drum\s*solo|"
    r"solo|log\s*drum\s*drop|drop|breakdown)$"
)

def format_lyrics_for_engine(raw_lyrics: str, engine: str = "ace_step_xl_sft") -> str:
    cleaned = sanitize_lyrics_for_ace_step(raw_lyrics)
    if engine == "minimax_music_3":
        def _title_tag(match: re.Match[str]) -> str:
            inner = match.group(1)
            titled = re.sub(r"[a-z]+", lambda m: m.group(0).capitalize(), inner)
            return f"[{titled}]"
        return re.sub(r"^\[([^\]]+)\]$", _title_tag, cleaned, flags=re.MULTILINE)
    return cleaned
```
2. Update `resolve_lora_cache_dir()` to prefer `/runpod-volume/lora_cache` when `/runpod-volume` exists, raise `_hot_swap_lora` HTTP timeout to `20s`, lift `duration_sec = max(10, min(360, int(song_spec.get("duration", 30))))`, lower `infer_steps` floor to `max(8, min(80, ...))` so `12`-step `ace_step_xl_turbo` runs at true Turbo speed, and thread `seed: Optional[int] = None` into both `ACEStepPipeline` (`torch.manual_seed(seed)` + `manual_seeds=[seed]` with `TypeError` fallback) and `synthesize_structured_song_wav(..., explicit_seed=seed)`.

### 2.3 Multi-Take `tools/zr-studio-gpu/mmo_extractor.py` & `handler.py`

1. In `mmo_extractor.py`, add `upload_take_mp3_to_r2(job_id: str, take_index: int, wav_path: str) -> str` transcoding `wav_path` to `320 kbps` MP3 (`audio/{job_id}/take_{take_index}.mp3`) or returning `{public_base}/audio/{job_id}/take_{take_index}.mp3` in offline/mock test mode.
2. In `handler.py`:
   - Send `planning_lyrics` (`18%`) webhook.
   - Compute `decision = ZRMultiModelRouter.resolve_route(job_input, song_spec)` and `seeds = ensure_unique_take_seeds(job_input.get("take_seeds"), batch_count)`.
   - Synthesize each candidate take $i \in \{0, \dots, B-1\}$, emitting `synthesizing` webhooks (`24%..54%`), normalizing to `44.1 kHz`, and scoring with `score_take_ar_quality`.
   - Sort candidates descending by `ar_score.score`; copy winning take `candidates[0]` to `master_wav_path`.
   - Run Demucs (`separating_stems`, `60%`), optional Seed-VC (`converting_vocals`, `72%`), 60Hz MMO extraction, and gentle `-14.0 LUFS` mastering (`mastering`, `84%`) on winning `master_wav_path` AND apply `master_clean_stereo_gentle` (`-14.0 LUFS`, `-1.0 dBTP`) to each secondary candidate WAV.
   - Upload winning master/stems/MMO via `upload_artifacts_to_r2` (`uploading`, `92%`) and secondary takes via `upload_take_mp3_to_r2`, building `takes_out` (`takeIndex: 0..B-1`, `takes_out[0]["audio_url"] == master_mp3_url`) and setting `final_attribution = candidates[0]["attribution"]`.

---

## 3. Pass 2 (`M81.3`–`M81.4`) — Flutter Scored Take Switcher & `:vhunambi-v4` Deployment

### 3.1 `GenerationTake`, Vault Promotion & `44dp` Scored Take Chips (`apps/vhunambi_client/`)

```dart
// apps/vhunambi_client/lib/features/studio/domain/models/generation_pipeline_state.dart
@immutable
class GenerationTake {
  final int takeIndex;
  final int seed;
  final String audioUrl;
  final String? stemsZipUrl;
  final String? coverUrl;
  final int durationSec;
  final String? engineUsed;
  final double? score;
  final String? attribution;

  const GenerationTake({
    required this.takeIndex,
    required this.seed,
    required this.audioUrl,
    this.stemsZipUrl,
    this.coverUrl,
    this.durationSec = 180,
    this.engineUsed,
    this.score,
    this.attribution,
  });

  factory GenerationTake.fromJson(Map<String, dynamic> json, {int index = 0}) {
    return GenerationTake(
      takeIndex: (json['takeIndex'] ?? json['take_index'] ?? index) is num
          ? ((json['takeIndex'] ?? json['take_index'] ?? index) as num).toInt()
          : index,
      seed: (json['seed'] as num?)?.toInt() ?? 0,
      audioUrl:
          (json['audioUrl'] ?? json['audio_url'] ?? json['masterMp3Url'] ?? '')
              .toString(),
      stemsZipUrl: (json['stemsZipUrl'] ?? json['stems_zip_url'])?.toString(),
      coverUrl: (json['coverUrl'] ?? json['cover_url'])?.toString(),
      durationSec:
          ((json['durationSec'] ?? json['duration_sec']) as num?)?.toInt() ??
          180,
      engineUsed: (json['engineUsed'] ?? json['engine_used'])?.toString(),
      score: (json['score'] as num?)?.toDouble(),
      attribution: json['attribution']?.toString(),
    );
  }
}
```

In `GenerationPipelineNotifier.selectActiveTake(int index)` (`generation_pipeline_providers.dart`), also synchronize `libraryTracksProvider` so switching takes updates the Vault record's `remoteAudioUrl`:

```dart
  void selectActiveTake(int index) {
    final current = state;
    if (current == null || current.takes.isEmpty) return;
    final clamped = index.clamp(0, current.takes.length - 1);
    final updated = current.copyWith(activeTakeIndex: clamped);
    state = updated;
    final nextTrack = updated.activeCompletedTrack;
    if (nextTrack != null && nextTrack.masterMp3Url.isNotEmpty) {
      final normalizedUrl = AppConstants.normalizeCloudMediaUrl(
        nextTrack.masterMp3Url,
      );
      try {
        _ref
            .read(playerStateProvider.notifier)
            .playTrack(nextTrack.copyWith(masterMp3Url: normalizedUrl).toTrack());
      } catch (_) {}
      try {
        final vaultTracks = _ref.read(libraryTracksProvider);
        final existing = vaultTracks
            .cast<LibraryTrack?>()
            .firstWhere((t) => t?.id == nextTrack.id, orElse: () => null);
        if (existing != null && existing.remoteAudioUrl != normalizedUrl) {
          _ref.read(libraryTracksProvider.notifier).addTrack(
                existing.copyWith(
                  remoteAudioUrl: normalizedUrl,
                  durationSeconds: nextTrack.duration.inSeconds,
                  updatedAtMs: DateTime.now().millisecondsSinceEpoch,
                ),
              );
        }
      } catch (_) {}
    }
  }
```

In `GenerationPipelineCard` (`generation_pipeline_card.dart`), enforce `minHeight: 44` (`STD-UIUX-001`) and render sibling `Text('Take ${i + 1}')` + optional score pill (`Key('pipeline_take_score_$i')`) so `find.text('Take 1')` remains 100% intact:

```dart
InkWell(
  key: Key('pipeline_take_chip_$i'),
  onTap: () => ref
      .read(generationProgressProvider.notifier)
      .selectActiveTake(i),
  borderRadius: AppRadius.pillBorder,
  child: ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 44),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.brandPrimary
            : AppColors.surfaceSecondaryOf(context),
        borderRadius: AppRadius.pillBorder,
        border: Border.all(
          color: isSelected
              ? AppColors.brandPrimary
              : AppColors.borderSubtleOf(context),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (i == 0 && take.score != null) ...[
            PhosphorIcon(
              PhosphorIconsFill.sparkle,
              size: 13,
              color: isSelected
                  ? AppColors.brandContrast
                  : AppColors.coinGold,
            ),
            const SizedBox(width: 5),
          ],
          Text(
            'Take ${i + 1}',
            style: AppTypography.caption.copyWith(
              color: isSelected
                  ? AppColors.brandContrast
                  : AppColors.textPrimaryOf(context),
              fontWeight: FontWeight.w800,
            ),
          ),
          if (take.score != null) ...[
            const SizedBox(width: 6),
            Text(
              key: Key('pipeline_take_score_$i'),
              '${(take.score! * 100).round()}%',
              style: AppTypography.badge.copyWith(
                color: isSelected
                    ? AppColors.brandContrast
                    : AppColors.textSecondaryOf(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    ),
  ),
)
```

### 3.2 `tools/zr-studio-gpu/Dockerfile` (`:vhunambi-v4`) & `Dockerfile.delta`

```dockerfile
# Dockerfile.delta — Fast multi-model router upgrade onto ndugelo/zr-studio-gpu:vhunambi-v4
FROM ndugelo/zr-studio-gpu:vhunambi-v3
WORKDIR /app

ENV PYTHONUNBUFFERED=1 \
    HF_HOME=/runpod-volume/hf_cache \
    HUGGINGFACE_HUB_CACHE=/runpod-volume/hf_cache/hub \
    ZR_LORA_CACHE_DIR=/runpod-volume/lora_cache

RUN pip install --no-cache-dir "soxr>=0.4.0"

COPY model_router.py model_utils.py mmo_extractor.py stem_mastering_worker.py seed_vc_worker.py handler.py /app/

RUN python -m py_compile \
    /app/model_router.py \
    /app/model_utils.py \
    /app/mmo_extractor.py \
    /app/stem_mastering_worker.py \
    /app/seed_vc_worker.py \
    /app/handler.py

CMD [ "python", "-u", "/app/handler.py" ]
```

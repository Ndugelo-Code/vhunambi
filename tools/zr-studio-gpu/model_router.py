"""
VHUNAMBI Phase 81 — ZRMultiModelRouter, MiniMax Music 3.0 Adapter,
32kHz->44.1kHz Polyphase Resampler & Mathematical Multi-Take A&R Scorer.
"""

from __future__ import annotations

import math
import os
import secrets
import struct
import wave
from dataclasses import dataclass
from typing import Any, Dict, List, Optional, Tuple

import numpy as np

try:
    import soundfile as sf  # type: ignore
except ImportError:
    sf = None  # type: ignore

TARGET_SAMPLE_RATE = 44100


def read_wav_float32(wav_path: str) -> Tuple[np.ndarray, int]:
    """Reads a WAV file into float32 (frames, channels), using stdlib wave when soundfile is absent."""
    if sf is not None:
        data, sr = sf.read(wav_path, dtype="float32", always_2d=True)
        return np.asarray(data, dtype=np.float32), int(sr)

    with wave.open(wav_path, "rb") as wf:
        sr = wf.getframerate()
        channels = max(1, wf.getnchannels())
        sampwidth = wf.getsampwidth()
        n_frames = wf.getnframes()
        raw = wf.readframes(n_frames)

    if sampwidth == 2:
        arr = np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768.0
    elif sampwidth == 4:
        arr = np.frombuffer(raw, dtype=np.int32).astype(np.float32) / 2147483648.0
    elif sampwidth == 3:
        raw_u8 = np.frombuffer(raw, dtype=np.uint8).reshape(-1, 3)
        signed = (
            raw_u8[:, 0].astype(np.int32)
            | (raw_u8[:, 1].astype(np.int32) << 8)
            | (raw_u8[:, 2].astype(np.int32) << 16)
        )
        signed = np.where(signed & 0x800000, signed - 0x1000000, signed)
        arr = signed.astype(np.float32) / 8388608.0
    else:
        arr = (np.frombuffer(raw, dtype=np.uint8).astype(np.float32) - 128.0) / 128.0

    frames = arr.reshape(-1, channels)
    return frames, int(sr)


def write_wav_float32(
    wav_path: str, data: np.ndarray, sr: int, subtype: str = "PCM_24"
) -> None:
    """Writes float32 (frames, channels) WAV safely via soundfile or stdlib wave."""
    arr = np.asarray(data, dtype=np.float32)
    if arr.ndim == 1:
        arr = arr[:, None]
    elif arr.ndim == 2 and arr.shape[0] <= 8 and arr.shape[1] > arr.shape[0]:
        # Guard callers passing (channels, frames) instead of (frames, channels)
        arr = arr.T

    if sf is not None:
        sf.write(wav_path, arr, int(sr), subtype=subtype)
        return

    clipped = np.clip(arr, -1.0, 1.0)
    pcm16 = (clipped * 32767.0).astype(np.int16)
    with wave.open(wav_path, "wb") as wf:
        wf.setnchannels(int(pcm16.shape[1]))
        wf.setsampwidth(2)
        wf.setframerate(int(sr))
        wf.writeframes(pcm16.tobytes())


def _offload_cuda_caches() -> None:
    """Releases unused CUDA allocations before cross-model swaps on L40S 48GB."""
    import sys

    if "torch" not in sys.modules:
        return
    try:
        import torch  # type: ignore

        if torch.cuda.is_available():
            free_bytes, _total_bytes = torch.cuda.mem_get_info()
            if free_bytes < 20 * 1024 * 1024 * 1024:
                torch.cuda.empty_cache()
    except Exception:
        pass


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


SUPPORTED_SAMPLE_RATES = (44100, 48000)


def normalize_wav_to_sr(
    wav_path: str, target_sr: int = TARGET_SAMPLE_RATE
) -> Dict[str, Any]:
    """
    Resamples arbitrary WAV sample rates (such as MiniMax Music 3.0's native 32kHz WAV)
    to 44.1kHz or 48kHz stereo PCM_24 using soxr VHQ, scipy rational polyphase, or
    vectorized NumPy interpolation on offline CPU dev hosts.
    """
    clean_sr = 48000 if int(target_sr or TARGET_SAMPLE_RATE) >= 48000 else 44100
    data, in_sr = read_wav_float32(wav_path)
    if data.shape[1] == 1:
        data = np.repeat(data, 2, axis=1)
    elif data.shape[1] > 2:
        data = data[:, :2]

    resampled = False
    if int(in_sr) != clean_sr:
        resampled = True
        try:
            import soxr  # type: ignore

            data = soxr.resample(data, int(in_sr), clean_sr, quality="VHQ")
        except ImportError:
            try:
                from scipy import signal as sp_signal  # type: ignore

                g = math.gcd(int(in_sr), clean_sr)
                up = clean_sr // g
                down = int(in_sr) // g
                data = sp_signal.resample_poly(data, up=up, down=down, axis=0)
            except ImportError:
                in_len = data.shape[0]
                out_len = max(1, int(round(in_len * float(clean_sr) / float(in_sr))))
                x_old = np.linspace(0.0, 1.0, in_len, endpoint=False)
                x_new = np.linspace(0.0, 1.0, out_len, endpoint=False)
                ch0 = np.interp(x_new, x_old, data[:, 0])
                ch1 = np.interp(x_new, x_old, data[:, 1])
                data = np.column_stack([ch0, ch1])
        data = np.asarray(data, dtype=np.float32)
        write_wav_float32(wav_path, data, clean_sr, subtype="PCM_24")

    return {
        "input_sr": int(in_sr),
        "output_sr": clean_sr,
        "resampled": resampled,
        "frames": int(data.shape[0]),
        "duration_sec": round(float(data.shape[0]) / float(clean_sr), 3),
    }


def normalize_wav_to_44k1(
    wav_path: str, target_sr: int = TARGET_SAMPLE_RATE
) -> Dict[str, Any]:
    """Backward-compatible wrapper around normalize_wav_to_sr."""
    return normalize_wav_to_sr(wav_path, target_sr=target_sr)


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
    data, sr = read_wav_float32(wav_path)
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


class MiniMax3Backend:
    """Client adapter for co-hosted sglang-omni MiniMaxAI/MiniMax-Music3 /v1/audio/speech."""

    @staticmethod
    def synthesize(
        lyrics: str,
        prompt: str,
        duration_sec: int,
        seed: int,
        output_wav_path: str,
        sglang_url: str,
    ) -> Optional[Dict[str, Any]]:
        if not sglang_url or not lyrics.strip():
            return None
        try:
            import requests

            resp = requests.post(
                sglang_url,
                json={
                    "model": os.environ.get(
                        "MINIMAX_MODEL_ID", "MiniMaxAI/MiniMax-Music3"
                    ),
                    "input": lyrics,
                    "prompt": prompt,
                    "seed": int(seed),
                    "duration": int(duration_sec),
                    "response_format": "wav",
                },
                timeout=max(120, int(duration_sec) * 2),
            )
            if resp.status_code == 200 and len(resp.content) > 512:
                with open(output_wav_path, "wb") as f:
                    f.write(resp.content)
                sr_meta = normalize_wav_to_44k1(output_wav_path)
                return {
                    "engine": "minimax_music_3",
                    "attribution": "MiniMax-Music3",
                    "seed": int(seed),
                    "duration_sec": int(duration_sec),
                    **sr_meta,
                }
            print(
                f"[ZR-Router] MiniMax sglang returned {resp.status_code}; falling back to ACE-Step XL-SFT",
                flush=True,
            )
        except Exception as exc:
            print(
                f"[ZR-Router] MiniMax sglang unreachable ({exc}); falling back to ACE-Step XL-SFT",
                flush=True,
            )
        return None


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

        if str(job_input.get("job_type") or "").strip().lower() == "section_repaint" or job_input.get("repaint_config"):
            return RouteDecision(
                resolved_engine="ace_step_xl_base",
                attribution_tag=None,
                infer_steps=int(song_spec.get("infer_steps") or 60),
                guidance_scale=float(song_spec.get("guidance_scale") or 12.0),
                reason="postgen_section_repaint",
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
            _offload_cuda_caches()
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
            mm_res = MiniMax3Backend.synthesize(
                lyrics=formatted_lyrics,
                prompt=rich_prompt,
                duration_sec=duration_sec,
                seed=int(seed),
                output_wav_path=output_wav_path,
                sglang_url=sglang_url,
            )
            if mm_res is not None:
                return mm_res

        # ACE-Step 1.5 XL ({turbo, sft, base}) or truthful fallback (clears MiniMax attribution!)
        _offload_cuda_caches()
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

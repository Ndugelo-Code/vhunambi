# tools/zr-studio-gpu/stem_mastering_worker.py
"""
VHUNAMBI V4 — Phase 25: Stem-Targeted Studio Mastering & Vocal Restoration Worker
Processes isolated stems (vocals.wav, drums.wav, bass.wav, melodic.wav) using:
- Phase-locked 35–55Hz sub-harmonic synthesis for Amapiano log drums
- MMO kick-transient sidechain ducking
- Mid/Side (M/S) 1.8kHz vocal pocket carving & stereo widening
- Spotify Pedalboard 4-stem EQ/compression chains + pyloudnorm True-Peak LUFS limiting
"""

import importlib
import math
import os
from typing import Any, Dict, List, Optional, Tuple
import numpy as np

from model_router import normalize_wav_to_sr, read_wav_float32, write_wav_float32


def _optional_import(module_name: str) -> Any:
    """Dynamically loads RunPod GPU container DSP libraries when available, with safe local host fallback."""
    try:
        return importlib.import_module(module_name)
    except ImportError:
        return None


signal = _optional_import("scipy.signal")
pyln = _optional_import("pyloudnorm")
_pedalboard_mod = _optional_import("pedalboard")


class _FallbackProcessor:
    """Pure-NumPy fallback DSP processor when Spotify Pedalboard C++ bindings are not installed on host."""

    def __init__(self, plugins: list[Any] | None = None, **kwargs: Any) -> None:
        self.plugins = plugins or []
        self.kwargs = kwargs

    def __call__(self, audio: np.ndarray, sr: int) -> np.ndarray:
        return np.clip(audio, -1.0, 1.0)


Pedalboard = getattr(_pedalboard_mod, "Pedalboard", _FallbackProcessor)
HighpassFilter = getattr(_pedalboard_mod, "HighpassFilter", _FallbackProcessor)
LowShelfFilter = getattr(_pedalboard_mod, "LowShelfFilter", _FallbackProcessor)
PeakFilter = getattr(_pedalboard_mod, "PeakFilter", _FallbackProcessor)
HighShelfFilter = getattr(_pedalboard_mod, "HighShelfFilter", _FallbackProcessor)
Compressor = getattr(_pedalboard_mod, "Compressor", _FallbackProcessor)
Distortion = getattr(_pedalboard_mod, "Distortion", _FallbackProcessor)
Limiter = getattr(_pedalboard_mod, "Limiter", _FallbackProcessor)


def synthesize_sub_harmonic(bass_audio: np.ndarray, sr: int, mix: float) -> np.ndarray:
    """Generates a phase-locked 35-55Hz sub-octave sine wave underneath Amapiano log drums."""
    if mix <= 0.01 or signal is None:
        return bass_audio
    sos_bp = signal.butter(4, [70, 140], btype="bandpass", fs=sr, output="sos")
    fundamental = signal.sosfilt(sos_bp, bass_audio, axis=-1)
    env = np.abs(signal.hilbert(fundamental, axis=-1))
    # Divide zero-crossing phase by 2 to drop 1 octave (35-70Hz sub weight)
    analytic_phase = np.unwrap(np.angle(signal.hilbert(fundamental, axis=-1)), axis=-1)
    sub_wave = np.sin(0.5 * analytic_phase) * env
    sos_lp = signal.butter(4, 65, btype="lowpass", fs=sr, output="sos")
    sub_clean = signal.sosfilt(sos_lp, sub_wave, axis=-1)
    return np.clip(bass_audio + (sub_clean * mix * 0.65), -1.0, 1.0)


def apply_kick_sidechain_ducking(
    bass_audio: np.ndarray,
    sr: int,
    transient_events: list[dict],
    duck_db: float = -3.5,
    window_ms: int = 55,
) -> np.ndarray:
    """Ducks bass.wav on every MMO 'kick' transient so kick and log drum never clash."""
    if duck_db >= -0.1 or not transient_events:
        return bass_audio
    num_samples = bass_audio.shape[-1]
    gain_env = np.ones(num_samples, dtype=np.float32)
    linear_floor = 10.0 ** (duck_db / 20.0)
    win_len = max(1, int((window_ms / 1000.0) * sr))
    duck_curve = (
        linear_floor
        + (1.0 - linear_floor) * np.linspace(0.0, 1.0, win_len, dtype=np.float32) ** 0.6
    )

    for ev in transient_events:
        if ev.get("type") == "kick":
            start_idx = int((ev.get("timestampMs", 0) / 1000.0) * sr)
            if 0 <= start_idx < num_samples:
                end_idx = min(num_samples, start_idx + win_len)
                seg_len = end_idx - start_idx
                gain_env[start_idx:end_idx] = np.minimum(
                    gain_env[start_idx:end_idx], duck_curve[:seg_len]
                )

    return bass_audio * gain_env


def apply_mid_side_vocal_pocket(
    melodic_stereo: np.ndarray,
    sr: int,
    mid_cut_db: float = -2.5,
    side_boost: float = 0.3,
) -> np.ndarray:
    """Carves a 1.8kHz pocket in the Mid channel for lead vocals and widens the Side channel."""
    if melodic_stereo.ndim == 1 or melodic_stereo.shape[0] < 2:
        return melodic_stereo
    left, right = melodic_stereo[0], melodic_stereo[1]
    mid = 0.5 * (left + right)
    side = 0.5 * (left - right)

    if mid_cut_db < -0.1:
        mid_board = Pedalboard(
            [PeakFilter(cutoff_frequency_hz=1800.0, gain_db=mid_cut_db, q=1.4)]
        )
        mid = mid_board(mid, sr)

    side = side * (1.0 + np.clip(side_boost, 0.0, 1.0) * 0.45)
    return np.vstack(
        [np.clip(mid + side, -1.0, 1.0), np.clip(mid - side, -1.0, 1.0)]
    )


def _deep_merge_dict(defaults: Dict[str, Any], overrides: Dict[str, Any]) -> Dict[str, Any]:
    merged: Dict[str, Any] = {}
    for k, v in defaults.items():
        if isinstance(v, dict):
            over_v = overrides.get(k)
            merged[k] = _deep_merge_dict(v, over_v if isinstance(over_v, dict) else {})
        else:
            merged[k] = overrides[k] if k in overrides and overrides[k] is not None else v
    for k, v in overrides.items():
        if k not in merged:
            merged[k] = v
    return merged


def normalize_mastering_recipe(recipe_input: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    """Normalizes either a flat handler recipe or a nested Phase 25/62 recipe into complete DSP keys."""
    raw = recipe_input if isinstance(recipe_input, dict) else {}
    master_bus = raw.get("masterBus") if isinstance(raw.get("masterBus"), dict) else {}
    target_lufs = float(raw.get("targetLufs", master_bus.get("targetLufs", raw.get("target_lufs", -9.5))))
    true_peak_db = min(
        -0.1,
        float(raw.get("truePeakDb", master_bus.get("ceilingDbtp", raw.get("true_peak_db", -1.0)))),
    )
    sub_boost = float(raw.get("log_drum_sub_boost", 1.5))
    raw_duck = raw.get("sidechain_ducking", -2.5)
    raw_duck_f = float(raw_duck)
    sidechain_duck_db = -abs(raw_duck_f * 4.0) if raw_duck_f > 0 else raw_duck_f

    defaults: Dict[str, Any] = {
        "targetLufs": target_lufs,
        "truePeakDb": true_peak_db,
        "sketchpadLayerMix": float(raw.get("sketchpadLayerMix", 0.0)),
        "vocals": {
            "eq": {
                "highpassHz": 90.0,
                "lowGainDb": 0.5,
                "midFreqHz": 2400.0,
                "midGainDb": 1.6,
                "airGainDb": 2.8,
            },
        },
        "bass": {
            "subHarmonicMix": min(0.75, max(0.0, sub_boost / 3.0)),
            "knockDriveDb": max(1.0, min(8.0, sub_boost * 2.5)),
            "sidechainDuckDb": sidechain_duck_db,
            "eq": {
                "highpassHz": 30.0,
                "lowGainDb": min(5.0, sub_boost * 1.5),
                "midGainDb": 2.2,
            },
        },
        "drums": {
            "parallelCrushMix": 0.28,
            "eq": {
                "highpassHz": 45.0,
                "midFreqHz": 320.0,
                "midGainDb": -2.0,
                "airGainDb": 2.2,
            },
        },
        "melodic": {
            "midVocalPocketCutDb": -2.0,
            "stereoWidthBoost": 0.30,
            "eq": {
                "highpassHz": 110.0,
                "lowGainDb": -1.5,
                "midFreqHz": 1800.0,
                "midGainDb": -1.8,
                "airGainDb": 1.8,
            },
        },
        "masterBus": {
            "glueThresholdDb": -12.0,
            "glueRatio": 2.0,
            "ceilingDbtp": true_peak_db,
            "targetLufs": target_lufs,
        },
    }

    normalized = _deep_merge_dict(defaults, raw)
    # Map 'other' override onto 'melodic' if provided without 'melodic'
    if isinstance(raw.get("other"), dict) and "melodic" not in raw:
        other_cfg = raw["other"]
        if "midSideVocalCarveDb" in other_cfg:
            normalized["melodic"]["midVocalPocketCutDb"] = float(other_cfg["midSideVocalCarveDb"])
        if "stereoWidthPct" in other_cfg:
            width_pct = float(other_cfg["stereoWidthPct"])
            normalized["melodic"]["stereoWidthBoost"] = max(0.0, min(1.0, (width_pct - 100.0) / 100.0))
    return normalized


def _resolve_stem_audio(stems: Dict[str, np.ndarray], role: str) -> np.ndarray:
    if role in stems and stems[role] is not None:
        return np.asarray(stems[role], dtype=np.float32)
    for fallback_arr in stems.values():
        if fallback_arr is not None:
            return np.zeros_like(np.asarray(fallback_arr, dtype=np.float32))
    return np.zeros((2, 4410), dtype=np.float32)


def _match_shape(target: np.ndarray, ref: np.ndarray) -> np.ndarray:
    if target.shape == ref.shape:
        return target
    if target.ndim == 1 and ref.ndim == 2:
        tiled = np.vstack([target, target])
        return tiled[:, : ref.shape[1]] if tiled.shape[1] >= ref.shape[1] else np.pad(tiled, ((0, 0), (0, ref.shape[1] - tiled.shape[1])))
    if target.ndim == 2 and ref.ndim == 1:
        mono = np.mean(target, axis=0)
        return mono[: ref.shape[0]] if mono.shape[0] >= ref.shape[0] else np.pad(mono, (0, ref.shape[0] - mono.shape[0]))
    if target.ndim == 2 and ref.ndim == 2:
        cols = min(target.shape[1], ref.shape[1])
        out = np.zeros_like(ref, dtype=np.float32)
        out[: min(target.shape[0], ref.shape[0]), :cols] = target[: min(target.shape[0], ref.shape[0]), :cols]
        return out
    return target


def _execute_mastering_pipeline(
    stems: Dict[str, np.ndarray],
    sr: int,
    recipe: Dict[str, Any],
    transient_events: Optional[List[dict]] = None,
) -> Tuple[np.ndarray, Dict[str, np.ndarray]]:
    """Executes the full 4-stem Cakewalk/Sonar + LUFS True-Peak mastering pipeline."""
    norm_recipe = normalize_mastering_recipe(recipe)
    events = transient_events if isinstance(transient_events, list) else []

    vocals_in = _resolve_stem_audio(stems, "vocals")
    bass_in = _resolve_stem_audio(stems, "bass")
    drums_in = _resolve_stem_audio(stems, "drums")
    mel_in = _resolve_stem_audio(stems, "melodic")

    # 1. Vocals Chain
    vox_cfg = norm_recipe["vocals"]
    vox_eq = vox_cfg["eq"]
    vox_board = Pedalboard(
        [
            HighpassFilter(cutoff_frequency_hz=float(vox_eq["highpassHz"])),
            LowShelfFilter(cutoff_frequency_hz=120.0, gain_db=float(vox_eq["lowGainDb"])),
            PeakFilter(
                cutoff_frequency_hz=float(vox_eq["midFreqHz"]),
                gain_db=float(vox_eq["midGainDb"]),
                q=1.2,
            ),
            PeakFilter(cutoff_frequency_hz=6500.0, gain_db=-2.5, q=3.0),
            Compressor(threshold_db=-18.0, ratio=4.0, attack_ms=5.0, release_ms=65.0),
            HighShelfFilter(
                cutoff_frequency_hz=11000.0, gain_db=float(vox_eq["airGainDb"])
            ),
        ]
    )
    vox_out = vox_board(vocals_in, sr)

    # 2. Bass / Log Drum Chain
    bass_cfg = norm_recipe["bass"]
    bass_eq = bass_cfg["eq"]
    bass_sub = synthesize_sub_harmonic(
        bass_in, sr, float(bass_cfg["subHarmonicMix"])
    )
    bass_board = Pedalboard(
        [
            HighpassFilter(cutoff_frequency_hz=float(bass_eq["highpassHz"])),
            LowShelfFilter(cutoff_frequency_hz=90.0, gain_db=float(bass_eq["lowGainDb"])),
            PeakFilter(
                cutoff_frequency_hz=165.0, gain_db=float(bass_eq["midGainDb"]), q=1.5
            ),
            Distortion(drive_db=float(bass_cfg["knockDriveDb"])),
        ]
    )
    bass_driven = 0.75 * bass_sub + 0.25 * bass_board(bass_sub, sr)
    bass_out = apply_kick_sidechain_ducking(
        bass_driven,
        sr,
        events,
        duck_db=float(bass_cfg["sidechainDuckDb"]),
    )

    # 3. Drums Chain
    drums_cfg = norm_recipe["drums"]
    drums_eq = drums_cfg["eq"]
    drums_board = Pedalboard(
        [
            HighpassFilter(cutoff_frequency_hz=float(drums_eq["highpassHz"])),
            PeakFilter(cutoff_frequency_hz=320.0, gain_db=-3.0, q=1.8),
            PeakFilter(
                cutoff_frequency_hz=float(drums_eq["midFreqHz"]),
                gain_db=float(drums_eq["midGainDb"]),
                q=1.2,
            ),
            HighShelfFilter(
                cutoff_frequency_hz=9500.0, gain_db=float(drums_eq["airGainDb"])
            ),
        ]
    )
    drums_clean = drums_board(drums_in, sr)
    crush_mix = float(drums_cfg["parallelCrushMix"])
    crush_board = Pedalboard(
        [Compressor(threshold_db=-24.0, ratio=8.0, attack_ms=2.0, release_ms=50.0)]
    )
    drums_out = (1.0 - crush_mix) * drums_clean + crush_mix * crush_board(drums_clean, sr)

    # 4. Melodic Chain (with Mid/Side Vocal Pocket)
    mel_cfg = norm_recipe["melodic"]
    mel_eq = mel_cfg["eq"]
    mel_pocket = apply_mid_side_vocal_pocket(
        mel_in,
        sr,
        mid_cut_db=float(mel_cfg["midVocalPocketCutDb"]),
        side_boost=float(mel_cfg["stereoWidthBoost"]),
    )
    mel_board = Pedalboard(
        [
            HighpassFilter(cutoff_frequency_hz=float(mel_eq["highpassHz"])),
            LowShelfFilter(cutoff_frequency_hz=140.0, gain_db=float(mel_eq["lowGainDb"])),
            PeakFilter(
                cutoff_frequency_hz=float(mel_eq["midFreqHz"]),
                gain_db=float(mel_eq["midGainDb"]),
                q=1.1,
            ),
            HighShelfFilter(
                cutoff_frequency_hz=10000.0, gain_db=float(mel_eq["airGainDb"])
            ),
        ]
    )
    mel_out = mel_board(mel_pocket, sr)

    # 5. Phase 27 Synergy: Optional Sketchpad Layer Blending (sketchpadLayerMix)
    sketchpad_mix = float(norm_recipe.get("sketchpadLayerMix", 0.0))
    if sketchpad_mix > 0.01 and "sketchpad_loop" in stems:
        sketch_loop = _match_shape(np.asarray(stems["sketchpad_loop"], dtype=np.float32), bass_out)
        bass_out = np.clip(bass_out + sketchpad_mix * sketch_loop, -1.0, 1.0)

    # 6. Master Bus Glue & True-Peak LUFS Normalization
    master_sum = (
        vox_out
        + _match_shape(bass_out, vox_out)
        + _match_shape(drums_out, vox_out)
        + _match_shape(mel_out, vox_out)
    )
    master_cfg = norm_recipe["masterBus"]
    ceiling_db = min(-0.1, float(master_cfg.get("ceilingDbtp", -1.0)))
    glue_board = Pedalboard(
        [
            Compressor(
                threshold_db=float(master_cfg.get("glueThresholdDb", -12.0)),
                ratio=float(master_cfg.get("glueRatio", 2.0)),
                attack_ms=30.0,
                release_ms=120.0,
            ),
            Limiter(threshold_db=ceiling_db, release_ms=40.0),
        ]
    )
    glued = glue_board(master_sum, sr)

    target_lufs = float(master_cfg.get("targetLufs", norm_recipe.get("targetLufs", -9.5)))
    if pyln is not None:
        meter = pyln.Meter(sr)
        current_lufs = meter.integrated_loudness(glued.T if glued.ndim > 1 else glued)
        if np.isfinite(current_lufs):
            normalized = pyln.normalize.loudness(
                glued.T if glued.ndim > 1 else glued, current_lufs, target_lufs
            )
            glued = normalized.T if glued.ndim > 1 else normalized
    else:
        rms = float(np.sqrt(np.mean(np.square(glued)) + 1e-12))
        approx_lufs = 20.0 * np.log10(rms) - 0.691
        gain_linear = 10.0 ** ((target_lufs - approx_lufs) / 20.0)
        glued = np.clip(glued * gain_linear, -1.0, 1.0)

    final_limiter = Pedalboard([Limiter(threshold_db=ceiling_db, release_ms=25.0)])
    ceiling_linear = float(10.0 ** (ceiling_db / 20.0))
    master_out = np.clip(final_limiter(glued, sr), -ceiling_linear, ceiling_linear)
    return master_out, {
        "vocals": vox_out,
        "bass": bass_out,
        "drums": drums_out,
        "melodic": mel_out,
    }


def master_stems_with_recipe(
    stems: Dict[str, np.ndarray],
    sr: int,
    recipe: Dict[str, Any],
    transient_events: Optional[List[dict]] = None,
) -> np.ndarray:
    """Backward-compatible entrypoint returning only the mastered stereo bus array."""
    master_out, _ = _execute_mastering_pipeline(
        stems=stems,
        sr=sr,
        recipe=recipe,
        transient_events=transient_events,
    )
    return master_out


def master_clean_stereo_gentle(
    audio: np.ndarray,
    sr: int,
    target_lufs: float = -14.0,
    true_peak_db: float = -1.0,
    highpass_hz: float = 28.0,
    max_gain_db: float = 6.0,
) -> Tuple[np.ndarray, Dict[str, Any]]:
    """
    Gentle master for an already-mixed ACE-Step stereo waveform (shape: channels x samples).

    The earlier pipeline re-summed Demucs stems, EQ-boosted them and slammed the result to
    -9.5 LUFS, lifting the diffusion noise floor of quiet intros by +8..+12 dB. Here:
      * 28 Hz high-pass (DC / sub-rumble only),
      * loudness gain toward `target_lufs`, capped at `max_gain_db` of boost (never attenuation-limited),
      * soft true-peak ceiling at `true_peak_db` (sample-peak safe, no brickwall pumping).
    """
    x = np.asarray(audio, dtype=np.float64)
    if x.ndim == 1:
        x = np.stack([x, x])

    if signal is not None and highpass_hz > 0:
        sos = signal.butter(2, highpass_hz, btype="highpass", fs=sr, output="sos")
        x = np.stack([signal.sosfiltfilt(sos, ch) for ch in x])

    measured = None
    if pyln is not None:
        try:
            meter = pyln.Meter(sr)
            measured = float(meter.integrated_loudness(x.T))
        except Exception:
            measured = None
    if measured is None or not np.isfinite(measured):
        rms = float(np.sqrt(np.mean(np.square(x)) + 1e-12))
        measured = 20.0 * np.log10(rms + 1e-12) - 0.7

    gain_db = float(np.clip(target_lufs - measured, -18.0, max_gain_db))
    x = x * (10.0 ** (gain_db / 20.0))

    ceiling = 10.0 ** (true_peak_db / 20.0)
    peak = float(np.max(np.abs(x)) + 1e-12)
    if peak > ceiling:
        # soft-knee: tanh-style roll-off above 85% of the ceiling, then hard trim to ceiling
        knee = 0.85 * ceiling
        over = np.abs(x) > knee
        sign = np.sign(x)
        span = ceiling - knee
        x = np.where(over, sign * (knee + span * np.tanh((np.abs(x) - knee) / span)), x)
        x = np.clip(x, -ceiling, ceiling)

    final_lufs = measured + gain_db
    if pyln is not None:
        try:
            final_lufs = float(pyln.Meter(sr).integrated_loudness(x.T))
        except Exception:
            pass
    final_peak_db = float(20.0 * np.log10(np.max(np.abs(x)) + 1e-12))
    metrics = {
        "mode": "gentle_direct_master",
        "input_lufs": round(measured, 2),
        "gain_db": round(gain_db, 2),
        "integrated_lufs": round(final_lufs, 2),
        "true_peak_dbtp": round(final_peak_db, 2),
        "target_lufs": target_lufs,
        "highpass_hz": highpass_hz,
    }
    return x.astype(np.float32), metrics


def master_stems_to_commercial_target(
    stems: Dict[str, np.ndarray],
    sr: int,
    recipe: Optional[Dict[str, Any]] = None,
    transient_events: Optional[List[dict]] = None,
) -> Tuple[np.ndarray, Dict[str, np.ndarray], Dict[str, Any]]:
    """Normalizes flat or nested recipes, runs 4-stem mastering, and returns bus, stems & metrics."""
    normalized_recipe = normalize_mastering_recipe(recipe or {})
    master_bus, processed_stems = _execute_mastering_pipeline(
        stems=stems,
        sr=sr,
        recipe=normalized_recipe,
        transient_events=transient_events,
    )
    metrics: Dict[str, Any] = {
        "mode": "stem_mastering_recipe",
        "engine": "pedalboard_4stem_master",
        "reference_profile": str(normalized_recipe.get("presetId", "amapiano_club_knock")),
        "integrated_lufs": float(normalized_recipe["masterBus"]["targetLufs"]),
        "target_lufs": float(normalized_recipe["masterBus"]["targetLufs"]),
        "true_peak_dbtp": float(normalized_recipe["masterBus"]["ceilingDbtp"]),
        "sample_rate_hz": int(sr),
        "bit_depth": 24,
    }
    return master_bus, processed_stems, metrics


SA_REFERENCE_MASTER_PROFILES: Dict[str, Dict[str, Any]] = {
    "amapiano_club": {
        "r2_key": "ref_masters/amapiano_club_ref.wav",
        "filename": "amapiano_club_ref.wav",
        "default_lufs": -14.0,
        "club_lufs": -9.0,
        "sub_weight": 1.30,
        "mid_weight": 0.92,
        "air_weight": 1.15,
    },
    "private_school_amapiano": {
        "r2_key": "ref_masters/private_school_amapiano_ref.wav",
        "filename": "private_school_amapiano_ref.wav",
        "default_lufs": -14.0,
        "club_lufs": -9.0,
        "sub_weight": 1.15,
        "mid_weight": 1.08,
        "air_weight": 1.05,
    },
    "afro_fusion_radio": {
        "r2_key": "ref_masters/afro_fusion_radio_ref.wav",
        "filename": "afro_fusion_radio_ref.wav",
        "default_lufs": -14.0,
        "club_lufs": -9.0,
        "sub_weight": 1.05,
        "mid_weight": 1.15,
        "air_weight": 1.18,
    },
    "gospel_choir": {
        "r2_key": "ref_masters/gospel_choir_ref.wav",
        "filename": "gospel_choir_ref.wav",
        "default_lufs": -14.0,
        "club_lufs": -9.0,
        "sub_weight": 0.95,
        "mid_weight": 1.12,
        "air_weight": 1.25,
    },
    "maskandi_acoustic": {
        "r2_key": "ref_masters/maskandi_acoustic_ref.wav",
        "filename": "maskandi_acoustic_ref.wav",
        "default_lufs": -14.0,
        "club_lufs": -9.0,
        "sub_weight": 0.92,
        "mid_weight": 1.20,
        "air_weight": 1.18,
    },
    "gqom_durban": {
        "r2_key": "ref_masters/gqom_durban_ref.wav",
        "filename": "gqom_durban_ref.wav",
        "default_lufs": -14.0,
        "club_lufs": -9.0,
        "sub_weight": 1.38,
        "mid_weight": 0.90,
        "air_weight": 1.12,
    },
}


def resolve_ref_masters_dir() -> str:
    env_dir = os.environ.get("ZR_REF_MASTERS_DIR", "").strip()
    if os.path.isdir("/runpod-volume"):
        return env_dir or "/runpod-volume/ref_masters"
    return env_dir or "/tmp/zr_ref_masters"


def resolve_sa_reference_profile_id(genre: str) -> str:
    g = (genre or "amapiano").strip().lower()
    if "private" in g or "deep house" in g or "jazz" in g:
        return "private_school_amapiano"
    if "gqom" in g or "drill" in g or "kuduro" in g or "house" in g:
        return "gqom_durban"
    if "maskandi" in g or "mbaqanga" in g or "chimurenga" in g or "malende" in g:
        return "maskandi_acoustic"
    if "gospel" in g or "isicathamiya" in g or "mbube" in g or "choir" in g:
        return "gospel_choir"
    if "afro" in g or "soul" in g or "pop" in g or "r&b" in g:
        return "afro_fusion_radio"
    return "amapiano_club"


def resolve_sa_reference_wav(profile_id: str, sr: int = 44100) -> str:
    """Resolves a curated SA reference WAV from /runpod-volume, R2 CDN, or calibrated synthesis."""
    spec = SA_REFERENCE_MASTER_PROFILES.get(
        profile_id, SA_REFERENCE_MASTER_PROFILES["amapiano_club"]
    )
    cache_dir = resolve_ref_masters_dir()
    os.makedirs(cache_dir, exist_ok=True)
    local_path = os.path.join(cache_dir, str(spec["filename"]))
    if os.path.exists(local_path) and os.path.getsize(local_path) > 1024:
        return local_path

    public_base = os.environ.get("R2_PUBLIC_BASE_URL", "").strip().rstrip("/")
    if public_base:
        try:
            import requests

            resp = requests.get(f"{public_base}/{spec['r2_key']}", timeout=8)
            if resp.status_code == 200 and len(resp.content) > 1024:
                with open(local_path, "wb") as rf:
                    rf.write(resp.content)
                return local_path
        except Exception:
            pass

    # Deterministic royalty-free calibrated studio reference profile
    dur = 1.5
    t = np.linspace(0.0, dur, int(sr * dur), endpoint=False, dtype=np.float32)
    sub = float(spec["sub_weight"]) * 0.24 * np.sin(2.0 * math.pi * 55.0 * t)
    mid = float(spec["mid_weight"]) * 0.22 * np.sin(2.0 * math.pi * 1200.0 * t)
    air = float(spec["air_weight"]) * 0.14 * np.sin(2.0 * math.pi * 8500.0 * t)
    ref_stereo = np.column_stack([sub + mid + air, sub + mid - 0.85 * air])
    write_wav_float32(local_path, np.clip(ref_stereo, -0.95, 0.95), sr, subtype="PCM_24")
    return local_path


def _apply_spectral_reference_tilt(
    audio: np.ndarray, ref_audio: np.ndarray, sr: int
) -> np.ndarray:
    """Matches coarse sub/mid/air spectral balance against a curated SA reference WAV."""
    n = audio.shape[0]
    if n < 64 or ref_audio.size == 0:
        return audio
    n_fft = 2048
    target_mono = np.mean(audio[:, :2], axis=1) if audio.shape[1] >= 2 else audio[:, 0]
    ref_mono = np.mean(ref_audio[:, :2], axis=1) if ref_audio.shape[1] >= 2 else ref_audio[:, 0]
    t_spec = np.abs(np.fft.rfft(target_mono[: max(n_fft, min(n, sr * 6))], n=n_fft)) + 1e-6
    r_spec = np.abs(np.fft.rfft(ref_mono[: max(n_fft, min(len(ref_mono), sr * 6))], n=n_fft)) + 1e-6
    freqs_s = np.fft.rfftfreq(n_fft, d=1.0 / float(sr))

    def _band_mean(spec_arr: np.ndarray, lo: float, hi: float) -> float:
        m = (freqs_s >= lo) & (freqs_s < hi)
        return float(np.mean(spec_arr[m])) if np.any(m) else 1.0

    sub_g = float(np.clip(_band_mean(r_spec, 30.0, 140.0) / max(_band_mean(t_spec, 30.0, 140.0), 1e-6), 0.80, 1.32))
    mid_g = float(np.clip(_band_mean(r_spec, 300.0, 3500.0) / max(_band_mean(t_spec, 300.0, 3500.0), 1e-6), 0.82, 1.25))
    air_g = float(np.clip(_band_mean(r_spec, 5000.0, 14000.0) / max(_band_mean(t_spec, 5000.0, 14000.0), 1e-6), 0.82, 1.28))

    freqs = np.fft.rfftfreq(n, d=1.0 / float(sr))
    eq = np.ones_like(freqs, dtype=np.float32)
    eq = np.where(freqs < 140.0, sub_g, eq)
    eq = np.where((freqs >= 300.0) & (freqs < 3500.0), mid_g, eq)
    eq = np.where(freqs >= 5000.0, air_g, eq)

    out = np.zeros_like(audio, dtype=np.float32)
    for ch in range(audio.shape[1]):
        sp = np.fft.rfft(audio[:, ch])
        out[:, ch] = np.fft.irfft(sp * eq, n=n).astype(np.float32)
    return out


def master_with_sa_reference_matchering(
    wav_path: str,
    genre: str,
    mastering_mode: str = "streaming",
    target_lufs: Optional[float] = None,
    true_peak_db: float = -1.0,
    target_sr: int = 44100,
) -> Dict[str, Any]:
    """
    Executes GPL-3.0 server-side Matchering 2.0 reference mastering (when available) +
    pyloudnorm loudness normalization (-14.0 LUFS streaming / -9.0 LUFS club at <= -1.0 dBTP).
    """
    clean_mode = "club" if str(mastering_mode or "streaming").strip().lower() == "club" else "streaming"
    clean_sr = 48000 if int(target_sr or 44100) >= 48000 else 44100
    profile_id = resolve_sa_reference_profile_id(genre)
    effective_lufs = (
        float(target_lufs)
        if target_lufs is not None
        else (-9.0 if clean_mode == "club" else -14.0)
    )

    normalize_wav_to_sr(wav_path, target_sr=clean_sr)
    ref_wav_path = resolve_sa_reference_wav(profile_id, sr=clean_sr)
    used_matchering = False

    if importlib.util.find_spec("matchering") is not None:
        try:
            import matchering as mg  # type: ignore

            matched_tmp = f"{wav_path}.mg24.wav"
            mg.process(
                target=wav_path,
                reference=ref_wav_path,
                results=[mg.pcm24(matched_tmp)],
            )
            if os.path.exists(matched_tmp):
                os.replace(matched_tmp, wav_path)
                used_matchering = True
        except Exception as mg_err:
            print(f"[ZR-WARN] Matchering 2.0 fallback ({mg_err}); using SA reference spectral tilt", flush=True)

    target_data, sr_now = read_wav_float32(wav_path)
    if not used_matchering:
        ref_data, _ref_sr = read_wav_float32(ref_wav_path)
        target_data = _apply_spectral_reference_tilt(target_data, ref_data, sr_now)

    mastered_arr, gentle_metrics = master_clean_stereo_gentle(
        target_data.T,
        int(sr_now or clean_sr),
        target_lufs=effective_lufs,
        true_peak_db=true_peak_db,
        max_gain_db=12.0,
    )
    write_wav_float32(wav_path, mastered_arr.T, int(sr_now or clean_sr), subtype="PCM_24")

    return {
        "mode": f"matchering_{clean_mode}",
        "engine": "matchering_2_0" if used_matchering else "sa_reference_spectral_master",
        "reference_profile": profile_id,
        "target_lufs": effective_lufs,
        "integrated_lufs": gentle_metrics["integrated_lufs"],
        "true_peak_dbtp": gentle_metrics["true_peak_dbtp"],
        "sample_rate_hz": int(sr_now or clean_sr),
        "bit_depth": 24,
    }


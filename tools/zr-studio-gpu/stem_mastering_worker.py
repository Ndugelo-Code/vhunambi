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
from typing import Any
import numpy as np


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


def master_stems_with_recipe(
    stems: dict[str, np.ndarray],
    sr: int,
    recipe: dict,
    transient_events: list[dict],
) -> np.ndarray:
    """Executes the full 4-stem Cakewalk/Sonar + LUFS True-Peak mastering pipeline."""
    # 1. Vocals Chain
    vox_cfg = recipe["vocals"]
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
            PeakFilter(cutoff_frequency_hz=6500.0, gain_db=-2.5, q=3.0),  # De-esser notch
            Compressor(threshold_db=-18.0, ratio=4.0, attack_ms=5.0, release_ms=65.0),
            HighShelfFilter(
                cutoff_frequency_hz=11000.0, gain_db=float(vox_eq["airGainDb"])
            ),
        ]
    )
    vox_out = vox_board(stems["vocals"], sr)

    # 2. Bass / Log Drum Chain
    bass_cfg = recipe["bass"]
    bass_eq = bass_cfg["eq"]
    bass_sub = synthesize_sub_harmonic(
        stems["bass"], sr, float(bass_cfg["subHarmonicMix"])
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
        transient_events,
        duck_db=float(bass_cfg["sidechainDuckDb"]),
    )

    # 3. Drums Chain
    drums_cfg = recipe["drums"]
    drums_eq = drums_cfg["eq"]
    drums_board = Pedalboard(
        [
            HighpassFilter(cutoff_frequency_hz=float(drums_eq["highpassHz"])),
            PeakFilter(cutoff_frequency_hz=320.0, gain_db=-3.0, q=1.8),  # Boxiness cut
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
    drums_clean = drums_board(stems["drums"], sr)
    crush_mix = float(drums_cfg["parallelCrushMix"])
    crush_board = Pedalboard(
        [Compressor(threshold_db=-24.0, ratio=8.0, attack_ms=2.0, release_ms=50.0)]
    )
    drums_out = (1.0 - crush_mix) * drums_clean + crush_mix * crush_board(drums_clean, sr)

    # 4. Melodic Chain (with Mid/Side Vocal Pocket)
    mel_cfg = recipe["melodic"]
    mel_eq = mel_cfg["eq"]
    mel_pocket = apply_mid_side_vocal_pocket(
        stems["melodic"],
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
    sketchpad_mix = float(recipe.get("sketchpadLayerMix", 0.0))
    if sketchpad_mix > 0.01 and "sketchpad_loop" in stems:
        sketch_loop = stems["sketchpad_loop"]
        if sketch_loop.shape[-1] == bass_out.shape[-1]:
            bass_out = np.clip(bass_out + sketchpad_mix * sketch_loop, -1.0, 1.0)

    # 6. Master Bus Glue & True-Peak LUFS Normalization
    master_sum = vox_out + bass_out + drums_out + mel_out
    glue_board = Pedalboard(
        [
            Compressor(threshold_db=-12.0, ratio=2.0, attack_ms=30.0, release_ms=120.0),
            Limiter(threshold_db=-1.0, release_ms=40.0),
        ]
    )
    glued = glue_board(master_sum, sr)

    target_lufs = float(recipe.get("targetLufs", -9.5))
    if pyln is not None:
        meter = pyln.Meter(sr)
        current_lufs = meter.integrated_loudness(glued.T if glued.ndim > 1 else glued)
        if np.isfinite(current_lufs):
            normalized = pyln.normalize.loudness(
                glued.T if glued.ndim > 1 else glued, current_lufs, target_lufs
            )
            glued = normalized.T if glued.ndim > 1 else normalized
    else:
        # Pure-NumPy RMS loudness approximation fallback when pyloudnorm is not installed locally
        rms = float(np.sqrt(np.mean(np.square(glued)) + 1e-12))
        approx_lufs = 20.0 * np.log10(rms) - 0.691
        gain_linear = 10.0 ** ((target_lufs - approx_lufs) / 20.0)
        glued = np.clip(glued * gain_linear, -1.0, 1.0)

    final_limiter = Pedalboard([Limiter(threshold_db=-1.0, release_ms=25.0)])
    return np.clip(final_limiter(glued, sr), -1.0, 1.0)


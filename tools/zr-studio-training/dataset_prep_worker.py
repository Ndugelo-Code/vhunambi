#!/usr/bin/env python3
"""
VHUNAMBI Phase 85 — Cloud RunPod Dataset Preprocessor (job_type="lora_dataset_prep")
===================================================================================
Converts cloud R2 MP3/M4A/FLAC tracks into validated 44.1 kHz / 24-bit stereo WAV
and NFC-normalized JSON sidecar pairs in `training-data/curated/{lora_id}/`, with
optional Phase 82 BS-RoFormer vocal isolation for `bantu_vocals_v1`.
"""

from __future__ import annotations

import gc
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unicodedata
import wave
from pathlib import Path
from typing import Any, Callable

import numpy as np

try:
    import soundfile as sf  # type: ignore
except ImportError:
    sf = None  # type: ignore

try:
    import librosa  # type: ignore
except ImportError:
    librosa = None  # type: ignore

# Allow sibling imports whether invoked as `training.dataset_prep_worker` or script
_THIS_DIR = Path(__file__).resolve().parent
_GPU_DIR = _THIS_DIR.parent / "zr-studio-gpu"
if str(_THIS_DIR) not in sys.path:
    sys.path.insert(0, str(_THIS_DIR))
if str(_GPU_DIR) not in sys.path:
    sys.path.insert(0, str(_GPU_DIR))

from validate_dataset import validate_dataset  # noqa: E402

MAJOR_PROFILE = np.array(
    [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88],
    dtype=np.float32,
)
MINOR_PROFILE = np.array(
    [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17],
    dtype=np.float32,
)
PITCH_NAMES = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]

LORA_TO_TRAINING_GENRE = {
    "amapiano_logdrum_v1": "amapiano",
    "amapiano_private_school_v1": "private_school_amapiano",
    "sgija_bacardi_v1": "sgija",
    "gqom_durban_v1": "gqom",
    "maskandi_picking_v1": "maskandi",
    "venda_malende_v1": "venda_malende",
    "afrobeats_lagos_v1": "afrobeats",
    "kwaito_township_v1": "kwaito",
    "afro_gospel_choir_v1": "gospel",
    "afrohouse_ancestral_v1": "afro_house",
    "bantu_vocals_v1": "bantu_vocals",
}

DEFAULT_INSTRUMENTATION_MAP = {
    "amapiano_logdrum_v1": ["log_drum", "shaker", "sub_bass", "piano_chords"],
    "amapiano_private_school_v1": ["log_drum", "rhodes_piano", "saxophone", "shaker"],
    "sgija_bacardi_v1": ["sgija_log_drum", "bacardi_brass", "snare_roll"],
    "gqom_durban_v1": ["durban_kick", "distorted_sub", "dark_percussion"],
    "maskandi_picking_v1": ["acoustic_guitar", "concertina", "bass_guitar", "shakers"],
    "venda_malende_v1": ["malende_drum", "lekompo_bass", "call_response_vocals"],
    "afrobeats_lagos_v1": ["talking_drum", "afrobeats_guitar", "shekere", "log_drum"],
    "kwaito_township_v1": ["slowed_house_kick", "sub_bass", "organ_stab"],
    "afro_gospel_choir_v1": ["hammond_organ", "mass_choir", "brass_section", "live_drums"],
    "afrohouse_ancestral_v1": ["congas", "shakers", "four_on_floor_kick", "ambient_pad"],
    "bantu_vocals_v1": ["lead_vocals", "backing_harmonies", "bantu_phonetics"],
}


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()


def read_wav_stereo_float32(wav_path: Path) -> tuple[np.ndarray, int]:
    """Reads 16/24/32-bit PCM WAV cleanly using soundfile or pure stdlib `wave`."""
    if sf is not None:
        arr, sr = sf.read(str(wav_path), dtype="float32", always_2d=True)
        if arr.shape[1] == 1:
            arr = np.repeat(arr, 2, axis=1)
        elif arr.shape[1] > 2:
            arr = arr[:, :2]
        return np.asarray(arr, dtype=np.float32), int(sr)

    with wave.open(str(wav_path), "rb") as w:
        sr = w.getframerate()
        ch = w.getnchannels()
        sw = w.getsampwidth()
        n = w.getnframes()
        raw = w.readframes(n)

    if sw == 2:
        data = np.frombuffer(raw, dtype="<i2").astype(np.float32) / 32768.0
    elif sw == 3:
        b = np.frombuffer(raw, dtype=np.uint8).reshape(-1, 3)
        signed = (
            b[:, 0].astype(np.int32)
            | (b[:, 1].astype(np.int32) << 8)
            | (b[:, 2].astype(np.int32) << 16)
        )
        signed = np.where(signed >= 0x800000, signed - 0x1000000, signed)
        data = signed.astype(np.float32) / 8388608.0
    elif sw == 4:
        data = np.frombuffer(raw, dtype="<i4").astype(np.float32) / 2147483648.0
    else:
        raise ValueError(f"Unsupported WAV sample width: {sw} bytes")

    frames = len(data) // max(1, ch)
    arr = data[: frames * ch].reshape(frames, ch)
    if ch == 1:
        arr = np.repeat(arr, 2, axis=1)
    elif ch > 2:
        arr = arr[:, :2]
    return np.asarray(arr, dtype=np.float32), int(sr)


def write_wav_pcm24_stereo(wav_path: Path, stereo: np.ndarray, sr: int = 44100) -> None:
    """Writes 24-bit stereo WAV using soundfile or stdlib `wave`."""
    arr = np.asarray(stereo, dtype=np.float32)
    if arr.ndim == 1:
        arr = np.repeat(arr[:, None], 2, axis=1)
    elif arr.shape[1] == 1:
        arr = np.repeat(arr, 2, axis=1)
    arr = np.clip(arr[:, :2], -0.9999, 0.9999)

    wav_path.parent.mkdir(parents=True, exist_ok=True)
    if sf is not None:
        sf.write(str(wav_path), arr, int(sr), subtype="PCM_24")
        return

    scaled = np.round(arr.reshape(-1) * 8388607.0).astype("<i4")
    u32 = scaled.view("<u4")
    packed = np.empty((len(u32), 3), dtype=np.uint8)
    packed[:, 0] = (u32 & 0xFF).astype(np.uint8)
    packed[:, 1] = ((u32 >> 8) & 0xFF).astype(np.uint8)
    packed[:, 2] = ((u32 >> 16) & 0xFF).astype(np.uint8)

    with wave.open(str(wav_path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(3)
        w.setframerate(int(sr))
        w.writeframes(packed.tobytes())


def detect_musical_key_from_audio(mono: np.ndarray, sr: int) -> dict[str, str]:
    """Krumhansl-Schmuckler tonal key detector using librosa chroma or FFT chroma fallback."""
    if len(mono) < sr:
        return {"tonic": "C", "mode": "minor"}

    try:
        if librosa is not None:
            chroma = librosa.feature.chroma_cqt(y=mono, sr=sr)
            chroma_vec = np.mean(chroma, axis=1).astype(np.float32)
        else:
            # Lightweight FFT chroma projection over middle-band slice
            n_fft = 4096
            hop = 2048
            slice_sig = mono[: min(len(mono), sr * 30)]
            win = np.hanning(n_fft).astype(np.float32)
            chroma_vec = np.zeros(12, dtype=np.float32)
            freqs = np.fft.rfftfreq(n_fft, 1.0 / sr)
            valid = (freqs >= 65.0) & (freqs <= 2000.0)
            midi_bins = np.round(69.0 + 12.0 * np.log2(freqs[valid] / 440.0)).astype(np.int32) % 12
            for start in range(0, max(1, len(slice_sig) - n_fft), hop):
                frame = slice_sig[start : start + n_fft]
                if len(frame) < n_fft:
                    continue
                mag = np.abs(np.fft.rfft(frame * win))[valid]
                np.add.at(chroma_vec, midi_bins, mag)
        norm = float(np.linalg.norm(chroma_vec))
        if norm > 0:
            chroma_vec = chroma_vec / norm

        best_score = -1e9
        best_tonic = "A"
        best_mode = "minor"
        for i, name in enumerate(PITCH_NAMES):
            maj_corr = float(np.corrcoef(chroma_vec, np.roll(MAJOR_PROFILE, i))[0, 1])
            min_corr = float(np.corrcoef(chroma_vec, np.roll(MINOR_PROFILE, i))[0, 1])
            if np.isfinite(maj_corr) and maj_corr > best_score:
                best_score, best_tonic, best_mode = maj_corr, name, "major"
            if np.isfinite(min_corr) and min_corr > best_score:
                best_score, best_tonic, best_mode = min_corr, name, "minor"
        return {"tonic": best_tonic, "mode": best_mode}
    except Exception:
        return {"tonic": "A", "mode": "minor"}


def detect_bpm_from_audio(mono: np.ndarray, sr: int, fallback_bpm: int = 114) -> int:
    if librosa is not None and len(mono) >= sr * 4:
        try:
            tempo, _ = librosa.beat.beat_track(y=mono, sr=sr)
            bpm_val = int(round(float(np.asarray(tempo).reshape(-1)[0])))
            if 60 <= bpm_val <= 200:
                return bpm_val
        except Exception:
            pass
    return max(60, min(200, int(fallback_bpm or 114)))


def transcode_to_training_wav(
    input_path: Path,
    output_wav_path: Path,
    target_sr: int = 44100,
    max_sec: float = 295.0,
) -> dict[str, Any]:
    """Transcodes input audio to 44.1 kHz / 24-bit stereo WAV capped at <= max_sec."""
    ext = input_path.suffix.lower()
    stereo: np.ndarray
    in_sr: int

    if ext == ".wav":
        stereo, in_sr = read_wav_stereo_float32(input_path)
    else:
        tmp_wav = output_wav_path.with_suffix(".tmp_decode.wav")
        subprocess.run(
            [
                "ffmpeg", "-y", "-i", str(input_path),
                "-t", str(max_sec),
                "-ar", str(target_sr), "-ac", "2",
                "-c:a", "pcm_s24le", str(tmp_wav),
            ],
            check=True,
            capture_output=True,
        )
        stereo, in_sr = read_wav_stereo_float32(tmp_wav)
        if tmp_wav.exists():
            tmp_wav.unlink()

    if in_sr != target_sr and len(stereo) > 0:
        out_frames = max(1, int(round(stereo.shape[0] * float(target_sr) / float(in_sr))))
        x_old = np.linspace(0.0, 1.0, stereo.shape[0], endpoint=False)
        x_new = np.linspace(0.0, 1.0, out_frames, endpoint=False)
        left = np.interp(x_new, x_old, stereo[:, 0])
        right = np.interp(x_new, x_old, stereo[:, 1])
        stereo = np.column_stack([left, right]).astype(np.float32)

    max_frames = int(round(max_sec * target_sr))
    if stereo.shape[0] > max_frames:
        stereo = stereo[:max_frames]

    # Trim low-energy silence tails (-55 dBFS threshold) while preserving at least 30s
    energy = np.max(np.abs(stereo), axis=1)
    non_silent = np.where(energy > 0.0018)[0]
    if len(non_silent) > target_sr * 30:
        end_idx = min(stereo.shape[0], int(non_silent[-1]) + int(target_sr * 0.5))
        stereo = stereo[:end_idx]

    peak = float(np.max(np.abs(stereo))) if len(stereo) else 0.0
    if peak > 0.89:
        stereo = stereo * (0.89 / peak)

    write_wav_pcm24_stereo(output_wav_path, stereo, target_sr)
    duration_sec = round(stereo.shape[0] / float(target_sr), 2)
    return {
        "sample_rate": target_sr,
        "bit_depth": 24,
        "channels": 2,
        "duration_sec": duration_sec,
    }


def _create_r2_client() -> tuple[Any | None, str]:
    endpoint = os.environ.get("R2_ENDPOINT_URL", os.environ.get("R2_ENDPOINT", "")).strip()
    key_id = os.environ.get("R2_ACCESS_KEY_ID", "").strip()
    secret = os.environ.get("R2_SECRET_ACCESS_KEY", "").strip()
    bucket = os.environ.get("R2_BUCKET", "zr-studio-audio").strip()
    if endpoint and key_id and secret:
        import boto3  # type: ignore

        client = boto3.client(
            "s3",
            endpoint_url=endpoint,
            aws_access_key_id=key_id,
            aws_secret_access_key=secret,
            region_name="auto",
        )
        return client, bucket
    return None, bucket


def _infer_bcp47_language(lyrics: str, lora_id: str) -> str:
    if any(ch in lyrics for ch in ("ḓ", "ḽ", "ṋ", "ṱ", "Ṅ", "ṅ")):
        return "ve-ZA"
    if lora_id == "venda_malende_v1":
        return "ve-ZA"
    lower = lyrics.lower()
    if any(w in lower for w in ("ngiyabonga", "yebo", "sikhathi", "wena")):
        return "zu-ZA"
    if any(w in lower for w in ("molweni", "nkosi", "uxolo")):
        return "xh-ZA"
    return "en-ZA"


def run_cloud_dataset_prep(
    job_input: dict[str, Any],
    webhook_fn: Callable[[str, dict[str, Any]], None] | None = None,
) -> dict[str, Any]:
    """Prepares curated 44.1 kHz 24-bit WAV + JSON pairs and validates them."""
    job_id = str(job_input.get("job_id") or "prep_job")
    lora_id = str(job_input.get("lora_id") or "amapiano_logdrum_v1")
    extract_vocals = bool(job_input.get("extract_vocals", lora_id == "bantu_vocals_v1"))
    webhook_url = str(job_input.get("webhook_url") or "")
    source_tracks = list(job_input.get("source_tracks") or [])
    training_genre = LORA_TO_TRAINING_GENRE.get(lora_id, "amapiano")
    default_inst = DEFAULT_INSTRUMENTATION_MAP.get(lora_id, ["drums", "bass"])

    s3, bucket = _create_r2_client()
    curated_prefix = f"training-data/curated/{lora_id}"
    prepared_records: list[dict[str, Any]] = []

    custom_curated_dir = str(job_input.get("curated_dir") or "").strip()
    tmp_ctx = tempfile.TemporaryDirectory()
    try:
        root = Path(tmp_ctx.name)
        raw_dir = root / "raw"
        curated_dir = Path(custom_curated_dir) if custom_curated_dir else (root / lora_id)
        raw_dir.mkdir(parents=True, exist_ok=True)
        curated_dir.mkdir(parents=True, exist_ok=True)

        for idx, track in enumerate(source_tracks):
            stem = f"track_{idx:03d}"
            title = unicodedata.normalize("NFC", str(track.get("title") or f"Track {idx + 1}"))
            r2_key = str(track.get("r2Key") or track.get("source_r2_key") or "").lstrip("/")
            local_override = str(track.get("localPath") or track.get("local_path") or "").strip()
            src_ext = Path(r2_key or local_override or "track.mp3").suffix or ".mp3"
            local_raw = raw_dir / f"{stem}{src_ext}"

            if local_override and os.path.isfile(local_override):
                shutil.copy2(local_override, local_raw)
            elif s3 is not None and r2_key:
                s3.download_file(bucket, r2_key, str(local_raw))
            else:
                continue

            src_sha = str(track.get("sha256") or sha256_file(local_raw))
            out_wav = curated_dir / f"{stem}.wav"
            out_json = curated_dir / f"{stem}.json"

            try:
                audio_spec = transcode_to_training_wav(
                    local_raw,
                    out_wav,
                    max_sec=65.0 if extract_vocals else 295.0,
                )
                vocal_isolated = False
                if extract_vocals:
                    vox_tmp_dir = curated_dir / f".vox_{stem}"
                    try:
                        from mmo_extractor import separate_lead_vocal_bs_roformer  # type: ignore

                        vox_tmp_dir.mkdir(parents=True, exist_ok=True)
                        vox_res = separate_lead_vocal_bs_roformer(str(out_wav), str(vox_tmp_dir))
                        vox_file = (
                            vox_res.get("lead_vocals_path") or vox_res.get("lead_vocals")
                            if isinstance(vox_res, dict)
                            else str(vox_res)
                        )
                        if vox_file and os.path.isfile(str(vox_file)):
                            shutil.copy2(str(vox_file), str(out_wav))
                            audio_spec = transcode_to_training_wav(out_wav, out_wav)
                            vocal_isolated = True
                    except Exception:
                        pass
                    finally:
                        if vox_tmp_dir.exists():
                            shutil.rmtree(vox_tmp_dir, ignore_errors=True)

                stereo, sr = read_wav_stereo_float32(out_wav)
                mono = np.mean(stereo, axis=1)
                bpm = detect_bpm_from_audio(mono, sr, fallback_bpm=int(track.get("bpm") or 114))
                key_obj = detect_musical_key_from_audio(mono, sr)
                lyrics = unicodedata.normalize("NFC", str(track.get("lyricsText") or "").strip())
                lang = str(track.get("language") or _infer_bcp47_language(lyrics, lora_id))

                sidecar = {
                    "title": title,
                    "lora_id": lora_id,
                    "genre": training_genre,
                    "sub_genre": str(track.get("subGenre") or "").strip() or None,
                    "bpm": bpm,
                    "key": key_obj,
                    "time_signature": "4/4",
                    "language": lang,
                    "lyrics": lyrics,
                    "instrumental": len(lyrics) == 0,
                    "instrumentation": default_inst,
                    "license": str(track.get("license") or "owned"),
                    "training_weight": 1.0,
                    "exclude_from_training": False,
                    "audio": audio_spec,
                    "source_r2_key": r2_key or local_override,
                    "source_sha256": src_sha,
                }
                sidecar = {k: v for k, v in sidecar.items() if v is not None}
                with open(out_json, "w", encoding="utf-8") as jf:
                    json.dump(sidecar, jf, indent=2, ensure_ascii=False)

                prepared_records.append(
                    {
                        "stem": stem,
                        "source_track_id": track.get("id"),
                        "source_r2_key": r2_key or local_override,
                        "source_sha256": src_sha,
                        "curated_wav_r2_key": f"{curated_prefix}/{stem}.wav",
                        "curated_json_r2_key": f"{curated_prefix}/{stem}.json",
                        "title": title,
                        "vocal_isolated": vocal_isolated,
                        "duration_sec": audio_spec["duration_sec"],
                        "sample_rate": audio_spec["sample_rate"],
                        "bit_depth": audio_spec["bit_depth"],
                        "bpm": bpm,
                        "musical_key": f"{key_obj['tonic']} {key_obj['mode']}",
                        "language": lang,
                        "license": sidecar["license"],
                        "training_weight": 1.0,
                    }
                )
            finally:
                if local_raw.exists():
                    local_raw.unlink()
                gc.collect()

        validation = validate_dataset(curated_dir)
        by_stem = {r.filename: r for r in validation.track_results}
        for rec in prepared_records:
            tr = by_stem.get(rec["stem"])
            rec["valid"] = bool(tr.valid) if tr else False
            rec["errors"] = list(tr.errors) if tr else ["Not validated"]

        if s3 is not None and validation.valid_tracks > 0:
            manifest = {
                "lora_id": lora_id,
                "genre": training_genre,
                "valid_tracks": validation.valid_tracks,
                "total_tracks": validation.total_tracks,
            }
            manifest_path = curated_dir / "_manifest.json"
            with open(manifest_path, "w", encoding="utf-8") as mf:
                json.dump(manifest, mf, indent=2)
            s3.upload_file(str(manifest_path), bucket, f"{curated_prefix}/_manifest.json")

            for rec in prepared_records:
                if not rec["valid"]:
                    continue
                    wav_f = curated_dir / f"{rec['stem']}.wav"
                    json_f = curated_dir / f"{rec['stem']}.json"
                    if wav_f.exists() and json_f.exists():
                        s3.upload_file(str(wav_f), bucket, rec["curated_wav_r2_key"])
                        s3.upload_file(str(json_f), bucket, rec["curated_json_r2_key"])
    finally:
        tmp_ctx.cleanup()

    payload = {
        "job_id": job_id,
        "lora_id": lora_id,
        "job_type": "dataset_prep",
        "status": "dataset_ready" if validation.valid_tracks >= 8 else "failed",
        "valid_tracks": validation.valid_tracks,
        "total_tracks": validation.total_tracks,
        "dataset_valid": validation.valid,
        "dataset_errors": validation.dataset_errors,
        "tracks": prepared_records,
    }
    if webhook_fn and webhook_url:
        webhook_fn(webhook_url, payload)
    return payload

#!/usr/bin/env python3
"""
VHUNAMBI Phase 85 — LoRA Training Dataset Validator
===================================================
Validates curated 44.1/48 kHz WAV + JSON sidecar datasets before PEFT LoRA
training on RunPod Cloud GPUs. Zero external dependencies (pure Python stdlib).
"""

from __future__ import annotations

import argparse
import dataclasses
import json
import sys
import wave
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

MIN_TRACKS = 8
RECOMMENDED_TRACKS = 15
VALID_SAMPLE_RATES = (44100, 48000)
VALID_BIT_DEPTHS = (16, 24)
VALID_CHANNELS = (1, 2)
MIN_DURATION_SEC = 30.0
MAX_DURATION_SEC = 300.0

VALID_LORA_IDS = (
    "amapiano_logdrum_v1",
    "amapiano_private_school_v1",
    "sgija_bacardi_v1",
    "gqom_durban_v1",
    "maskandi_picking_v1",
    "venda_malende_v1",
    "afrobeats_lagos_v1",
    "kwaito_township_v1",
    "afro_gospel_choir_v1",
    "afrohouse_ancestral_v1",
    "bantu_vocals_v1",
)

VALID_GENRES = (
    "amapiano",
    "private_school_amapiano",
    "sgija",
    "gqom",
    "maskandi",
    "venda_malende",
    "afrobeats",
    "kwaito",
    "gospel",
    "afro_house",
    "bantu_vocals",
)

VALID_LANGUAGES = (
    "zu-ZA",
    "xh-ZA",
    "nso-ZA",
    "ve-ZA",
    "tn-ZA",
    "st-ZA",
    "ts-ZA",
    "ss-ZA",
    "nr-ZA",
    "af-ZA",
    "en-ZA",
    "mixed",
)

VALID_LICENSES = ("royalty_free", "cc0", "cc_by", "owned", "licensed")

REQUIRED_METADATA_FIELDS = (
    "title",
    "lora_id",
    "genre",
    "bpm",
    "language",
    "instrumentation",
    "license",
)


@dataclass
class TrackResult:
    filename: str
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    excluded: bool = False
    audio_spec: dict[str, Any] = field(default_factory=dict)

    @property
    def valid(self) -> bool:
        return len(self.errors) == 0


@dataclass
class DatasetResult:
    dataset_dir: str
    lora_id: str | None
    total_tracks: int
    valid_tracks: int
    active_tracks: int
    track_results: list[TrackResult] = field(default_factory=list)
    dataset_errors: list[str] = field(default_factory=list)
    dataset_warnings: list[str] = field(default_factory=list)

    @property
    def valid(self) -> bool:
        return (
            len(self.dataset_errors) == 0
            and all(r.valid for r in self.track_results if not r.excluded)
        )

    def to_dict(self) -> dict[str, Any]:
        return {
            "valid": self.valid,
            "dataset_dir": self.dataset_dir,
            "lora_id": self.lora_id,
            "total_tracks": self.total_tracks,
            "valid_tracks": self.valid_tracks,
            "active_tracks": self.active_tracks,
            "dataset_errors": list(self.dataset_errors),
            "dataset_warnings": list(self.dataset_warnings),
            "track_results": [
                {
                    **dataclasses.asdict(tr),
                    "valid": tr.valid,
                }
                for tr in self.track_results
            ],
        }


def validate_audio(wav_path: Path) -> tuple[list[str], list[str], dict[str, Any]]:
    """Validates a WAV file header & audio parameters using stdlib `wave`."""
    errors: list[str] = []
    warnings: list[str] = []
    spec: dict[str, Any] = {}

    if wav_path.suffix.lower() != ".wav":
        errors.append(f"Not a WAV file: {wav_path.suffix}")
        return errors, warnings, spec

    if not wav_path.exists():
        errors.append("WAV file does not exist")
        return errors, warnings, spec

    try:
        with wave.open(str(wav_path), "rb") as w:
            sample_rate = w.getframerate()
            channels = w.getnchannels()
            bit_depth = w.getsampwidth() * 8
            n_frames = w.getnframes()
            duration = n_frames / sample_rate if sample_rate > 0 else 0.0

            spec = {
                "sample_rate": sample_rate,
                "channels": channels,
                "bit_depth": bit_depth,
                "duration_sec": round(duration, 2),
            }

            if sample_rate not in VALID_SAMPLE_RATES:
                errors.append(
                    f"Invalid sample rate: {sample_rate} Hz (expected {VALID_SAMPLE_RATES})"
                )
            if channels not in VALID_CHANNELS:
                errors.append(
                    f"Invalid channel count: {channels} (expected {VALID_CHANNELS})"
                )
            if bit_depth not in VALID_BIT_DEPTHS:
                errors.append(
                    f"Invalid bit depth: {bit_depth}-bit (expected {VALID_BIT_DEPTHS})"
                )
            if duration < MIN_DURATION_SEC:
                errors.append(
                    f"Track too short: {duration:.1f}s (minimum {MIN_DURATION_SEC}s)"
                )
            elif duration > MAX_DURATION_SEC:
                errors.append(
                    f"Track too long: {duration:.1f}s (maximum {MAX_DURATION_SEC}s)"
                )
            if channels == 1:
                warnings.append("Mono audio - stereo preferred for training")
            if bit_depth == 16:
                warnings.append("16-bit depth - 24-bit preferred for higher fidelity")
    except wave.Error as exc:
        errors.append(f"WAV read error: {exc}")
    except Exception as exc:
        errors.append(f"Unexpected WAV read error: {exc}")

    return errors, warnings, spec


def validate_metadata(json_path: Path) -> tuple[list[str], list[str], dict[str, Any]]:
    """Validates a JSON sidecar file against Vhunambi Phase 85 dataset rules."""
    errors: list[str] = []
    warnings: list[str] = []
    meta: dict[str, Any] = {}

    if not json_path.exists():
        errors.append("Missing JSON metadata sidecar")
        return errors, warnings, meta

    try:
        with open(json_path, "r", encoding="utf-8") as f:
            meta = json.load(f)
    except Exception as exc:
        errors.append(f"JSON parse error: {exc}")
        return errors, warnings, meta

    if not isinstance(meta, dict):
        errors.append("JSON sidecar root must be an object")
        return errors, warnings, {}

    for field_name in REQUIRED_METADATA_FIELDS:
        if field_name not in meta or meta[field_name] is None:
            errors.append(f"Missing required field: '{field_name}'")
        elif isinstance(meta[field_name], str) and not meta[field_name].strip():
            errors.append(f"Empty required field: '{field_name}'")

    if "lora_id" in meta and meta["lora_id"] not in VALID_LORA_IDS:
        errors.append(f"Invalid lora_id: '{meta['lora_id']}'")

    if "genre" in meta and meta["genre"] not in VALID_GENRES:
        errors.append(f"Invalid genre: '{meta['genre']}'")

    if "language" in meta and meta["language"] not in VALID_LANGUAGES:
        errors.append(f"Invalid language tag: '{meta['language']}'")

    if "license" in meta and meta["license"] not in VALID_LICENSES:
        errors.append(f"Invalid license: '{meta['license']}'")
    elif meta.get("license") == "cc_by" and not str(meta.get("attribution") or "").strip():
        errors.append("CC-BY license requires attribution field")

    if "bpm" in meta:
        try:
            bpm_val = int(meta["bpm"])
            if not (60 <= bpm_val <= 200):
                errors.append(f"BPM out of range: {bpm_val} (expected 60..200)")
        except (TypeError, ValueError):
            errors.append(f"Invalid BPM value: {meta['bpm']!r}")

    if "instrumentation" in meta:
        inst = meta["instrumentation"]
        if not isinstance(inst, list) or len(inst) == 0:
            errors.append("'instrumentation' must be a non-empty list")

    is_instrumental = bool(meta.get("instrumental", False))
    if not is_instrumental:
        lyrics = str(meta.get("lyrics") or "").strip()
        if not lyrics:
            warnings.append("No lyrics provided - add lyrics or set instrumental=true")
        elif "[" not in lyrics:
            warnings.append("Lyrics missing structural markers like [VERSE]/[CHORUS]")

    weight = meta.get("training_weight", 1.0)
    if not isinstance(weight, (int, float)) or not (0.1 <= float(weight) <= 3.0):
        errors.append(f"training_weight must be in [0.1, 3.0], got {weight!r}")

    return errors, warnings, meta


def validate_dataset(dataset_dir: Path, json_only: bool = False) -> DatasetResult:
    """Validates a complete curated LoRA dataset folder."""
    lora_id = dataset_dir.name
    res = DatasetResult(
        dataset_dir=str(dataset_dir),
        lora_id=lora_id,
        total_tracks=0,
        valid_tracks=0,
        active_tracks=0,
    )

    if not dataset_dir.exists():
        res.dataset_errors.append(f"Dataset directory does not exist: {dataset_dir}")
        return res

    wav_files = sorted(
        f for f in dataset_dir.glob("*.wav")
        if not f.name.startswith("_") and not f.name.startswith(".")
    )
    json_files = sorted(
        f for f in dataset_dir.glob("*.json")
        if not f.name.startswith("_") and not f.name.startswith(".") and ".sample" not in f.name
    )

    if not wav_files and not json_only:
        res.dataset_errors.append("No WAV files found in curated dataset directory")
        return res

    pairs: list[tuple[Path | None, Path | None, str]] = []
    if json_only:
        for jf in json_files:
            pairs.append((None, jf, jf.stem))
    else:
        for wf in wav_files:
            jf = wf.with_suffix(".json")
            pairs.append((wf, jf if jf.exists() else None, wf.stem))

    res.total_tracks = len(pairs)
    for wav_path, json_path, stem in pairs:
        tr = TrackResult(filename=stem)
        if wav_path is not None and not json_only:
            a_err, a_warn, spec = validate_audio(wav_path)
            tr.errors.extend(a_err)
            tr.warnings.extend(a_warn)
            tr.audio_spec = spec

        if json_path is not None:
            m_err, m_warn, meta = validate_metadata(json_path)
            tr.errors.extend(m_err)
            tr.warnings.extend(m_warn)
            tr.excluded = bool(meta.get("exclude_from_training", False))
        else:
            tr.errors.append("Missing JSON metadata sidecar")

        if tr.valid:
            res.valid_tracks += 1
        if not tr.excluded:
            res.active_tracks += 1
        res.track_results.append(tr)

    active_valid = sum(
        1 for tr in res.track_results if tr.valid and not tr.excluded
    )
    if active_valid < MIN_TRACKS:
        res.dataset_errors.append(
            f"Insufficient valid active tracks: {active_valid}/{MIN_TRACKS} minimum required"
        )
    elif active_valid < RECOMMENDED_TRACKS:
        res.dataset_warnings.append(
            f"Below recommended track count ({active_valid}/{RECOMMENDED_TRACKS})"
        )
    return res


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate curated Vhunambi LoRA dataset")
    parser.add_argument("--dataset", required=True, help="Path to curated dataset dir")
    parser.add_argument("--json-only", action="store_true", help="Skip WAV verification")
    args = parser.parse_args()

    result = validate_dataset(Path(args.dataset), json_only=args.json_only)
    print(json.dumps(result.to_dict(), indent=2))
    return 0 if result.valid else 1


if __name__ == "__main__":
    sys.exit(main())

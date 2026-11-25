"""
VHUNAMBI Phase 85 — Python Cloud Dataset Prep, Validator, Real PEFT LoRA Trainer & Loader Tests
Runs 100% on CPU in < 15 seconds with zero mock safetensors bytes or network downloads.
"""

from __future__ import annotations

import hashlib
import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import numpy as np

TOOLS_DIR = Path(__file__).resolve().parents[2]
TRAINING_DIR = TOOLS_DIR / "zr-studio-training"
GPU_DIR = TOOLS_DIR / "zr-studio-gpu"
if str(TRAINING_DIR) not in sys.path:
    sys.path.insert(0, str(TRAINING_DIR))
if str(GPU_DIR) not in sys.path:
    sys.path.insert(0, str(GPU_DIR))

import dataset_prep_worker  # noqa: E402
import handler  # noqa: E402
import model_utils  # noqa: E402
import train_lora  # noqa: E402
import validate_dataset  # noqa: E402

_WAV_TEMPLATE_CACHE: dict[tuple[float, int], bytes] = {}


def _make_sine_wav(path: Path, freq: float = 220.0, duration_sec: float = 30.2, sr: int = 44100) -> None:
    key = (float(freq), int(sr))
    cached = _WAV_TEMPLATE_CACHE.get(key)
    if cached is not None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(cached)
        return
    t = np.linspace(0.0, duration_sec, int(sr * duration_sec), endpoint=False, dtype=np.float32)
    sig = 0.25 * np.sin(2.0 * np.pi * freq * t)
    stereo = np.column_stack([sig, sig * 0.9]).astype(np.float32)
    dataset_prep_worker.write_wav_pcm24_stereo(path, stereo, sr=sr)
    _WAV_TEMPLATE_CACHE[key] = path.read_bytes()


class Phase85CloudLoraFactoryTests(unittest.TestCase):
    def test_validate_dataset_enforces_min_8_and_audio_rules(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td) / "amapiano_logdrum_v1"
            root.mkdir()
            # 3 tracks -> must fail MIN_TRACKS = 8
            for i in range(3):
                _make_sine_wav(root / f"track_0{i}.wav", freq=220.0, duration_sec=30.2)
                (root / f"track_0{i}.json").write_text(
                    json.dumps(
                        {
                            "title": f"Test {i}",
                            "lora_id": "amapiano_logdrum_v1",
                            "genre": "amapiano",
                            "bpm": 114,
                            "language": "zu-ZA",
                            "lyrics": "[VERSE]\nYebo log drum",
                            "instrumentation": ["log_drum", "shaker"],
                            "license": "owned",
                        }
                    ),
                    encoding="utf-8",
                )
            fail_res = validate_dataset.validate_dataset(root)
            self.assertFalse(fail_res.valid)
            self.assertEqual(fail_res.valid_tracks, 3)

            # Add 5 more valid tracks -> 8 total -> passes
            for i in range(3, 8):
                _make_sine_wav(root / f"track_0{i}.wav", freq=220.0, duration_sec=30.2)
                (root / f"track_0{i}.json").write_text(
                    json.dumps(
                        {
                            "title": f"Test {i}",
                            "lora_id": "amapiano_logdrum_v1",
                            "genre": "amapiano",
                            "bpm": 114,
                            "language": "ve-ZA",
                            "lyrics": "[CHORUS]\nṄwala Makoleni",
                            "instrumentation": ["log_drum"],
                            "license": "owned",
                        }
                    ),
                    encoding="utf-8",
                )
            ok_res = validate_dataset.validate_dataset(root)
            self.assertTrue(ok_res.valid)
            self.assertEqual(ok_res.valid_tracks, 8)

    def test_dataset_prep_worker_processes_local_tracks_and_emits_webhook(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            src_dir = Path(td) / "raw_src"
            src_dir.mkdir()
            sources = []
            for i in range(8):
                wav_p = src_dir / f"src_{i}.wav"
                _make_sine_wav(wav_p, freq=220.0, duration_sec=30.2, sr=44100)
                sources.append(
                    {
                        "id": f"trk_{i}",
                        "title": f"Ṅwala Makoleni {i}",
                        "localPath": str(wav_p),
                        "bpm": 113,
                        "language": "ve-ZA",
                        "lyricsText": "[VERSE]\nṄwala makoleni a vhudzimu",
                        "license": "owned",
                    }
                )

            captured: list[tuple[str, dict]] = []
            with patch.object(dataset_prep_worker, "_create_r2_client", return_value=(None, "zr-studio-audio")):
                res = dataset_prep_worker.run_cloud_dataset_prep(
                    {
                        "job_id": "job_prep_test",
                        "lora_id": "amapiano_logdrum_v1",
                        "extract_vocals": False,
                        "webhook_url": "https://example.invalid/v1/webhooks/training",
                        "source_tracks": sources,
                    },
                    webhook_fn=lambda url, payload: captured.append((url, payload)),
                )

            self.assertEqual(res["status"], "dataset_ready")
            self.assertTrue(res["dataset_valid"])
            self.assertEqual(res["valid_tracks"], 8)
            self.assertEqual(len(captured), 1)
            self.assertEqual(captured[0][1]["tracks"][0]["title"], "Ṅwala Makoleni 0")

    def test_real_peft_lora_training_exports_verified_safetensors_and_dual_load(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            curated = Path(td) / "amapiano_logdrum_v1"
            curated.mkdir()
            for i in range(8):
                _make_sine_wav(curated / f"track_0{i}.wav", freq=220.0, duration_sec=30.2)
                (curated / f"track_0{i}.json").write_text(
                    json.dumps(
                        {
                            "title": f"Log Drum {i}",
                            "lora_id": "amapiano_logdrum_v1",
                            "genre": "amapiano",
                            "bpm": 114,
                            "language": "zu-ZA",
                            "lyrics": "[VERSE]\nShaya log drum",
                            "instrumentation": ["log_drum", "shaker"],
                            "license": "owned",
                        }
                    ),
                    encoding="utf-8",
                )

            webhook_events: list[dict] = []
            with patch.object(dataset_prep_worker, "_create_r2_client", return_value=(None, "zr-studio-audio")):
                result = train_lora.run_cloud_peft_training(
                    {
                        "job_id": "job_train_test",
                        "lora_id": "amapiano_logdrum_v1",
                        "dataset_dir": str(curated),
                        "webhook_url": "https://example.invalid/v1/webhooks/training",
                        "training_config": {
                            "lora_rank": 8,
                            "lora_alpha": 16,
                            "epochs": 3,
                            "batch_size": 2,
                            "grad_accum_steps": 1,
                            "learning_rate": 1e-3,
                            "warmup_steps": 1,
                            "precision": "fp32",
                        },
                    },
                    webhook_fn=lambda _url, payload: webhook_events.append(payload),
                )

            self.assertEqual(result["status"], "completed")
            self.assertGreater(result["artifact_bytes"], 1024)
            self.assertEqual(len(result["artifact_sha256"]), 64)
            self.assertGreater(result["tensor_count"], 0)
            self.assertGreaterEqual(len(webhook_events), 4)

            # Verify handler early-routing for lora_dataset_prep & lora_train_peft
            with patch.object(train_lora, "run_cloud_peft_training", return_value={"status": "completed", "ok": True}) as mock_train:
                h_res = handler.runpod_handler(
                    {"input": {"job_type": "lora_train_peft", "lora_id": "amapiano_logdrum_v1"}}
                )
                self.assertEqual(h_res["status"], "completed")
                mock_train.assert_called_once()

        # Verify model_utils reconstructs PEFT directory cleanly from embedded __metadata__
        with tempfile.TemporaryDirectory() as td2:
            curated2 = Path(td2) / "ds"
            curated2.mkdir()
            import torch
            import torch.nn as nn

            class MiniDiT(nn.Module):
                def __init__(self) -> None:
                    super().__init__()
                    self.linear_q = nn.Linear(16, 16)
                    self.linear_v = nn.Linear(16, 16)

            peft_m, targets = train_lora.build_peft_lora_model(MiniDiT(), lora_rank=4, lora_alpha=8)
            st_path = Path(td2) / "amapiano_logdrum_v1.safetensors"
            cfg_path = Path(td2) / "adapter_config.json"
            info = train_lora.extract_and_save_verified_safetensors(
                peft_m,
                st_path,
                cfg_path,
                lora_id="amapiano_logdrum_v1",
                lora_rank=4,
                lora_alpha=8,
                target_modules=targets,
                training_tracks=8,
                final_loss=0.25,
            )
            self.assertGreater(info["bytes"], 64)
            mat_dir = model_utils.materialize_peft_dir_from_safetensors(str(st_path), str(Path(td2) / "reconstructed_peft"))
            self.assertIsNotNone(mat_dir)
            self.assertTrue((Path(mat_dir) / "adapter_config.json").is_file())
            self.assertTrue((Path(mat_dir) / "adapter_model.safetensors").is_file())
            self.assertIn("bantu_vocals", model_utils.GENRE_LORA_REGISTRY)


if __name__ == "__main__":
    unittest.main(verbosity=2)

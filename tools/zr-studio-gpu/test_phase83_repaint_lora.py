"""
VHUNAMBI Phase 83 — Offline Tests for Post-Generation Section Repaint,
Canonical/Legacy Stem-Lock Normalization, and Truthful Sovereign African LoRA Activation.
"""

from __future__ import annotations

import os
import sys
import tempfile
import unittest
from unittest.mock import patch

import numpy as np

GPU_DIR = os.path.dirname(os.path.abspath(__file__))
if GPU_DIR not in sys.path:
    sys.path.insert(0, GPU_DIR)

import handler  # noqa: E402
import model_router  # noqa: E402
import model_utils  # noqa: E402


class Phase83RepaintAndLoraTests(unittest.TestCase):
    def test_truthful_lora_loading_rejects_missing_and_normalizes_multi_lora(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            with patch.dict(
                os.environ,
                {"ZR_LORA_CACHE_DIR": tmp, "R2_PUBLIC_BASE_URL": ""},
                clear=False,
            ):
                mgr = model_utils.ZRModelManager()
                mgr.lora_cache_dir = tmp

                # 1. Missing .safetensors MUST NOT falsely report active_lora
                missing_metrics = mgr._hot_swap_loras([
                    {"lora_id": "missing_lora", "path": "loras/does_not_exist.safetensors", "weight": 0.90},
                ])
                self.assertEqual(missing_metrics["requested_count"], 1)
                self.assertEqual(missing_metrics["loaded_count"], 0)
                self.assertIsNone(mgr._active_lora_key)
                self.assertEqual(mgr._active_lora_weight, 0.0)

                # 2. Valid cached .safetensors weights load truthfully & normalize combined sum <= 1.35
                for name in ("amapiano_private_school_v1.safetensors", "venda_malende_v1.safetensors"):
                    p = os.path.join(tmp, name)
                    with open(p, "wb") as f:
                        f.write(b"SAFETENSORS_TEST_HEADER_" + os.urandom(256))

                inv = model_utils.inspect_volume_lora_inventory(tmp)
                self.assertEqual(inv["count"], 2)

                loaded_metrics = mgr._hot_swap_loras([
                    {"lora_id": "amapiano_private_school_v1", "path": "loras/amapiano_private_school_v1.safetensors", "weight": 0.95},
                    {"lora_id": "venda_malende_v1", "path": "loras/venda_malende_v1.safetensors", "weight": 0.95},
                ])
                self.assertEqual(loaded_metrics["loaded_count"], 2)
                self.assertEqual(mgr._active_lora_key, "loras/amapiano_private_school_v1.safetensors")
                total_w = sum(x["weight"] for x in loaded_metrics["loaded_loras"] if x["loaded"])
                self.assertLessEqual(total_w, 1.35 + 1e-4)

                # Reset singleton cache dir cleanly
                mgr._active_lora_key = None
                mgr._active_lora_weight = 0.0

    def test_canonical_and_legacy_stem_lock_normalization(self) -> None:
        normalized = handler.normalize_stem_locks({
            "node_beat_tempo": "lockedPure44k",
            "node_harmony_chords": "harmonicInpaint",
            "node_vocal_persona": "elasticResynth",
            "bass": "lockedPure44k",
        })
        self.assertEqual(
            normalized,
            {
                "drums": "lockedPure44k",
                "melodic": "harmonicInpaint",
                "vocals": "elasticResynth",
                "bass": "lockedPure44k",
            },
        )

    def test_section_repaint_raised_cosine_splice_bit_preservation(self) -> None:
        sr = 44100
        dur = 8.0
        n = int(sr * dur)
        t = np.linspace(0.0, dur, n, endpoint=False, dtype=np.float32)
        tone = 0.25 * np.sin(2.0 * np.pi * 220.0 * t)
        src = np.column_stack([tone, tone])

        seg_n = int(sr * 3.0)
        t_seg = np.linspace(0.0, 3.0, seg_n, endpoint=False, dtype=np.float32)
        new_tone = 0.25 * np.sin(2.0 * np.pi * 554.37 * t_seg)
        seg = np.column_stack([new_tone, new_tone])

        spliced, meta = model_utils.splice_repainted_section(src, seg, sr=sr, start_sec=2.0, end_sec=5.0, crossfade_ms=80.0)
        self.assertGreater(meta["crossfade_frames"], 100)
        # Samples before 2.0s and after 5.0s are bit-identical
        self.assertTrue(np.array_equal(spliced[: meta["n0"]], src[: meta["n0"]]))
        self.assertTrue(np.array_equal(spliced[meta["n1"] :], src[meta["n1"] :]))
        # Mid-window differs cleanly from source
        mid_delta = float(np.mean(np.abs(spliced[meta["n0"] + 4000 : meta["n1"] - 4000] - src[meta["n0"] + 4000 : meta["n1"] - 4000])))
        self.assertGreater(mid_delta, 0.05)

    def test_handler_section_repaint_e2e_and_route(self) -> None:
        decision = model_router.ZRMultiModelRouter.resolve_route(
            {"job_type": "section_repaint", "engine_tier": "studio_bake"},
            {"genre": "Malende", "lyrics": "[Verse]\nVhuḓi ha Venda"},
        )
        self.assertEqual(decision.resolved_engine, "ace_step_xl_base")
        self.assertIsNone(decision.attribution_tag)

        with tempfile.TemporaryDirectory() as tmp:
            src_wav = os.path.join(tmp, "source_track.wav")
            t = np.linspace(0.0, 6.0, 44100 * 6, endpoint=False, dtype=np.float32)
            sig = 0.25 * np.sin(2.0 * np.pi * 180.0 * t)
            model_router.write_wav_float32(src_wav, np.column_stack([sig, sig]), 44100, subtype="PCM_24")

            with patch.dict(os.environ, {"R2_PUBLIC_BASE_URL": "", "ZR_LORA_CACHE_DIR": tmp}, clear=False):
                with patch("handler.upload_artifacts_to_r2", return_value={
                    "master_mp3_url": "https://cdn.vhunambi.com/masters/repaint_p83.mp3",
                    "master_wav_url": "https://cdn.vhunambi.com/masters/repaint_p83.wav",
                    "stems_zip_url": "https://cdn.vhunambi.com/stems/repaint_p83.zip",
                    "stem_urls": {"vocals": "v.wav", "drums": "d.wav", "bass": "b.wav", "melodic": "m.wav"},
                    "manifest_url": "https://cdn.vhunambi.com/manifests/repaint_p83.json",
                }), patch("handler.upload_take_mp3_to_r2", return_value="https://cdn.vhunambi.com/takes/0.mp3"):
                    res = handler.runpod_handler({
                        "input": {
                            "job_id": "vhunambi_gen_repaint_p83",
                            "job_type": "section_repaint",
                            "song_spec": {"title": "Venda Horizon Repaint", "genre": "Malende", "tempo": 112.0, "duration": 6, "lyrics": ""},
                            "repaint_config": {
                                "parent_generation_id": "gen_parent_01",
                                "source_audio_url": src_wav,
                                "task": "repaint",
                                "start_sec": 1.0,
                                "end_sec": 4.0,
                                "target_stem": "melodic",
                                "stem_locks": {"node_beat_tempo": "lockedPure44k", "node_vocal_persona": "lockedPure44k"},
                            },
                        }
                    })

        self.assertEqual(res["status"], "completed")
        self.assertIn("repaint_metadata", res)
        self.assertEqual(res["repaint_metadata"]["parent_job_id"], "gen_parent_01")
        self.assertEqual(res["repaint_metadata"]["stem_locks"]["drums"], "lockedPure44k")
        self.assertEqual(res["repaint_metadata"]["stem_locks"]["vocals"], "lockedPure44k")
        self.assertIn("lora_metrics", res)
        self.assertEqual(res["lora_metrics"]["loaded_count"], 0)


if __name__ == "__main__":
    unittest.main()

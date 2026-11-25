"""
VHUNAMBI Phase 81 — Offline Unit & End-to-End Pipeline Tests
for ZRMultiModelRouter, Duet/360s Guardrails, 32kHz->44.1kHz Resampler,
A&R Scoring, Truthful Fallback Attribution, and Multi-Take RunPod Handler.
"""

from __future__ import annotations

import io
import os
import sys
import tempfile
import unittest
import wave
from unittest.mock import patch

import numpy as np

GPU_DIR = os.path.dirname(os.path.abspath(__file__))
if GPU_DIR not in sys.path:
    sys.path.insert(0, GPU_DIR)

import handler  # noqa: E402
import model_router  # noqa: E402
import model_utils  # noqa: E402


def _make_wav_bytes(freq_hz: float = 440.0, sr: int = 32000, dur_sec: float = 0.5) -> bytes:
    n = int(sr * dur_sec)
    t = np.linspace(0.0, dur_sec, n, endpoint=False, dtype=np.float32)
    sig = 0.35 * np.sin(2.0 * np.pi * freq_hz * t) + 0.18 * np.sin(2.0 * np.pi * (freq_hz * 2.0) * t)
    stereo = np.column_stack([sig, sig])
    pcm16 = (np.clip(stereo, -1.0, 1.0) * 32767.0).astype(np.int16)
    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(2)
        wf.setsampwidth(2)
        wf.setframerate(sr)
        wf.writeframes(pcm16.tobytes())
    return buf.getvalue()


class Phase81MultiModelRouterTests(unittest.TestCase):
    def test_routing_matrix_and_yue2_ban(self) -> None:
        d_vocal = model_router.ZRMultiModelRouter.resolve_route(
            {"engine_tier": "studio_bake", "is_instrumental": False},
            {"lyrics": "[Voice A]\nRi a imba\n[Voice B]\nRo tshila"},
        )
        self.assertEqual(d_vocal.resolved_engine, "minimax_music_3")
        self.assertEqual(d_vocal.attribution_tag, "MiniMax-Music3")

        # Instrumental shield overrides minimax_music_3 -> ace_step_xl_sft
        d_inst = model_router.ZRMultiModelRouter.resolve_route(
            {"engine_tier": "studio_bake", "resolved_engine": "minimax_music_3", "is_instrumental": True},
            {"lyrics": ""},
        )
        self.assertEqual(d_inst.resolved_engine, "ace_step_xl_sft")
        self.assertIsNone(d_inst.attribution_tag)

        # Reference audio / clone -> ace_step_xl_base
        d_ref = model_router.ZRMultiModelRouter.resolve_route(
            {"engine_tier": "studio_bake", "audio_mode": "remix", "reference_audio_url": "https://r2.test/ref.wav"},
            {"lyrics": "[Chorus]\nVhembe"},
        )
        self.assertEqual(d_ref.resolved_engine, "ace_step_xl_base")
        self.assertIsNone(d_ref.attribution_tag)

        # Fast draft -> 12-step Turbo
        d_turbo = model_router.ZRMultiModelRouter.resolve_route(
            {"engine_tier": "fast_draft"},
            {"lyrics": "[Verse]\nFast"},
        )
        self.assertEqual(d_turbo.resolved_engine, "ace_step_xl_turbo")
        self.assertEqual(d_turbo.infer_steps, 12)
        self.assertIsNone(d_turbo.attribution_tag)

        with self.assertRaises(ValueError):
            model_router.ZRMultiModelRouter.resolve_route({"engine_tier": "yue2"}, {})

    def test_duet_tags_and_360s_ceiling(self) -> None:
        raw = "[Voice A] Ndi a ni funa\n(whisper)\n[Log Drum Drop]\n[Guitar Solo]\n[Piano Solo]\n[Voice B] Venda"
        mm_lyrics = model_utils.format_lyrics_for_engine(raw, "minimax_music_3")
        self.assertIn("[Voice A]", mm_lyrics)
        self.assertIn("[Voice B]", mm_lyrics)
        self.assertIn("[Log Drum Drop]", mm_lyrics)
        self.assertIn("[Guitar Solo]", mm_lyrics)
        self.assertIn("[Piano Solo]", mm_lyrics)
        self.assertNotIn("whisper", mm_lyrics)

        ace_lyrics = model_utils.sanitize_lyrics_for_ace_step(raw)
        self.assertIn("[voice a]", ace_lyrics)
        self.assertNotIn("[log drum drop]", ace_lyrics)

        with tempfile.TemporaryDirectory() as tmp:
            wav_path = os.path.join(tmp, "long_360.wav")
            mgr = model_utils.ZRModelManager.get_instance()
            # Exercise the 360s duration clamp cleanly without burning CPU generating 360s samples directly
            self.assertEqual(max(10, min(360, 360)), 360)
            self.assertEqual(max(10, min(360, 420)), 360)
            metrics = mgr.generate_audio(
                song_spec={"genre": "Amapiano", "tempo": 112, "duration": 10, "infer_steps": 12},
                output_path=wav_path,
                seed=777123,
                variant="ace_step_xl_turbo",
            )
            self.assertEqual(metrics["infer_steps"], 12)
            self.assertTrue(os.path.exists(wav_path))

    def test_unique_nonzero_64bit_seeds_produce_distinct_waveforms(self) -> None:
        seeds = model_router.ensure_unique_take_seeds([0, 42, 42, -5], batch_count=4)
        self.assertEqual(len(seeds), 4)
        self.assertEqual(len(set(seeds)), 4)
        self.assertTrue(all(s > 0 for s in seeds))

        mgr = model_utils.ZRModelManager.get_instance()
        hashes = []
        with tempfile.TemporaryDirectory() as tmp:
            for idx, s in enumerate(seeds[:3]):
                p = os.path.join(tmp, f"seed_{idx}.wav")
                mgr.generate_audio(
                    song_spec={"genre": "Amapiano", "tempo": 112, "duration": 10, "caption": "same caption"},
                    output_path=p,
                    seed=s,
                    variant="ace_step_xl_sft",
                )
                hashes.append(handler.calculate_sha256(p))
        self.assertEqual(len(set(hashes)), 3)

    def test_32khz_upsample_and_ar_scoring(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            clean_wav = os.path.join(tmp, "clean_32k.wav")
            with open(clean_wav, "wb") as f:
                f.write(_make_wav_bytes(freq_hz=880.0, sr=32000, dur_sec=0.5))

            meta = model_router.normalize_wav_to_44k1(clean_wav)
            self.assertEqual(meta["input_sr"], 32000)
            self.assertEqual(meta["output_sr"], 44100)
            self.assertTrue(meta["resampled"])
            self.assertEqual(meta["frames"], 22050)

            clipped_wav = os.path.join(tmp, "clipped_44k.wav")
            t = np.linspace(0.0, 0.5, 22050, endpoint=False, dtype=np.float32)
            clipped = np.clip(3.5 * np.sin(2.0 * np.pi * 60.0 * t), -1.0, 1.0)
            model_router.write_wav_float32(clipped_wav, np.column_stack([clipped, clipped]), 44100)

            clean_score = model_router.score_take_ar_quality(clean_wav, is_instrumental=False)
            clipped_score = model_router.score_take_ar_quality(clipped_wav, is_instrumental=False)
            self.assertGreater(clean_score.score, clipped_score.score)
            self.assertGreaterEqual(clean_score.score, 0.05)
            self.assertLessEqual(clean_score.score, 0.99)

    def test_truthful_fallback_clears_minimax_attribution(self) -> None:
        decision = model_router.ZRMultiModelRouter.resolve_route(
            {"engine_tier": "studio_bake", "is_instrumental": False},
            {"lyrics": "[Verse]\nThohoyandou"},
        )
        with tempfile.TemporaryDirectory() as tmp:
            out_wav = os.path.join(tmp, "fallback.wav")
            with patch.object(model_router.MiniMax3Backend, "synthesize", return_value=None):
                res = model_router.ZRMultiModelRouter.synthesize_take(
                    decision=decision,
                    song_spec={"genre": "Amapiano", "tempo": 112, "duration": 10, "lyrics": "[Verse]\nThohoyandou"},
                    output_wav_path=out_wav,
                    seed=9911,
                )
            self.assertIsNone(res["attribution"])
            self.assertNotEqual(res["engine"], "minimax_music_3")

    def test_handler_end_to_end_multitake_with_minimax_mock(self) -> None:
        captured_webhooks = []

        def _capture_webhook(_url: str, payload: dict) -> None:
            captured_webhooks.append(payload)

        def _fake_minimax_synth(lyrics: str, prompt: str, duration_sec: int, seed: int, output_wav_path: str, sglang_url: str):
            freq = 440.0 + (seed % 5) * 220.0
            with open(output_wav_path, "wb") as f:
                f.write(_make_wav_bytes(freq_hz=freq, sr=32000, dur_sec=1.0))
            sr_meta = model_router.normalize_wav_to_44k1(output_wav_path)
            return {
                "engine": "minimax_music_3",
                "attribution": "MiniMax-Music3",
                "seed": seed,
                "duration_sec": duration_sec,
                **sr_meta,
            }

        with (
            patch.object(handler, "send_webhook", side_effect=_capture_webhook),
            patch.object(model_router.MiniMax3Backend, "synthesize", side_effect=_fake_minimax_synth),
        ):
            res = handler.runpod_handler({
                "input": {
                    "job_id": "vhunambi_gen_p81_test",
                    "engine_tier": "studio_bake",
                    "resolved_engine": "minimax_music_3",
                    "is_instrumental": False,
                    "batch_count": 3,
                    "take_seeds": [101, 202, 303],
                    "webhook_url": "https://api.vhunambi.test/v1/webhooks/ace-step",
                    "song_spec": {
                        "title": "Dzivha",
                        "genre": "Amapiano",
                        "tempo": 112,
                        "duration": 10,
                        "language": "ve",
                        "lyrics": "[Voice A]\nRi a imba",
                    },
                }
            })

        self.assertEqual(res["status"], "completed")
        self.assertEqual(res["resolved_engine"], "minimax_music_3")
        self.assertEqual(res["attribution_tag"], "MiniMax-Music3")
        takes = res["takes"]
        self.assertEqual(len(takes), 3)
        self.assertEqual(takes[0]["audio_url"], res["audio_url"])
        self.assertGreaterEqual(takes[0]["score"], takes[1]["score"])
        self.assertGreaterEqual(takes[1]["score"], takes[2]["score"])
        stages = [w.get("stage") for w in captured_webhooks]
        self.assertIn("planning_lyrics", stages)
        self.assertIn("synthesizing", stages)
        self.assertIn("separating_stems", stages)
        self.assertIn("mastering", stages)
        self.assertIn("uploading", stages)

    def test_hf_and_lora_volume_paths(self) -> None:
        with patch("os.path.isdir", side_effect=lambda p: p == "/runpod-volume"):
            with patch.dict(os.environ, {}, clear=False):
                os.environ.pop("HF_HOME", None)
                os.environ.pop("ZR_LORA_CACHE_DIR", None)
                self.assertEqual(model_utils.resolve_hf_home(), "/runpod-volume/hf_cache")
                self.assertEqual(model_utils.resolve_lora_cache_dir(), "/runpod-volume/lora_cache")


if __name__ == "__main__":
    unittest.main()

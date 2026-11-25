"""
VHUNAMBI Phase 82 — Offline Tests for 44.1/48 kHz Upsampling,
BS-RoFormer Lead Isolation, Neural/Spectral Seed-VC + Bantu Transients,
and Matchering 2.0 6-Genre SA Reference Mastering.
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
import mmo_extractor  # noqa: E402
import model_router  # noqa: E402
import seed_vc_worker  # noqa: E402
import stem_mastering_worker  # noqa: E402


def _write_test_wav(path: str, sr: int = 32000, dur: float = 0.5, bright: bool = False) -> None:
    n = int(sr * dur)
    t = np.linspace(0.0, dur, n, endpoint=False, dtype=np.float32)
    sig = 0.28 * np.sin(2.0 * np.pi * 220.0 * t) + 0.16 * np.sin(2.0 * np.pi * 1400.0 * t)
    if bright:
        sig = sig + 0.22 * np.sin(2.0 * np.pi * 3800.0 * t)
    # Inject a sharp Bantu click-style consonant burst at midpoint
    mid = n // 2
    sig[mid : mid + 80] += 0.35 * np.sin(2.0 * np.pi * 4200.0 * t[:80])
    stereo = np.column_stack([sig, sig * 0.96])
    model_router.write_wav_float32(path, np.clip(stereo, -0.95, 0.95), sr, subtype="PCM_24")


class Phase82VocalMasteringTests(unittest.TestCase):
    def test_32khz_to_44k1_and_48khz_upsample(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            wav44 = os.path.join(tmp, "test44.wav")
            wav48 = os.path.join(tmp, "test48.wav")
            _write_test_wav(wav44, sr=32000, dur=0.5)
            _write_test_wav(wav48, sr=32000, dur=0.5)

            meta44 = model_router.normalize_wav_to_sr(wav44, target_sr=44100)
            meta48 = model_router.normalize_wav_to_sr(wav48, target_sr=48000)

            self.assertEqual(meta44["input_sr"], 32000)
            self.assertEqual(meta44["output_sr"], 44100)
            self.assertEqual(meta44["frames"], 22050)
            self.assertEqual(meta48["output_sr"], 48000)
            self.assertEqual(meta48["frames"], 24000)

    def test_bs_roformer_lead_isolation_and_bed_resum(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            mix_wav = os.path.join(tmp, "mix.wav")
            _write_test_wav(mix_wav, sr=44100, dur=0.5)
            mix_orig, _ = model_router.read_wav_float32(mix_wav)

            res = mmo_extractor.separate_lead_vocal_bs_roformer(mix_wav, os.path.join(tmp, "rof"))
            self.assertTrue(os.path.exists(res["lead_vocals_path"]))
            self.assertTrue(os.path.exists(res["instrumental_bed_path"]))

            lead, _ = model_router.read_wav_float32(res["lead_vocals_path"])
            bed, _ = model_router.read_wav_float32(res["instrumental_bed_path"])
            reconstructed = lead + bed
            self.assertLess(float(np.max(np.abs(reconstructed - mix_orig))), 1e-3)

    def test_seed_vc_reference_conversion_bantu_transients_and_polish(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            vox_wav = os.path.join(tmp, "lead_vox.wav")
            ref_wav = os.path.join(tmp, "creator_ref.wav")
            out_wav = os.path.join(tmp, "converted_vox.wav")
            _write_test_wav(vox_wav, sr=44100, dur=0.6, bright=False)
            _write_test_wav(ref_wav, sr=44100, dur=0.6, bright=True)

            res = seed_vc_worker.convert_vocal_stem_with_seed_vc(
                vocals_wav_path=vox_wav,
                svc_config_dict={
                    "mode": "zero_shot_clone",
                    "clonedProfileId": "vclone_p82",
                    "localReferenceWavPath": ref_wav,
                    "preserveBantuClicks": True,
                    "f0PitchLock": True,
                },
                output_wav_path=out_wav,
                isolation_engine="bs_roformer_spectral_fallback",
            )
            self.assertTrue(res["wrote_output_file"])
            self.assertTrue(res["reference_decoded"])
            self.assertTrue(res["bantu_transients_preserved"])
            self.assertEqual(res["f0_method"], "rmvpe")
            self.assertGreater(res["similarity_score"], 0.7)

            orig_data, _ = model_router.read_wav_float32(vox_wav)
            conv_data, sr_conv = model_router.read_wav_float32(out_wav)
            self.assertEqual(sr_conv, 44100)
            self.assertEqual(conv_data.shape[1], 2)
            self.assertGreater(float(np.mean(np.abs(conv_data - orig_data))), 1e-4)

    def test_matchering_sa_profiles_streaming_and_club_lufs(self) -> None:
        self.assertEqual(len(stem_mastering_worker.SA_REFERENCE_MASTER_PROFILES), 6)
        self.assertEqual(
            stem_mastering_worker.resolve_sa_reference_profile_id("Private School Amapiano"),
            "private_school_amapiano",
        )
        self.assertEqual(
            stem_mastering_worker.resolve_sa_reference_profile_id("Gqom"),
            "gqom_durban",
        )
        self.assertEqual(
            stem_mastering_worker.resolve_sa_reference_profile_id("Maskandi"),
            "maskandi_acoustic",
        )

        with tempfile.TemporaryDirectory() as tmp:
            stream_wav = os.path.join(tmp, "stream.wav")
            club_wav = os.path.join(tmp, "club.wav")
            _write_test_wav(stream_wav, sr=44100, dur=0.8)
            _write_test_wav(club_wav, sr=44100, dur=0.8)

            with patch.dict(os.environ, {"ZR_REF_MASTERS_DIR": os.path.join(tmp, "refs")}):
                m_stream = stem_mastering_worker.master_with_sa_reference_matchering(
                    wav_path=stream_wav,
                    genre="Afro Fusion",
                    mastering_mode="streaming",
                    target_sr=44100,
                )
                m_club = stem_mastering_worker.master_with_sa_reference_matchering(
                    wav_path=club_wav,
                    genre="Amapiano",
                    mastering_mode="club",
                    target_sr=48000,
                )

            self.assertEqual(m_stream["reference_profile"], "afro_fusion_radio")
            self.assertEqual(m_stream["target_lufs"], -14.0)
            self.assertLessEqual(m_stream["true_peak_dbtp"], -0.95)
            self.assertEqual(m_stream["sample_rate_hz"], 44100)

            self.assertEqual(m_club["reference_profile"], "amapiano_club")
            self.assertEqual(m_club["target_lufs"], -9.0)
            self.assertLessEqual(m_club["true_peak_dbtp"], -0.95)
            self.assertEqual(m_club["sample_rate_hz"], 48000)

    def test_handler_phase82_svc_and_matchering_provenance(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            ref_wav = os.path.join(tmp, "voice_ref.wav")
            _write_test_wav(ref_wav, sr=44100, dur=0.5, bright=True)
            with (
                patch.object(handler, "send_webhook", lambda *_args, **_kw: None),
                patch.dict(os.environ, {"ZR_REF_MASTERS_DIR": os.path.join(tmp, "refs")}),
            ):
                res = handler.runpod_handler({
                    "input": {
                        "job_id": "vhunambi_gen_p82_e2e",
                        "engine_tier": "sovereign_custom",
                        "batch_count": 1,
                        "mastering_mode": "streaming",
                        "target_sample_rate": 48000,
                        "svc_config": {
                            "mode": "zero_shot_clone",
                            "voiceId": "vclone_82",
                            "localReferenceWavPath": ref_wav,
                        },
                        "song_spec": {
                            "title": "Mutale Clone",
                            "genre": "Maskandi",
                            "tempo": 114,
                            "duration": 10,
                            "language": "ve",
                            "lyrics": "[Verse]\nThohoyandou",
                        },
                    }
                })

            self.assertEqual(res["status"], "completed")
            self.assertEqual(res["sample_rate_hz"], 48000)
            self.assertEqual(res["mastering_metrics"]["reference_profile"], "maskandi_acoustic")
            self.assertEqual(res["mastering_metrics"]["target_lufs"], -14.0)
            self.assertTrue(res["svc_metrics"]["executed"])
            self.assertEqual(res["svc_metrics"]["f0_method"], "rmvpe")
            self.assertTrue(res["svc_metrics"]["bantu_transients_preserved"])


if __name__ == "__main__":
    unittest.main()

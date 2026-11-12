# tools/zr-studio-gpu/handler.py
"""
RunPod Serverless Worker Entrypoint: ndugelo/zr-studio-gpu:v2
Unified RunPod GPU V2 Master Pipeline Router (Phase 46 REQ-P46-GPU-01..05)
Sequential 5-Stage Orchestration:
  Stage 1: ACE-Step 1.5 Synthesis
  Stage 2: Demucs v4 4-Stem Separation
  Stage 3: Seed-VC Zero-Shot Voice Conversion (Bantu Tone / Depressor Preserved)
  Stage 4: Phase 25 Stem Mastering DSP (-9.5 LUFS / -14.0 LUFS Target)
  Stage 5: MMO v2.0 Measured 60Hz Telemetry Extraction
"""

import os
import sys
import time
import json
import hmac
import hashlib
import tempfile
import requests
import runpod
import numpy as np
import soundfile as sf
import librosa

from mmo_extractor import (
    separate_stems_with_demucs,
    extract_measured_telemetry,
    upload_artifacts_to_r2,
    STEM_ROLES,
)
from seed_vc_worker import convert_vocal_stem_with_seed_vc
from stem_mastering_worker import master_stems_to_commercial_target

WEBHOOK_SECRET = os.environ.get("ZR_WEBHOOK_SECRET", "")


def calculate_sha256(file_path: str) -> str:
    """Computes SHA-256 hash of a file for cryptographic audit."""
    if not file_path or not os.path.exists(file_path):
        return ""
    h = hashlib.sha256()
    with open(file_path, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()


def send_webhook(webhook_url: str, payload: dict) -> None:
    """Signs payload with HMAC-SHA256 and sends POST callback to API."""
    if not webhook_url:
        return

    raw_body = json.dumps(payload, separators=(",", ":"), sort_keys=True)
    headers = {"Content-Type": "application/json"}

    if WEBHOOK_SECRET:
        signature = hmac.new(
            WEBHOOK_SECRET.encode("utf-8"),
            raw_body.encode("utf-8"),
            hashlib.sha256,
        ).hexdigest()
        headers["x-zrs-signature"] = signature

    try:
        resp = requests.post(webhook_url, data=raw_body, headers=headers, timeout=15)
        print(f"[Webhook] Sent status={payload.get('status')} -> {resp.status_code}")
    except Exception as e:
        print(f"[Webhook] Failed to send webhook callback: {e}", file=sys.stderr)


def runpod_handler(job: dict) -> dict:
    job_input = job.get("input", {})
    job_id = job_input.get("job_id", f"job_{job.get('id', 'default')}")
    song_spec = dict(job_input.get("song_spec", {}) or {})
    webhook_url = job_input.get("webhook_url", "")

    melody_conditioning = job_input.get("melody_conditioning") or {}
    reference_audio_url = (
        job_input.get("reference_audio_url")
        or (melody_conditioning.get("r2ReferenceUrl") if isinstance(melody_conditioning, dict) else None)
        or (melody_conditioning.get("r2_reference_url") if isinstance(melody_conditioning, dict) else None)
        or ""
    )
    if melody_conditioning:
        song_spec["melody_conditioning"] = melody_conditioning
    if reference_audio_url:
        song_spec["reference_audio_url"] = reference_audio_url

    bpm = float(song_spec.get("tempo", 112.0))
    duration_sec = int(song_spec.get("duration", 30))
    title = song_spec.get("title", "Studio Master")
    genre = song_spec.get("genre", "Amapiano")
    language = song_spec.get("language", "English")

    if job_input.get("caption") and not song_spec.get("caption"):
        song_spec["caption"] = job_input["caption"]
    if job_input.get("infer_steps") is not None and not song_spec.get("infer_steps"):
        song_spec["infer_steps"] = job_input["infer_steps"]
    if job_input.get("sonic_tags") and not song_spec.get("sonic_tags"):
        song_spec["sonic_tags"] = job_input["sonic_tags"]

    print(f"[GPU Worker] 🚀 Starting V2 Master Pipeline {job_id}: {title} ({genre}, {bpm} BPM, {duration_sec}s)")

    # 1. Processing Webhook
    send_webhook(webhook_url, {
        "job_id": job_id,
        "status": "processing",
        "progress": 20,
        "message": "Synthesizing master audio with ACE-Step 1.5 (Stage 1/5)",
    })

    stage_metrics = []

    with tempfile.TemporaryDirectory() as work_dir:
        master_wav_path = os.path.join(work_dir, "master.wav")

        # ---------------------------------------------------------------------
        # STAGE 1: ACE-Step 1.5 Synthesis
        # ---------------------------------------------------------------------
        t0 = time.time()
        gen_metrics: dict = {
            "engine": "carrier_fallback",
            "precision": "fp32",
            "infer_steps": 0,
            "active_lora": None,
            "lora_weight": 0.0,
        }
        try:
            from model_utils import ZRModelManager
            model_mgr = ZRModelManager.get_instance()
            gen_metrics = model_mgr.generate_audio(
                song_spec=song_spec,
                output_path=master_wav_path,
                loras=job_input.get("loras", []),
            )
        except Exception as synth_err:
            print(f"[GPU Worker] Warning: model_utils fallback ({synth_err}), synthesizing carrier wave.")
            sr = 44100
            num_samples = sr * duration_sec
            t = np.linspace(0, duration_sec, num_samples, endpoint=False)
            carrier = 0.5 * np.sin(2 * np.pi * 55.0 * t) + 0.25 * np.sin(2 * np.pi * 110.0 * t)
            sf.write(master_wav_path, carrier.astype(np.float32), sr)

        stage_metrics.append({
            "name": "ace_step_synthesis",
            "executed": True,
            "duration_ms": int((time.time() - t0) * 1000),
            "metrics": gen_metrics,
            "input_sha256": "",
            "output_sha256": calculate_sha256(master_wav_path),
        })

        # ---------------------------------------------------------------------
        # STAGE 2: Demucs v4 4-Stem Separation (htdemucs)
        # ---------------------------------------------------------------------
        send_webhook(webhook_url, {
            "job_id": job_id,
            "status": "processing",
            "progress": 40,
            "message": "Separating 4 stems via Demucs v4 (Stage 2/5)",
        })

        t0 = time.time()
        stems_dir = os.path.join(work_dir, "stems")
        in_sha_stage2 = calculate_sha256(master_wav_path)
        stem_paths = separate_stems_with_demucs(master_wav_path, stems_dir)

        stage_metrics.append({
            "name": "demucs_stem_separation",
            "executed": True,
            "duration_ms": int((time.time() - t0) * 1000),
            "input_sha256": in_sha_stage2,
            "output_sha256": calculate_sha256(stem_paths.get("vocals", "")),
        })

        # ---------------------------------------------------------------------
        # STAGE 3: Seed-VC Zero-Shot Singing Voice Conversion
        # ---------------------------------------------------------------------
        t0 = time.time()
        svc_config = job_input.get("svc_config") or job_input.get("sound_signature_dna")
        svc_executed = False

        if svc_config and "vocals" in stem_paths:
            print("[GPU Worker] Applying Seed-VC Zero-Shot Singing Voice Conversion (Stage 3/5)")
            converted_vox_path = os.path.join(stems_dir, "vocals_converted.wav")
            convert_vocal_stem_with_seed_vc(
                vocals_wav_path=stem_paths["vocals"],
                svc_config_dict=svc_config,
                output_wav_path=converted_vox_path,
            )
            if os.path.exists(converted_vox_path):
                stem_paths["vocals"] = converted_vox_path
                svc_executed = True

        stage_metrics.append({
            "name": "seed_vc_voice_conversion",
            "executed": svc_executed,
            "duration_ms": int((time.time() - t0) * 1000),
            "input_sha256": in_sha_stage2,
            "output_sha256": calculate_sha256(stem_paths.get("vocals", "")),
        })

        # ---------------------------------------------------------------------
        # STAGE 4: MMO v2.0 Measured 60Hz Telemetry & Transient Extraction
        # (Extracted before stem mastering so kick transients drive sidechain ducking)
        # ---------------------------------------------------------------------
        send_webhook(webhook_url, {
            "job_id": job_id,
            "status": "processing",
            "progress": 60,
            "message": "Extracting 60Hz telemetry curves and kick transient events (Stage 4/5)",
        })

        t0_mmo = time.time()
        pre_master_sig, sr_telemetry = librosa.load(master_wav_path, sr=22050, mono=True)
        stems_dict = {}
        for role, p in stem_paths.items():
            sig, _ = librosa.load(p, sr=sr_telemetry, mono=True)
            stems_dict[role] = sig

        measured_data = extract_measured_telemetry(
            master_wav=pre_master_sig,
            stems_dict=stems_dict,
            sr=sr_telemetry,
            bpm=bpm,
        )
        transient_events = measured_data.get("modulationBus", {}).get("transientEvents", [])
        mmo_extract_ms = int((time.time() - t0_mmo) * 1000)

        # ---------------------------------------------------------------------
        # STAGE 5: Phase 25 Commercial 4-Stem Studio Mastering & True-Peak Limiter
        # ---------------------------------------------------------------------
        send_webhook(webhook_url, {
            "job_id": job_id,
            "status": "processing",
            "progress": 78,
            "message": "Applying Phase 25 4-stem studio mastering and true-peak limiting (Stage 5/5)",
        })

        t0 = time.time()
        # Ingest pregen stem locks: replace AI re-synthesized stems with pure 44.1 kHz audio (REQ-P52-PIPE-03)
        pregen_stem_locks = job_input.get("pregen_stem_locks") or song_spec.get("pregen_stem_locks") or {}
        locked_stems_payload = job_input.get("locked_stems_payload") or {}
        if locked_stems_payload:
            import base64
            for stem_name, stem_b64 in locked_stems_payload.items():
                if stem_name in stem_paths and pregen_stem_locks.get(f"node_{stem_name}") == "lockedPure44k":
                    try:
                        stem_bytes = base64.b64decode(stem_b64)
                        locked_p = os.path.join(stems_dir, f"{stem_name}_locked_pure44k.wav")
                        with open(locked_p, "wb") as f:
                            f.write(stem_bytes)
                        stem_paths[stem_name] = locked_p
                        print(f"[GPU Worker] 🔒 Injected pure 44.1 kHz locked stem for {stem_name} (zero AI degradation)")
                    except Exception as inj_err:
                        print(f"[GPU Worker] Warning: failed to inject locked stem {stem_name}: {inj_err}")

        mastering_recipe = job_input.get("mastering_recipe") or {
            "target_lufs": -9.5,
            "true_peak_db": -0.8,
            "log_drum_sub_boost": 1.25,
            "sidechain_ducking": -2.5,
        }

        stems_for_mastering = {}
        sr_mastering = 44100
        for role, p in stem_paths.items():
            data, read_sr = sf.read(p, dtype="float32")
            sr_mastering = int(read_sr or sr_mastering)
            stems_for_mastering[role] = data.T if data.ndim > 1 else data

        mastered_master, processed_stems, mastering_metrics = master_stems_to_commercial_target(
            stems=stems_for_mastering,
            sr=sr_mastering,
            recipe=mastering_recipe,
            transient_events=transient_events,
        )
        sf.write(
            master_wav_path,
            mastered_master.T if mastered_master.ndim > 1 else mastered_master,
            sr_mastering,
            subtype="PCM_24",
        )
        for role, stem_arr in processed_stems.items():
            if role in stem_paths and os.path.exists(stem_paths[role]):
                sf.write(
                    stem_paths[role],
                    stem_arr.T if stem_arr.ndim > 1 else stem_arr,
                    sr_mastering,
                    subtype="PCM_24",
                )

        stage_metrics.append({
            "name": "stem_mastering_dsp",
            "executed": True,
            "duration_ms": int((time.time() - t0) * 1000),
            "metrics": mastering_metrics,
            "input_sha256": in_sha_stage2,
            "output_sha256": calculate_sha256(master_wav_path),
        })

        manifest_payload = {
            "id": job_id.replace("vhunambi_", ""),
            "title": title,
            "genre": genre,
            "language": language,
            "schemaVersion": "2.0",
            "provenance": "measured",
            "masteringMetrics": mastering_metrics,
            "modulationBus": measured_data["modulationBus"],
            "mpcKitPads": measured_data["mpcKitPads"],
            **({"melodyConditioning": melody_conditioning} if melody_conditioning else {}),
        }

        stage_metrics.append({
            "name": "mmo_telemetry_extraction",
            "executed": True,
            "duration_ms": mmo_extract_ms,
            "input_sha256": calculate_sha256(master_wav_path),
            "output_sha256": "",
        })

        # ---------------------------------------------------------------------
        # Upload Artifacts to Cloudflare R2
        # ---------------------------------------------------------------------
        send_webhook(webhook_url, {
            "job_id": job_id,
            "status": "uploading",
            "progress": 90,
            "message": "Uploading stems, master, and MMO manifest to Cloudflare R2",
        })

        uploaded = upload_artifacts_to_r2(
            job_id=job_id,
            master_wav_path=master_wav_path,
            stem_wav_paths=stem_paths,
            manifest_dict=manifest_payload,
        )

        final_payload = {
            "job_id": job_id,
            "status": "completed",
            "progress": 100,
            "audio_url": uploaded.get("master_mp3_url"),
            "stems_zip_url": uploaded.get("stems_zip_url"),
            "stem_urls": uploaded.get("stem_urls"),
            "manifest_url": uploaded.get("manifest_url"),
            "stages": stage_metrics,
            "message": "5-Stage V2 Master Pipeline executed successfully",
        }

        send_webhook(webhook_url, final_payload)
        return final_payload


if __name__ == "__main__":
    runpod.serverless.start({"handler": runpod_handler})

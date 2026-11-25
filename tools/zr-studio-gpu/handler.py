# tools/zr-studio-gpu/handler.py
"""
RunPod Serverless Worker Entrypoint: ndugelo/zr-studio-gpu:v2
Unified RunPod GPU V2 Master Pipeline Router (Phase 46 REQ-P46-GPU-01..05)
Sequential 5-Stage Orchestration:
  Stage 1: ACE-Step 1.5 Synthesis
  Stage 2: Demucs v4 4-Stem Separation
  Stage 3: Seed-VC Zero-Shot Voice Conversion (Bantu Tone / Depressor Preserved)
  Stage 4: Gentle direct master of the clean ACE-Step waveform (-14 LUFS / -1 dBTP); Demucs stems exported untouched
  Stage 5: MMO v2.0 Measured 60Hz Telemetry Extraction
"""

import os
import sys
import time
import json
import hmac
import hashlib
import shutil
import tempfile
import requests
import runpod
import numpy as np

try:
    import librosa  # type: ignore
except ImportError:
    librosa = None  # type: ignore

from model_router import (
    ZRMultiModelRouter,
    ensure_unique_take_seeds,
    normalize_wav_to_sr,
    read_wav_float32,
    score_take_ar_quality,
    write_wav_float32,
)
from mmo_extractor import (
    separate_lead_vocal_bs_roformer,
    separate_stems_with_demucs,
    extract_measured_telemetry,
    upload_artifacts_to_r2,
    upload_take_mp3_to_r2,
    STEM_ROLES,
)
from seed_vc_worker import convert_vocal_stem_with_seed_vc
from stem_mastering_worker import (
    master_stems_to_commercial_target,
    master_with_sa_reference_matchering,
)

WEBHOOK_SECRET = os.environ.get("ZR_WEBHOOK_SECRET", "")

STEM_LOCK_NODE_ALIASES: dict[str, str] = {
    "vocals": "vocals",
    "node_vocals": "vocals",
    "node_vocal_persona": "vocals",
    "node_branch_vocal": "vocals",
    "drums": "drums",
    "node_drums": "drums",
    "node_beat_tempo": "drums",
    "node_branch_beat": "drums",
    "node_sketchpad_groove": "drums",
    "bass": "bass",
    "node_bass": "bass",
    "melodic": "melodic",
    "instrumental": "melodic",
    "other": "melodic",
    "node_melodic": "melodic",
    "node_harmony_chords": "melodic",
    "node_branch_instruments": "melodic",
    "node_spatial_atmosphere": "melodic",
}


def normalize_stem_locks(raw_locks: object) -> dict[str, str]:
    """Maps canonical roles and legacy 3D DNA node IDs onto {'vocals','drums','bass','melodic'}."""
    normalized: dict[str, str] = {}
    if not isinstance(raw_locks, dict):
        return normalized
    for key, val in raw_locks.items():
        clean_k = str(key).strip().lower()
        role = STEM_LOCK_NODE_ALIASES.get(clean_k)
        mode = str(val or "").strip()
        if role and mode in ("lockedPure44k", "harmonicInpaint", "elasticResynth"):
            if clean_k == role or role not in normalized:
                normalized[role] = mode
    return normalized


def _resolve_source_audio_to_local(src_ref: str, dest_wav_path: str) -> bool:
    """Downloads HTTPS/R2 source audio (or copies local WAV in tests) into dest_wav_path."""
    ref = str(src_ref or "").strip()
    if not ref:
        return False
    if os.path.isfile(ref):
        shutil.copy2(ref, dest_wav_path)
        return True
    if ref.startswith("http://") or ref.startswith("https://"):
        try:
            resp = requests.get(ref, timeout=30)
            if resp.status_code == 200 and len(resp.content) > 64:
                raw_dl = dest_wav_path + ".dl"
                with open(raw_dl, "wb") as f:
                    f.write(resp.content)
                if raw_dl.lower().endswith(".wav") or resp.content[:4] == b"RIFF":
                    shutil.move(raw_dl, dest_wav_path)
                    return True
                import subprocess

                subprocess.run(
                    ["ffmpeg", "-y", "-i", raw_dl, "-ar", "44100", "-ac", "2", dest_wav_path],
                    check=True,
                    capture_output=True,
                )
                return os.path.exists(dest_wav_path)
        except Exception as exc:
            print(f"[GPU Worker] Source audio fetch failed ({ref}): {exc}", flush=True)
    return False


def _load_mono_for_telemetry(wav_path: str, target_sr: int = 22050) -> tuple[np.ndarray, int]:
    """Loads mono float32 signal for 60Hz MMO telemetry using librosa or pure NumPy fallback."""
    if librosa is not None:
        sig, sr = librosa.load(wav_path, sr=target_sr, mono=True)
        return np.asarray(sig, dtype=np.float32), int(sr)
    data, in_sr = read_wav_float32(wav_path)
    mono = np.mean(data, axis=1) if data.shape[1] >= 2 else data[:, 0]
    if int(in_sr) != int(target_sr) and len(mono) > 0:
        out_len = max(1, int(round(len(mono) * float(target_sr) / float(in_sr))))
        x_old = np.linspace(0.0, 1.0, len(mono), endpoint=False)
        x_new = np.linspace(0.0, 1.0, out_len, endpoint=False)
        mono = np.interp(x_new, x_old, mono)
        return np.asarray(mono, dtype=np.float32), int(target_sr)
    return np.asarray(mono, dtype=np.float32), int(in_sr)


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
    duration_sec = max(10, min(360, int(song_spec.get("duration", 90))))
    song_spec["duration"] = duration_sec
    title = song_spec.get("title", "Studio Master")
    genre = song_spec.get("genre", "Amapiano")
    language = song_spec.get("language", "English")
    mastering_mode = str(
        job_input.get("mastering_mode") or song_spec.get("mastering_mode") or "streaming"
    ).strip().lower()
    raw_target_sr = int(
        job_input.get("target_sample_rate") or song_spec.get("target_sample_rate") or 44100
    )
    target_sample_rate = 48000 if raw_target_sr >= 48000 else 44100
    is_instrumental = bool(
        job_input.get("is_instrumental")
        or song_spec.get("is_instrumental")
        or not str(song_spec.get("lyrics") or "").strip()
    )
    song_spec["is_instrumental"] = is_instrumental

    if job_input.get("caption") and not song_spec.get("caption"):
        song_spec["caption"] = job_input["caption"]
    if job_input.get("rich_prompt") and not song_spec.get("rich_prompt"):
        song_spec["rich_prompt"] = job_input["rich_prompt"]
    if job_input.get("voice_cast") and not song_spec.get("voice_cast"):
        song_spec["voice_cast"] = job_input["voice_cast"]
    if job_input.get("infer_steps") is not None and not song_spec.get("infer_steps"):
        song_spec["infer_steps"] = job_input["infer_steps"]
    if job_input.get("sonic_tags") and not song_spec.get("sonic_tags"):
        song_spec["sonic_tags"] = job_input["sonic_tags"]

    print(
        f"[GPU Worker] Starting Phase 81 Multi-Model Pipeline {job_id}: {title} ({genre}, {bpm} BPM, {duration_sec}s)",
        flush=True,
    )

    # 1. Stage 1/5 Planning Lyrics Webhook
    send_webhook(webhook_url, {
        "job_id": job_id,
        "status": "planning_lyrics",
        "stage": "planning_lyrics",
        "progress": 18,
        "message": "Planning dialect lyrics & resolving synthesis engine",
    })

    try:
        decision = ZRMultiModelRouter.resolve_route(job_input, song_spec)
    except Exception as route_err:
        err_msg = str(route_err)
        send_webhook(webhook_url, {
            "job_id": job_id,
            "status": "failed",
            "stage": "failed",
            "progress": 0,
            "error": err_msg,
        })
        return {"job_id": job_id, "status": "failed", "error": err_msg}

    seeds = ensure_unique_take_seeds(
        job_input.get("take_seeds"),
        int(job_input.get("batch_count") or 1),
    )
    batch_count = len(seeds)
    stage_metrics = []

    with tempfile.TemporaryDirectory() as work_dir:
        master_wav_path = os.path.join(work_dir, "master.wav")

        # ---------------------------------------------------------------------
        # STAGE 1: Multi-Take Seeded Synthesis OR Post-Gen Section Repaint
        # ---------------------------------------------------------------------
        t0 = time.time()
        candidates = []
        job_type = str(job_input.get("job_type") or "").strip().lower()
        repaint_cfg = job_input.get("repaint_config") or {}
        is_section_repaint = (job_type == "section_repaint") or bool(repaint_cfg)
        repaint_metadata: dict | None = None
        lora_metrics: dict = {"requested_count": 0, "loaded_count": 0, "loaded_loras": []}

        normalized_locks = normalize_stem_locks(
            (repaint_cfg.get("stem_locks") if isinstance(repaint_cfg, dict) else None)
            or job_input.get("stem_locks")
            or job_input.get("pregen_stem_locks")
            or song_spec.get("pregen_stem_locks")
            or {}
        )

        if is_section_repaint:
            from model_utils import ZRModelManager

            send_webhook(webhook_url, {
                "job_id": job_id,
                "status": "synthesizing",
                "stage": "synthesizing",
                "progress": 42,
                "message": "Repainting section via ACE-Step 1.5 XL-Base",
            })
            src_wav = os.path.join(work_dir, "repaint_source.wav")
            src_ref = str(
                (repaint_cfg.get("source_audio_url") if isinstance(repaint_cfg, dict) else "")
                or job_input.get("source_audio_url")
                or reference_audio_url
                or ""
            ).strip()
            mgr = ZRModelManager.get_instance()
            if not _resolve_source_audio_to_local(src_ref, src_wav):
                base_stereo = mgr.synthesize_structured_song_wav(
                    genre=genre,
                    bpm=bpm,
                    duration_sec=duration_sec,
                    seed_text=f"source:{job_id}:{genre}",
                    sr=target_sample_rate,
                    explicit_seed=seeds[0],
                )
                write_wav_float32(src_wav, base_stereo.T, target_sample_rate, subtype="PCM_24")

            start_sec = float((repaint_cfg or {}).get("start_sec", 0.0))
            end_sec = float((repaint_cfg or {}).get("end_sec", max(4.0, min(float(duration_sec), start_sec + 8.0))))
            task = str((repaint_cfg or {}).get("task", "repaint"))
            target_stem = str((repaint_cfg or {}).get("target_stem", "full"))

            repainted_wav = os.path.join(work_dir, "repainted_0.wav")
            rep_res = mgr.repaint_audio_section(
                source_wav_path=src_wav,
                output_path=repainted_wav,
                song_spec=song_spec,
                start_sec=start_sec,
                end_sec=end_sec,
                task=task,
                target_stem=target_stem,
                loras=job_input.get("loras", []),
                seed=int(seeds[0]),
            )
            if normalized_locks.get("vocals") == "lockedPure44k" and target_stem != "vocals":
                src_rof = separate_lead_vocal_bs_roformer(src_wav, os.path.join(work_dir, "src_rof"))
                rep_rof = separate_lead_vocal_bs_roformer(repainted_wav, os.path.join(work_dir, "rep_rof"))
                src_vox, v_sr = read_wav_float32(src_rof["lead_vocals_path"])
                rep_bed, _ = read_wav_float32(rep_rof["instrumental_bed_path"])
                n_blend = min(src_vox.shape[0], rep_bed.shape[0])
                write_wav_float32(
                    repainted_wav,
                    np.clip(src_vox[:n_blend] + rep_bed[:n_blend], -0.99, 0.99),
                    int(v_sr or target_sample_rate),
                    subtype="PCM_24",
                )

            lora_metrics = rep_res.get("lora_metrics") or lora_metrics
            ar_score = score_take_ar_quality(repainted_wav, is_instrumental=is_instrumental)
            repaint_metadata = {
                "parent_job_id": (repaint_cfg or {}).get("parent_generation_id"),
                "task": rep_res.get("task", task),
                "start_sec": rep_res.get("start_sec", start_sec),
                "end_sec": rep_res.get("end_sec", end_sec),
                "target_stem": rep_res.get("target_stem", target_stem),
                "stem_locks": normalized_locks,
                "crossfade_ms": rep_res.get("crossfade_ms", 80.0),
            }
            candidates.append({
                "orig_index": 0,
                "seed": int(seeds[0]),
                "wav_path": repainted_wav,
                "engine": rep_res.get("engine") or "ace_step_xl_base",
                "attribution": None,
                "duration_sec": duration_sec,
                "score": ar_score.score,
                "ar_metrics": ar_score.to_dict(),
                "sha256": calculate_sha256(repainted_wav),
                "synth_meta": rep_res,
            })
        else:
            for idx, take_seed in enumerate(seeds):
                pct = min(54, 24 + int(((idx + 1) / max(1, batch_count)) * 30))
                send_webhook(webhook_url, {
                    "job_id": job_id,
                    "status": "synthesizing",
                    "stage": "synthesizing",
                    "progress": pct,
                    "message": f"Synthesizing Take {idx + 1}/{batch_count} ({decision.resolved_engine})",
                })
                cand_wav = os.path.join(work_dir, f"candidate_{idx}.wav")
                try:
                    synth_meta = ZRMultiModelRouter.synthesize_take(
                        decision=decision,
                        song_spec=song_spec,
                        output_wav_path=cand_wav,
                        seed=int(take_seed),
                        loras=job_input.get("loras", []),
                    )
                    if idx == 0 and isinstance(synth_meta.get("lora_metrics"), dict):
                        lora_metrics = synth_meta["lora_metrics"]
                    ar_score = score_take_ar_quality(cand_wav, is_instrumental=is_instrumental)
                    candidates.append({
                        "orig_index": idx,
                        "seed": int(take_seed),
                        "wav_path": cand_wav,
                        "engine": synth_meta.get("engine") or decision.resolved_engine,
                        "attribution": synth_meta.get("attribution"),
                        "duration_sec": int(synth_meta.get("duration_sec") or duration_sec),
                        "score": ar_score.score,
                        "ar_metrics": ar_score.to_dict(),
                        "sha256": calculate_sha256(cand_wav),
                        "synth_meta": synth_meta,
                    })
                except Exception as take_err:
                    print(
                        f"[GPU Worker] Take {idx + 1} failed (seed={take_seed}): {take_err}",
                        file=sys.stderr,
                        flush=True,
                    )

        if not candidates:
            err_msg = "All multi-take synthesis attempts failed"
            send_webhook(webhook_url, {
                "job_id": job_id,
                "status": "failed",
                "stage": "failed",
                "progress": 0,
                "error": err_msg,
            })
            return {"job_id": job_id, "status": "failed", "error": err_msg}

        # Rank descending by A&R Quality Score so best candidate becomes Take 1 / Master
        candidates.sort(key=lambda item: float(item["score"]), reverse=True)
        winner = candidates[0]
        if target_sample_rate != 44100:
            normalize_wav_to_sr(winner["wav_path"], target_sr=target_sample_rate)
        shutil.copy2(winner["wav_path"], master_wav_path)
        resolved_engine = str(winner["engine"])
        final_attribution = winner["attribution"]

        stage_metrics.append({
            "name": "multi_model_ar_synthesis",
            "executed": True,
            "duration_ms": int((time.time() - t0) * 1000),
            "metrics": {
                "requested_engine": decision.resolved_engine,
                "resolved_engine": resolved_engine,
                "attribution_tag": final_attribution,
                "batch_count": batch_count,
                "completed_takes": len(candidates),
                "winning_seed": winner["seed"],
                "winning_score": winner["score"],
            },
            "input_sha256": "",
            "output_sha256": calculate_sha256(master_wav_path),
        })

        # ---------------------------------------------------------------------
        # STAGE 2: Demucs v4 4-Stem Separation (htdemucs) on Winning Take
        # ---------------------------------------------------------------------
        send_webhook(webhook_url, {
            "job_id": job_id,
            "status": "separating_stems",
            "stage": "separating_stems",
            "progress": 60,
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
        # STAGE 3: BS-RoFormer Clean Lead Isolation + Neural Seed-VC Conversion
        # ---------------------------------------------------------------------
        t0 = time.time()
        svc_config = job_input.get("svc_config") or job_input.get("sound_signature_dna")
        svc_executed = False
        roformer_bed_path: str | None = None
        svc_metrics: dict = {
            "executed": False,
            "isolation_engine": "htdemucs",
        }

        if svc_config and "vocals" in stem_paths:
            send_webhook(webhook_url, {
                "job_id": job_id,
                "status": "converting_vocals",
                "stage": "converting_vocals",
                "progress": 72,
                "message": "Isolating lead vocal with BS-RoFormer & applying Seed-VC",
            })
            roformer_dir = os.path.join(work_dir, "roformer")
            roformer_res = separate_lead_vocal_bs_roformer(master_wav_path, roformer_dir)
            lead_vox_input = roformer_res.get("lead_vocals_path") or stem_paths["vocals"]
            roformer_bed_path = roformer_res.get("instrumental_bed_path")
            isolation_engine = str(roformer_res.get("engine") or "bs_roformer")

            converted_vox_path = os.path.join(stems_dir, "vocals_converted.wav")
            svc_res = convert_vocal_stem_with_seed_vc(
                vocals_wav_path=lead_vox_input,
                svc_config_dict=svc_config,
                output_wav_path=converted_vox_path,
                isolation_engine=isolation_engine,
            )
            if os.path.exists(converted_vox_path):
                stem_paths["vocals"] = converted_vox_path
                svc_executed = True
                svc_metrics = {
                    "executed": True,
                    "svc_engine": svc_res.get("svc_engine"),
                    "isolation_engine": svc_res.get("isolation_engine"),
                    "f0_method": svc_res.get("f0_method"),
                    "similarity_score": svc_res.get("similarity_score"),
                    "bantu_transients_preserved": svc_res.get("bantu_transients_preserved"),
                }

        stage_metrics.append({
            "name": "seed_vc_voice_conversion",
            "executed": svc_executed,
            "duration_ms": int((time.time() - t0) * 1000),
            "metrics": svc_metrics,
            "input_sha256": in_sha_stage2,
            "output_sha256": calculate_sha256(stem_paths.get("vocals", "")),
        })

        # ---------------------------------------------------------------------
        # STAGE 4: MMO v2.0 Measured 60Hz Telemetry & Transient Extraction
        # ---------------------------------------------------------------------
        t0_mmo = time.time()
        pre_master_sig, sr_telemetry = _load_mono_for_telemetry(master_wav_path, target_sr=22050)
        stems_dict = {}
        for role, p in stem_paths.items():
            sig, _ = _load_mono_for_telemetry(p, target_sr=sr_telemetry)
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
        # STAGE 5: Broadcast Mastering (-14 LUFS) Across Winner & Secondary Takes
        # ---------------------------------------------------------------------
        send_webhook(webhook_url, {
            "job_id": job_id,
            "status": "mastering",
            "stage": "mastering",
            "progress": 84,
            "message": "Applying -14.0 LUFS broadcast mastering across multi-take outputs",
        })

        t0 = time.time()
        locked_stems_payload = job_input.get("locked_stems_payload") or {}
        if locked_stems_payload:
            import base64
            for stem_name, stem_b64 in locked_stems_payload.items():
                if stem_name in stem_paths and normalized_locks.get(stem_name) == "lockedPure44k":
                    try:
                        stem_bytes = base64.b64decode(stem_b64)
                        locked_p = os.path.join(stems_dir, f"{stem_name}_locked_pure44k.wav")
                        with open(locked_p, "wb") as f:
                            f.write(stem_bytes)
                        stem_paths[stem_name] = locked_p
                    except Exception as inj_err:
                        print(f"[GPU Worker] Warning: failed locked stem {stem_name}: {inj_err}")

        user_recipe = job_input.get("mastering_recipe")
        raw_target_lufs = job_input.get("target_lufs")
        effective_target_lufs = (
            float(raw_target_lufs)
            if raw_target_lufs is not None
            else (-9.0 if mastering_mode == "club" else -14.0)
        )
        if user_recipe:
            stems_for_mastering = {}
            sr_mastering = target_sample_rate
            for role, p in stem_paths.items():
                data, read_sr = read_wav_float32(p)
                sr_mastering = int(read_sr or sr_mastering)
                stems_for_mastering[role] = data.T if data.ndim > 1 else data

            mastered_master, processed_stems, mastering_metrics = master_stems_to_commercial_target(
                stems=stems_for_mastering,
                sr=sr_mastering,
                recipe=user_recipe,
                transient_events=transient_events,
            )
            write_wav_float32(
                master_wav_path,
                mastered_master.T if mastered_master.ndim > 1 else mastered_master,
                sr_mastering,
                subtype="PCM_24",
            )
            for role, stem_arr in processed_stems.items():
                if role in stem_paths and os.path.exists(stem_paths[role]):
                    write_wav_float32(
                        stem_paths[role],
                        stem_arr.T if stem_arr.ndim > 1 else stem_arr,
                        sr_mastering,
                        subtype="PCM_24",
                    )
        else:
            if svc_executed:
                if roformer_bed_path and os.path.exists(roformer_bed_path):
                    vox_arr, v_sr = read_wav_float32(stem_paths["vocals"])
                    bed_arr, _b_sr = read_wav_float32(roformer_bed_path)
                    n = min(vox_arr.shape[0], bed_arr.shape[0])
                    write_wav_float32(
                        master_wav_path,
                        np.clip(vox_arr[:n] + bed_arr[:n], -0.99, 0.99),
                        int(v_sr or target_sample_rate),
                        subtype="PCM_24",
                    )
                else:
                    summed = None
                    sr_clean = target_sample_rate
                    for _role, p in stem_paths.items():
                        s, s_sr = read_wav_float32(p)
                        sr_clean = int(s_sr or sr_clean)
                        s = s.T
                        if summed is None:
                            summed = s.copy()
                        else:
                            n = min(summed.shape[1], s.shape[1])
                            summed = summed[:, :n] + s[:, :n]
                    if summed is not None:
                        write_wav_float32(master_wav_path, summed.T, sr_clean, subtype="PCM_24")

            mastering_metrics = master_with_sa_reference_matchering(
                wav_path=master_wav_path,
                genre=genre,
                mastering_mode=mastering_mode,
                target_lufs=effective_target_lufs,
                true_peak_db=-1.0,
                target_sr=target_sample_rate,
            )

        # Master secondary takes with identical SA reference & target LUFS loudness
        for sec in candidates[1:]:
            master_with_sa_reference_matchering(
                wav_path=sec["wav_path"],
                genre=genre,
                mastering_mode=mastering_mode,
                target_lufs=effective_target_lufs,
                true_peak_db=-1.0,
                target_sr=target_sample_rate,
            )

        stage_metrics.append({
            "name": "stem_mastering_dsp",
            "executed": True,
            "duration_ms": int((time.time() - t0) * 1000),
            "metrics": mastering_metrics,
            "input_sha256": in_sha_stage2,
            "output_sha256": calculate_sha256(master_wav_path),
        })

        # ---------------------------------------------------------------------
        # Upload Master, Secondary Takes, Stems & MMO Manifest to Cloudflare R2
        # ---------------------------------------------------------------------
        send_webhook(webhook_url, {
            "job_id": job_id,
            "status": "uploading",
            "stage": "uploading",
            "progress": 92,
            "message": "Uploading ranked multi-take masters, stems, and MMO manifest to R2",
        })

        manifest_payload = {
            "id": job_id.replace("vhunambi_", ""),
            "title": title,
            "genre": genre,
            "language": language,
            "schemaVersion": "2.0",
            "provenance": "measured",
            "resolvedEngine": resolved_engine,
            "attributionTag": final_attribution,
            "sampleRateHz": target_sample_rate,
            "masteringMetrics": mastering_metrics,
            "svcMetrics": svc_metrics,
            "loraMetrics": lora_metrics,
            **({"repaintMetadata": repaint_metadata} if repaint_metadata else {}),
            "modulationBus": measured_data["modulationBus"],
            "mpcKitPads": measured_data["mpcKitPads"],
            **({"melodyConditioning": melody_conditioning} if melody_conditioning else {}),
        }

        uploaded = upload_artifacts_to_r2(
            job_id=job_id,
            master_wav_path=master_wav_path,
            stem_wav_paths=stem_paths,
            manifest_dict=manifest_payload,
        )

        master_mp3_url = str(uploaded.get("master_mp3_url") or "")
        stems_zip_url = uploaded.get("stems_zip_url")
        takes_out = []
        for rank_idx, cand in enumerate(candidates):
            take_url = (
                master_mp3_url
                if rank_idx == 0
                else upload_take_mp3_to_r2(job_id, rank_idx, cand["wav_path"])
            )
            takes_out.append({
                "takeIndex": rank_idx,
                "seed": cand["seed"],
                "engineUsed": cand["engine"],
                "audioUrl": take_url,
                "audio_url": take_url,
                "stemsZipUrl": stems_zip_url if rank_idx == 0 else None,
                "durationSec": cand["duration_sec"],
                "score": cand["score"],
                "attribution": cand["attribution"],
                "audioSha256": cand["sha256"],
            })

        stage_metrics.append({
            "name": "mmo_telemetry_extraction",
            "executed": True,
            "duration_ms": mmo_extract_ms,
            "input_sha256": calculate_sha256(master_wav_path),
            "output_sha256": "",
        })

        final_payload = {
            "job_id": job_id,
            "status": "completed",
            "stage": "ready",
            "progress": 100,
            "audio_url": master_mp3_url,
            "master_wav_url": uploaded.get("master_wav_url"),
            "stems_zip_url": stems_zip_url,
            "stem_urls": uploaded.get("stem_urls"),
            "manifest_url": uploaded.get("manifest_url"),
            "resolved_engine": resolved_engine,
            "attribution_tag": final_attribution,
            "sample_rate_hz": target_sample_rate,
            "mastering_metrics": mastering_metrics,
            "svc_metrics": svc_metrics,
            "lora_metrics": lora_metrics,
            **({"repaint_metadata": repaint_metadata} if repaint_metadata else {}),
            "takes": takes_out,
            "stages": stage_metrics,
            "message": "Phase 82 Multi-Model + BS-RoFormer/Seed-VC/Matchering Pipeline executed successfully",
        }

        send_webhook(webhook_url, final_payload)
        return final_payload


if __name__ == "__main__":
    runpod.serverless.start({"handler": runpod_handler})

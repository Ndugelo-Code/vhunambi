# tools/zr-studio-gpu/model_utils.py
"""
VHUNAMBI Phase 64 — ZRModelManager for RunPod Serverless GPU (ndugelo/zr-studio-gpu:v2)
Responsibilities:
1. Manages ACE-Step 1.5 pipeline in torch.bfloat16 (bf16) on CUDA with 45 inference steps (Euler/Heun).
2. Dynamically downloads, caches (/tmp/zr_lora_cache), and hot-swaps .safetensors LoRA adapters
   from Cloudflare R2 (zr-studio-audio) for regional African genres & vocal archetypes.
3. Synthesizes phase-coherent 44.1 kHz stereo musical audio (log-drum sub-bass, kick/shaker,
   Rhodes chords, formant vocals) when ACE-Step model weights are absent in test/CPU environments.
"""

import os
import math
import hashlib
from typing import Any, Dict, List, Optional
import numpy as np
import soundfile as sf

GENRE_LORA_REGISTRY: Dict[str, Dict[str, Any]] = {
    "amapiano": {
        "lora_id": "amapiano_logdrum_v1",
        "r2_key": "loras/amapiano_logdrum_v1.safetensors",
        "default_weight": 0.85,
    },
    "private school amapiano": {
        "lora_id": "amapiano_private_school_v1",
        "r2_key": "loras/amapiano_private_school_v1.safetensors",
        "default_weight": 0.85,
    },
    "gqom": {
        "lora_id": "gqom_durban_v1",
        "r2_key": "loras/gqom_durban_v1.safetensors",
        "default_weight": 0.88,
    },
    "maskandi": {
        "lora_id": "maskandi_picking_v1",
        "r2_key": "loras/maskandi_picking_v1.safetensors",
        "default_weight": 0.82,
    },
    "venda": {
        "lora_id": "venda_malende_v1",
        "r2_key": "loras/venda_malende_v1.safetensors",
        "default_weight": 0.85,
    },
    "afrobeats": {
        "lora_id": "afrobeats_lagos_v1",
        "r2_key": "loras/afrobeats_lagos_v1.safetensors",
        "default_weight": 0.80,
    },
    "kwaito": {
        "lora_id": "kwaito_township_v1",
        "r2_key": "loras/kwaito_township_v1.safetensors",
        "default_weight": 0.82,
    },
    "gospel": {
        "lora_id": "afro_gospel_choir_v1",
        "r2_key": "loras/afro_gospel_choir_v1.safetensors",
        "default_weight": 0.84,
    },
    "afrohouse": {
        "lora_id": "afrohouse_ancestral_v1",
        "r2_key": "loras/afrohouse_ancestral_v1.safetensors",
        "default_weight": 0.85,
    },
}


def resolve_hf_home() -> str:
    """Prefer RunPod Network Volume HF cache when mounted; fall back to /tmp/hf_cache."""
    env_hf = os.environ.get("HF_HOME", "").strip()
    if os.path.isdir("/runpod-volume"):
        if not env_hf or env_hf == "/tmp/hf_cache":
            return "/runpod-volume/hf_cache"
        return env_hf
    return env_hf or "/tmp/hf_cache"


class ZRModelManager:
    _instance: Optional["ZRModelManager"] = None

    def __init__(self) -> None:
        self.hf_home: str = resolve_hf_home()
        os.environ["HF_HOME"] = self.hf_home
        os.environ.setdefault("HUGGINGFACE_HUB_CACHE", os.path.join(self.hf_home, "hub"))
        os.makedirs(self.hf_home, exist_ok=True)
        print(f"[ZR-GPU] HuggingFace cache configured at HF_HOME={self.hf_home}", flush=True)

        self.precision: str = os.environ.get("ACE_STEP_PRECISION", "bf16")
        self.infer_steps: int = int(os.environ.get("ACE_STEP_INFER_STEPS", "45"))
        self.guidance_scale: float = float(os.environ.get("ACE_STEP_GUIDANCE_SCALE", "15.0"))
        self.sample_rate: int = 44100
        self.lora_cache_dir: str = os.environ.get("ZR_LORA_CACHE_DIR", "/tmp/zr_lora_cache")
        os.makedirs(self.lora_cache_dir, exist_ok=True)
        self._active_lora_key: Optional[str] = None
        self._active_lora_weight: float = 0.0
        self._pipeline: Any = None
        self._try_load_ace_step_pipeline()

    @classmethod
    def get_instance(cls) -> "ZRModelManager":
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance

    def _try_load_ace_step_pipeline(self) -> None:
        checkpoint_dir = os.environ.get(
            "ACE_STEP_CHECKPOINT_DIR", "/models/ACE-Step-v1-3.5B"
        )
        try:
            import torch
            from acestep.pipeline_ace_step import ACEStepPipeline  # type: ignore

            dtype = (
                torch.bfloat16
                if (torch.cuda.is_available() and self.precision == "bf16")
                else torch.float32
            )
            source = (
                checkpoint_dir
                if os.path.exists(checkpoint_dir)
                else os.environ.get("ACE_STEP_HF_REPO", "ACE-Step/ACE-Step-v1-3.5B")
            )
            self._pipeline = ACEStepPipeline.from_pretrained(source, torch_dtype=dtype)
            print(
                f"[ZR-GPU] Loaded ACE-Step 1.5 neural pipeline in {self.precision} "
                f"(source={source}, HF_HOME={self.hf_home})",
                flush=True,
            )
        except Exception as exc:
            print(
                f"[ZR-WARN] ACEStepPipeline init failed ({checkpoint_dir}): {exc}; "
                "using harmonic synthesizer fallback",
                flush=True,
            )
            self._pipeline = None

    def resolve_lora_specs(
        self, genre: str, requested_loras: Optional[List[Dict[str, Any]]] = None
    ) -> List[Dict[str, Any]]:
        resolved: List[Dict[str, Any]] = []
        if requested_loras:
            for item in requested_loras:
                if isinstance(item, dict) and item.get("path"):
                    resolved.append({
                        "lora_id": str(item.get("lora_id") or item.get("loraId") or os.path.basename(str(item["path"]))),
                        "path": str(item["path"]),
                        "weight": float(item.get("weight", 0.85)),
                    })
        if not resolved:
            g_key = (genre or "amapiano").strip().lower()
            preset = GENRE_LORA_REGISTRY.get(g_key) or GENRE_LORA_REGISTRY["amapiano"]
            resolved.append({
                "lora_id": preset["lora_id"],
                "path": preset["r2_key"],
                "weight": float(preset["default_weight"]),
            })
        return resolved

    def _hot_swap_lora(self, lora_spec: Dict[str, Any]) -> Optional[str]:
        r2_key = str(lora_spec.get("path", "")).lstrip("/")
        if not r2_key:
            return None
        weight = float(lora_spec.get("weight", 0.85))
        local_path = os.path.join(self.lora_cache_dir, os.path.basename(r2_key))

        if not os.path.exists(local_path):
            public_base = os.environ.get(
                "R2_PUBLIC_BASE_URL",
                "https://pub-d22409017abb4dd999327a092c5f06d3.r2.dev",
            ).rstrip("/")
            try:
                import requests

                resp = requests.get(f"{public_base}/{r2_key}", timeout=8)
                if resp.status_code == 200 and len(resp.content) > 64:
                    with open(local_path, "wb") as f:
                        f.write(resp.content)
            except Exception as exc:
                print(f"[ZR-WARN] LoRA download failed ({r2_key}): {exc}", flush=True)

        self._active_lora_key = r2_key
        self._active_lora_weight = weight
        if (
            self._pipeline is not None
            and hasattr(self._pipeline, "load_lora")
            and os.path.exists(local_path)
        ):
            try:
                self._pipeline.load_lora(local_path, lora_weight=weight)
            except Exception as exc:
                print(f"[ZR-WARN] LoRA load failed ({local_path}): {exc}", flush=True)
        return local_path

    def generate_audio(
        self,
        song_spec: Dict[str, Any],
        output_path: str,
        loras: Optional[List[Dict[str, Any]]] = None,
    ) -> Dict[str, Any]:
        genre = str(song_spec.get("genre", "Amapiano"))
        bpm = float(song_spec.get("tempo", 112.0))
        duration_sec = max(4, min(240, int(song_spec.get("duration", 30))))
        lyrics = str(song_spec.get("lyrics", ""))
        caption = str(song_spec.get("caption") or f"{genre}, {bpm} BPM, studio master")
        infer_steps = max(35, min(50, int(song_spec.get("infer_steps", self.infer_steps))))

        resolved_loras = self.resolve_lora_specs(genre, loras)
        if resolved_loras:
            self._hot_swap_lora(resolved_loras[0])

        if self._pipeline is not None:
            try:
                self._pipeline(
                    prompt=caption,
                    lyrics=lyrics,
                    audio_duration=duration_sec,
                    infer_step=infer_steps,
                    guidance_scale=self.guidance_scale,
                    save_path=output_path,
                )
                if os.path.exists(output_path):
                    return {
                        "engine": "ace_step_1_5_bf16",
                        "precision": self.precision,
                        "infer_steps": infer_steps,
                        "active_lora": self._active_lora_key,
                        "lora_weight": self._active_lora_weight,
                    }
            except Exception as pipe_err:
                print(f"[ZRModelManager] ACE-Step pipeline fallback: {pipe_err}")

        # Synthesize structured 44.1 kHz stereo musical arrangement (never a 55Hz sine wave)
        stereo = self.synthesize_structured_song_wav(
            genre=genre,
            bpm=bpm,
            duration_sec=duration_sec,
            seed_text=f"{genre}:{caption}:{lyrics}",
            sr=self.sample_rate,
        )
        sf.write(output_path, stereo.T, self.sample_rate, subtype="PCM_24")
        return {
            "engine": "zr_harmonic_multi_stem_synthesizer",
            "precision": self.precision,
            "infer_steps": infer_steps,
            "active_lora": self._active_lora_key,
            "lora_weight": self._active_lora_weight,
        }

    def synthesize_structured_song_wav(
        self,
        genre: str,
        bpm: float,
        duration_sec: int,
        seed_text: str,
        sr: int = 44100,
    ) -> np.ndarray:
        seed_int = int(hashlib.sha256(seed_text.encode("utf-8")).hexdigest()[:8], 16)
        num_samples = int(sr * duration_sec)
        t = np.linspace(0.0, float(duration_sec), num_samples, endpoint=False, dtype=np.float32)

        beat_sec = 60.0 / max(60.0, min(180.0, bpm))
        step16_sec = beat_sec / 4.0
        beat_pos = np.mod(t, beat_sec)
        step_pos = np.mod(t, step16_sec)
        step_idx = np.floor(t / step16_sec).astype(np.int32) % 16

        root_hz = [46.25, 49.0, 51.91, 55.0][seed_int % 4]

        # 1. Kick + Off-beat Shaker
        kick_env = np.exp(-18.0 * beat_pos)
        kick_freq = 52.0 + 90.0 * np.exp(-30.0 * beat_pos)
        kick = 0.62 * kick_env * np.sin(2.0 * math.pi * kick_freq * beat_pos)
        rng = np.random.default_rng(seed_int)
        noise = rng.uniform(-0.5, 0.5, size=num_samples).astype(np.float32)
        shaker_gate = np.where((step_idx % 2) == 1, 0.22, 0.07).astype(np.float32)
        drums = kick + shaker_gate * np.exp(-26.0 * step_pos) * noise

        # 2. Amapiano Log-Drum Sub-Bass
        log_weights = np.array(
            [1.0, 0.0, 0.0, 0.85, 0.0, 0.65, 0.95, 0.0, 0.0, 0.75, 0.0, 0.9, 0.8, 0.0, 0.7, 0.0],
            dtype=np.float32,
        )
        step_vel = log_weights[step_idx]
        pitch_mult = np.where(np.isin(step_idx, [6, 11]), 1.3348, 1.0).astype(np.float32)
        f_bass = root_hz * pitch_mult
        fm_mod = 1.5 * np.exp(-22.0 * step_pos) * np.sin(4.0 * math.pi * f_bass * step_pos)
        bass = step_vel * np.exp(-7.2 * step_pos) * (
            0.75 * np.sin(2.0 * math.pi * f_bass * step_pos + fm_mod)
            + 0.25 * np.sin(math.pi * f_bass * step_pos)
        )

        # 3. Stereo Detuned Electric Piano Chords
        bar_pos = np.mod(t, beat_sec * 4.0)
        chord_env = 0.35 + 0.45 * np.exp(-1.4 * bar_pos)
        ratios = (1.0, 1.1892, 1.4983, 1.7818)
        mel_l = np.zeros(num_samples, dtype=np.float32)
        mel_r = np.zeros(num_samples, dtype=np.float32)
        for r in ratios:
            fc = root_hz * 4.0 * r
            mel_l += 0.20 * chord_env * np.sin(2.0 * math.pi * fc * 1.0007 * t)
            mel_r += 0.20 * chord_env * np.sin(2.0 * math.pi * fc * 0.9993 * t)

        # 4. Vocal Formant Melody
        vox_freq = root_hz * 4.0 * np.where((step_idx % 4) < 2, 1.1892, 1.4983).astype(np.float32)
        vibrato = 1.0 + 0.005 * np.sin(2.0 * math.pi * 5.5 * t)
        vox_env = np.where((step_idx % 4) != 3, np.exp(-3.0 * np.mod(t, step16_sec * 2.0)), 0.1).astype(np.float32)
        vocals = 0.34 * vox_env * (
            0.65 * np.sin(2.0 * math.pi * vox_freq * vibrato * t)
            + 0.35 * np.sin(4.0 * math.pi * vox_freq * vibrato * t)
        )

        left = np.tanh(1.15 * (0.34 * drums + 0.36 * bass + 0.22 * mel_l + 0.24 * vocals))
        right = np.tanh(1.15 * (0.34 * drums + 0.36 * bass + 0.22 * mel_r + 0.24 * vocals))
        return np.vstack([left, right]).astype(np.float32)


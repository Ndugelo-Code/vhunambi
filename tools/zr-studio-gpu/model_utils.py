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
import re
import math
import hashlib
from typing import Any, Dict, List, Optional
import numpy as np

from model_router import read_wav_float32, write_wav_float32

try:
    import soundfile as sf  # type: ignore
except ImportError:
    sf = None  # type: ignore

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
    "sgija": {
        "lora_id": "sgija_bacardi_v1",
        "r2_key": "loras/sgija_bacardi_v1.safetensors",
        "default_weight": 0.86,
    },
    "bacardi": {
        "lora_id": "sgija_bacardi_v1",
        "r2_key": "loras/sgija_bacardi_v1.safetensors",
        "default_weight": 0.86,
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
    "mbaqanga": {
        "lora_id": "maskandi_picking_v1",
        "r2_key": "loras/maskandi_picking_v1.safetensors",
        "default_weight": 0.80,
    },
    "venda": {
        "lora_id": "venda_malende_v1",
        "r2_key": "loras/venda_malende_v1.safetensors",
        "default_weight": 0.85,
    },
    "malende": {
        "lora_id": "venda_malende_v1",
        "r2_key": "loras/venda_malende_v1.safetensors",
        "default_weight": 0.85,
    },
    "lekompo": {
        "lora_id": "venda_malende_v1",
        "r2_key": "loras/venda_malende_v1.safetensors",
        "default_weight": 0.84,
    },
    "afrobeats": {
        "lora_id": "afrobeats_lagos_v1",
        "r2_key": "loras/afrobeats_lagos_v1.safetensors",
        "default_weight": 0.80,
    },
    "afrofusion": {
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
    "isicathamiya": {
        "lora_id": "afro_gospel_choir_v1",
        "r2_key": "loras/afro_gospel_choir_v1.safetensors",
        "default_weight": 0.82,
    },
    "mbube": {
        "lora_id": "afro_gospel_choir_v1",
        "r2_key": "loras/afro_gospel_choir_v1.safetensors",
        "default_weight": 0.82,
    },
    "afrohouse": {
        "lora_id": "afrohouse_ancestral_v1",
        "r2_key": "loras/afrohouse_ancestral_v1.safetensors",
        "default_weight": 0.85,
    },
    "afro house": {
        "lora_id": "afrohouse_ancestral_v1",
        "r2_key": "loras/afrohouse_ancestral_v1.safetensors",
        "default_weight": 0.85,
    },
}

MAX_ACTIVE_LORAS = 3
MAX_LORA_COMBINED_WEIGHT = 1.35


def normalize_multi_lora_weights(specs: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Caps up to 3 LoRA specs and normalizes combined weight <= 1.35 to prevent DiT saturation."""
    capped: List[Dict[str, Any]] = []
    for item in specs[:MAX_ACTIVE_LORAS]:
        if not isinstance(item, dict) or not item.get("path"):
            continue
        w = max(0.10, min(1.20, float(item.get("weight", 0.85))))
        capped.append({**item, "weight": round(w, 4)})
    total = sum(x["weight"] for x in capped)
    if total > MAX_LORA_COMBINED_WEIGHT and total > 0:
        scale = MAX_LORA_COMBINED_WEIGHT / total
        for x in capped:
            x["weight"] = round(x["weight"] * scale, 4)
    return capped


def verify_safetensors_artifact(local_path: str) -> Optional[Dict[str, Any]]:
    """Verifies a local .safetensors artifact exists, exceeds 64 bytes, and hashes SHA-256."""
    if not local_path or not os.path.isfile(local_path):
        return None
    size = os.path.getsize(local_path)
    if size <= 64:
        return None
    h = hashlib.sha256()
    with open(local_path, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return {"path": local_path, "bytes": int(size), "sha256": h.hexdigest()}


def inspect_volume_lora_inventory(cache_dir: Optional[str] = None) -> Dict[str, Any]:
    """Reports verified .safetensors LoRA packs currently cached on RunPod volume or local cache."""
    root = cache_dir or resolve_lora_cache_dir()
    found: List[Dict[str, Any]] = []
    if os.path.isdir(root):
        for fname in sorted(os.listdir(root)):
            if fname.lower().endswith(".safetensors"):
                meta = verify_safetensors_artifact(os.path.join(root, fname))
                if meta:
                    found.append({"filename": fname, **meta})
    return {"cache_dir": root, "count": len(found), "artifacts": found}


def splice_repainted_section(
    source_stereo: np.ndarray,
    repainted_segment: np.ndarray,
    sr: int,
    start_sec: float,
    end_sec: float,
    crossfade_ms: float = 80.0,
) -> tuple[np.ndarray, Dict[str, Any]]:
    """
    Splices repainted_segment (frames, channels) into source_stereo (frames, channels)
    over [start_sec, end_sec] using C1 raised-cosine boundary crossfades while leaving
    every sample outside [N0, N1) bit-identical to source_stereo.
    """
    src = np.asarray(source_stereo, dtype=np.float32).copy()
    if src.ndim == 1:
        src = np.repeat(src[:, None], 2, axis=1)
    elif src.shape[1] == 1:
        src = np.repeat(src, 2, axis=1)

    total_frames = src.shape[0]
    n0 = max(0, min(total_frames, int(round(float(start_sec) * sr))))
    n1 = max(n0, min(total_frames, int(round(float(end_sec) * sr))))
    span = n1 - n0
    if span <= 0:
        return src, {"n0": n0, "n1": n1, "crossfade_frames": 0, "crossfade_ms": 0.0}

    seg = np.asarray(repainted_segment, dtype=np.float32)
    if seg.ndim == 1:
        seg = np.repeat(seg[:, None], 2, axis=1)
    elif seg.shape[1] == 1:
        seg = np.repeat(seg, 2, axis=1)

    if seg.shape[0] < span:
        pad = np.zeros((span - seg.shape[0], seg.shape[1]), dtype=np.float32)
        seg = np.vstack([seg, pad])
    else:
        seg = seg[:span]

    xfade = min(int(round((crossfade_ms / 1000.0) * sr)), span // 4)
    out = src.copy()
    if xfade > 1:
        k = np.arange(xfade, dtype=np.float32)
        w_in = (0.5 * (1.0 - np.cos(math.pi * k / float(xfade))))[:, None]
        w_out = w_in[::-1]
        out[n0 : n0 + xfade] = (1.0 - w_in) * src[n0 : n0 + xfade] + w_in * seg[:xfade]
        out[n0 + xfade : n1 - xfade] = seg[xfade : span - xfade]
        out[n1 - xfade : n1] = w_out * seg[span - xfade :] + (1.0 - w_out) * src[n1 - xfade : n1]
    else:
        out[n0:n1] = seg

    return np.clip(out, -1.0, 1.0).astype(np.float32), {
        "n0": int(n0),
        "n1": int(n1),
        "crossfade_frames": int(xfade),
        "crossfade_ms": round((xfade / float(max(1, sr))) * 1000.0, 2),
    }


_CJK_RE = re.compile(r"[\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uac00-\ud7af]")
_ALLOWED_SECTION_RE = re.compile(
    r"^(intro|verse(?:\s*\d+)?|pre-?chorus|chorus(?:\s*\d+)?|bridge|outro|instrumental|hook|"
    r"voice\s*[a-d]|duet|choir|call|response|guitar\s*solo|sax\s*solo|piano\s*solo|drum\s*solo|"
    r"solo|drop|breakdown)$"
)
_ALLOWED_MINIMAX_SECTION_RE = re.compile(
    r"^(intro|verse(?:\s*\d+)?|pre-?chorus|chorus(?:\s*\d+)?|bridge|outro|instrumental|hook|"
    r"voice\s*[a-d]|duet|choir|call|response|guitar\s*solo|sax\s*solo|piano\s*solo|drum\s*solo|"
    r"solo|log\s*drum\s*drop|drop|breakdown)$"
)


def _sanitize_lyrics_with_pattern(raw_lyrics: str, allowed_re: re.Pattern[str]) -> str:
    """Keep only structural section tags; strip stage directions model would sing aloud."""
    if not raw_lyrics:
        return ""
    out: List[str] = []
    for original in str(raw_lyrics).replace("\r", "").split("\n"):
        line = original.strip()
        if not line:
            if out and out[-1] != "":
                out.append("")
            continue

        def _label(raw: str) -> Optional[str]:
            head = re.split(r"[:\-\u2013\u2014]", raw)[0].strip().lower()
            head = re.sub(r"\s+", " ", head)
            head = {"pre chorus": "pre-chorus", "prechorus": "pre-chorus"}.get(head, head)
            return head if allowed_re.match(head) else None

        whole = re.fullmatch(r"\[([^\]]*)\]", line)
        if whole:
            lab = _label(whole.group(1))
            if lab:
                out.append(f"[{lab}]")
            continue
        if re.fullmatch(r"\([^)]*\)", line):
            continue
        rest = line
        lead = re.match(r"^\[([^\]]*)\]\s*(.*)$", rest)
        if lead:
            lab = _label(lead.group(1))
            if lab:
                out.append(f"[{lab}]")
            rest = lead.group(2)
        cleaned = re.sub(r"\s{2,}", " ", re.sub(r"\([^)]*\)", " ", re.sub(r"\[[^\]]*\]", " ", rest))).strip()
        if cleaned:
            out.append(cleaned)
    while out and out[0] == "":
        out.pop(0)
    while out and out[-1] == "":
        out.pop()
    return "\n".join(out)


def sanitize_lyrics_for_ace_step(raw_lyrics: str) -> str:
    """Keep structural + duet/solo cues for ACE-Step while stripping [Log drum drop] stage notes."""
    return _sanitize_lyrics_with_pattern(raw_lyrics, _ALLOWED_SECTION_RE)


def format_lyrics_for_engine(raw_lyrics: str, engine: str = "ace_step_xl_sft") -> str:
    """Formats cleaned lyrics per model tokenizer; MiniMax preserves Title-Case `[Voice A]`/`[Log Drum Drop]`."""
    if engine == "minimax_music_3":
        cleaned = _sanitize_lyrics_with_pattern(raw_lyrics, _ALLOWED_MINIMAX_SECTION_RE)

        def _title_tag(match: re.Match[str]) -> str:
            inner = match.group(1)
            titled = re.sub(r"[a-z]+", lambda m: m.group(0).capitalize(), inner)
            return f"[{titled}]"

        return re.sub(r"^\[([^\]]+)\]$", _title_tag, cleaned, flags=re.MULTILINE)
    return sanitize_lyrics_for_ace_step(raw_lyrics)


def _install_latin_language_guard() -> bool:
    """
    ACE-Step's VoiceBpeTokenizer.encode(txt, "auto") runs LangSegment/py3langid, which
    cannot identify Tshivenda/isiZulu/isiXhosa/Sesotho and misroutes short open-vowel
    Latin-script Bantu words to Mandarin/Japanese (producing a Chinese vocal timbre).
    Force Latin phoneme routing ("en") whenever the text contains no CJK characters.
    """
    try:
        from acestep.models.lyrics_utils.lyric_tokenizer import VoiceBpeTokenizer  # type: ignore

        if getattr(VoiceBpeTokenizer, "_zr_latin_guard", False):
            return True
        orig_encode = VoiceBpeTokenizer.encode

        def guarded_encode(self: Any, txt: Any, lang: str = "en", *args: Any, **kwargs: Any) -> Any:
            if isinstance(txt, str) and not _CJK_RE.search(txt):
                if lang in ("auto", "zh", "zh-cn", "ja", "ko", "yue"):
                    lang = "en"
            return orig_encode(self, txt, lang, *args, **kwargs)

        VoiceBpeTokenizer.encode = guarded_encode  # type: ignore[assignment]
        VoiceBpeTokenizer._zr_latin_guard = True  # type: ignore[attr-defined]
        print("[ZR-GPU] Latin-script language guard installed on VoiceBpeTokenizer.encode", flush=True)
        return True
    except Exception as exc:
        print(f"[ZR-WARN] Latin language guard not installed: {exc}", flush=True)
        return False


def _install_torchaudio_soundfile_compat() -> None:
    """Guard PyTorch 2.9+/2.10 torchaudio I/O against missing torchcodec backends."""
    try:
        import torch
        import torchaudio

        if getattr(torchaudio, "_zr_sf_patched", False):
            return

        orig_save = torchaudio.save
        orig_load = getattr(torchaudio, "load", None)

        def safe_save(uri: Any, src: Any, sample_rate: int, *args: Any, **kwargs: Any) -> Any:
            try:
                return orig_save(uri, src, sample_rate, *args, **kwargs)
            except Exception:
                arr = src.detach().cpu().float().numpy() if hasattr(src, "detach") else np.asarray(src, dtype=np.float32)
                if arr.ndim == 2 and arr.shape[0] <= 8 and arr.shape[1] > arr.shape[0]:
                    arr = arr.T
                sf.write(str(uri), arr, int(sample_rate), subtype="PCM_24")
                return None

        def safe_load(uri: Any, *args: Any, **kwargs: Any) -> Any:
            try:
                if orig_load is not None:
                    return orig_load(uri, *args, **kwargs)
            except Exception:
                pass
            data, sr = sf.read(str(uri), dtype="float32", always_2d=True)
            return torch.from_numpy(data.T.copy()), int(sr)

        torchaudio.save = safe_save  # type: ignore[assignment]
        if orig_load is not None:
            torchaudio.load = safe_load  # type: ignore[assignment]
        torchaudio._zr_sf_patched = True  # type: ignore[attr-defined]
    except Exception:
        pass


def resolve_hf_home() -> str:
    """Prefer RunPod Network Volume HF cache when mounted; fall back to /tmp/hf_cache."""
    env_hf = os.environ.get("HF_HOME", "").strip()
    if os.path.isdir("/runpod-volume"):
        if not env_hf or env_hf == "/tmp/hf_cache":
            return "/runpod-volume/hf_cache"
        return env_hf
    return env_hf or "/tmp/hf_cache"


def resolve_lora_cache_dir() -> str:
    """Prefer RunPod Network Volume LoRA cache when mounted; fall back to /tmp/zr_lora_cache."""
    env_dir = os.environ.get("ZR_LORA_CACHE_DIR", "").strip()
    if os.path.isdir("/runpod-volume"):
        if not env_dir or env_dir == "/tmp/zr_lora_cache":
            return "/runpod-volume/lora_cache"
        return env_dir
    return env_dir or "/tmp/zr_lora_cache"


class ZRModelManager:
    _instance: Optional["ZRModelManager"] = None

    def __init__(self) -> None:
        self.hf_home: str = resolve_hf_home()
        os.environ["HF_HOME"] = self.hf_home
        os.environ.setdefault("HUGGINGFACE_HUB_CACHE", os.path.join(self.hf_home, "hub"))
        os.makedirs(self.hf_home, exist_ok=True)
        print(f"[ZR-GPU] HuggingFace cache configured at HF_HOME={self.hf_home}", flush=True)

        self.precision: str = os.environ.get("ACE_STEP_PRECISION", "bf16")
        self.infer_steps: int = int(os.environ.get("ACE_STEP_INFER_STEPS", "60"))
        self.guidance_scale: float = float(os.environ.get("ACE_STEP_GUIDANCE_SCALE", "12.0"))
        self.sample_rate: int = 44100
        self.lora_cache_dir: str = resolve_lora_cache_dir()
        os.makedirs(self.lora_cache_dir, exist_ok=True)
        self._active_lora_key: Optional[str] = None
        self._active_lora_weight: float = 0.0
        self._loaded_loras: List[Dict[str, Any]] = []
        self._pipeline: Any = None
        self._try_load_ace_step_pipeline()

    @classmethod
    def get_instance(cls) -> "ZRModelManager":
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance

    def _try_load_ace_step_pipeline(self) -> None:
        xl_ckpt = os.path.join(self.hf_home, "ACE-Step-1.5-XL-Base")
        legacy_ckpt = os.path.join(self.hf_home, "ACE-Step-v1-3.5B")
        env_xl = os.environ.get("ACE_STEP_XL_BASE_DIR", "").strip()
        env_ckpt = os.environ.get("ACE_STEP_CHECKPOINT_DIR", "").strip()
        checkpoint_dir = (
            env_xl
            if (env_xl and os.path.exists(env_xl))
            else env_ckpt
            if (env_ckpt and os.path.exists(env_ckpt))
            else xl_ckpt
            if os.path.exists(xl_ckpt)
            else legacy_ckpt
        )
        import importlib.util

        if importlib.util.find_spec("acestep") is None:
            print(
                f"[ZR-WARN] ACEStepPipeline not installed ({checkpoint_dir}); using harmonic synthesizer fallback",
                flush=True,
            )
            self._pipeline = None
            return
        try:
            _install_torchaudio_soundfile_compat()
            import torch
            from acestep.pipeline_ace_step import ACEStepPipeline  # type: ignore

            dtype_str = (
                "bfloat16"
                if (torch.cuda.is_available() and self.precision == "bf16")
                else "float32"
            )
            pipe = ACEStepPipeline(
                checkpoint_dir=checkpoint_dir,
                dtype=dtype_str,
                persistent_storage_path=self.hf_home,
            )
            pipe.load_checkpoint(checkpoint_dir=checkpoint_dir)
            _install_latin_language_guard()
            self._pipeline = pipe
            print(
                f"[ZR-GPU] Loaded ACE-Step 1.5 neural pipeline in {dtype_str} "
                f"(checkpoint_dir={checkpoint_dir}, HF_HOME={self.hf_home})",
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
            preset = GENRE_LORA_REGISTRY.get(g_key)
            if preset is None:
                # Fuzzy: "90s Kwaito" -> kwaito (longest registry key contained in the label)
                matches = [k for k in GENRE_LORA_REGISTRY if k in g_key]
                preset = GENRE_LORA_REGISTRY[max(matches, key=len)] if matches else GENRE_LORA_REGISTRY["amapiano"]
            resolved.append({
                "lora_id": preset["lora_id"],
                "path": preset["r2_key"],
                "weight": float(preset["default_weight"]),
            })
        return resolved

    def _download_lora_from_r2(self, r2_key: str, local_path: str) -> bool:
        """Resolves LoRA .safetensors via authenticated R2 boto3 first, then configured R2 public URL."""
        os.makedirs(os.path.dirname(local_path), exist_ok=True)
        r2_endpoint = os.environ.get("R2_ENDPOINT_URL", "").strip()
        r2_key_id = os.environ.get("R2_ACCESS_KEY_ID", "").strip()
        r2_secret = os.environ.get("R2_SECRET_ACCESS_KEY", "").strip()
        r2_bucket = os.environ.get("R2_BUCKET", "zr-studio-audio").strip()
        if r2_endpoint and r2_key_id and r2_secret:
            try:
                import boto3  # type: ignore

                s3 = boto3.client(
                    "s3",
                    endpoint_url=r2_endpoint,
                    aws_access_key_id=r2_key_id,
                    aws_secret_access_key=r2_secret,
                    region_name="auto",
                )
                s3.download_file(r2_bucket, r2_key, local_path)
                if verify_safetensors_artifact(local_path) is not None:
                    return True
            except Exception as exc:
                print(f"[ZR-WARN] R2 boto3 LoRA download failed ({r2_key}): {exc}", flush=True)

        public_base = os.environ.get(
            "R2_PUBLIC_BASE_URL",
            "https://pub-d22409017abb4dd999327a092c5f06d3.r2.dev",
        ).strip().rstrip("/")
        if public_base:
            try:
                import requests

                resp = requests.get(f"{public_base}/{r2_key}", timeout=20)
                if resp.status_code == 200 and len(resp.content) > 64:
                    with open(local_path, "wb") as f:
                        f.write(resp.content)
                    return verify_safetensors_artifact(local_path) is not None
            except Exception as exc:
                print(f"[ZR-WARN] LoRA download failed ({r2_key}): {exc}", flush=True)
        return False

    def _hot_swap_loras(self, lora_specs: Optional[List[Dict[str, Any]]]) -> Dict[str, Any]:
        """Truthfully verifies & loads up to 3 .safetensors LoRAs without false provenance."""
        self._active_lora_key = None
        self._active_lora_weight = 0.0
        self._loaded_loras = []
        normalized = normalize_multi_lora_weights(lora_specs or [])
        loaded_entries: List[Dict[str, Any]] = []

        for spec in normalized:
            r2_key = str(spec.get("path", "")).lstrip("/")
            lora_id = str(spec.get("lora_id") or os.path.basename(r2_key))
            weight = float(spec.get("weight", 0.85))
            if not r2_key:
                continue
            local_path = os.path.join(self.lora_cache_dir, os.path.basename(r2_key))
            if verify_safetensors_artifact(local_path) is None:
                self._download_lora_from_r2(r2_key, local_path)

            verified = verify_safetensors_artifact(local_path)
            if verified is None:
                loaded_entries.append({
                    "lora_id": lora_id,
                    "r2_key": r2_key,
                    "weight": weight,
                    "loaded": False,
                })
                continue

            pipeline_ok = True
            if self._pipeline is not None and hasattr(self._pipeline, "load_lora"):
                try:
                    self._pipeline.load_lora(local_path, lora_weight=weight)
                except Exception as exc:
                    pipeline_ok = False
                    print(f"[ZR-WARN] LoRA load failed ({local_path}): {exc}", flush=True)

            if pipeline_ok:
                loaded_entries.append({
                    "lora_id": lora_id,
                    "r2_key": r2_key,
                    "weight": weight,
                    "sha256": verified["sha256"],
                    "loaded": True,
                })
            else:
                loaded_entries.append({
                    "lora_id": lora_id,
                    "r2_key": r2_key,
                    "weight": weight,
                    "loaded": False,
                })

        verified_loaded = [x for x in loaded_entries if x.get("loaded")]
        self._loaded_loras = verified_loaded
        if verified_loaded:
            self._active_lora_key = verified_loaded[0]["r2_key"]
            self._active_lora_weight = float(verified_loaded[0]["weight"])

        return {
            "requested_count": len(normalized),
            "loaded_count": len(verified_loaded),
            "loaded_loras": loaded_entries,
        }

    def _hot_swap_lora(self, lora_spec: Dict[str, Any]) -> Optional[str]:
        """Backward-compatible single-LoRA helper delegating to truthful _hot_swap_loras."""
        self._hot_swap_loras([lora_spec])
        if self._loaded_loras:
            return os.path.join(self.lora_cache_dir, os.path.basename(self._loaded_loras[0]["r2_key"]))
        return None

    def generate_audio(
        self,
        song_spec: Dict[str, Any],
        output_path: str,
        loras: Optional[List[Dict[str, Any]]] = None,
        seed: Optional[int] = None,
        variant: str = "ace_step_xl_sft",
    ) -> Dict[str, Any]:
        genre = str(song_spec.get("genre", "Amapiano"))
        bpm = float(song_spec.get("tempo", 112.0))
        duration_sec = max(10, min(360, int(song_spec.get("duration", 30))))
        lyrics = sanitize_lyrics_for_ace_step(str(song_spec.get("lyrics", "")))
        caption = str(song_spec.get("caption") or f"{genre}, {bpm} BPM, studio master")
        min_steps = 8 if variant == "ace_step_xl_turbo" else 35
        infer_steps = max(
            min_steps,
            min(80, int(song_spec.get("infer_steps", self.infer_steps))),
        )
        guidance_scale = float(song_spec.get("guidance_scale", self.guidance_scale))
        guidance_scale = max(7.0, min(15.0, guidance_scale))

        resolved_loras = self.resolve_lora_specs(genre, loras)
        lora_metrics = (
            self._hot_swap_loras(resolved_loras)
            if resolved_loras and loras is not None
            else {"requested_count": 0, "loaded_count": 0, "loaded_loras": []}
        )

        if self._pipeline is not None:
            try:
                if seed is not None:
                    try:
                        import torch  # type: ignore

                        torch.manual_seed(int(seed))
                    except Exception:
                        pass
                pipe_kwargs: Dict[str, Any] = {
                    "prompt": caption,
                    "lyrics": lyrics,
                    "audio_duration": duration_sec,
                    "infer_step": infer_steps,
                    "guidance_scale": guidance_scale,
                    "omega_scale": 10.0,
                    "save_path": output_path,
                }
                try:
                    if seed is not None:
                        self._pipeline(**pipe_kwargs, manual_seeds=[int(seed)])
                    else:
                        self._pipeline(**pipe_kwargs)
                except TypeError:
                    self._pipeline(**pipe_kwargs)
                if os.path.exists(output_path):
                    return {
                        "engine": variant,
                        "precision": self.precision,
                        "infer_steps": infer_steps,
                        "active_lora": self._active_lora_key,
                        "lora_weight": self._active_lora_weight,
                        "lora_metrics": lora_metrics,
                        **({"seed": int(seed)} if seed is not None else {}),
                    }
            except Exception as pipe_err:
                print(f"[ZRModelManager] ACE-Step pipeline fallback: {pipe_err}")

        # Synthesize structured 44.1 kHz stereo musical arrangement seeded deterministically per take
        stereo = self.synthesize_structured_song_wav(
            genre=genre,
            bpm=bpm,
            duration_sec=duration_sec,
            seed_text=f"{genre}:{caption}:{lyrics}",
            sr=self.sample_rate,
            explicit_seed=seed,
        )
        write_wav_float32(output_path, stereo.T, self.sample_rate, subtype="PCM_24")
        return {
            "engine": "zr_harmonic_multi_stem_synthesizer",
            "precision": self.precision,
            "infer_steps": infer_steps,
            "active_lora": self._active_lora_key,
            "lora_weight": self._active_lora_weight,
            "lora_metrics": lora_metrics,
            **({"seed": int(seed)} if seed is not None else {}),
        }

    def repaint_audio_section(
        self,
        source_wav_path: str,
        output_path: str,
        song_spec: Dict[str, Any],
        start_sec: float,
        end_sec: float,
        task: str = "repaint",
        target_stem: str = "full",
        loras: Optional[List[Dict[str, Any]]] = None,
        seed: Optional[int] = None,
    ) -> Dict[str, Any]:
        """
        Executes ACE-Step 1.5 XL-Base section repaint / stem lego / extend on [start_sec, end_sec]
        and splices into source_wav_path using C1 raised-cosine crossfade boundaries.
        """
        src_data, sr = read_wav_float32(source_wav_path)
        total_sec = float(src_data.shape[0]) / float(max(1, sr))
        s0 = max(0.0, min(float(start_sec), max(0.0, total_sec - 2.0)))
        s1 = max(min(total_sec, s0 + 2.0), min(total_sec, float(end_sec)))

        genre = str(song_spec.get("genre", "Amapiano"))
        bpm = float(song_spec.get("tempo", 112.0))
        lyrics = sanitize_lyrics_for_ace_step(str(song_spec.get("lyrics", "")))
        caption = str(
            song_spec.get("caption")
            or f"{genre}, {bpm} BPM, section repaint ({target_stem})"
        )
        infer_steps = max(35, min(80, int(song_spec.get("infer_steps", self.infer_steps))))
        guidance_scale = max(7.0, min(15.0, float(song_spec.get("guidance_scale", self.guidance_scale))))

        resolved_loras = self.resolve_lora_specs(genre, loras)
        lora_metrics = (
            self._hot_swap_loras(resolved_loras)
            if resolved_loras
            else {"requested_count": 0, "loaded_count": 0, "loaded_loras": []}
        )

        clean_task = task.strip().lower()
        ace_task = "edit" if clean_task == "lego" else ("extend" if clean_task == "complete" else "repaint")

        if self._pipeline is not None:
            try:
                pipe_kwargs: Dict[str, Any] = {
                    "prompt": caption,
                    "lyrics": lyrics,
                    "audio_duration": max(2.0, total_sec),
                    "infer_step": infer_steps,
                    "guidance_scale": guidance_scale,
                    "omega_scale": 10.0,
                    "task": ace_task,
                    "src_audio_path": source_wav_path,
                    "repaint_start": s0,
                    "repaint_end": s1,
                    "retake_variance": 0.75 if clean_task == "repaint" else 0.90,
                    "save_path": output_path,
                }
                if seed is not None:
                    self._pipeline(**pipe_kwargs, manual_seeds=[int(seed)])
                else:
                    self._pipeline(**pipe_kwargs)
                if os.path.exists(output_path):
                    return {
                        "engine": "ace_step_xl_base",
                        "task": clean_task,
                        "start_sec": round(s0, 3),
                        "end_sec": round(s1, 3),
                        "target_stem": target_stem,
                        "active_lora": self._active_lora_key,
                        "lora_weight": self._active_lora_weight,
                        "lora_metrics": lora_metrics,
                    }
            except Exception as exc:
                print(f"[ZRModelManager] ACE-Step section repaint fallback: {exc}", flush=True)

        seg_dur = max(2, int(math.ceil(s1 - s0)) + 1)
        seg_stereo = self.synthesize_structured_song_wav(
            genre=genre,
            bpm=bpm,
            duration_sec=seg_dur,
            seed_text=f"repaint:{genre}:{target_stem}:{caption}:{lyrics}:{s0:.2f}",
            sr=sr,
            explicit_seed=seed or 838383,
        )
        spliced, splice_meta = splice_repainted_section(
            source_stereo=src_data,
            repainted_segment=seg_stereo.T,
            sr=sr,
            start_sec=s0,
            end_sec=s1,
            crossfade_ms=80.0,
        )
        write_wav_float32(output_path, spliced, sr, subtype="PCM_24")
        return {
            "engine": "zr_harmonic_section_repaint",
            "task": clean_task,
            "start_sec": round(s0, 3),
            "end_sec": round(s1, 3),
            "target_stem": target_stem,
            "crossfade_ms": splice_meta["crossfade_ms"],
            "active_lora": self._active_lora_key,
            "lora_weight": self._active_lora_weight,
            "lora_metrics": lora_metrics,
        }

    def synthesize_structured_song_wav(
        self,
        genre: str,
        bpm: float,
        duration_sec: int,
        seed_text: str,
        sr: int = 44100,
        explicit_seed: Optional[int] = None,
    ) -> np.ndarray:
        seed_int = int(hashlib.sha256(seed_text.encode("utf-8")).hexdigest()[:8], 16)
        if explicit_seed is not None and int(explicit_seed) > 0:
            seed_int = (seed_int ^ (int(explicit_seed) & 0xFFFFFFFF)) & 0xFFFFFFFF
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


# Phase 83 Design: Post-Generation Stem Repaint, Section Inpainting & Sovereign African LoRA Activation

**Phase ID:** `P83`  
**Stack Scope:** RunPod Python GPU (`tools/zr-studio-gpu/`) · Cloudflare Worker Hono TS (`apps/vhunambi_api/`) · Flutter Riverpod Client (`apps/vhunambi_client/`)

---

## 1. RunPod GPU Worker Design (`tools/zr-studio-gpu/`)

### 1.1 Canonical 10-Pack African LoRA Registry & Truthful Loader (`tools/zr-studio-gpu/model_utils.py`)

Replace the 9-entry `GENRE_LORA_REGISTRY` and false-positive `_hot_swap_lora()` with a 10-pack registry synchronized 1:1 with `apps/vhunambi_api/src/modules/synthesis/lora_catalog.ts`, plus SHA-256 verification, authenticated R2 S3 fallback, and multi-LoRA fusion (up to 3 packs capped at `sum(weights) <= 1.35`):

```python
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
    "mbaqanga": {
        "lora_id": "maskandi_picking_v1",
        "r2_key": "loras/maskandi_picking_v1.safetensors",
        "default_weight": 0.80,
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
    capped = []
    for item in specs[:MAX_ACTIVE_LORAS]:
        w = max(0.10, min(1.20, float(item.get("weight", 0.85))))
        capped.append({**item, "weight": round(w, 4)})
    total = sum(x["weight"] for x in capped)
    if total > MAX_LORA_COMBINED_WEIGHT and total > 0:
        scale = MAX_LORA_COMBINED_WEIGHT / total
        for x in capped:
            x["weight"] = round(x["weight"] * scale, 4)
    return capped


def verify_safetensors_artifact(local_path: str) -> Optional[Dict[str, Any]]:
    """Verifies a local LoRA artifact exists, is >64 bytes, and computes its SHA-256."""
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
    """Reports cached .safetensors LoRA packs on /runpod-volume/lora_cache (or override)."""
    root = cache_dir or resolve_lora_cache_dir()
    found: List[Dict[str, Any]] = []
    if os.path.isdir(root):
        for fname in sorted(os.listdir(root)):
            if fname.lower().endswith(".safetensors"):
                meta = verify_safetensors_artifact(os.path.join(root, fname))
                if meta:
                    found.append({"filename": fname, **meta})
    return {
        "cache_dir": root,
        "count": len(found),
        "artifacts": found,
    }
```

#### Truthful `_hot_swap_loras` & Checkpoint Resolution (`ZRModelManager`)

- Checkpoint resolution order in `_try_load_ace_step_pipeline()`:
  1. `ACE_STEP_XL_BASE_DIR` (if set and exists)
  2. `ACE_STEP_CHECKPOINT_DIR` (if set and exists)
  3. `<HF_HOME>/ACE-Step-1.5-XL-Base` (if exists)
  4. `<HF_HOME>/ACE-Step-v1-3.5B` (backward-compatible legacy fallback)
- `_hot_swap_loras(self, lora_specs)` resets `self._active_lora_key = None`, `self._active_lora_weight = 0.0`, and `self._loaded_loras = []`. For each normalized spec:
  1. Look up `os.path.join(self.lora_cache_dir, os.path.basename(r2_key))`.
  2. If missing and `R2_ACCESS_KEY_ID` + `R2_SECRET_ACCESS_KEY` + `R2_ENDPOINT_URL` are set, try `boto3.client("s3").download_file(bucket, r2_key, local_path)`.
  3. Else if missing and `R2_PUBLIC_BASE_URL` is configured (no hardcoded secret/dev bucket when explicitly blanked in tests via `R2_PUBLIC_BASE_URL=""`), try `requests.get(f"{public_base}/{r2_key}", timeout=20)` and write ONLY if `resp.status_code == 200 and len(resp.content) > 64`.
  4. Verify via `verify_safetensors_artifact(local_path)`.
  5. If verified: if `self._pipeline is not None and hasattr(self._pipeline, "load_lora")`, call `load_lora(local_path, lora_weight=weight)` inside `try/except`; record `{lora_id, r2_key, weight, sha256, loaded: True}` in `self._loaded_loras`. Only if `self._loaded_loras` is non-empty are `self._active_lora_key` and `self._active_lora_weight` populated!

### 1.2 Raised-Cosine Crossfade Section Splice & `repaint_audio_section()` (`tools/zr-studio-gpu/model_utils.py`)

```python
def splice_repainted_section(
    source_stereo: np.ndarray,
    repainted_segment: np.ndarray,
    sr: int,
    start_sec: float,
    end_sec: float,
    crossfade_ms: float = 80.0,
) -> Tuple[np.ndarray, Dict[str, Any]]:
    """
    Splices repainted_segment (frames, channels) into source_stereo (frames, channels)
    over [start_sec, end_sec] with C1 raised-cosine boundary crossfades while leaving
    all samples outside [N0, N1) bit-identical to source_stereo.
    """
    src = np.asarray(source_stereo, dtype=np.float32).copy()
    if src.ndim == 1:
        src = np.repeat(src[:, None], 2, axis=1)
    elif src.shape[1] == 1:
        src = np.repeat(src, 2, axis=1)

    total_frames = src.shape[0]
    n0 = max(0, min(total_frames, int(round(start_sec * sr))))
    n1 = max(n0, min(total_frames, int(round(end_sec * sr))))
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
        "crossfade_ms": round((xfade / float(sr)) * 1000.0, 2),
    }
```

And `ZRModelManager.repaint_audio_section(self, source_wav_path, output_path, song_spec, start_sec, end_sec, task="repaint", target_stem="full", loras=None, seed=None)`:
- Normalizes & loads `loras` via `self._hot_swap_loras(...)`.
- Clamps `start_sec` / `end_sec` (`end_sec - start_sec >= 2.0`).
- On live GPU with `self._pipeline is not None`: passes `task="repaint"|"edit"|"extend"`, `src_audio_path=source_wav_path`, `repaint_start=start_sec`, `repaint_end=end_sec`, `retake_variance=0.75 if task == "repaint" else 0.90`.
- On CPU fallback: synthesizes a fresh seeded segment of duration `max(2, ceil(end_sec - start_sec))` and calls `splice_repainted_section(src_data, seg_data, sr, start_sec, end_sec)` so outside samples are 100% bit-preserved!

### 1.3 Canonical Stem-Lock Normalizer & Repaint Branch (`tools/zr-studio-gpu/handler.py` & `model_router.py`)

```python
STEM_LOCK_NODE_ALIASES: Dict[str, str] = {
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


def normalize_stem_locks(raw_locks: Optional[Dict[str, Any]]) -> Dict[str, str]:
    """Maps canonical roles and legacy 3D DNA node IDs onto {'vocals','drums','bass','melodic'}."""
    normalized: Dict[str, str] = {}
    if not isinstance(raw_locks, dict):
        return normalized
    for key, val in raw_locks.items():
        role = STEM_LOCK_NODE_ALIASES.get(str(key).strip().lower())
        mode = str(val or "").strip()
        if role and mode in ("lockedPure44k", "harmonicInpaint", "elasticResynth"):
            # Explicit canonical key takes precedence over legacy node_* alias
            if str(key).strip().lower() == role or role not in normalized:
                normalized[role] = mode
    return normalized
```

In `model_router.py`:
- `ZRMultiModelRouter.resolve_route(job_input, song_spec)`: if `job_input.get("job_type") == "section_repaint"` or `job_input.get("repaint_config")`: immediately return `RouteDecision("ace_step_xl_base", None, infer_steps, guidance_scale, "postgen_section_repaint")`.

In `handler.py`:
- When `job_input.get("job_type") == "section_repaint"` or `job_input.get("repaint_config")`:
  1. Download `source_audio_url` (or synthesize deterministic test source when `source_audio_url` is a local path in unit tests).
  2. Normalize `stem_locks = normalize_stem_locks(...)`.
  3. Run `ZRModelManager.get_instance().repaint_audio_section(...)` with `start_sec`, `end_sec`, `task`, `target_stem`, `loras`.
  4. If `stem_locks.get("vocals") == "lockedPure44k"` and `target_stem != "vocals"`, preserve source lead vocals cleanly via `separate_lead_vocal_bs_roformer`.
  5. Continue through Stage 2 (`htdemucs`), Stage 4 (`MMO 60Hz`), Stage 5 (`master_with_sa_reference_matchering`), and R2 upload, stamping `repaint_metadata` and `lora_metrics` onto both `manifest_payload` and `final_payload`!

---

## 2. Cloudflare Worker API Design (`apps/vhunambi_api/`)

### 2.1 Canonical African LoRA Pack Catalog (`apps/vhunambi_api/src/modules/synthesis/lora_catalog.ts` — NEW)

Single source of truth imported by `llm_handler.ts`, `runpod_adapter.ts`, `prompt_compiler.ts`, `studio_routes.ts`, and `generation_routes.ts`:

```typescript
export interface AfricanLoraPackDescriptor {
  loraId: string;
  label: string;
  genre: string;
  region: string;
  r2Key: string;
  defaultWeight: number;
  compatibleGenres: string[];
  description: string;
  tier: 'sovereign_custom';
}

export const AFRICAN_LORA_PACKS: readonly AfricanLoraPackDescriptor[] = [
  {
    loraId: 'amapiano_logdrum_v1',
    label: 'Amapiano Log Drum',
    genre: 'Amapiano',
    region: 'Gauteng / South Africa',
    r2Key: 'loras/amapiano_logdrum_v1.safetensors',
    defaultWeight: 0.85,
    compatibleGenres: ['amapiano'],
    description: 'Iconic resonant South African log-drum sub pocket & syncopated shakers.',
    tier: 'sovereign_custom',
  },
  {
    loraId: 'amapiano_private_school_v1',
    label: 'Private School Rhodes',
    genre: 'Private School Amapiano',
    region: 'Johannesburg / South Africa',
    r2Key: 'loras/amapiano_private_school_v1.safetensors',
    defaultWeight: 0.85,
    compatibleGenres: ['privateschoolamapiano', 'afrojazz', 'afrosoul', 'lofichill'],
    description: 'Lush Rhodes electric piano jazz voicings, warm sax fills & smooth log-drum glide.',
    tier: 'sovereign_custom',
  },
  {
    loraId: 'sgija_bacardi_v1',
    label: 'Sgija & Bacardi Bounce',
    genre: 'Sgija',
    region: 'Pretoria / Tshwane',
    r2Key: 'loras/sgija_bacardi_v1.safetensors',
    defaultWeight: 0.86,
    compatibleGenres: ['sgija', 'bacardi'],
    description: 'Staccato Pretoria Sgija log-drum stabs and high-energy Tshwane Bacardi brass.',
    tier: 'sovereign_custom',
  },
  {
    loraId: 'gqom_durban_v1',
    label: 'Durban Gqom Sub',
    genre: 'Gqom',
    region: 'KwaZulu-Natal / Durban',
    r2Key: 'loras/gqom_durban_v1.safetensors',
    defaultWeight: 0.88,
    compatibleGenres: ['gqom', 'kuduro', 'afrodrill'],
    description: 'Dark hypnotic broken-beat Durban club kicks & distorted sub drones.',
    tier: 'sovereign_custom',
  },
  {
    loraId: 'maskandi_picking_v1',
    label: 'Maskandi Acoustic Picking',
    genre: 'Maskandi',
    region: 'KwaZulu-Natal / South Africa',
    r2Key: 'loras/maskandi_picking_v1.safetensors',
    defaultWeight: 0.82,
    compatibleGenres: ['maskandi', 'mbaqanga', 'marabi', 'chimurenga'],
    description: 'Fast Zulu fingerpicked acoustic guitar izihlabo and bright concertina runs.',
    tier: 'sovereign_custom',
  },
  {
    loraId: 'venda_malende_v1',
    label: 'Venda Malende & Lekompo',
    genre: 'Malende',
    region: 'Limpopo / Venda',
    r2Key: 'loras/venda_malende_v1.safetensors',
    defaultWeight: 0.85,
    compatibleGenres: ['venda', 'malende', 'lekompo'],
    description: 'Polyrhythmic Tshivenḓa Malende drums, Limpopo Lekompo bounce & communal call-and-response.',
    tier: 'sovereign_custom',
  },
  {
    loraId: 'afrobeats_lagos_v1',
    label: 'Lagos Afrobeats Groove',
    genre: 'Afrobeats',
    region: 'West & Pan-Africa',
    r2Key: 'loras/afrobeats_lagos_v1.safetensors',
    defaultWeight: 0.80,
    compatibleGenres: ['afrobeats', 'afrofusion', 'highlife', 'rumba', 'soukous', 'bongoflava', 'gengetone', 'coupedecale'],
    description: 'Clean interlocking Afrobeats guitars, talking drums & crisp shekere rimshot pocket.',
    tier: 'sovereign_custom',
  },
  {
    loraId: 'kwaito_township_v1',
    label: 'Township Kwaito Tape',
    genre: 'Kwaito',
    region: 'Soweto / South Africa',
    r2Key: 'loras/kwaito_township_v1.safetensors',
    defaultWeight: 0.82,
    compatibleGenres: ['kwaito', 'bubblegum', 'hiphop', 'dancehall', 'reggae'],
    description: 'Warm 90s slowed house bass bounce and vintage Soweto street groove.',
    tier: 'sovereign_custom',
  },
  {
    loraId: 'afro_gospel_choir_v1',
    label: 'Afro-Gospel Mass Choir',
    genre: 'Gospel',
    region: 'Southern Africa',
    r2Key: 'loras/afro_gospel_choir_v1.safetensors',
    defaultWeight: 0.84,
    compatibleGenres: ['gospel', 'gospelsoul', 'isicathamiya', 'mbube'],
    description: 'Soaring Hammond organ swells, brass fanfares & lush 4-part South African choral harmonies.',
    tier: 'sovereign_custom',
  },
  {
    loraId: 'afrohouse_ancestral_v1',
    label: 'Ancestral Afro House',
    genre: 'Afro House',
    region: 'Southern & East Africa',
    r2Key: 'loras/afrohouse_ancestral_v1.safetensors',
    defaultWeight: 0.85,
    compatibleGenres: ['afrohouse', 'electronic', 'ethiojazz', 'kizomba'],
    description: 'Rolling tribal congas, progressive spiritual pads & deep four-on-the-floor pulse.',
    tier: 'sovereign_custom',
  },
];
```

Exports:
- `findLoraPackById(loraId: string): AfricanLoraPackDescriptor | undefined`
- `resolveRecommendedLoraForGenre(genre: string): AfricanLoraPackDescriptor`
- `normalizeRequestedLoraSpecs(genre: string, explicit?: Array<{ loraId?: string; lora_id?: string; path?: string; weight?: number }>): Array<{ loraId: string; path: string; weight: number }>` (caps max 3 items and caps combined weight $\le 1.35$).

### 2.2 New Routes & Types (`apps/vhunambi_api/`)

1. **`studio_routes.ts`:** Add `GET /v1/studio/loras`:
   - Optional `?genre=<label>` query parameter.
   - Returns `200 { success: true, totalCount: AFRICAN_LORA_PACKS.length, recommended: resolveRecommendedLoraForGenre(genre ?? 'Amapiano'), packs: AFRICAN_LORA_PACKS }`.
2. **`dna_types.ts` & `job_types.ts`:**
   - Add `RepaintHistoryEntry`: `{ repaintId: string; task: 'repaint' | 'lego' | 'complete'; startSec: number; endSec: number; targetStem: string; stemLocks?: Record<string, string>; activeLoras?: string[]; createdAtIso: string; }`.
   - Add `LoraRuntimeMetrics`: `{ requestedCount: number; loadedCount: number; loadedLoras: Array<{ loraId: string; r2Key: string; weight: number; sha256?: string; loaded: boolean }>; }`.
   - Attach optional `parentGenerationId`, `repaintHistory`, `repaintMetadata`, and `loraMetrics` to `GenerationJob` and `MasterMediaObjectManifest` (serialized inside existing `manifest_json` / `generation_spec_json` in `vhunambi_db.ts` & `edge_persistence_bridge.ts` — **zero SQL migrations required**!).
3. **`generation_routes.ts`:**
   - Add `loras` array schema to `SubmitGenerationSchema`.
   - Add `POST /v1/generations/:id/repaint`:
     - Validates `RepaintGenerationSchema` (`startSec`, `endSec` with `.refine((d) => d.endSec - d.startSec >= 2)`, `task`, `targetStem`, `stemLocks`, `editPrompt`, `editLyrics`, `loras`, `masteringMode`, `sampleRateHz`).
     - Hydrates parent job (`getJob(id)` or `vhunambiDb.syncGenerationJobFromCloud(id, c)`), allows `trk_*` / `seed_*` fallback or returns `404`.
     - Forces `engineTier: 'sovereign_custom'`, `resolvedEngine: 'ace_step_xl_base'`, `attributionTag: null`, normalizes `stemLocks` (canonical + legacy node keys), creates child job `gen_repaint_<ts>_<nanoid>` with `parentGenerationId: id`, dispatches `dispatchRepaintJob(...)` in `runpod_adapter.ts`, and returns `201`.
4. **`webhook_routes.ts` & `runpod_adapter.ts`:**
   - Parse `repaint_metadata` & `lora_metrics` from RunPod completion payloads/polling, store on child job, and when `childJob.parentGenerationId` exists, append a new `RepaintHistoryEntry` onto the parent job's `repaintHistory[]` and `manifest.repaintHistory[]`!

---

## 3. Flutter Client Design (`apps/vhunambi_client/`)

### 3.1 `TrackDetailEntity` & `TrackDetailNotifier` (`lib/features/track/`)

- **`track_detail_models.dart`:**
  - Add immutable `TrackTakeRecord` (`takeIndex`, `seed`, `engineUsed`, `audioUrl`, `score`, `attribution`) and `TrackRepaintEntry` (`repaintId`, `task`, `startSec`, `endSec`, `targetStem`, `createdAtIso`).
  - Add optional fields on `TrackDetailEntity`: `takes` (default `const []`), `repaintHistory` (default `const []`), `activeLoras` (default `const []`), `selectedTakeIndex` (`int`, default `0`).
- **`track_providers.dart`:**
  - In `loadManifestFromCloud(...)`: hydrate `repaintHistory` (`body['repaintHistory'] ?? body['repaint_history']`), `activeLoras` (`loraMetrics['loadedLoras']` or `body['activeLoras']`), and `takes` when present.
  - Add `selectTake(int index)` updating `selectedTakeIndex` & `audioUrl`.
  - Add `submitSectionRepaint({required double startSec, required double endSec, String task = 'repaint', String targetStem = 'full', Map<String, String>? stemLocks, String? editPrompt, String? editLyrics, List<Map<String, dynamic>>? loras, http.Client? client, String? apiBaseUrl})`:
    - Calls `POST $origin/v1/generations/$trackId/repaint` with `authHeadersProvider`.
    - Appends optimistic `TrackRepaintEntry` onto `state.repaintHistory` on `200`/`201` (or cleanly returns error message on failure), guarded by `if (!mounted) return ...`.

### 3.2 `TrackSectionRepaintSheet` & Refactored `CockpitQuantumEntanglementRack` (`STD-UIUX-001`)

- **Refactor `cockpit_quantum_entanglement_rack.dart`:**
  - Replace hardcoded `Color(0xFF0A1422)` / `Colors.white` / `Colors.black87` with `AppColors.surfaceElevatedOf(context)`, `AppColors.surfaceSecondaryOf(context)`, `AppColors.textPrimaryOf(context)`, `AppColors.textSecondaryOf(context)`, `AppColors.borderSubtleOf(context)`.
  - Enforce `ConstrainedBox(constraints: const BoxConstraints(minHeight: 44))` on `_buildMicroModeChip` (`Lock | Inpaint | Resynth`) while keeping all existing `Key('cockpit_domain_card_...')` & `Key('cockpit_stem_lock_...')` intact so `phase54_cockpit_biome_quantum_entanglement_test.dart` remains 100% green!
- **New `lib/features/track/presentation/widgets/track_section_repaint_sheet.dart`:**
  - Modal sheet (`VhunambiGlassSurface` + `AppColors.surfaceModalOf(context)`) launched from `TrackDetailView`'s new `"Section Repaint & Inpaint"` button (`Key('track_detail_open_repaint_btn')`, `minHeight: 48`).
  - Contains:
    1. `RangeSlider` (`Key('repaint_range_slider')`) clamped to `[0, max(10, track.duration.inSeconds)]` with `>= 2s` minimum span and live `"Bar X – Bar Y (16.0s – 32.0s)"` telemetry label.
    2. Task mode selector (`Repaint`, `Stem Lego`, `Extend`) with `minHeight: 44` glass pills.
    3. Refactored `CockpitQuantumEntanglementRack` (mounted live in post-gen Track Detail!).
    4. Sovereign African LoRA Pack selector (`Key('repaint_lora_picker')`, horizontal scrollable `ChoiceChip`/glass pills using `PhosphorIcon`, plus blend strength slider `0.10–1.20`).
    5. Optional section lyric / cue `TextField` (`Key('repaint_edit_lyrics_field')`).
    6. Submit CTA (`Key('repaint_submit_btn')`, `minHeight: 48`) dispatching `submitSectionRepaint(...)`.
- **`TrackSonicTelemetryCard`:**
  - Render `Key('track_repaint_history_chip')` (`PhosphorIconsRegular.magicWand`, `'Repainted · ${track.repaintHistory.length} ${track.repaintHistory.length == 1 ? 'edit' : 'edits'}'`) when `track.repaintHistory.isNotEmpty`.
  - Render `Key('track_lora_provenance_chip')` (`PhosphorIconsRegular.vinylRecord`, `'LoRA · ${track.activeLoras.first}'`) when `track.activeLoras.isNotEmpty`.
- **`TrackDetailView` + `OpenVerseRemixCockpitSheet` + `StudioFormState` Repairs:**
  - `TrackDetailView._handleRemix()` calls `studioFormProvider.notifier.applyPastTrackRemix(...)` with `track.id`, `track.title`, `track.genre`, `regionForGenre(track.genre)`, `track.language`, `referenceAudioPath: track.audioUrl`, `lyrics: track.lyrics`.
  - `StudioFormState` & `HttpGenerationSubmissionService` add optional `selectedLoraId` & `selectedLoraWeight` and serialize `'loras': [{'loraId': selectedLoraId, 'weight': selectedLoraWeight}]` on `POST /v1/generations`.
  - `OpenVerseRemixCockpitSheet` replaces `dummyVocal[i] = 0.45` with a gentle harmonic sine vocal guide envelope and wires `remix_open_sketchpad_btn` to switch to Studio (`appNavigationTabProvider = 2`) & pop cleanly.
  - `StemSeparationLab` line 86 replaces hardcoded `Color(0xFF3A2508)` with `AppColors.brandPrimary.withValues(alpha: 0.16)`.

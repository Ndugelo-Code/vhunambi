# Phase 85 Technical Design Specification — Cloud-Only Zero-Local-RAM LoRA Factory

> **Spec Suite ID:** `SPEC-P85-CLOUD-LORA-FACTORY`  
> **Companion Documents:** [`blueprint.md`](./blueprint.md) · [`requirements.md`](./requirements.md) · [`tasks.md`](./tasks.md) · [`memory.md`](./memory.md)

---

## §1. Mathematical & Signal-Processing Foundations

### 1.1 Low-Rank Adaptation (`PEFT` LoRA on ACE-Step 1.5 DiT)
For every attention projection linear layer $W_0 \in \mathbb{R}^{d_{\text{out}} \times d_{\text{in}}}$ selected on `ace_step_transformer`, PEFT attaches low-rank matrices $A \in \mathbb{R}^{r \times d_{\text{in}}}$ and $B \in \mathbb{R}^{d_{\text{out}} \times r}$ with scaling factor $s = \alpha / r$:

$$h = W_0 x + \frac{\alpha}{r} B A x$$

- **Target Modules Discovery:** Because ACE-Step checkpoints vary across `ACE-Step-v1-3.5B` and `ACE-Step-1.5-XL-Base`, `discover_dit_target_modules(dit)` inspects `named_modules()` for `nn.Linear` leaves matching candidate suffixes `("linear_q", "linear_k", "linear_v", "to_q", "to_k", "to_v", "q_proj", "k_proj", "v_proj", "o_proj", "out_proj")` (plus `"to_out.0"`), selecting the non-empty intersection and falling back to any attention `nn.Linear` layer if needed.
- **Rank/Alpha Presets:**
  - Complex South African rhythmic/vocal packs (`amapiano_logdrum_v1`, `amapiano_private_school_v1`, `maskandi_picking_v1`, `venda_malende_v1`, `afro_gospel_choir_v1`, `bantu_vocals_v1`): $r = 32, \alpha = 64$ ($s = 2.0$).
  - Groove packs (`afrobeats_lagos_v1`, `afrohouse_ancestral_v1`, `sgija_bacardi_v1`, `gqom_durban_v1`, `kwaito_township_v1`): $r = 16, \alpha = 32$ ($s = 2.0$).

### 1.2 Rectified Flow-Matching Velocity Objective
Given a clean encoded audio latent $x_1 \in \mathbb{R}^{B \times C \times F \times T}$, standard normal noise $x_0 \sim \mathcal{N}(0, I)$, and logit-normal timestep $t = \sigma(u), \; u \sim \mathcal{N}(0, 1)$ clamped to $[10^{-4}, 1 - 10^{-4}]$:

$$x_t = (1 - t) x_0 + t x_1, \qquad v^* = x_1 - x_0$$

$$\mathcal{L}_{\text{FM}}(\theta_{\text{LoRA}}) = \frac{1}{B} \sum_{i=1}^{B} w_i \cdot \operatorname{mean}\!\left( \left( \hat{v}_{\theta}(x_{t,i}, t_i, c_i) - v^*_i \right)^2 \right)$$

where $w_i \in [0.1, 3.0]$ is the track's `training_weight` from its validated JSON sidecar. Optimization uses `AdamW` ($\beta_1=0.9, \beta_2=0.999, \lambda=10^{-2}$), gradient clipping $\|\nabla \theta\|_2 \le 1.0$, linear warmup over $S_{\text{warm}}$ steps, and cosine decay:

$$\eta(s) = \begin{cases} \eta_0 \cdot \frac{s}{S_{\text{warm}}}, & s < S_{\text{warm}} \\ \eta_{\min} + \frac{1}{2}(\eta_0 - \eta_{\min})\left(1 + \cos\!\left(\pi \frac{s - S_{\text{warm}}}{\max(1, S_{\text{total}} - S_{\text{warm}})}\right)\right), & s \ge S_{\text{warm}} \end{cases}$$

### 1.3 Dual-Format `.safetensors` + Embedded PEFT Header Contract
Every trained adapter is saved with `safetensors.torch.save_file(lora_state_dict, out_path, metadata=meta_dict)` where `meta_dict` contains strictly UTF-8 strings:
- `vhunambi_lora_id`, `vhunambi_version`, `base_model`, `lora_rank`, `lora_alpha`, `lora_dropout`, `target_modules` (JSON array string), `training_tracks`, `final_loss`, `peft_adapter_config` (serialized `adapter_config.json`).
This guarantees that **a single file** (`loras/{lora_id}.safetensors`) downloaded by `model_utils.py:_hot_swap_loras()` carries 100% of the structural metadata needed to reconstruct a valid PEFT directory (`adapter_config.json` + `adapter_model.safetensors`) locally on RunPod if single-file `load_lora()` is unsupported by an upstream pipeline version.

---

## §2. Additive Supabase PostgreSQL Migration

**Target File:** `supabase/migrations/20261125000002_phase85_cloud_lora_factory.sql`

```sql
-- Phase 85: Cloud-Only Zero-Local-RAM LoRA Factory Schema
-- Strictly additive & idempotent (IF NOT EXISTS). Zero destructive changes.

CREATE TABLE IF NOT EXISTS public.lora_registry (
  lora_id TEXT PRIMARY KEY,
  display_name TEXT NOT NULL,
  pack_type TEXT NOT NULL DEFAULT 'genre' CHECK (pack_type IN ('genre', 'language', 'mixed')),
  genre TEXT NOT NULL,
  region TEXT NOT NULL DEFAULT 'South Africa',
  r2_key TEXT NOT NULL,
  adapter_config_r2_key TEXT,
  default_weight REAL NOT NULL DEFAULT 0.85,
  lora_rank INTEGER NOT NULL DEFAULT 16,
  lora_alpha INTEGER NOT NULL DEFAULT 32,
  min_tracks INTEGER NOT NULL DEFAULT 8,
  recommended_tracks INTEGER NOT NULL DEFAULT 15,
  status TEXT NOT NULL DEFAULT 'untrained' CHECK (
    status IN ('untrained', 'preparing', 'ready_to_train', 'queued', 'training', 'validating', 'active', 'failed', 'deprecated')
  ),
  artifact_sha256 TEXT,
  artifact_bytes BIGINT NOT NULL DEFAULT 0,
  training_tracks INTEGER NOT NULL DEFAULT 0,
  version TEXT NOT NULL DEFAULT 'v1',
  final_loss REAL,
  trained_at TIMESTAMPTZ,
  metadata_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.lora_dataset_tracks (
  id TEXT PRIMARY KEY,
  lora_id TEXT NOT NULL REFERENCES public.lora_registry(lora_id) ON DELETE CASCADE,
  source_track_id TEXT,
  source_r2_key TEXT NOT NULL,
  source_sha256 TEXT NOT NULL,
  curated_wav_r2_key TEXT,
  curated_json_r2_key TEXT,
  title TEXT NOT NULL,
  vocal_isolated BOOLEAN NOT NULL DEFAULT FALSE,
  duration_sec REAL,
  sample_rate INTEGER,
  bit_depth INTEGER,
  bpm INTEGER,
  musical_key TEXT,
  language TEXT NOT NULL DEFAULT 'en-ZA',
  license TEXT NOT NULL DEFAULT 'owned',
  training_weight REAL NOT NULL DEFAULT 1.0,
  validation_status TEXT NOT NULL DEFAULT 'pending' CHECK (
    validation_status IN ('pending', 'valid', 'invalid', 'excluded')
  ),
  validation_errors_json JSONB NOT NULL DEFAULT '[]'::jsonb,
  metadata_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (lora_id, source_sha256)
);

CREATE TABLE IF NOT EXISTS public.lora_training_jobs (
  id TEXT PRIMARY KEY,
  lora_id TEXT NOT NULL REFERENCES public.lora_registry(lora_id) ON DELETE CASCADE,
  job_type TEXT NOT NULL CHECK (job_type IN ('dataset_prep', 'peft_train')),
  runpod_job_id TEXT,
  execution_target TEXT NOT NULL DEFAULT 'serverless' CHECK (execution_target IN ('serverless', 'pod')),
  status TEXT NOT NULL DEFAULT 'queued' CHECK (
    status IN ('queued', 'downloading', 'preparing', 'training', 'validating', 'uploading', 'dataset_ready', 'completed', 'failed')
  ),
  progress_pct INTEGER NOT NULL DEFAULT 0,
  current_epoch INTEGER NOT NULL DEFAULT 0,
  total_epochs INTEGER NOT NULL DEFAULT 0,
  current_loss REAL,
  best_loss REAL,
  hyperparams_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  metrics_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  artifact_r2_key TEXT,
  artifact_sha256 TEXT,
  error_message TEXT,
  triggered_by TEXT NOT NULL DEFAULT 'system',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_lora_dataset_tracks_lora_status
  ON public.lora_dataset_tracks (lora_id, validation_status);

CREATE INDEX IF NOT EXISTS idx_lora_training_jobs_lora_created
  ON public.lora_training_jobs (lora_id, created_at DESC);

ALTER TABLE public.lora_registry ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lora_dataset_tracks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lora_training_jobs ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'lora_registry' AND policyname = 'lora_registry_read_all'
  ) THEN
    CREATE POLICY lora_registry_read_all ON public.lora_registry FOR SELECT USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'lora_dataset_tracks' AND policyname = 'lora_dataset_tracks_read_auth'
  ) THEN
    CREATE POLICY lora_dataset_tracks_read_auth ON public.lora_dataset_tracks FOR SELECT TO authenticated USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'lora_training_jobs' AND policyname = 'lora_training_jobs_read_auth'
  ) THEN
    CREATE POLICY lora_training_jobs_read_auth ON public.lora_training_jobs FOR SELECT TO authenticated USING (true);
  END IF;
END
$$;

-- Seed all 11 canonical Vhunambi packs idempotently (10 genre + 1 language specialist)
INSERT INTO public.lora_registry (
  lora_id, display_name, pack_type, genre, region, r2_key, adapter_config_r2_key,
  default_weight, lora_rank, lora_alpha, min_tracks, recommended_tracks, status
) VALUES
  ('amapiano_logdrum_v1', 'Amapiano Log Drum', 'genre', 'Amapiano', 'Gauteng / South Africa', 'loras/amapiano_logdrum_v1.safetensors', 'loras/amapiano_logdrum_v1/adapter_config.json', 0.85, 32, 64, 8, 15, 'untrained'),
  ('amapiano_private_school_v1', 'Private School Rhodes', 'genre', 'Private School Amapiano', 'Johannesburg / South Africa', 'loras/amapiano_private_school_v1.safetensors', 'loras/amapiano_private_school_v1/adapter_config.json', 0.85, 32, 64, 8, 15, 'untrained'),
  ('sgija_bacardi_v1', 'Sgija & Bacardi Bounce', 'genre', 'Sgija', 'Pretoria / Tshwane', 'loras/sgija_bacardi_v1.safetensors', 'loras/sgija_bacardi_v1/adapter_config.json', 0.86, 16, 32, 8, 15, 'untrained'),
  ('gqom_durban_v1', 'Durban Gqom Sub', 'genre', 'Gqom', 'KwaZulu-Natal / Durban', 'loras/gqom_durban_v1.safetensors', 'loras/gqom_durban_v1/adapter_config.json', 0.88, 16, 32, 8, 15, 'untrained'),
  ('maskandi_picking_v1', 'Maskandi Acoustic Picking', 'genre', 'Maskandi', 'KwaZulu-Natal / South Africa', 'loras/maskandi_picking_v1.safetensors', 'loras/maskandi_picking_v1/adapter_config.json', 0.82, 32, 64, 8, 15, 'untrained'),
  ('venda_malende_v1', 'Venda Malende & Lekompo', 'genre', 'Malende', 'Limpopo / Venda', 'loras/venda_malende_v1.safetensors', 'loras/venda_malende_v1/adapter_config.json', 0.85, 32, 64, 8, 15, 'untrained'),
  ('afrobeats_lagos_v1', 'Lagos Afrobeats Groove', 'genre', 'Afrobeats', 'West & Pan-Africa', 'loras/afrobeats_lagos_v1.safetensors', 'loras/afrobeats_lagos_v1/adapter_config.json', 0.80, 16, 32, 8, 15, 'untrained'),
  ('kwaito_township_v1', 'Township Kwaito Tape', 'genre', 'Kwaito', 'Soweto / South Africa', 'loras/kwaito_township_v1.safetensors', 'loras/kwaito_township_v1/adapter_config.json', 0.82, 16, 32, 8, 15, 'untrained'),
  ('afro_gospel_choir_v1', 'Afro-Gospel Mass Choir', 'genre', 'Gospel', 'Southern Africa', 'loras/afro_gospel_choir_v1.safetensors', 'loras/afro_gospel_choir_v1/adapter_config.json', 0.84, 32, 64, 8, 15, 'untrained'),
  ('afrohouse_ancestral_v1', 'Ancestral Afro House', 'genre', 'Afro House', 'Southern & East Africa', 'loras/afrohouse_ancestral_v1.safetensors', 'loras/afrohouse_ancestral_v1/adapter_config.json', 0.85, 16, 32, 8, 15, 'untrained'),
  ('bantu_vocals_v1', 'Bantu Vocals & Phonetics', 'language', 'Bantu Vocals', '11 South African Languages', 'loras/bantu_vocals_v1.safetensors', 'loras/bantu_vocals_v1/adapter_config.json', 0.88, 32, 64, 8, 15, 'untrained')
ON CONFLICT (lora_id) DO NOTHING;
```

---

## §3. Cloudflare Worker Edge Orchestration (`apps/vhunambi_api/`)

### 3.1 Pure Edge Dataset Schema (`apps/vhunambi_api/src/modules/synthesis/training_dataset_schema.ts` — NEW)

```ts
import { z } from 'zod';

export const VhunambiLoraIdSchema = z.enum([
  'amapiano_logdrum_v1',
  'amapiano_private_school_v1',
  'sgija_bacardi_v1',
  'gqom_durban_v1',
  'maskandi_picking_v1',
  'venda_malende_v1',
  'afrobeats_lagos_v1',
  'kwaito_township_v1',
  'afro_gospel_choir_v1',
  'afrohouse_ancestral_v1',
  'bantu_vocals_v1',
]);

export type VhunambiLoraId = z.infer<typeof VhunambiLoraIdSchema>;

export const TrainingGenreSchema = z.enum([
  'amapiano',
  'private_school_amapiano',
  'sgija',
  'gqom',
  'maskandi',
  'venda_malende',
  'afrobeats',
  'kwaito',
  'gospel',
  'afro_house',
  'bantu_vocals',
]);

export type TrainingGenre = z.infer<typeof TrainingGenreSchema>;

export const BantuLanguageSchema = z.enum([
  'zu-ZA',
  'xh-ZA',
  'nso-ZA',
  've-ZA',
  'tn-ZA',
  'st-ZA',
  'ts-ZA',
  'ss-ZA',
  'nr-ZA',
  'af-ZA',
  'en-ZA',
  'mixed',
]);

export type BantuLanguage = z.infer<typeof BantuLanguageSchema>;

export const AudioSpecSchema = z.object({
  duration_sec: z.number().min(30).max(300),
  sample_rate: z.union([z.literal(44100), z.literal(48000)]),
  bit_depth: z.union([z.literal(16), z.literal(24)]),
  channels: z.union([z.literal(1), z.literal(2)]).default(2),
});

export const MusicalKeySchema = z.object({
  tonic: z.enum([
    'C', 'C#', 'Db', 'D', 'D#', 'Eb', 'E', 'F',
    'F#', 'Gb', 'G', 'G#', 'Ab', 'A', 'A#', 'Bb', 'B',
  ]),
  mode: z.enum(['major', 'minor', 'dorian', 'mixolydian', 'unknown']),
});

export const TrainingTrackMetadataSchema = z.object({
  title: z.string().min(1).max(160),
  lora_id: VhunambiLoraIdSchema,
  genre: TrainingGenreSchema,
  sub_genre: z.string().min(1).max(64).optional(),
  bpm: z.number().int().min(60).max(200),
  key: MusicalKeySchema.optional(),
  time_signature: z.enum(['4/4', '3/4', '6/8', '12/8']).default('4/4'),
  language: BantuLanguageSchema.default('en-ZA'),
  lyrics: z.string().max(12000).default(''),
  instrumental: z.boolean().default(false),
  instrumentation: z.array(z.string().min(1).max(48)).min(1).max(30),
  avoid_instrumentation: z.array(z.string().min(1).max(48)).max(10).default([]),
  mood: z.array(z.string().min(1).max(32)).max(10).default([]),
  energy: z.enum(['low', 'medium', 'high']).default('medium'),
  cultural_notes: z.string().max(1000).default(''),
  audio: AudioSpecSchema.optional(),
  license: z.enum(['royalty_free', 'cc0', 'cc_by', 'owned', 'licensed']).default('owned'),
  attribution: z.string().max(300).optional(),
  training_weight: z.number().min(0.1).max(3.0).default(1.0),
  exclude_from_training: z.boolean().default(false),
  source_r2_key: z.string().max(512).optional(),
  source_sha256: z.string().max(128).optional(),
});

export type TrainingTrackMetadata = z.infer<typeof TrainingTrackMetadataSchema>;

export const LoraRegistryStatusSchema = z.enum([
  'untrained',
  'preparing',
  'ready_to_train',
  'queued',
  'training',
  'validating',
  'active',
  'failed',
  'deprecated',
]);

export type LoraRegistryStatus = z.infer<typeof LoraRegistryStatusSchema>;

export interface LoraHyperparamDefaults {
  loraRank: number;
  loraAlpha: number;
  epochs: number;
  batchSize: number;
  gradAccumSteps: number;
  learningRate: number;
  warmupSteps: number;
  minTracks: number;
  recommendedTracks: number;
  extractVocals: boolean;
  defaultInstrumentation: string[];
}

export function getTrainingHyperparamDefaults(loraId: VhunambiLoraId): LoraHyperparamDefaults {
  switch (loraId) {
    case 'bantu_vocals_v1':
      return {
        loraRank: 32,
        loraAlpha: 64,
        epochs: 20,
        batchSize: 1,
        gradAccumSteps: 4,
        learningRate: 5e-5,
        warmupSteps: 120,
        minTracks: 8,
        recommendedTracks: 15,
        extractVocals: true,
        defaultInstrumentation: ['lead_vocals', 'backing_harmonies', 'bantu_phonetics'],
      };
    case 'amapiano_logdrum_v1':
    case 'amapiano_private_school_v1':
      return {
        loraRank: 32,
        loraAlpha: 64,
        epochs: 12,
        batchSize: 2,
        gradAccumSteps: 2,
        learningRate: 1.5e-4,
        warmupSteps: 50,
        minTracks: 8,
        recommendedTracks: 15,
        extractVocals: false,
        defaultInstrumentation: ['log_drum', 'shaker', 'rhodes_piano', 'sub_bass'],
      };
    case 'maskandi_picking_v1':
    case 'venda_malende_v1':
    case 'afro_gospel_choir_v1':
      return {
        loraRank: 32,
        loraAlpha: 64,
        epochs: 14,
        batchSize: 1,
        gradAccumSteps: 4,
        learningRate: 1e-4,
        warmupSteps: 60,
        minTracks: 8,
        recommendedTracks: 15,
        extractVocals: false,
        defaultInstrumentation: ['acoustic_guitar', 'traditional_percussion', 'vocal_choir'],
      };
    default:
      return {
        loraRank: 16,
        loraAlpha: 32,
        epochs: 10,
        batchSize: 2,
        gradAccumSteps: 2,
        learningRate: 1.2e-4,
        warmupSteps: 40,
        minTracks: 8,
        recommendedTracks: 15,
        extractVocals: false,
        defaultInstrumentation: ['drums', 'bass', 'percussion', 'synth'],
      };
  }
}

export interface SourceTrackCandidate {
  id: string;
  title: string;
  genre: string;
  subGenre?: string;
  audioUrl: string;
  contentSha256?: string;
  bpm?: number;
  lyricsText?: string;
  sourceOrigin?: string;
}

export function extractR2KeyFromAudioUrl(audioUrl: string): string | null {
  const trimmed = (audioUrl || '').trim();
  if (!trimmed) return null;
  if (trimmed.startsWith('/r2/')) return trimmed.slice(4).replace(/^\/+/, '');
  const idx = trimmed.indexOf('/r2/');
  if (idx !== -1) return trimmed.slice(idx + 4).replace(/^\/+/, '');
  if (/^(media|training-data|audio|stems)\//i.test(trimmed)) return trimmed;
  return null;
}

export function selectSourceTracksForLoraPack(
  loraId: VhunambiLoraId,
  tracks: SourceTrackCandidate[],
): SourceTrackCandidate[] {
  const seen = new Set<string>();
  const matches: SourceTrackCandidate[] = [];

  for (const t of tracks) {
    const r2Key = extractR2KeyFromAudioUrl(t.audioUrl);
    if (!r2Key) continue;
    const dedupeKey = (t.contentSha256 || r2Key).toLowerCase();
    if (seen.has(dedupeKey)) continue;

    const g = (t.genre || '').toLowerCase();
    const sg = (t.subGenre || '').toLowerCase();
    const hasLyrics = (t.lyricsText || '').trim().length >= 24;

    let ok = false;
    switch (loraId) {
      case 'amapiano_logdrum_v1':
        ok = g.includes('amapiano') || sg.includes('amapiano');
        break;
      case 'amapiano_private_school_v1':
        ok = g.includes('amapiano') || g.includes('jazz') || sg.includes('private school');
        break;
      case 'afrobeats_lagos_v1':
        ok = g.includes('afrobeats') || g.includes('afro fusion') || sg.includes('afro');
        break;
      case 'afrohouse_ancestral_v1':
        ok = g.includes('afro house') || g.includes('house');
        break;
      case 'bantu_vocals_v1':
        ok = hasLyrics;
        break;
      case 'venda_malende_v1':
        ok = g.includes('venda') || g.includes('malende') || g.includes('lekompo') || sg.includes('venda');
        break;
      case 'sgija_bacardi_v1':
        ok = g.includes('sgija') || g.includes('bacardi') || sg.includes('sgija') || sg.includes('bacardi');
        break;
      case 'gqom_durban_v1':
        ok = g.includes('gqom') || sg.includes('gqom');
        break;
      case 'maskandi_picking_v1':
        ok = g.includes('maskandi') || g.includes('mbaqanga');
        break;
      case 'kwaito_township_v1':
        ok = g.includes('kwaito') || g.includes('hip hop');
        break;
      case 'afro_gospel_choir_v1':
        ok = g.includes('gospel') || g.includes('isicathamiya') || g.includes('mbube');
        break;
    }

    if (ok) {
      seen.add(dedupeKey);
      matches.push(t);
    }
  }
  return matches;
}
```

### 3.2 Backward-Compatible `lora_catalog.ts` Extension (`apps/vhunambi_api/src/modules/synthesis/lora_catalog.ts`)
- Keep `AFRICAN_LORA_PACKS` at its exact `10` genre packs (zero regression on `phase83_repaint_lora_routes.test.ts:26-28`).
- Add `packType?: 'genre' | 'language'` on `AfricanLoraPackDescriptor` and export:
  ```ts
  export const LANGUAGE_LORA_PACKS: readonly AfricanLoraPackDescriptor[] = [
    {
      loraId: 'bantu_vocals_v1',
      label: 'Bantu Vocals & Phonetics',
      genre: 'Bantu Vocals',
      region: '11 South African Languages',
      r2Key: 'loras/bantu_vocals_v1.safetensors',
      defaultWeight: 0.88,
      compatibleGenres: ['bantuvocals', 'venda', 'zulu', 'xhosa', 'sepedi', 'sesotho'],
      description: 'BS-RoFormer vocal-isolated South African Bantu tonal phrasing & diacritic clarity.',
      tier: 'sovereign_custom',
      packType: 'language',
    },
  ];
  export const ALL_SOVEREIGN_LORA_PACKS: readonly AfricanLoraPackDescriptor[] = [
    ...AFRICAN_LORA_PACKS,
    ...LANGUAGE_LORA_PACKS,
  ];
  ```
- Update `findLoraPackById()` to search `ALL_SOVEREIGN_LORA_PACKS`.

### 3.3 Dual-Engine Persistence (`edge_persistence_bridge.ts` & `vhunambi_db.ts`)
Add symmetric interfaces and awaited write-through methods across both `EdgeIsolateDatabaseEngine` and `VhunambiDatabase` (SQLite tables created in `ensureTables()` for local tests; Supabase PostgREST read/write-through on Worker):
- `LoraRegistryRecord`, `LoraDatasetTrackRecord`, `LoraTrainingJobRecord`
- `listLoraRegistryAsync(c?)`, `getLoraRegistryEntry(loraId)`, `upsertLoraRegistryAsync(entry, c?)`
- `listLoraDatasetTracksAsync(loraId, c?)`, `upsertLoraDatasetTracksAsync(tracks, c?)`
- `listLoraTrainingJobsAsync(loraId?, c?)`, `getLoraTrainingJobAsync(jobId, c?)`, `upsertLoraTrainingJobAsync(job, c?)`

### 3.4 RunPod Training Dispatch (`apps/vhunambi_api/src/modules/synthesis/runpod_adapter.ts`)
Add two dedicated dispatch functions reusing `resolveRuntimeEnv(c)` and `WEBHOOK_BASE_URL` -> `${base}/v1/webhooks/training`:
- `dispatchLoraDatasetPrepJob(params: { jobId, loraId, sourceTracks, extractVocals, forceReprep }, cOrEnv?)` -> POSTs `{ input: { job_type: 'lora_dataset_prep', job_id, lora_id, source_tracks, extract_vocals, force_reprep, webhook_url } }` to `https://api.runpod.ai/v2/${RUNPOD_ENDPOINT_ID}/run` (or returns `{ runpodJobId: 'sim_prep_...', isSimulated: true }` when `RUNPOD_API_KEY` is absent in unit tests).
- `dispatchLoraPeftTrainingJob(params: { jobId, loraId, config, executionTarget }, cOrEnv?)` -> POSTs `{ input: { job_type: 'lora_train_peft', job_id, lora_id, training_config: config, webhook_url } }` when `executionTarget === 'serverless'`, or returns a zero-secret RunPod Pod command template when `executionTarget === 'pod'`.

### 3.5 Orchestration Routes (`apps/vhunambi_api/src/routes/studio_routes.ts` & `webhook_routes.ts`)
1. **`GET /v1/studio/loras`**:
   - Keeps `{ success: true, totalCount: AFRICAN_LORA_PACKS.length (10), genre, recommended, packs }` intact.
   - Hydrates each pack with live `registryStatus`, `trainingTracks`, `readyTrackCount`, `minTracks`, `artifactSha256`, `trainedAt` from `lora_registry` + `explore_tracks`.
   - Adds additive `languagePacks` (`LANGUAGE_LORA_PACKS` enriched identically).
2. **`GET /v1/studio/loras/factory`**:
   - Returns `{ success: true, totalPacks: 11, readyPackCount, activePackCount, totalSourceTracks, packs: [...11 packs with sourceTrackCount, validCuratedCount, latestJob], recentJobs }`.
3. **`POST /v1/studio/loras/datasets/prep`** (protected by `sovereignAuthMiddleware`):
   - Validates `{ loraId, sourceTrackIds?, extractVocals?, forceReprep?, allowPartialPrep? }`.
   - Auto-selects matching tracks via `selectSourceTracksForLoraPack()` if `sourceTrackIds` omitted.
   - Rejects `< 8` tracks with `400 INSUFFICIENT_SOURCE_TRACKS` unless `allowPartialPrep === true`.
   - Creates `lora_training_jobs` row (`jobType: 'dataset_prep'`), updates `lora_registry.status = 'preparing'`, dispatches RunPod job, returns `202`.
4. **`POST /v1/studio/loras/train`** (protected by `sovereignAuthMiddleware`):
   - Validates `{ loraId, epochs?, learningRate?, loraRank?, loraAlpha?, batchSize?, executionTarget? }`.
   - Checks `validCuratedCount >= minTracks (8)` in `lora_dataset_tracks` (unless `overrideCuratedCheck` is explicitly passed for curated R2 folders already verified); otherwise returns `400 DATASET_NOT_READY`.
   - Creates `lora_training_jobs` row (`jobType: 'peft_train'`), updates `lora_registry.status = 'queued'`, dispatches RunPod job, returns `202`.
5. **`GET /v1/studio/loras/jobs` & `GET /v1/studio/loras/jobs/:jobId`**: Returns recent jobs or a single job record (`404` if missing).
6. **`POST /v1/webhooks/training`** in `apps/vhunambi_api/src/routes/webhook_routes.ts`:
   - Constant-time HMAC-SHA256 verification against `x-zrs-signature` + `ZR_WEBHOOK_SECRET` (identical to `/v1/webhooks/ace-step`; returns `401` on mismatch).
   - Handles:
     - `status === 'dataset_ready'`: upserts `tracks[]` into `lora_dataset_tracks`, sets `lora_training_jobs.status = 'dataset_ready'`, and sets `lora_registry.status = valid_tracks >= min_tracks ? 'ready_to_train' : 'untrained'`.
     - `status === 'training' | 'downloading' | 'validating' | 'uploading'`: updates `lora_training_jobs` (`progressPct`, `currentEpoch`, `totalEpochs`, `currentLoss`, `bestLoss`) and `lora_registry.status`.
     - `status === 'completed'`: verifies `artifact_bytes > 64` and `/^[a-f0-9]{64}$/i.test(artifact_sha256)` (rejecting mock/corrupt callbacks with `422 INVALID_ARTIFACT_PROOF`), updates `lora_registry` (`status = 'active'`, `artifactSha256`, `artifactBytes`, `trainingTracks`, `finalLoss`, `trainedAt`), and completes `lora_training_jobs`.
     - `status === 'failed'`: records `errorMessage` and updates `lora_registry.status = 'failed'` (only if pack was not already `active`, preserving previously active production LoRAs on a failed retrain!).

---

## §4. Cloud-Only Python Dataset Prepper, Validator & Real PEFT Trainer (`tools/zr-studio-training/`)

### 4.1 Pure Python Dataset Validator (`tools/zr-studio-training/validate_dataset.py`)
Ported cleanly from Donor `validate_dataset.py` with zero raw Unicode emojis and aligned to Vhunambi's 11 packs:
- Constants: `MIN_TRACKS = 8`, `RECOMMENDED_TRACKS = 15`, `VALID_SAMPLE_RATES = (44100, 48000)`, `VALID_BIT_DEPTHS = (16, 24)`, `VALID_CHANNELS = (1, 2)`, `MIN_DURATION_SEC = 30.0`, `MAX_DURATION_SEC = 300.0`.
- `VALID_LORA_IDS` = all 11 canonical Vhunambi pack IDs.
- Exports `validate_audio(wav_path: Path)`, `validate_metadata(json_path: Path)`, `validate_dataset(dataset_dir: Path, json_only: bool = False) -> DatasetResult`, and `DatasetResult.to_dict()`.

### 4.2 Cloud RunPod Dataset Prepper (`tools/zr-studio-training/dataset_prep_worker.py`)
Key functions (zero local RAM on user laptop; streams sequentially on RunPod with `gc.collect()`):
```python
def detect_musical_key_from_audio(mono: np.ndarray, sr: int) -> dict[str, str]:
    """Krumhansl-Schmuckler chroma correlation over 12 major + 12 minor profiles."""

def transcode_to_training_wav(input_path: str, output_wav_path: str, target_sr: int = 44100, max_sec: float = 295.0) -> dict[str, Any]:
    """Converts MP3/M4A/FLAC/WAV into 44.1kHz 24-bit stereo PCM_24 WAV via ffmpeg/soundfile."""

def run_cloud_dataset_prep(job_input: dict[str, Any], webhook_fn: Callable[[str, dict[str, Any]], None] | None = None) -> dict[str, Any]:
    """
    1. Downloads source_tracks from R2 zr-studio-audio (or local file paths in tests).
    2. Transcodes each track to 44.1kHz 24-bit stereo WAV.
    3. If extract_vocals=True (e.g. bantu_vocals_v1), invokes separate_lead_vocal_bs_roformer().
    4. Computes measured BPM (librosa.beat.beat_track with track BPM fallback), musical key, and RMS energy.
    5. Writes NFC-normalized track_XX.json sidecars and validates entire folder via validate_dataset().
    6. Uploads valid curated pairs + _manifest.json to R2 training-data/curated/{lora_id}/.
    7. Sends signed webhook {job_id, lora_id, job_type='dataset_prep', status='dataset_ready', valid_tracks, tracks:[...]}.
    """
```

### 4.3 Real ACE-Step 1.5 `bf16` PEFT LoRA Trainer (`tools/zr-studio-training/train_lora.py`)
Zero mocks (`b"MOCK_SAFETENSORS_DATA"` is permanently eliminated). Full architecture:
```python
CANDIDATE_DIT_TARGET_MODULES = (
    "linear_q", "linear_k", "linear_v",
    "to_q", "to_k", "to_v", "to_out.0",
    "q_proj", "k_proj", "v_proj", "o_proj", "out_proj",
)

def discover_dit_target_modules(dit_model: "torch.nn.Module") -> list[str]:
    """Inspects dit_model.named_modules() and returns matching nn.Linear suffix names."""

def build_peft_lora_model(dit_model: "torch.nn.Module", lora_rank: int, lora_alpha: int, lora_dropout: float = 0.05) -> tuple[Any, list[str]]:
    """Attaches real peft.LoraConfig via peft.get_peft_model(); freezes base weights cleanly."""

def extract_and_save_verified_safetensors(
    peft_model: Any,
    output_safetensors_path: Path,
    adapter_config_path: Path,
    lora_id: str,
    lora_rank: int,
    lora_alpha: int,
    target_modules: list[str],
    training_tracks: int,
    final_loss: float,
    base_model: str = "ACE-Step-1.5-XL-Base",
) -> dict[str, Any]:
    """
    1. Collects all trainable LoRA tensors (lora_A / lora_B) via peft.get_peft_model_state_dict().
    2. Asserts non-empty dict and every tensor passes torch.isfinite(t).all().
    3. Builds PEFT adapter_config dict and embeds it in safetensors __metadata__ AND writes adapter_config.json.
    4. Serializes via safetensors.torch.save_file(..., metadata=meta).
    5. Verifies size > 64 bytes and computes SHA-256 hex digest.
    """

def run_flow_matching_training_loop(
    peft_dit: Any,
    latent_samples: list[dict[str, Any]],
    epochs: int,
    batch_size: int,
    grad_accum_steps: int,
    learning_rate: float,
    warmup_steps: int,
    precision: str = "bf16",
    on_epoch_end: Callable[[int, int, float, float], None] | None = None,
) -> dict[str, Any]:
    """
    Real PyTorch rectified flow-matching velocity optimization loop:
    - Logit-normal timestep sampling t = sigmoid(randn) clamped to [1e-4, 1-1e-4]
    - x_t = (1 - t) * x_0 + t * x_1, target velocity v* = x_1 - x_0
    - Per-track weighted MSE loss, bf16 autocast on CUDA, gradient accumulation,
      clip_grad_norm_(1.0), AdamW + warmup/cosine LR schedule, finite-loss assertion.
    - Returns {initial_loss, final_loss, best_loss, total_steps, epoch_history}.
    """
```
- **VAE Latent Caching:** Before Epoch 1, loads `ACEStepPipeline` via `ZRModelManager.get_instance()`, pre-encodes each curated WAV (cropped to `<= 60s` random/energy-peak window) through `music_dcae.encode()` and caption/lyrics through `text_encoder_model` (with `_install_latin_language_guard()` active) inside `torch.no_grad()`, moves `music_dcae` & `text_encoder_model` off GPU (`cpu()` + `torch.cuda.empty_cache()`), and runs the DiT PEFT training loop cleanly within `18–26 GB` VRAM.
- **Dual Invocation Modes:**
  1. **RunPod Serverless (`handler.py`):** Invoked via `run_cloud_peft_training(job_input, webhook_fn=...)` when `job_type == "lora_train_peft"`.
  2. **Standalone RunPod Pod CLI (`python -m training.train_lora --lora-id amapiano_logdrum_v1 --config training/configs/amapiano_logdrum_v1.yaml --resume-from-r2`):** Supports multi-hour training with epoch checkpoints uploaded to `training-checkpoints/{lora_id}/`.

### 4.4 YAML Hyperparameter Presets (`tools/zr-studio-training/configs/*.yaml`)
Ship 5 concrete day-1 YAML presets (`amapiano_logdrum_v1.yaml`, `amapiano_private_school_v1.yaml`, `afrobeats_lagos_v1.yaml`, `afrohouse_ancestral_v1.yaml`, `bantu_vocals_v1.yaml`) plus `default_genre_template.yaml`.

### 4.5 Dual-Path Loader & Handler Dispatch (`tools/zr-studio-gpu/`)
1. **`tools/zr-studio-gpu/model_utils.py`:**
   - Add `"bantu vocals"` and `"bantu_vocals"` entries to `GENRE_LORA_REGISTRY` mapping to `loras/bantu_vocals_v1.safetensors` (`default_weight: 0.88`).
   - Add helper `materialize_peft_dir_from_safetensors(safetensors_path: str, out_dir: str) -> Optional[str]` that reads the JSON metadata header from the `.safetensors` file (pure Python `struct.unpack('<Q', ...)` — zero heavy memory copy!), writes `adapter_config.json` and copies/symlinks `adapter_model.safetensors` into `out_dir`.
   - Upgrade `_hot_swap_loras()` so if `self._pipeline.load_lora(local_path, lora_weight=weight)` fails, it calls `materialize_peft_dir_from_safetensors()` and tries `self._pipeline.load_lora(peft_dir, lora_weight=weight)` or `ace_step_transformer.load_lora_adapter(peft_dir)` before marking `loaded: False`.
2. **`tools/zr-studio-gpu/handler.py`:**
   - At the top of `runpod_handler(job)` (before `ZRMultiModelRouter.resolve_route()`), inspect `job_type = str(job_input.get("job_type") or "").strip().lower()`:
     - If `job_type == "lora_dataset_prep"`: delegate to `training.dataset_prep_worker.run_cloud_dataset_prep(job_input, webhook_fn=send_webhook)`.
     - If `job_type == "lora_train_peft"`: delegate to `training.train_lora.run_cloud_peft_training(job_input, webhook_fn=send_webhook)`.
3. **Cloud CI Packaging (`.github/workflows/push_gpu_worker.yml` + `tools/zr-studio-gpu/Dockerfile.delta`):**
   - Update `.github/workflows/push_gpu_worker.yml` `paths` to include `tools/zr-studio-training/**` and set Docker build `context: ./tools` with `file: ./tools/zr-studio-gpu/Dockerfile.delta`.
   - Update `tools/zr-studio-gpu/Dockerfile.delta` to install `"peft>=0.13.0" "safetensors>=0.4.5" "pyyaml>=6.0.1"`, copy `zr-studio-gpu/*.py` into `/app/` and `zr-studio-training/` into `/app/training/`, and run `python -m py_compile` across both `/app/*.py` and `/app/training/*.py`.

---

## §5. Flutter Studio LoRA Registry & Factory UI (`apps/vhunambi_client/`)

### 5.1 Extended Model (`apps/vhunambi_client/lib/features/studio/domain/models/studio_form_state.dart`)
Add optional backward-compatible fields onto `AfricanLoraPackOption` (preserving all existing const constructors in `kAfricanLoraPacks`):
```dart
class AfricanLoraPackOption {
  final String loraId;
  final String label;
  final String region;
  final double defaultWeight;
  final String packType; // 'genre' | 'language'
  final String registryStatus; // 'untrained' | 'preparing' | 'ready_to_train' | 'queued' | 'training' | 'validating' | 'active' | 'failed'
  final int readyTrackCount;
  final int curatedTrackCount;
  final int minTracks;
  final int recommendedTracks;
  final String? artifactSha256;
  final double? finalLoss;

  const AfricanLoraPackOption({
    required this.loraId,
    required this.label,
    required this.region,
    this.defaultWeight = 0.85,
    this.packType = 'genre',
    this.registryStatus = 'untrained',
    this.readyTrackCount = 0,
    this.curatedTrackCount = 0,
    this.minTracks = 8,
    this.recommendedTracks = 15,
    this.artifactSha256,
    this.finalLoss,
  });

  bool get isActive => registryStatus == 'active';
  bool get isTraining =>
      registryStatus == 'preparing' ||
      registryStatus == 'queued' ||
      registryStatus == 'training' ||
      registryStatus == 'validating';
  bool get hasEnoughSourceTracks => readyTrackCount >= minTracks;
}
```
Also export `kBantuVocalsLoraPack` (`loraId: 'bantu_vocals_v1'`, `packType: 'language'`) and `kAllSovereignLoraPacks` (`[...kAfricanLoraPacks, kBantuVocalsLoraPack]`).

### 5.2 Live Registry Provider (`apps/vhunambi_client/lib/features/studio/presentation/providers/studio_lora_registry_provider.dart` — NEW)
- `StudioLoraRegistryState` (`packs: List<AfricanLoraPackOption>`, `isLoading`, `isDispatching`, `activeFilter`, `totalSourceTracks`, `errorMessage`, `noticeMessage`).
- `StudioLoraRegistryNotifier extends StateNotifier<StudioLoraRegistryState>` with `SafeNotifierMixin`:
  - `refreshFactory()` -> calls `GET /v1/studio/loras/factory` via `sovereignApiClientProvider` (graceful fallback to `kAllSovereignLoraPacks` on network/test offline).
  - `triggerDatasetPrep(String loraId)` -> calls `POST /v1/studio/loras/datasets/prep` and updates local pack status to `'preparing'`.
  - `triggerCloudTraining(String loraId)` -> calls `POST /v1/studio/loras/train` and updates local pack status to `'queued'`.
- Exports `studioLoraRegistryProvider`.

### 5.3 Sovereign LoRA Factory Sheet (`apps/vhunambi_client/lib/features/studio/presentation/widgets/lora_factory_status_sheet.dart` — NEW)
- `STD-UIUX-001` strict compliance:
  - Uses `package:vhunambi_client/...`, `package:phosphor_icons/phosphor_icons.dart` (`PhosphorIconsBold.sparkle`, `PhosphorIconsBold.cpu`, `PhosphorIconsBold.waveform`, `PhosphorIconsBold.checkCircle`, `PhosphorIconsBold.warningCircle`, `PhosphorIconsBold.x`), `AppColors.surfaceCanvasOf(context)`, `AppColors.surfaceElevatedOf(context)`, `AppColors.borderSubtleOf(context)`, `AppColors.textPrimaryOf(context)`, `AppColors.textSecondaryOf(context)`, `AppTypography.titleLarge`, `AppTypography.titleSmall`, `AppTypography.bodySmall`, `AppTypography.caption`, `AppTypography.badge`.
  - Zero `Icons.*`, zero raw Unicode emojis.
  - Explicit semantic keys:
    - `Key('lora_factory_status_sheet')`
    - `Key('lora_factory_filter_all')`, `Key('lora_factory_filter_ready')`, `Key('lora_factory_filter_active')`
    - `Key('lora_factory_card_<loraId>')`
    - `Key('lora_prep_btn_<loraId>')` (`minHeight: 44`)
    - `Key('lora_train_btn_<loraId>')` (`minHeight: 44`)
- Wire a compact `Key('repaint_open_lora_factory_btn')` (`>= 44dp`) and live status badge (`Active` / `Training` / `Ready` / `Untrained`) into `TrackSectionRepaintSheet` so creators immediately see which packs have trained weights live on R2 and can inspect or trigger Cloud Factory jobs in one tap.

---

## §6. Security & Anti-Regression Invariants

1. **Zero Local Secret Leakage:** No R2 or RunPod credentials are ever sent to Flutter; Flutter calls only authenticated Worker endpoints (`/v1/studio/loras/*`), and Worker dispatches RunPod jobs using Cloudflare Worker secrets (`RUNPOD_API_KEY`, `ZR_WEBHOOK_SECRET`).
2. **Webhook Spoofing Immunity:** `POST /v1/webhooks/training` enforces constant-time HMAC-SHA256 verification and refuses to mark any LoRA `active` without `artifact_bytes > 64` and a 64-character hex `artifact_sha256`.
3. **Active Pack Preservation on Failed Retrain:** If an `active` LoRA pack fails during a `v2` retrain, `lora_training_jobs` records `failed` while `lora_registry.status` remains `active` pointing to the verified `v1` `.safetensors` key.
4. **Phase 83 Zero Regression:** Default `GET /v1/studio/loras` maintains `totalCount === 10` and `packs.length === 10` while adding `languagePacks` and live registry enrichment fields.

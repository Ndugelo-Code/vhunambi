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

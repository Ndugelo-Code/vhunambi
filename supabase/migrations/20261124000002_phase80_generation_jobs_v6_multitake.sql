-- Phase 80: StudioGenerationContractV6 & Multi-Take Baking Registry on public.generation_jobs
-- Apply to Supabase Cloud via supabase_mcp BEFORE deploying vhunambi-api.

ALTER TABLE public.generation_jobs
  ADD COLUMN IF NOT EXISTS batch_id TEXT,
  ADD COLUMN IF NOT EXISTS batch_count INTEGER NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS engine_tier TEXT NOT NULL DEFAULT 'studio_bake',
  ADD COLUMN IF NOT EXISTS resolved_engine TEXT NOT NULL DEFAULT 'minimax_music_3',
  ADD COLUMN IF NOT EXISTS audio_mode TEXT NOT NULL DEFAULT 'none',
  ADD COLUMN IF NOT EXISTS reference_audio_url TEXT,
  ADD COLUMN IF NOT EXISTS visibility TEXT NOT NULL DEFAULT 'public',
  ADD COLUMN IF NOT EXISTS attribution_tag TEXT,
  ADD COLUMN IF NOT EXISTS lyrics_text TEXT,
  ADD COLUMN IF NOT EXISTS cover_url TEXT,
  ADD COLUMN IF NOT EXISTS voice_cast_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS generation_spec_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS takes_json JSONB NOT NULL DEFAULT '[]'::jsonb;

CREATE INDEX IF NOT EXISTS idx_generation_jobs_batch_id
  ON public.generation_jobs (batch_id)
  WHERE batch_id IS NOT NULL;

ALTER TABLE public.generation_jobs ENABLE ROW LEVEL SECURITY;

-- Phase 79 Advisor Guardrail (0003_auth_rls_initplan):
-- Wrap ONLY auth.jwt() inside SELECT so all 4 policies pass with 0 warnings.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'generation_jobs' AND policyname = 'generation_jobs_select_own'
  ) THEN
    CREATE POLICY generation_jobs_select_own ON public.generation_jobs
      FOR SELECT
      USING (((SELECT auth.jwt()) ->> 'creator_id') = creator_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'generation_jobs' AND policyname = 'generation_jobs_insert_own'
  ) THEN
    CREATE POLICY generation_jobs_insert_own ON public.generation_jobs
      FOR INSERT
      WITH CHECK (((SELECT auth.jwt()) ->> 'creator_id') = creator_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'generation_jobs' AND policyname = 'generation_jobs_update_own'
  ) THEN
    CREATE POLICY generation_jobs_update_own ON public.generation_jobs
      FOR UPDATE
      USING (((SELECT auth.jwt()) ->> 'creator_id') = creator_id)
      WITH CHECK (((SELECT auth.jwt()) ->> 'creator_id') = creator_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'generation_jobs' AND policyname = 'generation_jobs_delete_own'
  ) THEN
    CREATE POLICY generation_jobs_delete_own ON public.generation_jobs
      FOR DELETE
      USING (((SELECT auth.jwt()) ->> 'creator_id') = creator_id);
  END IF;
END $$;

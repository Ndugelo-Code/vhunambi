-- ============================================================================
-- VHUNAMBI PHASE 74: KINETIC REELS STUDIO COLUMNS & RPC SECURITY HARDENING
-- Migration: 20261121000002_phase74_reels_studio_and_rpc_hardening.sql
-- ============================================================================

-- 1. Extend public.published_clips with Reels Studio v4 & Multi-Reaction JSONB columns
ALTER TABLE public.published_clips
  ADD COLUMN IF NOT EXISTS video_url TEXT,
  ADD COLUMN IF NOT EXISTS media_kind TEXT NOT NULL DEFAULT 'artwork',
  ADD COLUMN IF NOT EXISTS audio_start_ms INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS audio_end_ms INTEGER NOT NULL DEFAULT 30000,
  ADD COLUMN IF NOT EXISTS effect_preset TEXT NOT NULL DEFAULT 'kinetic_gold',
  ADD COLUMN IF NOT EXISTS effect_intensity DOUBLE PRECISION NOT NULL DEFAULT 0.65,
  ADD COLUMN IF NOT EXISTS typography_preset TEXT NOT NULL DEFAULT 'kinetic_bounce',
  ADD COLUMN IF NOT EXISTS speed_rate DOUBLE PRECISION NOT NULL DEFAULT 1.0,
  ADD COLUMN IF NOT EXISTS sticker_id TEXT,
  ADD COLUMN IF NOT EXISTS reaction_counts_json JSONB NOT NULL DEFAULT '{}'::jsonb;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'published_clips_media_kind_check'
  ) THEN
    ALTER TABLE public.published_clips
      ADD CONSTRAINT published_clips_media_kind_check
      CHECK (
        media_kind IN (
          'artwork',
          'camera_video',
          'gallery_video',
          'gallery_photo',
          'vision'
        )
      );
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_published_clips_created_at_desc
  ON public.published_clips (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_published_clips_creator_created_desc
  ON public.published_clips (creator_id, created_at DESC);

-- 2. Covering Foreign Key Index for public.auth_sessions(creator_id)
CREATE INDEX IF NOT EXISTS idx_auth_sessions_creator_id
  ON public.auth_sessions (creator_id);

-- 3. Harden pre-existing SECURITY DEFINER functions (immutable search_path = public, pg_temp + service_role lockdown)
DO $$
DECLARE
  fn_record RECORD;
BEGIN
  FOR fn_record IN
    SELECT p.oid::regprocedure AS sig, p.proname
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN (
        'execute_atomic_payout',
        'record_beat_license_atomic',
        'send_cultural_tip_atomic',
        'custom_access_token_hook'
      )
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public, pg_temp;', fn_record.sig);

    IF fn_record.proname IN (
      'execute_atomic_payout',
      'record_beat_license_atomic',
      'send_cultural_tip_atomic'
    ) THEN
      EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon, authenticated;', fn_record.sig);
      EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role;', fn_record.sig);
    END IF;
  END LOOP;
END $$;

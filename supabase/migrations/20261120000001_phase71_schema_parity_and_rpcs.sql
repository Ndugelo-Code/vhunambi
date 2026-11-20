BEGIN;

-- =============================================================================
-- Phase 71 (REQ-P71-SQL-01): explore_tracks parity columns
-- =============================================================================
ALTER TABLE public.explore_tracks
  ADD COLUMN IF NOT EXISTS mood TEXT NOT NULL DEFAULT 'Vibrant';

ALTER TABLE public.explore_tracks
  ADD COLUMN IF NOT EXISTS language TEXT NOT NULL DEFAULT 'isiZulu';

ALTER TABLE public.explore_tracks
  ADD COLUMN IF NOT EXISTS discovery_stage TEXT NOT NULL DEFAULT 'freshCrate';

ALTER TABLE public.explore_tracks
  ADD COLUMN IF NOT EXISTS data_json JSONB NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE public.explore_tracks
  ADD COLUMN IF NOT EXISTS created_at BIGINT NOT NULL
    DEFAULT (EXTRACT(EPOCH FROM now()) * 1000)::BIGINT;

CREATE INDEX IF NOT EXISTS idx_explore_tracks_stage_updated
  ON public.explore_tracks (discovery_stage, updated_at DESC);

-- =============================================================================
-- Phase 71 (REQ-P71-SQL-02): user_library_sync parity columns
-- =============================================================================
ALTER TABLE public.user_library_sync
  ADD COLUMN IF NOT EXISTS item_type TEXT NOT NULL DEFAULT 'track';

ALTER TABLE public.user_library_sync
  ADD COLUMN IF NOT EXISTS created_at BIGINT NOT NULL
    DEFAULT (EXTRACT(EPOCH FROM now()) * 1000)::BIGINT;

-- =============================================================================
-- Phase 71 (REQ-P71-SQL-03 / EP-P71-ATOMIC-QUOTA-RPC):
-- Row-locked atomic monthly free song quota consumption across Cloudflare
-- Worker isolates. Prevents double-spending the 10-song free allowance and
-- rolls over expired 30-day cycles inside a single Postgres transaction.
-- =============================================================================
CREATE OR REPLACE FUNCTION public.consume_free_monthly_song_quota_atomic(
  p_user_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id TEXT := COALESCE(NULLIF(TRIM(p_user_id), ''), 'creator_cern');
  v_now TIMESTAMPTZ := now();
  v_row public.creator_quotas%ROWTYPE;
  v_used INTEGER;
  v_limit INTEGER;
  v_reset_at TIMESTAMPTZ;
  v_allowed BOOLEAN := false;
  v_remaining INTEGER := 0;
BEGIN
  INSERT INTO public.creator_quotas (
    user_id,
    plan_tier,
    free_monthly_songs_limit,
    free_monthly_songs_used,
    cycle_reset_at,
    updated_at
  )
  VALUES (
    v_user_id,
    'free',
    10,
    0,
    v_now + INTERVAL '30 days',
    v_now
  )
  ON CONFLICT (user_id) DO NOTHING;

  SELECT *
    INTO v_row
    FROM public.creator_quotas
   WHERE user_id = v_user_id
     FOR UPDATE;

  v_limit := COALESCE(v_row.free_monthly_songs_limit, 10);
  v_used := COALESCE(v_row.free_monthly_songs_used, 0);
  v_reset_at := COALESCE(v_row.cycle_reset_at, v_now + INTERVAL '30 days');

  IF v_now >= v_reset_at THEN
    v_used := 0;
    v_reset_at := v_now + INTERVAL '30 days';
  END IF;

  IF LOWER(COALESCE(v_row.plan_tier, 'free')) <> 'free' OR v_limit < 0 THEN
    v_allowed := true;
    v_remaining := CASE WHEN v_limit < 0 THEN 999999 ELSE GREATEST(0, v_limit - v_used) END;
  ELSIF v_used < v_limit THEN
    v_used := v_used + 1;
    v_allowed := true;
    v_remaining := GREATEST(0, v_limit - v_used);
  ELSE
    v_allowed := false;
    v_remaining := 0;
  END IF;

  UPDATE public.creator_quotas
     SET free_monthly_songs_used = v_used,
         cycle_reset_at = v_reset_at,
         updated_at = v_now
   WHERE user_id = v_user_id;

  RETURN jsonb_build_object(
    'userId', v_user_id,
    'planTier', COALESCE(v_row.plan_tier, 'free'),
    'freeMonthlySongsLimit', v_limit,
    'freeMonthlySongsUsed', v_used,
    'freeMonthlySongsRemaining', v_remaining,
    'cycleResetAt', to_char(v_reset_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
    'updatedAt', to_char(v_now AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
    'allowed', v_allowed
  );
END;
$$;

ALTER TABLE IF EXISTS public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.creator_quotas ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON FUNCTION public.consume_free_monthly_song_quota_atomic(TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.consume_free_monthly_song_quota_atomic(TEXT) TO service_role;

COMMIT;

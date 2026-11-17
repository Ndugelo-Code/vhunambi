BEGIN;

-- 20. Sovereign Notifications Table (Phase 67)
CREATE TABLE IF NOT EXISTS public.notifications (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'creatorActivity',
  subtype TEXT,
  priority TEXT NOT NULL DEFAULT 'normal',
  is_read BOOLEAN NOT NULL DEFAULT false,
  target_route TEXT,
  target_entity_id TEXT,
  cta_label TEXT,
  metadata_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_notifications_user_created
  ON public.notifications (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
  ON public.notifications (user_id, is_read);

-- 21. Creator Monthly Song Quotas Table (10 Free Songs / Month)
CREATE TABLE IF NOT EXISTS public.creator_quotas (
  user_id TEXT PRIMARY KEY,
  plan_tier TEXT NOT NULL DEFAULT 'free',
  free_monthly_songs_limit INTEGER NOT NULL DEFAULT 10,
  free_monthly_songs_used INTEGER NOT NULL DEFAULT 0,
  cycle_reset_at TIMESTAMPTZ NOT NULL DEFAULT (now() + INTERVAL '30 days'),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMIT;

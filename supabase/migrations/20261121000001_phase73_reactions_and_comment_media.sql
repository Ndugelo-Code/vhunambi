BEGIN;

-- 1. Phase 73 Multi-Reaction Aggregates on Kinetic Posts
ALTER TABLE public.kinetic_posts
  ADD COLUMN IF NOT EXISTS reaction_counts_json JSONB NOT NULL DEFAULT '{}'::jsonb;

-- 2. Phase 73 Multi-Reaction Aggregates & GIF/Sticker Media Columns on Comments
ALTER TABLE public.reel_comments
  ADD COLUMN IF NOT EXISTS reaction_counts_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS gif_url TEXT,
  ADD COLUMN IF NOT EXISTS sticker_id TEXT,
  ADD COLUMN IF NOT EXISTS media_aspect_ratio DOUBLE PRECISION;

-- 3. Typed Reaction Discriminator on Social Interactions
ALTER TABLE public.social_interactions
  ADD COLUMN IF NOT EXISTS reaction_type TEXT;

CREATE INDEX IF NOT EXISTS idx_social_interactions_target_type
  ON public.social_interactions (interaction_type, target_id);

COMMIT;

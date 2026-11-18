BEGIN;

-- 1. Add like_count and comment_count to public.kinetic_posts (Phase 69 KP-03 / REQ-P69-DB-01)
ALTER TABLE public.kinetic_posts
  ADD COLUMN IF NOT EXISTS like_count INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS comment_count INTEGER NOT NULL DEFAULT 0;

-- 2. Add nested reply threading columns to public.reel_comments (Phase 69 KP-02 / KP-03)
ALTER TABLE public.reel_comments
  ADD COLUMN IF NOT EXISTS parent_comment_id TEXT,
  ADD COLUMN IF NOT EXISTS reply_to_handle TEXT;

CREATE INDEX IF NOT EXISTS idx_reel_comments_parent
  ON public.reel_comments (clip_id, parent_comment_id);

COMMIT;

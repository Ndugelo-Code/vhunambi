BEGIN;

-- Phase 70: Canonical VhunambiMood (mood_id), Song Description & Open-Stems Remix Flag
-- Idempotent migration for public.explore_tracks (`REQ-P70-API-02`).

ALTER TABLE public.explore_tracks
  ADD COLUMN IF NOT EXISTS mood_id TEXT NOT NULL DEFAULT 'uplifting',
  ADD COLUMN IF NOT EXISTS description TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS allow_open_stems_remix BOOLEAN NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_explore_tracks_mood_id
  ON public.explore_tracks (mood_id);

COMMIT;

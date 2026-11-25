-- ============================================================================
-- VHUNAMBI PHASE 84: EDGE ID3V2 METADATA, SHA-256 DEDUPE & ZANIA INGEST SCHEMA
-- Migration: 20261125000001_phase84_media_id3_and_zania_ingest.sql
-- ============================================================================

-- 1. Extend public.user_media_uploads with ID3v2 metadata & content SHA-256
ALTER TABLE public.user_media_uploads
  ADD COLUMN IF NOT EXISTS id3_metadata_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS content_sha256 TEXT;

CREATE INDEX IF NOT EXISTS idx_user_media_uploads_creator_sha256
  ON public.user_media_uploads (creator_id, content_sha256)
  WHERE content_sha256 IS NOT NULL AND deleted_at IS NULL;

-- 2. Extend public.explore_tracks with deduplication hash, source origin & lyrics
ALTER TABLE public.explore_tracks
  ADD COLUMN IF NOT EXISTS content_sha256 TEXT,
  ADD COLUMN IF NOT EXISTS source_origin TEXT NOT NULL DEFAULT 'vhunambi_studio',
  ADD COLUMN IF NOT EXISTS lyrics_text TEXT NOT NULL DEFAULT '';

CREATE UNIQUE INDEX IF NOT EXISTS idx_explore_tracks_creator_sha256
  ON public.explore_tracks (creator_id, content_sha256)
  WHERE content_sha256 IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_explore_tracks_source_origin
  ON public.explore_tracks (source_origin, created_at DESC);

-- 3. Ensure public.kinetic_posts supports fast creator feed queries
CREATE INDEX IF NOT EXISTS idx_kinetic_posts_creator_created
  ON public.kinetic_posts (creator_id, created_at DESC);

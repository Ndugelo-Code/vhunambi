-- ============================================================================
-- VHUNAMBI PHASE 79: USER MEDIA UPLOADS DURABLE REGISTRY & RLS
-- Migration: 20261124000001_phase79_user_media_uploads.sql
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.user_media_uploads (
  id TEXT PRIMARY KEY,
  creator_id TEXT NOT NULL,
  media_kind TEXT NOT NULL CHECK (media_kind IN ('audio', 'video', 'image')),
  title TEXT NOT NULL,
  filename TEXT NOT NULL,
  mime_type TEXT NOT NULL,
  size_bytes BIGINT NOT NULL CHECK (size_bytes > 0),
  duration_ms INTEGER,
  width INTEGER,
  height INTEGER,
  r2_key TEXT NOT NULL,
  remote_url TEXT NOT NULL,
  thumbnail_url TEXT,
  source_surface TEXT NOT NULL DEFAULT 'vault',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_user_media_uploads_creator_created
  ON public.user_media_uploads (creator_id, created_at DESC)
  WHERE deleted_at IS NULL;

ALTER TABLE public.user_media_uploads ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'user_media_uploads'
      AND policyname = 'user_media_uploads_owner_select'
  ) THEN
    CREATE POLICY user_media_uploads_owner_select
      ON public.user_media_uploads
      FOR SELECT
      TO authenticated
      USING (((SELECT auth.jwt()) ->> 'creator_id') = creator_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'user_media_uploads'
      AND policyname = 'user_media_uploads_owner_insert'
  ) THEN
    CREATE POLICY user_media_uploads_owner_insert
      ON public.user_media_uploads
      FOR INSERT
      TO authenticated
      WITH CHECK (((SELECT auth.jwt()) ->> 'creator_id') = creator_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'user_media_uploads'
      AND policyname = 'user_media_uploads_owner_update'
  ) THEN
    CREATE POLICY user_media_uploads_owner_update
      ON public.user_media_uploads
      FOR UPDATE
      TO authenticated
      USING (((SELECT auth.jwt()) ->> 'creator_id') = creator_id)
      WITH CHECK (((SELECT auth.jwt()) ->> 'creator_id') = creator_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'user_media_uploads'
      AND policyname = 'user_media_uploads_owner_delete'
  ) THEN
    CREATE POLICY user_media_uploads_owner_delete
      ON public.user_media_uploads
      FOR DELETE
      TO authenticated
      USING (((SELECT auth.jwt()) ->> 'creator_id') = creator_id);
  END IF;
END $$;

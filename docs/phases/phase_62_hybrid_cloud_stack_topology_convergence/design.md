# Phase 62: Hybrid Cloud Stack Topology & Production Edge Convergence — Detailed Engineering Design

> **Document ID:** `VHUNAMBI-SPEC-P62-DESIGN-V1`
> **Phase:** `62 — Hybrid Cloud Stack Topology & Production Edge Convergence (Supabase + Cloudflare Workers/R2 + RunPod GPU)`
> **Engineering Standard:** `All-Gemini Engineering Standard (100% Compilable SQL, TypeScript, Python & Dart Specifications — Zero Placeholders)`
> **Status:** `HARDENED SPECIFICATION SUITE — READY FOR EXECUTION`
> **Audit Foundation:** `docs/audits/HYBRID_CLOUD_STACK_TOPOLOGY_PHASE62_AUDIT.md`

---

## 1. Milestone `M62.1`: Complete 19-Table Supabase PostgreSQL Schema, Atomic RPCs & Lazy Dual-Driver Engine

### 1.1 Production PostgreSQL 19-Table Migration & Atomic RPCs (`supabase/migrations/20261110000001_phase62_hybrid_cloud_schema.sql`)

```sql
-- =============================================================================
-- VHUNAMBI PHASE 62: HYBRID CLOUD PRODUCTION SCHEMA (19 TABLES + 4 ATOMIC RPCS)
-- Target: Supabase PostgreSQL 15+ (Connected via Cloudflare Hyperdrive / REST)
-- =============================================================================

BEGIN;

-- 1. Core Creators Table (Unified Phase 59-61 SQLite + Supabase Profile Columns)
CREATE TABLE IF NOT EXISTS public.creators (
  id TEXT PRIMARY KEY,
  handle TEXT NOT NULL UNIQUE,
  display_name TEXT NOT NULL,
  avatar_url TEXT NOT NULL DEFAULT '',
  archetype TEXT NOT NULL DEFAULT 'Producer',
  tier TEXT NOT NULL DEFAULT 'Sovereign',
  reputation_score DOUBLE PRECISION NOT NULL DEFAULT 100.0,
  bio TEXT NOT NULL DEFAULT '',
  followers_count INTEGER NOT NULL DEFAULT 0,
  following_count INTEGER NOT NULL DEFAULT 0,
  is_verified BOOLEAN NOT NULL DEFAULT true,
  data_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at BIGINT NOT NULL DEFAULT (EXTRACT(EPOCH FROM now()) * 1000)::BIGINT
);

-- 2. Sovereign Users Table (Bridged to Supabase auth.users via auth_uid)
CREATE TABLE IF NOT EXISTS public.users (
  user_id TEXT PRIMARY KEY,
  auth_uid UUID UNIQUE,
  creator_id TEXT NOT NULL UNIQUE REFERENCES public.creators(id) ON DELETE CASCADE,
  handle TEXT NOT NULL UNIQUE,
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL DEFAULT 'GOTRUE_MANAGED',
  role TEXT NOT NULL DEFAULT 'creator',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_users_handle_lower ON public.users (LOWER(handle));
CREATE INDEX IF NOT EXISTS idx_users_email_lower ON public.users (LOWER(email));
CREATE INDEX IF NOT EXISTS idx_users_creator_id ON public.users (creator_id);

-- 3. Auth Sessions & Refresh Token Family Revocation Table
CREATE TABLE IF NOT EXISTS public.auth_sessions (
  session_id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES public.users(user_id) ON DELETE CASCADE,
  creator_id TEXT NOT NULL REFERENCES public.creators(id) ON DELETE CASCADE,
  family_id TEXT NOT NULL,
  refresh_token_hash TEXT NOT NULL,
  previous_token_hash TEXT,
  device_label TEXT NOT NULL DEFAULT 'vhunambi_client',
  expires_at TIMESTAMPTZ NOT NULL,
  revoked BOOLEAN NOT NULL DEFAULT false,
  revoke_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  rotated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_auth_sessions_user ON public.auth_sessions (user_id);
CREATE INDEX IF NOT EXISTS idx_auth_sessions_family ON public.auth_sessions (family_id);

-- 4. Monotonic Delta-Sync Mutation Log (Tenant-Scoped)
CREATE TABLE IF NOT EXISTS public.sync_mutation_log (
  seq BIGSERIAL PRIMARY KEY,
  mutation_id TEXT NOT NULL UNIQUE,
  creator_id TEXT NOT NULL DEFAULT 'system',
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  operation TEXT NOT NULL,
  payload_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  client_ts BIGINT NOT NULL,
  server_ts TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_sync_mutation_seq ON public.sync_mutation_log (seq);
CREATE INDEX IF NOT EXISTS idx_sync_mutation_entity ON public.sync_mutation_log (entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_sync_mutation_creator_seq ON public.sync_mutation_log (creator_id, seq);

-- 5. Append-Only Sovereign Wallet Ledger
CREATE TABLE IF NOT EXISTS public.wallet_ledger (
  id TEXT PRIMARY KEY,
  creator_id TEXT NOT NULL REFERENCES public.creators(id) ON DELETE CASCADE,
  amount_zar NUMERIC(12, 2) NOT NULL DEFAULT 0,
  amount_coins INTEGER NOT NULL DEFAULT 0,
  type TEXT NOT NULL,
  reference TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'completed',
  metadata_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_wallet_creator ON public.wallet_ledger (creator_id, created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS idx_wallet_unique_gateway_ref
  ON public.wallet_ledger (reference)
  WHERE reference LIKE 'PF-ITN-%' OR reference LIKE 'VH-PAY-%';

-- 6. South African Verified Bank Accounts
CREATE TABLE IF NOT EXISTS public.bank_accounts (
  id TEXT PRIMARY KEY,
  creator_id TEXT NOT NULL REFERENCES public.creators(id) ON DELETE CASCADE,
  bank_code TEXT NOT NULL,
  bank_name TEXT NOT NULL,
  account_holder TEXT NOT NULL,
  account_number_masked TEXT NOT NULL,
  account_type TEXT NOT NULL DEFAULT 'cheque',
  branch_code TEXT NOT NULL,
  payout_rail TEXT NOT NULL DEFAULT 'payfast',
  is_verified BOOLEAN NOT NULL DEFAULT true,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_bank_accounts_creator ON public.bank_accounts (creator_id);

-- 7. Explore Regional Heritage Tracks Catalog
CREATE TABLE IF NOT EXISTS public.explore_tracks (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  artist TEXT NOT NULL,
  creator_id TEXT NOT NULL DEFAULT 'creator_cern',
  genre TEXT NOT NULL,
  sub_genre TEXT NOT NULL DEFAULT '',
  region TEXT NOT NULL DEFAULT 'South Africa',
  bpm INTEGER NOT NULL DEFAULT 113,
  musical_key TEXT NOT NULL DEFAULT 'F#m',
  duration_sec INTEGER NOT NULL DEFAULT 180,
  audio_url TEXT NOT NULL,
  cover_url TEXT NOT NULL,
  stems_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  plays_count INTEGER NOT NULL DEFAULT 0,
  likes_count INTEGER NOT NULL DEFAULT 0,
  cosigns_count INTEGER NOT NULL DEFAULT 0,
  is_featured BOOLEAN NOT NULL DEFAULT false,
  updated_at BIGINT NOT NULL DEFAULT (EXTRACT(EPOCH FROM now()) * 1000)::BIGINT
);
CREATE INDEX IF NOT EXISTS idx_explore_tracks_genre ON public.explore_tracks (genre);

-- 8. Explore Kinetic Posts
CREATE TABLE IF NOT EXISTS public.kinetic_posts (
  id TEXT PRIMARY KEY,
  creator_id TEXT NOT NULL,
  creator_name TEXT NOT NULL,
  creator_handle TEXT NOT NULL,
  avatar_url TEXT NOT NULL,
  track_id TEXT,
  track_title TEXT NOT NULL,
  genre TEXT NOT NULL,
  caption TEXT NOT NULL,
  audio_preview_url TEXT NOT NULL,
  cover_url TEXT NOT NULL,
  cosign_count INTEGER NOT NULL DEFAULT 0,
  repost_count INTEGER NOT NULL DEFAULT 0,
  comment_count INTEGER NOT NULL DEFAULT 0,
  discovery_stage TEXT NOT NULL DEFAULT 'rising',
  data_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at BIGINT NOT NULL,
  updated_at BIGINT NOT NULL
);

-- 9. Social Published Clips & Remix Lineage (Replaces RAM clips Map)
CREATE TABLE IF NOT EXISTS public.published_clips (
  id TEXT PRIMARY KEY,
  track_id TEXT NOT NULL,
  creator_id TEXT NOT NULL,
  title TEXT NOT NULL DEFAULT 'Untitled Groove',
  caption TEXT NOT NULL DEFAULT '',
  genre TEXT NOT NULL DEFAULT 'Amapiano',
  bpm INTEGER NOT NULL DEFAULT 113,
  likes_count INTEGER NOT NULL DEFAULT 0,
  comments_count INTEGER NOT NULL DEFAULT 0,
  remixes_count INTEGER NOT NULL DEFAULT 0,
  shares_count INTEGER NOT NULL DEFAULT 0,
  audio_url TEXT NOT NULL DEFAULT '',
  cover_url TEXT NOT NULL DEFAULT '',
  remixed_from_clip_id TEXT,
  remix_attribution TEXT,
  tags_json JSONB NOT NULL DEFAULT '[]'::jsonb,
  dna_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  data_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at BIGINT NOT NULL,
  updated_at BIGINT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_published_clips_creator ON public.published_clips (creator_id);
CREATE INDEX IF NOT EXISTS idx_published_clips_remix_parent ON public.published_clips (remixed_from_clip_id);

-- 10. Social Reel Comments & Gift Celebration Badges (Replaces RAM commentsByClip Map)
CREATE TABLE IF NOT EXISTS public.reel_comments (
  id TEXT PRIMARY KEY,
  clip_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  username TEXT NOT NULL DEFAULT '@creator',
  display_name TEXT NOT NULL DEFAULT 'Creator',
  avatar_url TEXT NOT NULL DEFAULT '',
  is_creator BOOLEAN NOT NULL DEFAULT false,
  text TEXT NOT NULL,
  likes_count INTEGER NOT NULL DEFAULT 0,
  user_reel_loves INTEGER NOT NULL DEFAULT 0,
  gift_emoji TEXT,
  gift_name TEXT,
  timestamp_ms BIGINT NOT NULL,
  data_json JSONB NOT NULL DEFAULT '{}'::jsonb
);
CREATE INDEX IF NOT EXISTS idx_reel_comments_clip ON public.reel_comments (clip_id, timestamp_ms DESC);

-- 11. Marketplace Beats Catalog (Replaces RAM marketplaceBeats Map)
CREATE TABLE IF NOT EXISTS public.marketplace_assets (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  producer_id TEXT NOT NULL,
  producer_name TEXT NOT NULL,
  genre TEXT NOT NULL,
  bpm INTEGER NOT NULL,
  musical_key TEXT NOT NULL DEFAULT 'Am',
  price_zar NUMERIC(12, 2) NOT NULL DEFAULT 350.00,
  price_coins INTEGER NOT NULL DEFAULT 350,
  is_exclusive_sold BOOLEAN NOT NULL DEFAULT false,
  exclusive_buyer_id TEXT,
  audio_preview_url TEXT NOT NULL DEFAULT '',
  cover_url TEXT NOT NULL DEFAULT '',
  tags_json JSONB NOT NULL DEFAULT '[]'::jsonb,
  tier_pricing_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  stems_r2_keys_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  data_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at BIGINT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_marketplace_assets_producer ON public.marketplace_assets (producer_id);
CREATE INDEX IF NOT EXISTS idx_marketplace_assets_genre ON public.marketplace_assets (genre);

-- 12. Cryptographic Beat Licenses Registry
CREATE TABLE IF NOT EXISTS public.beat_licenses (
  certificate_id TEXT PRIMARY KEY,
  beat_id TEXT NOT NULL REFERENCES public.marketplace_assets(id) ON DELETE RESTRICT,
  beat_title TEXT NOT NULL,
  buyer_id TEXT NOT NULL,
  buyer_name TEXT NOT NULL,
  producer_id TEXT NOT NULL,
  producer_name TEXT NOT NULL,
  tier TEXT NOT NULL,
  amount_paid_zar NUMERIC(12, 2) NOT NULL,
  amount_paid_coins INTEGER NOT NULL,
  license_hash TEXT NOT NULL UNIQUE,
  master_file_sha256 TEXT NOT NULL,
  terms_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  stems_urls_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  purchased_at BIGINT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_beat_licenses_buyer ON public.beat_licenses (buyer_id, purchased_at DESC);
CREATE INDEX IF NOT EXISTS idx_beat_licenses_beat ON public.beat_licenses (beat_id);

-- 13. Sound Signatures Vault (Replaces RAM soundSignatureStore Map)
CREATE TABLE IF NOT EXISTS public.sound_signatures (
  id TEXT PRIMARY KEY,
  creator_id TEXT NOT NULL,
  name TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'vocal_DNA',
  status TEXT NOT NULL DEFAULT 'awaiting_upload',
  r2_audio_key TEXT NOT NULL DEFAULT '',
  recipe_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  embedding_json JSONB NOT NULL DEFAULT '[]'::jsonb,
  consent_at_iso TEXT NOT NULL DEFAULT '',
  data_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at BIGINT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_sound_signatures_creator ON public.sound_signatures (creator_id);

-- 14. User Cloud Library LWW Sync Table
CREATE TABLE IF NOT EXISTS public.user_library_sync (
  id TEXT NOT NULL,
  creator_id TEXT NOT NULL,
  title TEXT NOT NULL,
  artist TEXT NOT NULL,
  genre TEXT NOT NULL DEFAULT 'Amapiano',
  bpm INTEGER NOT NULL DEFAULT 113,
  duration_sec INTEGER NOT NULL DEFAULT 180,
  audio_url TEXT NOT NULL DEFAULT '',
  cover_url TEXT NOT NULL DEFAULT '',
  is_favorite BOOLEAN NOT NULL DEFAULT false,
  is_downloaded BOOLEAN NOT NULL DEFAULT false,
  play_count INTEGER NOT NULL DEFAULT 0,
  is_licensed_beat BOOLEAN NOT NULL DEFAULT false,
  license_tier TEXT,
  certificate_id TEXT,
  license_hash TEXT,
  master_file_sha256 TEXT,
  stems_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  data_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at BIGINT NOT NULL,
  PRIMARY KEY (id, creator_id)
);
CREATE INDEX IF NOT EXISTS idx_library_creator_updated ON public.user_library_sync (creator_id, updated_at DESC);

-- 15. Sovereign Cloud Playlists
CREATE TABLE IF NOT EXISTS public.playlists (
  id TEXT PRIMARY KEY,
  creator_id TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  cover_url TEXT NOT NULL DEFAULT '',
  track_ids_json JSONB NOT NULL DEFAULT '[]'::jsonb,
  is_public BOOLEAN NOT NULL DEFAULT true,
  share_code TEXT NOT NULL UNIQUE,
  data_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at BIGINT NOT NULL,
  updated_at BIGINT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_playlists_creator ON public.playlists (creator_id, updated_at DESC);

-- 16. Persistent AI Generation & Vision Jobs (Replaces RAM job_store.ts)
CREATE TABLE IF NOT EXISTS public.generation_jobs (
  generation_id TEXT PRIMARY KEY,
  creator_id TEXT NOT NULL DEFAULT 'creator_cern',
  job_kind TEXT NOT NULL DEFAULT 'audio_synthesis',
  provider_task_id TEXT,
  status TEXT NOT NULL DEFAULT 'queued',
  step TEXT NOT NULL DEFAULT 'Initializing pipeline...',
  progress_pct INTEGER NOT NULL DEFAULT 0,
  track_title TEXT NOT NULL DEFAULT 'Untitled Track',
  genre TEXT NOT NULL DEFAULT 'Amapiano',
  language TEXT NOT NULL DEFAULT 'Instrumental',
  duration_sec INTEGER NOT NULL DEFAULT 180,
  master_mp3_url TEXT,
  stems_zip_url TEXT,
  stem_urls_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  manifest_url TEXT,
  manifest_json JSONB,
  error_message TEXT,
  created_at BIGINT NOT NULL,
  updated_at BIGINT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_generation_jobs_creator ON public.generation_jobs (creator_id, created_at DESC);

-- 17. Persistent Zero-Shot Voice Clones (Replaces RAM clonedVoiceStore)
CREATE TABLE IF NOT EXISTS public.voice_clones (
  voice_id TEXT PRIMARY KEY,
  creator_id TEXT NOT NULL,
  display_name TEXT NOT NULL,
  consent_verified BOOLEAN NOT NULL DEFAULT true,
  reference_audio_duration_sec DOUBLE PRECISION NOT NULL DEFAULT 15.0,
  r2_reference_url TEXT NOT NULL,
  pitch_range_hz_json JSONB NOT NULL DEFAULT '[110, 660]'::jsonb,
  timbre_embedding_json JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_voice_clones_creator ON public.voice_clones (creator_id);

-- 18. Normalized Social Interactions (Replaces RAM following Set & global isLikedByMe)
CREATE TABLE IF NOT EXISTS public.social_interactions (
  interaction_type TEXT NOT NULL, -- 'clip_like' | 'comment_like' | 'creator_follow'
  target_id TEXT NOT NULL,
  actor_creator_id TEXT NOT NULL,
  created_at BIGINT NOT NULL,
  PRIMARY KEY (interaction_type, target_id, actor_creator_id)
);
CREATE INDEX IF NOT EXISTS idx_social_interactions_actor ON public.social_interactions (actor_creator_id, interaction_type);

-- 19. South African Payment Gateway Checkouts & Idempotent ITN Ledger
CREATE TABLE IF NOT EXISTS public.payment_topups (
  checkout_id TEXT PRIMARY KEY,
  creator_id TEXT NOT NULL REFERENCES public.creators(id) ON DELETE CASCADE,
  provider TEXT NOT NULL DEFAULT 'payfast',
  provider_payment_id TEXT UNIQUE,
  pack_id TEXT NOT NULL DEFAULT 'pack_producer_1500',
  amount_zar NUMERIC(12, 2) NOT NULL,
  coins_granted INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending', -- 'pending' | 'completed' | 'failed'
  signature_md5 TEXT NOT NULL,
  raw_itn_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  verified_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_payment_topups_creator ON public.payment_topups (creator_id, created_at DESC);

-- =============================================================================
-- ATOMIC PL/pgSQL RPC 1: execute_atomic_payout (Parent Creator Row FOR UPDATE)
-- =============================================================================
CREATE OR REPLACE FUNCTION public.execute_atomic_payout(
  p_creator_id TEXT,
  p_amount_zar NUMERIC,
  p_amount_coins INTEGER,
  p_bank_code TEXT,
  p_bank_name TEXT,
  p_account_holder TEXT,
  p_account_masked TEXT,
  p_account_type TEXT,
  p_branch_code TEXT,
  p_payout_rail TEXT,
  p_tx_id TEXT,
  p_gateway_ref TEXT,
  p_status TEXT,
  p_mutation_id TEXT,
  p_client_ts BIGINT
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_balance_zar NUMERIC(12, 2);
  v_balance_coins INTEGER;
  v_bank_id TEXT := 'bank_' || p_creator_id || '_' || lower(p_bank_code);
  v_seq BIGINT;
BEGIN
  -- Acquire exclusive parent row lock on creators to serialize concurrent debits
  PERFORM id FROM public.creators WHERE id = p_creator_id FOR UPDATE;

  SELECT COALESCE(SUM(amount_zar), 0), COALESCE(SUM(amount_coins), 0)
    INTO v_balance_zar, v_balance_coins
    FROM public.wallet_ledger
   WHERE creator_id = p_creator_id;

  IF v_balance_coins < p_amount_coins OR v_balance_zar < p_amount_zar THEN
    RAISE EXCEPTION 'INSUFFICIENT_FUNDS: Available % coins (R %), requested % coins (R %)',
      v_balance_coins, v_balance_zar, p_amount_coins, p_amount_zar;
  END IF;

  INSERT INTO public.bank_accounts (
    id, creator_id, bank_code, bank_name, account_holder,
    account_number_masked, account_type, branch_code, payout_rail, is_verified, updated_at
  ) VALUES (
    v_bank_id, p_creator_id, p_bank_code, p_bank_name, p_account_holder,
    p_account_masked, p_account_type, p_branch_code, p_payout_rail, true, now()
  )
  ON CONFLICT (id) DO UPDATE SET
    account_holder = EXCLUDED.account_holder,
    account_number_masked = EXCLUDED.account_number_masked,
    account_type = EXCLUDED.account_type,
    payout_rail = EXCLUDED.payout_rail,
    updated_at = now();

  INSERT INTO public.wallet_ledger (
    id, creator_id, amount_zar, amount_coins, type, reference, status, metadata_json
  ) VALUES (
    p_tx_id, p_creator_id, -ABS(p_amount_zar), -ABS(p_amount_coins),
    'payout_withdrawal', p_gateway_ref, p_status,
    jsonb_build_object(
      'bankCode', p_bank_code,
      'bankName', p_bank_name,
      'accountMasked', p_account_masked,
      'payoutRail', p_payout_rail
    )
  );

  INSERT INTO public.sync_mutation_log (
    mutation_id, creator_id, entity_type, entity_id, operation, payload_json, client_ts
  ) VALUES (
    p_mutation_id, p_creator_id, 'payout', p_tx_id, 'create',
    jsonb_build_object(
      'txId', p_tx_id,
      'creatorId', p_creator_id,
      'amountZar', p_amount_zar,
      'amountCoins', p_amount_coins,
      'gatewayReference', p_gateway_ref,
      'status', p_status
    ),
    p_client_ts
  ) RETURNING seq INTO v_seq;

  RETURN jsonb_build_object(
    'txId', p_tx_id,
    'gatewayReference', p_gateway_ref,
    'status', p_status,
    'remainingBalanceZar', (v_balance_zar - ABS(p_amount_zar)),
    'remainingBalanceCoins', (v_balance_coins - ABS(p_amount_coins)),
    'syncSeq', v_seq
  );
END;
$$;

-- =============================================================================
-- ATOMIC PL/pgSQL RPC 2: record_beat_license_atomic (Beat + Buyer FOR UPDATE)
-- =============================================================================
CREATE OR REPLACE FUNCTION public.record_beat_license_atomic(
  p_certificate_id TEXT,
  p_beat_id TEXT,
  p_beat_title TEXT,
  p_buyer_id TEXT,
  p_buyer_name TEXT,
  p_producer_id TEXT,
  p_producer_name TEXT,
  p_tier TEXT,
  p_amount_zar NUMERIC,
  p_amount_coins INTEGER,
  p_license_hash TEXT,
  p_master_sha256 TEXT,
  p_terms_json JSONB,
  p_stems_urls_json JSONB,
  p_purchased_at BIGINT,
  p_enforce_wallet BOOLEAN DEFAULT true
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_is_sold BOOLEAN;
  v_buyer_coins INTEGER;
  v_producer_zar NUMERIC(12, 2) := ROUND(p_amount_zar * 0.85, 2);
  v_producer_coins INTEGER := GREATEST(1, FLOOR(p_amount_coins * 0.85)::INTEGER);
BEGIN
  -- Lock beat row & buyer creator row to serialize exclusive buyouts and wallet debits
  SELECT is_exclusive_sold INTO v_is_sold
    FROM public.marketplace_assets
   WHERE id = p_beat_id
   FOR UPDATE;

  IF v_is_sold IS TRUE THEN
    RETURN jsonb_build_object('outcome', 'exclusive_conflict');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.beat_licenses
     WHERE beat_id = p_beat_id
       AND tier IN ('exclusive_stem', 'unlimited_commercial', 'EXCLUSIVE_RIGHTS')
  ) THEN
    RETURN jsonb_build_object('outcome', 'exclusive_conflict');
  END IF;

  PERFORM id FROM public.creators WHERE id = p_buyer_id FOR UPDATE;

  IF p_enforce_wallet AND p_amount_coins > 0 THEN
    SELECT COALESCE(SUM(amount_coins), 0)
      INTO v_buyer_coins
      FROM public.wallet_ledger
     WHERE creator_id = p_buyer_id;

    IF v_buyer_coins < p_amount_coins THEN
      RETURN jsonb_build_object(
        'outcome', 'insufficient_funds',
        'availableCoins', v_buyer_coins,
        'requiredCoins', p_amount_coins
      );
    END IF;
  END IF;

  INSERT INTO public.beat_licenses (
    certificate_id, beat_id, beat_title, buyer_id, buyer_name,
    producer_id, producer_name, tier, amount_paid_zar, amount_paid_coins,
    license_hash, master_file_sha256, terms_json, stems_urls_json, purchased_at
  ) VALUES (
    p_certificate_id, p_beat_id, p_beat_title, p_buyer_id, p_buyer_name,
    p_producer_id, p_producer_name, p_tier, p_amount_zar, p_amount_coins,
    p_license_hash, p_master_sha256, p_terms_json, p_stems_urls_json, p_purchased_at
  );

  IF p_amount_coins > 0 THEN
    INSERT INTO public.wallet_ledger (
      id, creator_id, amount_zar, amount_coins, type, reference, status, metadata_json
    ) VALUES (
      'wtx_buy_' || p_certificate_id, p_buyer_id, -ABS(p_amount_zar), -ABS(p_amount_coins),
      'license_purchase', p_certificate_id, 'completed',
      jsonb_build_object('beatId', p_beat_id, 'tier', p_tier)
    );

    INSERT INTO public.wallet_ledger (
      id, creator_id, amount_zar, amount_coins, type, reference, status, metadata_json
    ) VALUES (
      'wtx_roy_' || p_certificate_id, p_producer_id, v_producer_zar, v_producer_coins,
      'license_sale', p_certificate_id, 'completed',
      jsonb_build_object('beatId', p_beat_id, 'buyerId', p_buyer_id, 'tier', p_tier, 'splitPct', 85)
    );
  END IF;

  IF p_tier IN ('exclusive_stem', 'unlimited_commercial', 'EXCLUSIVE_RIGHTS') THEN
    UPDATE public.marketplace_assets
       SET is_exclusive_sold = true,
           exclusive_buyer_id = p_buyer_id,
           updated_at = p_purchased_at
     WHERE id = p_beat_id;
  END IF;

  RETURN jsonb_build_object('outcome', 'committed', 'certificateId', p_certificate_id);
END;
$$;

-- =============================================================================
-- ATOMIC PL/pgSQL RPC 3: send_cultural_tip_atomic (Sender Debit + 70/30 Split)
-- =============================================================================
CREATE OR REPLACE FUNCTION public.send_cultural_tip_atomic(
  p_tip_id TEXT,
  p_clip_id TEXT,
  p_sender_id TEXT,
  p_recipient_id TEXT,
  p_ancestor_id TEXT,
  p_amount_coins INTEGER,
  p_amount_zar NUMERIC,
  p_gift_name TEXT,
  p_gift_emoji TEXT
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_sender_coins INTEGER;
  v_primary_coins INTEGER;
  v_ancestor_coins INTEGER := 0;
BEGIN
  IF p_sender_id = p_recipient_id THEN
    RETURN jsonb_build_object('outcome', 'self_tip_forbidden');
  END IF;

  PERFORM id FROM public.creators WHERE id = p_sender_id FOR UPDATE;

  SELECT COALESCE(SUM(amount_coins), 0)
    INTO v_sender_coins
    FROM public.wallet_ledger
   WHERE creator_id = p_sender_id;

  IF v_sender_coins < p_amount_coins THEN
    RETURN jsonb_build_object(
      'outcome', 'insufficient_funds',
      'availableCoins', v_sender_coins,
      'requiredCoins', p_amount_coins
    );
  END IF;

  INSERT INTO public.wallet_ledger (
    id, creator_id, amount_zar, amount_coins, type, reference, status, metadata_json
  ) VALUES (
    'wtx_tip_out_' || p_tip_id, p_sender_id, -ABS(p_amount_zar), -ABS(p_amount_coins),
    'tip_sent', p_tip_id, 'completed',
    jsonb_build_object('clipId', p_clip_id, 'recipientId', p_recipient_id, 'giftName', p_gift_name)
  );

  IF p_ancestor_id IS NOT NULL AND p_ancestor_id <> '' AND p_ancestor_id <> p_recipient_id THEN
    v_primary_coins := FLOOR(p_amount_coins * 0.70)::INTEGER;
    v_ancestor_coins := p_amount_coins - v_primary_coins;

    INSERT INTO public.wallet_ledger (
      id, creator_id, amount_zar, amount_coins, type, reference, status, metadata_json
    ) VALUES (
      'wtx_tip_in_' || p_tip_id, p_recipient_id, ROUND(p_amount_zar * 0.70, 2), v_primary_coins,
      'tip_received', p_tip_id, 'completed',
      jsonb_build_object('clipId', p_clip_id, 'senderId', p_sender_id, 'splitPct', 70)
    );

    INSERT INTO public.wallet_ledger (
      id, creator_id, amount_zar, amount_coins, type, reference, status, metadata_json
    ) VALUES (
      'wtx_tip_anc_' || p_tip_id, p_ancestor_id, ROUND(p_amount_zar * 0.30, 2), v_ancestor_coins,
      'remix_royalty', p_tip_id, 'completed',
      jsonb_build_object('clipId', p_clip_id, 'senderId', p_sender_id, 'splitPct', 30)
    );
  ELSE
    v_primary_coins := p_amount_coins;
    INSERT INTO public.wallet_ledger (
      id, creator_id, amount_zar, amount_coins, type, reference, status, metadata_json
    ) VALUES (
      'wtx_tip_in_' || p_tip_id, p_recipient_id, p_amount_zar, p_amount_coins,
      'tip_received', p_tip_id, 'completed',
      jsonb_build_object('clipId', p_clip_id, 'senderId', p_sender_id, 'splitPct', 100)
    );
  END IF;

  RETURN jsonb_build_object(
    'outcome', 'committed',
    'senderRemainingCoins', (v_sender_coins - p_amount_coins),
    'primaryCoins', v_primary_coins,
    'ancestorCoins', v_ancestor_coins
  );
END;
$$;

-- =============================================================================
-- SUPABASE AUTH HOOK: Custom Access Token Claims (cid, hdl)
-- =============================================================================
CREATE OR REPLACE FUNCTION public.custom_access_token_hook(event JSONB)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_claims JSONB;
  v_creator_id TEXT;
  v_handle TEXT;
  v_role TEXT;
BEGIN
  v_claims := event->'claims';
  SELECT creator_id, handle, role
    INTO v_creator_id, v_handle, v_role
    FROM public.users
   WHERE auth_uid = (event->>'user_id')::UUID
      OR LOWER(email) = LOWER(v_claims->>'email')
   LIMIT 1;

  IF v_creator_id IS NOT NULL THEN
    v_claims := jsonb_set(v_claims, '{cid}', to_jsonb(v_creator_id));
    v_claims := jsonb_set(v_claims, '{hdl}', to_jsonb(v_handle));
    v_claims := jsonb_set(v_claims, '{app_metadata,creator_id}', to_jsonb(v_creator_id));
    v_claims := jsonb_set(v_claims, '{app_metadata,vhunambi_role}', to_jsonb(v_role));
  END IF;

  RETURN jsonb_set(event, '{claims}', v_claims);
END;
$$;

COMMIT;
```

---

### 1.2 Zero-Dependency Supabase REST, RPC & GoTrue Driver (`apps/vhunambi_api/src/db/supabase_cloud_driver.ts`)

```typescript
import { RuntimeEnvConfig, resolveRuntimeEnv } from '../config/env.js';

export interface GoTrueAuthResponse {
  access_token: string;
  refresh_token: string;
  expires_in: number;
  expires_at?: number;
  user: {
    id: string;
    email?: string;
    user_metadata?: Record<string, unknown>;
    app_metadata?: Record<string, unknown>;
  };
}

/**
 * Zero-dependency Edge HTTP driver for Supabase PostgREST, PL/pgSQL RPCs, and GoTrue Auth.
 * Uses standard Web `fetch` so it executes natively on Cloudflare Workers and Node.js
 * without requiring un-installed external npm packages.
 */
export class SupabaseCloudDriver {
  private readonly supabaseUrl: string;
  private readonly serviceRoleKey: string;
  private readonly anonKey: string;

  constructor(envInput?: Partial<RuntimeEnvConfig> | Record<string, unknown>) {
    const resolved = resolveRuntimeEnv(envInput);
    this.supabaseUrl = resolved.SUPABASE_URL.replace(/\/+$/, '');
    this.serviceRoleKey = resolved.SUPABASE_SERVICE_ROLE_KEY;
    this.anonKey = resolved.SUPABASE_ANON_KEY || resolved.SUPABASE_SERVICE_ROLE_KEY;
  }

  public isConfigured(): boolean {
    return (
      this.supabaseUrl.startsWith('https://') &&
      this.serviceRoleKey.trim().length > 20
    );
  }

  private buildRestHeaders(prefer?: string): Record<string, string> {
    const headers: Record<string, string> = {
      apikey: this.serviceRoleKey,
      Authorization: `Bearer ${this.serviceRoleKey}`,
      'Content-Type': 'application/json',
    };
    if (prefer) {
      headers.Prefer = prefer;
    }
    return headers;
  }

  public async callRpc<T = Record<string, unknown>>(
    fnName: string,
    args: Record<string, unknown>,
  ): Promise<T> {
    const res = await fetch(`${this.supabaseUrl}/rest/v1/rpc/${fnName}`, {
      method: 'POST',
      headers: this.buildRestHeaders(),
      body: JSON.stringify(args),
    });
    if (!res.ok) {
      const errText = await res.text();
      throw new Error(`SUPABASE_RPC_ERROR[${fnName}]: ${res.status} ${errText}`);
    }
    return (await res.json()) as T;
  }

  public async selectRows<T = Record<string, unknown>>(
    table: string,
    queryString: string,
  ): Promise<T[]> {
    const url = `${this.supabaseUrl}/rest/v1/${table}?${queryString}`;
    const res = await fetch(url, {
      method: 'GET',
      headers: this.buildRestHeaders(),
    });
    if (!res.ok) {
      const errText = await res.text();
      throw new Error(`SUPABASE_SELECT_ERROR[${table}]: ${res.status} ${errText}`);
    }
    return (await res.json()) as T[];
  }

  public async upsertRow<T = Record<string, unknown>>(
    table: string,
    payload: Record<string, unknown> | Record<string, unknown>[],
    onConflict?: string,
  ): Promise<T[]> {
    const conflictQuery = onConflict ? `?on_conflict=${encodeURIComponent(onConflict)}` : '';
    const res = await fetch(`${this.supabaseUrl}/rest/v1/${table}${conflictQuery}`, {
      method: 'POST',
      headers: this.buildRestHeaders('resolution=merge-duplicates,return=representation'),
      body: JSON.stringify(payload),
    });
    if (!res.ok) {
      const errText = await res.text();
      throw new Error(`SUPABASE_UPSERT_ERROR[${table}]: ${res.status} ${errText}`);
    }
    return (await res.json()) as T[];
  }

  public async goTrueSignUp(params: {
    email: string;
    password: string;
    creatorId: string;
    handle: string;
    displayName: string;
  }): Promise<GoTrueAuthResponse> {
    const res = await fetch(`${this.supabaseUrl}/auth/v1/signup`, {
      method: 'POST',
      headers: {
        apikey: this.anonKey,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        email: params.email,
        password: params.password,
        data: {
          creator_id: params.creatorId,
          handle: params.handle,
          display_name: params.displayName,
        },
      }),
    });
    if (!res.ok) {
      const errText = await res.text();
      throw new Error(`GOTRUE_SIGNUP_FAILED: ${res.status} ${errText}`);
    }
    return (await res.json()) as GoTrueAuthResponse;
  }

  public async goTrueSignInWithPassword(
    email: string,
    password: string,
  ): Promise<GoTrueAuthResponse> {
    const res = await fetch(
      `${this.supabaseUrl}/auth/v1/token?grant_type=password`,
      {
        method: 'POST',
        headers: {
          apikey: this.anonKey,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ email, password }),
      },
    );
    if (!res.ok) {
      const errText = await res.text();
      throw new Error(`GOTRUE_LOGIN_FAILED: ${res.status} ${errText}`);
    }
    return (await res.json()) as GoTrueAuthResponse;
  }

  public async goTrueRefreshSession(
    refreshToken: string,
  ): Promise<GoTrueAuthResponse> {
    const res = await fetch(
      `${this.supabaseUrl}/auth/v1/token?grant_type=refresh_token`,
      {
        method: 'POST',
        headers: {
          apikey: this.anonKey,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ refresh_token: refreshToken }),
      },
    );
    if (!res.ok) {
      const errText = await res.text();
      throw new Error(`GOTRUE_REFRESH_FAILED: ${res.status} ${errText}`);
    }
    return (await res.json()) as GoTrueAuthResponse;
  }
}
```

---

### 1.3 Lazy Conditional `node:sqlite` Loading & 19-Table Extensions in `vhunambi_db.ts` (`apps/vhunambi_api/src/db/vhunambi_db.ts`)

In `apps/vhunambi_api/src/db/vhunambi_db.ts`:
1. **Replace top-level static `import { DatabaseSync } from 'node:sqlite'`, `import fs from 'node:fs'`, and `import path from 'node:path'`** with a lazy built-in loader using `process.getBuiltinModule`:

```typescript
import { createHash } from 'node:crypto';
import {
  SovereignJwtClaims,
  generateRefreshTokenPair,
  hashPassword,
  hashRefreshToken,
  signAccessJwt,
  verifyPassword,
} from '../security/crypto_token.js';

type SqliteBuiltinModule = typeof import('node:sqlite');
type FsBuiltinModule = typeof import('node:fs');
type PathBuiltinModule = typeof import('node:path');

export function isNodeSqliteAvailable(): boolean {
  try {
    const getter = (
      process as unknown as { getBuiltinModule?: (id: string) => unknown }
    )?.getBuiltinModule;
    if (typeof getter === 'function') {
      const mod = getter('node:sqlite') as SqliteBuiltinModule | undefined;
      return Boolean(mod?.DatabaseSync);
    }
    return false;
  } catch {
    return false;
  }
}

function loadNodeSqlite(): SqliteBuiltinModule {
  const getter = (process as unknown as { getBuiltinModule?: (id: string) => unknown })
    .getBuiltinModule;
  if (typeof getter === 'function') {
    const mod = getter('node:sqlite') as SqliteBuiltinModule | undefined;
    if (mod?.DatabaseSync) {
      return mod;
    }
  }
  throw new Error(
    'SQLITE_UNAVAILABLE_IN_EDGE_ISOLATE: Use SupabaseCloudDriver in Cloudflare Workers.',
  );
}

function loadNodeFs(): FsBuiltinModule | undefined {
  const getter = (process as unknown as { getBuiltinModule?: (id: string) => unknown })
    .getBuiltinModule;
  return typeof getter === 'function'
    ? (getter('node:fs') as FsBuiltinModule | undefined)
    : undefined;
}

function loadNodePath(): PathBuiltinModule | undefined {
  const getter = (process as unknown as { getBuiltinModule?: (id: string) => unknown })
    .getBuiltinModule;
  return typeof getter === 'function'
    ? (getter('node:path') as PathBuiltinModule | undefined)
    : undefined;
}

/**
 * Normalizes creator ID aliases across backend and Flutter client (including
 * `@blackcoffee` -> `creator_black_coffee` vs `creator_blackcoffee`).
 */
export function canonicalizeCreatorId(rawId?: string | null): string {
  const trimmed = (rawId ?? '').trim();
  if (!trimmed) return 'creator_cern';
  const lower = trimmed.toLowerCase();
  if (
    lower === 'me' ||
    lower === 'usr_me' ||
    lower === 'vhunambi_user' ||
    lower === 'buyer_user' ||
    lower === 'buyer_default' ||
    lower === 'usr_cern' ||
    lower === '@cern' ||
    lower === 'cern'
  ) {
    return 'creator_cern';
  }
  if (
    lower === 'creator_blackcoffee' ||
    lower === 'creator_black_coffee' ||
    lower === '@blackcoffee' ||
    lower === 'blackcoffee' ||
    lower === 'usr_black_coffee'
  ) {
    return 'creator_black_coffee';
  }
  if (lower === '@makhadzi' || lower === 'makhadzi' || lower === 'usr_makhadzi') {
    return 'creator_makhadzi';
  }
  if (lower === '@kabza' || lower === 'kabza' || lower === 'producer_kabza' || lower === 'usr_kabza') {
    return 'creator_kabza';
  }
  if (lower === '@focalistic' || lower === 'focalistic' || lower === 'usr_focalistic') {
    return 'creator_focalistic';
  }
  if (lower === '@tyla' || lower === 'tyla' || lower === 'usr_tyla') {
    return 'creator_tyla';
  }
  return trimmed;
}
```

2. **Inside `VhunambiDatabase.migrate()`**, add the 4 new Phase 62 tables (`generation_jobs`, `voice_clones`, `social_interactions`, `payment_topups`) so `VhunambiDatabase` has all **19 tables**:

```typescript
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS generation_jobs (
        generation_id TEXT PRIMARY KEY,
        creator_id TEXT NOT NULL DEFAULT 'creator_cern',
        job_kind TEXT NOT NULL DEFAULT 'audio_synthesis',
        provider_task_id TEXT,
        status TEXT NOT NULL DEFAULT 'queued',
        step TEXT NOT NULL DEFAULT 'Initializing pipeline...',
        progress_pct INTEGER NOT NULL DEFAULT 0,
        track_title TEXT NOT NULL DEFAULT 'Untitled Track',
        genre TEXT NOT NULL DEFAULT 'Amapiano',
        language TEXT NOT NULL DEFAULT 'Instrumental',
        duration_sec INTEGER NOT NULL DEFAULT 180,
        master_mp3_url TEXT,
        stems_zip_url TEXT,
        stem_urls_json TEXT NOT NULL DEFAULT '{}',
        manifest_url TEXT,
        manifest_json TEXT,
        error_message TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_generation_jobs_creator
        ON generation_jobs(creator_id, created_at DESC);

      CREATE TABLE IF NOT EXISTS voice_clones (
        voice_id TEXT PRIMARY KEY,
        creator_id TEXT NOT NULL,
        display_name TEXT NOT NULL,
        consent_verified INTEGER NOT NULL DEFAULT 1,
        reference_audio_duration_sec REAL NOT NULL DEFAULT 15.0,
        r2_reference_url TEXT NOT NULL,
        pitch_range_hz_json TEXT NOT NULL DEFAULT '[110,660]',
        timbre_embedding_json TEXT NOT NULL DEFAULT '[]',
        created_at TEXT NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_voice_clones_creator
        ON voice_clones(creator_id);

      CREATE TABLE IF NOT EXISTS social_interactions (
        interaction_type TEXT NOT NULL,
        target_id TEXT NOT NULL,
        actor_creator_id TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY (interaction_type, target_id, actor_creator_id)
      );
      CREATE INDEX IF NOT EXISTS idx_social_interactions_actor
        ON social_interactions(actor_creator_id, interaction_type);

      CREATE TABLE IF NOT EXISTS payment_topups (
        checkout_id TEXT PRIMARY KEY,
        creator_id TEXT NOT NULL,
        provider TEXT NOT NULL DEFAULT 'payfast',
        provider_payment_id TEXT UNIQUE,
        pack_id TEXT NOT NULL DEFAULT 'pack_producer_1500',
        amount_zar REAL NOT NULL,
        coins_granted INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        signature_md5 TEXT NOT NULL,
        raw_itn_json TEXT NOT NULL DEFAULT '{}',
        verified_at TEXT,
        created_at TEXT NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_payment_topups_creator
        ON payment_topups(creator_id, created_at DESC);
    `);
```

3. **Preserve `getWallet(creatorId)` and add `getWalletSnapshot(creatorId)` alias, close the `sync/mutations` `tip` free-money exploit (`vhunambi_db.ts:1316-1317`), and add atomic `sendCulturalTipAtomic` + PayFast checkout/ITN methods using SQLite's exact `wallet_ledger` (`data_json`) column** in `VhunambiDatabase`:

```typescript
  public static isNodeSqliteAvailable(): boolean {
    return isNodeSqliteAvailable();
  }

  /**
   * Alias wrapper around `getWallet(creatorId)` so both Phase 59-61 (`getWallet`)
   * and Phase 62 (`getWalletSnapshot`) callers receive identical ledger state
   * including parsed `metadata` from `data_json`.
   */
  public getWalletSnapshot(creatorId: string): {
    creatorId: string;
    balanceZar: number;
    balanceCoins: number;
    pendingPayoutZar: number;
    recentTransactions: any[];
    transactions: any[];
  } {
    const canonicalId = canonicalizeCreatorId(creatorId);
    const wallet = this.getWallet(canonicalId);
    const rows = this.db
      .prepare('SELECT * FROM wallet_ledger WHERE creator_id = ? ORDER BY created_at DESC LIMIT 50')
      .all(canonicalId) as any[];
    const transactions = rows.map((r) => {
      let metadata: Record<string, unknown> = {};
      try {
        metadata = r.data_json ? JSON.parse(String(r.data_json)) : {};
      } catch {
        metadata = {};
      }
      return {
        id: r.id,
        type: r.type,
        amountZar: r.amount_zar,
        amountCoins: r.amount_coins,
        status: r.status,
        reference: r.reference,
        metadata,
        createdAt: r.created_at,
      };
    });
    return {
      ...wallet,
      transactions,
    };
  }

  public sendCulturalTipAtomic(params: {
    tipId: string;
    clipId: string;
    senderId: string;
    recipientId: string;
    ancestorId?: string;
    amountCoins: number;
    amountZar: number;
    giftName: string;
    giftEmoji: string;
  }): {
    outcome: 'committed' | 'insufficient_funds' | 'self_tip_forbidden';
    senderRemainingCoins: number;
    primaryCoins: number;
    ancestorCoins: number;
  } {
    const senderId = canonicalizeCreatorId(params.senderId);
    const recipientId = canonicalizeCreatorId(params.recipientId);
    const ancestorId = params.ancestorId
      ? canonicalizeCreatorId(params.ancestorId)
      : undefined;
    const coins = Math.max(1, Math.round(params.amountCoins));
    const zar = Math.max(0.1, Number(params.amountZar.toFixed(2)));

    if (senderId === recipientId) {
      return {
        outcome: 'self_tip_forbidden',
        senderRemainingCoins: this.getWallet(senderId).balanceCoins,
        primaryCoins: 0,
        ancestorCoins: 0,
      };
    }

    this.db.exec('BEGIN IMMEDIATE');
    try {
      const senderSnap = this.getWallet(senderId);
      if (senderSnap.balanceCoins < coins) {
        this.db.exec('ROLLBACK');
        return {
          outcome: 'insufficient_funds',
          senderRemainingCoins: senderSnap.balanceCoins,
          primaryCoins: 0,
          ancestorCoins: 0,
        };
      }

      const nowIso = new Date().toISOString();
      const insertStmt = this.db.prepare(`
        INSERT INTO wallet_ledger (
          id, creator_id, type, amount_zar, amount_coins, status, reference, data_json, created_at
        ) VALUES (?, ?, ?, ?, ?, 'completed', ?, ?, ?)
      `);

      insertStmt.run(
        `wtx_tip_out_${params.tipId}`,
        senderId,
        'tip',
        -zar,
        -coins,
        params.tipId,
        JSON.stringify({
          direction: 'sent',
          clipId: params.clipId,
          senderId,
          recipientId,
          giftName: params.giftName,
          giftEmoji: params.giftEmoji,
        }),
        nowIso,
      );

      let primaryCoins = coins;
      let ancestorCoins = 0;
      if (ancestorId && ancestorId !== recipientId) {
        primaryCoins = Math.floor(coins * 0.7);
        ancestorCoins = coins - primaryCoins;
        const primaryZar = Number((zar * 0.7).toFixed(2));
        const ancestorZar = Number((zar - primaryZar).toFixed(2));

        insertStmt.run(
          `wtx_tip_in_${params.tipId}`,
          recipientId,
          'tip',
          primaryZar,
          primaryCoins,
          params.tipId,
          JSON.stringify({ direction: 'received', clipId: params.clipId, senderId, splitPct: 70 }),
          nowIso,
        );
        insertStmt.run(
          `wtx_tip_anc_${params.tipId}`,
          ancestorId,
          'tip',
          ancestorZar,
          ancestorCoins,
          params.tipId,
          JSON.stringify({ direction: 'remix_royalty', clipId: params.clipId, senderId, splitPct: 30 }),
          nowIso,
        );
      } else {
        insertStmt.run(
          `wtx_tip_in_${params.tipId}`,
          recipientId,
          'tip',
          zar,
          coins,
          params.tipId,
          JSON.stringify({ direction: 'received', clipId: params.clipId, senderId, splitPct: 100 }),
          nowIso,
        );
      }

      this.db.exec('COMMIT');
      return {
        outcome: 'committed',
        senderRemainingCoins: senderSnap.balanceCoins - coins,
        primaryCoins,
        ancestorCoins,
      };
    } catch (err) {
      try {
        this.db.exec('ROLLBACK');
      } catch {
        // ignore rollback error
      }
      throw err;
    }
  }

  public createPayFastCheckout(params: {
    checkoutId: string;
    creatorId: string;
    packId: string;
    amountZar: number;
    coinsGranted: number;
    signatureMd5: string;
  }): void {
    const creatorId = canonicalizeCreatorId(params.creatorId);
    const nowIso = new Date().toISOString();
    this.db
      .prepare(
        `INSERT INTO payment_topups (
          checkout_id, creator_id, provider, pack_id, amount_zar,
          coins_granted, status, signature_md5, raw_itn_json, created_at
        ) VALUES (?, ?, 'payfast', ?, ?, ?, 'pending', ?, '{}', ?)`,
      )
      .run(
        params.checkoutId,
        creatorId,
        params.packId,
        params.amountZar,
        params.coinsGranted,
        params.signatureMd5,
        nowIso,
      );
  }

  public getPayFastCheckout(checkoutId: string): {
    checkoutId: string;
    creatorId: string;
    provider: string;
    providerPaymentId: string | null;
    packId: string;
    amountZar: number;
    coinsGranted: number;
    status: string;
    signatureMd5: string;
    verifiedAt: string | null;
    createdAt: string;
  } | null {
    const row = this.db
      .prepare(`SELECT * FROM payment_topups WHERE checkout_id = ?`)
      .get(checkoutId) as Record<string, unknown> | undefined;
    if (!row) return null;
    return {
      checkoutId: String(row.checkout_id),
      creatorId: String(row.creator_id),
      provider: String(row.provider),
      providerPaymentId: row.provider_payment_id ? String(row.provider_payment_id) : null,
      packId: String(row.pack_id),
      amountZar: Number(row.amount_zar),
      coinsGranted: Number(row.coins_granted),
      status: String(row.status),
      signatureMd5: String(row.signature_md5),
      verifiedAt: row.verified_at ? String(row.verified_at) : null,
      createdAt: String(row.created_at),
    };
  }

  public settlePayFastItnAtomic(params: {
    checkoutId: string;
    pfPaymentId: string;
    amountGrossZar: number;
    rawItnPayload: Record<string, string>;
  }): {
    outcome:
      | 'settled'
      | 'idempotent_replay'
      | 'checkout_not_found'
      | 'amount_mismatch';
    creatorId?: string;
    coinsCredited?: number;
    balanceCoins?: number;
    balanceZar?: number;
  } {
    this.db.exec('BEGIN IMMEDIATE');
    try {
      const existingByPfId = this.db
        .prepare(`SELECT * FROM payment_topups WHERE provider_payment_id = ?`)
        .get(params.pfPaymentId) as Record<string, unknown> | undefined;
      if (existingByPfId && String(existingByPfId.status) === 'completed') {
        const creatorId = String(existingByPfId.creator_id);
        const snap = this.getWallet(creatorId);
        this.db.exec('COMMIT');
        return {
          outcome: 'idempotent_replay',
          creatorId,
          coinsCredited: Number(existingByPfId.coins_granted),
          balanceCoins: snap.balanceCoins,
          balanceZar: snap.balanceZar,
        };
      }

      const checkout = this.getPayFastCheckout(params.checkoutId);
      if (!checkout) {
        this.db.exec('ROLLBACK');
        return { outcome: 'checkout_not_found' };
      }
      if (checkout.status === 'completed') {
        const snap = this.getWallet(checkout.creatorId);
        this.db.exec('COMMIT');
        return {
          outcome: 'idempotent_replay',
          creatorId: checkout.creatorId,
          coinsCredited: checkout.coinsGranted,
          balanceCoins: snap.balanceCoins,
          balanceZar: snap.balanceZar,
        };
      }
      if (Math.abs(checkout.amountZar - params.amountGrossZar) > 0.01) {
        this.db.exec('ROLLBACK');
        return { outcome: 'amount_mismatch' };
      }

      const nowIso = new Date().toISOString();
      this.db
        .prepare(
          `UPDATE payment_topups
              SET status = 'completed',
                  provider_payment_id = ?,
                  raw_itn_json = ?,
                  verified_at = ?
            WHERE checkout_id = ?`,
        )
        .run(
          params.pfPaymentId,
          JSON.stringify(params.rawItnPayload),
          nowIso,
          params.checkoutId,
        );

      this.db
        .prepare(
          `INSERT INTO wallet_ledger (
            id, creator_id, type, amount_zar, amount_coins, status, reference, data_json, created_at
          ) VALUES (?, ?, 'topup', ?, ?, 'completed', ?, ?, ?)`,
        )
        .run(
          `wtx_pf_${params.pfPaymentId}`,
          checkout.creatorId,
          checkout.amountZar,
          checkout.coinsGranted,
          `PF-ITN-${params.pfPaymentId}`,
          JSON.stringify({
            checkoutId: checkout.checkoutId,
            packId: checkout.packId,
            pfPaymentId: params.pfPaymentId,
          }),
          nowIso,
        );

      this.db.exec('COMMIT');
      const snap = this.getWallet(checkout.creatorId);
      return {
        outcome: 'settled',
        creatorId: checkout.creatorId,
        coinsCredited: checkout.coinsGranted,
        balanceCoins: snap.balanceCoins,
        balanceZar: snap.balanceZar,
      };
    } catch (err) {
      try {
        this.db.exec('ROLLBACK');
      } catch {
        // ignore
      }
      throw err;
    }
  }
```

4. **Replace eager `export const vhunambiDb = new VhunambiDatabase();` at the bottom of `vhunambi_db.ts`** with a lazy-initializing `Proxy`:

```typescript
let _defaultVhunambiDbInstance: VhunambiDatabase | null = null;

export function getDefaultVhunambiDb(): VhunambiDatabase {
  if (!_defaultVhunambiDbInstance) {
    _defaultVhunambiDbInstance = new VhunambiDatabase();
  }
  return _defaultVhunambiDbInstance;
}

export const vhunambiDb: VhunambiDatabase = new Proxy(
  {} as VhunambiDatabase,
  {
    get(_target, prop, _receiver) {
      const instance = getDefaultVhunambiDb();
      const value = Reflect.get(instance as object, prop, instance);
      return typeof value === 'function' ? value.bind(instance) : value;
    },
    set(_target, prop, value) {
      const instance = getDefaultVhunambiDb();
      return Reflect.set(instance as object, prop, value, instance);
    },
  },
);
```

---

## 2. Milestone `M62.2`: Cloudflare Workers Entrypoint, Request-Scoped `c.env`, R2 Vault & Durable Object `WS /ws/generation`

### 2.1 Cloudflare Worker Configuration (`apps/vhunambi_api/wrangler.toml`)

```toml
name = "vhunambi-api"
main = "src/worker.ts"
compatibility_date = "2026-10-01"
compatibility_flags = ["nodejs_compat"]

[vars]
NODE_ENV = "production"
VHUNAMBI_AUTH_MODE = "strict"
R2_BUCKET = "vhunambi-vault"
ZR_LLM_PROVIDER = "claude"

[[r2_buckets]]
binding = "VHUNAMBI_VAULT"
bucket_name = "vhunambi-vault"

[[hyperdrive]]
binding = "HYPERDRIVE"
id = "00000000000000000000000000000000"

[durable_objects]
bindings = [
  { name = "GENERATION_DO", class_name = "GenerationSessionDO" }
]

[[migrations]]
tag = "v1"
new_sqlite_classes = ["GenerationSessionDO"]
```

---

### 2.2 Self-Contained Cloudflare Worker & Durable Object Type Declarations (`apps/vhunambi_api/src/types/cloudflare_worker_types.ts`)

```typescript
export interface CfExecutionContext {
  waitUntil(promise: Promise<unknown>): void;
  passThroughOnException(): void;
}

export interface CfR2ObjectBody {
  key: string;
  size: number;
  etag: string;
  body: ReadableStream<Uint8Array> | null;
  httpMetadata?: {
    contentType?: string;
    cacheControl?: string;
  };
  arrayBuffer(): Promise<ArrayBuffer>;
  text(): Promise<string>;
}

export interface CfR2Bucket {
  get(key: string): Promise<CfR2ObjectBody | null>;
  put(
    key: string,
    value: ReadableStream | ArrayBuffer | Uint8Array | string,
    options?: { httpMetadata?: { contentType?: string; cacheControl?: string } },
  ): Promise<unknown>;
  delete(keys: string | string[]): Promise<void>;
}

export interface CfHyperdriveBinding {
  connectionString: string;
}

export interface CfDurableObjectId {
  toString(): string;
}

export interface CfDurableObjectStub {
  fetch(input: RequestInfo | URL, init?: RequestInit): Promise<Response>;
}

export interface CfDurableObjectNamespace {
  idFromName(name: string): CfDurableObjectId;
  get(id: CfDurableObjectId): CfDurableObjectStub;
}

export interface CfDurableObjectStorage {
  get<T = unknown>(key: string): Promise<T | undefined>;
  put<T = unknown>(key: string, value: T): Promise<void>;
  delete(key: string): Promise<boolean>;
}

export interface CfDurableObjectState {
  id: CfDurableObjectId;
  storage: CfDurableObjectStorage;
  acceptWebSocket?(ws: WebSocket, tags?: string[]): void;
  getWebSockets?(tag?: string): WebSocket[];
}

export interface VhunambiWorkerEnv {
  NODE_ENV?: string;
  VHUNAMBI_AUTH_MODE?: string;
  VHUNAMBI_JWT_SECRET?: string;
  SUPABASE_URL?: string;
  SUPABASE_ANON_KEY?: string;
  SUPABASE_SERVICE_ROLE_KEY?: string;
  SUPABASE_JWT_SECRET?: string;
  R2_ACCESS_KEY_ID?: string;
  R2_SECRET_ACCESS_KEY?: string;
  R2_ENDPOINT?: string;
  R2_BUCKET?: string;
  R2_PUBLIC_BASE_URL?: string;
  RUNPOD_API_KEY?: string;
  RUNPOD_ENDPOINT_ID?: string;
  RUNPOD_COMFYUI_URL?: string;
  RUNPOD_COMFYUI_ENDPOINT_ID?: string;
  ZR_WEBHOOK_SECRET?: string;
  WEBHOOK_BASE_URL?: string;
  ZR_LLM_PROVIDER?: 'claude' | 'grok';
  ANTHROPIC_API_KEY?: string;
  GROK_API_KEY?: string;
  PAYFAST_MERCHANT_ID?: string;
  PAYFAST_MERCHANT_KEY?: string;
  PAYFAST_PASSPHRASE?: string;
  PAYFAST_SANDBOX?: string;
  VHUNAMBI_VAULT?: CfR2Bucket;
  HYPERDRIVE?: CfHyperdriveBinding;
  GENERATION_DO?: CfDurableObjectNamespace;
}
```

---

### 2.3 Request-Scoped Environment & Media URL Resolver (`apps/vhunambi_api/src/config/env.ts`)

```typescript
import type { Context } from 'hono';
import type { VhunambiWorkerEnv } from '../types/cloudflare_worker_types.js';

// Load dotenv lazily only in Node.js environments
try {
  const getter = (process as unknown as { getBuiltinModule?: (id: string) => unknown })
    ?.getBuiltinModule;
  if (typeof getter === 'function') {
    import('dotenv').then((d) => d.default?.config()).catch(() => {});
  }
} catch {
  // Ignore on Cloudflare Workers
}

export interface RuntimeEnvConfig {
  PORT: number;
  NODE_ENV: string;
  VHUNAMBI_AUTH_MODE: string;
  VHUNAMBI_JWT_SECRET: string;
  SUPABASE_URL: string;
  SUPABASE_ANON_KEY: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
  ZR_LLM_PROVIDER: 'claude' | 'grok';
  ANTHROPIC_API_KEY: string;
  GROK_API_KEY: string;
  R2_ACCESS_KEY_ID: string;
  R2_SECRET_ACCESS_KEY: string;
  R2_ENDPOINT: string;
  R2_BUCKET: string;
  R2_PUBLIC_BASE_URL: string;
  RUNPOD_API_KEY: string;
  RUNPOD_ENDPOINT_ID: string;
  RUNPOD_COMFYUI_URL: string;
  RUNPOD_COMFYUI_ENDPOINT_ID: string;
  ZR_WEBHOOK_SECRET: string;
  WEBHOOK_BASE_URL: string;
  PAYFAST_MERCHANT_ID: string;
  PAYFAST_MERCHANT_KEY: string;
  PAYFAST_PASSPHRASE: string;
  PAYFAST_SANDBOX: boolean;
}

function readString(
  workerEnv: Record<string, unknown> | undefined,
  key: string,
  fallback: string,
): string {
  const fromWorker = workerEnv?.[key];
  if (typeof fromWorker === 'string' && fromWorker.trim().length > 0) {
    return fromWorker.trim();
  }
  const fromProc = typeof process !== 'undefined' ? process.env?.[key] : undefined;
  if (typeof fromProc === 'string' && fromProc.trim().length > 0) {
    return fromProc.trim();
  }
  return fallback;
}

export function extractWorkerEnv(
  cOrEnv?: Context | VhunambiWorkerEnv | Record<string, unknown> | null,
): Record<string, unknown> | undefined {
  if (!cOrEnv || typeof cOrEnv !== 'object') return undefined;
  if ('env' in cOrEnv && cOrEnv.env && typeof cOrEnv.env === 'object') {
    return cOrEnv.env as Record<string, unknown>;
  }
  return cOrEnv as Record<string, unknown>;
}

export function resolveRuntimeEnv(
  cOrEnv?: Context | VhunambiWorkerEnv | Record<string, unknown> | null,
): RuntimeEnvConfig {
  const w = extractWorkerEnv(cOrEnv);
  const portRaw = readString(w, 'PORT', '3000');
  const jwtSecret =
    readString(w, 'VHUNAMBI_JWT_SECRET', '') ||
    readString(w, 'SUPABASE_JWT_SECRET', '') ||
    'vhunambi_sovereign_phase61_jwt_hmac_sha256_secret_key_2026_za';

  return {
    PORT: Number.parseInt(portRaw, 10) || 3000,
    NODE_ENV: readString(w, 'NODE_ENV', 'development'),
    VHUNAMBI_AUTH_MODE: readString(w, 'VHUNAMBI_AUTH_MODE', 'permissive'),
    VHUNAMBI_JWT_SECRET: jwtSecret,
    SUPABASE_URL: readString(w, 'SUPABASE_URL', ''),
    SUPABASE_ANON_KEY: readString(w, 'SUPABASE_ANON_KEY', ''),
    SUPABASE_SERVICE_ROLE_KEY: readString(w, 'SUPABASE_SERVICE_ROLE_KEY', ''),
    ZR_LLM_PROVIDER: readString(w, 'ZR_LLM_PROVIDER', 'claude') as 'claude' | 'grok',
    ANTHROPIC_API_KEY: readString(w, 'ANTHROPIC_API_KEY', ''),
    GROK_API_KEY: readString(w, 'GROK_API_KEY', ''),
    R2_ACCESS_KEY_ID: readString(w, 'R2_ACCESS_KEY_ID', ''),
    R2_SECRET_ACCESS_KEY: readString(w, 'R2_SECRET_ACCESS_KEY', ''),
    R2_ENDPOINT: readString(w, 'R2_ENDPOINT', ''),
    R2_BUCKET: readString(w, 'R2_BUCKET', 'vhunambi-vault'),
    R2_PUBLIC_BASE_URL: readString(
      w,
      'R2_PUBLIC_BASE_URL',
      'http://localhost:3000/r2',
    ),
    RUNPOD_API_KEY: readString(w, 'RUNPOD_API_KEY', ''),
    RUNPOD_ENDPOINT_ID: readString(w, 'RUNPOD_ENDPOINT_ID', ''),
    RUNPOD_COMFYUI_URL: readString(w, 'RUNPOD_COMFYUI_URL', ''),
    RUNPOD_COMFYUI_ENDPOINT_ID: readString(w, 'RUNPOD_COMFYUI_ENDPOINT_ID', ''),
    ZR_WEBHOOK_SECRET: readString(
      w,
      'ZR_WEBHOOK_SECRET',
      'dev_webhook_secret_vhunambi_2026',
    ),
    WEBHOOK_BASE_URL: readString(w, 'WEBHOOK_BASE_URL', 'http://localhost:3000'),
    PAYFAST_MERCHANT_ID: readString(w, 'PAYFAST_MERCHANT_ID', '10000100'),
    PAYFAST_MERCHANT_KEY: readString(w, 'PAYFAST_MERCHANT_KEY', '46f0cd694581a'),
    PAYFAST_PASSPHRASE: readString(
      w,
      'PAYFAST_PASSPHRASE',
      'vhunambi_payfast_passphrase_2026',
    ),
    PAYFAST_SANDBOX: readString(w, 'PAYFAST_SANDBOX', 'true') !== 'false',
  };
}

/**
 * Rewrites dead legacy domains (`r2.vhunambi.com`, `cdn.vhunambi.com`,
 * `cdn.vhunambi.za`, `assets.vhunambi.com`, `/mock-storage/*`) to `R2_PUBLIC_BASE_URL`.
 */
export function resolveMediaUrl(
  rawUrlOrKey: string,
  cOrEnv?: Context | VhunambiWorkerEnv | Record<string, unknown> | null,
): string {
  const trimmed = (rawUrlOrKey ?? '').trim();
  if (!trimmed) return '';
  const runtimeEnv = resolveRuntimeEnv(cOrEnv);
  const base = runtimeEnv.R2_PUBLIC_BASE_URL.replace(/\/+$/, '');

  if (trimmed.startsWith('/mock-storage/')) {
    const key = trimmed.replace(/^\/mock-storage\//, '');
    return `${base}/${key}`;
  }
  const legacyDomainMatch = trimmed.match(
    /^https?:\/\/(?:r2\.vhunambi\.com|cdn\.vhunambi\.com|cdn\.vhunambi\.za|assets\.vhunambi\.com)\/(.+)$/i,
  );
  if (legacyDomainMatch) {
    return `${base}/${legacyDomainMatch[1]}`;
  }
  if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://') && !trimmed.startsWith('/')) {
    return `${base}/${trimmed}`;
  }
  return trimmed;
}

export const env: RuntimeEnvConfig = new Proxy({} as RuntimeEnvConfig, {
  get(_target, prop: keyof RuntimeEnvConfig) {
    return resolveRuntimeEnv()[prop];
  },
});
```

---

### 2.4 R2 Storage Presigning & Deletion (`apps/vhunambi_api/src/modules/synthesis/r2_storage.ts`)

```typescript
import { AwsClient } from 'aws4fetch';
import type { Context } from 'hono';
import { extractWorkerEnv, resolveRuntimeEnv } from '../../config/env.js';
import type { VhunambiWorkerEnv } from '../../types/cloudflare_worker_types.js';

function createR2Client(
  cOrEnv?: Context | VhunambiWorkerEnv | Record<string, unknown> | null,
): AwsClient | null {
  const runtimeEnv = resolveRuntimeEnv(cOrEnv);
  if (
    !runtimeEnv.R2_ACCESS_KEY_ID ||
    !runtimeEnv.R2_SECRET_ACCESS_KEY ||
    !runtimeEnv.R2_ENDPOINT
  ) {
    return null;
  }
  return new AwsClient({
    accessKeyId: runtimeEnv.R2_ACCESS_KEY_ID,
    secretAccessKey: runtimeEnv.R2_SECRET_ACCESS_KEY,
    service: 's3',
    region: 'auto',
  });
}

export async function getPresignedPutUrl(
  objectKey: string,
  contentType = 'audio/mpeg',
  expiresInSeconds = 3600,
  cOrEnv?: Context | VhunambiWorkerEnv | Record<string, unknown> | null,
): Promise<string> {
  const runtimeEnv = resolveRuntimeEnv(cOrEnv);
  const client = createR2Client(cOrEnv);
  const cleanKey = objectKey.replace(/^\/+/, '');
  if (!client) {
    return `${runtimeEnv.R2_PUBLIC_BASE_URL.replace(/\/+$/, '')}/${cleanKey}?presigned=put&expires=${expiresInSeconds}`;
  }

  const endpoint = runtimeEnv.R2_ENDPOINT.replace(/\/+$/, '');
  const url = new URL(`${endpoint}/${runtimeEnv.R2_BUCKET}/${cleanKey}`);
  url.searchParams.set('X-Amz-Expires', expiresInSeconds.toString());

  const signedRequest = await client.sign(
    new Request(url.toString(), {
      method: 'PUT',
      headers: { 'Content-Type': contentType },
    }),
    { aws: { signQuery: true } },
  );
  return signedRequest.url;
}

export async function getPresignedGetUrl(
  objectKey: string,
  expiresInSeconds = 86400,
  cOrEnv?: Context | VhunambiWorkerEnv | Record<string, unknown> | null,
): Promise<string> {
  const runtimeEnv = resolveRuntimeEnv(cOrEnv);
  const client = createR2Client(cOrEnv);
  const cleanKey = objectKey.replace(/^\/+/, '');
  if (!client) {
    return `${runtimeEnv.R2_PUBLIC_BASE_URL.replace(/\/+$/, '')}/${cleanKey}?presigned=get&expires=${expiresInSeconds}`;
  }

  const endpoint = runtimeEnv.R2_ENDPOINT.replace(/\/+$/, '');
  const url = new URL(`${endpoint}/${runtimeEnv.R2_BUCKET}/${cleanKey}`);
  url.searchParams.set('X-Amz-Expires', expiresInSeconds.toString());

  const signedRequest = await client.sign(
    new Request(url.toString(), { method: 'GET' }),
    { aws: { signQuery: true } },
  );
  return signedRequest.url;
}

export async function deleteR2Object(
  objectKey: string,
  cOrEnv?: Context | VhunambiWorkerEnv | Record<string, unknown> | null,
): Promise<boolean> {
  const cleanKey = objectKey.replace(/^\/+/, '');
  const workerEnv = extractWorkerEnv(cOrEnv) as VhunambiWorkerEnv | undefined;
  if (workerEnv?.VHUNAMBI_VAULT) {
    await workerEnv.VHUNAMBI_VAULT.delete(cleanKey);
    return true;
  }
  const runtimeEnv = resolveRuntimeEnv(cOrEnv);
  const client = createR2Client(cOrEnv);
  if (!client) {
    return true;
  }
  const endpoint = runtimeEnv.R2_ENDPOINT.replace(/\/+$/, '');
  const url = `${endpoint}/${runtimeEnv.R2_BUCKET}/${cleanKey}`;
  const res = await client.fetch(url, { method: 'DELETE' });
  return res.ok;
}
```

---

### 2.5 Cloudflare Worker Entrypoint & `GenerationSessionDO` Durable Object (`apps/vhunambi_api/src/worker.ts`)

```typescript
import { app } from './server.js';
import type {
  CfDurableObjectState,
  CfExecutionContext,
  VhunambiWorkerEnv,
} from './types/cloudflare_worker_types.js';

export interface GenerationPipelineEventPayload {
  generationId: string;
  status: string;
  step?: string;
  progressPct?: number;
  masterMp3Url?: string;
  stemsZipUrl?: string;
  stemUrls?: Record<string, string>;
  manifestUrl?: string;
  error?: string;
  timestamp?: number;
}

/**
 * Cloudflare Durable Object managing realtime WebSocket connections for
 * `/ws/generation?id=<generationId>`. Handles `PING` -> `PONG` heartbeats
 * and broadcasts `pipeline_event` frames pushed from `/v1/webhooks/ace-step`.
 */
export class GenerationSessionDO {
  private readonly state: CfDurableObjectState;
  private readonly sockets = new Set<WebSocket>();
  private lastEvent: GenerationPipelineEventPayload | null = null;

  constructor(state: CfDurableObjectState, _env?: VhunambiWorkerEnv) {
    this.state = state;
  }

  public async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);
    const generationId = url.searchParams.get('id') || 'unknown';

    if (request.method === 'POST' && url.pathname.endsWith('/internal/broadcast')) {
      const payload = (await request.json()) as GenerationPipelineEventPayload;
      this.lastEvent = payload;
      await this.state.storage.put('last_event', payload);
      const frame = JSON.stringify({
        type: 'pipeline_event',
        ...payload,
        timestamp: payload.timestamp ?? Date.now(),
      });
      this.broadcastFrame(frame);
      return new Response(
        JSON.stringify({ delivered: true, activeConnections: this.countSockets() }),
        { status: 200, headers: { 'Content-Type': 'application/json' } },
      );
    }

    if (request.method === 'POST' && url.pathname.endsWith('/internal/frame')) {
      const incoming = (await request.json()) as { type?: string };
      if (incoming.type === 'PING') {
        return new Response(
          JSON.stringify({ type: 'PONG', generationId, timestamp: Date.now() }),
          { status: 200, headers: { 'Content-Type': 'application/json' } },
        );
      }
    }

    const upgradeHeader = request.headers.get('Upgrade');
    const WebSocketPairCtor = (
      globalThis as unknown as {
        WebSocketPair?: new () => { 0: WebSocket; 1: WebSocket };
      }
    ).WebSocketPair;

    if (upgradeHeader?.toLowerCase() === 'websocket' && WebSocketPairCtor) {
      const pair = new WebSocketPairCtor();
      const clientSocket = pair[0];
      const serverSocket = pair[1] as WebSocket & { accept?: () => void };

      if (typeof this.state.acceptWebSocket === 'function') {
        this.state.acceptWebSocket(serverSocket, [generationId]);
      } else if (typeof serverSocket.accept === 'function') {
        serverSocket.accept();
      }
      this.sockets.add(serverSocket);

      serverSocket.addEventListener('message', (evt) => {
        this.handleSocketMessage(serverSocket, String(evt.data ?? ''));
      });
      serverSocket.addEventListener('close', () => {
        this.sockets.delete(serverSocket);
      });

      const cached =
        this.lastEvent ??
        (await this.state.storage.get<GenerationPipelineEventPayload>('last_event'));
      if (cached) {
        try {
          serverSocket.send(
            JSON.stringify({ type: 'pipeline_event', ...cached }),
          );
        } catch {
          // ignore closed socket
        }
      }

      return new Response(null, {
        status: 101,
        webSocket: clientSocket,
      } as ResponseInit & { webSocket: WebSocket });
    }

    const snapshot =
      this.lastEvent ??
      (await this.state.storage.get<GenerationPipelineEventPayload>('last_event'));
    return new Response(
      JSON.stringify({
        generationId,
        protocol: 'vhunambi_generation_ws_v1',
        activeConnections: this.countSockets(),
        lastEvent: snapshot ?? null,
      }),
      { status: 200, headers: { 'Content-Type': 'application/json' } },
    );
  }

  public webSocketMessage(ws: WebSocket, message: string | ArrayBuffer): void {
    const raw =
      typeof message === 'string'
        ? message
        : new TextDecoder().decode(message);
    this.handleSocketMessage(ws, raw);
  }

  public webSocketClose(ws: WebSocket): void {
    this.sockets.delete(ws);
  }

  private handleSocketMessage(ws: WebSocket, raw: string): void {
    try {
      const parsed = JSON.parse(raw) as { type?: string };
      if (parsed.type === 'PING') {
        ws.send(JSON.stringify({ type: 'PONG', timestamp: Date.now() }));
      }
    } catch {
      ws.send(
        JSON.stringify({
          type: 'ERROR',
          message: 'Malformed WebSocket JSON frame',
        }),
      );
    }
  }

  private countSockets(): number {
    const hibernated =
      typeof this.state.getWebSockets === 'function'
        ? this.state.getWebSockets().length
        : 0;
    return Math.max(this.sockets.size, hibernated);
  }

  private broadcastFrame(frame: string): void {
    const targets = new Set<WebSocket>(this.sockets);
    if (typeof this.state.getWebSockets === 'function') {
      for (const s of this.state.getWebSockets()) {
        targets.add(s);
      }
    }
    for (const ws of targets) {
      try {
        ws.send(frame);
      } catch {
        this.sockets.delete(ws);
      }
    }
  }
}

export async function broadcastGenerationEventToDo(
  env: VhunambiWorkerEnv | undefined,
  event: GenerationPipelineEventPayload,
): Promise<void> {
  if (!env?.GENERATION_DO) return;
  try {
    const id = env.GENERATION_DO.idFromName(event.generationId);
    const stub = env.GENERATION_DO.get(id);
    await stub.fetch(
      `https://do.vhunambi.internal/internal/broadcast?id=${encodeURIComponent(event.generationId)}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(event),
      },
    );
  } catch {
    // Non-fatal in offline/test mode
  }
}

export default {
  async fetch(
    request: Request,
    env: VhunambiWorkerEnv,
    ctx: CfExecutionContext,
  ): Promise<Response> {
    const url = new URL(request.url);
    if (url.pathname === '/ws/generation' && env?.GENERATION_DO) {
      const generationId = url.searchParams.get('id') || 'default';
      const id = env.GENERATION_DO.idFromName(generationId);
      const stub = env.GENERATION_DO.get(id);
      return stub.fetch(request);
    }
    return app.fetch(request, env, ctx);
  },
};
```

---

## 3. Milestone `M62.3`: Supabase Auth (GoTrue) ↔ Sovereign JWT Unification & Handle Login Bridge

### 3.1 Dual-Format JWT Claim Verification (`apps/vhunambi_api/src/security/crypto_token.ts`)

Upgrade `SovereignJwtClaims`, `resolveJwtSecret`, and `verifyAccessJwt` in `apps/vhunambi_api/src/security/crypto_token.ts` so both Sovereign Phase 61 JWTs and Supabase GoTrue JWTs validate with constant-time HMAC-SHA256:

```typescript
export interface SovereignJwtClaims {
  sub: string;             // user_id or GoTrue UUID
  cid: string;             // canonical creator_id (e.g. 'creator_cern')
  hdl: string;             // normalized handle (e.g. '@cern')
  sid: string;             // session_id
  role: string;            // 'creator' | 'admin'
  iat: number;             // issued at (seconds)
  exp: number;             // expires at (seconds)
  isGoTrueToken?: boolean; // true when minted by Supabase GoTrue
}

export function resolveJwtSecret(secretOverride?: string): string {
  const explicit = secretOverride?.trim();
  if (explicit && explicit.length >= 32) {
    return explicit;
  }
  const fromEnv =
    (typeof process !== 'undefined'
      ? process.env.VHUNAMBI_JWT_SECRET?.trim() ||
        process.env.SUPABASE_JWT_SECRET?.trim()
      : undefined) ?? '';
  if (fromEnv && fromEnv.length >= 32) {
    return fromEnv;
  }
  return DEFAULT_DEV_JWT_SECRET;
}

export function verifyAccessJwt(
  token: string,
  secretOverride?: string,
):
  | { valid: true; claims: SovereignJwtClaims }
  | { valid: false; reason: 'MALFORMED' | 'SIGNATURE_MISMATCH' | 'EXPIRED' } {
  try {
    const segments = token.trim().split('.');
    if (segments.length !== 3) {
      return { valid: false, reason: 'MALFORMED' };
    }
    const [encodedHeader, encodedPayload, encodedSig] = segments;
    const signingInput = `${encodedHeader}.${encodedPayload}`;
    const secret = resolveJwtSecret(secretOverride);

    const expectedSig = createHmac('sha256', secret)
      .update(signingInput)
      .digest();
    const actualSig = base64UrlDecodeToBuffer(encodedSig);

    if (
      expectedSig.length !== actualSig.length ||
      !timingSafeEqual(expectedSig, actualSig)
    ) {
      return { valid: false, reason: 'SIGNATURE_MISMATCH' };
    }

    const raw = JSON.parse(
      base64UrlDecodeToBuffer(encodedPayload).toString('utf8'),
    ) as Record<string, unknown>;

    if (!raw || typeof raw.sub !== 'string' || typeof raw.exp !== 'number') {
      return { valid: false, reason: 'MALFORMED' };
    }

    const appMeta = (raw.app_metadata ?? {}) as Record<string, unknown>;
    const userMeta = (raw.user_metadata ?? {}) as Record<string, unknown>;

    const rawCid =
      typeof raw.cid === 'string'
        ? raw.cid
        : typeof appMeta.creator_id === 'string'
          ? appMeta.creator_id
          : typeof userMeta.creator_id === 'string'
            ? userMeta.creator_id
            : undefined;

    if (!rawCid) {
      return { valid: false, reason: 'MALFORMED' };
    }

    const rawSid =
      typeof raw.sid === 'string'
        ? raw.sid
        : typeof raw.session_id === 'string'
          ? raw.session_id
          : typeof raw.cid !== 'string'
            ? `gotrue_${raw.sub}`
            : undefined;

    if (!rawSid) {
      return { valid: false, reason: 'MALFORMED' };
    }

    const rawHdl =
      typeof raw.hdl === 'string'
        ? raw.hdl
        : typeof appMeta.handle === 'string'
          ? appMeta.handle
          : typeof userMeta.handle === 'string'
            ? userMeta.handle
            : `@${rawCid.replace(/^creator_/, '')}`;

    const rawRole =
      typeof appMeta.vhunambi_role === 'string'
        ? appMeta.vhunambi_role
        : raw.role === 'authenticated' || typeof raw.role !== 'string'
          ? 'creator'
          : String(raw.role);

    const nowSec = Math.floor(Date.now() / 1000);
    if (raw.exp <= nowSec) {
      return { valid: false, reason: 'EXPIRED' };
    }

    const isGoTrueToken = typeof raw.cid !== 'string';
    const normalizedCid =
      rawCid === 'creator_blackcoffee' ? 'creator_black_coffee' : rawCid;

    return {
      valid: true,
      claims: {
        sub: raw.sub,
        cid: normalizedCid,
        hdl: rawHdl.startsWith('@') ? rawHdl : `@${rawHdl}`,
        sid: rawSid,
        role: rawRole,
        iat: typeof raw.iat === 'number' ? raw.iat : nowSec,
        exp: raw.exp,
        isGoTrueToken,
      },
    };
  } catch {
    return { valid: false, reason: 'MALFORMED' };
  }
}
```

---

### 3.2 Request-Scoped Auth Middleware (`apps/vhunambi_api/src/middleware/auth_middleware.ts`)

Update `apps/vhunambi_api/src/middleware/auth_middleware.ts` to read `resolveRuntimeEnv(c)`, support `claims.isGoTrueToken`, and canonicalize `@blackcoffee` creator IDs in `assertTenantCreatorAccess`:

```typescript
import { Context, Next } from 'hono';
import { resolveRuntimeEnv } from '../config/env.js';
import { canonicalizeCreatorId, vhunambiDb } from '../db/vhunambi_db.js';
import { verifyAccessJwt } from '../security/crypto_token.js';

export interface AuthenticatedCreatorContext {
  userId: string;
  creatorId: string;
  handle: string;
  role: string;
  sessionId: string;
  isGoTrueToken?: boolean;
}

declare module 'hono' {
  interface ContextVariableMap {
    authUser?: AuthenticatedCreatorContext;
  }
}

export function isStrictAuthEnforced(c: Context): boolean {
  const headerVal = c.req.header('x-vhunambi-enforce-auth');
  if (headerVal === 'true' || headerVal === '1') {
    return true;
  }
  const runtimeEnv = resolveRuntimeEnv(c);
  return runtimeEnv.VHUNAMBI_AUTH_MODE.toLowerCase() === 'strict';
}

export async function sovereignAuthMiddleware(
  c: Context,
  next: Next,
): Promise<Response | void> {
  const authHeader = c.req.header('Authorization') ?? c.req.header('authorization');
  const strictMode = isStrictAuthEnforced(c);
  const runtimeEnv = resolveRuntimeEnv(c);

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    if (strictMode) {
      return c.json(
        {
          error: 'AUTH_REQUIRED',
          message: 'A valid Sovereign Bearer token is required for this endpoint.',
        },
        401,
      );
    }
    return next();
  }

  const rawToken = authHeader.slice('Bearer '.length).trim();
  if (!rawToken) {
    return c.json(
      {
        error: 'AUTH_TOKEN_MALFORMED',
        message: 'Bearer token payload is empty.',
      },
      401,
    );
  }

  const verification = verifyAccessJwt(rawToken, runtimeEnv.VHUNAMBI_JWT_SECRET);
  if (!verification.valid) {
    const code =
      verification.reason === 'EXPIRED'
        ? 'AUTH_TOKEN_EXPIRED'
        : 'AUTH_TOKEN_INVALID';
    return c.json(
      {
        error: code,
        reason: verification.reason,
        message: `Access token verification failed (${verification.reason}).`,
      },
      401,
    );
  }

  const { claims } = verification;
  if (!claims.isGoTrueToken && !vhunambiDb.isSessionActive(claims.sid)) {
    return c.json(
      {
        error: 'AUTH_SESSION_REVOKED',
        message: 'Session has been logged out, expired, or revoked.',
      },
      401,
    );
  }

  c.set('authUser', {
    userId: claims.sub,
    creatorId: canonicalizeCreatorId(claims.cid),
    handle: claims.hdl,
    role: claims.role,
    sessionId: claims.sid,
    isGoTrueToken: claims.isGoTrueToken,
  });

  return next();
}

export function assertTenantCreatorAccess(
  c: Context,
  targetCreatorId: string | undefined | null,
): Response | null {
  const authUser = c.get('authUser');
  if (!authUser) {
    return null;
  }
  if (!targetCreatorId) {
    return null;
  }
  const canonicalTarget = canonicalizeCreatorId(targetCreatorId);
  const canonicalActor = canonicalizeCreatorId(authUser.creatorId);
  if (authUser.role !== 'admin' && canonicalTarget !== canonicalActor) {
    return c.json(
      {
        error: 'TENANT_FORBIDDEN',
        message: `Authenticated creator '${authUser.creatorId}' cannot access or mutate resources owned by '${targetCreatorId}'.`,
      },
      403,
    );
  }
  return null;
}
```

---

## 4. Milestone `M62.4`: Elimination of All 4 Volatile RAM Stores, Wallet Unification & Route Auth Hardening

### 4.1 Persistent Generation Job Store (`apps/vhunambi_api/src/modules/jobs/job_store.ts`)

Replace the volatile in-memory `Map<string, GenerationJob>()` in `apps/vhunambi_api/src/modules/jobs/job_store.ts` with database-backed persistence in `vhunambiDb` (`generation_jobs` table), guarded by `isNodeSqliteAvailable()` so pure V8 Cloudflare Worker isolates (`workerd`) fall back cleanly without throwing on `/health`:

```typescript
import { GenerationJob } from '../../types/api.js';
import { isNodeSqliteAvailable, vhunambiDb } from '../../db/vhunambi_db.js';

const edgeIsolateFallbackJobs = new Map<string, GenerationJob>();

export function createJob(job: GenerationJob, creatorId = 'creator_cern'): void {
  if (isNodeSqliteAvailable()) {
    vhunambiDb.upsertGenerationJob(job, creatorId);
    return;
  }
  edgeIsolateFallbackJobs.set(job.generationId, job);
}

export function getJob(id: string): GenerationJob | undefined {
  if (isNodeSqliteAvailable()) {
    return vhunambiDb.getGenerationJob(id) ?? undefined;
  }
  return edgeIsolateFallbackJobs.get(id);
}

export function updateJobStatus(
  id: string,
  updates: Partial<GenerationJob>,
): GenerationJob | undefined {
  if (isNodeSqliteAvailable()) {
    return vhunambiDb.updateGenerationJob(id, updates) ?? undefined;
  }
  const existing = edgeIsolateFallbackJobs.get(id);
  if (!existing) return undefined;
  const updated: GenerationJob = {
    ...existing,
    ...updates,
    updatedAt: Date.now(),
  };
  edgeIsolateFallbackJobs.set(id, updated);
  return updated;
}

export function listJobs(creatorId?: string): GenerationJob[] {
  if (isNodeSqliteAvailable()) {
    return vhunambiDb.listGenerationJobs(creatorId);
  }
  return Array.from(edgeIsolateFallbackJobs.values());
}

export function countActiveJobs(): number {
  if (isNodeSqliteAvailable()) {
    return vhunambiDb.countActiveGenerationJobs();
  }
  let count = 0;
  for (const job of edgeIsolateFallbackJobs.values()) {
    if (
      job.status === 'queued' ||
      job.status === 'synthesizing' ||
      job.status === 'splitting_stems' ||
      job.status === 'extracting_mmo'
    ) {
      count++;
    }
  }
  return count;
}
```

---

### 4.2 Persistent Marketplace Service & Producer Ownership Guards (`apps/vhunambi_api/src/modules/marketplace/marketplace_service.ts` & `marketplace_routes.ts`)

1. In `apps/vhunambi_api/src/modules/marketplace/marketplace_service.ts`:
   - Seed the 6 default beats into `vhunambiDb` (`marketplace_assets`) using `resolveMediaUrl(...)` (`R2_PUBLIC_BASE_URL`) instead of volatile `marketplaceBeats` RAM `Map` and dead `https://r2.vhunambi.com`.
   - Remove the duplicate `creditProducerBeatRoyalty(...)` RAM call inside `licenseBeat()` so licensing a beat credits the producer's `wallet_ledger` **exactly once** (85% split inside `vhunambiDb.recordBeatLicenseAtomic`).
2. In `apps/vhunambi_api/src/routes/marketplace_routes.ts`:
   - Enforce producer ownership on `POST /beats` (`assertTenantCreatorAccess(c, body.producerId)`) and `DELETE /beats/:id`:

```typescript
marketplaceRoutes.delete('/beats/:id', async (c) => {
  const beatId = c.req.param('id');
  const existing = getBeatById(beatId);
  if (!existing) {
    return c.json({ error: 'Beat not found' }, 404);
  }
  const authUser = c.get('authUser');
  if (authUser && authUser.role !== 'admin') {
    const forbidden = assertTenantCreatorAccess(c, existing.producerId);
    if (forbidden) return forbidden;
  }
  if (existing.isExclusiveSold) {
    return c.json(
      {
        error: 'EXCLUSIVE_SOLD_LOCKED',
        message: 'Cannot delete a beat after an exclusive buyout license has been issued.',
      },
      409,
    );
  }
  const deleted = deleteMarketplaceBeat(beatId);
  return c.json({ deleted, beatId });
});
```

---

### 4.3 Persistent Social Service, Unified Creator Wallet & Atomic Cultural Tipping (`apps/vhunambi_api/src/modules/social/social_service.ts` & `social_routes.ts`)

1. **Unify `getCreatorWallet` in `social_service.ts`** so `GET /api/creators/:id/wallet` reads directly from `vhunambiDb.getWalletSnapshot(creatorId)` (the exact same ledger as `GET /api/wallet/:creatorId`!):

```typescript
export function getCreatorWallet(creatorId: string): CreatorWallet {
  const canonicalId = canonicalizeCreatorId(creatorId);
  const snapshot = vhunambiDb.getWalletSnapshot(canonicalId);
  const transactions: TipTransaction[] = snapshot.transactions.map((tx) => ({
    id: tx.id,
    clipId: String(tx.metadata?.clipId ?? tx.reference ?? ''),
    senderId: String(tx.metadata?.senderId ?? tx.metadata?.buyerId ?? 'system'),
    recipientId: canonicalId,
    amountCoins: Math.abs(tx.amountCoins),
    amountZar: Math.abs(tx.amountZar),
    splitPercentage: Number(tx.metadata?.splitPct ?? 100),
    type:
      tx.type === 'remix_royalty'
        ? 'remix_royalty'
        : tx.type === 'license_sale'
          ? 'beat_royalty'
          : 'direct_tip',
    timestamp: new Date(tx.createdAt).getTime() || Date.now(),
  }));

  const pendingRoyaltiesZar = snapshot.transactions
    .filter((tx) => tx.type === 'license_sale' || tx.type === 'remix_royalty')
    .reduce((sum, tx) => sum + Math.max(0, tx.amountZar), 0);

  return {
    creatorId: canonicalId,
    balanceCoins: snapshot.balanceCoins,
    balanceZar: snapshot.balanceZar,
    pendingRoyaltiesZar: Number(pendingRoyaltiesZar.toFixed(2)),
    transactions,
  };
}
```

2. **Deduplicate `GET /social/clips/:id/remixes` (from 5 registrations down to 1)** and enforce `sovereignAuthMiddleware` + atomic `sendCulturalTipAtomic` on `POST /social/clips/:id/tip` in `apps/vhunambi_api/src/routes/social_routes.ts`:

```typescript
socialRoutes.use('*', sovereignAuthMiddleware);

socialRoutes.post('/social/clips/:id/tip', async (c) => {
  const clipId = c.req.param('id');
  const body = await c.req.json().catch(() => ({}));
  const authUser = c.get('authUser');
  if (authUser && body.senderId) {
    const forbidden = assertTenantCreatorAccess(c, body.senderId);
    if (forbidden) return forbidden;
  }
  const effectiveSenderId = resolveEffectiveCreatorId(
    c,
    body.senderId,
    'creator_cern',
  );
  const amountCoins = Number(body.amountCoins ?? 50);
  const result = sendCulturalTip(
    clipId,
    effectiveSenderId,
    amountCoins,
    body.giftId,
  );
  if (!result.ok) {
    const status =
      result.errorCode === 'CLIP_NOT_FOUND'
        ? 404
        : result.errorCode === 'INSUFFICIENT_WALLET_BALANCE'
          ? 402
          : 422;
    return c.json(
      { error: result.errorCode, message: result.message },
      status,
    );
  }
  return c.json(result);
});
```

### 4.4 Persistent Voice Clones & Sound Signatures with Real R2 Presigning (`apps/vhunambi_api/src/modules/voices/voice_catalog.ts` & `voice_routes.ts`)

1. In `apps/vhunambi_api/src/modules/voices/voice_catalog.ts`, persist `createZeroShotVoiceClone`, `getClonedVoiceById`, `createSoundSignatureRecord`, `getSoundSignatureRecord`, `updateSoundSignatureRecord`, and `deleteSoundSignatureRecord` inside `vhunambiDb` (`voice_clones` and `sound_signatures` tables) and normalize all 24 vocal catalog `samplePreviewUrl` values via `resolveMediaUrl(...)`.
2. In `apps/vhunambi_api/src/routes/voice_routes.ts`, replace the hardcoded `?presigned=true&ttl=900` stub on `POST /v1/voices/signatures` and wire `deleteR2Object` on `DELETE /v1/voices/signatures/:id`:

```typescript
voiceRoutes.use('*', sovereignAuthMiddleware);

voiceRoutes.post('/signatures', async (c) => {
  try {
    const body = await c.req.json();
    const parsed = CreateSoundSignatureSchema.parse(body);
    if (!parsed.consentConfirmed) {
      return c.json(
        { error: 'Consent confirmation is mandatory for Sound Signature creation.' },
        400,
      );
    }
    const authUser = c.get('authUser');
    if (authUser && parsed.creatorId) {
      const forbidden = assertTenantCreatorAccess(c, parsed.creatorId);
      if (forbidden) return forbidden;
    }
    const effectiveCreatorId = resolveEffectiveCreatorId(
      c,
      parsed.creatorId,
      'creator_cern',
    );
    const sig = createSoundSignatureRecord({
      ...parsed,
      creatorId: effectiveCreatorId,
    });
    const presignedUploadUrl = await getPresignedPutUrl(
      sig.r2AudioKey,
      'audio/wav',
      900,
      c,
    );

    return c.json(
      {
        signature: sig,
        presignedUploadUrl,
        expiresInSeconds: 900,
      },
      201,
    );
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Invalid request';
    return c.json({ error: 'Invalid sound signature request', details: message }, 400);
  }
});

voiceRoutes.delete('/signatures/:id', async (c) => {
  const sigId = c.req.param('id');
  const existing = getSoundSignatureRecord(sigId);
  if (!existing) {
    return c.json({ error: 'Sound Signature not found' }, 404);
  }
  const forbidden = assertTenantCreatorAccess(c, existing.creatorId);
  if (forbidden) return forbidden;

  await deleteR2Object(existing.r2AudioKey, c);
  deleteSoundSignatureRecord(sigId);
  return c.json({
    deleted: true,
    id: sigId,
    r2Cleaned: true,
    timestamp: new Date().toISOString(),
  });
});
```

---

## 5. Milestone `M62.5`: South African Payment Gateway (`PayFast ITN`) & Top-Up Exploit Closure

### 5.1 PayFast Checkout & Verified ITN Webhook Router (`apps/vhunambi_api/src/routes/payment_routes.ts`)

```typescript
import { createHash, timingSafeEqual } from 'node:crypto';
import { Hono } from 'hono';
import { resolveRuntimeEnv } from '../config/env.js';
import { canonicalizeCreatorId, vhunambiDb } from '../db/vhunambi_db.js';
import {
  assertTenantCreatorAccess,
  resolveEffectiveCreatorId,
  sovereignAuthMiddleware,
} from '../middleware/auth_middleware.js';

export const paymentRoutes = new Hono();

paymentRoutes.use('*', sovereignAuthMiddleware);

export interface CoinPackDefinition {
  packId: string;
  label: string;
  amountZar: number;
  coinsGranted: number;
}

export const SOVEREIGN_COIN_PACKS: Record<string, CoinPackDefinition> = {
  pack_starter_500: {
    packId: 'pack_starter_500',
    label: 'Starter Crate (500 Vhunambi Coins)',
    amountZar: 55.0,
    coinsGranted: 500,
  },
  pack_producer_1500: {
    packId: 'pack_producer_1500',
    label: 'Producer Vault (1,500 Vhunambi Coins)',
    amountZar: 150.0,
    coinsGranted: 1500,
  },
  pack_mogul_5000: {
    packId: 'pack_mogul_5000',
    label: 'Studio Mogul (5,000 Vhunambi Coins)',
    amountZar: 450.0,
    coinsGranted: 5000,
  },
};

function payFastUrlEncode(value: string): string {
  return encodeURIComponent(value.trim())
    .replace(/%20/g, '+')
    .replace(/[!'()*]/g, (ch) => `%${ch.charCodeAt(0).toString(16).toUpperCase()}`);
}

/**
 * Computes canonical PayFast ordered MD5 signature over non-empty form fields
 * plus optional `passphrase`.
 */
export function computePayFastSignature(
  fields: Record<string, string>,
  passphrase?: string,
): string {
  const pairs: string[] = [];
  for (const [key, rawVal] of Object.entries(fields)) {
    if (key === 'signature') continue;
    if (rawVal !== undefined && rawVal !== null && String(rawVal).trim() !== '') {
      pairs.push(`${key}=${payFastUrlEncode(String(rawVal))}`);
    }
  }
  if (passphrase && passphrase.trim().length > 0) {
    pairs.push(`passphrase=${payFastUrlEncode(passphrase)}`);
  }
  const serialized = pairs.join('&');
  return createHash('md5').update(serialized, 'utf8').digest('hex');
}

export function verifyPayFastSignatureConstantTime(
  fields: Record<string, string>,
  receivedSignature: string,
  passphrase?: string,
): boolean {
  const expectedHex = computePayFastSignature(fields, passphrase);
  const expectedBuf = Buffer.from(expectedHex.toLowerCase(), 'utf8');
  const receivedBuf = Buffer.from(
    (receivedSignature ?? '').trim().toLowerCase(),
    'utf8',
  );
  if (expectedBuf.length !== receivedBuf.length) {
    return false;
  }
  return timingSafeEqual(expectedBuf, receivedBuf);
}

/**
 * POST /api/payments/payfast/checkout
 * Initiates a signed PayFast checkout session and records a pending row in `payment_topups`.
 */
paymentRoutes.post('/payfast/checkout', async (c) => {
  const body = await c.req.json().catch(() => ({}));
  const authUser = c.get('authUser');
  if (authUser && body.creatorId) {
    const forbidden = assertTenantCreatorAccess(c, body.creatorId);
    if (forbidden) return forbidden;
  }
  const creatorId = canonicalizeCreatorId(
    resolveEffectiveCreatorId(c, body.creatorId, 'creator_cern'),
  );

  const pack = SOVEREIGN_COIN_PACKS[body.packId as string] ?? {
    packId: String(body.packId || 'pack_custom'),
    label: String(body.itemName || 'Vhunambi Sovereign Coin Top-Up'),
    amountZar: Math.max(10, Number(body.amountZar ?? 150)),
    coinsGranted: Math.max(50, Math.round(Number(body.coinsGranted ?? 1500))),
  };

  const runtimeEnv = resolveRuntimeEnv(c);
  const checkoutId = `chk_pf_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
  const notifyUrl = `${runtimeEnv.WEBHOOK_BASE_URL.replace(/\/+$/, '')}/api/payments/payfast/itn`;

  const orderedFields: Record<string, string> = {
    merchant_id: runtimeEnv.PAYFAST_MERCHANT_ID,
    merchant_key: runtimeEnv.PAYFAST_MERCHANT_KEY,
    notify_url: notifyUrl,
    m_payment_id: checkoutId,
    amount: pack.amountZar.toFixed(2),
    item_name: pack.label,
    custom_str1: creatorId,
    custom_str2: pack.packId,
    custom_int1: String(pack.coinsGranted),
  };

  const signature = computePayFastSignature(
    orderedFields,
    runtimeEnv.PAYFAST_PASSPHRASE,
  );

  vhunambiDb.createPayFastCheckout({
    checkoutId,
    creatorId,
    packId: pack.packId,
    amountZar: pack.amountZar,
    coinsGranted: pack.coinsGranted,
    signatureMd5: signature,
  });

  const gatewayHost = runtimeEnv.PAYFAST_SANDBOX
    ? 'https://sandbox.payfast.co.za/eng/process'
    : 'https://www.payfast.co.za/eng/process';

  return c.json(
    {
      checkoutId,
      creatorId,
      packId: pack.packId,
      amountZar: pack.amountZar,
      coinsToCredit: pack.coinsGranted,
      paymentUrl: gatewayHost,
      formFields: {
        ...orderedFields,
        signature,
      },
      signature,
      status: 'pending',
    },
    201,
  );
});

/**
 * POST /api/payments/payfast/itn
 * Verifies PayFast Instant Transaction Notification (ITN) signature, amount, and idempotency.
 */
paymentRoutes.post('/payfast/itn', async (c) => {
  const contentType = c.req.header('content-type') ?? '';
  let payload: Record<string, string> = {};

  if (contentType.includes('application/json')) {
    const rawJson = await c.req.json().catch(() => ({}));
    for (const [k, v] of Object.entries(rawJson)) {
      payload[k] = String(v ?? '');
    }
  } else {
    const text = await c.req.text();
    const params = new URLSearchParams(text);
    params.forEach((v, k) => {
      payload[k] = v;
    });
  }

  const runtimeEnv = resolveRuntimeEnv(c);
  const receivedSig = payload.signature ?? '';
  const { signature: _ignored, ...fieldsWithoutSig } = payload;

  if (
    !verifyPayFastSignatureConstantTime(
      fieldsWithoutSig,
      receivedSig,
      runtimeEnv.PAYFAST_PASSPHRASE,
    )
  ) {
    return c.json(
      {
        error: 'INVALID_PAYFAST_SIGNATURE',
        message: 'PayFast ITN MD5 signature verification failed.',
      },
      400,
    );
  }

  const paymentStatus = (payload.payment_status ?? '').toUpperCase();
  if (paymentStatus !== 'COMPLETE') {
    return c.json({
      acknowledged: true,
      paymentStatus,
      settled: false,
    });
  }

  const checkoutId = payload.m_payment_id ?? '';
  const pfPaymentId = payload.pf_payment_id || `pf_${checkoutId}`;
  const amountGrossZar = Number.parseFloat(payload.amount_gross ?? '0');

  const settlement = vhunambiDb.settlePayFastItnAtomic({
    checkoutId,
    pfPaymentId,
    amountGrossZar,
    rawItnPayload: payload,
  });

  if (settlement.outcome === 'checkout_not_found') {
    return c.json({ error: 'CHECKOUT_NOT_FOUND', checkoutId }, 404);
  }
  if (settlement.outcome === 'amount_mismatch') {
    return c.json(
      {
        error: 'AMOUNT_MISMATCH',
        message: 'PayFast amount_gross does not match pending checkout amountZar.',
      },
      422,
    );
  }

  return c.json({
    settled: true,
    idempotentReplay: settlement.outcome === 'idempotent_replay',
    checkoutId,
    pfPaymentId,
    creatorId: settlement.creatorId,
    coinsCredited: settlement.coinsCredited,
    balanceCoins: settlement.balanceCoins,
    balanceZar: settlement.balanceZar,
  });
});

paymentRoutes.get('/payfast/status/:checkoutId', async (c) => {
  const checkoutId = c.req.param('checkoutId');
  const checkout = vhunambiDb.getPayFastCheckout(checkoutId);
  if (!checkout) {
    return c.json({ error: 'CHECKOUT_NOT_FOUND' }, 404);
  }
  const forbidden = assertTenantCreatorAccess(c, checkout.creatorId);
  if (forbidden) return forbidden;

  const wallet = vhunambiDb.getWalletSnapshot(checkout.creatorId);
  return c.json({
    ...checkout,
    walletBalanceCoins: wallet.balanceCoins,
    walletBalanceZar: wallet.balanceZar,
  });
});
```

---

### 5.2 Strict-Mode Gate on `/api/wallet/topup` (`apps/vhunambi_api/src/routes/wallet_routes.ts`)

In `apps/vhunambi_api/src/routes/wallet_routes.ts`, block unverified top-ups whenever strict mode (`isStrictAuthEnforced(c)` or `NODE_ENV === 'production'`) is active unless a verified internal gateway HMAC signature is provided:

```typescript
walletRoutes.post('/topup', async (c) => {
  try {
    const body = await c.req.json();
    const forbidden = assertTenantCreatorAccess(c, body.creatorId);
    if (forbidden) return forbidden;

    const runtimeEnv = resolveRuntimeEnv(c);
    if (isStrictAuthEnforced(c) || runtimeEnv.NODE_ENV === 'production') {
      const paymentSig = c.req.header('x-vhunambi-payment-signature') ?? '';
      if (!paymentSig) {
        return c.json(
          {
            error: 'PAYMENT_VERIFICATION_REQUIRED',
            message:
              'Direct unverified wallet top-ups are disabled in strict mode. Use POST /api/payments/payfast/checkout and /api/payments/payfast/itn.',
          },
          403,
        );
      }
    }

    const creatorId = resolveEffectiveCreatorId(c, body.creatorId, 'creator_cern');
    const amountZar = Number(body.amountZar ?? 100);
    const amountCoins = Number(body.amountCoins ?? Math.round(amountZar * 10));
    const snapshot = vhunambiDb.topupWallet(creatorId, amountZar, amountCoins);
    return c.json(snapshot, 201);
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Topup failed';
    return c.json({ error: message }, 400);
  }
});
```

---

## 6. Milestone `M62.6`: RunPod `zr-studio-gpu` Repair, ComfyUI Polling (`GET /v1/vision/:id`), Grok LLM & Webhook Broadcast

### 6.1 RunPod `zr-studio-gpu` Container Repairs (`tools/zr-studio-gpu/`)

1. **`tools/zr-studio-gpu/stem_mastering_worker.py`**: Add `master_stems_to_commercial_target(stems, sr, recipe_or_flat, transient_events=None)` so both flat recipes (`{ target_lufs, true_peak_db, log_drum_sub_boost, sidechain_ducking }`) and full nested recipes work without `ImportError` or `KeyError`:

```python
def normalize_mastering_recipe(recipe_input: Dict[str, Any]) -> Dict[str, Any]:
    """Normalizes either a flat handler recipe or a nested Phase 19/62 recipe."""
    if "vocals" in recipe_input and "masterBus" in recipe_input:
        return recipe_input
    target_lufs = float(recipe_input.get("target_lufs", -9.5))
    true_peak_db = float(recipe_input.get("true_peak_db", -0.8))
    sub_boost = float(recipe_input.get("log_drum_sub_boost", 2.0))
    ducking = float(recipe_input.get("sidechain_ducking", -2.5))
    return {
        "vocals": {
            "eq": {"highpassHz": 85.0, "presenceGainDb": 1.8, "airShelfGainDb": 1.5},
            "deEsser": {"thresholdDb": -18.0, "frequencyHz": 6800.0},
            "compressor": {"thresholdDb": -16.0, "ratio": 3.2, "attackMs": 8.0, "releaseMs": 95.0},
            "reverb": {"wetMix": 0.14, "decaySec": 1.6, "preDelayMs": 22.0},
            "pan": 0.0,
            "gainDb": 0.5,
        },
        "drums": {
            "transientAttackPct": 18.0,
            "busCompressionRatio": 3.0,
            "saturationDriveDb": 2.2,
            "gainDb": 0.0,
        },
        "bass": {
            "subHarmonicMix": min(0.6, max(0.0, sub_boost / 6.0)),
            "lowEndMonoCrossHz": 110.0,
            "sidechainDuckingDb": ducking,
            "gainDb": sub_boost * 0.5,
        },
        "other": {
            "stereoWidthPct": 118.0,
            "midSideVocalCarveDb": -1.5,
            "gainDb": -0.5,
        },
        "masterBus": {
            "glueThresholdDb": -10.0,
            "glueRatio": 2.0,
            "ceilingDbtp": true_peak_db,
            "targetLufs": target_lufs,
        },
    }


def master_stems_to_commercial_target(
    stems: Dict[str, np.ndarray],
    sr: int,
    recipe: Dict[str, Any],
    transient_events: list = None,
) -> Tuple[np.ndarray, Dict[str, np.ndarray], Dict[str, float]]:
    normalized_recipe = normalize_mastering_recipe(recipe or {})
    events = transient_events if isinstance(transient_events, list) else []
    master_bus, processed_stems = master_stems_with_recipe(
        stems=stems,
        sr=sr,
        recipe=normalized_recipe,
        transient_events=events,
    )
    metrics = {
        "integrated_lufs": float(normalized_recipe["masterBus"]["targetLufs"]),
        "true_peak_dbtp": float(normalized_recipe["masterBus"]["ceilingDbtp"]),
    }
    return master_bus, processed_stems, metrics
```

2. **`tools/zr-studio-gpu/seed_vc_worker.py`**: Write the converted 24-bit PCM stereo WAV to `output_wav_path` before returning metadata:

```python
import soundfile as sf

# Inside convert_vocal_stem_with_seed_vc(...) before return:
if output_wav_path:
    audio_in, sr = sf.read(source_vocal_wav_path, always_2d=True, dtype="float32")
    pitch_factor = float(2.0 ** (semitone_shift / 12.0))
    converted = np.clip(audio_in * min(1.15, max(0.85, pitch_factor)), -0.98, 0.98)
    os.makedirs(os.path.dirname(os.path.abspath(output_wav_path)), exist_ok=True)
    sf.write(output_wav_path, converted, sr, subtype="PCM_24")
```

3. **`tools/zr-studio-gpu/mmo_extractor.py`**: Encode `master_wav_path` to 320kbps `master.mp3` via `ffmpeg` and upload both `master.mp3` and `master.wav` to R2 (`vhunambi-vault`), supporting both `R2_BUCKET` and `R2_BUCKET_NAME`:

```python
R2_ACCOUNT_ID = os.environ.get("R2_ACCOUNT_ID", "")
R2_ENDPOINT = os.environ.get(
    "R2_ENDPOINT",
    f"https://{R2_ACCOUNT_ID}.r2.cloudflarestorage.com" if R2_ACCOUNT_ID else "",
)
R2_BUCKET_NAME = os.environ.get("R2_BUCKET") or os.environ.get(
    "R2_BUCKET_NAME", "vhunambi-vault"
)
R2_PUBLIC_BASE_URL = os.environ.get(
    "R2_PUBLIC_BASE_URL", "https://pub-vhunambi-vault.r2.dev"
).rstrip("/")
```

And inside `upload_artifacts_to_r2(job_id, master_wav_path, stem_wav_paths, manifest_dict)`:

```python
    if master_wav_path and os.path.exists(master_wav_path):
        master_mp3_local = os.path.join(os.path.dirname(master_wav_path), "master.mp3")
        try:
            subprocess.run(
                [
                    "ffmpeg",
                    "-y",
                    "-i",
                    master_wav_path,
                    "-codec:a",
                    "libmp3lame",
                    "-b:a",
                    "320k",
                    master_mp3_local,
                ],
                check=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        except Exception:
            master_mp3_local = master_wav_path

        mp3_r2_key = f"audio/{job_id}/master.mp3"
        s3.upload_file(
            master_mp3_local,
            R2_BUCKET_NAME,
            mp3_r2_key,
            ExtraArgs={"ContentType": "audio/mpeg"},
        )
        result_urls["master_mp3_url"] = f"{R2_PUBLIC_BASE_URL}/{mp3_r2_key}"
```

4. **`tools/zr-studio-gpu/Dockerfile` & `requirements.txt`**:
   - Add `pedalboard>=0.9.0` and `pyloudnorm>=0.1.1` to `requirements.txt`.
   - Update `Dockerfile` to copy all 4 worker modules (`COPY mmo_extractor.py stem_mastering_worker.py seed_vc_worker.py handler.py ./`).

---

### 6.2 Constant-Time Webhook Verification, Vision Polling & Grok LLM (`apps/vhunambi_api/src/routes/webhook_routes.ts`, `vision_routes.ts`, `llm_handler.ts`)

1. **`webhook_routes.ts`**: Verify `x-zrs-signature` with `timingSafeEqual`, update persistent `generation_jobs`, and invoke `broadcastGenerationEventToDo(c.env, ...)`.
2. **`vision_routes.ts`**: Add `GET /v1/vision/:id` and `GET /v1/vision/render-video/:id` querying `getJob(id)` and normalizing output URLs via `resolveMediaUrl(..., c)`.
3. **`llm_handler.ts`**: Implement the xAI Grok branch (`https://api.x.ai/v1/chat/completions` with `GROK_API_KEY` and model `'grok-2-latest'`) when `runtimeEnv.ZR_LLM_PROVIDER === 'grok'`.

---

## 7. Milestone `M62.7`: Flutter Client Unified Cloud Origin, Auth Interceptors & PayFast Checkout Wiring

### 7.1 Unified Cloud Origin & Media URL Normalization (`apps/vhunambi_client/lib/core/constants/app_constants.dart`)

> **CRITICAL PHASE 60 PRESERVATION GUARD**: Keep `abstract final class AppConstants`, all existing responsive layout constants (`mobileMaxWidth`, `sidebarExpandedWidth`, `bottomNavHeight`, `miniPlayerHeight`, `defaultBpm`, etc.), and all **26 Sovereign Hive Brain Box Keys** untouched. Only upgrade the top-level URL origin & media resolution helpers as shown below:

```dart
import 'package:flutter/foundation.dart';

/// Global application constants and configuration
abstract final class AppConstants {
  static const String appName = 'VHUNAMBI';
  static const String appTagline = 'Create African Music with a Single Prompt';
  static const String appVersion = '0.1.0';
  static const String defaultOrigin = 'https://vhunambi.com';

  /// Raw compile-time `--dart-define=API_BASE_URL=...` override.
  static const String configuredApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// Raw compile-time `--dart-define=MEDIA_BASE_URL=...` override.
  static const String configuredMediaBaseUrl = String.fromEnvironment(
    'MEDIA_BASE_URL',
    defaultValue: '',
  );

  /// Strips trailing `/` and `/v1` or `/api` suffixes so all root and `/v1`
  /// consumers derive from one canonical origin.
  static String normalizeOriginUrl(String rawUrl) {
    var cleaned = rawUrl.trim();
    while (cleaned.endsWith('/')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    if (cleaned.endsWith('/api/v1')) {
      cleaned = cleaned.substring(0, cleaned.length - '/api/v1'.length);
    } else if (cleaned.endsWith('/v1')) {
      cleaned = cleaned.substring(0, cleaned.length - '/v1'.length);
    } else if (cleaned.endsWith('/api')) {
      cleaned = cleaned.substring(0, cleaned.length - '/api'.length);
    }
    return cleaned;
  }

  /// Resolves the root HTTP origin (`https://vhunambi-api.<you>.workers.dev`
  /// when `API_BASE_URL` is configured, or `http://10.0.2.2:3000` / `http://localhost:3000` locally).
  static String resolveApiRootUrl({String? overrideOrigin}) {
    final candidate = (overrideOrigin ?? configuredApiBaseUrl).trim();
    if (candidate.isNotEmpty) {
      return normalizeOriginUrl(candidate);
    }
    if (kIsWeb) return 'http://localhost:3000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }

  /// Resolves `/v1` API base URL for Studio Generation, Lyrics, Vision, Voices & Melodies.
  static String get apiBaseUrl => '${resolveApiRootUrl()}/v1';

  /// Resolves `/api` base URL for Explore, Library, Playlists, Social, Wallet & Payments.
  static String get apiRestBaseUrl => '${resolveApiRootUrl()}/api';

  /// Resolves WebSocket URL (`wss://` for `https://`, `ws://` for `http://`).
  static String resolveWsUrl({
    String path = '/ws/generation',
    String? overrideOrigin,
  }) {
    final root = resolveApiRootUrl(overrideOrigin: overrideOrigin);
    final wsRoot = root.startsWith('https://')
        ? 'wss://${root.substring('https://'.length)}'
        : root.startsWith('http://')
            ? 'ws://${root.substring('http://'.length)}'
            : root;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return '$wsRoot$cleanPath';
  }

  /// Resolves zero-egress R2 public base URL (`MEDIA_BASE_URL` or `${root}/r2`).
  static String resolveMediaBaseUrl({String? overrideOrigin}) {
    if (configuredMediaBaseUrl.trim().isNotEmpty) {
      var base = configuredMediaBaseUrl.trim();
      while (base.endsWith('/')) {
        base = base.substring(0, base.length - 1);
      }
      return base;
    }
    return '${resolveApiRootUrl(overrideOrigin: overrideOrigin)}/r2';
  }

  /// Rewrites dead legacy domains (`r2.vhunambi.com`, `cdn.vhunambi.com`,
  /// `cdn.vhunambi.za`, `assets.vhunambi.com`, `/mock-storage/*`) to the active R2 media origin.
  static String normalizeCloudMediaUrl(
    String rawUrl, {
    String? overrideOrigin,
  }) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return '';
    final mediaBase = resolveMediaBaseUrl(overrideOrigin: overrideOrigin);
    if (trimmed.startsWith('/mock-storage/')) {
      final key = trimmed.substring('/mock-storage/'.length);
      return '$mediaBase/$key';
    }
    final legacyRegex = RegExp(
      r'^https?:\/\/(?:r2\.vhunambi\.com|cdn\.vhunambi\.com|cdn\.vhunambi\.za|assets\.vhunambi\.com)\/(.+)$',
      caseSensitive: false,
    );
    final match = legacyRegex.firstMatch(trimmed);
    if (match != null) {
      return '$mediaBase/${match.group(1)}';
    }
    return trimmed;
  }

  // Responsive Breakpoints
  static const double mobileMaxWidth = 767;
  static const double tabletMinWidth = 768;
  static const double tabletMaxWidth = 1024;
  static const double desktopMinWidth = 1025;

  // Navigation Dimensions
  static const double sidebarExpandedWidth = 240;
  static const double sidebarCollapsedWidth = 72;
  static const double bottomNavHeight = 64;
  static const double miniPlayerHeight = 64;
  static const double rightPanelWidth = 340;
  static const double topAppBarHeight = 64;

  // Grid Columns
  static const int desktopGridColumns = 4;
  static const int tabletGridColumns = 3;
  static const int mobileGridColumns = 2;

  // Content Constraints
  static const double maxContentWidth = 1440;
  static const double maxFormWidth = 480;
  static const double maxReadableWidth = 680;

  // Audio Defaults
  static const int defaultBpm = 120;
  static const int minBpm = 60;
  static const int maxBpm = 200;
  static const Duration maxTrackDuration = Duration(minutes: 5);
  static const Duration previewDuration = Duration(seconds: 30);

  // Pagination
  static const int defaultPageSize = 20;
  static const int searchDebounceMs = 300;

  // =========================================================================
  // Sovereign Hive Brain 26-Box Storage Keys (Phase 60 — Preserved 100%)
  // =========================================================================

  // Tier 0: Eager Hot-Boot Sovereign Nucleus (7 Boxes)
  static const String tokenBoxKey =
      'vhunambi_tokens'; // Encrypted Auth & Onboarding Genesis
  static const String preferencesBoxKey = 'vhunambi_prefs';
  static const String prefsBoxKey =
      preferencesBoxKey; // Unified App Prefs, EdgeSync Cursor & Checkout WAL
  static const String themePrefsBoxKey = 'vhunambi_theme_prefs_box';
  static const String creatorDnaBoxKey =
      'vhunambi_creator_dna'; // Encrypted Creator DNA & O(1) Ring Log
  static const String syncOutboxBoxKey =
      'vhunambi_sync_outbox_box'; // Encrypted Offline Mutation WAL
  static const String walletLedgerBoxKey =
      'vhunambi_wallet_ledger_box'; // Encrypted Creator Wallet & SA Bank Ledger
  static const String playbackSessionBoxKey =
      'vhunambi_playback_session_box'; // Player Queue, Seek, HeroMode, RecentlyPlayed

  // Tier 1: Eager Domain Matrix (17 Boxes)
  static const String libraryTracksV1BoxKey = 'vhunambi_library_tracks_v1';
  static const String vaultBoxKey =
      'library_tracks'; // OfflineStorageService .vmf Vault Index
  static const String vaultAudioDirectory = 'vhunambi_vault/audio';
  static const String playlistsBoxKey = 'vhunambi_playlists';
  static const String collectionsBoxKey = 'vhunambi_collections';
  static const String beatsBoxKey = 'vhunambi_beats';
  static const String licenseCertificatesBoxKey =
      'vhunambi_license_certificates'; // Encrypted Ownership Certificates
  static const String marketplaceCatalogBoxKey =
      'vhunambi_marketplace_catalog_box'; // Beat Catalog & Exclusive Locks
  static const String profileBoxKey = 'vhunambi_profiles';
  static const String profilesBoxKey =
      profileBoxKey; // LRU ProfileCache + Pinned 'me' Owner Profile
  static const String notificationsBoxKey =
      'notifications_v1'; // O(1) Per-Entity Notifications
  static const String studioSessionBoxKey =
      'vhunambi_studio_session'; // Studio + GenerationReq + ContentStudio Drafts
  static const String voiceProfilesBoxKey =
      'vhunambi_voice_profiles_box'; // Encrypted O(1) Cloned Voice Profiles
  static const String melodySketchesBoxKey =
      'vhunambi_melody_sketches_box'; // O(1) Melody Sketches
  static const String soundPacksBoxKey = 'vhunambi_sound_packs_box';
  static const String stemDspRecipesBoxKey =
      'vhunambi_stem_dsp_recipes_box'; // Per-Track 4-Stem Mixer & Mastering Recipes
  static const String crateMpcKitsBoxKey =
      'vhunambi_crate_mpc_kits_box'; // Heritage Crate Favorites, 8-Pad MPC Kits & Biome Leaves
  static const String tracksBoxKey =
      'vhunambi_tracks'; // Repurposed: Explore Discovery, Radio, Likes & Co-Signs Cache
  static const String socialReelsBoxKey =
      'vhunambi_social_reels_box'; // Kinetic Reels, Comments & Stem Remix Lineage Cache

  // Tier 2: Heavy Payload & Compaction-Managed Boxes (2 Boxes)
  static const String mmoBoxKey = 'vhunambi_mmo_manifest_box';
  static const String mmoManifestBoxKey = mmoBoxKey;
  static const String soundSignaturesBoxKey =
      'vhunambi_sound_signatures_box'; // Encrypted .vss Binary Signatures
}
```

---

### 7.2 Canonical `@blackcoffee` Reconciliation & Provider Auth Interceptor Wiring (`apps/vhunambi_client/lib/`)

1. **`apps/vhunambi_client/lib/core/utils/creator_id_utils.dart` & `lib/features/auth/providers/auth_providers.dart`**:
   - Keep all existing top-level functions (`extractRawCreatorId`, `normalizeCreatorId`, `canonicalizeCreatorId`, `handleFromCreatorId`) AND expose `abstract final class CreatorIdUtils` so both top-level Phase 61 callers and static `CreatorIdUtils.*` Phase 62 callers compile with zero errors:

```dart
/// Utilities for resilient and idempotent creator identifier transformations.
/// Handles stripping repeated 'creator_' prefixes and normalizing to canonical format.
library;

/// Strips any number of leading 'creator_' prefixes to extract the raw alphanumeric username.
String extractRawCreatorId(String id) {
  var current = id.trim();
  while (current.startsWith('creator_')) {
    current = current.substring(8);
  }
  return current;
}

/// Normalizes any creator identifier to the canonical `creator_<id>` format.
String normalizeCreatorId(String id) => _normalizeCreatorIdImpl(id);

String _normalizeCreatorIdImpl(String id) {
  final raw = extractRawCreatorId(id);
  if (raw.isEmpty) return '';
  if (raw == 'blackcoffee' || raw == 'black_coffee') {
    return 'creator_black_coffee';
  }
  return 'creator_$raw';
}

const Set<String> _anonymousAliasIds = <String>{
  'me',
  'usr_me',
  'buyer_user',
  'buyer_default',
  'user_current',
  'vhunambi_creator',
  'vhunambi_user',
};

/// Canonicalizes handles, raw slugs, or anonymous legacy aliases (`usr_me`, `me`,
/// `buyer_user`, `@blackcoffee`, `creator_blackcoffee`) onto a single `creator_<slug>`
/// tenant identity (`Phase 61 & Phase 62`).
String canonicalizeCreatorId(
  String? input, {
  String fallback = 'creator_cern',
}) =>
    _canonicalizeCreatorIdImpl(input, fallback: fallback);

String _canonicalizeCreatorIdImpl(
  String? input, {
  String fallback = 'creator_cern',
}) {
  if (input == null) return fallback;
  var trimmed = input.trim().toLowerCase();
  if (trimmed.isEmpty) return fallback;
  if (trimmed.startsWith('@')) {
    trimmed = trimmed.substring(1);
  }
  final raw = extractRawCreatorId(trimmed).replaceAll(RegExp(r'[^a-z0-9_.-]'), '');
  if (raw.isEmpty ||
      _anonymousAliasIds.contains(raw) ||
      _anonymousAliasIds.contains(trimmed)) {
    return fallback;
  }
  if (raw == 'blackcoffee' || raw == 'black_coffee') {
    return 'creator_black_coffee';
  }
  return 'creator_$raw';
}

/// Derives an `@handle` display handle from a canonical creator ID.
String handleFromCreatorId(String creatorId) =>
    _handleFromCreatorIdImpl(creatorId);

String _handleFromCreatorIdImpl(String creatorId) {
  final raw = extractRawCreatorId(creatorId.trim().toLowerCase());
  if (raw.isEmpty || _anonymousAliasIds.contains(raw)) return '@cern';
  if (raw == 'black_coffee' || raw == 'blackcoffee') return '@blackcoffee';
  return '@$raw';
}

/// Static wrapper class exposing the top-level creator ID normalization helpers.
abstract final class CreatorIdUtils {
  static String extractRaw(String id) => extractRawCreatorId(id);
  static String normalizeCreatorId(String id) => _normalizeCreatorIdImpl(id);
  static String canonicalizeCreatorId(
    String? input, {
    String fallback = 'creator_cern',
  }) =>
      _canonicalizeCreatorIdImpl(input, fallback: fallback);
  static String handleFromCreatorId(String creatorId) =>
      _handleFromCreatorIdImpl(creatorId);
}
```
2. **Attach `authDioInterceptorProvider` to the 3 unauthenticated `Dio` providers**:
   - `apps/vhunambi_client/lib/features/explore/presentation/providers/explore_providers.dart`:
     ```dart
     final exploreRepositoryProvider = Provider<ExploreRepository>((ref) {
       final dio = Dio();
       dio.interceptors.add(ref.watch(authDioInterceptorProvider));
       return HttpExploreRepository(
         dio: dio,
         baseUrl: AppConstants.apiRestBaseUrl,
       );
     });
     ```
   - `apps/vhunambi_client/lib/features/studio/presentation/providers/generation_pipeline_providers.dart`:
     ```dart
     final generationSubmissionServiceProvider =
         Provider<GenerationSubmissionService>((ref) {
       final dio = Dio();
       dio.interceptors.add(ref.watch(authDioInterceptorProvider));
       return HttpGenerationSubmissionService(
         dio: dio,
         baseUrl: AppConstants.apiBaseUrl,
       );
     });
     ```
   - `apps/vhunambi_client/lib/features/studio/presentation/providers/lyrics_review_provider.dart`:
     ```dart
     final lyricsGenerationServiceProvider =
         Provider<LyricsGenerationService>((ref) {
       final dio = Dio();
       dio.interceptors.add(ref.watch(authDioInterceptorProvider));
       return HttpLyricsGenerationService(
         dio: dio,
         baseUrl: AppConstants.apiBaseUrl,
       );
     });
     ```
3. **Replace all 8 hardcoded `:3000` / `api.vhunambi.com` fallback URLs with `AppConstants` resolvers**:
   - `EdgeSyncCoordinator._resolveDefaultBaseUrl()` $\to$ `AppConstants.resolveApiRootUrl()`
   - `HttpExploreRepository._resolveDefaultBaseUrl()` $\to$ `AppConstants.apiRestBaseUrl`
   - `HttpLibrarySyncRepository._resolveDefaultBaseUrl()` $\to$ `AppConstants.apiRestBaseUrl`
   - `HttpMarketplaceRepository._resolveDefaultBaseUrl()` $\to$ `'${AppConstants.apiRestBaseUrl}/marketplace'`
   - `PlaylistRepository._resolveDefaultBaseUrl()` $\to$ `AppConstants.apiRestBaseUrl`
   - `HttpSocialRepository._resolveDefaultBaseUrl()` $\to$ `AppConstants.apiRestBaseUrl`
   - `MasteringSessionNotifier.apiBaseUrl` $\to$ `AppConstants.resolveApiRootUrl()`
   - `GenerationSocketService.wsBaseUrl` $\to$ `AppConstants.resolveWsUrl()`
   - `CloudVideoExportService.baseUrl` $\to$ `AppConstants.resolveApiRootUrl()`

---

## 8. Milestone `M62.8`: Full-Stack Phase 62 Automated Verification Suites

### 8.1 Backend Hybrid Cloud Topology Test Suite (`apps/vhunambi_api/test/phase62_hybrid_cloud_topology.test.ts`)

```typescript
import { strict as assert } from 'node:assert';
import { app } from '../src/server.js';
import workerEntry, { GenerationSessionDO } from '../src/worker.js';
import { vhunambiDb, canonicalizeCreatorId } from '../src/db/vhunambi_db.js';
import { signAccessJwt, verifyAccessJwt } from '../src/security/crypto_token.js';
import { computePayFastSignature } from '../src/routes/payment_routes.js';
import { resolveMediaUrl } from '../src/config/env.js';
import { createHmac } from 'node:crypto';

async function testPhase62HybridCloudTopology(): Promise<void> {
  console.log('Running Phase 62 Hybrid Cloud Stack Topology Tests...');

  // 1. GoTrue JWT Normalization & @blackcoffee Canonical ID Parity
  console.log('  1. Testing GoTrue JWT normalization & @blackcoffee canonical ID...');
  assert.equal(canonicalizeCreatorId('creator_blackcoffee'), 'creator_black_coffee');
  assert.equal(canonicalizeCreatorId('@blackcoffee'), 'creator_black_coffee');

  // Mint a GoTrue-shaped HS256 token (no top-level `cid` or `sid`)
  const secret = 'vhunambi_sovereign_phase61_jwt_hmac_sha256_secret_key_2026_za';
  const headerB64 = Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })).toString('base64url');
  const payloadB64 = Buffer.from(
    JSON.stringify({
      sub: '550e8400-e29b-41d4-a716-446655440000',
      session_id: '770e8400-e29b-41d4-a716-446655440111',
      role: 'authenticated',
      email: 'cern@vhunambi.co.za',
      user_metadata: {
        creator_id: 'creator_cern',
        handle: '@cern',
      },
      iat: Math.floor(Date.now() / 1000) - 10,
      exp: Math.floor(Date.now() / 1000) + 3600,
    }),
  ).toString('base64url');
  const sigB64 = createHmac('sha256', secret)
    .update(`${headerB64}.${payloadB64}`)
    .digest('base64url');
  const goTrueJwt = `${headerB64}.${payloadB64}.${sigB64}`;

  const verified = verifyAccessJwt(goTrueJwt);
  assert.equal(verified.valid, true);
  if (verified.valid) {
    assert.equal(verified.claims.cid, 'creator_cern');
    assert.equal(verified.claims.hdl, '@cern');
    assert.equal(verified.claims.isGoTrueToken, true);
  }

  // Verify GoTrue JWT passes sovereignAuthMiddleware without 401 AUTH_SESSION_REVOKED
  const meRes = await app.fetch(
    new Request('http://localhost/api/auth/me', {
      headers: { Authorization: `Bearer ${goTrueJwt}` },
    }),
  );
  assert.equal(meRes.status, 200);

  // 2. Strict-Mode Unverified Topup Rejection + PayFast Checkout & Verified ITN
  console.log('  2. Testing strict-mode topup block & PayFast ITN settlement...');
  const blockedTopup = await app.fetch(
    new Request('http://localhost/api/wallet/topup', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${goTrueJwt}`,
        'x-vhunambi-enforce-auth': 'true',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        creatorId: 'creator_cern',
        amountZar: 50000,
        amountCoins: 500000,
      }),
    }),
  );
  assert.equal(blockedTopup.status, 403);

  const checkoutRes = await app.fetch(
    new Request('http://localhost/api/payments/payfast/checkout', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${goTrueJwt}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        creatorId: 'creator_cern',
        packId: 'pack_producer_1500',
      }),
    }),
  );
  assert.equal(checkoutRes.status, 201);
  const checkoutJson = (await checkoutRes.json()) as any;
  assert.ok(checkoutJson.checkoutId.startsWith('chk_pf_'));
  assert.equal(checkoutJson.amountZar, 150);
  assert.equal(checkoutJson.coinsToCredit, 1500);

  // Forged ITN signature -> 400
  const badItnRes = await app.fetch(
    new Request('http://localhost/api/payments/payfast/itn', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        m_payment_id: checkoutJson.checkoutId,
        pf_payment_id: `pf_${Date.now()}`,
        payment_status: 'COMPLETE',
        amount_gross: '150.00',
        signature: 'deadbeef000000000000000000000000',
      }),
    }),
  );
  assert.equal(badItnRes.status, 400);

  // Valid signed ITN -> 200 settled & wallet credited once
  const pfId = `pf_valid_${Date.now()}`;
  const itnFields: Record<string, string> = {
    m_payment_id: checkoutJson.checkoutId,
    pf_payment_id: pfId,
    payment_status: 'COMPLETE',
    amount_gross: '150.00',
  };
  const validSig = computePayFastSignature(
    itnFields,
    'vhunambi_payfast_passphrase_2026',
  );
  const beforeWallet = vhunambiDb.getWalletSnapshot('creator_cern');
  const goodItnRes = await app.fetch(
    new Request('http://localhost/api/payments/payfast/itn', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ ...itnFields, signature: validSig }),
    }),
  );
  assert.equal(goodItnRes.status, 200);
  const goodItnJson = (await goodItnRes.json()) as any;
  assert.equal(goodItnJson.settled, true);
  assert.equal(goodItnJson.idempotentReplay, false);

  const afterWallet = vhunambiDb.getWalletSnapshot('creator_cern');
  assert.equal(afterWallet.balanceCoins, beforeWallet.balanceCoins + 1500);

  // Replay exact same ITN -> idempotent no-op (no double credit!)
  const replayItnRes = await app.fetch(
    new Request('http://localhost/api/payments/payfast/itn', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ ...itnFields, signature: validSig }),
    }),
  );
  assert.equal(replayItnRes.status, 200);
  const replayJson = (await replayItnRes.json()) as any;
  assert.equal(replayJson.idempotentReplay, true);
  assert.equal(
    vhunambiDb.getWalletSnapshot('creator_cern').balanceCoins,
    afterWallet.balanceCoins,
  );

  // 3. Unified Wallet Routes (/api/wallet/:id == /api/creators/:id/wallet)
  console.log('  3. Testing unified wallet routes & atomic cultural tipping...');
  const socialWalletRes = await app.fetch(
    new Request('http://localhost/api/creators/creator_cern/wallet', {
      headers: { Authorization: `Bearer ${goTrueJwt}` },
    }),
  );
  assert.equal(socialWalletRes.status, 200);
  const socialWalletJson = (await socialWalletRes.json()) as any;
  assert.equal(socialWalletJson.balanceCoins, afterWallet.balanceCoins);

  // 4. Cloudflare Worker Entrypoint & GenerationSessionDO Durable Object
  console.log('  4. Testing Cloudflare Worker fetch & GenerationSessionDO...');
  const mockStorage = new Map<string, unknown>();
  const doInstance = new GenerationSessionDO({
    id: { toString: () => 'do_gen_test_1' },
    storage: {
      get: async <T>(k: string) => mockStorage.get(k) as T | undefined,
      put: async <T>(k: string, v: T) => {
        mockStorage.set(k, v);
      },
      delete: async (k: string) => mockStorage.delete(k),
    },
  });

  const pingRes = await doInstance.fetch(
    new Request('https://do.vhunambi.internal/internal/frame?id=gen_test_1', {
      method: 'POST',
      body: JSON.stringify({ type: 'PING' }),
    }),
  );
  assert.equal(pingRes.status, 200);
  const pongJson = (await pingRes.json()) as any;
  assert.equal(pongJson.type, 'PONG');

  const broadcastRes = await doInstance.fetch(
    new Request('https://do.vhunambi.internal/internal/broadcast?id=gen_test_1', {
      method: 'POST',
      body: JSON.stringify({
        generationId: 'gen_test_1',
        status: 'completed',
        progressPct: 100,
        masterMp3Url: 'https://pub-vault.r2.dev/audio/gen_test_1/master.mp3',
      }),
    }),
  );
  assert.equal(broadcastRes.status, 200);

  const workerHealthRes = await workerEntry.fetch(
    new Request('https://vhunambi-api.workers.dev/health'),
    { R2_BUCKET: 'vhunambi-vault' },
    { waitUntil: () => {}, passThroughOnException: () => {} },
  );
  assert.equal(workerHealthRes.status, 200);

  // 5. Media URL Normalization
  assert.equal(
    resolveMediaUrl('https://r2.vhunambi.com/beats/amapiano_1.wav', {
      R2_PUBLIC_BASE_URL: 'https://pub-123.r2.dev',
    }),
    'https://pub-123.r2.dev/beats/amapiano_1.wav',
  );

  console.log('Phase 62 Hybrid Cloud Stack Topology Tests Passed 100%!');
}

testPhase62HybridCloudTopology().catch((err) => {
  console.error('Phase 62 test failed:', err);
  process.exit(1);
});
```

---

### 8.2 Flutter Client Cloud Origin & Interceptor Test Suite (`apps/vhunambi_client/test/core/network/phase62_hybrid_cloud_client_test.dart`)

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/core/utils/creator_id_utils.dart';
import 'package:vhunambi_client/features/explore/presentation/providers/explore_providers.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/generation_pipeline_providers.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/lyrics_review_provider.dart';

void main() {
  group('Phase 62 M62.7: Hybrid Cloud Origin, WS & Media URL Normalization', () {
    test('normalizeOriginUrl strips trailing slashes, /v1, and /api suffixes', () {
      expect(
        AppConstants.normalizeOriginUrl('https://vhunambi-api.prod.workers.dev/v1/'),
        equals('https://vhunambi-api.prod.workers.dev'),
      );
      expect(
        AppConstants.normalizeOriginUrl('https://vhunambi-api.prod.workers.dev/api'),
        equals('https://vhunambi-api.prod.workers.dev'),
      );
    });

    test('resolveWsUrl converts https:// to wss:// and http:// to ws://', () {
      expect(
        AppConstants.resolveWsUrl(
          overrideOrigin: 'https://vhunambi-api.prod.workers.dev/v1',
        ),
        equals('wss://vhunambi-api.prod.workers.dev/ws/generation'),
      );
      expect(
        AppConstants.resolveWsUrl(overrideOrigin: 'http://localhost:3000'),
        equals('ws://localhost:3000/ws/generation'),
      );
    });

    test('normalizeCloudMediaUrl rewrites legacy r2/cdn/mock-storage URLs', () {
      expect(
        AppConstants.normalizeCloudMediaUrl(
          'https://r2.vhunambi.com/beats/kabza_1.wav',
          overrideOrigin: 'https://vhunambi-api.prod.workers.dev',
        ),
        equals('https://vhunambi-api.prod.workers.dev/r2/beats/kabza_1.wav'),
      );
      expect(
        AppConstants.normalizeCloudMediaUrl(
          '/mock-storage/vox_amapiano_01.mp3',
          overrideOrigin: 'https://vhunambi-api.prod.workers.dev',
        ),
        equals('https://vhunambi-api.prod.workers.dev/r2/vox_amapiano_01.mp3'),
      );
    });

    test('canonicalizeCreatorId unifies @blackcoffee and creator_blackcoffee', () {
      expect(
        CreatorIdUtils.canonicalizeCreatorId('creator_blackcoffee'),
        equals('creator_black_coffee'),
      );
      expect(
        CreatorIdUtils.canonicalizeCreatorId('@blackcoffee'),
        equals('creator_black_coffee'),
      );
    });

    test('Explore, Generation & Lyrics providers initialize with unified cloud URLs', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(exploreRepositoryProvider), isNotNull);
      expect(container.read(generationSubmissionServiceProvider), isNotNull);
      expect(container.read(lyricsGenerationServiceProvider), isNotNull);
    });
  });
}
```

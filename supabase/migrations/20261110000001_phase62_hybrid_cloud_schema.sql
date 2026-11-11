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
  interaction_type TEXT NOT NULL,
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
  status TEXT NOT NULL DEFAULT 'pending',
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

-- =============================================================================
-- IDEMPOTENT SOVEREIGN CREATOR SEEDS
-- =============================================================================
INSERT INTO public.creators (id, handle, display_name, avatar_url, archetype, tier)
VALUES
  ('creator_cern', '@cern', 'Cern', 'https://pub-vhunambi-vault.r2.dev/avatars/cern.jpg', 'aiSonicArchitect', 'verified'),
  ('creator_makhadzi', '@makhadzi', 'Makhadzi', 'https://pub-vhunambi-vault.r2.dev/avatars/makhadzi.jpg', 'traditionalInstrumentalist', 'verified'),
  ('creator_sigwa', '@sigwa', 'Sigwa', 'https://pub-vhunambi-vault.r2.dev/avatars/sigwa.jpg', 'traditionalInstrumentalist', 'verified'),
  ('creator_kabza', '@kabza', 'Kabza De Small', 'https://pub-vhunambi-vault.r2.dev/avatars/kabza.jpg', 'aiSonicArchitect', 'verified'),
  ('creator_focalistic', '@focalistic', 'Focalistic', 'https://pub-vhunambi-vault.r2.dev/avatars/focalistic.jpg', 'aiSonicArchitect', 'verified'),
  ('creator_tyla', '@tyla', 'Tyla', 'https://pub-vhunambi-vault.r2.dev/avatars/tyla.jpg', 'vocalist', 'verified'),
  ('creator_black_coffee', '@blackcoffee', 'Black Coffee', 'https://pub-vhunambi-vault.r2.dev/avatars/blackcoffee.jpg', 'aiSonicArchitect', 'verified')
ON CONFLICT (id) DO NOTHING;

COMMIT;


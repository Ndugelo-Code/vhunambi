import { createHash, randomUUID } from 'node:crypto';
import {
  generateRefreshTokenPair,
  hashPassword,
  hashRefreshToken,
  signAccessJwt,
  verifyPassword,
} from '../security/crypto_token.js';
import type { GenerationJob } from '../modules/jobs/job_types.js';
import {
  canonicalizeCreatorId,
  EdgeIsolateDatabaseEngine,
  EdgePersistenceBridge,
  getEdgeIsolateDatabaseEngine,
  SA_BANK_REGISTRY,
  type AuthTokenBundle,
  type BankPayoutRequest,
  type ExploreFeedOptions,
  type ExploreTrackRecord,
  type PaymentRailId,
  type PlaylistRecord,
  type SaBankMetadata,
  type SovereignAuthSessionRecord,
  type SovereignUserRecord,
  type SyncDeltaResult,
  type SyncMutationRecord,
} from './edge_persistence_bridge.js';

export {
  canonicalizeCreatorId,
  EdgeIsolateDatabaseEngine,
  EdgePersistenceBridge,
  getEdgeIsolateDatabaseEngine,
  SA_BANK_REGISTRY,
  type AuthTokenBundle,
  type BankPayoutRequest,
  type ExploreFeedOptions,
  type ExploreTrackRecord,
  type PaymentRailId,
  type PlaylistRecord,
  type SaBankMetadata,
  type SovereignAuthSessionRecord,
  type SovereignUserRecord,
  type SyncDeltaResult,
  type SyncMutationRecord,
};

type SqliteBuiltinModule = typeof import('node:sqlite');
type SqliteDatabaseSync = InstanceType<SqliteBuiltinModule['DatabaseSync']>;
type FsBuiltinModule = typeof import('node:fs');
type PathBuiltinModule = typeof import('node:path');

let _simulateEdgeIsolateMode = false;

/**
 * Enables/disables simulated Cloudflare `workerd` V8 isolate mode for tests,
 * causing `isNodeSqliteAvailable()` to return `false` and `vhunambiDb` to route
 * transparently through `EdgeIsolateDatabaseEngine`.
 */
export function setSimulateEdgeIsolateMode(enabled: boolean): void {
  _simulateEdgeIsolateMode = enabled;
}

export function isSimulatedEdgeIsolateMode(): boolean {
  return _simulateEdgeIsolateMode;
}

export function isCloudflareWorkerRuntime(): boolean {
  const g = globalThis as unknown as {
    navigator?: { userAgent?: string };
    WebSocketPair?: unknown;
  };
  if (g.navigator?.userAgent === 'Cloudflare-Workers') {
    return true;
  }
  if (typeof g.WebSocketPair === 'function') {
    return true;
  }
  return false;
}

export function isNodeSqliteAvailable(): boolean {
  if (_simulateEdgeIsolateMode || isCloudflareWorkerRuntime()) {
    return false;
  }
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
  if (_simulateEdgeIsolateMode || isCloudflareWorkerRuntime()) {
    throw new Error(
      'SQLITE_UNAVAILABLE_IN_EDGE_ISOLATE: Use SupabaseCloudDriver in Cloudflare Workers.',
    );
  }
  const getter = (
    process as unknown as { getBuiltinModule?: (id: string) => unknown }
  )?.getBuiltinModule;
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
  const getter = (
    process as unknown as { getBuiltinModule?: (id: string) => unknown }
  )?.getBuiltinModule;
  return typeof getter === 'function'
    ? (getter('node:fs') as FsBuiltinModule | undefined)
    : undefined;
}

function loadNodePath(): PathBuiltinModule | undefined {
  const getter = (
    process as unknown as { getBuiltinModule?: (id: string) => unknown }
  )?.getBuiltinModule;
  return typeof getter === 'function'
    ? (getter('node:path') as PathBuiltinModule | undefined)
    : undefined;
}

/**
 * Enterprise SQLite WAL Persistence Engine for Vhunambi API (REQ-P45-DB-01..06).
 * Supports zero-configuration disk persistence with WAL journal mode and in-memory test fallback.
 */
export class VhunambiDatabase {
  private db: SqliteDatabaseSync;
  private isMemory: boolean;

  public static isNodeSqliteAvailable(): boolean {
    return isNodeSqliteAvailable();
  }

  constructor(dbPathOrMemory?: string) {
    const sqliteMod = loadNodeSqlite();
    const isTestProcess =
      typeof process !== 'undefined' &&
      (process.env.NODE_ENV === 'test' ||
        process.argv.some((a) => a.endsWith('.test.ts') || a.endsWith('.test.js')));
    if (dbPathOrMemory === ':memory:' || (!dbPathOrMemory && isTestProcess)) {
      this.db = new sqliteMod.DatabaseSync(':memory:');
      this.isMemory = true;
    } else {
      const fsMod = loadNodeFs();
      const pathMod = loadNodePath();
      const targetPath =
        dbPathOrMemory ||
        (pathMod
          ? pathMod.resolve(process.cwd(), 'data', 'vhunambi_api.sqlite3')
          : './data/vhunambi_api.sqlite3');
      if (fsMod && pathMod) {
        const dir = pathMod.dirname(targetPath);
        if (!fsMod.existsSync(dir)) {
          fsMod.mkdirSync(dir, { recursive: true });
        }
      }
      this.db = new sqliteMod.DatabaseSync(targetPath);
      this.isMemory = false;
    }

    this.initPragmasAndTables();
    this.seedInitialDataIfEmpty();
  }

  private initPragmasAndTables(): void {
    if (!this.isMemory) {
      this.db.exec('PRAGMA journal_mode = WAL;');
    }
    this.db.exec('PRAGMA foreign_keys = ON;');

    // 1. Sync Mutation Log
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS sync_mutation_log (
        seq INTEGER PRIMARY KEY AUTOINCREMENT,
        idempotency_key TEXT UNIQUE NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        action TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        creator_id TEXT NOT NULL DEFAULT 'system',
        created_at TEXT NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_mutation_seq ON sync_mutation_log(seq);
      CREATE INDEX IF NOT EXISTS idx_mutation_idempotency ON sync_mutation_log(idempotency_key);
    `);

    const syncCols = this.db
      .prepare('PRAGMA table_info(sync_mutation_log)')
      .all() as Array<{ name: string }>;
    if (!syncCols.some((c) => c.name === 'creator_id')) {
      this.db.exec(
        "ALTER TABLE sync_mutation_log ADD COLUMN creator_id TEXT NOT NULL DEFAULT 'system';",
      );
    }
    this.db.exec(
      'CREATE INDEX IF NOT EXISTS idx_sync_mutation_creator_seq ON sync_mutation_log(creator_id, seq);',
    );

    // 2. Creators
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS creators (
        id TEXT PRIMARY KEY,
        handle TEXT UNIQUE NOT NULL,
        display_name TEXT NOT NULL,
        avatar_url TEXT,
        archetype TEXT NOT NULL,
        tier TEXT NOT NULL DEFAULT 'emerging',
        reputation_score INTEGER DEFAULT 100,
        data_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    `);

    // 3. Explore Tracks
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS explore_tracks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        artist_id TEXT NOT NULL,
        artist_name TEXT NOT NULL,
        genre TEXT NOT NULL,
        audio_url TEXT NOT NULL,
        bpm INTEGER,
        play_count INTEGER DEFAULT 0,
        like_count INTEGER DEFAULT 0,
        cosign_count INTEGER DEFAULT 0,
        discovery_stage TEXT NOT NULL DEFAULT 'freshCrate',
        data_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_explore_tracks_genre ON explore_tracks(genre, play_count DESC);
    `);

    // 4. Kinetic Posts
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS kinetic_posts (
        id TEXT PRIMARY KEY,
        creator_id TEXT NOT NULL,
        creator_handle TEXT NOT NULL,
        creator_name TEXT NOT NULL,
        caption TEXT NOT NULL,
        media_type TEXT NOT NULL,
        attachment_id TEXT,
        cosign_count INTEGER DEFAULT 0,
        cosign_target INTEGER DEFAULT 25,
        repost_count INTEGER DEFAULT 0,
        discovery_stage TEXT NOT NULL DEFAULT 'freshCrate',
        data_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    `);

    // 5. Published Clips
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS published_clips (
        id TEXT PRIMARY KEY,
        creator_id TEXT NOT NULL,
        creator_handle TEXT NOT NULL,
        video_url TEXT NOT NULL,
        audio_title TEXT NOT NULL,
        bantu_language TEXT,
        views_count INTEGER DEFAULT 0,
        likes_count INTEGER DEFAULT 0,
        data_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    `);

    // 6. Reel Comments
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS reel_comments (
        id TEXT PRIMARY KEY,
        reel_id TEXT NOT NULL,
        creator_id TEXT NOT NULL,
        content TEXT NOT NULL,
        language_code TEXT,
        created_at TEXT NOT NULL
      );
    `);

    // 7. Marketplace Assets & Phase 58 Sovereign Licensing Registry
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS marketplace_assets (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        producer_id TEXT NOT NULL,
        asset_category TEXT NOT NULL,
        price_zar REAL NOT NULL,
        price_coins INTEGER NOT NULL,
        is_exclusive_sold INTEGER NOT NULL DEFAULT 0,
        exclusive_buyer_id TEXT,
        data_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    `);
    try {
      this.db.exec(
        'ALTER TABLE marketplace_assets ADD COLUMN is_exclusive_sold INTEGER NOT NULL DEFAULT 0;',
      );
    } catch (_) { }
    try {
      this.db.exec(
        'ALTER TABLE marketplace_assets ADD COLUMN exclusive_buyer_id TEXT;',
      );
    } catch (_) { }

    this.db.exec(`
      CREATE TABLE IF NOT EXISTS beat_licenses (
        certificate_id TEXT PRIMARY KEY,
        license_hash TEXT UNIQUE NOT NULL,
        beat_id TEXT NOT NULL,
        producer_id TEXT NOT NULL,
        buyer_id TEXT NOT NULL,
        tier TEXT NOT NULL,
        coins_paid INTEGER NOT NULL,
        zar_paid REAL NOT NULL,
        producer_coins INTEGER NOT NULL,
        producer_zar REAL NOT NULL,
        issued_at TEXT NOT NULL,
        data_json TEXT NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_beat_licenses_buyer ON beat_licenses(buyer_id);
      CREATE INDEX IF NOT EXISTS idx_beat_licenses_beat ON beat_licenses(beat_id);
    `);

    // 8. Sound Signatures
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS sound_signatures (
        id TEXT PRIMARY KEY,
        creator_id TEXT NOT NULL,
        timbre_name TEXT NOT NULL,
        match_confidence INTEGER NOT NULL,
        data_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    `);

    // 9. User Library Sync (Cloud Vault)
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS user_library_sync (
        id TEXT PRIMARY KEY,
        creator_id TEXT NOT NULL,
        item_type TEXT NOT NULL,
        title TEXT NOT NULL,
        data_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    `);

    // 10. Sovereign Wallet Ledger
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS wallet_ledger (
        id TEXT PRIMARY KEY,
        creator_id TEXT NOT NULL,
        type TEXT NOT NULL,
        amount_zar REAL NOT NULL DEFAULT 0.0,
        amount_coins INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL,
        reference TEXT,
        data_json TEXT NOT NULL,
        created_at TEXT NOT NULL
      );
    `);

    // 11. Bank Accounts
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS bank_accounts (
        id TEXT PRIMARY KEY,
        creator_id TEXT NOT NULL,
        bank_name TEXT NOT NULL,
        account_number TEXT NOT NULL,
        branch_code TEXT NOT NULL,
        account_type TEXT NOT NULL,
        is_verified INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    `);

    // 12. Playlists (Phase 59 Cloud CRUD & Sharing)
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS playlists (
        id TEXT PRIMARY KEY,
        creator_id TEXT NOT NULL DEFAULT 'usr_me',
        title TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        cover_image_url TEXT,
        track_ids_json TEXT NOT NULL DEFAULT '[]',
        is_public INTEGER NOT NULL DEFAULT 0,
        share_code TEXT,
        share_url TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_playlists_creator ON playlists(creator_id, updated_at DESC);
    `);

    // 13. Sovereign Identity Users & Session Vault (Phase 61)
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS users (
        user_id TEXT PRIMARY KEY,
        creator_id TEXT NOT NULL UNIQUE,
        handle TEXT NOT NULL UNIQUE,
        email TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'creator',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (creator_id) REFERENCES creators(id)
      );
      CREATE INDEX IF NOT EXISTS idx_users_handle ON users(handle);
      CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

      CREATE TABLE IF NOT EXISTS auth_sessions (
        session_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        creator_id TEXT NOT NULL,
        family_id TEXT NOT NULL,
        refresh_token_hash TEXT NOT NULL,
        previous_token_hash TEXT,
        device_label TEXT NOT NULL DEFAULT 'vhunambi_client',
        expires_at TEXT NOT NULL,
        revoked INTEGER NOT NULL DEFAULT 0,
        revoke_reason TEXT,
        created_at TEXT NOT NULL,
        rotated_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(user_id)
      );
      CREATE INDEX IF NOT EXISTS idx_auth_sessions_user ON auth_sessions(user_id, revoked);
      CREATE INDEX IF NOT EXISTS idx_auth_sessions_family ON auth_sessions(family_id);
      CREATE INDEX IF NOT EXISTS idx_auth_sessions_token_hash ON auth_sessions(refresh_token_hash);
    `);

    // 14-19. Phase 62 Persistence Tables (replacing all volatile RAM stores)
    try {
      this.db.exec('ALTER TABLE published_clips ADD COLUMN remixed_from_clip_id TEXT;');
    } catch (_) { }
    try {
      this.db.exec('ALTER TABLE published_clips ADD COLUMN comments_count INTEGER DEFAULT 0;');
    } catch (_) { }
    try {
      this.db.exec('ALTER TABLE published_clips ADD COLUMN remixes_count INTEGER DEFAULT 0;');
    } catch (_) { }
    try {
      this.db.exec("ALTER TABLE reel_comments ADD COLUMN data_json TEXT NOT NULL DEFAULT '{}';");
    } catch (_) { }
    try {
      this.db.exec('CREATE INDEX IF NOT EXISTS idx_published_clips_remix_parent ON published_clips(remixed_from_clip_id);');
    } catch (_) { }
    try {
      this.db.exec('CREATE INDEX IF NOT EXISTS idx_reel_comments_clip ON reel_comments(reel_id, created_at DESC);');
    } catch (_) { }

    this.db.exec(`
      CREATE TABLE IF NOT EXISTS generation_jobs (
        generation_id TEXT PRIMARY KEY,
        creator_id TEXT NOT NULL DEFAULT 'creator_cern',
        job_kind TEXT NOT NULL DEFAULT 'audio_synthesis',
        provider_task_id TEXT,
        status TEXT NOT NULL DEFAULT 'queued',
        step TEXT NOT NULL DEFAULT 'queued',
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
        data_json TEXT NOT NULL DEFAULT '{}',
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
  }

  private seedInitialDataIfEmpty(): void {
    const creatorCount = this.db.prepare('SELECT COUNT(*) as count FROM creators').get() as { count: number };
    if (creatorCount.count === 0) {
      const now = new Date().toISOString();
      const insertCreator = this.db.prepare(`
        INSERT INTO creators (id, handle, display_name, avatar_url, archetype, tier, reputation_score, data_json, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `);

      insertCreator.run(
        'creator_cern',
        '@cern',
        'Cern',
        'https://cdn.vhunambi.com/avatars/cern.jpg',
        'aiSonicArchitect',
        'emerging',
        140,
        JSON.stringify({ monthlyListenersCount: 14200 }),
        now,
        now
      );

      insertCreator.run(
        'creator_sigwa',
        '@sigwa',
        'Sigwa',
        'https://cdn.vhunambi.com/avatars/sigwa.jpg',
        'traditionalInstrumentalist',
        'verified',
        220,
        JSON.stringify({ monthlyListenersCount: 28400 }),
        now,
        now
      );

      insertCreator.run(
        'usr_me',
        '@vhunambi_creator',
        'Vhunambi Creator',
        'https://cdn.vhunambi.com/avatars/me.jpg',
        'aiSonicArchitect',
        'verified',
        180,
        JSON.stringify({ monthlyListenersCount: 18500 }),
        now,
        now
      );

      insertCreator.run(
        'creator_makhadzi',
        '@makhadzi',
        'Makhadzi',
        'https://cdn.vhunambi.com/avatars/makhadzi.jpg',
        'traditionalInstrumentalist',
        'verified',
        340,
        JSON.stringify({ monthlyListenersCount: 95000 }),
        now,
        now
      );

      // Seed Initial Kinetic Posts
      const insertPost = this.db.prepare(`
        INSERT INTO kinetic_posts (id, creator_id, creator_handle, creator_name, caption, media_type, cosign_count, cosign_target, repost_count, discovery_stage, data_json, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `);

      insertPost.run(
        'post_seed_01',
        'creator_sigwa',
        '@sigwa',
        'Sigwa',
        'Late night studio session testing the Venda Folk LoRA & sub-bass log drum slide 🔥 What do you think of this rhythm?',
        'audio_card',
        22,
        25,
        14,
        'freshCrate',
        JSON.stringify({ genre: 'Venda Folk', bpm: 114 }),
        now,
        now
      );

      // Seed Wallet Balance for creator_cern
      const insertTx = this.db.prepare(`
        INSERT OR IGNORE INTO wallet_ledger (id, creator_id, type, amount_zar, amount_coins, status, reference, data_json, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      `);

      insertTx.run(
        'tx_seed_01',
        'creator_cern',
        'topup',
        1420.00,
        4750,
        'completed',
        'INITIAL_CREDIT',
        JSON.stringify({ note: 'Seeded wallet balance' }),
        now
      );
    }

    // Ensure Phase 59 default creators & wallets exist even when upgrading an existing SQLite DB
    const seedNow = new Date().toISOString();
    const insertCreatorIgnore = this.db.prepare(`
      INSERT OR IGNORE INTO creators (id, handle, display_name, avatar_url, archetype, tier, reputation_score, data_json, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);
    insertCreatorIgnore.run(
      'usr_me',
      '@vhunambi_creator',
      'Vhunambi Creator',
      'https://cdn.vhunambi.com/avatars/me.jpg',
      'aiSonicArchitect',
      'verified',
      180,
      JSON.stringify({ monthlyListenersCount: 18500 }),
      seedNow,
      seedNow
    );
    insertCreatorIgnore.run(
      'creator_makhadzi',
      '@makhadzi',
      'Makhadzi',
      'https://cdn.vhunambi.com/avatars/makhadzi.jpg',
      'traditionalInstrumentalist',
      'verified',
      340,
      JSON.stringify({ monthlyListenersCount: 95000 }),
      seedNow,
      seedNow
    );

    const ensureWalletStmt = this.db.prepare(`
      INSERT OR IGNORE INTO wallet_ledger (id, creator_id, type, amount_zar, amount_coins, status, reference, data_json, created_at)
      VALUES (?, ?, 'topup', ?, ?, 'completed', 'INITIAL_CREDIT', ?, ?)
    `);
    for (const cid of ['usr_me', 'creator_makhadzi']) {
      if (!this.hasWalletActivity(cid)) {
        ensureWalletStmt.run(
          `tx_seed_${cid}`,
          cid,
          1420.00,
          4750,
          JSON.stringify({ note: 'Seeded default Phase 59 creator balance' }),
          seedNow
        );
      }
    }

    const trackCount = (
      this.db.prepare('SELECT COUNT(*) as cnt FROM explore_tracks').get() as { cnt: number }
    ).cnt;

    if (trackCount === 0) {
      const now = new Date().toISOString();
      const insertTrack = this.db.prepare(`
        INSERT INTO explore_tracks (
          id, title, artist_id, artist_name, genre, audio_url, bpm,
          play_count, like_count, cosign_count, discovery_stage, data_json,
          created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `);

      const seedTracks: Array<{
        id: string;
        title: string;
        artistId: string;
        artistName: string;
        genre: string;
        subGenre: string;
        language: string;
        province: string;
        mood: string;
        musicalKey: string;
        bpm: number;
        audioUrl: string;
        coverUrl: string;
        durationMs: number;
        plays: number;
        likes: number;
        cosigns: number;
        comments: number;
        shares: number;
        stemsAvailable: boolean;
        creatorHandle: string;
        isNew: boolean;
        trendingRank?: number;
        createdAt: string;
      }> = [
          {
            id: 'trk_cloud_1',
            title: 'Sovereign Groove (Quantum Mix)',
            artistId: 'usr_amapiano_king',
            artistName: 'Kabza Spirit',
            genre: 'Amapiano',
            subGenre: 'Private School',
            language: 'isiZulu',
            province: 'Gauteng',
            mood: 'Deep',
            musicalKey: 'Fm',
            bpm: 113,
            audioUrl: 'https://cdn.vhunambi.za/audio/sovereign_groove.wav',
            coverUrl: 'https://cdn.vhunambi.za/covers/sovereign_groove.jpg',
            durationMs: 225000,
            plays: 14800,
            likes: 1420,
            cosigns: 312,
            comments: 89,
            shares: 210,
            stemsAvailable: true,
            creatorHandle: '@kabza_spirit',
            isNew: false,
            trendingRank: 1,
            createdAt: new Date(Date.now() - 4 * 3600 * 1000).toISOString(),
          },
          {
            id: 'trk_cloud_2',
            title: 'Tzaneen Sun (Lekompo Anthem)',
            artistId: 'usr_limpopo_wave',
            artistName: 'Kharishma Wave',
            genre: 'Lekompo',
            subGenre: 'Bolobedu',
            language: 'Sepedi',
            province: 'Limpopo',
            mood: 'Joyful',
            musicalKey: 'Am',
            bpm: 116,
            audioUrl: 'https://cdn.vhunambi.za/audio/tzaneen_sun.wav',
            coverUrl: 'https://cdn.vhunambi.za/covers/tzaneen_sun.jpg',
            durationMs: 198000,
            plays: 9400,
            likes: 980,
            cosigns: 265,
            comments: 64,
            shares: 185,
            stemsAvailable: true,
            creatorHandle: '@kharishma_wave',
            isNew: true,
            trendingRank: 2,
            createdAt: new Date(Date.now() - 6 * 3600 * 1000).toISOString(),
          },
          {
            id: 'trk_cloud_3',
            title: 'Durban 3-Step Horizon',
            artistId: 'usr_durban_gqom',
            artistName: 'Dlala Thukzin',
            genre: '3-Step',
            subGenre: 'Afro-Tech',
            language: 'isiZulu',
            province: 'KwaZulu-Natal',
            mood: 'Hypnotic',
            musicalKey: 'Cm',
            bpm: 118,
            audioUrl: 'https://cdn.vhunambi.za/audio/durban_3step.wav',
            coverUrl: 'https://cdn.vhunambi.za/covers/durban_3step.jpg',
            durationMs: 252000,
            plays: 18200,
            likes: 1650,
            cosigns: 410,
            comments: 142,
            shares: 390,
            stemsAvailable: true,
            creatorHandle: '@dlala_thukzin',
            isNew: false,
            trendingRank: 3,
            createdAt: new Date(Date.now() - 12 * 3600 * 1000).toISOString(),
          },
          {
            id: 'trk_cloud_4',
            title: 'Soweto Midnight Log Drum',
            artistId: 'usr_amapiano_king',
            artistName: 'Kelvin Momo',
            genre: 'Amapiano',
            subGenre: 'Sgija',
            language: 'Setswana',
            province: 'Gauteng',
            mood: 'Chill',
            musicalKey: 'Gm',
            bpm: 112,
            audioUrl: 'https://cdn.vhunambi.za/audio/soweto_log_drum.wav',
            coverUrl: 'https://cdn.vhunambi.za/covers/soweto_log_drum.jpg',
            durationMs: 290000,
            plays: 4600,
            likes: 820,
            cosigns: 134,
            comments: 53,
            shares: 97,
            stemsAvailable: true,
            creatorHandle: '@kelvin_momo',
            isNew: false,
            createdAt: new Date(Date.now() - 18 * 3600 * 1000).toISOString(),
          },
          {
            id: 'trk_cloud_5',
            title: 'Umlazi Bunker Dub',
            artistId: 'usr_durban_gqom',
            artistName: 'Que DJ',
            genre: 'Gqom',
            subGenre: 'Core Gqom',
            language: 'isiZulu',
            province: 'KwaZulu-Natal',
            mood: 'Energetic',
            musicalKey: 'Dm',
            bpm: 127,
            audioUrl: 'https://cdn.vhunambi.za/audio/umlazi_bunker.wav',
            coverUrl: 'https://cdn.vhunambi.za/covers/umlazi_bunker.jpg',
            durationMs: 210000,
            plays: 2300,
            likes: 490,
            cosigns: 88,
            comments: 31,
            shares: 64,
            stemsAvailable: false,
            creatorHandle: '@que_dj',
            isNew: false,
            createdAt: new Date(Date.now() - 24 * 3600 * 1000).toISOString(),
          },
          {
            id: 'trk_cloud_6',
            title: 'Mamelodi Bacardi Bounce',
            artistId: 'usr_amapiano_king',
            artistName: 'Mellow & Sleazy',
            genre: 'Bacardi',
            subGenre: 'Pitori Bacardi',
            language: 'Sepedi',
            province: 'Gauteng',
            mood: 'Party',
            musicalKey: 'Em',
            bpm: 114,
            audioUrl: 'https://cdn.vhunambi.za/audio/mamelodi_bacardi.wav',
            coverUrl: 'https://cdn.vhunambi.za/covers/mamelodi_bacardi.jpg',
            durationMs: 204000,
            plays: 3100,
            likes: 610,
            cosigns: 112,
            comments: 44,
            shares: 82,
            stemsAvailable: true,
            creatorHandle: '@mellow_sleazy',
            isNew: true,
            createdAt: new Date(Date.now() - 30 * 3600 * 1000).toISOString(),
          },
          {
            id: 'trk_cloud_7',
            title: 'Lagos to Jozi Express',
            artistId: 'usr_me',
            artistName: 'Burna Boy',
            genre: 'Afrobeats',
            subGenre: 'Afro-Fusion',
            language: 'Yoruba',
            province: 'Gauteng',
            mood: 'Uplifting',
            musicalKey: 'F#m',
            bpm: 106,
            audioUrl: 'https://cdn.vhunambi.za/audio/lagos_jozi.wav',
            coverUrl: 'https://cdn.vhunambi.za/covers/lagos_jozi.jpg',
            durationMs: 195000,
            plays: 24500,
            likes: 2100,
            cosigns: 520,
            comments: 215,
            shares: 480,
            stemsAvailable: false,
            creatorHandle: '@burna_afro',
            isNew: false,
            trendingRank: 4,
            createdAt: new Date(Date.now() - 36 * 3600 * 1000).toISOString(),
          },
          {
            id: 'trk_cloud_8',
            title: 'Giyani Marimba Warp (184 BPM)',
            artistId: 'usr_limpopo_wave',
            artistName: 'Sho Madjozi',
            genre: 'Shangaan Electro',
            subGenre: 'Tsonga Warp',
            language: 'Xitsonga',
            province: 'Limpopo',
            mood: 'Electrifying',
            musicalKey: 'C',
            bpm: 184,
            audioUrl: 'https://cdn.vhunambi.za/audio/giyani_warp.wav',
            coverUrl: 'https://cdn.vhunambi.za/covers/giyani_warp.jpg',
            durationMs: 168000,
            plays: 1180,
            likes: 340,
            cosigns: 42,
            comments: 19,
            shares: 38,
            stemsAvailable: true,
            creatorHandle: '@sho_madjozi',
            isNew: true,
            createdAt: new Date(Date.now() - 8 * 3600 * 1000).toISOString(),
          },
          {
            id: 'trk_cloud_9',
            title: 'Zululand Acoustic Soul',
            artistId: 'usr_durban_gqom',
            artistName: 'Sjava',
            genre: 'Maskandi',
            subGenre: 'Trap-Maskandi',
            language: 'isiZulu',
            province: 'KwaZulu-Natal',
            mood: 'Soulful',
            musicalKey: 'G',
            bpm: 98,
            audioUrl: 'https://cdn.vhunambi.za/audio/zululand_soul.wav',
            coverUrl: 'https://cdn.vhunambi.za/covers/zululand_soul.jpg',
            durationMs: 236000,
            plays: 5200,
            likes: 740,
            cosigns: 155,
            comments: 68,
            shares: 120,
            stemsAvailable: true,
            creatorHandle: '@sjava_indawo',
            isNew: false,
            createdAt: new Date(Date.now() - 40 * 3600 * 1000).toISOString(),
          },
          {
            id: 'trk_cloud_10',
            title: 'Zola 7 Heritage Groove',
            artistId: 'usr_amapiano_king',
            artistName: 'Mandoza Legacy',
            genre: 'Kwaito',
            subGenre: '90s Kwaito',
            language: 'Tsotsitaal',
            province: 'Gauteng',
            mood: 'Nostalgic',
            musicalKey: 'Am',
            bpm: 105,
            audioUrl: 'https://cdn.vhunambi.za/audio/zola_heritage.wav',
            coverUrl: 'https://cdn.vhunambi.za/covers/zola_heritage.jpg',
            durationMs: 244000,
            plays: 2890,
            likes: 530,
            cosigns: 96,
            comments: 37,
            shares: 71,
            stemsAvailable: false,
            creatorHandle: '@kwaito_roots',
            isNew: false,
            createdAt: new Date(Date.now() - 48 * 3600 * 1000).toISOString(),
          },
          {
            id: 'trk_cloud_11',
            title: 'Clifton Sunset Deep',
            artistId: 'usr_me',
            artistName: 'Black Coffee',
            genre: 'Afro-Tech',
            subGenre: 'Deep Afro',
            language: 'isiXhosa',
            province: 'Western Cape',
            mood: 'Atmospheric',
            musicalKey: 'Bm',
            bpm: 120,
            audioUrl: 'https://cdn.vhunambi.za/audio/clifton_sunset.wav',
            coverUrl: 'https://cdn.vhunambi.za/covers/clifton_sunset.jpg',
            durationMs: 310000,
            plays: 21400,
            likes: 1890,
            cosigns: 490,
            comments: 160,
            shares: 410,
            stemsAvailable: true,
            creatorHandle: '@realblackcoffee',
            isNew: false,
            trendingRank: 5,
            createdAt: new Date(Date.now() - 52 * 3600 * 1000).toISOString(),
          },
          {
            id: 'trk_cloud_12',
            title: 'Pretoria Dub Chord Study',
            artistId: 'usr_me',
            artistName: 'Jullian Gomes',
            genre: 'Deep House',
            subGenre: 'SA Deep',
            language: 'English',
            province: 'Gauteng',
            mood: 'Warm',
            musicalKey: 'Dm',
            bpm: 117,
            audioUrl: 'https://cdn.vhunambi.za/audio/pretoria_dub.wav',
            coverUrl: 'https://cdn.vhunambi.za/covers/pretoria_dub.jpg',
            durationMs: 268000,
            plays: 920,
            likes: 290,
            cosigns: 34,
            comments: 14,
            shares: 29,
            stemsAvailable: true,
            creatorHandle: '@jullian_gomes',
            isNew: true,
            createdAt: now,
          },
        ];

      this.db.exec('BEGIN IMMEDIATE');
      try {
        for (const t of seedTracks) {
          const stage =
            t.plays >= 8000 || t.cosigns >= 250
              ? 'mainstage'
              : t.plays >= 1500 || t.cosigns >= 60
                ? 'risingBreakout'
                : 'freshCrate';
          insertTrack.run(
            t.id,
            t.title,
            t.artistId,
            t.artistName,
            t.genre,
            t.audioUrl,
            t.bpm,
            t.plays,
            t.likes,
            t.cosigns,
            stage,
            JSON.stringify({
              subGenre: t.subGenre,
              language: t.language,
              province: t.province,
              mood: t.mood,
              musicalKey: t.musicalKey,
              coverUrl: t.coverUrl,
              durationMs: t.durationMs,
              stemsAvailable: t.stemsAvailable,
              commentsCount: t.comments,
              sharesCount: t.shares,
              creatorHandle: t.creatorHandle,
              isNew: t.isNew,
              trendingRank: t.trendingRank ?? null,
              provenanceType: 'humanCreated',
            }),
            t.createdAt,
            now
          );
        }
        this.db.exec('COMMIT');
      } catch (e) {
        this.db.exec('ROLLBACK');
        throw e;
      }
    }

    const playlistCount = (
      this.db.prepare('SELECT COUNT(*) as cnt FROM playlists').get() as { cnt: number }
    ).cnt;

    if (playlistCount === 0) {
      const now = new Date().toISOString();
      const insertPlaylist = this.db.prepare(`
        INSERT INTO playlists (
          id, creator_id, title, description, cover_image_url, track_ids_json,
          is_public, share_code, share_url, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `);
      insertPlaylist.run(
        'pl_amapiano_gold',
        'usr_me',
        'Amapiano & Lekompo Gold',
        'Curated Private School Amapiano and Limpopo Lekompo rotation.',
        'https://cdn.vhunambi.za/covers/sovereign_groove.jpg',
        JSON.stringify(['trk_cloud_1', 'trk_cloud_2', 'trk_cloud_4', 'trk_cloud_6']),
        1,
        'VH-AMAPIANO-01',
        'https://vhunambi.za/p/VH-AMAPIANO-01',
        now,
        now
      );
      insertPlaylist.run(
        'pl_3step_horizon',
        'usr_me',
        '3-Step & Afro-Tech Horizon',
        'High-energy Durban 3-Step and Cape Town Afro-Tech dubs.',
        'https://cdn.vhunambi.za/covers/durban_3step.jpg',
        JSON.stringify(['trk_cloud_3', 'trk_cloud_11', 'trk_cloud_5']),
        0,
        null,
        null,
        now,
        now
      );
    }

    this.seedUsersIfEmpty();
  }

  public static readonly DEFAULT_SEED_PASSWORD = 'VhunambiSovereign!2026';
  private static cachedDefaultSeedHash: string | null = null;

  private getDefaultSeedPasswordHash(): string {
    if (!VhunambiDatabase.cachedDefaultSeedHash) {
      VhunambiDatabase.cachedDefaultSeedHash = hashPassword(
        VhunambiDatabase.DEFAULT_SEED_PASSWORD,
        '7668756e616d62695f736565645f3631',
      );
    }
    return VhunambiDatabase.cachedDefaultSeedHash;
  }

  private seedUsersIfEmpty(): void {
    const userCount = (
      this.db.prepare('SELECT COUNT(*) as c FROM users').get() as { c: number }
    ).c;
    if (userCount > 0) return;

    const now = new Date().toISOString();
    const defaultHash = this.getDefaultSeedPasswordHash();

    const insertCreatorIgnore = this.db.prepare(`
      INSERT OR IGNORE INTO creators (
        id, handle, display_name, avatar_url, archetype, tier, reputation_score, data_json, created_at, updated_at
      ) VALUES (?, ?, ?, ?, 'aiSonicArchitect', 'verified', 200, ?, ?, ?)
    `);

    const seedAccounts = [
      {
        userId: 'usr_cern',
        creatorId: 'creator_cern',
        handle: '@cern',
        displayName: 'Cern',
        email: 'cern@vhunambi.co.za',
      },
      {
        userId: 'usr_makhadzi',
        creatorId: 'creator_makhadzi',
        handle: '@makhadzi',
        displayName: 'Makhadzi',
        email: 'makhadzi@vhunambi.co.za',
      },
      {
        userId: 'usr_sigwa',
        creatorId: 'creator_sigwa',
        handle: '@sigwa',
        displayName: 'Sigwa',
        email: 'sigwa@vhunambi.co.za',
      },
      {
        userId: 'usr_kabza',
        creatorId: 'creator_kabza',
        handle: '@kabza',
        displayName: 'Kabza De Small',
        email: 'kabza@vhunambi.co.za',
      },
      {
        userId: 'usr_focalistic',
        creatorId: 'creator_focalistic',
        handle: '@focalistic',
        displayName: 'Focalistic',
        email: 'focalistic@vhunambi.co.za',
      },
      {
        userId: 'usr_tyla',
        creatorId: 'creator_tyla',
        handle: '@tyla',
        displayName: 'Tyla',
        email: 'tyla@vhunambi.co.za',
      },
      {
        userId: 'usr_black_coffee',
        creatorId: 'creator_black_coffee',
        handle: '@blackcoffee',
        displayName: 'Black Coffee',
        email: 'blackcoffee@vhunambi.co.za',
      },
    ];

    const insertUser = this.db.prepare(`
      INSERT OR IGNORE INTO users (
        user_id, creator_id, handle, email, password_hash, role, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, 'creator', ?, ?)
    `);

    for (const acc of seedAccounts) {
      insertCreatorIgnore.run(
        acc.creatorId,
        acc.handle,
        acc.displayName,
        `https://cdn.vhunambi.com/avatars/${acc.creatorId}.jpg`,
        JSON.stringify({ monthlyListenersCount: 25000 }),
        now,
        now,
      );
      insertUser.run(
        acc.userId,
        acc.creatorId,
        acc.handle,
        acc.email,
        defaultHash,
        now,
        now,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Track D: Delta Sync & Idempotent Mutation Ingestion (REQ-P45-SYNC-01..06)
  // ---------------------------------------------------------------------------

  public applyMutationsBatch(mutations: SyncMutationRecord[]): {
    applied: string[];
    skipped: string[];
    failed: Array<{ idempotencyKey: string; code: string; message: string; retryable: boolean }>;
    latestSeq: number;
  } {
    const applied: string[] = [];
    const skipped: string[] = [];
    const failed: Array<{ idempotencyKey: string; code: string; message: string; retryable: boolean }> = [];

    const checkStmt = this.db.prepare('SELECT seq FROM sync_mutation_log WHERE idempotency_key = ?');
    const insertLogStmt = this.db.prepare(`
      INSERT INTO sync_mutation_log (idempotency_key, entity_type, entity_id, action, payload_json, creator_id, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `);

    const resolveMutationCreatorId = (m: SyncMutationRecord): string => {
      const p = m.payload || {};
      const candidate =
        (typeof p.creatorId === 'string' && p.creatorId) ||
        (typeof p.creator_id === 'string' && p.creator_id) ||
        (typeof p.buyerId === 'string' && p.buyerId) ||
        (typeof p.senderId === 'string' && p.senderId) ||
        (typeof p.authorId === 'string' && p.authorId);
      return candidate && candidate.trim() ? candidate.trim() : 'system';
    };

    // Commutative counter operations: atomic increment, never overwrite.
    const commutativeCounterActions = new Set(['like', 'cosign', 'repost']);

    for (const m of mutations) {
      // Phase 48: Per-item SAVEPOINT — a validation error on one item never aborts siblings.
      this.db.exec('SAVEPOINT sync_item');

      try {
        const existing = checkStmt.get(m.idempotencyKey);
        if (existing) {
          skipped.push(m.idempotencyKey);
          this.db.exec('RELEASE SAVEPOINT sync_item');
          continue;
        }

        const entityId =
          m.payload?.id || m.payload?.certificateId || `gen_${Date.now()}`;
        let shouldApply = true;

        // Phase 48: Distinguish commutative counters from versioned entity edits.
        if (commutativeCounterActions.has(m.action)) {
          // Atomic increment: SET count = count + 1 (never overwrite).
          if (m.entityType === 'post') {
            this.db.prepare(
              `UPDATE kinetic_posts SET cosign_count = cosign_count + 1 WHERE id = ?`
            ).run(entityId);
          } else if (m.entityType === 'track') {
            this.db.prepare(
              `UPDATE explore_tracks SET like_count = like_count + 1 WHERE id = ?`
            ).run(entityId);
          }
        } else if (m.entityType === 'post' && m.action === 'create') {
          const insertPost = this.db.prepare(`
            INSERT OR REPLACE INTO kinetic_posts (id, creator_id, creator_handle, creator_name, caption, media_type, cosign_count, cosign_target, repost_count, discovery_stage, data_json, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          `);
          insertPost.run(
            entityId,
            m.payload.creatorId || 'creator_cern',
            m.payload.creatorHandle || '@cern',
            m.payload.creatorName || 'Cern',
            m.payload.caption || '',
            m.payload.mediaType || 'audio_card',
            m.payload.cosignCount || 0,
            25,
            0,
            'freshCrate',
            JSON.stringify(m.payload),
            m.createdAt,
            m.createdAt
          );
        } else if (m.entityType === 'cosign') {
          this.cosignPost(entityId, m.payload?.creatorId);
        } else if (m.entityType === 'tip') {
          const senderId = String(m.payload?.senderId || 'creator_cern');
          const recipientId = String(m.payload?.recipientId || 'creator_makhadzi');
          const amountCoins = Math.max(1, Number(m.payload?.amountCoins ?? m.payload?.coins ?? 100));
          const amountZar = Math.max(0.1, Number(m.payload?.amountZar ?? amountCoins * 0.3));
          const tipRes = this._executeCulturalTipTransfer({
            tipId: String(m.payload?.tipId || m.idempotencyKey || entityId),
            clipId: String(m.payload?.clipId || ''),
            senderId,
            recipientId,
            ancestorId: m.payload?.ancestorId ? String(m.payload.ancestorId) : undefined,
            amountCoins,
            amountZar,
            giftName: String(m.payload?.giftName || 'Cultural Gift'),
            giftEmoji: String(m.payload?.giftEmoji || '🎵'),
            senderUsername: m.payload?.senderUsername ? String(m.payload.senderUsername) : undefined,
            message: m.payload?.message ? String(m.payload.message) : undefined,
            giftId: m.payload?.giftId ? String(m.payload.giftId) : undefined,
          });
          if (tipRes.outcome !== 'committed') {
            this.db.exec('ROLLBACK TO SAVEPOINT sync_item');
            this.db.exec('RELEASE SAVEPOINT sync_item');
            failed.push({
              idempotencyKey: m.idempotencyKey,
              code: tipRes.outcome,
              message:
                tipRes.outcome === 'insufficient_funds'
                  ? `Insufficient sender balance: available ${tipRes.senderRemainingCoins} coins, requested ${amountCoins}`
                  : 'Self-tipping is forbidden',
              retryable: false,
            });
            continue;
          }
          shouldApply = true;
        } else if (m.entityType === 'post' && m.action === 'update' && m.baseSeq !== undefined) {
          // Phase 48: Versioned entity edit — reject if baseSeq is stale (optimistic concurrency).
          const currentSeq = this.db.prepare(
            'SELECT seq FROM sync_mutation_log WHERE entity_type = ? AND entity_id = ? ORDER BY seq DESC LIMIT 1'
          ).get(m.entityType, entityId) as { seq: number } | undefined;

          if (currentSeq && currentSeq.seq > m.baseSeq!) {
            this.db.exec('ROLLBACK TO SAVEPOINT sync_item');
            this.db.exec('RELEASE SAVEPOINT sync_item');
            failed.push({
              idempotencyKey: m.idempotencyKey,
              code: 'conflict',
              message: `Concurrent edit detected: baseSeq ${m.baseSeq} is stale, current seq ${currentSeq.seq}`,
              retryable: false,
            });
            continue;
          }
          shouldApply = true;
        } else if (m.entityType === 'beat_license') {
          const certId = String(m.payload?.certificateId || entityId);
          const alreadyStored = this.db
            .prepare('SELECT certificate_id FROM beat_licenses WHERE certificate_id = ?')
            .get(certId) as { certificate_id: string } | undefined;
          if (!alreadyStored) {
            const beatIdStr = String(m.payload?.beatId || '');
            const assetPricing = beatIdStr
              ? (this.db
                .prepare('SELECT price_coins, price_zar FROM marketplace_assets WHERE id = ?')
                .get(beatIdStr) as { price_coins: number; price_zar: number } | undefined)
              : undefined;
            const tierSlug = String(m.payload?.tier || 'basic_lease');
            const isExclusive =
              m.payload?.isExclusiveRights === true ||
              tierSlug === 'exclusive_stem' ||
              tierSlug === 'unlimited_commercial' ||
              tierSlug === 'exclusive';
            const tierMultiplier = isExclusive ? 6 : tierSlug === 'stems_trackout' ? 3 : 1;
            const coinsPaid =
              assetPricing && Number(assetPricing.price_coins) > 0
                ? Number(assetPricing.price_coins) * tierMultiplier
                : Number(m.payload?.amountPaidCoins ?? 0);
            const zarPaid =
              assetPricing && Number(assetPricing.price_zar) > 0
                ? Number((Number(assetPricing.price_zar) * tierMultiplier).toFixed(2))
                : Number(m.payload?.amountPaidZar ?? 0);
            const prodCoins = Number(
              m.payload?.producerRoyaltyCoins ?? Math.floor((coinsPaid * 85 + 50) / 100),
            );
            const prodZar = Number(
              m.payload?.producerRoyaltyZar ?? Math.round(zarPaid * 0.85 * 100) / 100,
            );
            const insertRes = this._executeBeatLicenseInsert({
              certificateId: certId,
              beatId: beatIdStr,
              beatTitle: String(m.payload?.beatTitle || 'Untitled Beat'),
              producerId: String(m.payload?.producerId || 'creator_unknown'),
              producerHandle: String(m.payload?.producerHandle || '@producer'),
              buyerId: String(m.payload?.buyerId || 'creator_cern'),
              buyerHandle: String(m.payload?.buyerHandle || '@cern'),
              tierSlug,
              amountPaidCoins: coinsPaid,
              amountPaidZar: zarPaid,
              producerRoyaltyCoins: prodCoins,
              producerRoyaltyZar: prodZar,
              issuedAt: String(
                m.payload?.issuedAtIso8601 || m.payload?.issuedAt || m.createdAt,
              ),
              commercialTerms: String(m.payload?.commercialTerms || ''),
              masterFileSha256: m.payload?.masterFileSha256
                ? String(m.payload.masterFileSha256)
                : undefined,
              isExclusive,
              enforceBuyerWallet:
                Boolean(m.payload?.enforceWalletBalance) || Boolean(assetPricing),
              dataJson: m.payload || {},
            });
            if (insertRes.status === 'exclusive_conflict') {
              this.db.exec('ROLLBACK TO SAVEPOINT sync_item');
              this.db.exec('RELEASE SAVEPOINT sync_item');
              failed.push({
                idempotencyKey: m.idempotencyKey,
                code: 'conflict',
                message: 'Beat has already been purchased under an Exclusive license',
                retryable: false,
              });
              continue;
            }
            if (insertRes.status === 'insufficient_funds') {
              this.db.exec('ROLLBACK TO SAVEPOINT sync_item');
              this.db.exec('RELEASE SAVEPOINT sync_item');
              failed.push({
                idempotencyKey: m.idempotencyKey,
                code: 'insufficient_funds',
                message: 'Insufficient buyer balance for beat license purchase',
                retryable: false,
              });
              continue;
            }
          }
          shouldApply = true;
        } else if (m.entityType === 'library_track') {
          const targetCreator = String(
            m.payload?.creatorId || m.payload?.creator_id || 'creator_cern',
          );
          if (m.action === 'delete' && m.payload?.hardDelete === true) {
            this.deleteLibraryItem(entityId, targetCreator, false);
          } else if (m.action === 'delete') {
            this.syncLibraryDelta(
              targetCreator,
              [
                {
                  ...(m.payload || {}),
                  id: entityId,
                  deletedAt: m.payload?.deletedAt || m.createdAt,
                  updatedAtMs:
                    m.payload?.updatedAtMs ??
                    (Date.parse(m.createdAt) || Date.now()),
                },
              ],
              false,
            );
          } else {
            this.syncLibraryDelta(
              targetCreator,
              [
                {
                  ...(m.payload || {}),
                  id: entityId,
                  updatedAt: m.payload?.updatedAt || m.createdAt,
                },
              ],
              false,
            );
          }
          shouldApply = true;
        } else if (m.entityType === 'playlist') {
          if (m.action === 'delete') {
            this.deletePlaylist(entityId, m.payload?.creatorId, false);
          } else {
            this.upsertPlaylist(
              {
                ...(m.payload || {}),
                id: entityId,
                updatedAt: m.payload?.updatedAt || m.createdAt,
              },
              false,
            );
          }
          shouldApply = true;
        } else if (m.entityType === 'track') {
          if (m.action === 'create' || m.action === 'update') {
            this.upsertExploreTrack(
              {
                ...(m.payload || {}),
                id: entityId,
                createdAt: m.payload?.createdAt || m.createdAt,
              },
              false,
            );
            shouldApply = true;
          }
        }

        if (shouldApply) {
          insertLogStmt.run(
            m.idempotencyKey,
            m.entityType,
            entityId,
            m.action,
            JSON.stringify(m.payload),
            resolveMutationCreatorId(m),
            m.createdAt
          );
          applied.push(m.idempotencyKey);
        }

        this.db.exec('RELEASE SAVEPOINT sync_item');
      } catch (err: any) {
        // Phase 48: Rollback this item only, continue with siblings.
        this.db.exec('ROLLBACK TO SAVEPOINT sync_item');
        this.db.exec('RELEASE SAVEPOINT sync_item');
        failed.push({
          idempotencyKey: m.idempotencyKey,
          code: 'validation_error',
          message: err?.message || 'Unknown validation error',
          retryable: true,
        });
      }
    }

    const latestSeq = this.getLatestSeq();
    return { applied, skipped, failed, latestSeq };
  }

  public getDelta(
    sinceSeq: number,
    limit: number = 100,
    viewerCreatorId?: string,
  ): SyncDeltaResult {
    const safeLimit = Math.max(1, Math.min(200, limit));
    const normalizedViewer = viewerCreatorId?.trim();

    type SyncRow = {
      seq: number;
      idempotency_key: string;
      entity_type: string;
      entity_id: string;
      action: string;
      payload_json: string;
      creator_id: string;
      created_at: string;
    };

    let rows: SyncRow[];
    if (normalizedViewer) {
      const canonicalViewer = canonicalizeCreatorId(normalizedViewer);
      rows = this.db
        .prepare(
          `SELECT seq, idempotency_key, entity_type, entity_id, action, payload_json, creator_id, created_at
           FROM sync_mutation_log
           WHERE seq > ?
             AND (
               entity_type NOT IN ('payout', 'library_track', 'beat_license', 'wallet_ledger', 'playlist')
               OR creator_id IN (?, ?)
               OR (
                 creator_id = 'system'
                 AND json_valid(payload_json)
                 AND COALESCE(
                   json_extract(payload_json, '$.creatorId'),
                   json_extract(payload_json, '$.creator_id'),
                   json_extract(payload_json, '$.buyerId'),
                   'system'
                 ) IN (?, ?)
               )
               OR (
                 entity_type = 'beat_license'
                 AND json_valid(payload_json)
                 AND COALESCE(
                   json_extract(payload_json, '$.producerId'),
                   json_extract(payload_json, '$.sellerId'),
                   ''
                 ) IN (?, ?)
               )
               OR (
                 entity_type = 'playlist'
                 AND json_valid(payload_json)
                 AND (
                   json_extract(payload_json, '$.isPublic') IN (1, 'true', true)
                   OR json_extract(payload_json, '$.is_public') = 1
                   OR COALESCE(
                     json_extract(payload_json, '$.creatorId'),
                     json_extract(payload_json, '$.creator_id'),
                     'system'
                   ) IN ('system', ?, ?)
                 )
               )
             )
           ORDER BY seq ASC
           LIMIT ?`,
        )
        .all(
          sinceSeq,
          normalizedViewer,
          canonicalViewer,
          normalizedViewer,
          canonicalViewer,
          normalizedViewer,
          canonicalViewer,
          normalizedViewer,
          canonicalViewer,
          safeLimit + 1,
        ) as SyncRow[];
    } else {
      rows = this.db
        .prepare(
          `SELECT seq, idempotency_key, entity_type, entity_id, action, payload_json, creator_id, created_at
           FROM sync_mutation_log
           WHERE seq > ?
           ORDER BY seq ASC
           LIMIT ?`,
        )
        .all(sinceSeq, safeLimit + 1) as SyncRow[];
    }

    const hasMore = rows.length > safeLimit;
    const visibleRows = hasMore ? rows.slice(0, safeLimit) : rows;

    const mutations = visibleRows.map((r) => {
      let parsedPayload: Record<string, any> = {};
      try {
        parsedPayload = JSON.parse(r.payload_json || '{}');
      } catch {
        parsedPayload = {};
      }
      return {
        seq: r.seq,
        idempotencyKey: r.idempotency_key,
        entityType: r.entity_type,
        entityId: r.entity_id,
        action: r.action,
        creatorId: r.creator_id || 'system',
        payload: parsedPayload,
        createdAt: r.created_at,
      };
    });

    const latestSeq = this.getLatestSeq();
    const nextCursorSeq =
      visibleRows.length > 0
        ? visibleRows[visibleRows.length - 1].seq
        : latestSeq;

    return {
      mutations,
      latestSeq,
      nextCursorSeq,
      hasMore,
    };
  }

  public getLatestSeq(): number {
    const row = this.db.prepare('SELECT MAX(seq) as maxSeq FROM sync_mutation_log').get() as { maxSeq: number | null };
    return row?.maxSeq || 0;
  }

  // ---------------------------------------------------------------------------
  // Track C: Explore, Tracks Catalog & Radio Endpoints (Phase 59 Convergence)
  // ---------------------------------------------------------------------------

  public getExploreFeed(options: ExploreFeedOptions = {}): { posts: any[]; total: number } {
    let sql = 'SELECT * FROM kinetic_posts WHERE 1=1';
    const params: any[] = [];

    if (options.stage) {
      sql += ' AND discovery_stage = ?';
      params.push(options.stage);
    }

    sql += ' ORDER BY cosign_count DESC, created_at DESC';

    const rows = this.db.prepare(sql).all(...params) as any[];

    let posts = rows.map((r): Record<string, any> => {
      let data: Record<string, any> = {};
      try {
        data = JSON.parse(r.data_json);
      } catch (_) { }
      return {
        id: r.id,
        creatorId: r.creator_id,
        creatorHandle: r.creator_handle,
        creatorName: r.creator_name,
        caption: r.caption,
        mediaType: r.media_type,
        cosignCount: r.cosign_count,
        cosignTarget: r.cosign_target,
        repostCount: r.repost_count,
        discoveryStage: r.discovery_stage,
        createdAt: r.created_at,
        ...data,
      };
    });

    if (
      options.genre &&
      options.genre.trim() !== '' &&
      options.genre.toLowerCase() !== 'all'
    ) {
      const g = options.genre.trim().toLowerCase();
      posts = posts.filter((p) => {
        const postGenre = String(p.genre ?? p.songDna?.genre ?? '').toLowerCase();
        const caption = String(p.caption ?? '').toLowerCase();
        return postGenre === g || postGenre.includes(g) || caption.includes(g);
      });
    }

    const total = posts.length;
    const offset = options.offset && options.offset > 0 ? options.offset : 0;
    const sliced =
      options.limit && options.limit > 0
        ? posts.slice(offset, offset + options.limit)
        : posts.slice(offset);

    return { posts: sliced, total };
  }

  private mapExploreTrackRow(r: Record<string, any>): ExploreTrackRecord {
    let data: Record<string, any> = {};
    try {
      data = JSON.parse(String(r.data_json ?? '{}')) as Record<string, any>;
    } catch {
      data = {};
    }

    const plays = Number(r.play_count ?? 0);
    const likes = Number(r.like_count ?? 0);
    const cosigns = Number(r.cosign_count ?? 0);
    const stemsAvailable = Boolean(data.stemsAvailable);
    const createdAtStr = String(r.created_at ?? new Date().toISOString());
    const ageDays = Math.max(
      0,
      (Date.now() - new Date(createdAtStr).getTime()) / (1000 * 60 * 60 * 24),
    );
    const recencyBonus = Math.max(0, 15.0 - 0.5 * ageDays);
    const stemsBonus = stemsAvailable ? 6.0 : 0.0;
    const rawScore =
      18.0 * Math.log(1 + plays) +
      2.4 * Math.sqrt(likes) +
      3.8 * Math.sqrt(cosigns) +
      stemsBonus +
      recencyBonus;
    const trendingScore = Number(Math.min(100, Math.max(0, rawScore)).toFixed(2));

    let discoveryStage: 'freshCrate' | 'risingBreakout' | 'mainstage' = 'freshCrate';
    if (plays >= 8000 || cosigns >= 250 || trendingScore >= 82.0) {
      discoveryStage = 'mainstage';
    } else if (plays >= 1500 || cosigns >= 60 || trendingScore >= 58.0) {
      discoveryStage = 'risingBreakout';
    }

    const artistName = String(r.artist_name ?? 'Unknown Creator');
    return {
      id: String(r.id),
      title: String(r.title),
      artist: artistName,
      creatorName: artistName,
      creatorId: String(r.artist_id ?? 'usr_me'),
      creatorHandle: String(
        data.creatorHandle ??
        `@${artistName.toLowerCase().replace(/\s+/g, '_')}`,
      ),
      genre: String(r.genre ?? 'Amapiano'),
      subGenre: String(data.subGenre ?? 'Sgija'),
      language: String(data.language ?? 'isiZulu'),
      province: String(data.province ?? 'Gauteng'),
      mood: String(data.mood ?? 'Vibrant'),
      bpm: Number(r.bpm ?? 113),
      musicalKey: String(data.musicalKey ?? 'Am'),
      audioUrl: String(r.audio_url ?? ''),
      coverUrl: String(data.coverUrl ?? ''),
      durationMs: Number(data.durationMs ?? 180000),
      likeCount: likes,
      likesCount: likes,
      playCount: plays,
      playsCount: plays,
      cosignsCount: cosigns,
      commentsCount: Number(data.commentsCount ?? Math.round(likes * 0.08)),
      sharesCount: Number(data.sharesCount ?? Math.round(cosigns * 0.65)),
      isNew: Boolean(data.isNew ?? ageDays < 2),
      trendingRank:
        data.trendingRank !== null && data.trendingRank !== undefined
          ? Number(data.trendingRank)
          : undefined,
      stemsAvailable,
      discoveryStage,
      trendingScore,
      songDna: (data.songDna as Record<string, unknown>) ?? {
        genre: r.genre,
        subGenre: data.subGenre,
        bpm: r.bpm,
        musicalKey: data.musicalKey,
        province: data.province,
        provenanceType: data.provenanceType ?? 'humanCreated',
      },
      createdAt: createdAtStr,
    };
  }

  public getExploreTracks(options: {
    genre?: string;
    stage?: string;
    sort?: 'trending' | 'newest' | 'likes' | 'plays';
    search?: string;
    limit?: number;
  } = {}): { items: ExploreTrackRecord[]; total: number; serverSeq: number } {
    const limit = Math.min(Math.max(options.limit ?? 50, 1), 100);
    const rows = this.db
      .prepare('SELECT * FROM explore_tracks ORDER BY created_at DESC')
      .all() as Array<Record<string, any>>;

    let mapped = rows.map((r) => this.mapExploreTrackRow(r));

    if (
      options.genre &&
      options.genre.trim() !== '' &&
      options.genre.toLowerCase() !== 'all'
    ) {
      const g = options.genre.trim().toLowerCase();
      mapped = mapped.filter(
        (t) =>
          t.genre.toLowerCase() === g ||
          t.subGenre.toLowerCase() === g ||
          t.genre.toLowerCase().includes(g),
      );
    }

    if (
      options.stage &&
      options.stage.trim() !== '' &&
      options.stage.toLowerCase() !== 'all'
    ) {
      const st = options.stage.trim().toLowerCase();
      mapped = mapped.filter((t) => t.discoveryStage.toLowerCase() === st);
    }

    if (options.search && options.search.trim() !== '') {
      const q = options.search.trim().toLowerCase();
      mapped = mapped.filter(
        (t) =>
          t.title.toLowerCase().includes(q) ||
          t.artist.toLowerCase().includes(q) ||
          t.genre.toLowerCase().includes(q) ||
          t.province.toLowerCase().includes(q),
      );
    }

    const sortMode = options.sort ?? 'trending';
    mapped.sort((a, b) => {
      if (sortMode === 'newest') return b.createdAt.localeCompare(a.createdAt);
      if (sortMode === 'likes') return b.likesCount - a.likesCount;
      if (sortMode === 'plays') return b.playsCount - a.playsCount;
      return b.trendingScore - a.trendingScore;
    });

    return {
      items: mapped.slice(0, limit),
      total: mapped.length,
      serverSeq: this.getLatestSeq(),
    };
  }

  public getExploreRadioRotation(
    genre: string,
    limit: number = 20,
  ): {
    genre: string;
    stationTitle: string;
    description: string;
    seedBpm: number;
    rotation: ExploreTrackRecord[];
    serverSeq: number;
  } {
    const normalizedGenre =
      !genre || genre.trim() === '' || genre.toLowerCase() === 'all'
        ? 'All'
        : genre.trim();
    const { items } = this.getExploreTracks({
      genre: normalizedGenre === 'All' ? undefined : normalizedGenre,
      sort: 'trending',
      limit: 100,
    });

    const pool =
      items.length > 0 ? items : this.getExploreTracks({ limit: 50 }).items;
    const seedBpm = pool.length > 0 ? pool[0].bpm : 113;

    const scored = pool.map((track) => {
      const bpmDelta = Math.abs((track.bpm || seedBpm) - seedBpm);
      const genreExactBonus =
        normalizedGenre !== 'All' &&
          track.genre.toLowerCase() === normalizedGenre.toLowerCase()
          ? 25
          : 0;
      const rotationScore =
        track.trendingScore + genreExactBonus - bpmDelta * 0.25;
      return { track, rotationScore };
    });
    scored.sort((a, b) => b.rotationScore - a.rotationScore);

    return {
      genre: normalizedGenre,
      stationTitle:
        normalizedGenre === 'All'
          ? 'Vhunambi Sovereign Pan-African Radio'
          : `${normalizedGenre} Sovereign Radio`,
      description: `Harmonic ${normalizedGenre} rotation anchored around ${Math.round(seedBpm)} BPM.`,
      seedBpm,
      rotation: scored.slice(0, Math.min(Math.max(limit, 1), 50)).map((s) => s.track),
      serverSeq: this.getLatestSeq(),
    };
  }

  public upsertExploreTrack(
    input: Record<string, any>,
    recordMutation: boolean = true,
  ): ExploreTrackRecord {
    const now = new Date().toISOString();
    const id = String(input.id || `trk_${Date.now()}_${randomUUID().slice(0, 6)}`);
    const artistName = String(
      input.creatorName || input.artist || 'Vhunambi Creator',
    );
    const artistId = String(input.creatorId || 'usr_me');
    const genre = String(input.genre || 'Amapiano');
    const bpm = Number(input.bpm ?? 113);
    const playCount = Number(input.playCount ?? input.playsCount ?? 0);
    const likeCount = Number(input.likeCount ?? input.likesCount ?? 0);
    const cosignCount = Number(input.cosignsCount ?? 0);
    const stage = String(
      input.discoveryStage ||
      (playCount >= 8000
        ? 'mainstage'
        : playCount >= 1500
          ? 'risingBreakout'
          : 'freshCrate'),
    );
    const dataJson = {
      subGenre: input.subGenre ?? 'Sgija',
      language: input.language ?? 'isiZulu',
      province: input.province ?? 'Gauteng',
      mood: input.mood ?? 'Vibrant',
      musicalKey: input.musicalKey ?? 'Am',
      coverUrl: input.coverUrl ?? '',
      durationMs: Number(input.durationMs ?? input.duration ?? 180000),
      stemsAvailable: Boolean(input.stemsAvailable ?? false),
      commentsCount: Number(input.commentsCount ?? 0),
      sharesCount: Number(input.sharesCount ?? 0),
      creatorHandle:
        input.creatorHandle ?? `@${artistName.toLowerCase().replace(/\s+/g, '_')}`,
      isNew: Boolean(input.isNew ?? true),
      trendingRank: input.trendingRank ?? null,
      provenanceType: input.provenanceType ?? 'humanCreated',
    };

    this.db
      .prepare(
        `
      INSERT INTO explore_tracks (
        id, title, artist_id, artist_name, genre, audio_url, bpm,
        play_count, like_count, cosign_count, discovery_stage, data_json,
        created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        title = excluded.title,
        artist_name = excluded.artist_name,
        genre = excluded.genre,
        audio_url = excluded.audio_url,
        bpm = excluded.bpm,
        play_count = MAX(explore_tracks.play_count, excluded.play_count),
        like_count = MAX(explore_tracks.like_count, excluded.like_count),
        cosign_count = MAX(explore_tracks.cosign_count, excluded.cosign_count),
        discovery_stage = excluded.discovery_stage,
        data_json = excluded.data_json,
        updated_at = excluded.updated_at
    `,
      )
      .run(
        id,
        String(input.title || 'Untitled Track'),
        artistId,
        artistName,
        genre,
        String(input.audioUrl || ''),
        bpm,
        playCount,
        likeCount,
        cosignCount,
        stage,
        JSON.stringify(dataJson),
        String(input.createdAt || now),
        now,
      );

    if (recordMutation) {
      this.db
        .prepare(
          `
        INSERT OR IGNORE INTO sync_mutation_log (
          idempotency_key, entity_type, entity_id, action, payload_json, created_at
        ) VALUES (?, 'track', ?, 'create', ?, ?)
      `,
        )
        .run(
          `track_upsert_${id}_${Date.now()}`,
          id,
          JSON.stringify({ id, ...input }),
          now,
        );
    }

    const stored = this.db
      .prepare('SELECT * FROM explore_tracks WHERE id = ?')
      .get(id) as Record<string, any>;
    return this.mapExploreTrackRow(stored);
  }

  public getExploreDiscoveryBundle(options: ExploreFeedOptions = {}): {
    tracks: ExploreTrackRecord[];
    posts: any[];
    radio: ReturnType<VhunambiDatabase['getExploreRadioRotation']>;
    totalTracks: number;
    totalPosts: number;
    serverSeq: number;
    syncedAt: string;
  } {
    const trackResult = this.getExploreTracks({
      genre: options.genre,
      stage: options.stage,
      limit: options.limit ?? 50,
    });
    const postResult = this.getExploreFeed(options);
    const radio = this.getExploreRadioRotation(options.genre || 'All', 12);

    return {
      tracks: trackResult.items,
      posts: postResult.posts,
      radio,
      totalTracks: trackResult.total,
      totalPosts: postResult.total,
      serverSeq: this.getLatestSeq(),
      syncedAt: new Date().toISOString(),
    };
  }

  public cosignPost(postId: string, _creatorId?: string): {
    success: boolean;
    postId: string;
    cosignCount: number;
    discoveryStage: string;
    promoted: boolean;
  } {
    const post = this.db.prepare('SELECT * FROM kinetic_posts WHERE id = ?').get(postId) as any;
    if (!post) {
      return { success: false, postId, cosignCount: 0, discoveryStage: 'freshCrate', promoted: false };
    }

    const newCount = (post.cosign_count || 0) + 1;
    let newStage = post.discovery_stage;
    let promoted = false;

    // Automatic graduation when co-signs reach 25 (REQ-P45-EXP-05)
    if (newCount >= 25 && post.discovery_stage === 'freshCrate') {
      newStage = 'risingBreakout';
      promoted = true;
    }

    this.db.prepare(`
      UPDATE kinetic_posts
      SET cosign_count = ?, discovery_stage = ?, updated_at = ?
      WHERE id = ?
    `).run(newCount, newStage, new Date().toISOString(), postId);

    return {
      success: true,
      postId,
      cosignCount: newCount,
      discoveryStage: newStage,
      promoted,
    };
  }

  public repostPost(postId: string): { success: boolean; postId: string; repostCount: number } {
    const post = this.db.prepare('SELECT repost_count FROM kinetic_posts WHERE id = ?').get(postId) as any;
    if (!post) {
      return { success: false, postId, repostCount: 0 };
    }

    const newCount = (post.repost_count || 0) + 1;
    this.db.prepare('UPDATE kinetic_posts SET repost_count = ?, updated_at = ? WHERE id = ?').run(
      newCount,
      new Date().toISOString(),
      postId
    );

    return { success: true, postId, repostCount: newCount };
  }

  // ---------------------------------------------------------------------------
  // Track C / Phase 59: Cloud Vault Library Sync Endpoints
  // ---------------------------------------------------------------------------

  public getLibrary(creatorId: string): any[] {
    const rows = this.db
      .prepare('SELECT * FROM user_library_sync WHERE creator_id = ? ORDER BY updated_at DESC')
      .all(creatorId) as any[];
    return rows.map((r) => {
      let data: Record<string, any> = {};
      try {
        data = JSON.parse(r.data_json);
      } catch (_) { }
      return {
        id: r.id,
        creatorId: r.creator_id,
        itemType: r.item_type,
        title: r.title,
        createdAt: data.createdAt || r.created_at,
        updatedAt: data.updatedAt || r.updated_at,
        updated_at: r.updated_at,
        ...data,
      };
    });
  }

  public upsertLibrary(creatorId: string, items: any[]): number {
    const result = this.syncLibraryDelta(creatorId, items, false);
    return result.appliedCount + result.skippedCount;
  }

  public deleteLibraryItem(
    id: string,
    creatorId?: string,
    recordMutation: boolean = true,
  ): boolean {
    const res = creatorId
      ? this.db
        .prepare('DELETE FROM user_library_sync WHERE id = ? AND creator_id = ?')
        .run(id, creatorId)
      : this.db.prepare('DELETE FROM user_library_sync WHERE id = ?').run(id);
    const deleted = Number(res.changes ?? 0) > 0;
    if (deleted && recordMutation) {
      const now = new Date().toISOString();
      const effectiveCreator = creatorId || 'creator_cern';
      this.db
        .prepare(
          `
        INSERT OR IGNORE INTO sync_mutation_log (
          idempotency_key, entity_type, entity_id, action, payload_json, creator_id, created_at
        ) VALUES (?, 'library_track', ?, 'delete', ?, ?, ?)
      `,
        )
        .run(
          `lib_del_${id}_${Date.now()}`,
          id,
          JSON.stringify({ id, creatorId: effectiveCreator, hardDelete: true }),
          effectiveCreator,
          now,
        );
    }
    return deleted;
  }

  public getLibraryItemOwnerCreatorId(id: string): string | null {
    const row = this.db
      .prepare('SELECT creator_id FROM user_library_sync WHERE id = ?')
      .get(id) as { creator_id: string } | undefined;
    return row ? String(row.creator_id) : null;
  }

  public syncLibraryDelta(
    creatorId: string,
    incomingItems: any[],
    recordMutation: boolean = true,
  ): {
    creatorId: string;
    appliedCount: number;
    skippedCount: number;
    items: any[];
    serverSeq: number;
    syncedAt: string;
  } {
    const selectStmt = this.db.prepare(
      'SELECT * FROM user_library_sync WHERE id = ?',
    );
    const upsertStmt = this.db.prepare(`
      INSERT INTO user_library_sync (id, creator_id, item_type, title, data_json, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        item_type = excluded.item_type,
        title = excluded.title,
        data_json = excluded.data_json,
        updated_at = excluded.updated_at
    `);
    const insertLogStmt = this.db.prepare(`
      INSERT OR IGNORE INTO sync_mutation_log (
        idempotency_key, entity_type, entity_id, action, payload_json, creator_id, created_at
      ) VALUES (?, 'library_track', ?, ?, ?, ?, ?)
    `);

    let appliedCount = 0;
    let skippedCount = 0;
    const now = new Date().toISOString();

    const toMillis = (val: any, fallbackIso?: string): number => {
      if (typeof val === 'number' && Number.isFinite(val)) return val;
      if (typeof val === 'string' && val.trim() !== '') {
        const parsed = Date.parse(val);
        if (!Number.isNaN(parsed)) return parsed;
      }
      if (fallbackIso) {
        const parsedFallback = Date.parse(fallbackIso);
        if (!Number.isNaN(parsedFallback)) return parsedFallback;
      }
      return Date.now();
    };

    this.db.exec('SAVEPOINT lib_delta_sync');
    try {
      for (const item of incomingItems || []) {
        const id = String(item.id || `lib_${Date.now()}_${appliedCount + skippedCount}`);
        const existingRow = selectStmt.get(id) as Record<string, any> | undefined;

        const incomingUpdatedAtMs = toMillis(
          item.updatedAtMs,
          item.updatedAt || item.deletedAt || item.createdAt,
        );

        let existingData: Record<string, any> = {};
        let existingUpdatedAtMs = -1;
        if (existingRow) {
          try {
            existingData = JSON.parse(String(existingRow.data_json || '{}'));
          } catch (_) { }
          existingUpdatedAtMs = toMillis(
            existingData.updatedAtMs,
            existingRow.updated_at || existingData.updatedAt,
          );
        }

        if (existingRow && incomingUpdatedAtMs < existingUpdatedAtMs) {
          skippedCount++;
          continue;
        }

        // Preserve Phase 58 licensing metadata and monotonic play count
        const mergedPlayCount = Math.max(
          Number(existingData.playCount ?? 0),
          Number(item.playCount ?? 0),
        );
        const merged = {
          ...existingData,
          ...item,
          id,
          creatorId,
          playCount: mergedPlayCount,
          updatedAtMs: incomingUpdatedAtMs,
          updatedAt: item.updatedAt || new Date(incomingUpdatedAtMs).toISOString(),
          isLicensedBeat:
            item.isLicensedBeat ?? existingData.isLicensedBeat ?? false,
          licenseTier: item.licenseTier ?? existingData.licenseTier,
          certificateId: item.certificateId ?? existingData.certificateId,
          licenseHash: item.licenseHash ?? existingData.licenseHash,
          masterFileSha256:
            item.masterFileSha256 ?? existingData.masterFileSha256,
          stemFilesJson: item.stemFilesJson ?? existingData.stemFilesJson,
        };

        const itemType = String(merged.itemType || 'track');
        const title = String(merged.title || existingRow?.title || 'Untitled Track');
        const createdAt = String(
          merged.createdAt || existingRow?.created_at || now,
        );
        const updatedAtIso = String(merged.updatedAt);

        upsertStmt.run(
          id,
          creatorId,
          itemType,
          title,
          JSON.stringify(merged),
          createdAt,
          updatedAtIso,
        );

        if (recordMutation) {
          insertLogStmt.run(
            `lib_sync_${id}_${incomingUpdatedAtMs}`,
            id,
            existingRow ? 'update' : 'create',
            JSON.stringify(merged),
            creatorId,
            now,
          );
        }

        appliedCount++;
      }
      this.db.exec('RELEASE SAVEPOINT lib_delta_sync');
    } catch (e) {
      this.db.exec('ROLLBACK TO SAVEPOINT lib_delta_sync');
      this.db.exec('RELEASE SAVEPOINT lib_delta_sync');
      throw e;
    }

    return {
      creatorId,
      appliedCount,
      skippedCount,
      items: this.getLibrary(creatorId),
      serverSeq: this.getLatestSeq(),
      syncedAt: now,
    };
  }

  // ---------------------------------------------------------------------------
  // Phase 59: Playlists Cloud CRUD & Public Share Links
  // ---------------------------------------------------------------------------

  private mapPlaylistRow(r: Record<string, any>): Record<string, any> {
    let trackIds: string[] = [];
    try {
      const parsed = JSON.parse(String(r.track_ids_json ?? '[]'));
      if (Array.isArray(parsed)) trackIds = parsed.map((e) => String(e));
    } catch (_) { }

    const isPublic = Number(r.is_public ?? 0) === 1;
    return {
      id: String(r.id),
      creatorId: String(r.creator_id ?? 'usr_me'),
      creator_id: String(r.creator_id ?? 'usr_me'),
      title: String(r.title ?? 'Untitled Playlist'),
      description: String(r.description ?? ''),
      coverImageUrl: r.cover_image_url ?? null,
      cover_image_url: r.cover_image_url ?? null,
      trackIds,
      track_ids: trackIds,
      isPublic,
      is_public: isPublic,
      shareCode: r.share_code ?? null,
      share_code: r.share_code ?? null,
      shareUrl: r.share_url ?? null,
      share_url: r.share_url ?? null,
      createdAt: String(r.created_at),
      created_at: String(r.created_at),
      updatedAt: String(r.updated_at),
      updated_at: String(r.updated_at),
    };
  }

  public getPlaylists(creatorId?: string, includePublic: boolean = true): any[] {
    let rows: Record<string, any>[];
    if (creatorId && creatorId.trim() !== '') {
      rows = includePublic
        ? (this.db
          .prepare(
            'SELECT * FROM playlists WHERE creator_id = ? OR is_public = 1 ORDER BY updated_at DESC',
          )
          .all(creatorId) as Record<string, any>[])
        : (this.db
          .prepare(
            'SELECT * FROM playlists WHERE creator_id = ? ORDER BY updated_at DESC',
          )
          .all(creatorId) as Record<string, any>[]);
    } else {
      rows = this.db
        .prepare('SELECT * FROM playlists ORDER BY updated_at DESC')
        .all() as Record<string, any>[];
    }
    return rows.map((r) => this.mapPlaylistRow(r));
  }

  public getPlaylistById(id: string): Record<string, any> | null {
    const row = this.db
      .prepare('SELECT * FROM playlists WHERE id = ? OR share_code = ?')
      .get(id, id) as Record<string, any> | undefined;
    return row ? this.mapPlaylistRow(row) : null;
  }

  public upsertPlaylist(
    input: Record<string, any>,
    recordMutation: boolean = true,
  ): Record<string, any> {
    const now = new Date().toISOString();
    const id = String(input.id || `pl_${Date.now()}_${randomUUID().slice(0, 6)}`);
    const existing = this.db
      .prepare('SELECT * FROM playlists WHERE id = ?')
      .get(id) as Record<string, any> | undefined;

    const creatorId = String(
      input.creatorId ?? input.creator_id ?? existing?.creator_id ?? 'usr_me',
    );
    const title = String(input.title ?? existing?.title ?? 'Untitled Playlist');
    const description = String(
      input.description ?? existing?.description ?? '',
    );
    const coverImageUrl =
      input.coverImageUrl !== undefined
        ? input.coverImageUrl
        : input.cover_image_url !== undefined
          ? input.cover_image_url
          : existing?.cover_image_url ?? null;
    const rawTrackIds = input.trackIds ?? input.track_ids;
    const trackIds: string[] = Array.isArray(rawTrackIds)
      ? rawTrackIds.map((t) => String(t))
      : existing
        ? JSON.parse(String(existing.track_ids_json ?? '[]'))
        : [];
    const isPublic =
      input.isPublic !== undefined
        ? Boolean(input.isPublic)
        : input.is_public !== undefined
          ? Boolean(input.is_public)
          : Number(existing?.is_public ?? 0) === 1;
    const shareCode =
      input.shareCode ?? input.share_code ?? existing?.share_code ?? null;
    const shareUrl =
      input.shareUrl ?? input.share_url ?? existing?.share_url ?? null;
    const createdAt = String(
      input.createdAt ?? input.created_at ?? existing?.created_at ?? now,
    );
    const updatedAt = String(input.updatedAt ?? input.updated_at ?? now);

    this.db
      .prepare(
        `
      INSERT INTO playlists (
        id, creator_id, title, description, cover_image_url, track_ids_json,
        is_public, share_code, share_url, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        title = excluded.title,
        description = excluded.description,
        cover_image_url = excluded.cover_image_url,
        track_ids_json = excluded.track_ids_json,
        is_public = excluded.is_public,
        share_code = COALESCE(excluded.share_code, playlists.share_code),
        share_url = COALESCE(excluded.share_url, playlists.share_url),
        updated_at = excluded.updated_at
    `,
      )
      .run(
        id,
        creatorId,
        title,
        description,
        coverImageUrl,
        JSON.stringify(trackIds),
        isPublic ? 1 : 0,
        shareCode,
        shareUrl,
        createdAt,
        updatedAt,
      );

    const mapped = this.getPlaylistById(id)!;
    if (recordMutation) {
      this.db
        .prepare(
          `
        INSERT OR IGNORE INTO sync_mutation_log (
          idempotency_key, entity_type, entity_id, action, payload_json, creator_id, created_at
        ) VALUES (?, 'playlist', ?, ?, ?, ?, ?)
      `,
        )
        .run(
          `pl_upsert_${id}_${Date.now()}`,
          id,
          existing ? 'update' : 'create',
          JSON.stringify(mapped),
          creatorId,
          now,
        );
    }
    return mapped;
  }

  public getPlaylistOwnerCreatorId(id: string): string | null {
    const row = this.db
      .prepare('SELECT creator_id FROM playlists WHERE id = ? OR share_code = ?')
      .get(id, id) as { creator_id: string } | undefined;
    return row ? String(row.creator_id) : null;
  }

  public deletePlaylist(
    id: string,
    creatorId?: string,
    recordMutation: boolean = true,
  ): boolean {
    const res =
      creatorId && creatorId.trim() !== ''
        ? this.db
          .prepare('DELETE FROM playlists WHERE id = ? AND creator_id = ?')
          .run(id, creatorId)
        : this.db.prepare('DELETE FROM playlists WHERE id = ?').run(id);
    const deleted = Number(res.changes ?? 0) > 0;
    if (deleted && recordMutation) {
      const now = new Date().toISOString();
      const effectiveCreator = creatorId || 'usr_me';
      this.db
        .prepare(
          `
        INSERT OR IGNORE INTO sync_mutation_log (
          idempotency_key, entity_type, entity_id, action, payload_json, creator_id, created_at
        ) VALUES (?, 'playlist', ?, 'delete', ?, ?, ?)
      `,
        )
        .run(
          `pl_del_${id}_${Date.now()}`,
          id,
          JSON.stringify({ id, creatorId: effectiveCreator }),
          effectiveCreator,
          now,
        );
    }
    return deleted;
  }

  public sharePlaylist(id: string): Record<string, any> | null {
    const existing = this.getPlaylistById(id);
    if (!existing) return null;
    const now = new Date().toISOString();
    const shareCode =
      existing.shareCode ||
      `VH-${createHash('sha256')
        .update(`${id}|${now}|${randomUUID()}`)
        .digest('hex')
        .slice(0, 8)
        .toUpperCase()}`;
    const shareUrl = `https://vhunambi.za/p/${shareCode}`;

    this.db
      .prepare(
        `
      UPDATE playlists
      SET is_public = 1, share_code = ?, share_url = ?, updated_at = ?
      WHERE id = ?
    `,
      )
      .run(shareCode, shareUrl, now, existing.id);

    const updated = this.getPlaylistById(existing.id)!;
    this.db
      .prepare(
        `
      INSERT OR IGNORE INTO sync_mutation_log (
        idempotency_key, entity_type, entity_id, action, payload_json, creator_id, created_at
      ) VALUES (?, 'playlist', ?, 'update', ?, ?, ?)
    `,
      )
      .run(
        `pl_share_${existing.id}_${Date.now()}`,
        existing.id,
        JSON.stringify(updated),
        String(updated.creatorId ?? existing.creatorId ?? 'system'),
        now,
      );
    return updated;
  }

  // ---------------------------------------------------------------------------
  // Track C / Phase 59: Sovereign Creator Wallet Ledger & SA Banking Gateway
  // ---------------------------------------------------------------------------

  public getSaBanks(): SaBankMetadata[] {
    const seen = new Set<string>();
    const list: SaBankMetadata[] = [];
    for (const meta of Object.values(SA_BANK_REGISTRY)) {
      if (!seen.has(meta.code)) {
        seen.add(meta.code);
        list.push(meta);
      }
    }
    return list;
  }

  public getWallet(creatorId: string): {
    creatorId: string;
    balanceZar: number;
    balanceCoins: number;
    pendingPayoutZar: number;
    recentTransactions: any[];
  } {
    const rows = this.db
      .prepare('SELECT * FROM wallet_ledger WHERE creator_id = ? ORDER BY created_at DESC')
      .all(creatorId) as any[];

    let balanceZar = 0.0;
    let balanceCoins = 0;
    let pendingPayoutZar = 0.0;

    for (const r of rows) {
      if (
        r.type === 'topup' ||
        r.type === 'tip' ||
        r.type === 'tip_sent' ||
        r.type === 'tip_received' ||
        r.type === 'remix_royalty' ||
        r.type === 'license_sale' ||
        r.type === 'license_purchase'
      ) {
        if (r.status === 'completed') {
          balanceZar += r.amount_zar;
          balanceCoins += r.amount_coins;
        }
      } else if (r.type === 'payout' || r.type === 'payout_withdrawal') {
        const debitZar = Math.abs(r.amount_zar);
        if (r.status === 'completed' || r.status === 'instant_cleared') {
          balanceZar -= debitZar;
        } else if (
          r.status === 'pending' ||
          r.status === 'processing' ||
          r.status === 'processing_eft'
        ) {
          pendingPayoutZar += debitZar;
          balanceZar -= debitZar;
        }
      }
    }

    const recentTransactions = rows.slice(0, 10).map((r) => {
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
      creatorId,
      balanceZar: Math.max(0, Math.round(balanceZar * 100) / 100),
      balanceCoins: Math.max(0, balanceCoins),
      pendingPayoutZar: Math.round(pendingPayoutZar * 100) / 100,
      recentTransactions,
    };
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
    const trimmedRaw = (creatorId ?? '').trim();
    const resolvedId =
      trimmedRaw && this.hasWalletActivity(trimmedRaw)
        ? trimmedRaw
        : canonicalizeCreatorId(trimmedRaw);
    const wallet = this.getWallet(resolvedId);
    const rows = this.db
      .prepare('SELECT * FROM wallet_ledger WHERE creator_id = ? ORDER BY created_at DESC LIMIT 50')
      .all(resolvedId) as any[];
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

  private _executeCulturalTipTransfer(params: {
    tipId: string;
    clipId: string;
    senderId: string;
    recipientId: string;
    ancestorId?: string;
    amountCoins: number;
    amountZar: number;
    giftName: string;
    giftEmoji: string;
    giftId?: string;
    senderUsername?: string;
    message?: string;
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

    const senderSnap = this.getWallet(senderId);
    if (senderSnap.balanceCoins < coins) {
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
      'tip_sent',
      -zar,
      -coins,
      params.tipId,
      JSON.stringify({
        direction: 'sent',
        clipId: params.clipId,
        senderId,
        senderUsername: params.senderUsername ?? `@${senderId.replace(/^creator_/, '')}`,
        recipientId,
        giftId: params.giftId,
        giftName: params.giftName,
        giftEmoji: params.giftEmoji,
        message: params.message,
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
        'tip_received',
        primaryZar,
        primaryCoins,
        params.tipId,
        JSON.stringify({
          direction: 'received',
          clipId: params.clipId,
          senderId,
          senderUsername: params.senderUsername ?? `@${senderId.replace(/^creator_/, '')}`,
          giftId: params.giftId,
          giftName: params.giftName,
          giftEmoji: params.giftEmoji,
          message: params.message,
          splitPct: 70,
        }),
        nowIso,
      );
      insertStmt.run(
        `wtx_tip_anc_${params.tipId}`,
        ancestorId,
        'remix_royalty',
        ancestorZar,
        ancestorCoins,
        params.tipId,
        JSON.stringify({
          direction: 'remix_royalty',
          clipId: params.clipId,
          senderId,
          senderUsername: params.senderUsername ?? `@${senderId.replace(/^creator_/, '')}`,
          giftId: params.giftId,
          giftName: params.giftName,
          giftEmoji: params.giftEmoji,
          message: params.message,
          splitPct: 30,
        }),
        nowIso,
      );
    } else {
      insertStmt.run(
        `wtx_tip_in_${params.tipId}`,
        recipientId,
        'tip_received',
        zar,
        coins,
        params.tipId,
        JSON.stringify({
          direction: 'received',
          clipId: params.clipId,
          senderId,
          senderUsername: params.senderUsername ?? `@${senderId.replace(/^creator_/, '')}`,
          giftId: params.giftId,
          giftName: params.giftName,
          giftEmoji: params.giftEmoji,
          message: params.message,
          splitPct: 100,
        }),
        nowIso,
      );
    }

    return {
      outcome: 'committed',
      senderRemainingCoins: senderSnap.balanceCoins - coins,
      primaryCoins,
      ancestorCoins,
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
    giftId?: string;
    senderUsername?: string;
    message?: string;
  }): {
    outcome: 'committed' | 'insufficient_funds' | 'self_tip_forbidden';
    senderRemainingCoins: number;
    primaryCoins: number;
    ancestorCoins: number;
  } {
    this.db.exec('BEGIN IMMEDIATE');
    try {
      const result = this._executeCulturalTipTransfer(params);
      if (result.outcome !== 'committed') {
        this.db.exec('ROLLBACK');
        return result;
      }
      this.db.exec('COMMIT');
      return result;
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
      .prepare('SELECT * FROM payment_topups WHERE checkout_id = ?')
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
        .prepare('SELECT * FROM payment_topups WHERE provider_payment_id = ?')
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

  public topupWallet(creatorId: string, amountZar: number, amountCoins: number): any {
    const now = new Date().toISOString();
    const id = `tx_${Date.now()}_${randomUUID().slice(0, 8)}`;

    this.db.prepare(`
      INSERT INTO wallet_ledger (id, creator_id, type, amount_zar, amount_coins, status, reference, data_json, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(id, creatorId, 'topup', amountZar, amountCoins, 'completed', 'INSTANT_TOPUP', '{}', now);

    return this.getWallet(creatorId);
  }

  public requestPayout(req: BankPayoutRequest): {
    success: boolean;
    payoutId?: string;
    deductedZar?: number;
    remainingBalanceZar?: number;
    status?: string;
    bankName?: string;
    branchCode?: string;
    maskedAccount?: string;
    paymentRail?: string;
    estimatedSettlement?: string;
    gatewayRef?: string;
    processedAt?: string;
    error?: string;
  } {
    const rawBank = String(req.bankName || '').trim();
    const bankMeta = SA_BANK_REGISTRY[rawBank.toLowerCase()];
    if (!bankMeta) {
      return {
        success: false,
        error: `Invalid South African Bank: ${rawBank}. Supported banks: Capitec Bank, FNB, Standard Bank, Nedbank, Absa Bank, TymeBank`,
      };
    }

    const digits = String(req.accountNumber || '').replace(/\D/g, '');
    if (digits.length < 8 || digits.length > 12) {
      return {
        success: false,
        error: 'South African account number must contain 8 to 12 digits.',
      };
    }

    if (!Number.isFinite(req.amountZar) || req.amountZar < 50.0) {
      return {
        success: false,
        error: 'Minimum payout threshold is R50.00.',
      };
    }

    const normalizedRail = String(req.paymentRail || 'eft').trim().toLowerCase();
    const validRails = new Set(['capitec_pay', 'ozow', 'payfast', 'eft']);
    if (!validRails.has(normalizedRail)) {
      return {
        success: false,
        error: `Unsupported settlement rail: ${normalizedRail}. Supported: capitec_pay, ozow, payfast, eft`,
      };
    }

    if (normalizedRail === 'capitec_pay' && !bankMeta.supportsCapitecPay) {
      return {
        success: false,
        error: `Capitec Pay is only available for Capitec Bank accounts (selected: ${bankMeta.canonicalName}).`,
      };
    }

    const resolvedBranchCode =
      req.branchCode && req.branchCode.trim() !== ''
        ? req.branchCode.trim()
        : bankMeta.universalBranchCode;
    const maskedAccount = `****${digits.slice(-4)}`;
    const payoutId = `payout_${Date.now()}_${randomUUID().slice(0, 8)}`;
    const gatewayRef = `VH-PAY-${randomUUID().slice(0, 8).toUpperCase()}`;
    const now = new Date().toISOString();

    const isInstant =
      normalizedRail === 'capitec_pay' ||
      normalizedRail === 'ozow' ||
      normalizedRail === 'payfast';
    const ledgerStatus = isInstant ? 'instant_cleared' : 'processing';
    const estimatedSettlement = isInstant
      ? 'Instant (< 60s)'
      : '1-2 Business Days (SARB EFT)';

    const bankAccountId = `bank_${req.creatorId}_${bankMeta.code.toLowerCase()}`;
    const receiptPayload = {
      bankName: bankMeta.canonicalName,
      branchCode: resolvedBranchCode,
      maskedAccount,
      paymentRail: normalizedRail,
      estimatedSettlement,
      gatewayRef,
      accountHolder: req.accountHolder || null,
    };

    // Phase 61: Atomic SQLite write lock (`BEGIN IMMEDIATE`) eliminates TOCTOU double-spend races
    this.db.exec('BEGIN IMMEDIATE');
    try {
      const currentWallet = this.getWallet(req.creatorId);
      if (req.amountZar > currentWallet.balanceZar) {
        this.db.exec('ROLLBACK');
        return {
          success: false,
          error: `Insufficient ZAR balance. Requested R${req.amountZar.toFixed(2)}, available R${currentWallet.balanceZar.toFixed(2)}`,
        };
      }

      const existingBank = this.db
        .prepare('SELECT id FROM bank_accounts WHERE id = ?')
        .get(bankAccountId) as { id: string } | undefined;
      if (existingBank) {
        this.db
          .prepare(
            `
          UPDATE bank_accounts
          SET bank_name = ?, account_number = ?, branch_code = ?, account_type = ?, updated_at = ?
          WHERE id = ?
        `,
          )
          .run(
            bankMeta.canonicalName,
            maskedAccount,
            resolvedBranchCode,
            normalizedRail,
            now,
            bankAccountId,
          );
      } else {
        this.db
          .prepare(
            `
          INSERT INTO bank_accounts (
            id, creator_id, bank_name, account_number, branch_code, account_type, is_verified, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?)
        `,
          )
          .run(
            bankAccountId,
            req.creatorId,
            bankMeta.canonicalName,
            maskedAccount,
            resolvedBranchCode,
            normalizedRail,
            now,
            now,
          );
      }

      this.db.prepare(`
        INSERT INTO wallet_ledger (id, creator_id, type, amount_zar, amount_coins, status, reference, data_json, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      `).run(
        payoutId,
        req.creatorId,
        'payout',
        req.amountZar,
        0,
        ledgerStatus,
        gatewayRef,
        JSON.stringify(receiptPayload),
        now,
      );

      this.db
        .prepare(
          `
        INSERT OR IGNORE INTO sync_mutation_log (
          idempotency_key, entity_type, entity_id, action, payload_json, creator_id, created_at
        ) VALUES (?, 'payout', ?, 'create', ?, ?, ?)
      `,
        )
        .run(
          `payout_${payoutId}`,
          payoutId,
          JSON.stringify({
            payoutId,
            creatorId: req.creatorId,
            amountZar: req.amountZar,
            ...receiptPayload,
          }),
          req.creatorId,
          now,
        );

      this.db.exec('COMMIT');
    } catch (err) {
      try {
        this.db.exec('ROLLBACK');
      } catch (_) { }
      throw err;
    }

    const updatedWallet = this.getWallet(req.creatorId);

    return {
      success: true,
      payoutId,
      deductedZar: req.amountZar,
      remainingBalanceZar: updatedWallet.balanceZar,
      status: ledgerStatus,
      bankName: bankMeta.canonicalName,
      branchCode: resolvedBranchCode,
      maskedAccount,
      paymentRail: normalizedRail,
      estimatedSettlement,
      gatewayRef,
      processedAt: now,
    };
  }

  // ---------------------------------------------------------------------------
  // Phase 58: Sovereign Beatstore Licensing & SHA-256 Registry
  // ---------------------------------------------------------------------------

  public hasWalletActivity(creatorId: string): boolean {
    const row = this.db
      .prepare(
        "SELECT 1 as present FROM wallet_ledger WHERE creator_id = ? AND type IN ('topup', 'tip', 'tip_sent', 'tip_received', 'remix_royalty', 'license_sale', 'payout', 'payout_withdrawal') LIMIT 1",
      )
      .get(creatorId) as { present: number } | undefined;
    return Boolean(row);
  }

  public computeCanonicalLicenseHash(params: {
    certificateId: string;
    beatId: string;
    producerId: string;
    buyerId: string;
    tierSlug: string;
    amountPaidCoins: number;
    amountPaidZar: number;
    issuedAt: string;
    masterFileSha256?: string;
  }): string {
    const masterDigest =
      params.masterFileSha256 ||
      createHash('sha256').update(params.beatId).digest('hex');
    const preimage = [
      'VHUNAMBI_LIC_V2',
      params.certificateId,
      params.beatId,
      params.producerId,
      params.buyerId,
      params.tierSlug,
      String(params.amountPaidCoins),
      params.amountPaidZar.toFixed(2),
      params.issuedAt,
      masterDigest,
    ].join('|');
    return createHash('sha256').update(preimage).digest('hex');
  }

  private _executeBeatLicenseInsert(params: {
    certificateId: string;
    beatId: string;
    beatTitle: string;
    producerId: string;
    producerHandle: string;
    buyerId: string;
    buyerHandle: string;
    tierSlug: string;
    amountPaidCoins: number;
    amountPaidZar: number;
    producerRoyaltyCoins: number;
    producerRoyaltyZar: number;
    issuedAt: string;
    commercialTerms: string;
    masterFileSha256?: string;
    isExclusive: boolean;
    enforceBuyerWallet?: boolean;
    dataJson: Record<string, any>;
  }): {
    status: 'ok' | 'exclusive_conflict' | 'insufficient_funds';
    licenseHash?: string;
    masterFileSha256?: string;
  } {
    const asset = this.db
      .prepare('SELECT id, is_exclusive_sold FROM marketplace_assets WHERE id = ?')
      .get(params.beatId) as { id: string; is_exclusive_sold: number } | undefined;

    if (asset && asset.is_exclusive_sold === 1) {
      return { status: 'exclusive_conflict' };
    }

    const existingExclusive = this.db
      .prepare(
        "SELECT certificate_id FROM beat_licenses WHERE beat_id = ? AND tier IN ('exclusive_stem', 'unlimited_commercial') LIMIT 1",
      )
      .get(params.beatId) as { certificate_id: string } | undefined;
    if (existingExclusive) {
      return { status: 'exclusive_conflict' };
    }

    if (params.enforceBuyerWallet) {
      const wallet = this.getWallet(params.buyerId);
      if (wallet.balanceCoins < params.amountPaidCoins) {
        return { status: 'insufficient_funds' };
      }
    }

    const masterDigest =
      params.masterFileSha256 ||
      createHash('sha256').update(params.beatId).digest('hex');

    const licenseHash = this.computeCanonicalLicenseHash({
      certificateId: params.certificateId,
      beatId: params.beatId,
      producerId: params.producerId,
      buyerId: params.buyerId,
      tierSlug: params.tierSlug,
      amountPaidCoins: params.amountPaidCoins,
      amountPaidZar: params.amountPaidZar,
      issuedAt: params.issuedAt,
      masterFileSha256: masterDigest,
    });

    const payloadWithHash = {
      ...params.dataJson,
      licenseHash,
      masterFileSha256: masterDigest,
    };

    this.db
      .prepare(
        `INSERT INTO beat_licenses (
           certificate_id, license_hash, beat_id, producer_id, buyer_id, tier,
           coins_paid, zar_paid, producer_coins, producer_zar, issued_at, data_json
         ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      )
      .run(
        params.certificateId,
        licenseHash,
        params.beatId,
        params.producerId,
        params.buyerId,
        params.tierSlug,
        params.amountPaidCoins,
        params.amountPaidZar,
        params.producerRoyaltyCoins,
        params.producerRoyaltyZar,
        params.issuedAt,
        JSON.stringify(payloadWithHash),
      );

    if (params.enforceBuyerWallet) {
      this.db
        .prepare(
          `INSERT INTO wallet_ledger (id, creator_id, type, amount_zar, amount_coins, status, reference, data_json, created_at)
           VALUES (?, ?, 'license_purchase', ?, ?, 'completed', ?, ?, ?)`,
        )
        .run(
          `tx_buy_${Date.now()}_${params.certificateId}`,
          params.buyerId,
          -params.amountPaidZar,
          -params.amountPaidCoins,
          params.certificateId,
          JSON.stringify({ beatId: params.beatId, tier: params.tierSlug }),
          params.issuedAt,
        );
    }

    this.db
      .prepare(
        `INSERT INTO wallet_ledger (id, creator_id, type, amount_zar, amount_coins, status, reference, data_json, created_at)
         VALUES (?, ?, 'license_sale', ?, ?, 'completed', ?, ?, ?)`,
      )
      .run(
        `tx_roy_${Date.now()}_${params.certificateId}`,
        params.producerId,
        params.producerRoyaltyZar,
        params.producerRoyaltyCoins,
        params.certificateId,
        JSON.stringify({
          beatId: params.beatId,
          beatTitle: params.beatTitle,
          buyerId: params.buyerId,
          buyerHandle: params.buyerHandle,
          tier: params.tierSlug,
          message: `Beat license sale: "${params.beatTitle}" (${params.tierSlug.replaceAll('_', ' ')}) to ${params.buyerHandle}`,
        }),
        params.issuedAt,
      );

    if (params.isExclusive) {
      if (asset) {
        this.db
          .prepare(
            'UPDATE marketplace_assets SET is_exclusive_sold = 1, exclusive_buyer_id = ?, updated_at = ? WHERE id = ?',
          )
          .run(params.buyerId, params.issuedAt, params.beatId);
      } else {
        this.db
          .prepare(
            `INSERT INTO marketplace_assets (id, title, producer_id, asset_category, price_zar, price_coins, is_exclusive_sold, exclusive_buyer_id, data_json, created_at, updated_at)
             VALUES (?, ?, ?, 'beats', ?, ?, 1, ?, ?, ?, ?)`,
          )
          .run(
            params.beatId,
            params.beatTitle,
            params.producerId,
            params.amountPaidZar,
            params.amountPaidCoins,
            params.buyerId,
            JSON.stringify(payloadWithHash),
            params.issuedAt,
            params.issuedAt,
          );
      }
    }

    return { status: 'ok', licenseHash, masterFileSha256: masterDigest };
  }

  public recordBeatLicenseAtomic(params: {
    certificateId: string;
    beatId: string;
    beatTitle: string;
    producerId: string;
    producerHandle: string;
    buyerId: string;
    buyerHandle: string;
    tierSlug: string;
    amountPaidCoins: number;
    amountPaidZar: number;
    producerRoyaltyCoins: number;
    producerRoyaltyZar: number;
    issuedAt: string;
    commercialTerms: string;
    masterFileSha256?: string;
    isExclusive: boolean;
    enforceBuyerWallet?: boolean;
    dataJson: Record<string, any>;
  }): {
    status: 'ok' | 'exclusive_conflict' | 'insufficient_funds';
    licenseHash?: string;
    masterFileSha256?: string;
  } {
    this.db.exec('BEGIN IMMEDIATE');
    try {
      const result = this._executeBeatLicenseInsert(params);
      if (result.status !== 'ok') {
        this.db.exec('ROLLBACK');
        return result;
      }
      this.db.exec('COMMIT');
      return result;
    } catch (e) {
      this.db.exec('ROLLBACK');
      throw e;
    }
  }

  public getBeatLicensesByBuyer(buyerId: string): any[] {
    const rows = this.db
      .prepare('SELECT data_json FROM beat_licenses WHERE buyer_id = ? ORDER BY issued_at DESC')
      .all(buyerId) as Array<{ data_json: string }>;
    return rows.map((r) => JSON.parse(r.data_json));
  }

  public verifyBeatLicense(certificateId: string): {
    found: boolean;
    valid: boolean;
    certificate?: any;
  } {
    const row = this.db
      .prepare('SELECT * FROM beat_licenses WHERE certificate_id = ?')
      .get(certificateId) as
      | {
        certificate_id: string;
        license_hash: string;
        beat_id: string;
        producer_id: string;
        buyer_id: string;
        tier: string;
        coins_paid: number;
        zar_paid: number;
        issued_at: string;
        data_json: string;
      }
      | undefined;
    if (!row) return { found: false, valid: false };

    const parsed = JSON.parse(row.data_json);
    const recomputed = this.computeCanonicalLicenseHash({
      certificateId: row.certificate_id,
      beatId: row.beat_id,
      producerId: row.producer_id,
      buyerId: row.buyer_id,
      tierSlug: row.tier,
      amountPaidCoins: row.coins_paid,
      amountPaidZar: row.zar_paid,
      issuedAt: row.issued_at,
      masterFileSha256: parsed.masterFileSha256,
    });
    return {
      found: true,
      valid: recomputed === row.license_hash,
      certificate: parsed,
    };
  }

  // ---------------------------------------------------------------------------
  // Phase 61: Sovereign Identity, Cryptographic Auth & Multi-Tenant Sessions
  // ---------------------------------------------------------------------------

  private static normalizeHandle(rawHandle: string): string {
    const cleaned = rawHandle.trim().toLowerCase().replace(/^@+/, '');
    return `@${cleaned.replace(/[^a-z0-9_.-]/g, '')}`;
  }

  public getUserByCreatorId(creatorId: string): SovereignUserRecord | null {
    const canonicalId = canonicalizeCreatorId(creatorId);
    const row = this.db
      .prepare(
        `SELECT u.user_id, u.creator_id, u.handle, u.email, u.role, u.created_at,
                c.display_name, c.avatar_url, c.tier
         FROM users u
         LEFT JOIN creators c ON c.id = u.creator_id
         WHERE u.creator_id = ? OR u.creator_id = ?`,
      )
      .get(creatorId, canonicalId) as Record<string, unknown> | undefined;
    if (!row) return null;
    return {
      userId: String(row.user_id),
      creatorId: String(row.creator_id),
      handle: String(row.handle),
      displayName: String(row.display_name ?? row.handle),
      email: String(row.email),
      role: String(row.role ?? 'creator'),
      avatarUrl: String(
        row.avatar_url ??
        `https://api.dicebear.com/7.x/avataaars/svg?seed=${encodeURIComponent(String(row.creator_id))}`,
      ),
      isVerified: String(row.tier ?? 'verified') !== 'unverified',
      createdAt: String(row.created_at),
    };
  }

  public isSessionActive(sessionId: string): boolean {
    const row = this.db
      .prepare(
        `SELECT revoked, expires_at FROM auth_sessions WHERE session_id = ?`,
      )
      .get(sessionId) as { revoked: number; expires_at: string } | undefined;
    if (!row || Number(row.revoked) !== 0) {
      return false;
    }
    return new Date(row.expires_at).getTime() > Date.now();
  }

  private createAuthSessionAndTokens(
    user: SovereignUserRecord,
    deviceLabel = 'vhunambi_client',
  ): AuthTokenBundle {
    const now = new Date();
    const nowIso = now.toISOString();
    const expiresAtIso = new Date(
      now.getTime() + 30 * 24 * 60 * 60 * 1000,
    ).toISOString();
    const sessionId = `ses_${randomUUID().replace(/-/g, '').slice(0, 20)}`;
    const familyId = `fam_${randomUUID().replace(/-/g, '').slice(0, 16)}`;
    const { refreshToken, refreshTokenHash } = generateRefreshTokenPair();

    this.db
      .prepare(
        `INSERT INTO auth_sessions (
          session_id, user_id, creator_id, family_id, refresh_token_hash,
          previous_token_hash, device_label, expires_at, revoked, revoke_reason,
          created_at, rotated_at
        ) VALUES (?, ?, ?, ?, ?, NULL, ?, ?, 0, NULL, ?, ?)`,
      )
      .run(
        sessionId,
        user.userId,
        user.creatorId,
        familyId,
        refreshTokenHash,
        deviceLabel,
        expiresAtIso,
        nowIso,
        nowIso,
      );

    const signed = signAccessJwt({
      sub: user.userId,
      cid: user.creatorId,
      hdl: user.handle,
      sid: sessionId,
      role: user.role,
    });

    return {
      user,
      session: {
        sessionId,
        userId: user.userId,
        creatorId: user.creatorId,
        familyId,
        deviceLabel,
        expiresAt: expiresAtIso,
        revoked: false,
        revokeReason: null,
        createdAt: nowIso,
        rotatedAt: nowIso,
      },
      accessToken: signed.token,
      refreshToken,
      expiresAt: signed.expiresAtIso,
    };
  }

  public registerUser(input: {
    handle: string;
    email: string;
    password: string;
    displayName?: string;
    creatorId?: string;
    deviceLabel?: string;
    initialCoins?: number;
  }): AuthTokenBundle {
    const normalizedHandle = VhunambiDatabase.normalizeHandle(input.handle);
    if (normalizedHandle.length < 3) {
      throw new Error(
        'INVALID_HANDLE: Handle must contain at least 2 alphanumeric characters.',
      );
    }
    const normalizedEmail = input.email.trim().toLowerCase();
    if (!normalizedEmail.includes('@') || normalizedEmail.length < 5) {
      throw new Error('INVALID_EMAIL: A valid email address is required.');
    }
    if (!input.password || input.password.length < 8) {
      throw new Error(
        'WEAK_PASSWORD: Password must be at least 8 characters long.',
      );
    }

    const handleSlug = normalizedHandle.slice(1).replace(/[^a-z0-9_]/g, '_');
    const creatorId = input.creatorId?.trim() || `creator_${handleSlug}`;
    const userId = `usr_${handleSlug}_${randomUUID().slice(0, 6)}`;
    const displayName =
      input.displayName?.trim() || normalizedHandle.slice(1).toUpperCase();
    const passwordHash = hashPassword(input.password);
    const now = new Date().toISOString();

    this.db.exec('BEGIN IMMEDIATE');
    try {
      const existing = this.db
        .prepare(
          `SELECT user_id FROM users WHERE LOWER(handle) = ? OR LOWER(email) = ? OR LOWER(creator_id) = ?`,
        )
        .get(
          normalizedHandle.toLowerCase(),
          normalizedEmail,
          creatorId.toLowerCase(),
        ) as { user_id: string } | undefined;

      if (existing) {
        throw new Error(
          'AUTH_IDENTITY_EXISTS: A sovereign user with that handle, email, or creator ID already exists.',
        );
      }

      this.db
        .prepare(
          `INSERT INTO creators (
            id, handle, display_name, avatar_url, archetype, tier, reputation_score, data_json, created_at, updated_at
          ) VALUES (?, ?, ?, ?, 'aiSonicArchitect', 'verified', 150, ?, ?, ?)
          ON CONFLICT(id) DO UPDATE SET
            handle = excluded.handle,
            display_name = excluded.display_name,
            updated_at = excluded.updated_at`,
        )
        .run(
          creatorId,
          normalizedHandle,
          displayName,
          `https://api.dicebear.com/7.x/avataaars/svg?seed=${encodeURIComponent(creatorId)}`,
          JSON.stringify({ bio: 'Sovereign Creator on Vhunambi Cloud' }),
          now,
          now,
        );

      this.db
        .prepare(
          `INSERT INTO users (user_id, creator_id, handle, email, password_hash, role, created_at, updated_at)
           VALUES (?, ?, ?, ?, ?, 'creator', ?, ?)`,
        )
        .run(
          userId,
          creatorId,
          normalizedHandle,
          normalizedEmail,
          passwordHash,
          now,
          now,
        );

      const welcomeCoins =
        typeof input.initialCoins === 'number'
          ? Math.max(0, Math.round(input.initialCoins))
          : 2500;
      if (welcomeCoins > 0 && !this.hasWalletActivity(creatorId)) {
        const zarRate = 0.3;
        this.db
          .prepare(
            `INSERT INTO wallet_ledger (id, creator_id, type, amount_zar, amount_coins, status, reference, data_json, created_at)
             VALUES (?, ?, 'topup', ?, ?, 'completed', 'SOVEREIGN_GRANT', ?, ?)`,
          )
          .run(
            `wtx_welcome_${creatorId}`,
            creatorId,
            Number((welcomeCoins * zarRate).toFixed(2)),
            welcomeCoins,
            JSON.stringify({ note: 'Sovereign Creator Genesis Grant' }),
            now,
          );
      }

      this.db.exec('COMMIT');
    } catch (err) {
      try {
        this.db.exec('ROLLBACK');
      } catch (_) { }
      throw err;
    }

    const createdUser = this.getUserByCreatorId(creatorId)!;
    return this.createAuthSessionAndTokens(
      createdUser,
      input.deviceLabel ?? 'vhunambi_client',
    );
  }

  public authenticateUser(input: {
    identifier: string;
    password: string;
    deviceLabel?: string;
  }): AuthTokenBundle {
    const rawId = input.identifier.trim().toLowerCase();
    const handleCandidate = rawId.startsWith('@') ? rawId : `@${rawId}`;
    const canonicalCandidate = canonicalizeCreatorId(rawId).toLowerCase();

    const row = this.db
      .prepare(
        `SELECT user_id, creator_id, password_hash
         FROM users
         WHERE LOWER(email) = ? OR LOWER(handle) = ? OR LOWER(creator_id) = ? OR LOWER(creator_id) = ?`,
      )
      .get(rawId, handleCandidate, rawId, canonicalCandidate) as
      | { user_id: string; creator_id: string; password_hash: string }
      | undefined;

    if (!row || !verifyPassword(input.password, row.password_hash)) {
      throw new Error('INVALID_CREDENTIALS: Invalid handle/email or password.');
    }

    const user = this.getUserByCreatorId(row.creator_id);
    if (!user) {
      throw new Error('INVALID_CREDENTIALS: Creator record missing.');
    }

    return this.createAuthSessionAndTokens(
      user,
      input.deviceLabel ?? 'vhunambi_client',
    );
  }

  public rotateRefreshToken(refreshToken: string): AuthTokenBundle {
    const tokenHash = hashRefreshToken(refreshToken);

    const sessionRow = this.db
      .prepare(
        `SELECT session_id, user_id, creator_id, family_id, refresh_token_hash,
                previous_token_hash, device_label, expires_at, revoked, revoke_reason, created_at
         FROM auth_sessions
         WHERE refresh_token_hash = ? OR previous_token_hash = ?`,
      )
      .get(tokenHash, tokenHash) as Record<string, unknown> | undefined;

    if (!sessionRow) {
      throw new Error('AUTH_REFRESH_INVALID: Unrecognized refresh token.');
    }

    const familyId = String(sessionRow.family_id);
    const isReplayOfRotatedToken =
      String(sessionRow.previous_token_hash ?? '') === tokenHash &&
      String(sessionRow.refresh_token_hash) !== tokenHash;

    if (isReplayOfRotatedToken) {
      const nowIso = new Date().toISOString();
      this.db
        .prepare(
          `UPDATE auth_sessions
           SET revoked = 1, revoke_reason = 'TOKEN_REUSE_DETECTED', rotated_at = ?
           WHERE family_id = ?`,
        )
        .run(nowIso, familyId);
      throw new Error(
        'AUTH_TOKEN_REUSE_DETECTED: Refresh token reuse detected; session family revoked.',
      );
    }

    if (Number(sessionRow.revoked) !== 0) {
      throw new Error('AUTH_SESSION_REVOKED: Session has been revoked.');
    }

    if (new Date(String(sessionRow.expires_at)).getTime() <= Date.now()) {
      throw new Error('AUTH_SESSION_EXPIRED: Refresh session has expired.');
    }

    const nextPair = generateRefreshTokenPair();
    const nowIso = new Date().toISOString();
    const nextExpiresAt = new Date(
      Date.now() + 30 * 24 * 60 * 60 * 1000,
    ).toISOString();
    const sessionId = String(sessionRow.session_id);
    const creatorId = String(sessionRow.creator_id);

    this.db
      .prepare(
        `UPDATE auth_sessions
         SET previous_token_hash = refresh_token_hash,
             refresh_token_hash = ?,
             expires_at = ?,
             rotated_at = ?
         WHERE session_id = ?`,
      )
      .run(nextPair.refreshTokenHash, nextExpiresAt, nowIso, sessionId);

    const user = this.getUserByCreatorId(creatorId);
    if (!user) {
      throw new Error('AUTH_USER_NOT_FOUND: User no longer exists.');
    }

    const signed = signAccessJwt({
      sub: user.userId,
      cid: user.creatorId,
      hdl: user.handle,
      sid: sessionId,
      role: user.role,
    });

    return {
      user,
      session: {
        sessionId,
        userId: user.userId,
        creatorId: user.creatorId,
        familyId,
        deviceLabel: String(sessionRow.device_label ?? 'vhunambi_client'),
        expiresAt: nextExpiresAt,
        revoked: false,
        revokeReason: null,
        createdAt: String(sessionRow.created_at),
        rotatedAt: nowIso,
      },
      accessToken: signed.token,
      refreshToken: nextPair.refreshToken,
      expiresAt: signed.expiresAtIso,
    };
  }

  public revokeSession(
    sessionId: string,
    reason = 'USER_LOGOUT',
  ): { sessionId: string; revoked: boolean } {
    const nowIso = new Date().toISOString();
    const res = this.db
      .prepare(
        `UPDATE auth_sessions
         SET revoked = 1, revoke_reason = ?, rotated_at = ?
         WHERE session_id = ?`,
      )
      .run(reason, nowIso, sessionId);
    return {
      sessionId,
      revoked: Number(res.changes) > 0,
    };
  }

  public listSessionsForCreator(
    creatorId: string,
  ): SovereignAuthSessionRecord[] {
    const rows = this.db
      .prepare(
        `SELECT session_id, user_id, creator_id, family_id, device_label,
                expires_at, revoked, revoke_reason, created_at, rotated_at
         FROM auth_sessions
         WHERE creator_id = ?
         ORDER BY rotated_at DESC`,
      )
      .all(creatorId) as Array<Record<string, unknown>>;

    return rows.map((r) => ({
      sessionId: String(r.session_id),
      userId: String(r.user_id),
      creatorId: String(r.creator_id),
      familyId: String(r.family_id),
      deviceLabel: String(r.device_label ?? 'vhunambi_client'),
      expiresAt: String(r.expires_at),
      revoked: Number(r.revoked) !== 0,
      revokeReason: r.revoke_reason ? String(r.revoke_reason) : null,
      createdAt: String(r.created_at),
      rotatedAt: String(r.rotated_at),
    }));
  }

  // ---------------------------------------------------------------------------
  // Phase 62: Persistent Generation Jobs, Marketplace, Social & Voice Stores
  // ---------------------------------------------------------------------------

  private mapGenerationJobRow(r: Record<string, unknown>): GenerationJob {
    let stemUrls: Record<string, string> | undefined;
    try {
      const parsed = JSON.parse(String(r.stem_urls_json || '{}')) as Record<string, string>;
      if (parsed && Object.keys(parsed).length > 0) stemUrls = parsed;
    } catch {
      stemUrls = undefined;
    }

    let manifest: GenerationJob['manifest'];
    if (r.manifest_json) {
      try {
        manifest = JSON.parse(String(r.manifest_json)) as GenerationJob['manifest'];
      } catch {
        manifest = undefined;
      }
    }

    return {
      generationId: String(r.generation_id),
      trackTitle: String(r.track_title ?? 'Untitled Track'),
      genre: String(r.genre ?? 'Amapiano'),
      language: String(r.language ?? 'Instrumental'),
      status: String(r.status ?? 'queued') as GenerationJob['status'],
      step: String(r.step ?? 'queued') as GenerationJob['step'],
      progressPct: Number(r.progress_pct ?? 0),
      masterMp3Url: r.master_mp3_url ? String(r.master_mp3_url) : undefined,
      stemsZipUrl: r.stems_zip_url ? String(r.stems_zip_url) : undefined,
      stemUrls,
      manifestUrl: r.manifest_url ? String(r.manifest_url) : undefined,
      manifest,
      durationSec: r.duration_sec !== null && r.duration_sec !== undefined ? Number(r.duration_sec) : undefined,
      errorMessage: r.error_message ? String(r.error_message) : undefined,
      providerTaskId: r.provider_task_id ? String(r.provider_task_id) : undefined,
      createdAt: new Date(Number(r.created_at ?? Date.now())),
      updatedAt: new Date(Number(r.updated_at ?? Date.now())),
    };
  }

  public upsertGenerationJob(
    job: GenerationJob,
    creatorId = 'creator_cern',
    jobKind = 'audio_synthesis',
  ): void {
    const createdMs = job.createdAt instanceof Date ? job.createdAt.getTime() : Date.now();
    const updatedMs = job.updatedAt instanceof Date ? job.updatedAt.getTime() : Date.now();
    this.db
      .prepare(
        `INSERT INTO generation_jobs (
          generation_id, creator_id, job_kind, provider_task_id, status, step,
          progress_pct, track_title, genre, language, duration_sec,
          master_mp3_url, stems_zip_url, stem_urls_json, manifest_url,
          manifest_json, error_message, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(generation_id) DO UPDATE SET
          provider_task_id = COALESCE(excluded.provider_task_id, generation_jobs.provider_task_id),
          status = excluded.status,
          step = excluded.step,
          progress_pct = excluded.progress_pct,
          track_title = excluded.track_title,
          genre = excluded.genre,
          language = excluded.language,
          duration_sec = excluded.duration_sec,
          master_mp3_url = COALESCE(excluded.master_mp3_url, generation_jobs.master_mp3_url),
          stems_zip_url = COALESCE(excluded.stems_zip_url, generation_jobs.stems_zip_url),
          stem_urls_json = excluded.stem_urls_json,
          manifest_url = COALESCE(excluded.manifest_url, generation_jobs.manifest_url),
          manifest_json = COALESCE(excluded.manifest_json, generation_jobs.manifest_json),
          error_message = excluded.error_message,
          updated_at = excluded.updated_at`,
      )
      .run(
        job.generationId,
        canonicalizeCreatorId(creatorId),
        jobKind,
        job.providerTaskId ?? null,
        job.status,
        job.step,
        Math.round(job.progressPct ?? 0),
        job.trackTitle,
        job.genre,
        job.language,
        job.durationSec ?? 180,
        job.masterMp3Url ?? null,
        job.stemsZipUrl ?? null,
        JSON.stringify(job.stemUrls ?? {}),
        job.manifestUrl ?? null,
        job.manifest ? JSON.stringify(job.manifest) : null,
        job.errorMessage ?? null,
        createdMs,
        updatedMs,
      );
  }

  public getGenerationJob(generationId: string): GenerationJob | null {
    const row = this.db
      .prepare('SELECT * FROM generation_jobs WHERE generation_id = ?')
      .get(generationId) as Record<string, unknown> | undefined;
    return row ? this.mapGenerationJobRow(row) : null;
  }

  public updateGenerationJob(
    generationId: string,
    updates: Partial<GenerationJob>,
  ): GenerationJob | null {
    const existing = this.getGenerationJob(generationId);
    if (!existing) return null;
    const merged: GenerationJob = {
      ...existing,
      ...updates,
      updatedAt: new Date(),
    };
    this.upsertGenerationJob(merged);
    return this.getGenerationJob(generationId);
  }

  public listGenerationJobs(creatorId?: string): GenerationJob[] {
    const rows =
      creatorId && creatorId.trim() !== ''
        ? (this.db
          .prepare('SELECT * FROM generation_jobs WHERE creator_id = ? ORDER BY created_at DESC')
          .all(canonicalizeCreatorId(creatorId)) as Array<Record<string, unknown>>)
        : (this.db
          .prepare('SELECT * FROM generation_jobs ORDER BY created_at DESC')
          .all() as Array<Record<string, unknown>>);
    return rows.map((r) => this.mapGenerationJobRow(r));
  }

  public countActiveGenerationJobs(): number {
    const row = this.db
      .prepare(
        "SELECT COUNT(*) as cnt FROM generation_jobs WHERE status IN ('queued', 'running', 'synthesizing', 'splitting_stems', 'extracting_mmo')",
      )
      .get() as { cnt: number };
    return Number(row?.cnt ?? 0);
  }

  // Persistent Marketplace Assets (M62.4)
  public countMarketplaceBeats(): number {
    const row = this.db
      .prepare("SELECT COUNT(*) as cnt FROM marketplace_assets WHERE asset_category = 'beats'")
      .get() as { cnt: number };
    return Number(row?.cnt ?? 0);
  }

  public upsertMarketplaceBeat(beat: Record<string, any>): void {
    const now = new Date().toISOString();
    const id = String(beat.id);
    const title = String(beat.title || 'Untitled Beat');
    const producerId = String(beat.producerId || 'creator_cern');
    const priceZar = Number(beat.priceZar ?? 0);
    const priceCoins = Number(beat.priceCoins ?? 0);
    const isExclusiveSold = beat.isExclusiveSold ? 1 : 0;
    const exclusiveBuyerId = beat.exclusiveBuyerId ? String(beat.exclusiveBuyerId) : null;
    const createdAt = String(beat.createdAt || now);
    const updatedAt = String(beat.updatedAt || now);

    this.db
      .prepare(
        `INSERT INTO marketplace_assets (
          id, title, producer_id, asset_category, price_zar, price_coins,
          is_exclusive_sold, exclusive_buyer_id, data_json, created_at, updated_at
        ) VALUES (?, ?, ?, 'beats', ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          title = excluded.title,
          producer_id = excluded.producer_id,
          price_zar = excluded.price_zar,
          price_coins = excluded.price_coins,
          is_exclusive_sold = excluded.is_exclusive_sold,
          exclusive_buyer_id = excluded.exclusive_buyer_id,
          data_json = excluded.data_json,
          updated_at = excluded.updated_at`,
      )
      .run(
        id,
        title,
        producerId,
        priceZar,
        priceCoins,
        isExclusiveSold,
        exclusiveBuyerId,
        JSON.stringify(beat),
        createdAt,
        updatedAt,
      );
  }

  private mapMarketplaceBeatRow(r: Record<string, any>): Record<string, any> {
    let data: Record<string, any> = {};
    try {
      data = JSON.parse(String(r.data_json || '{}'));
    } catch {
      data = {};
    }
    return {
      ...data,
      id: String(r.id),
      title: String(data.title ?? r.title),
      producerId: String(data.producerId ?? r.producer_id),
      priceZar: Number(data.priceZar ?? r.price_zar ?? 0),
      priceCoins: Number(data.priceCoins ?? r.price_coins ?? 0),
      isExclusiveSold: Number(r.is_exclusive_sold ?? 0) === 1 || Boolean(data.isExclusiveSold),
      exclusiveBuyerId: r.exclusive_buyer_id ?? data.exclusiveBuyerId,
      createdAt: String(data.createdAt ?? r.created_at),
      updatedAt: String(data.updatedAt ?? r.updated_at),
    };
  }

  public getMarketplaceBeatById(beatId: string): Record<string, any> | null {
    const row = this.db
      .prepare("SELECT * FROM marketplace_assets WHERE id = ? AND asset_category = 'beats'")
      .get(beatId) as Record<string, any> | undefined;
    return row ? this.mapMarketplaceBeatRow(row) : null;
  }

  public listMarketplaceBeats(includeExclusiveSold = false): Record<string, any>[] {
    const rows = includeExclusiveSold
      ? (this.db
        .prepare("SELECT * FROM marketplace_assets WHERE asset_category = 'beats' ORDER BY created_at DESC, rowid DESC")
        .all() as Array<Record<string, any>>)
      : (this.db
        .prepare(
          "SELECT * FROM marketplace_assets WHERE asset_category = 'beats' AND is_exclusive_sold = 0 ORDER BY created_at DESC, rowid DESC",
        )
        .all() as Array<Record<string, any>>);
    return rows.map((r) => this.mapMarketplaceBeatRow(r));
  }

  public incrementBeatAuditionCount(beatId: string): number {
    const existing = this.getMarketplaceBeatById(beatId);
    if (!existing) return 0;
    const nextCount = Number(existing.auditionCount ?? 0) + 1;
    const updated = {
      ...existing,
      auditionCount: nextCount,
      updatedAt: new Date().toISOString(),
    };
    this.upsertMarketplaceBeat(updated);
    return nextCount;
  }

  public updateMarketplaceBeatSaleState(
    beatId: string,
    params: { isExclusiveSold?: boolean; exclusiveBuyerId?: string },
  ): Record<string, any> | null {
    const existing = this.getMarketplaceBeatById(beatId);
    if (!existing) return null;
    const updated = {
      ...existing,
      salesCount: Number(existing.salesCount ?? 0) + 1,
      isExclusiveSold: params.isExclusiveSold ?? existing.isExclusiveSold ?? false,
      exclusiveBuyerId: params.exclusiveBuyerId ?? existing.exclusiveBuyerId,
      updatedAt: new Date().toISOString(),
    };
    this.upsertMarketplaceBeat(updated);
    return updated;
  }

  public deleteMarketplaceBeat(beatId: string): boolean {
    const res = this.db
      .prepare("DELETE FROM marketplace_assets WHERE id = ? AND asset_category = 'beats'")
      .run(beatId);
    return Number(res.changes ?? 0) > 0;
  }

  // Persistent Social Clips, Comments & Interactions (M62.4)
  public countPublishedClips(): number {
    const row = this.db.prepare('SELECT COUNT(*) as cnt FROM published_clips').get() as { cnt: number };
    return Number(row?.cnt ?? 0);
  }

  public upsertPublishedClip(clip: Record<string, any>): void {
    const now = new Date().toISOString();
    const id = String(clip.id);
    const creatorId = canonicalizeCreatorId(String(clip.creatorId || 'creator_cern'));
    const creatorHandle = String(clip.creatorUsername || clip.creatorHandle || `@${creatorId.replace(/^creator_/, '')}`);
    const videoUrl = String(clip.audioUrl || clip.videoUrl || '');
    const audioTitle = String(clip.title || 'Untitled Clip');
    const bantuLanguage = clip.genre ? String(clip.genre) : null;
    const viewsCount = Number(clip.playCount ?? clip.viewsCount ?? 0);
    const likesCount = Number(clip.likeCount ?? clip.likesCount ?? 0);
    const commentsCount = Number(clip.commentCount ?? clip.commentsCount ?? 0);
    const remixesCount = Number(clip.remixCount ?? clip.remixesCount ?? 0);
    const remixedFromClipId = clip.remixedFromClipId ? String(clip.remixedFromClipId) : null;
    const createdAt = String(clip.publishedAt || clip.createdAt || now);

    this.db
      .prepare(
        `INSERT INTO published_clips (
          id, creator_id, creator_handle, video_url, audio_title, bantu_language,
          views_count, likes_count, comments_count, remixes_count, remixed_from_clip_id,
          data_json, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          video_url = excluded.video_url,
          audio_title = excluded.audio_title,
          views_count = excluded.views_count,
          likes_count = excluded.likes_count,
          comments_count = excluded.comments_count,
          remixes_count = excluded.remixes_count,
          remixed_from_clip_id = excluded.remixed_from_clip_id,
          data_json = excluded.data_json,
          updated_at = excluded.updated_at`,
      )
      .run(
        id,
        creatorId,
        creatorHandle,
        videoUrl,
        audioTitle,
        bantuLanguage,
        viewsCount,
        likesCount,
        commentsCount,
        remixesCount,
        remixedFromClipId,
        JSON.stringify({
          ...clip,
          creatorId,
          creatorUsername: creatorHandle,
        }),
        createdAt,
        now,
      );
  }

  private mapPublishedClipRow(r: Record<string, any>): Record<string, any> {
    let data: Record<string, any> = {};
    try {
      data = JSON.parse(String(r.data_json || '{}'));
    } catch {
      data = {};
    }
    return {
      ...data,
      id: String(r.id),
      creatorId: String(data.creatorId ?? r.creator_id),
      creatorUsername: String(data.creatorUsername ?? r.creator_handle),
      title: String(data.title ?? r.audio_title),
      playCount: Number(r.views_count ?? data.playCount ?? 0),
      likeCount: Number(r.likes_count ?? data.likeCount ?? 0),
      commentCount: Number(r.comments_count ?? data.commentCount ?? 0),
      remixCount: Number(r.remixes_count ?? data.remixCount ?? 0),
      remixedFromClipId: r.remixed_from_clip_id ?? data.remixedFromClipId ?? undefined,
      publishedAt: String(data.publishedAt ?? r.created_at),
    };
  }

  public getPublishedClipRow(clipId: string): Record<string, any> | null {
    const row = this.db
      .prepare('SELECT * FROM published_clips WHERE id = ?')
      .get(clipId) as Record<string, any> | undefined;
    return row ? this.mapPublishedClipRow(row) : null;
  }

  public listPublishedClipRows(): Record<string, any>[] {
    const rows = this.db
      .prepare('SELECT * FROM published_clips ORDER BY created_at DESC, rowid DESC')
      .all() as Array<Record<string, any>>;
    return rows.map((r) => this.mapPublishedClipRow(r));
  }

  public listRemixClipRows(parentClipId: string): Record<string, any>[] {
    const rows = this.db
      .prepare('SELECT * FROM published_clips WHERE remixed_from_clip_id = ? ORDER BY created_at DESC, rowid DESC')
      .all(parentClipId) as Array<Record<string, any>>;
    return rows.map((r) => this.mapPublishedClipRow(r));
  }

  public insertReelComment(comment: Record<string, any>): void {
    const id = String(comment.id);
    const reelId = String(comment.clipId || comment.reelId);
    const creatorId = String(comment.userId || comment.creatorId || 'creator_cern');
    const content = String(comment.text || comment.content || '');
    const createdAt = String(comment.createdAt || new Date().toISOString());

    this.db
      .prepare(
        `INSERT OR REPLACE INTO reel_comments (
          id, reel_id, creator_id, content, language_code, data_json, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?)`,
      )
      .run(
        id,
        reelId,
        creatorId,
        content,
        comment.languageCode ? String(comment.languageCode) : null,
        JSON.stringify(comment),
        createdAt,
      );
  }

  private mapReelCommentRow(r: Record<string, any>): Record<string, any> {
    let data: Record<string, any> = {};
    try {
      data = JSON.parse(String(r.data_json || '{}'));
    } catch {
      data = {};
    }
    return {
      ...data,
      id: String(r.id),
      clipId: String(data.clipId ?? r.reel_id),
      userId: String(data.userId ?? r.creator_id),
      text: String(data.text ?? r.content),
      likeCount: Number(data.likeCount ?? 0),
      createdAt: String(data.createdAt ?? r.created_at),
    };
  }

  public getReelCommentById(commentId: string): Record<string, any> | null {
    const row = this.db
      .prepare('SELECT * FROM reel_comments WHERE id = ?')
      .get(commentId) as Record<string, any> | undefined;
    return row ? this.mapReelCommentRow(row) : null;
  }

  public listReelCommentsByClip(clipId: string): Record<string, any>[] {
    const rows = this.db
      .prepare('SELECT * FROM reel_comments WHERE reel_id = ? ORDER BY created_at DESC, rowid DESC')
      .all(clipId) as Array<Record<string, any>>;
    return rows.map((r) => this.mapReelCommentRow(r));
  }

  public hasSocialInteraction(
    interactionType: string,
    targetId: string,
    actorCreatorId: string,
  ): boolean {
    const row = this.db
      .prepare(
        'SELECT 1 as present FROM social_interactions WHERE interaction_type = ? AND target_id = ? AND actor_creator_id = ?',
      )
      .get(interactionType, targetId, canonicalizeCreatorId(actorCreatorId)) as { present: number } | undefined;
    return Boolean(row);
  }

  public setSocialInteraction(
    interactionType: string,
    targetId: string,
    actorCreatorId: string,
    active: boolean,
  ): boolean {
    const actor = canonicalizeCreatorId(actorCreatorId);
    if (active) {
      this.db
        .prepare(
          'INSERT OR IGNORE INTO social_interactions (interaction_type, target_id, actor_creator_id, created_at) VALUES (?, ?, ?, ?)',
        )
        .run(interactionType, targetId, actor, Date.now());
    } else {
      this.db
        .prepare(
          'DELETE FROM social_interactions WHERE interaction_type = ? AND target_id = ? AND actor_creator_id = ?',
        )
        .run(interactionType, targetId, actor);
    }
    return active;
  }

  public toggleSocialInteraction(
    interactionType: string,
    targetId: string,
    actorCreatorId: string,
  ): boolean {
    const currentlyActive = this.hasSocialInteraction(
      interactionType,
      targetId,
      actorCreatorId,
    );
    return this.setSocialInteraction(
      interactionType,
      targetId,
      actorCreatorId,
      !currentlyActive,
    );
  }

  public listSocialInteractionTargets(
    interactionType: string,
    actorCreatorId: string,
  ): Set<string> {
    const rows = this.db
      .prepare(
        'SELECT target_id FROM social_interactions WHERE interaction_type = ? AND actor_creator_id = ?',
      )
      .all(interactionType, canonicalizeCreatorId(actorCreatorId)) as Array<{ target_id: string }>;
    return new Set(rows.map((r) => String(r.target_id)));
  }

  public countSocialInteractionActors(
    interactionType: string,
    targetId: string,
  ): number {
    const row = this.db
      .prepare(
        'SELECT COUNT(*) as cnt FROM social_interactions WHERE interaction_type = ? AND target_id = ?',
      )
      .get(interactionType, targetId) as { cnt: number };
    return Number(row?.cnt ?? 0);
  }

  // Persistent Voice Clones & Sound Signatures (M62.4)
  public upsertVoiceClone(profile: Record<string, any>): void {
    const now = new Date().toISOString();
    this.db
      .prepare(
        `INSERT OR REPLACE INTO voice_clones (
          voice_id, creator_id, display_name, consent_verified,
          reference_audio_duration_sec, r2_reference_url,
          pitch_range_hz_json, timbre_embedding_json, data_json, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      )
      .run(
        String(profile.voiceId),
        canonicalizeCreatorId(String(profile.creatorId || 'creator_cern')),
        String(profile.displayName || 'Cloned Voice'),
        profile.consentVerified ? 1 : 0,
        Number(profile.referenceAudioDurationSec ?? 15.0),
        String(profile.r2ReferenceUrl || ''),
        JSON.stringify(profile.pitchRangeHz ?? [110, 660]),
        JSON.stringify(profile.timbreEmbedding ?? []),
        JSON.stringify(profile),
        String(profile.createdAt || now),
      );
  }

  public getVoiceCloneById(voiceId: string): Record<string, any> | null {
    const row = this.db
      .prepare('SELECT * FROM voice_clones WHERE voice_id = ?')
      .get(voiceId) as Record<string, any> | undefined;
    if (!row) return null;
    try {
      return JSON.parse(String(row.data_json || '{}'));
    } catch {
      return {
        voiceId: String(row.voice_id),
        creatorId: String(row.creator_id),
        displayName: String(row.display_name),
        consentVerified: Number(row.consent_verified) === 1,
        referenceAudioDurationSec: Number(row.reference_audio_duration_sec),
        r2ReferenceUrl: String(row.r2_reference_url),
        pitchRangeHz: JSON.parse(String(row.pitch_range_hz_json || '[110,660]')),
        timbreEmbedding: JSON.parse(String(row.timbre_embedding_json || '[]')),
        createdAt: String(row.created_at),
      };
    }
  }

  public upsertSoundSignature(sig: Record<string, any>): void {
    const now = new Date().toISOString();
    this.db
      .prepare(
        `INSERT OR REPLACE INTO sound_signatures (
          id, creator_id, timbre_name, match_confidence, data_json, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?)`,
      )
      .run(
        String(sig.id),
        canonicalizeCreatorId(String(sig.creatorId || 'creator_cern')),
        String(sig.name || sig.timbreName || 'Sound Signature'),
        Math.round(Number(sig.matchConfidence ?? 90)),
        JSON.stringify(sig),
        String(sig.createdAt || now),
        String(sig.updatedAt || now),
      );
  }

  public getSoundSignatureById(sigId: string): Record<string, any> | null {
    const row = this.db
      .prepare('SELECT * FROM sound_signatures WHERE id = ?')
      .get(sigId) as Record<string, any> | undefined;
    if (!row) return null;
    try {
      return JSON.parse(String(row.data_json || '{}'));
    } catch {
      return {
        id: String(row.id),
        creatorId: String(row.creator_id),
        name: String(row.timbre_name),
        createdAt: String(row.created_at),
        updatedAt: String(row.updated_at),
      };
    }
  }

  public deleteSoundSignature(sigId: string): boolean {
    const res = this.db
      .prepare('DELETE FROM sound_signatures WHERE id = ?')
      .run(sigId);
    return Number(res.changes ?? 0) > 0;
  }
}

let _defaultVhunambiDbInstance: VhunambiDatabase | null = null;

export function getDefaultVhunambiDb(): VhunambiDatabase {
  if (!isNodeSqliteAvailable()) {
    return getEdgeIsolateDatabaseEngine() as unknown as VhunambiDatabase;
  }
  if (!_defaultVhunambiDbInstance) {
    _defaultVhunambiDbInstance = new VhunambiDatabase();
  }
  return _defaultVhunambiDbInstance;
}

// Lazy-initializing Proxy so pure V8 Cloudflare Worker isolates never open SQLite on module load
export const vhunambiDb: VhunambiDatabase = new Proxy(
  {} as VhunambiDatabase,
  {
    get(_target, prop) {
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


import { DatabaseSync } from 'node:sqlite';
import * as fs from 'node:fs';
import * as path from 'node:path';

export interface SyncMutationRecord {
  idempotencyKey: string;
  entityType: string;
  action: string;
  payload: Record<string, any>;
  createdAt: string;
  priority?: 'critical' | 'normal' | 'background';
  baseSeq?: number;
  schemaVersion?: number;
}

export interface SyncDeltaResult {
  mutations: Array<{
    seq: number;
    idempotencyKey: string;
    entityType: string;
    entityId: string;
    action: string;
    payload: Record<string, any>;
    createdAt: string;
  }>;
  latestSeq: number;
  nextCursorSeq?: number;
  hasMore?: boolean;
}

export interface ExploreFeedOptions {
  stage?: 'mainstage' | 'risingBreakout' | 'freshCrate' | 'following';
  genre?: string;
  limit?: number;
  offset?: number;
}

export interface BankPayoutRequest {
  creatorId: string;
  amountZar: number;
  bankName: string;
  accountNumber: string;
  branchCode: string;
}

/**
 * Enterprise SQLite WAL Persistence Engine for Vhunambi API (REQ-P45-DB-01..06).
 * Supports zero-configuration disk persistence with WAL journal mode and in-memory test fallback.
 */
export class VhunambiDatabase {
  private db: DatabaseSync;
  private isMemory: boolean;

  constructor(dbPathOrMemory?: string) {
    if (dbPathOrMemory === ':memory:' || process.env.NODE_ENV === 'test') {
      this.db = new DatabaseSync(':memory:');
      this.isMemory = true;
    } else {
      const targetPath = dbPathOrMemory || path.resolve(process.cwd(), 'data', 'vhunambi_api.sqlite3');
      const dir = path.dirname(targetPath);
      if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
      }
      this.db = new DatabaseSync(targetPath);
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
        created_at TEXT NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_mutation_seq ON sync_mutation_log(seq);
      CREATE INDEX IF NOT EXISTS idx_mutation_idempotency ON sync_mutation_log(idempotency_key);
    `);

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

    // 7. Marketplace Assets
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS marketplace_assets (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        producer_id TEXT NOT NULL,
        asset_category TEXT NOT NULL,
        price_zar REAL NOT NULL,
        price_coins INTEGER NOT NULL,
        data_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
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
        INSERT INTO wallet_ledger (id, creator_id, type, amount_zar, amount_coins, status, reference, data_json, created_at)
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
      INSERT INTO sync_mutation_log (idempotency_key, entity_type, entity_id, action, payload_json, created_at)
      VALUES (?, ?, ?, ?, ?, ?)
    `);

    // Commutative counter operations: atomic increment, never overwrite.
    const commutativeCounterActions = new Set(['like', 'cosign', 'repost', 'tip']);

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

        const entityId = m.payload?.id || `gen_${Date.now()}`;
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
          this.topupWallet(m.payload?.recipientId || 'creator_cern', m.payload?.amountZar || 10, m.payload?.amountCoins || 100);
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
        }

        if (shouldApply) {
          insertLogStmt.run(
            m.idempotencyKey,
            m.entityType,
            entityId,
            m.action,
            JSON.stringify(m.payload),
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

  public getDelta(sinceSeq: number, limit: number = 100): SyncDeltaResult {
    const stmt = this.db.prepare(`
      SELECT seq, idempotency_key, entity_type, entity_id, action, payload_json, created_at
      FROM sync_mutation_log
      WHERE seq > ?
      ORDER BY seq ASC
      LIMIT ?
    `);

    const rows = stmt.all(sinceSeq, limit) as Array<{
      seq: number;
      idempotency_key: string;
      entity_type: string;
      entity_id: string;
      action: string;
      payload_json: string;
      created_at: string;
    }>;

    const mutations = rows.map((r) => ({
      seq: r.seq,
      idempotencyKey: r.idempotency_key,
      entityType: r.entity_type,
      entityId: r.entity_id,
      action: r.action,
      payload: JSON.parse(r.payload_json || '{}'),
      createdAt: r.created_at,
    }));

    const latestSeq = this.getLatestSeq();
    const hasMore = mutations.length === limit && mutations.length > 0;
    const nextCursorSeq = mutations.length > 0 ? mutations[mutations.length - 1].seq : latestSeq;

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
  // Track C: Explore & Social Endpoints (REQ-P45-EXP-01..06)
  // ---------------------------------------------------------------------------

  public getExploreFeed(options: ExploreFeedOptions = {}): { posts: any[]; total: number } {
    let sql = 'SELECT * FROM kinetic_posts WHERE 1=1';
    const params: any[] = [];

    if (options.stage) {
      sql += ' AND discovery_stage = ?';
      params.push(options.stage);
    }

    sql += ' ORDER BY cosign_count DESC, created_at DESC';

    if (options.limit) {
      sql += ' LIMIT ?';
      params.push(options.limit);
      if (options.offset) {
        sql += ' OFFSET ?';
        params.push(options.offset);
      }
    }

    const rows = this.db.prepare(sql).all(...params) as any[];
    const totalRow = this.db.prepare('SELECT COUNT(*) as count FROM kinetic_posts').get() as { count: number };

    const posts = rows.map((r) => {
      let data = {};
      try {
        data = JSON.parse(r.data_json);
      } catch (_) {}
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

    return { posts, total: totalRow.count };
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
  // Track C: Cloud Vault Library Sync Endpoints (REQ-P45-LIB-01..04)
  // ---------------------------------------------------------------------------

  public getLibrary(creatorId: string): any[] {
    const rows = this.db.prepare('SELECT * FROM user_library_sync WHERE creator_id = ? ORDER BY updated_at DESC').all(creatorId) as any[];
    return rows.map((r) => {
      let data = {};
      try {
        data = JSON.parse(r.data_json);
      } catch (_) {}
      return {
        id: r.id,
        creatorId: r.creator_id,
        itemType: r.item_type,
        title: r.title,
        createdAt: r.created_at,
        updated_at: r.updated_at,
        ...data,
      };
    });
  }

  public upsertLibrary(creatorId: string, items: any[]): number {
    const stmt = this.db.prepare(`
      INSERT INTO user_library_sync (id, creator_id, item_type, title, data_json, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        title = excluded.title,
        data_json = excluded.data_json,
        updated_at = excluded.updated_at
      WHERE excluded.updated_at >= user_library_sync.updated_at
    `);

    let count = 0;
    const now = new Date().toISOString();

    for (const item of items) {
      const id = item.id || `lib_${Date.now()}_${count}`;
      const itemType = item.itemType || 'track';
      const title = item.title || 'Untitled Track';
      const updatedAt = item.updatedAt || now;

      stmt.run(id, creatorId, itemType, title, JSON.stringify(item), now, updatedAt);
      count++;
    }

    return count;
  }

  // ---------------------------------------------------------------------------
  // Track C: Sovereign Creator Wallet Ledger & Payouts (REQ-P45-WAL-01..05)
  // ---------------------------------------------------------------------------

  public getWallet(creatorId: string): {
    creatorId: string;
    balanceZar: number;
    balanceCoins: number;
    pendingPayoutZar: number;
    recentTransactions: any[];
  } {
    const rows = this.db.prepare('SELECT * FROM wallet_ledger WHERE creator_id = ? ORDER BY created_at DESC').all(creatorId) as any[];

    let balanceZar = 0.0;
    let balanceCoins = 0;
    let pendingPayoutZar = 0.0;

    for (const r of rows) {
      if (r.status === 'completed') {
        if (r.type === 'topup' || r.type === 'tip' || r.type === 'license_sale') {
          balanceZar += r.amount_zar;
          balanceCoins += r.amount_coins;
        } else if (r.type === 'payout') {
          balanceZar -= r.amount_zar;
        }
      } else if (r.status === 'pending' && r.type === 'payout') {
        pendingPayoutZar += r.amount_zar;
        balanceZar -= r.amount_zar;
      }
    }

    const recentTransactions = rows.slice(0, 10).map((r) => ({
      id: r.id,
      type: r.type,
      amountZar: r.amount_zar,
      amountCoins: r.amount_coins,
      status: r.status,
      reference: r.reference,
      createdAt: r.created_at,
    }));

    return {
      creatorId,
      balanceZar: Math.max(0, Math.round(balanceZar * 100) / 100),
      balanceCoins: Math.max(0, balanceCoins),
      pendingPayoutZar: Math.round(pendingPayoutZar * 100) / 100,
      recentTransactions,
    };
  }

  public topupWallet(creatorId: string, amountZar: number, amountCoins: number): any {
    const now = new Date().toISOString();
    const id = `tx_${Date.now()}`;

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
    error?: string;
  } {
    const allowedBanks = ['ABSA', 'FNB', 'Standard Bank', 'Capitec', 'Nedbank', 'TymeBank'];
    if (!allowedBanks.includes(req.bankName)) {
      return { success: false, error: `Invalid South African Bank: ${req.bankName}. Must be one of ${allowedBanks.join(', ')}` };
    }

    const currentWallet = this.getWallet(req.creatorId);
    if (req.amountZar <= 0 || req.amountZar > currentWallet.balanceZar) {
      return {
        success: false,
        error: `Insufficient ZAR balance. Requested R${req.amountZar.toFixed(2)}, available R${currentWallet.balanceZar.toFixed(2)}`,
      };
    }

    const payoutId = `pay_${Date.now()}`;
    const now = new Date().toISOString();

    this.db.prepare(`
      INSERT INTO wallet_ledger (id, creator_id, type, amount_zar, amount_coins, status, reference, data_json, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      payoutId,
      req.creatorId,
      'payout',
      req.amountZar,
      0,
      'pending',
      `PAYOUT_${req.bankName.toUpperCase()}`,
      JSON.stringify(req),
      now
    );

    const updatedWallet = this.getWallet(req.creatorId);

    return {
      success: true,
      payoutId,
      deductedZar: req.amountZar,
      remainingBalanceZar: updatedWallet.balanceZar,
      status: 'processing',
    };
  }
}

// Singleton database instance
export const vhunambiDb = new VhunambiDatabase();


import { createHash, randomUUID } from 'node:crypto';
import type { Context } from 'hono';
import type { GenerationJob } from '../modules/jobs/job_types.js';
import {
  generateRefreshTokenPair,
  hashPassword,
  hashRefreshToken,
  signAccessJwt,
  verifyPassword,
} from '../security/crypto_token.js';
import { validateSovereignPassword } from '../security/password_policy.js';
import {
  normalizeVhunambiMoodId,
  type VhunambiMoodId,
} from '../utils/mood_taxonomy.js';
import {
  SupabaseCloudDriver,
  computeWalletTotalsFromLedgerRows,
  normalizeBeatLicenseRow,
  normalizeLibrarySyncRow,
  normalizeMarketplaceAssetRow,
  normalizePlaylistRow,
  normalizeSyncMutationRow,
  normalizeWalletLedgerRow,
} from './supabase_cloud_driver.js';

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
    lower === 'vhunambi_creator' ||
    lower === 'user_current' ||
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
  if (
    lower === '@kabza' ||
    lower === 'kabza' ||
    lower === 'producer_kabza' ||
    lower === 'usr_kabza'
  ) {
    return 'creator_kabza';
  }
  if (lower === '@focalistic' || lower === 'focalistic' || lower === 'usr_focalistic') {
    return 'creator_focalistic';
  }
  if (lower === '@tyla' || lower === 'tyla' || lower === 'usr_tyla') {
    return 'creator_tyla';
  }
  if (lower === '@sigwa' || lower === 'sigwa' || lower === 'usr_sigwa') {
    return 'creator_sigwa';
  }
  return trimmed;
}

export interface SovereignUserRecord {
  userId: string;
  creatorId: string;
  handle: string;
  displayName: string;
  email: string;
  role: string;
  avatarUrl: string;
  isVerified: boolean;
  createdAt: string;
}

export interface SovereignAuthSessionRecord {
  sessionId: string;
  userId: string;
  creatorId: string;
  familyId: string;
  deviceLabel: string;
  expiresAt: string;
  revoked: boolean;
  revokeReason: string | null;
  createdAt: string;
  rotatedAt: string;
}

export interface AuthTokenBundle {
  user: SovereignUserRecord;
  session: SovereignAuthSessionRecord;
  accessToken: string;
  refreshToken: string;
  expiresAt: string;
}

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
    creatorId?: string;
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

export interface NotificationRecord {
  id: string;
  userId: string;
  title: string;
  message: string;
  body: string;
  category: 'social' | 'system' | 'creatorActivity' | 'algorithmic';
  subtype: string | null;
  priority: 'low' | 'normal' | 'high' | 'urgent';
  isRead: boolean;
  targetRoute: string | null;
  targetEntityId: string | null;
  ctaLabel: string | null;
  metadata: Record<string, any>;
  createdAt: string;
}

export interface UpsertNotificationInput {
  id: string;
  userId: string;
  title: string;
  message: string;
  category?: 'social' | 'system' | 'creatorActivity' | 'algorithmic';
  subtype?: string | null;
  priority?: 'low' | 'normal' | 'high' | 'urgent';
  isRead?: boolean;
  targetRoute?: string | null;
  targetEntityId?: string | null;
  ctaLabel?: string | null;
  metadata?: Record<string, any>;
  createdAt?: string;
}

export type MediaUploadKindWire = 'audio' | 'video' | 'image';

export interface UserMediaUploadRecord {
  id: string;
  creatorId: string;
  mediaKind: MediaUploadKindWire;
  title: string;
  filename: string;
  mimeType: string;
  sizeBytes: number;
  durationMs: number | null;
  width: number | null;
  height: number | null;
  r2Key: string;
  remoteUrl: string;
  thumbnailUrl: string | null;
  sourceSurface: string;
  createdAt: string;
  deletedAt: string | null;
}

export function normalizeUserMediaUploadRow(
  raw: Record<string, unknown>,
): UserMediaUploadRecord {
  const kindRaw = String(raw.media_kind ?? raw.mediaKind ?? 'image').toLowerCase();
  const mediaKind: MediaUploadKindWire =
    kindRaw === 'audio' || kindRaw === 'video' ? kindRaw : 'image';
  return {
    id: String(raw.id ?? ''),
    creatorId: canonicalizeCreatorId(
      String(raw.creator_id ?? raw.creatorId ?? 'creator_cern'),
    ),
    mediaKind,
    title: String(raw.title ?? 'Uploaded Media'),
    filename: String(raw.filename ?? 'upload.bin'),
    mimeType: String(raw.mime_type ?? raw.mimeType ?? 'application/octet-stream'),
    sizeBytes: Math.max(1, Number(raw.size_bytes ?? raw.sizeBytes ?? 1)),
    durationMs:
      raw.duration_ms != null || raw.durationMs != null
        ? Number(raw.duration_ms ?? raw.durationMs)
        : null,
    width: raw.width != null ? Number(raw.width) : null,
    height: raw.height != null ? Number(raw.height) : null,
    r2Key: String(raw.r2_key ?? raw.r2Key ?? ''),
    remoteUrl: String(raw.remote_url ?? raw.remoteUrl ?? ''),
    thumbnailUrl:
      raw.thumbnail_url != null || raw.thumbnailUrl != null
        ? String(raw.thumbnail_url ?? raw.thumbnailUrl)
        : null,
    sourceSurface: String(raw.source_surface ?? raw.sourceSurface ?? 'vault'),
    createdAt: String(
      raw.created_at ?? raw.createdAt ?? new Date().toISOString(),
    ),
    deletedAt:
      raw.deleted_at != null || raw.deletedAt != null
        ? String(raw.deleted_at ?? raw.deletedAt)
        : null,
  };
}

export interface CreatorQuotaRecord {
  userId: string;
  planTier: string;
  freeMonthlySongsLimit: number;
  freeMonthlySongsUsed: number;
  freeMonthlySongsRemaining: number;
  cycleResetAt: string;
  updatedAt: string;
}

export interface WriteThroughFailureRecord {
  id: string;
  label: string;
  error: string;
  timestamp: string;
}

export interface AtomicQuotaConsumeResult extends CreatorQuotaRecord {
  allowed: boolean;
}

export interface SaBankMetadata {
  canonicalName: string;
  code: string;
  universalBranchCode: string;
  supportsCapitecPay: boolean;
  supportsOzow: boolean;
  supportsPayFast: boolean;
}

export type KineticReactionWire =
  | 'like'
  | 'love'
  | 'haha'
  | 'fire'
  | 'wow'
  | 'angry';

export const VALID_KINETIC_REACTIONS = new Set<KineticReactionWire>([
  'like',
  'love',
  'haha',
  'fire',
  'wow',
  'angry',
]);

export function normalizeKineticReactionWire(
  raw: unknown,
): KineticReactionWire | null {
  if (typeof raw !== 'string') return null;
  const cleaned = raw.trim().toLowerCase() as KineticReactionWire;
  return VALID_KINETIC_REACTIONS.has(cleaned) ? cleaned : null;
}

export function normalizeReactionCounts(
  raw: unknown,
): Record<KineticReactionWire, number> {
  const out: Record<KineticReactionWire, number> = {
    like: 0,
    love: 0,
    haha: 0,
    fire: 0,
    wow: 0,
    angry: 0,
  };
  let parsed: Record<string, unknown> = {};
  if (typeof raw === 'string') {
    try {
      parsed = JSON.parse(raw) as Record<string, unknown>;
    } catch {
      parsed = {};
    }
  } else if (raw && typeof raw === 'object') {
    parsed = raw as Record<string, unknown>;
  }
  for (const key of VALID_KINETIC_REACTIONS) {
    const val = Number(parsed[key] ?? 0);
    out[key] = Number.isFinite(val) && val > 0 ? Math.floor(val) : 0;
  }
  return out;
}

export function compactReactionCounts(
  counts: Record<KineticReactionWire, number>,
): Partial<Record<KineticReactionWire, number>> {
  const result: Partial<Record<KineticReactionWire, number>> = {};
  for (const key of VALID_KINETIC_REACTIONS) {
    if (counts[key] > 0) result[key] = counts[key];
  }
  return result;
}

export function sumReactionCounts(
  counts: Record<KineticReactionWire, number>,
): number {
  let total = 0;
  for (const key of VALID_KINETIC_REACTIONS) {
    total += counts[key] || 0;
  }
  return total;
}

export interface KineticReactionMutationResult {
  success: boolean;
  targetId: string;
  myReaction: KineticReactionWire | null;
  reactionCounts: Partial<Record<KineticReactionWire, number>>;
  likeCount: number;
  liked: boolean;
}

export const SA_BANK_REGISTRY: Record<string, SaBankMetadata> = {
  capitec: {
    canonicalName: 'Capitec Bank',
    code: 'CAPITEC',
    universalBranchCode: '470010',
    supportsCapitecPay: true,
    supportsOzow: true,
    supportsPayFast: true,
  },
  'capitec bank': {
    canonicalName: 'Capitec Bank',
    code: 'CAPITEC',
    universalBranchCode: '470010',
    supportsCapitecPay: true,
    supportsOzow: true,
    supportsPayFast: true,
  },
  fnb: {
    canonicalName: 'FNB',
    code: 'FNB',
    universalBranchCode: '250655',
    supportsCapitecPay: false,
    supportsOzow: true,
    supportsPayFast: true,
  },
  'first national bank': {
    canonicalName: 'FNB',
    code: 'FNB',
    universalBranchCode: '250655',
    supportsCapitecPay: false,
    supportsOzow: true,
    supportsPayFast: true,
  },
  'standard bank': {
    canonicalName: 'Standard Bank',
    code: 'SBSA',
    universalBranchCode: '051001',
    supportsCapitecPay: false,
    supportsOzow: true,
    supportsPayFast: true,
  },
  nedbank: {
    canonicalName: 'Nedbank',
    code: 'NEDBANK',
    universalBranchCode: '198765',
    supportsCapitecPay: false,
    supportsOzow: true,
    supportsPayFast: true,
  },
  absa: {
    canonicalName: 'Absa Bank',
    code: 'ABSA',
    universalBranchCode: '632005',
    supportsCapitecPay: false,
    supportsOzow: true,
    supportsPayFast: true,
  },
  'absa bank': {
    canonicalName: 'Absa Bank',
    code: 'ABSA',
    universalBranchCode: '632005',
    supportsCapitecPay: false,
    supportsOzow: true,
    supportsPayFast: true,
  },
  tymebank: {
    canonicalName: 'TymeBank',
    code: 'TYME',
    universalBranchCode: '678910',
    supportsCapitecPay: false,
    supportsOzow: true,
    supportsPayFast: true,
  },
  'tyme bank': {
    canonicalName: 'TymeBank',
    code: 'TYME',
    universalBranchCode: '678910',
    supportsCapitecPay: false,
    supportsOzow: true,
    supportsPayFast: true,
  },
};

export type PaymentRailId = 'capitec_pay' | 'ozow' | 'payfast' | 'eft';

export interface BankPayoutRequest {
  creatorId: string;
  amountZar: number;
  bankName: string;
  accountNumber: string;
  branchCode?: string;
  paymentRail?: PaymentRailId | string;
  accountHolder?: string;
}

export interface ExploreTrackRecord {
  id: string;
  title: string;
  artist: string;
  creatorName: string;
  creatorId: string;
  creatorHandle: string;
  genre: string;
  subGenre: string;
  language: string;
  province: string;
  mood: string;
  moodId: VhunambiMoodId;
  description: string;
  allowOpenStemsRemix: boolean;
  bpm: number;
  musicalKey: string;
  audioUrl: string;
  coverUrl: string;
  durationMs: number;
  likeCount: number;
  likesCount: number;
  playCount: number;
  playsCount: number;
  cosignsCount: number;
  commentsCount: number;
  sharesCount: number;
  isNew: boolean;
  trendingRank?: number;
  stemsAvailable: boolean;
  discoveryStage: 'freshCrate' | 'risingBreakout' | 'mainstage';
  trendingScore: number;
  songDna: Record<string, unknown>;
  createdAt: string;
}

export interface PlaylistRecord {
  id: string;
  creator_id: string;
  title: string;
  description: string;
  cover_image_url: string | null;
  track_ids: string[];
  is_public: boolean;
  share_code: string | null;
  share_url: string | null;
  created_at: string;
  updated_at: string;
}

interface InternalUserRow {
  userId: string;
  creatorId: string;
  handle: string;
  displayName: string;
  email: string;
  passwordHash: string;
  role: string;
  avatarUrl: string;
  isVerified: boolean;
  createdAt: string;
}

interface InternalSessionRow extends SovereignAuthSessionRecord {
  refreshTokenHash: string;
  previousTokenHash: string | null;
}

interface InternalGenerationJobEntry {
  job: GenerationJob;
  creatorId: string;
  jobKind: string;
}

interface InternalMutationLogEntry {
  seq: number;
  idempotencyKey: string;
  entityType: string;
  entityId: string;
  action: string;
  creatorId: string;
  payload: Record<string, any>;
  createdAt: string;
}

/**
 * Pure V8 Isolate persistence engine implementing the full `VhunambiDatabase`
 * contract when `node:sqlite` is unavailable (`workerd`), paired with async
 * `SupabaseCloudDriver` write-through / normalization helpers.
 */
export class EdgeIsolateDatabaseEngine {
  public static readonly DEFAULT_SEED_PASSWORD = 'VhunambiSovereign!2026';
  private static readonly PRECOMPUTED_DEFAULT_SEED_HASH =
    'scrypt$16384$8$1$7668756e616d62695f736565645f3631$019d07af66616b7e53fad54dcbe9f54bd408a3541a1ebe76b8236186a3c7a5ff3e46d2c1ac432e8c91de6c2824564d14df02413dad24040c4cfe5b08d3dac9a0';
  private static readonly PRECOMPUTED_EDGE_SEED_HASH_N1024 =
    'scrypt$1024$8$1$7668756e616d62695f736565645f3631$46240025478633eac29c8dfe3e22f42a40290ce0a444edc4ab2a67d8a6ac2b873e16373cafdfce184ddeecfde7362ab15cd8db9dbba51ae9089941ab19440b52';
  private static cachedDefaultSeedHash: string | null = null;

  public static readonly DEFAULT_SWR_TTL_MS = 12_000;
  private static readonly MAX_WRITE_THROUGH_FAILURES = 100;

  private readonly domainHydratedAtMs = new Map<string, number>();
  private readonly domainInFlightPromises = new Map<string, Promise<boolean>>();
  private readonly writeThroughFailures: WriteThroughFailureRecord[] = [];
  private coldStartHydrationPromise: Promise<void> | null = null;
  private readonly injectedDriver: SupabaseCloudDriver | null;

  private seqCounter = 0;
  private readonly creators = new Map<string, Record<string, any>>();
  private readonly usersByCreatorId = new Map<string, InternalUserRow>();
  private readonly sessions = new Map<string, InternalSessionRow>();
  private readonly walletLedger = new Map<string, Array<Record<string, any>>>();
  private readonly bankAccounts = new Map<string, Record<string, any>>();
  private readonly exploreTracks = new Map<string, Record<string, any>>();
  private readonly kineticPosts = new Map<string, Record<string, any>>();
  private readonly libraryItems = new Map<string, Record<string, any>>();
  private readonly playlists = new Map<string, Record<string, any>>();
  private readonly mutations: InternalMutationLogEntry[] = [];
  private readonly seenMutationKeys = new Set<string>();
  private readonly marketplaceAssets = new Map<string, Record<string, any>>();
  private readonly beatLicenses = new Map<string, Record<string, any>>();
  private readonly generationJobs = new Map<string, InternalGenerationJobEntry>();
  private readonly voiceClones = new Map<string, Record<string, any>>();
  private readonly soundSignatures = new Map<string, Record<string, any>>();
  private readonly payfastCheckouts = new Map<string, Record<string, any>>();
  private readonly payfastByPfId = new Map<string, string>();
  private readonly publishedClips = new Map<string, Record<string, any>>();
  private readonly reelComments = new Map<string, Record<string, any>>();
  private readonly socialInteractions = new Set<string>();
  private readonly socialInteractionReactions = new Map<string, KineticReactionWire>();
  private readonly notifications = new Map<string, NotificationRecord>();
  private readonly creatorQuotas = new Map<string, CreatorQuotaRecord>();

  constructor(injectedDriver?: SupabaseCloudDriver) {
    this.injectedDriver = injectedDriver ?? null;
    this.seedDefaults();
  }

  private resolveCloudDriver(cOrEnv?: unknown): SupabaseCloudDriver {
    if (this.injectedDriver) {
      return this.injectedDriver;
    }
    const resolvedCtx = cOrEnv ?? EdgePersistenceBridge.getActiveContext();
    return EdgePersistenceBridge.getCloudDriver(
      resolvedCtx as Context | Record<string, unknown> | undefined,
    );
  }

  public getWriteThroughFailures(): WriteThroughFailureRecord[] {
    return [...this.writeThroughFailures];
  }

  public getDomainHydratedAt(domainKey: string): number | undefined {
    return this.domainHydratedAtMs.get(domainKey);
  }

  private recordWriteThroughFailure(label: string, err: unknown): void {
    const message = err instanceof Error ? err.message : String(err);
    const entry: WriteThroughFailureRecord = {
      id: `wtf_${Date.now()}_${this.writeThroughFailures.length + 1}`,
      label,
      error: message,
      timestamp: new Date().toISOString(),
    };
    this.writeThroughFailures.push(entry);
    if (
      this.writeThroughFailures.length >
      EdgeIsolateDatabaseEngine.MAX_WRITE_THROUGH_FAILURES
    ) {
      this.writeThroughFailures.splice(
        0,
        this.writeThroughFailures.length -
        EdgeIsolateDatabaseEngine.MAX_WRITE_THROUGH_FAILURES,
      );
    }
    console.error(`[EdgeWriteThroughError] label=${label} error=${message}`);
  }

  private static getDefaultSeedPasswordHash(): string {
    if (!EdgeIsolateDatabaseEngine.cachedDefaultSeedHash) {
      const g = globalThis as unknown as {
        navigator?: { userAgent?: string };
        WebSocketPair?: unknown;
      };
      const isWorker =
        g.navigator?.userAgent === 'Cloudflare-Workers' ||
        typeof g.WebSocketPair === 'function';
      EdgeIsolateDatabaseEngine.cachedDefaultSeedHash = isWorker
        ? EdgeIsolateDatabaseEngine.PRECOMPUTED_EDGE_SEED_HASH_N1024
        : EdgeIsolateDatabaseEngine.PRECOMPUTED_DEFAULT_SEED_HASH;
    }
    return EdgeIsolateDatabaseEngine.cachedDefaultSeedHash;
  }

  private static normalizeHandle(rawHandle: string): string {
    const cleaned = rawHandle.trim().toLowerCase().replace(/^@+/, '');
    return `@${cleaned.replace(/[^a-z0-9_.-]/g, '')}`;
  }

  public resetForTesting(): void {
    this.domainHydratedAtMs.clear();
    this.domainInFlightPromises.clear();
    this.writeThroughFailures.length = 0;
    this.coldStartHydrationPromise = null;
    this.seqCounter = 0;
    this.creators.clear();
    this.usersByCreatorId.clear();
    this.sessions.clear();
    this.walletLedger.clear();
    this.bankAccounts.clear();
    this.exploreTracks.clear();
    this.kineticPosts.clear();
    this.libraryItems.clear();
    this.playlists.clear();
    this.mutations.length = 0;
    this.seenMutationKeys.clear();
    this.marketplaceAssets.clear();
    this.beatLicenses.clear();
    this.generationJobs.clear();
    this.voiceClones.clear();
    this.soundSignatures.clear();
    this.payfastCheckouts.clear();
    this.payfastByPfId.clear();
    this.publishedClips.clear();
    this.reelComments.clear();
    this.socialInteractions.clear();
    this.socialInteractionReactions.clear();
    this.notifications.clear();
    this.creatorQuotas.clear();
    this.userMediaUploads.clear();
    this.seedDefaults();
  }

  private static async withTimeout<T>(
    promise: Promise<T>,
    timeoutMs: number,
    fallback: T,
  ): Promise<T> {
    let timer: ReturnType<typeof setTimeout> | undefined;
    try {
      return await Promise.race([
        promise,
        new Promise<T>((resolve) => {
          timer = setTimeout(() => resolve(fallback), timeoutMs);
        }),
      ]);
    } finally {
      if (timer !== undefined) clearTimeout(timer);
    }
  }

  private static async withTimeoutResult<T>(
    promise: Promise<T>,
    timeoutMs: number,
  ): Promise<
    { ok: true; value: T } | { ok: false; timedOut: boolean; error?: unknown }
  > {
    let timer: ReturnType<typeof setTimeout> | undefined;
    try {
      const result = await Promise.race([
        promise.then(
          (value) => ({ ok: true as const, value }),
          (error) => ({ ok: false as const, timedOut: false, error }),
        ),
        new Promise<{ ok: false; timedOut: true }>((resolve) => {
          timer = setTimeout(() => resolve({ ok: false, timedOut: true }), timeoutMs);
        }),
      ]);
      return result;
    } finally {
      if (timer !== undefined) clearTimeout(timer);
    }
  }

  private mirrorWriteThrough(
    opOrLabel: string | ((driver: SupabaseCloudDriver) => Promise<unknown>),
    maybeOp?: (driver: SupabaseCloudDriver) => Promise<unknown>,
  ): void {
    const label = typeof opOrLabel === 'string' ? opOrLabel : 'anonymous_write_through';
    const op = typeof opOrLabel === 'function' ? opOrLabel : maybeOp;
    if (!op) return;

    const activeCtx = EdgePersistenceBridge.getActiveContext();
    const driver = this.resolveCloudDriver(activeCtx);
    if (!driver.isConfigured()) return;

    const task = Promise.resolve()
      .then(() => op(driver))
      .catch((err) => {
        this.recordWriteThroughFailure(label, err);
      });

    try {
      const maybeExecCtx = (activeCtx as Context | undefined)?.executionCtx;
      if (maybeExecCtx && typeof maybeExecCtx.waitUntil === 'function') {
        maybeExecCtx.waitUntil(task);
      }
    } catch {
      // Hono executionCtx getter throws outside Cloudflare Workers runtime
    }
  }

  public async awaitWriteThrough(
    label: string,
    op: (driver: SupabaseCloudDriver) => Promise<unknown>,
    cOrEnv?: unknown,
  ): Promise<boolean> {
    const driver = this.resolveCloudDriver(cOrEnv);
    if (!driver.isConfigured()) return false;
    try {
      await op(driver);
      return true;
    } catch (err) {
      this.recordWriteThroughFailure(label, err);
      return false;
    }
  }

  private async ensureCreatorRowInSupabase(
    driver: SupabaseCloudDriver,
    rawCreatorId: string,
  ): Promise<void> {
    const cid = canonicalizeCreatorId(rawCreatorId);
    const local = this.creators.get(cid) ?? this.creators.get(rawCreatorId);
    const handle = String(
      local?.handle ?? `@${cid.replace(/^creator_/, '')}`,
    );
    await driver
      .upsertRow(
        'creators',
        {
          id: cid,
          handle,
          display_name: String(
            local?.displayName ?? handle.slice(1).toUpperCase(),
          ),
          avatar_url: String(
            local?.avatarUrl ??
            `https://api.dicebear.com/7.x/avataaars/svg?seed=${encodeURIComponent(cid)}`,
          ),
          archetype: String(local?.archetype ?? 'Producer'),
          tier: String(local?.tier ?? 'verified'),
          is_verified: String(local?.tier ?? 'verified') !== 'unverified',
          updated_at: Date.now(),
        },
        'id',
      )
      .catch(() => {
        // Best-effort creator FK assurance
      });
  }

  public async ensureColdStartHydrated(cOrEnv?: unknown): Promise<void> {
    if (this.domainHydratedAtMs.has('cold_start:core')) return;
    if (this.coldStartHydrationPromise) return this.coldStartHydrationPromise;

    const driver = this.resolveCloudDriver(cOrEnv);
    if (!driver.isConfigured()) {
      return;
    }

    const hydrateTask = (async () => {
      try {
        const res = await EdgeIsolateDatabaseEngine.withTimeoutResult(
          Promise.all([
            driver.selectRows<Record<string, any>>('creators', 'select=*&limit=300'),
            driver.selectRows<Record<string, any>>('users', 'select=*&limit=300'),
            driver.selectRows<Record<string, any>>('auth_sessions', 'select=*&revoked=eq.false&order=rotated_at.desc&limit=300'),
            driver.selectRows<Record<string, any>>('explore_tracks', 'select=*&limit=200'),
            driver.selectRows<Record<string, any>>('kinetic_posts', 'select=*&order=created_at.desc&limit=200'),
            driver.selectRows<Record<string, any>>('published_clips', 'select=*&order=created_at.desc&limit=200'),
            driver.selectRows<Record<string, any>>('reel_comments', 'select=*&order=timestamp_ms.desc&limit=400'),
            driver.selectRows<Record<string, any>>('marketplace_assets', 'select=*&limit=200'),
            driver.selectRows<Record<string, any>>('beat_licenses', 'select=*&order=purchased_at.desc&limit=300'),
            driver.selectRows<Record<string, any>>('sound_signatures', 'select=*&limit=200'),
            driver.selectRows<Record<string, any>>('user_library_sync', 'select=*&limit=500'),
            driver.selectRows<Record<string, any>>('playlists', 'select=*&limit=200'),
            driver.selectRows<Record<string, any>>('generation_jobs', 'select=*&order=updated_at.desc&limit=200'),
            driver.selectRows<Record<string, any>>('voice_clones', 'select=*&limit=200'),
            driver.selectRows<Record<string, any>>('social_interactions', 'select=*&limit=1000'),
            driver.selectRows<Record<string, any>>('wallet_ledger', 'select=*&order=created_at.desc&limit=500'),
            driver.selectRows<Record<string, any>>('bank_accounts', 'select=*&limit=200'),
            driver.selectRows<Record<string, any>>('payment_topups', 'select=*&order=created_at.desc&limit=300'),
            driver.selectRows<Record<string, any>>('sync_mutation_log', 'select=*&order=seq.asc&limit=300'),
            driver.selectRows<Record<string, any>>('notifications', 'select=*&order=created_at.desc&limit=500'),
            driver.selectRows<Record<string, any>>('creator_quotas', 'select=*&limit=300'),
          ]),
          4500,
        );
        if (!res.ok) {
          return;
        }
        const [
          creatorsRows,
          usersRows,
          sessionsRows,
          exploreRows,
          postsRows,
          clipsRows,
          commentsRows,
          assetsRows,
          licensesRows,
          signaturesRows,
          libraryRows,
          playlistRows,
          jobRows,
          voiceRows,
          socialRows,
          walletRows,
          bankRows,
          topupRows,
          mutationRows,
          notificationRows,
          quotaRows,
        ] = res.value;

        for (const cr of creatorsRows) {
          const cid = canonicalizeCreatorId(String(cr.id ?? ''));
          if (!cid) continue;
          const existing = this.creators.get(cid);
          this.creators.set(cid, {
            ...(existing ?? {}),
            id: cid,
            handle: String(cr.handle ?? existing?.handle ?? `@${cid.replace(/^creator_/, '')}`),
            displayName: String(cr.display_name ?? existing?.displayName ?? cid),
            avatarUrl: String(cr.avatar_url ?? existing?.avatarUrl ?? ''),
            archetype: String(cr.archetype ?? existing?.archetype ?? 'Producer'),
            tier: String(cr.tier ?? existing?.tier ?? 'verified'),
            reputationScore: Number(cr.reputation_score ?? existing?.reputationScore ?? 100),
            createdAt: String(cr.created_at ?? existing?.createdAt ?? new Date().toISOString()),
            updatedAt: new Date(Number(cr.updated_at || Date.now())).toISOString(),
          });
        }

        for (const u of usersRows) {
          const cid = canonicalizeCreatorId(String(u.creator_id ?? u.user_id ?? ''));
          if (!cid) continue;
          const creator = this.creators.get(cid);
          this.hydrateExternalUser({
            userId: String(u.user_id ?? `usr_${cid}`),
            creatorId: cid,
            handle: String(u.handle ?? creator?.handle ?? `@${cid.replace(/^creator_/, '')}`),
            displayName: creator?.displayName ? String(creator.displayName) : undefined,
            email: String(u.email ?? `${cid}@vhunambi.co.za`),
            passwordHash: String(u.password_hash ?? 'GOTRUE_MANAGED'),
            role: String(u.role ?? 'creator'),
            avatarUrl: creator?.avatarUrl ? String(creator.avatarUrl) : undefined,
            isVerified: creator?.tier !== 'unverified',
            createdAt: u.created_at ? String(u.created_at) : undefined,
          });
        }

        for (const s of sessionsRows) {
          if (!s.session_id) continue;
          this.hydrateExternalSession({
            sessionId: String(s.session_id),
            userId: String(s.user_id ?? ''),
            creatorId: String(s.creator_id ?? 'creator_cern'),
            familyId: String(s.family_id ?? s.session_id),
            refreshTokenHash: String(s.refresh_token_hash ?? ''),
            previousTokenHash: s.previous_token_hash ? String(s.previous_token_hash) : null,
            deviceLabel: String(s.device_label ?? 'vhunambi_client'),
            expiresAt: String(s.expires_at ?? new Date().toISOString()),
            revoked: Boolean(s.revoked),
            revokeReason: s.revoke_reason ? String(s.revoke_reason) : null,
            createdAt: s.created_at ? String(s.created_at) : undefined,
            rotatedAt: s.rotated_at ? String(s.rotated_at) : undefined,
          });
        }

        this.hydrateExploreTrackRows(exploreRows);
        this.hydrateKineticPostRows(postsRows);
        this.hydratePublishedClipRows(clipsRows);
        this.hydrateReelCommentRows(commentsRows);

        this.hydrateMarketplaceAssetRows(assetsRows);
        this.hydrateBeatLicenseRows(licensesRows);
        this.hydrateSoundSignatureRows(signaturesRows);
        this.hydrateLibraryRows(libraryRows);
        this.hydratePlaylistRows(playlistRows);

        for (const gj of jobRows) {
          if (!gj.generation_id) continue;
          const genId = String(gj.generation_id);
          const existing = this.generationJobs.get(genId);
          const job = this.mapSupabaseGenerationJobRow(gj, existing?.job);
          this.generationJobs.set(job.generationId, {
            job,
            creatorId: canonicalizeCreatorId(String(gj.creator_id ?? existing?.creatorId ?? 'creator_cern')),
            jobKind: String(gj.job_kind ?? existing?.jobKind ?? 'audio_synthesis'),
          });
        }

        this.hydrateVoiceCloneRows(voiceRows);
        this.hydrateSocialInteractionRows(socialRows);

        const groupedWallet = new Map<string, Array<Record<string, any>>>();
        for (const wl of walletRows) {
          if (!wl.id || !wl.creator_id) continue;
          const cid = canonicalizeCreatorId(String(wl.creator_id));
          const list = groupedWallet.get(cid) ?? [];
          const metaStr =
            typeof wl.metadata_json === 'string'
              ? wl.metadata_json
              : JSON.stringify(wl.metadata_json ?? {});
          list.push({
            id: String(wl.id),
            creator_id: cid,
            type: String(wl.type ?? 'topup'),
            amount_zar: Number(wl.amount_zar ?? 0),
            amount_coins: Number(wl.amount_coins ?? 0),
            status: String(wl.status ?? 'completed'),
            reference: String(wl.reference ?? ''),
            data_json: metaStr,
            created_at: String(wl.created_at ?? new Date().toISOString()),
          });
          groupedWallet.set(cid, list);
        }
        for (const [cid, pgList] of groupedWallet.entries()) {
          const existingList = this.walletLedger.get(cid) ?? [];
          const seenIds = new Set(pgList.map((r) => String(r.id)));
          const merged = [
            ...pgList,
            ...existingList.filter((r) => !seenIds.has(String(r.id))),
          ];
          this.walletLedger.set(cid, merged);
        }

        for (const ba of bankRows) {
          if (!ba.id) continue;
          this.bankAccounts.set(String(ba.id), {
            id: String(ba.id),
            creatorId: canonicalizeCreatorId(String(ba.creator_id ?? 'creator_cern')),
            bankName: String(ba.bank_name ?? ''),
            branchCode: String(ba.branch_code ?? ''),
            maskedAccount: String(ba.account_number_masked ?? ''),
            paymentRail: String(ba.payout_rail ?? 'payfast'),
            accountHolder: ba.account_holder ? String(ba.account_holder) : null,
            updatedAt: String(ba.updated_at ?? new Date().toISOString()),
          });
        }

        for (const pt of topupRows) {
          if (!pt.checkout_id) continue;
          const cid = canonicalizeCreatorId(String(pt.creator_id ?? 'creator_cern'));
          this.payfastCheckouts.set(String(pt.checkout_id), {
            checkoutId: String(pt.checkout_id),
            creatorId: cid,
            provider: String(pt.provider ?? 'payfast'),
            providerPaymentId: pt.provider_payment_id ? String(pt.provider_payment_id) : null,
            packId: String(pt.pack_id ?? 'pack_producer_1500'),
            amountZar: Number(pt.amount_zar ?? 0),
            coinsGranted: Number(pt.coins_granted ?? 0),
            status: String(pt.status ?? 'pending'),
            signatureMd5: String(pt.signature_md5 ?? ''),
            verifiedAt: pt.verified_at ? String(pt.verified_at) : null,
            createdAt: String(pt.created_at ?? new Date().toISOString()),
          });
          if (pt.provider_payment_id) {
            this.payfastByPfId.set(String(pt.provider_payment_id), String(pt.checkout_id));
          }
        }

        for (const mut of mutationRows) {
          const norm = normalizeSyncMutationRow(mut);
          const key = String(norm.idempotencyKey || '');
          const seqNum = Number(norm.seq ?? 0);
          if (!key || this.seenMutationKeys.has(key)) continue;
          this.seenMutationKeys.add(key);
          this.seqCounter = Math.max(this.seqCounter, seqNum);
          this.mutations.push({
            seq: seqNum || this.seqCounter,
            idempotencyKey: key,
            entityType: String(norm.entityType ?? ''),
            entityId: String(norm.entityId ?? ''),
            action: String(norm.action ?? 'upsert'),
            creatorId: String(norm.creatorId ?? 'system'),
            payload: (norm.payload as Record<string, any>) ?? {},
            createdAt: String(norm.createdAt ?? new Date().toISOString()),
          });
        }

        this.hydrateNotificationRows(notificationRows);
        this.hydrateCreatorQuotaRows(quotaRows);

        const nowMs = Date.now();
        this.domainHydratedAtMs.set('cold_start:core', nowMs);
        this.domainHydratedAtMs.set('explore:global', nowMs);
      } finally {
        this.coldStartHydrationPromise = null;
      }
    })();

    this.coldStartHydrationPromise = hydrateTask;
    return hydrateTask;
  }

  private hydrateExploreTrackRows(exploreRows: Array<Record<string, any>>): void {
    for (const t of exploreRows) {
      if (!t.id) continue;
      const updatedIso = new Date(Number(t.updated_at || Date.now())).toISOString();
      const createdIso = new Date(
        Number(t.created_at || t.updated_at || Date.now()),
      ).toISOString();
      const stems =
        t.stems_json && typeof t.stems_json === 'object' ? t.stems_json : {};
      const parsedData =
        t.data_json && typeof t.data_json === 'object'
          ? (t.data_json as Record<string, any>)
          : {};
      const normalizedMoodId = normalizeVhunambiMoodId(
        t.mood_id ?? parsedData.moodId ?? t.mood ?? parsedData.mood,
      );
      const description = String(t.description ?? parsedData.description ?? '');
      const allowOpenStemsRemix = Boolean(
        t.allow_open_stems_remix ??
        parsedData.allowOpenStemsRemix ??
        Object.keys(stems).length > 0,
      );
      const playsCount = Number(t.plays_count ?? parsedData.playCount ?? 0);
      const discoveryStage = String(
        t.discovery_stage ??
        parsedData.discoveryStage ??
        (playsCount >= 8000
          ? 'mainstage'
          : playsCount >= 1500
            ? 'risingBreakout'
            : 'freshCrate'),
      );
      const moodLabel = String(t.mood ?? parsedData.mood ?? 'Vibrant');
      const languageLabel = String(t.language ?? parsedData.language ?? 'isiZulu');

      this.exploreTracks.set(String(t.id), {
        id: String(t.id),
        title: String(t.title ?? 'Untitled Track'),
        artist_name: String(t.artist ?? 'Vhunambi Creator'),
        artist_id: canonicalizeCreatorId(String(t.creator_id ?? 'creator_cern')),
        genre: String(t.genre ?? 'Amapiano'),
        language: languageLabel,
        audio_url: String(t.audio_url ?? ''),
        bpm: Number(t.bpm ?? 113),
        play_count: playsCount,
        like_count: Number(t.likes_count ?? parsedData.likeCount ?? 0),
        cosign_count: Number(t.cosigns_count ?? parsedData.cosignCount ?? 0),
        discovery_stage: discoveryStage,
        mood_id: normalizedMoodId,
        description,
        allow_open_stems_remix: allowOpenStemsRemix ? 1 : 0,
        data_json: JSON.stringify({
          ...parsedData,
          subGenre: t.sub_genre ?? parsedData.subGenre ?? '',
          province: t.region ?? parsedData.province ?? 'South Africa',
          mood: moodLabel,
          moodId: normalizedMoodId,
          language: languageLabel,
          description,
          allowOpenStemsRemix,
          musicalKey: t.musical_key ?? parsedData.musicalKey ?? 'Am',
          coverUrl: t.cover_url ?? parsedData.coverUrl ?? '',
          durationMs: Number(t.duration_sec ?? 180) * 1000,
          stemsAvailable: Object.keys(stems).length > 0,
          isNew: Boolean(t.is_featured ?? parsedData.isNew ?? false),
        }),
        created_at: createdIso,
        updated_at: updatedIso,
      });
    }
  }

  private hydrateSocialInteractionRows(rows: Array<Record<string, any>>): void {
    for (const row of rows) {
      const interactionType = String(row.interaction_type ?? '').trim();
      const targetId = String(row.target_id ?? '').trim();
      const actor = canonicalizeCreatorId(
        String(row.actor_creator_id ?? 'creator_cern'),
      );
      if (!interactionType || !targetId) continue;
      const key = `${interactionType}::${targetId}::${actor}`;
      this.socialInteractions.add(key);
      const rx = normalizeKineticReactionWire(row.reaction_type);
      if (rx) {
        this.socialInteractionReactions.set(key, rx);
      }
    }
  }

  private hydratePublishedClipRows(clipsRows: Array<Record<string, any>>): void {
    for (const pc of clipsRows) {
      if (!pc.id) continue;
      const parsedData =
        pc.data_json && typeof pc.data_json === 'object'
          ? (pc.data_json as Record<string, any>)
          : this.parseJsonField(pc.data_json);
      const createdMs = Number(pc.created_at);
      const updatedMs = Number(pc.updated_at);
      const createdIso = Number.isFinite(createdMs) && createdMs > 0
        ? new Date(createdMs).toISOString()
        : String(pc.created_at || parsedData.publishedAt || new Date().toISOString());
      const updatedIso = Number.isFinite(updatedMs) && updatedMs > 0
        ? new Date(updatedMs).toISOString()
        : String(pc.updated_at || createdIso);
      const cid = canonicalizeCreatorId(String(pc.creator_id ?? 'creator_cern'));
      const reactionCounts = compactReactionCounts(
        normalizeReactionCounts(pc.reaction_counts_json ?? parsedData.reactionCounts),
      );
      const videoUrl =
        typeof pc.video_url === 'string' && pc.video_url.trim().length > 0
          ? pc.video_url.trim()
          : (typeof parsedData.videoUrl === 'string' && parsedData.videoUrl.trim().length > 0
            ? parsedData.videoUrl.trim()
            : null);
      const mediaKind = String(pc.media_kind ?? parsedData.mediaKind ?? 'artwork');
      const audioStartMs = Number(pc.audio_start_ms ?? parsedData.audioStartMs ?? 0);
      const audioEndMs = Number(pc.audio_end_ms ?? parsedData.audioEndMs ?? 30000);
      const effectPreset = String(pc.effect_preset ?? parsedData.effectPreset ?? 'kinetic_gold');
      const effectIntensity = Number(pc.effect_intensity ?? parsedData.effectIntensity ?? 0.65);
      const typographyPreset = String(
        pc.typography_preset ?? parsedData.typographyPreset ?? 'kinetic_bounce',
      );
      const speedRate = Number(pc.speed_rate ?? parsedData.speedRate ?? 1.0);
      const stickerId =
        typeof pc.sticker_id === 'string' && pc.sticker_id.trim().length > 0
          ? pc.sticker_id.trim()
          : (typeof parsedData.stickerId === 'string' && parsedData.stickerId.trim().length > 0
            ? parsedData.stickerId.trim()
            : null);

      const mergedPayload = {
        ...parsedData,
        id: String(pc.id),
        trackId: pc.track_id ?? parsedData.trackId ?? String(pc.id),
        creatorId: cid,
        creatorUsername: String(
          parsedData.creatorUsername ?? `@${cid.replace(/^creator_/, '')}`,
        ),
        title: String(parsedData.title ?? pc.title ?? 'Untitled Clip'),
        genre: String(pc.genre ?? parsedData.genre ?? 'Amapiano'),
        audioUrl: String(pc.audio_url ?? parsedData.audioUrl ?? ''),
        coverUrl: String(pc.cover_url ?? parsedData.coverUrl ?? ''),
        videoUrl,
        mediaKind,
        audioStartMs,
        audioEndMs,
        effectPreset,
        effectIntensity,
        typographyPreset,
        speedRate,
        stickerId,
        reactionCounts,
        likeCount: Number(pc.likes_count ?? parsedData.likeCount ?? 0),
        commentCount: Number(pc.comments_count ?? parsedData.commentCount ?? 0),
        remixCount: Number(pc.remixes_count ?? parsedData.remixCount ?? 0),
        publishedAt: String(parsedData.publishedAt ?? createdIso),
      };

      this.publishedClips.set(String(pc.id), {
        id: String(pc.id),
        creator_id: cid,
        creator_handle: mergedPayload.creatorUsername,
        video_url: videoUrl ?? mergedPayload.audioUrl ?? '',
        audio_title: mergedPayload.title,
        bantu_language: mergedPayload.genre,
        views_count: Number(parsedData.playCount ?? pc.views_count ?? 0),
        likes_count: mergedPayload.likeCount,
        comments_count: mergedPayload.commentCount,
        remixes_count: mergedPayload.remixCount,
        remixed_from_clip_id: pc.remixed_from_clip_id
          ? String(pc.remixed_from_clip_id)
          : null,
        reaction_counts_json: JSON.stringify(reactionCounts),
        data_json: JSON.stringify(mergedPayload),
        created_at: createdIso,
        updated_at: updatedIso,
      });
    }
  }

  private hydrateKineticPostRows(postsRows: Array<Record<string, any>>): void {
    for (const kp of postsRows) {
      if (!kp.id) continue;
      const dataObj =
        kp.data_json && typeof kp.data_json === 'object'
          ? (kp.data_json as Record<string, any>)
          : {};
      const reactionCounts = compactReactionCounts(
        normalizeReactionCounts(
          kp.reaction_counts_json ?? dataObj.reactionCounts,
        ),
      );
      this.kineticPosts.set(String(kp.id), {
        id: String(kp.id),
        creator_id: String(kp.creator_id ?? 'creator_cern'),
        creator_handle: String(kp.creator_handle ?? '@cern'),
        creator_name: String(kp.creator_name ?? 'Cern'),
        caption: String(kp.caption ?? ''),
        media_type: String(dataObj.mediaType ?? 'audio_card'),
        like_count: Number(kp.like_count ?? dataObj.likeCount ?? 0),
        comment_count: Number(kp.comment_count ?? dataObj.commentCount ?? 0),
        cosign_count: Number(kp.cosign_count ?? 0),
        cosign_target: Number(dataObj.cosignTarget ?? 25),
        repost_count: Number(kp.repost_count ?? 0),
        reaction_counts_json: JSON.stringify(reactionCounts),
        discovery_stage: String(kp.discovery_stage ?? 'freshCrate'),
        data_json:
          typeof kp.data_json === 'string'
            ? kp.data_json
            : JSON.stringify({
              ...dataObj,
              reactionCounts,
            }),
        created_at: new Date(Number(kp.created_at || Date.now())).toISOString(),
        updated_at: new Date(Number(kp.updated_at || Date.now())).toISOString(),
      });
    }
  }

  private hydrateReelCommentRows(commentsRows: Array<Record<string, any>>): void {
    for (const rc of commentsRows) {
      if (!rc.id) continue;
      const parsed =
        rc.data_json && typeof rc.data_json === 'object'
          ? (rc.data_json as Record<string, any>)
          : {};
      const createdIso = new Date(Number(rc.timestamp_ms || Date.now())).toISOString();
      const parentCommentId = rc.parent_comment_id ?? parsed.parentCommentId ?? null;
      const replyToHandle = rc.reply_to_handle ?? parsed.replyToHandle ?? null;
      const likesCount = Number(rc.likes_count ?? parsed.likeCount ?? 0);
      const userId = String(rc.user_id ?? parsed.userId ?? 'creator_cern');
      const username = String(
        rc.username ?? parsed.username ?? `@${userId.replace(/^creator_/, '')}`,
      );
      const displayName = String(
        rc.display_name ?? parsed.displayName ?? parsed.creatorName ?? 'Creator',
      );
      const avatarUrl = String(rc.avatar_url ?? parsed.avatarUrl ?? '');
      const isCreator = Boolean(rc.is_creator ?? parsed.isCreator ?? false);
      const reactionCounts = compactReactionCounts(
        normalizeReactionCounts(rc.reaction_counts_json ?? parsed.reactionCounts),
      );
      const gifUrl =
        (rc.gif_url ?? parsed.gifUrl)
          ? String(rc.gif_url ?? parsed.gifUrl)
          : undefined;
      const stickerId =
        (rc.sticker_id ?? parsed.stickerId)
          ? String(rc.sticker_id ?? parsed.stickerId)
          : undefined;
      const mediaAspectRatioRaw =
        rc.media_aspect_ratio ?? parsed.mediaAspectRatio;
      const mediaAspectRatio =
        typeof mediaAspectRatioRaw === 'number' &&
          Number.isFinite(mediaAspectRatioRaw)
          ? mediaAspectRatioRaw
          : undefined;

      this.reelComments.set(String(rc.id), {
        id: String(rc.id),
        reel_id: String(rc.clip_id),
        creator_id: userId,
        username,
        display_name: displayName,
        avatar_url: avatarUrl,
        is_creator: isCreator,
        likes_count: likesCount,
        content: String(rc.text ?? ''),
        language_code: parsed.languageCode ? String(parsed.languageCode) : null,
        parent_comment_id: parentCommentId,
        reply_to_handle: replyToHandle,
        reaction_counts_json: JSON.stringify(reactionCounts),
        gif_url: gifUrl ?? null,
        sticker_id: stickerId ?? null,
        media_aspect_ratio: mediaAspectRatio ?? null,
        data_json: JSON.stringify({
          ...parsed,
          id: String(rc.id),
          clipId: String(rc.clip_id),
          userId,
          username,
          displayName,
          avatarUrl,
          isCreator,
          text: String(rc.text ?? ''),
          likeCount: likesCount,
          reactionCounts,
          ...(gifUrl ? { gifUrl } : {}),
          ...(stickerId ? { stickerId } : {}),
          ...(mediaAspectRatio ? { mediaAspectRatio } : {}),
          userReelLoves: Number(rc.user_reel_loves ?? parsed.userReelLoves ?? 0),
          ...(rc.gift_emoji ? { giftEmoji: String(rc.gift_emoji) } : {}),
          ...(rc.gift_name ? { giftName: String(rc.gift_name) } : {}),
          ...(parentCommentId ? { parentCommentId: String(parentCommentId) } : {}),
          ...(replyToHandle ? { replyToHandle: String(replyToHandle) } : {}),
          createdAt: parsed.createdAt ?? createdIso,
        }),
        created_at: createdIso,
      });
    }
  }

  private hydrateNotificationRows(notificationRows: Array<Record<string, any>>): void {
    for (const nr of notificationRows) {
      if (!nr.id) continue;
      const id = String(nr.id);
      const cid = canonicalizeCreatorId(String(nr.user_id ?? 'creator_cern'));
      const metaObj =
        nr.metadata_json && typeof nr.metadata_json === 'object'
          ? (nr.metadata_json as Record<string, any>)
          : {};
      this.notifications.set(id, {
        id,
        userId: cid,
        title: String(nr.title ?? 'Notification'),
        message: String(nr.body ?? nr.message ?? ''),
        body: String(nr.body ?? nr.message ?? ''),
        category: (nr.category as NotificationRecord['category']) ?? 'creatorActivity',
        subtype: nr.subtype ? String(nr.subtype) : null,
        priority: (nr.priority as NotificationRecord['priority']) ?? 'normal',
        isRead: Boolean(nr.is_read),
        targetRoute: nr.target_route ? String(nr.target_route) : null,
        targetEntityId: nr.target_entity_id ? String(nr.target_entity_id) : null,
        ctaLabel: nr.cta_label ? String(nr.cta_label) : null,
        metadata: metaObj,
        createdAt: String(nr.created_at ?? new Date().toISOString()),
      });
    }
  }

  private hydrateCreatorQuotaRows(quotaRows: Array<Record<string, any>>): void {
    for (const qr of quotaRows) {
      if (!qr.user_id) continue;
      const cid = canonicalizeCreatorId(String(qr.user_id));
      const limit = Number(qr.free_monthly_songs_limit ?? 10);
      const used = Number(qr.free_monthly_songs_used ?? 0);
      this.creatorQuotas.set(cid, {
        userId: cid,
        planTier: String(qr.plan_tier ?? 'free'),
        freeMonthlySongsLimit: limit,
        freeMonthlySongsUsed: used,
        freeMonthlySongsRemaining: Math.max(0, limit - used),
        cycleResetAt: String(
          qr.cycle_reset_at ??
          new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
        ),
        updatedAt: String(qr.updated_at ?? new Date().toISOString()),
      });
    }
  }

  public async syncNotificationsFromCloud(
    userId: string,
    cOrEnv?: unknown,
  ): Promise<NotificationRecord[]> {
    const cid = canonicalizeCreatorId(userId);
    const driver = this.resolveCloudDriver(cOrEnv);
    if (!driver.isConfigured()) {
      return this.listNotifications(cid);
    }
    const domainKey = `notifications:${cid}`;
    const res = await EdgeIsolateDatabaseEngine.withTimeoutResult(
      driver.selectRows<Record<string, any>>(
        'notifications',
        `select=*&user_id=eq.${encodeURIComponent(cid)}&order=created_at.desc&limit=500`,
      ),
      3500,
    );
    if (res.ok) {
      this.hydrateNotificationRows(res.value);
      this.domainHydratedAtMs.set(domainKey, Date.now());
    }
    return this.listNotifications(cid);
  }

  public async syncCreatorQuotaFromCloud(
    userId: string,
    cOrEnv?: unknown,
  ): Promise<CreatorQuotaRecord> {
    const cid = canonicalizeCreatorId(userId);
    const driver = this.resolveCloudDriver(cOrEnv);
    if (!driver.isConfigured()) {
      return this.getCreatorQuota(cid);
    }
    const domainKey = `quota:${cid}`;
    const res = await EdgeIsolateDatabaseEngine.withTimeoutResult(
      driver.selectRows<Record<string, any>>(
        'creator_quotas',
        `select=*&user_id=eq.${encodeURIComponent(cid)}&limit=1`,
      ),
      3000,
    );
    if (res.ok) {
      this.hydrateCreatorQuotaRows(res.value);
      this.domainHydratedAtMs.set(domainKey, Date.now());
    }
    return this.getCreatorQuota(cid);
  }

  public async syncGenerationJobFromCloud(
    genId: string,
    cOrEnv?: unknown,
  ): Promise<GenerationJob | null> {
    const driver = this.resolveCloudDriver(cOrEnv);
    if (!driver.isConfigured()) {
      return this.getGenerationJob(genId);
    }
    const domainKey = `generation:${genId}`;
    const res = await EdgeIsolateDatabaseEngine.withTimeoutResult(
      driver.selectRows<Record<string, any>>(
        'generation_jobs',
        `select=*&generation_id=eq.${encodeURIComponent(genId)}&limit=1`,
      ),
      3000,
    );
    if (res.ok) {
      this.domainHydratedAtMs.set(domainKey, Date.now());
      const gj = res.value[0];
      if (gj && gj.generation_id) {
        const existing = this.generationJobs.get(genId);
        const remoteStatus = String(gj.status ?? 'queued');
        const remoteUpdatedMs = Number(gj.updated_at || 0);
        const existingUpdatedMs = existing?.job.updatedAt.getTime() ?? 0;
        if (
          !existing ||
          (remoteStatus === 'succeeded' && existing.job.status !== 'succeeded') ||
          (remoteStatus === 'failed' && existing.job.status !== 'failed') ||
          remoteUpdatedMs >= existingUpdatedMs
        ) {
          const mapped = this.mapSupabaseGenerationJobRow(gj, existing?.job);
          this.generationJobs.set(mapped.generationId, {
            job: mapped,
            creatorId: canonicalizeCreatorId(
              String(gj.creator_id ?? existing?.creatorId ?? 'creator_cern'),
            ),
            jobKind: String(gj.job_kind ?? existing?.jobKind ?? 'audio_synthesis'),
          });
          return mapped;
        }
      }
    }
    return this.getGenerationJob(genId);
  }

  public async syncExploreFromCloud(
    force = false,
    cOrEnv?: unknown,
  ): Promise<boolean> {
    const driver = this.resolveCloudDriver(cOrEnv);
    if (!driver.isConfigured()) return false;

    const domainKey = 'explore:global';
    const lastHydrated = this.domainHydratedAtMs.get(domainKey) ?? 0;
    if (
      !force &&
      lastHydrated > 0 &&
      Date.now() - lastHydrated < EdgeIsolateDatabaseEngine.DEFAULT_SWR_TTL_MS
    ) {
      return true;
    }

    const existingFlight = this.domainInFlightPromises.get(domainKey);
    if (existingFlight && !force) {
      return existingFlight;
    }

    const syncPromise = (async (): Promise<boolean> => {
      const [tracksRes, postsRes, commentsRes, interactionsRes] =
        await Promise.all([
          EdgeIsolateDatabaseEngine.withTimeoutResult(
            driver.selectRows<Record<string, any>>(
              'explore_tracks',
              'select=*&order=updated_at.desc&limit=200',
            ),
            3500,
          ),
          EdgeIsolateDatabaseEngine.withTimeoutResult(
            driver.selectRows<Record<string, any>>(
              'kinetic_posts',
              'select=*&order=created_at.desc&limit=200',
            ),
            3500,
          ),
          EdgeIsolateDatabaseEngine.withTimeoutResult(
            driver.selectRows<Record<string, any>>(
              'reel_comments',
              'select=*&order=timestamp_ms.desc&limit=400',
            ),
            3500,
          ),
          EdgeIsolateDatabaseEngine.withTimeoutResult(
            driver.selectRows<Record<string, any>>(
              'social_interactions',
              'select=*&limit=1000',
            ),
            3500,
          ),
        ]);

      if (tracksRes.ok) this.hydrateExploreTrackRows(tracksRes.value);
      if (postsRes.ok) this.hydrateKineticPostRows(postsRes.value);
      if (commentsRes.ok) this.hydrateReelCommentRows(commentsRes.value);
      if (interactionsRes.ok) {
        this.hydrateSocialInteractionRows(interactionsRes.value);
      }

      const allSucceeded =
        tracksRes.ok && postsRes.ok && commentsRes.ok && interactionsRes.ok;
      if (allSucceeded) {
        this.domainHydratedAtMs.set(domainKey, Date.now());
      }
      return allSucceeded;
    })().finally(() => {
      if (this.domainInFlightPromises.get(domainKey) === syncPromise) {
        this.domainInFlightPromises.delete(domainKey);
      }
    });

    this.domainInFlightPromises.set(domainKey, syncPromise);
    return syncPromise;
  }

  public async syncSocialFromCloud(
    force = false,
    cOrEnv?: unknown,
  ): Promise<boolean> {
    const driver = this.resolveCloudDriver(cOrEnv);
    if (!driver.isConfigured()) return false;

    const domainKey = 'social:global';
    const lastHydrated = this.domainHydratedAtMs.get(domainKey) ?? 0;
    if (
      !force &&
      lastHydrated > 0 &&
      Date.now() - lastHydrated < EdgeIsolateDatabaseEngine.DEFAULT_SWR_TTL_MS
    ) {
      return true;
    }

    const existingFlight = this.domainInFlightPromises.get(domainKey);
    if (existingFlight && !force) {
      return existingFlight;
    }

    const syncPromise = (async (): Promise<boolean> => {
      const [clipsRes, commentsRes, interactionsRes] = await Promise.all([
        EdgeIsolateDatabaseEngine.withTimeoutResult(
          driver.selectRows<Record<string, any>>(
            'published_clips',
            'select=*&order=created_at.desc&limit=120',
          ),
          3500,
        ),
        EdgeIsolateDatabaseEngine.withTimeoutResult(
          driver.selectRows<Record<string, any>>(
            'reel_comments',
            'select=*&order=timestamp_ms.desc&limit=400',
          ),
          3500,
        ),
        EdgeIsolateDatabaseEngine.withTimeoutResult(
          driver.selectRows<Record<string, any>>(
            'social_interactions',
            'select=*&limit=1000',
          ),
          3500,
        ),
      ]);

      if (clipsRes.ok) this.hydratePublishedClipRows(clipsRes.value);
      if (commentsRes.ok) this.hydrateReelCommentRows(commentsRes.value);
      if (interactionsRes.ok) {
        this.hydrateSocialInteractionRows(interactionsRes.value);
      }

      const allSucceeded = clipsRes.ok && commentsRes.ok && interactionsRes.ok;
      if (allSucceeded) {
        this.domainHydratedAtMs.set(domainKey, Date.now());
      }
      return allSucceeded;
    })().finally(() => {
      if (this.domainInFlightPromises.get(domainKey) === syncPromise) {
        this.domainInFlightPromises.delete(domainKey);
      }
    });

    this.domainInFlightPromises.set(domainKey, syncPromise);
    return syncPromise;
  }

  public async syncCreatorWalletFromCloud(
    creatorId: string,
    cOrEnv?: unknown,
  ): Promise<boolean> {
    const cid = canonicalizeCreatorId(creatorId);
    const driver = this.resolveCloudDriver(cOrEnv);
    if (!driver.isConfigured()) return false;

    const domainKey = `wallet:${cid}`;
    const [walletRes, bankRes, topupRes] = await Promise.all([
      EdgeIsolateDatabaseEngine.withTimeoutResult(
        driver.selectRows<Record<string, any>>(
          'wallet_ledger',
          `select=*&creator_id=eq.${encodeURIComponent(cid)}&order=created_at.desc&limit=500`,
        ),
        3500,
      ),
      EdgeIsolateDatabaseEngine.withTimeoutResult(
        driver.selectRows<Record<string, any>>(
          'bank_accounts',
          `select=*&creator_id=eq.${encodeURIComponent(cid)}&limit=50`,
        ),
        3500,
      ),
      EdgeIsolateDatabaseEngine.withTimeoutResult(
        driver.selectRows<Record<string, any>>(
          'payment_topups',
          `select=*&creator_id=eq.${encodeURIComponent(cid)}&order=created_at.desc&limit=100`,
        ),
        3500,
      ),
    ]);

    if (walletRes.ok) {
      const mapped = walletRes.value
        .filter((wl) => Boolean(wl.id))
        .map((wl) => ({
          id: String(wl.id),
          creator_id: cid,
          type: String(wl.type ?? 'topup'),
          amount_zar: Number(wl.amount_zar ?? 0),
          amount_coins: Number(wl.amount_coins ?? 0),
          status: String(wl.status ?? 'completed'),
          reference: String(wl.reference ?? ''),
          data_json:
            typeof wl.metadata_json === 'string'
              ? wl.metadata_json
              : JSON.stringify(wl.metadata_json ?? {}),
          created_at: String(wl.created_at ?? new Date().toISOString()),
        }));
      const existingList = this.walletLedger.get(cid) ?? [];
      const seenIds = new Set(mapped.map((r) => String(r.id)));
      this.walletLedger.set(cid, [
        ...mapped,
        ...existingList.filter((r) => !seenIds.has(String(r.id))),
      ]);
    }
    if (bankRes.ok) {
      for (const ba of bankRes.value) {
        if (!ba.id) continue;
        this.bankAccounts.set(String(ba.id), {
          id: String(ba.id),
          creatorId: cid,
          bankName: String(ba.bank_name ?? ''),
          branchCode: String(ba.branch_code ?? ''),
          maskedAccount: String(ba.account_number_masked ?? ''),
          paymentRail: String(ba.payout_rail ?? 'payfast'),
          accountHolder: ba.account_holder ? String(ba.account_holder) : null,
          updatedAt: String(ba.updated_at ?? new Date().toISOString()),
        });
      }
    }
    if (topupRes.ok) {
      for (const pt of topupRes.value) {
        if (!pt.checkout_id) continue;
        this.payfastCheckouts.set(String(pt.checkout_id), {
          checkoutId: String(pt.checkout_id),
          creatorId: cid,
          provider: String(pt.provider ?? 'payfast'),
          providerPaymentId: pt.provider_payment_id ? String(pt.provider_payment_id) : null,
          packId: String(pt.pack_id ?? 'pack_producer_1500'),
          amountZar: Number(pt.amount_zar ?? 0),
          coinsGranted: Number(pt.coins_granted ?? 0),
          status: String(pt.status ?? 'pending'),
          signatureMd5: String(pt.signature_md5 ?? ''),
          verifiedAt: pt.verified_at ? String(pt.verified_at) : null,
          createdAt: String(pt.created_at ?? new Date().toISOString()),
        });
        if (pt.provider_payment_id) {
          this.payfastByPfId.set(String(pt.provider_payment_id), String(pt.checkout_id));
        }
      }
    }

    const allOk = walletRes.ok && bankRes.ok && topupRes.ok;
    if (allOk) {
      this.domainHydratedAtMs.set(domainKey, Date.now());
    }
    return allOk;
  }

  private hydrateLibraryRows(rows: Array<Record<string, any>>): void {
    for (const lib of rows) {
      if (!lib.id) continue;
      const norm = normalizeLibrarySyncRow(lib);
      const normId = String(norm.id);
      const cid = canonicalizeCreatorId(
        String(norm.creatorId ?? lib.creator_id ?? 'creator_cern'),
      );
      this.libraryItems.set(normId, {
        id: normId,
        creator_id: cid,
        item_type: String(norm.itemType ?? lib.item_type ?? 'track'),
        title: String(norm.title ?? lib.title ?? 'Untitled Track'),
        data_json: JSON.stringify({ ...norm, creatorId: cid }),
        created_at: String(
          norm.createdAt ?? norm.updatedAt ?? new Date().toISOString(),
        ),
        updated_at: String(norm.updatedAt ?? new Date().toISOString()),
      });
    }
  }

  private hydratePlaylistRows(rows: Array<Record<string, any>>): void {
    for (const pl of rows) {
      if (!pl.id) continue;
      const norm = normalizePlaylistRow(pl);
      const id = String(norm.id);
      const cid = canonicalizeCreatorId(
        String(norm.creatorId ?? pl.creator_id ?? 'creator_cern'),
      );
      const rawShareCode = norm.shareCode ? String(norm.shareCode) : null;
      const effectiveShareCode =
        rawShareCode && rawShareCode.startsWith('priv_') ? null : rawShareCode;
      const createdIso = new Date(Number(pl.created_at || Date.now())).toISOString();
      const updatedIso = new Date(Number(pl.updated_at || Date.now())).toISOString();
      this.playlists.set(id, {
        id,
        creator_id: cid,
        title: String(norm.title ?? 'Untitled Playlist'),
        description: String(norm.description ?? ''),
        cover_image_url: norm.coverImageUrl ?? null,
        track_ids_json: JSON.stringify(norm.trackIds ?? []),
        is_public: norm.isPublic ? 1 : 0,
        share_code: effectiveShareCode,
        share_url: effectiveShareCode
          ? `https://vhunambi.za/p/${effectiveShareCode}`
          : null,
        created_at: createdIso,
        updated_at: updatedIso,
      });
    }
  }

  private hydrateBeatLicenseRows(rows: Array<Record<string, any>>): void {
    for (const bl of rows) {
      if (!bl.certificate_id) continue;
      const norm = normalizeBeatLicenseRow(bl);
      const amtZar = Number(bl.amount_paid_zar ?? norm.amountPaidZar ?? 0);
      const amtCoins = Number(bl.amount_paid_coins ?? norm.amountPaidCoins ?? 0);
      const buyerCid = canonicalizeCreatorId(String(bl.buyer_id ?? norm.buyerId ?? ''));
      const producerCid = canonicalizeCreatorId(
        String(bl.producer_id ?? norm.producerId ?? ''),
      );
      const enriched = {
        ...norm,
        buyerId: buyerCid,
        producerId: producerCid,
      };
      this.beatLicenses.set(String(bl.certificate_id), {
        certificate_id: String(bl.certificate_id),
        license_hash: String(bl.license_hash ?? ''),
        beat_id: String(bl.beat_id ?? ''),
        producer_id: producerCid,
        buyer_id: buyerCid,
        tier: String(bl.tier ?? 'basic_lease'),
        coins_paid: amtCoins,
        zar_paid: amtZar,
        producer_coins: Math.max(1, Math.floor(amtCoins * 0.85)),
        producer_zar: Number((amtZar * 0.85).toFixed(2)),
        issued_at: String(
          bl.issued_at ??
          norm.issuedAtIso8601 ??
          norm.issuedAt ??
          new Date(Number(bl.purchased_at || Date.now())).toISOString(),
        ),
        data_json: JSON.stringify(enriched),
      });
    }
  }

  private hydrateMarketplaceAssetRows(rows: Array<Record<string, any>>): void {
    for (const ma of rows) {
      if (!ma.id) continue;
      const norm = normalizeMarketplaceAssetRow(ma);
      const id = String(norm.id);
      const producerCid = canonicalizeCreatorId(
        String(norm.producerId ?? ma.producer_id ?? 'creator_cern'),
      );
      const updatedIso = new Date(Number(ma.updated_at || Date.now())).toISOString();
      this.marketplaceAssets.set(id, {
        id,
        title: String(ma.title ?? norm.title ?? 'Untitled Beat'),
        producer_id: producerCid,
        asset_category: 'beats',
        price_zar: Number(ma.price_zar ?? norm.priceZar ?? 0),
        price_coins: Number(ma.price_coins ?? norm.priceCoins ?? 0),
        is_exclusive_sold:
          ma.is_exclusive_sold || norm.isExclusiveSold ? 1 : 0,
        exclusive_buyer_id:
          ma.exclusive_buyer_id ?? norm.exclusiveBuyerId ?? null,
        data_json: JSON.stringify({ ...norm, producerId: producerCid }),
        created_at: updatedIso,
        updated_at: updatedIso,
      });
    }
  }

  public async syncUserLibraryFromCloud(
    creatorId: string,
    cOrEnv?: unknown,
    force = false,
  ): Promise<any[]> {
    const cid = canonicalizeCreatorId(creatorId);
    const driver = this.resolveCloudDriver(cOrEnv);
    if (!driver.isConfigured()) {
      return this.getLibrary(cid);
    }

    const domainKey = `library:${cid}`;
    const lastHydrated = this.domainHydratedAtMs.get(domainKey) ?? 0;
    if (
      !force &&
      lastHydrated > 0 &&
      Date.now() - lastHydrated < EdgeIsolateDatabaseEngine.DEFAULT_SWR_TTL_MS
    ) {
      return this.getLibrary(cid);
    }

    const res = await EdgeIsolateDatabaseEngine.withTimeoutResult(
      driver.selectRows<Record<string, any>>(
        'user_library_sync',
        `select=*&creator_id=eq.${encodeURIComponent(cid)}&order=updated_at.desc&limit=500`,
      ),
      3500,
    );
    if (res.ok) {
      const remoteIds = new Set(res.value.map((r) => String(r.id ?? '')).filter(Boolean));
      for (const [existingId, existingRow] of this.libraryItems.entries()) {
        if (
          canonicalizeCreatorId(String(existingRow.creator_id)) === cid &&
          !remoteIds.has(existingId)
        ) {
          this.libraryItems.delete(existingId);
        }
      }
      this.hydrateLibraryRows(res.value);
      this.domainHydratedAtMs.set(domainKey, Date.now());
    }
    return this.getLibrary(cid);
  }

  public async syncPlaylistsFromCloud(
    creatorId?: string,
    cOrEnv?: unknown,
    force = false,
  ): Promise<boolean> {
    const cid = creatorId ? canonicalizeCreatorId(creatorId) : '';
    const driver = this.resolveCloudDriver(cOrEnv);
    if (!driver.isConfigured()) return false;

    const domainKey = `playlists:${cid || 'public'}`;
    const lastHydrated = this.domainHydratedAtMs.get(domainKey) ?? 0;
    if (
      !force &&
      lastHydrated > 0 &&
      Date.now() - lastHydrated < EdgeIsolateDatabaseEngine.DEFAULT_SWR_TTL_MS
    ) {
      return true;
    }

    const query = cid
      ? `select=*&or=(creator_id.eq.${encodeURIComponent(cid)},is_public.eq.true)&order=updated_at.desc&limit=200`
      : 'select=*&order=updated_at.desc&limit=200';
    const res = await EdgeIsolateDatabaseEngine.withTimeoutResult(
      driver.selectRows<Record<string, any>>('playlists', query),
      3500,
    );
    if (res.ok) {
      const remoteIds = new Set(res.value.map((r) => String(r.id ?? '')).filter(Boolean));
      if (cid) {
        for (const [plId, row] of this.playlists.entries()) {
          if (
            canonicalizeCreatorId(String(row.creator_id)) === cid &&
            !remoteIds.has(plId)
          ) {
            this.playlists.delete(plId);
          }
        }
      }
      this.hydratePlaylistRows(res.value);
      this.domainHydratedAtMs.set(domainKey, Date.now());
      return true;
    }
    return false;
  }

  public async syncBuyerLicensesFromCloud(
    buyerId: string,
    cOrEnv?: unknown,
    force = false,
  ): Promise<any[]> {
    const cid = canonicalizeCreatorId(buyerId);
    const driver = this.resolveCloudDriver(cOrEnv);
    if (!driver.isConfigured()) {
      return this.getBeatLicensesByBuyer(cid);
    }

    const domainKey = `licenses:${cid}`;
    const lastHydrated = this.domainHydratedAtMs.get(domainKey) ?? 0;
    if (
      !force &&
      lastHydrated > 0 &&
      Date.now() - lastHydrated < EdgeIsolateDatabaseEngine.DEFAULT_SWR_TTL_MS
    ) {
      return this.getBeatLicensesByBuyer(cid);
    }

    const res = await EdgeIsolateDatabaseEngine.withTimeoutResult(
      driver.selectRows<Record<string, any>>(
        'beat_licenses',
        `select=*&buyer_id=eq.${encodeURIComponent(cid)}&order=purchased_at.desc&limit=300`,
      ),
      3500,
    );
    if (res.ok) {
      this.hydrateBeatLicenseRows(res.value);
      this.domainHydratedAtMs.set(domainKey, Date.now());
    }
    return this.getBeatLicensesByBuyer(cid);
  }

  public async syncMarketplaceFromCloud(
    force = false,
    cOrEnv?: unknown,
  ): Promise<boolean> {
    const driver = this.resolveCloudDriver(cOrEnv);
    if (!driver.isConfigured()) return false;

    const domainKey = 'marketplace:global';
    const lastHydrated = this.domainHydratedAtMs.get(domainKey) ?? 0;
    if (
      !force &&
      lastHydrated > 0 &&
      Date.now() - lastHydrated < EdgeIsolateDatabaseEngine.DEFAULT_SWR_TTL_MS
    ) {
      return true;
    }

    const [assetsRes, licensesRes] = await Promise.all([
      EdgeIsolateDatabaseEngine.withTimeoutResult(
        driver.selectRows<Record<string, any>>(
          'marketplace_assets',
          'select=*&order=updated_at.desc&limit=200',
        ),
        3500,
      ),
      EdgeIsolateDatabaseEngine.withTimeoutResult(
        driver.selectRows<Record<string, any>>(
          'beat_licenses',
          'select=*&order=purchased_at.desc&limit=300',
        ),
        3500,
      ),
    ]);

    if (assetsRes.ok) this.hydrateMarketplaceAssetRows(assetsRes.value);
    if (licensesRes.ok) this.hydrateBeatLicenseRows(licensesRes.value);

    const ok = assetsRes.ok && licensesRes.ok;
    if (ok) {
      this.domainHydratedAtMs.set(domainKey, Date.now());
    }
    return ok;
  }

  public async syncLibraryDeltaAsync(
    creatorId: string,
    incomingItems: any[],
    cOrEnv?: unknown,
  ): Promise<ReturnType<EdgeIsolateDatabaseEngine['syncLibraryDelta']>> {
    const cid = canonicalizeCreatorId(creatorId);
    await this.syncUserLibraryFromCloud(cid, cOrEnv);
    const result = this.syncLibraryDelta(cid, incomingItems, true);
    const driver = this.resolveCloudDriver(cOrEnv);
    if (driver.isConfigured()) {
      for (const item of result.items) {
        const updatedAtMs = Number(item.updatedAtMs ?? Date.now());
        try {
          await driver.upsertRow(
            'user_library_sync',
            {
              id: String(item.id),
              creator_id: cid,
              item_type: String(item.itemType ?? 'track'),
              title: String(item.title ?? 'Untitled Track'),
              artist: String(
                item.creatorName ?? item.artistName ?? item.artist ?? 'Vhunambi Creator',
              ),
              genre: String(item.genre ?? 'Amapiano'),
              bpm: Math.round(Number(item.bpm ?? 113)),
              duration_sec: Math.round(
                Number(item.durationSeconds ?? item.durationSec ?? 180),
              ),
              audio_url: String(
                item.remoteAudioUrl ?? item.audioUrl ?? item.masterMp3Url ?? '',
              ),
              cover_url: String(item.coverImageUrl ?? item.coverUrl ?? ''),
              is_favorite: Boolean(item.isFavorite ?? false),
              is_downloaded: Boolean(item.isDownloaded ?? false),
              play_count: Number(item.playCount ?? 0),
              is_licensed_beat: Boolean(item.isLicensedBeat ?? false),
              license_tier: item.licenseTierId ?? item.licenseTier ?? null,
              certificate_id:
                item.licenseCertificateIdOverride ?? item.certificateId ?? null,
              license_hash: item.licenseHash ?? null,
              master_file_sha256: item.masterFileSha256 ?? null,
              stems_json: item.stemPaths ?? item.stemFilesJson ?? {},
              data_json: item,
              created_at: Date.parse(String(item.createdAt ?? '')) || updatedAtMs,
              updated_at: updatedAtMs,
            },
            'id,creator_id',
          );
        } catch (err) {
          this.recordWriteThroughFailure('user_library_sync.upsert_async', err);
        }
      }
      this.domainHydratedAtMs.set(`library:${cid}`, Date.now());
    }
    return result;
  }

  public async deleteLibraryItemAsync(
    id: string,
    creatorId?: string,
    cOrEnv?: unknown,
  ): Promise<boolean> {
    const cid = creatorId ? canonicalizeCreatorId(creatorId) : undefined;
    if (cid) {
      await this.syncUserLibraryFromCloud(cid, cOrEnv);
    }
    const deleted = this.deleteLibraryItem(id, cid, true);
    if (!deleted) return false;
    const driver = this.resolveCloudDriver(cOrEnv);
    if (driver.isConfigured()) {
      try {
        const filter = cid ? `&creator_id=eq.${encodeURIComponent(cid)}` : '';
        await driver.deleteRows(
          'user_library_sync',
          `id=eq.${encodeURIComponent(id)}${filter}`,
        );
      } catch (err) {
        this.recordWriteThroughFailure('user_library_sync.delete_async', err);
      }
    }
    return true;
  }

  public async upsertPlaylistAsync(
    input: Record<string, any>,
    cOrEnv?: unknown,
  ): Promise<Record<string, any>> {
    const normalizedInput = {
      ...input,
      creatorId: canonicalizeCreatorId(
        String(input.creatorId ?? input.creator_id ?? 'creator_cern'),
      ),
    };
    const mapped = this.upsertPlaylist(normalizedInput, true);
    const driver = this.resolveCloudDriver(cOrEnv);
    if (driver.isConfigured()) {
      try {
        await driver.upsertRow(
          'playlists',
          {
            id: String(mapped.id),
            creator_id: canonicalizeCreatorId(String(mapped.creatorId)),
            title: String(mapped.title),
            description: String(mapped.description ?? ''),
            cover_url: String(mapped.coverImageUrl ?? ''),
            track_ids_json: mapped.trackIds ?? [],
            is_public: Boolean(mapped.isPublic),
            share_code: mapped.shareCode
              ? String(mapped.shareCode)
              : `priv_${String(mapped.id)}`,
            data_json: mapped,
            created_at: Date.parse(String(mapped.createdAt)) || Date.now(),
            updated_at: Date.parse(String(mapped.updatedAt)) || Date.now(),
          },
          'id',
        );
        this.domainHydratedAtMs.set(
          `playlists:${canonicalizeCreatorId(String(mapped.creatorId))}`,
          Date.now(),
        );
      } catch (err) {
        this.recordWriteThroughFailure('playlists.upsert_async', err);
      }
    }
    return mapped;
  }

  public async deletePlaylistAsync(
    id: string,
    creatorId?: string,
    cOrEnv?: unknown,
  ): Promise<boolean> {
    const cid = creatorId ? canonicalizeCreatorId(creatorId) : undefined;
    await this.syncPlaylistsFromCloud(cid, cOrEnv);
    const deleted = this.deletePlaylist(id, cid, true);
    if (!deleted) return false;
    const driver = this.resolveCloudDriver(cOrEnv);
    if (driver.isConfigured()) {
      try {
        await driver.deleteRows('playlists', `id=eq.${encodeURIComponent(id)}`);
      } catch (err) {
        this.recordWriteThroughFailure('playlists.delete_async', err);
      }
    }
    return true;
  }

  public async sharePlaylistAsync(
    id: string,
    cOrEnv?: unknown,
  ): Promise<Record<string, any> | null> {
    await this.syncPlaylistsFromCloud(undefined, cOrEnv);
    const shared = this.sharePlaylist(id);
    if (!shared) return null;
    const driver = this.resolveCloudDriver(cOrEnv);
    if (driver.isConfigured()) {
      try {
        await driver.upsertRow(
          'playlists',
          {
            id: String(shared.id),
            creator_id: canonicalizeCreatorId(String(shared.creatorId ?? 'creator_cern')),
            title: String(shared.title ?? 'Untitled Playlist'),
            description: String(shared.description ?? ''),
            cover_url: String(shared.coverImageUrl ?? ''),
            track_ids_json: shared.trackIds ?? [],
            is_public: true,
            share_code: String(shared.shareCode),
            data_json: shared,
            created_at: Date.parse(String(shared.createdAt)) || Date.now(),
            updated_at: Date.now(),
          },
          'id',
        );
      } catch (err) {
        this.recordWriteThroughFailure('playlists.share_async', err);
      }
    }
    return shared;
  }

  private appendMutation(entry: {
    idempotencyKey: string;
    entityType: string;
    entityId: string;
    action: string;
    payload: Record<string, any>;
    creatorId?: string;
    createdAt?: string;
  }): number {
    if (this.seenMutationKeys.has(entry.idempotencyKey)) {
      return this.seqCounter;
    }
    this.seqCounter += 1;
    this.seenMutationKeys.add(entry.idempotencyKey);
    const createdAt = entry.createdAt ?? new Date().toISOString();
    const creatorId = entry.creatorId?.trim() || 'system';
    this.mutations.push({
      seq: this.seqCounter,
      idempotencyKey: entry.idempotencyKey,
      entityType: entry.entityType,
      entityId: entry.entityId,
      action: entry.action,
      creatorId,
      payload: entry.payload,
      createdAt,
    });
    if (entry.entityType !== 'payout') {
      this.mirrorWriteThrough(async (driver) => {
        await driver.upsertRow(
          'sync_mutation_log',
          {
            mutation_id: entry.idempotencyKey,
            creator_id: creatorId,
            entity_type: entry.entityType,
            entity_id: entry.entityId,
            operation: entry.action,
            payload_json: entry.payload,
            client_ts: Date.parse(createdAt) || Date.now(),
          },
          'mutation_id',
        );
      });
    }
    return this.seqCounter;
  }

  private seedDefaults(): void {
    const now = new Date().toISOString();
    const defaultCreators = [
      {
        id: 'creator_cern',
        handle: '@cern',
        displayName: 'Cern',
        avatarUrl: 'https://cdn.vhunambi.com/avatars/cern.jpg',
        archetype: 'aiSonicArchitect',
        tier: 'emerging',
        reputationScore: 140,
      },
      {
        id: 'creator_sigwa',
        handle: '@sigwa',
        displayName: 'Sigwa',
        avatarUrl: 'https://cdn.vhunambi.com/avatars/sigwa.jpg',
        archetype: 'traditionalInstrumentalist',
        tier: 'verified',
        reputationScore: 220,
      },
      {
        id: 'usr_me',
        handle: '@vhunambi_creator',
        displayName: 'Vhunambi Creator',
        avatarUrl: 'https://cdn.vhunambi.com/avatars/me.jpg',
        archetype: 'aiSonicArchitect',
        tier: 'verified',
        reputationScore: 180,
      },
      {
        id: 'creator_makhadzi',
        handle: '@makhadzi',
        displayName: 'Makhadzi',
        avatarUrl: 'https://cdn.vhunambi.com/avatars/makhadzi.jpg',
        archetype: 'traditionalInstrumentalist',
        tier: 'verified',
        reputationScore: 340,
      },
    ];
    for (const c of defaultCreators) {
      this.creators.set(c.id, { ...c, createdAt: now, updatedAt: now });
    }

    // Seed wallets matching SQLite seedInitialDataIfEmpty (4750 coins / R1420.00)
    this.walletLedger.set('creator_cern', [
      {
        id: 'tx_seed_01',
        creator_id: 'creator_cern',
        type: 'topup',
        amount_zar: 1420.0,
        amount_coins: 4750,
        status: 'completed',
        reference: 'INITIAL_CREDIT',
        data_json: JSON.stringify({ note: 'Seeded wallet balance' }),
        created_at: now,
      },
    ]);
    for (const cid of ['usr_me', 'creator_makhadzi']) {
      this.walletLedger.set(cid, [
        {
          id: `tx_seed_${cid}`,
          creator_id: cid,
          type: 'topup',
          amount_zar: 1420.0,
          amount_coins: 4750,
          status: 'completed',
          reference: 'INITIAL_CREDIT',
          data_json: JSON.stringify({
            note: 'Seeded default Phase 59 creator balance',
          }),
          created_at: now,
        },
      ]);
    }

    // Seed initial kinetic post (starts at 22 cosigns so 3 more hits 25 threshold)
    this.kineticPosts.set('post_seed_01', {
      id: 'post_seed_01',
      creator_id: 'creator_sigwa',
      creator_handle: '@sigwa',
      creator_name: 'Sigwa',
      caption:
        'Late night studio session testing the Venda Folk LoRA & sub-bass log drum slide 🔥 What do you think of this rhythm?',
      media_type: 'audio_card',
      like_count: 0,
      comment_count: 0,
      cosign_count: 22,
      cosign_target: 25,
      repost_count: 14,
      discovery_stage: 'freshCrate',
      data_json: JSON.stringify({ genre: 'Venda Folk', bpm: 114 }),
      created_at: now,
      updated_at: now,
    });

    // Seed all 12 Explore tracks matching SQLite
    const seedTracks = [
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

    for (const t of seedTracks) {
      const stage =
        t.plays >= 8000 || t.cosigns >= 250
          ? 'mainstage'
          : t.plays >= 1500 || t.cosigns >= 60
            ? 'risingBreakout'
            : 'freshCrate';
      const normalizedMoodId = normalizeVhunambiMoodId(t.mood);
      this.exploreTracks.set(t.id, {
        id: t.id,
        title: t.title,
        artist_id: t.artistId,
        artist_name: t.artistName,
        genre: t.genre,
        audio_url: t.audioUrl,
        bpm: t.bpm,
        play_count: t.plays,
        like_count: t.likes,
        cosign_count: t.cosigns,
        discovery_stage: stage,
        mood_id: normalizedMoodId,
        description: '',
        allow_open_stems_remix: t.stemsAvailable ? 1 : 0,
        data_json: JSON.stringify({
          subGenre: t.subGenre,
          language: t.language,
          province: t.province,
          mood: t.mood,
          moodId: normalizedMoodId,
          description: '',
          allowOpenStemsRemix: t.stemsAvailable,
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
        created_at: t.createdAt,
        updated_at: now,
      });
    }

    // Seed initial playlists matching SQLite
    this.playlists.set('pl_amapiano_gold', {
      id: 'pl_amapiano_gold',
      creator_id: 'usr_me',
      title: 'Amapiano & Lekompo Gold',
      description: 'Curated Private School Amapiano and Limpopo Lekompo rotation.',
      cover_image_url: 'https://cdn.vhunambi.za/covers/sovereign_groove.jpg',
      track_ids_json: JSON.stringify([
        'trk_cloud_1',
        'trk_cloud_2',
        'trk_cloud_4',
        'trk_cloud_6',
      ]),
      is_public: 1,
      share_code: 'VH-AMAPIANO-01',
      share_url: 'https://vhunambi.za/p/VH-AMAPIANO-01',
      created_at: now,
      updated_at: now,
    });
    this.playlists.set('pl_3step_horizon', {
      id: 'pl_3step_horizon',
      creator_id: 'usr_me',
      title: '3-Step & Afro-Tech Horizon',
      description: 'High-energy Durban 3-Step and Cape Town Afro-Tech dubs.',
      cover_image_url: 'https://cdn.vhunambi.za/covers/durban_3step.jpg',
      track_ids_json: JSON.stringify(['trk_cloud_3', 'trk_cloud_11', 'trk_cloud_5']),
      is_public: 0,
      share_code: null,
      share_url: null,
      created_at: now,
      updated_at: now,
    });

    // Seed canonical 7 Sovereign Auth accounts
    const defaultHash = EdgeIsolateDatabaseEngine.getDefaultSeedPasswordHash();
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
    for (const acc of seedAccounts) {
      if (!this.creators.has(acc.creatorId)) {
        this.creators.set(acc.creatorId, {
          id: acc.creatorId,
          handle: acc.handle,
          displayName: acc.displayName,
          avatarUrl: `https://cdn.vhunambi.com/avatars/${acc.creatorId}.jpg`,
          tier: 'verified',
          createdAt: now,
          updatedAt: now,
        });
      }
      this.usersByCreatorId.set(acc.creatorId, {
        userId: acc.userId,
        creatorId: acc.creatorId,
        handle: acc.handle,
        displayName: acc.displayName,
        email: acc.email,
        passwordHash: defaultHash,
        role: 'creator',
        avatarUrl: `https://cdn.vhunambi.com/avatars/${acc.creatorId}.jpg`,
        isVerified: true,
        createdAt: now,
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Delta Sync & Idempotent Mutation Ingestion
  // ---------------------------------------------------------------------------

  public applyMutationsBatch(mutations: SyncMutationRecord[]): {
    applied: string[];
    skipped: string[];
    failed: Array<{
      idempotencyKey: string;
      code: string;
      message: string;
      retryable: boolean;
    }>;
    latestSeq: number;
  } {
    const applied: string[] = [];
    const skipped: string[] = [];
    const failed: Array<{
      idempotencyKey: string;
      code: string;
      message: string;
      retryable: boolean;
    }> = [];

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

    const commutativeCounterActions = new Set(['like', 'cosign', 'repost']);

    for (const m of mutations) {
      try {
        if (this.seenMutationKeys.has(m.idempotencyKey)) {
          skipped.push(m.idempotencyKey);
          continue;
        }

        const entityId = String(
          m.payload?.id ||
          m.payload?.trackId ||
          m.payload?.postId ||
          m.payload?.originalPostId ||
          m.payload?.certificateId ||
          (m as { entityId?: string }).entityId ||
          `gen_${Date.now()}`,
        );
        let shouldApply = true;

        if (commutativeCounterActions.has(m.action)) {
          if (m.entityType === 'post') {
            if (m.action === 'like') {
              const p = this.kineticPosts.get(entityId);
              if (p) {
                p.like_count = Number(p.like_count ?? 0) + 1;
                p.updated_at = new Date().toISOString();
                this.mirrorWriteThrough(async (driver) => {
                  await driver.patchRows(
                    'kinetic_posts',
                    `id=eq.${encodeURIComponent(entityId)}`,
                    { like_count: p.like_count, updated_at: Date.now() },
                  );
                });
              }
            } else if (m.action === 'cosign') {
              this.cosignPost(entityId, m.payload?.creatorId);
            } else if (m.action === 'repost') {
              const targetPostId = String(m.payload?.originalPostId || entityId);
              const repostPayload =
                m.payload?.repost && typeof m.payload.repost === 'object'
                  ? (m.payload.repost as Record<string, any>)
                  : undefined;
              this.repostPost(targetPostId, repostPayload);
            }
          } else if (m.entityType === 'track') {
            const t = this.exploreTracks.get(entityId);
            if (t) {
              t.like_count = Number(t.like_count ?? 0) + 1;
              t.updated_at = new Date().toISOString();
              this.mirrorWriteThrough('explore_tracks.like', async (driver) => {
                await driver.patchRows(
                  'explore_tracks',
                  `id=eq.${encodeURIComponent(entityId)}`,
                  { likes_count: t.like_count, updated_at: Date.now() },
                );
              });
            }
          }
        } else if (m.entityType === 'post' && m.action === 'create') {
          this.upsertKineticPost({
            ...(m.payload || {}),
            id: entityId,
            createdAt: m.payload?.createdAt || m.createdAt,
          });
        } else if (m.entityType === 'cosign') {
          this.cosignPost(entityId, m.payload?.creatorId);
        } else if (m.entityType === 'comment' && m.action === 'create') {
          const targetId = String(m.payload?.postId || m.payload?.clipId || entityId);
          const added = this.addKineticPostComment(targetId, {
            ...(m.payload || {}),
            id: m.payload?.id,
            createdAt: m.payload?.createdAt || m.createdAt,
          });
          if (!added) {
            this.insertReelComment({
              ...(m.payload || {}),
              id: String(m.payload?.id || `c_${Date.now()}`),
              clipId: targetId,
              createdAt: m.payload?.createdAt || m.createdAt,
            });
          }
          shouldApply = true;
        } else if (m.entityType === 'tip') {
          const senderId = String(m.payload?.senderId || 'creator_cern');
          const recipientId = String(m.payload?.recipientId || 'creator_makhadzi');
          const amountCoins = Math.max(
            1,
            Number(m.payload?.amountCoins ?? m.payload?.coins ?? 100),
          );
          const amountZar = Math.max(
            0.1,
            Number(m.payload?.amountZar ?? amountCoins * 0.3),
          );
          const tipRes = this.sendCulturalTipAtomic({
            tipId: String(m.payload?.tipId || m.idempotencyKey || entityId),
            clipId: String(m.payload?.clipId || ''),
            senderId,
            recipientId,
            ancestorId: m.payload?.ancestorId
              ? String(m.payload.ancestorId)
              : undefined,
            amountCoins,
            amountZar,
            giftName: String(m.payload?.giftName || 'Cultural Gift'),
            giftEmoji: String(m.payload?.giftEmoji || '🎵'),
            senderUsername: m.payload?.senderUsername
              ? String(m.payload.senderUsername)
              : undefined,
            message: m.payload?.message ? String(m.payload.message) : undefined,
            giftId: m.payload?.giftId ? String(m.payload.giftId) : undefined,
          });
          if (tipRes.outcome !== 'committed') {
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
        } else if (
          m.entityType === 'post' &&
          m.action === 'update' &&
          m.baseSeq !== undefined
        ) {
          let latestForEntity = 0;
          for (let i = this.mutations.length - 1; i >= 0; i -= 1) {
            const existing = this.mutations[i];
            if (
              existing.entityType === m.entityType &&
              existing.entityId === entityId
            ) {
              latestForEntity = existing.seq;
              break;
            }
          }
          if (latestForEntity > m.baseSeq) {
            failed.push({
              idempotencyKey: m.idempotencyKey,
              code: 'conflict',
              message: `Concurrent edit detected: baseSeq ${m.baseSeq} is stale, current seq ${latestForEntity}`,
              retryable: false,
            });
            continue;
          }
          shouldApply = true;
        } else if (m.entityType === 'beat_license') {
          const certId = String(m.payload?.certificateId || entityId);
          if (!this.beatLicenses.has(certId)) {
            const beatIdStr = String(m.payload?.beatId || '');
            const assetPricing = beatIdStr
              ? this.getMarketplaceBeatById(beatIdStr)
              : null;
            const tierSlug = String(m.payload?.tier || 'basic_lease');
            const isExclusive =
              m.payload?.isExclusiveRights === true ||
              tierSlug === 'exclusive_stem' ||
              tierSlug === 'unlimited_commercial' ||
              tierSlug === 'exclusive';
            const tierMultiplier = isExclusive
              ? 6
              : tierSlug === 'stems_trackout'
                ? 3
                : 1;
            const coinsPaid =
              assetPricing && Number(assetPricing.priceCoins) > 0
                ? Number(assetPricing.priceCoins) * tierMultiplier
                : Number(m.payload?.amountPaidCoins ?? 0);
            const zarPaid =
              assetPricing && Number(assetPricing.priceZar) > 0
                ? Number((Number(assetPricing.priceZar) * tierMultiplier).toFixed(2))
                : Number(m.payload?.amountPaidZar ?? 0);
            const prodCoins = Number(
              m.payload?.producerRoyaltyCoins ??
              Math.floor((coinsPaid * 85 + 50) / 100),
            );
            const prodZar = Number(
              m.payload?.producerRoyaltyZar ??
              Math.round(zarPaid * 0.85 * 100) / 100,
            );
            const insertRes = this.recordBeatLicenseAtomic({
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
              failed.push({
                idempotencyKey: m.idempotencyKey,
                code: 'conflict',
                message: 'Beat has already been purchased under an Exclusive license',
                retryable: false,
              });
              continue;
            }
            if (insertRes.status === 'insufficient_funds') {
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
          this.appendMutation({
            idempotencyKey: m.idempotencyKey,
            entityType: m.entityType,
            entityId,
            action: m.action,
            payload: m.payload,
            creatorId: resolveMutationCreatorId(m),
            createdAt: m.createdAt,
          });
          applied.push(m.idempotencyKey);
        }
      } catch (err: any) {
        failed.push({
          idempotencyKey: m.idempotencyKey,
          code: 'validation_error',
          message: err?.message || 'Unknown validation error',
          retryable: true,
        });
      }
    }

    return { applied, skipped, failed, latestSeq: this.getLatestSeq() };
  }

  public getDelta(
    sinceSeq: number,
    limit: number = 100,
    viewerCreatorId?: string,
  ): SyncDeltaResult {
    const safeLimit = Math.max(1, Math.min(200, limit));
    const normalizedViewer = viewerCreatorId?.trim();
    const privateTypes = new Set([
      'payout',
      'library_track',
      'beat_license',
      'wallet_ledger',
      'playlist',
    ]);

    let rows = this.mutations.filter((r) => r.seq > sinceSeq);
    if (normalizedViewer) {
      const canonicalViewer = canonicalizeCreatorId(normalizedViewer);
      const viewerIds = new Set([normalizedViewer, canonicalViewer]);
      rows = rows.filter((r) => {
        if (!privateTypes.has(r.entityType)) return true;
        if (viewerIds.has(r.creatorId)) return true;
        const p = r.payload || {};
        if (r.creatorId === 'system') {
          const fallbackOwner = String(
            p.creatorId ?? p.creator_id ?? p.buyerId ?? 'system',
          );
          if (viewerIds.has(fallbackOwner)) return true;
        }
        if (r.entityType === 'beat_license') {
          const counterparty = String(p.producerId ?? p.sellerId ?? '');
          if (viewerIds.has(counterparty)) return true;
        }
        if (r.entityType === 'playlist') {
          const isPublic =
            p.isPublic === true ||
            p.isPublic === 1 ||
            p.isPublic === 'true' ||
            p.is_public === 1 ||
            p.is_public === true;
          if (isPublic) return true;
          const plOwner = String(p.creatorId ?? p.creator_id ?? 'system');
          if (plOwner === 'system' || viewerIds.has(plOwner)) return true;
        }
        return false;
      });
    }

    const hasMore = rows.length > safeLimit;
    const visibleRows = hasMore ? rows.slice(0, safeLimit) : rows;
    const latestSeq = this.getLatestSeq();
    const nextCursorSeq =
      visibleRows.length > 0
        ? visibleRows[visibleRows.length - 1].seq
        : latestSeq;

    return {
      mutations: visibleRows.map((r) => ({ ...r })),
      latestSeq,
      nextCursorSeq,
      hasMore,
    };
  }

  public getLatestSeq(): number {
    return this.seqCounter;
  }

  // ---------------------------------------------------------------------------
  // Explore, Tracks Catalog & Radio
  // ---------------------------------------------------------------------------

  public getExploreFeed(
    options: ExploreFeedOptions & { viewerCreatorId?: string } = {},
  ): { posts: any[]; total: number } {
    const viewerId = canonicalizeCreatorId(
      options.viewerCreatorId ?? 'creator_cern',
    );
    let posts: Record<string, any>[] = Array.from(this.kineticPosts.values()).map((r) => {
      let data: Record<string, any> = {};
      try {
        data = JSON.parse(String(r.data_json || '{}')) as Record<string, any>;
      } catch {
        data = {};
      }
      const postId = String(r.id);
      const reactionCounts = compactReactionCounts(
        normalizeReactionCounts(r.reaction_counts_json ?? data.reactionCounts),
      );
      const myReaction = this.getSocialReaction('post_react', postId, viewerId);
      const hasLegacyLike = this.hasSocialInteraction('post_like', postId, viewerId);
      return {
        ...data,
        id: postId,
        creatorId: r.creator_id,
        creatorHandle: r.creator_handle,
        creatorName: r.creator_name,
        caption: r.caption,
        mediaType: r.media_type,
        likeCount: Number(r.like_count ?? data.likeCount ?? 0),
        commentCount: Number(r.comment_count ?? data.commentCount ?? 0),
        cosignCount: Number(r.cosign_count ?? data.cosignCount ?? 0),
        cosignTarget: Number(r.cosign_target ?? data.cosignTarget ?? 25),
        repostCount: Number(r.repost_count ?? data.repostCount ?? 0),
        reactionCounts,
        myReaction: myReaction ?? (hasLegacyLike ? 'love' : null),
        isLikedByMe: myReaction !== null || hasLegacyLike,
        discoveryStage: r.discovery_stage,
        createdAt: r.created_at,
      };
    });

    if (options.stage) {
      posts = posts.filter((p) => p.discoveryStage === options.stage);
    }

    posts.sort((a, b) => {
      const cDiff = Number(b.cosignCount ?? 0) - Number(a.cosignCount ?? 0);
      if (cDiff !== 0) return cDiff;
      return String(b.createdAt).localeCompare(String(a.createdAt));
    });

    if (
      options.genre &&
      options.genre.trim() !== '' &&
      options.genre.toLowerCase() !== 'all'
    ) {
      const g = options.genre.trim().toLowerCase();
      posts = posts.filter((p) => {
        const postGenre = String(
          p.genre ?? p.songDna?.genre ?? '',
        ).toLowerCase();
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

    let discoveryStage: 'freshCrate' | 'risingBreakout' | 'mainstage' =
      'freshCrate';
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
        data.creatorHandle ?? `@${artistName.toLowerCase().replace(/\s+/g, '_')}`,
      ),
      genre: String(r.genre ?? 'Amapiano'),
      subGenre: String(data.subGenre ?? 'Sgija'),
      language: String(data.language ?? 'isiZulu'),
      province: String(data.province ?? 'Gauteng'),
      mood: String(data.mood ?? 'Vibrant'),
      moodId: normalizeVhunambiMoodId(
        (r.mood_id as string | undefined) ??
        (data.moodId as string | undefined) ??
        (data.mood as string | undefined),
      ),
      description: String(r.description ?? data.description ?? ''),
      allowOpenStemsRemix: Boolean(
        r.allow_open_stems_remix ?? data.allowOpenStemsRemix ?? false,
      ),
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

  public getExploreTracks(
    options: {
      genre?: string;
      stage?: string;
      moodId?: string;
      mood?: string;
      sort?: 'trending' | 'newest' | 'likes' | 'plays';
      search?: string;
      limit?: number;
    } = {},
  ): { items: ExploreTrackRecord[]; total: number; serverSeq: number } {
    const limit = Math.min(Math.max(options.limit ?? 50, 1), 100);
    let mapped = Array.from(this.exploreTracks.values()).map((r) =>
      this.mapExploreTrackRow(r),
    );

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

    const rawMood = options.moodId ?? options.mood;
    if (rawMood && rawMood.trim() !== '' && rawMood.toLowerCase() !== 'all') {
      const targetMoodId = normalizeVhunambiMoodId(rawMood);
      mapped = mapped.filter(
        (t) => normalizeVhunambiMoodId(t.moodId ?? t.mood) === targetMoodId,
      );
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
      rotation: scored
        .slice(0, Math.min(Math.max(limit, 1), 50))
        .map((s) => s.track),
      serverSeq: this.getLatestSeq(),
    };
  }

  public upsertExploreTrack(
    input: Record<string, any>,
    recordMutation: boolean = true,
  ): ExploreTrackRecord {
    const now = new Date().toISOString();
    const id = String(input.id || `trk_${Date.now()}_${randomUUID().slice(0, 6)}`);
    const existing = this.exploreTracks.get(id);
    const artistName = String(
      input.creatorName || input.artist || 'Vhunambi Creator',
    );
    const artistId = String(input.creatorId || 'usr_me');
    const genre = String(input.genre || 'Amapiano');
    const bpm = Number(input.bpm ?? 113);
    const playCount = Math.max(
      Number(existing?.play_count ?? 0),
      Number(input.playCount ?? input.playsCount ?? 0),
    );
    const likeCount = Math.max(
      Number(existing?.like_count ?? 0),
      Number(input.likeCount ?? input.likesCount ?? 0),
    );
    const cosignCount = Math.max(
      Number(existing?.cosign_count ?? 0),
      Number(input.cosignsCount ?? 0),
    );
    const stage = String(
      input.discoveryStage ||
      (playCount >= 8000
        ? 'mainstage'
        : playCount >= 1500
          ? 'risingBreakout'
          : 'freshCrate'),
    );
    const normalizedMoodId = normalizeVhunambiMoodId(
      (input.moodId as string | undefined) ?? (input.mood as string | undefined),
    );
    const description = String(input.description ?? '');
    const allowOpenStemsRemix = Boolean(
      input.allowOpenStemsRemix ?? input.stemsAvailable ?? false,
    );
    const dataJson = {
      subGenre: input.subGenre ?? 'Sgija',
      language: input.language ?? 'isiZulu',
      province: input.province ?? 'Gauteng',
      mood: input.mood ?? 'Vibrant',
      moodId: normalizedMoodId,
      description,
      allowOpenStemsRemix,
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

    const row = {
      id,
      title: String(input.title || 'Untitled Track'),
      artist_id: artistId,
      artist_name: artistName,
      genre,
      audio_url: String(input.audioUrl || ''),
      bpm,
      play_count: playCount,
      like_count: likeCount,
      cosign_count: cosignCount,
      discovery_stage: stage,
      mood_id: normalizedMoodId,
      description,
      allow_open_stems_remix: allowOpenStemsRemix ? 1 : 0,
      data_json: JSON.stringify(dataJson),
      created_at: String(existing?.created_at || input.createdAt || now),
      updated_at: now,
    };
    this.exploreTracks.set(id, row);

    this.mirrorWriteThrough('explore_tracks.upsert', async (driver) => {
      await driver.upsertRow(
        'explore_tracks',
        {
          id,
          title: row.title,
          artist: artistName,
          creator_id: artistId,
          genre,
          sub_genre: String(dataJson.subGenre ?? ''),
          region: String(dataJson.province ?? 'South Africa'),
          mood: String(dataJson.mood ?? 'Vibrant'),
          language: String(dataJson.language ?? 'isiZulu'),
          discovery_stage: stage,
          bpm: Math.round(bpm),
          musical_key: String(dataJson.musicalKey ?? 'Am'),
          duration_sec: Math.max(1, Math.round(dataJson.durationMs / 1000)),
          audio_url: row.audio_url,
          cover_url: String(dataJson.coverUrl ?? ''),
          stems_json: input.stemUrls ?? input.stems ?? {},
          plays_count: playCount,
          likes_count: likeCount,
          cosigns_count: cosignCount,
          is_featured: Boolean(dataJson.isNew),
          mood_id: normalizedMoodId,
          description,
          allow_open_stems_remix: allowOpenStemsRemix,
          data_json: dataJson,
          created_at: Date.parse(row.created_at) || Date.now(),
          updated_at: Date.now(),
        },
        'id',
      );
    });

    if (recordMutation) {
      this.appendMutation({
        idempotencyKey: `track_upsert_${id}_${Date.now()}_${this.seqCounter + 1}`,
        entityType: 'track',
        entityId: id,
        action: 'create',
        payload: { id, ...input },
        creatorId: 'system',
        createdAt: now,
      });
    }

    return this.mapExploreTrackRow(row);
  }

  public getExploreDiscoveryBundle(options: ExploreFeedOptions = {}): {
    tracks: ExploreTrackRecord[];
    posts: any[];
    radio: ReturnType<EdgeIsolateDatabaseEngine['getExploreRadioRotation']>;
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

  public cosignPost(
    postId: string,
    _creatorId?: string,
  ): {
    success: boolean;
    postId: string;
    cosignCount: number;
    discoveryStage: string;
    promoted: boolean;
  } {
    const post = this.kineticPosts.get(postId);
    if (!post) {
      return {
        success: false,
        postId,
        cosignCount: 0,
        discoveryStage: 'freshCrate',
        promoted: false,
      };
    }

    const newCount = Number(post.cosign_count || 0) + 1;
    let newStage = String(post.discovery_stage || 'freshCrate');
    let promoted = false;
    if (newCount >= 25 && newStage === 'freshCrate') {
      newStage = 'risingBreakout';
      promoted = true;
    }
    post.cosign_count = newCount;
    post.discovery_stage = newStage;
    post.updated_at = new Date().toISOString();

    this.mirrorWriteThrough(async (driver) => {
      await driver.patchRows(
        'kinetic_posts',
        `id=eq.${encodeURIComponent(postId)}`,
        {
          cosign_count: newCount,
          discovery_stage: newStage,
          updated_at: Date.now(),
        },
      );
    });

    return {
      success: true,
      postId,
      cosignCount: newCount,
      discoveryStage: newStage,
      promoted,
    };
  }

  private mapKineticPostRow(
    r: Record<string, any>,
    viewerCreatorId = 'creator_cern',
  ): Record<string, any> {
    let data: Record<string, any> = {};
    try {
      data = JSON.parse(String(r.data_json || '{}'));
    } catch {
      data = {};
    }
    const postId = String(r.id);
    const actor = canonicalizeCreatorId(viewerCreatorId);
    const reactionCounts = compactReactionCounts(
      normalizeReactionCounts(r.reaction_counts_json ?? data.reactionCounts),
    );
    const myReaction = this.getSocialReaction('post_react', postId, actor);
    const hasLegacyLike = this.hasSocialInteraction('post_like', postId, actor);
    return {
      ...data,
      id: postId,
      creatorId: String(r.creator_id),
      creatorHandle: String(r.creator_handle),
      creatorName: String(r.creator_name),
      caption: String(r.caption ?? ''),
      mediaType: String(r.media_type ?? 'audio_card'),
      likeCount: Number(r.like_count ?? data.likeCount ?? 0),
      commentCount: Number(r.comment_count ?? data.commentCount ?? 0),
      cosignCount: Number(r.cosign_count ?? data.cosignCount ?? 0),
      cosignTarget: Number(r.cosign_target ?? data.cosignTarget ?? 25),
      repostCount: Number(r.repost_count ?? data.repostCount ?? 0),
      reactionCounts,
      myReaction: myReaction ?? (hasLegacyLike ? 'love' : null),
      isLikedByMe: myReaction !== null || hasLegacyLike,
      discoveryStage: String(r.discovery_stage ?? 'freshCrate'),
      createdAt: String(r.created_at),
      updatedAt: String(r.updated_at),
    };
  }

  public getKineticPostById(
    postId: string,
    viewerCreatorId = 'creator_cern',
  ): Record<string, any> | null {
    const row = this.kineticPosts.get(postId);
    return row ? this.mapKineticPostRow(row, viewerCreatorId) : null;
  }

  public upsertKineticPost(input: Record<string, any>): Record<string, any> {
    const now = new Date().toISOString();
    const id = String(input.id || `kpost_${Date.now()}_${randomUUID().slice(0, 6)}`);
    const existing = this.getKineticPostById(id);
    const creatorId = canonicalizeCreatorId(
      String(input.creatorId || existing?.creatorId || 'creator_cern'),
    );
    const rawHandle = String(
      input.creatorHandle || existing?.creatorHandle || `@${creatorId.replace(/^creator_/, '')}`,
    );
    const creatorHandle = rawHandle.startsWith('@') ? rawHandle : `@${rawHandle}`;
    const creatorName = String(
      input.creatorName || existing?.creatorName || creatorHandle.slice(1),
    );
    const caption = String(input.caption ?? existing?.caption ?? '');
    const mediaType = String(input.mediaType ?? existing?.mediaType ?? 'audio_card');
    const likeCount = Number(input.likeCount ?? existing?.likeCount ?? 0);
    const commentCount = Number(input.commentCount ?? existing?.commentCount ?? 0);
    const cosignCount = Number(input.cosignCount ?? existing?.cosignCount ?? 0);
    const cosignTarget = Number(input.cosignTarget ?? existing?.cosignTarget ?? 25);
    const repostCount = Number(input.repostCount ?? existing?.repostCount ?? 0);
    const discoveryStage = String(
      input.discoveryStage || existing?.discoveryStage || 'freshCrate',
    );
    const createdAt = String(input.publishedAt || input.createdAt || existing?.createdAt || now);
    const mergedPayload = {
      ...(existing ?? {}),
      ...input,
      id,
      creatorId,
      creatorHandle,
      creatorName,
      caption,
      mediaType,
      likeCount,
      commentCount,
      cosignCount,
      cosignTarget,
      repostCount,
      discoveryStage,
      createdAt,
      updatedAt: now,
    };

    const row = {
      id,
      creator_id: creatorId,
      creator_handle: creatorHandle,
      creator_name: creatorName,
      caption,
      media_type: mediaType,
      like_count: likeCount,
      comment_count: commentCount,
      cosign_count: cosignCount,
      cosign_target: cosignTarget,
      repost_count: repostCount,
      discovery_stage: discoveryStage,
      data_json: JSON.stringify(mergedPayload),
      created_at: createdAt,
      updated_at: now,
    };
    this.kineticPosts.set(id, row);

    const createdMs = Date.parse(createdAt) || Date.now();
    const updatedMs = Date.parse(now) || Date.now();
    this.mirrorWriteThrough(async (driver) => {
      await driver.upsertRow(
        'kinetic_posts',
        {
          id,
          creator_id: creatorId,
          creator_name: creatorName,
          creator_handle: creatorHandle,
          avatar_url: String(input.avatarUrl ?? input.creatorAvatarUrl ?? ''),
          track_id: input.trackId ? String(input.trackId) : null,
          track_title: String(input.trackTitle ?? 'Untitled'),
          genre: String(input.genre ?? 'Amapiano'),
          caption,
          audio_preview_url: String(input.audioPreviewUrl ?? ''),
          cover_url: String(input.coverUrl ?? ''),
          like_count: likeCount,
          cosign_count: cosignCount,
          repost_count: repostCount,
          comment_count: commentCount,
          discovery_stage: discoveryStage,
          data_json: mergedPayload,
          created_at: createdMs,
          updated_at: updatedMs,
        },
        'id',
      );
    });

    return this.getKineticPostById(id)!;
  }

  private parseJsonField(raw: unknown): Record<string, any> {
    if (raw && typeof raw === 'object') {
      return { ...(raw as Record<string, any>) };
    }
    try {
      return JSON.parse(String(raw || '{}')) as Record<string, any>;
    } catch {
      return {};
    }
  }

  public getSocialReaction(
    interactionType: 'post_react' | 'comment_react' | 'clip_react',
    targetId: string,
    actorCreatorId = 'creator_cern',
  ): KineticReactionWire | null {
    const key = `${interactionType}::${targetId}::${canonicalizeCreatorId(actorCreatorId)}`;
    return this.socialInteractionReactions.get(key) ?? null;
  }

  public reactToKineticPost(
    postId: string,
    actorCreatorId = 'creator_cern',
    reactionType: KineticReactionWire | null = null,
    skipMirror = false,
  ): KineticReactionMutationResult {
    const post = this.kineticPosts.get(postId);
    if (!post) {
      return {
        success: false,
        targetId: postId,
        myReaction: null,
        reactionCounts: {},
        likeCount: 0,
        liked: false,
      };
    }

    const actor = canonicalizeCreatorId(actorCreatorId);
    const key = `post_react::${postId}::${actor}`;
    const prevReaction = this.socialInteractionReactions.get(key) ?? null;
    const requested = normalizeKineticReactionWire(reactionType);
    const nextReaction: KineticReactionWire | null =
      requested === null || requested === prevReaction ? null : requested;

    const counts = normalizeReactionCounts(
      post.reaction_counts_json ?? this.parseJsonField(post.data_json).reactionCounts,
    );
    const legacyLikeCount = Math.max(0, Number(post.like_count ?? 0));
    if (sumReactionCounts(counts) === 0 && legacyLikeCount > 0) {
      counts.love = legacyLikeCount;
    }

    if (prevReaction) {
      counts[prevReaction] = Math.max(0, counts[prevReaction] - 1);
    }
    if (nextReaction) {
      counts[nextReaction] = counts[nextReaction] + 1;
      this.socialInteractions.add(key);
      this.socialInteractionReactions.set(key, nextReaction);
    } else {
      this.socialInteractions.delete(key);
      this.socialInteractionReactions.delete(key);
    }

    const compact = compactReactionCounts(counts);
    const nextLikes = Math.max(sumReactionCounts(counts), 0);
    post.reaction_counts_json = JSON.stringify(compact);
    post.like_count = nextLikes;
    post.updated_at = new Date().toISOString();

    const parsedData = this.parseJsonField(post.data_json);
    parsedData.reactionCounts = compact;
    parsedData.likeCount = nextLikes;
    post.data_json = JSON.stringify(parsedData);

    if (!skipMirror) {
      this.mirrorWriteThrough('kinetic_posts.react', async (driver) => {
        if (nextReaction) {
          await driver.upsertRow(
            'social_interactions',
            {
              interaction_type: 'post_react',
              target_id: postId,
              actor_creator_id: actor,
              reaction_type: nextReaction,
              created_at: Date.now(),
            },
            'interaction_type,target_id,actor_creator_id',
          );
        } else {
          await driver.deleteRows(
            'social_interactions',
            `interaction_type=eq.post_react&target_id=eq.${encodeURIComponent(postId)}&actor_creator_id=eq.${encodeURIComponent(actor)}`,
          );
        }
        await driver.patchRows(
          'kinetic_posts',
          `id=eq.${encodeURIComponent(postId)}`,
          {
            reaction_counts_json: compact,
            like_count: nextLikes,
            data_json: parsedData,
            updated_at: Date.now(),
          },
        );
      });
    }

    return {
      success: true,
      targetId: postId,
      myReaction: nextReaction,
      reactionCounts: compact,
      likeCount: nextLikes,
      liked: nextReaction !== null,
    };
  }

  public async reactToKineticPostAsync(
    postId: string,
    actorCreatorId = 'creator_cern',
    reactionType: KineticReactionWire | null = null,
    cOrEnv?: unknown,
  ): Promise<KineticReactionMutationResult> {
    const result = this.reactToKineticPost(
      postId,
      actorCreatorId,
      reactionType,
      true,
    );
    if (!result.success) return result;
    const actor = canonicalizeCreatorId(actorCreatorId);
    const post = this.kineticPosts.get(postId);
    const parsedData = post ? this.parseJsonField(post.data_json) : {};
    await this.awaitWriteThrough(
      'kinetic_posts.react',
      async (driver) => {
        await Promise.all([
          result.myReaction
            ? driver.upsertRow(
              'social_interactions',
              {
                interaction_type: 'post_react',
                target_id: postId,
                actor_creator_id: actor,
                reaction_type: result.myReaction,
                created_at: Date.now(),
              },
              'interaction_type,target_id,actor_creator_id',
            )
            : driver.deleteRows(
              'social_interactions',
              `interaction_type=eq.post_react&target_id=eq.${encodeURIComponent(postId)}&actor_creator_id=eq.${encodeURIComponent(actor)}`,
            ),
          driver.patchRows(
            'kinetic_posts',
            `id=eq.${encodeURIComponent(postId)}`,
            {
              reaction_counts_json: result.reactionCounts,
              like_count: result.likeCount,
              data_json: parsedData,
              updated_at: Date.now(),
            },
          ),
        ]);
      },
      cOrEnv,
    );
    return result;
  }

  public likeKineticPost(
    postId: string,
    actorCreatorId = 'creator_cern',
  ): { success: boolean; postId: string; liked: boolean; likeCount: number } {
    const post = this.kineticPosts.get(postId);
    if (!post) {
      return { success: false, postId, liked: false, likeCount: 0 };
    }
    const actor = canonicalizeCreatorId(actorCreatorId);
    const liked = this.toggleSocialInteraction('post_like', postId, actor);
    const nextLikes = Math.max(0, Number(post.like_count ?? 0) + (liked ? 1 : -1));
    post.like_count = nextLikes;
    post.updated_at = new Date().toISOString();
    this.mirrorWriteThrough(async (driver) => {
      await driver.patchRows(
        'kinetic_posts',
        `id=eq.${encodeURIComponent(postId)}`,
        { like_count: nextLikes, updated_at: Date.now() },
      );
    });
    return { success: true, postId, liked, likeCount: nextLikes };
  }

  public repostPost(
    postId: string,
    repostPayload?: Record<string, any>,
  ): {
    success: boolean;
    postId: string;
    repostCount: number;
    repost?: Record<string, any>;
  } {
    const post = this.kineticPosts.get(postId);
    if (!post) {
      return { success: false, postId, repostCount: 0 };
    }
    const newCount = Number(post.repost_count || 0) + 1;
    post.repost_count = newCount;
    post.updated_at = new Date().toISOString();
    this.mirrorWriteThrough(async (driver) => {
      await driver.patchRows(
        'kinetic_posts',
        `id=eq.${encodeURIComponent(postId)}`,
        {
          repost_count: newCount,
          updated_at: Date.now(),
        },
      );
    });
    let createdRepost: Record<string, any> | undefined;
    if (repostPayload && typeof repostPayload === 'object') {
      createdRepost = this.upsertKineticPost({
        ...repostPayload,
        repostedFromPostId: repostPayload.repostedFromPostId ?? postId,
      });
    }
    return {
      success: true,
      postId,
      repostCount: newCount,
      ...(createdRepost ? { repost: createdRepost } : {}),
    };
  }

  public getKineticPostComments(
    postId: string,
    viewerCreatorId = 'creator_cern',
    sort: 'relevant' | 'newest' = 'relevant',
  ): Record<string, any>[] {
    const canonicalViewer = canonicalizeCreatorId(viewerCreatorId);
    const likedComments = this.listSocialInteractionTargets(
      'comment_like',
      canonicalViewer,
    );
    const comments: Record<string, any>[] = this.listReelCommentsByClip(postId).map(
      (c): Record<string, any> => {
        const myReaction = this.getSocialReaction(
          'comment_react',
          String(c.id),
          canonicalViewer,
        );
        const isLegacyLiked = likedComments.has(String(c.id));
        return {
          ...c,
          myReaction: myReaction ?? (isLegacyLiked ? 'love' : null),
          isLikedByMe: myReaction !== null || isLegacyLiked,
        };
      },
    );
    const replyCounts = new Map<string, number>();
    for (const c of comments) {
      if (c.parentCommentId) {
        const pid = String(c.parentCommentId);
        replyCounts.set(pid, (replyCounts.get(pid) ?? 0) + 1);
      }
    }
    if (sort === 'newest') {
      comments.sort((a, b) =>
        String(b.createdAt).localeCompare(String(a.createdAt)),
      );
      return comments;
    }
    const nowMs = Date.now();
    const scoreOf = (c: Record<string, any>): number => {
      const createdMs = Date.parse(String(c.createdAt)) || nowMs;
      const ageHours = Math.max(0, (nowMs - createdMs) / 3600000);
      const recencyBonus = Math.max(0, 12.0 - 0.25 * ageHours);
      const replies = replyCounts.get(String(c.id)) ?? 0;
      const creatorBonus = c.isCreator ? 8.0 : 0.0;
      return (
        2.0 * Number(c.likeCount ?? 0) +
        3.5 * replies +
        creatorBonus +
        1.5 * Number(c.userReelLoves ?? 0) +
        recencyBonus
      );
    };
    comments.sort((a, b) => {
      const diff = scoreOf(b) - scoreOf(a);
      if (diff !== 0) return diff;
      return String(b.createdAt).localeCompare(String(a.createdAt));
    });
    return comments;
  }

  public addKineticPostComment(
    postId: string,
    input: Record<string, any>,
  ): Record<string, any> | null {
    const post = this.getKineticPostById(postId);
    if (!post) return null;

    const now = new Date().toISOString();
    const commentId = String(input.id || `c_${randomUUID().slice(0, 8)}`);
    const userId = canonicalizeCreatorId(String(input.userId || 'creator_cern'));
    const rawUsername = String(
      input.username || userId.replace(/^creator_/, ''),
    ).replace(/^@+/, '');
    const postCreatorHandle = String(post.creatorHandle || '')
      .replace(/^@+/, '')
      .toLowerCase();
    const isCreator =
      Boolean(input.isCreator) ||
      userId === canonicalizeCreatorId(String(post.creatorId)) ||
      (postCreatorHandle.length > 0 &&
        postCreatorHandle === rawUsername.toLowerCase());

    const parentCommentId = input.parentCommentId
      ? String(input.parentCommentId).trim() || undefined
      : undefined;
    const replyToHandle = input.replyToHandle
      ? String(input.replyToHandle).trim() || undefined
      : undefined;
    const gifUrl = input.gifUrl ? String(input.gifUrl).trim() || undefined : undefined;
    const stickerId = input.stickerId
      ? String(input.stickerId).trim() || undefined
      : undefined;
    const mediaAspectRatio =
      typeof input.mediaAspectRatio === 'number' &&
        Number.isFinite(input.mediaAspectRatio)
        ? input.mediaAspectRatio
        : undefined;

    const comment: Record<string, any> = {
      id: commentId,
      clipId: postId,
      postId,
      userId,
      username: rawUsername,
      displayName: String(input.displayName || rawUsername),
      avatarUrl: input.avatarUrl ? String(input.avatarUrl) : undefined,
      isCreator,
      text: String(input.text ?? input.content ?? '').trim(),
      likeCount: Number(input.likeCount ?? 0),
      isLikedByMe: false,
      reactionCounts: compactReactionCounts(
        normalizeReactionCounts(input.reactionCounts),
      ),
      myReaction: null,
      ...(gifUrl ? { gifUrl } : {}),
      ...(stickerId ? { stickerId } : {}),
      ...(mediaAspectRatio ? { mediaAspectRatio } : {}),
      userReelLoves: Number(input.userReelLoves ?? 0),
      ...(parentCommentId ? { parentCommentId } : {}),
      ...(replyToHandle ? { replyToHandle } : {}),
      createdAt: String(input.createdAt || now),
    };

    this.insertReelComment(comment);
    const postRow = this.kineticPosts.get(postId);
    const nextComments = Number(post.commentCount ?? 0) + 1;
    if (postRow) {
      postRow.comment_count = nextComments;
      postRow.updated_at = now;
    }
    this.mirrorWriteThrough(async (driver) => {
      await driver.patchRows(
        'kinetic_posts',
        `id=eq.${encodeURIComponent(postId)}`,
        { comment_count: nextComments, updated_at: Date.now() },
      );
    });
    return comment;
  }

  public reactToComment(
    commentId: string,
    actorCreatorId = 'creator_cern',
    reactionType: KineticReactionWire | null = null,
    skipMirror = false,
  ): KineticReactionMutationResult | null {
    const comment = this.getReelCommentById(commentId);
    if (!comment) return null;

    const actor = canonicalizeCreatorId(actorCreatorId);
    const key = `comment_react::${commentId}::${actor}`;
    const prevReaction = this.socialInteractionReactions.get(key) ?? null;
    const requested = normalizeKineticReactionWire(reactionType);
    const nextReaction: KineticReactionWire | null =
      requested === null || requested === prevReaction ? null : requested;

    const counts = normalizeReactionCounts(comment.reactionCounts);
    const legacyLikeCount = Math.max(0, Number(comment.likeCount ?? 0));
    if (sumReactionCounts(counts) === 0 && legacyLikeCount > 0) {
      counts.love = legacyLikeCount;
    }

    if (prevReaction) {
      counts[prevReaction] = Math.max(0, counts[prevReaction] - 1);
    }
    if (nextReaction) {
      counts[nextReaction] = counts[nextReaction] + 1;
      this.socialInteractions.add(key);
      this.socialInteractionReactions.set(key, nextReaction);
    } else {
      this.socialInteractions.delete(key);
      this.socialInteractionReactions.delete(key);
    }

    const compact = compactReactionCounts(counts);
    const nextLikes = Math.max(sumReactionCounts(counts), 0);
    this.insertReelComment({
      ...comment,
      likeCount: nextLikes,
      reactionCounts: compact,
    });

    if (!skipMirror) {
      this.mirrorWriteThrough('reel_comments.react', async (driver) => {
        if (nextReaction) {
          await driver.upsertRow(
            'social_interactions',
            {
              interaction_type: 'comment_react',
              target_id: commentId,
              actor_creator_id: actor,
              reaction_type: nextReaction,
              created_at: Date.now(),
            },
            'interaction_type,target_id,actor_creator_id',
          );
        } else {
          await driver.deleteRows(
            'social_interactions',
            `interaction_type=eq.comment_react&target_id=eq.${encodeURIComponent(commentId)}&actor_creator_id=eq.${encodeURIComponent(actor)}`,
          );
        }
      });
    }

    return {
      success: true,
      targetId: commentId,
      myReaction: nextReaction,
      reactionCounts: compact,
      likeCount: nextLikes,
      liked: nextReaction !== null,
    };
  }

  public async reactToCommentAsync(
    commentId: string,
    actorCreatorId = 'creator_cern',
    reactionType: KineticReactionWire | null = null,
    cOrEnv?: unknown,
  ): Promise<KineticReactionMutationResult | null> {
    const result = this.reactToComment(
      commentId,
      actorCreatorId,
      reactionType,
      true,
    );
    if (!result) return null;
    const actor = canonicalizeCreatorId(actorCreatorId);
    const comment = this.getReelCommentById(commentId);
    await this.awaitWriteThrough(
      'reel_comments.react',
      async (driver) => {
        await Promise.all([
          result.myReaction
            ? driver.upsertRow(
              'social_interactions',
              {
                interaction_type: 'comment_react',
                target_id: commentId,
                actor_creator_id: actor,
                reaction_type: result.myReaction,
                created_at: Date.now(),
              },
              'interaction_type,target_id,actor_creator_id',
            )
            : driver.deleteRows(
              'social_interactions',
              `interaction_type=eq.comment_react&target_id=eq.${encodeURIComponent(commentId)}&actor_creator_id=eq.${encodeURIComponent(actor)}`,
            ),
          driver.patchRows(
            'reel_comments',
            `id=eq.${encodeURIComponent(commentId)}`,
            {
              reaction_counts_json: result.reactionCounts,
              likes_count: result.likeCount,
              data_json: comment ?? {},
            },
          ),
        ]);
      },
      cOrEnv,
    );
    return result;
  }

  public likeCommentById(
    commentId: string,
    actorCreatorId = 'creator_cern',
  ): { liked: boolean; likeCount: number } | null {
    const comment = this.getReelCommentById(commentId);
    if (!comment) return null;
    const actor = canonicalizeCreatorId(actorCreatorId);
    const liked = this.toggleSocialInteraction('comment_like', commentId, actor);
    const likeCount = Math.max(0, Number(comment.likeCount ?? 0) + (liked ? 1 : -1));
    this.insertReelComment({
      ...comment,
      likeCount,
    });
    return { liked, likeCount };
  }

  // ---------------------------------------------------------------------------
  // Cloud Vault Library Sync
  // ---------------------------------------------------------------------------

  public getLibrary(creatorId: string): any[] {
    const cid = canonicalizeCreatorId(creatorId);
    const rows = Array.from(this.libraryItems.values())
      .filter((r) => canonicalizeCreatorId(String(r.creator_id)) === cid)
      .sort((a, b) => String(b.updated_at).localeCompare(String(a.updated_at)));
    return rows.map((r) => {
      let data: Record<string, any> = {};
      try {
        data = JSON.parse(String(r.data_json || '{}'));
      } catch {
        data = {};
      }
      return {
        id: r.id,
        creatorId: canonicalizeCreatorId(String(r.creator_id)),
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
    const existing = this.libraryItems.get(id);
    if (!existing) return false;
    const canonicalCreator = creatorId ? canonicalizeCreatorId(creatorId) : undefined;
    if (
      canonicalCreator &&
      canonicalizeCreatorId(String(existing.creator_id)) !== canonicalCreator
    ) {
      return false;
    }
    this.libraryItems.delete(id);
    this.mirrorWriteThrough('user_library_sync.delete', async (driver) => {
      const creatorFilter = canonicalCreator
        ? `&creator_id=eq.${encodeURIComponent(canonicalCreator)}`
        : '';
      await driver.deleteRows(
        'user_library_sync',
        `id=eq.${encodeURIComponent(id)}${creatorFilter}`,
      );
    });
    if (recordMutation) {
      const now = new Date().toISOString();
      const effectiveCreator = creatorId || 'creator_cern';
      this.appendMutation({
        idempotencyKey: `lib_del_${id}_${Date.now()}_${this.seqCounter + 1}`,
        entityType: 'library_track',
        entityId: id,
        action: 'delete',
        payload: { id, creatorId: effectiveCreator, hardDelete: true },
        creatorId: effectiveCreator,
        createdAt: now,
      });
    }
    return true;
  }

  public getLibraryItemOwnerCreatorId(id: string): string | null {
    const row = this.libraryItems.get(id);
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

    for (const item of incomingItems || []) {
      const id = String(
        item.id || `lib_${Date.now()}_${appliedCount + skippedCount}`,
      );
      const existingRow = this.libraryItems.get(id);
      const incomingUpdatedAtMs = toMillis(
        item.updatedAtMs,
        item.updatedAt || item.deletedAt || item.createdAt,
      );

      let existingData: Record<string, any> = {};
      let existingUpdatedAtMs = -1;
      if (existingRow) {
        try {
          existingData = JSON.parse(String(existingRow.data_json || '{}'));
        } catch {
          existingData = {};
        }
        existingUpdatedAtMs = toMillis(
          existingData.updatedAtMs,
          existingRow.updated_at || existingData.updatedAt,
        );
      }

      if (existingRow && incomingUpdatedAtMs < existingUpdatedAtMs) {
        skippedCount++;
        continue;
      }

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
      const title = String(
        merged.title || existingRow?.title || 'Untitled Track',
      );
      const createdAt = String(
        merged.createdAt || existingRow?.created_at || now,
      );
      const updatedAtIso = String(merged.updatedAt);

      const effectiveCreator = existingRow?.creator_id ?? creatorId;
      this.libraryItems.set(id, {
        id,
        creator_id: effectiveCreator,
        item_type: itemType,
        title,
        data_json: JSON.stringify(merged),
        created_at: createdAt,
        updated_at: updatedAtIso,
      });

      this.mirrorWriteThrough('user_library_sync.upsert', async (driver) => {
        await driver.upsertRow(
          'user_library_sync',
          {
            id,
            creator_id: effectiveCreator,
            item_type: itemType,
            title,
            artist: String(merged.artistName || merged.artist || 'Vhunambi Creator'),
            genre: String(merged.genre || 'Amapiano'),
            bpm: Math.round(Number(merged.bpm ?? 113)),
            duration_sec: Math.round(Number(merged.durationSec ?? 180)),
            audio_url: String(merged.remoteAudioUrl || merged.audioUrl || merged.masterMp3Url || ''),
            cover_url: String(merged.coverUrl || ''),
            is_favorite: Boolean(merged.isFavorite ?? false),
            is_downloaded: Boolean(merged.isDownloaded ?? false),
            play_count: mergedPlayCount,
            is_licensed_beat: Boolean(merged.isLicensedBeat ?? false),
            license_tier: merged.licenseTier ? String(merged.licenseTier) : null,
            certificate_id: merged.certificateId ? String(merged.certificateId) : null,
            license_hash: merged.licenseHash ? String(merged.licenseHash) : null,
            master_file_sha256: merged.masterFileSha256 ? String(merged.masterFileSha256) : null,
            stems_json: merged.stemFilesJson ?? merged.stems ?? {},
            data_json: merged,
            created_at: Date.parse(createdAt) || incomingUpdatedAtMs,
            updated_at: incomingUpdatedAtMs,
          },
          'id,creator_id',
        );
      });

      if (recordMutation) {
        this.appendMutation({
          idempotencyKey: `lib_sync_${id}_${incomingUpdatedAtMs}_${this.seqCounter + 1}`,
          entityType: 'library_track',
          entityId: id,
          action: existingRow ? 'update' : 'create',
          payload: merged,
          creatorId,
          createdAt: now,
        });
      }
      appliedCount++;
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
  // Playlists Cloud CRUD & Public Share Links
  // ---------------------------------------------------------------------------

  private mapPlaylistRow(r: Record<string, any>): Record<string, any> {
    let trackIds: string[] = [];
    try {
      const parsed = JSON.parse(String(r.track_ids_json ?? '[]'));
      if (Array.isArray(parsed)) trackIds = parsed.map((e) => String(e));
    } catch {
      trackIds = [];
    }

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

  public getPlaylists(
    creatorId?: string,
    includePublic: boolean = true,
  ): any[] {
    const cid =
      creatorId && creatorId.trim() !== ''
        ? canonicalizeCreatorId(creatorId)
        : '';
    let rows = Array.from(this.playlists.values());
    if (cid) {
      rows = includePublic
        ? rows.filter(
          (r) =>
            canonicalizeCreatorId(String(r.creator_id)) === cid ||
            Number(r.is_public ?? 0) === 1,
        )
        : rows.filter(
          (r) => canonicalizeCreatorId(String(r.creator_id)) === cid,
        );
    }
    rows.sort((a, b) =>
      String(b.updated_at).localeCompare(String(a.updated_at)),
    );
    return rows.map((r) => this.mapPlaylistRow(r));
  }

  public getPlaylistById(id: string): Record<string, any> | null {
    const direct = this.playlists.get(id);
    if (direct) return this.mapPlaylistRow(direct);
    for (const r of this.playlists.values()) {
      if (r.share_code === id) return this.mapPlaylistRow(r);
    }
    return null;
  }

  public upsertPlaylist(
    input: Record<string, any>,
    recordMutation: boolean = true,
  ): Record<string, any> {
    const now = new Date().toISOString();
    const id = String(input.id || `pl_${Date.now()}_${randomUUID().slice(0, 6)}`);
    const existing = this.playlists.get(id);

    const creatorId = canonicalizeCreatorId(
      String(
        input.creatorId ?? input.creator_id ?? existing?.creator_id ?? 'creator_cern',
      ),
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

    this.playlists.set(id, {
      id,
      creator_id: existing?.creator_id ?? creatorId,
      title,
      description,
      cover_image_url: coverImageUrl,
      track_ids_json: JSON.stringify(trackIds),
      is_public: isPublic ? 1 : 0,
      share_code: shareCode,
      share_url: shareUrl,
      created_at: createdAt,
      updated_at: updatedAt,
    });

    const mapped = this.getPlaylistById(id)!;
    this.mirrorWriteThrough('playlists.upsert', async (driver) => {
      await driver.upsertRow(
        'playlists',
        {
          id,
          creator_id: canonicalizeCreatorId(String(mapped.creatorId)),
          title: mapped.title,
          description: mapped.description,
          cover_url: String(mapped.coverImageUrl ?? ''),
          track_ids_json: mapped.trackIds,
          is_public: Boolean(mapped.isPublic),
          share_code: mapped.shareCode ? String(mapped.shareCode) : `priv_${id}`,
          data_json: mapped,
          created_at: Date.parse(String(mapped.createdAt)) || Date.now(),
          updated_at: Date.parse(String(mapped.updatedAt)) || Date.now(),
        },
        'id',
      );
    });
    if (recordMutation) {
      this.appendMutation({
        idempotencyKey: `pl_upsert_${id}_${Date.now()}_${this.seqCounter + 1}`,
        entityType: 'playlist',
        entityId: id,
        action: existing ? 'update' : 'create',
        payload: mapped,
        creatorId,
        createdAt: now,
      });
    }
    return mapped;
  }

  public getPlaylistOwnerCreatorId(id: string): string | null {
    const row = this.getPlaylistById(id);
    return row ? String(row.creatorId) : null;
  }

  public deletePlaylist(
    id: string,
    creatorId?: string,
    recordMutation: boolean = true,
  ): boolean {
    const existing = this.playlists.get(id);
    if (!existing) return false;
    const canonicalCreator =
      creatorId && creatorId.trim() !== ''
        ? canonicalizeCreatorId(creatorId)
        : undefined;
    if (
      canonicalCreator &&
      canonicalizeCreatorId(String(existing.creator_id)) !== canonicalCreator
    ) {
      return false;
    }
    this.playlists.delete(id);
    this.mirrorWriteThrough('playlists.delete', async (driver) => {
      await driver.deleteRows('playlists', `id=eq.${encodeURIComponent(id)}`);
    });
    if (recordMutation) {
      const now = new Date().toISOString();
      const effectiveCreator = canonicalCreator || 'creator_cern';
      this.appendMutation({
        idempotencyKey: `pl_del_${id}_${Date.now()}_${this.seqCounter + 1}`,
        entityType: 'playlist',
        entityId: id,
        action: 'delete',
        payload: { id, creatorId: effectiveCreator },
        creatorId: effectiveCreator,
        createdAt: now,
      });
    }
    return true;
  }

  public sharePlaylist(id: string): Record<string, any> | null {
    const existing = this.getPlaylistById(id);
    if (!existing) return null;
    const raw = this.playlists.get(existing.id);
    if (!raw) return null;
    const now = new Date().toISOString();
    const shareCode =
      existing.shareCode ||
      `VH-${createHash('sha256')
        .update(`${id}|${now}|${randomUUID()}`)
        .digest('hex')
        .slice(0, 8)
        .toUpperCase()}`;
    const shareUrl = `https://vhunambi.za/p/${shareCode}`;

    raw.is_public = 1;
    raw.share_code = shareCode;
    raw.share_url = shareUrl;
    raw.updated_at = now;

    const updated = this.getPlaylistById(existing.id)!;
    this.mirrorWriteThrough('playlists.share', async (driver) => {
      await driver.upsertRow(
        'playlists',
        {
          id: existing.id,
          creator_id: String(updated.creatorId ?? existing.creatorId ?? 'usr_me'),
          title: String(updated.title ?? 'Untitled Playlist'),
          description: String(updated.description ?? ''),
          cover_url: String(updated.coverImageUrl ?? ''),
          track_ids_json: updated.trackIds ?? [],
          is_public: true,
          share_code: shareCode,
          data_json: updated,
          created_at: Date.parse(String(updated.createdAt)) || Date.now(),
          updated_at: Date.parse(now) || Date.now(),
        },
        'id',
      );
    });
    this.appendMutation({
      idempotencyKey: `pl_share_${existing.id}_${Date.now()}_${this.seqCounter + 1}`,
      entityType: 'playlist',
      entityId: existing.id,
      action: 'update',
      payload: updated,
      creatorId: String(updated.creatorId ?? existing.creatorId ?? 'system'),
      createdAt: now,
    });
    return updated;
  }

  // ---------------------------------------------------------------------------
  // Sovereign Creator Wallet Ledger & SA Banking Gateway
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
    const rows = [...(this.walletLedger.get(creatorId) ?? [])].sort((a, b) =>
      String(b.created_at).localeCompare(String(a.created_at)),
    );

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
          balanceZar += Number(r.amount_zar ?? 0);
          balanceCoins += Number(r.amount_coins ?? 0);
        }
      } else if (r.type === 'payout' || r.type === 'payout_withdrawal') {
        const debitZar = Math.abs(Number(r.amount_zar ?? 0));
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
    const rows = [...(this.walletLedger.get(resolvedId) ?? [])]
      .sort((a, b) => String(b.created_at).localeCompare(String(a.created_at)))
      .slice(0, 50);

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
    const senderList = this.walletLedger.get(senderId) ?? [];
    senderList.unshift({
      id: `wtx_tip_out_${params.tipId}`,
      creator_id: senderId,
      type: 'tip_sent',
      amount_zar: -zar,
      amount_coins: -coins,
      status: 'completed',
      reference: params.tipId,
      data_json: JSON.stringify({
        direction: 'sent',
        clipId: params.clipId,
        senderId,
        senderUsername:
          params.senderUsername ?? `@${senderId.replace(/^creator_/, '')}`,
        recipientId,
        giftId: params.giftId,
        giftName: params.giftName,
        giftEmoji: params.giftEmoji,
        message: params.message,
      }),
      created_at: nowIso,
    });
    this.walletLedger.set(senderId, senderList);

    let primaryCoins = coins;
    let ancestorCoins = 0;
    if (ancestorId && ancestorId !== recipientId) {
      primaryCoins = Math.floor(coins * 0.7);
      ancestorCoins = coins - primaryCoins;
      const primaryZar = Number((zar * 0.7).toFixed(2));
      const ancestorZar = Number((zar - primaryZar).toFixed(2));

      const recipientList = this.walletLedger.get(recipientId) ?? [];
      recipientList.unshift({
        id: `wtx_tip_in_${params.tipId}`,
        creator_id: recipientId,
        type: 'tip_received',
        amount_zar: primaryZar,
        amount_coins: primaryCoins,
        status: 'completed',
        reference: params.tipId,
        data_json: JSON.stringify({
          direction: 'received',
          clipId: params.clipId,
          senderId,
          senderUsername:
            params.senderUsername ?? `@${senderId.replace(/^creator_/, '')}`,
          giftId: params.giftId,
          giftName: params.giftName,
          giftEmoji: params.giftEmoji,
          message: params.message,
          splitPct: 70,
        }),
        created_at: nowIso,
      });
      this.walletLedger.set(recipientId, recipientList);

      const ancestorList = this.walletLedger.get(ancestorId) ?? [];
      ancestorList.unshift({
        id: `wtx_tip_anc_${params.tipId}`,
        creator_id: ancestorId,
        type: 'remix_royalty',
        amount_zar: ancestorZar,
        amount_coins: ancestorCoins,
        status: 'completed',
        reference: params.tipId,
        data_json: JSON.stringify({
          direction: 'remix_royalty',
          clipId: params.clipId,
          senderId,
          senderUsername:
            params.senderUsername ?? `@${senderId.replace(/^creator_/, '')}`,
          giftId: params.giftId,
          giftName: params.giftName,
          giftEmoji: params.giftEmoji,
          message: params.message,
          splitPct: 30,
        }),
        created_at: nowIso,
      });
      this.walletLedger.set(ancestorId, ancestorList);
    } else {
      const recipientList = this.walletLedger.get(recipientId) ?? [];
      recipientList.unshift({
        id: `wtx_tip_in_${params.tipId}`,
        creator_id: recipientId,
        type: 'tip_received',
        amount_zar: zar,
        amount_coins: coins,
        status: 'completed',
        reference: params.tipId,
        data_json: JSON.stringify({
          direction: 'received',
          clipId: params.clipId,
          senderId,
          senderUsername:
            params.senderUsername ?? `@${senderId.replace(/^creator_/, '')}`,
          giftId: params.giftId,
          giftName: params.giftName,
          giftEmoji: params.giftEmoji,
          message: params.message,
          splitPct: 100,
        }),
        created_at: nowIso,
      });
      this.walletLedger.set(recipientId, recipientList);
    }

    const senderSnapBeforeTip = senderSnap;
    this.mirrorWriteThrough(async (driver) => {
      await this.ensureCreatorRowInSupabase(driver, senderId);
      await this.ensureCreatorRowInSupabase(driver, recipientId);
      if (ancestorId) {
        await this.ensureCreatorRowInSupabase(driver, ancestorId);
      }
      try {
        await driver.callRpc('send_cultural_tip_atomic', {
          p_tip_id: params.tipId,
          p_clip_id: params.clipId,
          p_sender_id: senderId,
          p_recipient_id: recipientId,
          p_ancestor_id: ancestorId ?? null,
          p_amount_coins: coins,
          p_amount_zar: zar,
          p_gift_name: params.giftName,
          p_gift_emoji: params.giftEmoji,
        });
      } catch {
        // Fallback mirror if seeded creator balance hasn't been topped up in PG ledger yet
        const ledgerEntries: Array<Record<string, unknown>> = [
          {
            id: `wtx_tip_out_${params.tipId}`,
            creator_id: senderId,
            amount_zar: -zar,
            amount_coins: -coins,
            type: 'tip_sent',
            reference: params.tipId,
            status: 'completed',
            metadata_json: {
              clipId: params.clipId,
              recipientId,
              giftName: params.giftName,
            },
          },
          {
            id: `wtx_tip_in_${params.tipId}`,
            creator_id: recipientId,
            amount_zar: ancestorId && ancestorId !== recipientId ? Number((zar * 0.7).toFixed(2)) : zar,
            amount_coins: primaryCoins,
            type: 'tip_received',
            reference: params.tipId,
            status: 'completed',
            metadata_json: {
              clipId: params.clipId,
              senderId,
              giftName: params.giftName,
            },
          },
        ];
        if (ancestorId && ancestorId !== recipientId && ancestorCoins > 0) {
          ledgerEntries.push({
            id: `wtx_tip_anc_${params.tipId}`,
            creator_id: ancestorId,
            amount_zar: Number((zar - Number((zar * 0.7).toFixed(2))).toFixed(2)),
            amount_coins: ancestorCoins,
            type: 'remix_royalty',
            reference: params.tipId,
            status: 'completed',
            metadata_json: {
              clipId: params.clipId,
              senderId,
              giftName: params.giftName,
            },
          });
        }
        await driver.upsertRow('wallet_ledger', ledgerEntries, 'id');
      }
    });

    return {
      outcome: 'committed',
      senderRemainingCoins: senderSnapBeforeTip.balanceCoins - coins,
      primaryCoins,
      ancestorCoins,
    };
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
    this.payfastCheckouts.set(params.checkoutId, {
      checkoutId: params.checkoutId,
      creatorId,
      provider: 'payfast',
      providerPaymentId: null,
      packId: params.packId,
      amountZar: params.amountZar,
      coinsGranted: params.coinsGranted,
      status: 'pending',
      signatureMd5: params.signatureMd5,
      verifiedAt: null,
      createdAt: nowIso,
    });
    this.mirrorWriteThrough(async (driver) => {
      await this.ensureCreatorRowInSupabase(driver, creatorId);
      await driver.upsertRow(
        'payment_topups',
        {
          checkout_id: params.checkoutId,
          creator_id: creatorId,
          provider: 'payfast',
          provider_payment_id: null,
          pack_id: params.packId,
          amount_zar: params.amountZar,
          coins_granted: params.coinsGranted,
          status: 'pending',
          signature_md5: params.signatureMd5,
          raw_itn_json: {},
          created_at: nowIso,
        },
        'checkout_id',
      );
    });
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
    const r = this.payfastCheckouts.get(checkoutId);
    if (!r) return null;
    return {
      checkoutId: String(r.checkoutId),
      creatorId: String(r.creatorId),
      provider: String(r.provider),
      providerPaymentId: r.providerPaymentId ? String(r.providerPaymentId) : null,
      packId: String(r.packId),
      amountZar: Number(r.amountZar),
      coinsGranted: Number(r.coinsGranted),
      status: String(r.status),
      signatureMd5: String(r.signatureMd5),
      verifiedAt: r.verifiedAt ? String(r.verifiedAt) : null,
      createdAt: String(r.createdAt),
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
    const existingCheckoutId = this.payfastByPfId.get(params.pfPaymentId);
    if (existingCheckoutId) {
      const prev = this.payfastCheckouts.get(existingCheckoutId);
      if (prev && prev.status === 'completed') {
        const snap = this.getWallet(String(prev.creatorId));
        return {
          outcome: 'idempotent_replay',
          creatorId: String(prev.creatorId),
          coinsCredited: Number(prev.coinsGranted),
          balanceCoins: snap.balanceCoins,
          balanceZar: snap.balanceZar,
        };
      }
    }

    const checkout = this.payfastCheckouts.get(params.checkoutId);
    if (!checkout) {
      return { outcome: 'checkout_not_found' };
    }
    if (checkout.status === 'completed') {
      const snap = this.getWallet(String(checkout.creatorId));
      return {
        outcome: 'idempotent_replay',
        creatorId: String(checkout.creatorId),
        coinsCredited: Number(checkout.coinsGranted),
        balanceCoins: snap.balanceCoins,
        balanceZar: snap.balanceZar,
      };
    }
    if (Math.abs(Number(checkout.amountZar) - params.amountGrossZar) > 0.01) {
      return { outcome: 'amount_mismatch' };
    }

    const nowIso = new Date().toISOString();
    checkout.status = 'completed';
    checkout.providerPaymentId = params.pfPaymentId;
    checkout.rawItnPayload = params.rawItnPayload;
    checkout.verifiedAt = nowIso;
    this.payfastByPfId.set(params.pfPaymentId, checkout.checkoutId);

    const rows = this.walletLedger.get(String(checkout.creatorId)) ?? [];
    rows.unshift({
      id: `wtx_pf_${params.pfPaymentId}`,
      creator_id: String(checkout.creatorId),
      type: 'topup',
      amount_zar: Number(checkout.amountZar),
      amount_coins: Number(checkout.coinsGranted),
      status: 'completed',
      reference: `PF-ITN-${params.pfPaymentId}`,
      data_json: JSON.stringify({
        checkoutId: checkout.checkoutId,
        packId: checkout.packId,
        pfPaymentId: params.pfPaymentId,
      }),
      created_at: nowIso,
    });
    this.walletLedger.set(String(checkout.creatorId), rows);

    const topupCreatorId = String(checkout.creatorId);
    this.mirrorWriteThrough(async (driver) => {
      await this.ensureCreatorRowInSupabase(driver, topupCreatorId);
      await driver.patchRows(
        'payment_topups',
        `checkout_id=eq.${encodeURIComponent(checkout.checkoutId)}`,
        {
          status: 'completed',
          provider_payment_id: params.pfPaymentId,
          raw_itn_json: params.rawItnPayload,
          verified_at: nowIso,
        },
      );
      await driver.upsertRow(
        'wallet_ledger',
        {
          id: `wtx_pf_${params.pfPaymentId}`,
          creator_id: topupCreatorId,
          amount_zar: Number(checkout.amountZar),
          amount_coins: Number(checkout.coinsGranted),
          type: 'topup',
          reference: `PF-ITN-${params.pfPaymentId}`,
          status: 'completed',
          metadata_json: {
            checkoutId: checkout.checkoutId,
            packId: checkout.packId,
            pfPaymentId: params.pfPaymentId,
          },
          created_at: nowIso,
        },
        'id',
      );
    });

    const snap = this.getWallet(String(checkout.creatorId));
    return {
      outcome: 'settled',
      creatorId: String(checkout.creatorId),
      coinsCredited: Number(checkout.coinsGranted),
      balanceCoins: snap.balanceCoins,
      balanceZar: snap.balanceZar,
    };
  }

  public topupWallet(
    creatorId: string,
    amountZar: number,
    amountCoins: number,
  ): ReturnType<EdgeIsolateDatabaseEngine['getWallet']> {
    const now = new Date().toISOString();
    const id = `tx_${Date.now()}_${randomUUID().slice(0, 8)}`;
    const rows = this.walletLedger.get(creatorId) ?? [];
    rows.unshift({
      id,
      creator_id: creatorId,
      type: 'topup',
      amount_zar: amountZar,
      amount_coins: amountCoins,
      status: 'completed',
      reference: 'INSTANT_TOPUP',
      data_json: '{}',
      created_at: now,
    });
    this.walletLedger.set(creatorId, rows);
    const canonicalCreator = canonicalizeCreatorId(creatorId);
    this.mirrorWriteThrough(async (driver) => {
      await this.ensureCreatorRowInSupabase(driver, canonicalCreator);
      await driver.upsertRow(
        'wallet_ledger',
        {
          id,
          creator_id: canonicalCreator,
          amount_zar: amountZar,
          amount_coins: amountCoins,
          type: 'topup',
          reference: 'INSTANT_TOPUP',
          status: 'completed',
          metadata_json: {},
          created_at: now,
        },
        'id',
      );
    });
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

    const normalizedRail = String(req.paymentRail || 'eft')
      .trim()
      .toLowerCase();
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

    const currentWallet = this.getWallet(req.creatorId);
    if (req.amountZar > currentWallet.balanceZar) {
      return {
        success: false,
        error: `Insufficient ZAR balance. Requested R${req.amountZar.toFixed(2)}, available R${currentWallet.balanceZar.toFixed(2)}`,
      };
    }

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

    this.bankAccounts.set(bankAccountId, {
      id: bankAccountId,
      creatorId: req.creatorId,
      ...receiptPayload,
      updatedAt: now,
    });

    const rows = this.walletLedger.get(req.creatorId) ?? [];
    rows.unshift({
      id: payoutId,
      creator_id: req.creatorId,
      type: 'payout',
      amount_zar: req.amountZar,
      amount_coins: 0,
      status: ledgerStatus,
      reference: gatewayRef,
      data_json: JSON.stringify(receiptPayload),
      created_at: now,
    });
    this.walletLedger.set(req.creatorId, rows);

    this.appendMutation({
      idempotencyKey: `payout_${payoutId}`,
      entityType: 'payout',
      entityId: payoutId,
      action: 'create',
      payload: {
        payoutId,
        creatorId: req.creatorId,
        amountZar: req.amountZar,
        ...receiptPayload,
      },
      creatorId: req.creatorId,
      createdAt: now,
    });

    const payoutCreator = canonicalizeCreatorId(req.creatorId);
    const clientTs = Date.now();
    this.mirrorWriteThrough(async (driver) => {
      await this.ensureCreatorRowInSupabase(driver, payoutCreator);
      try {
        await driver.callRpc('execute_atomic_payout', {
          p_creator_id: payoutCreator,
          p_amount_zar: req.amountZar,
          p_amount_coins: 0,
          p_bank_code: bankMeta.code,
          p_bank_name: bankMeta.canonicalName,
          p_account_holder: req.accountHolder || payoutCreator,
          p_account_masked: maskedAccount,
          p_account_type: 'cheque',
          p_branch_code: resolvedBranchCode,
          p_payout_rail: normalizedRail,
          p_tx_id: payoutId,
          p_gateway_ref: gatewayRef,
          p_status: ledgerStatus,
          p_mutation_id: `payout_${payoutId}`,
          p_client_ts: clientTs,
        });
      } catch {
        await driver.upsertRow(
          'bank_accounts',
          {
            id: bankAccountId,
            creator_id: payoutCreator,
            bank_code: bankMeta.code,
            bank_name: bankMeta.canonicalName,
            account_holder: req.accountHolder || payoutCreator,
            account_number_masked: maskedAccount,
            account_type: 'cheque',
            branch_code: resolvedBranchCode,
            payout_rail: normalizedRail,
            is_verified: true,
            updated_at: now,
          },
          'id',
        );
        await driver.upsertRow(
          'wallet_ledger',
          {
            id: payoutId,
            creator_id: payoutCreator,
            amount_zar: -Math.abs(req.amountZar),
            amount_coins: 0,
            type: 'payout_withdrawal',
            reference: gatewayRef,
            status: ledgerStatus,
            metadata_json: receiptPayload,
            created_at: now,
          },
          'id',
        );
      }
    });

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
  // Sovereign Beatstore Licensing & SHA-256 Registry
  // ---------------------------------------------------------------------------

  public hasWalletActivity(creatorId: string): boolean {
    const activeTypes = new Set([
      'topup',
      'tip',
      'tip_sent',
      'tip_received',
      'remix_royalty',
      'license_sale',
      'payout',
      'payout_withdrawal',
    ]);
    const rows = this.walletLedger.get(creatorId) ?? [];
    return rows.some((r) => activeTypes.has(String(r.type)));
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
    const asset = this.marketplaceAssets.get(params.beatId);
    if (asset && Number(asset.is_exclusive_sold ?? 0) === 1) {
      return { status: 'exclusive_conflict' };
    }
    for (const lic of this.beatLicenses.values()) {
      if (
        lic.beat_id === params.beatId &&
        (lic.tier === 'exclusive_stem' || lic.tier === 'unlimited_commercial')
      ) {
        return { status: 'exclusive_conflict' };
      }
    }

    if (params.enforceBuyerWallet) {
      const wallet = this.getWallet(params.buyerId);
      if (wallet.balanceCoins < params.amountPaidCoins) {
        return { status: 'insufficient_funds' };
      }
    }

    const buyerCid = canonicalizeCreatorId(params.buyerId);
    const producerCid = canonicalizeCreatorId(params.producerId);

    const masterDigest =
      params.masterFileSha256 ||
      createHash('sha256').update(params.beatId).digest('hex');
    const licenseHash = this.computeCanonicalLicenseHash({
      certificateId: params.certificateId,
      beatId: params.beatId,
      producerId: producerCid,
      buyerId: buyerCid,
      tierSlug: params.tierSlug,
      amountPaidCoins: params.amountPaidCoins,
      amountPaidZar: params.amountPaidZar,
      issuedAt: params.issuedAt,
      masterFileSha256: masterDigest,
    });

    const payloadWithHash = {
      ...params.dataJson,
      buyerId: buyerCid,
      producerId: producerCid,
      licenseHash,
      masterFileSha256: masterDigest,
    };

    this.beatLicenses.set(params.certificateId, {
      certificate_id: params.certificateId,
      license_hash: licenseHash,
      beat_id: params.beatId,
      producer_id: producerCid,
      buyer_id: buyerCid,
      tier: params.tierSlug,
      coins_paid: params.amountPaidCoins,
      zar_paid: params.amountPaidZar,
      producer_coins: params.producerRoyaltyCoins,
      producer_zar: params.producerRoyaltyZar,
      issued_at: params.issuedAt,
      data_json: JSON.stringify(payloadWithHash),
    });

    if (params.enforceBuyerWallet) {
      const buyerRows = this.walletLedger.get(params.buyerId) ?? [];
      buyerRows.unshift({
        id: `tx_buy_${Date.now()}_${params.certificateId}`,
        creator_id: params.buyerId,
        type: 'license_purchase',
        amount_zar: -params.amountPaidZar,
        amount_coins: -params.amountPaidCoins,
        status: 'completed',
        reference: params.certificateId,
        data_json: JSON.stringify({
          beatId: params.beatId,
          tier: params.tierSlug,
        }),
        created_at: params.issuedAt,
      });
      this.walletLedger.set(params.buyerId, buyerRows);
    }

    const prodRows = this.walletLedger.get(params.producerId) ?? [];
    prodRows.unshift({
      id: `tx_roy_${Date.now()}_${params.certificateId}`,
      creator_id: params.producerId,
      type: 'license_sale',
      amount_zar: params.producerRoyaltyZar,
      amount_coins: params.producerRoyaltyCoins,
      status: 'completed',
      reference: params.certificateId,
      data_json: JSON.stringify({
        beatId: params.beatId,
        beatTitle: params.beatTitle,
        buyerId: params.buyerId,
        buyerHandle: params.buyerHandle,
        tier: params.tierSlug,
        message: `Beat license sale: "${params.beatTitle}" (${params.tierSlug.replaceAll('_', ' ')}) to ${params.buyerHandle}`,
      }),
      created_at: params.issuedAt,
    });
    this.walletLedger.set(params.producerId, prodRows);

    if (params.isExclusive) {
      if (asset) {
        asset.is_exclusive_sold = 1;
        asset.exclusive_buyer_id = params.buyerId;
        asset.updated_at = params.issuedAt;
      } else {
        this.marketplaceAssets.set(params.beatId, {
          id: params.beatId,
          title: params.beatTitle,
          producer_id: params.producerId,
          asset_category: 'beats',
          price_zar: params.amountPaidZar,
          price_coins: params.amountPaidCoins,
          is_exclusive_sold: 1,
          exclusive_buyer_id: params.buyerId,
          data_json: JSON.stringify(payloadWithHash),
          created_at: params.issuedAt,
          updated_at: params.issuedAt,
        });
      }
    }

    const purchasedAtMs = Date.parse(params.issuedAt) || Date.now();
    this.mirrorWriteThrough('beat_licenses.record', async (driver) => {
      const buyerCid = canonicalizeCreatorId(params.buyerId);
      const producerCid = canonicalizeCreatorId(params.producerId);
      await this.ensureCreatorRowInSupabase(driver, buyerCid);
      await this.ensureCreatorRowInSupabase(driver, producerCid);
      const beatObj = this.getMarketplaceBeatById(params.beatId);
      await driver.upsertRow(
        'marketplace_assets',
        {
          id: params.beatId,
          title: String(beatObj?.title ?? params.beatTitle),
          producer_id: producerCid,
          producer_name: String(beatObj?.producerName ?? params.producerHandle),
          genre: String(beatObj?.genre ?? 'Amapiano'),
          bpm: Math.round(Number(beatObj?.bpm ?? 113)),
          musical_key: String(beatObj?.musicalKey ?? 'Am'),
          price_zar: Number(beatObj?.priceZar ?? params.amountPaidZar),
          price_coins: Number(beatObj?.priceCoins ?? params.amountPaidCoins),
          is_exclusive_sold: Boolean(beatObj?.isExclusiveSold ?? params.isExclusive),
          exclusive_buyer_id: params.isExclusive ? buyerCid : null,
          updated_at: purchasedAtMs,
        },
        'id',
      );
      try {
        await driver.callRpc('record_beat_license_atomic', {
          p_certificate_id: params.certificateId,
          p_beat_id: params.beatId,
          p_beat_title: params.beatTitle,
          p_buyer_id: buyerCid,
          p_buyer_name: params.buyerHandle,
          p_producer_id: producerCid,
          p_producer_name: params.producerHandle,
          p_tier: params.tierSlug,
          p_amount_zar: params.amountPaidZar,
          p_amount_coins: params.amountPaidCoins,
          p_license_hash: licenseHash,
          p_master_sha256: masterDigest,
          p_terms_json: payloadWithHash,
          p_stems_urls_json: (params.dataJson?.stemUrls as Record<string, unknown>) ?? {},
          p_purchased_at: purchasedAtMs,
          p_enforce_wallet: Boolean(params.enforceBuyerWallet),
        });
      } catch {
        await driver.upsertRow(
          'beat_licenses',
          {
            certificate_id: params.certificateId,
            beat_id: params.beatId,
            beat_title: params.beatTitle,
            buyer_id: buyerCid,
            buyer_name: params.buyerHandle,
            producer_id: producerCid,
            producer_name: params.producerHandle,
            tier: params.tierSlug,
            amount_paid_zar: params.amountPaidZar,
            amount_paid_coins: params.amountPaidCoins,
            license_hash: licenseHash,
            master_file_sha256: masterDigest,
            terms_json: payloadWithHash,
            stems_urls_json: (params.dataJson?.stemUrls as Record<string, unknown>) ?? {},
            purchased_at: purchasedAtMs,
          },
          'certificate_id',
        );
      }
    });

    return { status: 'ok', licenseHash, masterFileSha256: masterDigest };
  }

  public getBeatLicensesByBuyer(buyerId: string): any[] {
    const cid = canonicalizeCreatorId(buyerId);
    return Array.from(this.beatLicenses.values())
      .filter((r) => canonicalizeCreatorId(String(r.buyer_id)) === cid)
      .sort((a, b) => String(b.issued_at).localeCompare(String(a.issued_at)))
      .map((r) => JSON.parse(String(r.data_json || '{}')));
  }

  public verifyBeatLicense(certificateId: string): {
    found: boolean;
    valid: boolean;
    certificate?: any;
  } {
    const row = this.beatLicenses.get(certificateId);
    if (!row) return { found: false, valid: false };
    const parsed = JSON.parse(String(row.data_json || '{}'));
    const recomputed = this.computeCanonicalLicenseHash({
      certificateId: String(row.certificate_id),
      beatId: String(row.beat_id),
      producerId: String(row.producer_id),
      buyerId: String(row.buyer_id),
      tierSlug: String(row.tier),
      amountPaidCoins: Number(row.coins_paid),
      amountPaidZar: Number(row.zar_paid),
      issuedAt: String(row.issued_at),
      masterFileSha256: parsed.masterFileSha256,
    });
    return {
      found: true,
      valid: recomputed === row.license_hash,
      certificate: parsed,
    };
  }

  // ---------------------------------------------------------------------------
  // Sovereign Identity, Cryptographic Auth & Multi-Tenant Sessions
  // ---------------------------------------------------------------------------

  public getUserByCreatorId(creatorId: string): SovereignUserRecord | null {
    const canonicalId = canonicalizeCreatorId(creatorId);
    const row =
      this.usersByCreatorId.get(creatorId) ??
      this.usersByCreatorId.get(canonicalId);
    if (!row) return null;
    const creator = this.creators.get(row.creatorId);
    return {
      userId: row.userId,
      creatorId: row.creatorId,
      handle: row.handle,
      displayName: String(creator?.displayName ?? row.displayName ?? row.handle),
      email: row.email,
      role: row.role,
      avatarUrl: String(
        creator?.avatarUrl ??
        row.avatarUrl ??
        `https://api.dicebear.com/7.x/avataaars/svg?seed=${encodeURIComponent(row.creatorId)}`,
      ),
      isVerified: String(creator?.tier ?? 'verified') !== 'unverified',
      createdAt: row.createdAt,
    };
  }

  public isSessionActive(sessionId: string): boolean {
    const row = this.sessions.get(sessionId);
    if (!row || row.revoked) return false;
    return new Date(row.expiresAt).getTime() > Date.now();
  }

  public getAuthSyncSnapshot(
    creatorId: string,
    sessionId?: string,
  ): {
    passwordHash: string;
    refreshTokenHash: string;
    previousTokenHash: string | null;
  } | null {
    const canonical = canonicalizeCreatorId(creatorId);
    const userRow =
      this.usersByCreatorId.get(creatorId) ??
      this.usersByCreatorId.get(canonical);
    const sessionRow = sessionId ? this.sessions.get(sessionId) : undefined;
    if (!userRow && !sessionRow) return null;
    return {
      passwordHash: userRow?.passwordHash ?? '',
      refreshTokenHash: sessionRow?.refreshTokenHash ?? '',
      previousTokenHash: sessionRow?.previousTokenHash ?? null,
    };
  }

  public hydrateExternalUser(record: {
    userId: string;
    creatorId: string;
    handle: string;
    displayName?: string;
    email: string;
    passwordHash: string;
    role?: string;
    avatarUrl?: string;
    isVerified?: boolean;
    createdAt?: string;
  }): void {
    const cid = canonicalizeCreatorId(record.creatorId);
    const handle = record.handle.startsWith('@')
      ? record.handle
      : `@${record.handle}`;
    const displayName =
      record.displayName?.trim() || handle.replace(/^@/, '').toUpperCase();
    const avatarUrl =
      record.avatarUrl ||
      `https://api.dicebear.com/7.x/avataaars/svg?seed=${encodeURIComponent(cid)}`;
    const nowIso = record.createdAt || new Date().toISOString();

    if (!this.creators.has(cid)) {
      this.creators.set(cid, {
        id: cid,
        handle,
        displayName,
        avatarUrl,
        tier: record.isVerified === false ? 'unverified' : 'verified',
        createdAt: nowIso,
        updatedAt: nowIso,
      });
    }
    const existing = this.usersByCreatorId.get(cid);
    this.usersByCreatorId.set(cid, {
      userId: record.userId || existing?.userId || `usr_${cid}`,
      creatorId: cid,
      handle,
      displayName,
      email: record.email.toLowerCase(),
      passwordHash:
        record.passwordHash && record.passwordHash !== 'GOTRUE_MANAGED'
          ? record.passwordHash
          : existing?.passwordHash || 'GOTRUE_MANAGED',
      role: record.role || existing?.role || 'creator',
      avatarUrl,
      isVerified: record.isVerified ?? true,
      createdAt: nowIso,
    });
  }

  public hydrateExternalSession(record: {
    sessionId: string;
    userId: string;
    creatorId: string;
    familyId: string;
    refreshTokenHash: string;
    previousTokenHash?: string | null;
    deviceLabel?: string;
    expiresAt: string;
    revoked?: boolean;
    revokeReason?: string | null;
    createdAt?: string;
    rotatedAt?: string;
  }): void {
    const nowIso = new Date().toISOString();
    this.sessions.set(record.sessionId, {
      sessionId: record.sessionId,
      userId: record.userId,
      creatorId: canonicalizeCreatorId(record.creatorId),
      familyId: record.familyId,
      refreshTokenHash: record.refreshTokenHash,
      previousTokenHash: record.previousTokenHash ?? null,
      deviceLabel: record.deviceLabel ?? 'vhunambi_client',
      expiresAt: record.expiresAt,
      revoked: Boolean(record.revoked),
      revokeReason: record.revokeReason ?? null,
      createdAt: record.createdAt ?? nowIso,
      rotatedAt: record.rotatedAt ?? nowIso,
    });
  }

  private createAuthSessionAndTokens(
    user: SovereignUserRecord,
    deviceLabel = 'vhunambi_client',
    jwtSecret?: string,
  ): AuthTokenBundle {
    const now = new Date();
    const nowIso = now.toISOString();
    const expiresAtIso = new Date(
      now.getTime() + 30 * 24 * 60 * 60 * 1000,
    ).toISOString();
    const sessionId = `ses_${randomUUID().replace(/-/g, '').slice(0, 20)}`;
    const familyId = `fam_${randomUUID().replace(/-/g, '').slice(0, 16)}`;
    const { refreshToken, refreshTokenHash } = generateRefreshTokenPair();

    const sessionRow: InternalSessionRow = {
      sessionId,
      userId: user.userId,
      creatorId: user.creatorId,
      familyId,
      refreshTokenHash,
      previousTokenHash: null,
      deviceLabel,
      expiresAt: expiresAtIso,
      revoked: false,
      revokeReason: null,
      createdAt: nowIso,
      rotatedAt: nowIso,
    };
    this.sessions.set(sessionId, sessionRow);

    const signed = signAccessJwt(
      {
        sub: user.userId,
        cid: user.creatorId,
        hdl: user.handle,
        sid: sessionId,
        role: user.role,
      },
      undefined,
      undefined,
      jwtSecret,
    );

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
    jwtSecret?: string;
  }): AuthTokenBundle {
    const normalizedHandle = EdgeIsolateDatabaseEngine.normalizeHandle(
      input.handle,
    );
    if (normalizedHandle.length < 3) {
      throw new Error(
        'INVALID_HANDLE: Handle must contain at least 2 alphanumeric characters.',
      );
    }
    const normalizedEmail = input.email.trim().toLowerCase();
    if (!normalizedEmail.includes('@') || normalizedEmail.length < 5) {
      throw new Error('INVALID_EMAIL: A valid email address is required.');
    }
    validateSovereignPassword(input.password);

    const handleSlug = normalizedHandle.slice(1).replace(/[^a-z0-9_]/g, '_');
    const creatorId = input.creatorId?.trim() || `creator_${handleSlug}`;
    const userId = `usr_${handleSlug}_${randomUUID().slice(0, 6)}`;
    const displayName =
      input.displayName?.trim() || normalizedHandle.slice(1).toUpperCase();
    const passwordHash = hashPassword(input.password);
    const now = new Date().toISOString();

    for (const u of this.usersByCreatorId.values()) {
      if (
        u.handle.toLowerCase() === normalizedHandle.toLowerCase() ||
        u.email.toLowerCase() === normalizedEmail ||
        u.creatorId.toLowerCase() === creatorId.toLowerCase()
      ) {
        throw new Error(
          'AUTH_IDENTITY_EXISTS: A sovereign user with that handle, email, or creator ID already exists.',
        );
      }
    }

    const avatarUrl = `https://api.dicebear.com/7.x/avataaars/svg?seed=${encodeURIComponent(creatorId)}`;
    this.creators.set(creatorId, {
      id: creatorId,
      handle: normalizedHandle,
      displayName,
      avatarUrl,
      tier: 'verified',
      createdAt: now,
      updatedAt: now,
    });
    this.usersByCreatorId.set(creatorId, {
      userId,
      creatorId,
      handle: normalizedHandle,
      displayName,
      email: normalizedEmail,
      passwordHash,
      role: 'creator',
      avatarUrl,
      isVerified: true,
      createdAt: now,
    });

    const welcomeCoins =
      typeof input.initialCoins === 'number'
        ? Math.max(0, Math.round(input.initialCoins))
        : 2500;
    if (welcomeCoins > 0 && !this.hasWalletActivity(creatorId)) {
      const zarRate = 0.3;
      const welcomeZar = Number((welcomeCoins * zarRate).toFixed(2));
      const rows = this.walletLedger.get(creatorId) ?? [];
      rows.unshift({
        id: `wtx_welcome_${creatorId}`,
        creator_id: creatorId,
        type: 'topup',
        amount_zar: welcomeZar,
        amount_coins: welcomeCoins,
        status: 'completed',
        reference: 'SOVEREIGN_GRANT',
        data_json: JSON.stringify({ note: 'Sovereign Creator Genesis Grant' }),
        created_at: now,
      });
      this.walletLedger.set(creatorId, rows);
      this.mirrorWriteThrough(async (driver) => {
        await this.ensureCreatorRowInSupabase(driver, creatorId);
        await driver.upsertRow(
          'wallet_ledger',
          {
            id: `wtx_welcome_${creatorId}`,
            creator_id: creatorId,
            amount_zar: welcomeZar,
            amount_coins: welcomeCoins,
            type: 'topup',
            reference: 'SOVEREIGN_GRANT',
            status: 'completed',
            metadata_json: { note: 'Sovereign Creator Genesis Grant' },
            created_at: now,
          },
          'id',
        );
      });
    }

    const createdUser = this.getUserByCreatorId(creatorId)!;
    return this.createAuthSessionAndTokens(
      createdUser,
      input.deviceLabel ?? 'vhunambi_client',
      input.jwtSecret,
    );
  }

  public authenticateUser(input: {
    identifier: string;
    password: string;
    deviceLabel?: string;
    jwtSecret?: string;
  }): AuthTokenBundle {
    const rawId = input.identifier.trim().toLowerCase();
    const handleCandidate = rawId.startsWith('@') ? rawId : `@${rawId}`;
    const canonicalCandidate = canonicalizeCreatorId(rawId).toLowerCase();

    let matched: InternalUserRow | undefined;
    for (const u of this.usersByCreatorId.values()) {
      const cidLower = u.creatorId.toLowerCase();
      if (
        u.email.toLowerCase() === rawId ||
        u.handle.toLowerCase() === handleCandidate ||
        cidLower === rawId ||
        cidLower === canonicalCandidate
      ) {
        matched = u;
        break;
      }
    }

    if (!matched || !verifyPassword(input.password, matched.passwordHash)) {
      throw new Error('INVALID_CREDENTIALS: Invalid handle/email or password.');
    }

    const user = this.getUserByCreatorId(matched.creatorId);
    if (!user) {
      throw new Error('INVALID_CREDENTIALS: Creator record missing.');
    }
    return this.createAuthSessionAndTokens(
      user,
      input.deviceLabel ?? 'vhunambi_client',
      input.jwtSecret,
    );
  }

  public rotateRefreshToken(
    refreshToken: string,
    jwtSecret?: string,
  ): AuthTokenBundle {
    const tokenHash = hashRefreshToken(refreshToken);
    let sessionRow: InternalSessionRow | undefined;
    for (const s of this.sessions.values()) {
      if (s.refreshTokenHash === tokenHash || s.previousTokenHash === tokenHash) {
        sessionRow = s;
        break;
      }
    }

    if (!sessionRow) {
      throw new Error('AUTH_REFRESH_INVALID: Unrecognized refresh token.');
    }

    const familyId = sessionRow.familyId;
    const isReplayOfRotatedToken =
      sessionRow.previousTokenHash === tokenHash &&
      sessionRow.refreshTokenHash !== tokenHash;

    if (isReplayOfRotatedToken) {
      const nowIso = new Date().toISOString();
      for (const s of this.sessions.values()) {
        if (s.familyId === familyId) {
          s.revoked = true;
          s.revokeReason = 'TOKEN_REUSE_DETECTED';
          s.rotatedAt = nowIso;
        }
      }
      throw new Error(
        'AUTH_TOKEN_REUSE_DETECTED: Refresh token reuse detected; session family revoked.',
      );
    }

    if (sessionRow.revoked) {
      throw new Error('AUTH_SESSION_REVOKED: Session has been revoked.');
    }

    if (new Date(sessionRow.expiresAt).getTime() <= Date.now()) {
      throw new Error('AUTH_SESSION_EXPIRED: Refresh session has expired.');
    }

    const nextPair = generateRefreshTokenPair();
    const nowIso = new Date().toISOString();
    const nextExpiresAt = new Date(
      Date.now() + 30 * 24 * 60 * 60 * 1000,
    ).toISOString();

    sessionRow.previousTokenHash = sessionRow.refreshTokenHash;
    sessionRow.refreshTokenHash = nextPair.refreshTokenHash;
    sessionRow.expiresAt = nextExpiresAt;
    sessionRow.rotatedAt = nowIso;

    const user = this.getUserByCreatorId(sessionRow.creatorId);
    if (!user) {
      throw new Error('AUTH_USER_NOT_FOUND: User no longer exists.');
    }

    const signed = signAccessJwt(
      {
        sub: user.userId,
        cid: user.creatorId,
        hdl: user.handle,
        sid: sessionRow.sessionId,
        role: user.role,
      },
      undefined,
      undefined,
      jwtSecret,
    );

    return {
      user,
      session: {
        sessionId: sessionRow.sessionId,
        userId: user.userId,
        creatorId: user.creatorId,
        familyId,
        deviceLabel: sessionRow.deviceLabel,
        expiresAt: nextExpiresAt,
        revoked: false,
        revokeReason: null,
        createdAt: sessionRow.createdAt,
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
    const existing = this.sessions.get(sessionId);
    if (!existing) {
      return { sessionId, revoked: false };
    }
    existing.revoked = true;
    existing.revokeReason = reason;
    existing.rotatedAt = new Date().toISOString();
    return { sessionId, revoked: true };
  }

  public listSessionsForCreator(
    creatorId: string,
  ): SovereignAuthSessionRecord[] {
    return Array.from(this.sessions.values())
      .filter((s) => s.creatorId === creatorId)
      .sort((a, b) => b.rotatedAt.localeCompare(a.rotatedAt))
      .map((s) => ({
        sessionId: s.sessionId,
        userId: s.userId,
        creatorId: s.creatorId,
        familyId: s.familyId,
        deviceLabel: s.deviceLabel,
        expiresAt: s.expiresAt,
        revoked: s.revoked,
        revokeReason: s.revokeReason,
        createdAt: s.createdAt,
        rotatedAt: s.rotatedAt,
      }));
  }

  // ---------------------------------------------------------------------------
  // Persistent Generation Jobs
  // ---------------------------------------------------------------------------

  private mapSupabaseGenerationJobRow(
    gj: Record<string, any>,
    existingJob?: GenerationJob,
  ): GenerationJob {
    const rawManifestObj =
      gj.manifest_json && typeof gj.manifest_json === 'object'
        ? (gj.manifest_json as Record<string, any>)
        : undefined;
    const manifest = rawManifestObj
      ? (rawManifestObj as GenerationJob['manifest'])
      : existingJob?.manifest;
    const visionMeta =
      rawManifestObj?.visionMeta && typeof rawManifestObj.visionMeta === 'object'
        ? (rawManifestObj.visionMeta as Record<string, unknown>)
        : existingJob?.visionMeta;
    const resolvedCoverUrl =
      existingJob?.coverUrl ??
      manifest?.assets?.coverArt1x1Url ??
      manifest?.assets?.coverArt9x16Url ??
      (typeof visionMeta?.coverUrl === 'string' ? visionMeta.coverUrl : undefined);
    const rawStemUrls = gj.stem_urls_json;
    const hasRemoteStems =
      rawStemUrls &&
      typeof rawStemUrls === 'object' &&
      Object.keys(rawStemUrls as Record<string, unknown>).length > 0;
    return {
      generationId: String(gj.generation_id),
      trackTitle: String(gj.track_title ?? existingJob?.trackTitle ?? 'Untitled Track'),
      genre: String(gj.genre ?? existingJob?.genre ?? 'Amapiano'),
      language: String(gj.language ?? existingJob?.language ?? 'Instrumental'),
      status: (gj.status ?? existingJob?.status ?? 'queued') as GenerationJob['status'],
      step: (gj.step ?? existingJob?.step ?? 'queued') as GenerationJob['step'],
      progressPct: Number(gj.progress_pct ?? existingJob?.progressPct ?? 0),
      masterMp3Url: gj.master_mp3_url
        ? String(gj.master_mp3_url)
        : existingJob?.masterMp3Url,
      stemsZipUrl: gj.stems_zip_url
        ? String(gj.stems_zip_url)
        : existingJob?.stemsZipUrl,
      stemUrls: hasRemoteStems
        ? (rawStemUrls as Record<string, string>)
        : existingJob?.stemUrls,
      manifestUrl: gj.manifest_url
        ? String(gj.manifest_url)
        : existingJob?.manifestUrl,
      manifest,
      visionMeta,
      coverUrl: resolvedCoverUrl,
      lyrics: existingJob?.lyrics,
      durationSec: Number(gj.duration_sec ?? existingJob?.durationSec ?? 180),
      errorMessage: gj.error_message
        ? String(gj.error_message)
        : existingJob?.errorMessage,
      providerTaskId: gj.provider_task_id
        ? String(gj.provider_task_id)
        : existingJob?.providerTaskId,
      createdAt: new Date(
        Number(gj.created_at || existingJob?.createdAt?.getTime() || Date.now()),
      ),
      updatedAt: new Date(
        Number(gj.updated_at || existingJob?.updatedAt?.getTime() || Date.now()),
      ),
    };
  }

  public async hydrateGenerationJobById(
    generationId: string,
    cOrEnv?: unknown,
  ): Promise<GenerationJob | null> {
    return this.syncGenerationJobFromCloud(generationId, cOrEnv);
  }

  private buildGenerationManifestPayload(
    job: GenerationJob,
  ): Record<string, unknown> | null {
    if (!job.manifest && !job.visionMeta) return null;
    return {
      ...(job.manifest ?? {}),
      ...(job.visionMeta ? { visionMeta: job.visionMeta } : {}),
    };
  }

  private mergeAndStoreGenerationJob(
    job: GenerationJob,
    creatorId: string,
    jobKind: string,
  ): { merged: GenerationJob; effectiveCreatorId: string; payload: Record<string, unknown> } {
    const existing = this.generationJobs.get(job.generationId);
    const merged: GenerationJob = {
      ...(existing?.job ?? ({} as GenerationJob)),
      ...job,
      providerTaskId: job.providerTaskId ?? existing?.job.providerTaskId,
      masterMp3Url: job.masterMp3Url ?? existing?.job.masterMp3Url,
      stemsZipUrl: job.stemsZipUrl ?? existing?.job.stemsZipUrl,
      stemUrls: job.stemUrls ?? existing?.job.stemUrls,
      manifestUrl: job.manifestUrl ?? existing?.job.manifestUrl,
      manifest: job.manifest ?? existing?.job.manifest,
      visionMeta: job.visionMeta ?? existing?.job.visionMeta,
      coverUrl: job.coverUrl ?? existing?.job.coverUrl,
      lyrics: job.lyrics ?? existing?.job.lyrics,
    };
    const effectiveCreatorId = canonicalizeCreatorId(creatorId);
    const resolvedKind = existing?.jobKind && jobKind === 'audio_synthesis' ? existing.jobKind : jobKind;
    this.generationJobs.set(job.generationId, {
      job: merged,
      creatorId: effectiveCreatorId,
      jobKind: resolvedKind,
    });
    return {
      merged,
      effectiveCreatorId,
      payload: {
        generation_id: merged.generationId,
        creator_id: effectiveCreatorId,
        job_kind: resolvedKind,
        provider_task_id: merged.providerTaskId ?? null,
        status: merged.status,
        step: merged.step,
        progress_pct: Math.round(Number(merged.progressPct ?? 0)),
        track_title: merged.trackTitle || 'Untitled Track',
        genre: merged.genre || 'Amapiano',
        language: merged.language || 'Instrumental',
        duration_sec: Math.round(Number(merged.durationSec ?? 180)),
        master_mp3_url: merged.masterMp3Url ?? null,
        stems_zip_url: merged.stemsZipUrl ?? null,
        stem_urls_json: merged.stemUrls ?? {},
        manifest_url: merged.manifestUrl ?? null,
        manifest_json: this.buildGenerationManifestPayload(merged),
        error_message: merged.errorMessage ?? null,
        created_at: merged.createdAt ? merged.createdAt.getTime() : Date.now(),
        updated_at: merged.updatedAt ? merged.updatedAt.getTime() : Date.now(),
      },
    };
  }

  public upsertGenerationJob(
    job: GenerationJob,
    creatorId = 'creator_cern',
    jobKind = 'audio_synthesis',
  ): void {
    const { payload } = this.mergeAndStoreGenerationJob(job, creatorId, jobKind);
    this.mirrorWriteThrough('generation_jobs.upsert', async (driver) => {
      await driver.upsertRow('generation_jobs', payload, 'generation_id');
    });
  }

  public async upsertGenerationJobAsync(
    job: GenerationJob,
    creatorId = 'creator_cern',
    jobKind = 'audio_synthesis',
    cOrEnv?: unknown,
  ): Promise<void> {
    const { payload } = this.mergeAndStoreGenerationJob(job, creatorId, jobKind);
    await this.awaitWriteThrough(
      'generation_jobs.upsert',
      async (driver) => {
        await driver.upsertRow('generation_jobs', payload, 'generation_id');
      },
      cOrEnv,
    );
  }

  public getGenerationJob(generationId: string): GenerationJob | null {
    return this.generationJobs.get(generationId)?.job ?? null;
  }

  public updateGenerationJob(
    generationId: string,
    updates: Partial<GenerationJob>,
  ): GenerationJob | null {
    const entry = this.generationJobs.get(generationId);
    if (!entry) return null;
    const merged: GenerationJob = {
      ...entry.job,
      ...updates,
      updatedAt: new Date(),
    };
    this.upsertGenerationJob(merged, entry.creatorId, entry.jobKind);
    return this.getGenerationJob(generationId);
  }

  public async updateGenerationJobAsync(
    generationId: string,
    updates: Partial<GenerationJob>,
    cOrEnv?: unknown,
  ): Promise<GenerationJob | null> {
    const entry = this.generationJobs.get(generationId);
    if (!entry) return null;
    const merged: GenerationJob = {
      ...entry.job,
      ...updates,
      updatedAt: new Date(),
    };
    await this.upsertGenerationJobAsync(merged, entry.creatorId, entry.jobKind, cOrEnv);
    return this.getGenerationJob(generationId);
  }

  public listGenerationJobs(creatorId?: string): GenerationJob[] {
    let entries = Array.from(this.generationJobs.values());
    if (creatorId && creatorId.trim() !== '') {
      const canonical = canonicalizeCreatorId(creatorId);
      entries = entries.filter((e) => e.creatorId === canonical);
    }
    return entries
      .map((e) => e.job)
      .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
  }

  public countActiveGenerationJobs(): number {
    const active = new Set([
      'queued',
      'running',
      'synthesizing',
      'splitting_stems',
      'extracting_mmo',
    ]);
    let count = 0;
    for (const e of this.generationJobs.values()) {
      if (active.has(e.job.status)) count += 1;
    }
    return count;
  }

  // ---------------------------------------------------------------------------
  // Persistent Marketplace Assets
  // ---------------------------------------------------------------------------

  public countMarketplaceBeats(): number {
    let count = 0;
    for (const a of this.marketplaceAssets.values()) {
      if (a.asset_category === 'beats') count += 1;
    }
    return count;
  }

  public upsertMarketplaceBeat(beat: Record<string, any>): void {
    const now = new Date().toISOString();
    const id = String(beat.id);
    this.marketplaceAssets.set(id, {
      id,
      title: String(beat.title || 'Untitled Beat'),
      producer_id: String(beat.producerId || 'creator_cern'),
      asset_category: 'beats',
      price_zar: Number(beat.priceZar ?? 0),
      price_coins: Number(beat.priceCoins ?? 0),
      is_exclusive_sold: beat.isExclusiveSold ? 1 : 0,
      exclusive_buyer_id: beat.exclusiveBuyerId
        ? String(beat.exclusiveBuyerId)
        : null,
      data_json: JSON.stringify(beat),
      created_at: String(beat.createdAt || now),
      updated_at: String(beat.updatedAt || now),
    });
    this.mirrorWriteThrough(async (driver) => {
      await driver.upsertRow(
        'marketplace_assets',
        {
          id,
          title: String(beat.title || 'Untitled Beat'),
          producer_id: canonicalizeCreatorId(String(beat.producerId || 'creator_cern')),
          producer_name: String(beat.producerName || beat.producerHandle || 'Vhunambi Producer'),
          genre: String(beat.genre || 'Amapiano'),
          bpm: Math.round(Number(beat.bpm ?? 113)),
          musical_key: String(beat.musicalKey || 'Am'),
          price_zar: Number(beat.priceZar ?? 350),
          price_coins: Math.round(Number(beat.priceCoins ?? 350)),
          is_exclusive_sold: Boolean(beat.isExclusiveSold),
          exclusive_buyer_id: beat.exclusiveBuyerId ? String(beat.exclusiveBuyerId) : null,
          audio_preview_url: String(beat.previewAudioUrl || beat.audioUrl || ''),
          cover_url: String(beat.coverUrl || ''),
          tags_json: Array.isArray(beat.tags) ? beat.tags : [],
          tier_pricing_json: beat.tierPricing ?? {},
          stems_r2_keys_json: beat.stemsR2Keys ?? {},
          data_json: beat,
          updated_at: Date.parse(String(beat.updatedAt || now)) || Date.now(),
        },
        'id',
      );
    });
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
      isExclusiveSold:
        Number(r.is_exclusive_sold ?? 0) === 1 || Boolean(data.isExclusiveSold),
      exclusiveBuyerId: r.exclusive_buyer_id ?? data.exclusiveBuyerId,
      createdAt: String(data.createdAt ?? r.created_at),
      updatedAt: String(data.updatedAt ?? r.updated_at),
    };
  }

  public getMarketplaceBeatById(beatId: string): Record<string, any> | null {
    const row = this.marketplaceAssets.get(beatId);
    if (!row || row.asset_category !== 'beats') return null;
    return this.mapMarketplaceBeatRow(row);
  }

  public listMarketplaceBeats(
    includeExclusiveSold = false,
  ): Record<string, any>[] {
    const rows = Array.from(this.marketplaceAssets.values())
      .filter(
        (r) =>
          r.asset_category === 'beats' &&
          (includeExclusiveSold || Number(r.is_exclusive_sold ?? 0) === 0),
      )
      .reverse();
    return rows.map((r) => this.mapMarketplaceBeatRow(r));
  }

  public incrementBeatAuditionCount(beatId: string): number {
    const existing = this.getMarketplaceBeatById(beatId);
    if (!existing) return 0;
    const nextCount = Number(existing.auditionCount ?? 0) + 1;
    this.upsertMarketplaceBeat({
      ...existing,
      auditionCount: nextCount,
      updatedAt: new Date().toISOString(),
    });
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
      isExclusiveSold:
        params.isExclusiveSold ?? existing.isExclusiveSold ?? false,
      exclusiveBuyerId: params.exclusiveBuyerId ?? existing.exclusiveBuyerId,
      updatedAt: new Date().toISOString(),
    };
    this.upsertMarketplaceBeat(updated);
    return updated;
  }

  public deleteMarketplaceBeat(beatId: string): boolean {
    const existing = this.marketplaceAssets.get(beatId);
    if (!existing || existing.asset_category !== 'beats') return false;
    const deleted = this.marketplaceAssets.delete(beatId);
    if (deleted) {
      this.mirrorWriteThrough(async (driver) => {
        await driver.deleteRows('marketplace_assets', `id=eq.${encodeURIComponent(beatId)}`);
      });
    }
    return deleted;
  }

  // ---------------------------------------------------------------------------
  // Persistent Social Clips, Comments & Interactions
  // ---------------------------------------------------------------------------

  public countPublishedClips(): number {
    return this.publishedClips.size;
  }

  private buildPublishedClipCloudPayload(clip: Record<string, any>): {
    localRow: Record<string, any>;
    cloudRow: Record<string, any>;
  } {
    const now = new Date().toISOString();
    const id = String(clip.id);
    const creatorId = canonicalizeCreatorId(
      String(clip.creatorId || 'creator_cern'),
    );
    const creatorHandle = String(
      clip.creatorUsername ||
      clip.creatorHandle ||
      `@${creatorId.replace(/^creator_/, '')}`,
    );
    const createdAt = String(
      clip.publishedAt ||
      clip.createdAt ||
      this.publishedClips.get(id)?.created_at ||
      now,
    );
    const createdMs = Date.parse(createdAt) || Date.now();
    const updatedMs = Date.parse(now) || Date.now();
    const reactionCounts = compactReactionCounts(
      normalizeReactionCounts(clip.reactionCounts),
    );
    const videoUrl =
      typeof clip.videoUrl === 'string' && clip.videoUrl.trim().length > 0
        ? clip.videoUrl.trim()
        : null;
    const clipPayload = {
      ...clip,
      id,
      creatorId,
      creatorUsername: creatorHandle,
      videoUrl,
      mediaKind: String(clip.mediaKind || 'artwork'),
      audioStartMs: Number(clip.audioStartMs ?? 0),
      audioEndMs: Number(clip.audioEndMs ?? 30000),
      effectPreset: String(clip.effectPreset || 'kinetic_gold'),
      effectIntensity: Number(clip.effectIntensity ?? 0.65),
      typographyPreset: String(clip.typographyPreset || 'kinetic_bounce'),
      speedRate: Number(clip.speedRate ?? 1.0),
      stickerId: clip.stickerId ? String(clip.stickerId) : null,
      reactionCounts,
      publishedAt: createdAt,
    };
    return {
      localRow: {
        id,
        creator_id: creatorId,
        creator_handle: creatorHandle,
        video_url: videoUrl ?? String(clip.audioUrl || ''),
        audio_title: String(clip.title || 'Untitled Clip'),
        bantu_language: clip.genre ? String(clip.genre) : null,
        views_count: Number(clip.playCount ?? clip.viewsCount ?? 0),
        likes_count: Number(clip.likeCount ?? clip.likesCount ?? 0),
        comments_count: Number(clip.commentCount ?? clip.commentsCount ?? 0),
        remixes_count: Number(clip.remixCount ?? clip.remixesCount ?? 0),
        remixed_from_clip_id: clip.remixedFromClipId
          ? String(clip.remixedFromClipId)
          : null,
        reaction_counts_json: JSON.stringify(reactionCounts),
        data_json: JSON.stringify(clipPayload),
        created_at: createdAt,
        updated_at: now,
      },
      cloudRow: {
        id,
        track_id: String(clip.trackId || id),
        creator_id: creatorId,
        title: String(clip.title || 'Untitled Groove'),
        caption: String(clip.caption || ''),
        genre: String(clip.genre || 'Amapiano'),
        bpm: Math.round(Number(clip.bpm ?? 113)),
        likes_count: Number(clip.likeCount ?? clip.likesCount ?? 0),
        comments_count: Number(clip.commentCount ?? clip.commentsCount ?? 0),
        remixes_count: Number(clip.remixCount ?? clip.remixesCount ?? 0),
        shares_count: Number(clip.shareCount ?? clip.sharesCount ?? 0),
        audio_url: String(clip.audioUrl || ''),
        cover_url: String(clip.coverUrl || ''),
        video_url: videoUrl,
        media_kind: clipPayload.mediaKind,
        audio_start_ms: clipPayload.audioStartMs,
        audio_end_ms: clipPayload.audioEndMs,
        effect_preset: clipPayload.effectPreset,
        effect_intensity: clipPayload.effectIntensity,
        typography_preset: clipPayload.typographyPreset,
        speed_rate: clipPayload.speedRate,
        sticker_id: clipPayload.stickerId,
        reaction_counts_json: reactionCounts,
        remixed_from_clip_id: clip.remixedFromClipId ? String(clip.remixedFromClipId) : null,
        remix_attribution: clip.remixAttribution ? String(clip.remixAttribution) : null,
        tags_json: Array.isArray(clip.tags) ? clip.tags : [],
        dna_json: clip.dna ?? {},
        data_json: clipPayload,
        created_at: createdMs,
        updated_at: updatedMs,
      },
    };
  }

  public upsertPublishedClip(
    clip: Record<string, any>,
    skipMirror = false,
  ): void {
    const { localRow, cloudRow } = this.buildPublishedClipCloudPayload(clip);
    this.publishedClips.set(localRow.id, localRow);
    if (!skipMirror) {
      this.mirrorWriteThrough('published_clips.upsert', async (driver) => {
        await driver.upsertRow('published_clips', cloudRow, 'id');
      });
    }
  }

  public async upsertPublishedClipAsync(
    clip: Record<string, any>,
    cOrEnv?: unknown,
  ): Promise<void> {
    const { localRow, cloudRow } = this.buildPublishedClipCloudPayload(clip);
    this.publishedClips.set(localRow.id, localRow);
    await this.awaitWriteThrough(
      'published_clips.upsert',
      async (driver) => {
        await driver.upsertRow('published_clips', cloudRow, 'id');
      },
      cOrEnv,
    );
  }

  private mapPublishedClipRow(r: Record<string, any>): Record<string, any> {
    let data: Record<string, any> = {};
    try {
      data = JSON.parse(String(r.data_json || '{}'));
    } catch {
      data = {};
    }
    const reactionCounts = compactReactionCounts(
      normalizeReactionCounts(r.reaction_counts_json ?? data.reactionCounts),
    );
    return {
      ...data,
      id: String(r.id),
      creatorId: String(data.creatorId ?? r.creator_id),
      creatorUsername: String(data.creatorUsername ?? r.creator_handle),
      title: String(data.title ?? r.audio_title),
      videoUrl: data.videoUrl ?? null,
      mediaKind: String(data.mediaKind ?? 'artwork'),
      audioStartMs: Number(data.audioStartMs ?? 0),
      audioEndMs: Number(data.audioEndMs ?? 30000),
      effectPreset: String(data.effectPreset ?? 'kinetic_gold'),
      effectIntensity: Number(data.effectIntensity ?? 0.65),
      typographyPreset: String(data.typographyPreset ?? 'kinetic_bounce'),
      speedRate: Number(data.speedRate ?? 1.0),
      stickerId: data.stickerId ?? null,
      reactionCounts,
      playCount: Number(r.views_count ?? data.playCount ?? 0),
      likeCount: Number(r.likes_count ?? data.likeCount ?? 0),
      commentCount: Number(r.comments_count ?? data.commentCount ?? 0),
      remixCount: Number(r.remixes_count ?? data.remixCount ?? 0),
      remixedFromClipId:
        r.remixed_from_clip_id ?? data.remixedFromClipId ?? undefined,
      publishedAt: String(data.publishedAt ?? r.created_at),
    };
  }

  public getPublishedClipRow(clipId: string): Record<string, any> | null {
    const row = this.publishedClips.get(clipId);
    return row ? this.mapPublishedClipRow(row) : null;
  }

  public listPublishedClipRows(): Record<string, any>[] {
    return Array.from(this.publishedClips.values())
      .reverse()
      .sort((a, b) => {
        const ta = Date.parse(String(a.created_at || '')) || 0;
        const tb = Date.parse(String(b.created_at || '')) || 0;
        return tb - ta;
      })
      .map((r) => this.mapPublishedClipRow(r));
  }

  public listRemixClipRows(parentClipId: string): Record<string, any>[] {
    return Array.from(this.publishedClips.values())
      .filter((r) => r.remixed_from_clip_id === parentClipId)
      .reverse()
      .sort((a, b) => {
        const ta = Date.parse(String(a.created_at || '')) || 0;
        const tb = Date.parse(String(b.created_at || '')) || 0;
        return tb - ta;
      })
      .map((r) => this.mapPublishedClipRow(r));
  }

  public reactToClip(
    clipId: string,
    actorCreatorId = 'creator_cern',
    reactionType: KineticReactionWire | null = null,
    skipMirror = false,
  ): KineticReactionMutationResult {
    const row = this.publishedClips.get(clipId);
    if (!row) {
      return {
        success: false,
        targetId: clipId,
        myReaction: null,
        reactionCounts: {},
        likeCount: 0,
        liked: false,
      };
    }

    const actor = canonicalizeCreatorId(actorCreatorId);
    const key = `clip_react::${clipId}::${actor}`;
    const prevReaction = this.socialInteractionReactions.get(key) ?? null;
    const requested = normalizeKineticReactionWire(reactionType);
    const nextReaction: KineticReactionWire | null =
      requested === null || requested === prevReaction ? null : requested;

    const parsedData = this.parseJsonField(row.data_json);
    const counts = normalizeReactionCounts(
      row.reaction_counts_json ?? parsedData.reactionCounts,
    );
    const legacyLikeCount = Math.max(
      0,
      Number(row.likes_count ?? parsedData.likeCount ?? 0),
    );
    if (sumReactionCounts(counts) === 0 && legacyLikeCount > 0) {
      counts.love = legacyLikeCount;
    }

    if (prevReaction) {
      counts[prevReaction] = Math.max(0, counts[prevReaction] - 1);
    }
    if (nextReaction) {
      counts[nextReaction] = counts[nextReaction] + 1;
      this.socialInteractions.add(key);
      this.socialInteractionReactions.set(key, nextReaction);
    } else {
      this.socialInteractions.delete(key);
      this.socialInteractionReactions.delete(key);
    }

    const compact = compactReactionCounts(counts);
    const nextLikes = Math.max(sumReactionCounts(counts), 0);
    row.reaction_counts_json = JSON.stringify(compact);
    row.likes_count = nextLikes;
    row.updated_at = new Date().toISOString();
    parsedData.reactionCounts = compact;
    parsedData.likeCount = nextLikes;
    row.data_json = JSON.stringify(parsedData);

    if (!skipMirror) {
      this.mirrorWriteThrough('published_clips.react', async (driver) => {
        if (nextReaction) {
          await driver.upsertRow(
            'social_interactions',
            {
              interaction_type: 'clip_react',
              target_id: clipId,
              actor_creator_id: actor,
              reaction_type: nextReaction,
              created_at: Date.now(),
            },
            'interaction_type,target_id,actor_creator_id',
          );
        } else {
          await driver.deleteRows(
            'social_interactions',
            `interaction_type=eq.clip_react&target_id=eq.${encodeURIComponent(clipId)}&actor_creator_id=eq.${encodeURIComponent(actor)}`,
          );
        }
        await driver.patchRows(
          'published_clips',
          `id=eq.${encodeURIComponent(clipId)}`,
          {
            reaction_counts_json: compact,
            likes_count: nextLikes,
            data_json: parsedData,
            updated_at: Date.now(),
          },
        );
      });
    }

    return {
      success: true,
      targetId: clipId,
      myReaction: nextReaction,
      reactionCounts: compact,
      likeCount: nextLikes,
      liked: nextReaction !== null,
    };
  }

  public async reactToClipAsync(
    clipId: string,
    actorCreatorId = 'creator_cern',
    reactionType: KineticReactionWire | null = null,
    cOrEnv?: unknown,
  ): Promise<KineticReactionMutationResult> {
    const result = this.reactToClip(clipId, actorCreatorId, reactionType, true);
    if (!result.success) return result;
    const actor = canonicalizeCreatorId(actorCreatorId);
    const row = this.publishedClips.get(clipId);
    const parsedData = row ? this.parseJsonField(row.data_json) : {};
    await this.awaitWriteThrough(
      'published_clips.react',
      async (driver) => {
        await Promise.all([
          result.myReaction
            ? driver.upsertRow(
              'social_interactions',
              {
                interaction_type: 'clip_react',
                target_id: clipId,
                actor_creator_id: actor,
                reaction_type: result.myReaction,
                created_at: Date.now(),
              },
              'interaction_type,target_id,actor_creator_id',
            )
            : driver.deleteRows(
              'social_interactions',
              `interaction_type=eq.clip_react&target_id=eq.${encodeURIComponent(clipId)}&actor_creator_id=eq.${encodeURIComponent(actor)}`,
            ),
          driver.patchRows(
            'published_clips',
            `id=eq.${encodeURIComponent(clipId)}`,
            {
              reaction_counts_json: result.reactionCounts,
              likes_count: result.likeCount,
              data_json: parsedData,
              updated_at: Date.now(),
            },
          ),
        ]);
      },
      cOrEnv,
    );
    return result;
  }

  public insertReelComment(comment: Record<string, any>): void {
    const id = String(comment.id);
    const reelId = String(comment.clipId || comment.postId || comment.reelId);
    const creatorId = String(
      comment.userId || comment.creatorId || 'creator_cern',
    );
    const content = String(comment.text || comment.content || '');
    const parentCommentId = comment.parentCommentId
      ? String(comment.parentCommentId).trim() || null
      : null;
    const replyToHandle = comment.replyToHandle
      ? String(comment.replyToHandle).trim() || null
      : null;
    const gifUrl = comment.gifUrl ? String(comment.gifUrl).trim() || null : null;
    const stickerId = comment.stickerId
      ? String(comment.stickerId).trim() || null
      : null;
    const mediaAspectRatio =
      typeof comment.mediaAspectRatio === 'number' &&
        Number.isFinite(comment.mediaAspectRatio)
        ? comment.mediaAspectRatio
        : null;
    const reactionCounts = compactReactionCounts(
      normalizeReactionCounts(comment.reactionCounts),
    );
    const createdAt = String(comment.createdAt || new Date().toISOString());
    this.reelComments.set(id, {
      id,
      reel_id: reelId,
      creator_id: creatorId,
      content,
      language_code: comment.languageCode ? String(comment.languageCode) : null,
      parent_comment_id: parentCommentId,
      reply_to_handle: replyToHandle,
      reaction_counts_json: JSON.stringify(reactionCounts),
      gif_url: gifUrl,
      sticker_id: stickerId,
      media_aspect_ratio: mediaAspectRatio,
      data_json: JSON.stringify({
        ...comment,
        reactionCounts,
        ...(gifUrl ? { gifUrl } : {}),
        ...(stickerId ? { stickerId } : {}),
        ...(mediaAspectRatio !== null ? { mediaAspectRatio } : {}),
        ...(parentCommentId ? { parentCommentId } : {}),
        ...(replyToHandle ? { replyToHandle } : {}),
      }),
      created_at: createdAt,
    });
    this.mirrorWriteThrough('reel_comments.upsert', async (driver) => {
      await driver.upsertRow(
        'reel_comments',
        {
          id,
          clip_id: reelId,
          user_id: creatorId,
          username: String(comment.username ?? `@${creatorId.replace(/^creator_/, '')}`),
          display_name: String(comment.displayName ?? comment.creatorName ?? 'Creator'),
          avatar_url: String(comment.avatarUrl ?? ''),
          is_creator: Boolean(comment.isCreator ?? false),
          text: content,
          likes_count: Number(comment.likeCount ?? 0),
          reaction_counts_json: reactionCounts,
          gif_url: gifUrl,
          sticker_id: stickerId,
          media_aspect_ratio: mediaAspectRatio,
          user_reel_loves: Number(comment.userReelLoves ?? 0),
          gift_emoji: comment.giftEmoji ? String(comment.giftEmoji) : null,
          gift_name: comment.giftName ? String(comment.giftName) : null,
          parent_comment_id: parentCommentId,
          reply_to_handle: replyToHandle,
          timestamp_ms: Date.parse(createdAt) || Date.now(),
          data_json: comment,
        },
        'id',
      );
    });
  }

  private mapReelCommentRow(r: Record<string, any>): Record<string, any> {
    let data: Record<string, any> = {};
    try {
      data = JSON.parse(String(r.data_json || '{}'));
    } catch {
      data = {};
    }
    const parentCommentId =
      data.parentCommentId ?? r.parent_comment_id ?? undefined;
    const replyToHandle =
      data.replyToHandle ?? r.reply_to_handle ?? undefined;
    const userId = String(data.userId ?? r.creator_id);
    const username = String(
      data.username ?? r.username ?? `@${userId.replace(/^creator_/, '')}`,
    );
    const displayName = String(
      data.displayName ?? r.display_name ?? data.creatorName ?? 'Creator',
    );
    const avatarUrl = String(data.avatarUrl ?? r.avatar_url ?? '');
    const isCreator = Boolean(data.isCreator ?? r.is_creator ?? false);
    const likeCount = Number(r.likes_count ?? data.likeCount ?? 0);
    const reactionCounts = compactReactionCounts(
      normalizeReactionCounts(r.reaction_counts_json ?? data.reactionCounts),
    );
    const gifUrl = data.gifUrl ?? r.gif_url ?? undefined;
    const stickerId = data.stickerId ?? r.sticker_id ?? undefined;
    const mediaAspectRatio =
      data.mediaAspectRatio ?? r.media_aspect_ratio ?? undefined;

    return {
      ...data,
      id: String(r.id),
      clipId: String(data.clipId ?? r.reel_id),
      userId,
      username,
      displayName,
      avatarUrl,
      isCreator,
      text: String(data.text ?? r.content),
      likeCount,
      reactionCounts,
      ...(gifUrl ? { gifUrl: String(gifUrl) } : {}),
      ...(stickerId ? { stickerId: String(stickerId) } : {}),
      ...(typeof mediaAspectRatio === 'number' &&
        Number.isFinite(mediaAspectRatio)
        ? { mediaAspectRatio }
        : {}),
      ...(parentCommentId ? { parentCommentId: String(parentCommentId) } : {}),
      ...(replyToHandle ? { replyToHandle: String(replyToHandle) } : {}),
      createdAt: String(data.createdAt ?? r.created_at),
    };
  }

  public getReelCommentById(commentId: string): Record<string, any> | null {
    const row = this.reelComments.get(commentId);
    return row ? this.mapReelCommentRow(row) : null;
  }

  public listReelCommentsByClip(clipId: string): Record<string, any>[] {
    return Array.from(this.reelComments.values())
      .filter((r) => r.reel_id === clipId)
      .reverse()
      .map((r) => this.mapReelCommentRow(r));
  }

  public hasSocialInteraction(
    interactionType: string,
    targetId: string,
    actorCreatorId: string,
  ): boolean {
    const key = `${interactionType}::${targetId}::${canonicalizeCreatorId(actorCreatorId)}`;
    return this.socialInteractions.has(key);
  }

  public setSocialInteraction(
    interactionType: string,
    targetId: string,
    actorCreatorId: string,
    active: boolean,
  ): boolean {
    const canonicalActor = canonicalizeCreatorId(actorCreatorId);
    const key = `${interactionType}::${targetId}::${canonicalActor}`;
    if (active) {
      this.socialInteractions.add(key);
    } else {
      this.socialInteractions.delete(key);
    }
    this.mirrorWriteThrough(async (driver) => {
      if (active) {
        await driver.upsertRow(
          'social_interactions',
          {
            interaction_type: interactionType,
            target_id: targetId,
            actor_creator_id: canonicalActor,
            created_at: Date.now(),
          },
          'interaction_type,target_id,actor_creator_id',
        );
      } else {
        await driver.deleteRows(
          'social_interactions',
          `interaction_type=eq.${encodeURIComponent(interactionType)}&target_id=eq.${encodeURIComponent(targetId)}&actor_creator_id=eq.${encodeURIComponent(canonicalActor)}`,
        );
      }
    });
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
    const actor = canonicalizeCreatorId(actorCreatorId);
    const targets = new Set<string>();
    const prefix = `${interactionType}::`;
    const suffix = `::${actor}`;
    for (const k of this.socialInteractions) {
      if (k.startsWith(prefix) && k.endsWith(suffix)) {
        const targetId = k.slice(prefix.length, k.length - suffix.length);
        targets.add(targetId);
      }
    }
    return targets;
  }

  public countSocialInteractionActors(
    interactionType: string,
    targetId: string,
  ): number {
    const prefix = `${interactionType}::${targetId}::`;
    let count = 0;
    for (const k of this.socialInteractions) {
      if (k.startsWith(prefix)) count += 1;
    }
    return count;
  }

  // ---------------------------------------------------------------------------
  // Persistent Voice Clones & Sound Signatures (Phase 75: 12s SWR + Async)
  // ---------------------------------------------------------------------------

  private hydrateVoiceCloneRows(voiceRows: Array<Record<string, any>>): void {
    for (const vc of voiceRows) {
      if (!vc.voice_id) continue;
      const id = String(vc.voice_id);
      const createdAt = String(vc.created_at ?? new Date().toISOString());
      this.voiceClones.set(id, {
        id,
        voiceId: id,
        creatorId: canonicalizeCreatorId(String(vc.creator_id ?? 'creator_cern')),
        displayName: String(vc.display_name ?? 'Cloned Voice'),
        creatorName: String(vc.display_name ?? 'Cloned Voice'),
        consentVerified: Boolean(vc.consent_verified ?? true),
        referenceAudioDurationSec: Number(vc.reference_audio_duration_sec ?? 15.0),
        r2ReferenceUrl: String(vc.r2_reference_url ?? ''),
        pitchRangeHz: vc.pitch_range_hz_json ?? [110, 660],
        timbreEmbedding: vc.timbre_embedding_json ?? [],
        timbreEmbeddingPreview: vc.timbre_embedding_json ?? [],
        createdAt,
        createdAtIso: createdAt,
      });
    }
  }

  private hydrateSoundSignatureRows(signaturesRows: Array<Record<string, any>>): void {
    for (const ss of signaturesRows) {
      if (!ss.id) continue;
      const parsedData =
        ss.data_json && typeof ss.data_json === 'object'
          ? (ss.data_json as Record<string, any>)
          : {};
      this.soundSignatures.set(String(ss.id), {
        ...parsedData,
        id: String(ss.id),
        creatorId: canonicalizeCreatorId(
          String(ss.creator_id ?? parsedData.creatorId ?? 'creator_cern'),
        ),
        name: String(ss.name ?? parsedData.displayCode ?? 'Sound Signature'),
        category: String(ss.category ?? 'vocal_DNA'),
        status: String(ss.status ?? 'awaiting_upload'),
        r2AudioKey: String(ss.r2_audio_key ?? parsedData.r2AudioKey ?? ''),
        recipe: ss.recipe_json ?? parsedData.recipe ?? {},
        embedding: ss.embedding_json ?? parsedData.embedding ?? [],
        consentAtIso: String(ss.consent_at_iso ?? parsedData.consentAtIso ?? ''),
      });
    }
  }

  public async syncVoicesFromCloud(
    force = false,
    cOrEnv?: unknown,
  ): Promise<boolean> {
    const driver = this.resolveCloudDriver(cOrEnv);
    if (!driver.isConfigured()) return false;

    const domainKey = 'voices:global';
    const lastHydrated = this.domainHydratedAtMs.get(domainKey) ?? 0;
    if (
      !force &&
      lastHydrated > 0 &&
      Date.now() - lastHydrated < EdgeIsolateDatabaseEngine.DEFAULT_SWR_TTL_MS
    ) {
      return true;
    }

    const existingFlight = this.domainInFlightPromises.get(domainKey);
    if (existingFlight && !force) {
      return existingFlight;
    }

    const syncPromise = (async (): Promise<boolean> => {
      const [voicesRes, sigsRes] = await Promise.all([
        EdgeIsolateDatabaseEngine.withTimeoutResult(
          driver.selectRows<Record<string, any>>('voice_clones', 'select=*&limit=200'),
          3500,
        ),
        EdgeIsolateDatabaseEngine.withTimeoutResult(
          driver.selectRows<Record<string, any>>('sound_signatures', 'select=*&limit=200'),
          3500,
        ),
      ]);

      if (voicesRes.ok) this.hydrateVoiceCloneRows(voicesRes.value);
      if (sigsRes.ok) this.hydrateSoundSignatureRows(sigsRes.value);

      const allSucceeded = voicesRes.ok && sigsRes.ok;
      if (allSucceeded) {
        this.domainHydratedAtMs.set(domainKey, Date.now());
      }
      return allSucceeded;
    })().finally(() => {
      if (this.domainInFlightPromises.get(domainKey) === syncPromise) {
        this.domainInFlightPromises.delete(domainKey);
      }
    });

    this.domainInFlightPromises.set(domainKey, syncPromise);
    return syncPromise;
  }

  private buildVoiceCloneCloudRow(profile: Record<string, any>): {
    voiceId: string;
    mergedProfile: Record<string, any>;
    row: Record<string, any>;
  } {
    const voiceId = String(profile.voiceId || profile.id);
    const mergedProfile = { ...profile, id: voiceId, voiceId };
    return {
      voiceId,
      mergedProfile,
      row: {
        voice_id: voiceId,
        creator_id: canonicalizeCreatorId(String(profile.creatorId || 'creator_cern')),
        display_name: String(profile.displayName || profile.creatorName || 'Cloned Voice'),
        consent_verified: Boolean(profile.consentVerified ?? true),
        reference_audio_duration_sec: Number(profile.referenceAudioDurationSec ?? 15.0),
        r2_reference_url: String(profile.r2ReferenceUrl || ''),
        pitch_range_hz_json: profile.pitchRangeHz ?? [110, 660],
        timbre_embedding_json: profile.timbreEmbedding ?? profile.timbreEmbeddingPreview ?? [],
        created_at: String(profile.createdAt || profile.createdAtIso || new Date().toISOString()),
      },
    };
  }

  public upsertVoiceClone(profile: Record<string, any>): void {
    const { voiceId, mergedProfile, row } = this.buildVoiceCloneCloudRow(profile);
    this.voiceClones.set(voiceId, mergedProfile);
    this.mirrorWriteThrough('voice_clones.upsert', async (driver) => {
      await driver.upsertRow('voice_clones', row, 'voice_id');
    });
  }

  public async upsertVoiceCloneAsync(
    profile: Record<string, any>,
    cOrEnv?: unknown,
  ): Promise<void> {
    const { voiceId, mergedProfile, row } = this.buildVoiceCloneCloudRow(profile);
    this.voiceClones.set(voiceId, mergedProfile);
    await this.awaitWriteThrough(
      'voice_clones.upsert',
      async (driver) => {
        await driver.upsertRow('voice_clones', row, 'voice_id');
      },
      cOrEnv,
    );
  }

  public getVoiceCloneById(voiceId: string): Record<string, any> | null {
    return this.voiceClones.get(voiceId) ?? null;
  }

  private buildSoundSignatureCloudRow(sig: Record<string, any>): {
    id: string;
    row: Record<string, any>;
  } {
    const id = String(sig.id);
    return {
      id,
      row: {
        id,
        creator_id: canonicalizeCreatorId(String(sig.creatorId || 'creator_cern')),
        name: String(sig.name || sig.displayCode || 'Sound Signature'),
        category: String(sig.category || 'vocal_DNA'),
        status: String(sig.status || 'awaiting_upload'),
        r2_audio_key: String(sig.r2AudioKey || ''),
        recipe_json: sig.recipe ?? {},
        embedding_json: sig.embedding ?? [],
        consent_at_iso: String(sig.consentAtIso || ''),
        data_json: sig,
        updated_at: Date.now(),
      },
    };
  }

  public upsertSoundSignature(sig: Record<string, any>): void {
    const { id, row } = this.buildSoundSignatureCloudRow(sig);
    this.soundSignatures.set(id, { ...sig });
    this.mirrorWriteThrough('sound_signatures.upsert', async (driver) => {
      await driver.upsertRow('sound_signatures', row, 'id');
    });
  }

  public async upsertSoundSignatureAsync(
    sig: Record<string, any>,
    cOrEnv?: unknown,
  ): Promise<void> {
    const { id, row } = this.buildSoundSignatureCloudRow(sig);
    this.soundSignatures.set(id, { ...sig });
    await this.awaitWriteThrough(
      'sound_signatures.upsert',
      async (driver) => {
        await driver.upsertRow('sound_signatures', row, 'id');
      },
      cOrEnv,
    );
  }

  public getSoundSignatureById(sigId: string): Record<string, any> | null {
    return this.soundSignatures.get(sigId) ?? null;
  }

  public deleteSoundSignature(sigId: string): boolean {
    const deleted = this.soundSignatures.delete(sigId);
    if (deleted) {
      this.mirrorWriteThrough('sound_signatures.delete', async (driver) => {
        await driver.deleteRows('sound_signatures', `id=eq.${encodeURIComponent(sigId)}`);
      });
    }
    return deleted;
  }

  public async deleteSoundSignatureAsync(
    sigId: string,
    cOrEnv?: unknown,
  ): Promise<boolean> {
    const deleted = this.soundSignatures.delete(sigId);
    if (deleted) {
      await this.awaitWriteThrough(
        'sound_signatures.delete',
        async (driver) => {
          await driver.deleteRows('sound_signatures', `id=eq.${encodeURIComponent(sigId)}`);
        },
        cOrEnv,
      );
    }
    return deleted;
  }

  // ---------------------------------------------------------------------------
  // Phase 67: Sovereign Notifications & 10 Free Monthly Songs Quota Engine
  // ---------------------------------------------------------------------------

  public listNotifications(userId: string): NotificationRecord[] {
    const cid = canonicalizeCreatorId(userId);
    return Array.from(this.notifications.values())
      .filter((n) => n.userId === cid)
      .sort((a, b) => b.createdAt.localeCompare(a.createdAt));
  }

  private buildNotificationRecord(input: UpsertNotificationInput): NotificationRecord {
    const cid = canonicalizeCreatorId(input.userId);
    const existing = this.notifications.get(input.id);
    const record: NotificationRecord = {
      id: input.id,
      userId: cid,
      title: input.title,
      message: input.message,
      body: input.message,
      category: input.category ?? existing?.category ?? 'creatorActivity',
      subtype: input.subtype !== undefined ? input.subtype : (existing?.subtype ?? null),
      priority: input.priority ?? existing?.priority ?? 'normal',
      isRead: existing ? existing.isRead : Boolean(input.isRead ?? false),
      targetRoute:
        input.targetRoute !== undefined
          ? input.targetRoute
          : (existing?.targetRoute ?? null),
      targetEntityId:
        input.targetEntityId !== undefined
          ? input.targetEntityId
          : (existing?.targetEntityId ?? null),
      ctaLabel:
        input.ctaLabel !== undefined
          ? input.ctaLabel
          : (existing?.ctaLabel ?? null),
      metadata: input.metadata ?? existing?.metadata ?? {},
      createdAt: input.createdAt ?? existing?.createdAt ?? new Date().toISOString(),
    };
    this.notifications.set(record.id, record);
    return record;
  }

  private notificationRowPayload(record: NotificationRecord): Record<string, unknown> {
    return {
      id: record.id,
      user_id: record.userId,
      title: record.title,
      body: record.body,
      category: record.category,
      subtype: record.subtype,
      priority: record.priority,
      is_read: record.isRead,
      target_route: record.targetRoute,
      target_entity_id: record.targetEntityId,
      cta_label: record.ctaLabel,
      metadata_json: record.metadata,
      created_at: record.createdAt,
    };
  }

  public upsertNotification(input: UpsertNotificationInput): NotificationRecord {
    const record = this.buildNotificationRecord(input);
    this.mirrorWriteThrough('notifications.upsert', async (driver) => {
      await driver.upsertRow('notifications', this.notificationRowPayload(record), 'id');
    });
    return record;
  }

  public async upsertNotificationAsync(
    input: UpsertNotificationInput,
    cOrEnv?: unknown,
  ): Promise<NotificationRecord> {
    const record = this.buildNotificationRecord(input);
    await this.awaitWriteThrough(
      'notifications.upsert',
      async (driver) => {
        await driver.upsertRow('notifications', this.notificationRowPayload(record), 'id');
      },
      cOrEnv,
    );
    return record;
  }

  public markNotificationRead(userId: string, id: string): NotificationRecord | null {
    const cid = canonicalizeCreatorId(userId);
    const existing = this.notifications.get(id);
    if (!existing || existing.userId !== cid) {
      return null;
    }
    const updated: NotificationRecord = { ...existing, isRead: true };
    this.notifications.set(id, updated);
    this.mirrorWriteThrough(async (driver) => {
      await driver.patchRows(
        'notifications',
        `id=eq.${encodeURIComponent(id)}&user_id=eq.${encodeURIComponent(cid)}`,
        { is_read: true },
      );
    });
    return updated;
  }

  public markAllNotificationsRead(userId: string): number {
    const cid = canonicalizeCreatorId(userId);
    let updatedCount = 0;
    for (const [id, n] of this.notifications.entries()) {
      if (n.userId === cid && !n.isRead) {
        this.notifications.set(id, { ...n, isRead: true });
        updatedCount += 1;
      }
    }
    if (updatedCount > 0) {
      this.mirrorWriteThrough(async (driver) => {
        await driver.patchRows(
          'notifications',
          `user_id=eq.${encodeURIComponent(cid)}&is_read=eq.false`,
          { is_read: true },
        );
      });
    }
    return updatedCount;
  }

  public deleteNotification(userId: string, id: string): boolean {
    const cid = canonicalizeCreatorId(userId);
    const existing = this.notifications.get(id);
    if (!existing || existing.userId !== cid) {
      return false;
    }
    this.notifications.delete(id);
    this.mirrorWriteThrough(async (driver) => {
      await driver.deleteRows(
        'notifications',
        `id=eq.${encodeURIComponent(id)}&user_id=eq.${encodeURIComponent(cid)}`,
      );
    });
    return true;
  }

  public getCreatorQuota(userId: string): CreatorQuotaRecord {
    const cid = canonicalizeCreatorId(userId);
    const now = Date.now();
    const existing = this.creatorQuotas.get(cid);
    const resetAtMs = existing ? Date.parse(existing.cycleResetAt) : 0;

    if (!existing || (Number.isFinite(resetAtMs) && resetAtMs > 0 && now >= resetAtMs)) {
      const nextResetIso = new Date(now + 30 * 24 * 60 * 60 * 1000).toISOString();
      const nowIso = new Date(now).toISOString();
      const limit = existing?.freeMonthlySongsLimit ?? 10;
      const fresh: CreatorQuotaRecord = {
        userId: cid,
        planTier: existing?.planTier ?? 'free',
        freeMonthlySongsLimit: limit,
        freeMonthlySongsUsed: 0,
        freeMonthlySongsRemaining: limit,
        cycleResetAt: nextResetIso,
        updatedAt: nowIso,
      };
      this.creatorQuotas.set(cid, fresh);
      this.mirrorWriteThrough(async (driver) => {
        await driver.upsertRow(
          'creator_quotas',
          {
            user_id: fresh.userId,
            plan_tier: fresh.planTier,
            free_monthly_songs_limit: fresh.freeMonthlySongsLimit,
            free_monthly_songs_used: fresh.freeMonthlySongsUsed,
            cycle_reset_at: fresh.cycleResetAt,
            updated_at: fresh.updatedAt,
          },
          'user_id',
        );
      });
      return fresh;
    }
    return existing;
  }

  public consumeFreeMonthlySongQuota(userId: string): CreatorQuotaRecord {
    const current = this.getCreatorQuota(userId);
    const nowIso = new Date().toISOString();
    const nextUsed = Math.min(
      current.freeMonthlySongsLimit,
      current.freeMonthlySongsUsed + 1,
    );
    const updated: CreatorQuotaRecord = {
      ...current,
      freeMonthlySongsUsed: nextUsed,
      freeMonthlySongsRemaining: Math.max(0, current.freeMonthlySongsLimit - nextUsed),
      updatedAt: nowIso,
    };
    this.creatorQuotas.set(current.userId, updated);
    this.mirrorWriteThrough(async (driver) => {
      await driver.upsertRow(
        'creator_quotas',
        {
          user_id: updated.userId,
          plan_tier: updated.planTier,
          free_monthly_songs_limit: updated.freeMonthlySongsLimit,
          free_monthly_songs_used: updated.freeMonthlySongsUsed,
          cycle_reset_at: updated.cycleResetAt,
          updated_at: updated.updatedAt,
        },
        'user_id',
      );
    });
    return updated;
  }

  public async consumeFreeMonthlySongQuotaAsync(
    userId: string,
    cOrEnv?: unknown,
  ): Promise<AtomicQuotaConsumeResult> {
    const cid = canonicalizeCreatorId(userId);
    const driver = this.resolveCloudDriver(cOrEnv);
    if (driver.isConfigured()) {
      try {
        const rpcRes = await driver.callRpc<Record<string, any>>(
          'consume_free_monthly_song_quota_atomic',
          { p_user_id: cid },
        );
        if (rpcRes && typeof rpcRes === 'object') {
          const limit = Number(rpcRes.freeMonthlySongsLimit ?? 10);
          const used = Number(rpcRes.freeMonthlySongsUsed ?? 0);
          const remaining = Number(
            rpcRes.freeMonthlySongsRemaining ?? Math.max(0, limit - used),
          );
          const record: CreatorQuotaRecord = {
            userId: cid,
            planTier: String(rpcRes.planTier ?? 'free'),
            freeMonthlySongsLimit: limit,
            freeMonthlySongsUsed: used,
            freeMonthlySongsRemaining: remaining,
            cycleResetAt: String(
              rpcRes.cycleResetAt ??
              new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
            ),
            updatedAt: String(rpcRes.updatedAt ?? new Date().toISOString()),
          };
          this.creatorQuotas.set(cid, record);
          this.domainHydratedAtMs.set(`quota:${cid}`, Date.now());
          return {
            ...record,
            allowed: Boolean(rpcRes.allowed ?? true),
          };
        }
      } catch (err) {
        this.recordWriteThroughFailure('creator_quotas.consume_atomic_rpc', err);
      }
    }

    const before = this.getCreatorQuota(cid);
    const isPaid =
      before.planTier.toLowerCase() !== 'free' || before.freeMonthlySongsLimit < 0;
    const allowed =
      isPaid || before.freeMonthlySongsUsed < before.freeMonthlySongsLimit;
    const updated = allowed ? this.consumeFreeMonthlySongQuota(cid) : before;
    return { ...updated, allowed };
  }

  // ---------------------------------------------------------------------------
  // Phase 79: Durable User Media Uploads Registry & 12s Edge SWR (REQ-P79-BE-02)
  // ---------------------------------------------------------------------------
  private readonly userMediaUploads = new Map<string, UserMediaUploadRecord>();

  private hydrateUserMediaUploadRows(rows: Array<Record<string, unknown>>): void {
    for (const raw of rows) {
      const normalized = normalizeUserMediaUploadRow(raw);
      if (normalized.id) {
        this.userMediaUploads.set(normalized.id, normalized);
      }
    }
  }

  public recordUserMediaUpload(
    input: Partial<UserMediaUploadRecord> & {
      id: string;
      r2Key: string;
      remoteUrl: string;
    },
    skipMirror = false,
  ): UserMediaUploadRecord {
    const record = normalizeUserMediaUploadRow({
      ...input,
      creatorId: canonicalizeCreatorId(input.creatorId ?? 'creator_cern'),
      createdAt: input.createdAt ?? new Date().toISOString(),
    });
    this.userMediaUploads.set(record.id, record);
    if (!skipMirror) {
      this.mirrorWriteThrough('user_media_uploads.upsert', (driver) =>
        driver.upsertRow(
          'user_media_uploads',
          {
            id: record.id,
            creator_id: record.creatorId,
            media_kind: record.mediaKind,
            title: record.title,
            filename: record.filename,
            mime_type: record.mimeType,
            size_bytes: record.sizeBytes,
            duration_ms: record.durationMs,
            width: record.width,
            height: record.height,
            r2_key: record.r2Key,
            remote_url: record.remoteUrl,
            thumbnail_url: record.thumbnailUrl,
            source_surface: record.sourceSurface,
            created_at: record.createdAt,
            deleted_at: record.deletedAt,
          },
          'id',
        ),
      );
    }
    return record;
  }

  public async recordUserMediaUploadAsync(
    input: Partial<UserMediaUploadRecord> & {
      id: string;
      r2Key: string;
      remoteUrl: string;
    },
    cOrEnv?: unknown,
  ): Promise<UserMediaUploadRecord> {
    const record = this.recordUserMediaUpload(input, true);
    await this.awaitWriteThrough(
      'user_media_uploads.upsert_async',
      async (driver) => {
        await driver.upsertRow(
          'user_media_uploads',
          {
            id: record.id,
            creator_id: record.creatorId,
            media_kind: record.mediaKind,
            title: record.title,
            filename: record.filename,
            mime_type: record.mimeType,
            size_bytes: record.sizeBytes,
            duration_ms: record.durationMs,
            width: record.width,
            height: record.height,
            r2_key: record.r2Key,
            remote_url: record.remoteUrl,
            thumbnail_url: record.thumbnailUrl,
            source_surface: record.sourceSurface,
            created_at: record.createdAt,
            deleted_at: record.deletedAt,
          },
          'id',
        );
      },
      cOrEnv,
    );
    return record;
  }

  public getUserMediaUploadById(id: string): UserMediaUploadRecord | null {
    const found = this.userMediaUploads.get(id);
    if (!found || found.deletedAt) return null;
    return found;
  }

  public listUserMediaUploads(
    creatorId: string,
    kind?: MediaUploadKindWire,
  ): UserMediaUploadRecord[] {
    const cid = canonicalizeCreatorId(creatorId);
    const items = Array.from(this.userMediaUploads.values()).filter((u) => {
      if (u.deletedAt) return false;
      if (canonicalizeCreatorId(u.creatorId) !== cid) return false;
      if (kind && u.mediaKind !== kind) return false;
      return true;
    });
    items.sort((a, b) => b.createdAt.localeCompare(a.createdAt));
    return items;
  }

  public async syncUserMediaUploadsFromCloud(
    creatorId: string,
    cOrEnv?: unknown,
    force = false,
  ): Promise<UserMediaUploadRecord[]> {
    const cid = canonicalizeCreatorId(creatorId);
    const driver = this.resolveCloudDriver(cOrEnv);
    if (!driver.isConfigured()) {
      return this.listUserMediaUploads(cid);
    }

    const domainKey = `media_uploads:${cid}`;
    const lastHydrated = this.domainHydratedAtMs.get(domainKey) ?? 0;
    if (
      !force &&
      lastHydrated > 0 &&
      Date.now() - lastHydrated < EdgeIsolateDatabaseEngine.DEFAULT_SWR_TTL_MS
    ) {
      return this.listUserMediaUploads(cid);
    }

    const existing = this.domainInFlightPromises.get(domainKey);
    if (existing && !force) {
      await existing;
      return this.listUserMediaUploads(cid);
    }

    const flight = (async (): Promise<boolean> => {
      const res = await EdgeIsolateDatabaseEngine.withTimeoutResult(
        driver.selectRows<Record<string, unknown>>(
          'user_media_uploads',
          `select=*&creator_id=eq.${encodeURIComponent(cid)}&order=created_at.desc&limit=200`,
        ),
        3500,
      );
      if (res.ok) {
        this.hydrateUserMediaUploadRows(res.value);
        this.domainHydratedAtMs.set(domainKey, Date.now());
        return true;
      }
      return false;
    })().finally(() => {
      if (this.domainInFlightPromises.get(domainKey) === flight) {
        this.domainInFlightPromises.delete(domainKey);
      }
    });

    this.domainInFlightPromises.set(domainKey, flight);
    await flight;
    return this.listUserMediaUploads(cid);
  }

  public deleteUserMediaUpload(
    id: string,
    creatorId?: string,
    skipMirror = false,
  ): boolean {
    const existing = this.userMediaUploads.get(id);
    if (!existing || existing.deletedAt) return false;
    if (
      creatorId &&
      canonicalizeCreatorId(existing.creatorId) !== canonicalizeCreatorId(creatorId)
    ) {
      return false;
    }
    const deletedAt = new Date().toISOString();
    this.userMediaUploads.set(id, { ...existing, deletedAt });
    if (!skipMirror) {
      this.mirrorWriteThrough('user_media_uploads.soft_delete', (driver) =>
        driver.patchRows(
          'user_media_uploads',
          `id=eq.${encodeURIComponent(id)}`,
          { deleted_at: deletedAt },
        ),
      );
    }
    return true;
  }

  public async deleteUserMediaUploadAsync(
    id: string,
    creatorId?: string,
    cOrEnv?: unknown,
  ): Promise<boolean> {
    const deleted = this.deleteUserMediaUpload(id, creatorId, true);
    if (!deleted) return false;
    const deletedAt =
      this.userMediaUploads.get(id)?.deletedAt ?? new Date().toISOString();
    await this.awaitWriteThrough(
      'user_media_uploads.soft_delete_async',
      async (driver) => {
        await driver.patchRows(
          'user_media_uploads',
          `id=eq.${encodeURIComponent(id)}`,
          { deleted_at: deletedAt },
        );
      },
      cOrEnv,
    );
    return true;
  }
}

let _edgeEngineInstance: EdgeIsolateDatabaseEngine | null = null;

export function getEdgeIsolateDatabaseEngine(): EdgeIsolateDatabaseEngine {
  if (!_edgeEngineInstance) {
    _edgeEngineInstance = new EdgeIsolateDatabaseEngine();
  }
  return _edgeEngineInstance;
}

export class EdgePersistenceBridge {
  private static activeContext: Context | Record<string, unknown> | undefined;

  public static setActiveContext(
    cOrEnv?: Context | Record<string, unknown>,
  ): void {
    EdgePersistenceBridge.activeContext = cOrEnv;
  }

  public static getActiveContext():
    | Context
    | Record<string, unknown>
    | undefined {
    return EdgePersistenceBridge.activeContext;
  }

  public static getCloudDriver(
    cOrEnv?: Context | Record<string, unknown>,
  ): SupabaseCloudDriver {
    return new SupabaseCloudDriver(cOrEnv as Record<string, unknown>);
  }

  public static resolveActiveEngineMode(
    isSqliteAvailable: boolean,
    cOrEnv?: Context | Record<string, unknown>,
  ): 'node_sqlite' | 'supabase_cloud' | 'edge_isolate_memory' {
    const cloud = this.getCloudDriver(cOrEnv);
    if (cloud.isConfigured()) return 'supabase_cloud';
    if (isSqliteAvailable) return 'node_sqlite';
    return 'edge_isolate_memory';
  }

  public static normalizePostgresRows(
    table: string,
    rows: Array<Record<string, unknown>>,
  ): Array<Record<string, unknown>> {
    switch (table) {
      case 'wallet_ledger':
        return rows.map((r) => ({ ...r, ...normalizeWalletLedgerRow(r) }));
      case 'beat_licenses':
        return rows.map(normalizeBeatLicenseRow);
      case 'user_library_sync':
        return rows.map(normalizeLibrarySyncRow);
      case 'sync_mutation_log':
        return rows.map(normalizeSyncMutationRow);
      case 'playlists':
        return rows.map(normalizePlaylistRow);
      case 'marketplace_assets':
        return rows.map(normalizeMarketplaceAssetRow);
      default:
        return rows;
    }
  }
}

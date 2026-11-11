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

export interface SaBankMetadata {
  canonicalName: string;
  code: string;
  universalBranchCode: string;
  supportsCapitecPay: boolean;
  supportsOzow: boolean;
  supportsPayFast: boolean;
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
  private static cachedDefaultSeedHash: string | null = null;

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

  constructor() {
    this.seedDefaults();
  }

  private static getDefaultSeedPasswordHash(): string {
    if (!EdgeIsolateDatabaseEngine.cachedDefaultSeedHash) {
      EdgeIsolateDatabaseEngine.cachedDefaultSeedHash = hashPassword(
        EdgeIsolateDatabaseEngine.DEFAULT_SEED_PASSWORD,
        '7668756e616d62695f736565645f3631',
      );
    }
    return EdgeIsolateDatabaseEngine.cachedDefaultSeedHash;
  }

  private static normalizeHandle(rawHandle: string): string {
    const cleaned = rawHandle.trim().toLowerCase().replace(/^@+/, '');
    return `@${cleaned.replace(/[^a-z0-9_.-]/g, '')}`;
  }

  public resetForTesting(): void {
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
    this.seedDefaults();
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
    this.mutations.push({
      seq: this.seqCounter,
      idempotencyKey: entry.idempotencyKey,
      entityType: entry.entityType,
      entityId: entry.entityId,
      action: entry.action,
      creatorId: entry.creatorId?.trim() || 'system',
      payload: entry.payload,
      createdAt: entry.createdAt ?? new Date().toISOString(),
    });
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
        data_json: JSON.stringify({
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
          m.payload?.id || m.payload?.certificateId || m.payload?.postId || `gen_${Date.now()}`,
        );
        let shouldApply = true;

        if (commutativeCounterActions.has(m.action)) {
          if (m.entityType === 'post') {
            const p = this.kineticPosts.get(entityId);
            if (p) p.cosign_count = Number(p.cosign_count ?? 0) + 1;
          } else if (m.entityType === 'track') {
            const t = this.exploreTracks.get(entityId);
            if (t) t.like_count = Number(t.like_count ?? 0) + 1;
          }
        } else if (m.entityType === 'post' && m.action === 'create') {
          this.kineticPosts.set(entityId, {
            id: entityId,
            creator_id: m.payload.creatorId || 'creator_cern',
            creator_handle: m.payload.creatorHandle || '@cern',
            creator_name: m.payload.creatorName || 'Cern',
            caption: m.payload.caption || '',
            media_type: m.payload.mediaType || 'audio_card',
            cosign_count: m.payload.cosignCount || 0,
            cosign_target: 25,
            repost_count: 0,
            discovery_stage: 'freshCrate',
            data_json: JSON.stringify(m.payload),
            created_at: m.createdAt,
            updated_at: m.createdAt,
          });
        } else if (m.entityType === 'cosign') {
          this.cosignPost(entityId, m.payload?.creatorId);
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
    options: ExploreFeedOptions = {},
  ): { posts: any[]; total: number } {
    let posts: Record<string, any>[] = Array.from(this.kineticPosts.values()).map((r) => {
      let data: Record<string, any> = {};
      try {
        data = JSON.parse(String(r.data_json || '{}')) as Record<string, any>;
      } catch {
        data = {};
      }
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
      data_json: JSON.stringify(dataJson),
      created_at: String(existing?.created_at || input.createdAt || now),
      updated_at: now,
    };
    this.exploreTracks.set(id, row);

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

    return {
      success: true,
      postId,
      cosignCount: newCount,
      discoveryStage: newStage,
      promoted,
    };
  }

  public repostPost(
    postId: string,
  ): { success: boolean; postId: string; repostCount: number } {
    const post = this.kineticPosts.get(postId);
    if (!post) {
      return { success: false, postId, repostCount: 0 };
    }
    const newCount = Number(post.repost_count || 0) + 1;
    post.repost_count = newCount;
    post.updated_at = new Date().toISOString();
    return { success: true, postId, repostCount: newCount };
  }

  // ---------------------------------------------------------------------------
  // Cloud Vault Library Sync
  // ---------------------------------------------------------------------------

  public getLibrary(creatorId: string): any[] {
    const rows = Array.from(this.libraryItems.values())
      .filter((r) => r.creator_id === creatorId)
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
    const existing = this.libraryItems.get(id);
    if (!existing) return false;
    if (creatorId && existing.creator_id !== creatorId) return false;
    this.libraryItems.delete(id);
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

      this.libraryItems.set(id, {
        id,
        creator_id: existingRow?.creator_id ?? creatorId,
        item_type: itemType,
        title,
        data_json: JSON.stringify(merged),
        created_at: createdAt,
        updated_at: updatedAtIso,
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
    let rows = Array.from(this.playlists.values());
    if (creatorId && creatorId.trim() !== '') {
      rows = includePublic
        ? rows.filter(
          (r) => r.creator_id === creatorId || Number(r.is_public ?? 0) === 1,
        )
        : rows.filter((r) => r.creator_id === creatorId);
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
    if (creatorId && creatorId.trim() !== '' && existing.creator_id !== creatorId) {
      return false;
    }
    this.playlists.delete(id);
    if (recordMutation) {
      const now = new Date().toISOString();
      const effectiveCreator = creatorId || 'usr_me';
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

    return {
      outcome: 'committed',
      senderRemainingCoins: senderSnap.balanceCoins - coins,
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

    this.beatLicenses.set(params.certificateId, {
      certificate_id: params.certificateId,
      license_hash: licenseHash,
      beat_id: params.beatId,
      producer_id: params.producerId,
      buyer_id: params.buyerId,
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

    return { status: 'ok', licenseHash, masterFileSha256: masterDigest };
  }

  public getBeatLicensesByBuyer(buyerId: string): any[] {
    return Array.from(this.beatLicenses.values())
      .filter((r) => r.buyer_id === buyerId)
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
      const rows = this.walletLedger.get(creatorId) ?? [];
      rows.unshift({
        id: `wtx_welcome_${creatorId}`,
        creator_id: creatorId,
        type: 'topup',
        amount_zar: Number((welcomeCoins * zarRate).toFixed(2)),
        amount_coins: welcomeCoins,
        status: 'completed',
        reference: 'SOVEREIGN_GRANT',
        data_json: JSON.stringify({ note: 'Sovereign Creator Genesis Grant' }),
        created_at: now,
      });
      this.walletLedger.set(creatorId, rows);
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
    );
  }

  public rotateRefreshToken(refreshToken: string): AuthTokenBundle {
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

    const signed = signAccessJwt({
      sub: user.userId,
      cid: user.creatorId,
      hdl: user.handle,
      sid: sessionRow.sessionId,
      role: user.role,
    });

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

  public upsertGenerationJob(
    job: GenerationJob,
    creatorId = 'creator_cern',
    jobKind = 'audio_synthesis',
  ): void {
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
    };
    this.generationJobs.set(job.generationId, {
      job: merged,
      creatorId: canonicalizeCreatorId(creatorId),
      jobKind,
    });
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
    return this.marketplaceAssets.delete(beatId);
  }

  // ---------------------------------------------------------------------------
  // Persistent Social Clips, Comments & Interactions
  // ---------------------------------------------------------------------------

  public countPublishedClips(): number {
    return this.publishedClips.size;
  }

  public upsertPublishedClip(clip: Record<string, any>): void {
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
    this.publishedClips.set(id, {
      id,
      creator_id: creatorId,
      creator_handle: creatorHandle,
      video_url: String(clip.audioUrl || clip.videoUrl || ''),
      audio_title: String(clip.title || 'Untitled Clip'),
      bantu_language: clip.genre ? String(clip.genre) : null,
      views_count: Number(clip.playCount ?? clip.viewsCount ?? 0),
      likes_count: Number(clip.likeCount ?? clip.likesCount ?? 0),
      comments_count: Number(clip.commentCount ?? clip.commentsCount ?? 0),
      remixes_count: Number(clip.remixCount ?? clip.remixesCount ?? 0),
      remixed_from_clip_id: clip.remixedFromClipId
        ? String(clip.remixedFromClipId)
        : null,
      data_json: JSON.stringify({
        ...clip,
        creatorId,
        creatorUsername: creatorHandle,
      }),
      created_at: createdAt,
      updated_at: now,
    });
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
      .map((r) => this.mapPublishedClipRow(r));
  }

  public listRemixClipRows(parentClipId: string): Record<string, any>[] {
    return Array.from(this.publishedClips.values())
      .filter((r) => r.remixed_from_clip_id === parentClipId)
      .reverse()
      .map((r) => this.mapPublishedClipRow(r));
  }

  public insertReelComment(comment: Record<string, any>): void {
    const id = String(comment.id);
    const reelId = String(comment.clipId || comment.reelId);
    const creatorId = String(
      comment.userId || comment.creatorId || 'creator_cern',
    );
    const content = String(comment.text || comment.content || '');
    const createdAt = String(comment.createdAt || new Date().toISOString());
    this.reelComments.set(id, {
      id,
      reel_id: reelId,
      creator_id: creatorId,
      content,
      language_code: comment.languageCode ? String(comment.languageCode) : null,
      data_json: JSON.stringify(comment),
      created_at: createdAt,
    });
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
    const key = `${interactionType}::${targetId}::${canonicalizeCreatorId(actorCreatorId)}`;
    if (active) {
      this.socialInteractions.add(key);
    } else {
      this.socialInteractions.delete(key);
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
  // Persistent Voice Clones & Sound Signatures
  // ---------------------------------------------------------------------------

  public upsertVoiceClone(profile: Record<string, any>): void {
    const voiceId = String(profile.voiceId || profile.id);
    this.voiceClones.set(voiceId, { ...profile, voiceId });
  }

  public getVoiceCloneById(voiceId: string): Record<string, any> | null {
    return this.voiceClones.get(voiceId) ?? null;
  }

  public upsertSoundSignature(sig: Record<string, any>): void {
    this.soundSignatures.set(String(sig.id), { ...sig });
  }

  public getSoundSignatureById(sigId: string): Record<string, any> | null {
    return this.soundSignatures.get(sigId) ?? null;
  }

  public deleteSoundSignature(sigId: string): boolean {
    return this.soundSignatures.delete(sigId);
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

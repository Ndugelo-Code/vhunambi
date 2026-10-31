import { nanoid } from 'nanoid';
import {
  ClipFeedPage,
  CreateCommentRequest,
  CreatorWalletDto,
  CulturalGiftDto,
  GiftTransactionDto,
  PayoutRequest,
  PublishClipRequest,
  PublishedClipDto,
  ReelCommentDto,
  SupporterRankDto,
  TipRequest,
} from './social_types.js';

/**
 * In-memory social store (Phase 18 / Phase C).
 */
const clips = new Map<string, PublishedClipDto>();

/** Follower counts per creator id (REQ-SOC-08 / REQ-SOC-25). */
const followerCounts = new Map<string, number>();

/** Comments grouped by clip ID (Phase C). */
const commentsByClip = new Map<string, ReelCommentDto[]>();

/** Creator wallet balances & transaction ledgers (Phase C). */
interface StoredWallet {
  balanceZar: number;
  totalCoinsReceived: number;
  transactions: GiftTransactionDto[];
}
const creatorWallets = new Map<string, StoredWallet>();

/** Single-demo-user follow graph. */
const following = new Set<string>();
const ME = 'vhunambi_user';

/** Demo owner used when a publish request omits explicit identity. */
const DEFAULT_CREATOR = {
  creatorId: 'creator_makhadzi',
  creatorUsername: 'makhadzi',
  creatorDisplayName: 'Makhadzi',
  creatorAvatarUrl: null as string | null,
  isCreatorVerified: true,
};

/** The 4 Canonical African Cultural Gifts (REQ-GFT-02). */
export const CULTURAL_GIFTS: Record<string, CulturalGiftDto> = {
  cowrie_shell: {
    id: 'cowrie_shell',
    name: 'Cowrie Shell (Mbaḓi)',
    emoji: '🐚',
    coinPrice: 5,
    zarPrice: 2.0,
    culturalMeaning:
      'Ancient African currency representing honor, fertility, and lasting community appreciation.',
  },
  african_drum: {
    id: 'african_drum',
    name: 'African Drum (Ngoma)',
    emoji: '🥁',
    coinPrice: 15,
    zarPrice: 5.0,
    culturalMeaning:
      'Sacred rhythm salute honoring the primal heartbeat and syncopated spirit of the song.',
  },
  log_drum_trophy: {
    id: 'log_drum_trophy',
    name: 'Log Drum Trophy (Tshikona)',
    emoji: '🎹',
    coinPrice: 50,
    zarPrice: 15.0,
    culturalMeaning:
      'Trophy for top-tier Amapiano bassline mastery, sonic innovation, and heavy club groove.',
  },
  royal_venda_crown: {
    id: 'royal_venda_crown',
    name: 'Royal Venda Crown (Khare)',
    emoji: '👑',
    coinPrice: 200,
    zarPrice: 50.0,
    culturalMeaning:
      'Royalty honor reserved for master producers, community legends, and cultural innovators.',
  },
};

/** Newest-first ordered view of all clips. */
function orderedClips(): PublishedClipDto[] {
  return [...clips.values()].reverse();
}

/**
 * Normalizes a (possibly partial) client DNA payload into the canonical
 * `SongMetadataDna` JSON shape so the Flutter client's
 * `SongMetadataDna.fromJson` never crashes on missing sub-objects.
 */
function normalizeDna(
  partial: Record<string, unknown> | undefined,
  title: string,
  genre: string,
): Record<string, unknown> {
  const p = partial ?? {};
  const num = (v: unknown, fallback: number): number =>
    typeof v === 'number' && Number.isFinite(v) ? v : fallback;
  const str = (v: unknown, fallback: string): string =>
    typeof v === 'string' && v.length > 0 ? v : fallback;
  return {
    id: str(p.id, `dna_${title.replaceAll(/\s+/g, '_').toLowerCase()}`),
    version: str(p.version, '1.0'),
    title,
    genre,
    language: str(p.language, 'Tshivenḓa'),
    culturalContext: p.culturalContext ?? null,
    musical: {
      bpm: num((p.musical as { bpm?: unknown } | undefined)?.bpm, num(p.bpm, 112)),
      key: str((p.musical as { key?: unknown } | undefined)?.key, 'Am'),
      energyBracket: str(
        (p.musical as { energyBracket?: unknown } | undefined)?.energyBracket,
        'mid',
      ),
      durationSec: num(
        (p.musical as { durationSec?: unknown } | undefined)?.durationSec,
        180,
      ),
    },
    vocals: {
      deliveryMode: str(
        (p.vocals as { deliveryMode?: unknown } | undefined)?.deliveryMode,
        'melodic',
      ),
      gender: str((p.vocals as { gender?: unknown } | undefined)?.gender, 'male'),
      energy: str((p.vocals as { energy?: unknown } | undefined)?.energy, 'mid'),
      loras: (p.vocals as { loras?: unknown } | undefined)?.loras ?? [],
    },
    visualTheme: {
      mood: str((p.visualTheme as { mood?: unknown } | undefined)?.mood, str(p.mood, 'Cinematic')),
      comfyPrompt: str(
        (p.visualTheme as { comfyPrompt?: unknown } | undefined)?.comfyPrompt,
        `${genre} aesthetic, vibrant, cinematic`,
      ),
      negativePrompt: str(
        (p.visualTheme as { negativePrompt?: unknown } | undefined)
          ?.negativePrompt,
        'blurry, low quality, watermark, text, signature',
      ),
      seed: num((p.visualTheme as { seed?: unknown } | undefined)?.seed, 42),
      aspectRatio: str(
        (p.visualTheme as { aspectRatio?: unknown } | undefined)?.aspectRatio,
        '9:16',
      ),
    },
    alignment: Array.isArray(p.alignment) ? p.alignment : [],
  };
}

function makeClip(req: PublishClipRequest, id: string): PublishedClipDto {
  const creator = {
    creatorId: req.creatorId ?? DEFAULT_CREATOR.creatorId,
    creatorUsername: req.creatorUsername ?? DEFAULT_CREATOR.creatorUsername,
    creatorDisplayName:
      req.creatorDisplayName ?? DEFAULT_CREATOR.creatorDisplayName,
    creatorAvatarUrl: req.creatorAvatarUrl ?? DEFAULT_CREATOR.creatorAvatarUrl,
    isCreatorVerified: req.isCreatorVerified ?? DEFAULT_CREATOR.isCreatorVerified,
  };
  const genre = ((req.dna?.genre as string | undefined) ?? 'Amapiano');
  const dna = normalizeDna(req.dna, req.title, genre);
  const base = 'https://cdn.vhunambi.com/social';
  return {
    id,
    trackId: req.trackId,
    ...creator,
    title: req.title,
    caption: req.caption ?? '',
    tags: req.tags ?? [],
    genre,
    audioUrl: req.audioUrl ?? `${base}/${req.trackId}.mp3`,
    coverUrl: req.coverUrl ?? `${base}/${req.trackId}.jpg`,
    dna,
    playCount: 0,
    likeCount: 0,
    commentCount: 0,
    remixCount: 0,
    isLikedByMe: false,
    isSavedByMe: false,
    remixedFromClipId: req.remixedFromClipId,
    remixAttribution: req.remixAttribution,
    publishedAt: new Date().toISOString(),
  };
}

/** Publishes a clip and returns the share descriptor (design.md §5.1 response). */
export function publishClip(req: PublishClipRequest): {
  clipId: string;
  shareUrl: string;
  publishedAt: string;
} {
  const clipId = `clip_pub_${nanoid(8)}`;
  const clip = makeClip(req, clipId);
  clips.set(clipId, clip);

  if (!followerCounts.has(clip.creatorId)) {
    followerCounts.set(clip.creatorId, 0);
  }

  // Phase D: Viral Remix Lineage Tracking
  if (req.remixedFromClipId) {
    const parent = clips.get(req.remixedFromClipId);
    if (parent) {
      parent.remixCount += 1;
    }
  }

  return {
    clipId,
    shareUrl: `https://vhunambi.com/@${clip.creatorUsername}/reels/${clipId}`,
    publishedAt: clip.publishedAt,
  };
}

/** Cursor-paginated newest-first feed (design.md §5.2). */
export function getFeed(cursor?: string, limit = 20): ClipFeedPage {
  const all = orderedClips();
  const offset = parseOffset(cursor);
  const size = clampLimit(limit);
  const page = all.slice(offset, offset + size);
  const nextIndex = offset + size;
  return {
    clips: page,
    nextCursor: nextIndex < all.length ? String(nextIndex) : null,
  };
}

/** All clips authored by a creator, newest-first. */
export function getClipsByCreator(creatorId: string): PublishedClipDto[] {
  return orderedClips().filter((clip) => clip.creatorId === creatorId);
}

/** Toggles the demo user's like on a clip; returns null when not found. */
export function likeClip(
  clipId: string,
): { liked: boolean; likeCount: number } | null {
  const clip = clips.get(clipId);
  if (!clip) return null;
  clip.isLikedByMe = !clip.isLikedByMe;
  clip.likeCount = Math.max(0, clip.likeCount + (clip.isLikedByMe ? 1 : -1));
  return { liked: clip.isLikedByMe, likeCount: clip.likeCount };
}

/** Toggles the demo user's follow on a creator; returns state + count. */
export function followCreator(creatorId: string): {
  following: boolean;
  followerCount: number;
} {
  const key = `${ME}:${creatorId}`;
  const base = followerCounts.get(creatorId) ?? 0;
  const nowFollowing = !following.has(key);
  if (nowFollowing) following.add(key);
  else following.delete(key);
  const count = Math.max(0, base + (nowFollowing ? 1 : -1));
  followerCounts.set(creatorId, count);
  return { following: nowFollowing, followerCount: count };
}

// ---------------------------------------------------------------------------
// Phase C: Community Comments Engine (REQ-COM-01, REQ-COM-02)
// ---------------------------------------------------------------------------

/** Retrieves comments for a specific clip ID, newest first. */
export function getComments(clipId: string): ReelCommentDto[] {
  return commentsByClip.get(clipId) ?? [];
}

/** Appends a new comment to a reel thread and increments the clip's commentCount. */
export function addComment(
  clipId: string,
  req: CreateCommentRequest,
): ReelCommentDto | null {
  const clip = clips.get(clipId);
  if (!clip) return null;

  const commentId = `c_${nanoid(8)}`;
  const comment: ReelCommentDto = {
    id: commentId,
    clipId,
    userId: req.userId ?? 'user_listener',
    username: req.username ?? 'ndugelo_musician',
    displayName: req.displayName ?? 'Ndugelo Musician',
    avatarUrl: req.avatarUrl,
    isCreator: req.userId === clip.creatorId || req.username === clip.creatorUsername,
    text: req.text.trim(),
    likeCount: 0,
    isLikedByMe: false,
    userReelLoves: req.userReelLoves ?? 0,
    giftEmoji: req.giftEmoji,
    giftName: req.giftName,
    createdAt: new Date().toISOString(),
  };

  const existing = commentsByClip.get(clipId) ?? [];
  commentsByClip.set(clipId, [comment, ...existing]);
  clip.commentCount += 1;

  return comment;
}

/** Toggles like state on a comment. */
export function likeComment(
  commentId: string,
): { liked: boolean; likeCount: number } | null {
  for (const list of commentsByClip.values()) {
    const comment = list.find((c) => c.id === commentId);
    if (comment) {
      comment.isLikedByMe = !comment.isLikedByMe;
      comment.likeCount = Math.max(0, comment.likeCount + (comment.isLikedByMe ? 1 : -1));
      return { liked: comment.isLikedByMe, likeCount: comment.likeCount };
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// Phase C: Creator Gifting & Tipping Ledger (REQ-GFT-02, REQ-WAL-01, REQ-WAL-02)
// ---------------------------------------------------------------------------

function getOrCreateWallet(creatorId: string): StoredWallet {
  let wallet = creatorWallets.get(creatorId);
  if (!wallet) {
    wallet = {
      balanceZar: 1420.0,
      totalCoinsReceived: 4750,
      transactions: [],
    };
    creatorWallets.set(creatorId, wallet);
  }
  return wallet;
}

/** Records a cultural micro-gift tip sent to a creator. */
export function sendTip(
  clipId: string,
  req: TipRequest,
): {
  transaction: GiftTransactionDto;
  comment: ReelCommentDto;
  newBalanceZar: number;
} | null {
  const clip = clips.get(clipId);
  if (!clip) return null;

  const gift = CULTURAL_GIFTS[req.giftId] ?? CULTURAL_GIFTS.cowrie_shell;
  const senderUsername = req.senderUsername ?? 'ndugelo_musician';
  const wallet = getOrCreateWallet(clip.creatorId);

  // Credit creator earnings in ZAR and coin count
  wallet.balanceZar += gift.zarPrice;
  wallet.totalCoinsReceived += gift.coinPrice;

  const tx: GiftTransactionDto = {
    id: `tx_${nanoid(8)}`,
    clipId,
    senderUsername,
    recipientCreatorId: clip.creatorId,
    gift,
    message: req.message,
    timestamp: new Date().toISOString(),
  };
  wallet.transactions.unshift(tx);

  // Auto-post public cultural celebration comment into reel thread (REQ-GFT-03)
  const celebrationComment = addComment(clipId, {
    text: req.message && req.message.trim().length > 0
      ? `${req.message.trim()} (Sent ${gift.name} ${gift.emoji})`
      : `Sent ${gift.name} ${gift.emoji}! Proud of this sound.`,
    username: senderUsername,
    displayName: senderUsername,
    giftEmoji: gift.emoji,
    giftName: gift.name,
    userReelLoves: 5,
  })!;

  return {
    transaction: tx,
    comment: celebrationComment,
    newBalanceZar: wallet.balanceZar,
  };
}

/** Retrieves creator earnings, supporter leaderboard, and transaction ledger. */
export function getCreatorWallet(creatorId: string): CreatorWalletDto {
  const wallet = getOrCreateWallet(creatorId);

  // Aggregate leaderboard from transactions
  const userMap = new Map<string, { coins: number; zar: number; topEmoji: string }>();
  for (const tx of wallet.transactions) {
    const prev = userMap.get(tx.senderUsername) ?? {
      coins: 0,
      zar: 0,
      topEmoji: tx.gift.emoji,
    };
    prev.coins += tx.gift.coinPrice;
    prev.zar += tx.gift.zarPrice;
    userMap.set(tx.senderUsername, prev);
  }

  // Pre-seed some honorary supporters if new
  if (userMap.size === 0) {
    userMap.set('lerato_piano', { coins: 1800, zar: 540.0, topEmoji: '👑' });
    userMap.set('soweto_beats', { coins: 1200, zar: 360.0, topEmoji: '🎹' });
    userMap.set('makhado_groove', { coins: 750, zar: 225.0, topEmoji: '🥁' });
  }

  const leaderboard: SupporterRankDto[] = [...userMap.entries()]
    .map(([username, data]) => ({
      username,
      displayName: username.replaceAll('_', ' ').toUpperCase(),
      totalCoins: data.coins,
      totalZar: data.zar,
      topGiftEmoji: data.topEmoji,
      rank: 1,
    }))
    .sort((a, b) => b.totalCoins - a.totalCoins)
    .map((item, idx) => ({ ...item, rank: idx + 1 }));

  return {
    creatorId,
    balanceZar: wallet.balanceZar,
    totalCoinsReceived: wallet.totalCoinsReceived,
    topSupporters: leaderboard.slice(0, 10),
    recentTransactions: wallet.transactions.slice(0, 20),
  };
}

/** Requests a cashout payout from the creator's balance. */
export function requestPayout(
  creatorId: string,
  req: PayoutRequest,
): { success: boolean; payoutId: string; remainingBalanceZar: number } | null {
  const wallet = getOrCreateWallet(creatorId);
  if (req.amountZar < 50.0 || req.amountZar > wallet.balanceZar) {
    return null;
  }
  wallet.balanceZar -= req.amountZar;
  return {
    success: true,
    payoutId: `payout_${nanoid(8)}`,
    remainingBalanceZar: wallet.balanceZar,
  };
}

/**
 * Credits a producer's wallet with beat license royalty earnings (85% net split).
 */
export function creditProducerBeatRoyalty(
  creatorId: string,
  amountZar: number,
  coins: number,
  description: string,
  buyerUsername: string,
): { newBalanceZar: number } {
  const wallet = getOrCreateWallet(creatorId);
  wallet.balanceZar += amountZar;
  wallet.totalCoinsReceived += coins;
  wallet.transactions.unshift({
    id: `tx_beat_${nanoid(8)}`,
    clipId: 'beat_sale',
    senderUsername: buyerUsername,
    recipientCreatorId: creatorId,
    gift: {
      id: 'beat_license_royalty',
      name: 'Beat Royalty (85%)',
      emoji: '💰',
      coinPrice: coins,
      zarPrice: amountZar,
      culturalMeaning: description,
    },
    message: description,
    timestamp: new Date().toISOString(),
  });
  return { newBalanceZar: wallet.balanceZar };
}

/** Test/observability helper — total stored clips. */
export function countClips(): number {
  return clips.size;
}

function parseOffset(cursor?: string): number {
  if (!cursor) return 0;
  const n = Number.parseInt(cursor, 10);
  return Number.isFinite(n) && n > 0 ? n : 0;
}

function clampLimit(limit: number): number {
  if (!Number.isFinite(limit) || limit <= 0) return 20;
  return Math.min(limit, 50);
}

/**
 * Seeds a small catalogue so the feed & creator grids are never empty on a cold start.
 */
export function seedSocialClips(): void {
  if (clips.size > 0) return;

  publishClip({
    trackId: 'track_amapiano_101',
    title: 'Ndo Mufuna Matibe',
    caption:
      'New late-night piano vibe featuring indigenous live percussion! 🎹🔥',
    tags: ['Amapiano', 'Tshivenḓa', 'DeepSoul'],
    visibility: 'public',
    dna: {
      genre: 'Amapiano',
      bpm: 113,
      mood: 'Uplifting',
      paletteId: 'sunsetGold',
      typographyPreset: 'karaokeBounce',
      timestamps: [],
    },
  });
  publishClip({
    trackId: 'track_gqom_204',
    title: 'Township Log Drum Heat',
    caption: 'Durban energy, straight from the shins. #Gqom',
    tags: ['Gqom', 'Durban'],
    visibility: 'public',
    dna: {
      genre: 'Gqom',
      bpm: 127,
      mood: 'Intense',
      paletteId: 'neonNight',
      typographyPreset: 'boldPunch',
      timestamps: [],
    },
  });
  publishClip({
    trackId: 'track_afrohouse_77',
    title: 'Sunset Gold Sessions',
    caption: 'Afro House for golden hour drives 🌅',
    tags: ['AfroHouse', 'Sunset'],
    visibility: 'public',
    dna: {
      genre: 'Afro House',
      bpm: 122,
      mood: 'Dreamy',
      paletteId: 'sunsetGold',
      typographyPreset: 'softGlow',
      timestamps: [],
    },
  });

  const first = orderedClips()[0];
  if (first) {
    first.playCount = 24500;
    first.likeCount = 1840;
    first.commentCount = 96;
    first.remixCount = 12;

    // Seed realistic African community comments
    addComment(first.id, {
      text: 'This log drum hits directly in the soul! 🎹🔥',
      username: 'kgothatso_piano',
      displayName: 'Kgothatso Piano',
      userReelLoves: 8,
    });
    addComment(first.id, {
      text: 'Tshivenḓa vocal delivery is elite here. Proud of our roots 🇿🇦',
      username: 'thabo_beats',
      displayName: 'Thabo Beats',
      userReelLoves: 5,
    });
    addComment(first.id, {
      text: 'Makhado sunrise vibe! Blessed 🌅',
      username: 'lerato_piano',
      displayName: 'Lerato Piano',
      giftEmoji: '👑',
      giftName: 'Royal Venda Crown (Khare)',
      userReelLoves: 20,
    });
  }
}

seedSocialClips();

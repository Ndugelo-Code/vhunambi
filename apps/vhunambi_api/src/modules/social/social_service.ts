import { nanoid } from 'nanoid';
import { resolveMediaUrl } from '../../config/env.js';
import {
  canonicalizeCreatorId,
  vhunambiDb,
} from '../../db/vhunambi_db.js';
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
function orderedClips(viewerCreatorId = 'creator_cern'): PublishedClipDto[] {
  seedSocialClips();
  const likedTargets = vhunambiDb.listSocialInteractionTargets(
    'clip_like',
    canonicalizeCreatorId(viewerCreatorId),
  );
  return vhunambiDb.listPublishedClipRows().map((raw) => {
    const clip = raw as PublishedClipDto;
    return {
      ...clip,
      audioUrl: resolveMediaUrl(clip.audioUrl),
      coverUrl: resolveMediaUrl(clip.coverUrl),
      isLikedByMe: likedTargets.has(clip.id),
    };
  });
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
  const creatorId = canonicalizeCreatorId(req.creatorId ?? DEFAULT_CREATOR.creatorId);
  const creator = {
    creatorId,
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
    audioUrl: resolveMediaUrl(req.audioUrl ?? `${base}/${req.trackId}.mp3`),
    coverUrl: resolveMediaUrl(req.coverUrl ?? `${base}/${req.trackId}.jpg`),
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
  seedSocialClips();
  const clipId = `clip_pub_${nanoid(8)}`;
  const clip = makeClip(req, clipId);

  vhunambiDb.upsertPublishedClip(clip);
  if (req.remixedFromClipId) {
    const parent = vhunambiDb.getPublishedClipRow(req.remixedFromClipId);
    if (parent) {
      parent.remixCount = Number(parent.remixCount ?? 0) + 1;
      vhunambiDb.upsertPublishedClip(parent);
    }
  }

  return {
    clipId,
    shareUrl: `https://vhunambi.com/@${clip.creatorUsername}/reels/${clipId}`,
    publishedAt: clip.publishedAt,
  };
}

/** Cursor-paginated newest-first feed (design.md §5.2). */
export function getFeed(
  cursor?: string,
  limit = 20,
  viewerCreatorId = 'creator_cern',
): ClipFeedPage {
  const all = orderedClips(viewerCreatorId);
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
export function getClipsByCreator(
  creatorId: string,
  viewerCreatorId = 'creator_cern',
): PublishedClipDto[] {
  const canonical = canonicalizeCreatorId(creatorId);
  return orderedClips(viewerCreatorId).filter(
    (clip) => canonicalizeCreatorId(clip.creatorId) === canonical,
  );
}

/** Toggles a creator's like on a clip; returns null when not found. */
export function likeClip(
  clipId: string,
  actorCreatorId = 'creator_cern',
): { liked: boolean; likeCount: number } | null {
  seedSocialClips();
  const actor = canonicalizeCreatorId(actorCreatorId);
  const clip = vhunambiDb.getPublishedClipRow(clipId);
  if (!clip) return null;
  const liked = vhunambiDb.toggleSocialInteraction('clip_like', clipId, actor);
  const likeCount = Math.max(0, Number(clip.likeCount ?? 0) + (liked ? 1 : -1));
  vhunambiDb.upsertPublishedClip({ ...clip, likeCount });
  return { liked, likeCount };
}

/** Toggles a creator's follow on another creator; returns state + count. */
export function followCreator(
  creatorId: string,
  actorCreatorId = 'creator_cern',
): {
  following: boolean;
  followerCount: number;
} {
  const canonicalTarget = canonicalizeCreatorId(creatorId);
  const actor = canonicalizeCreatorId(actorCreatorId);
  const nowFollowing = vhunambiDb.toggleSocialInteraction(
    'creator_follow',
    canonicalTarget,
    actor,
  );
  const followerCount = vhunambiDb.countSocialInteractionActors(
    'creator_follow',
    canonicalTarget,
  );
  return { following: nowFollowing, followerCount };
}

// ---------------------------------------------------------------------------
// Phase C: Community Comments Engine (REQ-COM-01, REQ-COM-02)
// ---------------------------------------------------------------------------

/** Retrieves comments for a specific clip ID, newest first. */
export function getComments(
  clipId: string,
  viewerCreatorId = 'creator_cern',
): ReelCommentDto[] {
  seedSocialClips();
  const likedComments = vhunambiDb.listSocialInteractionTargets(
    'comment_like',
    canonicalizeCreatorId(viewerCreatorId),
  );
  return vhunambiDb.listReelCommentsByClip(clipId).map((raw) => {
    const comment = raw as ReelCommentDto;
    return {
      ...comment,
      isLikedByMe: likedComments.has(comment.id),
    };
  });
}

/** Appends a new comment to a reel thread and increments the clip's commentCount. */
export function addComment(
  clipId: string,
  req: CreateCommentRequest,
): ReelCommentDto | null {
  seedSocialClips();
  const clip = vhunambiDb.getPublishedClipRow(clipId);
  if (!clip) return null;

  const commentId = `c_${nanoid(8)}`;
  const comment: ReelCommentDto = {
    id: commentId,
    clipId,
    userId: req.userId ?? 'user_listener',
    username: req.username ?? 'ndugelo_musician',
    displayName: req.displayName ?? 'Ndugelo Musician',
    avatarUrl: req.avatarUrl,
    isCreator:
      req.userId === clip.creatorId || req.username === clip.creatorUsername,
    text: req.text.trim(),
    likeCount: 0,
    isLikedByMe: false,
    userReelLoves: req.userReelLoves ?? 0,
    giftEmoji: req.giftEmoji,
    giftName: req.giftName,
    createdAt: new Date().toISOString(),
  };

  vhunambiDb.insertReelComment(comment);
  vhunambiDb.upsertPublishedClip({
    ...clip,
    commentCount: Number(clip.commentCount ?? 0) + 1,
  });
  return comment;
}

/** Toggles like state on a comment. */
export function likeComment(
  commentId: string,
  actorCreatorId = 'creator_cern',
): { liked: boolean; likeCount: number } | null {
  seedSocialClips();
  const actor = canonicalizeCreatorId(actorCreatorId);
  const comment = vhunambiDb.getReelCommentById(commentId);
  if (!comment) return null;
  const liked = vhunambiDb.toggleSocialInteraction('comment_like', commentId, actor);
  const likeCount = Math.max(0, Number(comment.likeCount ?? 0) + (liked ? 1 : -1));
  vhunambiDb.insertReelComment({
    ...comment,
    likeCount,
    isLikedByMe: liked,
  });
  return { liked, likeCount };
}

// ---------------------------------------------------------------------------
// Phase C + 62: Atomic Creator Gifting & Unified Wallet Ledger
// ---------------------------------------------------------------------------

export type SendCulturalTipResult =
  | {
    ok: true;
    transaction: GiftTransactionDto;
    comment: ReelCommentDto;
    newBalanceZar: number;
    senderRemainingCoins: number;
    primaryCoins: number;
    ancestorCoins: number;
  }
  | {
    ok: false;
    errorCode: 'CLIP_NOT_FOUND' | 'INSUFFICIENT_WALLET_BALANCE' | 'SELF_TIP_FORBIDDEN';
    message: string;
  };

/**
 * Atomic cultural tip transfer backed by `vhunambiDb.sendCulturalTipAtomic`.
 * Enforces sender wallet balance (`402`), blocks self-tipping (`422`), and
 * splits 70/30 royalties to parent creators on remixed clips.
 */
export function sendCulturalTip(
  clipId: string,
  senderId: string,
  amountCoins?: number,
  giftId?: string,
  message?: string,
  senderUsername?: string,
): SendCulturalTipResult {
  seedSocialClips();
  const clip = vhunambiDb.getPublishedClipRow(clipId);

  if (!clip) {
    return {
      ok: false,
      errorCode: 'CLIP_NOT_FOUND',
      message: `Clip ${clipId} not found`,
    };
  }

  const resolvedGift =
    (giftId && CULTURAL_GIFTS[giftId]) || CULTURAL_GIFTS.cowrie_shell;
  const effectiveCoins =
    typeof amountCoins === 'number' && Number.isFinite(amountCoins) && amountCoins > 0
      ? Math.round(amountCoins)
      : resolvedGift.coinPrice;
  const effectiveZar =
    giftId && CULTURAL_GIFTS[giftId] && (!amountCoins || amountCoins === resolvedGift.coinPrice)
      ? resolvedGift.zarPrice
      : Number((effectiveCoins * 0.3).toFixed(2));

  const effectiveGift: CulturalGiftDto =
    effectiveCoins === resolvedGift.coinPrice && effectiveZar === resolvedGift.zarPrice
      ? resolvedGift
      : {
        ...resolvedGift,
        coinPrice: effectiveCoins,
        zarPrice: effectiveZar,
      };

  const canonicalSender = canonicalizeCreatorId(senderId || 'creator_cern');
  const resolvedUsername =
    senderUsername?.trim() || canonicalSender.replace(/^creator_/, '');
  const tipId = nanoid(10);

  const parentClip = clip.remixedFromClipId
    ? vhunambiDb.getPublishedClipRow(String(clip.remixedFromClipId))
    : null;

  const transfer = vhunambiDb.sendCulturalTipAtomic({
    tipId,
    clipId,
    senderId: canonicalSender,
    recipientId: String(clip.creatorId),
    ancestorId: parentClip ? String(parentClip.creatorId) : undefined,
    amountCoins: effectiveCoins,
    amountZar: effectiveZar,
    giftName: effectiveGift.name,
    giftEmoji: effectiveGift.emoji,
    giftId: effectiveGift.id,
    senderUsername: resolvedUsername,
    message,
  });

  if (transfer.outcome === 'self_tip_forbidden') {
    return {
      ok: false,
      errorCode: 'SELF_TIP_FORBIDDEN',
      message: 'Cannot send a cultural tip to your own clip.',
    };
  }
  if (transfer.outcome === 'insufficient_funds') {
    return {
      ok: false,
      errorCode: 'INSUFFICIENT_WALLET_BALANCE',
      message: `Insufficient wallet coins: available ${transfer.senderRemainingCoins}, requested ${effectiveCoins}.`,
    };
  }

  const senderRemainingCoins = transfer.senderRemainingCoins;
  const primaryCoins = transfer.primaryCoins;
  const ancestorCoins = transfer.ancestorCoins;
  const newBalanceZar = vhunambiDb.getWalletSnapshot(String(clip.creatorId)).balanceZar;

  const tx: GiftTransactionDto = {
    id: `tx_${tipId}`,
    clipId,
    senderId: canonicalSender,
    senderUsername: resolvedUsername,
    recipientId: String(clip.creatorId),
    recipientCreatorId: String(clip.creatorId),
    amountCoins: effectiveCoins,
    amountZar: effectiveZar,
    splitPercentage: parentClip ? 70 : 100,
    type: 'direct_tip',
    gift: effectiveGift,
    message,
    timestamp: new Date().toISOString(),
  };

  const celebrationComment = addComment(clipId, {
    text:
      message && message.trim().length > 0
        ? `${message.trim()} (Sent ${effectiveGift.name} ${effectiveGift.emoji})`
        : `Sent ${effectiveGift.name} ${effectiveGift.emoji}! Proud of this sound.`,
    userId: canonicalSender,
    username: resolvedUsername,
    displayName: resolvedUsername,
    giftEmoji: effectiveGift.emoji,
    giftName: effectiveGift.name,
    userReelLoves: 5,
  })!;

  return {
    ok: true,
    transaction: tx,
    comment: celebrationComment,
    newBalanceZar,
    senderRemainingCoins,
    primaryCoins,
    ancestorCoins,
  };
}

/** Legacy convenience wrapper for cultural micro-gift tipping. */
export function sendTip(
  clipId: string,
  req: TipRequest,
  senderId = 'creator_cern',
): {
  transaction: GiftTransactionDto;
  comment: ReelCommentDto;
  newBalanceZar: number;
} | null {
  const res = sendCulturalTip(
    clipId,
    req.senderId || senderId,
    req.amountCoins ?? req.coins,
    req.giftId,
    req.message,
    req.senderUsername,
  );
  if (!res.ok) return null;
  return {
    transaction: res.transaction,
    comment: res.comment,
    newBalanceZar: res.newBalanceZar,
  };
}

/**
 * Unified Creator Wallet backed directly by `vhunambiDb.getWalletSnapshot(creatorId)`
 * (the exact same SQLite `wallet_ledger` as `GET /api/wallet/:creatorId`).
 */
export function getCreatorWallet(creatorId: string): CreatorWalletDto {
  const canonicalId = canonicalizeCreatorId(creatorId);

  const snapshot = vhunambiDb.getWalletSnapshot(canonicalId);
  const unifiedTxs: GiftTransactionDto[] = snapshot.transactions.map((tx) => {
    const meta = (tx.metadata ?? {}) as Record<string, unknown>;
    const absCoins = Math.abs(Number(tx.amountCoins ?? 0));
    const absZar = Math.abs(Number(tx.amountZar ?? 0));
    const txType: GiftTransactionDto['type'] =
      tx.type === 'remix_royalty'
        ? 'remix_royalty'
        : tx.type === 'license_sale'
          ? 'beat_royalty'
          : tx.type === 'payout' || tx.type === 'payout_withdrawal'
            ? 'payout'
            : tx.type === 'topup'
              ? 'topup'
              : 'direct_tip';

    const giftId = String(
      meta.giftId ??
      (tx.type === 'license_sale'
        ? 'beat_license_royalty'
        : tx.type === 'topup'
          ? 'sovereign_topup'
          : 'cowrie_shell'),
    );
    const giftName = String(
      meta.giftName ??
      (tx.type === 'license_sale'
        ? 'Beat Royalty (85%)'
        : tx.type === 'topup'
          ? 'Sovereign Top-Up'
          : 'Cultural Gift'),
    );
    const giftEmoji = String(
      meta.giftEmoji ?? (tx.type === 'license_sale' ? '💰' : '🎵'),
    );
    const msg = String(
      meta.message ??
      meta.note ??
      (tx.reference ? `${tx.type} (${tx.reference})` : tx.type),
    );
    const senderUsername = String(
      meta.senderUsername ??
      meta.buyerHandle ??
      meta.senderId ??
      'system',
    );

    return {
      id: String(tx.id),
      clipId: String(
        meta.clipId ?? (tx.type === 'license_sale' ? 'beat_sale' : tx.reference ?? ''),
      ),
      senderId: String(meta.senderId ?? meta.buyerId ?? 'system'),
      senderUsername,
      recipientId: canonicalId,
      recipientCreatorId: canonicalId,
      amountCoins: absCoins,
      amountZar: absZar,
      splitPercentage: Number(
        meta.splitPct ?? (tx.type === 'license_sale' ? 85 : 100),
      ),
      type: txType,
      gift: {
        id: giftId,
        name: giftName,
        emoji: giftEmoji,
        coinPrice: absCoins,
        zarPrice: absZar,
        culturalMeaning: msg,
      },
      message: msg,
      timestamp: String(tx.createdAt),
    };
  });

  // Aggregate supporter leaderboard from incoming tips/royalties
  const userMap = new Map<
    string,
    { coins: number; zar: number; topEmoji: string }
  >();
  for (const tx of snapshot.transactions) {
    if (
      tx.type !== 'tip_received' &&
      tx.type !== 'tip' &&
      tx.type !== 'remix_royalty'
    ) {
      continue;
    }
    const meta = (tx.metadata ?? {}) as Record<string, unknown>;
    const username = String(
      meta.senderUsername ?? meta.senderId ?? '',
    ).trim();
    if (!username || username === 'system') continue;
    const prev = userMap.get(username) ?? {
      coins: 0,
      zar: 0,
      topEmoji: String(meta.giftEmoji ?? '🎵'),
    };
    prev.coins += Math.max(0, Number(tx.amountCoins ?? 0));
    prev.zar += Math.max(0, Number(tx.amountZar ?? 0));
    userMap.set(username, prev);
  }

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
      totalZar: Number(data.zar.toFixed(2)),
      topGiftEmoji: data.topEmoji,
      rank: 1,
    }))
    .sort((a, b) => b.totalCoins - a.totalCoins)
    .map((item, idx) => ({ ...item, rank: idx + 1 }));

  const pendingRoyaltiesZar = snapshot.transactions
    .filter((tx) => tx.type === 'license_sale' || tx.type === 'remix_royalty')
    .reduce((sum, tx) => sum + Math.max(0, Number(tx.amountZar ?? 0)), 0);

  const positiveCoinsTotal = snapshot.transactions.reduce(
    (sum, tx) =>
      sum + (Number(tx.amountCoins ?? 0) > 0 ? Number(tx.amountCoins) : 0),
    0,
  );

  return {
    creatorId: canonicalId,
    balanceZar: snapshot.balanceZar,
    balanceCoins: snapshot.balanceCoins,
    pendingRoyaltiesZar: Number(pendingRoyaltiesZar.toFixed(2)),
    totalCoinsReceived: Math.max(snapshot.balanceCoins, positiveCoinsTotal),
    topSupporters: leaderboard.slice(0, 10),
    recentTransactions: unifiedTxs.slice(0, 20),
    transactions: unifiedTxs,
  };
}

/** Requests a cashout payout from the creator's persistent SQLite wallet ledger. */
export function requestPayout(
  creatorId: string,
  req: PayoutRequest,
): { success: boolean; payoutId: string; remainingBalanceZar: number } | null {
  const canonicalId = canonicalizeCreatorId(creatorId);
  if (!Number.isFinite(req.amountZar) || req.amountZar < 50.0) {
    return null;
  }
  const receipt = vhunambiDb.requestPayout({
    creatorId: canonicalId,
    amountZar: req.amountZar,
    bankName: 'Standard Bank',
    accountNumber: '1234567890',
    paymentRail: req.payoutMethod || 'eft',
  });
  if (!receipt.success || !receipt.payoutId) {
    return null;
  }
  return {
    success: true,
    payoutId: receipt.payoutId,
    remainingBalanceZar: receipt.remainingBalanceZar ?? 0,
  };
}

/** Test/observability helper — total stored clips. */
export function countClips(): number {
  seedSocialClips();
  return vhunambiDb.countPublishedClips();
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

let _seedingSocialClips = false;

/**
 * Seeds a small catalogue so the feed & creator grids are never empty on a cold start.
 * Invoked lazily by service entrypoints (not at module scope, for Cloudflare Workers compatibility).
 */
export function seedSocialClips(): void {
  if (_seedingSocialClips) return;
  if (vhunambiDb.countPublishedClips() > 0) return;

  _seedingSocialClips = true;
  try {
    const firstPublished = publishClip({
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

    const first = vhunambiDb.getPublishedClipRow(firstPublished.clipId);
    if (first) {
      vhunambiDb.upsertPublishedClip({
        ...first,
        playCount: 24500,
        likeCount: 1840,
        commentCount: 93,
        remixCount: 12,
      });

      addComment(firstPublished.clipId, {
        text: 'This log drum hits directly in the soul! 🎹🔥',
        username: 'kgothatso_piano',
        displayName: 'Kgothatso Piano',
        userReelLoves: 8,
      });
      addComment(firstPublished.clipId, {
        text: 'Tshivenḓa vocal delivery is elite here. Proud of our roots 🇿🇦',
        username: 'thabo_beats',
        displayName: 'Thabo Beats',
        userReelLoves: 5,
      });
      addComment(firstPublished.clipId, {
        text: 'Makhado sunrise vibe! Blessed 🌅',
        username: 'lerato_piano',
        displayName: 'Lerato Piano',
        giftEmoji: '👑',
        giftName: 'Royal Venda Crown (Khare)',
        userReelLoves: 20,
      });
    }
  } finally {
    _seedingSocialClips = false;
  }
}

/** Returns all remix descendant clips for a parent clip (Phase 37 REQ-RMX-TREE-01). */
export function getClipRemixes(clipId: string): PublishedClipDto[] {
  seedSocialClips();
  return vhunambiDb.listRemixClipRows(clipId).map((raw) => {
    const clip = raw as PublishedClipDto;
    return {
      ...clip,
      audioUrl: resolveMediaUrl(clip.audioUrl),
      coverUrl: resolveMediaUrl(clip.coverUrl),
    };
  });
}

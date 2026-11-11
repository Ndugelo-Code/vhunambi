/**
 * Phase 18 / Phase C · Social Creator Network — domain types.
 *
 * These DTOs mirror the Dart `PublishedClip`, `ReelComment`, `CulturalGift`,
 * and `GiftTransaction` entities in `apps/vhunambi_client/lib/features/social/`
 * so the client's `.fromJson` constructors map 1:1 onto these payloads.
 */

/** Clip visibility selector (REQ-SOC-02). */
export type ClipVisibility = 'public' | 'followers';

/** Request body for `POST /api/social/publish` (design.md §5.1). */
export interface PublishClipRequest {
  trackId: string;
  title: string;
  caption: string;
  tags: string[];
  visibility: ClipVisibility;
  /** Immutable SongMetadataDNA powering zero-video vector canvas playback. */
  dna: Record<string, unknown>;
  /** Optional publisher identity — defaults to the demo owner when omitted. */
  creatorId?: string;
  creatorUsername?: string;
  creatorDisplayName?: string;
  creatorAvatarUrl?: string;
  isCreatorVerified?: boolean;
  /** Optional media references — synthesized placeholders when omitted. */
  audioUrl?: string;
  coverUrl?: string;
  /** Optional lineage for viral sound remixes (Phase D). */
  remixedFromClipId?: string;
  remixAttribution?: string;
}

/** Wire DTO for a published clip (design.md §1.1 PublishedClip). */
export interface PublishedClipDto {
  id: string;
  trackId: string;
  creatorId: string;
  creatorUsername: string;
  creatorDisplayName: string;
  creatorAvatarUrl: string | null;
  isCreatorVerified: boolean;
  title: string;
  caption: string;
  tags: string[];
  genre: string;
  audioUrl: string;
  coverUrl: string;
  dna: Record<string, unknown>;
  playCount: number;
  likeCount: number;
  commentCount: number;
  remixCount: number;
  isLikedByMe: boolean;
  isSavedByMe: boolean;
  remixedFromClipId?: string;
  remixAttribution?: string;
  publishedAt: string;
}

/** Cursor-paginated feed response (design.md §5.2). */
export interface ClipFeedPage {
  clips: PublishedClipDto[];
  nextCursor: string | null;
}

/** Reel comment DTO (Phase C, mirrors `ReelComment.dart`). */
export interface ReelCommentDto {
  id: string;
  clipId: string;
  userId: string;
  username: string;
  displayName: string;
  avatarUrl?: string;
  isCreator: boolean;
  text: string;
  likeCount: number;
  isLikedByMe: boolean;
  userReelLoves: number;
  giftEmoji?: string;
  giftName?: string;
  createdAt: string;
}

/** Request body for creating a comment (`POST /api/social/clips/:id/comments`). */
export interface CreateCommentRequest {
  text: string;
  userReelLoves?: number;
  userId?: string;
  username?: string;
  displayName?: string;
  avatarUrl?: string;
  giftEmoji?: string;
  giftName?: string;
}

/** Cultural Gift payload. */
export interface CulturalGiftDto {
  id: string;
  name: string;
  emoji: string;
  coinPrice: number;
  zarPrice: number;
  culturalMeaning: string;
}

/** Micro-tipping transaction DTO (mirrors `GiftTransaction.dart` + Phase 62 wallet ledger). */
export interface GiftTransactionDto {
  id: string;
  clipId: string;
  senderId?: string;
  senderUsername: string;
  recipientId?: string;
  recipientCreatorId: string;
  amountCoins?: number;
  amountZar?: number;
  splitPercentage?: number;
  type?: 'direct_tip' | 'remix_royalty' | 'beat_royalty' | 'payout' | 'topup';
  gift: CulturalGiftDto;
  message?: string;
  timestamp: string;
}

/** Request body for sending a cultural gift (`POST /api/social/clips/:id/tip`). */
export interface TipRequest {
  giftId?: string;
  senderId?: string;
  amountCoins?: number;
  coins?: number;
  senderUsername?: string;
  message?: string;
}

/** Top patron rank on creator leaderboard (mirrors `SupporterRank.dart`). */
export interface SupporterRankDto {
  username: string;
  displayName: string;
  totalCoins: number;
  totalZar: number;
  topGiftEmoji: string;
  rank: number;
}

/** Creator earnings ledger & wallet status (`GET /api/creators/:id/wallet`). */
export interface CreatorWalletDto {
  creatorId: string;
  balanceZar: number;
  balanceCoins?: number;
  pendingRoyaltiesZar?: number;
  totalCoinsReceived: number;
  topSupporters: SupporterRankDto[];
  recentTransactions: GiftTransactionDto[];
  transactions?: GiftTransactionDto[];
}

/** Request body for creator payout (`POST /api/creators/:id/wallet/payout`). */
export interface PayoutRequest {
  amountZar: number;
  payoutMethod?: string;
}

import 'package:vhunambi_client/features/social/domain/models/creator_wallet.dart';
import 'package:vhunambi_client/features/social/domain/models/kinetic_reaction.dart';
import 'package:vhunambi_client/features/social/domain/models/published_clip.dart';
import 'package:vhunambi_client/features/social/domain/models/reel_comment.dart';

/// GIF catalog search/trending entry returned by `/api/social/gifs/*`.
class GifSearchItem {
  final String id;
  final String title;
  final String previewUrl;
  final String gifUrl;
  final int width;
  final int height;

  const GifSearchItem({
    required this.id,
    required this.title,
    required this.previewUrl,
    required this.gifUrl,
    this.width = 480,
    this.height = 360,
  });

  double get aspectRatio =>
      height > 0 ? (width / height).clamp(0.5, 2.2) : 1.33;

  factory GifSearchItem.fromJson(Map<String, dynamic> json) {
    final gif = (json['gifUrl'] ?? json['gif_url'] ?? '').toString();
    final preview =
        (json['previewUrl'] ?? json['preview_url'] ?? gif).toString();
    return GifSearchItem(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Studio GIF').toString(),
      previewUrl: preview,
      gifUrl: gif,
      width: (json['width'] as num?)?.toInt() ?? 480,
      height: (json['height'] as num?)?.toInt() ?? 360,
    );
  }
}

/// Abstract contract for the Vhunambi Social Creator Network repository (REQ-SOC-01..26).
///
/// Implemented by [HttpSocialRepository] for production REST communication with
/// `apps/vhunambi_api` with seamless offline cache / in-memory fallback.
abstract class ISocialRepository {
  /// Fetches a cursor-paginated page of published kinetic reels for discovery feed.
  Future<List<PublishedClip>> getFeed({String? cursor, int limit = 20});

  /// Toggles the user's like state on a reel clip.
  Future<({bool liked, int likeCount})> toggleLikeClip(String clipId);

  /// Toggles follow status on a creator.
  Future<({bool following, int followerCount})> toggleFollowCreator(
    String creatorId,
  );

  /// Retrieves clips published by a specific creator.
  Future<List<PublishedClip>> getCreatorClips(String creatorId);

  /// Fetches live remix descendant clips via `GET /api/social/clips/:id/remixes`.
  Future<List<PublishedClip>> getClipRemixes(String clipId);

  /// Retrieves the community comment thread for a specific clip.
  Future<List<ReelComment>> getComments(String clipId);

  /// Posts a new comment or nested reply to a clip thread.
  Future<ReelComment> addComment({
    required String clipId,
    required String text,
    String? username,
    String? displayName,
    int? userReelLoves,
    String? giftEmoji,
    String? giftName,
    String? parentCommentId,
    String? replyToHandle,
    String? gifUrl,
    String? stickerId,
    double? mediaAspectRatio,
  });

  /// Toggles like state on an individual comment.
  Future<({bool liked, int likeCount})> toggleLikeComment(String commentId);

  /// Applies, switches, or clears a multi-reaction on an individual comment.
  Future<
    ({
      int likeCount,
      bool isLikedByMe,
      Map<KineticReactionType, int> reactionCounts,
      KineticReactionType? myReaction,
    })
  >
  reactToComment(String commentId, KineticReactionType? reaction);

  /// Searches curated / Tenor / Giphy studio GIFs via the backend proxy.
  Future<List<GifSearchItem>> searchGifs(String query, {int limit = 16});

  /// Fetches trending studio GIFs via the backend proxy.
  Future<List<GifSearchItem>> getTrendingGifs({int limit = 16});

  /// Sends a cultural micro-gift tip to the creator of a clip.
  Future<
    ({GiftTransaction transaction, ReelComment comment, double newBalanceZar})
  >
  sendTip({
    required String clipId,
    required String giftId,
    String? senderUsername,
    String? message,
  });

  /// Retrieves the creator's wallet balance, supporter leaderboard, and transaction ledger.
  Future<CreatorWallet> getCreatorWallet(String creatorId);

  /// Retrieves supported South African clearing banks and instant payout rails.
  Future<List<SaBankOption>> fetchSupportedBanks();

  /// Requests a payout / cashout from the creator wallet.
  Future<PayoutReceipt> requestPayout({
    required String creatorId,
    required double amountZar,
    String payoutMethod = 'eft',
    required String accountDetails,
    String? bankName,
    String? accountHolder,
    String? accountNumber,
    String? branchCode,
    PayoutGatewayRail? paymentRail,
  });

  /// 1-tap in-house publishing of a song clip to the social creator network.
  Future<({String clipId, String shareUrl, DateTime publishedAt})> publishClip(
    Map<String, dynamic> payload,
  );

  /// Retrieves canonical PayFast ZAR coin top-up SKUs (`Phase 63`).
  Future<List<PayFastCoinPack>> fetchPayFastCoinPacks();

  /// Initiates a PayFast ZAR checkout session (`POST /api/payments/payfast/checkout`).
  Future<PayFastCheckoutSession> initiatePayFastCheckout({
    required String creatorId,
    required String packId,
    double? amountZar,
    int? coinsGranted,
  });

  /// Polls PayFast checkout settlement status (`GET /api/payments/payfast/status/:checkoutId`).
  Future<PayFastStatusSnapshot> getPayFastCheckoutStatus(String checkoutId);

  /// Executes deterministic sandbox ITN settlement (`POST /api/payments/payfast/sandbox-settle/:checkoutId`).
  Future<PayFastStatusSnapshot> sandboxSettlePayFastCheckout(String checkoutId);
}

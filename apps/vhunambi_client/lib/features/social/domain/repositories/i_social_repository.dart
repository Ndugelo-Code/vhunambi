import '../models/creator_wallet.dart';
import '../models/published_clip.dart';
import '../models/reel_comment.dart';

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

  /// Retrieves the community comment thread for a specific clip.
  Future<List<ReelComment>> getComments(String clipId);

  /// Posts a new comment to a clip thread.
  Future<ReelComment> addComment({
    required String clipId,
    required String text,
    String? username,
    String? displayName,
    int? userReelLoves,
    String? giftEmoji,
    String? giftName,
  });

  /// Toggles like state on an individual comment.
  Future<({bool liked, int likeCount})> toggleLikeComment(String commentId);

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

  /// Requests a payout / cashout from the creator wallet.
  Future<PayoutReceipt> requestPayout({
    required String creatorId,
    required double amountZar,
    String payoutMethod = 'eft',
    required String accountDetails,
  });

  /// 1-tap in-house publishing of a song clip to the social creator network.
  Future<({String clipId, String shareUrl, DateTime publishedAt})> publishClip(
    Map<String, dynamic> payload,
  );
}

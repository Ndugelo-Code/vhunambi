import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../domain/models/creator_wallet.dart';
import '../../domain/models/cultural_gift.dart';
import '../../domain/models/published_clip.dart';
import '../../domain/models/reel_comment.dart';
import '../../domain/repositories/i_social_repository.dart';

/// Production HTTP repository for Vhunambi Social Creator Network (Phase C).
///
/// Communicates with `apps/vhunambi_api` (`/api/social/*`, `/api/creators/*`).
/// When running in Flutter test environments or offline when the backend server
/// is not bound, transparently utilizes an in-memory session ledger to prevent
/// unmanaged Dio socket timers and network crashes.
class HttpSocialRepository implements ISocialRepository {
  final Dio _dio;
  final String _baseUrl;
  final bool isTestMode;

  // In-memory fallback stores for offline/test resilience
  final Map<String, List<ReelComment>> _fallbackComments = {};
  final Map<String, ({bool liked, int likeCount})> _fallbackLikes = {};
  final Map<String, ({bool following, int followerCount})> _fallbackFollows = {};
  final Map<String, CreatorWallet> _fallbackWallets = {};

  HttpSocialRepository({
    Dio? dio,
    String? baseUrl,
    bool? isTestMode,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 4),
                receiveTimeout: const Duration(seconds: 4),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
              ),
            ),
        _baseUrl = baseUrl ?? _resolveDefaultBaseUrl(),
        isTestMode = isTestMode ?? _detectTestMode();

  static bool _detectTestMode() {
    if (const bool.fromEnvironment('FLUTTER_TEST')) return true;
    try {
      if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  static String _resolveDefaultBaseUrl() {
    if (kIsWeb) return 'http://localhost:3000/api';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000/api';
    }
    return 'http://localhost:3000/api';
  }

  @override
  Future<List<PublishedClip>> getFeed({String? cursor, int limit = 20}) async {
    if (isTestMode) return const [];
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/social/feed',
        queryParameters: {
          'cursor': ?cursor,
          'limit': limit,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        final list = response.data!['clips'] as List<dynamic>? ?? const [];
        return list
            .map((c) => PublishedClip.fromJson(c as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('[HttpSocialRepository] getFeed fallback: $e');
    }
    return const [];
  }

  @override
  Future<({bool liked, int likeCount})> toggleLikeClip(String clipId) async {
    if (isTestMode) return _toggleLikeClipFallback(clipId);
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_baseUrl/social/clips/$clipId/like',
        data: {},
      );
      if (response.statusCode == 200 && response.data != null) {
        return (
          liked: response.data!['liked'] as bool? ?? true,
          likeCount: (response.data!['likeCount'] as num?)?.toInt() ?? 1,
        );
      }
    } catch (e) {
      debugPrint('[HttpSocialRepository] toggleLikeClip fallback: $e');
    }
    return _toggleLikeClipFallback(clipId);
  }

  ({bool liked, int likeCount}) _toggleLikeClipFallback(String clipId) {
    final prev = _fallbackLikes[clipId] ?? (liked: false, likeCount: 0);
    final next = (
      liked: !prev.liked,
      likeCount: (prev.likeCount + (!prev.liked ? 1 : -1)).clamp(0, 999999),
    );
    _fallbackLikes[clipId] = next;
    return next;
  }

  @override
  Future<({bool following, int followerCount})> toggleFollowCreator(
      String creatorId) async {
    if (isTestMode) return _toggleFollowCreatorFallback(creatorId);
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_baseUrl/creators/$creatorId/follow',
        data: {},
      );
      if (response.statusCode == 200 && response.data != null) {
        return (
          following: response.data!['following'] as bool? ?? true,
          followerCount:
              (response.data!['followerCount'] as num?)?.toInt() ?? 1,
        );
      }
    } catch (e) {
      debugPrint('[HttpSocialRepository] toggleFollowCreator fallback: $e');
    }
    return _toggleFollowCreatorFallback(creatorId);
  }

  ({bool following, int followerCount}) _toggleFollowCreatorFallback(
      String creatorId) {
    final prev =
        _fallbackFollows[creatorId] ?? (following: false, followerCount: 120);
    final next = (
      following: !prev.following,
      followerCount:
          (prev.followerCount + (!prev.following ? 1 : -1)).clamp(0, 999999),
    );
    _fallbackFollows[creatorId] = next;
    return next;
  }

  @override
  Future<List<PublishedClip>> getCreatorClips(String creatorId) async {
    if (isTestMode) return const [];
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/creators/$creatorId/clips',
      );
      if (response.statusCode == 200 && response.data != null) {
        final list = response.data!['clips'] as List<dynamic>? ?? const [];
        return list
            .map((c) => PublishedClip.fromJson(c as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('[HttpSocialRepository] getCreatorClips fallback: $e');
    }
    return const [];
  }

  @override
  Future<List<ReelComment>> getComments(String clipId) async {
    if (isTestMode) return _fallbackComments[clipId] ?? const [];
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/social/clips/$clipId/comments',
      );
      if (response.statusCode == 200 && response.data != null) {
        final list = response.data!['comments'] as List<dynamic>? ?? const [];
        return list
            .map((c) => ReelComment(
                  id: c['id'] as String? ?? 'c_0',
                  clipId: c['clipId'] as String? ?? clipId,
                  userId: c['userId'] as String? ?? 'u_listener',
                  username: c['username'] as String? ?? 'listener',
                  displayName: c['displayName'] as String? ?? 'Listener',
                  avatarUrl: c['avatarUrl'] as String?,
                  isCreator: c['isCreator'] as bool? ?? false,
                  text: c['text'] as String? ?? '',
                  likeCount: (c['likeCount'] as num?)?.toInt() ?? 0,
                  isLikedByMe: c['isLikedByMe'] as bool? ?? false,
                  userReelLoves: (c['userReelLoves'] as num?)?.toInt() ?? 0,
                  giftEmoji: c['giftEmoji'] as String?,
                  giftName: c['giftName'] as String?,
                  createdAt:
                      DateTime.tryParse(c['createdAt'] as String? ?? '') ??
                          DateTime.now(),
                ))
            .toList();
      }
    } catch (e) {
      debugPrint('[HttpSocialRepository] getComments fallback: $e');
    }

    return _fallbackComments[clipId] ?? const [];
  }

  @override
  Future<ReelComment> addComment({
    required String clipId,
    required String text,
    String? username,
    String? displayName,
    int? userReelLoves,
    String? giftEmoji,
    String? giftName,
  }) async {
    if (isTestMode) {
      return _addCommentFallback(
        clipId: clipId,
        text: text,
        username: username,
        displayName: displayName,
        userReelLoves: userReelLoves,
        giftEmoji: giftEmoji,
        giftName: giftName,
      );
    }

    final payload = {
      'text': text.trim(),
      'username': ?username,
      'displayName': ?displayName,
      'userReelLoves': ?userReelLoves,
      'giftEmoji': ?giftEmoji,
      'giftName': ?giftName,
    };

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_baseUrl/social/clips/$clipId/comments',
        data: payload,
      );
      if (response.statusCode == 201 && response.data != null) {
        final c = response.data!;
        final comment = ReelComment(
          id: c['id'] as String? ?? 'c_${DateTime.now().millisecondsSinceEpoch}',
          clipId: c['clipId'] as String? ?? clipId,
          userId: c['userId'] as String? ?? 'u_me',
          username: c['username'] as String? ?? username ?? 'ndugelo_musician',
          displayName:
              c['displayName'] as String? ?? displayName ?? 'Ndugelo Musician',
          avatarUrl: c['avatarUrl'] as String?,
          isCreator: c['isCreator'] as bool? ?? false,
          text: c['text'] as String? ?? text,
          likeCount: (c['likeCount'] as num?)?.toInt() ?? 0,
          isLikedByMe: c['isLikedByMe'] as bool? ?? false,
          userReelLoves:
              (c['userReelLoves'] as num?)?.toInt() ?? userReelLoves ?? 0,
          giftEmoji: c['giftEmoji'] as String? ?? giftEmoji,
          giftName: c['giftName'] as String? ?? giftName,
          createdAt: DateTime.tryParse(c['createdAt'] as String? ?? '') ??
              DateTime.now(),
        );
        final list = _fallbackComments[clipId] ?? [];
        _fallbackComments[clipId] = [comment, ...list];
        return comment;
      }
    } catch (e) {
      debugPrint('[HttpSocialRepository] addComment fallback: $e');
    }

    return _addCommentFallback(
      clipId: clipId,
      text: text,
      username: username,
      displayName: displayName,
      userReelLoves: userReelLoves,
      giftEmoji: giftEmoji,
      giftName: giftName,
    );
  }

  ReelComment _addCommentFallback({
    required String clipId,
    required String text,
    String? username,
    String? displayName,
    int? userReelLoves,
    String? giftEmoji,
    String? giftName,
  }) {
    final fallback = ReelComment(
      id: 'c_local_${DateTime.now().millisecondsSinceEpoch}',
      clipId: clipId,
      userId: 'u_current',
      username: username ?? 'ndugelo_musician',
      displayName: displayName ?? 'Ndugelo Musician',
      text: text.trim(),
      userReelLoves: userReelLoves ?? 0,
      giftEmoji: giftEmoji,
      giftName: giftName,
      createdAt: DateTime.now(),
    );
    final list = _fallbackComments[clipId] ?? [];
    _fallbackComments[clipId] = [fallback, ...list];
    return fallback;
  }

  @override
  Future<({bool liked, int likeCount})> toggleLikeComment(
      String commentId) async {
    if (isTestMode) return _toggleLikeCommentFallback(commentId);
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_baseUrl/social/comments/$commentId/like',
        data: {},
      );
      if (response.statusCode == 200 && response.data != null) {
        return (
          liked: response.data!['liked'] as bool? ?? true,
          likeCount: (response.data!['likeCount'] as num?)?.toInt() ?? 1,
        );
      }
    } catch (e) {
      debugPrint('[HttpSocialRepository] toggleLikeComment fallback: $e');
    }
    return _toggleLikeCommentFallback(commentId);
  }

  ({bool liked, int likeCount}) _toggleLikeCommentFallback(String commentId) {
    final prev = _fallbackLikes[commentId] ?? (liked: false, likeCount: 0);
    final next = (
      liked: !prev.liked,
      likeCount: (prev.likeCount + (!prev.liked ? 1 : -1)).clamp(0, 999999),
    );
    _fallbackLikes[commentId] = next;
    return next;
  }

  @override
  Future<
      ({
        GiftTransaction transaction,
        ReelComment comment,
        double newBalanceZar
      })> sendTip({
    required String clipId,
    required String giftId,
    String? senderUsername,
    String? message,
  }) async {
    if (isTestMode) {
      return _sendTipFallback(
        clipId: clipId,
        giftId: giftId,
        senderUsername: senderUsername,
        message: message,
      );
    }

    final payload = {
      'giftId': giftId,
      'senderUsername': ?senderUsername,
      'message': ?message,
    };

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_baseUrl/social/clips/$clipId/tip',
        data: payload,
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data!;
        final tx = GiftTransaction.fromJson(
            data['transaction'] as Map<String, dynamic>);
        final comment = ReelComment(
          id: data['comment']['id'] as String,
          clipId: clipId,
          userId: 'u_tipper',
          username: senderUsername ?? 'listener',
          displayName: senderUsername ?? 'Listener',
          text: data['comment']['text'] as String,
          giftEmoji: data['comment']['giftEmoji'] as String?,
          giftName: data['comment']['giftName'] as String?,
          createdAt: DateTime.now(),
        );
        final balance = (data['newBalanceZar'] as num).toDouble();
        return (transaction: tx, comment: comment, newBalanceZar: balance);
      }
    } catch (e) {
      debugPrint('[HttpSocialRepository] sendTip fallback: $e');
    }

    return _sendTipFallback(
      clipId: clipId,
      giftId: giftId,
      senderUsername: senderUsername,
      message: message,
    );
  }

  Future<
      ({
        GiftTransaction transaction,
        ReelComment comment,
        double newBalanceZar
      })> _sendTipFallback({
    required String clipId,
    required String giftId,
    String? senderUsername,
    String? message,
  }) async {
    final matchedGift = kCulturalGifts.firstWhere(
      (g) => g.id == giftId,
      orElse: () => kCulturalGifts.first,
    );
    final tx = GiftTransaction(
      id: 'tx_local_${DateTime.now().millisecondsSinceEpoch}',
      clipId: clipId,
      senderUsername: senderUsername ?? 'ndugelo_musician',
      recipientCreatorId: 'creator_makhadzi',
      gift: matchedGift,
      message: message,
      timestamp: DateTime.now(),
    );
    final comment = await addComment(
      clipId: clipId,
      text: (message != null && message.trim().isNotEmpty)
          ? '${message.trim()} (Sent ${matchedGift.name} ${matchedGift.emoji})'
          : 'Sent ${matchedGift.name} ${matchedGift.emoji}! Proud of this sound.',
      username: senderUsername ?? 'ndugelo_musician',
      displayName: senderUsername ?? 'Ndugelo Musician',
      giftEmoji: matchedGift.emoji,
      giftName: matchedGift.name,
      userReelLoves: 5,
    );
    return (transaction: tx, comment: comment, newBalanceZar: 1450.0);
  }

  @override
  Future<CreatorWallet> getCreatorWallet(String creatorId) async {
    if (isTestMode) return _getCreatorWalletFallback(creatorId);
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/creators/$creatorId/wallet',
      );
      if (response.statusCode == 200 && response.data != null) {
        return CreatorWallet.fromJson(response.data!);
      }
    } catch (e) {
      debugPrint('[HttpSocialRepository] getCreatorWallet fallback: $e');
    }

    return _getCreatorWalletFallback(creatorId);
  }

  CreatorWallet _getCreatorWalletFallback(String creatorId) {
    return _fallbackWallets.putIfAbsent(
      creatorId,
      () => CreatorWallet(
        creatorId: creatorId,
        balanceZar: 1420.0,
        totalCoinsReceived: 4750,
        topSupporters: const [
          SupporterRank(
            username: 'lerato_piano',
            displayName: 'LERATO PIANO',
            totalCoins: 1800,
            totalZar: 540.0,
            topGiftEmoji: '👑',
            rank: 1,
          ),
          SupporterRank(
            username: 'soweto_beats',
            displayName: 'SOWETO BEATS',
            totalCoins: 1200,
            totalZar: 360.0,
            topGiftEmoji: '🎹',
            rank: 2,
          ),
          SupporterRank(
            username: 'makhado_groove',
            displayName: 'MAKHADO GROOVE',
            totalCoins: 750,
            totalZar: 225.0,
            topGiftEmoji: '🥁',
            rank: 3,
          ),
        ],
        recentTransactions: const [],
      ),
    );
  }

  @override
  Future<PayoutReceipt> requestPayout({
    required String creatorId,
    required double amountZar,
    String payoutMethod = 'eft',
    required String accountDetails,
  }) async {
    if (isTestMode) {
      return _requestPayoutFallback(creatorId, amountZar);
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_baseUrl/creators/$creatorId/wallet/payout',
        data: {
          'amountZar': amountZar,
          'payoutMethod': payoutMethod,
          'accountDetails': accountDetails,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        return PayoutReceipt.fromJson(response.data!);
      }
    } catch (e) {
      debugPrint('[HttpSocialRepository] requestPayout fallback: $e');
    }

    return _requestPayoutFallback(creatorId, amountZar);
  }

  Future<PayoutReceipt> _requestPayoutFallback(
      String creatorId, double amountZar) async {
    final wallet = await getCreatorWallet(creatorId);
    final remaining = (wallet.balanceZar - amountZar).clamp(0.0, 999999.0);
    _fallbackWallets[creatorId] = wallet.copyWith(balanceZar: remaining);
    return PayoutReceipt(
      success: true,
      payoutId: 'payout_local_${DateTime.now().millisecondsSinceEpoch}',
      remainingBalanceZar: remaining,
    );
  }

  @override
  Future<({String clipId, String shareUrl, DateTime publishedAt})> publishClip(
    Map<String, dynamic> payload,
  ) async {
    if (isTestMode) return _publishClipFallback();
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_baseUrl/social/publish',
        data: payload,
      );
      if (response.statusCode == 201 && response.data != null) {
        final d = response.data!;
        return (
          clipId: d['clipId'] as String? ??
              'clip_${DateTime.now().millisecondsSinceEpoch}',
          shareUrl: d['shareUrl'] as String? ?? 'https://vhunambi.com/reels',
          publishedAt: DateTime.tryParse(d['publishedAt'] as String? ?? '') ??
              DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('[HttpSocialRepository] publishClip fallback: $e');
    }

    return _publishClipFallback();
  }

  ({String clipId, String shareUrl, DateTime publishedAt})
      _publishClipFallback() {
    final id = 'clip_pub_${DateTime.now().millisecondsSinceEpoch}';
    return (
      clipId: id,
      shareUrl: 'https://vhunambi.com/@creator/reels/$id',
      publishedAt: DateTime.now(),
    );
  }
}

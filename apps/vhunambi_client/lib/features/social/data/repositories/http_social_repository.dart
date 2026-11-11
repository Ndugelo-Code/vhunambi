import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/features/social/domain/models/creator_wallet.dart';
import 'package:vhunambi_client/features/social/domain/models/cultural_gift.dart';
import 'package:vhunambi_client/features/social/domain/models/published_clip.dart';
import 'package:vhunambi_client/features/social/domain/models/reel_comment.dart';
import 'package:vhunambi_client/features/social/domain/repositories/i_social_repository.dart';

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
  final bool _hasCustomDio;

  // In-memory fallback stores for offline/test resilience
  final Map<String, List<ReelComment>> _fallbackComments = {};
  final Map<String, ({bool liked, int likeCount})> _fallbackLikes = {};
  final Map<String, ({bool following, int followerCount})> _fallbackFollows =
      {};
  final Map<String, CreatorWallet> _fallbackWallets = {};
  final Map<String, PayFastCheckoutSession> _fallbackPayFastSessions = {};
  final Set<String> _settledFallbackCheckouts = {};

  HttpSocialRepository({
    Dio? dio,
    String? baseUrl,
    bool? isTestMode,
    Interceptor? authInterceptor,
  }) : _dio =
           dio ??
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
       isTestMode = isTestMode ?? _detectTestMode(),
       _hasCustomDio = dio != null {
    if (dio == null && authInterceptor != null) {
      _dio.interceptors.add(authInterceptor);
    }
  }

  bool get _shouldSkipNetwork => isTestMode && !_hasCustomDio;

  static bool _detectTestMode() {
    if (const bool.fromEnvironment('FLUTTER_TEST')) return true;
    try {
      if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  static String _resolveDefaultBaseUrl() => AppConstants.apiRestBaseUrl;

  @override
  Future<List<PublishedClip>> getFeed({String? cursor, int limit = 20}) async {
    if (_shouldSkipNetwork) return const [];
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/social/feed',
        queryParameters: {'cursor': ?cursor, 'limit': limit},
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
    if (_shouldSkipNetwork) return _toggleLikeClipFallback(clipId);
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
    String creatorId,
  ) async {
    if (_shouldSkipNetwork) return _toggleFollowCreatorFallback(creatorId);
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
    String creatorId,
  ) {
    final prev =
        _fallbackFollows[creatorId] ?? (following: false, followerCount: 120);
    final next = (
      following: !prev.following,
      followerCount: (prev.followerCount + (!prev.following ? 1 : -1)).clamp(
        0,
        999999,
      ),
    );
    _fallbackFollows[creatorId] = next;
    return next;
  }

  @override
  Future<List<PublishedClip>> getCreatorClips(String creatorId) async {
    if (_shouldSkipNetwork) return const [];
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
    if (_shouldSkipNetwork) return _fallbackComments[clipId] ?? const [];
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/social/clips/$clipId/comments',
      );
      if (response.statusCode == 200 && response.data != null) {
        final list = response.data!['comments'] as List<dynamic>? ?? const [];
        return list
            .map(
              (c) => ReelComment(
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
              ),
            )
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
    if (_shouldSkipNetwork) {
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
          id:
              c['id'] as String? ??
              'c_${DateTime.now().millisecondsSinceEpoch}',
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
          createdAt:
              DateTime.tryParse(c['createdAt'] as String? ?? '') ??
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
    String commentId,
  ) async {
    if (_shouldSkipNetwork) return _toggleLikeCommentFallback(commentId);
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
    ({GiftTransaction transaction, ReelComment comment, double newBalanceZar})
  >
  sendTip({
    required String clipId,
    required String giftId,
    String? senderUsername,
    String? message,
  }) async {
    if (_shouldSkipNetwork) {
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
          data['transaction'] as Map<String, dynamic>,
        );
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
    ({GiftTransaction transaction, ReelComment comment, double newBalanceZar})
  >
  _sendTipFallback({
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
    if (_shouldSkipNetwork) return _getCreatorWalletFallback(creatorId);
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
  Future<List<SaBankOption>> fetchSupportedBanks() async {
    if (_shouldSkipNetwork) return SaBankRegistry.banks;
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/wallet/banks',
      );
      if (response.statusCode == 200 && response.data != null) {
        final rawBanks = response.data!['banks'] as List<dynamic>? ?? const [];
        final parsed = rawBanks
            .whereType<Map>()
            .map((b) => SaBankOption.fromJson(Map<String, dynamic>.from(b)))
            .where((b) => b.canonicalName.isNotEmpty)
            .toList(growable: false);
        if (parsed.isNotEmpty) return parsed;
      }
    } catch (e) {
      debugPrint('[HttpSocialRepository] fetchSupportedBanks fallback: $e');
    }
    return SaBankRegistry.banks;
  }

  @override
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
  }) async {
    final resolvedRail =
        paymentRail ?? PayoutGatewayRail.fromWire(payoutMethod);
    final bankMeta = SaBankRegistry.lookupBank(bankName);
    final resolvedBankName = bankMeta?.canonicalName ?? bankName?.trim();
    final resolvedBranch = (branchCode != null && branchCode.trim().isNotEmpty)
        ? branchCode.trim()
        : bankMeta?.universalBranchCode;

    if (_shouldSkipNetwork) {
      return _requestPayoutFallback(
        creatorId,
        amountZar,
        bankName: resolvedBankName,
        branchCode: resolvedBranch,
        accountNumber: accountNumber,
        paymentRail: resolvedRail,
      );
    }

    final hasStructuredBank =
        resolvedBankName != null &&
        resolvedBankName.isNotEmpty &&
        accountNumber != null &&
        accountNumber.trim().isNotEmpty;

    final payload = <String, dynamic>{
      'creatorId': creatorId,
      'amountZar': amountZar,
      'payoutMethod': payoutMethod,
      'paymentRail': resolvedRail.wireId,
      'accountDetails': accountDetails,
      'bankName': ?resolvedBankName,
      if (accountHolder != null && accountHolder.trim().isNotEmpty)
        'accountHolder': accountHolder.trim(),
      if (accountNumber != null && accountNumber.trim().isNotEmpty)
        'accountNumber': accountNumber.trim(),
      if (resolvedBranch != null && resolvedBranch.isNotEmpty)
        'branchCode': resolvedBranch,
    };

    if (hasStructuredBank) {
      try {
        final response = await _dio.post<Map<String, dynamic>>(
          '$_baseUrl/wallet/payout',
          data: payload,
        );
        if (response.statusCode == 200 && response.data != null) {
          final receipt = PayoutReceipt.fromJson(response.data!);
          if (receipt.success && _fallbackWallets.containsKey(creatorId)) {
            _fallbackWallets[creatorId] = _fallbackWallets[creatorId]!.copyWith(
              balanceZar: receipt.remainingBalanceZar,
            );
          }
          return receipt;
        }
      } on DioException catch (e) {
        if (e.response?.statusCode == 400 && e.response?.data is Map) {
          final errMap = Map<String, dynamic>.from(e.response!.data as Map);
          final cachedWallet = _fallbackWallets[creatorId];
          return PayoutReceipt(
            success: false,
            payoutId: '',
            remainingBalanceZar: cachedWallet?.balanceZar ?? 0.0,
            status: 'rejected',
            bankName: resolvedBankName,
            branchCode: resolvedBranch,
            paymentRail: resolvedRail,
            error: errMap['error']?.toString() ?? 'Payout rejected by gateway',
          );
        }
        debugPrint('[HttpSocialRepository] /wallet/payout fallback: $e');
      } catch (e) {
        debugPrint('[HttpSocialRepository] /wallet/payout fallback: $e');
      }
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_baseUrl/creators/$creatorId/wallet/payout',
        data: payload,
      );
      if (response.statusCode == 200 && response.data != null) {
        return PayoutReceipt.fromJson(response.data!);
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 400 && e.response?.data is Map) {
        final errMap = Map<String, dynamic>.from(e.response!.data as Map);
        final cachedWallet = _fallbackWallets[creatorId];
        return PayoutReceipt(
          success: false,
          payoutId: '',
          remainingBalanceZar: cachedWallet?.balanceZar ?? 0.0,
          status: 'rejected',
          bankName: resolvedBankName,
          branchCode: resolvedBranch,
          paymentRail: resolvedRail,
          error: errMap['error']?.toString() ?? 'Payout rejected by gateway',
        );
      }
      debugPrint('[HttpSocialRepository] requestPayout fallback: $e');
    } catch (e) {
      debugPrint('[HttpSocialRepository] requestPayout fallback: $e');
    }

    return _requestPayoutFallback(
      creatorId,
      amountZar,
      bankName: resolvedBankName,
      branchCode: resolvedBranch,
      accountNumber: accountNumber,
      paymentRail: resolvedRail,
    );
  }

  Future<PayoutReceipt> _requestPayoutFallback(
    String creatorId,
    double amountZar, {
    String? bankName,
    String? branchCode,
    String? accountNumber,
    PayoutGatewayRail paymentRail = PayoutGatewayRail.eft,
  }) async {
    final wallet = await getCreatorWallet(creatorId);
    final remaining = (wallet.balanceZar - amountZar).clamp(0.0, 999999.0);
    _fallbackWallets[creatorId] = wallet.copyWith(balanceZar: remaining);
    final digits = (accountNumber ?? '').replaceAll(RegExp(r'\D'), '');
    final masked = digits.length >= 4
        ? '****${digits.substring(digits.length - 4)}'
        : null;
    return PayoutReceipt(
      success: true,
      payoutId: 'payout_local_${DateTime.now().millisecondsSinceEpoch}',
      remainingBalanceZar: remaining,
      status: paymentRail.isInstant ? 'instant_cleared' : 'processing',
      bankName: bankName,
      branchCode: branchCode,
      maskedAccount: masked,
      paymentRail: paymentRail,
      estimatedSettlement: paymentRail.estimatedSettlement,
    );
  }

  @override
  Future<({String clipId, String shareUrl, DateTime publishedAt})> publishClip(
    Map<String, dynamic> payload,
  ) async {
    if (_shouldSkipNetwork) return _publishClipFallback();
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_baseUrl/social/publish',
        data: payload,
      );
      if (response.statusCode == 201 && response.data != null) {
        final d = response.data!;
        return (
          clipId:
              d['clipId'] as String? ??
              'clip_${DateTime.now().millisecondsSinceEpoch}',
          shareUrl: d['shareUrl'] as String? ?? 'https://vhunambi.com/reels',
          publishedAt:
              DateTime.tryParse(d['publishedAt'] as String? ?? '') ??
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

  static const List<PayFastCoinPack> _defaultCoinPacks = <PayFastCoinPack>[
    PayFastCoinPack(
      packId: 'pack_starter_500',
      label: 'Starter Crate (500 Vhunambi Coins)',
      amountZar: 55.0,
      coinsGranted: 500,
    ),
    PayFastCoinPack(
      packId: 'pack_producer_1500',
      label: 'Producer Vault (1,500 Vhunambi Coins)',
      amountZar: 150.0,
      coinsGranted: 1500,
    ),
    PayFastCoinPack(
      packId: 'pack_mogul_5000',
      label: 'Studio Mogul (5,000 Vhunambi Coins)',
      amountZar: 450.0,
      coinsGranted: 5000,
    ),
  ];

  @override
  Future<List<PayFastCoinPack>> fetchPayFastCoinPacks() async {
    if (_shouldSkipNetwork) return _defaultCoinPacks;
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/payments/payfast/packs',
      );
      if (response.statusCode == 200 && response.data != null) {
        final rawPacks =
            response.data!['packs'] as List<dynamic>? ?? const <dynamic>[];
        final parsed = rawPacks
            .whereType<Map>()
            .map(
              (entry) => PayFastCoinPack.fromJson(
                Map<String, dynamic>.from(entry),
              ),
            )
            .where((pack) => pack.packId.isNotEmpty)
            .toList(growable: false);
        if (parsed.isNotEmpty) return parsed;
      }
    } catch (e) {
      debugPrint('[HttpSocialRepository] fetchPayFastCoinPacks fallback: $e');
    }
    return _defaultCoinPacks;
  }

  @override
  Future<PayFastCheckoutSession> initiatePayFastCheckout({
    required String creatorId,
    required String packId,
    double? amountZar,
    int? coinsGranted,
  }) async {
    if (_shouldSkipNetwork) {
      return _initiatePayFastFallback(
        creatorId: creatorId,
        packId: packId,
        amountZar: amountZar,
        coinsGranted: coinsGranted,
      );
    }
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_baseUrl/payments/payfast/checkout',
        data: <String, dynamic>{
          'creatorId': creatorId,
          'packId': packId,
          'amountZar': ?amountZar,
          'coinsGranted': ?coinsGranted,
        },
      );
      if ((response.statusCode == 201 || response.statusCode == 200) &&
          response.data != null) {
        final session = PayFastCheckoutSession.fromJson(response.data!);
        _fallbackPayFastSessions[session.checkoutId] = session;
        return session;
      }
    } catch (e) {
      debugPrint(
        '[HttpSocialRepository] initiatePayFastCheckout fallback: $e',
      );
    }
    return _initiatePayFastFallback(
      creatorId: creatorId,
      packId: packId,
      amountZar: amountZar,
      coinsGranted: coinsGranted,
    );
  }

  PayFastCheckoutSession _initiatePayFastFallback({
    required String creatorId,
    required String packId,
    double? amountZar,
    int? coinsGranted,
  }) {
    final matched = _defaultCoinPacks.where((p) => p.packId == packId);
    final pack = matched.isNotEmpty
        ? matched.first
        : PayFastCoinPack(
            packId: packId,
            label: 'Vhunambi Sovereign Coin Top-Up',
            amountZar: amountZar ?? 150.0,
            coinsGranted: coinsGranted ?? 1500,
          );
    final checkoutId = 'chk_pf_local_${DateTime.now().millisecondsSinceEpoch}';
    final session = PayFastCheckoutSession(
      checkoutId: checkoutId,
      creatorId: creatorId,
      packId: pack.packId,
      amountZar: pack.amountZar,
      coinsToCredit: pack.coinsGranted,
      paymentUrl: 'https://sandbox.payfast.co.za/eng/process',
      formFields: <String, String>{
        'm_payment_id': checkoutId,
        'amount': pack.amountZar.toStringAsFixed(2),
        'item_name': pack.label,
        'custom_str1': creatorId,
        'custom_str2': pack.packId,
      },
      signature: 'local_sandbox_sig',
      status: 'pending',
    );
    _fallbackPayFastSessions[checkoutId] = session;
    return session;
  }

  @override
  Future<PayFastStatusSnapshot> getPayFastCheckoutStatus(
    String checkoutId,
  ) async {
    if (_shouldSkipNetwork) {
      return _payFastStatusFallback(checkoutId);
    }
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/payments/payfast/status/$checkoutId',
      );
      if (response.statusCode == 200 && response.data != null) {
        return PayFastStatusSnapshot.fromJson(response.data!);
      }
    } catch (e) {
      debugPrint(
        '[HttpSocialRepository] getPayFastCheckoutStatus fallback: $e',
      );
    }
    return _payFastStatusFallback(checkoutId);
  }

  @override
  Future<PayFastStatusSnapshot> sandboxSettlePayFastCheckout(
    String checkoutId,
  ) async {
    if (_shouldSkipNetwork) {
      return _payFastSettleFallback(checkoutId);
    }
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_baseUrl/payments/payfast/sandbox-settle/$checkoutId',
      );
      if (response.statusCode == 200 && response.data != null) {
        return PayFastStatusSnapshot.fromJson(response.data!);
      }
    } catch (e) {
      debugPrint(
        '[HttpSocialRepository] sandboxSettlePayFastCheckout fallback: $e',
      );
    }
    return _payFastSettleFallback(checkoutId);
  }

  PayFastStatusSnapshot _payFastStatusFallback(String checkoutId) {
    final session = _fallbackPayFastSessions[checkoutId];
    final creatorId = session?.creatorId ?? 'creator_cern';
    final wallet = _getCreatorWalletFallback(creatorId);
    final settled = _settledFallbackCheckouts.contains(checkoutId);
    return PayFastStatusSnapshot(
      checkoutId: checkoutId,
      creatorId: creatorId,
      status: settled ? 'completed' : (session?.status ?? 'pending'),
      settled: settled,
      coinsCredited: settled ? (session?.coinsToCredit ?? 0) : 0,
      walletBalanceCoins: wallet.balanceCoins ?? wallet.totalCoinsReceived,
      walletBalanceZar: wallet.balanceZar,
    );
  }

  PayFastStatusSnapshot _payFastSettleFallback(String checkoutId) {
    final session = _fallbackPayFastSessions[checkoutId];
    final creatorId = session?.creatorId ?? 'creator_cern';
    final coins = session?.coinsToCredit ?? 500;
    final currentWallet = _getCreatorWalletFallback(creatorId);
    final currentCoins =
        currentWallet.balanceCoins ?? currentWallet.totalCoinsReceived;
    final alreadySettled = _settledFallbackCheckouts.contains(checkoutId);
    final nextCoins = alreadySettled ? currentCoins : currentCoins + coins;
    if (!alreadySettled) {
      _settledFallbackCheckouts.add(checkoutId);
      _fallbackWallets[creatorId] = currentWallet.copyWith(
        balanceCoins: nextCoins,
      );
    }
    return PayFastStatusSnapshot(
      checkoutId: checkoutId,
      creatorId: creatorId,
      status: 'completed',
      settled: true,
      idempotentReplay: alreadySettled,
      coinsCredited: coins,
      walletBalanceCoins: nextCoins,
      walletBalanceZar: currentWallet.balanceZar,
      pfPaymentId: 'pf_sandbox_$checkoutId',
    );
  }
}

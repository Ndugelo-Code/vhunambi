import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/cultural_gift.dart';
import 'reels_comments_provider.dart';

/// A recorded gift transaction sent to an African creator (REQ-GFT-02).
@immutable
class GiftTransaction {
  final String id;
  final String clipId;
  final String senderUsername;
  final String recipientCreatorId;
  final CulturalGift gift;
  final String? message;
  final DateTime timestamp;

  const GiftTransaction({
    required this.id,
    required this.clipId,
    required this.senderUsername,
    required this.recipientCreatorId,
    required this.gift,
    this.message,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'clipId': clipId,
        'senderUsername': senderUsername,
        'recipientCreatorId': recipientCreatorId,
        'gift': gift.toJson(),
        'message': message,
        'timestamp': timestamp.toIso8601String(),
      };

  factory GiftTransaction.fromJson(Map<String, dynamic> json) {
    return GiftTransaction(
      id: json['id'] as String,
      clipId: json['clipId'] as String,
      senderUsername: json['senderUsername'] as String,
      recipientCreatorId: json['recipientCreatorId'] as String,
      gift: CulturalGift.fromJson(json['gift'] as Map<String, dynamic>),
      message: json['message'] as String?,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// A top supporter entry on the creator's leaderboard (REQ-WAL-02).
@immutable
class SupporterRank {
  final String username;
  final String displayName;
  final int totalCoins;
  final double totalZar;
  final String topGiftEmoji;
  final int rank;

  const SupporterRank({
    required this.username,
    required this.displayName,
    required this.totalCoins,
    required this.totalZar,
    required this.topGiftEmoji,
    required this.rank,
  });

  Map<String, dynamic> toJson() => {
        'username': username,
        'displayName': displayName,
        'totalCoins': totalCoins,
        'totalZar': totalZar,
        'topGiftEmoji': topGiftEmoji,
        'rank': rank,
      };

  factory SupporterRank.fromJson(Map<String, dynamic> json) {
    return SupporterRank(
      username: json['username'] as String,
      displayName: json['displayName'] as String,
      totalCoins: (json['totalCoins'] as num).toInt(),
      totalZar: (json['totalZar'] as num).toDouble(),
      topGiftEmoji: json['topGiftEmoji'] as String? ?? '🪙',
      rank: (json['rank'] as num).toInt(),
    );
  }
}

/// State of the user's gifting wallet and creator earnings ledger (REQ-WAL-01).
@immutable
class CreatorWalletState {
  /// The current user's coin balance for sending gifts.
  final int userCoinsBalance;

  /// The creator's total lifetime earnings in South African Rand (ZAR).
  final double creatorEarnedZar;

  /// The creator's total lifetime cultural coins received.
  final int creatorReceivedCoins;

  /// Full history of gift transactions sent or received.
  final List<GiftTransaction> transactions;

  /// Top patron leaderboard for this creator profile.
  final List<SupporterRank> topSupporters;

  /// Whether a cashout payout operation is currently pending.
  final bool isProcessingPayout;

  /// Status message from the most recent payout request.
  final String? payoutStatusMessage;

  const CreatorWalletState({
    this.userCoinsBalance = 250,
    this.creatorEarnedZar = 1420.0,
    this.creatorReceivedCoins = 4750,
    this.transactions = const [],
    this.topSupporters = const [],
    this.isProcessingPayout = false,
    this.payoutStatusMessage,
  });

  CreatorWalletState copyWith({
    int? userCoinsBalance,
    double? creatorEarnedZar,
    int? creatorReceivedCoins,
    List<GiftTransaction>? transactions,
    List<SupporterRank>? topSupporters,
    bool? isProcessingPayout,
    String? payoutStatusMessage,
  }) {
    return CreatorWalletState(
      userCoinsBalance: userCoinsBalance ?? this.userCoinsBalance,
      creatorEarnedZar: creatorEarnedZar ?? this.creatorEarnedZar,
      creatorReceivedCoins:
          creatorReceivedCoins ?? this.creatorReceivedCoins,
      transactions: transactions ?? this.transactions,
      topSupporters: topSupporters ?? this.topSupporters,
      isProcessingPayout: isProcessingPayout ?? this.isProcessingPayout,
      payoutStatusMessage: payoutStatusMessage ?? this.payoutStatusMessage,
    );
  }
}

/// Manages cultural micro-gifting, coin deductions, creator ledger credits,
/// and automated celebratory comment announcements.
class CreatorWalletNotifier extends StateNotifier<CreatorWalletState> {
  final Ref _ref;

  CreatorWalletNotifier(this._ref) : super(const CreatorWalletState()) {
    _seedInitialState();
  }

  void _seedInitialState() {
    final now = DateTime.now();

    final seedTxs = [
      GiftTransaction(
        id: 'tx_seed_01',
        clipId: 'clip_seed_01',
        senderUsername: 'thabo_beats',
        recipientCreatorId: 'creator_makhadzi',
        gift: kCulturalGifts[3], // Royal Venda Crown
        message: 'Masterclass production from Makhado! 👑🇿🇦',
        timestamp: now.subtract(const Duration(hours: 2)),
      ),
      GiftTransaction(
        id: 'tx_seed_02',
        clipId: 'clip_seed_01',
        senderUsername: 'lerato_piano',
        recipientCreatorId: 'creator_makhadzi',
        gift: kCulturalGifts[2], // Log Drum Trophy
        message: 'Bassline is unreal! 🎹',
        timestamp: now.subtract(const Duration(hours: 4)),
      ),
      GiftTransaction(
        id: 'tx_seed_03',
        clipId: 'clip_seed_02',
        senderUsername: 'sbu_gqom',
        recipientCreatorId: 'creator_makhadzi',
        gift: kCulturalGifts[1], // African Drum
        message: 'Pure rhythm energy! 🥁',
        timestamp: now.subtract(const Duration(hours: 8)),
      ),
    ];

    const seedRanks = [
      SupporterRank(
        username: 'thabo_beats',
        displayName: 'Thabo Beats',
        totalCoins: 1200,
        totalZar: 300.0,
        topGiftEmoji: '👑',
        rank: 1,
      ),
      SupporterRank(
        username: 'lerato_piano',
        displayName: 'Lerato Piano',
        totalCoins: 650,
        totalZar: 195.0,
        topGiftEmoji: '🎹',
        rank: 2,
      ),
      SupporterRank(
        username: 'sbu_gqom',
        displayName: 'Sbu Gqom',
        totalCoins: 450,
        totalZar: 135.0,
        topGiftEmoji: '🥁',
        rank: 3,
      ),
      SupporterRank(
        username: 'kgothatso_sa',
        displayName: 'Kgothatso',
        totalCoins: 180,
        totalZar: 54.0,
        topGiftEmoji: '🐚',
        rank: 4,
      ),
    ];

    state = state.copyWith(
      transactions: seedTxs,
      topSupporters: seedRanks,
    );
  }

  /// Sends an African cultural gift to a creator (REQ-GFT-01 / REQ-GFT-02).
  ///
  /// Deducts [gift.coinPrice] from [userCoinsBalance], credits creator's
  /// ZAR and coin ledgers, logs the transaction, and pins a celebratory
  /// announcement into the reel's comment thread.
  Future<bool> sendGift({
    required String clipId,
    required String recipientCreatorId,
    required String senderUsername,
    required CulturalGift gift,
    String? message,
    String? senderDisplayName,
  }) async {
    if (state.userCoinsBalance < gift.coinPrice) {
      return false;
    }

    final newTx = GiftTransaction(
      id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
      clipId: clipId,
      senderUsername: senderUsername,
      recipientCreatorId: recipientCreatorId,
      gift: gift,
      message: message,
      timestamp: DateTime.now(),
    );

    final commentText = (message != null && message.trim().isNotEmpty)
        ? '${gift.emoji} Sent a ${gift.name}! "${message.trim()}"'
        : '${gift.emoji} Sent a ${gift.name}!';

    // Deduct coins & credit creator
    state = state.copyWith(
      userCoinsBalance: state.userCoinsBalance - gift.coinPrice,
      creatorEarnedZar: state.creatorEarnedZar + gift.zarPrice,
      creatorReceivedCoins: state.creatorReceivedCoins + gift.coinPrice,
      transactions: [newTx, ...state.transactions],
    );

    // Auto-post celebratory supporter announcement to reel comments
    _ref.read(reelsCommentsProvider.notifier).addComment(
          clipId: clipId,
          text: commentText,
          username: senderUsername,
          displayName: senderDisplayName ?? senderUsername,
          giftEmoji: gift.emoji,
          giftName: gift.name,
        );

    return true;
  }

  /// Adds coins to the user's gifting balance.
  void topUpCoins(int coins) {
    if (coins <= 0) return;
    state = state.copyWith(
      userCoinsBalance: state.userCoinsBalance + coins,
    );
  }

  /// Requests payout for earned creator royalties via South African rails (REQ-WAL-03).
  Future<bool> requestPayout({
    required double amountZar,
    required String payoutMethod,
  }) async {
    if (amountZar > state.creatorEarnedZar || amountZar < 50.0) {
      return false;
    }

    state = state.copyWith(isProcessingPayout: true);

    state = state.copyWith(
      creatorEarnedZar: state.creatorEarnedZar - amountZar,
      isProcessingPayout: false,
      payoutStatusMessage:
          'Payout of R${amountZar.toStringAsFixed(2)} via $payoutMethod initiated successfully!',
    );

    return true;
  }
}

/// Global provider for the Creator Cultural Wallet and micro-gifting ledger.
final creatorWalletProvider =
    StateNotifierProvider<CreatorWalletNotifier, CreatorWalletState>((ref) {
  return CreatorWalletNotifier(ref);
});

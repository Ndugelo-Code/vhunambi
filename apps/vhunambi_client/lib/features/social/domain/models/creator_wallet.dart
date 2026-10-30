import 'package:flutter/foundation.dart';
import 'cultural_gift.dart';

/// Represents a top community supporter on a creator's tipping leaderboard (REQ-WAL-01).
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
      username: json['username'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      totalCoins: (json['totalCoins'] as num?)?.toInt() ?? 0,
      totalZar: (json['totalZar'] as num?)?.toDouble() ?? 0.0,
      topGiftEmoji: json['topGiftEmoji'] as String? ?? '🐚',
      rank: (json['rank'] as num?)?.toInt() ?? 1,
    );
  }
}

/// Ledger entry for a cultural micro-gift tip sent to a creator (REQ-GFT-02, REQ-WAL-01).
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
        if (message != null) 'message': message,
        'timestamp': timestamp.toIso8601String(),
      };

  factory GiftTransaction.fromJson(Map<String, dynamic> json) {
    return GiftTransaction(
      id: json['id'] as String? ?? '',
      clipId: json['clipId'] as String? ?? '',
      senderUsername: json['senderUsername'] as String? ?? 'listener',
      recipientCreatorId: json['recipientCreatorId'] as String? ?? '',
      gift: json['gift'] != null
          ? CulturalGift.fromJson(json['gift'] as Map<String, dynamic>)
          : kCulturalGifts.first,
      message: json['message'] as String?,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// Creator financial balance, lifetime coins, and tipping ledger (REQ-WAL-01).
@immutable
class CreatorWallet {
  final String creatorId;
  final double balanceZar;
  final int totalCoinsReceived;
  final List<SupporterRank> topSupporters;
  final List<GiftTransaction> recentTransactions;

  const CreatorWallet({
    required this.creatorId,
    this.balanceZar = 0.0,
    this.totalCoinsReceived = 0,
    this.topSupporters = const [],
    this.recentTransactions = const [],
  });

  CreatorWallet copyWith({
    String? creatorId,
    double? balanceZar,
    int? totalCoinsReceived,
    List<SupporterRank>? topSupporters,
    List<GiftTransaction>? recentTransactions,
  }) {
    return CreatorWallet(
      creatorId: creatorId ?? this.creatorId,
      balanceZar: balanceZar ?? this.balanceZar,
      totalCoinsReceived: totalCoinsReceived ?? this.totalCoinsReceived,
      topSupporters: topSupporters ?? this.topSupporters,
      recentTransactions: recentTransactions ?? this.recentTransactions,
    );
  }

  Map<String, dynamic> toJson() => {
        'creatorId': creatorId,
        'balanceZar': balanceZar,
        'totalCoinsReceived': totalCoinsReceived,
        'topSupporters': topSupporters.map((s) => s.toJson()).toList(),
        'recentTransactions':
            recentTransactions.map((tx) => tx.toJson()).toList(),
      };

  factory CreatorWallet.fromJson(Map<String, dynamic> json) {
    return CreatorWallet(
      creatorId: json['creatorId'] as String? ?? '',
      balanceZar: (json['balanceZar'] as num?)?.toDouble() ?? 0.0,
      totalCoinsReceived:
          (json['totalCoinsReceived'] as num?)?.toInt() ?? 0,
      topSupporters: (json['topSupporters'] as List<dynamic>?)
              ?.map((e) => SupporterRank.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      recentTransactions: (json['recentTransactions'] as List<dynamic>?)
              ?.map((e) => GiftTransaction.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

/// Confirmation receipt after a creator requests a cashout payout (REQ-WAL-02).
@immutable
class PayoutReceipt {
  final bool success;
  final String payoutId;
  final double remainingBalanceZar;

  const PayoutReceipt({
    required this.success,
    required this.payoutId,
    required this.remainingBalanceZar,
  });

  Map<String, dynamic> toJson() => {
        'success': success,
        'payoutId': payoutId,
        'remainingBalanceZar': remainingBalanceZar,
      };

  factory PayoutReceipt.fromJson(Map<String, dynamic> json) {
    return PayoutReceipt(
      success: json['success'] as bool? ?? false,
      payoutId: json['payoutId'] as String? ?? '',
      remainingBalanceZar:
          (json['remainingBalanceZar'] as num?)?.toDouble() ?? 0.0,
    );
  }
}


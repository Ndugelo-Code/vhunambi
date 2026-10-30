import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/creator_wallet.dart';
import '../../domain/models/cultural_gift.dart';
import '../../domain/repositories/i_social_repository.dart';
import 'reels_comments_provider.dart';
import 'social_repository_provider.dart';

export '../../domain/models/creator_wallet.dart';
export '../../domain/models/cultural_gift.dart';

/// Immutable state for creator cultural wallet & micro-gifting (REQ-WAL-01 … REQ-WAL-03).
class CreatorWalletState {
  final int userCoinsBalance;
  final double creatorEarnedZar;
  final int creatorReceivedCoins;
  final List<SupporterRank> topSupporters;
  final List<GiftTransaction> transactions;
  final String? payoutStatusMessage;
  final bool isLoading;
  final String? errorMessage;
  final CreatorWallet? wallet;

  const CreatorWalletState({
    this.userCoinsBalance = 250,
    this.creatorEarnedZar = 1420.0,
    this.creatorReceivedCoins = 4750,
    this.topSupporters = const [],
    this.transactions = const [],
    this.payoutStatusMessage,
    this.isLoading = false,
    this.errorMessage,
    this.wallet,
  });

  CreatorWalletState copyWith({
    int? userCoinsBalance,
    double? creatorEarnedZar,
    int? creatorReceivedCoins,
    List<SupporterRank>? topSupporters,
    List<GiftTransaction>? transactions,
    String? payoutStatusMessage,
    bool? isLoading,
    String? errorMessage,
    CreatorWallet? wallet,
  }) {
    return CreatorWalletState(
      userCoinsBalance: userCoinsBalance ?? this.userCoinsBalance,
      creatorEarnedZar: creatorEarnedZar ?? this.creatorEarnedZar,
      creatorReceivedCoins: creatorReceivedCoins ?? this.creatorReceivedCoins,
      topSupporters: topSupporters ?? this.topSupporters,
      transactions: transactions ?? this.transactions,
      payoutStatusMessage: payoutStatusMessage ?? this.payoutStatusMessage,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      wallet: wallet ?? this.wallet,
    );
  }
}

/// Orchestrates creator earnings, fan tipping, and royalty cashouts.
class CreatorWalletNotifier extends StateNotifier<CreatorWalletState> {
  final Ref _ref;
  final ISocialRepository? _repo;
  final String _creatorId;

  CreatorWalletNotifier(
    this._ref, {
    this._repo,
    this._creatorId = 'creator_makhadzi',
  }) : super(const CreatorWalletState()) {
    _seedInitial();
  }

  void _seedInitial() {
    state = state.copyWith(
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
      transactions: [
        GiftTransaction(
          id: 'tx_seed_1',
          clipId: 'clip_seed_01',
          senderUsername: 'lerato_piano',
          recipientCreatorId: _creatorId,
          gift: kCulturalGifts.firstWhere((g) => g.id == 'royal_venda_crown'),
          message: 'Legendary piano groove! 👑',
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      ],
    );
  }

  Future<void> loadWallet() async {
    if (_repo == null) return;
    try {
      final remoteWallet = await _repo.getCreatorWallet(_creatorId);
      state = state.copyWith(
        wallet: remoteWallet,
        creatorEarnedZar: remoteWallet.balanceZar,
        creatorReceivedCoins: remoteWallet.totalCoinsReceived,
        topSupporters: remoteWallet.topSupporters.isNotEmpty
            ? remoteWallet.topSupporters
            : state.topSupporters,
        transactions: remoteWallet.recentTransactions.isNotEmpty
            ? remoteWallet.recentTransactions
            : state.transactions,
      );
    } catch (_) {}
  }

  /// Tops up the current user's coin balance.
  void topUpCoins(int amount) {
    if (amount <= 0) return;
    state = state.copyWith(userCoinsBalance: state.userCoinsBalance + amount);
  }

  /// Sends a cultural micro-gift to a creator.
  Future<bool> sendGift({
    required String clipId,
    required String recipientCreatorId,
    required String senderUsername,
    String? senderDisplayName,
    required CulturalGift gift,
    String? message,
  }) async {
    if (state.userCoinsBalance < gift.coinPrice) {
      return false;
    }

    final tx = GiftTransaction(
      id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
      clipId: clipId,
      senderUsername: senderUsername,
      recipientCreatorId: recipientCreatorId,
      gift: gift,
      message: message,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      userCoinsBalance: state.userCoinsBalance - gift.coinPrice,
      creatorEarnedZar: state.creatorEarnedZar + gift.zarPrice,
      creatorReceivedCoins: state.creatorReceivedCoins + gift.coinPrice,
      transactions: [tx, ...state.transactions],
    );

    // Auto-post cultural celebration comment into reel thread (REQ-GFT-03)
    final commentText = (message != null && message.trim().isNotEmpty)
        ? 'Sent a ${gift.name}! $message'
        : 'Sent a ${gift.name}! Proud of this sound.';

    _ref
        .read(reelsCommentsProvider.notifier)
        .addComment(
          clipId: clipId,
          text: commentText,
          username: senderUsername,
          displayName: senderDisplayName ?? senderUsername,
          giftEmoji: gift.emoji,
          giftName: gift.name,
          userReelLoves: 5,
        );

    _repo?.sendTip(
      clipId: clipId,
      giftId: gift.id,
      senderUsername: senderUsername,
      message: message,
    );

    return true;
  }

  /// Requests a payout / royalty cashout (REQ-WAL-02).
  Future<bool> requestPayout({
    required double amountZar,
    required String payoutMethod,
  }) async {
    if (amountZar < 50.0 || amountZar > state.creatorEarnedZar) {
      return false;
    }

    state = state.copyWith(
      creatorEarnedZar: state.creatorEarnedZar - amountZar,
      payoutStatusMessage:
          'Payout of R${amountZar.toStringAsFixed(2)} via $payoutMethod initiated!',
    );

    _repo?.requestPayout(
      creatorId: _creatorId,
      amountZar: amountZar,
      payoutMethod: payoutMethod,
      accountDetails: payoutMethod,
    );

    return true;
  }
}

final creatorWalletProvider =
    StateNotifierProvider<CreatorWalletNotifier, CreatorWalletState>((ref) {
      final repo = ref.watch(socialRepositoryProvider);
      return CreatorWalletNotifier(ref, repo: repo);
    });

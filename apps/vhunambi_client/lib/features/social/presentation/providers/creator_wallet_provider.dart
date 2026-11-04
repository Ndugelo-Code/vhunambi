import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../collections/domain/models/collection_entity.dart';
import '../../../collections/domain/services/royalty_distribution_service.dart';
import '../../domain/models/creator_wallet.dart';
import '../../domain/models/cultural_gift.dart';
import '../../domain/repositories/i_social_repository.dart';
import 'reels_comments_provider.dart';
import 'social_repository_provider.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../../notifications/domain/models/notification_entity.dart';
import '../../../notifications/domain/models/notification_enums.dart';

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

  /// Dispatches a track tip (credits/coins), splitting proceeds proportionally
  /// across collaborators if the track belongs to a collection with a valid split sheet (REQ-ROY-SPLIT-03),
  /// or across co-creators (e.g. 70% Remixer / 30% Originator) if [coCreationSplits] is present (Phase 37 REQ-RMX-ROYALTY-01).
  Future<bool> distributeTrackTip({
    required String trackId,
    required String trackTitle,
    required String creatorId,
    required String creatorName,
    required int credits,
    CollectionEntity? collection,
    List<SplitParticipant>? coCreationSplits,
  }) async {
    if (state.userCoinsBalance < credits || credits <= 0) {
      return false;
    }

    // Convert credits to ZAR (R0.30 per coin/credit in standard Vhunambi tokenomics)
    final grossZar = double.parse((credits * 0.30).toStringAsFixed(2));
    final grossCoins = credits;

    final distributions =
        (coCreationSplits != null && coCreationSplits.isNotEmpty)
        ? RoyaltyDistributionService.calculateDirectSplit(
            splits: coCreationSplits,
            grossZar: grossZar,
            grossCoins: grossCoins,
          ).distributions
        : (collection != null && collection.isSplitBalanced)
        ? RoyaltyDistributionService.calculateSplit(
            collection: collection,
            grossZar: grossZar,
            grossCoins: grossCoins,
          ).distributions
        : [
            SplitShareDistribution(
              participant: SplitParticipant(
                name: creatorName,
                role: 'Creator',
                sharePercent: 100.0,
                creatorId: creatorId,
              ),
              zarAmount: grossZar,
              coinsAmount: grossCoins,
            ),
          ];

    // Debit user coins, credit creator wallet earnings
    final newTransactions = <GiftTransaction>[...state.transactions];
    for (final dist in distributions) {
      newTransactions.insert(
        0,
        GiftTransaction(
          id: 'tx_tip_${DateTime.now().millisecondsSinceEpoch}_${dist.participant.name}',
          clipId: trackId,
          senderUsername: 'me',
          recipientCreatorId: dist.participant.creatorId ?? creatorId,
          gift: CulturalGift(
            id: 'tip_${dist.participant.name}',
            name: collection != null
                ? 'Split Tip: ${collection.title} (${dist.participant.shareLabel})'
                : 'Track Tip: $trackTitle',
            emoji: '🪙',
            coinPrice: dist.coinsAmount,
            zarPrice: dist.zarAmount,
            culturalMeaning: 'Music connects through fair splits',
          ),
          message:
              'Tip on "$trackTitle" [${dist.participant.role} - ${dist.participant.shareLabel}]',
          timestamp: DateTime.now(),
        ),
      );
    }

    state = state.copyWith(
      userCoinsBalance: state.userCoinsBalance - credits,
      creatorEarnedZar: state.creatorEarnedZar + grossZar,
      creatorReceivedCoins: state.creatorReceivedCoins + grossCoins,
      transactions: newTransactions,
    );

    _ref.read(notificationsProvider.notifier).addNotification(
      NotificationEntity(
        id: 'notif_tip_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Tip Sent!',
        message: 'Tipped $credits credits on "$trackTitle".',
        category: NotificationCategory.social,
        priority: NotificationPriority.normal,
        createdAt: DateTime.now(),
      ),
    );
    return true;
  }

  /// Distributes beat license sales or marketplace royalty earnings across collection collaborators (REQ-ROY-SPLIT-02).
  Future<RoyaltyDistributionResult> distributeSplitPayout({
    required CollectionEntity collection,
    required double grossZar,
    int grossCoins = 0,
    required String trackTitle,
  }) async {
    final result = RoyaltyDistributionService.calculateSplit(
      collection: collection,
      grossZar: grossZar,
      grossCoins: grossCoins,
    );

    final newTransactions = <GiftTransaction>[...state.transactions];
    for (final dist in result.distributions) {
      newTransactions.insert(
        0,
        GiftTransaction(
          id: 'tx_royalty_${DateTime.now().millisecondsSinceEpoch}_${dist.participant.name}',
          clipId: collection.id,
          senderUsername: 'marketplace',
          recipientCreatorId: dist.participant.creatorId ?? _creatorId,
          gift: CulturalGift(
            id: 'royalty_${dist.participant.name}',
            name:
                'Royalty Split: ${collection.title} (${dist.participant.shareLabel})',
            emoji: '💎',
            coinPrice: dist.coinsAmount,
            zarPrice: dist.zarAmount,
            culturalMeaning: 'Fair compensation for all collaborators',
          ),
          message:
              'Royalty on "$trackTitle" [${dist.participant.role} - ${dist.participant.shareLabel}]',
          timestamp: DateTime.now(),
        ),
      );
    }

    state = state.copyWith(
      creatorEarnedZar: state.creatorEarnedZar + grossZar,
      creatorReceivedCoins: state.creatorReceivedCoins + grossCoins,
      transactions: newTransactions,
    );

    return result;
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


  /// Records direct 85% creator marketplace royalty earnings from beat / vocal / pack licenses (REQ-MARKET-03).
  void recordMarketplaceRoyalty({
    required String assetTitle,
    required int amountCoins,
    required double netZar,
  }) {
    state = state.copyWith(
      creatorEarnedZar: state.creatorEarnedZar + netZar,
      creatorReceivedCoins: state.creatorReceivedCoins + amountCoins,
      transactions: [
        GiftTransaction(
          id: 'tx_royalty_${DateTime.now().millisecondsSinceEpoch}',
          clipId: 'marketplace_asset',
          senderUsername: 'marketplace_buyer',
          recipientCreatorId: _creatorId,
          gift: CulturalGift(
            id: 'royalty_license',
            name: '85% Royalty: $assetTitle',
            emoji: '💎',
            coinPrice: amountCoins,
            zarPrice: netZar,
            culturalMeaning: 'Fair creator split (85%) from marketplace licensing',
          ),
          message: 'Marketplace license sale for "$assetTitle"',
          timestamp: DateTime.now(),
        ),
        ...state.transactions,
      ],
    );
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

  /// Requests a verified banking payout with full account and branch details (Phase 41 REQ-PAYOUT-DISPATCH-01).
  Future<bool> requestBankingPayout({
    required double amountZar,
    required CreatorBankingDetails bankingDetails,
  }) async {
    if (amountZar < 50.0 || amountZar > state.creatorEarnedZar) {
      return false;
    }

    final statusMsg =
        'Payout of R${amountZar.toStringAsFixed(2)} to ${bankingDetails.bankName} (${bankingDetails.maskedAccount}) initiated!';

    state = state.copyWith(
      creatorEarnedZar: state.creatorEarnedZar - amountZar,
      payoutStatusMessage: statusMsg,
    );

    _repo?.requestPayout(
      creatorId: _creatorId,
      amountZar: amountZar,
      payoutMethod: bankingDetails.payoutMethod,
      accountDetails:
          '${bankingDetails.bankName} - ${bankingDetails.accountNumber} (${bankingDetails.accountHolder}) [Branch: ${bankingDetails.branchCode}]',
    );

    _ref.read(notificationsProvider.notifier).addNotification(
      NotificationEntity(
        id: 'notif_payout_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Royalty Payout Initiated',
        message: statusMsg,
        category: NotificationCategory.system,
        priority: NotificationPriority.high,
        createdAt: DateTime.now(),
      ),
    );

    return true;
  }
}

final creatorWalletProvider =
    StateNotifierProvider<CreatorWalletNotifier, CreatorWalletState>((ref) {
      final repo = ref.watch(socialRepositoryProvider);
      return CreatorWalletNotifier(ref, repo: repo);
    });

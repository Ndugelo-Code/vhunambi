import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/social/presentation/providers/creator_wallet_provider.dart';
import 'package:vhunambi_client/features/social/presentation/providers/reels_comments_provider.dart';

void main() {
  group('CulturalGift & kCulturalGifts', () {
    test('contains 4 canonical African cultural gifts with accurate pricing', () {
      expect(kCulturalGifts.length, 4);

      final cowrie = kCulturalGifts.firstWhere((g) => g.id == 'cowrie_shell');
      expect(cowrie.coinPrice, 5);
      expect(cowrie.zarPrice, 2.0);
      expect(cowrie.emoji, '🐚');

      final drum = kCulturalGifts.firstWhere((g) => g.id == 'african_drum');
      expect(drum.coinPrice, 15);
      expect(drum.zarPrice, 5.0);
      expect(drum.emoji, '🥁');

      final logDrum = kCulturalGifts.firstWhere((g) => g.id == 'log_drum_trophy');
      expect(logDrum.coinPrice, 50);
      expect(logDrum.zarPrice, 15.0);
      expect(logDrum.emoji, '🎹');

      final crown = kCulturalGifts.firstWhere((g) => g.id == 'royal_venda_crown');
      expect(crown.coinPrice, 200);
      expect(crown.zarPrice, 50.0);
      expect(crown.emoji, '👑');
    });

    test('serializes CulturalGift correctly', () {
      final gift = kCulturalGifts.first;
      final json = gift.toJson();
      final fromJson = CulturalGift.fromJson(json);

      expect(fromJson.id, gift.id);
      expect(fromJson.name, gift.name);
      expect(fromJson.coinPrice, gift.coinPrice);
      expect(fromJson.zarPrice, gift.zarPrice);
    });
  });

  group('CreatorWalletNotifier & creatorWalletProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state has default coin balance and seed leaderboard', () {
      final state = container.read(creatorWalletProvider);
      expect(state.userCoinsBalance, 250);
      expect(state.creatorEarnedZar, 1420.0);
      expect(state.creatorReceivedCoins, 4750);
      expect(state.topSupporters.isNotEmpty, isTrue);
      expect(state.transactions.isNotEmpty, isTrue);
    });

    test('sendGift deducts coins, credits creator, and auto-posts comment announcement', () async {
      final notifier = container.read(creatorWalletProvider.notifier);
      final initialCoins = container.read(creatorWalletProvider).userCoinsBalance;
      final initialEarnedZar = container.read(creatorWalletProvider).creatorEarnedZar;

      final gift = kCulturalGifts.firstWhere((g) => g.id == 'log_drum_trophy'); // 50 coins, R15

      final success = await notifier.sendGift(
        clipId: 'clip_test_123',
        recipientCreatorId: 'creator_makhadzi',
        senderUsername: 'test_user',
        gift: gift,
        message: 'Masterclass production!',
      );

      expect(success, isTrue);

      final updatedState = container.read(creatorWalletProvider);
      expect(updatedState.userCoinsBalance, initialCoins - gift.coinPrice);
      expect(updatedState.creatorEarnedZar, initialEarnedZar + gift.zarPrice);
      expect(updatedState.transactions.first.gift.id, gift.id);

      // Verify comment posted to reelsCommentsProvider
      final commentsState = container.read(reelsCommentsProvider);
      final clipComments = commentsState.commentsByClipId['clip_test_123'];
      expect(clipComments, isNotNull);
      expect(clipComments!.first.text, contains('Sent a Log Drum Trophy (Tshikona)!'));
      expect(clipComments.first.text, contains('Masterclass production!'));
      expect(clipComments.first.giftEmoji, gift.emoji);
      expect(clipComments.first.giftName, gift.name);
    });

    test('sendGift fails when user has insufficient coins', () async {
      final notifier = container.read(creatorWalletProvider.notifier);
      final crown = kCulturalGifts.firstWhere((g) => g.id == 'royal_venda_crown'); // 200 coins

      // Send 1 crown (250 - 200 = 50 left)
      final first = await notifier.sendGift(
        clipId: 'clip_1',
        recipientCreatorId: 'creator_1',
        senderUsername: 'test_user',
        gift: crown,
      );
      expect(first, isTrue);

      // Attempt to send another crown (requires 200, only 50 left)
      final second = await notifier.sendGift(
        clipId: 'clip_1',
        recipientCreatorId: 'creator_1',
        senderUsername: 'test_user',
        gift: crown,
      );
      expect(second, isFalse);
    });

    test('topUpCoins adds to user coin balance', () {
      final notifier = container.read(creatorWalletProvider.notifier);
      final initial = container.read(creatorWalletProvider).userCoinsBalance;

      notifier.topUpCoins(100);
      expect(container.read(creatorWalletProvider).userCoinsBalance, initial + 100);
    });

    test('requestPayout validates amounts and deducts earned ZAR', () async {
      final notifier = container.read(creatorWalletProvider.notifier);
      final initialZar = container.read(creatorWalletProvider).creatorEarnedZar;

      // Payout above balance should fail
      final tooMuch = await notifier.requestPayout(
        amountZar: initialZar + 500,
        payoutMethod: 'Ozow Instant EFT',
      );
      expect(tooMuch, isFalse);

      // Payout below minimum (R50) should fail
      final tooSmall = await notifier.requestPayout(
        amountZar: 20,
        payoutMethod: 'Ozow Instant EFT',
      );
      expect(tooSmall, isFalse);

      // Valid payout should succeed
      final valid = await notifier.requestPayout(
        amountZar: 500,
        payoutMethod: 'Ozow Instant EFT',
      );
      expect(valid, isTrue);

      final state = container.read(creatorWalletProvider);
      expect(state.creatorEarnedZar, initialZar - 500);
      expect(state.payoutStatusMessage, contains('R500.00'));
      expect(state.payoutStatusMessage, contains('Ozow Instant EFT'));
    });
  });
}

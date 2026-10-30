import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/social/data/repositories/http_social_repository.dart';

void main() {
  group('HttpSocialRepository (Offline / Test Resilient)', () {
    late HttpSocialRepository repository;

    setUp(() {
      repository = HttpSocialRepository(
        baseUrl: 'http://127.0.0.1:9999/api', // Unbound port ensures fallback coverage
      );
    });

    test('getFeed gracefully falls back offline', () async {
      final feed = await repository.getFeed();
      expect(feed, isNotNull);
    });

    test('toggleLikeClip toggles state in fallback store', () async {
      final res1 = await repository.toggleLikeClip('clip_test_1');
      expect(res1.liked, isTrue);
      expect(res1.likeCount, 1);

      final res2 = await repository.toggleLikeClip('clip_test_1');
      expect(res2.liked, isFalse);
      expect(res2.likeCount, 0);
    });

    test('toggleFollowCreator toggles state in fallback store', () async {
      final res1 = await repository.toggleFollowCreator('creator_test_1');
      expect(res1.following, isTrue);

      final res2 = await repository.toggleFollowCreator('creator_test_1');
      expect(res2.following, isFalse);
    });

    test('comments lifecycle (add, get, like) functions in fallback store', () async {
      final initial = await repository.getComments('clip_test_2');
      expect(initial.isEmpty, isTrue);

      final created = await repository.addComment(
        clipId: 'clip_test_2',
        text: 'That bass drop is massive!',
        username: 'thabo_groove',
        displayName: 'Thabo Groove',
        userReelLoves: 4,
      );
      expect(created.id, isNotEmpty);
      expect(created.text, 'That bass drop is massive!');
      expect(created.userReelLoves, 4);

      final comments = await repository.getComments('clip_test_2');
      expect(comments.length, 1);
      expect(comments.first.id, created.id);

      final likeRes = await repository.toggleLikeComment(created.id);
      expect(likeRes.liked, isTrue);
      expect(likeRes.likeCount, 1);
    });

    test('sendTip records transaction and auto-posts celebration comment in fallback store', () async {
      final tipRes = await repository.sendTip(
        clipId: 'clip_test_3',
        giftId: 'log_drum_trophy',
        senderUsername: 'ndugelo_musician',
        message: 'Masterclass production!',
      );

      expect(tipRes.transaction.id, isNotEmpty);
      expect(tipRes.transaction.gift.id, 'log_drum_trophy');
      expect(tipRes.comment.text, contains('Log Drum Trophy'));
      expect(tipRes.comment.text, contains('Masterclass production!'));
      expect(tipRes.newBalanceZar, greaterThanOrEqualTo(1400.0));
    });

    test('getCreatorWallet and requestPayout function in fallback store', () async {
      final wallet = await repository.getCreatorWallet('creator_makhadzi');
      expect(wallet.creatorId, 'creator_makhadzi');
      expect(wallet.balanceZar, 1420.0);
      expect(wallet.totalCoinsReceived, 4750);
      expect(wallet.topSupporters.isNotEmpty, isTrue);

      final receipt = await repository.requestPayout(
        creatorId: 'creator_makhadzi',
        amountZar: 200.0,
        accountDetails: 'EFT to Standard Bank',
      );
      expect(receipt.success, isTrue);
      expect(receipt.remainingBalanceZar, 1220.0);
    });

    test('publishClip returns share descriptor with remix attribution support', () async {
      final result = await repository.publishClip({
        'trackId': 'track_remix_101',
        'title': 'Venda Nights (Remix)',
        'remixedFromClipId': 'clip_parent_999',
        'remixAttribution': 'Remixed from @makhadzi',
      });

      expect(result.clipId, isNotEmpty);
      expect(result.shareUrl, contains('vhunambi.com'));
      expect(result.publishedAt, isNotNull);
    });
  });
}


import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/social/presentation/providers/reels_comments_provider.dart';

void main() {
  group('ReelsCommentsNotifier', () {
    test('seeds initial comments for default clips', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final comments = container
          .read(reelsCommentsProvider.notifier)
          .commentsForClip('clip_seed_01');

      expect(comments, isNotEmpty);
      expect(comments.any((c) => c.username == 'makhadzi' && c.isCreator), isTrue);
      expect(comments.any((c) => c.userReelLoves > 0), isTrue);
    });

    test('addComment optimistically inserts new comment at top', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(reelsCommentsProvider.notifier);
      notifier.addComment(
        clipId: 'test_clip_01',
        text: 'This bassline is wild! 🎹',
        userReelLoves: 5,
        username: 'test_user',
        displayName: 'Test User',
      );

      final comments = notifier.commentsForClip('test_clip_01');
      expect(comments.length, 1);
      expect(comments.first.text, 'This bassline is wild! 🎹');
      expect(comments.first.userReelLoves, 5);
      expect(comments.first.username, 'test_user');
    });

    test('toggleCommentLike toggles like state and adjusts count', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(reelsCommentsProvider.notifier);
      final initial = notifier.commentsForClip('clip_seed_01').first;
      final initialLikes = initial.likeCount;
      final initiallyLiked = initial.isLikedByMe;

      notifier.toggleCommentLike(
        clipId: 'clip_seed_01',
        commentId: initial.id,
      );

      final updated = notifier.commentsForClip('clip_seed_01').first;
      expect(updated.isLikedByMe, !initiallyLiked);
      expect(
        updated.likeCount,
        initialLikes + (initiallyLiked ? -1 : 1),
      );
    });
  });
}

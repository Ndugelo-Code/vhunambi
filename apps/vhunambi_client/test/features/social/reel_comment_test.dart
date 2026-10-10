import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/social/domain/models/reel_comment.dart';

void main() {
  group('ReelComment domain model', () {
    test('constructs with documented defaults', () {
      final now = DateTime.now();
      final comment = ReelComment(
        id: 'c_1',
        clipId: 'clip_101',
        userId: 'u_1',
        username: 'thabo_beats',
        displayName: 'Thabo Beats',
        text: 'This log drum hits hard! 🎹',
        createdAt: now,
      );

      expect(comment.id, 'c_1');
      expect(comment.clipId, 'clip_101');
      expect(comment.isCreator, false);
      expect(comment.likeCount, 0);
      expect(comment.isLikedByMe, false);
      expect(comment.userReelLoves, 0);
      expect(comment.timeAgo, 'just now');
    });

    test('supports honest community badge userReelLoves', () {
      final comment = ReelComment(
        id: 'c_2',
        clipId: 'clip_101',
        userId: 'u_2',
        username: 'lerato_piano',
        displayName: 'Lerato Piano',
        text: 'Makhado sunrise vibe 🌅',
        userReelLoves: 5,
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );

      expect(comment.userReelLoves, 5);
      expect(comment.timeAgo, '5m ago');
    });

    test('copyWith updates likes and honest reaction counters', () {
      final comment = ReelComment(
        id: 'c_3',
        clipId: 'clip_101',
        userId: 'u_3',
        username: 'kgothatso',
        displayName: 'Kgothatso',
        text: 'Fire! 🔥',
        createdAt: DateTime.now(),
      );

      final liked = comment.copyWith(
        isLikedByMe: true,
        likeCount: 1,
        userReelLoves: 10,
      );

      expect(liked.isLikedByMe, true);
      expect(liked.likeCount, 1);
      expect(liked.userReelLoves, 10);
      expect(liked.text, 'Fire! 🔥');
    });

    test('toJson -> fromJson round-trips losslessly', () {
      final original = ReelComment(
        id: 'c_4',
        clipId: 'clip_101',
        userId: 'u_4',
        username: 'fifi_live',
        displayName: 'Fifi',
        isCreator: true,
        text: 'Proudly South African 🇿🇦',
        likeCount: 42,
        isLikedByMe: true,
        userReelLoves: 8,
        createdAt: DateTime.utc(2026, 10, 11, 8, 30),
      );

      final json = original.toJson();
      final restored = ReelComment.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.clipId, original.clipId);
      expect(restored.username, original.username);
      expect(restored.isCreator, true);
      expect(restored.text, original.text);
      expect(restored.likeCount, 42);
      expect(restored.isLikedByMe, true);
      expect(restored.userReelLoves, 8);
      expect(restored.createdAt, original.createdAt);
    });
  });
}

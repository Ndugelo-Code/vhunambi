import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/social/presentation/providers/trending_reels_provider.dart';

void main() {
  group('trendingReelsProvider', () {
    test('returns seeded clips sorted by virality score', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final clips = container.read(trendingReelsProvider);
      expect(clips, isNotEmpty);

      // Verify descending virality score ordering
      for (var i = 0; i < clips.length - 1; i++) {
        final scoreA = clips[i].playCount + (clips[i].likeCount * 3) + (clips[i].commentCount * 5);
        final scoreB = clips[i + 1].playCount + (clips[i + 1].likeCount * 3) + (clips[i + 1].commentCount * 5);
        expect(scoreA >= scoreB, isTrue);
      }
    });

    test('filters clips dynamically when genre changes', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Switch to Amapiano
      container.read(trendingReelsGenreProvider.notifier).state = '#Amapiano';
      final amapianoClips = container.read(trendingReelsProvider);
      expect(amapianoClips, isNotEmpty);
      expect(amapianoClips.every((c) => c.genre.toLowerCase() == 'amapiano'), isTrue);

      // Switch to Gqom
      container.read(trendingReelsGenreProvider.notifier).state = '#Gqom';
      final gqomClips = container.read(trendingReelsProvider);
      expect(gqomClips.every((c) => c.genre.toLowerCase() == 'gqom'), isTrue);
    });
  });
}

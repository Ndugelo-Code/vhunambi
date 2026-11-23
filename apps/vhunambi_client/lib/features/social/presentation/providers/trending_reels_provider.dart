import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/auth_providers.dart';
import '../../../../core/utils/creator_id_utils.dart';
import '../../domain/models/published_clip.dart';
import 'social_feed_provider.dart';

/// Available genre filter pills for the Trending Kinetic Reels shelf (REQ-TRD-04).
const List<String> kTrendingGenres = [
  'All',
  '#Amapiano',
  '#Gqom',
  '#Maskandi',
  '#AfroHouse',
];

/// Active genre filter for the global Trending Reels discovery shelves.
final trendingReelsGenreProvider = StateProvider<String>((ref) => 'All');

/// Provides clips pinned with newly published / fresh clips at index 0 followed
/// by virality momentum order (`VA-01` / REQ-TRD-01 / REQ-TRD-04).
final trendingReelsProvider = Provider<List<PublishedClip>>((ref) {
  final feedState = ref.watch(socialFeedProvider);
  final activeGenre = ref.watch(trendingReelsGenreProvider);
  final activeCreatorId = canonicalizeCreatorId(
    ref.watch(currentCreatorIdProvider),
  );

  var list = List<PublishedClip>.from(feedState.clips);

  if (activeGenre != 'All') {
    final cleanGenre = activeGenre.replaceAll('#', '').trim().toLowerCase();
    list = list
        .where((c) => c.genre.trim().toLowerCase() == cleanGenre)
        .toList();
  }

  final now = DateTime.now();
  bool isPinnedFresh(PublishedClip c) {
    final isNonSeed = !SocialFeedNotifier.isSeedClipId(c.id);
    if (!isNonSeed) return false;
    final isOwned =
        canonicalizeCreatorId(c.creatorId) == activeCreatorId ||
        c.creatorId == 'creator_me';
    final isRecent = now.difference(c.publishedAt).inHours.abs() <= 24;
    return isOwned || isRecent;
  }

  final pinned = list.where(isPinnedFresh).toList()
    ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
  final rest = list.where((c) => !isPinnedFresh(c)).toList()
    ..sort((a, b) {
      final scoreA = a.playCount + (a.likeCount * 3) + (a.commentCount * 5);
      final scoreB = b.playCount + (b.likeCount * 3) + (b.commentCount * 5);
      return scoreB.compareTo(scoreA);
    });

  return <PublishedClip>[...pinned, ...rest];
});

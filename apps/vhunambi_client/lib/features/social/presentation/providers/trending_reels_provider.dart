import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// Provides clips sorted by viral momentum and filtered by the selected genre (REQ-TRD-01 / REQ-TRD-04).
final trendingReelsProvider = Provider<List<PublishedClip>>((ref) {
  final feedState = ref.watch(socialFeedProvider);
  final activeGenre = ref.watch(trendingReelsGenreProvider);

  var list = List<PublishedClip>.from(feedState.clips);

  if (activeGenre != 'All') {
    final cleanGenre = activeGenre.replaceAll('#', '').trim().toLowerCase();
    list = list
        .where((c) => c.genre.trim().toLowerCase() == cleanGenre)
        .toList();
  }

  // Sort by virality momentum: plays + likes * 3 + comments * 5
  list.sort((a, b) {
    final scoreA = a.playCount + (a.likeCount * 3) + (a.commentCount * 5);
    final scoreB = b.playCount + (b.likeCount * 3) + (b.commentCount * 5);
    return scoreB.compareTo(scoreA);
  });

  return list;
});

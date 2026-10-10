import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/track.dart';
import '../../../library/presentation/providers/library_providers.dart';
import '../../../onboarding/presentation/providers/onboarding_providers.dart';
import '../../domain/services/recommendation_engine.dart';
import 'explore_providers.dart';

/// Singleton recommendation engine instance.
final recommendationEngineProvider = Provider<RecommendationEngine>((ref) {
  return const RecommendationEngine();
});

/// Computes personalized, dynamic "For You" recommended tracks.
final recommendationProvider = Provider<List<Track>>((ref) {
  final engine = ref.watch(recommendationEngineProvider);
  final allTracks = ref.watch(exploreTracksProvider);
  final recentlyPlayedIds = ref.watch(recentlyPlayedIdsProvider);
  final vaultTracks = ref.watch(libraryTracksProvider);
  final onboarding = ref.watch(onboardingStateProvider);

  return engine.rankTracks(
    tracks: allTracks,
    recentlyPlayedIds: recentlyPlayedIds,
    vaultTracks: vaultTracks,
    preferredGenres: onboarding.selectedGenres,
    preferredLanguages: onboarding.selectedLanguages,
  );
});

/// Recommended tracks filtered by active explore search query and genre filter.
final filteredRecommendedTracksProvider = Provider<List<Track>>((ref) {
  final recommended = ref.watch(recommendationProvider);
  final query = ref.watch(exploreSearchQueryProvider);
  final genre = ref.watch(exploreGenreFilterProvider);

  return recommended.where((track) {
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      final matchTitle = track.title.toLowerCase().contains(q);
      final matchCreator = track.creatorName.toLowerCase().contains(q);
      final matchGenre = track.genre.toLowerCase().contains(q);
      if (!matchTitle && !matchCreator && !matchGenre) return false;
    }
    if (genre != 'All' && track.genre != genre) {
      return false;
    }
    return true;
  }).toList();
});

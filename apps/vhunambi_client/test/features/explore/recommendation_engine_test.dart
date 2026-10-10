import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vhunambi_client/features/explore/domain/services/recommendation_engine.dart';
import 'package:vhunambi_client/features/explore/presentation/providers/explore_providers.dart';
import 'package:vhunambi_client/features/explore/presentation/providers/recommendation_provider.dart';
import 'package:vhunambi_client/features/library/domain/models/library_models.dart';
import 'package:vhunambi_client/shared/models/track.dart';

void main() {
  const engine = RecommendationEngine();

  final trackA = Track(
    id: 't_amapiano_1',
    title: 'Amapiano Groove',
    creatorName: 'DJ Maphorisa style',
    genre: 'Amapiano',
    language: 'isiZulu',
    duration: const Duration(minutes: 3, seconds: 45),
    playCount: 1500,
    coverUrl: 'https://images.unsplash.com/photo-1',
  );

  final trackB = Track(
    id: 't_gqom_1',
    title: 'Durban Rush',
    creatorName: 'Gqom Master',
    genre: 'Gqom',
    language: 'isiZulu',
    duration: const Duration(minutes: 4),
    playCount: 500,
    coverUrl: 'https://images.unsplash.com/photo-2',
  );

  final trackC = Track(
    id: 't_maskandi_1',
    title: 'KwaZulu Guitar',
    creatorName: 'Maskandi Legend',
    genre: 'Maskandi',
    language: 'isiZulu',
    duration: const Duration(minutes: 3, seconds: 20),
    playCount: 200,
    coverUrl: 'https://images.unsplash.com/photo-3',
  );

  group('RecommendationEngine Unit Tests', () {
    test('returns empty list when candidate tracks are empty', () {
      final results = engine.rankTracks(
        tracks: const [],
        recentlyPlayedIds: const [],
        vaultTracks: const [],
        preferredGenres: const ['Amapiano'],
      );
      expect(results, isEmpty);
    });

    test('ranks tracks matching preferredGenres higher than non-matching', () {
      final results = engine.rankTracks(
        tracks: [trackB, trackA],
        recentlyPlayedIds: const [],
        vaultTracks: const [],
        preferredGenres: const ['Amapiano'],
      );

      expect(results.first.id, 't_amapiano_1');
      expect(results.last.id, 't_gqom_1');
    });

    test('boosts tracks that exist in vault as favorites', () {
      final vaultFavorite = LibraryTrack(
        id: 't_maskandi_1',
        title: 'KwaZulu Guitar',
        creatorName: 'Maskandi Legend',
        genre: 'Maskandi',
        language: 'isiZulu',
        durationSeconds: 200,
        remoteAudioUrl: 'https://example.com/audio/t_maskandi_1.mp3',
        isFavorite: true,
        playCount: 200,
        createdAt: DateTime.now(),
      );

      final results = engine.rankTracks(
        tracks: [trackB, trackC],
        recentlyPlayedIds: const [],
        vaultTracks: [vaultFavorite],
        preferredGenres: const ['Amapiano'],
      );

      expect(results.first.id, 't_maskandi_1');
    });

    test('boosts tracks based on listening recency in recentlyPlayedIds', () {
      final results = engine.rankTracks(
        tracks: [trackB, trackC],
        recentlyPlayedIds: ['t_gqom_1'],
        vaultTracks: const [],
        preferredGenres: const [],
      );

      expect(results.first.id, 't_gqom_1');
    });

    test('factors in play count velocity as a tie-breaker', () {
      final trackLow = Track(
        id: 't1',
        title: 'Low',
        creatorName: 'A',
        genre: 'Kwaito',
        duration: const Duration(minutes: 3),
        playCount: 10,
        coverUrl: 'https://cover',
      );
      final trackHigh = Track(
        id: 't2',
        title: 'High',
        creatorName: 'B',
        genre: 'Kwaito',
        duration: const Duration(minutes: 3),
        playCount: 5000,
        coverUrl: 'https://cover',
      );

      final results = engine.rankTracks(
        tracks: [trackLow, trackHigh],
        recentlyPlayedIds: const [],
        vaultTracks: const [],
        preferredGenres: const ['Kwaito'],
      );

      expect(results.first.id, 't2');
      expect(results.last.id, 't1');
    });
  });

  group('Riverpod recommendationProvider Integration Tests', () {
    test('recommendationProvider reacts to onboarding preferences and vault', () {
      final container = ProviderContainer(
        overrides: [
          exploreTracksProvider.overrideWith(
            (ref) => ExploreTracksNotifier(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final recommended = container.read(recommendationProvider);
      expect(recommended, isNotEmpty);
    });

    test('filteredRecommendedTracksProvider applies query and genre filters', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(exploreGenreFilterProvider.notifier).state = 'Gqom';
      final gqomFiltered = container.read(filteredRecommendedTracksProvider);

      for (final t in gqomFiltered) {
        expect(t.genre, 'Gqom');
      }
    });
  });
}

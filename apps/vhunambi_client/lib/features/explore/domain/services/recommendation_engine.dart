import 'dart:math' as math;
import '../../../../shared/models/track.dart';
import '../../../library/domain/models/library_models.dart';

/// Scoring breakdown for a track recommendation candidate.
class ScoredTrack {
  final Track track;
  final double score;
  final double genreScore;
  final double favoriteScore;
  final double playCountScore;
  final double recencyScore;
  final double trendingScore;

  const ScoredTrack({
    required this.track,
    required this.score,
    this.genreScore = 0.0,
    this.favoriteScore = 0.0,
    this.playCountScore = 0.0,
    this.recencyScore = 0.0,
    this.trendingScore = 0.0,
  });
}

/// Pure algorithmic scoring engine for personalized "For You" music discovery.
class RecommendationEngine {
  const RecommendationEngine();

  /// Scores and ranks candidate [tracks] against user preferences, vault favorites,
  /// listening recency, and catalog play velocity.
  List<Track> rankTracks({
    required List<Track> tracks,
    required List<String> recentlyPlayedIds,
    required List<LibraryTrack> vaultTracks,
    required List<String> preferredGenres,
    List<String> preferredLanguages = const [],
  }) {
    if (tracks.isEmpty) return const [];

    final scored = tracks.map((track) {
      double genreScore = 0.0;
      double favoriteScore = 0.0;
      double playCountScore = 0.0;
      double recencyScore = 0.0;
      double trendingScore = 0.0;

      // 1. Genre Affinity (Match against onboarding preferences & vault favorite genres)
      if (preferredGenres.contains(track.genre)) {
        genreScore += 40.0;
      }

      // Check genres of favorited vault tracks
      final favoriteVaultTracks = vaultTracks.where((t) => t.isFavorite).toList();
      final hasGenreInFavorites = favoriteVaultTracks.any((t) => t.genre == track.genre);
      if (hasGenreInFavorites) {
        genreScore += 20.0;
      }

      // 2. Direct Favorite Affinity
      final isDirectFavorite = favoriteVaultTracks.any((t) => t.id == track.id);
      if (isDirectFavorite) {
        favoriteScore += 35.0;
      }

      // 3. Play Count Velocity
      if (track.playCount > 0) {
        playCountScore += math.min(25.0, (track.playCount / 1000.0) * 2.5);
      }

      // 4. Listening Recency (from recentlyPlayedIds)
      final recentIndex = recentlyPlayedIds.indexOf(track.id);
      if (recentIndex != -1) {
        // Boost most recent tracks, decay linearly down to +5
        recencyScore += math.max(5.0, 30.0 - (recentIndex * 2.5));
      }

      // 5. Language Affinity
      if (preferredLanguages.contains(track.language)) {
        genreScore += 10.0;
      }

      // 6. Trending Rank
      if (track.trendingRank != null && track.trendingRank! > 0) {
        trendingScore += math.max(0.0, 20.0 - (track.trendingRank! * 2.0));
      }

      final totalScore = genreScore + favoriteScore + playCountScore + recencyScore + trendingScore;

      return ScoredTrack(
        track: track,
        score: totalScore,
        genreScore: genreScore,
        favoriteScore: favoriteScore,
        playCountScore: playCountScore,
        recencyScore: recencyScore,
        trendingScore: trendingScore,
      );
    }).toList();

    // Sort highest score first; tiebreak by playCount descending
    scored.sort((a, b) {
      final cmp = b.score.compareTo(a.score);
      if (cmp != 0) return cmp;
      return b.track.playCount.compareTo(a.track.playCount);
    });

    return scored.map((s) => s.track).toList();
  }
}

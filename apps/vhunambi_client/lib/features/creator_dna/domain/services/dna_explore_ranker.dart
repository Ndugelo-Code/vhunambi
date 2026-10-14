import '../entities/creator_dna_profile.dart';

/// Pure Dart, synchronous client-side DNA affinity ranker.
/// Performs zero network calls and zero asynchronous operations.
class DnaExploreRanker {
  const DnaExploreRanker._();

  /// Returns [tracks] sorted by DNA affinity score in descending order.
  /// Tracks are expected to carry 'genre' and optionally 'language' metadata fields.
  static List<Map<String, dynamic>> rank(
    List<Map<String, dynamic>> tracks,
    CreatorDnaProfile dna,
  ) {
    if (!dna.onboardingCompleted) return tracks;
    final topGenres = dna.topGenres(2).toSet();
    final primaryLang = dna.primaryLanguage;

    double affinityScore(Map<String, dynamic> track) {
      double score = 0.0;
      final genre = track['genre'] as String?;
      final language = track['language'] as String?;
      if (genre != null && topGenres.contains(genre)) score += 0.30;
      if (language != null && language == primaryLang) score += 0.15;
      return score;
    }

    return [...tracks]..sort(
        (a, b) => affinityScore(b).compareTo(affinityScore(a)),
      );
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/creator_dna/domain/entities/creator_dna_profile.dart';
import 'package:vhunambi_client/features/creator_dna/domain/services/dna_explore_ranker.dart';

void main() {
  group('DnaExploreRanker', () {
    final now = DateTime.now();

    final testTracks = [
      {'id': '1', 'title': 'Track Highlife', 'genre': 'Highlife', 'language': 'Yoruba'},
      {'id': '2', 'title': 'Track Amapiano En', 'genre': 'Amapiano', 'language': 'English'},
      {'id': '3', 'title': 'Track Amapiano Zu', 'genre': 'Amapiano', 'language': 'isiZulu'},
      {'id': '4', 'title': 'Track Bongo', 'genre': 'Bongo Flava', 'language': 'Swahili'},
    ];

    test('returns unmodified track list when onboarding is not completed', () {
      final unseededDna = CreatorDnaProfile.initial();
      final ranked = DnaExploreRanker.rank(testTracks, unseededDna);

      expect(ranked.map((t) => t['id']).toList(), equals(['1', '2', '3', '4']));
    });

    test('boosts top genre and primary language matches to the top', () {
      final dna = CreatorDnaProfile(
        userId: 'u1',
        createdAt: now,
        lastUpdatedAt: now,
        onboardingCompleted: true,
        primaryLanguage: 'isiZulu',
        genreWeights: {
          'Amapiano': 2.0,
          'Afrobeats': 1.0,
        },
      );

      final ranked = DnaExploreRanker.rank(testTracks, dna);

      // Track 3 is Amapiano (+0.30) and isiZulu (+0.15) = 0.45
      // Track 2 is Amapiano (+0.30) = 0.30
      // Tracks 1 and 4 have 0.0 affinity
      expect(ranked.first['id'], equals('3'));
      expect(ranked[1]['id'], equals('2'));
    });
  });
}

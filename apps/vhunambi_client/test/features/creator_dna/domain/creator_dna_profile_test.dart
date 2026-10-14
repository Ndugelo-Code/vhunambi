import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/creator_dna/domain/entities/creator_dna_profile.dart';

void main() {
  group('CreatorDnaProfile Domain Entity', () {
    test('initial profile has uninitialized state and 0 strength', () {
      final profile = CreatorDnaProfile.initial();

      expect(profile.userId, isEmpty);
      expect(profile.lifecycleState, DnaLifecycleState.uninitialized);
      expect(profile.totalBehaviorEvents, 0);
      expect(profile.strengthPercent, 0);
      expect(profile.onboardingCompleted, isFalse);
    });

    test('strengthPercent scales across event milestones and onboarding', () {
      final now = DateTime.now();

      // Seeded profile with onboarding completed (completeness = 1.0 -> 15%)
      final seeded = CreatorDnaProfile(
        userId: 'user_1',
        createdAt: now,
        lastUpdatedAt: now,
        onboardingCompleted: true,
        onboardingCompleteness: 1.0,
        genreWeights: {'Amapiano': 1.0, 'Afrobeats': 1.0},
        languageWeights: {'isiZulu': 1.5},
        totalBehaviorEvents: 0,
      );
      // 0 events + diversity score (3 weights > 0.5 -> 3/30 * 0.25 = 0.025) + onboarding (0.15) = ~18%
      expect(seeded.strengthPercent, greaterThanOrEqualTo(15));
      expect(seeded.strengthPercent, lessThan(30));

      // 50 events
      final learning = seeded.copyWith(totalBehaviorEvents: 50);
      expect(learning.strengthPercent, greaterThan(seeded.strengthPercent));

      // 200+ events caps event contribution at 60%
      final matured = seeded.copyWith(totalBehaviorEvents: 250);
      expect(matured.strengthPercent, greaterThanOrEqualTo(75));
    });

    test('topGenres returns highest-weighted genres in descending order', () {
      final now = DateTime.now();
      final profile = CreatorDnaProfile(
        userId: 'user_1',
        createdAt: now,
        lastUpdatedAt: now,
        genreWeights: {
          'Gqom': 0.8,
          'Amapiano': 2.5,
          'Afrobeats': 1.9,
          'Highlife': 0.3,
        },
      );

      final top2 = profile.topGenres(2);
      expect(top2, equals(['Amapiano', 'Afrobeats']));

      final top1 = profile.topGenres(1);
      expect(top1, equals(['Amapiano']));

      final top5 = profile.topGenres(5);
      expect(top5, equals(['Amapiano', 'Afrobeats', 'Gqom', 'Highlife']));
    });

    test('toJson and fromJson maintain complete fidelity', () {
      final now = DateTime(2026, 10, 14, 12, 0, 0);
      final original = CreatorDnaProfile(
        userId: 'user_42',
        creativeRole: CreativeRole.producer,
        experienceLevel: ExperienceLevel.pro,
        genreWeights: {'Amapiano': 3.2, 'Afro House': 2.1},
        languageWeights: {'Tshivenḓa': 1.5, 'English': 1.0},
        primaryLanguage: 'Tshivenḓa',
        moodWeights: {'Energetic': 1.8},
        tempoPreference: 'fast',
        vocalEnergyPreference: 'intense',
        lifecycleState: DnaLifecycleState.calibrated,
        totalBehaviorEvents: 85,
        createdAt: now,
        lastUpdatedAt: now,
        onboardingCompleted: true,
        onboardingCompleteness: 1.0,
        dnaInsightCardDismissed: true,
      );

      final json = original.toJson();
      final restored = CreatorDnaProfile.fromJson(json);

      expect(restored.userId, original.userId);
      expect(restored.creativeRole, original.creativeRole);
      expect(restored.experienceLevel, original.experienceLevel);
      expect(restored.genreWeights, original.genreWeights);
      expect(restored.languageWeights, original.languageWeights);
      expect(restored.primaryLanguage, original.primaryLanguage);
      expect(restored.moodWeights, original.moodWeights);
      expect(restored.tempoPreference, original.tempoPreference);
      expect(restored.vocalEnergyPreference, original.vocalEnergyPreference);
      expect(restored.lifecycleState, original.lifecycleState);
      expect(restored.totalBehaviorEvents, original.totalBehaviorEvents);
      expect(restored.onboardingCompleted, original.onboardingCompleted);
      expect(restored.onboardingCompleteness, original.onboardingCompleteness);
      expect(restored.dnaInsightCardDismissed, original.dnaInsightCardDismissed);
      expect(restored, equals(original));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/creator_dna/domain/entities/creator_dna_profile.dart';
import 'package:vhunambi_client/features/studio/domain/services/studio_prompt_intelligence.dart';

void main() {
  group('StudioPromptIntelligence', () {
    test('extracts genre and language keywords accurately', () {
      final result = StudioPromptIntelligence.enhance(
        'A soulful maskandi song in isiZulu with acoustic guitar',
      );

      expect(result.detectedGenre, 'Maskandi');
      expect(result.detectedLanguage, 'isiZulu');
      expect(result.suggestedOverrides['genre'], 'Maskandi');
      expect(result.suggestedOverrides['language'], 'isiZulu');
      expect(result.hasOverrides, isTrue);
    });

    test('detects mood keywords like pain or spiritual', () {
      final darkResult = StudioPromptIntelligence.enhance(
        'A dark and sad story about heartbreak and pain',
      );
      expect(darkResult.detectedMood, 'Melancholic');

      final spiritualResult = StudioPromptIntelligence.enhance(
        'A spiritual prayer song for the ancestors',
      );
      expect(spiritualResult.detectedMood, 'Peaceful');
    });

    test('detects vocal mode and gender cues', () {
      final result = StudioPromptIntelligence.enhance(
        'Female choir singing soft harmonies for gospel track',
      );

      expect(result.suggestedOverrides['vocalGender'], 'female');
      expect(result.suggestedOverrides['vocalMode'], 'choir');
      expect(result.detectedGenre, 'Gospel');
    });

    test('enriches prompt with African acoustic texture context', () {
      final result = StudioPromptIntelligence.enhance(
        'High energy amapiano club banger with log drums',
      );

      expect(result.enhancedPrompt.contains('Amapiano'), isTrue);
      expect(result.detectedGenre, 'Amapiano');
      expect(result.enhancedPrompt.length, greaterThanOrEqualTo(result.rawPrompt.length));
    });

    test('incorporates Creator DNA affinities when prompt lacks explicit signals', () {
      final dna = CreatorDnaProfile.initial().copyWith(
        onboardingCompleted: true,
        genreWeights: {'Maskandi': 0.85, 'Amapiano': 0.1},
      );

      final result = StudioPromptIntelligence.enhance(
        'Guitar melody at dawn',
        dna: dna,
      );

      expect(result.detectedGenre, 'Maskandi');
      expect(result.suggestedOverrides['genre'], 'Maskandi');
    });
  });
}

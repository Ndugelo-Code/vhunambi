import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/studio/domain/models/option_preview_descriptor.dart';

void main() {
  group('OptionPreviewDescriptor', () {
    test('kStudioOptionPreviews contains comprehensive previews for all core brackets', () {
      expect(kStudioOptionPreviews.containsKey('tempo_slow'), isTrue);
      expect(kStudioOptionPreviews.containsKey('tempo_medium'), isTrue);
      expect(kStudioOptionPreviews.containsKey('tempo_fast'), isTrue);
      expect(kStudioOptionPreviews.containsKey('tempo_veryFast'), isTrue);

      expect(kStudioOptionPreviews.containsKey('vocalMode_auto'), isTrue);
      expect(kStudioOptionPreviews.containsKey('vocalMode_melodic'), isTrue);
      expect(kStudioOptionPreviews.containsKey('vocalMode_rap'), isTrue);
      expect(kStudioOptionPreviews.containsKey('vocalMode_spokenWord'), isTrue);
      expect(kStudioOptionPreviews.containsKey('vocalMode_choir'), isTrue);

      expect(kStudioOptionPreviews.containsKey('vocalEnergy_soft'), isTrue);
      expect(kStudioOptionPreviews.containsKey('vocalEnergy_mid'), isTrue);
      expect(kStudioOptionPreviews.containsKey('vocalEnergy_intense'), isTrue);
    });

    test('each descriptor contains non-empty emoji, title, description, and bestForGenres', () {
      for (final entry in kStudioOptionPreviews.entries) {
        final d = entry.value;
        expect(d.emoji.isNotEmpty, isTrue, reason: 'Empty emoji in ${entry.key}');
        expect(d.title.isNotEmpty, isTrue, reason: 'Empty title in ${entry.key}');
        expect(d.description.isNotEmpty, isTrue, reason: 'Empty description in ${entry.key}');
        expect(d.bestForGenres.isNotEmpty, isTrue, reason: 'Empty bestForGenres in ${entry.key}');
      }
    });
  });
}

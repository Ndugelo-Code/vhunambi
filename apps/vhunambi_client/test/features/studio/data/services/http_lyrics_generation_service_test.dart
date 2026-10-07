import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/studio/data/services/fake_lyrics_generation_service.dart';
import 'package:vhunambi_client/features/studio/data/services/http_lyrics_generation_service.dart';

void main() {
  group('HttpLyricsGenerationService', () {
    test('falls back gracefully to FakeLyricsGenerationService on network failure',
        () async {
      // Dio pointing to an unroutable port
      final service = HttpLyricsGenerationService(
        baseUrl: 'http://127.0.0.1:54321/v1',
        fallback: FakeLyricsGenerationService(),
      );

      final draft = await service.generateLyrics(
        prompt: 'Morning in Venda',
        genre: 'Amapiano',
        language: 've',
      );

      expect(draft.prompt, equals('Morning in Venda'));
      expect(draft.genre, equals('Amapiano'));
      expect(draft.sections, isNotEmpty);
      expect(draft.sections.first.header, contains('['));
    });

    test('getCulturalIdioms proxies through to dialect phrase banks', () {
      final service = HttpLyricsGenerationService();
      final idioms = service.getCulturalIdioms('ve');

      expect(idioms, isNotEmpty);
      expect(idioms, contains('Ndi khou vha fhululedza'));
    });
  });
}

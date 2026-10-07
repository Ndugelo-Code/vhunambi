import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/studio/data/services/http_generation_submission_service.dart';

void main() {
  group('HttpGenerationSubmissionService', () {
    test('submits generation and gracefully handles network error with fallback ID',
        () async {
      final service = HttpGenerationSubmissionService(
        baseUrl: 'http://127.0.0.1:54321/v1',
      );

      final result = await service.submitGeneration(
        trackTitle: 'Ndi Masiari',
        genre: 'Amapiano',
        language: 've',
        lyrics: '[Intro]\nNdi khou vha fhululedza',
      );

      expect(result['generationId'], isNotNull);
      expect((result['generationId'] as String).startsWith('gen_'), isTrue);
      expect(result['status'], equals('queued'));
    });
  });
}

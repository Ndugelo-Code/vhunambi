import '../../domain/services/i_bantu_translation_service.dart';

/// Offline stand-in for the Bantu lyrics translation endpoint (M10 /
/// REQ-BLS-04).
///
/// Simulates network latency with a 300ms delay and returns a clearly
/// tagged translation so creators (and tests) can distinguish translated
/// output from the original.
class FakeBantuTranslationService implements IBantuTranslationService {
  const FakeBantuTranslationService();

  @override
  Future<String> translate({
    required String text,
    required String fromLanguage,
    required String toLanguage,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return '[Translated to $toLanguage]: $text';
  }
}
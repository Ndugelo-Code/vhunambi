/// Translation contract for the Bantu Lyrics Language Switcher (M10 /
/// REQ-BLS-04).
///
/// Production implementation talks to the Vhunambi API translation endpoint;
/// [FakeBantuTranslationService] covers offline/dev and test runs.
abstract interface class IBantuTranslationService {
  /// Translates [text] from [fromLanguage] into [toLanguage], preserving
  /// phonetic structure where possible.
  Future<String> translate({
    required String text,
    required String fromLanguage,
    required String toLanguage,
  });
}
import '../models/lyrics_review_models.dart';

/// Studio lyrics synthesis contract (REQ-LYR-01 / REQ-LYR-07).
///
/// `FakeLyricsGenerationService` provides deterministic, offline stanzas for
/// tests and previews; the production implementation talks to the Vhunambi
/// LLM synthesis worker.
abstract class ILyricsGenerationService {
  /// Generates a reviewable draft for the supplied studio parameters.
  ///
  /// Implementations SHALL return structurally parsed [LyricsReviewDraft]
  /// sections so the review cockpit can edit them stanza by stanza.
  Future<LyricsReviewDraft> generateLyrics({
    required String prompt,
    required String genre,
    required String language,
  });

  /// Regional idiom / ad-lib chips offered for [language] (REQ-LYR-06).
  List<String> getCulturalIdioms(String language);
}

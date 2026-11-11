import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vhunambi_client/core/auth/auth_providers.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';

import '../../data/services/fake_lyrics_generation_service.dart';
import '../../data/services/http_lyrics_generation_service.dart';
import '../../domain/models/lyrics_review_models.dart';
import '../../domain/services/i_lyrics_generation_service.dart';

/// Injectable lyrics synthesis service (T12.2 / Phase 15).
///
/// Production implementation talks to Vhunambi API with automatic offline
/// fallback to [FakeLyricsGenerationService].
final lyricsGenerationServiceProvider = Provider<ILyricsGenerationService>(
  (ref) => HttpLyricsGenerationService(
    baseUrl: AppConstants.apiBaseUrl,
    authInterceptor: ref.watch(authDioInterceptorProvider),
  ),
);

/// `null` = no lyrics review in flight (the cockpit is closed).
final lyricsReviewProvider =
    StateNotifierProvider<LyricsReviewNotifier, LyricsReviewDraft?>(
  (ref) => LyricsReviewNotifier(ref.watch(lyricsGenerationServiceProvider)),
);

/// Owns the Studio lyrics review draft (T12.3).
///
/// Mirrors every structural edit into [LyricsReviewDraft.rawText] and every
/// raw edit back into the stanza list so the raw markdown editor and the
/// stanza cards stay bi-directionally synchronised (REQ-LYR-05).
class LyricsReviewNotifier extends StateNotifier<LyricsReviewDraft?> {
  LyricsReviewNotifier(this._service) : super(null);

  final ILyricsGenerationService _service;

  /// `true` while [loadGeneratedLyrics] / [regenerate] is awaiting the
  /// synthesis service — the cockpit shows its generating state.
  bool isLoading = false;

  /// Number of drafts produced in this session (drives "Regenerate Lyrics").
  int generationCount = 0;

  /// `true` once the creator has edited the generated draft (REQ-LYR-09).
  bool hasEdits = false;

  String _prompt = '';
  String _genre = '';
  String _language = '';

  String get prompt => _prompt;
  String get genre => _genre;
  String get language => _language;

  /// Latest draft as synthesis-ready raw lyrics (REQ-LYR-08 handoff payload).
  String get lyricsForSynthesis => state?.rebuildRawText() ?? '';

  /// Generates a fresh draft and publishes it for review (REQ-LYR-01).
  Future<void> loadGeneratedLyrics({
    required String prompt,
    required String genre,
    required String language,
  }) async {
    _prompt = prompt;
    _genre = genre;
    _language = language;

    isLoading = true;
    try {
      final draft = await _service.generateLyrics(
        prompt: prompt,
        genre: genre,
        language: language,
      );
      generationCount++;
      hasEdits = false;
      state = draft;
    } finally {
      isLoading = false;
    }
  }

  /// Re-rolls the draft with a fresh stylistic seed, keeping the studio
  /// parameters untouched (REQ-LYR-07).
  Future<void> regenerate() async {
    if (_prompt.isEmpty && _genre.isEmpty && _language.isEmpty) return;
    await loadGeneratedLyrics(
      prompt: _prompt,
      genre: _genre,
      language: _language,
    );
  }

  /// Replaces the lines of a single stanza and rebuilds the raw surface.
  void updateSectionLines(String sectionId, List<String> newLines) {
    final current = state;
    if (current == null) return;

    final updated = <LyricsSection>[
      for (final section in current.sections)
        section.id == sectionId ? section.copyWith(lines: newLines) : section,
    ];

    hasEdits = true;

    final draft = current.copyWith(sections: updated);
    state = draft.copyWith(rawText: draft.rebuildRawText());
  }

  /// Appends a cultural idiom / ad-lib to a stanza (REQ-LYR-06).
  ///
  /// Defaults to the last stanza when [sectionId] is omitted; when the draft
  /// has no stanzas yet a fresh `[Verse]` is opened for the phrase.
  void insertIdiom(String idiom, {String? sectionId}) {
    final current = state;
    final phrase = idiom.trim();
    if (current == null || phrase.isEmpty) return;

    if (current.sections.isEmpty) {
      const section = LyricsSection(
        id: 'section_1',
        type: LyricsSectionType.verse,
        header: '[Verse]',
        lines: <String>[],
      );
      final draft = current.copyWith(
        sections: <LyricsSection>[section.copyWith(lines: <String>[phrase])],
      );
      state = draft.copyWith(rawText: draft.rebuildRawText());
      return;
    }

    final target = sectionId == null
        ? current.sections.last
        : current.sections.firstWhere(
            (section) => section.id == sectionId,
            orElse: () => current.sections.last,
          );

    updateSectionLines(target.id, <String>[...target.lines, phrase]);
  }

  /// Flips between the stanza-card view and the raw markdown editor,
  /// re-synchronising whichever side was edited last (REQ-LYR-05).
  void toggleEditorMode() {
    final current = state;
    if (current == null) return;

    if (current.isRawEditorMode) {
      state = current.copyWith(
        isRawEditorMode: false,
        sections: parseLyricsSections(
          current.rawText,
          previous: current.sections,
        ),
      );
      return;
    }

    state = current.copyWith(
      isRawEditorMode: true,
      rawText: current.rebuildRawText(),
    );
  }

  /// Applies a raw markdown edit and re-parses it into stanzas.
  void updateRawText(String rawText) {
    final current = state;
    if (current == null) return;

    state = current.copyWith(
      rawText: rawText,
      sections: parseLyricsSections(rawText, previous: current.sections),
    );
    hasEdits = true;
  }

  /// Closes the review cockpit (REQ-LYR-09 keeps drafts in memory until then).
  void clear() {
    state = null;
  }
}

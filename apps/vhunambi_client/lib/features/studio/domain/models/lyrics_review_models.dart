import 'dart:convert';

import 'package:flutter/foundation.dart';
import '../../../sound_signature/domain/dsp/bantu_phonology.dart';
import '../../../sound_signature/domain/dsp/bantu_similarity.dart';

export '../../../sound_signature/domain/dsp/bantu_similarity.dart' show BantuSimilarityResult;

/// Domain helper for extracting non-bracketed Bantu lyric tokens and finding cognate suggestions (REQ-P56-COG-01).
abstract final class BantuCognateEngine {
  static const Set<String> structuralStopwords = {
    'intro',
    'verse',
    'chorus',
    'bridge',
    'outro',
    'hook',
    'pre-chorus',
    'interlude',
  };

  static List<BantuSimilarityResult> findSuggestions(
    String rawLyricsOrToken, {
    String languageCode = 'zu',
  }) {
    final lang = BantuLanguage.fromCode(languageCode) ?? BantuLanguage.zu;
    final stripped = rawLyricsOrToken.replaceAll(RegExp(r'\[[^\]]*\]'), ' ');
    final words = stripped
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s\u00C0-\u017F]'), ' ')
        .split(RegExp(r'\s+'))
        .where(
          (w) =>
              w.length >= 3 && !structuralStopwords.contains(w.toLowerCase()),
        )
        .take(5)
        .toList();

    final results = <BantuSimilarityResult>[];
    for (final w in words) {
      for (final target in BantuLanguage.values) {
        if (target != lang) {
          final res = BantuSimilarity.compare(w, lang, w, target);
          if (res.score >= 50) {
            results.add(res);
          }
        }
      }
    }
    return results;
  }
}

/// Structural role of a lyrical stanza (REQ-LYR-03).
enum LyricsSectionType {
  intro,
  verse,
  chorus,
  hook,
  bridge,
  outro,
}

/// Maps a bracketed stanza tag (e.g. `Verse 1`, `Chorus`, `Hook`) onto its
/// [LyricsSectionType]. Unknown tags degrade gracefully to
/// [LyricsSectionType.verse] so hand-written lyrics never fail to parse.
LyricsSectionType lyricsSectionTypeFromTag(String tag) {
  final normalized = tag.trim().toLowerCase();

  if (normalized.startsWith('intro')) return LyricsSectionType.intro;
  if (normalized.startsWith('chorus')) return LyricsSectionType.chorus;
  if (normalized.startsWith('hook')) return LyricsSectionType.hook;
  if (normalized.startsWith('bridge')) return LyricsSectionType.bridge;
  if (normalized.startsWith('outro')) return LyricsSectionType.outro;
  if (normalized.startsWith('verse')) return LyricsSectionType.verse;

  return LyricsSectionType.verse;
}

/// Human readable label for a stanza type — powers the review modal badges.
String lyricsSectionTypeLabel(LyricsSectionType type) {
  switch (type) {
    case LyricsSectionType.intro:
      return 'Intro';
    case LyricsSectionType.verse:
      return 'Verse';
    case LyricsSectionType.chorus:
      return 'Chorus';
    case LyricsSectionType.hook:
      return 'Hook';
    case LyricsSectionType.bridge:
      return 'Bridge';
    case LyricsSectionType.outro:
      return 'Outro';
  }
}

/// A single editable stanza inside the Studio lyrics review cockpit.
@immutable
class LyricsSection {
  final String id;
  final LyricsSectionType type;

  /// Bracketed header exactly as it appears in the raw lyrics, e.g. `[Verse 1]`.
  final String header;
  final List<String> lines;

  /// Optional per-line rhyme / delivery hints surfaced beside the editors.
  final List<String> rhymeNotes;

  const LyricsSection({
    required this.id,
    required this.type,
    required this.header,
    required this.lines,
    this.rhymeNotes = const [],
  });

  LyricsSection copyWith({
    String? id,
    LyricsSectionType? type,
    String? header,
    List<String>? lines,
    List<String>? rhymeNotes,
  }) {
    return LyricsSection(
      id: id ?? this.id,
      type: type ?? this.type,
      header: header ?? this.header,
      lines: lines ?? this.lines,
      rhymeNotes: rhymeNotes ?? this.rhymeNotes,
    );
  }

  /// Raw markdown fragment for this stanza (header + body), used by the
  /// bi-directional raw editor synchronisation (REQ-LYR-05).
  String toFormattedString() {
    if (lines.isEmpty) return header;
    return '$header\n${lines.join('\n')}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LyricsSection &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          type == other.type &&
          header == other.header &&
          listEquals(lines, other.lines) &&
          listEquals(rhymeNotes, other.rhymeNotes);

  @override
  int get hashCode => Object.hash(
        id,
        type,
        header,
        Object.hashAll(lines),
        Object.hashAll(rhymeNotes),
      );
}

/// Parses raw lyrical text into structured stanzas (REQ-LYR-03).
///
/// Recognises bracketed tags on their own line (`[Intro]`, `[Verse 1]`,
/// `[Chorus]`, `[Hook]`, `[Bridge]`, `[Outro]`). Text appearing before the
/// first tag is preserved as an implicit verse. Stanza identity and rhyme
/// notes are inherited from [previous] by index so inline edits survive a
/// raw-editor round trip (REQ-LYR-05).
List<LyricsSection> parseLyricsSections(
  String rawText, {
  List<LyricsSection> previous = const [],
}) {
  final headerPattern = RegExp(r'^\s*\[([^\]]+)\][^\S\n]*(.*)$');
  final headers = <String>[];
  final tagNames = <String>[];
  final bodies = <List<String>>[];

  for (final line in const LineSplitter().convert(rawText)) {
    final match = headerPattern.firstMatch(line);
    if (match != null) {
      // Keep trailing metadata (`[Verse 1] • 8 bars`) inside the header so
      // structured edits round-trip byte-identically.
      headers.add(line.trim());
      tagNames.add(match.group(1)!.trim());
      bodies.add(<String>[]);
      continue;
    }

    if (headers.isEmpty) {
      // Leading prose before any tag becomes an implicit verse.
      if (line.trim().isEmpty) continue;
      headers.add('[Verse]');
      tagNames.add('Verse');
      bodies.add(<String>[]);
    }

    bodies.last.add(line);
  }

  return <LyricsSection>[
    for (var index = 0; index < headers.length; index++)
      LyricsSection(
        id: index < previous.length
            ? previous[index].id
            : 'section_${index + 1}',
        type: lyricsSectionTypeFromTag(tagNames[index]),
        header: headers[index],
        lines: _trimTrailingBlankLines(bodies[index]),
        rhymeNotes:
            index < previous.length ? previous[index].rhymeNotes : const [],
      ),
  ];
}

List<String> _trimTrailingBlankLines(List<String> lines) {
  var end = lines.length;
  while (end > 0 && lines[end - 1].trim().isEmpty) {
    end--;
  }
  return lines.sublist(0, end);
}

/// The in-flight lyrics review draft owned by `LyricsReviewNotifier`.
@immutable
class LyricsReviewDraft {
  final String prompt;
  final String genre;
  final String language;
  final List<LyricsSection> sections;
  final List<String> culturalIdioms;

  /// `true` while the user is editing the raw markdown surface (REQ-LYR-05).
  final bool isRawEditorMode;
  final String rawText;

  const LyricsReviewDraft({
    required this.prompt,
    required this.genre,
    required this.language,
    required this.sections,
    this.culturalIdioms = const [],
    this.isRawEditorMode = false,
    required this.rawText,
  });

  /// Builds a draft straight from generated raw lyrics, parsing the stanzas.
  factory LyricsReviewDraft.fromRawText({
    required String prompt,
    required String genre,
    required String language,
    required String rawText,
    List<String> culturalIdioms = const [],
  }) {
    return LyricsReviewDraft(
      prompt: prompt,
      genre: genre,
      language: language,
      sections: parseLyricsSections(rawText),
      culturalIdioms: culturalIdioms,
      rawText: rawText,
    );
  }

  LyricsReviewDraft copyWith({
    String? prompt,
    String? genre,
    String? language,
    List<LyricsSection>? sections,
    List<String>? culturalIdioms,
    bool? isRawEditorMode,
    String? rawText,
  }) {
    return LyricsReviewDraft(
      prompt: prompt ?? this.prompt,
      genre: genre ?? this.genre,
      language: language ?? this.language,
      sections: sections ?? this.sections,
      culturalIdioms: culturalIdioms ?? this.culturalIdioms,
      isRawEditorMode: isRawEditorMode ?? this.isRawEditorMode,
      rawText: rawText ?? this.rawText,
    );
  }

  int get sectionCount => sections.length;

  /// Every lyric line across every stanza — used by review summaries.
  List<String> get allLines =>
      <String>[for (final section in sections) ...section.lines];

  /// Rebuilds [rawText] from the structured stanzas (markdown sync).
  String rebuildRawText() =>
      sections.map((section) => section.toFormattedString()).join('\n\n');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LyricsReviewDraft &&
          runtimeType == other.runtimeType &&
          prompt == other.prompt &&
          genre == other.genre &&
          language == other.language &&
          listEquals(sections, other.sections) &&
          listEquals(culturalIdioms, other.culturalIdioms) &&
          isRawEditorMode == other.isRawEditorMode &&
          rawText == other.rawText;

  @override
  int get hashCode => Object.hash(
        prompt,
        genre,
        language,
        Object.hashAll(sections),
        Object.hashAll(culturalIdioms),
        isRawEditorMode,
        rawText,
      );
}

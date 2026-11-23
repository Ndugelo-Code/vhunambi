import 'package:vhunambi_client/features/content_studio/domain/models/lyric_word_timestamp.dart';

/// Deterministic lyric sanitizer for Kinetic Reels 60 FPS Karaoke Canvas & MiniPlayer.
///
/// Strips structural section cues (`[Intro]`, `[Verse 1]`, `[Chorus]`,
/// `[Crisp soft shakers, airy synth pads]`), stage directions (`(x2)`, `[Repeat]`),
/// and metadata labels (`Title:`, `Genre:`, `BPM:`) before word tokenization (`SOC-06c`).
class LyricKaraokeSanitizer {
  const LyricKaraokeSanitizer._();

  static final RegExp _squareBracketBlock = RegExp(r'\[[^\]]*\]');
  static final RegExp _parenCueBlock = RegExp(r'\([^)]*\)');
  static final RegExp _unclosedParenLineCue = RegExp(r'\([^)\n]*$');
  static final RegExp _danglingCloseParen = RegExp(r'^[^(\n]*\)');
  static final RegExp _metadataHeaderLine = RegExp(
    r'^\s*(?:title|song\s*title|track|artist|creator|genre|sub[-\s]*genre|bpm|tempo|key|style|mood|language|duration|prompt)\s*:\s*.*$',
    caseSensitive: false,
    multiLine: true,
  );
  static final RegExp _structuralHeaderOnly = RegExp(
    r'^\[\s*(?:intro|verse(?:\s*\d+)?|pre[-\s]*chorus|chorus|post[-\s]*chorus|bridge|hook|outro|interlude|solo\s*verse(?:\s*\d+)?|call\s*and\s*response|drop(?:\s*\d+)?|final\s*drop)\s*\]$',
    caseSensitive: false,
  );
  static final RegExp _nonSungBookendHeader = RegExp(
    r'^\[\s*(?:intro|outro|instrumental|break|breakdown|interlude|drop(?:\s*\d+)?|final\s*drop)\s*\]$',
    caseSensitive: false,
  );
  static final RegExp _pureCueToken = RegExp(
    r'^(?:\[.*\]|\((?:x\d+|\d+x|repeat|chorus|verse|intro|outro|hook|bridge)\)|(?:intro|verse|chorus|bridge|outro|hook):?)$',
    caseSensitive: false,
  );

  /// Preserves readable structural stanza headers (`[Verse 1]`, `[Chorus]`) for
  /// multi-line teleprompters while stripping metadata lines (`Title:`, `BPM:`),
  /// instrumental cue brackets (`[Crisp soft shakers, airy synth pads]`), and
  /// parenthetical stage cues (`(x2)`, `(Repeat)`, `(Sacred drum;`).
  static String cleanLyricsForTeleprompter(String rawLyrics) {
    if (rawLyrics.trim().isEmpty) return '';
    final out = <String>[];
    for (final rawLine in rawLyrics.replaceAll('\r\n', '\n').split('\n')) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty) {
        if (out.isNotEmpty && out.last.isNotEmpty) out.add('');
        continue;
      }
      if (_metadataHeaderLine.hasMatch(trimmed)) continue;
      if (_structuralHeaderOnly.hasMatch(trimmed)) {
        out.add(trimmed);
        continue;
      }
      final cleaned = cleanLyricTextForKaraoke(trimmed);
      if (cleaned.isNotEmpty) {
        out.add(cleaned);
      }
    }
    return out.join('\n').trim();
  }

  /// Strips non-sung bookend headers (`[INTRO]`, `[OUTRO]`, `[Instrumental]`)
  /// for playback teleprompters while preserving stanza markers like `[Verse 1]`.
  static String cleanLyricsForPlayback(String rawLyrics) {
    final teleprompter = cleanLyricsForTeleprompter(rawLyrics);
    if (teleprompter.isEmpty) return '';
    final out = <String>[];
    for (final rawLine in teleprompter.split('\n')) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty) {
        if (out.isNotEmpty && out.last.isNotEmpty) out.add('');
        continue;
      }
      if (_nonSungBookendHeader.hasMatch(trimmed)) continue;
      out.add(trimmed);
    }
    return out.join('\n').trim();
  }

  /// Cleans raw multi-line lyric text before word-level [LyricWordTimestamp] tokenization.
  static String cleanLyricTextForKaraoke(String rawLyrics) {
    if (rawLyrics.trim().isEmpty) return '';
    var text = rawLyrics.replaceAll('\r\n', '\n');
    text = text.replaceAll(_metadataHeaderLine, ' ');
    text = text.replaceAll(_squareBracketBlock, ' ');
    text = text.replaceAll(_parenCueBlock, ' ');
    final cleanedLines = <String>[];
    for (final line in text.split('\n')) {
      var l = line.replaceAll(_unclosedParenLineCue, ' ');
      l = l.replaceAll(_danglingCloseParen, ' ');
      cleanedLines.add(l);
    }
    text = cleanedLines.join(' ');

    final cleanedTokens = <String>[];
    for (final rawToken in text.split(RegExp(r'\s+'))) {
      final token = rawToken.trim();
      if (token.isEmpty || _pureCueToken.hasMatch(token)) continue;
      final stripped = token
          .replaceAll(RegExp(r'^[\[\]()+*#]+|[\[\]()+*#]+$'), '')
          .trim();
      if (stripped.isEmpty || _pureCueToken.hasMatch(stripped)) continue;
      cleanedTokens.add(stripped);
    }
    return cleanedTokens.join(' ');
  }

  /// Sanitizes an existing list of [LyricWordTimestamp] tokens so legacy clips
  /// containing bracketed section tags or multi-word bracket/paren runs (`[Crisp`,
  /// `soft`, `shakers]`, `(Sacred`, `drum;`) render only clean singable vocal words.
  static List<LyricWordTimestamp> sanitizeAlignment(
    List<LyricWordTimestamp> words,
  ) {
    if (words.isEmpty) return const <LyricWordTimestamp>[];
    final result = <LyricWordTimestamp>[];
    var insideBracketRun = false;
    var insideParenRun = false;

    for (final item in words) {
      final rawWord = item.word.trim();
      if (rawWord.isEmpty) continue;

      if (insideBracketRun) {
        if (rawWord.contains(']')) {
          insideBracketRun = false;
        }
        continue;
      }

      if (insideParenRun) {
        if (rawWord.contains(')')) {
          insideParenRun = false;
        }
        continue;
      }

      if (rawWord.startsWith('[') && !rawWord.contains(']')) {
        insideBracketRun = true;
        continue;
      }

      if (rawWord.startsWith('(') && !rawWord.contains(')')) {
        insideParenRun = true;
        continue;
      }

      if (_squareBracketBlock.hasMatch(rawWord) ||
          _parenCueBlock.hasMatch(rawWord) ||
          _pureCueToken.hasMatch(rawWord)) {
        continue;
      }

      final cleaned = cleanLyricTextForKaraoke(rawWord);
      if (cleaned.isEmpty) continue;

      result.add(item.copyWith(word: cleaned, stanzaIndex: result.length ~/ 6));
    }
    return result;
  }
}

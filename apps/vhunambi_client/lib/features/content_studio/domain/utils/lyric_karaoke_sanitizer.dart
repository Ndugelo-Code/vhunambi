import 'package:vhunambi_client/features/content_studio/domain/models/lyric_word_timestamp.dart';

/// Deterministic lyric sanitizer for Kinetic Reels 60 FPS Karaoke Canvas & MiniPlayer.
///
/// Strips structural section cues (`[Intro]`, `[Verse 1]`, `[Chorus]`,
/// `[Crisp soft shakers, airy synth pads]`), stage directions (`(x2)`, `[Repeat]`),
/// and metadata labels (`Title:`, `Genre:`, `BPM:`) before word tokenization (`SOC-06c`).
class LyricKaraokeSanitizer {
  const LyricKaraokeSanitizer._();

  static final RegExp _squareBracketBlock = RegExp(r'\[[^\]]*\]');
  static final RegExp _parenCueBlock = RegExp(
    r'\(\s*(?:intro|verse\s*\d*|chorus|pre[-\s]*chorus|post[-\s]*chorus|bridge|outro|hook|drop|break|breakdown|interlude|repeat(?:\s*x?\d+)?|x\d+|\d+x|instrumental|solo|ad[-\s]*libs?)\s*\)',
    caseSensitive: false,
  );
  static final RegExp _metadataHeaderLine = RegExp(
    r'^\s*(?:title|song\s*title|track|artist|creator|genre|sub[-\s]*genre|bpm|tempo|key|style|mood|language|duration|prompt)\s*:\s*.*$',
    caseSensitive: false,
    multiLine: true,
  );
  static final RegExp _pureCueToken = RegExp(
    r'^(?:\[.*\]|\((?:x\d+|\d+x|repeat|chorus|verse|intro|outro|hook|bridge)\)|(?:intro|verse|chorus|bridge|outro|hook):?)$',
    caseSensitive: false,
  );

  /// Cleans raw multi-line lyric text before word-level [LyricWordTimestamp] tokenization.
  static String cleanLyricTextForKaraoke(String rawLyrics) {
    if (rawLyrics.trim().isEmpty) return '';
    var text = rawLyrics.replaceAll('\r\n', '\n');
    text = text.replaceAll(_metadataHeaderLine, ' ');
    text = text.replaceAll(_squareBracketBlock, ' ');
    text = text.replaceAll(_parenCueBlock, ' ');

    final cleanedTokens = <String>[];
    for (final rawToken in text.split(RegExp(r'\s+'))) {
      final token = rawToken.trim();
      if (token.isEmpty || _pureCueToken.hasMatch(token)) continue;
      final stripped = token
          .replaceAll(RegExp(r'^[\[\]+*#]+|[\[\]+*#]+$'), '')
          .trim();
      if (stripped.isEmpty || _pureCueToken.hasMatch(stripped)) continue;
      cleanedTokens.add(stripped);
    }
    return cleanedTokens.join(' ');
  }

  /// Sanitizes an existing list of [LyricWordTimestamp] tokens so legacy clips
  /// containing bracketed section tags or multi-word bracket runs (`[Crisp`,
  /// `soft`, `shakers]`) render only clean singable vocal words.
  static List<LyricWordTimestamp> sanitizeAlignment(
    List<LyricWordTimestamp> words,
  ) {
    if (words.isEmpty) return const <LyricWordTimestamp>[];
    final result = <LyricWordTimestamp>[];
    var insideBracketRun = false;

    for (final item in words) {
      final rawWord = item.word.trim();
      if (rawWord.isEmpty) continue;

      if (insideBracketRun) {
        if (rawWord.contains(']')) {
          insideBracketRun = false;
        }
        continue;
      }

      if (rawWord.startsWith('[') && !rawWord.contains(']')) {
        insideBracketRun = true;
        continue;
      }

      if (_squareBracketBlock.hasMatch(rawWord) ||
          _parenCueBlock.hasMatch(rawWord) ||
          _pureCueToken.hasMatch(rawWord)) {
        continue;
      }

      final cleaned = cleanLyricTextForKaraoke(rawWord);
      if (cleaned.isEmpty) continue;

      result.add(
        item.copyWith(
          word: cleaned,
          stanzaIndex: result.length ~/ 6,
        ),
      );
    }
    return result;
  }
}

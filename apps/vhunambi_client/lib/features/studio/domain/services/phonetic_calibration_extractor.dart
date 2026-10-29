import 'dart:math' as math;
import '../models/vocal_identity_models.dart';

/// Deterministic Bantu Phonetic Calibration Line Extractor (REQ-VOC-04..06).
///
/// Scores every line in the user's lyrics using the Bantu Phonetic Density Formula:
///   S_line = 3.0 * N_diacritics + 2.5 * N_clusters + 2.0 * N_idioms + 1.0 * clamp(wordCount / 6, 0, 2)
/// and selects the top 3 non-duplicate lines so a 15-20s recording captures the creator's
/// vocal tract formants on the exact words their song contains.
class PhoneticCalibrationExtractor {
  const PhoneticCalibrationExtractor._();

  static final RegExp _diacriticRegex = RegExp(r'[ḓṱṋḽṅḒṰṊḼṄ]');
  static final RegExp _clusterRegex = RegExp(
    r'\b\w*(tsh|dz|pf|bv|hl|dl|kh|ph|th|ng|nk|ny|sh|zh|c|q|x)\w*\b',
    caseSensitive: false,
  );

  static const Set<String> _culturalIdioms = {
    'ndaa',
    'aa',
    'yebo',
    'ahee',
    'siyabonga',
    'kea',
    'leboga',
    'eish',
    'yoh',
    'bathong',
    'haibo',
    'shapa',
    'khuza',
    'woza',
    'ashu',
    'tsha',
    'mbilu',
    'vhunambi',
    'ngoma',
    'lufuno',
  };

  static const Map<String, List<String>> _fallbackLinesByLanguage = {
    've': [
      'Ndaa! Mbilu yanga i khou lidza ngoma dza Vhunambi na ḓuvha ḽa muṱa.',
      'Ri tshimbila kha ṋaledzi dza vhusiku, ri imba nga lufuno lwa vhukuma.',
      'Ahee! Kha vha ḓe ri ṱangane tshilombe tsha Amapiano.',
    ],
    'zu': [
      'Yebo! Siyabonga kakhulu, inhliziyo yami ishaya isigqi se-Amapiano.',
      'Woza la! Amagagasi olwandle athetha ingoma yaseThekwini.',
      'Haibo! Hlala phansi ulalele uMaskandi oqotho.',
    ],
    'default': [
      'Ndaa! Mbilu yanga i khou tshina kha ngoma dza Vhunambi.',
      'Yebo! Hlala phansi ulalele isigqi saseMzansi esishisayo.',
      'Ahee! Kea leboga, re bina koša ya Amapiano bosigo kamoka.',
    ],
  };

  /// Computes the Bantu Phonetic Density Score and highlighted tokens for a single line.
  static ({double score, List<String> highlightedTokens}) scoreLine(
    String line,
  ) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('[')) {
      return (score: 0.0, highlightedTokens: const []);
    }

    final diacriticMatches = _diacriticRegex.allMatches(trimmed).length;
    final words = trimmed
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    final highlighted = <String>{};
    var clusterCount = 0;
    var idiomCount = 0;

    for (final rawWord in words) {
      final cleanWord = rawWord.replaceAll(RegExp(r'[.,!?;:"()\[\]]'), '');
      if (cleanWord.isEmpty) continue;

      if (_diacriticRegex.hasMatch(cleanWord)) {
        highlighted.add(cleanWord);
      }
      if (_clusterRegex.hasMatch(cleanWord)) {
        clusterCount++;
        highlighted.add(cleanWord);
      }
      if (_culturalIdioms.contains(cleanWord.toLowerCase())) {
        idiomCount++;
        highlighted.add(cleanWord);
      }
    }

    final wordFactor = (words.length / 6.0).clamp(0.0, 2.0);
    final rawScore =
        3.0 * diacriticMatches +
        2.5 * clusterCount +
        2.0 * idiomCount +
        1.0 * wordFactor;

    final rounded = (rawScore * 100).roundToDouble() / 100.0;
    return (score: rounded, highlightedTokens: highlighted.take(6).toList());
  }

  /// Extracts the top 3 phonetically rich calibration lines from [lyrics] (REQ-VOC-05, REQ-VOC-06).
  static PhoneticCalibrationScript extractScript(
    String lyrics, {
    String language = 'Tshivenḓa',
  }) {
    final rawLines = lyrics
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.length > 3 && !l.startsWith('['))
        .toList();

    final uniqueLines = <String>[];
    for (final line in rawLines) {
      if (!uniqueLines.contains(line)) {
        uniqueLines.add(line);
      }
    }

    final scored = uniqueLines.map((text) {
      final result = scoreLine(text);
      return (
        text: text,
        score: result.score,
        tokens: result.highlightedTokens,
      );
    }).toList()..sort((a, b) => b.score.compareTo(a.score));

    final selected = scored.take(3).toList();

    final lowerLang = language.toLowerCase();
    final langKey = lowerLang.startsWith('zu') || lowerLang.contains('zulu')
        ? 'zu'
        : (lowerLang.startsWith('ve') || lowerLang.contains('venda')
              ? 've'
              : 'default');
    final fallbacks =
        _fallbackLinesByLanguage[langKey] ??
        _fallbackLinesByLanguage['default']!;

    for (final fb in fallbacks) {
      if (selected.length >= 3) break;
      if (!selected.any((s) => s.text == fb)) {
        final fbScore = scoreLine(fb);
        selected.add((
          text: fb,
          score: fbScore.score,
          tokens: fbScore.highlightedTokens,
        ));
      }
    }

    final calibrationLines = <PhoneticCalibrationLine>[];
    for (var i = 0; i < selected.length; i++) {
      final item = selected[i];
      final wordCount = item.text
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .length;
      final estSec = math.max(4, math.min(8, (wordCount * 0.65).round()));
      final tokens = item.tokens.isNotEmpty
          ? item.tokens
          : item.text.split(RegExp(r'\s+')).take(2).toList();

      calibrationLines.add(
        PhoneticCalibrationLine(
          lineIndex: i,
          text: item.text,
          phoneticScore: item.score,
          highlightedTokens: tokens,
          estimatedDurationSec: estSec,
        ),
      );
    }

    final totalSec = calibrationLines.fold<int>(
      0,
      (sum, line) => sum + line.estimatedDurationSec,
    );

    return PhoneticCalibrationScript(
      language: language,
      lines: calibrationLines,
      totalEstimatedDurationSec: totalSec,
    );
  }
}

import 'package:flutter/widgets.dart';
import '../../../sound_signature/domain/dsp/bantu_phonology.dart';
import '../../../sound_signature/domain/dsp/bantu_similarity.dart';

/// Single line translation, phonetic guide, and cognate insight (REQ-BANTU-LYR-01).
class BantuLyricTranslationItem {
  const BantuLyricTranslationItem({
    required this.originalLine,
    required this.phoneticSingAlongGuide,
    required this.translatedMeaning,
    required this.cognateMatches,
    this.isGlossaryMatch = false,
  });

  final String originalLine;
  final String phoneticSingAlongGuide;
  final String translatedMeaning;
  final List<BantuSimilarityResult> cognateMatches;
  final bool isGlossaryMatch;

  bool get hasMeaning => translatedMeaning != 'meaning unavailable';
}

/// Fallback sentinel when a phrase or word is not in the curated glossary.
const String kMeaningUnavailable = 'meaning unavailable';

/// Curated glossary entry with designated source language.
class BantuGlossaryEntry {
  const BantuGlossaryEntry({
    required this.phrase,
    required this.meaning,
    required this.language,
  });

  final String phrase;
  final String meaning;
  final BantuLanguage language;
}

/// Small curated glossary of verified cultural phrases and lyric staples.
const List<BantuGlossaryEntry> kBantuCuratedEntries = [
  BantuGlossaryEntry(
    phrase: 'sawubona',
    meaning: 'hello / I see you (isiZulu)',
    language: BantuLanguage.zu,
  ),
  BantuGlossaryEntry(
    phrase: 'molo',
    meaning: 'hello (isiXhosa)',
    language: BantuLanguage.xh,
  ),
  BantuGlossaryEntry(
    phrase: 'dumelang',
    meaning: 'greetings to all (Sesotho/Setswana)',
    language: BantuLanguage.st,
  ),
  BantuGlossaryEntry(
    phrase: 'ndaa',
    meaning: 'reverent greeting (Tshivenḓa male)',
    language: BantuLanguage.ve,
  ),
  BantuGlossaryEntry(
    phrase: 'aa',
    meaning: 'reverent greeting (Tshivenḓa female)',
    language: BantuLanguage.ve,
  ),
  BantuGlossaryEntry(
    phrase: 'avuxeni',
    meaning: 'good morning / greetings (Xitsonga)',
    language: BantuLanguage.ts,
  ),
  BantuGlossaryEntry(
    phrase: 'yebo',
    meaning: 'yes / affirmation (Nguni)',
    language: BantuLanguage.zu,
  ),
  BantuGlossaryEntry(
    phrase: 'ewe',
    meaning: 'yes (isiXhosa)',
    language: BantuLanguage.xh,
  ),
  BantuGlossaryEntry(
    phrase: 'ee',
    meaning: 'yes (Sesotho)',
    language: BantuLanguage.st,
  ),
  BantuGlossaryEntry(
    phrase: 'ndi zwone',
    meaning: 'it is true / agreed (Tshivenḓa)',
    language: BantuLanguage.ve,
  ),
  BantuGlossaryEntry(
    phrase: 'hi swona',
    meaning: 'it is correct (Xitsonga)',
    language: BantuLanguage.ts,
  ),
  BantuGlossaryEntry(
    phrase: 'ngiyabonga',
    meaning: 'thank you (isiZulu)',
    language: BantuLanguage.zu,
  ),
  BantuGlossaryEntry(
    phrase: 'enkosi',
    meaning: 'thank you (isiXhosa)',
    language: BantuLanguage.xh,
  ),
  BantuGlossaryEntry(
    phrase: 'ke a leboga',
    meaning: 'thank you (Setswana/Sesotho)',
    language: BantuLanguage.tn,
  ),
  BantuGlossaryEntry(
    phrase: 'ndo livhuwa',
    meaning: 'thank you (Tshivenḓa)',
    language: BantuLanguage.ve,
  ),
  BantuGlossaryEntry(
    phrase: 'inkomu',
    meaning: 'thank you (Xitsonga)',
    language: BantuLanguage.ts,
  ),
  BantuGlossaryEntry(
    phrase: 'hambani kahle',
    meaning: 'go well / peace be with you (isiZulu)',
    language: BantuLanguage.zu,
  ),
  BantuGlossaryEntry(
    phrase: 'sala kahle',
    meaning: 'stay well (isiZulu)',
    language: BantuLanguage.zu,
  ),
  BantuGlossaryEntry(
    phrase: 'tshimbilani zwavhudi',
    meaning: 'travel well (Tshivenḓa)',
    language: BantuLanguage.ve,
  ),
  BantuGlossaryEntry(
    phrase: 'thando lwami',
    meaning: 'my love / my beloved (isiZulu)',
    language: BantuLanguage.zu,
  ),
  BantuGlossaryEntry(
    phrase: 'mufunwa wanga',
    meaning: 'my beloved (Tshivenḓa)',
    language: BantuLanguage.ve,
  ),
  BantuGlossaryEntry(
    phrase: 'moratuwa wa ka',
    meaning: 'my love (Sesotho)',
    language: BantuLanguage.st,
  ),
  BantuGlossaryEntry(
    phrase: 'shisa',
    meaning: 'bring the heat / burn bright',
    language: BantuLanguage.zu,
  ),
  BantuGlossaryEntry(
    phrase: 'woza',
    meaning: 'come here / step forward',
    language: BantuLanguage.zu,
  ),
  BantuGlossaryEntry(
    phrase: 'masambe',
    meaning: 'let us journey forward (isiXhosa)',
    language: BantuLanguage.xh,
  ),
  BantuGlossaryEntry(
    phrase: 'kha ri tshimbile',
    meaning: 'let us move / let us walk (Tshivenḓa)',
    language: BantuLanguage.ve,
  ),
  BantuGlossaryEntry(
    phrase: 'mutsho wa vhonala',
    meaning: 'the dawn appears / a new morning shines (Tshivenḓa)',
    language: BantuLanguage.ve,
  ),
  BantuGlossaryEntry(
    phrase: 'taba ke yeo',
    meaning: 'that is the matter / the truth (Sepedi)',
    language: BantuLanguage.nso,
  ),
  BantuGlossaryEntry(
    phrase: 'kuleli lizwe',
    meaning: 'in this beautiful country (isiZulu)',
    language: BantuLanguage.zu,
  ),
  BantuGlossaryEntry(
    phrase: 'matsheloni',
    meaning: 'morning / greetings (Tshivenḓa)',
    language: BantuLanguage.ve,
  ),
  BantuGlossaryEntry(
    phrase: 'ndi matsheloni',
    meaning: 'it is morning / morning greetings (Tshivenḓa)',
    language: BantuLanguage.ve,
  ),
  BantuGlossaryEntry(
    phrase: 'makhado',
    meaning: 'historical Venda town & heritage (Tshivenḓa)',
    language: BantuLanguage.ve,
  ),
];

/// Backwards-compatible map view of curated glossary.
final Map<String, String> kBantuCuratedGlossary = {
  for (final entry in kBantuCuratedEntries) entry.phrase: entry.meaning,
};

/// Service providing deterministic lyric translation, phonetic guides, and cognate matches.
class BantuLyricTranslationService {
  const BantuLyricTranslationService._();

  /// Translates a multi-line lyric text into structured sing-along items.
  static List<BantuLyricTranslationItem> processLyrics({
    required String lyricsText,
    required String baseLanguageCode,
    List<String> targetCognateLanguages = const ['zu', 'xh', 'nso', 've', 'ts'],
  }) {
    final lines = lyricsText.split('\n');
    final results = <BantuLyricTranslationItem>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      results.add(
        translateLine(
          line: trimmed,
          baseLanguageCode: baseLanguageCode,
          targetCognateLanguages: targetCognateLanguages,
        ),
      );
    }

    return results;
  }

  /// Translates an individual line and builds its phonetic sing-along guide.
  static BantuLyricTranslationItem translateLine({
    required String line,
    required String baseLanguageCode,
    List<String> targetCognateLanguages = const ['zu', 'xh', 'nso', 've', 'ts'],
  }) {
    // 1. Phonetic guide with penultimate syllable stress marked (REQ-BANTU-LYR-03)
    final phonetic = generatePhoneticGuide(line);

    // 2. Lexicon lookup (REQ-BANTU-LYR-02)
    final norm = line
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s\u00C0-\u017F]'), '')
        .trim();
    String meaning = kMeaningUnavailable;
    bool isMatch = false;

    if (kBantuCuratedGlossary.containsKey(norm)) {
      meaning = kBantuCuratedGlossary[norm]!;
      isMatch = true;
    } else {
      // Check if any known phrase is contained within the line
      for (final entry in kBantuCuratedGlossary.entries) {
        if (norm.contains(entry.key)) {
          meaning = entry.value;
          isMatch = true;
          break;
        }
      }
    }

    // 3. Cognate detection via BantuSimilarity (REQ-BANTU-LYR-06)
    final sourceLang =
        BantuLanguage.fromCode(baseLanguageCode) ?? BantuLanguage.zu;
    final cognates = <BantuSimilarityResult>[];

    const nonBantuTokens = {
      'sunrise',
      'sunset',
      'morning',
      'love',
      'baby',
      'yeah',
      'the',
      'and',
      'in',
      'on',
      'at',
      'to',
      'for',
      'of',
      'with',
      'from',
      'remix',
      'feat',
      'ft',
    };

    final words = norm
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 3 && !nonBantuTokens.contains(w))
        .toList();
    for (final targetCode in targetCognateLanguages) {
      final targetLang = BantuLanguage.fromCode(targetCode);
      if (targetLang == null || targetLang == sourceLang) continue;

      for (final w in words) {
        // Authentically compare only against candidate words originating in targetLang
        for (final entry in kBantuCuratedEntries) {
          if (entry.language != targetLang) continue;
          final candWords = entry.phrase.split(' ');
          for (final cw in candWords) {
            if (cw.length >= 3) {
              final sim = BantuSimilarity.compare(
                w,
                sourceLang,
                cw,
                targetLang,
              );
              if (sim.score >= 65 &&
                  !cognates.any(
                    (c) => c.sourceWord == w && c.targetWord == cw,
                  )) {
                cognates.add(sim);
              }
            }
          }
        }
      }
    }

    return BantuLyricTranslationItem(
      originalLine: line,
      phoneticSingAlongGuide: phonetic,
      translatedMeaning: meaning,
      cognateMatches: cognates,
      isGlossaryMatch: isMatch,
    );
  }

  /// Generates a sing-along phonetic guide marking the penultimate syllable.
  ///
  /// Examples:
  /// - `hambani` -> `ham-**ba**-ni`
  /// - `ngiyabonga` -> `ngi-ya-**bo**-nga`
  /// - `woza` -> `**wo**-za`
  static String generatePhoneticGuide(String line) {
    if (line.startsWith('[') && line.endsWith(']')) {
      return line; // Leave section markers like [VERSE 1] untouched
    }

    final words = line.split(RegExp(r'\s+'));
    final out = <String>[];

    for (final word in words) {
      if (word.isEmpty) continue;
      out.add(syllabifyAndMarkPenultimate(word));
    }

    return out.join(' ');
  }

  /// Breaks a Bantu word into open syllables and bolds the penultimate syllable.
  static String syllabifyAndMarkPenultimate(String word) {
    // Strip trailing punctuation
    final puncMatch = RegExp(r'[.,!?;:]+$').firstMatch(word);
    final trailingPunc = puncMatch?.group(0) ?? '';
    final clean = word.substring(0, word.length - trailingPunc.length);

    if (clean.length <= 2) {
      return '**$clean**$trailingPunc';
    }

    final syllables = splitBantuSyllables(clean);
    if (syllables.isEmpty) return '$clean$trailingPunc';
    if (syllables.length == 1) return '**${syllables[0]}**$trailingPunc';

    final penultIndex = syllables.length - 2;
    final marked = <String>[];
    for (int i = 0; i < syllables.length; i++) {
      if (i == penultIndex) {
        marked.add('**${syllables[i]}**');
      } else {
        marked.add(syllables[i]);
      }
    }

    return '${marked.join('-')}$trailingPunc';
  }

  /// Splits an indigenous Bantu word into open (C)(G)V syllables.
  static List<String> splitBantuSyllables(String word) {
    final lower = word.toLowerCase();
    final vowels = RegExp(r'[aeiouáéíóúâêîôû\u1E13\u1E3C\u1E45\u1E4B]');
    final syllables = <String>[];

    int start = 0;
    for (int i = 0; i < lower.length; i++) {
      if (vowels.hasMatch(lower[i])) {
        // Vowel found. Lookahead: if the next char is a nasal consonant followed by another consonant,
        // it may form a cluster or coda in fast speech. Standard Bantu: syllable boundary right after vowel.
        syllables.add(word.substring(start, i + 1));
        start = i + 1;
      }
    }

    if (start < word.length) {
      if (syllables.isNotEmpty) {
        syllables[syllables.length - 1] += word.substring(start);
      } else {
        syllables.add(word.substring(start));
      }
    }

    return syllables;
  }

  /// Renders a phonetic guide string (with **bold** markdown tags) as a styled Widget
  /// with zero raw markdown asterisks rendered on screen.
  static Widget buildStyledPhoneticGuide(
    String guideText, {
    TextStyle? baseStyle,
    Color? accentColor,
  }) {
    final parts = guideText.split('**');
    final spans = <TextSpan>[];
    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      final isBold = i % 2 == 1;
      spans.add(
        TextSpan(
          text: parts[i],
          style: isBold
              ? (baseStyle ?? const TextStyle()).copyWith(
                  fontWeight: FontWeight.w800,
                  color: accentColor,
                )
              : baseStyle,
        ),
      );
    }
    return Text.rich(TextSpan(children: spans));
  }
}

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

/// Small curated glossary of verified cultural phrases and lyric staples.
///
/// v1 requirement (REQ-BANTU-LYR-02): lexicon-based ONLY. Unknown words/lines
/// yield [kMeaningUnavailable]. Zero AI/LLM fabrication of indigenous translations.
const Map<String, String> kBantuCuratedGlossary = {
  'sawubona': 'hello / I see you (isiZulu)',
  'molo': 'hello (isiXhosa)',
  'dumelang': 'greetings to all (Sesotho/Setswana)',
  'ndaa': 'reverent greeting (Tshivenḓa male)',
  'aa': 'reverent greeting (Tshivenḓa female)',
  'avuxeni': 'good morning / greetings (Xitsonga)',
  'yebo': 'yes / affirmation (Nguni)',
  'ewe': 'yes (isiXhosa)',
  'ee': 'yes (Sesotho)',
  'ndi zwone': 'it is true / agreed (Tshivenḓa)',
  'hi swona': 'it is correct (Xitsonga)',
  'ngiyabonga': 'thank you (isiZulu)',
  'enkosi': 'thank you (isiXhosa)',
  'ke a leboga': 'thank you (Setswana/Sesotho)',
  'ndo livhuwa': 'thank you (Tshivenḓa)',
  'inkomu': 'thank you (Xitsonga)',
  'hambani kahle': 'go well / peace be with you (isiZulu)',
  'sala kahle': 'stay well (isiZulu)',
  'tshimbilani zwavhudi': 'travel well (Tshivenḓa)',
  'thando lwami': 'my love / my beloved (isiZulu)',
  'mufunwa wanga': 'my beloved (Tshivenḓa)',
  'moratuwa wa ka': 'my love (Sesotho)',
  'shisa': 'bring the heat / burn bright',
  'woza': 'come here / step forward',
  'masambe': 'let us journey forward (isiXhosa)',
  'kha ri tshimbile': 'let us move / let us walk (Tshivenḓa)',
  'mutsho wa vhonala': 'the dawn appears / a new morning shines (Tshivenḓa)',
  'taba ke yeo': 'that is the matter / the truth (Sepedi)',
  'kuleli lizwe': 'in this beautiful country (isiZulu)',
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
    final norm = line.toLowerCase().replaceAll(RegExp(r'[^\w\s\u00C0-\u017F]'), '').trim();
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
    final sourceLang = BantuLanguage.fromCode(baseLanguageCode) ?? BantuLanguage.zu;
    final cognates = <BantuSimilarityResult>[];

    final words = norm.split(RegExp(r'\s+')).where((w) => w.length >= 3).toList();
    for (final targetCode in targetCognateLanguages) {
      final targetLang = BantuLanguage.fromCode(targetCode);
      if (targetLang == null || targetLang == sourceLang) continue;

      for (final w in words) {
        for (final glossKey in kBantuCuratedGlossary.keys) {
          final candWords = glossKey.split(' ');
          for (final cw in candWords) {
            if (cw.length >= 3) {
              final sim = BantuSimilarity.compare(w, sourceLang, cw, targetLang);
              if (sim.score >= 60 && !cognates.any((c) => c.sourceWord == w && c.targetWord == cw)) {
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
}

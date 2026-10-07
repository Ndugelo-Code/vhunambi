import '../../domain/models/lyrics_review_models.dart';
import '../../domain/services/i_lyrics_generation_service.dart';

/// Deterministic offline lyrics synthesis (REQ-LYR-01, NFR-12-02).
///
/// Output is dialect-authentic per language and stable for a given call
/// sequence, so provider/widget tests can assert exact stanza content while
/// "Regenerate Lyrics" (REQ-LYR-07) still yields fresh variation — each call
/// walks the phrase banks one step further.
class FakeLyricsGenerationService implements ILyricsGenerationService {
  FakeLyricsGenerationService({this.latency = Duration.zero});

  /// Simulated network latency; the zero default keeps headless tests
  /// timer-free.
  final Duration latency;

  /// Number of drafts produced so far — doubles as the variation seed.
  int generationCount = 0;

  @override
  Future<LyricsReviewDraft> generateLyrics({
    required String prompt,
    required String genre,
    required String language,
  }) async {
    if (latency > Duration.zero) {
      await Future<void>.delayed(latency);
    }

    final variant = generationCount;
    generationCount++;

    return LyricsReviewDraft.fromRawText(
      prompt: prompt,
      genre: genre,
      language: language,
      rawText: composeRawLyrics(
        genre: genre,
        language: language,
        variant: variant,
      ),
      culturalIdioms: getCulturalIdioms(language),
    );
  }

  @override
  List<String> getCulturalIdioms(String language) =>
      List<String>.unmodifiable(culturalIdiomsFor(language));

  /// Regional idiom / ad-lib pack for [language], falling back to English.
  static List<String> culturalIdiomsFor(String language) =>
      _idioms[_normalise(language)] ?? _idioms[_fallbackKey]!;

  /// Ad-lib pack matching [genre] (e.g. Amapiano log-drum calls), falling back
  /// to the language pack when the genre has no dedicated vocal pack.
  static List<String> genreAdLibs(String genre, String language) =>
      _idioms[_normalise(genre)] ?? culturalIdiomsFor(language);

  /// Builds the full raw lyrics payload for the given studio parameters.
  ///
  /// [variant] rotates the phrase banks so successive regenerations differ
  /// while remaining fully deterministic.
  static String composeRawLyrics({
    required String genre,
    required String language,
    int variant = 0,
  }) {
    final key = _verseBank.containsKey(_normalise(language))
        ? _normalise(language)
        : _fallbackKey;
    final verses = _rotate(_verseBank[key]!, variant);
    final hooks = _rotate(_chorusBank[key]!, variant);
    final adLib = genreAdLibs(genre, language).first;

    return '[Intro]\n$adLib\n${verses[0]}\n'
        '\n[Verse 1]\n${verses[1]}\n${verses[2]}\n${verses[3]}\n'
        '\n[Chorus]\n${hooks[0]}\n${hooks[1]}\n${hooks[2]}\n'
        '\n[Verse 2]\n${verses[4]}\n${verses[5]}\n${verses[0]}\n'
        '\n[Outro]\n${hooks[0]}';
  }

  /// Rotates [source] by `variant`, keeping the payload stable per call index.
  static List<String> _rotate(List<String> source, int variant) {
    if (source.isEmpty) return const <String>[];
    final offset = variant % source.length;
    return <String>[...source.sublist(offset), ...source.sublist(0, offset)];
  }
}

const String _fallbackKey = 'english';

/// Regional idiom / ad-lib packs keyed by normalised language **or** genre.
const Map<String, List<String>> _idioms = <String, List<String>>{
  'tshivenḓa': <String>[
    'Ndi khou vha fhululedza',
    'Vhuthu ndi vhuṱu',
    'Ri khou imba nga u takala',
  ],
  'isizulu': <String>['Yebo yes', 'Sthandwa sami', 'Shaya phansi'],
  'sepedi': <String>['Ke a go rata', 'Tsoga o bone', 'Batho ba rona'],
  'swahili': <String>['Karibu nyumbani', 'Moyo wangu', 'Pamoja tunaweza'],
  'amapiano': <String>['Yanos!', 'Aw yebo', 'Phansi!'],
  'gqom': <String>['Durban!', 'Deep bass!', 'Hype!'],
  'english': <String>['Light it up', 'One more time', 'Hold the line'],
};

/// Stanza phrase banks — six lines per language so two verses never repeat.
const Map<String, List<String>> _verseBank = <String, List<String>>{
  'tshivenḓa': <String>[
    'Ndi khou vhona the light yo dzhena',
    'Vhutshilo vhu ṱoḓa vhuthu nga mbilu',
    'Rine vha Venda ri khou imba nga u takala',
    'Zwiṱhi zwi khou tshina nga mulenzhe woṱhe',
    'Mudi wa hashu u khou vha na thendo',
    'Maḓi a khou elela mulamboni',
  ],
  'isizulu': <String>[
    'Sikhanya phakathi kobumnyama',
    'Uthando lwethu lunamandla amakhulu',
    'Sina phezulu kwezintaba zaseKhathazekile',
    'Izwi lethu livakala emhlabeni',
    'Umoya wethu uhlala ungena',
    'Imvula iyana emasimini ethu',
  ],
  'sepedi': <String>[
    'Lesedi le tsena ka ntlong ya rena',
    'Lerato la rena le na le maatla',
    'Re bina ka thabo ye kgolo',
    'Lentswe la rena le kwa godimo',
    'Moya wa rena o dula o le gona',
    'Pula e na masimong a rena',
  ],
  'swahili': <String>[
    'Nuru inaingia nyumbani kwetu',
    'Upendo wetu una nguvu nyingi',
    'Tunacheza juu ya milima',
    'Sauti yetu inasikika duniani',
    'Roho yetu iko pamoja nasi',
    'Mvua inanyesha mashambani',
  ],
  'english': <String>[
    'The light came down into the streets',
    'Our love is stronger than the dark',
    'We dance above the city skyline',
    'Our voices echo through the night',
    'The spirit stays with us always',
    'Rain is falling on the fields',
  ],
};

/// Hook banks — three lines per language, reprised by the outro.
const Map<String, List<String>> _chorusBank = <String, List<String>>{
  'tshivenḓa': <String>[
    'Vhuthu ndi vhuṱu, ri khou imba',
    'Ndi khou vha fhululedza nga luimbo',
    'Zwa hashu zwi ḓo dzhena',
  ],
  'isizulu': <String>[
    'Yebo yes, siyakubonga',
    'Shaya phansi, phakathi kwethu',
    'Uthando lwethu lunamandla',
  ],
  'sepedi': <String>[
    'Ke a go rata, mmino wa rona',
    'Tsoga o bone letšatši',
    'Batho ba rona ba tumile',
  ],
  'swahili': <String>[
    'Karibu nyumbani, moyo wangu',
    'Pamoja tunaweza, Afrika',
    'Sauti yetu inasikika',
  ],
  'english': <String>[
    'Light it up, one more time',
    'We rise together tonight',
    'Say it loud, say it proud',
  ],
};

/// Normalises a language / genre label for bank lookups.
String _normalise(String value) {
  final lowered = value.trim().toLowerCase();
  return _aliases[lowered] ?? lowered;
}

const Map<String, String> _aliases = <String, String>{
  've': 'tshivenḓa',
  'tshivenda': 'tshivenḓa',
  'venda': 'tshivenḓa',
  'zu': 'isizulu',
  'zulu': 'isizulu',
  'nso': 'sepedi',
  'pedi': 'sepedi',
  'northern sotho': 'sepedi',
  'sw': 'swahili',
  'kiswahili': 'swahili',
  'en': 'english',
};

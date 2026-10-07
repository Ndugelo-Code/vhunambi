import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/studio/data/services/fake_lyrics_generation_service.dart';
import 'package:vhunambi_client/features/studio/domain/models/lyrics_review_models.dart';

/// T12.2 — Deterministic lyrics synthesis double suite.
void main() {
  late FakeLyricsGenerationService service;

  setUp(() {
    service = FakeLyricsGenerationService();
  });

  test('generateLyrics returns five parsed, non-empty stanzas', () async {
    final draft = await service.generateLyrics(
      prompt: 'heritage anthem',
      genre: 'Amapiano',
      language: 'Tshivenḓa',
    );

    expect(
      draft.sections.map((section) => section.header),
      <String>['[Intro]', '[Verse 1]', '[Chorus]', '[Verse 2]', '[Outro]'],
    );
    expect(
      draft.sections.map((section) => section.type),
      <LyricsSectionType>[
        LyricsSectionType.intro,
        LyricsSectionType.verse,
        LyricsSectionType.chorus,
        LyricsSectionType.verse,
        LyricsSectionType.outro,
      ],
    );
    expect(draft.sections.every((section) => section.lines.isNotEmpty), isTrue);
    expect(draft.rawText, contains('[Chorus]'));
  });

  test('carries the studio metadata and the idiom catalogue', () async {
    final draft = await service.generateLyrics(
      prompt: 'heritage anthem',
      genre: 'Amapiano',
      language: 'Tshivenḓa',
    );

    expect(draft.prompt, 'heritage anthem');
    expect(draft.genre, 'Amapiano');
    expect(draft.language, 'Tshivenḓa');
    expect(draft.culturalIdioms, contains('Ndi khou vha fhululedza'));
    expect(draft.isRawEditorMode, isFalse);
    expect(draft.sectionCount, 5);
  });

  test('is deterministic across fresh service instances', () async {
    final other = FakeLyricsGenerationService();

    final first = await service.generateLyrics(
      prompt: 'p',
      genre: 'Gqom',
      language: 'isiZulu',
    );
    final second = await other.generateLyrics(
      prompt: 'p',
      genre: 'Gqom',
      language: 'isiZulu',
    );

    expect(second, first);
    expect(service.generationCount, 1);
    expect(other.generationCount, 1);
  });

  test('regeneration advances the variation seed', () async {
    final first = await service.generateLyrics(
      prompt: 'p',
      genre: 'Afro House',
      language: 'Swahili',
    );
    final second = await service.generateLyrics(
      prompt: 'p',
      genre: 'Afro House',
      language: 'Swahili',
    );

    expect(service.generationCount, 2);
    expect(second.rawText, isNot(first.rawText));
    expect(second.sections.first.lines, isNot(first.sections.first.lines));
    expect(second.prompt, first.prompt);
  });

  test('composes each supported language from its own phrase bank', () async {
    final venda = await service.generateLyrics(
      prompt: 'p',
      genre: 'Amapiano',
      language: 'Tshivenḓa',
    );
    final zulu = await service.generateLyrics(
      prompt: 'p',
      genre: 'Amapiano',
      language: 'isiZulu',
    );

    expect(venda.rawText, contains('Rine vha Venda ri khou imba nga u takala'));
    expect(zulu.rawText, contains('Sina phezulu kwezintaba zaseKhathazekile'));
    expect(zulu.sections.first.type, LyricsSectionType.intro);
  });

  test('getCulturalIdioms exposes unmodifiable dialect chips', () {
    for (final language in <String>[
      'Tshivenḓa',
      'isiZulu',
      'Sepedi',
      'Swahili',
    ]) {
      expect(service.getCulturalIdioms(language), isNotEmpty);
    }

    expect(service.getCulturalIdioms('Tsonga'), contains('Light it up'));
    expect(service.getCulturalIdioms('venda'), isNotEmpty);
    expect(
      () => service.getCulturalIdioms('isiZulu').add('extra'),
      throwsUnsupportedError,
    );
  });

  test('unknown languages fall back to the English phrase bank', () async {
    final draft = await service.generateLyrics(
      prompt: 'p',
      genre: 'Maskandi',
      language: 'Klingon',
    );

    expect(
      draft.sections[1].lines.first,
      'Our love is stronger than the dark',
    );
    expect(draft.culturalIdioms, contains('Light it up'));
  });

  test('the genre pack injects ad-libs into the intro', () async {
    final amapiano = await service.generateLyrics(
      prompt: 'p',
      genre: 'Amapiano',
      language: 'isiZulu',
    );
    final maskandi = await service.generateLyrics(
      prompt: 'p',
      genre: 'Maskandi',
      language: 'isiZulu',
    );

    expect(amapiano.sections.first.lines.first, 'Yanos!');
    expect(maskandi.sections.first.lines.first, 'Yebo yes');
  });

  test('honours the injected latency without leaking timers', () async {
    final slow = FakeLyricsGenerationService(
      latency: const Duration(milliseconds: 5),
    );

    final draft = await slow.generateLyrics(
      prompt: 'p',
      genre: 'Afro House',
      language: 'Swahili',
    );

    expect(draft.language, 'Swahili');
    expect(slow.generationCount, 1);
  });
}

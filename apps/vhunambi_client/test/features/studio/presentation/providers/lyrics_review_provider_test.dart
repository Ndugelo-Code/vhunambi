import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/studio/domain/models/lyrics_review_models.dart';
import 'package:vhunambi_client/features/studio/domain/services/i_lyrics_generation_service.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/lyrics_review_provider.dart';

/// T12.3 — Studio lyrics review notifier suite.
void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  LyricsReviewNotifier notifier() =>
      container.read(lyricsReviewProvider.notifier);

  Future<void> load() => notifier().loadGeneratedLyrics(
        prompt: 'heritage anthem',
        genre: 'Amapiano',
        language: 'Tshivenḓa',
      );

  test('starts with no draft and no synthesis payload', () {
    expect(container.read(lyricsReviewProvider), isNull);
    expect(notifier().lyricsForSynthesis, isEmpty);
    expect(notifier().generationCount, 0);
    expect(notifier().isLoading, isFalse);
  });

  test('loadGeneratedLyrics publishes a parsed draft and records the request',
      () async {
    await load();

    final draft = container.read(lyricsReviewProvider)!;

    expect(draft.sections, hasLength(5));
    expect(draft.sections.first.type, LyricsSectionType.intro);
    expect(draft.culturalIdioms, contains('Ndi khou vha fhululedza'));
    expect(notifier().prompt, 'heritage anthem');
    expect(notifier().genre, 'Amapiano');
    expect(notifier().language, 'Tshivenḓa');
    expect(notifier().generationCount, 1);
    expect(notifier().isLoading, isFalse);
    expect(notifier().lyricsForSynthesis, contains('[Chorus]'));
  });

  test('updateSectionLines rewrites the stanza and the raw surface', () async {
    await load();

    final verse = container.read(lyricsReviewProvider)!.sections[1];
    notifier().updateSectionLines(verse.id, <String>['Brand new line']);

    final draft = container.read(lyricsReviewProvider)!;

    expect(draft.sections[1].lines, <String>['Brand new line']);
    expect(draft.rawText, contains('Brand new line'));
    expect(draft.sections[1].header, verse.header);
    expect(draft.sections[0].lines, isNotEmpty);
  });

  test('updateSectionLines ignores unknown stanza ids', () async {
    await load();

    final before = container.read(lyricsReviewProvider)!;
    notifier().updateSectionLines('missing', <String>['nope']);

    expect(container.read(lyricsReviewProvider), before);
  });

  test('insertIdiom appends to the requested stanza', () async {
    await load();

    final verse = container.read(lyricsReviewProvider)!.sections[1];
    notifier().insertIdiom('Yanos!', sectionId: verse.id);

    final draft = container.read(lyricsReviewProvider)!;

    expect(draft.sections[1].lines.last, 'Yanos!');
    expect(draft.sections[1].lines, hasLength(verse.lines.length + 1));
  });

  test('insertIdiom defaults to the last stanza and trims the phrase',
      () async {
    await load();

    notifier().insertIdiom('  Hold the line  ');

    final draft = container.read(lyricsReviewProvider)!;

    expect(draft.sections.last.header, '[Outro]');
    expect(draft.sections.last.lines.last, 'Hold the line');
  });

  test('insertIdiom opens a verse when every stanza was deleted', () async {
    await load();

    notifier().updateRawText('');
    expect(container.read(lyricsReviewProvider)!.sections, isEmpty);

    notifier().insertIdiom('Yanos!');

    final draft = container.read(lyricsReviewProvider)!;

    expect(draft.sections.single.header, '[Verse]');
    expect(draft.sections.single.type, LyricsSectionType.verse);
    expect(draft.sections.single.lines, <String>['Yanos!']);
  });

  test('toggleEditorMode keeps raw markdown and stanza cards in sync',
      () async {
    await load();

    notifier().toggleEditorMode();
    var draft = container.read(lyricsReviewProvider)!;
    expect(draft.isRawEditorMode, isTrue);
    expect(draft.rawText, contains('[Chorus]'));

    notifier().updateRawText('[Verse]\nOnly line here');
    draft = container.read(lyricsReviewProvider)!;
    expect(draft.sections.single.lines, <String>['Only line here']);
    expect(draft.sections.single.header, '[Verse]');

    notifier().toggleEditorMode();
    draft = container.read(lyricsReviewProvider)!;
    expect(draft.isRawEditorMode, isFalse);
    expect(draft.sections.single.lines, <String>['Only line here']);
    expect(draft.rawText, '[Verse]\nOnly line here');
  });

  test('regenerate re-rolls the draft without losing the studio parameters',
      () async {
    await load();
    final before = container.read(lyricsReviewProvider)!;

    await notifier().regenerate();
    final after = container.read(lyricsReviewProvider)!;

    expect(notifier().generationCount, 2);
    expect(after.rawText, isNot(before.rawText));
    expect(after.prompt, before.prompt);
    expect(after.genre, before.genre);
    expect(notifier().genre, 'Amapiano');
  });

  test('regenerate is a no-op before the first request', () async {
    await notifier().regenerate();

    expect(container.read(lyricsReviewProvider), isNull);
    expect(notifier().generationCount, 0);
  });

  test('clear releases the draft payload', () async {
    await load();

    notifier().clear();

    expect(container.read(lyricsReviewProvider), isNull);
    expect(notifier().lyricsForSynthesis, isEmpty);
    expect(notifier().generationCount, 1);
  });

  test('structural edits are no-ops while no draft exists', () {
    notifier().updateSectionLines('section_1', <String>['nope']);
    notifier().insertIdiom('Yanos!');
    notifier().toggleEditorMode();
    notifier().updateRawText('[Verse]\nhi');

    expect(container.read(lyricsReviewProvider), isNull);
  });

  test('a failing synthesis service surfaces the error and resets isLoading',
      () async {
    final failing = ProviderContainer(
      overrides: <Override>[
        lyricsGenerationServiceProvider.overrideWithValue(
          _ThrowingLyricsService(),
        ),
      ],
    );
    addTearDown(failing.dispose);

    await expectLater(
      failing.read(lyricsReviewProvider.notifier).loadGeneratedLyrics(
            prompt: 'p',
            genre: 'Gqom',
            language: 'isiZulu',
          ),
      throwsStateError,
    );

    expect(failing.read(lyricsReviewProvider), isNull);
    expect(failing.read(lyricsReviewProvider.notifier).isLoading, isFalse);
  });
}

/// Minimal failing double proving the notifier never publishes a bad draft.
class _ThrowingLyricsService implements ILyricsGenerationService {
  @override
  Future<LyricsReviewDraft> generateLyrics({
    required String prompt,
    required String genre,
    required String language,
  }) async {
    throw StateError('synthesis worker offline');
  }

  @override
  List<String> getCulturalIdioms(String language) => const <String>[];
}

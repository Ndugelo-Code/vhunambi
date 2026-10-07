import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/studio/data/services/fake_lyrics_generation_service.dart';
import 'package:vhunambi_client/features/studio/domain/models/generation_pipeline_state.dart';
import 'package:vhunambi_client/features/studio/domain/models/lyrics_review_models.dart';
import 'package:vhunambi_client/features/studio/domain/models/studio_form_state.dart';
import 'package:vhunambi_client/features/studio/domain/services/i_generation_socket_service.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/generation_pipeline_providers.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/lyrics_review_provider.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/studio_form_provider.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/lyrics_review_modal.dart';

/// T12.5 — Studio lyrics review cockpit widget suite.
///
/// The cockpit renders stanza cards, so the suite pins a desktop viewport and
/// scrolls before tapping controls that live below the fold.
void _useViewport(WidgetTester tester, [Size size = const Size(1280, 1100)]) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
}

/// Platform-channel calls (haptics, clipboard) observed during a test.
///
/// `SystemChannels.platform` is mocked in [_openReview] so the Mission 1/2
/// micro-interactions never raise `MissingPluginException` and their exact
/// payloads stay assertable.
final List<MethodCall> _platformCalls = <MethodCall>[];

/// Haptic ticks of the given `HapticFeedbackType.*` recorded so far.
Iterable<MethodCall> _hapticCalls(String type) => _platformCalls.where(
      (call) =>
          call.method == 'HapticFeedback.vibrate' && call.arguments == type,
    );

/// Loads a deterministic draft, then opens the cockpit exactly like
/// `StudioActionBar._handleGenerate` does (REQ-LYR-01 → REQ-LYR-02).
Future<ProviderContainer> _openReview(
  WidgetTester tester, {
  Size size = const Size(1280, 1100),
}) async {
  _useViewport(tester, size);

  _platformCalls.clear();
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async {
      _platformCalls.add(call);
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );

  final container = ProviderContainer(
    overrides: <Override>[
      socketServiceProvider.overrideWithValue(_SilentSocketService()),
      lyricsGenerationServiceProvider
          .overrideWithValue(FakeLyricsGenerationService()),
    ],
  );
  addTearDown(container.dispose);

  final form = container.read(studioFormProvider.notifier);
  form.updatePrompt('Amapiano heritage anthem');
  form.setGenre('Amapiano');
  form.setLanguage('Tshivenḓa');
  form.beginLyricsReview();

  await container.read(lyricsReviewProvider.notifier).loadGeneratedLyrics(
        prompt: 'Amapiano heritage anthem',
        genre: 'Amapiano',
        language: 'Tshivenḓa',
      );
  form.markReviewingLyrics();

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => LyricsReviewModal.show(context),
                child: const Text('open review'),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open review'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  return container;
}

void main() {
  testWidgets('renders the generated stanzas with their bracketed headers',
      (tester) async {
    final container = await _openReview(tester);

    expect(find.text('Review Lyrics'), findsOneWidget);
    expect(find.text('Amapiano • Tshivenḓa'), findsOneWidget);
    expect(find.text('AI draft • 5 sections'), findsOneWidget);
    expect(find.text('[Intro]'), findsOneWidget);
    expect(find.text('[Verse 1]'), findsOneWidget);
    expect(find.text('[Chorus]'), findsOneWidget);
    expect(find.text('[Outro]'), findsOneWidget);
    expect(
      container.read(lyricsReviewProvider)?.isRawEditorMode,
      isFalse,
    );

    // The stanza body renders in read-only mode until the edit trigger fires.
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('falls back to a bottom sheet on mobile viewports',
      (tester) async {
    await _openReview(tester, size: const Size(520, 900));

    expect(find.text('Review Lyrics'), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('inline editing rewrites the stanza and the raw markdown',
      (tester) async {
    final container = await _openReview(tester);

    await tester.ensureVisible(find.byKey(const Key('stanza_edit_section_2')));
    await tester.tap(find.byKey(const Key('stanza_edit_section_2')));
    await tester.pump();

    await tester.enterText(
      find.byKey(const Key('stanza_editor_section_2')),
      'Brand new verse line',
    );
    await tester.pump();

    final draft = container.read(lyricsReviewProvider)!;

    expect(draft.sections[1].lines, <String>['Brand new verse line']);
    expect(draft.rawText, contains('Brand new verse line'));
    expect(container.read(lyricsReviewProvider.notifier).hasEdits, isTrue);
  });

  testWidgets('an idiom chip inserts into the first verse with a light haptic '
      'and toast when nothing is focused (Mission 1)', (tester) async {
    final container = await _openReview(tester);

    await tester.ensureVisible(find.byKey(const Key('idiom_chip_0')));
    await tester.tap(find.byKey(const Key('idiom_chip_0')));
    await tester.pump();

    final draft = container.read(lyricsReviewProvider)!;
    final firstVerse = draft.sections
        .firstWhere((section) => section.type == LyricsSectionType.verse);

    // Fallback: no stanza was ever focused → the first verse receives it…
    expect(firstVerse.header, '[Verse 1]');
    expect(firstVerse.lines.last, 'Ndi khou vha fhululedza');
    // …and the last stanza (the old default) stays untouched.
    expect(
      draft.sections.last.lines,
      isNot(contains('Ndi khou vha fhululedza')),
    );

    expect(_hapticCalls('HapticFeedbackType.lightImpact'), hasLength(1));
    expect(find.text('Inserted idiom into lyrics'), findsOneWidget);

    // Drain the toast's 2 s auto-dismiss timer before the test ends.
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('Inserted idiom into lyrics'), findsNothing);
  });

  testWidgets('a focused stanza editor receives the idiom inline (Mission 1)',
      (tester) async {
    final container = await _openReview(tester);

    // Open the [Verse 2] editor (section_4) and give it keyboard focus.
    await tester.ensureVisible(find.byKey(const Key('stanza_edit_section_4')));
    await tester.tap(find.byKey(const Key('stanza_edit_section_4')));
    await tester.pump();

    final editor = find.byKey(const Key('stanza_editor_section_4'));
    await tester.ensureVisible(editor);
    await tester.tap(editor);
    await tester.pump();

    await tester.ensureVisible(find.byKey(const Key('idiom_chip_0')));
    await tester.tap(find.byKey(const Key('idiom_chip_0')));
    await tester.pump();

    final draft = container.read(lyricsReviewProvider)!;
    // The focused stanza wins over the first-verse fallback…
    expect(draft.sections[3].header, '[Verse 2]');
    expect(draft.sections[3].lines.last, 'Ndi khou vha fhululedza');
    expect(
      draft.sections[1].lines,
      isNot(contains('Ndi khou vha fhululedza')),
    );
    // …and the live editor buffer picked the insert up immediately.
    final field = tester.widget<TextFormField>(editor);
    expect(field.controller!.text, contains('Ndi khou vha fhululedza'));

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
  });

  testWidgets('the header copy action compiles bracketed lyrics to the '
      'clipboard (Mission 2)', (tester) async {
    await _openReview(tester);

    await tester.tap(find.byKey(const Key('lyrics_copy')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final clipboardCalls = _platformCalls
        .where((call) => call.method == 'Clipboard.setData')
        .toList();
    expect(clipboardCalls, hasLength(1));

    final args = clipboardCalls.single.arguments as Map;
    final copied = args['text'] as String;
    expect(copied, contains('[Intro]'));
    expect(copied, contains('[Verse 1]'));
    expect(copied, contains('[Chorus]'));
    expect(copied, contains('[Outro]'));

    expect(_hapticCalls('HapticFeedbackType.mediumImpact'), hasLength(1));
    expect(find.text('Lyrics copied to clipboard'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
  });

  testWidgets('the raw editor toggle keeps both surfaces in sync',
      (tester) async {
    final container = await _openReview(tester);

    await tester.ensureVisible(find.byKey(const Key('lyrics_toggle_raw')));
    await tester.tap(find.byKey(const Key('lyrics_toggle_raw')));
    await tester.pump();

    expect(find.byKey(const Key('lyrics_raw_editor')), findsOneWidget);
    expect(find.text('[Intro]'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('lyrics_raw_editor')),
      '[Verse]\nOnly line here',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('lyrics_toggle_raw')));
    await tester.pump();

    expect(container.read(lyricsReviewProvider)!.sections, hasLength(1));
    expect(find.text('[Verse]'), findsOneWidget);
    expect(find.text('Only line here'), findsOneWidget);
  });

  testWidgets('regenerate swaps in a fresh variation', (tester) async {
    final container = await _openReview(tester);
    final before = container.read(lyricsReviewProvider)!;

    await tester.ensureVisible(find.byKey(const Key('lyrics_regenerate')));
    await tester.tap(find.byKey(const Key('lyrics_regenerate')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final after = container.read(lyricsReviewProvider)!;

    expect(container.read(lyricsReviewProvider.notifier).generationCount, 2);
    expect(after.rawText, isNot(before.rawText));
    expect(after.prompt, before.prompt);
  });

  testWidgets('an untouched draft closes without a confirmation prompt',
      (tester) async {
    final container = await _openReview(tester);

    await tester.tap(find.byKey(const Key('lyrics_close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Discard lyric changes?'), findsNothing);
    expect(find.text('Review Lyrics'), findsNothing);
    // REQ-LYR-09 — the draft stays in memory for the next review.
    expect(container.read(lyricsReviewProvider), isNotNull);
  });

  testWidgets('an edited draft asks for confirmation before closing',
      (tester) async {
    final container = await _openReview(tester);

    container
        .read(lyricsReviewProvider.notifier)
        .updateRawText('[Verse]\nEdited line');

    await tester.tap(find.byKey(const Key('lyrics_close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Discard lyric changes?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('lyrics_discard')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Review Lyrics'), findsNothing);
    expect(container.read(lyricsReviewProvider), isNotNull);
    expect(find.text('Discard lyric changes?'), findsNothing);
  });

  testWidgets('approve saves the lyrics, queues synthesis and dismisses',
      (tester) async {
    final container = await _openReview(tester);

    await tester.ensureVisible(find.byKey(const Key('lyrics_approve')));
    await tester.tap(find.byKey(const Key('lyrics_approve')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final form = container.read(studioFormProvider);
    final pipeline = container.read(generationProgressProvider);

    expect(form.phase, GenerationPhase.queued);
    expect(form.customLyrics, contains('[Chorus]'));
    expect(pipeline, isNotNull);
    expect(pipeline?.trackTitle, 'Amapiano heritage anthem');
    expect(pipeline?.genre, 'Amapiano');
    expect(find.text('Review Lyrics'), findsNothing);
  });
}

/// Socket stub that never emits, keeping the suite timer-free.
class _SilentSocketService implements IGenerationSocketService {
  @override
  bool get isConnected => false;

  @override
  Stream<PipelineSocketEvent> connect(String generationId) =>
      const Stream<PipelineSocketEvent>.empty();

  @override
  Future<void> disconnect() async {}
}

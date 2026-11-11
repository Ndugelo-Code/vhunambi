import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/studio/data/services/fake_generation_socket_service.dart';
import 'package:vhunambi_client/features/studio/data/services/fake_stem_download_service.dart';
import 'package:vhunambi_client/features/studio/domain/models/generation_pipeline_state.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/generation_pipeline_providers.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/stem_download_provider.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/generation_pipeline_card.dart';
import 'package:vhunambi_client/features/track/domain/models/track_entity.dart';

/// T10.4 — Live pipeline card widget suite.
///
/// Every pump is explicit: the equalizer and skeleton controllers animate
/// indefinitely, so `pumpAndSettle` is never used here.
TrackEntity _track() => TrackEntity(
      id: 'trk_pipeline_001',
      title: 'rave',
      genre: 'Gqom',
      duration: const Duration(minutes: 3, seconds: 29),
      masterMp3Url: 'https://cdn.vhunambi.com/masters/trk_pipeline_001.mp3',
    );

Future<ProviderContainer> _pumpCard(
  WidgetTester tester, {
  FakeGenerationSocketService? socket,
  VoidCallback? onNewSong,
}) async {
  final container = ProviderContainer(
    overrides: <Override>[
      socketServiceProvider.overrideWithValue(
        socket ??
            FakeGenerationSocketService(
              stepDelay: Duration.zero,
              completedTrack: _track(),
              generatedLyrics: '[Verse 1]\nNight breaks through the haze',
            ),
      ),
      stemDownloadServiceProvider.overrideWithValue(
        FakeStemDownloadService(stepDelay: Duration.zero),
      ),
    ],
  );
  addTearDown(() {
    try {
      container.dispose();
    } catch (_) {}
  });

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: GenerationPipelineCard(onNewSong: onNewSong),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return container;
}

Future<void> _start(ProviderContainer container, {String id = 'gen_1'}) {
  return container.read(generationProgressProvider.notifier).startGeneration(
        generationId: id,
        trackTitle: 'rave',
        genre: 'Gqom',
      );
}

Future<void> _advance(WidgetTester tester, [int frames = 6]) async {
  for (var index = 0; index < frames; index++) {
    await tester.pump(Duration.zero);
  }
}

void main() {
  testWidgets('a null session keeps the shell and hides the steps',
      (tester) async {
    await _pumpCard(tester, onNewSong: () {});

    expect(find.text('Result'), findsOneWidget);
    expect(find.text('New song'), findsOneWidget);
    expect(find.byType(AnimatedSwitcher), findsOneWidget);
    expect(find.text('Starting up...'), findsNothing);
    expect(find.text('Your song is ready!'), findsNothing);
  });

  testWidgets('hides New song action when onNewSong callback is omitted',
      (tester) async {
    await _pumpCard(tester);

    expect(find.text('Result'), findsOneWidget);
    expect(find.text('New song'), findsNothing);
  });

  testWidgets('a generating session renders title, genre, pill and steps',
      (tester) async {
    final container = await _pumpCard(tester);

    await _start(container);
    await tester.pump();

    expect(find.text('rave'), findsOneWidget);
    expect(find.text('Gqom'), findsOneWidget);
    expect(find.text('Generating'), findsOneWidget);
    expect(find.text('Allocating GPU synthesis worker...'), findsOneWidget);
    expect(find.text('Starting up...'), findsOneWidget);
    expect(find.text('Writing lyrics...'), findsOneWidget);
    expect(find.text('Producing the beat...'), findsOneWidget);
    expect(find.text('Your song is ready!'), findsOneWidget);

    container.dispose();
  });

  testWidgets('the active step spins while later steps stay idle',
      (tester) async {
    final container = await _pumpCard(tester);

    await _start(container);
    await tester.pump();

    // Generating pill spinner + the active first step.
    expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
    expect(find.byIcon(Icons.check), findsNothing);

    container.dispose();
  });

  testWidgets('reaching ready completes all four steps and drops the pill',
      (tester) async {
    final container = await _pumpCard(tester);

    await _start(container);
    await _advance(tester);

    expect(find.text('Generating'), findsNothing);
    expect(find.byIcon(Icons.check), findsNWidgets(4));
    expect(find.text('Your song is ready!'), findsWidgets);
  });

  testWidgets('the lyrics shelf appears only when lyrics arrive',
      (tester) async {
    final container = await _pumpCard(tester);

    await _start(container);
    await tester.pump();
    expect(find.text('Show lyrics'), findsNothing);

    await _advance(tester);
    expect(find.text('Show lyrics'), findsOneWidget);

    await tester.tap(find.text('Show lyrics'));
    await tester.pump();

    expect(find.text('Hide lyrics'), findsOneWidget);
    expect(find.textContaining('Night breaks through'), findsOneWidget);
  });

  testWidgets('a failed session renders the error banner and retry CTA',
      (tester) async {
    final container = await _pumpCard(
      tester,
      socket: FakeGenerationSocketService(
        stepDelay: Duration.zero,
        failAtStep: PipelineStep.producingBeat,
      ),
    );

    await _start(container);
    await _advance(tester);

    expect(find.text('Generation failed'), findsOneWidget);
    expect(find.text('Synthesis worker crashed.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Generating'), findsNothing);
  });

  testWidgets('the retry CTA re-binds the pipeline socket', (tester) async {
    final socket = FakeGenerationSocketService(
      stepDelay: Duration.zero,
      failAtStep: PipelineStep.producingBeat,
    );
    final container = await _pumpCard(tester, socket: socket);

    await _start(container);
    await _advance(tester);
    expect(socket.connectCount, 1);

    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(socket.connectCount, 2);

    container.dispose();
  });

  testWidgets('the New song action stays reachable in every state',
      (tester) async {
    var taps = 0;
    final container = await _pumpCard(tester, onNewSong: () => taps++);

    expect(find.text('New song'), findsOneWidget);

    await _start(container);
    await tester.pump();
    await tester.tap(find.text('New song'));
    await tester.pump();

    expect(taps, 1);
    expect(find.text('New song'), findsOneWidget);

    container.dispose();
  });

  testWidgets('the skeleton placeholder renders before the first frame',
      (tester) async {
    final container = await _pumpCard(
      tester,
      socket: FakeGenerationSocketService(
        stepDelay: const Duration(seconds: 2),
        completedTrack: _track(),
      ),
    );

    await _start(container);
    await tester.pump();

    expect(find.byType(GenerationPipelineCard), findsOneWidget);
    expect(find.text('Your song is ready!'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNothing);

    container.dispose();
  });

  testWidgets('the card lays out cleanly on a compact mobile viewport',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final container = await _pumpCard(tester);
    await _start(container);
    await _advance(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(GenerationPipelineCard), findsOneWidget);
  });

  testWidgets('ready track without stemsUrl hides the Stems download button',
      (tester) async {
    final container = await _pumpCard(
      tester,
      socket: FakeGenerationSocketService(
        stepDelay: Duration.zero,
        completedTrack: _track(), // stemsUrl is null by default
      ),
    );

    await _start(container);
    await _advance(tester);

    expect(find.text('Play Master'), findsOneWidget);
    expect(find.byKey(const Key('pipeline_download_stems')), findsNothing);
    expect(find.text('Stems'), findsNothing);
  });

  testWidgets('ready track with stemsUrl renders Stems button and triggers download',
      (tester) async {
    final trackWithStems = TrackEntity(
      id: 'trk_stems_001',
      title: 'rave_stems',
      genre: 'Gqom',
      duration: const Duration(minutes: 3, seconds: 29),
      masterMp3Url: 'https://cdn.vhunambi.com/masters/trk_stems_001.mp3',
      stemsUrl: 'https://cdn.vhunambi.com/stems/trk_stems_001_stems.zip',
    );

    final container = await _pumpCard(
      tester,
      socket: FakeGenerationSocketService(
        stepDelay: Duration.zero,
        completedTrack: trackWithStems,
      ),
    );

    await _start(container);
    await _advance(tester);

    expect(find.text('Play Master'), findsOneWidget);
    expect(find.byKey(const Key('pipeline_download_stems')), findsOneWidget);
    expect(find.text('Stems'), findsOneWidget);

    await tester.tap(find.byKey(const Key('pipeline_download_stems')));
    await tester.pump();

    expect(find.textContaining('Downloading stem bundle for rave_stems'), findsOneWidget);
  });

  testWidgets('ready track renders Create Reel button', (tester) async {
    final container = await _pumpCard(tester);
    await _start(container);
    await _advance(tester);

    expect(find.byKey(const Key('pipeline_create_reel_btn')), findsOneWidget);
    expect(find.text('Create Reel'), findsOneWidget);
  });
}


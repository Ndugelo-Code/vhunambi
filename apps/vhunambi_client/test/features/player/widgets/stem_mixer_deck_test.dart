import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/player/data/services/headless_multi_stem_engine.dart';
import 'package:vhunambi_client/features/player/data/services/stem_mix_bounce_service.dart';
import 'package:vhunambi_client/features/player/domain/models/stem_mixer_state.dart';
import 'package:vhunambi_client/features/player/presentation/providers/multi_stem_audio_provider.dart';
import 'package:vhunambi_client/features/player/presentation/providers/stem_mixer_provider.dart';
import 'package:vhunambi_client/features/player/presentation/widgets/stem_mixer_deck.dart';

void main() {
  testWidgets('renders 4 channel strips with faders and M/S controls',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final fakeEngine = HeadlessMultiStemEngine(hasRealStems: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          multiStemAudioEngineProvider.overrideWithValue(fakeEngine),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: StemMixerDeck()),
        ),
      ),
    );

    expect(find.text('Pocket Stem Mixer'), findsOneWidget);
    expect(find.text('Master Bus DSP'), findsOneWidget);
    expect(find.byKey(const Key('stem_mixer_play_pause_btn')), findsOneWidget);
    for (final type in StemType.values) {
      expect(find.byKey(Key('fader_${type.name}')), findsOneWidget);
      expect(find.byKey(Key('pan_${type.name}')), findsOneWidget);
      expect(find.byKey(Key('mute_${type.name}')), findsOneWidget);
      expect(find.byKey(Key('solo_${type.name}')), findsOneWidget);
    }
  });

  testWidgets('master-only mode shows banner and disables channel controls',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final fakeEngine = HeadlessMultiStemEngine(hasRealStems: false);

    final container = ProviderContainer(
      overrides: [
        multiStemAudioEngineProvider.overrideWithValue(fakeEngine),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: StemMixerDeck()),
        ),
      ),
    );

    // Banner is visible
    expect(find.byKey(const Key('stem_master_only_banner')), findsOneWidget);
    expect(find.text('Master Only'), findsOneWidget);

    // Tapping mute does not alter channel state because controls are disabled
    await tester.tap(find.byKey(const Key('mute_vocals')));
    await tester.pump();
    expect(
      container.read(stemMixerProvider).channelFor(StemType.vocals).isMuted,
      isFalse,
    );
  });

  testWidgets('stems active mode enables channel controls and toggles M/S',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final fakeEngine = HeadlessMultiStemEngine(hasRealStems: true);

    final container = ProviderContainer(
      overrides: [
        multiStemAudioEngineProvider.overrideWithValue(fakeEngine),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: StemMixerDeck()),
        ),
      ),
    );

    // Banner is not displayed
    expect(find.byKey(const Key('stem_master_only_banner')), findsNothing);

    await tester.tap(find.byKey(const Key('mute_vocals')));
    await tester.pump();
    expect(
      container.read(stemMixerProvider).channelFor(StemType.vocals).isMuted,
      isTrue,
    );

    await tester.tap(find.byKey(const Key('solo_drums')));
    await tester.pump();
    expect(
      container.read(stemMixerProvider).channelFor(StemType.drums).isSolo,
      isTrue,
    );
  });

  testWidgets('measured drift badge displays sync status', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final fakeEngine = HeadlessMultiStemEngine(
      hasRealStems: true,
      measuredDrift: const Duration(milliseconds: 14),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          multiStemAudioEngineProvider.overrideWithValue(fakeEngine),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: StemMixerDeck()),
        ),
      ),
    );

    expect(find.text('±14ms Sync'), findsOneWidget);
  });

  testWidgets('play/pause button toggles multi-stem engine playback',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final fakeEngine = HeadlessMultiStemEngine(hasRealStems: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          multiStemAudioEngineProvider.overrideWithValue(fakeEngine),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: StemMixerDeck()),
        ),
      ),
    );

    expect(fakeEngine.isPlaying, isFalse);

    await tester.tap(find.byKey(const Key('stem_mixer_play_pause_btn')));
    await tester.pump();
    expect(fakeEngine.isPlaying, isTrue);

    await tester.tap(find.byKey(const Key('stem_mixer_play_pause_btn')));
    await tester.pump();
    expect(fakeEngine.isPlaying, isFalse);
  });

  testWidgets('tapping a preset chip updates master DSP', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final fakeEngine = HeadlessMultiStemEngine(hasRealStems: true);

    final container = ProviderContainer(
      overrides: [
        multiStemAudioEngineProvider.overrideWithValue(fakeEngine),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: StemMixerDeck()),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('preset_Amapiano Club Banger')));
    await tester.pump();

    expect(
      container.read(stemMixerProvider).masterDsp.logDrumSaturation,
      0.85,
    );
  });

  testWidgets('tapping Preview bounce renders a master file and shows snackbar',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final fakeEngine = HeadlessMultiStemEngine(hasRealStems: true);
    final inMemoryBounce = StemMixBounceService(writer: (path, bytes) async {});

    final container = ProviderContainer(
      overrides: [
        multiStemAudioEngineProvider.overrideWithValue(fakeEngine),
        stemMixerProvider.overrideWith((ref) => StemMixerNotifier(
          bounceService: inMemoryBounce,
          outputDirectoryResolver: () async => '/test/bounces',
        )),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: StemMixerDeck()),
        ),
      ),
    );

    expect(find.text('Preview bounce'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mixer_bounce_btn')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(container.read(stemMixerProvider).lastBouncedAudioPath, isNotNull);
    expect(find.textContaining('Preview bounce created'), findsOneWidget);
  });

  testWidgets('Tier 2: auto-hydrates stems into multi-stem engine and exits master-only mode',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final fakeEngine = HeadlessMultiStemEngine(hasRealStems: false);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          multiStemAudioEngineProvider.overrideWithValue(fakeEngine),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: StemMixerDeck(
              title: 'Tier 2 Cloud Stems',
              masterUrl: 'https://r2.vhunambi.com/audio/master.mp3',
              stemUrls: {
                StemType.vocals: 'https://r2.vhunambi.com/audio/vocals.mp3',
                StemType.drums: 'https://r2.vhunambi.com/audio/drums.mp3',
                StemType.bass: 'https://r2.vhunambi.com/audio/bass.mp3',
                StemType.melody: 'https://r2.vhunambi.com/audio/melodic.mp3',
              },
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(fakeEngine.hasRealStems, isTrue);
    expect(find.byKey(const Key('stem_master_only_banner')), findsNothing);
    expect(find.textContaining('Sync'), findsOneWidget);
  });
}

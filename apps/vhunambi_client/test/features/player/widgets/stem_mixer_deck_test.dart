import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/player/domain/models/stem_mixer_state.dart';
import 'package:vhunambi_client/features/player/presentation/providers/stem_mixer_provider.dart';
import 'package:vhunambi_client/features/player/presentation/widgets/stem_mixer_deck.dart';

void main() {
  testWidgets('renders 4 channel strips with faders and M/S controls',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: StemMixerDeck()),
        ),
      ),
    );

    expect(find.text('Pocket Stem Mixer'), findsOneWidget);
    expect(find.text('Master Bus DSP'), findsOneWidget);
    for (final type in StemType.values) {
      expect(find.byKey(Key('fader_${type.name}')), findsOneWidget);
      expect(find.byKey(Key('pan_${type.name}')), findsOneWidget);
      expect(find.byKey(Key('mute_${type.name}')), findsOneWidget);
      expect(find.byKey(Key('solo_${type.name}')), findsOneWidget);
    }
  });

  testWidgets('tapping mute and solo toggles channel state', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer();
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

  testWidgets('tapping a preset chip updates master DSP', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer();
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

  testWidgets('tapping Bounce Master Mix renders a master file', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer();
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

    await tester.tap(find.byKey(const Key('mixer_bounce_btn')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(container.read(stemMixerProvider).lastBouncedAudioPath, isNotNull);
    // Drain the bounce SnackBar timer.
    await tester.pump(const Duration(seconds: 5));
  });
}

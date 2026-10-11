import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/heritage_crate_provider.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/mpc_slicer_deck.dart';

void main() {
  testWidgets('renders 8 MPC pads', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: MpcSlicerDeck()),
        ),
      ),
    );

    for (var i = 0; i < 8; i++) {
      expect(find.byKey(Key('mpc_pad_$i')), findsOneWidget);
    }
    expect(find.text('Mbira DzaVadzimu'), findsOneWidget);
  });

  testWidgets('tapping a pad triggers activation', (tester) async {
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
          home: const Scaffold(body: MpcSlicerDeck()),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('mpc_pad_3')));
    await tester.pump();

    expect(container.read(mpcSlicerProvider).pads[3].isTriggered, isTrue);
    expect(container.read(mpcSlicerProvider).selectedPadIndex, 3);
  });

  testWidgets('dragging the pitch slider adjusts semitones', (tester) async {
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
          home: const Scaffold(body: MpcSlicerDeck()),
        ),
      ),
    );

    // Selected pad is index 0 by default.
    await tester.drag(find.byKey(const Key('mpc_pitch_slider')),
        const Offset(200, 0));
    await tester.pump();

    expect(
      container.read(mpcSlicerProvider).pads[0].pitchShiftSemitones,
      isNot(0),
    );
  });

  testWidgets('tapping the reverse toggle flips the reverse flag',
      (tester) async {
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
          home: const Scaffold(body: MpcSlicerDeck()),
        ),
      ),
    );

    expect(container.read(mpcSlicerProvider).pads[0].isReversed, isFalse);
    await tester.tap(find.byKey(const Key('mpc_reverse_toggle')));
    await tester.pump();
    expect(container.read(mpcSlicerProvider).pads[0].isReversed, isTrue);
  });

  testWidgets('Send to Stem Mixer bounces the chop kit', (tester) async {
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
          home: const Scaffold(body: MpcSlicerDeck()),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('mpc_send_to_mixer')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(container.read(mpcSlicerProvider).lastBouncedChopPath, isNotNull);
    // Drain the celebration SnackBar timer.
    await tester.pump(const Duration(seconds: 5));
  });
}

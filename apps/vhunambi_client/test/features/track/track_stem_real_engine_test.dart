import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/player/domain/models/stem_mixer_state.dart';
import 'package:vhunambi_client/features/player/presentation/providers/stem_mixer_provider.dart';
import 'package:vhunambi_client/features/track/presentation/views/track_detail_view.dart';
import 'package:vhunambi_client/features/track/presentation/widgets/stem_separation_lab.dart';

void main() {
  testWidgets(
    'StemSeparationLab binds to StemMixerNotifier for live mute and solo',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 2800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final container = ProviderContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const TrackDetailView(trackId: 'seed-01'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Separate stems
      final separateBtn = find.text('Separate');
      expect(separateBtn, findsOneWidget);
      await tester.tap(separateBtn);

      // Pump FSM steps
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpAndSettle();

      // 2. Stems are ready
      expect(find.text('Vocals'), findsOneWidget);
      expect(find.text('Drums'), findsOneWidget);

      // Check initial mute state in StemMixerNotifier
      final initialVocals = container
          .read(stemMixerProvider)
          .channels
          .firstWhere((c) => c.type == StemType.vocals);
      expect(initialVocals.isMuted, isFalse);

      // 3. Tap Mute on Vocals stem card
      final muteButtons = find.descendant(
        of: find.byType(StemSeparationLab),
        matching: find.byType(IconButton),
      );
      // First icon button in stem card is Mute
      await tester.tap(muteButtons.at(0));
      await tester.pumpAndSettle();

      // StemMixerNotifier must reflect muted vocals
      final updatedVocals = container
          .read(stemMixerProvider)
          .channels
          .firstWhere((c) => c.type == StemType.vocals);
      expect(updatedVocals.isMuted, isTrue);

      // 4. Tap Solo on Drums stem card
      final soloButtons = find.descendant(
        of: find.byType(StemSeparationLab),
        matching: find.text('SOLO'),
      );
      await tester.tap(soloButtons.at(1));
      await tester.pumpAndSettle();

      // StemMixerNotifier must reflect soloed drums
      final updatedDrums = container
          .read(stemMixerProvider)
          .channels
          .firstWhere((c) => c.type == StemType.drums);
      expect(updatedDrums.isSolo, isTrue);

      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );
}

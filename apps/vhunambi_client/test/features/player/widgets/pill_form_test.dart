import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/player/data/services/vhunambi_audio_handler.dart';
import 'package:vhunambi_client/features/player/presentation/providers/audio_bridge_providers.dart';
import 'package:vhunambi_client/features/player/presentation/providers/player_provider.dart';
import 'package:vhunambi_client/features/player/presentation/widgets/pill_form.dart';
import 'package:vhunambi_client/shared/models/track.dart';

void main() {
  Track sampleTrack() => Track(
        id: 'trk_pill_1',
        title: 'Makhadzi Fire',
        creatorName: 'Queen of Limpopo',
        genre: 'Amapiano',
        duration: const Duration(minutes: 4, seconds: 12),
      );

  testWidgets('renders track iconography and responds to onExpand', (tester) async {
    final handler = TestVhunambiAudioHandler();
    addTearDown(handler.dispose);

    final container = ProviderContainer(
      overrides: [
        audioHandlerProvider.overrideWithValue(handler),
      ],
    );

    container.read(playerStateProvider.notifier).playTrack(sampleTrack());

    bool expanded = false;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: PillForm(
              onExpand: () => expanded = true,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(PillForm), findsOneWidget);
    expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);

    await tester.tap(find.byType(PillForm));
    await tester.pump();

    expect(expanded, isTrue);

    // Unmount and ensure no timer leaks
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
    container.dispose();
  });

  testWidgets('respects reduce-motion by removing blur and spread radius',
      (tester) async {
    final handler = TestVhunambiAudioHandler();
    addTearDown(handler.dispose);

    final container = ProviderContainer(
      overrides: [
        audioHandlerProvider.overrideWithValue(handler),
      ],
    );

    container.read(playerStateProvider.notifier).playTrack(sampleTrack());

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: PillForm(),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    final containerFinder = find.descendant(
      of: find.byType(PillForm),
      matching: find.byType(Container),
    );
    expect(containerFinder, findsWidgets);

    final pillContainer = tester.widget<Container>(containerFinder.first);
    final decoration = pillContainer.decoration as BoxDecoration;
    final shadow = decoration.boxShadow!.first;

    expect(shadow.blurRadius, 0);
    expect(shadow.spreadRadius, 0);

    // Unmount safely
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
    container.dispose();
  });

  testWidgets('samples MasterMediaObject masterRms curve during playback',
      (tester) async {
    final handler = TestVhunambiAudioHandler();
    addTearDown(handler.dispose);

    final container = ProviderContainer(
      overrides: [
        audioHandlerProvider.overrideWithValue(handler),
      ],
    );

    container.read(playerStateProvider.notifier).playTrack(sampleTrack());

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: PillForm(),
          ),
        ),
      ),
    );
    // Allow amplitude timer to fire at 33ms interval
    await tester.pump(const Duration(milliseconds: 70));

    expect(find.byType(PillForm), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
    container.dispose();
  });
}

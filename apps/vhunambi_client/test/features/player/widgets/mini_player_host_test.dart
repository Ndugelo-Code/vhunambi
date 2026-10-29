import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/player/data/services/vhunambi_audio_handler.dart';
import 'package:vhunambi_client/features/player/presentation/providers/audio_bridge_providers.dart';
import 'package:vhunambi_client/features/player/presentation/providers/mini_player_controller.dart';
import 'package:vhunambi_client/features/player/presentation/providers/player_provider.dart';
import 'package:vhunambi_client/features/player/presentation/widgets/card_form.dart';
import 'package:vhunambi_client/features/player/presentation/widgets/mini_player_host.dart';
import 'package:vhunambi_client/features/player/presentation/widgets/mobile_mini_player.dart';
import 'package:vhunambi_client/features/player/presentation/widgets/pill_form.dart';
import 'package:vhunambi_client/shared/models/track.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  Track sampleTrack() => Track(
        id: 'trk_test_1',
        title: 'Shibabu Beats',
        creatorName: 'Tsonga Electro King',
        genre: 'Shangaan Electro',
        duration: const Duration(minutes: 3, seconds: 45),
      );

  testWidgets('renders transparent Material wrapper', (tester) async {
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
            body: MiniPlayerHost(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final materialFinder = find.descendant(
      of: find.byType(MiniPlayerHost),
      matching: find.byType(Material),
    );
    expect(materialFinder, findsWidgets);

    final material = tester.widget<Material>(materialFinder.first);
    expect(material.type, MaterialType.transparency);

    container.dispose();
  });

  testWidgets('switches between Bar, Card, and Pill forms based on controller',
      (tester) async {
    final handler = TestVhunambiAudioHandler();
    addTearDown(handler.dispose);

    final controller = MiniPlayerController();
    await controller.loadState();

    final container = ProviderContainer(
      overrides: [
        audioHandlerProvider.overrideWithValue(handler),
        miniPlayerControllerProvider.overrideWith((ref) => controller),
      ],
    );

    container.read(playerStateProvider.notifier).playTrack(sampleTrack());

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: MiniPlayerHost(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Default form is Bar
    expect(find.byType(MobileMiniPlayer), findsOneWidget);
    expect(find.byType(CardForm), findsNothing);
    expect(find.byType(PillForm), findsNothing);

    // Switch to Card form
    controller.setForm(PlayerForm.card);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(MobileMiniPlayer), findsNothing);
    expect(find.byType(CardForm), findsOneWidget);
    expect(find.byType(PillForm), findsNothing);

    // Switch to Pill form
    controller.setForm(PlayerForm.pill);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(MobileMiniPlayer), findsNothing);
    expect(find.byType(CardForm), findsNothing);
    expect(find.byType(PillForm), findsOneWidget);

    container.dispose();
  });

  testWidgets('hides when track is dismissed', (tester) async {
    final handler = TestVhunambiAudioHandler();
    addTearDown(handler.dispose);

    final container = ProviderContainer(
      overrides: [
        audioHandlerProvider.overrideWithValue(handler),
      ],
    );

    container.read(playerStateProvider.notifier).dismiss();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: MiniPlayerHost(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(MobileMiniPlayer), findsNothing);
    expect(find.byType(CardForm), findsNothing);
    expect(find.byType(PillForm), findsNothing);

    container.dispose();
  });
}

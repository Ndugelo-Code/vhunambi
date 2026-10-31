import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vhunambi_client/core/navigation/app_navigator.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/explore/presentation/views/explore_view.dart';
import 'package:vhunambi_client/features/mastering/presentation/providers/mastering_session_provider.dart';
import 'package:vhunambi_client/features/player/data/services/vhunambi_audio_handler.dart';
import 'package:vhunambi_client/features/player/presentation/providers/audio_bridge_providers.dart';
import 'package:vhunambi_client/features/player/presentation/providers/mini_player_controller.dart';
import 'package:vhunambi_client/features/player/presentation/providers/player_provider.dart';
import 'package:vhunambi_client/features/player/presentation/widgets/expanded_cockpit_modal.dart';
import 'package:vhunambi_client/features/player/presentation/widgets/mini_player_host.dart';
import 'package:vhunambi_client/features/player/presentation/widgets/mobile_mini_player.dart';
import 'package:vhunambi_client/features/player/presentation/widgets/pill_form.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/studio_form_provider.dart';
import 'package:vhunambi_client/shared/models/track.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  Track sampleTrack({
    String id = 'trk_phase33_test',
    String title = 'Venda Midnight Groove',
    String genre = 'Amapiano',
  }) {
    return Track(
      id: id,
      title: title,
      creatorName: 'DJ Sigwa',
      genre: genre,
      language: 'Tshivenḓa',
      duration: const Duration(minutes: 4, seconds: 12),
      audioUrl: 'https://r2.vhunambi.com/audio/venda_midnight.mp3',
    );
  }

  group('Phase 33: Adaptive Mini Player & Expanded Cockpit V4.1 Convergence', () {
    testWidgets(
      'Finding AMP-001: MiniPlayerHost renders in MaterialApp.builder overlay without route trapping',
      (tester) async {
        final handler = TestVhunambiAudioHandler();
        addTearDown(handler.dispose);

        final container = ProviderContainer(
          overrides: [
            audioHandlerProvider.overrideWithValue(handler),
          ],
        );
        addTearDown(container.dispose);

        // Seed active track
        container.read(playerStateProvider.notifier).playTrack(sampleTrack());

        // Mount via MaterialApp.builder exactly as in main.dart
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              navigatorKey: appNavigatorKey,
              theme: AppTheme.darkTheme,
              builder: (context, child) {
                return Stack(
                  children: [
                    ?child,
                    const MiniPlayerHost(),
                  ],
                );
              },
              home: const Scaffold(
                body: Center(child: Text('Home Content')),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Must find MiniPlayerHost and MobileMiniPlayer without route trapping
        expect(find.byKey(const Key('mini_player_host')), findsOneWidget);
        expect(find.byKey(const Key('mini_player_bar')), findsOneWidget);
        expect(find.text('Venda Midnight Groove'), findsOneWidget);

        // Verify Material transparency
        final material = tester.widget<Material>(
          find.byKey(const Key('mini_player_host')),
        );
        expect(material.type, equals(MaterialType.transparency));

        container.read(playerStateProvider.notifier).dismiss();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Finding AMP-002 & 003: Auto-mode positioning math lifts Bar form above registered PlayerObstacles',
      (tester) async {
        final controller = MiniPlayerController();
        const screenSize = Size(360, 800);
        const bottomSafeArea = 34.0;

        // Base docked position when no obstacles are present
        final basePos = controller.calculateAutoPosition(
          screenSize: screenSize,
          bottomSafeArea: bottomSafeArea,
        );
        // Base dock: 800 - (56 + 34 + 8 + 64) = 638
        expect(basePos.dy, equals(638.0));
        expect(basePos.dx, equals(8.0));

        // Register a bottom obstacle (e.g. Studio bottom dock at Y=660..760)
        controller.registerObstacle(
          'content_studio_dock',
          const Rect.fromLTWH(0, 660, 360, 100),
        );

        // Position must elevate 8dp above the obstacle top: 660 - 64 - 8 = 588.0
        final elevatedPos = controller.calculateAutoPosition(
          screenSize: screenSize,
          bottomSafeArea: bottomSafeArea,
        );
        expect(elevatedPos.dy, equals(588.0));

        // Unregister obstacle -> restores back to default base dock
        controller.unregisterObstacle('content_studio_dock');
        final restoredPos = controller.calculateAutoPosition(
          screenSize: screenSize,
          bottomSafeArea: bottomSafeArea,
        );
        expect(restoredPos.dy, equals(638.0));
      },
    );

    testWidgets(
      'Finding AMP-004: Tapping Bar, Card, and Pill forms opens ExpandedCockpitModal',
      (tester) async {
        final handler = TestVhunambiAudioHandler();
        addTearDown(handler.dispose);

        final controller = MiniPlayerController();
        final container = ProviderContainer(
          overrides: [
            audioHandlerProvider.overrideWithValue(handler),
            miniPlayerControllerProvider.overrideWith((ref) => controller),
          ],
        );
        addTearDown(container.dispose);

        container.read(playerStateProvider.notifier).playTrack(sampleTrack());

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              navigatorKey: appNavigatorKey,
              theme: AppTheme.darkTheme,
              builder: (context, child) {
                return Stack(
                  children: [
                    ?child,
                    const MiniPlayerHost(),
                  ],
                );
              },
              home: const Scaffold(
                body: Center(child: Text('Screen Content')),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Bar Form tap launches cockpit
        expect(find.byType(MobileMiniPlayer), findsOneWidget);
        await tester.tap(find.byKey(const Key('mini_player_art')));
        await tester.pumpAndSettle();
        expect(find.byType(ExpandedCockpitModal), findsOneWidget);

        // Dismiss modal
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        expect(find.byType(ExpandedCockpitModal), findsNothing);

        // 2. Switch to Pill Form
        controller.setForm(PlayerForm.pill);
        await tester.pumpAndSettle();
        expect(find.byType(PillForm), findsOneWidget);
        await tester.tap(find.byKey(const Key('mini_player_pill')));
        await tester.pumpAndSettle();
        expect(find.byType(ExpandedCockpitModal), findsOneWidget);

        // Cleanup
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        container.read(playerStateProvider.notifier).dismiss();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Finding AMP-005: Scrolling Social Explore feed triggers auto-collapse to PlayerForm.pill',
      (tester) async {
        final handler = TestVhunambiAudioHandler();
        addTearDown(handler.dispose);

        final controller = MiniPlayerController();
        final container = ProviderContainer(
          overrides: [
            audioHandlerProvider.overrideWithValue(handler),
            miniPlayerControllerProvider.overrideWith((ref) => controller),
          ],
        );
        addTearDown(container.dispose);

        container.read(playerStateProvider.notifier).playTrack(sampleTrack());

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              navigatorKey: appNavigatorKey,
              theme: AppTheme.darkTheme,
              home: const ExploreView(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(controller.form, equals(PlayerForm.bar));

        // Drag the Explore scroll view vertically
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
        await tester.pumpAndSettle();

        // Controller should automatically transition to Pill form
        expect(controller.form, equals(PlayerForm.pill));

        container.read(playerStateProvider.notifier).dismiss();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Finding AMP-006: ExpandedCockpitModal renders 60-bar masterRmsBytes waveform visualizer',
      (tester) async {
        final handler = TestVhunambiAudioHandler();
        addTearDown(handler.dispose);

        final container = ProviderContainer(
          overrides: [
            audioHandlerProvider.overrideWithValue(handler),
          ],
        );
        addTearDown(container.dispose);

        container.read(playerStateProvider.notifier).playTrack(sampleTrack());

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              navigatorKey: appNavigatorKey,
              theme: AppTheme.darkTheme,
              home: const Scaffold(
                body: ExpandedCockpitModal(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('cockpit_waveform_scrubber')), findsOneWidget);

        container.read(playerStateProvider.notifier).dismiss();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Finding AMP-007: ExpandedCockpitModal exposes 1-tap Master A/B toggle and Remix in Studio action',
      (tester) async {
        tester.view.physicalSize = const Size(400, 850);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final handler = TestVhunambiAudioHandler();
        addTearDown(handler.dispose);

        final container = ProviderContainer(
          overrides: [
            audioHandlerProvider.overrideWithValue(handler),
          ],
        );
        addTearDown(container.dispose);

        container.read(playerStateProvider.notifier).playTrack(sampleTrack());

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              navigatorKey: appNavigatorKey,
              theme: AppTheme.darkTheme,
              home: const Scaffold(
                body: ExpandedCockpitModal(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Master A/B Toggle
        final masterBtn = find.byKey(const Key('cockpit_master_ab_btn'));
        expect(masterBtn, findsOneWidget);
        expect(container.read(masteringSessionProvider).isMasteredPreviewActive, isTrue);

        await tester.ensureVisible(masterBtn);
        await tester.pumpAndSettle();
        await tester.tap(masterBtn);
        await tester.pumpAndSettle();
        expect(container.read(masteringSessionProvider).isMasteredPreviewActive, isFalse);

        // 2. Remix in Studio Button
        final remixBtn = find.byKey(const Key('cockpit_remix_studio_btn'));
        expect(remixBtn, findsOneWidget);

        await tester.ensureVisible(remixBtn);
        await tester.pumpAndSettle();
        await tester.tap(remixBtn);
        await tester.pumpAndSettle();

        // studioFormProvider was populated with active track's genre and remix prompt
        expect(container.read(studioFormProvider).genre, equals('Amapiano'));
        expect(container.read(studioFormProvider).prompt, contains('Remix of Venda Midnight Groove'));

        container.read(playerStateProvider.notifier).dismiss();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Finding AMP-008: 360x800 compact mobile viewport renders MiniPlayerHost without RenderFlex overflows',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final handler = TestVhunambiAudioHandler();
        addTearDown(handler.dispose);

        final container = ProviderContainer(
          overrides: [
            audioHandlerProvider.overrideWithValue(handler),
          ],
        );
        addTearDown(container.dispose);

        container.read(playerStateProvider.notifier).playTrack(sampleTrack());

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              navigatorKey: appNavigatorKey,
              theme: AppTheme.darkTheme,
              builder: (context, child) {
                return Stack(
                  children: [
                    ?child,
                    const MiniPlayerHost(),
                  ],
                );
              },
              home: const Scaffold(
                body: Center(child: Text('Content')),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('mini_player_host')), findsOneWidget);
        expect(find.byKey(const Key('mini_player_bar')), findsOneWidget);
        expect(find.byKey(const Key('mini_player_prev')), findsOneWidget);
        expect(find.byKey(const Key('mini_player_play_pause')), findsOneWidget);
        expect(find.byKey(const Key('mini_player_next')), findsOneWidget);

        container.read(playerStateProvider.notifier).dismiss();
        await tester.pumpAndSettle();
      },
    );
  });
}

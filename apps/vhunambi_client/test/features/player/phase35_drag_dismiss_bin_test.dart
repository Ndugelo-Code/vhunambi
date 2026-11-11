import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vhunambi_client/core/design_system/tokens/app_icons.dart';
import 'package:vhunambi_client/core/navigation/app_navigator.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/onboarding/domain/models/onboarding_models.dart';
import 'package:vhunambi_client/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:vhunambi_client/features/onboarding/presentation/views/splash_view.dart';
import 'package:vhunambi_client/features/player/data/services/vhunambi_audio_handler.dart';
import 'package:vhunambi_client/features/player/presentation/providers/audio_bridge_providers.dart';
import 'package:vhunambi_client/features/player/presentation/providers/mini_player_controller.dart';
import 'package:vhunambi_client/features/player/presentation/providers/player_provider.dart';
import 'package:vhunambi_client/features/player/presentation/widgets/mini_player_host.dart';
import 'package:vhunambi_client/features/player/presentation/widgets/mobile_mini_player.dart';
import 'package:vhunambi_client/features/player/presentation/widgets/pill_form.dart';
import 'package:vhunambi_client/shared/models/track.dart';

class _CompletedOnboardingNotifier extends OnboardingNotifier {
  _CompletedOnboardingNotifier() {
    state = const OnboardingState(hasCompletedOnboarding: true);
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  Track sampleTrack() => Track(
        id: 'trk_bin_test_1',
        title: 'Mapungubwe Gold',
        creatorName: 'Tsonga Electro King',
        genre: 'Amapiano',
        duration: const Duration(minutes: 4, seconds: 12),
      );

  group('Phase 35: Drag to Bin Dismiss & 2-Form Architecture Tests', () {
    test('PlayerForm enum only has bar and pill', () {
      expect(PlayerForm.values.length, 2);
      expect(PlayerForm.values, containsAll([PlayerForm.bar, PlayerForm.pill]));
    });

    test('Controller handles drag state, anchor position and resetToDock', () {
      final controller = MiniPlayerController();
      expect(controller.isDragging, isFalse);
      expect(controller.mode, PlayerMode.auto);

      // Start drag switches to manual mode
      controller.startDrag(const Offset(100, 300));
      expect(controller.isDragging, isTrue);
      expect(controller.mode, PlayerMode.manual);
      expect(controller.position, const Offset(100, 300));

      // Update drag updates position
      controller.updateDrag(const Offset(120, 350));
      expect(controller.position, const Offset(120, 350));

      // Reset to dock restores bar form and auto mode
      controller.resetToDock(const Size(400, 800));
      expect(controller.form, PlayerForm.bar);
      expect(controller.mode, PlayerMode.auto);
      expect(controller.isDragging, isFalse);
    });

    testWidgets('Bin drop target emerges during drag and dismisses on drop',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final handler = TestVhunambiAudioHandler();
      addTearDown(handler.dispose);

      final controller = MiniPlayerController();
      final container = ProviderContainer(
        overrides: [
          audioHandlerProvider.overrideWithValue(handler),
          miniPlayerControllerProvider.overrideWith((ref) => controller),
          isSplashActiveProvider.overrideWith((ref) => false),
          onboardingStateProvider.overrideWith(
            (ref) => _CompletedOnboardingNotifier(),
          ),
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
              body: Stack(
                children: [
                  Center(child: Text('Content')),
                  MiniPlayerHost(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial state: mini player is visible in Bar form, bin is NOT visible
      expect(find.byType(MobileMiniPlayer), findsOneWidget);
      expect(find.byIcon(AppIcons.trash), findsNothing);

      // Long press mini player to activate drag
      final gesture = await tester.startGesture(const Offset(200, 700));
      await tester.pump(const Duration(milliseconds: 600));

      // Drag mode activated: Bin target is now visible at bottom center
      expect(controller.isDragging, isTrue);
      expect(find.byIcon(AppIcons.trash), findsOneWidget);

      // Drag mini player directly onto the bottom-center bin target
      // Screen height is 800, bin target is centered at y ≈ 700-750
      await gesture.moveTo(const Offset(200, 720));
      await tester.pump(const Duration(milliseconds: 50));

      // Release inside the bin boundary: dismisses mini player
      await gesture.up();
      await tester.pumpAndSettle();

      // Audio player is dismissed and mini player is killed
      expect(container.read(playerStateProvider).hasActiveTrack, isFalse);
      expect(find.byType(MobileMiniPlayer), findsNothing);
      expect(find.byIcon(AppIcons.trash), findsNothing);

      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('Mini player buttons use soft rounded Phosphor icons',
        (tester) async {
      final handler = TestVhunambiAudioHandler();
      addTearDown(handler.dispose);

      final container = ProviderContainer(
        overrides: [
          audioHandlerProvider.overrideWithValue(handler),
          isSplashActiveProvider.overrideWith((ref) => false),
          onboardingStateProvider.overrideWith(
            (ref) => _CompletedOnboardingNotifier(),
          ),
        ],
      );
      addTearDown(container.dispose);

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
      await tester.pumpAndSettle();

      // MobileMiniPlayer has soft circular previous, play/pause and next buttons
      final prevBtn = tester.widget<IconButton>(find.byKey(const Key('mini_player_prev')));
      expect(prevBtn.style?.shape?.resolve({}), isA<CircleBorder>());

      final nextBtn = tester.widget<IconButton>(find.byKey(const Key('mini_player_next')));
      expect(nextBtn.style?.shape?.resolve({}), isA<CircleBorder>());

      final playPauseBtn = tester.widget<IconButton>(find.byKey(const Key('mini_player_play_pause')));
      expect(playPauseBtn.style?.shape?.resolve({}), isA<CircleBorder>());

      // Switch to PillForm
      container.read(miniPlayerControllerProvider.notifier).setForm(PlayerForm.pill);
      await tester.pumpAndSettle();

      expect(find.byType(PillForm), findsOneWidget);
      expect(find.byType(PhosphorIcon), findsWidgets);

      container.read(playerStateProvider.notifier).dismiss();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/navigation/navigation_providers.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/mastering/presentation/providers/mastering_session_provider.dart';
import 'package:vhunambi_client/features/notifications/domain/models/notification_enums.dart';
import 'package:vhunambi_client/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:vhunambi_client/features/player/presentation/providers/player_provider.dart';
import 'package:vhunambi_client/features/player/presentation/widgets/expanded_cockpit_modal.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/studio_form_provider.dart';
import 'package:vhunambi_client/shared/models/track.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testTrack = const Track(
    id: 'trk_cockpit_01',
    title: 'Durban Midnight Groove',
    creatorName: 'DJ Vibe',
    genre: 'Gqom',
    language: 'isiZulu',
    duration: Duration(minutes: 4),
    audioUrl: 'https://cdn.vhunambi.com/audio/durban-midnight.mp3',
    playCount: 2400,
  );

  group('Phase 42: Cockpit Hardware Player Studio Bridge & Multitrack Transport', () {
    testWidgets('REQ-LED-TOGGLE-01 & 02: Hardware DSP LED indicator mounts and reflects state', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(playerStateProvider.notifier).playTrack(testTrack);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: ExpandedCockpitModal(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cockpit_dsp_led_indicator')), findsOneWidget);
      expect(find.text('DSP'), findsOneWidget);

      // Toggle A/B DSP
      await tester.tap(find.byKey(const Key('cockpit_master_ab_btn')));
      await tester.pumpAndSettle();

      final isBypassed = !container.read(masteringSessionProvider).isMasteredPreviewActive;
      expect(isBypassed, isTrue);
      expect(find.text('RAW'), findsOneWidget);

      container.read(playerStateProvider.notifier).dismiss();
      await tester.pumpAndSettle();
    });

    testWidgets('REQ-BRIDGE-REMIX-02: Remix in Studio updates form, switches tab to 2, and notifies', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(playerStateProvider.notifier).playTrack(testTrack);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: ExpandedCockpitModal(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cockpit_remix_in_studio_btn')), findsOneWidget);

      await tester.tap(find.byKey(const Key('cockpit_remix_in_studio_btn')));
      await tester.pumpAndSettle();

      // Verify studio form state updated
      final studioForm = container.read(studioFormProvider);
      expect(studioForm.genre, 'Gqom');
      expect(studioForm.prompt, contains('Remix of Durban Midnight Groove'));

      // Verify app navigation tab switched to 2 (Studio Cockpit)
      final activeTab = container.read(appNavigationTabProvider);
      expect(activeTab, 2);

      // Verify notification logged
      final notifs = container.read(notificationsProvider);
      expect(
        notifs.any((n) =>
            n.title == 'Studio Remix Loaded' &&
            n.category == NotificationCategory.creatorActivity &&
            n.message.contains('Durban Midnight Groove')),
        isTrue,
      );

      container.read(playerStateProvider.notifier).dismiss();
      await tester.pumpAndSettle();
    });
  });
}


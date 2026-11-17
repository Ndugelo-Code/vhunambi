import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vhunambi_client/features/home/presentation/views/home_dashboard_view.dart';
import 'package:vhunambi_client/features/home/presentation/widgets/subscription_upgrade_modal.dart';
import 'package:vhunambi_client/features/player/presentation/providers/player_provider.dart';

void main() {
  group('HomeDashboardView Widget Tests', () {
    testWidgets('renders greeting, streak, credit chip, and quick actions', (
      WidgetTester tester,
    ) async {
      bool studioNavigated = false;
      bool marketNavigated = false;
      bool libraryNavigated = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: HomeDashboardView(
              onNavigateToStudio: () => studioNavigated = true,
              onNavigateToMarket: () => marketNavigated = true,
              onNavigateToLibrary: () => libraryNavigated = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top Header: Profile avatar button, authentic greeting, streak, credit/coin chip
      expect(find.byKey(const Key('home_avatar_btn')), findsOneWidget);
      expect(find.byKey(const Key('home_greeting_text')), findsOneWidget);
      expect(find.byKey(const Key('home_streak_pill')), findsOneWidget);
      expect(find.text('5 Streak'), findsOneWidget);
      expect(find.byKey(const Key('home_coins_pill')), findsOneWidget);
      expect(find.text('250 Coins'), findsOneWidget);
      expect(find.text('Ndugelo Musician'), findsNothing);

      // Direct Studio CTA, Quota Pill & Now Playing Deck (Phase 68 Main Room)
      expect(find.byKey(const Key('home_allowance_pill')), findsOneWidget);
      expect(find.text('10/10 Free'), findsOneWidget);
      expect(find.byKey(const Key('home_now_playing_card')), findsOneWidget);
      expect(find.byKey(const Key('home_create_studio_cta')), findsOneWidget);
      expect(find.text('Create in AI Studio'), findsOneWidget);

      // 4 Clean Creation Tool Cards (Zero duplicate AI Studio tile)
      expect(find.byKey(const Key('home_hub_ai_studio')), findsNothing);
      expect(find.text('Voice Clone'), findsOneWidget);
      expect(find.text('Sketchpad'), findsOneWidget);
      expect(find.text('Beats Market'), findsOneWidget);
      expect(find.text('Asset Vault'), findsOneWidget);

      // Test navigation tile clicks
      await tester.ensureVisible(find.text('Beats Market'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Beats Market'));
      expect(marketNavigated, isTrue);

      await tester.ensureVisible(find.text('Asset Vault'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Asset Vault'));
      expect(libraryNavigated, isTrue);

      // Test direct Studio CTA click
      await tester.ensureVisible(
        find.byKey(const Key('home_create_studio_cta')),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const Key('home_create_studio_cta')));
      expect(studioNavigated, isTrue);
    });

    testWidgets('tapping credit chip opens SubscriptionUpgradeModal', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: HomeDashboardView())),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SubscriptionUpgradeModal), findsNothing);

      // Tap coin/credit badge
      await tester.tap(find.byKey(const Key('home_coins_pill')));
      await tester.pumpAndSettle();

      // Modal appears
      expect(find.byType(SubscriptionUpgradeModal), findsOneWidget);
      expect(find.text('Creator Plans & Credits'), findsOneWidget);
      expect(find.text('Monthly'), findsOneWidget);
      expect(find.text('Yearly (-20%)'), findsOneWidget);
    });

    testWidgets('jump back in card triggers player state playback', (
      WidgetTester tester,
    ) async {
      late ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, child) {
              container = ProviderScope.containerOf(context);
              return const MaterialApp(home: HomeDashboardView());
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Jump Back In'), findsOneWidget);

      // Initial track is the default player track
      expect(
        container.read(playerStateProvider).currentTrack?.id,
        equals('track_default_1'),
      );

      // Tap play button on inline Now Playing / Jump Back In card
      final playButton = find.byKey(const Key('home_player_play_pause_btn'));
      expect(playButton, findsOneWidget);

      await tester.ensureVisible(playButton);
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(playButton);
      await tester.pump(const Duration(milliseconds: 150));

      // State is now playing the Jump Back In track ('lib_track_001')
      expect(
        container.read(playerStateProvider).currentTrack?.id,
        equals('lib_track_001'),
      );
      expect(container.read(playerStateProvider).isPlaying, isTrue);
    });
  });
}

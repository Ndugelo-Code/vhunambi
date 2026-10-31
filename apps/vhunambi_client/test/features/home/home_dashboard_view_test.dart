import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vhunambi_client/core/design_system/tokens/app_icons.dart';
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

      // Quick Creation Card
      expect(find.text('What are you feeling today?'), findsOneWidget);
      expect(find.text('Create ✨'), findsOneWidget);

      // Action Tiles
      expect(find.text('AI Studio'), findsOneWidget);
      expect(find.text('Beats Market'), findsOneWidget);
      expect(find.text('Asset Vault'), findsOneWidget);
      expect(find.text('Stem Lab'), findsOneWidget);

      // Test navigation tile clicks
      await tester.tap(find.text('Beats Market'));
      expect(marketNavigated, isTrue);

      await tester.tap(find.text('Asset Vault'));
      expect(libraryNavigated, isTrue);

      // Test prompt preset click
      await tester.tap(find.text('Create ✨'));
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

      // Tap play button on Jump Back In card
      final playButton = find.descendant(
        of: find.byType(HomeDashboardView),
        matching: find.byIcon(AppIcons.play),
      );
      expect(playButton, findsOneWidget);

      await tester.ensureVisible(playButton);
      await tester.pumpAndSettle();

      await tester.tap(playButton);
      await tester.pumpAndSettle();

      // State is now playing the Jump Back In track ('lib_track_001')
      expect(
        container.read(playerStateProvider).currentTrack?.id,
        equals('lib_track_001'),
      );
      expect(container.read(playerStateProvider).isPlaying, isTrue);
    });
  });
}

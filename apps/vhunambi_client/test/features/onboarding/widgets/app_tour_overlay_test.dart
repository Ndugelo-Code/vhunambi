import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vhunambi_client/features/onboarding/presentation/widgets/app_tour_overlay.dart';

void main() {
  group('AppTourOverlay Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('renders all 5 tour cards with correct content',
        (WidgetTester tester) async {
      bool tourCompleted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppTourOverlay(
              key: const Key('app_tour_test'),
              onTourComplete: () => tourCompleted = true,
            ),
          ),
        ),
      );

      // First card: Compose
      expect(find.text('Compose'), findsOneWidget);
      expect(find.text('Describe a song idea in plain language'), findsOneWidget);

      // Navigate through all cards
      await tester.tap(find.byKey(const Key('app_tour_continue')));
      await tester.pumpAndSettle();
      expect(find.text('Write Lyrics First'), findsOneWidget);

      await tester.tap(find.byKey(const Key('app_tour_continue')));
      await tester.pumpAndSettle();
      expect(find.text('Voice'), findsOneWidget);

      await tester.tap(find.byKey(const Key('app_tour_continue')));
      await tester.pumpAndSettle();
      expect(find.text('Crate & MPC'), findsOneWidget);

      await tester.tap(find.byKey(const Key('app_tour_continue')));
      await tester.pumpAndSettle();
      expect(find.text('Credits & Library'), findsOneWidget);
      expect(find.byKey(const Key('app_tour_get_started')), findsOneWidget);
      expect(tourCompleted, isFalse);
    });

    testWidgets('shows dot indicator with current position',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppTourOverlay(
              key: const Key('app_tour_dots'),
              onTourComplete: () {},
            ),
          ),
        ),
      );

      // Dot indicator should be present
      expect(find.byType(AnimatedContainer), findsWidgets);
    });

    testWidgets('Skip Tour button dismisses overlay and calls onTourComplete',
        (WidgetTester tester) async {
      bool tourCompleted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppTourOverlay(
              key: const Key('app_tour_skip_widget'),
              onTourComplete: () => tourCompleted = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('app_tour_skip')));
      await tester.pumpAndSettle();

      // Overlay should be dismissed (empty SizedBox)
      expect(find.text('Compose'), findsNothing);
      expect(find.byKey(const Key('app_tour_skip')), findsNothing);
      expect(tourCompleted, isTrue);
    });

    testWidgets('Get Started button on final card completes tour',
        (WidgetTester tester) async {
      bool tourCompleted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppTourOverlay(
              key: const Key('app_tour_getstarted'),
              onTourComplete: () => tourCompleted = true,
            ),
          ),
        ),
      );

      // Navigate to final card
      for (int i = 0; i < 4; i++) {
        await tester.tap(find.byKey(const Key('app_tour_continue')));
        await tester.pumpAndSettle();
      }

      // On final card, Get Started should be visible
      expect(find.byKey(const Key('app_tour_get_started')), findsOneWidget);
      await tester.tap(find.byKey(const Key('app_tour_get_started')));
      await tester.pumpAndSettle();

      expect(tourCompleted, isTrue);
    });

    testWidgets('persists completion flag to SharedPreferences',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppTourOverlay(
              key: const Key('app_tour_persist'),
              onTourComplete: () {},
            ),
          ),
        ),
      );

      // Complete the tour
      for (int i = 0; i < 4; i++) {
        await tester.tap(find.byKey(const Key('app_tour_continue')));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const Key('app_tour_get_started')));
      await tester.pumpAndSettle();

      // Verify flag persisted
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('has_completed_app_tour'), isTrue);
    });

    testWidgets('does not show overlay if already completed',
        (WidgetTester tester) async {
      // Pre-set completion flag
      SharedPreferences.setMockInitialValues({
        'has_completed_app_tour': true,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppTourOverlay(
              key: const Key('app_tour_already'),
              onTourComplete: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Overlay should not show (empty SizedBox)
      expect(find.text('Compose'), findsNothing);
      expect(find.byKey(const Key('app_tour_skip')), findsNothing);
    });

    testWidgets('all interactive elements have explicit Keys',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppTourOverlay(
              key: const Key('app_tour_keys'),
              onTourComplete: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('app_tour_keys')), findsOneWidget);
      expect(find.byKey(const Key('app_tour_skip')), findsOneWidget);
      expect(find.byKey(const Key('app_tour_continue')), findsOneWidget);
    });
  });
}

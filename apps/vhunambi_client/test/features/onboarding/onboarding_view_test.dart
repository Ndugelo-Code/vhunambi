import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vhunambi_client/features/onboarding/presentation/views/onboarding_view.dart';
import 'package:vhunambi_client/features/onboarding/presentation/providers/onboarding_providers.dart';

void main() {
  group('OnboardingView Widget Tests', () {
    testWidgets('renders welcome slide and advances through slides with Continue',
        (WidgetTester tester) async {
      bool finishedCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: OnboardingView(
              onFinish: () => finishedCalled = true,
            ),
          ),
        ),
      );

      // Slide 0: Welcome
      expect(find.text('Create Authentic African Music'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);

      // Advance to Slide 1
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Personalize Your Sound'), findsOneWidget);
      expect(find.text('Favorite Genres'), findsOneWidget);
      expect(find.text('Indigenous Languages'), findsOneWidget);

      // Toggle a genre chip
      await tester.tap(find.text('Maskandi'));
      await tester.pumpAndSettle();

      // Advance to Slide 2
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('You’re Ready to Create'), findsOneWidget);
      expect(find.text('10 Free Song Credits Loaded'), findsOneWidget);
      expect(find.text('Start Creating ✨'), findsOneWidget);

      // Tap finish button
      await tester.tap(find.text('Start Creating ✨'));
      await tester.pumpAndSettle();

      expect(finishedCalled, isTrue);
    });

    testWidgets('tapping Skip immediately marks onboarding complete and finishes',
        (WidgetTester tester) async {
      bool finishedCalled = false;
      late ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, child) {
              container = ProviderScope.containerOf(context);
              return MaterialApp(
                home: OnboardingView(
                  onFinish: () => finishedCalled = true,
                ),
              );
            },
          ),
        ),
      );

      expect(find.text('Skip'), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(finishedCalled, isTrue);
      expect(container.read(onboardingStateProvider).hasCompletedOnboarding, isTrue);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vhunambi_client/features/creator_dna/domain/entities/creator_dna_profile.dart';
import 'package:vhunambi_client/features/creator_dna/presentation/providers/creator_dna_provider.dart';
import 'package:vhunambi_client/features/onboarding/presentation/views/onboarding_view.dart';
import 'package:vhunambi_client/features/onboarding/presentation/providers/onboarding_providers.dart';

void main() {
  group('OnboardingView Widget Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });
    testWidgets('renders welcome slide and advances through all 6 slides then app tour',
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

      // Slide 0: Welcome
      expect(find.text('Create Authentic African Music'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);

      // Advance to Slide 1: Creative Identity
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Your Creative Identity'), findsOneWidget);
      expect(find.byKey(const Key('onboarding_role_card_producer')), findsOneWidget);

      // Select role: Producer
      await tester.tap(find.byKey(const Key('onboarding_role_card_producer')));
      await tester.pumpAndSettle();

      // Select experience: Pro
      await tester.ensureVisible(find.byKey(const Key('onboarding_experience_pro')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onboarding_experience_pro')));
      await tester.pumpAndSettle();

      // Advance to Slide 2: Genre Heritage
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Genre Heritage'), findsOneWidget);
      expect(find.byKey(const Key('onboarding_genre_chip_Maskandi')), findsOneWidget);

      // Toggle genre chip
      await tester.tap(find.byKey(const Key('onboarding_genre_chip_Maskandi')));
      await tester.pumpAndSettle();

      // Advance to Slide 3: Language & Dialect
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Language & Dialect'), findsOneWidget);
      expect(find.byKey(const Key('onboarding_primary_language_isiZulu')), findsOneWidget);

      // Select primary language
      await tester.tap(find.byKey(const Key('onboarding_primary_language_isiZulu')));
      await tester.pumpAndSettle();

      // Advance to Slide 4: Sound Signature
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Sound Signature'), findsOneWidget);

      // Advance to Slide 5: DNA Activation
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Your Creator DNA is Ready'), findsOneWidget);
      expect(find.byKey(const Key('onboarding_dna_activate_cta')), findsOneWidget);

      // Tap Activate Creator DNA CTA — shows AppTourOverlay instead of finishing
      await tester.tap(find.byKey(const Key('onboarding_dna_activate_cta')));
      await tester.pumpAndSettle();

      // App Tour overlay should appear
      expect(find.byKey(const Key('app_tour_overlay')), findsOneWidget);
      expect(find.text('Compose'), findsOneWidget);

      // Navigate through all 5 app tour cards
      for (int i = 0; i < 4; i++) {
        await tester.tap(find.byKey(const Key('app_tour_continue')));
        await tester.pumpAndSettle();
      }

      // Final card: Credits & Library with Get Started
      expect(find.text('Credits & Library'), findsOneWidget);
      expect(find.byKey(const Key('app_tour_get_started')), findsOneWidget);

      // Complete the tour
      await tester.tap(find.byKey(const Key('app_tour_get_started')));
      await tester.pumpAndSettle();

      expect(finishedCalled, isTrue);

      // Verify onboarding state
      expect(container.read(onboardingStateProvider).hasCompletedOnboarding, isTrue);
      expect(container.read(onboardingStateProvider).creativeRole, CreativeRole.producer);
      expect(container.read(onboardingStateProvider).experienceLevel, ExperienceLevel.pro);
      expect(container.read(creatorDnaProvider).lifecycleState, DnaLifecycleState.seeded);

      // Verify app tour completion flag persisted
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('has_completed_app_tour'), isTrue);
    });

    testWidgets('tapping role card updates onboarding state with creative role',
        (WidgetTester tester) async {
      late ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, child) {
              container = ProviderScope.containerOf(context);
              return const MaterialApp(
                home: OnboardingView(),
              );
            },
          ),
        ),
      );

      // Advance to Slide 1
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('onboarding_role_card_producer')), findsOneWidget);
      await tester.tap(find.byKey(const Key('onboarding_role_card_producer')));
      await tester.pumpAndSettle();

      expect(container.read(onboardingStateProvider).creativeRole, CreativeRole.producer);
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

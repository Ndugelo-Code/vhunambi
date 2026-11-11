import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/creator_dna/domain/entities/creator_dna_profile.dart';
import 'package:vhunambi_client/features/creator_dna/presentation/providers/creator_dna_provider.dart';
import 'package:vhunambi_client/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:vhunambi_client/features/onboarding/presentation/views/onboarding_view.dart';

void main() {
  group('OnboardingView Widget Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets(
      'renders Act 1 without overflow on compact screen and advances through all 4 acts to activate DNA',
      (WidgetTester tester) async {
        // Verify Act 1 renders on default 800x600 viewport with zero RenderFlex overflow
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const OnboardingView(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
        expect(find.text('Welcome to Vhunambi'), findsOneWidget);

        // Full 4-Act walkthrough on tall viewport
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        bool finishedCalled = false;
        late ProviderContainer container;

        await tester.pumpWidget(
          ProviderScope(
            child: Consumer(
              builder: (context, ref, child) {
                container = ProviderScope.containerOf(context);
                return MaterialApp(
                  theme: AppTheme.darkTheme,
                  home: OnboardingView(
                    onFinish: () => finishedCalled = true,
                  ),
                );
              },
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // Act 1: Living Sonic Showcase
        expect(find.text('Welcome to Vhunambi'), findsOneWidget);
        expect(find.text('Continue'), findsOneWidget);
        expect(find.text('Skip'), findsOneWidget);

        await tester.tap(find.text('AI Studio & Stems'));
        await tester.pump(const Duration(milliseconds: 100));

        // Advance to Act 2: Interactive 3D Identity Card Stack
        await tester.tap(find.byKey(const Key('onboarding_continue_btn')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 450));

        expect(find.text('Claim Your Craft'), findsOneWidget);
        expect(
          find.byKey(const Key('identity_stack_next_btn')),
          findsOneWidget,
        );

        // Select next persona card (producer -> vocalist)
        await tester.tap(find.byKey(const Key('identity_stack_next_btn')));
        await tester.pump(const Duration(milliseconds: 350));
        expect(
          container.read(onboardingStateProvider).creativeRole,
          CreativeRole.vocalist,
        );

        // Advance to Act 3: African Genre Roots & Generation Era
        await tester.tap(find.byKey(const Key('onboarding_continue_btn')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 450));

        expect(find.text('African Genre Roots'), findsOneWidget);
        expect(
          find.byKey(const Key('onboarding_autotune_era_btn')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('onboarding_autotune_era_btn')));
        await tester.pump(const Duration(milliseconds: 100));

        // Advance to Act 4: Creator DNA Helix Finale
        await tester.tap(find.byKey(const Key('onboarding_continue_btn')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 450));

        expect(find.text('Your Creator DNA is Live'), findsOneWidget);
        final launchBtn = find.byKey(const Key('onboarding_launch_studio_btn'));
        expect(launchBtn, findsOneWidget);

        // Trigger DNA portal launch (400ms forward animation)
        await tester.tap(launchBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 450));
        await tester.pump(const Duration(milliseconds: 50));

        expect(finishedCalled, isTrue);
        expect(
          container.read(onboardingStateProvider).hasCompletedOnboarding,
          isTrue,
        );
        expect(
          container.read(onboardingStateProvider).creativeRole,
          CreativeRole.vocalist,
        );
        expect(
          container.read(creatorDnaProvider).lifecycleState,
          DnaLifecycleState.seeded,
        );
      },
    );

    testWidgets(
      'tapping role navigation updates onboarding state with creative role',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        late ProviderContainer container;

        await tester.pumpWidget(
          ProviderScope(
            child: Consumer(
              builder: (context, ref, child) {
                container = ProviderScope.containerOf(context);
                return MaterialApp(
                  theme: AppTheme.darkTheme,
                  home: const OnboardingView(),
                );
              },
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // Advance to Act 2
        await tester.tap(find.byKey(const Key('onboarding_continue_btn')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 450));

        expect(
          find.byKey(const Key('identity_stack_next_btn')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('identity_stack_next_btn')));
        await tester.pump(const Duration(milliseconds: 350));

        expect(
          container.read(onboardingStateProvider).creativeRole,
          CreativeRole.vocalist,
        );
      },
    );

    testWidgets(
      'tapping Skip immediately marks onboarding complete and finishes',
      (WidgetTester tester) async {
        bool finishedCalled = false;
        late ProviderContainer container;

        await tester.pumpWidget(
          ProviderScope(
            child: Consumer(
              builder: (context, ref, child) {
                container = ProviderScope.containerOf(context);
                return MaterialApp(
                  theme: AppTheme.darkTheme,
                  home: OnboardingView(
                    onFinish: () => finishedCalled = true,
                  ),
                );
              },
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Skip'), findsOneWidget);
        await tester.tap(find.text('Skip'));
        await tester.pump(const Duration(milliseconds: 100));

        expect(finishedCalled, isTrue);
        expect(
          container.read(onboardingStateProvider).hasCompletedOnboarding,
          isTrue,
        );
        expect(
          container.read(creatorDnaProvider).lifecycleState,
          DnaLifecycleState.seeded,
        );
      },
    );
  });
}

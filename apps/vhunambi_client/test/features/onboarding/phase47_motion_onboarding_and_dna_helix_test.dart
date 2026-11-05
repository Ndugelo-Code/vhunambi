import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vhunambi_client/features/creator_dna/domain/entities/creator_dna_profile.dart';
import 'package:vhunambi_client/features/onboarding/domain/models/onboarding_models.dart';
import 'package:vhunambi_client/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:vhunambi_client/features/onboarding/presentation/views/splash_view.dart';
import 'package:vhunambi_client/features/player/presentation/providers/player_provider.dart';
import 'package:vhunambi_client/features/player/presentation/widgets/mini_player_host.dart';
import 'package:vhunambi_client/features/onboarding/presentation/widgets/onboarding_act1_showcase.dart';
import 'package:vhunambi_client/features/onboarding/presentation/widgets/interactive_identity_card_stack.dart';
import 'package:vhunambi_client/features/onboarding/presentation/widgets/onboarding_act3_roots_deck.dart';
import 'package:vhunambi_client/features/onboarding/presentation/widgets/creator_dna_helix_finale.dart';

void main() {
  group('Phase 47: Motion Graphics Onboarding & DNA Genesis Tests', () {
    test('1. kAfricanOnboardingGenres contains exactly 12 distinct African genres (Zero Duplicates)', () {
      expect(kAfricanOnboardingGenres.length, 12);
      final names = kAfricanOnboardingGenres.map((g) => g.name).toSet();
      expect(names.length, 12, reason: 'All 12 genre names must be unique without duplicate Amapiano pills');

      final ids = kAfricanOnboardingGenres.map((g) => g.id).toSet();
      expect(ids.length, 12);
      expect(names, contains('Amapiano'));
      expect(names, contains('Private School Piano'));
      expect(names, contains('Gqom'));
      expect(names, contains('Maskandi'));
      expect(names, contains('Afro House'));
      expect(names, contains('Mbaqanga'));
      expect(names, contains('Bongo Flava'));
      expect(names, contains('Shangaan Electro'));
    });

    testWidgets('2. MiniPlayerHost is completely suppressed when onboarding is incomplete or splash is active', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final container = ProviderContainer(
        overrides: [
          isSplashActiveProvider.overrideWith((ref) => true),
          onboardingStateProvider.overrideWith((ref) => OnboardingNotifier()),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  SizedBox(key: Key('main_content')),
                  MiniPlayerHost(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Main content is rendered
      expect(find.byKey(const Key('main_content')), findsOneWidget);
      // Floating mini-player container is NOT visible (suppressed)
      expect(find.byKey(const Key('mini_player_host')), findsNothing);

      container.read(playerStateProvider.notifier).dismiss();
      container.dispose();
      await tester.pumpAndSettle();
    });

    testWidgets('3. Act 1: Living Sonic Showcase renders without error', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OnboardingAct1Showcase(
              onInteraction: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Welcome to Vhunambi'), findsOneWidget);
      expect(find.text('AI Studio & Stems'), findsOneWidget);
    });

    testWidgets('4. Act 2: InteractiveIdentityCardStack renders 5 3D tarot cards (Zero Raw Emojis)', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: InteractiveIdentityCardStack(
                selectedRole: CreativeRole.producer,
                onRoleChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Verify the 5 card keys exist
      expect(find.byKey(const Key('identity_card_producer')), findsOneWidget);
      expect(find.byKey(const Key('identity_card_vocalist')), findsOneWidget);
      expect(find.byKey(const Key('identity_card_multiHyphenate')), findsOneWidget);
      expect(find.byKey(const Key('identity_card_songwriter')), findsOneWidget);
      expect(find.byKey(const Key('identity_card_musicLover')), findsOneWidget);

      // Verify zero raw emojis on screen
      expect(find.text('🎹'), findsNothing);
      expect(find.text('🎤'), findsNothing);
      expect(find.text('✍️'), findsNothing);
      expect(find.text('🎧'), findsNothing);
    });

    testWidgets('5. Act 3: Tactile Roots Deck renders genre cards & generation dial', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: OnboardingAct3RootsDeck(
                  onInteraction: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('African Genre Roots'), findsOneWidget);
      expect(find.byKey(const Key('onboarding_birth_year_selector')), findsOneWidget);
      // Zero duplicate "Energetic" pills
      expect(find.text('Energetic'), findsNothing);
    });

    testWidgets('6. Act 4: CreatorDnaHelixFinale renders spinning 3D DNA & launch studio CTA', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      var launched = false;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CreatorDnaHelixFinale(
                onLaunchStudio: () {
                  launched = true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Your Creator DNA is Live'), findsOneWidget);
      final launchBtn = find.byKey(const Key('onboarding_launch_studio_btn'));
      expect(launchBtn, findsOneWidget);

      await tester.tap(launchBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump(const Duration(milliseconds: 50));
      expect(launched, isTrue);
    });
  });
}

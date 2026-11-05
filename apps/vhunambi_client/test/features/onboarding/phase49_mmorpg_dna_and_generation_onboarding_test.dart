import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vhunambi_client/features/creator_dna/domain/entities/creator_dna_profile.dart';
import 'package:vhunambi_client/features/creator_dna/presentation/widgets/creator_dna_profile_card.dart';
import 'package:vhunambi_client/features/onboarding/domain/models/onboarding_models.dart';
import 'package:vhunambi_client/features/onboarding/presentation/widgets/interactive_identity_card_stack.dart';
import 'package:vhunambi_client/features/onboarding/presentation/widgets/onboarding_act3_roots_deck.dart';
import 'package:vhunambi_client/features/onboarding/presentation/widgets/creator_dna_helix_finale.dart';
import 'package:vhunambi_client/features/profile/domain/models/creator_dna_node.dart';

void main() {
  group('Phase 49: MMORPG Creator DNA Helix & Generation Onboarding Tests', () {
    test(
      '1. SonicGenerationEra accurately partitions eras & maps recommended genres (REQ-P49-ROOTS-01..03)',
      () {
        expect(
          SonicGenerationEra.fromBirthYear(1982),
          SonicGenerationEra.era80sGolden,
        );
        expect(
          SonicGenerationEra.fromBirthYear(1989),
          SonicGenerationEra.era80sGolden,
        );
        expect(
          SonicGenerationEra.fromBirthYear(1990),
          SonicGenerationEra.era90sKwaitoHouse,
        );
        expect(
          SonicGenerationEra.fromBirthYear(1998),
          SonicGenerationEra.era90sKwaitoHouse,
        );
        expect(
          SonicGenerationEra.fromBirthYear(2000),
          SonicGenerationEra.era2000sPianoGqom,
        );
        expect(
          SonicGenerationEra.fromBirthYear(2005),
          SonicGenerationEra.era2000sPianoGqom,
        );
        expect(
          SonicGenerationEra.fromBirthYear(2011),
          SonicGenerationEra.era2011NextGenKinetic,
        );
        expect(
          SonicGenerationEra.fromBirthYear(2018),
          SonicGenerationEra.era2011NextGenKinetic,
        );

        // Verify authentic genres mapped
        expect(
          SonicGenerationEra.era80sGolden.recommendedGenres,
          contains('Mbaqanga'),
        );
        expect(
          SonicGenerationEra.era90sKwaitoHouse.recommendedGenres,
          contains('Kwaito'),
        );
        expect(
          SonicGenerationEra.era2000sPianoGqom.recommendedGenres,
          contains('Amapiano'),
        );
        expect(
          SonicGenerationEra.era2011NextGenKinetic.recommendedGenres,
          contains('Shangaan Electro'),
        );
      },
    );

    test(
      '2. 8-Node MMORPG Genomic Model partitions 4 sequenced and 4 locked quests (REQ-P49-DNA-01..02)',
      () {
        const state = OnboardingState(
          creativeRole: CreativeRole.musicLover,
          birthYear: 2004,
          selectedGenres: ['Amapiano', 'Gqom'],
          primaryLanguage: 'isiZulu',
        );

        final nodes = CreatorDnaNode.getOnboardingDnaNodes(state);
        expect(nodes.length, 8);

        // Nodes 1-4: Sequenced
        for (int i = 0; i < 4; i++) {
          expect(
            nodes[i].status,
            GenomicStatus.sequenced,
            reason: 'Node $i must be sequenced during onboarding',
          );
          expect(nodes[i].isSequenced, isTrue);
        }

        // Nodes 5-8: Locked Quests
        for (int i = 4; i < 8; i++) {
          expect(
            nodes[i].status,
            GenomicStatus.lockedQuest,
            reason: 'Node $i must be a locked studio quest',
          );
          expect(nodes[i].isSequenced, isFalse);
          expect(nodes[i].questInstruction, isNotNull);
        }

        // Friendly persona title verification (STD-UIUX-001)
        expect(nodes[0].title, 'Kinetic Creator & Curator');
        expect(nodes[0].title, isNot(contains('MUSICLOVER')));
      },
    );

    testWidgets(
      '3. InteractiveIdentityCardStack renders opaque front card & arrow navigation (REQ-P49-CARD-01..05)',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        CreativeRole currentRole = CreativeRole.producer;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return InteractiveIdentityCardStack(
                    selectedRole: currentRole,
                    onRoleChanged: (role) {
                      setState(() {
                        currentRole = role;
                      });
                    },
                  );
                },
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // Verify Prev & Next navigation buttons
        final prevBtn = find.byKey(const Key('identity_stack_prev_btn'));
        final nextBtn = find.byKey(const Key('identity_stack_next_btn'));
        expect(prevBtn, findsOneWidget);
        expect(nextBtn, findsOneWidget);

        // Tap Next button to advance role (producer -> vocalist)
        await tester.tap(nextBtn);
        await tester.pumpAndSettle();
        expect(currentRole, CreativeRole.vocalist);

        // Tap Next again (vocalist -> multiHyphenate)
        await tester.tap(nextBtn);
        await tester.pumpAndSettle();
        expect(currentRole, CreativeRole.multiHyphenate);

        // Tap Prev button to go back (multiHyphenate -> vocalist)
        await tester.tap(prevBtn);
        await tester.pumpAndSettle();
        expect(currentRole, CreativeRole.vocalist);
      },
    );

    testWidgets(
      '4. Act 3: 3-Tier Roots Deck renders Birth Year Dial, Orbs & Era Genres (REQ-P49-ROOTS-01..06)',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: OnboardingAct3RootsDeck(onInteraction: () {}),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // Verify Tier 1: Birth Year Dial & Auto-Tune button
        expect(
          find.byKey(const Key('onboarding_birth_year_selector')),
          findsOneWidget,
        );
        final autotuneBtn = find.byKey(
          const Key('onboarding_autotune_era_btn'),
        );
        expect(autotuneBtn, findsOneWidget);

        // Verify Tier 2: Cultural Orbs
        expect(
          find.byKey(const Key('onboarding_culture_language_orbs')),
          findsOneWidget,
        );

        // Verify Tier 3: Era Genre Deck
        expect(
          find.byKey(const Key('onboarding_era_genre_deck')),
          findsOneWidget,
        );

        // Tap Auto-Tune Era Genres
        await tester.tap(autotuneBtn);
        await tester.pump(const Duration(milliseconds: 100));

        // Verify glowing "✨ Era Match" pill is present
        expect(find.text('✨ Era Match'), findsWidgets);
      },
    );

    testWidgets(
      '5. Act 4: CreatorDnaHelixFinale renders 8 nodes, carousel & MMORPG inspector (REQ-P49-DNA-01..05)',
      (tester) async {
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

        // Verify title uses bouncy typography
        expect(find.text('Your Creator DNA is Live'), findsOneWidget);

        // Verify MMORPG Node Inspector Card is rendered
        expect(
          find.byKey(const Key('dna_node_inspector_card')),
          findsOneWidget,
        );

        // Verify all 8 node carousel pills exist
        for (int i = 0; i < 8; i++) {
          expect(find.byKey(Key('dna_helix_node_$i')), findsOneWidget);
        }

        // Tap Locus 5 (Node index 4: Voice Signature Quest)
        await tester.tap(find.byKey(const Key('dna_helix_node_4')));
        await tester.pump(const Duration(milliseconds: 100));

        // Verify inspector card now shows the Quest instruction
        expect(
          find.textContaining('Record a 20s voice take in Studio'),
          findsOneWidget,
        );
        expect(find.text('LOCKED QUEST'), findsOneWidget);

        // Tap Launch Button
        final launchBtn = find.byKey(const Key('onboarding_launch_studio_btn'));
        expect(launchBtn, findsOneWidget);
        await tester.tap(launchBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 450));
        await tester.pump(const Duration(milliseconds: 50));
        expect(launched, isTrue);
      },
    );

    testWidgets(
      '6. Main App: CreatorDnaProfileCard renders 3D Mini-Helix & opens DNA Lab (REQ-P49-LAB-01..02)',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: CreatorDnaProfileCard(isOwner: true),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // Verify Open 3D DNA Lab button
        final openLabBtn = find.byKey(const Key('open_3d_dna_lab_btn'));
        expect(openLabBtn, findsOneWidget);

        // Tap to open 3D DNA Lab sheet
        await tester.tap(openLabBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Verify CreatorDnaHelixLabSheet and Complete Quest button are visible
        expect(
          find.byKey(const Key('creator_dna_helix_lab_sheet')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('dna_lab_complete_quest_btn')),
          findsOneWidget,
        );
      },
    );
  });
}

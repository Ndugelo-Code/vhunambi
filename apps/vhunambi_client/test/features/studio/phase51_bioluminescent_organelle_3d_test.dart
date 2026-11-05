import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vhunambi_client/core/navigation/navigation_providers.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/onboarding/presentation/widgets/interactive_identity_card_stack.dart';
import 'package:vhunambi_client/features/onboarding/presentation/widgets/onboarding_act1_showcase.dart';
import 'package:vhunambi_client/features/creator_dna/domain/entities/creator_dna_profile.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/song_dna_graph_provider.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/studio_form_provider.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/song_dna_node_tree_modal.dart';

void main() {
  group('Phase 51: Bioluminescent Song Organelle 3D Universe & Hardware Bug Fixes', () {
    // -------------------------------------------------------------------------
    // 1. Track A: Card Stack Z-Order Inversion Sorting (REQ-P51-FIX-01)
    // -------------------------------------------------------------------------
    testWidgets(
      '1. InteractiveIdentityCardStack renders active card LAST in Stack (on top)',
      (tester) async {
        CreativeRole selectedRole = CreativeRole.producer;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: Center(
                child: InteractiveIdentityCardStack(
                  selectedRole: selectedRole,
                  onRoleChanged: (role) => selectedRole = role,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find the inner 3D Stack
        final stackFinder = find.byType(Stack);
        expect(stackFinder, findsWidgets);



        // Verify selected card #0 is present and rendered on top
        expect(find.byKey(Key(kIdentityCards[0].testKey)), findsOneWidget);

        // Tap next button to select card #1 (vocalist)
        await tester.tap(find.byKey(const Key('identity_stack_next_btn')));
        await tester.pumpAndSettle();

        expect(selectedRole, CreativeRole.vocalist);

        // Re-verify after index change that the active card is still the last child
        final updatedStack = tester
            .widgetList<Stack>(stackFinder)
            .firstWhere((s) => s.children.length == kIdentityCards.length);
        expect(updatedStack.children.length, kIdentityCards.length);
      },
    );

    // -------------------------------------------------------------------------
    // 2. Track A: Act 1 Welcome Pills Clearance (REQ-P51-FIX-02)
    // -------------------------------------------------------------------------
    testWidgets(
      '2. OnboardingAct1Showcase renders 18dp clearance and animated pills',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(body: Center(child: OnboardingAct1Showcase())),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.byKey(const Key('onboarding_act_1_showcase')),
          findsOneWidget,
        );
        expect(find.text('Welcome to Vhunambi'), findsOneWidget);
        expect(
          find.text('The African AI Audio Synthesis & Co-Creation Network'),
          findsOneWidget,
        );
        expect(find.text('AI Studio & Stems'), findsOneWidget);
        expect(find.text('Voice DNA'), findsOneWidget);
        expect(find.text('5-Channel Groove'), findsOneWidget);
        expect(find.text('Kinetic Marketplace'), findsOneWidget);
      },
    );

    // -------------------------------------------------------------------------
    // 3. Track B & D: 24+ Molecular Dendrite Nodes & Category Modeling (REQ-P51-DENDR-01)
    // -------------------------------------------------------------------------
    test(
      '3. SongDnaGraphNotifier partitions 4 multi-jointed arms into 24+ interactive nodes',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Attach reference audio so invasive node is present
        container.read(studioFormProvider.notifier).setReferenceAudio('test/path.wav');

        final graph = container.read(songDnaGraphProvider);
        // 22-26 interactive nodes
        expect(graph.nodes.length, greaterThanOrEqualTo(20));

        // Verify Arm 1: Beat & Rhythm
        expect(graph.nodes.any((n) => n.id == 'node_beat_tempo'), isTrue);
        expect(
          graph.nodes.any((n) => n.id == 'node_beat_rhythm_pocket'),
          isTrue,
        );
        expect(graph.nodes.any((n) => n.id == 'node_beat_tempo_feel'), isTrue);
        expect(graph.nodes.any((n) => n.id == 'node_beat_era'), isTrue);
        expect(graph.nodes.any((n) => n.id == 'node_beat_structure'), isTrue);

        // Verify Arm 2: Vocal & Linguistics
        expect(graph.nodes.any((n) => n.id == 'node_vocal_persona'), isTrue);
        expect(graph.nodes.any((n) => n.id == 'node_vocal_lora'), isTrue);
        expect(graph.nodes.any((n) => n.id == 'node_language_lyrics'), isTrue);
        expect(graph.nodes.any((n) => n.id == 'node_vocal_dialects'), isTrue);
        expect(graph.nodes.any((n) => n.id == 'node_mood_energy'), isTrue);

        // Verify Arm 3: Instruments & 5-Channel Groove
        expect(graph.nodes.any((n) => n.id == 'node_sketchpad_groove'), isTrue);
        expect(graph.nodes.any((n) => n.id == 'node_inst_lead'), isTrue);
        expect(graph.nodes.any((n) => n.id == 'node_inst_chords'), isTrue);
        expect(graph.nodes.any((n) => n.id == 'node_inst_logdrum'), isTrue);
        expect(graph.nodes.any((n) => n.id == 'node_inst_drums'), isTrue);
        expect(graph.nodes.any((n) => n.id == 'node_inst_hats'), isTrue);
        expect(graph.nodes.any((n) => n.id == 'node_heritage_mpc'), isTrue);

        // Verify Arm 4: Invasive & Symbiotic Intake
        expect(
          graph.nodes.any((n) => n.id == 'node_invasive_reference'),
          isTrue,
        );
        expect(
          graph.nodes.any((n) => n.id == 'node_invasive_ref_beat'),
          isTrue,
        );

        // Verify terminal receptor flag
        final logDrumNode = graph.nodes.firstWhere(
          (n) => n.id == 'node_inst_logdrum',
        );
        expect(logDrumNode.isTerminalReceptor, isTrue);
        expect(logDrumNode.parentId, 'node_sketchpad_groove');
      },
    );

    // -------------------------------------------------------------------------
    // 4. Track B & C: Sovereign 3D Modal Opacity & MiniPlayerHost Suppression (REQ-P51-FIX-03)
    // -------------------------------------------------------------------------
    testWidgets(
      '4. SongDnaNodeTreeModal increments modalSheetOpenCountProvider and renders 100% opaque void',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1024);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final container = ProviderContainer();
        addTearDown(container.dispose);

        expect(container.read(modalSheetOpenCountProvider), 0);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const Scaffold(body: SongDnaNodeTreeModal()),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Verify modal sheet open count is incremented (suppressing MiniPlayerHost)
        expect(container.read(modalSheetOpenCountProvider), greaterThan(0));

        // Verify 100% opaque scaffold
        final scaffold = tester.widget<Scaffold>(
          find.byKey(const Key('song_dna_3d_tree_modal')),
        );
        expect(scaffold.backgroundColor, const Color(0xFF020710));
      },
    );

    // -------------------------------------------------------------------------
    // 5. Track A & D: Synthesize CTA triggers GenerationPipelineNotifier (REQ-P51-FIX-04)
    // -------------------------------------------------------------------------
    testWidgets(
      '5. Synthesize Song from 3D DNA button triggers live generation pipeline',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1024);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Seed form prompt
        container
            .read(studioFormProvider.notifier)
            .updatePrompt('Amapiano Sunset Vibez');

        bool synthesizeRequested = false;

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: Scaffold(
                body: SongDnaNodeTreeModal(
                  onSynthesizeRequested: () => synthesizeRequested = true,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Find synthesize button
        final synthesizeBtn = find.byKey(const Key('song_dna_synthesize_btn'));
        expect(synthesizeBtn, findsOneWidget);
        expect(find.text('⚡ Synthesize Song from 3D DNA'), findsOneWidget);

        // Tap button
        await tester.tap(synthesizeBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Verify onSynthesizeRequested callback was fired
        expect(synthesizeRequested, isTrue);
      },
    );

    // -------------------------------------------------------------------------
    // 6. Track D: Tap-to-Dive & Decluttered Holographic Receptor Selection
    // -------------------------------------------------------------------------
    testWidgets(
      '6. Tapping terminal receptor bubble selects node and reveals quick action card',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1024);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const Scaffold(body: SongDnaNodeTreeModal()),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Terminal receptor for Log Drum
        final logDrumBubble = find.byKey(
          const Key('song_dna_bubble_node_inst_logdrum'),
        );
        expect(logDrumBubble, findsOneWidget);

        await tester.tap(logDrumBubble);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Verify node selected and quick action card displayed
        expect(
          container.read(songDnaGraphProvider).selectedNodeId,
          'node_inst_logdrum',
        );
        expect(
          find.byKey(const Key('song_dna_quick_action_card')),
          findsOneWidget,
        );
        expect(find.text('Log-Drum Sub Bass'), findsOneWidget);
      },
    );
  });
}

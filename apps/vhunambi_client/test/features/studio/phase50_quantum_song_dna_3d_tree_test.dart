import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/studio/domain/models/song_dna_graph_models.dart';
import 'package:vhunambi_client/features/studio/domain/models/studio_form_state.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/song_dna_graph_provider.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/studio_form_provider.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/progress_tracker.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/song_dna_node_tree_modal.dart';

void main() {
  group('Phase 50: Quantum-Entangled 3D Song DNA Node Tree & Hover Pill', () {
    // -------------------------------------------------------------------------
    // 1. Vector3D & Data Structures
    // -------------------------------------------------------------------------
    test('1. Vector3D arithmetic, distance, normalization, and projection', () {
      const v1 = Vector3D(1.0, 2.0, 3.0);
      const v2 = Vector3D(4.0, 5.0, 6.0);

      final added = v1 + v2;
      expect(added.x, 5.0);
      expect(added.y, 7.0);
      expect(added.z, 9.0);

      final subtracted = v2 - v1;
      expect(subtracted.x, 3.0);
      expect(subtracted.y, 3.0);
      expect(subtracted.z, 3.0);

      final scaled = v1 * 2.0;
      expect(scaled.x, 2.0);
      expect(scaled.y, 4.0);
      expect(scaled.z, 6.0);

      expect(v1.length, closeTo(3.7416, 0.001));
      final norm = v1.normalized;
      expect(norm.length, closeTo(1.0, 0.001));

      expect(v1.dot(v2), 1.0 * 4.0 + 2.0 * 5.0 + 3.0 * 6.0);
    });

    test('2. SongDnaNodeCategory correctly maps authentic colors and names', () {
      expect(
        SongDnaNodeCategory.beatCore.defaultColor,
        const Color(0xFFF59E0B),
      );
      expect(
        SongDnaNodeCategory.vocalLyrics.defaultColor,
        const Color(0xFF06B6D4),
      );
      expect(
        SongDnaNodeCategory.instrumentsHarmony.defaultColor,
        const Color(0xFF10B981),
      );
      expect(
        SongDnaNodeCategory.invasiveThirdParty.defaultColor,
        const Color(0xFFD946EF),
      );

      expect(SongDnaNodeCategory.beatCore.displayName, 'Beat & Core Rhythm');
      expect(SongDnaNodeCategory.vocalLyrics.displayName, 'Vocal & Lyric Soul');
      expect(SongDnaNodeCategory.instrumentsHarmony.displayName, 'Instruments & Harmony');
      expect(SongDnaNodeCategory.invasiveThirdParty.displayName, 'Invasive Intake Audio');
    });

    // -------------------------------------------------------------------------
    // 2. SongDnaGraphNotifier & State Graph Logic
    // -------------------------------------------------------------------------
    test('3. Graph notifier synthesizes 4 categories and reacts to form changes', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Verify initial graph state
      final initialGraph = container.read(songDnaGraphProvider);
      expect(initialGraph.nodes, isNotEmpty);
      expect(initialGraph.selectedNodeId, isNull);

      // Check presence of core nodes
      final hasBeat = initialGraph.nodes.any((n) => n.category == SongDnaNodeCategory.beatCore);
      final hasVocal = initialGraph.nodes.any((n) => n.category == SongDnaNodeCategory.vocalLyrics);
      final hasInst = initialGraph.nodes.any((n) => n.category == SongDnaNodeCategory.instrumentsHarmony);
      expect(hasBeat, isTrue);
      expect(hasVocal, isTrue);
      expect(hasInst, isTrue);

      // Initially no invasive nodes
      final hasInvasive = initialGraph.nodes.any((n) => n.category == SongDnaNodeCategory.invasiveThirdParty);
      expect(hasInvasive, isFalse);

      // Mutate studio form with reference audio
      container.read(studioFormProvider.notifier).setReferenceAudio('sample_ref.wav');

      final updatedGraph = container.read(songDnaGraphProvider);
      final invasiveRef = updatedGraph.nodes.firstWhere(
        (n) => n.id == 'node_invasive_reference',
      );
      expect(invasiveRef.category, SongDnaNodeCategory.invasiveThirdParty);
      expect(invasiveRef.isInvasive, isTrue);
      expect(invasiveRef.isUnlocked, isTrue);
      expect(invasiveRef.glowColor, const Color(0xFFD946EF));

      // Detach invasive reference node
      container.read(songDnaGraphProvider.notifier).detachInvasiveNode('node_invasive_reference');
      final detachedGraph = container.read(songDnaGraphProvider);
      expect(
        detachedGraph.nodes.any((n) => n.id == 'node_invasive_reference'),
        isFalse,
      );
      expect(container.read(studioFormProvider).referenceAudioPath, isNull);
    });

    test('4. Quantum entanglement updates genre and tempo through graph notifier', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(songDnaGraphProvider.notifier);

      notifier.selectGenre('Kwaito');
      expect(container.read(studioFormProvider).genre, 'Kwaito');

      notifier.selectTempo(124);
      expect(container.read(studioFormProvider).tempo, TempoBracket.fast);

      // Verify node selection
      notifier.selectNode('node_beat_tempo');
      expect(container.read(songDnaGraphProvider).selectedNodeId, 'node_beat_tempo');

      notifier.selectNode(null);
      expect(container.read(songDnaGraphProvider).selectedNodeId, isNull);
    });

    // -------------------------------------------------------------------------
    // 3. SongDnaHoverPill Widget
    // -------------------------------------------------------------------------
    testWidgets('5. SongDnaHoverPill renders with 60 FPS hover and opens 3D tree modal on tap', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: Center(
                child: ProgressTrackerWidget(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify living hover pill is present in progress tracker
      final pillFinder = find.byKey(const Key('studio_song_dna_hover_pill'));
      expect(pillFinder, findsOneWidget);
      expect(find.textContaining('Song DNA'), findsOneWidget);

      // Tap the hover pill to open the 3D Song DNA modal
      await tester.tap(pillFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify full-screen 3D spatial node tree modal opened
      expect(find.byKey(const Key('song_dna_3d_tree_modal')), findsOneWidget);
      expect(find.text('SONG DNA QUANTUM TREE'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 4. SongDnaNodeTreeModal 3D Controls, Billboard Bubbles & Quick Action Card
    // -------------------------------------------------------------------------
    testWidgets('6. SongDnaNodeTreeModal renders camera controls, billboard bubbles, and quick action card', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool synthesizeTriggered = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: SongDnaNodeTreeModal(
                onSynthesizeRequested: () {
                  synthesizeTriggered = true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 1. Verify 3D Camera Controls
      expect(find.byKey(const Key('song_dna_zoom_in_btn')), findsOneWidget);
      expect(find.byKey(const Key('song_dna_zoom_out_btn')), findsOneWidget);
      expect(find.byKey(const Key('song_dna_reset_camera_btn')), findsOneWidget);

      // Tap zoom in and reset camera
      await tester.tap(find.byKey(const Key('song_dna_zoom_in_btn')));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('song_dna_reset_camera_btn')));
      await tester.pump(const Duration(milliseconds: 100));

      // 2. Verify Billboarded Floating Cue Bubbles
      final tempoBubble = find.byKey(const Key('song_dna_bubble_node_beat_tempo'));
      expect(tempoBubble, findsOneWidget);

      // Tap tempo bubble to select it
      await tester.tap(tempoBubble, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 3. Verify Floating Quick-Action Card appeared at bottom
      expect(find.byKey(const Key('song_dna_quick_action_card')), findsOneWidget);
      expect(find.text('Tempo (BPM)'), findsWidgets);

      // Tap tempo chip 118 BPM to quantum-mutate the form
      final chip118 = find.text('118');
      expect(chip118, findsOneWidget);
      await tester.tap(chip118);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 4. Verify Synthesize Song CTA button
      final synthesizeBtn = find.byKey(const Key('song_dna_synthesize_btn'));
      expect(synthesizeBtn, findsOneWidget);
      expect(find.text('⚡ Synthesize Song from 3D DNA'), findsOneWidget);

      // Tap synthesize CTA
      await tester.tap(synthesizeBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(synthesizeTriggered, isTrue);
    });

    testWidgets('7. Quick-Action Card allows detaching invasive nodes', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Seed reference audio to instantiate invasive node
      container.read(studioFormProvider.notifier).setReferenceAudio('stem_guide.mp3');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: SongDnaNodeTreeModal(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Find invasive reference audio bubble
      final invasiveBubble = find.byKey(const Key('song_dna_bubble_node_invasive_reference'));
      expect(invasiveBubble, findsOneWidget);

      // Tap invasive bubble
      await tester.tap(invasiveBubble);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Detach button must be visible in quick action card
      final detachBtn = find.byKey(const Key('song_dna_detach_node_btn'));
      expect(detachBtn, findsOneWidget);
      expect(find.text('Detach from Graph'), findsOneWidget);

      // Tap detach
      await tester.tap(detachBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Invasive node should dissolve and be gone
      expect(find.byKey(const Key('song_dna_bubble_node_invasive_reference')), findsNothing);
      expect(container.read(studioFormProvider).referenceAudioPath, isNull);
    });
  });
}

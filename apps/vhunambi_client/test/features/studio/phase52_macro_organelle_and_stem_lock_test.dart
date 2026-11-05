import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/studio/domain/models/song_dna_graph_models.dart';
import 'package:vhunambi_client/features/studio/domain/models/studio_form_state.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/song_dna_graph_provider.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/studio_form_provider.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/song_dna_node_tree_modal.dart';

void main() {
  group('Phase 52: Macro-Canopy 3D Organelle Biome & Pre-Gen Stem-Lock Engine', () {
    // -------------------------------------------------------------------------
    // 1. Domain Modeling: StemLockMode & Default Branch Stem Locks
    // -------------------------------------------------------------------------
    test('1. StudioFormState defaults Beat and Sketchpad branches to lockedPure44k', () {
      const state = StudioFormState();

      expect(state.branchStemLockModes, isNotNull);
      expect(state.branchStemLockModes['node_beat_tempo'], StemLockMode.lockedPure44k);
      expect(state.branchStemLockModes['node_sketchpad_groove'], StemLockMode.lockedPure44k);
      expect(state.branchStemLockModes['node_vocal_persona'], StemLockMode.harmonicInpaint);
      expect(state.branchStemLockModes['node_spatial_atmosphere'], StemLockMode.harmonicInpaint);

      // Verify copyWith works properly
      final updated = state.copyWith(
        branchStemLockModes: {
          ...state.branchStemLockModes,
          'node_beat_tempo': StemLockMode.elasticResynth,
        },
      );
      expect(updated.branchStemLockModes['node_beat_tempo'], StemLockMode.elasticResynth);
    });

    test('2. SongDnaNode models isBranchRoot and StemLockMode correctly', () {
      const node = SongDnaNode(
        id: 'node_beat_tempo',
        parentId: 'node_core',
        title: 'Amapiano Log-Drum',
        subtitle: '113 BPM • High Energy',
        cueLabel: '113 BPM',
        category: SongDnaNodeCategory.beatCore,
        accentColor: Color(0xFFF97316),
        icon: PhosphorIconsBold.metronome,
        branchUnlockProgress: 1.0,
        localPosition: Vector3D(0, 180, 0),
        isBranchRoot: true,
        stemLockMode: StemLockMode.lockedPure44k,
      );

      expect(node.isBranchRoot, isTrue);
      expect(node.stemLockMode, StemLockMode.lockedPure44k);

      final leafNode = node.copyWith(
        title: 'Mutated Beat Node',
        isBranchRoot: false,
        stemLockMode: StemLockMode.harmonicInpaint,
      );
      expect(leafNode.isBranchRoot, isFalse);
      expect(leafNode.stemLockMode, StemLockMode.harmonicInpaint);
      expect(leafNode.title, 'Mutated Beat Node');
    });

    // -------------------------------------------------------------------------
    // 2. Graph Provider: 4 Primary Branch Roots & Dynamic Instrument Leaves
    // -------------------------------------------------------------------------
    test('3. songDnaGraphProvider marks exactly 4 primary roots and supports leaf spawning', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final graphState = container.read(songDnaGraphProvider);
      final primaryRoots = graphState.nodes.where((n) => n.isBranchRoot).toList();

      expect(primaryRoots.length, 4);
      expect(primaryRoots.map((n) => n.id).toSet(), containsAll([
        'node_beat_tempo',
        'node_vocal_persona',
        'node_sketchpad_groove',
        'node_spatial_atmosphere',
      ]));

      // Test adding a dynamic instrument leaf
      container.read(songDnaGraphProvider.notifier).addInstrumentLeaf(
        name: 'Bamboo Flute Solo',
        icon: PhosphorIconsBold.musicNotes,
      );

      final updatedGraph = container.read(songDnaGraphProvider);
      expect(updatedGraph.nodes.any((n) => n.title == 'Bamboo Flute Solo'), isTrue);

      // Test manifest export for pre-gen stem locks
      final manifest = container.read(songDnaGraphProvider.notifier).exportPregenStemLocksManifest();
      expect(manifest.containsKey('locks'), isTrue);
      final locks = manifest['locks'] as Map<String, String>;
      expect(locks['node_beat_tempo'], 'lockedPure44k');
    });

    // -------------------------------------------------------------------------
    // 3. UI & 2-Tier Camera Hierarchy Widget Test
    // -------------------------------------------------------------------------
    testWidgets(
      '4. SongDnaNodeTreeModal: 2-tier spatial camera hierarchy (Overview <-> Canopy Focus)',
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
              home: const Scaffold(
                body: SongDnaNodeTreeModal(),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 1. Verify modal is rendered in full-screen opaque mode
        expect(find.byType(SongDnaNodeTreeModal), findsOneWidget);

        // 2. In Overview mode, only the 4 primary branch roots display bubbles
        expect(find.byKey(const Key('song_dna_bubble_node_beat_tempo')), findsOneWidget);
        expect(find.byKey(const Key('song_dna_bubble_node_vocal_persona')), findsOneWidget);
        expect(find.byKey(const Key('song_dna_bubble_node_sketchpad_groove')), findsOneWidget);
        expect(find.byKey(const Key('song_dna_bubble_node_spatial_atmosphere')), findsOneWidget);

        // Return overview button is not visible yet in overview mode
        expect(find.byKey(const Key('song_dna_return_overview_btn')), findsNothing);

        // 3. Tap on the Sketchpad/Instruments branch root to dive into canopy
        await tester.tap(find.byKey(const Key('song_dna_bubble_node_sketchpad_groove')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // 4. Return overview button should now be visible
        final btnFinder = find.byKey(const Key('song_dna_return_overview_btn'));
        expect(btnFinder, findsOneWidget);

        // 5. Add Instrument Leaf button should be available in the Quick-Action card
        expect(find.byKey(const Key('song_dna_add_instrument_leaf_btn')), findsOneWidget);

        // 6. Tap Add Instrument Leaf button to open bottom sheet
        await tester.tap(find.byKey(const Key('song_dna_add_instrument_leaf_btn')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 7. Select Bamboo Flute from sheet, closing it and adding leaf to canopy
        await tester.tap(find.text('Bamboo Flute'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // 8. Verify Stem Authority selector pill exists
        expect(find.byKey(const Key('song_dna_stem_lock_selector')), findsOneWidget);

        // 9. Tap the return to overview button to zoom back out
        await tester.tap(btnFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Return button disappears in overview mode
        expect(find.byKey(const Key('song_dna_return_overview_btn')), findsNothing);
      },
    );

    // -------------------------------------------------------------------------
    // 4. Stem-Lock Authority Selector Interaction
    // -------------------------------------------------------------------------
    testWidgets(
      '5. Stem Lock Selector toggles between pure 44k, guided inpaint, and re-imagine',
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
              home: const Scaffold(
                body: SongDnaNodeTreeModal(),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Focus the beat branch
        await tester.tap(find.byKey(const Key('song_dna_bubble_node_beat_tempo')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final stemLockBtn = find.byKey(const Key('song_dna_stem_lock_selector'));
        expect(stemLockBtn, findsOneWidget);

        // Initial state for beat is lockedPure44k
        expect(
          container.read(studioFormProvider).branchStemLockModes['node_beat_tempo'],
          StemLockMode.lockedPure44k,
        );

        // Tap AI Inpaint tab
        final inpaintTab = find.byKey(const Key('song_dna_stem_lock_tab_harmonicInpaint'));
        expect(inpaintTab, findsOneWidget);
        await tester.tap(inpaintTab);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          container.read(studioFormProvider).branchStemLockModes['node_beat_tempo'],
          StemLockMode.harmonicInpaint,
        );

        // Tap Re-Imagine tab
        final reImagineTab = find.byKey(const Key('song_dna_stem_lock_tab_elasticResynth'));
        expect(reImagineTab, findsOneWidget);
        await tester.tap(reImagineTab);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          container.read(studioFormProvider).branchStemLockModes['node_beat_tempo'],
          StemLockMode.elasticResynth,
        );
      },
    );
  });
}

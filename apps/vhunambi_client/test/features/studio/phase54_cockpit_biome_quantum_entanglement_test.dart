import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/studio/domain/models/mycelium_biome_models.dart';
import 'package:vhunambi_client/features/studio/domain/models/studio_form_state.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/studio_form_provider.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/mycelium_biome_provider.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/heritage_crate_provider.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/melody_sketchpad_provider.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/cockpit_quantum_entanglement_rack.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/inline_crate_mpc_workbench.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/biome/biome_cluster_inspector_panel.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/song_dna_node_tree_modal.dart';

void main() {
  group('Phase 54: Cockpit & 3D Biome Quantum Entanglement', () {
    // -------------------------------------------------------------------------
    // 1. Canonical & legacy stem-lock key parity in StudioFormState & Notifier
    // -------------------------------------------------------------------------
    test(
      '1. Canonical & legacy stem-lock key parity in StudioFormState & Notifier',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(studioFormProvider.notifier);

        // a) Setting canonical 'node_harmony_chords' atomically updates legacy 'node_branch_instruments'
        notifier.setBranchStemLockMode('node_harmony_chords', StemLockMode.lockedPure44k);
        var state = container.read(studioFormProvider);
        expect(state.branchStemLockModes['node_harmony_chords'], StemLockMode.lockedPure44k);
        expect(state.branchStemLockModes['node_branch_instruments'], StemLockMode.lockedPure44k);

        // b) Setting legacy 'node_branch_beat' atomically updates canonical 'node_beat_tempo'
        notifier.setBranchStemLockMode('node_branch_beat', StemLockMode.lockedPure44k);
        state = container.read(studioFormProvider);
        expect(state.branchStemLockModes['node_branch_beat'], StemLockMode.lockedPure44k);
        expect(state.branchStemLockModes['node_beat_tempo'], StemLockMode.lockedPure44k);

        // c) setClusterStemLockMode updates both keys for vocalNetwork
        notifier.setClusterStemLockMode(
          MyceliumClusterDomain.vocalNetwork,
          StemLockMode.lockedPure44k,
        );
        state = container.read(studioFormProvider);
        expect(
          state.branchStemLockModes[MyceliumClusterDomain.vocalNetwork.studioBranchKey],
          StemLockMode.lockedPure44k,
        );
        expect(
          state.branchStemLockModes[MyceliumClusterDomain.vocalNetwork.legacyBranchAliasKey],
          StemLockMode.lockedPure44k,
        );

        // d) cycleClusterStemLockMode cycles lockedPure44k -> harmonicInpaint -> elasticResynth -> lockedPure44k
        notifier.setClusterStemLockMode(
          MyceliumClusterDomain.productionNetwork,
          StemLockMode.lockedPure44k,
        );
        notifier.cycleClusterStemLockMode(MyceliumClusterDomain.productionNetwork);
        state = container.read(studioFormProvider);
        expect(
          state.branchStemLockModes[MyceliumClusterDomain.productionNetwork.studioBranchKey],
          StemLockMode.harmonicInpaint,
        );

        notifier.cycleClusterStemLockMode(MyceliumClusterDomain.productionNetwork);
        state = container.read(studioFormProvider);
        expect(
          state.branchStemLockModes[MyceliumClusterDomain.productionNetwork.studioBranchKey],
          StemLockMode.elasticResynth,
        );

        notifier.cycleClusterStemLockMode(MyceliumClusterDomain.productionNetwork);
        state = container.read(studioFormProvider);
        expect(
          state.branchStemLockModes[MyceliumClusterDomain.productionNetwork.studioBranchKey],
          StemLockMode.lockedPure44k,
        );
      },
    );

    // -------------------------------------------------------------------------
    // 2. Non-destructive 5-provider reconciliation preserves focus & custom leaves
    // -------------------------------------------------------------------------
    test(
      '2. Non-destructive 5-provider reconciliation preserves focus & custom leaves',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Warm up biome provider
        var graph = container.read(myceliumBiomeGraphProvider);
        expect(graph.clusters.length, 6);

        // Focus vocalNetwork
        final biomeNotifier = container.read(myceliumBiomeGraphProvider.notifier);
        biomeNotifier.focusCluster(MyceliumClusterDomain.vocalNetwork);
        expect(
          container.read(myceliumBiomeGraphProvider).focusedDomain,
          MyceliumClusterDomain.vocalNetwork,
        );

        // Select arrangement section
        biomeNotifier.selectSongJourneySection(SongJourneySection.intro);
        expect(
          container.read(myceliumBiomeGraphProvider).activeSection,
          SongJourneySection.intro,
        );

        // Add custom leaf to harmonyNetwork
        biomeNotifier.addInstrumentLeaf(
          name: 'Mbira Ancestral Chords',
          iconIdentifier: 'musicNotes',
        );

        final harmLeavesBefore = container
            .read(myceliumBiomeGraphProvider)
            .clusters[MyceliumClusterDomain.harmonyNetwork]!
            .childLeaves;
        expect(
          harmLeavesBefore.any((l) => l.title == 'Mbira Ancestral Chords'),
          isTrue,
        );

        // Mutate studioFormProvider form state (2D Cockpit change)
        container.read(studioFormProvider.notifier).setTempo(TempoBracket.fast);

        // Verify non-destructive reconciliation preserved all 3D ephemeral states
        graph = container.read(myceliumBiomeGraphProvider);
        expect(graph.focusedDomain, MyceliumClusterDomain.vocalNetwork);
        expect(graph.activeSection, SongJourneySection.intro);
        final harmLeavesAfter =
            graph.clusters[MyceliumClusterDomain.harmonyNetwork]!.childLeaves;
        expect(
          harmLeavesAfter.any((l) => l.title == 'Mbira Ancestral Chords'),
          isTrue,
        );
      },
    );

    // -------------------------------------------------------------------------
    // 3. Dynamic 2D -> 3D telemetry & child leaf updates
    // -------------------------------------------------------------------------
    test(
      '3. Dynamic 2D -> 3D telemetry & child leaf updates',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // 1. Check initial rhythm telemetry
        var graph = container.read(myceliumBiomeGraphProvider);
        var rhy = graph.clusters[MyceliumClusterDomain.rhythmNetwork]!;
        expect(rhy.liveTelemetrySummary, contains('112 BPM'));

        // 2. Mutate MPC Slicer BPM
        container.read(mpcSlicerProvider.notifier).setBpm(132);

        graph = container.read(myceliumBiomeGraphProvider);
        rhy = graph.clusters[MyceliumClusterDomain.rhythmNetwork]!;
        expect(rhy.liveTelemetrySummary, contains('132'));
        final bpmLeaf = rhy.childLeaves.firstWhere((l) => l.id == 'node_leaf_rhy_bpm');
        expect(bpmLeaf.title, contains('132'));

        // 3. Mutate Melody Sketchpad Musical Key
        container.read(melodySketchpadProvider.notifier).setMusicalKey('F#');

        graph = container.read(myceliumBiomeGraphProvider);
        final mel = graph.clusters[MyceliumClusterDomain.melodyCore]!;
        expect(mel.liveTelemetrySummary, contains('F#'));
        final keyLeaf = mel.childLeaves.firstWhere((l) => l.id == 'node_leaf_mel_key');
        expect(keyLeaf.title, contains('F#'));
      },
    );

    // -------------------------------------------------------------------------
    // 4. CockpitQuantumEntanglementRack renders 6 domains, stem locks, and triggers 3D dive
    // -------------------------------------------------------------------------
    testWidgets(
      '4. CockpitQuantumEntanglementRack renders 6 domains, stem locks, and triggers 3D dive',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const Scaffold(
                body: SingleChildScrollView(
                  child: CockpitQuantumEntanglementRack(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify rack container rendered
        expect(find.byKey(const Key('cockpit_quantum_entanglement_rack')), findsOneWidget);

        // Verify all 6 domain cards rendered
        for (final domain in MyceliumClusterDomain.values) {
          expect(
            find.byKey(Key('cockpit_domain_card_${domain.name}')),
            findsOneWidget,
          );
        }

        // Tap stem lock on melodyCore
        final lockFinder = find.byKey(const Key('cockpit_stem_lock_melodyCore'));
        expect(lockFinder, findsOneWidget);
        await tester.tap(lockFinder);
        await tester.pumpAndSettle();

        // Tap 3D jump on melodyCore to verify modal opens
        final jumpFinder = find.byKey(const Key('cockpit_jump_3d_melodyCore'));
        expect(jumpFinder, findsOneWidget);
        await tester.tap(jumpFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(SongDnaNodeTreeModal), findsOneWidget);
      },
    );

    // -------------------------------------------------------------------------
    // 5. BiomeClusterInspectorPanel stem-lock toggle & onExploreDetails tab teleportation
    // -------------------------------------------------------------------------
    testWidgets(
      '5. BiomeClusterInspectorPanel stem-lock toggle & onExploreDetails tab teleportation',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final container = ProviderContainer();
        addTearDown(container.dispose);

        final graph = container.read(myceliumBiomeGraphProvider);
        final voxCluster = graph.clusters[MyceliumClusterDomain.vocalNetwork]!;

        CockpitWorkspaceTab? teleportedTab;

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: Scaffold(
                body: BiomeClusterInspectorPanel(
                  cluster: voxCluster,
                  animationPhase: 0.0,
                  onClose: () {},
                  onSelectPartnerCluster: (_) {},
                  onExploreDetails: () {
                    teleportedTab = voxCluster.domain.targetCockpitTab;
                    container.read(studioCockpitTabProvider.notifier).state =
                        teleportedTab!;
                  },
                  onToggleStemLock: () {
                    container
                        .read(studioFormProvider.notifier)
                        .cycleClusterStemLockMode(voxCluster.domain);
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Test Stem-Lock button
        final lockBtn = find.byKey(const Key('biome_inspector_stem_lock_btn'));
        expect(lockBtn, findsOneWidget);
        await tester.tap(lockBtn);
        await tester.pumpAndSettle();

        // Verify state toggled in StudioFormState
        final form = container.read(studioFormProvider);
        expect(
          form.branchStemLockModes[voxCluster.domain.studioBranchKey],
          isNotNull,
        );

        // Test onExploreDetails button
        final exploreBtn = find.byKey(const Key('biome_explore_details_btn'));
        expect(exploreBtn, findsOneWidget);
        await tester.tap(exploreBtn);
        await tester.pumpAndSettle();

        expect(teleportedTab, CockpitWorkspaceTab.voice);
        expect(container.read(studioCockpitTabProvider), CockpitWorkspaceTab.voice);
      },
    );

    // -------------------------------------------------------------------------
    // 6. InlineCrateMpcWorkbench switches between Crate, MPC, and Sketchpad, handles chop & beat lock
    // -------------------------------------------------------------------------
    testWidgets(
      '6. InlineCrateMpcWorkbench switches between Crate, MPC, and Sketchpad, handles chop & beat lock',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const Scaffold(
                body: SingleChildScrollView(
                  child: InlineCrateMpcWorkbench(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify workbench rendered
        expect(find.byKey(const Key('cockpit_inline_crate_mpc_workbench')), findsOneWidget);
        expect(find.byKey(const Key('workbench_lock_beat_btn')), findsOneWidget);

        // Switch to MPC mode
        final mpcTab = find.byKey(const Key('workbench_mode_mpc'));
        expect(mpcTab, findsOneWidget);
        await tester.tap(mpcTab);
        await tester.pumpAndSettle();

        // Verify 8 pads rendered
        expect(find.byKey(const Key('workbench_mpc_pad_0')), findsOneWidget);

        // Switch to Sketchpad mode
        final sketchTab = find.byKey(const Key('workbench_mode_sketchpad'));
        expect(sketchTab, findsOneWidget);
        await tester.tap(sketchTab);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('workbench_open_sketchpad_btn')), findsOneWidget);

        // Verify initial state is lockedPure44k
        expect(
          container.read(studioFormProvider).branchStemLockModes['node_beat_tempo'],
          StemLockMode.lockedPure44k,
        );

        // Tap Beat Stem Lock toggle -> cycles to harmonicInpaint
        final beatLockBtn = find.byKey(const Key('workbench_lock_beat_btn'));
        await tester.tap(beatLockBtn);
        await tester.pumpAndSettle();

        final form = container.read(studioFormProvider);
        expect(
          form.branchStemLockModes['node_beat_tempo'],
          StemLockMode.harmonicInpaint,
        );
      },
    );

    // -------------------------------------------------------------------------
    // 7. Sonic Vibe Dice cycles 2D form parameters and synchronizes 3D Biome
    // -------------------------------------------------------------------------
    test(
      '7. Sonic Vibe Dice cycles 2D form parameters and synchronizes 3D Biome',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Warm up
        container.read(myceliumBiomeGraphProvider);
        final initialGenre = container.read(studioFormProvider).genre;

        // Cycle Vibe Dice
        container.read(studioFormProvider.notifier).cycleSonicVibeDice();
        final newGenre = container.read(studioFormProvider).genre;
        expect(newGenre, isNot(equals(initialGenre)));

        // Verify 3D Biome re-reconciled with new genre
        final graph = container.read(myceliumBiomeGraphProvider);
        final leadLeaf = graph
            .clusters[MyceliumClusterDomain.melodyCore]!
            .childLeaves
            .firstWhere((l) => l.id == 'node_leaf_mel_lead');
        expect(leadLeaf.title, contains(newGenre));
      },
    );
  });
}

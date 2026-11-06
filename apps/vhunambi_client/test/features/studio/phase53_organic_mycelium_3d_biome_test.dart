import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/studio/domain/models/mycelium_biome_models.dart';
import 'package:vhunambi_client/features/studio/presentation/controllers/biome_camera_controller.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/mycelium_biome_provider.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/biome/biome_cluster_inspector_panel.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/biome/biome_hud_decks.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/biome/biome_top_bar.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/biome/song_journey_timeline_scrubber.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/song_dna_node_tree_modal.dart';

void main() {
  group('Phase 53: 3D Organic Mycelium Biome ("A Song as a Living Ecosystem")', () {
    // -------------------------------------------------------------------------
    // 1. Milestone M1: Pure Dart 3D Y-Up Domain Models & Terrain Elevation Math
    // -------------------------------------------------------------------------
    test(
      '1. Vector3D operations, dot product, normalization, and distance',
      () {
        const v1 = Vector3D(10.0, 20.0, 30.0);
        const v2 = Vector3D(5.0, 10.0, 15.0);

        final added = v1 + v2;
        expect(added.x, 15.0);
        expect(added.y, 30.0);
        expect(added.z, 45.0);

        final subtracted = v1 - v2;
        expect(subtracted.x, 5.0);
        expect(subtracted.y, 10.0);
        expect(subtracted.z, 15.0);

        final scaled = v2 * 2.0;
        expect(scaled, equals(v1));

        expect(v1.dot(v2), 10.0 * 5.0 + 20.0 * 10.0 + 30.0 * 15.0);
        expect(v1.normalized.length, closeTo(1.0, 1e-4));
        expect(v1.distanceTo(v2), closeTo((v1 - v2).length, 1e-4));

        final lerped = Vector3D.lerp(v1, v2, 0.5);
        expect(lerped.x, 7.5);
        expect(lerped.y, 15.0);
        expect(lerped.z, 22.5);
      },
    );

    test(
      '2. BiomeTerrainMath heightAt(x, z) satisfies Y = h(X, Z) >= 0 everywhere',
      () {
        // Test at all 6 cluster coordinates
        final testCoords = [
          (0.0, 0.0), // melodyCore
          (-195.0, 95.0), // rhythmNetwork
          (-155.0, -90.0), // vocalNetwork
          (165.0, -85.0), // harmonyNetwork
          (190.0, 75.0), // emotionNetwork
          (-35.0, 155.0), // productionNetwork
          (-300.0, -240.0), // boundary min
          (300.0, 240.0), // boundary max
        ];

        for (final (x, z) in testCoords) {
          final h = BiomeTerrainMath.heightAt(x, z);
          expect(h, greaterThan(0.0));
        }

        // Center mound (melodyCore) should be the tallest topographic feature
        final melHeight = BiomeTerrainMath.heightAt(0.0, 0.0);
        expect(melHeight, closeTo(32.0, 2.0));

        // Normal vector should have unit magnitude and positive Y (pointing up)
        final norm = BiomeTerrainMath.normalAt(0.0, 0.0);
        expect(norm.length, closeTo(1.0, 1e-4));
        expect(norm.y, greaterThan(0.5));
      },
    );

    // -------------------------------------------------------------------------
    // 2. Milestone M2: Space-Colonization Mycelium Web, 16 3D Sprouts & Rootlets
    // -------------------------------------------------------------------------
    test(
      '3. MyceliumHyphaEdge 15 arterial edges, 9 waypoints on Y = h(X, Z) + 1.5',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final graph = container.read(myceliumBiomeGraphProvider);

        // Exactly 15 edges between all pairs of 6 clusters (6 * 5 / 2 = 15)
        expect(graph.hyphaeEdges.length, 15);

        for (final edge in graph.hyphaeEdges) {
          expect(edge.splineWaypoints.length, 9);
          // Each waypoint must satisfy Y >= 1.5
          for (final wp in edge.splineWaypoints) {
            expect(wp.y, greaterThan(1.5));
          }

          // sampleAt(t) returns smooth continuous 3D interpolation
          final mid = edge.sampleAt(0.5);
          expect(mid.length, greaterThan(0.0));
        }

        // Exactly 72 rootlet tendrils (12 per cluster * 6 clusters)
        expect(graph.rootTendrils.length, 72);
        for (final tendril in graph.rootTendrils) {
          expect(tendril.waypoints.length, 5);
          expect(tendril.thickness, greaterThan(0.0));
        }

        // Exactly 16 miniature 3D sprout / pinhead mushrooms
        expect(graph.sproutNodes.length, 16);
        for (final sprout in graph.sproutNodes) {
          expect(sprout.height, inInclusiveRange(9.0, 18.0));
          expect(sprout.capRadius, inInclusiveRange(5.0, 11.0));
          expect(sprout.apexPosition.y, greaterThan(sprout.rootPosition.y));
        }
      },
    );

    // -------------------------------------------------------------------------
    // 3. Milestone M3: 6 Musical Clusters Seed Factory & Entangled Riverpod Notifier
    // -------------------------------------------------------------------------
    test(
      '4. Canonical 6-cluster Right-Handed 3D Y-Up geometry & Studio sync',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final graph = container.read(myceliumBiomeGraphProvider);
        expect(graph.clusters.length, 6);

        // 1. melodyCore
        final mel = graph.clusters[MyceliumClusterDomain.melodyCore]!;
        expect(mel.capApexPosition.x, closeTo(0.0, 0.1));
        expect(mel.capApexPosition.y, closeTo(140.0, 1.0));
        expect(mel.capApexPosition.z, closeTo(0.0, 0.1));
        expect(mel.capRadius, 56.0);
        expect(mel.childLeaves.length, 5);

        // 2. rhythmNetwork
        final rhy = graph.clusters[MyceliumClusterDomain.rhythmNetwork]!;
        expect(rhy.capApexPosition.x, closeTo(-195.0, 0.1));
        expect(rhy.capApexPosition.y, closeTo(96.0, 1.0));
        expect(rhy.capApexPosition.z, closeTo(95.0, 0.1));
        expect(rhy.capRadius, 42.0);
        expect(rhy.childLeaves.length, 5);

        // 3. vocalNetwork
        final vox = graph.clusters[MyceliumClusterDomain.vocalNetwork]!;
        expect(vox.capApexPosition.x, closeTo(-155.0, 0.1));
        expect(vox.capApexPosition.y, closeTo(120.0, 1.0));
        expect(vox.capApexPosition.z, closeTo(-90.0, 0.1));
        expect(vox.capRadius, 47.0);

        // 4. harmonyNetwork
        final harm = graph.clusters[MyceliumClusterDomain.harmonyNetwork]!;
        expect(harm.capApexPosition.x, closeTo(165.0, 0.1));
        expect(harm.capApexPosition.y, closeTo(115.0, 1.0));
        expect(harm.capApexPosition.z, closeTo(-85.0, 0.1));

        // 5. emotionNetwork
        final emo = graph.clusters[MyceliumClusterDomain.emotionNetwork]!;
        expect(emo.capApexPosition.x, closeTo(190.0, 0.1));
        expect(emo.capApexPosition.y, closeTo(96.0, 1.0));
        expect(emo.capApexPosition.z, closeTo(75.0, 0.1));

        // 6. productionNetwork
        final prod = graph.clusters[MyceliumClusterDomain.productionNetwork]!;
        expect(prod.capApexPosition.x, closeTo(-35.0, 0.1));
        expect(prod.capApexPosition.y, closeTo(82.0, 1.0));
        expect(prod.capApexPosition.z, closeTo(155.0, 0.1));

        // Test cluster focusing
        final notifier = container.read(myceliumBiomeGraphProvider.notifier);
        notifier.focusCluster(MyceliumClusterDomain.melodyCore);
        expect(
          container.read(myceliumBiomeGraphProvider).focusedDomain,
          MyceliumClusterDomain.melodyCore,
        );
        expect(
          container.read(myceliumBiomeGraphProvider).focusedCluster,
          isNotNull,
        );

        // Test growth progress
        notifier.setGrowthProgress(0.5);
        expect(
          container.read(myceliumBiomeGraphProvider).growthPhase,
          BiomeGrowthPhase.hyphaeBranching,
        );

        // Test dynamic instrument leaf addition
        notifier.addInstrumentLeaf(
          name: 'Kora Solo',
          iconIdentifier: 'musicNotes',
        );
        final updatedHarm = container
            .read(myceliumBiomeGraphProvider)
            .clusters[MyceliumClusterDomain.harmonyNetwork]!;
        expect(
          updatedHarm.childLeaves.any((l) => l.title == 'Kora Solo'),
          isTrue,
        );
      },
    );

    // -------------------------------------------------------------------------
    // 4. Milestone M4: Projection Engine & 3D Hit-Testing Verification
    // -------------------------------------------------------------------------
    test(
      '5. BiomeProjectionEngine projects and synchronously hit-tests caps',
      () {
        const camera = BiomeCameraState(
          target: Vector3D(0.0, 55.0, 0.0),
          yaw: 0.0,
          pitch: 32.0 * math.pi / 180.0,
          distance: 420.0,
        );
        const viewport = Size(1080.0, 1920.0);

        // Project central melodyCore apex (0, 140, 0)
        final proj = BiomeProjectionEngine.project3D(
          const Vector3D(0.0, 140.0, 0.0),
          camera,
          viewport,
        );

        expect(proj, isNotNull);
        expect(proj!.screenOffset.dx, closeTo(viewport.width * 0.5, 1.0));
        // In Y-Up space, Y=140 is higher than target Y=55, so it must project HIGHER (smaller sy)
        expect(proj.screenOffset.dy, lessThan(viewport.height * 0.5));

        final container = ProviderContainer();
        addTearDown(container.dispose);
        final graph = container.read(myceliumBiomeGraphProvider);

        // Hit-test directly at projected melodyCore apex
        final hitResult = BiomeProjectionEngine.hitTest(
          tapPosition: proj.screenOffset,
          viewportSize: viewport,
          graph: graph,
          camera: camera,
        );

        expect(hitResult.hasHit, isTrue);
        expect(hitResult.hitCluster, MyceliumClusterDomain.melodyCore);
      },
    );

    // -------------------------------------------------------------------------
    // 5. Milestone M4 & M5: HUD Decks & Interactive Widgets Test
    // -------------------------------------------------------------------------
    testWidgets(
      '6. BiomeTopBar renders and triggers play/pause, mute, close callbacks',
      (tester) async {
        bool playToggled = false;
        bool muteToggled = false;
        bool closed = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: BiomeTopBar(
                trackTitle: 'African Dreams',
                isPlaying: true,
                isMuted: false,
                onTogglePlay: () => playToggled = true,
                onToggleMute: () => muteToggled = true,
                onClose: () => closed = true,
              ),
            ),
          ),
        );

        expect(find.byKey(const Key('biome_top_bar')), findsOneWidget);
        expect(find.text('African Dreams'), findsOneWidget);

        await tester.tap(find.byKey(const Key('biome_play_pause_btn')));
        expect(playToggled, isTrue);

        await tester.tap(find.byKey(const Key('biome_mute_btn')));
        expect(muteToggled, isTrue);

        await tester.tap(find.byKey(const Key('biome_close_btn')));
        expect(closed, isTrue);
      },
    );

    testWidgets(
      '7. SongJourneyTimelineScrubber allows selecting arrangement sections',
      (tester) async {
        SongJourneySection selectedSection = SongJourneySection.chorus;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return SongJourneyTimelineScrubber(
                    activeSection: selectedSection,
                    onSelectSection: (s) => setState(() => selectedSection = s),
                  );
                },
              ),
            ),
          ),
        );

        expect(
          find.byKey(const Key('biome_song_journey_scrubber')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('biome_section_intro')), findsOneWidget);
        expect(find.byKey(const Key('biome_section_verse')), findsOneWidget);
        expect(find.byKey(const Key('biome_section_chorus')), findsOneWidget);
        expect(find.byKey(const Key('biome_section_bridge')), findsOneWidget);
        expect(find.byKey(const Key('biome_section_outro')), findsOneWidget);

        await tester.tap(find.byKey(const Key('biome_section_bridge')));
        await tester.pump();
        expect(selectedSection, SongJourneySection.bridge);
      },
    );

    testWidgets(
      '8. BiomeInteractiveControlsBar triggers rotate, zoom, focus, compare, analyse',
      (tester) async {
        bool rotate = false;
        bool zoom = false;
        bool focus = false;
        bool compare = false;
        bool analyse = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: BiomeInteractiveControlsBar(
                isAutoRotating: false,
                isMacroZoomed: false,
                isCompareActive: false,
                isAnalyseActive: false,
                onToggleRotate: () => rotate = true,
                onToggleZoom: () => zoom = true,
                onFocusReset: () => focus = true,
                onToggleCompare: () => compare = true,
                onToggleAnalyse: () => analyse = true,
              ),
            ),
          ),
        );

        expect(find.byKey(const Key('biome_controls_bar')), findsOneWidget);

        await tester.tap(find.byKey(const Key('biome_ctrl_rotate')));
        expect(rotate, isTrue);

        await tester.tap(find.byKey(const Key('biome_ctrl_zoom')));
        expect(zoom, isTrue);

        await tester.tap(find.byKey(const Key('biome_ctrl_focus')));
        expect(focus, isTrue);

        await tester.tap(find.byKey(const Key('biome_ctrl_compare')));
        expect(compare, isTrue);

        await tester.tap(find.byKey(const Key('biome_ctrl_analyse')));
        expect(analyse, isTrue);
      },
    );

    testWidgets('9. BiomeNetworkLayersFilter toggles ecological layer pills', (
      tester,
    ) async {
      MyceliumNetworkLayer? toggled;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: BiomeNetworkLayersFilter(
              activeLayers: const {
                MyceliumNetworkLayer.coreElements,
                MyceliumNetworkLayer.supportingElements,
                MyceliumNetworkLayer.atmosphere,
                MyceliumNetworkLayer.emotionalLayer,
              },
              onToggleLayer: (l) => toggled = l,
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('biome_network_layers_filter')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('biome_layer_coreElements')));
      expect(toggled, MyceliumNetworkLayer.coreElements);
    });

    testWidgets(
      '10. BiomeClusterInspectorPanel displays live waveform, 3 metrics, and related chips',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final cluster = container
            .read(myceliumBiomeGraphProvider)
            .clusters[MyceliumClusterDomain.melodyCore]!;

        MyceliumClusterDomain? selectedPartner;
        bool closed = false;
        bool explore = false;

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: Scaffold(
                body: BiomeClusterInspectorPanel(
                  cluster: cluster,
                  animationPhase: 0.5,
                  onClose: () => closed = true,
                  onSelectPartnerCluster: (p) => selectedPartner = p,
                  onExploreDetails: () => explore = true,
                  onToggleStemLock: () {},
                ),
              ),
            ),
          ),
        );

        expect(
          find.byKey(const Key('biome_cluster_inspector_panel')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('biome_inspector_waveform')),
          findsOneWidget,
        );
        expect(find.text('92%'), findsOneWidget); // Intensity
        expect(find.text('78%'), findsOneWidget); // Complexity
        expect(find.text('95%'), findsOneWidget); // Influence

        // Tapping a related partner chip
        expect(
          find.byKey(const Key('biome_related_chip_harmonyNetwork')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const Key('biome_related_chip_harmonyNetwork')),
        );
        expect(selectedPartner, MyceliumClusterDomain.harmonyNetwork);

        // Tapping Explore Details
        await tester.tap(find.byKey(const Key('biome_explore_details_btn')));
        expect(explore, isTrue);

        // Tapping Close
        await tester.tap(find.byKey(const Key('biome_inspector_close_btn')));
        expect(closed, isTrue);
      },
    );

    testWidgets(
      '11. SongDnaNodeTreeModal renders 3D Mycelium Biome, cluster badges, and triggers inspector',
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
        await tester.pump(const Duration(milliseconds: 300));

        // Verify sovereign opaque scaffold
        expect(find.byKey(const Key('song_dna_3d_tree_modal')), findsOneWidget);

        // Verify Biome Top Bar
        expect(find.byKey(const Key('biome_top_bar')), findsOneWidget);

        // Verify 6 semantic cluster badges exist
        expect(
          find.byKey(const Key('biome_cluster_badge_melodyCore')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('biome_cluster_badge_rhythmNetwork')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('biome_cluster_badge_vocalNetwork')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('biome_cluster_badge_harmonyNetwork')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('biome_cluster_badge_emotionNetwork')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('biome_cluster_badge_productionNetwork')),
          findsOneWidget,
        );

        // Verify Overview decks
        expect(find.byKey(const Key('biome_controls_bar')), findsOneWidget);
        expect(
          find.byKey(const Key('biome_network_layers_filter')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('biome_song_journey_scrubber')),
          findsOneWidget,
        );

        // Tap Melody Core badge to focus canopy
        await tester.tap(
          find.byKey(const Key('biome_cluster_badge_melodyCore')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Inspector panel should appear
        expect(
          find.byKey(const Key('biome_cluster_inspector_panel')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('song_dna_return_overview_btn')),
          findsOneWidget,
        );

        // Tap Return to Overview
        await tester.tap(find.byKey(const Key('song_dna_return_overview_btn')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(
          find.byKey(const Key('song_dna_return_overview_btn')),
          findsNothing,
        );

        container.dispose();
      },
    );
  });
}

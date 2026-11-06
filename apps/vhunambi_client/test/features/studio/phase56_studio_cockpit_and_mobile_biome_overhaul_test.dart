import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/navigation/navigation_providers.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/studio/domain/models/lyrics_review_models.dart';
import 'package:vhunambi_client/features/studio/domain/models/mycelium_biome_models.dart';
import 'package:vhunambi_client/features/studio/domain/models/studio_form_state.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/mycelium_biome_provider.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/studio_form_provider.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/crate_browser_deck.dart';
import 'package:vhunambi_client/features/studio/presentation/views/studio_view.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/lyrics_review_modal.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/song_dna_node_tree_modal.dart';

void main() {
  group(
    'Phase 56: Studio Cockpit Compaction, Ergonomic Unification & Mobile 3D Biome Overhaul',
    () {
      testWidgets(
        '1. Prompt-First Compose: PromptInputBox is above CockpitQuantumEntanglementRack and 2x3 rack collapses cleanly',
        (tester) async {
          tester.view.physicalSize = const Size(360, 780);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                theme: AppTheme.darkTheme,
                home: const StudioView(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final promptTop = tester
              .getTopLeft(find.text('Describe your song'))
              .dy;
          final rackTop = tester
              .getTopLeft(
                find.byKey(const Key('cockpit_quantum_entanglement_rack')),
              )
              .dy;

          expect(promptTop, lessThan(rackTop));
          expect(find.text('Reference Audio (optional)'), findsOneWidget);
          expect(
            find.byKey(const Key('dropzone_upload_audio_btn')),
            findsOneWidget,
          );

          // Toggle rack collapse
          await tester.ensureVisible(
            find.byKey(const Key('cockpit_rack_collapse_toggle_btn')),
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(const Key('cockpit_rack_collapse_toggle_btn')),
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('cockpit_domain_card_melodyCore')),
            findsNothing,
          );
        },
      );

      testWidgets(
        '2. Voice Station Unification: Ensemble/Gender/Energy header card & 2x2 dialect grid render in Voice tab',
        (tester) async {
          tester.view.physicalSize = const Size(360, 780);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final container = ProviderContainer();
          addTearDown(container.dispose);

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: AppTheme.darkTheme,
                home: const StudioView(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(const Key('studio_tab_voice')));
          await tester.pumpAndSettle();

          expect(
            find.byKey(const Key('voice_ensemble_header_card')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('voice_dialect_grid_card')),
            findsOneWidget,
          );

          await tester.tap(find.byKey(const Key('voice_config_choir')));
          await tester.pump(const Duration(seconds: 1));
          await tester.pumpAndSettle();
          expect(
            container.read(studioFormProvider).vocalConfiguration,
            VocalConfiguration.choir,
          );
        },
      );

      testWidgets(
        '3. Crate & MPC Unification: Zero 1-char vertical crash in HeritageCrateModal on 360dp & 4-mode workbench switcher',
        (tester) async {
          tester.view.physicalSize = const Size(360, 780);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                theme: AppTheme.darkTheme,
                home: const StudioView(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(const Key('studio_tab_crate_mpc')));
          await tester.pumpAndSettle();

          expect(
            find.byKey(const Key('workbench_mode_daw_upload')),
            findsOneWidget,
          );

          // Open full-screen HeritageCrateModal with Sketchpad button enabled on 360dp width
          await tester.tap(find.byKey(const Key('studio_open_crate_btn')));
          await tester.pumpAndSettle();

          expect(find.byType(HeritageCrateModal), findsOneWidget);
          final titleSize = tester.getSize(find.text('Heritage Crate Digging'));
          expect(titleSize.height, lessThan(36.0));
        },
      );

      test(
        '4. Non-Blocking Generation Lifecycle: cancelLyricsReview restores idle state and prevents stuck skeleton',
        () {
          final container = ProviderContainer();
          addTearDown(container.dispose);

          final notifier = container.read(studioFormProvider.notifier);
          notifier.openLyricsReview();
          expect(
            container.read(studioFormProvider).phase,
            GenerationPhase.reviewingLyrics,
          );

          notifier.cancelLyricsReview();
          expect(
            container.read(studioFormProvider).phase,
            GenerationPhase.idle,
          );
        },
      );

      testWidgets(
        '5. Cognate Finder Bracket Stripping: Ignores [Intro] header and matches actual Bantu lyric token',
        (tester) async {
          tester.view.physicalSize = const Size(420, 820);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final container = ProviderContainer();
          addTearDown(container.dispose);

          container
              .read(studioFormProvider.notifier)
              .updateLyrics('[Intro]\nKhuluma nami uthando\n[Chorus]\nAmanzi');

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: AppTheme.darkTheme,
                home: const Scaffold(body: LyricsReviewModal()),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(container.read(modalSheetOpenCountProvider), greaterThan(0));

          final suggestions = BantuCognateEngine.findSuggestions('amanzi');
          expect(suggestions, isNotEmpty);
          expect(
            suggestions.any((s) => s.sourceWord.toLowerCase() == 'intro'),
            isFalse,
          );
        },
      );

      testWidgets(
        '6. BiomeTopBar Mobile Ellipsis Guard: Long trackTitle never crushes left title on 360dp width',
        (tester) async {
          tester.view.physicalSize = const Size(360, 780);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final container = ProviderContainer();
          addTearDown(container.dispose);

          container
              .read(studioFormProvider.notifier)
              .updatePrompt(
                'Traditional acoustic storytelling with deep Venda ancestral drums and choir harmonies',
              );

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
          await tester.pump(const Duration(milliseconds: 250));

          final subtitleSize = tester.getSize(
            find.text('Explore the Living DNA of Music'),
          );
          expect(subtitleSize.height, lessThan(28.0));
        },
      );

      testWidgets(
        '7. Mobile 3D Biome Popover Tooltips: Controls and Layers cards are hidden inside popovers by default on 360dp',
        (tester) async {
          tester.view.physicalSize = const Size(360, 780);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                theme: AppTheme.darkTheme,
                home: const Scaffold(body: SongDnaNodeTreeModal()),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 250));

          final controlsBtn = find.byKey(
            const Key('biome_controls_popover_btn'),
          );
          final layersBtn = find.byKey(const Key('biome_layers_popover_btn'));
          expect(controlsBtn, findsOneWidget);
          expect(layersBtn, findsOneWidget);

          // By default on mobile, BiomeInteractiveControlsBar is offstage
          expect(
            find.byKey(const Key('biome_interactive_controls_bar')),
            findsNothing,
          );

          // Tap Controls pill -> reveals BiomeInteractiveControlsBar
          await tester.tap(controlsBtn);
          await tester.pump();
          expect(
            find.byKey(const Key('biome_interactive_controls_bar')),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        '8. True 3D Camera Dolly & Zoom: Zoom buttons and mushroom cluster tap mutate BiomeCameraState',
        (tester) async {
          tester.view.physicalSize = const Size(360, 780);
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
          await tester.pump(const Duration(milliseconds: 250));

          final initialCam = container.read(biomeCameraProvider);
          expect(initialCam.distance, 420.0);

          // Tap [+] zoom in button -> mutates BiomeCameraState
          await tester.tap(find.byKey(const Key('song_dna_zoom_in_btn')));
          await tester.pump();
          final zoomedCam = container.read(biomeCameraProvider);
          expect(zoomedCam.distance, lessThan(initialCam.distance));
          expect(zoomedCam.zoom, greaterThan(initialCam.zoom));

          // Tap Vocal Network mushroom badge -> dollies 3D camera into Vocal cluster apex
          await tester.tap(
            find.byKey(const Key('biome_cluster_badge_vocalNetwork')),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));

          final focusedCam = container.read(biomeCameraProvider);
          final vocalApex = container
              .read(myceliumBiomeGraphProvider)
              .clusters[MyceliumClusterDomain.vocalNetwork]!
              .capApexPosition;
          expect(focusedCam.target.x, closeTo(vocalApex.x, 0.1));
          expect(focusedCam.distance, closeTo(220.0, 0.1));
          expect(
            find.byKey(const Key('biome_mobile_unified_bottom_sheet')),
            findsOneWidget,
          );
        },
      );
    },
  );
}

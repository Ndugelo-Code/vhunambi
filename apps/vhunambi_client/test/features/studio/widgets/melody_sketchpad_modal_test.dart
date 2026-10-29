import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/crate_browser_deck.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/melody_sketchpad_modal.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/reference_audio_dropzone.dart';

void main() {
  group('Phase 27 — Device-Adaptive Melody & Log-Drum Sketchpad UI Tests', () {
    testWidgets(
      'Mobile viewport (< 768px) renders 4-Step Bar Paginated Grid (44x44dp cells), switches to 8-Pad Live Deck, and attaches song reference',
      (tester) async {
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: MelodySketchpadModal(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify Mobile 4-Bar Paginator & Bar Grid
        expect(find.byKey(const Key('mobile_bar_grid')), findsOneWidget);
        expect(find.byKey(const Key('mobile_bar_page_0')), findsOneWidget);
        expect(find.byKey(const Key('mobile_bar_page_1')), findsOneWidget);

        // Verify cell touch target >= 44x44dp
        final cellFinder = find.byKey(const Key('sketchpad_cell_0_0'));
        expect(cellFinder, findsOneWidget);
        final cellSize = tester.getSize(cellFinder);
        expect(cellSize.width, greaterThanOrEqualTo(44.0));
        expect(cellSize.height, greaterThanOrEqualTo(44.0));

        // Switch to Mobile 8-Pad Live Scale Performance Deck
        await tester.tap(find.byKey(const Key('mobile_input_mode_toggle')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('mobile_live_pad_deck')), findsOneWidget);
        expect(find.byKey(const Key('mobile_scale_pad_0')), findsOneWidget);

        // Tap Euclidean Groove Generator
        await tester.tap(find.byKey(const Key('sketchpad_euclidean_groove_btn')));
        await tester.pumpAndSettle();

        // Tap Attach as Song Reference & Master Layer
        await tester.tap(find.byKey(const Key('sketchpad_attach_reference_btn')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('sketchpad_attached_ready_badge')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Desktop viewport (> 1024px) renders full 16-Step x 8-Row Split DAW Piano Roll, Chord Voicing Stamp, and Velocity/Glide Stalk Lane',
      (tester) async {
        tester.view.physicalSize = const Size(1366, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: MelodySketchpadModal(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify Desktop Piano Roll + Chord Stamp + Velocity Lane
        expect(find.byKey(const Key('desktop_piano_roll_grid')), findsOneWidget);
        expect(
          find.byKey(const Key('desktop_chord_stamp_triad')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('desktop_velocity_lane')), findsOneWidget);
        expect(find.byKey(const Key('desktop_step_glide_0')), findsOneWidget);

        // Activate Triad Stamp and click step 15 on row 2
        await tester.tap(find.byKey(const Key('desktop_chord_stamp_triad')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('sketchpad_cell_2_15')));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'ReferenceAudioDropzone and CrateBrowserDeck expose 1-tap Melody Sketchpad entrypoints',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 860);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    ReferenceAudioDropzone(),
                    Expanded(child: CrateBrowserDeck()),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('dropzone_open_sketchpad_btn')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('crate_open_sketchpad_btn')),
          findsOneWidget,
        );
      },
    );
  });
}


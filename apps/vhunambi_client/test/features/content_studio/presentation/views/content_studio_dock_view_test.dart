import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/song_metadata_dna.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/lyric_word_timestamp.dart';
import 'package:vhunambi_client/features/content_studio/presentation/views/content_studio_dock_view.dart';
import 'package:vhunambi_client/features/content_studio/presentation/widgets/kinetic_preview_canvas.dart';
import 'package:vhunambi_client/features/content_studio/presentation/widgets/typography_preset_picker.dart';
import 'package:vhunambi_client/features/content_studio/presentation/widgets/duration_trim_scrubber.dart';
import 'package:vhunambi_client/features/content_studio/presentation/widgets/atmospheric_effects_deck.dart';
import 'package:vhunambi_client/features/content_studio/presentation/widgets/export_action_sheet.dart';

void main() {
  group('ContentStudioDockView Widget Tests', () {
    late SongMetadataDna sampleDna;

    setUp(() {
      sampleDna = const SongMetadataDna(
        id: 'dna_reel_view_test',
        title: 'Mbilu Yanga Anthem',
        genre: 'Amapiano',
        language: 'Tshivenḓa',
        musical: MusicalDna(bpm: 112, key: 'F# Minor', energyBracket: 'mid', durationSec: 180),
        vocals: VocalsDna(deliveryMode: 'melodic', gender: 'female', energy: 'mid'),
        visualTheme: VisualThemeDna(mood: 'Warm Sunset', comfyPrompt: 'Golden hour lights', seed: 101),
        alignment: [
          LyricWordTimestamp(word: 'Ndi', start: 0.0, end: 1.0, stanzaIndex: 0),
          LyricWordTimestamp(word: 'mufunwa', start: 1.1, end: 2.0, stanzaIndex: 0),
        ],
      );
    });

    testWidgets('renders desktop split-screen cockpit at 1200x800', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ContentStudioDockView(
              initialDna: sampleDna,
              initialAudioUrl: 'https://r2.vhunambi.com/audio.mp3',
              initialCoverArtUrl: 'https://r2.vhunambi.com/cover.png',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Mbilu Yanga Anthem'), findsOneWidget);
      expect(find.byType(KineticPreviewCanvas), findsOneWidget);
      expect(find.byType(DurationTrimScrubber), findsOneWidget);
      expect(find.byType(TypographyPresetPicker), findsOneWidget);
      expect(find.byType(AtmosphericEffectsDeck), findsOneWidget);
      expect(find.text('Render & Export 1080x1920 MP4'), findsOneWidget);
    });

    testWidgets('renders mobile layout at 400x800 and interacts with export', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ContentStudioDockView(
              initialDna: sampleDna,
              initialAudioUrl: 'https://r2.vhunambi.com/audio.mp3',
              initialCoverArtUrl: 'https://r2.vhunambi.com/cover.png',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(KineticPreviewCanvas), findsOneWidget);
      expect(find.byType(DurationTrimScrubber), findsOneWidget);

      // Tap Export MP4 in AppBar
      final exportBtn = find.byKey(const Key('app_bar_export_button'));
      expect(exportBtn, findsOneWidget);
      await tester.tap(exportBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Modal bottom sheet appears
      expect(find.byType(ExportActionSheet), findsOneWidget);
    });
  });
}

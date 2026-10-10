import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/content_studio_preset.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/lyric_word_timestamp.dart';
import 'package:vhunambi_client/features/content_studio/presentation/widgets/kinetic_preview_canvas.dart';

void main() {
  group('KineticPreviewCanvas Widget Tests', () {
    testWidgets('renders fallback artwork when coverArtUrl is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                height: 533,
                child: KineticPreviewCanvas(
                  coverArtUrl: null,
                  words: [],
                  preset: LyricTypographyPreset.kineticBounce,
                  effects: AtmosphericEffects(),
                  playbackPositionSec: 0.0,
                  isPlaying: false,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('VHUNAMBI 9:16 COVER'), findsOneWidget);
      expect(find.text('♪ Instrumental Rhythms & Harmonies ♪'), findsOneWidget);
    });

    testWidgets('renders word list and highlights active word', (tester) async {
      final words = [
        const LyricWordTimestamp(word: 'Vhubvo', start: 0.0, end: 1.0, stanzaIndex: 0),
        const LyricWordTimestamp(word: 'Hanga', start: 1.1, end: 2.0, stanzaIndex: 0),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                height: 533,
                child: KineticPreviewCanvas(
                  coverArtUrl: null,
                  words: words,
                  preset: LyricTypographyPreset.kineticBounce,
                  effects: const AtmosphericEffects(),
                  playbackPositionSec: 0.5,
                  isPlaying: true,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('VHUBVO'), findsOneWidget);
      expect(find.text('HANGA'), findsOneWidget);
    });
  });
}

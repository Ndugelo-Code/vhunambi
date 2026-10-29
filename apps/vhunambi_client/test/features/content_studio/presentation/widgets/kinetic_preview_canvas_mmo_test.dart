import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/content_studio_preset.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/lyric_word_timestamp.dart';
import 'package:vhunambi_client/features/content_studio/presentation/providers/master_media_object_provider.dart';
import 'package:vhunambi_client/features/content_studio/presentation/widgets/kinetic_preview_canvas.dart';

void main() {
  group('KineticPreviewCanvas MMO Telemetry & Choreography Tests', () {
    const sampleWords = [
      LyricWordTimestamp(
        word: 'Woza',
        start: 0.0,
        end: 1.0,
        phoneticStress: 0.95,
        isCulturalIdiom: true,
      ),
      LyricWordTimestamp(
        word: 'Vhunambi',
        start: 1.1,
        end: 2.0,
        phoneticStress: 0.5,
        isCulturalIdiom: false,
      ),
    ];

    testWidgets('renders modulated canvas with log drum snap zoom and particles',
        (tester) async {
      const snapshot = FrameModulationSnapshot(
        effectiveBassEnergy: 0.85,
        effectiveDrumsEnergy: 0.9,
        effectiveMelodicEnergy: 0.7,
        effectiveVocalGlow: 0.95,
        logDrumSnapZoom: 0.98,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                height: 533,
                child: KineticPreviewCanvas(
                  coverArtUrl: null,
                  words: sampleWords,
                  preset: LyricTypographyPreset.kineticBounce,
                  effects: AtmosphericEffects(
                    kenBurnsMotion: true,
                    filmGrain: true,
                    bassPulse: true,
                  ),
                  playbackPositionSec: 0.5,
                  isPlaying: true,
                  modulationSnapshot: snapshot,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('WOZA'), findsOneWidget);
      expect(find.text('VHUNAMBI'), findsOneWidget);

      // Verify idiom word text widget renders with brandPrimary
      final textWidget = tester.widget<Text>(find.text('WOZA'));
      expect(textWidget.style?.color, equals(AppColors.brandPrimary));
    });

    testWidgets('renders all 4 typography presets with phonetic bloom without crashing',
        (tester) async {
      const presets = [
        LyricTypographyPreset.kineticBounce,
        LyricTypographyPreset.luminousGlow,
        LyricTypographyPreset.minimalSubtitle,
        LyricTypographyPreset.bantuCalligraphy,
      ];

      for (final preset in presets) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  height: 533,
                  child: KineticPreviewCanvas(
                    coverArtUrl: null,
                    words: sampleWords,
                    preset: preset,
                    effects: const AtmosphericEffects(),
                    playbackPositionSec: 0.5,
                    isPlaying: true,
                    modulationSnapshot: const FrameModulationSnapshot(
                      effectiveVocalGlow: 0.8,
                      effectiveBassEnergy: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        expect(find.byType(KineticPreviewCanvas), findsOneWidget);
      }
    });
  });
}

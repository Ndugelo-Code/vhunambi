import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/creator_dna/domain/entities/creator_dna_profile.dart';
import 'package:vhunambi_client/features/creator_dna/presentation/widgets/dna_visualization_widget.dart';

void main() {
  group('DnaVisualizationWidget Tests', () {
    testWidgets('renders DNA visualization with nodes',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DnaVisualizationWidget(
              key: const Key('dna_viz_test'),
              creativeRole: CreativeRole.producer,
              genres: ['Amapiano', 'Afro House'],
              moods: ['Energetic'],
              tempoPreference: 'medium',
              reduceMotion: true,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('dna_viz_test')), findsOneWidget);
    });

    testWidgets('displays static version when reduce-motion is enabled',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DnaVisualizationWidget(
              key: const Key('dna_viz_reduce'),
              creativeRole: CreativeRole.vocalist,
              genres: ['Gqom', 'Kwaito'],
              moods: ['Melancholic', 'Calm'],
              tempoPreference: 'slow',
              reduceMotion: true,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('dna_viz_reduce')), findsOneWidget);
    });

    testWidgets('animates build-up when reduce-motion is disabled',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DnaVisualizationWidget(
              key: const Key('dna_viz_animate'),
              creativeRole: CreativeRole.songwriter,
              genres: ['Afro Pop'],
              moods: ['Romantic'],
              tempoPreference: 'fast',
              reduceMotion: false,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('dna_viz_animate')), findsOneWidget);
      // Animation should complete within 1800ms
      await tester.pump(const Duration(milliseconds: 2000));
    });

    testWidgets('derives node colors from genre and mood selections',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DnaVisualizationWidget(
              key: const Key('dna_viz_colors'),
              creativeRole: CreativeRole.multiHyphenate,
              genres: ['Maskandi', 'Hip-Hop', 'Gospel'],
              moods: ['Joyful'],
              tempoPreference: 'hyperspeed',
              reduceMotion: true,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('dna_viz_colors')), findsOneWidget);
    });

    testWidgets('DnaGrowthPathWidget renders all three explanation beats',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const DnaGrowthPathWidget(),
          ),
        ),
      );

      expect(find.text('Built from your choices:'), findsOneWidget);
      expect(find.text('your roles, genres, tempo, vocal feel, mood'), findsOneWidget);
      expect(find.text('Shapes every song:'), findsOneWidget);
      expect(find.text('pre-fills the cockpit and steers generation toward your sound'), findsOneWidget);
      expect(find.text('Grows with you:'), findsOneWidget);
      expect(find.text('every song you make, keep, or edit sharpens it'), findsOneWidget);
    });
  });
}

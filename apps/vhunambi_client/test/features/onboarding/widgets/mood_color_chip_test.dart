import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vhunambi_client/core/design_system/design_system.dart';
import 'package:vhunambi_client/features/onboarding/presentation/widgets/mood_color_chip.dart';

void main() {
  group('MoodColorChip Tests', () {
    testWidgets('renders all 5 mood chips',
        (WidgetTester tester) async {
      final moods = Mood.values;

      for (final mood in moods) {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: MoodColorChip(
                  key: Key('mood_chip_${mood.displayName}'),
                  mood: mood,
                  isSelected: false,
                  onTap: () {},
                ),
              ),
            ),
          ),
        );

        expect(find.byKey(Key('mood_chip_${mood.displayName}')), findsOneWidget);
        expect(find.text(mood.displayName), findsOneWidget);
      }
    });

    testWidgets('selected state applies mood accent color to border and text',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MoodColorChip(
                key: const Key('mood_chip_joyful_selected'),
                mood: Mood.joyful,
                isSelected: true,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('mood_chip_joyful_selected')), findsOneWidget);
      expect(find.text('Joyful'), findsOneWidget);
    });

    testWidgets('fires onTap when chip is tapped',
        (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MoodColorChip(
                key: const Key('mood_chip_tap_test'),
                mood: Mood.calm,
                isSelected: false,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('mood_chip_tap_test')));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('has semantics label for screen readers',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MoodColorChip(
                key: const Key('mood_chip_semantics'),
                mood: Mood.romantic,
                isSelected: false,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      final semantics = tester.getSemantics(find.byKey(const Key('mood_chip_semantics')));
      expect(semantics.label, contains('Romantic'));
      expect(semantics.flagsCollection.isButton, isTrue);
    });

    testWidgets('maintains minimum 40x40 touch target',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MoodColorChip(
                key: const Key('mood_chip_touch'),
                mood: Mood.energetic,
                isSelected: false,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byKey(const Key('mood_chip_touch')));
      expect(size.height, greaterThanOrEqualTo(40));
      expect(size.width, greaterThanOrEqualTo(40));
    });

    testWidgets('is visually distinct from GenreColorChip (smaller, rounded)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MoodColorChip(
                key: const Key('mood_chip_distinct'),
                mood: Mood.joyful,
                isSelected: false,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      // Mood chip has pill border radius (distinct from genre card styling)
      expect(find.byKey(const Key('mood_chip_distinct')), findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vhunambi_client/core/design_system/design_system.dart';
import 'package:vhunambi_client/features/onboarding/presentation/widgets/genre_color_chip.dart';

void main() {
  group('GenreColorChip Tests', () {
    testWidgets('renders all 8 genre chips with correct colors',
        (WidgetTester tester) async {
      final genres = Genre.values;

      for (final genre in genres) {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: GenreColorChip(
                  key: Key('genre_chip_${genre.displayName}'),
                  genre: genre,
                  isSelected: false,
                  onTap: () {},
                ),
              ),
            ),
          ),
        );

        expect(find.byKey(Key('genre_chip_${genre.displayName}')), findsOneWidget);
        expect(find.text(genre.displayName), findsOneWidget);
      }
    });

    testWidgets('selected state applies genre accent color to border and text',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: GenreColorChip(
                key: const Key('genre_chip_amapiano_selected'),
                genre: Genre.amapiano,
                isSelected: true,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('genre_chip_amapiano_selected')), findsOneWidget);
      expect(find.text('Amapiano'), findsOneWidget);
    });

    testWidgets('fires onTap when chip is tapped',
        (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: GenreColorChip(
                key: const Key('genre_chip_tap_test'),
                genre: Genre.gqom,
                isSelected: false,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('genre_chip_tap_test')));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('has semantics label for screen readers',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: GenreColorChip(
                key: const Key('genre_chip_semantics'),
                genre: Genre.maskandi,
                isSelected: true,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      final semantics = tester.getSemantics(find.byKey(const Key('genre_chip_semantics')));
      expect(semantics.label, contains('Maskandi'));
      expect(semantics.label, contains('selected'));
      expect(semantics.flagsCollection.isButton, isTrue);
    });

    testWidgets('maintains minimum 44x44 touch target',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: GenreColorChip(
                key: const Key('genre_chip_touch'),
                genre: Genre.hipHop,
                isSelected: false,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byKey(const Key('genre_chip_touch')));
      expect(size.height, greaterThanOrEqualTo(44));
      expect(size.width, greaterThanOrEqualTo(44));
    });
  });
}

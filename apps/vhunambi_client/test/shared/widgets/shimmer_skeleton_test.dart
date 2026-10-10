import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/shared/widgets/shimmer_skeleton.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(body: child),
      );

  group('ShimmerSkeleton Widget Tests', () {
    testWidgets('ShimmerBox renders correctly with static dimensions',
        (tester) async {
      await tester.pumpWidget(
        host(
          const ShimmerBox(
            width: 120,
            height: 24,
            animate: false,
          ),
        ),
      );

      expect(find.byType(ShimmerBox), findsOneWidget);
    });

    testWidgets('TrackTileSkeleton renders list tile skeleton layout',
        (tester) async {
      await tester.pumpWidget(
        host(
          const TrackTileSkeleton(animate: false),
        ),
      );

      expect(find.byType(TrackTileSkeleton), findsOneWidget);
      // Contains 4 shimmer boxes: art + title + subtitle + badge
      expect(find.byType(ShimmerBox), findsNWidgets(4));
    });

    testWidgets('TrackGridCardSkeleton renders grid card layout',
        (tester) async {
      await tester.pumpWidget(
        host(
          const SizedBox(
            width: 160,
            height: 200,
            child: TrackGridCardSkeleton(animate: false),
          ),
        ),
      );

      expect(find.byType(TrackGridCardSkeleton), findsOneWidget);
      // Contains 3 shimmer boxes: art + title + subtitle
      expect(find.byType(ShimmerBox), findsNWidgets(3));
    });

    testWidgets('ShelfSectionSkeleton renders horizontal shelf with cards',
        (tester) async {
      await tester.pumpWidget(
        host(
          const ShelfSectionSkeleton(
            cardCount: 3,
            animate: false,
          ),
        ),
      );

      expect(find.byType(ShelfSectionSkeleton), findsOneWidget);
      expect(find.byType(TrackGridCardSkeleton), findsNWidgets(3));
    });
  });
}

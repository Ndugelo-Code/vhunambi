import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/error/error_boundary.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/loading/async_image_with_fallback.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/loading/loading_overlay.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/loading/profile_skeleton_screen.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/loading/progressive_list_loader.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/offline/offline_indicator.dart';

void main() {
  group('UI Loading & Error Components', () {
    testWidgets('ProfileSkeletonScreen renders shimmer placeholders', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileSkeletonScreen(),
        ),
      );

      expect(find.byType(ProfileSkeletonScreen), findsOneWidget);
    });

    testWidgets('ErrorBoundary renders message and triggers onRetry callback', (tester) async {
      bool retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorBoundary(
              message: 'Failed to connect to Vhunambi API',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.text('Failed to connect to Vhunambi API'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });

    testWidgets('LoadingOverlay displays child when not loading and overlay when loading', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingOverlay(
              isLoading: false,
              message: 'Saving...',
              child: Text('Main Content'),
            ),
          ),
        ),
      );

      expect(find.text('Main Content'), findsOneWidget);
      expect(find.text('Saving...'), findsNothing);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingOverlay(
              isLoading: true,
              message: 'Saving...',
              child: Text('Main Content'),
            ),
          ),
        ),
      );

      expect(find.text('Saving...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('AsyncImageWithFallback displays monogram on empty or null image URL', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AsyncImageWithFallback(
              imageUrl: null,
              monogram: 'FI',
              size: 68,
            ),
          ),
        ),
      );

      expect(find.text('FI'), findsOneWidget);
    });

    testWidgets('OfflineIndicator shows time ago and invokes refresh callback', (tester) async {
      bool refreshed = false;
      final twoHoursAgo = DateTime.now().subtract(const Duration(hours: 2));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfflineIndicator(
              cacheTimestamp: twoHoursAgo,
              onRefresh: () => refreshed = true,
            ),
          ),
        ),
      );

      expect(find.textContaining('Offline Mode'), findsOneWidget);
      expect(find.textContaining('2h ago'), findsOneWidget);

      await tester.tap(find.byType(IconButton));
      expect(refreshed, isTrue);
    });

    testWidgets('ProgressiveListLoader renders items and Load More trigger', (tester) async {
      bool loadMoreTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProgressiveListLoader<String>(
              items: const ['Item 1', 'Item 2'],
              hasMore: true,
              onLoadMore: () async => loadMoreTriggered = true,
              itemBuilder: (context, item, index) => ListTile(title: Text(item)),
            ),
          ),
        ),
      );

      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
      expect(find.text('Load More'), findsOneWidget);

      await tester.tap(find.text('Load More'));
      expect(loadMoreTriggered, isTrue);
    });
  });
}

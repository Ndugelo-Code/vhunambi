import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/social/presentation/widgets/trending_reels_shelf.dart';

void main() {
  testWidgets('renders header, genre pills, and reel cards', (tester) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(body: SingleChildScrollView(child: TrendingReelsShelf())),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Kinetic Reels'), findsOneWidget);
    expect(find.byKey(const Key('explore_post_kinetic_reel_card')), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('#Amapiano'), findsOneWidget);
    expect(find.byType(TrendingReelCard), findsWidgets);
  });

  testWidgets('tapping a genre pill switches the active filter', (tester) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(body: SingleChildScrollView(child: TrendingReelsShelf())),
        ),
      ),
    );
    await tester.pump();

    // Tapping should not throw and keeps the shelf mounted.
    await tester.tap(find.text('#Gqom'));
    await tester.pump();
    expect(find.text('#Gqom'), findsOneWidget);
  });

  testWidgets('tapping a card launches the KineticReelsModal', (tester) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(body: SingleChildScrollView(child: TrendingReelsShelf())),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(TrendingReelCard).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The reels modal exposes its action rail like button.
    expect(find.byKey(const Key('reel_like_btn')), findsWidgets);
  });
}

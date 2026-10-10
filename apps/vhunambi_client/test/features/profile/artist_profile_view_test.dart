import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/profile/presentation/views/artist_profile_view.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/profile_banner_header.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/profile_stats_grid.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/top_supporters_leaderboard.dart';

Future<void> _pumpArtistProfile(
  WidgetTester tester, {
  String artistId = 'fifi',
  Size size = const Size(1280, 2400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.view.resetPhysicalSize());

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: ArtistProfileView(artistId: artistId),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('ArtistProfileView renders banner, monogram, 5 stats, and supporters',
      (WidgetTester tester) async {
    await _pumpArtistProfile(tester);

    // 1. Header Banner & Identity (REQ-TRK-12)
    expect(find.byType(ProfileBannerHeader), findsOneWidget);
    expect(find.text('Fifi'), findsOneWidget);
    expect(find.text('@fifi'), findsOneWidget);
    expect(find.text('FI'), findsOneWidget);
    expect(find.text('Verified Artist'), findsOneWidget);
    expect(find.text('Follow'), findsOneWidget);
    expect(find.text('Tip Artist'), findsOneWidget);

    // 2. 5-Metric Stats Grid (REQ-TRK-13)
    expect(find.byType(ProfileStatsGrid), findsOneWidget);
    expect(find.text('Songs'), findsOneWidget);
    expect(find.text('Likes'), findsOneWidget);
    expect(find.text('Plays'), findsOneWidget);
    expect(find.text('Followers'), findsOneWidget);
    expect(find.text('Day Streak'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.text('1.8K'), findsOneWidget);
    expect(find.text('🔥 4'), findsOneWidget);

    // 3. Switch to Music tab (Top Songs & Recent Activity)
    await tester.tap(find.text('Music'));
    await tester.pumpAndSettle();
    expect(find.text('Top Songs'), findsOneWidget);
    expect(find.text('Ndo Mufuna Matibe'), findsWidgets);
    expect(find.text('Recent Activity'), findsOneWidget);

    // 4. Switch to Beats tab (Top Supporters Leaderboard REQ-TRK-14)
    await tester.tap(find.text('Beats'));
    await tester.pumpAndSettle();
    expect(find.byType(TopSupportersLeaderboard), findsOneWidget);
    expect(find.text('Top Supporters'), findsOneWidget);
    expect(find.text('Sipho Beats'), findsOneWidget);
    expect(find.text('🥇'), findsOneWidget);
    expect(find.text('Lerato K'), findsOneWidget);
    expect(find.text('🥈'), findsOneWidget);
  });

  testWidgets('ArtistProfileView toggles follow button and updates following state',
      (WidgetTester tester) async {
    await _pumpArtistProfile(tester);

    expect(find.text('Follow'), findsOneWidget);

    // Tap Follow
    await tester.tap(find.text('Follow'));
    await tester.pumpAndSettle();

    expect(find.text('Following'), findsOneWidget);

    // Tap Following to unfollow
    await tester.tap(find.text('Following'));
    await tester.pumpAndSettle();

    expect(find.text('Follow'), findsOneWidget);
  });

  testWidgets('ArtistProfileView opens tip modal when Tip Artist pressed',
      (WidgetTester tester) async {
    await _pumpArtistProfile(tester);

    final tipButton = find.text('Tip Artist');
    expect(tipButton, findsOneWidget);

    await tester.tap(tipButton);
    await tester.pumpAndSettle();

    expect(find.text('Tip Fifi'), findsOneWidget);
    expect(find.text('⚡ 10'), findsOneWidget);
    expect(find.text('⚡ 25'), findsOneWidget);
  });
}

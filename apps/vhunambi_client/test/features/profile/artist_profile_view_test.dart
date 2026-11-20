import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/profile/presentation/views/artist_profile_view.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/profile_banner_header.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/profile_stats_grid.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/top_supporters_leaderboard.dart';
import 'package:vhunambi_client/features/social/presentation/widgets/creator_tipping_sheet.dart';

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
  testWidgets(
    'ArtistProfileView renders banner, monogram, inline stats, 5 Facebook tabs, and supporters',
    (WidgetTester tester) async {
      await _pumpArtistProfile(tester);

      // 1. Header Banner & Identity (REQ-TRK-12)
      expect(find.byType(ProfileBannerHeader), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ProfileBannerHeader),
          matching: find.text('Fifi'),
        ),
        findsOneWidget,
      );
      expect(find.text('@fifi'), findsOneWidget);
      expect(find.text('FI'), findsOneWidget);
      expect(find.text('Verified Artist'), findsOneWidget);
      expect(find.text('Follow'), findsOneWidget);
      expect(find.text('Tip Artist'), findsOneWidget);

      // 2. Inline Public Social Proof Strip without private Day Streak (`SC-01`, `VP-05`)
      expect(
        find.byKey(const Key('visitor_profile_inline_stats')),
        findsOneWidget,
      );
      expect(find.byType(ProfileStatsGrid), findsNothing);
      expect(find.text('Day Streak'), findsNothing);
      expect(find.text('Top Songs'), findsOneWidget);

      // 3. Switch to Songs tab (`visitor_tab_songs`) -> shows ranked live song tiles
      await tester.tap(find.byKey(const Key('visitor_tab_songs')));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key as ValueKey<String>).value.startsWith(
                'visitor_song_tile_',
              ),
        ),
        findsWidgets,
      );

      // 4. Switch to Beats tab (Top Supporters Leaderboard REQ-TRK-14)
      await tester.tap(find.byKey(const Key('visitor_tab_beats')));
      await tester.pumpAndSettle();
      expect(find.byType(TopSupportersLeaderboard), findsOneWidget);
      expect(find.text('Top Supporters'), findsOneWidget);
      expect(find.text('Sipho Beats'), findsOneWidget);
      expect(find.textContaining('Gold'), findsOneWidget);
      expect(find.text('Lerato K'), findsOneWidget);
      expect(find.textContaining('Silver'), findsOneWidget);
    },
  );

  testWidgets(
    'ArtistProfileView toggles follow button and updates following state',
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
    },
  );

  testWidgets(
    'ArtistProfileView opens cultural tipping sheet when Tip Artist pressed',
    (WidgetTester tester) async {
      await _pumpArtistProfile(tester);

      final tipButton = find.text('Tip Artist');
      expect(tipButton, findsOneWidget);

      await tester.tap(tipButton);
      await tester.pumpAndSettle();

      expect(find.byType(CreatorTippingSheet), findsOneWidget);
      expect(find.text('Support @fifi'), findsOneWidget);
      expect(find.byKey(const Key('tip_coin_balance')), findsOneWidget);
      expect(find.byKey(const Key('tip_send_btn')), findsOneWidget);
    },
  );
}

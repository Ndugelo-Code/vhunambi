import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/design_system/tokens/app_icons.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/explore/domain/models/explore_models.dart';
import 'package:vhunambi_client/features/explore/presentation/providers/explore_providers.dart';
import 'package:vhunambi_client/features/explore/presentation/views/explore_view.dart';
import 'package:vhunambi_client/features/explore/presentation/widgets/catalog_filter_bar.dart';
import 'package:vhunambi_client/features/explore/presentation/widgets/explore_empty_state.dart';
import 'package:vhunambi_client/features/explore/presentation/widgets/explore_social_post_card.dart';
import 'package:vhunambi_client/features/explore/presentation/widgets/explore_top_bar.dart';
import 'package:vhunambi_client/features/explore/presentation/widgets/track_card.dart';
import 'package:vhunambi_client/features/player/presentation/providers/player_provider.dart';
import 'package:vhunambi_client/features/social/presentation/widgets/trending_reels_shelf.dart';

Future<void> _pumpExplore(
  WidgetTester tester, {
  Size size = const Size(1280, 2800),
  VoidCallback? onCreateRequested,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.view.resetPhysicalSize());

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: ExploreView(onCreateRequested: onCreateRequested),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ProviderContainer _containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(ExploreView)));

void main() {
  testWidgets(
    'Desktop explore renders the discovery feed with reels and social cards',
    (WidgetTester tester) async {
      await _pumpExplore(tester);

      // Top bar (REQ-EXP-01)
      expect(find.byType(DesktopExploreTopBar), findsOneWidget);
      expect(find.text('VHUNAMBI'), findsOneWidget);
      expect(find.text('/ Explore'), findsOneWidget);
      expect(find.text('Ctrl + K'), findsOneWidget);
      expect(find.text('10 songs left'), findsOneWidget);
      expect(find.text('Create'), findsOneWidget);

      // Trending Kinetic Reels shelf (REQ-TRD-01)
      expect(find.byType(TrendingReelsShelf), findsOneWidget);

      // Social Post Cards (REQ-EXP-FEED-01)
      expect(find.byType(ExploreSocialPostCard), findsAtLeastNWidgets(1));

      // Feed Switcher Pills
      expect(find.text('For You'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('explore_feed_switcher')),
          matching: find.text('Following'),
        ),
        findsOneWidget,
      );
      expect(find.text('All Songs'), findsOneWidget);
    },
  );

  testWidgets(
    'Switching to All Songs toggles the catalog browser & paginates with Load more',
    (WidgetTester tester) async {
      await _pumpExplore(tester);

      // Switch to All Songs
      await tester.tap(find.text('All Songs'));
      await tester.pumpAndSettle();

      expect(find.byType(CatalogFilterBar), findsOneWidget);
      expect(find.byType(TrackCard), findsNWidgets(6));
      expect(find.text('8 tracks'), findsOneWidget);
      expect(find.text('Load more'), findsOneWidget);

      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();

      // All 8 catalog tracks now render.
      expect(find.byType(TrackCard), findsNWidgets(8));
      expect(find.text('Load more'), findsNothing);
    },
  );

  testWidgets(
    'Catalog search + clear filters toggles the empty state in All Songs',
    (WidgetTester tester) async {
      await _pumpExplore(tester);

      // Switch to All Songs
      await tester.tap(find.text('All Songs'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'zzzz');
      await tester.pumpAndSettle();

      expect(find.text('No songs match these filters'), findsOneWidget);
      expect(find.text('Create a song'), findsOneWidget);
      expect(find.text('0 tracks'), findsOneWidget);
      expect(find.text('Load more'), findsNothing);

      final clearAction = find.descendant(
        of: find.byType(ExploreEmptyState),
        matching: find.text('Clear filters'),
      );
      expect(clearAction, findsOneWidget);

      await tester.tap(clearAction);
      await tester.pumpAndSettle();

      expect(find.text('No songs match these filters'), findsNothing);
      expect(find.text('8 tracks'), findsOneWidget);
      expect(find.byType(TrackCard), findsNWidgets(6));
    },
  );

  testWidgets('Language filter narrows the catalog result count in All Songs', (
    WidgetTester tester,
  ) async {
    await _pumpExplore(tester);

    // Switch to All Songs
    await tester.tap(find.text('All Songs'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Language: All'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('isiZulu').last);
    await tester.pumpAndSettle();

    expect(find.text('2 tracks'), findsOneWidget);
    expect(find.text('Language: isiZulu'), findsOneWidget);
    expect(find.byType(TrackCard), findsNWidgets(2));
  });

  testWidgets(
    'Tapping play button on social post card routes playback into the player',
    (WidgetTester tester) async {
      await _pumpExplore(tester);
      final container = _containerOf(tester);
      expect(
        container.read(playerStateProvider).currentTrack?.id,
        'track_default_1',
      );

      // Find first social post play button
      final playBtn = find.byIcon(AppIcons.play).first;
      await tester.tap(playBtn);
      await tester.pumpAndSettle();

      final player = container.read(playerStateProvider);
      expect(player.currentTrack?.id, 'exp_track_002');
      expect(player.isPlaying, isTrue);
    },
  );

  testWidgets('Desktop + Create CTA requests the Studio cockpit', (
    WidgetTester tester,
  ) async {
    var studioRequests = 0;
    await _pumpExplore(tester, onCreateRequested: () => studioRequests++);

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(studioRequests, 1);
  });

  testWidgets('Mobile explore renders the compact top bar and Stories rail', (
    WidgetTester tester,
  ) async {
    await _pumpExplore(tester, size: const Size(420, 2400));

    expect(find.byType(MobileExploreTopBar), findsOneWidget);
    expect(find.byType(DesktopExploreTopBar), findsNothing);
    expect(find.text('Ctrl + K'), findsNothing);
    expect(
      find.byKey(const Key('explore_open_search_view_btn')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('explore_open_discovery_drawer_btn')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('explore_open_notifications_btn')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('explore_post_kinetic_reel_card')),
      findsOneWidget,
    );
    expect(find.byType(ExploreSocialPostCard), findsAtLeastNWidgets(1));
  });

  testWidgets('Tapping For You and Following switches social feeds', (
    WidgetTester tester,
  ) async {
    await _pumpExplore(tester);

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('explore_feed_switcher')),
        matching: find.text('Following'),
      ),
    );
    await tester.pumpAndSettle();

    final container = _containerOf(tester);
    expect(container.read(exploreTabProvider), ExploreTab.following);

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('explore_feed_switcher')),
        matching: find.text('For You'),
      ),
    );
    await tester.pumpAndSettle();
    expect(container.read(exploreTabProvider), ExploreTab.forYou);
  });
}

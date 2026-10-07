import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/explore/presentation/views/explore_view.dart';
import 'package:vhunambi_client/features/explore/presentation/widgets/african_charts_banner.dart';
import 'package:vhunambi_client/features/explore/presentation/widgets/creator_card.dart';
import 'package:vhunambi_client/features/explore/presentation/widgets/explore_empty_state.dart';
import 'package:vhunambi_client/features/explore/presentation/widgets/explore_top_bar.dart';
import 'package:vhunambi_client/features/explore/presentation/widgets/genre_radio_tile.dart';
import 'package:vhunambi_client/features/explore/presentation/widgets/track_card.dart';
import 'package:vhunambi_client/features/explore/presentation/widgets/track_list_tile.dart';
import 'package:vhunambi_client/features/player/presentation/providers/player_provider.dart';

Future<void> _pumpExplore(
  WidgetTester tester, {
  Size size = const Size(1280, 2400),
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
  testWidgets('Desktop explore renders the full discovery feed',
      (WidgetTester tester) async {
    await _pumpExplore(tester);

    // Top bar (REQ-EXP-01)
    expect(find.byType(DesktopExploreTopBar), findsOneWidget);
    expect(find.text('VHUNAMBI'), findsOneWidget);
    expect(find.text('/ Explore'), findsOneWidget);
    expect(find.text('Ctrl + K'), findsOneWidget);
    expect(find.text('10 songs left'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);

    // Header section (REQ-EXP-02)
    expect(find.text('Explore'), findsOneWidget);
    expect(
      find.text('Discover AI music from creators around the world'),
      findsOneWidget,
    );
    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('For You'), findsOneWidget);
    expect(find.text('Following'), findsOneWidget);
    expect(find.text('2 Streak'), findsOneWidget);

    // African Music Charts banner (REQ-EXP-03)
    expect(find.byType(AfricanChartsBanner), findsOneWidget);
    expect(find.text('African Music Charts'), findsOneWidget);
    expect(find.text('View ->'), findsOneWidget);

    // Feed sections
    expect(find.text('New This Week'), findsOneWidget);
    expect(find.text('Rising'), findsOneWidget);
    expect(find.text('Featured Creators'), findsOneWidget);
    expect(find.text('Genre Radio'), findsOneWidget);
    expect(find.text('All Songs'), findsOneWidget);

    // New This Week (6) + catalog page (6) card grids
    expect(find.byType(TrackCard), findsNWidgets(12));
    expect(find.byType(TrackListTile), findsNWidgets(3));
    expect(find.byType(CreatorCard), findsNWidgets(6));
    expect(find.byType(GenreRadioTile), findsNWidgets(12));

    // Catalog filter engine (REQ-EXP-08)
    expect(find.text('8 tracks'), findsOneWidget);
    expect(find.text('😊 Uplifting'), findsOneWidget);
    expect(find.text('🖤 Dark'), findsOneWidget);
    expect(find.text('Language: All'), findsOneWidget);
    expect(find.text('🔥 Newest'), findsOneWidget);
    expect(find.text('❤️ Most Liked'), findsOneWidget);
    expect(find.text('Load more'), findsOneWidget);

    // Badges render on both the New This Week and catalog instances of each
    // card: one ✨ NEW drop plus trending ranks #1–#3.
    expect(find.text('✨ NEW'), findsNWidgets(2));
    expect(find.text('#1'), findsNWidgets(2));
    expect(find.text('#2'), findsNWidgets(2));
    expect(find.text('#3'), findsNWidgets(2));
  });

  testWidgets('Desktop explore paginates the catalog with Load more',
      (WidgetTester tester) async {
    await _pumpExplore(tester);
    expect(find.byType(TrackCard), findsNWidgets(12));

    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();

    // All 8 catalog tracks now render alongside the 6 New This Week cards.
    expect(find.byType(TrackCard), findsNWidgets(14));
    expect(find.text('Load more'), findsNothing);
  });

  testWidgets('Search + clear filters toggles the catalog empty state',
      (WidgetTester tester) async {
    await _pumpExplore(tester);

    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pumpAndSettle();

    expect(find.text('No songs match these filters'), findsOneWidget);
    expect(find.text('Create a song'), findsOneWidget);
    expect(find.text('0 tracks'), findsOneWidget);
    expect(find.text('Load more'), findsNothing);

    // The filter bar link and the empty-state action share a label, so the
    // empty-state action is targeted explicitly.
    final clearAction = find.descendant(
      of: find.byType(ExploreEmptyState),
      matching: find.text('Clear filters'),
    );
    expect(clearAction, findsOneWidget);

    await tester.tap(clearAction);
    await tester.pumpAndSettle();

    expect(find.text('No songs match these filters'), findsNothing);
    expect(find.text('8 tracks'), findsOneWidget);
    expect(find.byType(TrackCard), findsNWidgets(12));
  });

  testWidgets('Language filter narrows the catalog result count',
      (WidgetTester tester) async {
    await _pumpExplore(tester);

    await tester.tap(find.text('Language: All'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('isiZulu').last);
    await tester.pumpAndSettle();

    expect(find.text('2 tracks'), findsOneWidget);
    expect(find.text('Language: isiZulu'), findsOneWidget);
    // 6 New This Week cards + the 2 matching catalog cards.
    expect(find.byType(TrackCard), findsNWidgets(8));
  });

  testWidgets('Tapping a track card routes playback into the player',
      (WidgetTester tester) async {
    await _pumpExplore(tester);
    final container = _containerOf(tester);
    expect(
      container.read(playerStateProvider).currentTrack?.id,
      'track_default_1',
    );

    await tester.tap(find.byType(TrackCard).first);
    await tester.pumpAndSettle();

    final player = container.read(playerStateProvider);
    expect(player.currentTrack?.id, 'exp_track_001');
    expect(player.currentTrack?.title, 'Grateful in the Light');
    expect(player.isPlaying, isTrue);
    expect(player.queue.length, 8);
  });

  testWidgets('Rising tile play button reflects live playback state',
      (WidgetTester tester) async {
    await _pumpExplore(tester);
    final container = _containerOf(tester);
    final firstTile = find.byType(TrackListTile).first;

    expect(
      find.descendant(
        of: firstTile,
        matching: find.byIcon(Icons.play_arrow_rounded),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: firstTile,
        matching: find.byIcon(Icons.play_arrow_rounded),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      container.read(playerStateProvider).currentTrack?.id,
      'exp_track_002',
    );
    expect(
      find.descendant(
        of: firstTile,
        matching: find.byIcon(Icons.pause_rounded),
      ),
      findsOneWidget,
    );

    // Tapping again toggles playback off (live state binding).
    await tester.tap(
      find.descendant(
        of: firstTile,
        matching: find.byIcon(Icons.pause_rounded),
      ),
    );
    await tester.pumpAndSettle();

    expect(container.read(playerStateProvider).isPlaying, isFalse);
    expect(
      find.descendant(
        of: firstTile,
        matching: find.byIcon(Icons.play_arrow_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Genre radio tile queues continuous genre playback',
      (WidgetTester tester) async {
    await _pumpExplore(tester);
    final container = _containerOf(tester);

    await tester.tap(find.byType(GenreRadioTile).first);
    await tester.pumpAndSettle();

    final player = container.read(playerStateProvider);
    expect(player.currentTrack?.genre, 'Amapiano');
    expect(player.queue.length, 3);
    expect(
      find.text('Playing Amapiano radio — 3 tracks queued.'),
      findsOneWidget,
    );
  });

  testWidgets('Desktop + Create CTA requests the Studio cockpit',
      (WidgetTester tester) async {
    var studioRequests = 0;
    await _pumpExplore(tester, onCreateRequested: () => studioRequests++);

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(studioRequests, 1);
  });

  testWidgets('Mobile explore renders the compact top bar and stacked feed',
      (WidgetTester tester) async {
    await _pumpExplore(tester, size: const Size(420, 2400));

    expect(find.byType(MobileExploreTopBar), findsOneWidget);
    expect(find.byType(DesktopExploreTopBar), findsNothing);
    expect(find.text('Ctrl + K'), findsNothing);
    expect(find.text('Search songs...'), findsOneWidget);
    expect(find.text('10 songs left'), findsNothing);
    expect(find.text('Create'), findsNothing);

    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('African Music Charts'), findsOneWidget);
    expect(find.text('New This Week'), findsOneWidget);

    // Mobile New This Week grid = 2 columns x 3 rows of curated drops.
    expect(find.byType(TrackCard), findsNWidgets(6));
    // Rising renders as a dense single-column list on mobile.
    expect(find.byType(TrackListTile), findsNWidgets(3));
  });
}

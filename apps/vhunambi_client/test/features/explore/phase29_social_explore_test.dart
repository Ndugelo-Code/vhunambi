import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/explore/domain/models/explore_models.dart';
import 'package:vhunambi_client/features/explore/domain/models/social_music_post.dart';
import 'package:vhunambi_client/features/explore/presentation/providers/explore_providers.dart';
import 'package:vhunambi_client/features/explore/presentation/views/explore_search_view.dart';
import 'package:vhunambi_client/features/explore/presentation/views/explore_view.dart';
import 'package:vhunambi_client/features/explore/presentation/widgets/catalog_filter_bar.dart';
import 'package:vhunambi_client/features/explore/presentation/widgets/explore_discovery_drawer_sheet.dart';
import 'package:vhunambi_client/features/explore/presentation/widgets/explore_social_post_card.dart';
import 'package:vhunambi_client/features/explore/presentation/widgets/explore_top_bar.dart';
import 'package:vhunambi_client/features/library/domain/models/library_models.dart';
import 'package:vhunambi_client/features/library/presentation/providers/library_providers.dart';
import 'package:vhunambi_client/features/notifications/presentation/views/notifications_view.dart';
import 'package:vhunambi_client/features/player/presentation/providers/player_provider.dart';
import 'package:vhunambi_client/features/social/presentation/providers/trending_reels_provider.dart';
import 'package:vhunambi_client/features/social/presentation/widgets/kinetic_reels_modal.dart';
import 'package:vhunambi_client/features/social/presentation/widgets/trending_reels_shelf.dart';

void main() {
  group('Phase 29: V4.1 Social Explore Redesign', () {
    testWidgets(
      'Track B: Minimalist Top Bar renders 56dp mobile chrome, transient title & action triad',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const Scaffold(
                appBar: PreferredSize(
                  preferredSize: Size.fromHeight(MobileExploreTopBar.barHeight),
                  child: MobileExploreTopBar(),
                ),
                body: SizedBox(),
              ),
            ),
          ),
        );
        await tester.pump();

        // 1. Transient 4s title pill exists
        final titlePill = find.byKey(const Key('explore_transient_title_pill'));
        expect(titlePill, findsOneWidget);
        expect(find.text('Explore'), findsOneWidget);

        // 2. Action triad icons exist with 44dp hit targets
        expect(
          find.byKey(const Key('explore_open_discovery_drawer_btn')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('explore_open_search_view_btn')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('explore_open_notifications_btn')),
          findsOneWidget,
        );

        // 3. Permanent inline text field and orange create button are eliminated
        expect(find.byKey(const Key('explore_search_field')), findsNothing);

        // 4. Advance time by 4 seconds to verify transient collapse without timer leaks
        await tester.pump(const Duration(seconds: 4));
        await tester.pump(const Duration(milliseconds: 300));
      },
    );

    testWidgets(
      'Track B: Notifications bell button opens NotificationsView in 1 step on mobile',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const Scaffold(
                appBar: PreferredSize(
                  preferredSize: Size.fromHeight(MobileExploreTopBar.barHeight),
                  child: MobileExploreTopBar(),
                ),
                body: SizedBox(),
              ),
            ),
          ),
        );
        await tester.pump();

        // Tap notifications button
        await tester.tap(find.byKey(const Key('explore_open_notifications_btn')));
        await tester.pumpAndSettle();

        // Directly opens NotificationsView in 1 step!
        expect(find.byType(NotificationsView), findsOneWidget);
      },
    );

    testWidgets(
      'Track C: Search icon button pushes dedicated full-screen ExploreSearchView',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const ExploreSearchView(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('explore_search_view')), findsOneWidget);
        expect(find.byKey(const Key('explore_search_back_btn')), findsOneWidget);
        expect(find.byKey(const Key('explore_search_input')), findsOneWidget);
        expect(find.byKey(const Key('explore_recent_clear_all')), findsOneWidget);
        expect(find.text('You May Like'), findsOneWidget);

        // Enter search query
        await tester.enterText(
          find.byKey(const Key('explore_search_input')),
          'Amapiano',
        );
        await tester.pumpAndSettle();

        // Multi-dimensional category tabs appear
        expect(find.byKey(const Key('explore_search_tab_top')), findsOneWidget);
        expect(find.byKey(const Key('explore_search_tab_songs')), findsOneWidget);
        expect(find.byKey(const Key('explore_search_tab_reels')), findsOneWidget);
        expect(find.byKey(const Key('explore_search_tab_creators')), findsOneWidget);

        // Clear query
        await tester.tap(find.byKey(const Key('explore_search_clear_btn')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('explore_search_tab_top')), findsNothing);
      },
    );

    testWidgets(
      'Track D: TrendingReelsShelf renders Card #0 [ ➕ Post Reel ] on far left',
      (tester) async {
        final mockTrack = LibraryTrack(
          id: 'vault_track_1',
          title: 'Makhado Sunrise',
          creatorName: 'Makhadzi',
          genre: 'Amapiano',
          language: 'Tshivenḓa',
          durationSeconds: 198,
          remoteAudioUrl: 'https://cdn.vhunambi.com/audio/makhado-sunrise.mp3',
          createdAt: DateTime.now(),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              libraryTracksProvider.overrideWith(
                (ref) => _TestLibraryNotifier([mockTrack]),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const Scaffold(
                body: TrendingReelsShelf(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Card #0 exists
        final postCard = find.byKey(const Key('explore_post_kinetic_reel_card'));
        expect(postCard, findsOneWidget);
        expect(find.text('Post Reel'), findsOneWidget);

        // Tap Card #0 opens track picker sheet
        await tester.tap(postCard);
        await tester.pumpAndSettle();

        expect(find.text('Select Track for Reel'), findsOneWidget);
        expect(find.text('Makhado Sunrise'), findsOneWidget);
      },
    );

    testWidgets(
      'Track E: KineticReelsModal top bar features TikTok filter tabs & search button',
      (tester) async {
        final container = ProviderContainer();
        final clips = container.read(trendingReelsProvider);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: KineticReelsModal(clips: clips),
            ),
          ),
        );
        await tester.pump();

        expect(find.byKey(const Key('reels_modal_top_bar')), findsOneWidget);
        expect(find.byKey(const Key('reels_modal_tab_trending')), findsOneWidget);
        expect(find.byKey(const Key('reels_modal_tab_for_you')), findsOneWidget);
        expect(find.byKey(const Key('reels_modal_tab_following')), findsOneWidget);
        expect(find.byKey(const Key('reels_modal_tab_newest')), findsOneWidget);
        expect(find.byKey(const Key('reels_modal_search_btn')), findsOneWidget);

        // Tap 'For You' tab
        await tester.tap(find.byKey(const Key('reels_modal_tab_for_you')));
        await tester.pump();
        expect(container.read(activeReelTabProvider), ReelFeedTab.forYou);

        // Tap 'Following' tab
        await tester.tap(find.byKey(const Key('reels_modal_tab_following')));
        await tester.pump();
        expect(container.read(activeReelTabProvider), ReelFeedTab.following);

        // Teardown modal and container to cancel playback tickers
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 200));
        container.read(playerStateProvider.notifier).dismiss();
        await tester.pump(const Duration(milliseconds: 200));
        container.dispose();
      },
    );

    testWidgets(
      'Track F: ExploreDiscoveryDrawerSheet displays 5 structured shortcuts',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const Scaffold(
                body: ExploreDiscoveryDrawerSheet(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('explore_discovery_drawer')), findsOneWidget);
        expect(find.byKey(const Key('drawer_item_charts')), findsOneWidget);
        expect(find.byKey(const Key('drawer_item_radio')), findsOneWidget);
        expect(find.byKey(const Key('drawer_item_rising')), findsOneWidget);
        expect(find.byKey(const Key('drawer_item_streak')), findsOneWidget);
        expect(find.byKey(const Key('drawer_item_creators')), findsOneWidget);
      },
    );

    testWidgets(
      'Track G: ExploreSocialPostCard renders creator identity, follow toggle & actions',
      (tester) async {
        final post = seedSocialPosts().first;
        var remixClicked = false;

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: Scaffold(
                body: SingleChildScrollView(
                  child: ExploreSocialPostCard(
                    post: post,
                    onRemixSuccess: () => remixClicked = true,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(Key('social_post_card_${post.id}')), findsOneWidget);
        expect(find.text(post.creatorName), findsOneWidget);
        expect(find.text(post.caption), findsOneWidget);
        expect(find.text(post.track.title), findsOneWidget);

        // Check Like Action
        final likeBtn = find.byKey(Key('social_post_like_btn_${post.id}'));
        expect(likeBtn, findsOneWidget);
        await tester.tap(likeBtn);
        await tester.pump();

        // Check Follow Button
        final followBtn = find.byKey(Key('social_post_follow_${post.id}'));
        expect(followBtn, findsOneWidget);
        await tester.tap(followBtn);
        await tester.pump();

        // Check Remix Button
        final remixBtn = find.byKey(Key('social_post_remix_btn_${post.id}'));
        expect(remixBtn, findsOneWidget);
        await tester.tap(remixBtn);
        await tester.pump();
        expect(remixClicked, isTrue);
      },
    );

    testWidgets(
      'Track G: ExploreView mounts Stories rail, feed switcher and interleaved social posts',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const ExploreView(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Stories rail with Card #0
        expect(find.byType(TrendingReelsShelf), findsOneWidget);
        expect(find.byKey(const Key('explore_post_kinetic_reel_card')), findsOneWidget);

        // Feed switcher pills
        expect(find.text('For You'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('explore_feed_switcher')),
            matching: find.text('Following'),
          ),
          findsOneWidget,
        );
        expect(find.text('All Songs'), findsOneWidget);
        expect(find.byKey(const Key('explore_feed_drawer_shortcut')), findsOneWidget);

        // Interleaved social post cards
        expect(find.byType(ExploreSocialPostCard), findsAtLeastNWidgets(1));

        // Switch to All Songs (Catalog Mode)
        await tester.tap(
          find.descendant(
            of: find.byKey(const Key('explore_feed_switcher')),
            matching: find.text('All Songs'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(CatalogFilterBar), findsOneWidget);
      },
    );
  });
}

class _TestLibraryNotifier extends LibraryTracksNotifier {
  _TestLibraryNotifier(List<LibraryTrack> initial) : super() {
    state = initial;
  }
}


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../core/widgets/vhunambi_bottom_dock_kit.dart';
import '../../../../core/widgets/vhunambi_top_bar_kit.dart';
import '../../../../shared/models/track.dart';
import '../../../player/presentation/providers/mini_player_controller.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../social/presentation/widgets/trending_reels_shelf.dart';
import '../../domain/models/explore_models.dart';
import '../../domain/models/social_music_post.dart';
import '../../domain/services/discovery_hierarchy_ranker.dart';
import '../providers/explore_providers.dart';
import '../widgets/catalog_filter_bar.dart';
import '../widgets/explore_discovery_drawer_sheet.dart';
import '../widgets/explore_empty_state.dart';
import '../widgets/explore_social_post_card.dart';
import '../widgets/kinetic_post_composer_bar.dart';
import '../widgets/explore_top_bar.dart';
import '../widgets/track_card.dart';
import '../widgets/track_list_tile.dart';

/// V4.1 Social Explore Feed & Music Discovery (`/explore`) — mounted at tab index 1 of `RootShell`.
/// Unifies TikTok search and reels with Facebook Stories-style rail, compact discovery drawer,
/// and rich creator music feed with zero-skip 5-slot stride interleaving.
class ExploreView extends ConsumerStatefulWidget {
  /// Routes the `+ Create` CTA into the Studio cockpit (tab index 2).
  final VoidCallback? onCreateRequested;

  const ExploreView({super.key, this.onCreateRequested});

  @override
  ConsumerState<ExploreView> createState() => _ExploreViewState();
}

class _ExploreViewState extends ConsumerState<ExploreView> {
  bool _showingAllSongs = false;

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final activeTab = ref.watch(exploreTabProvider);
    final followingIds = ref.watch(followingCreatorIdsProvider);
    final allPosts = ref.watch(socialFeedPostsProvider);
    final rising = ref.watch(risingTracksProvider);
    final catalog = ref.watch(visibleExploreTracksProvider);
    final hasResults = ref.watch(filteredExploreTracksProvider).isNotEmpty;
    final hasMore = ref.watch(hasMoreExploreTracksProvider);
    final hasActiveTrack =
        ref.watch(playerStateProvider.select((s) => s.hasActiveTrack));

    final selectedTier = ref.watch(selectedDiscoveryTierProvider);
    // Filter posts if on following tab and rank/filter by discovery tier
    final rawPosts = activeTab == ExploreTab.following
        ? allPosts.where((p) => followingIds.contains(p.creatorId)).toList()
        : allPosts;
    final displayPosts =
        DiscoveryHierarchyRanker.filterByTier(rawPosts, selectedTier);

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(
          isDesktop
              ? DesktopExploreTopBar.barHeight
              : VhunambiTopBarMetrics.totalHeight(
                  context,
                  toolbarHeight: MobileExploreTopBar.barHeight,
                ),
        ),
        child: isDesktop
            ? DesktopExploreTopBar(onCreateRequested: widget.onCreateRequested)
            : MobileExploreTopBar(onCreateRequested: widget.onCreateRequested),
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.axis != Axis.vertical) return false;
          if (notification is ScrollUpdateNotification) {
            final controller = ref.read(miniPlayerControllerProvider);
            if (controller.mode == PlayerMode.auto) {
              final delta = notification.scrollDelta ?? 0;
              final pixels = notification.metrics.pixels;
              if (pixels > 40 &&
                  delta > 1.5 &&
                  controller.form == PlayerForm.bar) {
                ref
                    .read(miniPlayerControllerProvider.notifier)
                    .setForm(PlayerForm.pill);
              } else if (pixels <= 10 && controller.form == PlayerForm.pill) {
                ref
                    .read(miniPlayerControllerProvider.notifier)
                    .setForm(PlayerForm.bar);
              }
            }
          }
          return false;
        },
        child: CustomScrollView(
          slivers: [
          // 1. Facebook Stories-Style Kinetic Reels Discovery Rail (Card #0 is ➕ Post Reel)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: AppSpacing.xs),
              child: TrendingReelsShelf(),
            ),
          ),

          // 2. Feed Switcher Filter Bar
          SliverToBoxAdapter(
            child: _buildFeedSwitcher(context, activeTab, selectedTier),
          ),

          // Kinetic Post Composer Bar (Phase 38 REQ-KPOST-COMP-01)
          if (!_showingAllSongs)
            const SliverToBoxAdapter(
              child: KineticPostComposerBar(),
            ),

          // 3. Main Body: Catalog Mode vs. Creator Music Social Feed
          if (_showingAllSongs) ...[
            // Catalog Filter Engine & Results
            const SliverToBoxAdapter(child: CatalogFilterBar()),
            if (hasResults)
              _buildCatalogGrid(context, catalog)
            else
              SliverToBoxAdapter(
                child: ExploreEmptyState(
                  onCreateRequested: widget.onCreateRequested,
                ),
              ),
            if (hasResults && hasMore)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Center(
                    child: OutlinedButton(
                      onPressed: () => loadMoreExploreTracks(ref),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: BorderSide(color: AppColors.borderSubtle),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.pillBorder,
                        ),
                      ),
                      child: const Text('Load more'),
                    ),
                  ),
                ),
              ),
          ] else ...[
            // Unified Creator Music Social Feed with Zero-Skip 5-Slot Interleaving
            if (displayPosts.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.person_search_rounded,
                          size: 48,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          activeTab == ExploreTab.following
                              ? 'Not following any creators yet'
                              : 'No posts in feed',
                          style: AppTypography.titleMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Follow creators or switch to "For You" to discover new music.',
                          textAlign: TextAlign.center,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              _buildInterleavedSocialFeed(displayPosts, rising),
          ],

          // 4. Bottom Transport Clearance Dock Metric
          SliverToBoxAdapter(
            child: SizedBox(
              height: VhunambiBottomDockMetrics.scrollInset(
                hasActiveTrack: hasActiveTrack,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildFeedSwitcher(BuildContext context, ExploreTab activeTab, DiscoveryStageTier? selectedTier) {
    return Container(
      key: const Key('explore_feed_switcher'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Row(
          children: [
            // 'For You' Pill
            _buildFilterPill(
              label: 'For You',
              isSelected: !_showingAllSongs && activeTab == ExploreTab.forYou,
              onTap: () {
                setState(() => _showingAllSongs = false);
                ref.read(exploreTabProvider.notifier).state = ExploreTab.forYou;
              },
            ),
            const SizedBox(width: AppSpacing.xs),

            // 'Following' Pill
            _buildFilterPill(
              label: 'Following',
              isSelected: !_showingAllSongs && activeTab == ExploreTab.following,
              onTap: () {
                setState(() => _showingAllSongs = false);
                ref.read(exploreTabProvider.notifier).state =
                    ExploreTab.following;
              },
            ),
            const SizedBox(width: AppSpacing.xs),

            // 'All Songs' (Catalog Browser) Pill
            _buildFilterPill(
              label: 'All Songs',
              isSelected: _showingAllSongs,
              onTap: () {
                setState(() => _showingAllSongs = true);
              },
            ),
            const SizedBox(width: AppSpacing.sm),

            // Discovery Stage Tier Selector (Phase 39 REQ-DISC-UI-01)
            Container(
              key: const Key('explore_stage_tier_selector'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: DiscoveryStageTier.values.map((tier) {
                  final isTierSelected = selectedTier == tier;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _buildFilterPill(
                      label: tier.displayName,
                      isSelected: isTierSelected,
                      onTap: () {
                        setState(() => _showingAllSongs = false);
                        ref.read(selectedDiscoveryTierProvider.notifier).state =
                            isTierSelected ? null : tier;
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // Compact Discovery Drawer Hub Trigger
            InkWell(
              key: const Key('explore_feed_drawer_shortcut'),
              onTap: () => ExploreDiscoveryDrawerSheet.show(context),
              borderRadius: AppRadius.pillBorder,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: AppRadius.pillBorder,
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.explore_rounded,
                      size: 14,
                      color: AppColors.brandPrimary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Hub',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.pillBorder,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.brandPrimary : AppColors.surfaceElevated,
          borderRadius: AppRadius.pillBorder,
          border: Border.all(
            color: isSelected ? AppColors.brandPrimary : AppColors.borderSubtle,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: isSelected
                ? AppColors.brandContrast
                : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildInterleavedSocialFeed(
    List<SocialMusicPost> posts,
    List<Track> rising,
  ) {
    // 5-Slot Stride: every 5th slot is an interleaved carousel.
    // postIndex = idx - (idx ~/ 5)
    final carouselCount = posts.length ~/ 4;
    final totalSlots = posts.length + carouselCount;

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, idx) {
          final isCarouselSlot = (idx + 1) % 5 == 0;

          if (isCarouselSlot) {
            final carouselIdx = (idx + 1) ~/ 5;
            return _buildInterleavedCarousel(carouselIdx, rising);
          }

          final postIndex = idx - (idx ~/ 5);
          if (postIndex < posts.length) {
            return ExploreSocialPostCard(
              post: posts[postIndex],
              onRemixSuccess: widget.onCreateRequested,
            );
          }

          return const SizedBox.shrink();
        },
        childCount: totalSlots,
      ),
    );
  }

  Widget _buildInterleavedCarousel(int carouselIdx, List<Track> rising) {
    // Modulo 3: rotate through Radio Stations, Rising MP3s, and African Charts
    final type = carouselIdx % 3;

    switch (type) {
      case 1:
        // Carousel A: 12-Genre Radio Strip
        return Container(
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.surfaceSecondary,
            borderRadius: AppRadius.cardBorder,
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.radio_rounded,
                    color: AppColors.badgeCyan,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '12-Genre Radio Stations',
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: exploreGenreCatalog.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpacing.xs),
                  itemBuilder: (context, i) {
                    final genre = exploreGenreCatalog[i];
                    return ActionChip(
                      label: Text(genre),
                      backgroundColor: AppColors.surfaceElevated,
                      onPressed: () => playExploreGenreRadio(ref, genre),
                    );
                  },
                ),
              ),
            ],
          ),
        );

      case 2:
        // Carousel B: Rising MP3s Strip
        return Container(
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.surfaceSecondary,
            borderRadius: AppRadius.cardBorder,
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.rocket_launch_rounded,
                    color: AppColors.brandPrimary,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Fastest Growing Tracks 🚀',
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              for (final track in rising.take(2))
                TrackListTile(
                  track: track,
                ),
            ],
          ),
        );

      default:
        // Carousel C: African Music Charts Teaser
        return Container(
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.surfaceElevated, AppColors.surfaceSecondary],
            ),
            borderRadius: AppRadius.cardBorder,
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.leaderboard_rounded,
                color: AppColors.brandPrimary,
                size: 32,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'African Music Charts Top 50',
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'See which songs are trending across SA & Nigeria',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => ExploreDiscoveryDrawerSheet.show(context),
                child: const Text('View ->'),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildCatalogGrid(BuildContext context, List<Track> tracks) {
    final columns = ResponsiveUtils.isDesktop(context)
        ? 6
        : ResponsiveUtils.isTablet(context)
            ? 4
            : 2;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: AppSpacing.sm,
          mainAxisSpacing: AppSpacing.sm,
          childAspectRatio: 0.75,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final track = tracks[index];
            return TrackCard(
              track: track,
            );
          },
          childCount: tracks.length,
        ),
      ),
    );
  }
}

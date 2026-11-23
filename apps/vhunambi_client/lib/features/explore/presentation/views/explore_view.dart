import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../core/widgets/vhunambi_bottom_dock_kit.dart';
import '../../../../core/widgets/vhunambi_glass_tab_bar.dart';
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
    final hasActiveTrack = ref.watch(
      playerStateProvider.select((s) => s.hasActiveTrack),
    );

    final selectedTier = ref.watch(selectedDiscoveryTierProvider);
    // Filter posts if on following tab and rank/filter by discovery tier
    final rawPosts = activeTab == ExploreTab.following
        ? allPosts.where((p) => followingIds.contains(p.creatorId)).toList()
        : allPosts;
    final displayPosts = DiscoveryHierarchyRanker.filterByTier(
      rawPosts,
      selectedTier,
    );

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvasOf(context),
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
              const SliverToBoxAdapter(child: KineticPostComposerBar()),

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
                          foregroundColor: AppColors.textPrimaryOf(context),
                          side: BorderSide(
                            color: AppColors.borderSubtleOf(context),
                          ),
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
                          PhosphorIcon(
                            AppIcons.search,
                            size: 48,
                            color: AppColors.textSecondaryOf(context),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            activeTab == ExploreTab.following
                                ? 'Not following any creators yet'
                                : 'No posts in feed',
                            style: AppTypography.titleMedium.copyWith(
                              color: AppColors.textSecondaryOf(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Follow creators or switch to "For You" to discover new music.',
                            textAlign: TextAlign.center,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondaryOf(context),
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

  Widget _buildFeedSwitcher(
    BuildContext context,
    ExploreTab activeTab,
    DiscoveryStageTier? selectedTier,
  ) {
    final selectedFeedIndex = _showingAllSongs
        ? 2
        : (activeTab == ExploreTab.following ? 1 : 0);

    return Container(
      key: const Key('explore_feed_switcher'),
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Row(
          children: [
            VhunambiGlassTabBar(
              selectedIndex: selectedFeedIndex,
              scrollable: true,
              items: const <VhunambiGlassTabItem>[
                VhunambiGlassTabItem(
                  key: Key('explore_tab_for_you'),
                  label: 'For You',
                  icon: PhosphorIconsRegular.sparkle,
                ),
                VhunambiGlassTabItem(
                  key: Key('explore_tab_following'),
                  label: 'Following',
                  icon: PhosphorIconsRegular.usersThree,
                ),
                VhunambiGlassTabItem(
                  key: Key('explore_tab_all_songs'),
                  label: 'All Songs',
                  icon: PhosphorIconsRegular.musicNotes,
                ),
              ],
              onSelected: (index) {
                if (index == 0) {
                  setState(() => _showingAllSongs = false);
                  ref.read(exploreTabProvider.notifier).state =
                      ExploreTab.forYou;
                } else if (index == 1) {
                  setState(() => _showingAllSongs = false);
                  ref.read(exploreTabProvider.notifier).state =
                      ExploreTab.following;
                } else {
                  setState(() => _showingAllSongs = true);
                }
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
                      context: context,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevatedOf(context),
                  borderRadius: AppRadius.pillBorder,
                  border: Border.all(color: AppColors.borderSubtleOf(context)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const PhosphorIcon(
                      AppIcons.navExploreActive,
                      size: 14,
                      color: AppColors.brandPrimary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Hub',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textPrimaryOf(context),
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
    required BuildContext context,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.pillBorder,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brandPrimary
              : AppColors.surfaceElevatedOf(context),
          borderRadius: AppRadius.pillBorder,
          border: Border.all(
            color: isSelected
                ? AppColors.brandPrimary
                : AppColors.borderSubtleOf(context),
          ),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: isSelected
                ? AppColors.brandContrast
                : AppColors.textSecondaryOf(context),
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
      delegate: SliverChildBuilderDelegate((context, idx) {
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
      }, childCount: totalSlots),
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
            color: AppColors.surfaceSecondaryOf(context),
            borderRadius: AppRadius.cardBorder,
            border: Border.all(color: AppColors.borderSubtleOf(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const PhosphorIcon(
                    PhosphorIconsRegular.radio,
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
                      backgroundColor: AppColors.surfaceElevatedOf(context),
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
            color: AppColors.surfaceSecondaryOf(context),
            borderRadius: AppRadius.cardBorder,
            border: Border.all(color: AppColors.borderSubtleOf(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const PhosphorIcon(
                    PhosphorIconsFill.rocketLaunch,
                    color: AppColors.brandPrimary,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Fastest Growing Tracks',
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              for (final track in rising.take(2)) TrackListTile(track: track),
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
              colors: [
                AppColors.surfaceElevatedOf(context),
                AppColors.surfaceSecondaryOf(context),
              ],
            ),
            borderRadius: AppRadius.cardBorder,
            border: Border.all(color: AppColors.borderSubtleOf(context)),
          ),
          child: Row(
            children: [
              const PhosphorIcon(
                AppIcons.analytics,
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
                        color: AppColors.textSecondaryOf(context),
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
        delegate: SliverChildBuilderDelegate((context, index) {
          final track = tracks[index];
          return TrackCard(track: track);
        }, childCount: tracks.length),
      ),
    );
  }
}

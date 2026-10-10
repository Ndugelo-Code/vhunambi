import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../shared/models/track.dart';
import '../../domain/models/explore_models.dart';
import '../providers/explore_providers.dart';
import '../providers/recommendation_provider.dart';
import '../widgets/african_charts_banner.dart';
import '../widgets/catalog_filter_bar.dart';
import '../widgets/creator_card.dart';
import '../widgets/explore_empty_state.dart';
import '../widgets/explore_header_section.dart';
import '../widgets/explore_top_bar.dart';
import '../widgets/genre_radio_tile.dart';
import '../widgets/track_card.dart';
import '../widgets/track_list_tile.dart';
import '../../../social/presentation/widgets/trending_reels_shelf.dart';

/// Explore Feed & Music Discovery (`/explore`) — mounted at tab index 1 of
/// `RootShell`. Reference: `docs/phases/phase_05_explore_feed/blueprint.md`
class ExploreView extends ConsumerWidget {
  static const String newThisWeekTitle = 'New This Week';
  static const String recommendedForYouTitle = 'Recommended For You';
  static const String risingTitle = 'Rising';
  static const String featuredCreatorsTitle = 'Featured Creators';
  static const String genreRadioTitle = 'Genre Radio';

  /// Routes the `+ Create` CTA into the Studio cockpit (tab index 2).
  final VoidCallback? onCreateRequested;

  const ExploreView({super.key, this.onCreateRequested});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final isMobile = ResponsiveUtils.isMobile(context);

    final activeTab = ref.watch(exploreTabProvider);
    final newTracks = ref.watch(newThisWeekTracksProvider);
    final recommendedTracks = ref.watch(filteredRecommendedTracksProvider);
    final rising = ref.watch(risingTracksProvider);
    final creators = ref.watch(exploreCreatorsProvider);
    final catalog = ref.watch(visibleExploreTracksProvider);
    final hasResults = ref.watch(filteredExploreTracksProvider).isNotEmpty;
    final hasMore = ref.watch(hasMoreExploreTracksProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(
          isDesktop
              ? DesktopExploreTopBar.barHeight
              : MobileExploreTopBar.barHeight,
        ),
        child: isDesktop
            ? DesktopExploreTopBar(onCreateRequested: onCreateRequested)
            : MobileExploreTopBar(onCreateRequested: onCreateRequested),
      ),
      body: CustomScrollView(
        slivers: [
          // 2. Page header: title, tabs, streak chip
          const SliverToBoxAdapter(child: ExploreHeaderSection()),

          // 3. African Music Charts hero banner
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            sliver: SliverToBoxAdapter(
              child: AfricanChartsBanner(
                onViewCharts: () => _showChartsNotice(context),
              ),
            ),
          ),

          // 3.5 Trending Kinetic Reels discovery shelf (Phase 19)
          const SliverToBoxAdapter(child: TrendingReelsShelf()),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),

          // 4. Hero Grid: Personalized "Recommended For You" when on For You tab, else "New This Week"
          if (activeTab == ExploreTab.forYou) ...[
            _sectionHeader(recommendedForYouTitle),
            _trackCardGrid(context, recommendedTracks.take(6).toList()),
          ] else ...[
            _sectionHeader(newThisWeekTitle),
            _trackCardGrid(context, newTracks),
          ],

          // 5. Rising tracks (2-col split matrix on desktop, dense list mobile)
          _sectionHeader(risingTitle),
          if (isMobile)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              sliver: SliverList.separated(
                itemCount: rising.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.xs),
                itemBuilder: (_, index) =>
                    TrackListTile(track: rising[index]),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _risingColumns(context),
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisSpacing: AppSpacing.md,
                  childAspectRatio: 4.8,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, index) => TrackListTile(track: rising[index]),
                  childCount: rising.length,
                ),
              ),
            ),

          // 6. Featured Creators deck
          _sectionHeader(featuredCreatorsTitle),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _creatorColumns(context),
                crossAxisSpacing: AppSpacing.sm,
                mainAxisSpacing: AppSpacing.sm,
                childAspectRatio: _creatorRatio(context),
              ),
              delegate: SliverChildBuilderDelegate(
                (_, index) => CreatorCard(creator: creators[index]),
                childCount: creators.length,
              ),
            ),
          ),

          // 7. 12-genre radio mosaic
          _sectionHeader(genreRadioTitle),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _radioColumns(context),
                crossAxisSpacing: AppSpacing.sm,
                mainAxisSpacing: AppSpacing.sm,
                childAspectRatio: 1.4,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, index) =>
                    GenreRadioTile(genre: exploreGenreCatalog[index]),
                childCount: exploreGenreCatalog.length,
              ),
            ),
          ),

          // 8. Catalog filter engine
          const SliverToBoxAdapter(child: CatalogFilterBar()),

          // 9. Catalog grid or universal empty state
          if (hasResults)
            _trackCardGrid(context, catalog)
          else
            SliverToBoxAdapter(
              child: ExploreEmptyState(
                onCreateRequested: onCreateRequested,
              ),
            ),

          // 10. Pagination
          if (hasResults && hasMore)
            const SliverToBoxAdapter(child: _LoadMoreButton()),

          const SliverToBoxAdapter(child: SizedBox(height: 110)),
        ],
      ),
    );
  }

  void _showChartsNotice(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceModal,
        duration: const Duration(seconds: 3),
        content: Text(
          'African Music Charts expand into the full leaderboards with the marketplace release.',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Text(title, style: AppTypography.titleLarge),
      ),
    );
  }

  Widget _trackCardGrid(BuildContext context, List<Track> tracks) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _cardColumns(context),
          crossAxisSpacing: _cardSpacing(context),
          mainAxisSpacing: _cardSpacing(context),
          childAspectRatio: _cardRatio(context),
        ),
        delegate: SliverChildBuilderDelegate(
          (_, index) => TrackCard(track: tracks[index]),
          childCount: tracks.length,
        ),
      ),
    );
  }
}

/// Centered `Load more` pill advancing the catalog pagination cursor
/// (REQ-EXP-08 / Blueprint 01 §5 Section F.4).
class _LoadMoreButton extends ConsumerWidget {
  const _LoadMoreButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      child: Center(
        child: InkWell(
          onTap: () => loadMoreExploreTracks(ref),
          borderRadius: AppRadius.pillBorder,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxl,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: AppRadius.pillBorder,
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Text(
              'Load more',
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Track card columns: 2 mobile / 4 tablet / 6 desktop.
int _cardColumns(BuildContext context) {
  if (ResponsiveUtils.isDesktop(context)) return 6;
  if (ResponsiveUtils.isTablet(context)) return 4;
  return 2;
}

/// Track card aspect ratio: 0.75 mobile / 0.74 tablet / 0.72 desktop.
double _cardRatio(BuildContext context) {
  if (ResponsiveUtils.isDesktop(context)) return 0.72;
  if (ResponsiveUtils.isTablet(context)) return 0.74;
  return 0.75;
}

double _cardSpacing(BuildContext context) =>
    ResponsiveUtils.isDesktop(context) ? AppSpacing.md : AppSpacing.sm;

/// Rising tracks: balanced 2-column split matrix (1 column on tablet).
int _risingColumns(BuildContext context) =>
    ResponsiveUtils.isTablet(context) ? 1 : 2;

/// Featured creators: 2 mobile / 3 tablet / 6 desktop single-row deck.
int _creatorColumns(BuildContext context) {
  if (ResponsiveUtils.isDesktop(context)) return 6;
  if (ResponsiveUtils.isTablet(context)) return 3;
  return 2;
}

double _creatorRatio(BuildContext context) =>
    ResponsiveUtils.isDesktop(context) ? 1.8 : 2.2;

/// Genre radio mosaic: 2x6 mobile / 3x4 tablet / 6x2 desktop.
int _radioColumns(BuildContext context) {
  if (ResponsiveUtils.isDesktop(context)) return 6;
  if (ResponsiveUtils.isTablet(context)) return 3;
  return 2;
}

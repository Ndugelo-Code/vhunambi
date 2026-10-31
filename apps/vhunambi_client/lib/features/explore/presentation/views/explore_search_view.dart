import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/models/track.dart';
import '../../../profile/presentation/views/artist_profile_view.dart';
import '../../../social/presentation/providers/trending_reels_provider.dart';
import '../../../social/presentation/widgets/kinetic_reels_modal.dart';
import '../../domain/models/explore_models.dart';
import '../providers/explore_providers.dart';
import '../widgets/track_list_tile.dart';

/// Curated African trending search tags (REQ-EXP-SEARCH-04).
const List<String> kAfricanTrendingQueries = [
  '#Amapiano2026',
  'Tshivenḓa log drum',
  'Maskandi top 10',
  'Gqom warehouse',
  'Private School Rhodes',
  'Makhadzi live',
  'Kabza de Small',
  'Soweto Gospel vibe',
];

/// Dedicated full-screen TikTok-style search view (REQ-EXP-SEARCH-01..05).
class ExploreSearchView extends ConsumerStatefulWidget {
  const ExploreSearchView({super.key});

  @override
  ConsumerState<ExploreSearchView> createState() => _ExploreSearchViewState();
}

class _ExploreSearchViewState extends ConsumerState<ExploreSearchView> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  ExploreSearchCategory _selectedCategory = ExploreSearchCategory.top;

  @override
  void initState() {
    super.initState();
    // Auto-focus the search field after transition
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _executeSearch(String query) {
    _searchController.text = query;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: query.length),
    );
    if (query.trim().isNotEmpty) {
      ref.read(recentSearchesProvider.notifier).addQuery(query.trim());
    }
    setState(() {});
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();
    final recentSearches = ref.watch(recentSearchesProvider);
    final allTracks = ref.watch(exploreTracksProvider);
    final allReels = ref.watch(trendingReelsProvider);
    final allCreators = ref.watch(exploreCreatorsProvider);

    return Scaffold(
      key: const Key('explore_search_view'),
      backgroundColor: AppColors.surfaceCanvas,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: SafeArea(
          bottom: false,
          child: Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: IconButton(
                    key: const Key('explore_search_back_btn'),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: AppColors.textPrimary,
                    ),
                    onPressed: () {
                      _focusNode.unfocus();
                      Navigator.of(context).pop();
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: AppRadius.pillBorder,
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Icon(
                            Icons.search_rounded,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            key: const Key('explore_search_input'),
                            controller: _searchController,
                            focusNode: _focusNode,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search songs, artists, reels...',
                              hintStyle: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 10,
                              ),
                            ),
                            onSubmitted: (val) {
                              if (val.trim().isNotEmpty) {
                                ref
                                    .read(recentSearchesProvider.notifier)
                                    .addQuery(val.trim());
                              }
                            },
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          SizedBox(
                            width: 36,
                            height: 36,
                            child: IconButton(
                              key: const Key('explore_search_clear_btn'),
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                              onPressed: _clearSearch,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: query.isEmpty
          ? _buildInitialDiscovery(recentSearches)
          : _buildSearchResults(
              query: query,
              tracks: allTracks,
              reels: allReels,
              creators: allCreators,
            ),
    );
  }

  Widget _buildInitialDiscovery(List<String> recentSearches) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (recentSearches.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Searches',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                key: const Key('explore_recent_clear_all'),
                onPressed: () {
                  ref.read(recentSearchesProvider.notifier).clearAll();
                },
                child: Text(
                  'Clear all',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final query in recentSearches)
                InputChip(
                  label: Text(
                    query,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  backgroundColor: AppColors.surfaceElevated,
                  deleteIconColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.borderSubtle),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.pillBorder,
                  ),
                  onPressed: () => _executeSearch(query),
                  onDeleted: () {
                    ref.read(recentSearchesProvider.notifier).removeQuery(query);
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        // Trending Queries Section
        Row(
          children: [
            const Icon(
              Icons.trending_up_rounded,
              color: AppColors.brandPrimary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'You May Like',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final tag in kAfricanTrendingQueries)
              ActionChip(
                label: Text(
                  tag,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.brandPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor: AppColors.surfaceElevated,
                side: const BorderSide(color: AppColors.borderSubtle),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.pillBorder,
                ),
                onPressed: () => _executeSearch(tag),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchResults({
    required String query,
    required List<Track> tracks,
    required List<dynamic> reels,
    required List<CreatorProfile> creators,
  }) {
    final lowerQ = query.toLowerCase();
    final matchedTracks = tracks
        .where((t) =>
            t.title.toLowerCase().contains(lowerQ) ||
            t.creatorName.toLowerCase().contains(lowerQ) ||
            t.genre.toLowerCase().contains(lowerQ))
        .toList();

    final matchedReels = reels
        .where((r) =>
            r.title.toLowerCase().contains(lowerQ) ||
            r.creatorUsername.toLowerCase().contains(lowerQ) ||
            r.genre.toLowerCase().contains(lowerQ))
        .toList();

    final matchedCreators = creators
        .where((c) =>
            c.name.toLowerCase().contains(lowerQ) ||
            c.handle.toLowerCase().contains(lowerQ) ||
            c.primaryGenres.any((g) => g.toLowerCase().contains(lowerQ)))
        .toList();

    return Column(
      children: [
        // Category Filter Tabs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              _buildCategoryTab(
                category: ExploreSearchCategory.top,
                label: 'Top',
                key: const Key('explore_search_tab_top'),
              ),
              const SizedBox(width: AppSpacing.xs),
              _buildCategoryTab(
                category: ExploreSearchCategory.songs,
                label: 'Songs (${matchedTracks.length})',
                key: const Key('explore_search_tab_songs'),
              ),
              const SizedBox(width: AppSpacing.xs),
              _buildCategoryTab(
                category: ExploreSearchCategory.reels,
                label: 'Kinetic Reels (${matchedReels.length})',
                key: const Key('explore_search_tab_reels'),
              ),
              const SizedBox(width: AppSpacing.xs),
              _buildCategoryTab(
                category: ExploreSearchCategory.creators,
                label: 'Creators (${matchedCreators.length})',
                key: const Key('explore_search_tab_creators'),
              ),
            ],
          ),
        ),
        const Divider(color: AppColors.borderSubtle, height: 1),

        // Result Body
        Expanded(
          child: switch (_selectedCategory) {
            ExploreSearchCategory.top => _buildTopResults(
                matchedTracks,
                matchedReels,
                matchedCreators,
              ),
            ExploreSearchCategory.songs => _buildSongsList(matchedTracks),
            ExploreSearchCategory.reels => _buildReelsGrid(matchedReels),
            ExploreSearchCategory.creators =>
              _buildCreatorsList(matchedCreators),
          },
        ),
      ],
    );
  }

  Widget _buildCategoryTab({
    required ExploreSearchCategory category,
    required String label,
    required Key key,
  }) {
    final isSelected = _selectedCategory == category;
    return InkWell(
      key: key,
      borderRadius: AppRadius.pillBorder,
      onTap: () => setState(() => _selectedCategory = category),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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

  Widget _buildTopResults(
    List<Track> tracks,
    List<dynamic> reels,
    List<CreatorProfile> creators,
  ) {
    if (tracks.isEmpty && reels.isEmpty && creators.isEmpty) {
      return _buildEmptyResults();
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (creators.isNotEmpty) ...[
          Text('Creators', style: AppTypography.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          for (final c in creators.take(2)) _buildCreatorTile(c),
          const SizedBox(height: AppSpacing.md),
        ],
        if (tracks.isNotEmpty) ...[
          Text('Songs', style: AppTypography.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          for (final t in tracks.take(4))
            TrackListTile(track: t),
          const SizedBox(height: AppSpacing.md),
        ],
        if (reels.isNotEmpty) ...[
          Text('Kinetic Reels', style: AppTypography.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: reels.length,
              itemBuilder: (context, i) {
                final r = reels[i];
                return GestureDetector(
                  onTap: () => KineticReelsModal.show(
                    context,
                    clips: reels.cast(),
                    initialClipId: r.id,
                  ),
                  child: Container(
                    width: 100,
                    margin: const EdgeInsets.only(right: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: AppRadius.cardBorder,
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          r.title,
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSongsList(List<Track> tracks) {
    if (tracks.isEmpty) return _buildEmptyResults();
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: tracks.length,
      itemBuilder: (context, i) => TrackListTile(
        track: tracks[i],
      ),
    );
  }

  Widget _buildReelsGrid(List<dynamic> reels) {
    if (reels.isEmpty) return _buildEmptyResults();
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 9 / 16,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
      ),
      itemCount: reels.length,
      itemBuilder: (context, i) {
        final r = reels[i];
        return GestureDetector(
          onTap: () => KineticReelsModal.show(
            context,
            clips: reels.cast(),
            initialClipId: r.id,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: AppRadius.cardBorder,
              border: Border.all(color: AppColors.borderSubtle),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                Text(
                  '@${r.creatorUsername}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.brandPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  r.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCreatorsList(List<CreatorProfile> creators) {
    if (creators.isEmpty) return _buildEmptyResults();
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: creators.length,
      itemBuilder: (context, i) => _buildCreatorTile(creators[i]),
    );
  }

  Widget _buildCreatorTile(CreatorProfile creator) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppColors.brandPrimary,
        child: Text(
          creator.initials,
          style: AppTypography.caption.copyWith(
            color: AppColors.brandContrast,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Row(
        children: [
          Text(creator.name, style: AppTypography.bodyLarge),
          if (creator.isVerified) ...[
            const SizedBox(width: 4),
            const Icon(
              Icons.verified_rounded,
              color: AppColors.brandPrimary,
              size: 14,
            ),
          ],
        ],
      ),
      subtitle: Text(
        '${creator.handle} • ${creator.primaryGenreLabel}',
        style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textSecondary,
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ArtistProfileView(artistId: creator.id),
          ),
        );
      },
    );
  }

  Widget _buildEmptyResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 48,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No matches found',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try searching by genre, producer, or song title',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}


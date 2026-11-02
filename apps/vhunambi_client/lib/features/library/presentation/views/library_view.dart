import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../core/widgets/vhunambi_top_bar_kit.dart';
import '../../../../core/widgets/vhunambi_bottom_dock_kit.dart';
import '../../../beats/presentation/views/beats_vault_view.dart';
import '../../../collections/presentation/views/collections_vault_view.dart';
import '../../../playlists/presentation/views/playlists_vault_view.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../domain/models/library_models.dart';
import '../providers/library_providers.dart';
import '../widgets/library_app_bar.dart';
import '../widgets/library_category_rail.dart';
import '../widgets/library_cover_art.dart';
import '../widgets/library_empty_state.dart';
import '../widgets/library_track_grid_card.dart';
import '../widgets/library_track_tile.dart';

/// Library & User Asset Vault (`/library`) — mounted at tab index 3 of `RootShell`.
/// Reference: `docs/phases/phase_04_library_vault/blueprint.md`
class LibraryView extends ConsumerWidget {
  /// Routes to the Studio cockpit (tab index 2) when the host shell provides it.
  final VoidCallback? onCreateRequested;

  const LibraryView({super.key, this.onCreateRequested});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final category = ref.watch(libraryCategoryProvider);
    final viewMode = ref.watch(libraryViewModeProvider);
    final searchQuery = ref.watch(librarySearchQueryProvider);
    final tracks = ref.watch(filteredLibraryTracksProvider);

    // The search strip stays mounted while a query is active so it can be cleared.
    final showSearchStrip = tracks.isNotEmpty || searchQuery.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(
          VhunambiTopBarMetrics.totalHeight(context),
        ),
        child: LibraryAppBar(onCreateRequested: onCreateRequested),
      ),
      body: Column(
        children: [
          const LibraryCategoryRail(),
          Expanded(
            child: category == LibraryCategory.playlists
                ? PlaylistsVaultView(onCreateRequested: onCreateRequested)
                : category == LibraryCategory.collections
                    ? CollectionsVaultView(
                        onCreateRequested: onCreateRequested,
                      )
                    : category == LibraryCategory.beats
                        ? BeatsVaultView(
                            onCreateRequested: onCreateRequested,
                          )
                        : Column(
                    children: [
                      if (showSearchStrip)
                        _VaultSearchStrip(
                          category: category,
                          viewMode: viewMode,
                          resultCount: tracks.length,
                        ),
                      if (category == LibraryCategory.songs &&
                          searchQuery.trim().isEmpty)
                        const _RecentlyPlayedShelf(),
                      Expanded(
                        child: tracks.isEmpty
                            ? LibraryEmptyState(
                                category: category,
                                searchQuery: searchQuery,
                                onCreateRequested: onCreateRequested,
                              )
                            : viewMode == LibraryViewMode.grid
                                ? _VaultGrid(tracks: tracks)
                                : _VaultList(tracks: tracks, isMobile: isMobile),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Recently Played horizontal shelf (Mission 11).
///
/// Renders one-tap 44px cover cards for the user's most recently played songs,
/// resolving live vault records (deleted ids are dropped by the provider).
/// Hidden automatically when there is no history yet.
class _RecentlyPlayedShelf extends ConsumerWidget {
  const _RecentlyPlayedShelf();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentlyPlayedTracksProvider);
    if (recent.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: Text(
            'Recently Played',
            style: AppTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: recent.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              final track = recent[index];
              return SizedBox(
                width: 44,
                height: 44,
                child: Tooltip(
                  message: track.title,
                  child: InkWell(
                    borderRadius: AppRadius.thumbBorder,
                    onTap: () => playLibraryTrack(ref, track),
                    child: LibraryCoverArt(track: track, size: 44),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
      ],
    );
  }
}

class _VaultList extends ConsumerWidget {
  final List<LibraryTrack> tracks;
  final bool isMobile;

  const _VaultList({required this.tracks, required this.isMobile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomInset = VhunambiBottomDockMetrics.scrollInset(
      hasActiveTrack:
          ref.watch(playerStateProvider.select((s) => s.hasActiveTrack)),
    );
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xxs,
        AppSpacing.md,
        bottomInset,
      ),
      itemCount: tracks.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (_, index) => LibraryTrackTile(
        track: tracks[index],
        showGenreBadge: !isMobile,
      ),
    );
  }
}

class _VaultGrid extends ConsumerWidget {
  final List<LibraryTrack> tracks;

  const _VaultGrid({required this.tracks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomInset = VhunambiBottomDockMetrics.scrollInset(
      hasActiveTrack:
          ref.watch(playerStateProvider.select((s) => s.hasActiveTrack)),
    );
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xxs,
        AppSpacing.md,
        bottomInset,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: ResponsiveUtils.gridColumns(context),
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        childAspectRatio: 1,
      ),
      itemCount: tracks.length,
      itemBuilder: (_, index) => LibraryTrackGridCard(track: tracks[index]),
    );
  }
}

/// Real-time search input, local/cloud filter and grid/list view toggle (REQ-LIB-04).
class _VaultSearchStrip extends ConsumerStatefulWidget {
  final LibraryCategory category;
  final LibraryViewMode viewMode;
  final int resultCount;

  const _VaultSearchStrip({
    required this.category,
    required this.viewMode,
    required this.resultCount,
  });

  @override
  ConsumerState<_VaultSearchStrip> createState() => _VaultSearchStripState();
}

class _VaultSearchStripState extends ConsumerState<_VaultSearchStrip> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(librarySearchQueryProvider),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _hint => switch (widget.category) {
        LibraryCategory.songs => 'Search my songs...',
        LibraryCategory.playlists => 'Search my playlists...',
        LibraryCategory.collections => 'Search my collections...',
        LibraryCategory.beats => 'Search my beats...',
        LibraryCategory.licensing => 'Search my licenses...',
        LibraryCategory.trash => 'Search trash...',
      };

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);

    // Keep the field in sync when the query is reset elsewhere (category change).
    ref.listen(librarySearchQueryProvider, (previous, next) {
      if (_controller.text != next) {
        _controller.text = next;
      }
    });

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xxs,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 40),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: AppRadius.inputBorder,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Center(
                      child: TextField(
                        controller: _controller,
                        onChanged: (value) => ref
                            .read(librarySearchQueryProvider.notifier)
                            .state = value,
                        textInputAction: TextInputAction.search,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textPrimary,
                        ),
                        cursorColor: AppColors.brandPrimary,
                        decoration: InputDecoration(
                          hintText: _hint,
                          hintStyle: AppTypography.caption,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          const _SyncFilterButton(),
          const SizedBox(width: AppSpacing.xs),
          _ViewModeToggle(viewMode: widget.viewMode),
          if (isDesktop) ...[
            const SizedBox(width: AppSpacing.sm),
            Text(
              '${widget.resultCount} ${widget.resultCount == 1 ? 'asset' : 'assets'}',
              style: AppTypography.caption,
            ),
          ],
        ],
      ),
    );
  }
}

class _SyncFilterButton extends ConsumerWidget {
  const _SyncFilterButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeFilter = ref.watch(librarySyncFilterProvider);
    final isFiltered = activeFilter != LibrarySyncFilter.any;

    return PopupMenuButton<LibrarySyncFilter>(
      tooltip: 'Filter assets',
      color: AppColors.surfaceModal,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.inputBorder,
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      onSelected: (filter) =>
          ref.read(librarySyncFilterProvider.notifier).state = filter,
      itemBuilder: (_) => [
        for (final filter in LibrarySyncFilter.values)
          PopupMenuItem<LibrarySyncFilter>(
            value: filter,
            height: 40,
            child: Row(
              children: [
                Icon(
                  _syncFilterIcon(filter),
                  size: 16,
                  color: filter == activeFilter
                      ? AppColors.brandPrimary
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    _syncFilterLabel(filter),
                    style: AppTypography.bodySmall.copyWith(
                      color: filter == activeFilter
                          ? AppColors.brandPrimary
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (filter == activeFilter)
                  const Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: AppColors.brandPrimary,
                  ),
              ],
            ),
          ),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surfaceSecondary,
          borderRadius: AppRadius.inputBorder,
          border: Border.all(
            color:
                isFiltered ? AppColors.brandPrimary : AppColors.borderSubtle,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune_rounded,
              size: 15,
              color: isFiltered
                  ? AppColors.brandPrimary
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.xxs + 2),
            Text(
              isFiltered ? _syncFilterLabel(activeFilter) : 'Filter',
              style: AppTypography.caption.copyWith(
                color: isFiltered
                    ? AppColors.brandPrimary
                    : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewModeToggle extends ConsumerWidget {
  final LibraryViewMode viewMode;

  const _ViewModeToggle({required this.viewMode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: AppRadius.inputBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          _ViewModeButton(
            icon: Icons.grid_view_rounded,
            tooltip: 'Grid view',
            isActive: viewMode == LibraryViewMode.grid,
            onTap: () => ref.read(libraryViewModeProvider.notifier).state =
                LibraryViewMode.grid,
          ),
          _ViewModeButton(
            icon: Icons.view_list_rounded,
            tooltip: 'List view',
            isActive: viewMode == LibraryViewMode.list,
            onTap: () => ref.read(libraryViewModeProvider.notifier).state =
                LibraryViewMode.list,
          ),
        ],
      ),
    );
  }
}

class _ViewModeButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback onTap;

  const _ViewModeButton({
    required this.icon,
    required this.tooltip,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.thumbBorder,
        child: Container(
          width: 38,
          height: 38,
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: isActive ? AppColors.brandPrimary : Colors.transparent,
            borderRadius: AppRadius.thumbBorder,
          ),
          child: Icon(
            icon,
            size: 17,
            color: isActive
                ? AppColors.brandContrast
                : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

String _syncFilterLabel(LibrarySyncFilter filter) => switch (filter) {
      LibrarySyncFilter.any => 'All tracks',
      LibrarySyncFilter.offlineOnly => 'Offline only',
      LibrarySyncFilter.cloudOnly => 'Cloud only',
    };

IconData _syncFilterIcon(LibrarySyncFilter filter) => switch (filter) {
      LibrarySyncFilter.any => Icons.album_outlined,
      LibrarySyncFilter.offlineOnly => Icons.download_done_rounded,
      LibrarySyncFilter.cloudOnly => Icons.cloud_outlined,
    };

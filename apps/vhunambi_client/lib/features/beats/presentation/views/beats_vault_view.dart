import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../library/domain/models/library_models.dart';
import '../../../library/presentation/widgets/library_empty_state.dart';
import '../../../player/domain/models/player_state.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../domain/models/producer_beat_entity.dart';
import '../beat_format.dart';
import '../providers/beats_provider.dart';
import '../widgets/beat_card.dart';
import '../widgets/beat_form_dialog.dart';
import '../widgets/beat_list_tile.dart';
import '../widgets/beat_stats_banner.dart';
import '../widgets/publish_beat_modal.dart';
import '../widgets/stem_export_modal.dart';
import 'beat_detail_cockpit_view.dart';

/// Producer Beats Vault & Beatstore cockpit (`/library?tab=beats`).
///
/// Implements REQ-BEAT-14 to REQ-BEAT-22: responsive grid/list vault, status
/// filtering, authoring dialog, marketplace publish sheet, stems export and the
/// persistent player audition bridge.
class BeatsVaultView extends ConsumerStatefulWidget {
  /// Retained for API parity with the other vault tabs; the empty-state CTA
  /// opens the beat authoring dialog owned by this view.
  final VoidCallback? onCreateRequested;

  const BeatsVaultView({super.key, this.onCreateRequested});

  @override
  ConsumerState<BeatsVaultView> createState() => _BeatsVaultViewState();
}

class _BeatsVaultViewState extends ConsumerState<BeatsVaultView> {
  final TextEditingController _searchController = TextEditingController();
  LibraryViewMode _viewMode = LibraryViewMode.grid;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ───────────────────────────── Actions ─────────────────────────────

  /// Opens the beat authoring dialog (REQ-BEAT-18).
  void _showCreateDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => BeatFormDialog(
        onSubmitted: (result) {
          ref.read(beatsProvider.notifier).createBeat(
                title: result.title,
                genre: result.genre,
                bpm: result.bpm,
                musicalKey: result.musicalKey,
                tags: result.tags,
                priceInCredits: result.priceInCredits,
                licenseTier: result.licenseTier,
                status: result.status,
                previewAudioUrl: beatPreviewUrlFor(result.title),
              );
        },
      ),
    );
  }

  void _showEditDialog(ProducerBeatEntity beat) {
    showDialog<void>(
      context: context,
      builder: (_) => BeatFormDialog(
        initial: beat,
        onSubmitted: (result) {
          ref.read(beatsProvider.notifier).updateBeat(
                beat.copyWith(
                  title: result.title,
                  genre: result.genre,
                  bpm: result.bpm,
                  musicalKey: result.musicalKey,
                  tags: result.tags,
                  priceInCredits: result.priceInCredits,
                  licenseTier: result.licenseTier,
                  status: result.status,
                ),
              );
        },
      ),
    );
  }

  /// Confirms the marketplace terms before injecting the listing
  /// (REQ-BEAT-19).
  void _showPublishModal(ProducerBeatEntity beat) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => PublishBeatModal(
        beat: beat,
        onConfirm: () {
          ref.read(beatsProvider.notifier).publishToMarket(beat.id);
          _showSnack('"${beat.title}" is live on the marketplace');
        },
      ),
    );
  }

  void _showStemModal(ProducerBeatEntity beat) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => StemExportModal(
        beat: beat,
        onAuditionStem: (stem) => _showSnack('Auditioning $stem stem'),
        onDownloadStem: (stem) => _showSnack('$stem stem queued for download'),
        onDownloadBundle: () =>
            _showSnack('ZIP manifest for "${beat.title}" queued'),
      ),
    );
  }

  /// Publishing routes through the confirmation sheet; unpublishing is
  /// immediate (REQ-BEAT-21).
  void _togglePublication(ProducerBeatEntity beat) {
    if (!beat.isPublished) {
      _showPublishModal(beat);
      return;
    }

    ref.read(beatsProvider.notifier).unpublishFromMarket(beat.id);
    _showSnack('"${beat.title}" switched back to draft');
  }

  void _confirmDelete(ProducerBeatEntity beat) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceModal,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
        title: Text(
          'Delete Beat?',
          style:
              AppTypography.titleMedium.copyWith(color: AppColors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete "${beat.title}"? '
          'The beat is removed from the marketplace immediately.',
          style: AppTypography.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Cancel',
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            key: const Key('beat_delete_confirm'),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ref.read(beatsProvider.notifier).deleteBeat(beat.id);
            },
            child: Text(
              'Delete',
              style: AppTypography.bodyLarge.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  /// Plays / pauses the 180s instrumental preview (REQ-BEAT-22).
  void _audition(ProducerBeatEntity beat) {
    final playback = ref.read(playerStateProvider);
    if (isBeatAuditioning(playback, beat)) {
      ref.read(playerStateProvider.notifier).pause();
      return;
    }
    auditionBeatPreview(ref, beat);
  }

  void _openCockpit(ProducerBeatEntity beat) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BeatDetailCockpitView(beatId: beat.id),
      ),
    );
  }

  void _clearFilters() {
    _searchController.clear();
    ref.read(beatsVaultFilterProvider.notifier).state =
        const BeatsVaultFilterState();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppTypography.bodyLarge),
        backgroundColor: AppColors.surfaceElevated,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ───────────────────────────── Build ─────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final isTablet = ResponsiveUtils.isTablet(context);
    final allBeats = ref.watch(beatsProvider);
    final beats = ref.watch(filteredBeatsVaultProvider);
    final stats = ref.watch(beatsVaultStatsProvider);
    final filter = ref.watch(beatsVaultFilterProvider);
    final playback = ref.watch(playerStateProvider);

    return Padding(
      padding: EdgeInsets.all(isMobile ? AppSpacing.sm : AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BeatStatsBanner(stats: stats, compact: isMobile),
          const SizedBox(height: AppSpacing.md),
          _VaultActionStrip(
            searchController: _searchController,
            filter: filter,
            stats: stats,
            viewMode: _viewMode,
            onSearchChanged: (value) => ref
                .read(beatsVaultFilterProvider.notifier)
                .state = ref.read(beatsVaultFilterProvider).copyWith(
                      searchQuery: value,
                    ),
            onStatusSelected: (status) => ref
                .read(beatsVaultFilterProvider.notifier)
                .state = ref.read(beatsVaultFilterProvider).copyWith(
                      statusFilter: status,
                      clearStatus: status == null,
                    ),
            onSortSelected: (order) => ref
                .read(beatsVaultFilterProvider.notifier)
                .state = ref.read(beatsVaultFilterProvider).copyWith(
                      sortOrder: order,
                    ),
            onViewModeChanged: (mode) => setState(() => _viewMode = mode),
            onCreatePressed: _showCreateDialog,
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: _buildBody(
              allBeats: allBeats,
              beats: beats,
              filter: filter,
              playback: playback,
              isMobile: isMobile,
              isTablet: isTablet,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody({
    required List<ProducerBeatEntity> allBeats,
    required List<ProducerBeatEntity> beats,
    required BeatsVaultFilterState filter,
    required PlayerState playback,
    required bool isMobile,
    required bool isTablet,
  }) {
    if (allBeats.isEmpty) {
      // Universal vault empty state (REQ-BEAT-14); its CTA opens the beat
      // authoring dialog so the vault loop is never left.
      return LibraryEmptyState(
        category: LibraryCategory.beats,
        onCreateRequested: _showCreateDialog,
      );
    }

    if (beats.isEmpty) {
      return _NoBeatsMatch(
        searchQuery: filter.searchQuery,
        onClearFilters: _clearFilters,
      );
    }

    return _viewMode == LibraryViewMode.grid
        ? _buildGrid(beats, isMobile: isMobile, isTablet: isTablet, playback: playback)
        : _buildList(beats, playback: playback);
  }

  /// Responsive 2 / 3 / 4 column grid (REQ-BEAT-14 / Blueprint 14 §2.1).
  Widget _buildGrid(
    List<ProducerBeatEntity> beats, {
    required bool isMobile,
    required bool isTablet,
    required PlayerState playback,
  }) {
    final columns = isMobile ? 2 : (isTablet ? 3 : 4);
    final aspectRatio = isMobile ? 0.78 : (isTablet ? 0.82 : 0.85);

    return GridView.builder(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: aspectRatio,
      ),
      itemCount: beats.length,
      itemBuilder: (context, index) {
        final beat = beats[index];
        return BeatCard(
          key: ValueKey<String>('beat_grid_${beat.id}'),
          beat: beat,
          isAuditioning: isBeatAuditioning(playback, beat),
          onTap: () => _openCockpit(beat),
          onAudition: () => _audition(beat),
          onEdit: () => _showEditDialog(beat),
          onTogglePublish: () => _togglePublication(beat),
          onExportStems: () => _showStemModal(beat),
          onDelete: () => _confirmDelete(beat),
        );
      },
    );
  }

  /// Dense `Material`-wrapped list mode (REQ-BEAT-14 / REQ-BEAT-16).
  Widget _buildList(
    List<ProducerBeatEntity> beats, {
    required PlayerState playback,
  }) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      itemCount: beats.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, index) {
        final beat = beats[index];
        return BeatListTile(
          beat: beat,
          isAuditioning: isBeatAuditioning(playback, beat),
          onTap: () => _openCockpit(beat),
          onAudition: () => _audition(beat),
          onEdit: () => _showEditDialog(beat),
          onTogglePublish: () => _togglePublication(beat),
          onExportStems: () => _showStemModal(beat),
          onDelete: () => _confirmDelete(beat),
        );
      },
    );
  }
}

/// Search field, status chips, sort menu, view toggle and `+ New Beat` CTA
/// (REQ-BEAT-14).
class _VaultActionStrip extends StatelessWidget {
  final TextEditingController searchController;
  final BeatsVaultFilterState filter;
  final BeatsVaultStats stats;
  final LibraryViewMode viewMode;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<BeatStatus?> onStatusSelected;
  final ValueChanged<BeatsSortOrder> onSortSelected;
  final ValueChanged<LibraryViewMode> onViewModeChanged;
  final VoidCallback onCreatePressed;

  const _VaultActionStrip({
    required this.searchController,
    required this.filter,
    required this.stats,
    required this.viewMode,
    required this.onSearchChanged,
    required this.onStatusSelected,
    required this.onSortSelected,
    required this.onViewModeChanged,
    required this.onCreatePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 240,
          height: 44,
          child: TextField(
            key: const Key('beat_search'),
            controller: searchController,
            onChanged: onSearchChanged,
            style: AppTypography.bodyLarge,
            decoration: InputDecoration(
              hintText: 'Search my beats...',
              hintStyle: AppTypography.bodySmall,
              isDense: true,
              filled: true,
              fillColor: AppColors.surfaceSecondary,
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: 16,
                color: AppColors.textTertiary,
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: AppSpacing.sm,
              ),
              border: OutlineInputBorder(
                borderRadius: AppRadius.inputBorder,
                borderSide: const BorderSide(color: AppColors.borderSubtle),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.inputBorder,
                borderSide: const BorderSide(color: AppColors.borderSubtle),
              ),
            ),
          ),
        ),
        _StatusChip(
          key: const Key('beat_status_chip_all'),
          label: 'All (${stats.totalBeats})',
          isSelected: filter.statusFilter == null,
          onTap: () => onStatusSelected(null),
        ),
        _StatusChip(
          key: const Key('beat_status_chip_published'),
          label: 'Published (${stats.publishedCount})',
          isSelected: filter.statusFilter == BeatStatus.published,
          onTap: () => onStatusSelected(BeatStatus.published),
        ),
        _StatusChip(
          key: const Key('beat_status_chip_draft'),
          label: 'Draft (${stats.draftCount})',
          isSelected: filter.statusFilter == BeatStatus.draft,
          onTap: () => onStatusSelected(BeatStatus.draft),
        ),
        _SortMenu(sortOrder: filter.sortOrder, onSelected: onSortSelected),
        _ViewModeToggle(viewMode: viewMode, onChanged: onViewModeChanged),
        ElevatedButton.icon(
          key: const Key('new_beat_button'),
          onPressed: onCreatePressed,
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('New Beat'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brandPrimary,
            foregroundColor: AppColors.brandContrast,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.pillBorder,
            ),
          ),
        ),
      ],
    );
  }
}

/// `All` / `Published` / `Draft` filter chip carrying the live vault counts.
class _StatusChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.pillBorder,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color:
              isSelected ? AppColors.amberInset : AppColors.surfaceSecondary,
          borderRadius: AppRadius.pillBorder,
          border: Border.all(
            color:
                isSelected ? AppColors.brandPrimary : AppColors.borderSubtle,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color:
                isSelected ? AppColors.brandPrimary : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Vault ordering menu (newest / BPM / sales / earnings).
class _SortMenu extends StatelessWidget {
  final BeatsSortOrder sortOrder;
  final ValueChanged<BeatsSortOrder> onSelected;

  const _SortMenu({required this.sortOrder, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<BeatsSortOrder>(
      key: const Key('beat_sort_menu'),
      tooltip: 'Sort beats',
      color: AppColors.surfaceModal,
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final order in BeatsSortOrder.values)
          PopupMenuItem<BeatsSortOrder>(
            value: order,
            child: Text(order.label),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceSecondary,
          borderRadius: AppRadius.pillBorder,
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.swap_vert_rounded,
              size: 14,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.xxs),
            Text(
              'Sort: ${sortOrder.label}',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grid / list presentation toggle (REQ-BEAT-14).
class _ViewModeToggle extends StatelessWidget {
  final LibraryViewMode viewMode;
  final ValueChanged<LibraryViewMode> onChanged;

  const _ViewModeToggle({required this.viewMode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: AppRadius.inputBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ViewModeButton(
            buttonKey: const Key('beat_view_grid'),
            icon: Icons.grid_view_rounded,
            tooltip: 'Grid view',
            isActive: viewMode == LibraryViewMode.grid,
            onTap: () => onChanged(LibraryViewMode.grid),
          ),
          _ViewModeButton(
            buttonKey: const Key('beat_view_list'),
            icon: Icons.view_list_rounded,
            tooltip: 'List view',
            isActive: viewMode == LibraryViewMode.list,
            onTap: () => onChanged(LibraryViewMode.list),
          ),
        ],
      ),
    );
  }
}

class _ViewModeButton extends StatelessWidget {
  final Key buttonKey;
  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback onTap;

  const _ViewModeButton({
    required this.buttonKey,
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
        key: buttonKey,
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
            color:
                isActive ? AppColors.brandContrast : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Themed no-match state with a one-tap reset (Mission 3): shown whenever a
/// filter combination (search, status or genre) empties a non-empty vault.
class _NoBeatsMatch extends StatelessWidget {
  final String searchQuery;
  final VoidCallback onClearFilters;

  const _NoBeatsMatch({
    required this.searchQuery,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    final query = searchQuery.trim();

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.music_off_outlined,
            size: 32,
            color: AppColors.brandPrimary,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No beats found matching this filter',
            style: AppTypography.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (query.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text('Nothing matched "$query"', style: AppTypography.caption),
          ],
          const SizedBox(height: AppSpacing.md),
          TextButton(
            key: const Key('beat_clear_filters'),
            onPressed: onClearFilters,
            child: Text(
              'Reset Filters',
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.brandPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

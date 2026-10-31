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
import '../../../../core/theme/app_gradients.dart';
import '../../../library/presentation/providers/library_providers.dart';
import '../../../library/presentation/widgets/track_actions_sheet.dart';
import '../../../studio/presentation/providers/studio_form_provider.dart';
import '../../../studio/presentation/providers/melody_sketchpad_provider.dart';

/// Producer Beats Vault & Beatstore cockpit (`/library?tab=beats`).
///
/// Implements REQ-BEAT-14 to REQ-BEAT-22: responsive grid/list vault, status
/// filtering, authoring dialog, marketplace publish sheet, stems export and the
/// persistent player audition bridge.
/// Dual vault view mode: Producer's own beats vs Licensed beats purchased.
enum BeatsVaultMode {
  produced,
  licensed,
}

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
  BeatsVaultMode _vaultMode = BeatsVaultMode.produced;

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
          // Segmented Switcher (Produced vs Licensed)
          Container(
            padding: const EdgeInsets.all(AppSpacing.xxs),
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              borderRadius: AppRadius.pillBorder,
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    key: const Key('beats_vault_mode_produced'),
                    onTap: () => setState(() => _vaultMode = BeatsVaultMode.produced),
                    borderRadius: AppRadius.pillBorder,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _vaultMode == BeatsVaultMode.produced
                            ? AppColors.brandPrimary
                            : Colors.transparent,
                        borderRadius: AppRadius.pillBorder,
                      ),
                      child: Text(
                        '🎛️ My Produced Beats',
                        style: AppTypography.bodySmall.copyWith(
                          color: _vaultMode == BeatsVaultMode.produced
                              ? AppColors.brandContrast
                              : AppColors.textSecondary,
                          fontWeight: _vaultMode == BeatsVaultMode.produced
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    key: const Key('beats_vault_mode_licensed'),
                    onTap: () => setState(() => _vaultMode = BeatsVaultMode.licensed),
                    borderRadius: AppRadius.pillBorder,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _vaultMode == BeatsVaultMode.licensed
                            ? AppColors.brandPrimary
                            : Colors.transparent,
                        borderRadius: AppRadius.pillBorder,
                      ),
                      child: Text(
                        '🛍️ Licensed Beats',
                        style: AppTypography.bodySmall.copyWith(
                          color: _vaultMode == BeatsVaultMode.licensed
                              ? AppColors.brandContrast
                              : AppColors.textSecondary,
                          fontWeight: _vaultMode == BeatsVaultMode.licensed
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_vaultMode == BeatsVaultMode.produced) ...[
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
          ] else ...[
            Expanded(
              child: _buildLicensedBeats(
                isMobile: isMobile,
                isTablet: isTablet,
              ),
            ),
          ],
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

  Widget _buildLicensedBeats({
    required bool isMobile,
    required bool isTablet,
  }) {
    final allTracks = ref.watch(libraryTracksProvider);
    final licensedBeats = allTracks
        .where((t) =>
            !t.isDeleted &&
            (t.id.startsWith('market_') ||
                (t.isInstrumental &&
                    t.licenseType.trim().isNotEmpty && t.licenseType != 'Commercial')))
        .toList();

    if (licensedBeats.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.shopping_bag_outlined,
                size: 48,
                color: AppColors.brandPrimary,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'No licensed beats yet',
                style: AppTypography.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'Explore the Beats Marketplace to license top African instrumental beats.',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final columns = isMobile ? 2 : (isTablet ? 3 : 4);
    final aspectRatio = isMobile ? 0.72 : (isTablet ? 0.76 : 0.80);

    return GridView.builder(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: aspectRatio,
      ),
      itemCount: licensedBeats.length,
      itemBuilder: (context, index) {
        final track = licensedBeats[index];
        return _LicensedBeatCard(
          track: track,
          onUseInStudio: () {
            ref.read(studioFormProvider.notifier).setReferenceAudio(track.remoteAudioUrl);
            ref.read(studioFormProvider.notifier).setGenre(track.genre);
            ref.read(melodySketchpadProvider.notifier).initializeFromRemixDna(
                  genre: track.genre,
                );
            widget.onCreateRequested?.call();
            _showSnack('Loaded "${track.title}" into Studio as backing track 🎤');
          },
          onShowCertificate: () {
            showLibraryLicenseDialog(context, track);
          },
          onPlay: () {
            playLibraryTrack(ref, track);
          },
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


class _LicensedBeatCard extends ConsumerWidget {
  final LibraryTrack track;
  final VoidCallback? onUseInStudio;
  final VoidCallback? onShowCertificate;
  final VoidCallback? onPlay;

  const _LicensedBeatCard({
    required this.track,
    this.onUseInStudio,
    this.onShowCertificate,
    this.onPlay,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerStateProvider);
    final isPlaying = playerState.currentTrack?.id == track.id &&
        playerState.playbackStatus == PlaybackStatus.playing;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover art with genre gradient
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: AppGradients.forGenre(track.genre),
                borderRadius: AppRadius.inputBorder,
              ),
              child: Stack(
                children: [
                  Center(
                    child: IconButton(
                      iconSize: 36,
                      icon: Icon(
                        isPlaying
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_filled_rounded,
                        color: AppColors.brandContrast,
                      ),
                      onPressed: onPlay,
                    ),
                  ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCanvas.withValues(alpha: 0.8),
                        borderRadius: AppRadius.pillBorder,
                      ),
                      child: Text(
                        track.genre,
                        style: AppTypography.badge.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            track.title,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            track.creatorName,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.brandPrimary.withValues(alpha: 0.15),
              borderRadius: AppRadius.pillBorder,
            ),
            child: Text(
              track.licenseType,
              style: AppTypography.badge.copyWith(
                color: AppColors.brandPrimary,
                fontSize: 9.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  key: Key('licensed_beat_use_in_studio_${track.id}'),
                  onPressed: onUseInStudio,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: AppColors.brandContrast,
                    minimumSize: const Size(44, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.pillBorder,
                    ),
                  ),
                  icon: const Icon(Icons.mic_rounded, size: 14),
                  label: Text(
                    'Studio',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.brandContrast,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xxs),
              IconButton(
                key: Key('licensed_beat_cert_${track.id}'),
                icon: const Icon(Icons.verified_rounded, size: 18),
                color: AppColors.coinGold,
                tooltip: 'License Certificate',
                constraints: const BoxConstraints(
                  minWidth: 44,
                  minHeight: 44,
                ),
                onPressed: onShowCertificate,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

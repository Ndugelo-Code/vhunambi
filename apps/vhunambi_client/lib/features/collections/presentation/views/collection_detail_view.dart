import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/vhunambi_top_bar_kit.dart';
import '../../../../shared/models/track.dart';
import '../../../library/domain/models/library_models.dart';
import '../../../library/presentation/providers/library_providers.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../domain/models/collection_entity.dart';
import '../collection_format.dart';
import '../providers/collections_provider.dart';
import '../widgets/add_participant_dialog.dart';
import '../widgets/add_to_collection_sheet.dart';
import '../widgets/collection_artwork_placeholder.dart';
import '../widgets/collection_form_dialog.dart';
import '../widgets/collection_type_badge.dart';
import '../widgets/split_sheet_modal.dart';

/// Resolves collection track ids against the vault, substituting a
/// placeholder `Track` for ids that no longer exist (REQ-COL-22).
List<Track> resolveCollectionTracks(
  List<String> trackIds,
  List<LibraryTrack> vault,
) {
  final byId = {for (final track in vault) track.id: track.toTrack()};
  return <Track>[
    for (final id in trackIds)
      byId[id] ??
          Track(
            id: id,
            title: 'Track $id',
            creatorName: 'Vhunambi Artist',
            genre: 'Amapiano',
            duration: const Duration(minutes: 3, seconds: 30),
          ),
  ];
}

/// Deep-dive workspace for a single collection bundle.
///
/// Implements REQ-COL-20 through REQ-COL-27: hero header with unified artwork
/// and release metadata, reorderable track listing, Play All / Shuffle playback
/// wiring, the split-sheet participant ledger and the summary modal.
class CollectionDetailView extends ConsumerWidget {
  final CollectionEntity collection;

  const CollectionDetailView({super.key, required this.collection});

  void _showRenameDialog(
    BuildContext context,
    WidgetRef ref,
    CollectionEntity current,
  ) {
    showDialog<void>(
      context: context,
      builder: (_) => CollectionFormDialog(
        initial: current,
        onSubmitted: (title, type, genre, description, releaseDate) {
          ref.read(collectionsProvider.notifier).updateCollection(
                current.id,
                title: title,
                type: type,
                genre: genre,
                description: description,
                releaseDate: releaseDate,
              );
        },
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    CollectionEntity current,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceModal,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
        title: Text(
          'Delete Collection?',
          style: AppTypography.titleMedium.copyWith(color: AppColors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete "${current.title}"? '
          'Your saved tracks will remain in your Vault.',
          style: AppTypography.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Cancel',
              style: AppTypography.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            key: const Key('collection_detail_delete_confirm'),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ref.read(collectionsProvider.notifier).deleteCollection(current.id);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.textPrimary,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collections = ref.watch(collectionsProvider);
    CollectionEntity liveCollection = collection;
    for (final candidate in collections) {
      if (candidate.id == collection.id) liveCollection = candidate;
    }

    final resolvedTracks = resolveCollectionTracks(
      liveCollection.trackIds,
      ref.watch(libraryTracksProvider),
    );
    final totalSeconds = resolvedTracks.fold<int>(
      0,
      (sum, track) => sum + track.duration.inSeconds,
    );
    final durationLabel = formatCollectionDuration(totalSeconds);

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceCanvas,
        elevation: 0,
        leading: const VhunambiBackButton(),
        title: Text(
          liveCollection.title,
          style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          PopupMenuButton<String>(
            key: const Key('collection_detail_menu'),
            icon: const Icon(Icons.more_vert_rounded),
            color: AppColors.surfaceModal,
            onSelected: (action) {
              if (action == 'rename') {
                _showRenameDialog(context, ref, liveCollection);
              }
              if (action == 'delete') {
                _confirmDelete(context, ref, liveCollection);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem<String>(
                value: 'rename',
                child: Row(
                  children: [
                    Icon(Icons.edit_rounded, size: 16),
                    SizedBox(width: 8),
                    Text('Rename'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: AppColors.error,
                    ),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          120,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CollectionHeroHeader(
              collection: liveCollection,
              durationLabel: durationLabel,
            ),
            const SizedBox(height: AppSpacing.md),
            _CollectionPlaybackDeck(
              collection: liveCollection,
              tracks: resolvedTracks,
              durationLabel: durationLabel,
            ),
            const SizedBox(height: AppSpacing.lg),
            _CollectionTrackSection(
              collection: liveCollection,
              tracks: resolvedTracks,
            ),
            const SizedBox(height: AppSpacing.lg),
            _SplitParticipantsSection(collection: liveCollection),
          ],
        ),
      ),
    );
  }
}

/// Unified artwork + release metadata header (REQ-COL-21).
class _CollectionHeroHeader extends StatelessWidget {
  final CollectionEntity collection;
  final String durationLabel;

  const _CollectionHeroHeader({
    required this.collection,
    required this.durationLabel,
  });

  @override
  Widget build(BuildContext context) {
    final (minTracks, maxTracks) = collection.type.recommendedRange;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CollectionArtworkPlaceholder(size: 140, iconSize: 46, gap: 4),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  collection.title,
                  style: AppTypography.titleLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Row(
                  children: [
                    CollectionTypeBadge(type: collection.type),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        collection.genre.isEmpty
                            ? 'No genre set'
                            : collection.genre,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${collection.trackCountLabel} • $durationLabel',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.brandPrimary,
                  ),
                ),
                if (collection.releaseDate != null)
                  Text(
                    'Release: ${formatCollectionDate(collection.releaseDate!)}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                if (collection.description.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    collection.description,
                    style: AppTypography.bodyMuted,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (!collection.isWithinRecommendedRange) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '⚠ Recommended $minTracks–$maxTracks tracks '
                    'for a ${collection.typeLabel}.',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.coinGold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Play All / Shuffle / Split Sheet action deck (REQ-COL-21 / REQ-COL-27).
class _CollectionPlaybackDeck extends ConsumerWidget {
  final CollectionEntity collection;
  final List<Track> tracks;
  final String durationLabel;

  const _CollectionPlaybackDeck({
    required this.collection,
    required this.tracks,
    required this.durationLabel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `playerStateProvider.notifier` is the playback engine entry point —
    // the `playerNotifierProvider` named by REQ-COL-21 does not exist.
    void start(List<Track> queue) {
      if (queue.isEmpty) return;
      ref
          .read(playerStateProvider.notifier)
          .playTrack(queue.first, queue: queue);
    }

    final pill = RoundedRectangleBorder(borderRadius: AppRadius.pillBorder);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                key: const Key('collection_play_all'),
                onPressed: tracks.isEmpty ? null : () => start(tracks),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  foregroundColor: AppColors.brandContrast,
                  shape: pill,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                label: const Text(
                  'Play All',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('collection_shuffle'),
                onPressed: tracks.isEmpty
                    ? null
                    : () => start(List<Track>.of(tracks)..shuffle(Random())),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.borderSubtle),
                  shape: pill,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.shuffle_rounded, size: 20),
                label: const Text(
                  'Shuffle',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const Key('collection_split_sheet'),
            onPressed: () => SplitSheetModal.show(
              context,
              collection,
              durationLabel: durationLabel,
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.borderSubtle),
              shape: pill,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.description_outlined, size: 18),
            label: const Text(
              '📄 Split Sheet',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }
}

/// Reorderable track listing + `+ Add Track from Library` entry point
/// (REQ-COL-22 / REQ-COL-23).
class _CollectionTrackSection extends ConsumerWidget {
  final CollectionEntity collection;
  final List<Track> tracks;

  const _CollectionTrackSection({
    required this.collection,
    required this.tracks,
  });

  /// `onReorderItem` already reports the destination index adjusted for the
  /// removed item, so the move is a plain remove-then-insert.
  void _applyReorder(WidgetRef ref, int oldIndex, int newIndex) {
    final order = List<String>.of(collection.trackIds);
    if (oldIndex < 0 || oldIndex >= order.length) return;

    final moved = order.removeAt(oldIndex);
    final target = newIndex < 0
        ? 0
        : (newIndex > order.length ? order.length : newIndex);
    order.insert(target, moved);

    ref.read(collectionsProvider.notifier).reorderTracks(collection.id, order);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tracks',
          style: AppTypography.bodyLarge.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (tracks.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: AppRadius.cardBorder,
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Center(
              child: Text(
                'No songs added yet.\n'
                'Add tracks from your Vault to build this '
                '${collection.typeLabel}.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMuted,
              ),
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: tracks.length,
            onReorderItem: (oldIndex, newIndex) =>
                _applyReorder(ref, oldIndex, newIndex),
            itemBuilder: (context, index) => _CollectionTrackRow(
              key: ValueKey<String>('collection_track_${tracks[index].id}'),
              track: tracks[index],
              index: index,
              queue: tracks,
              onRemove: () => ref
                  .read(collectionsProvider.notifier)
                  .removeTrack(collection.id, tracks[index].id),
            ),
          ),
        const SizedBox(height: AppSpacing.xxs),
        TextButton.icon(
          key: const Key('collection_add_track'),
          onPressed: () => AddToCollectionSheet.show(
            context,
            collectionId: collection.id,
          ),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('+ Add Track from Library'),
        ),
      ],
    );
  }
}

/// Drag-handled track row used by the reorderable listing (REQ-COL-22).
class _CollectionTrackRow extends ConsumerWidget {
  final Track track;
  final int index;
  final List<Track> queue;
  final VoidCallback onRemove;

  const _CollectionTrackRow({
    super.key,
    required this.track,
    required this.index,
    required this.queue,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Material(
        color: AppColors.surfaceElevated,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.cardBorder,
          side: BorderSide(color: AppColors.borderSubtle),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 2,
          ),
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ReorderableDragStartListener(
                index: index,
                child: const Icon(
                  Icons.drag_handle_rounded,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '${index + 1}',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          title: Text(
            track.title,
            style: AppTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${track.creatorName} • ${track.genre}',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                track.formattedDuration,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.xxs),
              IconButton(
                key: Key('collection_remove_${track.id}'),
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
                tooltip: 'Remove from collection',
                onPressed: onRemove,
              ),
            ],
          ),
          onTap: () => ref
              .read(playerStateProvider.notifier)
              .playTrack(track, queue: queue),
        ),
      ),
    );
  }
}

/// Split-sheet participant ledger + total share indicator (REQ-COL-24).
class _SplitParticipantsSection extends ConsumerWidget {
  final CollectionEntity collection;

  const _SplitParticipantsSection({required this.collection});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final participants = collection.participants;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Split Sheet Participants',
          style: AppTypography.bodyLarge.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (participants.isEmpty)
          Text('No collaborators added yet.', style: AppTypography.bodyMuted)
        else
          for (final participant in participants)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Material(
                color: AppColors.surfaceElevated,
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.cardBorder,
                  side: BorderSide(color: AppColors.borderSubtle),
                ),
                child: ListTile(
                  key: Key('participant_${participant.name}'),
                  dense: true,
                  title: Text(
                    participant.name,
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    participant.role,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        participant.shareLabel,
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppColors.brandPrimary,
                        ),
                      ),
                      IconButton(
                        key: Key('participant_edit_${participant.name}'),
                        icon: const Icon(
                          Icons.edit_rounded,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        tooltip: 'Edit collaborator',
                        onPressed: () => AddParticipantDialog.show(
                          context,
                          collectionId: collection.id,
                          initial: participant,
                        ),
                      ),
                      IconButton(
                        key: Key('participant_remove_${participant.name}'),
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: AppColors.textTertiary,
                        ),
                        tooltip: 'Remove collaborator',
                        onPressed: () => ref
                            .read(collectionsProvider.notifier)
                            .removeParticipant(
                              collection.id,
                              participant.name,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'Total: ${collection.totalSharePercent.toStringAsFixed(0)}%',
          key: const Key('collection_total_share'),
          style: AppTypography.bodyLarge.copyWith(
            color: collection.isSplitBalanced
                ? AppColors.success
                : AppColors.error,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        TextButton.icon(
          key: const Key('collection_add_participant'),
          onPressed: () => AddParticipantDialog.show(
            context,
            collectionId: collection.id,
          ),
          icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
          label: const Text('+ Add Collaborator'),
        ),
      ],
    );
  }
}





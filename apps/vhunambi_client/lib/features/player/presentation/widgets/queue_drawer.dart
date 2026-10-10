import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../shared/models/track.dart';
import '../../domain/models/player_state.dart';
import '../providers/player_provider.dart';
import 'waveform_bars.dart';

/// Interactive playback queue drawer (T12.6 / REQ-PL-03 → REQ-PL-07).
///
/// Desktop viewports get a right-aligned elevated drawer; mobile gets an
/// expandable bottom sheet. Both surfaces share this widget.
class QueueDrawer extends ConsumerWidget {
  const QueueDrawer({super.key});

  static Future<void> show(BuildContext context) {
    if (!ResponsiveUtils.isDesktop(context)) {
      return showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.surfaceModal,
        isScrollControlled: true,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.modalBorder,
          side: BorderSide(color: AppColors.borderSubtle),
        ),
        builder: (_) => const QueueDrawer(),
      );
    }

    return showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => const Dialog(
        backgroundColor: Colors.transparent,
        alignment: Alignment.topRight,
        insetPadding: EdgeInsets.only(top: 70, right: 16),
        child: SizedBox(width: 380, child: QueueDrawer()),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerStateProvider);
    final notifier = ref.read(playerStateProvider.notifier);
    final upcoming = _upcomingTracks(player);
    final offset = player.currentIndex + 1;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceModal,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _QueueDrawerHeader(
            trackCount: player.queue.length,
            onClear: notifier.clearUpcomingQueue,
            onClose: () => Navigator.of(context).pop(),
          ),
          const Divider(height: 1),
          if (player.currentTrack != null) ...[
            _NowPlayingCard(state: player),
            const Divider(height: 1),
          ],
          Flexible(
            child: upcoming.isEmpty
                ? const _EmptyQueueState()
                : ReorderableListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    itemCount: upcoming.length,
                    buildDefaultDragHandles: false,
                    onReorderItem: (oldIndex, newIndex) {
                      // `onReorderItem` reports the post-removal ("adjusted")
                      // index, whereas `PlayerNotifier.reorderQueue` expects the
                      // raw pre-removal index that it adjusts internally, so
                      // translate back before applying the Up Next offset.
                      final rawIndex =
                          newIndex >= oldIndex ? newIndex + 1 : newIndex;
                      notifier.reorderQueue(
                        offset + oldIndex,
                        offset + rawIndex,
                      );
                    },
                    itemBuilder: (context, index) {
                      final track = upcoming[index];
                      return Padding(
                        key: ValueKey<String>('queue_row_${offset + index}'),
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: _QueueTrackTile(
                          track: track,
                          dragIndex: index,
                          onTap: () =>
                              notifier.playTrack(track, queue: player.queue),
                          onRemove: () =>
                              notifier.removeFromQueue(offset + index),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// Everything strictly after the active index — the "Up Next" slice.
  static List<Track> _upcomingTracks(PlayerState player) {
    if (player.queue.isEmpty) return const <Track>[];
    final start = player.currentIndex + 1;
    if (start <= 0 || start >= player.queue.length) return const <Track>[];
    return player.queue.sublist(start);
  }
}

/// Header: title, track counter pill, `Clear` action and dismissal.
class _QueueDrawerHeader extends StatelessWidget {
  const _QueueDrawerHeader({
    required this.trackCount,
    required this.onClear,
    required this.onClose,
  });

  final int trackCount;
  final VoidCallback onClear;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.xxs,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.queue_music_rounded,
            size: 20,
            color: AppColors.brandPrimary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text('Playback Queue', style: AppTypography.titleMedium),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              borderRadius: AppRadius.pillBorder,
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Text(
              trackCount == 1 ? '1 Track' : '$trackCount Tracks',
              style: AppTypography.badge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xxs),
          IconButton(
            key: const Key('queue_clear'),
            onPressed: onClear,
            visualDensity: VisualDensity.compact,
            tooltip: 'Clear Queue',
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            icon: const Icon(
              Icons.clear_all_rounded,
              size: 20,
              color: AppColors.brandPrimary,
            ),
          ),
          IconButton(
            key: const Key('queue_close'),
            tooltip: 'Close queue',
            visualDensity: VisualDensity.compact,
            onPressed: onClose,
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Rendered when nothing is queued after the active track.
class _EmptyQueueState extends StatelessWidget {
  const _EmptyQueueState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxl,
      ),
      child: Column(
        children: [
          const Icon(
            Icons.queue_music_rounded,
            size: 30,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Nothing queued up',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Add tracks from Explore and they land here.',
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Now Playing hero card with live equalizer bars (REQ-PL-04).
class _NowPlayingCard extends StatelessWidget {
  const _NowPlayingCard({required this.state});

  final PlayerState state;

  @override
  Widget build(BuildContext context) {
    final track = state.currentTrack!;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.brandPrimary.withAlpha(30),
              borderRadius: AppRadius.thumbBorder,
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: const Icon(
              Icons.piano_rounded,
              color: AppColors.brandPrimary,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Now Playing',
                  style: AppTypography.badge.copyWith(
                    color: AppColors.brandPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${track.creatorName} • ${track.genre}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              WaveformBars(
                isPlaying: state.isPlaying,
                barCount: 4,
                maxHeight: 16,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                '${state.formattedPosition} / ${state.formattedDuration}',
                style: AppTypography.caption,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One upcoming queue row: drag handle, artwork, metadata, duration, remove.
class _QueueTrackTile extends StatelessWidget {
  const _QueueTrackTile({
    required this.track,
    required this.dragIndex,
    required this.onTap,
    required this.onRemove,
  });

  final Track track;
  final int dragIndex;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceElevated,
      borderRadius: AppRadius.cardBorder,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardBorder,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xxs,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardBorder,
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: dragIndex,
                child: const Icon(
                  Icons.drag_handle_rounded,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(width: AppSpacing.xxs),
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.music_note_rounded,
                  size: 16,
                  color: AppColors.brandPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${track.creatorName} • ${track.genre}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xxs),
              Text(track.formattedDuration, style: AppTypography.caption),
              IconButton(
                key: Key('queue_remove_${track.id}'),
                tooltip: 'Remove from queue',
                visualDensity: VisualDensity.compact,
                onPressed: onRemove,
                icon: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

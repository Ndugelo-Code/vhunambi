import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/models/track.dart';
import '../../../library/presentation/providers/library_providers.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../domain/models/playlist_entity.dart';
import '../providers/playlists_provider.dart';

/// Detailed view for inspecting, playing and managing a user playlist.
///
/// Implements REQ-PV-04, REQ-PV-05, and REQ-PV-06 from Phase 12.1.
class PlaylistDetailView extends ConsumerWidget {
  final PlaylistEntity playlist;

  const PlaylistDetailView({super.key, required this.playlist});

  void _showRenameDialog(BuildContext context, WidgetRef ref, PlaylistEntity current) {
    final titleController = TextEditingController(text: current.title);
    final descController = TextEditingController(text: current.description);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceModal,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
        title: Text('Edit Playlist', style: AppTypography.titleMedium),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              autofocus: true,
              style: AppTypography.bodyLarge,
              decoration: const InputDecoration(labelText: 'Playlist Title'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: descController,
              style: AppTypography.bodyLarge,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
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
            onPressed: () {
              final title = titleController.text.trim();
              if (title.isEmpty) return;
              ref.read(playlistsProvider.notifier).updatePlaylist(
                    current.id,
                    title: title,
                    description: descController.text.trim(),
                  );
              Navigator.of(dialogContext).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: AppColors.brandContrast,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, PlaylistEntity current) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceModal,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
        title: Text(
          'Delete Playlist?',
          style: AppTypography.titleMedium.copyWith(color: AppColors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete "${current.title}"? Your tracks will remain in your vault.',
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
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ref.read(playlistsProvider.notifier).deletePlaylist(current.id);
              Navigator.of(context).pop(); // Back to vault
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

  List<Track> _resolveTracks(WidgetRef ref, List<String> trackIds) {
    final libraryTracks = ref.watch(libraryTracksProvider);
    final map = {for (final t in libraryTracks) t.id: t.toTrack()};

    final resolved = <Track>[];
    for (final id in trackIds) {
      if (map.containsKey(id)) {
        resolved.add(map[id]!);
      } else {
        // Fallback placeholder track if not found in library
        resolved.add(
          Track(
            id: id,
            title: 'Track $id',
            creatorName: 'Vhunambi Artist',
            genre: 'Amapiano',
            duration: const Duration(minutes: 3, seconds: 30),
          ),
        );
      }
    }
    return resolved;
  }

  String _formatTotalDuration(List<Track> tracks) {
    final totalSeconds = tracks.fold<int>(0, (sum, t) => sum + t.duration.inSeconds);
    final minutes = totalSeconds ~/ 60;
    if (minutes < 60) return '$minutes mins';
    final hours = minutes ~/ 60;
    final remainingMins = minutes % 60;
    return '$hours hr $remainingMins mins';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch current playlist from provider to reflect live edits
    final allPlaylists = ref.watch(playlistsProvider);
    final livePlaylist = allPlaylists.firstWhere(
      (p) => p.id == playlist.id,
      orElse: () => playlist,
    );

    final resolvedTracks = _resolveTracks(ref, livePlaylist.trackIds);
    final formattedTime = _formatTotalDuration(resolvedTracks);

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceCanvas,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          livePlaylist.title,
          style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            color: AppColors.surfaceModal,
            onSelected: (action) {
              if (action == 'rename') _showRenameDialog(context, ref, livePlaylist);
              if (action == 'delete') _confirmDelete(context, ref, livePlaylist);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'rename',
                child: Row(
                  children: [
                    Icon(Icons.edit_rounded, size: 16),
                    SizedBox(width: 8),
                    Text('Rename'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
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
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Header Card
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: AppRadius.cardBorder,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Artwork container
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        colors: [AppColors.surfaceSecondary, AppColors.surfaceElevated],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.queue_music_rounded,
                        size: 44,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),

                  // Metadata Stack
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          livePlaylist.title,
                          style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (livePlaylist.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            livePlaylist.description,
                            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          '${resolvedTracks.length} ${resolvedTracks.length == 1 ? 'song' : 'songs'} • $formattedTime',
                          style: AppTypography.caption.copyWith(color: AppColors.brandPrimary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Playback Actions Deck
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: resolvedTracks.isEmpty
                        ? null
                        : () {
                            ref
                                .read(playerStateProvider.notifier)
                                .playPlaylist(livePlaylist, resolvedTracks);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      foregroundColor: AppColors.brandContrast,
                      shape: const RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
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
                    onPressed: resolvedTracks.isEmpty
                        ? null
                        : () {
                            final shuffled = List<Track>.of(resolvedTracks)..shuffle(Random());
                            ref
                                .read(playerStateProvider.notifier)
                                .playPlaylist(livePlaylist, shuffled);
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.borderSubtle),
                      shape: const RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
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
            const SizedBox(height: AppSpacing.lg),

            // Track Listing Header
            Text(
              'Tracks',
              style: AppTypography.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),

            if (resolvedTracks.isEmpty)
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
                    'No songs in this playlist yet.\nAdd songs from your Library or Explore.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMuted,
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: resolvedTracks.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
                itemBuilder: (context, index) {
                  final track = resolvedTracks[index];
                  return Material(
                    color: AppColors.surfaceElevated,
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.cardBorder,
                      side: BorderSide(color: AppColors.borderSubtle),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 2),
                      leading: SizedBox(
                        width: 32,
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
                          ),
                        ),
                      ),
                      title: Text(
                        track.title,
                        style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${track.creatorName} • ${track.genre}',
                        style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            track.formattedDuration,
                            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textTertiary),
                            tooltip: 'Remove from playlist',
                            onPressed: () {
                              ref
                                  .read(playlistsProvider.notifier)
                                  .removeTrackFromPlaylist(livePlaylist.id, track.id);
                            },
                          ),
                        ],
                      ),
                      onTap: () {
                        // Play this single track within the playlist context
                        ref.read(playerStateProvider.notifier).playTrack(
                              track,
                              queue: resolvedTracks,
                            );
                      },
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/services/haptics_service.dart';
import '../../../../core/design_system/theme/vhunambi_theme_extension.dart';
import '../../../../core/design_system/tokens/design_enums.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../library/domain/models/library_models.dart';
import '../../../library/presentation/providers/library_providers.dart';
import '../../../offline/presentation/providers/offline_providers.dart';
import '../../../playlists/presentation/widgets/add_to_playlist_sheet.dart';
import '../../domain/models/player_state.dart';
import '../providers/player_provider.dart';
import 'queue_drawer.dart';
import 'waveform_bars.dart';

class DesktopTransportBar extends ConsumerWidget {
  final VoidCallback? onExpand;

  const DesktopTransportBar({
    super.key,
    this.onExpand,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerStateProvider);
    final track = playerState.currentTrack;

    if (!playerState.hasActiveTrack || track == null) {
      return const SizedBox.shrink();
    }

    final notifier = ref.read(playerStateProvider.notifier);
    final genre = _mapStringToGenre(track.genre);
    final extension = VhunambiThemeExtension.of(context);
    final accent = extension.genreAccent(genre);

    return Container(
      height: 72,
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: Column(
        children: [
          // 2px Top Interactive Progress Line
          GestureDetector(
            onHorizontalDragUpdate: (details) {
              final box = context.findRenderObject() as RenderBox?;
              if (box != null) {
                final ratio = (details.localPosition.dx / box.size.width).clamp(0.0, 1.0);
                notifier.seekByRatio(ratio);
              }
            },
            onTapDown: (details) {
              final box = context.findRenderObject() as RenderBox?;
              if (box != null) {
                final ratio = (details.localPosition.dx / box.size.width).clamp(0.0, 1.0);
                notifier.seekByRatio(ratio);
              }
            },
            child: LinearProgressIndicator(
              value: playerState.progressRatio,
              minHeight: 2.5,
              backgroundColor: AppColors.borderSubtle,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  // 1. Leading 48x48 Album Artwork
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: AppGradients.forGenre(track.genre),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const PhosphorIcon(AppIcons.piano, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),

                  // 2. Metadata Stack & Amplitude Bars
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${track.genre} • ${playerState.formattedPosition} / ${playerState.formattedDuration}',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),

                  // Real-time amplitude equalizer bars
                  WaveformBars(
                    isPlaying: playerState.isPlaying,
                    barCount: 10,
                    maxHeight: 20,
                  ),

                  const Spacer(),

                  // 3. Primary DAW Transport Controls
                  Semantics(
                    label: 'Skip previous track',
                    child: IconButton(
                      icon: const PhosphorIcon(AppIcons.skipBack, color: Colors.white, size: 24),
                      onPressed: notifier.skipPrevious,
                      tooltip: 'Previous Track',
                    ),
                  ),
                  const SizedBox(width: 6),

                  Semantics(
                    label: playerState.isPlaying ? 'Pause' : 'Play',
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          playerState.isPlaying
                              ? AppIcons.pause
                              : AppIcons.play,
                          color: _contrastTextColor(accent),
                          size: 24,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                        onPressed: notifier.togglePlayPause,
                        tooltip: playerState.isPlaying ? 'Pause' : 'Play',
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  Semantics(
                    label: 'Skip next track',
                    child: IconButton(
                      icon: const PhosphorIcon(AppIcons.skipForward, color: Colors.white, size: 24),
                      onPressed: notifier.skipNext,
                      tooltip: 'Next Track',
                    ),
                  ),
                  const SizedBox(width: 20),

                  // 4. Utility Strip
                  Semantics(
                    label: playerState.isShuffle ? 'Shuffle on' : 'Shuffle off',
                    child: IconButton(
                      key: const Key('transport_shuffle_button'),
                      icon: Icon(
                        AppIcons.shuffle,
                        color: playerState.isShuffle
                            ? accent
                            : AppColors.textSecondary,
                        size: 20,
                      ),
                      onPressed: () {
                        HapticsService().selectionClick();
                        notifier.toggleShuffle();
                      },
                      tooltip: 'Shuffle',
                    ),
                  ),

                  Semantics(
                    label: playerState.repeatMode == AudioRepeatMode.one
                        ? 'Repeat one'
                        : playerState.repeatMode == AudioRepeatMode.all
                            ? 'Repeat all'
                            : 'Repeat off',
                    child: IconButton(
                      icon: Icon(
                        playerState.repeatMode == AudioRepeatMode.one
                            ? AppIcons.repeat
                            : AppIcons.repeat,
                        color: playerState.repeatMode != AudioRepeatMode.off
                            ? accent
                            : AppColors.textTertiary,
                        size: 20,
                      ),
                      onPressed: notifier.cycleRepeatMode,
                      tooltip: 'Repeat Mode',
                    ),
                  ),

                  PopupMenuButton<double>(
                    tooltip: 'Playback Speed',
                    icon: const Icon(Icons.speed_rounded, color: AppColors.textSecondary, size: 20),
                    onSelected: notifier.setPlaybackSpeed,
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 0.75, child: Text('0.75x')),
                      const PopupMenuItem(value: 1.0, child: Text('1.0x (Normal)')),
                      const PopupMenuItem(value: 1.25, child: Text('1.25x')),
                      const PopupMenuItem(value: 1.5, child: Text('1.5x')),
                    ],
                  ),

                  Builder(
                    builder: (context) {
                      final libraryTrack = ref
                          .watch(libraryTracksProvider)
                          .cast<LibraryTrack?>()
                          .firstWhere(
                            (t) => t?.id == track.id,
                            orElse: () => null,
                          );
                      final isDownloading = ref.watch(downloadManagerProvider)[track.id]?.isActive ?? false;
                      final isOffline = libraryTrack?.isOfflineAvailable ?? false;

                      return IconButton(
                        key: const Key('transport_download_button'),
                        icon: isDownloading
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: accent,
                                ),
                              )
                            : Icon(
                                isOffline ? AppIcons.checkCircle : AppIcons.download,
                                color: isOffline ? accent : AppColors.textSecondary,
                                size: 20,
                              ),
                        onPressed: () {
                          if (libraryTrack != null) {
                            if (!isOffline && !isDownloading) {
                              ref.read(downloadManagerProvider.notifier).downloadTrack(libraryTrack);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Downloading "${track.title}" for offline playback...'),
                                  backgroundColor: AppColors.surfaceModal,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            } else if (isOffline) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('"${track.title}" is saved offline in your vault.'),
                                  backgroundColor: AppColors.surfaceModal,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Add "${track.title}" to library to enable offline download.'),
                                backgroundColor: AppColors.surfaceModal,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        tooltip: isOffline
                            ? 'Saved Offline'
                            : (isDownloading ? 'Downloading...' : 'Direct Audio Download'),
                      );
                    },
                  ),

                  Builder(
                    builder: (context) {
                      final isFavorite = ref
                          .watch(libraryTracksProvider)
                          .any((t) => t.id == track.id && t.isFavorite);
                      return IconButton(
                        key: const Key('transport_favorite_button'),
                        icon: Icon(
                          isFavorite
                              ? AppIcons.heart
                              : AppIcons.heartOutline,
                          color: isFavorite ? accent : AppColors.textSecondary,
                          size: 20,
                        ),
                        tooltip: isFavorite
                            ? 'Remove from favourites'
                            : 'Add to favourites',
                        onPressed: () {
                          HapticsService().selectionClick();
                          ref
                              .read(libraryTracksProvider.notifier)
                              .toggleFavorite(track.id);
                        },
                      );
                    },
                  ),

                  IconButton(
                    key: const Key('transport_add_to_playlist_button'),
                    icon: const Icon(Icons.playlist_add_rounded, color: AppColors.textSecondary, size: 22),
                    onPressed: () {
                      final track = ref.read(playerStateProvider).currentTrack;
                      if (track != null) {
                        AddToPlaylistSheet.show(context, track);
                      }
                    },
                    tooltip: 'Add to Playlist',
                  ),

                  IconButton(
                    key: const Key('transport_queue_button'),
                    icon: const Icon(Icons.queue_music_rounded, color: AppColors.textSecondary, size: 20),
                    onPressed: () => QueueDrawer.show(context),
                    tooltip: 'Queue Drawer',
                  ),

                  const SizedBox(width: 16),

                  // 5. Volume Slider & Window Controls
                  const PhosphorIcon(AppIcons.volumeHigh, color: AppColors.textSecondary, size: 20),
                  SizedBox(
                    width: 90,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        activeTrackColor: accent,
                        inactiveTrackColor: AppColors.borderSubtle,
                        thumbColor: accent,
                        overlayColor: accent.withAlpha(30),
                      ),
                      child: Slider(
                        value: playerState.volume,
                        onChanged: notifier.setVolume,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  IconButton(
                    icon: const PhosphorIcon(AppIcons.caretUp, color: AppColors.textSecondary, size: 20),
                    onPressed: onExpand,
                    tooltip: 'Expand Cockpit',
                  ),

                  IconButton(
                    icon: const PhosphorIcon(AppIcons.close, color: AppColors.textTertiary, size: 18),
                    onPressed: notifier.dismiss,
                    tooltip: 'Dismiss Player',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Maps a free-form [genre] string from [Track] to a
  /// [Genre] enum for the design system token registry.
  ///
  /// Unknown genres fall back to [Genre.amapiano].
  Genre _mapStringToGenre(String genre) {
    final normalized = genre.trim().toLowerCase();
    return switch (normalized) {
      'amapiano' => Genre.amapiano,
      'afro house' => Genre.afroHouse,
      'afrohouse' => Genre.afroHouse,
      'gqom' => Genre.gqom,
      'kwaito' => Genre.kwaito,
      'afro pop' => Genre.afroPop,
      'afropop' => Genre.afroPop,
      'afrobeats' => Genre.afroPop,
      'afro beats' => Genre.afroPop,
      'maskandi' => Genre.maskandi,
      'hip hop' => Genre.hipHop,
      'hiphop' => Genre.hipHop,
      'gospel' => Genre.gospel,
      _ => Genre.amapiano,
    };
  }

  Color _contrastTextColor(Color background) {
    return background.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }
}

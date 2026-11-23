import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/design_system/services/haptics_service.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/vhunambi_track_artwork.dart';
import '../../../library/domain/models/library_models.dart';
import '../../../library/presentation/providers/library_providers.dart';
import '../../../offline/presentation/providers/offline_providers.dart';
import '../../../playlists/presentation/widgets/add_to_playlist_sheet.dart';
import '../../domain/models/player_state.dart';
import '../providers/player_provider.dart';
import 'player_chromatic_resolver_mixin.dart';
import 'queue_drawer.dart';
import 'waveform_bars.dart';

class DesktopTransportBar extends ConsumerStatefulWidget {
  final VoidCallback? onExpand;

  const DesktopTransportBar({
    super.key,
    this.onExpand,
  });

  @override
  ConsumerState<DesktopTransportBar> createState() =>
      _DesktopTransportBarState();
}

class _DesktopTransportBarState extends ConsumerState<DesktopTransportBar>
    with PlayerChromaticPaletteMixin<DesktopTransportBar> {
  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerStateProvider);
    final track = playerState.currentTrack;

    if (!playerState.hasActiveTrack || track == null) {
      return const SizedBox.shrink();
    }

    final notifier = ref.read(playerStateProvider.notifier);
    final palette = resolvePlayerChromaticPalette(context, track);
    final accent = palette.accent;
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final borderSubtle = AppColors.borderSubtleOf(context);

    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevatedOf(context),
        border: Border(
          top: BorderSide(color: palette.glassBorderTint, width: 1),
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
              backgroundColor: borderSubtle,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  // 1. Leading 48x48 Album Artwork
                  VhunambiTrackArtwork(
                    key: const Key('desktop_transport_artwork'),
                    coverUrl: track.coverUrl,
                    genre: track.genre,
                    trackId: track.id,
                    width: 48,
                    height: 48,
                    borderRadius: BorderRadius.circular(8),
                    badgeIconSize: 22,
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
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${track.genre} • ${playerState.formattedPosition} / ${playerState.formattedDuration}',
                        style: AppTypography.bodySmall.copyWith(
                          color: textSecondary,
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
                      icon: PhosphorIcon(AppIcons.skipBack, color: textPrimary, size: 24),
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
                        icon: PhosphorIcon(
                          playerState.isPlaying
                              ? AppIcons.pause
                              : AppIcons.play,
                          color: palette.onAccent,
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
                      icon: PhosphorIcon(AppIcons.skipForward, color: textPrimary, size: 24),
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
                      icon: PhosphorIcon(
                        AppIcons.shuffle,
                        color: playerState.isShuffle ? accent : textSecondary,
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
                      icon: PhosphorIcon(
                        AppIcons.repeat,
                        color: playerState.repeatMode != AudioRepeatMode.off
                            ? accent
                            : textSecondary.withValues(alpha: 0.65),
                        size: 20,
                      ),
                      onPressed: notifier.cycleRepeatMode,
                      tooltip: 'Repeat Mode',
                    ),
                  ),

                  PopupMenuButton<double>(
                    tooltip: 'Playback Speed',
                    icon: PhosphorIcon(
                      PhosphorIconsRegular.gauge,
                      color: textSecondary,
                      size: 20,
                    ),
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
                            : PhosphorIcon(
                                isOffline ? AppIcons.checkCircle : AppIcons.download,
                                color: isOffline ? accent : textSecondary,
                                size: 20,
                              ),
                        onPressed: () {
                          final snackBg = AppColors.surfaceModalOf(context);
                          if (libraryTrack != null) {
                            if (!isOffline && !isDownloading) {
                              ref.read(downloadManagerProvider.notifier).downloadTrack(libraryTrack);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Downloading "${track.title}" for offline playback...'),
                                  backgroundColor: snackBg,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            } else if (isOffline) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('"${track.title}" is saved offline in your vault.'),
                                  backgroundColor: snackBg,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Add "${track.title}" to library to enable offline download.'),
                                backgroundColor: snackBg,
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
                        icon: PhosphorIcon(
                          isFavorite ? AppIcons.heart : AppIcons.heartOutline,
                          color: isFavorite ? accent : textSecondary,
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
                    icon: PhosphorIcon(
                      AppIcons.playlist,
                      color: textSecondary,
                      size: 20,
                    ),
                    onPressed: () {
                      final active = ref.read(playerStateProvider).currentTrack;
                      if (active != null) {
                        AddToPlaylistSheet.show(context, active);
                      }
                    },
                    tooltip: 'Add to Playlist',
                  ),

                  IconButton(
                    key: const Key('transport_queue_button'),
                    icon: PhosphorIcon(
                      PhosphorIconsRegular.queue,
                      color: textSecondary,
                      size: 20,
                    ),
                    onPressed: () => QueueDrawer.show(context),
                    tooltip: 'Queue Drawer',
                  ),

                  const SizedBox(width: 16),

                  // 5. Volume Slider & Window Controls
                  PhosphorIcon(AppIcons.volumeHigh, color: textSecondary, size: 20),
                  SizedBox(
                    width: 90,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        activeTrackColor: accent,
                        inactiveTrackColor: borderSubtle,
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
                    icon: PhosphorIcon(AppIcons.caretUp, color: textSecondary, size: 20),
                    onPressed: widget.onExpand,
                    tooltip: 'Expand Cockpit',
                  ),

                  IconButton(
                    icon: PhosphorIcon(
                      AppIcons.close,
                      color: textSecondary.withValues(alpha: 0.72),
                      size: 18,
                    ),
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
}

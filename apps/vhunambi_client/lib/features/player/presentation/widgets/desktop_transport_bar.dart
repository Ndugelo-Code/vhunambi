import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
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
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.brandPrimary),
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
                    child: const Icon(Icons.piano_rounded, color: Colors.white, size: 26),
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
                  IconButton(
                    icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 24),
                    onPressed: notifier.skipPrevious,
                    tooltip: 'Previous Track',
                  ),
                  const SizedBox(width: 6),

                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppColors.brandPrimary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        playerState.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: AppColors.brandContrast,
                        size: 24,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: notifier.togglePlayPause,
                      tooltip: playerState.isPlaying ? 'Pause' : 'Play',
                    ),
                  ),
                  const SizedBox(width: 6),

                  IconButton(
                    icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 24),
                    onPressed: notifier.skipNext,
                    tooltip: 'Next Track',
                  ),
                  const SizedBox(width: 20),

                  // 4. Utility Strip
                  IconButton(
                    icon: Icon(
                      playerState.repeatMode == AudioRepeatMode.one
                          ? Icons.repeat_one_rounded
                          : Icons.repeat_rounded,
                      color: playerState.repeatMode != AudioRepeatMode.off
                          ? AppColors.brandPrimary
                          : AppColors.textSecondary,
                      size: 20,
                    ),
                    onPressed: notifier.cycleRepeatMode,
                    tooltip: 'Repeat Mode',
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

                  IconButton(
                    icon: const Icon(Icons.download_rounded, color: AppColors.textSecondary, size: 20),
                    onPressed: () {},
                    tooltip: 'Direct Audio Download',
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
                  const Icon(Icons.volume_up_rounded, color: AppColors.textSecondary, size: 20),
                  SizedBox(
                    width: 90,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        activeTrackColor: AppColors.brandPrimary,
                        inactiveTrackColor: AppColors.borderSubtle,
                        thumbColor: AppColors.brandPrimary,
                        overlayColor: AppColors.brandPrimary.withAlpha(30),
                      ),
                      child: Slider(
                        value: playerState.volume,
                        onChanged: notifier.setVolume,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_up_rounded, color: AppColors.textSecondary, size: 20),
                    onPressed: onExpand,
                    tooltip: 'Expand Cockpit',
                  ),

                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textTertiary, size: 18),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/player_provider.dart';

class MobileMiniPlayer extends ConsumerWidget {
  final VoidCallback? onExpand;

  const MobileMiniPlayer({
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
      height: 60,
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: Column(
        children: [
          // 2px Top Progress Line
          LinearProgressIndicator(
            value: playerState.progressRatio,
            minHeight: 2,
            backgroundColor: AppColors.borderSubtle,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.brandPrimary),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  // Leading 40x40px Album Art
                  GestureDetector(
                    onTap: onExpand,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: AppGradients.forGenre(track.genre),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.piano_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Metadata Stack
                  Expanded(
                    child: GestureDetector(
                      onTap: onExpand,
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            style: AppTypography.bodyLarge.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${track.genre} • ${playerState.formattedPosition} / ${playerState.formattedDuration}',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Transport Controls
                  IconButton(
                    icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: notifier.skipPrevious,
                  ),
                  const SizedBox(width: 4),

                  // Play/Pause Orb
                  Container(
                    width: 36,
                    height: 36,
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
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: notifier.togglePlayPause,
                    ),
                  ),
                  const SizedBox(width: 4),

                  IconButton(
                    icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: notifier.skipNext,
                  ),
                  const SizedBox(width: 2),

                  // Dismiss Button
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textTertiary, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: notifier.dismiss,
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

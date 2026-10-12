import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/vhunambi_bottom_dock_kit.dart';
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

    // Floating frosted "island" pill with an ambient glow sampled from the
    // track's genre gradient. Dismiss is a swipe-down gesture (not a button),
    // freeing horizontal room so every transport control keeps a 44x44 target.
    return VhunambiFloatingTransportSurface(
      glow: AppGradients.forGenre(track.genre).colors.first,
      child: Column(
        children: [
          // 2px progress line (non-interactive on mobile; scrub in the cockpit).
          LinearProgressIndicator(
            value: playerState.progressRatio,
            minHeight: 2,
            backgroundColor: AppColors.borderSubtle,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.brandPrimary),
          ),

          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragEnd: (details) {
                // `primaryVelocity` is nullable on some drag terminations.
                final velocity = details.primaryVelocity ?? 0;
                if (velocity < -250) {
                  HapticFeedback.lightImpact();
                  notifier.skipNext();
                } else if (velocity > 250) {
                  HapticFeedback.lightImpact();
                  notifier.skipPrevious();
                }
              },
              // Vertical fling → drag up to expand the cockpit, drag down to
              // dismiss the player (replaces the old 28x28 dismiss button).
              // The gesture arena disambiguates by dominant axis, so this does
              // not conflict with the horizontal swipe-to-skip above.
              onVerticalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity < -250) {
                  HapticFeedback.lightImpact();
                  onExpand?.call();
                } else if (velocity > 250) {
                  HapticFeedback.lightImpact();
                  notifier.dismiss();
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    // Leading 44x44 album art (tap to expand).
                    GestureDetector(
                      onTap: onExpand,
                      child: Hero(
                        tag: 'now_playing_art_${track.id}',
                        child: Container(
                          width: 44,
                          height: 44,
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

                  // Skip previous — 44x44 hit target.
                  IconButton(
                    icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      notifier.skipPrevious();
                    },
                  ),

                  // Play/Pause orb — 44x44 hit target.
                  Container(
                    width: 44,
                    height: 44,
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
                        size: 22,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        notifier.togglePlayPause();
                      },
                    ),
                  ),
                  // Skip next — 44x44 hit target.
                  IconButton(
                    icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      notifier.skipNext();
                    },
                  ),
                ],
              ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

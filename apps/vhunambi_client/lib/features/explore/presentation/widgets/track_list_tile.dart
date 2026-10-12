import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/models/track.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../providers/explore_providers.dart';
import 'genre_glyph.dart';

/// Dense Rising track row with a live play/pause trigger
/// (REQ-EXP-05 / Blueprint 01 §3.5).
class TrackListTile extends ConsumerWidget {
  final Track track;

  const TrackListTile({super.key, required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `select` subscribes only to this track's playback flags.
    final isCurrent = ref.watch(
      playerStateProvider.select((s) => s.currentTrack?.id == track.id),
    );
    final isPlaying = ref.watch(
      playerStateProvider
          .select((s) => s.isPlaying && s.currentTrack?.id == track.id),
    );

    void handlePlayPause() {
      if (isCurrent) {
        ref.read(playerStateProvider.notifier).togglePlayPause();
        return;
      }
      playExploreTrack(ref, track);
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs + 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(
          color: isCurrent ? AppColors.brandPrimary : AppColors.borderSubtle,
        ),
      ),
      child: Row(
        children: [
          // 48x48 genre gradient thumbnail
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AppGradients.forGenre(track.genre),
              borderRadius: BorderRadius.circular(AppRadius.input),
            ),
            child: Icon(
              exploreGenreGlyph(track.genre),
              size: 20,
              color: AppColors.textPrimary.withAlpha(235),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${track.creatorName} • ${track.genre} • ${track.formattedDuration}',
                  style: AppTypography.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),

          // Social stat
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.favorite_rounded,
                size: 13,
                color: AppColors.error,
              ),
              const SizedBox(width: 3),
              Text('${track.likeCount}', style: AppTypography.caption),
            ],
          ),
          const SizedBox(width: AppSpacing.sm),

          // Live play/pause trigger
          InkWell(
            onTap: handlePlayPause,
            borderRadius: AppRadius.pillBorder,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              child: Center(
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: AppColors.brandPrimary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 20,
                    color: AppColors.brandContrast,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

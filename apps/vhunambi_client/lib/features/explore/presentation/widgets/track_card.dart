import 'package:cached_network_image/cached_network_image.dart';
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

/// Discovery track card: 1:1 genre-gradient artwork, status badge, metadata
/// and social footer (REQ-EXP-04 / Blueprint 01 §3.4).
class TrackCard extends ConsumerWidget {
  final Track track;

  const TrackCard({super.key, required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `select` keeps this tile off the 1-second playback-position rebuild path.
    final isCurrent = ref.watch(
      playerStateProvider.select((s) => s.currentTrack?.id == track.id),
    );
    final isPlaying = ref.watch(
      playerStateProvider
          .select((s) => s.isPlaying && s.currentTrack?.id == track.id),
    );

    return InkWell(
      onTap: () => playExploreTrack(ref, track),
      borderRadius: AppRadius.cardBorder,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xs),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: AppRadius.cardBorder,
          border: Border.all(
            color: isCurrent ? AppColors.brandPrimary : AppColors.borderSubtle,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1:1 artwork cover
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _artwork(),
                      if (track.isNew || track.trendingRank != null)
                        Positioned(
                          top: AppSpacing.xxs + 2,
                          left: AppSpacing.xxs + 2,
                          child: _statusBadge(),
                        ),
                      if (isCurrent)
                        Positioned(
                          bottom: AppSpacing.xxs + 2,
                          right: AppSpacing.xxs + 2,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              color: AppColors.brandPrimary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 16,
                              color: AppColors.brandContrast,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),

            // Title
            Text(
              track.title,
              style: AppTypography.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),

            // Metadata: [Genre] • [Language] • [Duration]
            Text(
              '${track.genre} • ${track.language} • ${track.formattedDuration}',
              style: AppTypography.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xxs),

            // Social footer
            Row(
              children: [
                const Icon(
                  Icons.favorite_rounded,
                  size: 12,
                  color: AppColors.error,
                ),
                const SizedBox(width: 3),
                Text('${track.likeCount}', style: AppTypography.caption),
                const SizedBox(width: AppSpacing.xs),
                const Icon(
                  Icons.play_arrow_rounded,
                  size: 13,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: 3),
                Text('${track.playCount}', style: AppTypography.caption),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    track.handleLabel,
                    style: AppTypography.caption,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _artwork() {
    final gradient = AppGradients.forGenre(track.genre);
    final coverUrl = track.coverUrl;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (coverUrl != null)
          CachedNetworkImage(
            imageUrl: coverUrl,
            fit: BoxFit.cover,
            placeholder: (_, _) => _gradientLayer(gradient),
            errorWidget: (_, _, _) => _gradientLayer(gradient),
          )
        else
          _gradientLayer(gradient),
        Center(
          child: Icon(
            exploreGenreGlyph(track.genre),
            size: 34,
            color: AppColors.textPrimary.withAlpha(235),
          ),
        ),
      ],
    );
  }

  Widget _gradientLayer(LinearGradient gradient) {
    return DecoratedBox(decoration: BoxDecoration(gradient: gradient));
  }

  /// Cyan `✨ NEW` pill for new drops, orange `#N` pill for trending ranks.
  Widget _statusBadge() {
    final rank = track.trendingRank;

    if (track.isNew) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.badgeCyanBg,
          borderRadius: AppRadius.pillBorder,
          border: Border.all(color: AppColors.badgeCyan),
        ),
        child: Text(
          '✨ NEW',
          style: AppTypography.badge.copyWith(color: AppColors.badgeCyan),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.brandPrimary,
        borderRadius: AppRadius.pillBorder,
      ),
      child: Text(
        '#$rank',
        style: AppTypography.badge.copyWith(
          color: AppColors.brandContrast,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

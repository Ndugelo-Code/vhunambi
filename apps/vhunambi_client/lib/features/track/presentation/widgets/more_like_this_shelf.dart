import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/track_detail_models.dart';

/// "More Like This" Recommendation Shelf (REQ-TRK-11).
class MoreLikeThisShelf extends StatelessWidget {
  final List<TrackDetailEntity> recommendations;
  final ValueChanged<TrackDetailEntity> onSelectTrack;
  final ValueChanged<TrackDetailEntity>? onAuditionTrack;

  const MoreLikeThisShelf({
    super.key,
    required this.recommendations,
    required this.onSelectTrack,
    this.onAuditionTrack,
  });

  @override
  Widget build(BuildContext context) {
    if (recommendations.isEmpty) return const SizedBox.shrink();

    final genre = recommendations.first.genre;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Text(
                'More Like This',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withAlpha(20),
                  borderRadius: AppRadius.pillBorder,
                  border: Border.all(color: AppColors.brandPrimary),
                ),
                child: Text(
                  genre,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandPrimary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Tracks List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recommendations.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = recommendations[index];
              return _buildTrackCard(item);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTrackCard(TrackDetailEntity item) {
    return InkWell(
      onTap: () => onSelectTrack(item),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            // Genre Cover Art Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: AppGradients.forGenre(item.genre),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(
                  Icons.music_note_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Metadata Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: AppTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.creatorName} • ${item.genre} • ${item.formattedDuration}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Likes Badge
            Row(
              children: [
                const Icon(
                  Icons.favorite_rounded,
                  size: 14,
                  color: AppColors.brandPrimary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${item.likesCount}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),

            // Play Trigger Button
            IconButton(
              iconSize: 26,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(
                Icons.play_circle_fill_rounded,
                color: AppColors.brandPrimary,
              ),
              onPressed: () => onAuditionTrack?.call(item),
            ),
          ],
        ),
      ),
    );
  }
}

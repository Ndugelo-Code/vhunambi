import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/design_system/tokens/app_icons.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_glass_surface.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_track_artwork.dart';
import 'package:vhunambi_client/features/track/domain/models/track_detail_models.dart';

/// "More Like This" Recommendation Shelf (`REQ-TRK-11`, `REQ-P70-SCUX-01`).
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
    final textPrimary = AppColors.textPrimaryOf(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'More Like This',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
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
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recommendations.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) =>
                _buildTrackCard(context, recommendations[index]),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackCard(BuildContext context, TrackDetailEntity item) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onSelectTrack(item),
        borderRadius: AppRadius.cardBorder,
        child: VhunambiGlassSurface(
          variant: VhunambiGlassVariant.card,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              VhunambiTrackArtwork(
                coverUrl: item.coverUrl,
                genre: item.genre,
                trackId: item.id,
                width: 44,
                height: 44,
                borderRadius: BorderRadius.circular(8),
                badgeIconSize: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.title,
                      style: AppTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.creatorName} · ${item.genre} · ${item.formattedDuration}',
                      style: AppTypography.caption.copyWith(
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: <Widget>[
                  const PhosphorIcon(
                    AppIcons.heart,
                    size: 14,
                    color: AppColors.brandPrimary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${item.likesCount}',
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.bold,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              IconButton(
                iconSize: 24,
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                icon: const PhosphorIcon(
                  PhosphorIconsFill.playCircle,
                  color: AppColors.brandPrimary,
                ),
                onPressed: () => onAuditionTrack?.call(item),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

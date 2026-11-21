import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_track_artwork.dart';

/// Unified collection cover backed by [VhunambiTrackArtwork] (`EP-P68-TRACK-ARTWORK`)
/// with a subtle disc corner badge and zero stock Material icons (`STD-UIUX-001`).
class CollectionArtworkPlaceholder extends StatelessWidget {
  final double size;
  final double iconSize;
  final double gap;
  final String genre;
  final String? seedId;

  const CollectionArtworkPlaceholder({
    super.key,
    this.size = 48,
    this.iconSize = 22,
    this.gap = 2,
    this.genre = 'Amapiano',
    this.seedId,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          VhunambiTrackArtwork(
            genre: genre,
            trackId: seedId ?? 'collection_cover',
            width: size,
            height: size,
            borderRadius: AppRadius.squircleBorder,
            badgeIconSize: iconSize,
          ),
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppColors.surfaceCanvasOf(
                  context,
                ).withValues(alpha: 0.78),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.brandPrimary.withValues(alpha: 0.65),
                  width: 0.8,
                ),
              ),
              child: PhosphorIcon(
                PhosphorIconsRegular.disc,
                size: (iconSize * 0.56).clamp(11.0, 18.0),
                color: AppColors.brandPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

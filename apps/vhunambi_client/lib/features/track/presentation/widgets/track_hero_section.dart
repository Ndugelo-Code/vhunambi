import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../domain/models/track_detail_models.dart';

/// 1:1 Cover Art Showcase, Metadata & Ownership Callout (REQ-TRK-02, REQ-TRK-03).
class TrackHeroSection extends StatelessWidget {
  final TrackDetailEntity track;
  final VoidCallback? onTapCreator;

  const TrackHeroSection({super.key, required this.track, this.onTapCreator});

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final artSize = isDesktop ? 280.0 : 220.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 16),

        // 1:1 Cover Art Card with Ambient Amber Glow
        Container(
          width: artSize,
          height: artSize,
          decoration: BoxDecoration(
            gradient: AppGradients.forGenre(track.genre),
            borderRadius: AppRadius.cardBorder,
            border: Border.all(color: AppColors.borderSubtle, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x3DF97316),
                blurRadius: 40,
                spreadRadius: -8,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            children: [
              Center(
                child: PhosphorIcon(
                  _getGenreIcon(track.genre),
                  color: Colors.white.withAlpha(220),
                  size: artSize * 0.35,
                ),
              ),
              Positioned(
                bottom: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(160),
                    borderRadius: AppRadius.pillBorder,
                    border: Border.all(color: Colors.white.withAlpha(40)),
                  ),
                  child: Text(
                    track.genre.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Track Title
        Text(
          track.title,
          style:
              (isDesktop
                      ? AppTypography.displayMedium
                      : AppTypography.titleLarge)
                  .copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),

        const SizedBox(height: 6),

        // Metadata Subtitle
        Text(
          track.metadataLabel,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 12),

        // License Pill Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.surfaceSecondary,
            borderRadius: AppRadius.pillBorder,
            border: Border.all(
              color: track.isCommercial
                  ? AppColors.brandPrimary.withAlpha(80)
                  : AppColors.borderSubtle,
            ),
          ),
          child: Text(
            track.licenseBadge,
            style: AppTypography.caption.copyWith(
              color: track.isCommercial
                  ? AppColors.brandPrimary
                  : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Royalty-Free Legal Notice Callout
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              TrackDetailEntity.ownershipNotice,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Creator Link Byline
        InkWell(
          onTap: onTapCreator,
          borderRadius: AppRadius.pillBorder,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary.withAlpha(30),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.brandPrimary),
                  ),
                  child: Center(
                    child: Text(
                      track.creatorName.isNotEmpty
                          ? track.creatorName[0].toUpperCase()
                          : 'C',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  track.creatorName,
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  track.creatorHandle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  IconData _getGenreIcon(String genre) {
    switch (genre.toLowerCase()) {
      case 'amapiano':
        return PhosphorIconsRegular.pianoKeys;
      case 'gqom':
        return PhosphorIconsRegular.disc;
      case 'maskandi':
        return PhosphorIconsRegular.guitar;
      case 'kwaito':
        return PhosphorIconsRegular.speakerHigh;
      case 'afro house':
        return PhosphorIconsRegular.waveSine;
      default:
        return PhosphorIconsRegular.headphones;
    }
  }
}

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/explore_models.dart';

/// Featured creator deck card: monogram avatar, artist name, track count and
/// `View profile ->` action link (REQ-EXP-06 / Blueprint 01 §3.6).
class CreatorCard extends StatelessWidget {
  final CreatorProfile creator;
  final VoidCallback? onViewProfile;

  const CreatorCard({super.key, required this.creator, this.onViewProfile});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          // Monogram avatar
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.brandPrimaryDark,
              shape: BoxShape.circle,
            ),
            child: Text(
              creator.initials,
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        creator.name,
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (creator.isVerified) ...[
                      const SizedBox(width: AppSpacing.xxs),
                      const Icon(
                        Icons.verified_rounded,
                        size: 14,
                        color: AppColors.badgeCyan,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  creator.trackCountLabel,
                  style: AppTypography.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xxs),
                InkWell(
                  onTap: onViewProfile,
                  child: Text(
                    'View profile ->',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.brandPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

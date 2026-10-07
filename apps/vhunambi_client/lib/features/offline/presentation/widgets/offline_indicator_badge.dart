import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';

/// Visual pill badge indicating that a track is stored locally on device
/// or that audio is playing from offline storage (REQ-OFF-08, REQ-OFF-10).
class OfflineIndicatorBadge extends StatelessWidget {
  final bool isCompact;
  final String label;

  const OfflineIndicatorBadge({
    super.key,
    this.isCompact = false,
    this.label = 'Offline',
  });

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.brandPrimary.withAlpha(35),
          borderRadius: AppRadius.pillBorder,
          border: Border.all(
            color: AppColors.brandPrimary.withAlpha(80),
            width: 0.5,
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.offline_pin_rounded,
              color: AppColors.brandPrimary,
              size: 11,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.brandPrimary.withAlpha(35),
        borderRadius: AppRadius.pillBorder,
        border: Border.all(
          color: AppColors.brandPrimary.withAlpha(80),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.offline_pin_rounded,
            color: AppColors.brandPrimary,
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.brandPrimary,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

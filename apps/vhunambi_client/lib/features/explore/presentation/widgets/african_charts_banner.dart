import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive_utils.dart';

/// African Music Charts hero banner (REQ-EXP-03 / Blueprint 01 §3.3).
class AfricanChartsBanner extends StatelessWidget {
  static const String headline = 'African Music Charts';
  static const String subtitle =
      'Top songs across All Africa, South Africa, West & East Africa';
  static const String ctaLabel = 'View ->';

  final VoidCallback? onViewCharts;

  const AfricanChartsBanner({super.key, this.onViewCharts});

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Icon(
              Icons.trending_up_rounded,
              size: 28,
              color: AppColors.textPrimary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                headline,
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          subtitle,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textPrimary.withAlpha(230),
          ),
        ),
      ],
    );

    final cta = ElevatedButton(
      onPressed: onViewCharts,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, 44),
        backgroundColor: AppColors.textPrimary,
        foregroundColor: AppColors.brandContrast,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.pillBorder,
        ),
      ),
      child: Text(
        ctaLabel,
        style: AppTypography.bodySmall.copyWith(
          color: AppColors.brandContrast,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    return Container(
      padding: EdgeInsets.all(
        isMobile ? AppSpacing.md : AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        gradient: AppGradients.africanChartsBanner,
        borderRadius: AppRadius.cardBorder,
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                titleBlock,
                const SizedBox(height: AppSpacing.sm),
                cta,
              ],
            )
          : Row(
              children: [
                Expanded(child: titleBlock),
                const SizedBox(width: AppSpacing.md),
                cta,
              ],
            ),
    );
  }
}

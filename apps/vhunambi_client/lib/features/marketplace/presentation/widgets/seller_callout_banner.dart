import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';

/// Seller monetization callout banner with an amber ambient glow
/// (REQ-MKT-02 / Blueprint 05 §2.2.3).
class SellerCalloutBanner extends StatelessWidget {
  static const String headline = 'Sell your beats';
  static const String description =
      'Create instrumental beats and list them here. Every time someone licenses your beat, credits go straight to your balance.';
  static const String ctaLabel = 'Go to Library';

  final VoidCallback? onGoToLibrary;

  const SellerCalloutBanner({super.key, this.onGoToLibrary});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 768;

    final emblem = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.brandPrimary.withAlpha(89)),
      ),
      child: const Icon(
        Icons.monetization_on_outlined,
        size: 20,
        color: AppColors.coinGold,
      ),
    );

    final cta = ElevatedButton(
      onPressed: onGoToLibrary,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.brandPrimary,
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

    final title = Text(
      headline,
      style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    final subtext = Text(
      description,
      style: AppTypography.bodySmall.copyWith(height: 1.4),
    );

    return Container(
      padding: EdgeInsets.all(isMobile ? AppSpacing.md : AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.brandPrimary.withAlpha(89)),
        boxShadow: const [
          BoxShadow(color: AppColors.amberGlow, blurRadius: 16),
        ],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    emblem,
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: title),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                subtext,
                const SizedBox(height: AppSpacing.sm),
                cta,
              ],
            )
          : Row(
              children: [
                emblem,
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      title,
                      const SizedBox(height: AppSpacing.xxs),
                      subtext,
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                cta,
              ],
            ),
    );
  }
}

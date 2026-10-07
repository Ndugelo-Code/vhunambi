import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../domain/models/landing_models.dart';
import '../providers/landing_providers.dart';

/// Pricing matrix with the billing cycle toggle and four subscription tiers
/// (REQ-MKT-11).
class PricingMatrixSection extends ConsumerWidget {
  static const String title = 'Start Free, Scale Up';
  static const String monthlyLabel = 'Monthly';
  static const String yearlyLabel = 'Yearly - Save 20%';

  const PricingMatrixSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cycle = ref.watch(pricingBillingCycleProvider);
    final tiers = ref.watch(pricingTiersProvider);
    final isMobile = ResponsiveUtils.isMobile(context);
    final isTablet = ResponsiveUtils.isTablet(context);
    final columns = isMobile ? 1 : (isTablet ? 2 : 4);

    final rows = <List<PricingTier>>[];
    for (var index = 0; index < tiers.length; index += columns) {
      final end =
          index + columns > tiers.length ? tiers.length : index + columns;
      rows.add(tiers.sublist(index, end));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppTypography.titleLarge),
          const SizedBox(height: AppSpacing.sm),

          // Billing cycle toggle
          Center(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.xxs),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: AppRadius.pillBorder,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CyclePill(
                    label: monthlyLabel,
                    isActive: cycle == BillingCycle.monthly,
                    onTap: () => ref
                        .read(pricingBillingCycleProvider.notifier)
                        .state = BillingCycle.monthly,
                  ),
                  _CyclePill(
                    label: yearlyLabel,
                    isActive: cycle == BillingCycle.yearly,
                    onTap: () => ref
                        .read(pricingBillingCycleProvider.notifier)
                        .state = BillingCycle.yearly,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          for (final row in rows) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < row.length; index++) ...[
                  Expanded(
                    child: _PricingCard(tier: row[index], cycle: cycle),
                  ),
                  if (index != row.length - 1)
                    const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _CyclePill extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _CyclePill({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.pillBorder,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: isActive ? AppColors.brandPrimary : Colors.transparent,
          borderRadius: AppRadius.pillBorder,
        ),
        child: Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            fontSize: 12,
            color:
                isActive ? AppColors.brandContrast : AppColors.textSecondary,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _PricingCard extends StatelessWidget {
  final PricingTier tier;
  final BillingCycle cycle;

  const _PricingCard({required this.tier, required this.cycle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(
          color: tier.isPopular
              ? AppColors.brandPrimary
              : AppColors.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tier.isPopular) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.brandPrimary,
                borderRadius: AppRadius.pillBorder,
              ),
              child: Text(
                'Most Popular',
                style: AppTypography.badge.copyWith(
                  color: AppColors.brandContrast,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          Text(
            tier.name,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${tier.priceFor(cycle)}',
                style: AppTypography.displayMedium.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: AppSpacing.xxs),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    cycle == BillingCycle.yearly ? '/mo billed yearly' : '/mo',
                    style: AppTypography.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            tier.songAllowance,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.brandPrimary,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            tier.audioQuality,
            style: AppTypography.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            tier.licenseScope,
            style: AppTypography.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final feature in tier.features)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxs + 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: AppSpacing.xxs + 2),
                  Expanded(
                    child: Text(
                      feature,
                      style: AppTypography.caption.copyWith(height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: tier.isPopular
                    ? AppColors.brandPrimary
                    : AppColors.surfaceSecondary,
                foregroundColor: tier.isPopular
                    ? AppColors.brandContrast
                    : AppColors.textPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.pillBorder,
                ),
              ),
              child: Text(
                tier.ctaLabel,
                style: AppTypography.bodySmall.copyWith(
                  color: tier.isPopular
                      ? AppColors.brandContrast
                      : AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

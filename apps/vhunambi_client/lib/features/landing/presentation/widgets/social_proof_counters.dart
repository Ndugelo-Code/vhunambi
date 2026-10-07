import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/landing_providers.dart';

/// 3-column social proof metric banner (REQ-MKT-08).
class SocialProofCounters extends ConsumerWidget {
  const SocialProofCounters({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(landingMetricsProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: AppRadius.cardBorder,
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var index = 0; index < metrics.length; index++) ...[
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      metrics[index].value,
                      style: AppTypography.displayMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      metrics[index].label,
                      textAlign: TextAlign.center,
                      style: AppTypography.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (index != metrics.length - 1)
                Container(
                  width: 1,
                  height: 40,
                  color: AppColors.borderSubtle,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/marketplace_providers.dart';

/// Universal marketplace empty state (REQ-MKT-05 / Blueprint 05 §2.2.7).
class MarketplaceEmptyState extends ConsumerWidget {
  static const String title = 'No beats found';
  static const String description =
      'Try a different genre, BPM range or price cap — or clear the filters to browse every listing.';

  const MarketplaceEmptyState({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.section,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: AppRadius.squircleBorder,
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  size: 22,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTypography.titleLarge.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                description,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMuted.copyWith(height: 1.5),
              ),
              const SizedBox(height: AppSpacing.xl),
              OutlinedButton.icon(
                onPressed: () => clearMarketplaceFilters(ref),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.borderSubtle),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.pillBorder,
                  ),
                ),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: Text(
                  'Clear filters',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

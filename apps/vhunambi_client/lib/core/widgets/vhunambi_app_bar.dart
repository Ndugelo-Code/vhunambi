import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_typography.dart';
import '../constants/app_assets.dart';
import 'vhunambi_top_bar_kit.dart';
import '../../features/notifications/presentation/widgets/notification_bell_button.dart';

/// Studio cockpit header (VH-006).
///
/// Replaces the text \"VHUNAMBI Studio\" title with a compact brand mark logo
/// asset, reducing horizontal space consumption to ~80-100px and providing
/// 60-80px of additional clearance for the credits chip.
///
/// Uses [AppAssets.compactMarkImage] with light/dark mode color variants,
/// falling back to an orange circle glyph when the SVG asset is unavailable.
class VhunambiAppBar extends ConsumerWidget {
  const VhunambiAppBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final barHeight = VhunambiTopBarMetrics.toolbarHeight(context);

    return VhunambiTopBarSurface(
      toolbarHeight: barHeight,
      child: SizedBox(
        height: barHeight,
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Brand Emblem — compact logo mark instead of text title
              // (VH-006). Falls back to orange circle glyph when SVG is
              // unavailable.
              AppAssets.compactMarkImage(size: 32),
              const SizedBox(width: AppSpacing.xs),

              const Spacer(),

              // Studio Route Title
              Text(
                'Studio',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),

              // Token Balance Badge (Centered vertically with lineHeight 1.1 so it never clips)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: AppRadius.pillBorder,
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.bolt_rounded,
                      size: 15,
                      color: AppColors.brandPrimary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '10 left',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),

              // Live Alert Centre (Phase 11)
              const NotificationBellButton(),
            ],
          ),
        ),
      ),
    );
  }
}
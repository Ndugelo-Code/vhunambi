import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimensions.dart';
import '../../../../../core/utils/responsive_utils.dart';
import '../../../../../shared/widgets/shimmer_skeleton.dart';

/// Animated skeleton screen matching profile layout using Vhunambi's standard ShimmerBox.
class ProfileSkeletonScreen extends StatelessWidget {
  const ProfileSkeletonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? AppSpacing.xl : AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner placeholder wrapped in RepaintBoundary for 60fps rendering
              const RepaintBoundary(
                child: ShimmerBox(
                  width: double.infinity,
                  height: 220,
                  borderRadius: AppRadius.cardBorder,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Profile header avatar & name
              Row(
                children: [
                  RepaintBoundary(
                    child: ShimmerBox(
                      width: 68,
                      height: 68,
                      borderRadius: BorderRadius.circular(34),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(width: 150, height: 24),
                        SizedBox(height: AppSpacing.xs),
                        ShimmerBox(width: 200, height: 14),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              // Action buttons skeleton (44px touch targets)
              const Row(
                children: [
                  ShimmerBox(
                    width: 100,
                    height: 44,
                    borderRadius: AppRadius.pillBorder,
                  ),
                  SizedBox(width: AppSpacing.sm),
                  ShimmerBox(
                    width: 80,
                    height: 44,
                    borderRadius: AppRadius.pillBorder,
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xl),

              // Stats grid skeleton
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: isDesktop ? 5 : 4,
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
                childAspectRatio: 1.2,
                children: List.generate(
                  isDesktop ? 5 : 4,
                  (_) => const RepaintBoundary(
                    child: ShimmerBox(
                      width: double.infinity,
                      height: double.infinity,
                      borderRadius: AppRadius.cardBorder,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // Track list skeletons using standard TrackTileSkeleton
              ...List.generate(
                3,
                (_) => const RepaintBoundary(
                  child: TrackTileSkeleton(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

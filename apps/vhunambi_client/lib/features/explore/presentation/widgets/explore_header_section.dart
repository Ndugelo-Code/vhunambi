import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/explore_models.dart';
import '../providers/explore_providers.dart';

/// Explore page header: title, subtitle, segmented discovery tabs and the
/// gamification streak chip (REQ-EXP-02 / Blueprint 01 §3.2).
class ExploreHeaderSection extends ConsumerWidget {
  static const String title = 'Explore';
  static const String subtitle =
      'Discover AI music from creators around the world';
  static const String streakLabel = '2 Streak';

  static const List<_ExploreTabSpec> _tabs = [
    _ExploreTabSpec(ExploreTab.discover, 'Discover'),
    _ExploreTabSpec(ExploreTab.forYou, 'For You'),
    _ExploreTabSpec(ExploreTab.following, 'Following'),
  ];

  const ExploreHeaderSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(exploreTabProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.displayLarge),
          const SizedBox(height: AppSpacing.xxs),
          Text(subtitle, style: AppTypography.bodyMuted),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final spec in _tabs) ...[
                        _TabPill(
                          label: spec.label,
                          isActive: spec.tab == activeTab,
                          onTap: () => ref
                              .read(exploreTabProvider.notifier)
                              .state = spec.tab,
                        ),
                        if (spec != _tabs.last)
                          const SizedBox(width: AppSpacing.xs),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const _StreakChip(),
            ],
          ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _TabPill({
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
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: isActive ? AppColors.brandPrimary : Colors.transparent,
          borderRadius: AppRadius.pillBorder,
        ),
        child: Text(
          label,
          style: AppTypography.bodyLarge.copyWith(
            color: isActive ? AppColors.brandContrast : AppColors.textSecondary,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _StreakChip extends StatelessWidget {
  const _StreakChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: AppRadius.pillBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            size: 15,
            color: AppColors.streakFire,
          ),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            ExploreHeaderSection.streakLabel,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExploreTabSpec {
  final ExploreTab tab;
  final String label;

  const _ExploreTabSpec(this.tab, this.label);
}

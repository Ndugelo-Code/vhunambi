import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/studio_form_provider.dart';
import 'song_dna_hover_pill.dart';

class ProgressTrackerWidget extends ConsumerWidget {
  final VoidCallback? onOpen3dTree;

  const ProgressTrackerWidget({super.key, this.onOpen3dTree});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completedSteps = ref.watch(studioCompletedStepsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const totalSteps = 9;
    final progress = (completedSteps / totalSteps).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceElevated.withValues(alpha: 0.55)
            : AppColors.lightSurfaceElevated.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          PhosphorIcon(
            completedSteps == totalSteps
                ? PhosphorIconsFill.checkCircle
                : PhosphorIconsRegular.slidersHorizontal,
            color: completedSteps == totalSteps
                ? AppColors.success
                : AppColors.brandPrimary,
            size: 15,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: isDark
                    ? AppColors.darkBorder
                    : AppColors.lightBorder,
                valueColor: AlwaysStoppedAnimation<Color>(
                  completedSteps == totalSteps
                      ? AppColors.success
                      : AppColors.brandPrimary,
                ),
                minHeight: 5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$completedSteps/$totalSteps',
            style: AppTypography.caption.copyWith(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 8),
          SongDnaHoverPill(onTap: onOpen3dTree),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';

/// Compact badge pill representing a top genre in the user's Creator DNA.
class DnaGenreBadge extends StatelessWidget {
  final String genre;
  final int rank;

  const DnaGenreBadge({
    super.key,
    required this.genre,
    this.rank = 1,
  });

  @override
  Widget build(BuildContext context) {
    final isPrimary = rank == 1;

    final backgroundColor = isPrimary
        ? AppColors.brandPrimary
        : AppColors.badgeCyanBg;

    final textColor = isPrimary
        ? AppColors.brandContrast
        : AppColors.badgeCyan;

    return Semantics(
      label: 'Rank $rank Genre: $genre',
      child: Container(
        key: Key('dna_genre_badge_${genre.toLowerCase().replaceAll(' ', '_')}'),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: AppRadius.pillBorder,
          border: isPrimary
              ? null
              : Border.all(color: AppColors.badgeCyan.withValues(alpha: 0.4), width: 1),
        ),
        child: Text(
          genre,
          style: AppTypography.caption.copyWith(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

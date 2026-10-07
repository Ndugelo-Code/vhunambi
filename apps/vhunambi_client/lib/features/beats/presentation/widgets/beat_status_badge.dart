import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/producer_beat_entity.dart';

/// Draft / Published / Archived pill badge (Blueprint 14 §3).
///
/// * `published` → green (`AppColors.success`)
/// * `draft` → amber (`AppColors.brandPrimary` on `AppColors.amberInset`)
/// * `archived` → muted grey (`AppColors.textTertiary`)
class BeatStatusBadge extends StatelessWidget {
  final BeatStatus status;
  final bool compact;

  const BeatStatusBadge({super.key, required this.status, this.compact = false});

  Color get _foreground => switch (status) {
        BeatStatus.published => AppColors.success,
        BeatStatus.draft => AppColors.brandPrimary,
        BeatStatus.archived => AppColors.textTertiary,
      };

  Color get _background => switch (status) {
        BeatStatus.published => AppColors.badgeCyanBg,
        BeatStatus.draft => AppColors.amberInset,
        BeatStatus.archived => AppColors.surfaceSecondary,
      };

  IconData get _icon => switch (status) {
        BeatStatus.published => Icons.public_rounded,
        BeatStatus.draft => Icons.edit_note_rounded,
        BeatStatus.archived => Icons.archive_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('beat_status_badge_${status.name}'),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.xs : AppSpacing.sm,
        vertical: compact ? 3 : AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: AppRadius.pillBorder,
        border: Border.all(color: _foreground),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: compact ? 10 : 12, color: _foreground),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            status.label,
            style: AppTypography.badge.copyWith(color: _foreground),
          ),
        ],
      ),
    );
  }
}

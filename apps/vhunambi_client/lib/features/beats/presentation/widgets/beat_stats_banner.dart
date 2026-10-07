import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/beats_provider.dart';

/// Producer analytics banner pinned to the top of the Beats Vault
/// (REQ-BEAT-14 / Blueprint 14 §2.1).
///
/// Surfaces the four cockpit metrics: total beats, live listings, completed
/// license sales and royalty credits earned.
class BeatStatsBanner extends StatelessWidget {
  final BeatsVaultStats stats;

  /// Condensed single-row variant used on mobile viewports.
  final bool compact;

  const BeatStatsBanner({
    super.key,
    required this.stats,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('beat_stats_banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.amberInset),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.equalizer_rounded,
                size: 15,
                color: AppColors.brandPrimary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'PRODUCER BEATS COCKPIT',
                style: AppTypography.badge.copyWith(
                  color: AppColors.brandPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: [
              _MetricTile(
                key: const Key('beat_stat_total'),
                icon: Icons.music_note_rounded,
                label: 'Total Beats',
                value: '${stats.totalBeats}',
                compact: compact,
              ),
              _MetricTile(
                key: const Key('beat_stat_published'),
                icon: Icons.storefront_rounded,
                label: 'Live on Market',
                value: '${stats.publishedCount}',
                compact: compact,
              ),
              _MetricTile(
                key: const Key('beat_stat_sales'),
                icon: Icons.handshake_rounded,
                label: 'Licenses Sold',
                value: '${stats.totalSalesCount}',
                compact: compact,
              ),
              _MetricTile(
                key: const Key('beat_stat_credits'),
                icon: Icons.bolt_rounded,
                label: 'Credits Earned',
                value: '${stats.totalCreditsEarned}',
                highlight: true,
                compact: compact,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool highlight;
  final bool compact;

  const _MetricTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = highlight ? AppColors.brandPrimary : AppColors.badgeCyan;

    return Container(
      width: compact ? 132 : 168,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: AppRadius.inputBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: AppTypography.titleMedium.copyWith(color: accent),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: AppTypography.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive_utils.dart';

/// Side-by-side cultural translation comparison: generic AI translation versus
/// Vhunambi indigenous synthesis (REQ-MKT-10).
class CulturalTranslationSpotlight extends StatelessWidget {
  static const String title = 'Cultural Translation Spotlight';
  static const String genericTitle = '❌ Generic AI Translation';
  static const String vhunambiTitle = '✅ Vhunambi Indigenous Synthesis';

  static const List<String> genericPoints = [
    'Literary word-for-word swaps that break proverbs',
    'Ignores regional meters, log-drum phrasing and call-and-response',
    'Robotic pronunciation that misplaces tonal stress',
  ];

  static const List<String> vhunambiPoints = [
    'Idiomatic Tshivenḓa, isiZulu and 25+ language modelling',
    'Rhythms tuned to Amapiano, Gqom and Maskandi structures',
    'Native vocal cadence with authentic tonal delivery',
  ];

  const CulturalTranslationSpotlight({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    final generic = _ComparisonCard(
      title: genericTitle,
      points: genericPoints,
      accent: AppColors.error,
      icon: Icons.cancel_outlined,
    );
    final vhunambi = _ComparisonCard(
      title: vhunambiTitle,
      points: vhunambiPoints,
      accent: AppColors.success,
      icon: Icons.check_circle_outline_rounded,
    );

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
          if (isMobile)
            Column(
              children: [
                generic,
                const SizedBox(height: AppSpacing.sm),
                vhunambi,
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: generic),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: vhunambi),
              ],
            ),
        ],
      ),
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  final String title;
  final List<String> points;
  final Color accent;
  final IconData icon;

  const _ComparisonCard({
    required this.title,
    required this.points,
    required this.accent,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: accent.withAlpha(140)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: AppTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.w700,
              color: accent,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final point in points)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 15, color: accent),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      point,
                      style: AppTypography.bodySmall.copyWith(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

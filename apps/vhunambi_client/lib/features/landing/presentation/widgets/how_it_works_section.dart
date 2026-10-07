import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive_utils.dart';

/// 3-step guided workflow section with the free-launch CTA (REQ-MKT-08).
class HowItWorksSection extends StatelessWidget {
  static const String title = 'How It Works';
  static const String ctaLabel = "✨ Try it now — It's free";

  static const List<_WorkflowStep> _steps = [
    _WorkflowStep(
      marker: '01 ✍️',
      title: 'Describe your song',
      description:
          'Share the theme, mood and story — in any language you speak.',
    ),
    _WorkflowStep(
      marker: '02 ⚡',
      title: 'AI generates it',
      description:
          'Authentic rhythms, vocals and lyrics rendered in under 60 seconds.',
    ),
    _WorkflowStep(
      marker: '03 🚀',
      title: 'Share with the world',
      description:
          'Download MP3s and stems, then share straight to WhatsApp.',
    ),
  ];

  final VoidCallback? onGetStarted;

  const HowItWorksSection({super.key, this.onGetStarted});

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    final cards = [
      for (final step in _steps) _WorkflowCard(step: step),
    ];

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
                for (var index = 0; index < cards.length; index++) ...[
                  cards[index],
                  if (index != cards.length - 1)
                    const SizedBox(height: AppSpacing.sm),
                ],
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < cards.length; index++) ...[
                  Expanded(child: cards[index]),
                  if (index != cards.length - 1)
                    const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: ElevatedButton(
              onPressed: onGetStarted,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: AppColors.brandContrast,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.pillBorder,
                ),
              ),
              child: Text(
                ctaLabel,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.brandContrast,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkflowCard extends StatelessWidget {
  final _WorkflowStep step;

  const _WorkflowCard({required this.step});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            step.marker,
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.brandPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            step.title,
            style: AppTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            step.description,
            style: AppTypography.bodySmall.copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _WorkflowStep {
  final String marker;
  final String title;
  final String description;

  const _WorkflowStep({
    required this.marker,
    required this.title,
    required this.description,
  });
}

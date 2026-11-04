import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../social/presentation/providers/stem_remix_provider.dart';

/// Top banner displayed in StudioView when an active reel remix context is attached (REQ-BANNER-01).
class ActiveRemixLineageBanner extends ConsumerWidget {
  const ActiveRemixLineageBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remixContext = ref.watch(stemRemixProvider);
    if (remixContext == null) return const SizedBox.shrink();

    return Container(
      key: const Key('active_remix_lineage_banner'),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.brandPrimary.withValues(alpha: 0.12),
        borderRadius: AppRadius.cardBorder,
        border: Border.all(
          color: AppColors.brandPrimary.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.brandPrimary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: PhosphorIcon(
                PhosphorIconsBold.gitFork,
                size: 16,
                color: AppColors.brandPrimary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Remixing @${remixContext.parentCreatorUsername}\'s "${remixContext.parentTrackTitle}"',
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  'Conditioned on Originator DNA · 70% / 30% Split Active',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.brandPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            key: const Key('studio_clear_remix_btn'),
            icon: const PhosphorIcon(PhosphorIconsBold.x, size: 16),
            color: AppColors.textSecondary,
            tooltip: 'Detach from Remix Lineage',
            onPressed: () {
              HapticFeedback.selectionClick();
              ref.read(stemRemixProvider.notifier).clearRemix();
            },
          ),
        ],
      ),
    );
  }
}


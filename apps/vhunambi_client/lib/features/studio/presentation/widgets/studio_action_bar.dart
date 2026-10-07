import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/studio_form_state.dart';
import '../providers/lyrics_review_provider.dart';
import '../providers/studio_form_provider.dart';
import 'lyrics_review_modal.dart';

class StudioActionBar extends ConsumerWidget {
  const StudioActionBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(studioFormProvider);
    final notifier = ref.read(studioFormProvider.notifier);

    final isAiLyrics =
        !state.isInstrumental && state.lyricsMode == LyricsMode.aiWrite;
    final ctaLabel = isAiLyrics ? 'Write Lyrics First' : 'Generate Song';
    final ctaIcon =
        isAiLyrics ? Icons.description_outlined : Icons.auto_awesome;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Public Visibility Toggle Card
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: AppRadius.cardBorder,
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.public_rounded,
                color: AppColors.brandPrimary,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Public',
                      style: AppTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Visible on Explore & your profile',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              Switch(
                value: state.isPublic,
                onChanged: notifier.togglePublic,
                activeThumbColor: AppColors.brandPrimary,
                activeTrackColor: AppColors.brandPrimary.withAlpha(80),
                inactiveThumbColor: AppColors.textSecondary,
                inactiveTrackColor: AppColors.surfaceSecondary,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Primary Action CTA Button
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: () => _handleGenerate(context, ref),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: AppColors.brandContrast,
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.pillBorder,
              ),
              elevation: 4,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(ctaIcon, size: 20, color: AppColors.brandContrast),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  ctaLabel,
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.brandContrast,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),

        // Process Description
        if (isAiLyrics)
          Center(
            child: Text(
              'AI writes the lyrics ➔ you review & edit ➔ then the beat is produced',
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        const SizedBox(height: AppSpacing.xs),

        // Commercial Licensing Terms
        Center(
          child: Text(
            'By generating, you agree to our Terms of Service. You own 100% of what you create on paid plans. See licensing ➔',
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  /// REQ-LYR-01/02 — AI lyrics mode pauses in `generatingLyrics`, drafts the
  /// stanzas, then opens the review cockpit before beat production.
  Future<void> _handleGenerate(BuildContext context, WidgetRef ref) async {
    final formNotifier = ref.read(studioFormProvider.notifier);
    final formState = ref.read(studioFormProvider);
    final reviewLyrics =
        !formState.isInstrumental && formState.lyricsMode == LyricsMode.aiWrite;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceModal,
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.brandPrimary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                reviewLyrics
                    ? 'Synthesizing lyrics in ${formState.language} for review...'
                    : 'Generating ${formState.genre} track...',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );

    if (!reviewLyrics) {
      formNotifier.triggerGeneration();
      return;
    }

    formNotifier.beginLyricsReview();
    await ref.read(lyricsReviewProvider.notifier).loadGeneratedLyrics(
          prompt: formState.prompt,
          genre: formState.genre,
          language: formState.language,
        );
    formNotifier.markReviewingLyrics();

    if (!context.mounted) return;
    await LyricsReviewModal.show(context);
  }
}

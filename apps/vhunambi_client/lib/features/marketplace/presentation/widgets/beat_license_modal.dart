import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../explore/presentation/widgets/genre_glyph.dart';
import '../../domain/models/marketplace_models.dart';
import '../providers/marketplace_providers.dart';

/// Commercial licensing confirmation sheet (REQ-MKT-04).
Future<void> showBeatLicenseModal(
  BuildContext context,
  BeatListingEntity beat,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surfaceModal,
    barrierColor: Colors.black54,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.modalBorder,
      side: BorderSide(color: AppColors.borderSubtle),
    ),
    builder: (_) => _BeatLicenseSheet(beat: beat),
  );
}

class _BeatLicenseSheet extends ConsumerWidget {
  final BeatListingEntity beat;

  const _BeatLicenseSheet({required this.beat});

  static const List<String> terms = [
    'Non-exclusive commercial sync rights',
    'Lossless WAV + 4-stem package delivery',
    'Unlimited streaming and monetised distribution',
    'Instant vault copy with a commercial licence record',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final credits = ref.watch(marketplaceCreditsProvider);
    final remainder = credits - beat.priceInCredits;
    final canAfford = remainder >= 0;

    void handleConfirm() {
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      final outcome = licenseBeat(ref, beat);

      if (outcome == BeatLicenseOutcome.licensed) {
        navigator.pop();
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: AppColors.surfaceModal,
            duration: const Duration(seconds: 3),
            content: Text(
              '"${beat.title}" licensed — saved to your Library vault.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        );
        return;
      }

      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceModal,
          duration: const Duration(seconds: 4),
          content: Text(
            'Not enough credits: ${beat.priceInCredits} required, $credits available.',
            style: AppTypography.bodySmall.copyWith(color: AppColors.error),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderActive,
                    borderRadius: AppRadius.pillBorder,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: AppGradients.forGenre(beat.genre),
                      borderRadius: AppRadius.squircleBorder,
                    ),
                    child: Icon(
                      exploreGenreGlyph(beat.genre),
                      size: 24,
                      color: AppColors.textPrimary.withAlpha(235),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          beat.title,
                          style: AppTypography.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          '${beat.producerHandle} • ${beat.bpmLabel} • ${beat.musicalKey}',
                          style: AppTypography.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          beat.priceLabel,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.brandPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${beat.licenseType} licence',
                style: AppTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xs),
              for (final term in terms)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxs + 2),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          term,
                          style: AppTypography.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                canAfford
                    ? 'Balance after licensing: $remainder credits'
                    : 'Insufficient balance — $credits credits available',
                style: AppTypography.caption.copyWith(
                  color: canAfford ? AppColors.textSecondary : AppColors.error,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.pillBorder,
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: handleConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandPrimary,
                        foregroundColor: AppColors.brandContrast,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.pillBorder,
                        ),
                      ),
                      child: Text(
                        'License for ${beat.priceInCredits} Credits',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.brandContrast,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

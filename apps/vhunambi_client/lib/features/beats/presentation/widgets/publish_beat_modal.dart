import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/producer_beat_entity.dart';

/// Marketplace publish confirmation sheet (REQ-BEAT-19 / Blueprint 14 §2.4).
///
/// Educates the producer on the 180s preview stream, the 100% royalty split
/// and the immediate public route before injecting the listing.
class PublishBeatModal extends StatelessWidget {
  final ProducerBeatEntity beat;

  /// Invoked by `Confirm & Publish` before the sheet closes itself.
  final VoidCallback onConfirm;

  const PublishBeatModal({
    super.key,
    required this.beat,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceModal,
        borderRadius: AppRadius.modalBorder,
      ),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderSubtle,
                borderRadius: AppRadius.pillBorder,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const Icon(
                Icons.rocket_launch_rounded,
                size: 18,
                color: AppColors.brandPrimary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Publish Beat to Live Marketplace',
                  style: AppTypography.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _PublishRow(
            label: 'Listing',
            value: '${beat.title} (${beat.genre} • ${beat.bpmLabel})',
          ),
          _PublishRow(label: 'Listing Price', value: beat.priceLabel),
          const _PublishRow(
            label: 'Producer Royalty',
            value: '100% of credits credited on each license',
          ),
          const _PublishRow(
            label: 'Preview Length',
            value: '180 second preview streaming enabled',
          ),
          const _PublishRow(
            label: 'Public Route',
            value: 'Visible immediately at /market',
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.amberInset,
              borderRadius: AppRadius.inputBorder,
              border: Border.all(color: AppColors.brandPrimary),
            ),
            child: Text(
              'You can switch back to Draft at any time — the listing is '
              'removed from the marketplace instantly.',
              style: AppTypography.caption.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('publish_keep_draft_button'),
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: BorderSide(color: AppColors.borderSubtle),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                  ),
                  child: const Text('Keep as Draft'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ElevatedButton(
                  key: const Key('publish_confirm_button'),
                  onPressed: () {
                    onConfirm();
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: AppColors.brandContrast,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                  ),
                  child: const Text('Confirm & Publish'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PublishRow extends StatelessWidget {
  final String label;
  final String value;

  const _PublishRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(label, style: AppTypography.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/recording_quality_profile.dart';

/// Visual card providing honest acoustic quality metrics and remediation feedback (REQ-SIG-INTAKE-05).
///
/// Strictly compliant with `STD-UIUX-001`: Phosphor icons only, dynamic [AppColors] getters,
/// and reactive theme palette support.
class InputQualityCard extends StatelessWidget {
  const InputQualityCard({
    super.key,
    required this.quality,
  });

  final RecordingQualityProfile quality;

  @override
  Widget build(BuildContext context) {
    final verdict = quality.verdict;
    final Color badgeColor;
    final PhosphorIconData badgeIcon;

    switch (verdict) {
      case RecordingQualityVerdict.good:
        badgeColor = AppColors.success;
        badgeIcon = PhosphorIconsRegular.checkCircle;
        break;
      case RecordingQualityVerdict.fair:
        badgeColor = AppColors.coinGold;
        badgeIcon = PhosphorIconsRegular.warning;
        break;
      case RecordingQualityVerdict.poor:
        badgeColor = AppColors.error;
        badgeIcon = PhosphorIconsRegular.warningCircle;
        break;
    }

    return Container(
      key: const Key('input_quality_card'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PhosphorIcon(badgeIcon, color: badgeColor, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Acoustic Health',
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: AppRadius.pillBorder,
                  border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  verdict.label,
                  style: AppTypography.caption.copyWith(
                    color: badgeColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            quality.remediationTip,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _metricChip(
                label: 'SNR',
                value: '${quality.snrDb.toStringAsFixed(0)} dB',
              ),
              const SizedBox(width: AppSpacing.sm),
              _metricChip(
                label: 'Clipping',
                value: '${quality.clippingPct.toStringAsFixed(1)}%',
              ),
              const SizedBox(width: AppSpacing.sm),
              _metricChip(
                label: 'Bandwidth',
                value: '${(quality.bandwidthHz / 1000).toStringAsFixed(1)} kHz',
              ),
              const SizedBox(width: AppSpacing.sm),
              _metricChip(
                label: 'Echo',
                value: quality.reverbEdtMs < 150 ? 'Low' : 'Med',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricChip({required String label, required String value}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.xs,
          horizontal: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceSecondary,
          borderRadius: AppRadius.inputBorder,
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: AppTypography.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

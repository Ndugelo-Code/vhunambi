import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/sound_signature_dna.dart';

/// Reusable badge for displaying the sovereign [SoundSignatureDna] identifier (REQ-SIG-UI-01).
///
/// Complies with `STD-UIUX-001`: Phosphor icons only, dynamic [AppColors] getters.
class VhuSigBadge extends StatelessWidget {
  const VhuSigBadge({
    super.key,
    required this.displayCode,
    this.source = SignatureSource.live,
    this.compact = false,
  });

  final String displayCode;
  final SignatureSource source;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isLive = source == SignatureSource.live;
    final sourceColor = isLive ? AppColors.success : AppColors.badgeCyan;
    final sourceLabel = isLive ? 'LIVE' : 'SAMPLE';

    return Container(
      key: const Key('vhu_sig_badge'),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.xs : AppSpacing.sm,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: AppRadius.pillBorder,
        border: Border.all(
          color: AppColors.borderActive.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PhosphorIcon(
            PhosphorIconsRegular.dna,
            size: compact ? 12 : 14,
            color: AppColors.coinGold,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            displayCode,
            style: AppTypography.bodySmall.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.6,
              color: AppColors.textPrimary,
              fontSize: compact ? 11 : 12,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: sourceColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: sourceColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              sourceLabel,
              style: AppTypography.badge.copyWith(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: sourceColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

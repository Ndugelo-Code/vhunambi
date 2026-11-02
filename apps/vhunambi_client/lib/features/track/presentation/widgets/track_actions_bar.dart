import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/track_detail_models.dart';

/// Primary Social Engagement Row: Like, Plays, Remix, Tip (REQ-TRK-04 / STD-UIUX-001).
class TrackActionsBar extends StatelessWidget {
  final TrackDetailEntity track;
  final VoidCallback onToggleLike;
  final VoidCallback? onRemix;
  final VoidCallback? onTip;

  const TrackActionsBar({
    super.key,
    required this.track,
    required this.onToggleLike,
    this.onRemix,
    this.onTip,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          // 1. Like Pill Button
          InkWell(
            onTap: onToggleLike,
            borderRadius: AppRadius.pillBorder,
            child: Container(
              constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: track.isLiked
                    ? AppColors.brandPrimary.withAlpha(25)
                    : AppColors.surfaceElevated,
                borderRadius: AppRadius.pillBorder,
                border: Border.all(
                  color: track.isLiked
                      ? AppColors.brandPrimary
                      : AppColors.borderSubtle,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PhosphorIcon(
                    track.isLiked ? PhosphorIconsFill.heart : PhosphorIconsRegular.heart,
                    color: track.isLiked ? AppColors.brandPrimary : Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${track.likesCount}',
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.bold,
                      color: track.isLiked ? AppColors.brandPrimary : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Play Count Pill
          Container(
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: AppRadius.pillBorder,
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PhosphorIcon(
                  PhosphorIconsRegular.play,
                  color: AppColors.textSecondary,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  '${track.playCount}',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // 3. Remix in Studio Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surfaceElevated,
              foregroundColor: AppColors.brandPrimary,
              side: BorderSide(color: AppColors.borderSubtle),
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.pillBorder,
              ),
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              elevation: 0,
            ),
            onPressed: onRemix,
            icon: const PhosphorIcon(PhosphorIconsRegular.shuffle, size: 18),
            label: const Text(
              'Remix',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),

          // 4. Tip Creator Button (Gold/Amber)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surfaceElevated,
              foregroundColor: AppColors.coinGold,
              side: BorderSide(color: AppColors.coinGold.withAlpha(90)),
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.pillBorder,
              ),
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              elevation: 0,
            ),
            onPressed: onTip,
            icon: const PhosphorIcon(PhosphorIconsRegular.coin, size: 18),
            label: const Text(
              'Tip',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

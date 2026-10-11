import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/published_clip.dart';

/// Lineage attribution pill shown on remixed clips (REQ-RMX-03).
///
/// Renders nothing for original (non-remix) clips.
class RemixAttributionBadge extends StatelessWidget {
  final PublishedClip clip;
  final VoidCallback? onTap;

  const RemixAttributionBadge({super.key, required this.clip, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (!clip.isRemix) return const SizedBox.shrink();

    final label = clip.remixAttribution ?? '🔁 Remix';
    return GestureDetector(
      key: const Key('remix_attribution_badge'),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.badgeCyanBg,
          borderRadius: AppRadius.pillBorder,
          border: Border.all(color: AppColors.badgeCyan.withAlpha(120)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.alt_route_rounded,
                size: 13, color: AppColors.badgeCyan),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: AppColors.badgeCyan,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

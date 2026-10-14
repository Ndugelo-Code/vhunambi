import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimensions.dart';
import '../../../../../core/theme/app_typography.dart';

/// Offline status banner displaying cache age and refresh action.
class OfflineIndicator extends StatelessWidget {
  final DateTime? cacheTimestamp;
  final VoidCallback? onRefresh;

  const OfflineIndicator({
    super.key,
    this.cacheTimestamp,
    this.onRefresh,
  });

  String _formatTimeAgo(DateTime? timestamp) {
    if (timestamp == null) return 'recently';
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final timeAgo = _formatTimeAgo(cacheTimestamp);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.brandPrimary.withAlpha(25),
        border: Border(
          bottom: BorderSide(
            color: AppColors.brandPrimary.withAlpha(70),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 18,
            color: AppColors.brandPrimary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Offline Mode · Showing cached profile ($timeAgo)',
              style: AppTypography.caption.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (onRefresh != null)
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
              child: IconButton(
                onPressed: onRefresh,
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 18,
                  color: AppColors.brandPrimary,
                ),
                tooltip: 'Refresh connection',
              ),
            ),
        ],
      ),
    );
  }
}

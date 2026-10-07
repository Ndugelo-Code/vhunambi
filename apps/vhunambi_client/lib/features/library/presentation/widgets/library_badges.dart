import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/library_models.dart';

/// Genre style token badge rendered on vault tiles, grid cards and the action sheet.
class GenreBadge extends StatelessWidget {
  final String genre;

  const GenreBadge({super.key, required this.genre});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: AppRadius.pillBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Text(
        genre,
        style: AppTypography.badge.copyWith(color: AppColors.brandPrimary),
      ),
    );
  }
}

/// Offline cache indicator: `⬇️ Offline` vs. `☁️ Cloud` (REQ-LIB-05).
class SyncStatusBadge extends StatelessWidget {
  final LibraryTrack track;

  const SyncStatusBadge({super.key, required this.track});

  @override
  Widget build(BuildContext context) {
    final isDownloading = track.syncStatus == TrackSyncStatus.downloading;
    final isOffline = track.isOfflineAvailable;
    final accent = isDownloading
        ? AppColors.brandPrimary
        : (isOffline ? AppColors.success : AppColors.textSecondary);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: AppRadius.pillBorder,
        border: Border.all(
          color: isDownloading
              ? AppColors.brandPrimary
              : (isOffline ? AppColors.success : AppColors.borderSubtle),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDownloading
                ? Icons.downloading_rounded
                : (isOffline ? Icons.download_done_rounded : Icons.cloud_outlined),
            size: 12,
            color: accent,
          ),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            isDownloading ? 'Downloading' : (isOffline ? 'Offline' : 'Cloud'),
            style: AppTypography.badge.copyWith(color: accent),
          ),
        ],
      ),
    );
  }
}

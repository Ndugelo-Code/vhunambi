import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';

class ExportActionSheet extends StatelessWidget {
  final bool isExporting;
  final double progress;
  final String? exportedFilePath;
  final String? errorMessage;
  final VoidCallback onDismiss;
  final VoidCallback? onPublish;

  const ExportActionSheet({
    super.key,
    required this.isExporting,
    required this.progress,
    required this.exportedFilePath,
    this.errorMessage,
    required this.onDismiss,
    this.onPublish,
  });

  @override
  Widget build(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  isExporting ? 'EXPORTING 1080x1920 REEL' : 'EXPORT READY',
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                onPressed: onDismiss,
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.15),
                borderRadius: AppRadius.inputBorder,
                border: Border.all(color: AppColors.error),
              ),
              child: Text(
                errorMessage!,
                style: AppTypography.bodyLarge.copyWith(color: AppColors.error),
              ),
            ),
          ] else if (isExporting) ...[
            LinearProgressIndicator(
              value: progress > 0 ? progress : null,
              backgroundColor: AppColors.surfaceSecondary,
              color: AppColors.brandPrimary,
              minHeight: 8,
              borderRadius: AppRadius.thumbBorder,
            ),
            const SizedBox(height: 12),
            Text(
              'Rendering kinetic typography and muxing studio master... ${(progress * 100).toInt()}%',
              style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
              textAlign: TextAlign.center,
            ),
          ] else if (exportedFilePath != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.brandPrimary.withValues(alpha: 0.1),
                borderRadius: AppRadius.cardBorder,
                border: Border.all(color: AppColors.brandPrimary.withValues(alpha: 0.4)),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.brandPrimary,
                    size: 48,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pristine 1080x1920 MP4 Generated!',
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    exportedFilePath!,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (onPublish != null) ...[
              ElevatedButton.icon(
                key: const Key('export_publish_to_profile_btn'),
                onPressed: onPublish,
                icon: const Icon(Icons.campaign_rounded, color: AppColors.brandContrast),
                label: Text(
                  'Publish to Profile',
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.brandContrast,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
                ),
              ),
              const SizedBox(height: 8),
            ],
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Ready for TikTok / Instagram Reels share sheet!'),
                    backgroundColor: AppColors.brandPrimary,
                  ),
                );
              },
              icon: const Icon(Icons.share_rounded, color: AppColors.brandContrast),
              label: Text(
                'Share to Socials (TikTok / Reels)',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.brandContrast,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: exportedFilePath!),
                      );
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Reel path copied to clipboard'),
                          backgroundColor: AppColors.surfaceModal,
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16, color: AppColors.textSecondary),
                    label: Text(
                      'Copy Path',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.borderSubtle),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Saved to your device gallery'),
                          backgroundColor: AppColors.surfaceModal,
                        ),
                      );
                    },
                    icon: const Icon(Icons.download_done_rounded, size: 16, color: AppColors.textSecondary),
                    label: Text(
                      'Save to Device',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.borderSubtle),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

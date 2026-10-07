import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';

/// Persistent PWA installation dock floating above the navigation dock
/// (REQ-MKT-06 / Blueprint 05 §2.2.8).
///
/// The dock is dismissed for the session by `Not now` and survives tab
/// switches because the root shell keeps its page in an `IndexedStack`.
class PwaInstallDock extends StatefulWidget {
  static const String title = 'Install VHUNAMBI';
  static const String description =
      'Add the studio to your home screen for full-screen sessions.';
  static const String dismissLabel = 'Not now';
  static const String howLabel = 'How?';

  const PwaInstallDock({super.key});

  @override
  State<PwaInstallDock> createState() => _PwaInstallDockState();
}

class _PwaInstallDockState extends State<PwaInstallDock> {
  bool _isVisible = true;

  void _showInstallGuidance() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceModal,
        duration: const Duration(seconds: 4),
        content: Text(
          'Open your browser menu and choose "Install app" or "Add to Home screen".',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceModal,
        borderRadius: AppRadius.squircleBorder,
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.surfaceSecondary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.download_rounded,
              size: 16,
              color: AppColors.brandPrimary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  PwaInstallDock.title,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  PwaInstallDock.description,
                  style: AppTypography.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xxs),
          TextButton(
            onPressed: () => setState(() => _isVisible = false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              PwaInstallDock.dismissLabel,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xxs),
          ElevatedButton(
            onPressed: _showInstallGuidance,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: AppColors.brandContrast,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 4,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.pillBorder,
              ),
            ),
            child: Text(
              PwaInstallDock.howLabel,
              style: AppTypography.caption.copyWith(
                color: AppColors.brandContrast,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/track_detail_models.dart';

/// Secondary Utility Toolbar: Download, Reel Export, Playlist, Radio, Lyrics, Variation, Comments, Embed (REQ-TRK-05 / STD-UIUX-001).
class UtilityToolDock extends StatelessWidget {
  final TrackDetailEntity track;
  final VoidCallback? onDownload;
  final VoidCallback? onExportVideo;
  final VoidCallback? onAddToPlaylist;
  final VoidCallback? onStartRadio;
  final VoidCallback? onJumpToLyrics;
  final VoidCallback? onVariation;
  final VoidCallback? onJumpToComments;
  final VoidCallback? onEmbed;

  const UtilityToolDock({
    super.key,
    required this.track,
    this.onDownload,
    this.onExportVideo,
    this.onAddToPlaylist,
    this.onStartRadio,
    this.onJumpToLyrics,
    this.onVariation,
    this.onJumpToComments,
    this.onEmbed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildToolChip(
            icon: PhosphorIconsRegular.downloadSimple,
            label: 'Download',
            onTap: onDownload,
          ),
          if (onExportVideo != null)
            _buildToolChip(
              icon: PhosphorIconsRegular.videoCamera,
              label: 'Export Reel',
              onTap: onExportVideo,
            ),
          _buildToolChip(
            icon: PhosphorIconsRegular.playlist,
            label: 'Playlist',
            onTap: onAddToPlaylist,
          ),
          _buildToolChip(
            icon: PhosphorIconsRegular.radio,
            label: 'Radio',
            onTap: onStartRadio,
          ),
          _buildToolChip(
            icon: PhosphorIconsRegular.textT,
            label: 'Lyrics',
            onTap: onJumpToLyrics,
          ),
          _buildToolChip(
            icon: PhosphorIconsRegular.gitFork,
            label: 'Variation',
            onTap: onVariation,
          ),
          _buildToolChip(
            icon: PhosphorIconsRegular.chatCircleDots,
            label: 'Comments',
            onTap: onJumpToComments,
          ),
          _buildToolChip(
            icon: PhosphorIconsRegular.code,
            label: 'Embed',
            onTap: onEmbed,
          ),
        ],
      ),
    );
  }

  Widget _buildToolChip({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.pillBorder,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: AppRadius.pillBorder,
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PhosphorIcon(icon, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

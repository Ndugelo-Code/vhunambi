import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/track_detail_models.dart';

/// Secondary Utility Toolbar: Download, Playlist, Radio, Lyrics, Variation, Comments, Embed (REQ-TRK-05).
class UtilityToolDock extends StatelessWidget {
  final TrackDetailEntity track;
  final VoidCallback? onDownload;
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
            icon: Icons.download_rounded,
            label: 'Download',
            onTap: onDownload,
          ),
          _buildToolChip(
            icon: Icons.playlist_add_rounded,
            label: 'Playlist',
            onTap: onAddToPlaylist,
          ),
          _buildToolChip(
            icon: Icons.radio_rounded,
            label: 'Radio',
            onTap: onStartRadio,
          ),
          _buildToolChip(
            icon: Icons.lyrics_rounded,
            label: 'Lyrics',
            onTap: onJumpToLyrics,
          ),
          _buildToolChip(
            icon: Icons.alt_route_rounded,
            label: 'Variation',
            onTap: onVariation,
          ),
          _buildToolChip(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Comments',
            onTap: onJumpToComments,
          ),
          _buildToolChip(
            icon: Icons.code_rounded,
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
          constraints: const BoxConstraints(minHeight: 44),
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
              Icon(icon, size: 16, color: AppColors.textSecondary),
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

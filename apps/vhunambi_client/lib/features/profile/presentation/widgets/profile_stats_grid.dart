import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../domain/models/profile_models.dart';

/// 5-Metric Statistical Grid conforming to STD-UIUX-001 (REQ-TRK-13).
///
/// Supports reactive overrides from [synchronizedAnalyticsProvider] to ensure
/// live platform stats update seamlessly across Library, Reels, and Beatstore.
class ProfileStatsGrid extends StatelessWidget {
  final ArtistProfileEntity profile;
  final int? songCountOverride;
  final int? likeCountOverride;
  final int? playCountOverride;

  const ProfileStatsGrid({
    super.key,
    required this.profile,
    this.songCountOverride,
    this.likeCountOverride,
    this.playCountOverride,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final effectiveSongs = songCountOverride ?? profile.songCount;
    final effectiveLikes = likeCountOverride ?? profile.likeCount;
    final effectivePlays = playCountOverride ?? profile.playCount;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 32 : 16,
        vertical: 18,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;
          final crossAxisCount = isNarrow ? 3 : 5;

          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildStatTile(
                icon: AppIcons.songs,
                value: '$effectiveSongs',
                label: 'Songs',
                color: AppColors.brandPrimary,
                width: isNarrow
                    ? (constraints.maxWidth - 20) / crossAxisCount
                    : 110,
              ),
              _buildStatTile(
                icon: AppIcons.heart,
                value: _formatNumber(effectiveLikes),
                label: 'Likes',
                color: Colors.redAccent,
                width: isNarrow
                    ? (constraints.maxWidth - 20) / crossAxisCount
                    : 110,
              ),
              _buildStatTile(
                icon: AppIcons.play,
                value: _formatNumber(effectivePlays),
                label: 'Plays',
                color: const Color(0xFF3B82F6),
                width: isNarrow
                    ? (constraints.maxWidth - 20) / crossAxisCount
                    : 110,
              ),
              _buildStatTile(
                icon: AppIcons.user,
                value: _formatNumber(profile.followerCount),
                label: 'Followers',
                color: AppColors.success,
                width: isNarrow
                    ? (constraints.maxWidth - 20) / crossAxisCount
                    : 110,
              ),
              _buildStatTile(
                icon: AppIcons.flame,
                value: '${profile.dayStreak}',
                label: 'Day Streak',
                color: AppColors.brandPrimary,
                width: isNarrow
                    ? (constraints.maxWidth - 20) / crossAxisCount
                    : 110,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatTile({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required double width,
  }) {
    return Semantics(
      label: '$value $label',
      readOnly: true,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: AppRadius.cardBorder,
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          children: [
            PhosphorIcon(icon, size: 20, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return '$count';
  }
}

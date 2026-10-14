import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../domain/models/profile_models.dart';

/// 5-Metric Statistical Grid (REQ-TRK-13).
class ProfileStatsGrid extends StatelessWidget {
  final ArtistProfileEntity profile;

  const ProfileStatsGrid({
    super.key,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);

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
                icon: Icons.music_note_rounded,
                value: '${profile.songCount}',
                label: 'Songs',
                color: AppColors.brandPrimary,
                width: isNarrow ? (constraints.maxWidth - 20) / crossAxisCount : 110,
              ),
              _buildStatTile(
                icon: Icons.favorite_rounded,
                value: _formatNumber(profile.likeCount),
                label: 'Likes',
                color: Colors.redAccent,
                width: isNarrow ? (constraints.maxWidth - 20) / crossAxisCount : 110,
              ),
              _buildStatTile(
                icon: Icons.play_arrow_rounded,
                value: _formatNumber(profile.playCount),
                label: 'Plays',
                color: const Color(0xFF3B82F6),
                width: isNarrow ? (constraints.maxWidth - 20) / crossAxisCount : 110,
              ),
              _buildStatTile(
                icon: Icons.people_outline_rounded,
                value: _formatNumber(profile.followerCount),
                label: 'Followers',
                color: const Color(0xFF10B981),
                width: isNarrow ? (constraints.maxWidth - 20) / crossAxisCount : 110,
              ),
              _buildStatTile(
                icon: Icons.local_fire_department_rounded,
                value: '🔥 ${profile.dayStreak}',
                label: 'Day Streak',
                color: AppColors.brandPrimary,
                width: isNarrow ? (constraints.maxWidth - 20) / crossAxisCount : 110,
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
          Icon(icon, size: 20, color: color),
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
            style: const TextStyle(
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

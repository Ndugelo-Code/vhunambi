import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../profile/presentation/views/artist_profile_view.dart';
import '../../../profile/presentation/views/owner_profile_view.dart';
import '../../domain/models/explore_models.dart';
import '../providers/explore_providers.dart';
import 'track_list_tile.dart';

/// Facebook-style compact Discovery Drawer (REQ-EXP-DRAWER-01 / 02).
/// Organizes African Music Charts, 12-Genre Radio, Rising MP3s, Listening Streak,
/// and Top Creators into a clean, accessible bottom sheet.
class ExploreDiscoveryDrawerSheet extends ConsumerWidget {
  const ExploreDiscoveryDrawerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceModal,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const ExploreDiscoveryDrawerSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      key: const Key('explore_discovery_drawer'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drawer Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.explore_rounded,
                      color: AppColors.brandPrimary,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Discovery Hub',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  width: 44,
                  height: 44,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // 0. My Creator Studio Shortcut (Phase 30 REQ-PROF-NAV-02)
            _buildDrawerTile(
              context: context,
              key: const Key('drawer_item_creator_studio'),
              icon: Icons.person_rounded,
              iconColor: AppColors.brandPrimary,
              title: 'My Creator Studio',
              subtitle: 'Catalog, beatstore cockpit, sound DNA & royalties',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const OwnerProfileView()),
                );
              },
            ),
            const SizedBox(height: AppSpacing.xs),

            // 5 Structured Shortcut Tiles
            _buildDrawerTile(
              context: context,
              key: const Key('drawer_item_charts'),
              icon: Icons.leaderboard_rounded,
              iconColor: AppColors.brandPrimary,
              title: 'African Music Charts',
              subtitle: 'Top 50 regional Amapiano, Gqom & Afrobeat hits',
              onTap: () {
                Navigator.of(context).pop();
                _showChartsSheet(context);
              },
            ),
            const SizedBox(height: AppSpacing.xs),
            _buildDrawerTile(
              context: context,
              key: const Key('drawer_item_radio'),
              icon: Icons.radio_rounded,
              iconColor: AppColors.badgeCyan,
              title: '12-Genre Radio Stations',
              subtitle: 'Continuous curated audio streams across Africa',
              onTap: () {
                Navigator.of(context).pop();
                _showGenreRadioSheet(context, ref);
              },
            ),
            const SizedBox(height: AppSpacing.xs),
            _buildDrawerTile(
              context: context,
              key: const Key('drawer_item_rising'),
              icon: Icons.rocket_launch_rounded,
              iconColor: AppColors.brandPrimary,
              title: 'Rising MP3 Tracks',
              subtitle: 'Fastest growing independent releases this week',
              onTap: () {
                Navigator.of(context).pop();
                _showRisingTracksSheet(context, ref);
              },
            ),
            const SizedBox(height: AppSpacing.xs),
            _buildDrawerTile(
              context: context,
              key: const Key('drawer_item_streak'),
              icon: Icons.local_fire_department_rounded,
              iconColor: AppColors.brandPrimary,
              title: 'Listening Streak & Taste DNA',
              subtitle: '3-day listening streak • Private School Amapiano archetype',
              onTap: () {
                Navigator.of(context).pop();
                _showStreakDnaSheet(context);
              },
            ),
            const SizedBox(height: AppSpacing.xs),
            _buildDrawerTile(
              context: context,
              key: const Key('drawer_item_creators'),
              icon: Icons.verified_user_rounded,
              iconColor: AppColors.coinGold,
              title: 'Top Creators Directory',
              subtitle: 'Explore verified African producers & vocalists',
              onTap: () {
                Navigator.of(context).pop();
                _showCreatorsSheet(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerTile({
    required BuildContext context,
    required Key key,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: AppRadius.cardBorder,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: AppRadius.cardBorder,
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showChartsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceModal,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📈 African Music Charts',
              style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Leaderboards update daily based on plays, likes, and studio remixes across southern and west Africa.',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            ListTile(
              leading: const Text('01', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.brandPrimary)),
              title: const Text('Ndo Mufuna Matibe'),
              subtitle: const Text('Makhadzi • 113 BPM • Amapiano'),
              trailing: const Icon(Icons.play_circle_filled_rounded, color: AppColors.brandPrimary),
            ),
            ListTile(
              leading: const Text('02', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.brandPrimary)),
              title: const Text('Grateful in the Light'),
              subtitle: const Text('Sigwa & Inaf • 112 BPM • Amapiano'),
              trailing: const Icon(Icons.play_circle_filled_rounded, color: AppColors.brandPrimary),
            ),
          ],
        ),
      ),
    );
  }

  void _showGenreRadioSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceModal,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📻 12-Genre Radio Stations',
              style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Tap a genre to start continuous station playback.',
              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final genre in exploreGenreCatalog)
                  ActionChip(
                    label: Text(genre),
                    backgroundColor: AppColors.surfaceElevated,
                    onPressed: () {
                      Navigator.of(context).pop();
                      playExploreGenreRadio(ref, genre);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRisingTracksSheet(BuildContext context, WidgetRef ref) {
    final rising = ref.read(risingTracksProvider);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceModal,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: rising.length,
        itemBuilder: (context, i) => TrackListTile(
          track: rising[i],
        ),
      ),
    );
  }

  void _showStreakDnaSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceModal,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_fire_department_rounded, color: AppColors.brandPrimary, size: 48),
            const SizedBox(height: AppSpacing.sm),
            Text('3-Day Listening Streak!', style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Your musical DNA leans 65% Private School Amapiano, 20% Gqom, and 15% Maskandi.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreatorsSheet(BuildContext context, WidgetRef ref) {
    final creators = ref.read(exploreCreatorsProvider);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceModal,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: creators.length,
        itemBuilder: (context, i) {
          final c = creators[i];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.brandPrimary,
              child: Text(c.initials, style: const TextStyle(color: AppColors.brandContrast)),
            ),
            title: Text(c.name),
            subtitle: Text('${c.handle} • ${c.primaryGenreLabel}'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ArtistProfileView(artistId: c.id)),
              );
            },
          );
        },
      ),
    );
  }
}


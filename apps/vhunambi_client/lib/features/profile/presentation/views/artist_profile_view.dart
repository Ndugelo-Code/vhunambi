import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../shared/models/track.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../track/presentation/views/track_detail_view.dart';
import '../providers/profile_providers.dart';
import '../widgets/profile_banner_header.dart';
import '../widgets/profile_stats_grid.dart';
import '../widgets/top_supporters_leaderboard.dart';

/// Public Artist Profile View (`/profile/:id`) (REQ-TRK-12 … REQ-TRK-14).
class ArtistProfileView extends ConsumerWidget {
  final String artistId;

  const ArtistProfileView({
    super.key,
    required this.artistId,
  });

  void _showTipDialog(BuildContext context, WidgetRef ref, String artistName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceModal,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.monetization_on_rounded,
                    color: AppColors.coinGold,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Tip $artistName',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Show direct appreciation. 100% of credits support this creator.',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [10, 25, 50, 100].map((credits) {
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surfaceElevated,
                      foregroundColor: AppColors.coinGold,
                      side: BorderSide(color: AppColors.coinGold.withAlpha(90)),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.pillBorder,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () {
                      ref
                          .read(artistProfileFamilyProvider(artistId).notifier)
                          .tipArtist(credits);
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Tipped $credits credits to $artistName! 🪙'),
                          backgroundColor: AppColors.surfaceElevated,
                        ),
                      );
                    },
                    child: Text(
                      '⚡ $credits',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final profile = ref.watch(artistProfileFamilyProvider(artistId));

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.music_note_rounded,
              color: AppColors.brandPrimary,
              size: 20,
            ),
            const SizedBox(width: 6),
            Text(
              'VHUNAMBI',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Colors.white),
            onPressed: () {
              final url = 'https://vhunambi.com/profile/${profile.username}';
              Clipboard.setData(ClipboardData(text: url));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profile link copied! 🔗')),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Ambient Banner & Profile Action Header
                  ProfileBannerHeader(
                    profile: profile,
                    onToggleFollow: () {
                      ref
                          .read(artistProfileFamilyProvider(artistId).notifier)
                          .toggleFollow();
                    },
                    onTipArtist: () => _showTipDialog(context, ref, profile.displayName),
                    onShare: () {
                      Clipboard.setData(
                        ClipboardData(
                          text: 'https://vhunambi.com/profile/${profile.username}',
                        ),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Profile link copied! 🔗')),
                      );
                    },
                    onReport: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Report submitted for review')),
                      );
                    },
                  ),

                  // 2. 5-Metric Statistical Grid
                  ProfileStatsGrid(profile: profile),

                  // 3. Top Songs Shelf
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 32 : 16,
                      vertical: 14,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Top Songs',
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildTopSongTile(
                          context: context,
                          ref: ref,
                          rank: 1,
                          trackId: 'seed-01',
                          title: 'Ndo Mufuna Matibe',
                          genre: 'Amapiano',
                          duration: '3:18',
                          plays: '12.4K',
                          likes: 840,
                        ),
                        const SizedBox(height: 10),
                        _buildTopSongTile(
                          context: context,
                          ref: ref,
                          rank: 2,
                          trackId: 'track_default_1',
                          title: 'Grateful in the Light',
                          genre: 'Amapiano',
                          duration: '3:29',
                          plays: '9.1K',
                          likes: 412,
                        ),
                      ],
                    ),
                  ),

                  // 4. Top Supporters Leaderboard
                  TopSupportersLeaderboard(
                    supporters: profile.topSupporters,
                    onTipFirst: () => _showTipDialog(context, ref, profile.displayName),
                  ),

                  // 5. Recent Activity Feed
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      isDesktop ? 32 : 16,
                      14,
                      isDesktop ? 32 : 16,
                      40,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recent Activity',
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildActivityRow(
                          title: 'Ndo Mufuna Matibe',
                          genre: 'Amapiano',
                          timeAgo: 'Released 2 days ago',
                        ),
                        const SizedBox(height: 10),
                        _buildActivityRow(
                          title: 'Tshikona Morning',
                          genre: 'Amapiano',
                          timeAgo: 'Released 1 week ago',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopSongTile({
    required BuildContext context,
    required WidgetRef ref,
    required int rank,
    required String trackId,
    required String title,
    required String genre,
    required String duration,
    required String plays,
    required int likes,
  }) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TrackDetailView(trackId: trackId),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            Text(
              '$rank',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.brandPrimary,
              ),
            ),
            const SizedBox(width: 14),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: AppGradients.forGenre(genre),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.piano_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$genre • $duration',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                const Icon(
                  Icons.play_arrow_rounded,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                Text(
                  plays,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.favorite_rounded,
                  size: 14,
                  color: AppColors.brandPrimary,
                ),
                const SizedBox(width: 2),
                Text(
                  '$likes',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            IconButton(
              iconSize: 26,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(
                Icons.play_circle_fill_rounded,
                color: AppColors.brandPrimary,
              ),
              onPressed: () {
                ref.read(playerStateProvider.notifier).playTrack(
                      Track(
                        id: trackId,
                        title: title,
                        creatorName: 'Fifi',
                        genre: genre,
                        duration: const Duration(minutes: 3, seconds: 18),
                      ),
                    );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityRow({
    required String title,
    required String genre,
    required String timeAgo,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: AppGradients.forGenre(genre),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '$timeAgo • $genre',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

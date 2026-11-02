import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../core/utils/creator_id_utils.dart';
import '../../../../core/widgets/vhunambi_bottom_dock_kit.dart';
import '../../../../core/widgets/vhunambi_top_bar_kit.dart';
import '../../../../shared/models/track.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../track/presentation/views/track_detail_view.dart';
import '../../../social/domain/models/published_clip.dart';
import '../../../social/presentation/providers/creator_clips_provider.dart';
import '../../../social/presentation/widgets/creator_reel_thumbnail_card.dart';
import '../../../social/presentation/widgets/kinetic_reels_modal.dart';
import '../../../social/presentation/widgets/creator_tipping_sheet.dart';
import '../../../marketplace/presentation/providers/marketplace_providers.dart';
import '../../../marketplace/presentation/widgets/beat_license_modal.dart';
import '../widgets/producer_beat_listing_tile.dart';
import '../../../creator_dna/presentation/widgets/creator_dna_profile_card.dart';
import '../../../creator_dna/presentation/providers/creator_dna_provider.dart';
import '../widgets/artist_voice_showcase_card.dart';
import '../widgets/pinned_spotlight_card.dart';
import '../providers/profile_providers.dart';
import '../../domain/models/profile_models.dart';
import '../../domain/models/profile_operation_type.dart';
import '../../domain/models/profile_operation_state.dart';
import '../widgets/error/error_boundary.dart';
import '../widgets/loading/loading_overlay.dart';
import '../widgets/loading/profile_skeleton_screen.dart';
import '../widgets/offline/offline_indicator.dart';
import '../widgets/profile_banner_header.dart';
import '../widgets/profile_stats_grid.dart';
import '../widgets/top_supporters_leaderboard.dart';

/// Public Artist Profile View (`/profile/:id`) (REQ-TRK-12 … REQ-TRK-14).
class ArtistProfileView extends ConsumerWidget {
  final String artistId;

  const ArtistProfileView({super.key, required this.artistId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(artistProfileFamilyProvider(artistId));
    final opState = ref.watch(profileOperationProvider(artistId));
    final clips = ref.watch(
      creatorClipsFamilyProvider(normalizeCreatorId(profile.id)),
    );

    // Listen for mutation errors to display snackbars
    ref.listen<ProfileOperationState>(profileOperationProvider(artistId), (
      previous,
      current,
    ) {
      final followError = current.errorFor(ProfileOperationType.follow);
      if (followError != null &&
          previous?.errorFor(ProfileOperationType.follow) != followError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(followError.message),
            backgroundColor: AppColors.error,
          ),
        );
      }
      final tipError = current.errorFor(ProfileOperationType.tip);
      if (tipError != null &&
          previous?.errorFor(ProfileOperationType.tip) != tipError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tipError.message),
            backgroundColor: AppColors.error,
          ),
        );
      }
    });

    // Initial fetch loading state
    if (opState.isLoading(ProfileOperationType.fetch) &&
        opState.cachedProfile == null) {
      return const ProfileSkeletonScreen();
    }

    // Initial fetch error state
    final fetchError = opState.errorFor(ProfileOperationType.fetch);
    if (fetchError != null && opState.cachedProfile == null) {
      return Scaffold(
        backgroundColor: AppColors.surfaceCanvas,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const VhunambiBackButton(color: Colors.white),
        ),
        body: ErrorBoundary(
          message: fetchError.message,
          onRetry: () => ref
              .read(profileOperationProvider(artistId).notifier)
              .fetchProfile(),
        ),
      );
    }

    final isMutating =
        opState.isLoading(ProfileOperationType.follow) ||
        opState.isLoading(ProfileOperationType.tip);
    final mutationMessage = opState.isLoading(ProfileOperationType.follow)
        ? 'Updating follow status...'
        : 'Processing tip...';

    final hasActiveTrack = ref.watch(
      playerStateProvider.select((s) => s.hasActiveTrack),
    );
    final bottomInset =
        VhunambiBottomDockMetrics.scrollInset(hasActiveTrack: hasActiveTrack) +
        24;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.surfaceCanvas,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const VhunambiBackButton(color: Colors.white),
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
        body: LoadingOverlay(
          isLoading: isMutating,
          message: mutationMessage,
          child: RefreshIndicator(
            color: AppColors.brandPrimary,
            backgroundColor: AppColors.surfaceModal,
            onRefresh: () => ref
                .read(profileOperationProvider(artistId).notifier)
                .fetchProfile(),
            child: NestedScrollView(
              headerSliverBuilder: (context, _) => [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      if (opState.isOffline)
                        OfflineIndicator(
                          cacheTimestamp: opState.cachedProfile?.timestamp,
                          onRefresh: () => ref
                              .read(profileOperationProvider(artistId).notifier)
                              .fetchProfile(),
                        ),
                      ProfileBannerHeader(
                        profile: profile,
                        onToggleFollow: () => ref
                            .read(profileOperationProvider(artistId).notifier)
                            .toggleFollow(),
                        onTipArtist: () => CreatorTippingSheet.show(
                          context,
                          creatorId: profile.id,
                          creatorName: profile.displayName,
                          creatorUsername: profile.username,
                          creatorAvatarUrl: profile.avatarUrl,
                        ),
                        onShare: () {
                          Clipboard.setData(
                            ClipboardData(
                              text:
                                  'https://vhunambi.com/profile/${profile.username}',
                            ),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Profile link copied! 🔗'),
                            ),
                          );
                        },
                        onReport: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Report submitted for review'),
                            ),
                          );
                        },
                      ),
                      ProfileStatsGrid(profile: profile),
                      if (profile.pinnedTrackId != null &&
                          profile.pinnedTrackId!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: ResponsiveUtils.isDesktop(context)
                                ? 32
                                : 16,
                          ),
                          child: PinnedSpotlightCard(
                            pinnedTrackId: profile.pinnedTrackId,
                            fallbackCreatorName: profile.displayName,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _ProfileTabBarDelegate(
                    TabBar(
                      labelColor: AppColors.brandPrimary,
                      indicatorColor: AppColors.brandPrimary,
                      unselectedLabelColor: AppColors.textSecondary,
                      tabs: const [
                        Tab(
                          icon: Icon(AppIcons.reels, size: 20),
                          text: 'Clips',
                        ),
                        Tab(
                          icon: Icon(AppIcons.songs, size: 20),
                          text: 'Music',
                        ),
                        Tab(
                          icon: Icon(AppIcons.beatstore, size: 20),
                          text: 'Beats',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              body: TabBarView(
                children: [
                  _reelsGrid(context, ref, clips, bottomInset),
                  _discographyTab(context, ref, profile, bottomInset),
                  _beatsCommunityTab(
                    context,
                    ref,
                    profile,
                    () => CreatorTippingSheet.show(
                      context,
                      creatorId: profile.id,
                      creatorName: profile.displayName,
                      creatorUsername: profile.username,
                      creatorAvatarUrl: profile.avatarUrl,
                    ),
                    bottomInset,
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
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Icon(
                  Icons.play_arrow_rounded,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                Text(
                  plays,
                  style: TextStyle(
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
                  style: TextStyle(
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
                ref
                    .read(playerStateProvider.notifier)
                    .playTrack(
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
            child: const Icon(
              Icons.music_note_rounded,
              color: Colors.white,
              size: 18,
            ),
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
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Tri-modal profile tabs (REQ-SOC-06 / REQ-SOC-07) ---

  Widget _reelsGrid(
    BuildContext context,
    WidgetRef ref,
    List<PublishedClip> clips,
    double bottomInset,
  ) {
    if (clips.isEmpty) {
      return _TabEmptyState(
        icon: Icons.movie_filter_outlined,
        message: 'No clips yet.\nPublish a reel from the Content Studio!',
      );
    }
    final columns = ResponsiveUtils.isDesktop(context) ? 4 : 3;
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        bottomInset,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        childAspectRatio: 9 / 16 * 1.25,
      ),
      itemCount: clips.length,
      itemBuilder: (context, i) {
        final clip = clips[i];
        return CreatorReelThumbnailCard(
          clip: clip,
          onTap: () => KineticReelsModal.show(
            context,
            clips: clips,
            initialClipId: clip.id,
          ),
        );
      },
    );
  }

  Widget _discographyTab(
    BuildContext context,
    WidgetRef ref,
    ArtistProfileEntity profile,
    double bottomInset,
  ) {
    final artistDna =
        profile.creatorDna ?? ref.watch(artistDnaFamilyProvider(profile.id));

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        bottomInset,
      ),
      children: [
        // 1. Sovereign Bantu Voice Identity Showcase (Phase 30 REQ-PROF-VOICE-01)
        ArtistVoiceShowcaseCard(
          artistName: profile.displayName,
          vocalArchetypeTitle: profile.vocalArchetypeTitle,
          vocalArchetypeLanguage: profile.vocalArchetypeLanguage,
          vocalSampleUrl: profile.vocalSampleUrl,
        ),
        const SizedBox(height: AppSpacing.md),

        // 2. Scoped Creator DNA Profile Card (Phase 30 REQ-PROF-DNA-01)
        CreatorDnaProfileCard(isOwner: false, customDna: artistDna),
        const SizedBox(height: AppSpacing.lg),

        Text(
          'Top Songs',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
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
        const SizedBox(height: AppSpacing.xs),
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
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Releases',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (profile.releases.isEmpty)
          Text('No releases yet.', style: AppTypography.bodyMuted)
        else
          for (final release in profile.releases) _ReleaseRow(release: release),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Recent Activity',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildActivityRow(
          title: 'Ndo Mufuna Matibe',
          genre: 'Amapiano',
          timeAgo: 'Released 2 days ago',
        ),
      ],
    );
  }

  Widget _beatsCommunityTab(
    BuildContext context,
    WidgetRef ref,
    ArtistProfileEntity profile,
    VoidCallback onTip,
    double bottomInset,
  ) {
    final beats = ref.watch(creatorBeatsFamilyProvider(profile.id));
    final currentTrack = ref.watch(playerStateProvider).currentTrack;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        bottomInset,
      ),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.storefront_rounded,
                  color: AppColors.brandPrimary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Beats & Stems',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Text(
              '${beats.length} available',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (beats.isEmpty)
          Container(
            key: const Key('artist_profile_empty_beats'),
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: AppRadius.cardBorder,
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.music_off_rounded,
                  size: 32,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 8),
                Text(
                  'No beats listed yet by this producer.',
                  style: AppTypography.bodyMuted,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          for (final beat in beats)
            ProducerBeatListingTile(
              beat: beat,
              isPlaying: currentTrack?.id == beat.id,
              onAudition: () => auditionBeat(ref, beat),
              onLicense: () => showBeatLicenseModal(context, beat),
            ),
        const SizedBox(height: AppSpacing.lg),
        TopSupportersLeaderboard(
          supporters: profile.topSupporters,
          onTipFirst: onTip,
        ),
        const SizedBox(height: AppSpacing.md),
        if (profile.topSupporters.isEmpty)
          Text(
            'No supporters yet — be the first to tip!',
            style: AppTypography.bodyMuted,
          ),
      ],
    );
  }
}

/// Pinned TabBar sliver header for the tri-modal profile.
class _ProfileTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _ProfileTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: AppColors.surfaceCanvas, child: tabBar);
  }

  @override
  bool shouldRebuild(_ProfileTabBarDelegate oldDelegate) => false;
}

class _TabEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _TabEmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReleaseRow extends StatelessWidget {
  final MusicReleaseEntity release;
  const _ReleaseRow({required this.release});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppGradients.forGenre(release.genre),
              borderRadius: AppRadius.thumbBorder,
            ),
            child: const Icon(
              Icons.album_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  release.title,
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${release.typeLabel} • ${release.trackCount} tracks • ${release.releaseYear}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

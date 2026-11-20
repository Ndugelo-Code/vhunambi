import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/design_system/tokens/app_icons.dart';
import 'package:vhunambi_client/core/design_system/tokens/vhunambi_mood.dart';
import 'package:vhunambi_client/core/navigation/navigation_providers.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/core/utils/creator_id_utils.dart';
import 'package:vhunambi_client/core/utils/responsive_utils.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_ambient_mesh_backdrop.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_glass_surface.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_top_bar_kit.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_track_artwork.dart';
import 'package:vhunambi_client/features/explore/domain/models/social_music_post.dart';
import 'package:vhunambi_client/features/explore/presentation/views/kinetic_post_focus_view.dart';
import 'package:vhunambi_client/features/marketplace/presentation/providers/marketplace_providers.dart';
import 'package:vhunambi_client/features/marketplace/presentation/widgets/beat_license_modal.dart';
import 'package:vhunambi_client/features/player/presentation/providers/player_provider.dart';
import 'package:vhunambi_client/features/profile/domain/models/profile_models.dart';
import 'package:vhunambi_client/features/profile/domain/models/profile_operation_state.dart';
import 'package:vhunambi_client/features/profile/domain/models/profile_operation_type.dart';
import 'package:vhunambi_client/features/profile/presentation/providers/profile_providers.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/error/error_boundary.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/loading/profile_skeleton_screen.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/offline/offline_indicator.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/pinned_spotlight_card.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/producer_beat_listing_tile.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/profile_banner_header.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/top_supporters_leaderboard.dart';
import 'package:vhunambi_client/features/social/domain/models/published_clip.dart';
import 'package:vhunambi_client/features/social/presentation/providers/creator_clips_provider.dart';
import 'package:vhunambi_client/features/social/presentation/widgets/creator_reel_thumbnail_card.dart';
import 'package:vhunambi_client/features/social/presentation/widgets/creator_tipping_sheet.dart';
import 'package:vhunambi_client/features/social/presentation/widgets/kinetic_reels_modal.dart';
import 'package:vhunambi_client/features/track/presentation/views/track_detail_view.dart';
import 'package:vhunambi_client/shared/models/track.dart';

/// Facebook-Benchmark Public Visitor Creator Profile View (`/profile/:id`)
/// (`REQ-P70-PROF-01..03`, `REQ-P70-PTAB-01..03`, `STD-UIUX-001`).
class ArtistProfileView extends ConsumerStatefulWidget {
  final String artistId;

  const ArtistProfileView({super.key, required this.artistId});

  @override
  ConsumerState<ArtistProfileView> createState() => _ArtistProfileViewState();
}

class _ArtistProfileViewState extends ConsumerState<ArtistProfileView> {
  StateController<int>? _pushedOverlayCounter;
  bool _didIncrementPushedOverlay = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final counter = ref.read(pushedFullScreenOverlayCountProvider.notifier);
      _pushedOverlayCounter = counter;
      _didIncrementPushedOverlay = true;
      counter.state++;
    });
  }

  @override
  void dispose() {
    final counter = _pushedOverlayCounter;
    if (_didIncrementPushedOverlay && counter != null) {
      _didIncrementPushedOverlay = false;
      Future<void>.microtask(() {
        if (counter.mounted && counter.state > 0) {
          counter.state = (counter.state - 1).clamp(0, 99);
        }
      });
    }
    super.dispose();
  }

  String _formatCompactMetric(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '$count';
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _openTipSheet(BuildContext context, ArtistProfileEntity profile) {
    CreatorTippingSheet.show(
      context,
      creatorId: profile.id,
      creatorName: profile.displayName,
      creatorUsername: profile.username,
      creatorAvatarUrl: profile.avatarUrl,
    );
  }

  void _openOverflowSheet(BuildContext context, ArtistProfileEntity profile) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceModalOf(context),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.modalBorder),
      builder: (sheetCtx) {
        final textPrimary = AppColors.textPrimaryOf(sheetCtx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  key: const Key('visitor_overflow_share'),
                  leading: PhosphorIcon(AppIcons.share, color: textPrimary),
                  title: Text(
                    'Share Profile',
                    style: AppTypography.bodyLarge.copyWith(color: textPrimary),
                  ),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    Clipboard.setData(
                      ClipboardData(text: profile.profileUrl),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Copied ${profile.displayName} profile link',
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  key: const Key('visitor_overflow_copy_handle'),
                  leading: PhosphorIcon(
                    PhosphorIconsRegular.copy,
                    color: textPrimary,
                  ),
                  title: Text(
                    'Copy ${profile.handle}',
                    style: AppTypography.bodyLarge.copyWith(color: textPrimary),
                  ),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    Clipboard.setData(ClipboardData(text: profile.handle));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Copied ${profile.handle}')),
                    );
                  },
                ),
                ListTile(
                  key: const Key('visitor_overflow_report'),
                  leading: const PhosphorIcon(
                    PhosphorIconsRegular.flag,
                    color: AppColors.error,
                  ),
                  title: Text(
                    'Report Creator',
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Report submitted for ${profile.handle}.'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(artistProfileFamilyProvider(widget.artistId));
    final opState = ref.watch(profileOperationProvider(widget.artistId));
    final liveTracks = ref.watch(creatorCatalogTracksProvider(profile.id));
    final creatorPosts = ref.watch(creatorKineticPostsProvider(profile.id));
    final clips = ref.watch(
      creatorClipsFamilyProvider(normalizeCreatorId(profile.id)),
    );
    final textPrimary = AppColors.textPrimaryOf(context);

    ref.listen<ProfileOperationState>(
      profileOperationProvider(widget.artistId),
      (previous, current) {
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
      },
    );

    if (opState.isLoading(ProfileOperationType.fetch) &&
        opState.cachedProfile == null) {
      return const ProfileSkeletonScreen();
    }

    final fetchError = opState.errorFor(ProfileOperationType.fetch);
    if (fetchError != null && opState.cachedProfile == null) {
      return Scaffold(
        backgroundColor: AppColors.surfaceCanvasOf(context),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: VhunambiBackButton(color: textPrimary),
        ),
        body: ErrorBoundary(
          message: fetchError.message,
          onRetry: () => ref
              .read(profileOperationProvider(widget.artistId).notifier)
              .fetchProfile(),
        ),
      );
    }

    final primaryGenre = profile.topGenres.isNotEmpty
        ? profile.topGenres.first
        : 'Amapiano';

    return DefaultTabController(
      length: 5,
      initialIndex: 0,
      child: Scaffold(
        backgroundColor: AppColors.surfaceCanvasOf(context),
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(
            VhunambiTopBarMetrics.totalHeight(context),
          ),
          child: VhunambiTopBarSurface(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Row(
                children: <Widget>[
                  VhunambiBackButton(color: textPrimary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      profile.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    icon: PhosphorIcon(
                      AppIcons.share,
                      color: textPrimary,
                      size: 20,
                    ),
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: profile.profileUrl),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Profile link copied!')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        body: VhunambiAmbientMeshBackdrop.forGenre(
          genre: primaryGenre,
          child: RefreshIndicator(
            color: AppColors.brandPrimary,
            backgroundColor: AppColors.surfaceModalOf(context),
            onRefresh: () => ref
                .read(profileOperationProvider(widget.artistId).notifier)
                .fetchProfile(),
            child: NestedScrollView(
              headerSliverBuilder: (context, _) => <Widget>[
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (opState.isOffline)
                        OfflineIndicator(
                          cacheTimestamp: opState.cachedProfile?.timestamp,
                          onRefresh: () => ref
                              .read(
                                profileOperationProvider(
                                  widget.artistId,
                                ).notifier,
                              )
                              .fetchProfile(),
                        ),
                      ProfileBannerHeader(
                        profile: profile,
                        onToggleFollow: () => ref
                            .read(
                              profileOperationProvider(
                                widget.artistId,
                              ).notifier,
                            )
                            .toggleFollow(),
                        onTipArtist: () => _openTipSheet(context, profile),
                        onOpenOverflowMenu: () =>
                            _openOverflowSheet(context, profile),
                      ),
                      _buildInlineSocialProofStrip(
                        context,
                        profile,
                        liveTracks.length,
                      ),
                    ],
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _ProfileTabBarDelegate(
                    surfaceColor: AppColors.surfaceCanvasOf(context),
                    tabBar: TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      labelColor: AppColors.brandPrimary,
                      indicatorColor: AppColors.brandPrimary,
                      unselectedLabelColor: AppColors.textSecondaryOf(context),
                      tabs: const <Tab>[
                        Tab(key: Key('visitor_tab_overview'), text: 'Overview'),
                        Tab(key: Key('visitor_tab_songs'), text: 'Songs'),
                        Tab(
                          key: Key('visitor_tab_posts_reels'),
                          text: 'Posts & Reels',
                        ),
                        Tab(key: Key('visitor_tab_beats'), text: 'Beats'),
                        Tab(key: Key('visitor_tab_about'), text: 'About'),
                      ],
                    ),
                  ),
                ),
              ],
              body: TabBarView(
                children: <Widget>[
                  _buildOverviewTab(
                    context,
                    profile,
                    liveTracks,
                    creatorPosts,
                  ),
                  _buildSongsTab(context, profile, liveTracks),
                  _buildPostsAndReelsTab(context, profile, creatorPosts, clips),
                  _buildBeatsTab(context, profile),
                  _buildAboutTab(context, profile),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInlineSocialProofStrip(
    BuildContext context,
    ArtistProfileEntity profile,
    int liveSongCount,
  ) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final resolvedSongs = liveSongCount > 0 ? liveSongCount : profile.songCount;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.isDesktop(context) ? 32 : 16,
        vertical: AppSpacing.xs,
      ),
      child: VhunambiGlassSurface(
        key: const Key('visitor_profile_inline_stats'),
        variant: VhunambiGlassVariant.card,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text(
              '${_formatCompactMetric(profile.followerCount)} followers',
              style: AppTypography.bodySmall.copyWith(
                color: textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text('·', style: AppTypography.bodySmall.copyWith(color: textSecondary)),
            Text(
              '${_formatCompactMetric(profile.monthlyListenersCount)} monthly listeners',
              style: AppTypography.bodySmall.copyWith(color: textSecondary),
            ),
            Text('·', style: AppTypography.bodySmall.copyWith(color: textSecondary)),
            Text(
              '$resolvedSongs songs',
              style: AppTypography.bodySmall.copyWith(color: textSecondary),
            ),
            Text('·', style: AppTypography.bodySmall.copyWith(color: textSecondary)),
            Text(
              '${_formatCompactMetric(profile.playCount)} plays',
              style: AppTypography.bodySmall.copyWith(color: textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab(
    BuildContext context,
    ArtistProfileEntity profile,
    List<Track> liveTracks,
    List<SocialMusicPost> creatorPosts,
  ) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final moodTags = <VhunambiMood>{
      for (final track in liveTracks)
        VhunambiMood.normalize(track.mood),
      if (liveTracks.isEmpty) VhunambiMood.uplifting,
    }.toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        36,
      ),
      children: <Widget>[
        if (profile.pinnedTrackId != null &&
            profile.pinnedTrackId!.isNotEmpty) ...<Widget>[
          PinnedSpotlightCard(
            pinnedTrackId: profile.pinnedTrackId,
            fallbackCreatorName: profile.displayName,
          ),
        ],

        if (profile.bio.isNotEmpty) ...<Widget>[
          VhunambiGlassSurface(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const PhosphorIcon(
                      AppIcons.user,
                      size: 16,
                      color: AppColors.brandPrimary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Artist Overview',
                      style: AppTypography.titleSmall.copyWith(
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  profile.bio,
                  style: AppTypography.bodyMuted.copyWith(color: textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        Text(
          'Top Songs',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (liveTracks.isEmpty)
          _buildVisitorEmptyGlassCard(
            context,
            icon: AppIcons.songs,
            message: '${profile.displayName} has no public tracks published yet.',
          )
        else
          for (int i = 0; i < liveTracks.take(3).length; i++) ...<Widget>[
            _buildTrackTile(context, liveTracks[i], rank: i + 1),
            const SizedBox(height: AppSpacing.xs),
          ],

        const SizedBox(height: AppSpacing.md),
        Text(
          'Latest Post',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (creatorPosts.isEmpty)
          _buildVisitorEmptyGlassCard(
            context,
            icon: AppIcons.reels,
            message: '${profile.handle} has not posted updates yet.',
          )
        else
          _buildKineticPostPreviewCard(context, creatorPosts.first),

        const SizedBox(height: AppSpacing.md),
        Text(
          'Genres & Sonic Moods',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final genre in profile.topGenres)
              VhunambiGlassSurface(
                variant: VhunambiGlassVariant.pill,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Text(
                  genre,
                  style: AppTypography.caption.copyWith(
                    color: textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            for (final mood in moodTags)
              VhunambiGlassSurface(
                variant: VhunambiGlassVariant.pill,
                tintAccent: mood.accentColor,
                borderColorOverride: mood.accentColor.withValues(alpha: 0.45),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    PhosphorIcon(mood.icon, size: 13, color: mood.accentColor),
                    const SizedBox(width: 6),
                    Text(
                      mood.label,
                      style: AppTypography.caption.copyWith(
                        color: textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSongsTab(
    BuildContext context,
    ArtistProfileEntity profile,
    List<Track> liveTracks,
  ) {
    if (liveTracks.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          _buildVisitorEmptyGlassCard(
            context,
            icon: AppIcons.songs,
            message: '${profile.handle} has no public songs listed yet.',
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        36,
      ),
      itemCount: liveTracks.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, index) =>
          _buildTrackTile(context, liveTracks[index], rank: index + 1),
    );
  }

  Widget _buildTrackTile(
    BuildContext context,
    Track track, {
    required int rank,
  }) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final playerState = ref.watch(playerStateProvider);
    final isPlaying =
        playerState.isPlaying && playerState.currentTrack?.id == track.id;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('visitor_song_tile_${track.id}'),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => TrackDetailView(trackId: track.id),
            ),
          );
        },
        borderRadius: AppRadius.cardBorder,
        child: VhunambiGlassSurface(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 24,
                child: Text(
                  '$rank',
                  textAlign: TextAlign.center,
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              VhunambiTrackArtwork(
                coverUrl: track.coverUrl,
                genre: track.genre,
                trackId: track.id,
                width: 44,
                height: 44,
                borderRadius: BorderRadius.circular(8),
                badgeIconSize: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${track.genre} · ${_formatDuration(track.duration)} · ${_formatCompactMetric(track.playCount)} plays',
                      style: AppTypography.caption.copyWith(
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: Key('visitor_song_play_${track.id}'),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                icon: PhosphorIcon(
                  isPlaying
                      ? PhosphorIconsFill.pauseCircle
                      : PhosphorIconsFill.playCircle,
                  size: 28,
                  color: AppColors.brandPrimary,
                ),
                onPressed: () {
                  if (isPlaying) {
                    ref.read(playerStateProvider.notifier).pause();
                  } else {
                    ref.read(playerStateProvider.notifier).playTrack(track);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostsAndReelsTab(
    BuildContext context,
    ArtistProfileEntity profile,
    List<SocialMusicPost> creatorPosts,
    List<PublishedClip> clips,
  ) {
    if (creatorPosts.isEmpty && clips.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          _buildVisitorEmptyGlassCard(
            context,
            icon: AppIcons.reels,
            message: "${profile.handle} hasn't shared any posts or reels yet.",
          ),
        ],
      );
    }

    final columns = ResponsiveUtils.isDesktop(context) ? 4 : 3;
    final textPrimary = AppColors.textPrimaryOf(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        36,
      ),
      children: <Widget>[
        if (creatorPosts.isNotEmpty) ...<Widget>[
          Text(
            'Kinetic Posts',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final post in creatorPosts) ...<Widget>[
            _buildKineticPostPreviewCard(context, post),
            const SizedBox(height: AppSpacing.xs),
          ],
          const SizedBox(height: AppSpacing.md),
        ],
        if (clips.isNotEmpty) ...<Widget>[
          Text(
            'Reels & Clips',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
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
          ),
        ],
      ],
    );
  }

  Widget _buildKineticPostPreviewCard(
    BuildContext context,
    SocialMusicPost post,
  ) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('visitor_post_preview_${post.id}'),
        onTap: () {
          KineticPostFocusView.show(
            context,
            postId: post.id,
            initialPost: post,
          );
        },
        borderRadius: AppRadius.cardBorder,
        child: VhunambiGlassSurface(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                post.caption,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall.copyWith(color: textPrimary),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  PhosphorIcon(
                    AppIcons.heart,
                    size: 14,
                    color: AppColors.brandPrimary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${post.likeCount}',
                    style: AppTypography.caption.copyWith(color: textSecondary),
                  ),
                  const SizedBox(width: 14),
                  PhosphorIcon(
                    AppIcons.chat,
                    size: 14,
                    color: textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${post.commentCount} comments',
                    style: AppTypography.caption.copyWith(color: textSecondary),
                  ),
                  const Spacer(),
                  Text(
                    'Open Post',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.brandPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBeatsTab(BuildContext context, ArtistProfileEntity profile) {
    final asyncBeats = ref.watch(producerBeatsFamilyProvider(profile.id));
    final fallbackLocal = ref.watch(creatorBeatsFamilyProvider(profile.id));
    final beats = asyncBeats.valueOrNull ?? fallbackLocal;
    final currentTrack = ref.watch(playerStateProvider).currentTrack;
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        36,
      ),
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Row(
              children: <Widget>[
                const PhosphorIcon(
                  AppIcons.navMarketActive,
                  color: AppColors.brandPrimary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Beats & Stems',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
            Text(
              '${beats.length} available',
              style: AppTypography.caption.copyWith(color: textSecondary),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (beats.isEmpty)
          _buildVisitorEmptyGlassCard(
            context,
            key: const Key('artist_profile_empty_beats'),
            icon: AppIcons.songsOutline,
            message: 'No beats listed yet by this producer.',
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
          onTipFirst: () => _openTipSheet(context, profile),
        ),
      ],
    );
  }

  Widget _buildAboutTab(BuildContext context, ArtistProfileEntity profile) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        36,
      ),
      children: <Widget>[
        VhunambiGlassSurface(
          key: const Key('visitor_about_provenance_card'),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const PhosphorIcon(
                    AppIcons.info,
                    size: 18,
                    color: AppColors.brandPrimary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'About ${profile.displayName}',
                    style: AppTypography.titleSmall.copyWith(
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                profile.bio.isNotEmpty
                    ? profile.bio
                    : 'Independent African music creator on Vhunambi.',
                style: AppTypography.bodyMuted.copyWith(color: textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              _AboutRow(
                icon: profile.archetype.icon,
                label: 'Craft Archetype',
                value: profile.archetype.displayName,
              ),
              _AboutRow(
                icon: AppIcons.songs,
                label: 'Primary Genres',
                value: profile.topGenres.isNotEmpty
                    ? profile.topGenres.join(', ')
                    : 'Amapiano',
              ),
              _AboutRow(
                icon: AppIcons.coin,
                label: 'Direct Fan Support',
                value: profile.tipsEnabled ? 'Enabled' : 'Paused',
              ),
            ],
          ),
        ),
        if (profile.releases.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Text(
            'Releases',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final release in profile.releases) _ReleaseRow(release: release),
        ],
      ],
    );
  }

  Widget _buildVisitorEmptyGlassCard(
    BuildContext context, {
    Key? key,
    required IconData icon,
    required String message,
  }) {
    return VhunambiGlassSurface(
      key: key,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: <Widget>[
          PhosphorIcon(icon, size: 32, color: AppColors.textSecondaryOf(context)),
          const SizedBox(height: 8),
          Text(
            message,
            style: AppTypography.bodyMuted.copyWith(
              color: AppColors.textSecondaryOf(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ProfileTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Color surfaceColor;
  final TabBar tabBar;

  _ProfileTabBarDelegate({required this.surfaceColor, required this.tabBar});

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
    return Container(color: surfaceColor, child: tabBar);
  }

  @override
  bool shouldRebuild(_ProfileTabBarDelegate oldDelegate) =>
      surfaceColor != oldDelegate.surfaceColor;
}

class _AboutRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _AboutRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          PhosphorIcon(icon, size: 16, color: AppColors.brandPrimary),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondaryOf(context),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimaryOf(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReleaseRow extends StatelessWidget {
  final MusicReleaseEntity release;

  const _ReleaseRow({required this.release});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: VhunambiGlassSurface(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            VhunambiTrackArtwork(
              genre: release.genre,
              trackId: release.id,
              width: 44,
              height: 44,
              borderRadius: AppRadius.thumbBorder,
              badgeIconSize: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    release.title,
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                  Text(
                    '${release.typeLabel} · ${release.trackCount} tracks · ${release.releaseYear}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

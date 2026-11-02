import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../profile/presentation/views/artist_profile_view.dart';
import '../../../social/presentation/widgets/creator_tipping_sheet.dart';
import '../../../social/presentation/widgets/reels_comment_sheet.dart';
import '../../../studio/presentation/providers/melody_sketchpad_provider.dart';
import '../../../studio/presentation/providers/studio_form_provider.dart';
import '../../../studio/presentation/providers/vocal_identity_provider.dart';
import '../../domain/models/social_music_post.dart';
import '../providers/explore_providers.dart';

/// Rich Social Music Post Card (REQ-EXP-FEED-01..04).
/// Features creator header, + Follow action, contextual caption, embedded playable
/// waveform audio card, and complete 5-action social engagement bar.
class ExploreSocialPostCard extends ConsumerWidget {
  final SocialMusicPost post;
  final VoidCallback? onRemixSuccess;

  const ExploreSocialPostCard({
    super.key,
    required this.post,
    this.onRemixSuccess,
  });

  void _handleRemixInStudio(BuildContext context, WidgetRef ref) {
    HapticFeedback.mediumImpact();
    final track = post.track;
    ref.read(studioFormProvider.notifier).setGenre(track.genre);
    ref
        .read(studioFormProvider.notifier)
        .updatePrompt('Remix inspired by ${track.title} by ${track.creatorName}');
    ref
        .read(melodySketchpadProvider.notifier)
        .initializeFromRemixDna(
          musicalKey: 'Am',
          bpm: 113,
          genre: track.genre,
        );
    ref
        .read(vocalIdentityProvider.notifier)
        .initializeFromRemixDna(
          deliveryMode: 'afroSoulMelodic',
          genre: track.genre,
        );

    onRemixSuccess?.call();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Remix loaded into Studio: "${track.title}"'),
        backgroundColor: AppColors.badgeCyan,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _handleShare(BuildContext context) {
    Clipboard.setData(ClipboardData(text: post.track.audioUrl ?? ''));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Track link copied to clipboard! ↗️'),
        backgroundColor: AppColors.brandPrimary,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followingIds = ref.watch(followingCreatorIdsProvider);
    final isFollowing = followingIds.contains(post.creatorId);

    final player = ref.watch(playerStateProvider);
    final isPlayingThis =
        player.isPlaying && player.currentTrack?.id == post.track.id;

    return Container(
      key: Key('social_post_card_${post.id}'),
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Creator Header (Avatar, Name, Handle, Verified, Relative Time, Follow Action)
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  key: Key('social_post_creator_${post.id}'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ArtistProfileView(artistId: post.creatorId),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.surfaceSecondary,
                        backgroundImage: post.creatorAvatarUrl != null
                            ? NetworkImage(post.creatorAvatarUrl!)
                            : null,
                        child: post.creatorAvatarUrl == null
                            ? Text(
                                post.creatorName.isNotEmpty
                                    ? post.creatorName[0].toUpperCase()
                                    : '?',
                                style: AppTypography.titleMedium.copyWith(
                                  color: AppColors.brandPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    post.creatorName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.bodyMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                if (post.isCreatorVerified) ...[
                                  const SizedBox(width: 4),
                                  const PhosphorIcon(
                                    AppIcons.verified,
                                    color: AppColors.brandPrimary,
                                    size: 15,
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              '${post.creatorHandle} • ${post.relativeTimeAgo} • ${post.location}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              // Follow/Following Button (44dp target)
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 36, minWidth: 44),
                child: TextButton(
                  key: Key('social_post_follow_${post.id}'),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    ref
                        .read(followingCreatorIdsProvider.notifier)
                        .toggleFollow(post.creatorId);
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: isFollowing
                        ? AppColors.surfaceSecondary
                        : AppColors.brandPrimary,
                    foregroundColor: isFollowing
                        ? AppColors.textPrimary
                        : AppColors.brandContrast,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.pillBorder,
                      side: BorderSide(
                        color: isFollowing
                            ? AppColors.borderSubtle
                            : AppColors.brandPrimary,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                  ),
                  child: Text(
                    isFollowing ? 'Following' : '+ Follow',
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isFollowing
                          ? AppColors.textPrimary
                          : AppColors.brandContrast,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // 2. Caption Context Text
          if (post.caption.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              post.caption,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                height: 1.35,
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.md),

          // 3. Embedded Playable MP3 Audio Card with Waveform
          _EmbeddedTrackCard(
            post: post,
            isPlaying: isPlayingThis,
            onPlayToggle: () {
              if (isPlayingThis) {
                ref.read(playerStateProvider.notifier).pause();
              } else {
                playExploreTrack(ref, post.track);
              }
            },
          ),

          const SizedBox(height: AppSpacing.md),

          // 4. Social Engagement Action Bar (Like, Comment, Remix, Tip, Share)
          Row(
            children: [
              // Like Action
              Expanded(
                child: _ActionButton(
                  key: Key('social_post_like_btn_${post.id}'),
                  icon: post.isLikedByMe
                      ? AppIcons.heart
                      : AppIcons.heartOutline,
                  iconColor: post.isLikedByMe
                      ? AppColors.brandPrimary
                      : AppColors.textSecondary,
                  label: post.likeCount > 0 ? '${post.likeCount}' : 'Like',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref
                        .read(socialFeedPostsProvider.notifier)
                        .toggleLike(post.id);
                  },
                ),
              ),

              // Comment Action
              Expanded(
                child: _ActionButton(
                  key: Key('social_post_comment_btn_${post.id}'),
                  icon: AppIcons.chat,
                  iconColor: AppColors.textSecondary,
                  label:
                      post.commentCount > 0 ? '${post.commentCount}' : 'Comment',
                  onTap: () =>
                      ReelsCommentSheet.show(context, clip: post.toPublishedClip),
                ),
              ),

              // Remix in Studio Action
              Expanded(
                child: _ActionButton(
                  key: Key('social_post_remix_btn_${post.id}'),
                  icon: AppIcons.remix,
                  iconColor: AppColors.badgeCyan,
                  label: 'Remix',
                  onTap: () => _handleRemixInStudio(context, ref),
                ),
              ),

              // Tip Creator Action
              Expanded(
                child: _ActionButton(
                  key: Key('social_post_tip_btn_${post.id}'),
                  icon: AppIcons.coin,
                  iconColor: AppColors.coinGold,
                  label:
                      post.tipCountCoins > 0 ? '${post.tipCountCoins}' : 'Tip',
                  onTap: () =>
                      CreatorTippingSheet.show(context, clip: post.toPublishedClip),
                ),
              ),

              // Share Action
              Expanded(
                child: _ActionButton(
                  icon: AppIcons.share,
                  iconColor: AppColors.textSecondary,
                  label: 'Share',
                  onTap: () => _handleShare(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmbeddedTrackCard extends StatelessWidget {
  final SocialMusicPost post;
  final bool isPlaying;
  final VoidCallback onPlayToggle;

  const _EmbeddedTrackCard({
    required this.post,
    required this.isPlaying,
    required this.onPlayToggle,
  });

  @override
  Widget build(BuildContext context) {
    final track = post.track;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          // Album Cover Artwork
          ClipRRect(
            borderRadius: AppRadius.thumbBorder,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: AppGradients.forGenre(track.genre),
              ),
              child: track.coverUrl != null && track.coverUrl!.isNotEmpty
                  ? Image.network(
                      track.coverUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => PhosphorIcon(
                        AppIcons.waveform,
                        color: AppColors.textPrimary,
                        size: 26,
                      ),
                    )
                  : PhosphorIcon(
                      AppIcons.waveform,
                      color: AppColors.textPrimary,
                      size: 26,
                    ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Metadata & 16-Bar Waveform
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${track.genre} • ${track.language} • ${track.formattedDuration}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 6),

                // 16-Bar Waveform Scrubber Mock
                _WaveformVisualizer(isPlaying: isPlaying),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Play/Pause Action Button (44dp target)
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              key: Key('social_post_play_btn_${post.id}'),
              icon: PhosphorIcon(
                isPlaying
                    ? AppIcons.pause
                    : AppIcons.play,
                color: AppColors.brandPrimary,
                size: 38,
              ),
              onPressed: onPlayToggle,
            ),
          ),
        ],
      ),
    );
  }
}

class _WaveformVisualizer extends StatelessWidget {
  final bool isPlaying;

  const _WaveformVisualizer({required this.isPlaying});

  // 16 baseline bar heights
  static const List<double> _barHeights = [
    6, 12, 18, 14, 8, 16, 20, 14, 10, 18, 22, 16, 12, 8, 14, 10,
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _barHeights.length; i++) ...[
          Container(
            width: 3,
            height: isPlaying ? _barHeights[i] : (_barHeights[i] * 0.5).clamp(4.0, 12.0),
            decoration: BoxDecoration(
              color: isPlaying && i < 8
                  ? AppColors.brandPrimary
                  : AppColors.borderSubtle,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
          if (i < _barHeights.length - 1) const SizedBox(width: 2.5),
        ],
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.pillBorder,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PhosphorIcon(icon, color: iconColor, size: 17),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: iconColor == AppColors.brandPrimary ||
                            iconColor == AppColors.badgeCyan ||
                            iconColor == AppColors.coinGold
                        ? iconColor
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

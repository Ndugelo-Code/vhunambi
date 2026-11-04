import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../profile/presentation/views/artist_profile_view.dart';
import '../../../social/presentation/widgets/creator_tipping_sheet.dart';
import '../../../social/presentation/widgets/open_verse_remix_cockpit_sheet.dart';
import '../../../social/presentation/widgets/reels_comment_sheet.dart';
import '../../../social/presentation/widgets/remix_lineage_tree_sheet.dart';
import '../../domain/models/social_music_post.dart';
import '../../../../shared/models/track.dart';
import '../providers/explore_providers.dart';
import 'kinetic_post_sonic_pill.dart';
import 'repost_kinetic_post_sheet.dart';
import '../../../notifications/domain/models/notification_entity.dart';
import '../../../notifications/domain/models/notification_enums.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';

/// Kinetic Social Music Post Card (REQ-KPOST-01..04).
/// 4-Zone Editorial Hierarchy:
/// Zone 1: Creator Identity Header with Repost & Lineage attribution
/// Zone 2: Contextual Caption with highlighted tags & quotes
/// Zone 3: Visual Canvas (1:1, 4:5, 16:9) with Docked Frosted Sonic Pill or Slim Capsule
/// Zone 4: Social Action Bar (Like, Comment, Repost, Remix, Tip, Share)
class ExploreSocialPostCard extends ConsumerStatefulWidget {
  final SocialMusicPost post;
  final VoidCallback? onRemixSuccess;

  const ExploreSocialPostCard({
    super.key,
    required this.post,
    this.onRemixSuccess,
  });

  @override
  ConsumerState<ExploreSocialPostCard> createState() =>
      _ExploreSocialPostCardState();
}

class _ExploreSocialPostCardState extends ConsumerState<ExploreSocialPostCard> {
  int _currentImageIndex = 0;

  void _handleRemixInStudio(BuildContext context) {
    HapticFeedback.mediumImpact();
    OpenVerseRemixCockpitSheet.show(context, clip: widget.post.toPublishedClip);
    widget.onRemixSuccess?.call();
  }

  void _handleRepost(BuildContext context) {
    HapticFeedback.mediumImpact();
    RepostKineticPostSheet.show(context, originalPost: widget.post);
  }

  void _handleShare(BuildContext context) {
    Clipboard.setData(ClipboardData(text: widget.post.track.audioUrl ?? ''));
    final post = widget.post;
    ref.read(notificationsProvider.notifier).addNotification(
      NotificationEntity(
        id: 'notif_share_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Social Link Shared',
        message: 'Shared "${post.track.title}" by @${post.creatorHandle} to your network.',
        createdAt: DateTime.now(),
        category: NotificationCategory.creatorActivity,
        isRead: false,
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Track link copied to clipboard!'),
        backgroundColor: AppColors.brandPrimary,
      ),
    );
  }

  Widget _buildVisionProceduralCanvas(
    BuildContext context,
    SocialMusicPost post,
  ) {
    final genreGradient = AppGradients.forGenre(post.track.genre);
    return Stack(
      fit: StackFit.expand,
      children: [
        // Genre Gradient Base
        Container(
          decoration: BoxDecoration(
            gradient: genreGradient,
          ),
        ),
        // Heritage Crate Cover Texture Overlay
        Opacity(
          opacity: 0.32,
          child: Image.asset(
            AppAssets.heritageCrateCover,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
        // Vignette gradient overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.15),
                Colors.black.withValues(alpha: 0.65),
              ],
            ),
          ),
        ),
        // African Vision / Sonic Badge at Center
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: const PhosphorIcon(
                  PhosphorIconsFill.sparkle,
                  size: 28,
                  color: AppColors.badgeCyan,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  'Vhunambi Vision • ${post.track.genre}',
                  style: AppTypography.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.4,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRemixButton(BuildContext context, SocialMusicPost post) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        key: Key('social_post_remix_btn_${post.id}'),
        onTap: () => _handleRemixInStudio(context),
        borderRadius: AppRadius.pillBorder,
        child: Container(
          constraints: const BoxConstraints(minHeight: 36, minWidth: 44),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.brandPrimary.withValues(alpha: 0.12),
            borderRadius: AppRadius.pillBorder,
            border: Border.all(
              color: AppColors.brandPrimary.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PhosphorIcon(
                AppIcons.remix,
                color: AppColors.brandPrimary,
                size: 14,
              ),
              const SizedBox(width: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Remix',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.brandPrimary,
                    fontWeight: FontWeight.bold,
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

  Widget _buildCosignButton(BuildContext context, SocialMusicPost post) {
    final isGraduated = post.cosignCount >= 25;
    return InkWell(
      key: Key('post_cosign_btn_${post.id}'),
      onTap: () {
        HapticFeedback.mediumImpact();
        ref.read(socialFeedPostsProvider.notifier).cosignPost(post.id);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: post.isCosigned
              ? AppColors.brandPrimary.withValues(alpha: 0.15)
              : AppColors.surfaceSecondaryOf(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: post.isCosigned
                ? AppColors.brandPrimary
                : AppColors.borderSubtleOf(context),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhosphorIcon(
              PhosphorIconsFill.fire,
              size: 11,
              color: post.isCosigned ? AppColors.coinGold : AppColors.textSecondaryOf(context),
            ),
            const SizedBox(width: 3),
            Text(
              isGraduated
                  ? '🔥 Graduated · ${post.cosignCount}'
                  : '🔥 Co-Sign · ${post.cosignCount}/25',
              style: AppTypography.caption.copyWith(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: post.isCosigned
                    ? AppColors.brandPrimary
                    : AppColors.textPrimaryOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProvenanceBadge(BuildContext context, SocialMusicPost post) {
    final prov = post.provenanceType;
    return Container(
      key: Key('post_provenance_badge_${post.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondaryOf(context),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.borderSubtleOf(context),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PhosphorIcon(
            prov.icon,
            size: 11,
            color: prov == AudioProvenanceType.humanDawMaster
                ? AppColors.coinGold
                : (prov == AudioProvenanceType.liveVocalRecording
                    ? AppColors.badgeCyan
                    : AppColors.brandPrimary),
          ),
          const SizedBox(width: 3),
          Text(
            prov.displayName,
            style: AppTypography.caption.copyWith(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimaryOf(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareButton(BuildContext context) {
    return InkWell(
      key: Key('social_post_share_btn_${widget.post.id}'),
      onTap: () => _handleShare(context),
      borderRadius: AppRadius.pillBorder,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 40, minHeight: 44),
        child: Center(
          child: PhosphorIcon(
            AppIcons.share,
            color: AppColors.textSecondaryOf(context),
            size: 18,
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final followingIds = ref.watch(followingCreatorIdsProvider);
    final isFollowing = followingIds.contains(post.creatorId);

    final images = post.allImageAttachments;
    final hasImages = images.isNotEmpty;

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
          // Repost Header Banner (if this is a repost)
          if (post.isRepost) ...[
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: [
                  PhosphorIcon(
                    PhosphorIconsRegular.repeat,
                    size: 13,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Reposted from ${post.repostedFromCreatorHandle ?? 'creator'}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ZONE 1: Creator Header (Avatar, Name, Verified, Relative Time, Follow Action)
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
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    '${post.creatorHandle} • ${post.relativeTimeAgo}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.textSecondaryOf(context),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                _buildProvenanceBadge(context, post),
                                const SizedBox(width: 5),
                                _buildCosignButton(context, post),
                              ],
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

          // ZONE 2: Caption Context & Quote Commentary
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

          const SizedBox(height: AppSpacing.sm),

          // Interactive Remix Lineage Pill (Preserved Key)
          GestureDetector(
            key: Key('post_remix_tree_btn_${post.id}'),
            onTap: () => RemixLineageTreeSheet.show(
              context,
              trackOrClipId: post.id,
              clip: post.toPublishedClip,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.brandPrimary.withValues(alpha: 0.12),
                borderRadius: AppRadius.pillBorder,
                border: Border.all(
                  color: AppColors.brandPrimary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const PhosphorIcon(
                    PhosphorIconsRegular.gitFork,
                    size: 13,
                    color: AppColors.brandPrimary,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      post.isRemix
                          ? 'Remix of ${post.parentCreatorHandle} · 70/30 Split'
                          : 'Open Stems · ${post.remixCount} Remixes',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.brandPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // ZONE 3: Visual Canvas with Resizable Aspect Ratio & Docked Frosted Sonic Pill
          if (hasImages) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: post.effectiveAspectRatio.ratio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Visual Image(s)
                    if (images.length > 1)
                      PageView.builder(
                        itemCount: images.length,
                        onPageChanged: (idx) {
                          setState(() => _currentImageIndex = idx);
                        },
                        itemBuilder: (context, idx) {
                          return Image.network(
                            images[idx].imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _buildVisionProceduralCanvas(context, post),
                          );
                        },
                      )
                    else
                      Image.network(
                        images.first.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _buildVisionProceduralCanvas(context, post),
                      ),

                    // Vhunambi Vision AI Badge
                    if (images[_currentImageIndex.clamp(0, images.length - 1)]
                        .isAiGeneratedVision)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const PhosphorIcon(
                                PhosphorIconsFill.sparkle,
                                size: 12,
                                color: AppColors.badgeCyan,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Vhunambi Vision',
                                style: AppTypography.caption.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Multi-Image Index Indicator
                    if (images.length > 1)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_currentImageIndex + 1}/${images.length}',
                            style: AppTypography.caption.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),

                    // Docked Non-Invasive Frosted Sonic Pill
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 10,
                      child: KineticPostSonicPill(post: post, isOverlay: true),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // Text-only Post: Standalone Slim Capsule (No vertical clipping!)
            KineticPostSonicPill(post: post, isOverlay: false),
          ],

          const SizedBox(height: AppSpacing.md),

          // ZONE 4: Social Engagement Action Bar (Like, Comment, Repost, Remix, Tip, Share)
          Row(
            children: [
              // 1. Like Action
              Expanded(
                child: _ActionButton(
                  key: Key('social_post_like_btn_${post.id}'),
                  icon: post.isLikedByMe
                      ? AppIcons.heart
                      : AppIcons.heartOutline,
                  iconColor: post.isLikedByMe
                      ? AppColors.brandPrimary
                      : AppColors.textSecondary,
                  label: post.likeCount > 0 ? '${post.likeCount}' : '',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref
                        .read(socialFeedPostsProvider.notifier)
                        .toggleLike(post.id);
                  },
                ),
              ),

              // 2. Comment Action
              Expanded(
                child: _ActionButton(
                  key: Key('social_post_comment_btn_${post.id}'),
                  icon: AppIcons.chat,
                  iconColor: AppColors.textSecondary,
                  label: post.commentCount > 0 ? '${post.commentCount}' : '',
                  onTap: () => ReelsCommentSheet.show(
                    context,
                    clip: post.toPublishedClip,
                  ),
                ),
              ),

              // 3. Repost Action (Phase 38 Sovereignty)
              Expanded(
                child: _ActionButton(
                  key: Key('social_post_repost_btn_${post.id}'),
                  icon: PhosphorIconsRegular.repeat,
                  iconColor: post.repostCount > 0
                      ? AppColors.badgeCyan
                      : AppColors.textSecondary,
                  label: post.repostCount > 0 ? '${post.repostCount}' : '',
                  onTap: () => _handleRepost(context),
                ),
              ),

              // 4. Remix in Studio Action (Compact Pill with FittedBox)
              _buildRemixButton(context, post),

              // 5. Tip Creator Action
              Expanded(
                child: _ActionButton(
                  key: Key('social_post_tip_btn_${post.id}'),
                  icon: AppIcons.coin,
                  iconColor: AppColors.coinGold,
                  label: post.tipCountCoins > 0 ? '${post.tipCountCoins}' : '',
                  onTap: () => CreatorTippingSheet.show(
                    context,
                    clip: post.toPublishedClip,
                  ),
                ),
              ),

              // 6. Share Action (Icon-only 44x44dp button)
              _buildShareButton(context),
            ],
          ),
        ],
      ),
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
    final showLabel = label.isNotEmpty && label != '0';
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.pillBorder,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44, minWidth: 36),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PhosphorIcon(icon, color: iconColor, size: 16),
              if (showLabel) ...[
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
            ],
          ),
        ),
      ),
    );
  }
}

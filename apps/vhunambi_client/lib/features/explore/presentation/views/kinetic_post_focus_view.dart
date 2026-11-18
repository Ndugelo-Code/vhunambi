import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/safe_network_avatar.dart';
import '../../../../core/widgets/vhunambi_track_artwork.dart';
import '../../../notifications/domain/models/notification_entity.dart';
import '../../../notifications/domain/models/notification_enums.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../profile/presentation/views/artist_profile_view.dart';
import '../../../social/presentation/providers/reels_comments_provider.dart';
import '../../../social/presentation/widgets/creator_tipping_sheet.dart';
import '../../../social/presentation/widgets/open_verse_remix_cockpit_sheet.dart';
import '../../../social/presentation/widgets/remix_lineage_tree_sheet.dart';
import '../../../social/presentation/widgets/threaded_comments_section.dart';
import '../../domain/models/social_music_post.dart';
import '../providers/explore_providers.dart';
import '../widgets/kinetic_post_sonic_pill.dart';
import '../widgets/repost_kinetic_post_sheet.dart';

/// Full-screen Facebook-benchmark Post Focus Domain (`< Post`) (`REQ-P69-FOCUS-01..04`).
///
/// Combines complete creator attribution, full caption, interactive multi-image or
/// normalized track artwork canvas, `KineticPostSonicPill`, Stem/Co-Sign telemetry,
/// Engagement Summary Strip, nested threaded comments (`Most relevant` / `Newest`),
/// and a sticky bottom reply-aware `StudioReactionComposerBar`.
class KineticPostFocusView extends ConsumerStatefulWidget {
  final String postId;
  final SocialMusicPost? initialPost;
  final bool autofocusComposer;
  final VoidCallback? onRemixSuccess;

  const KineticPostFocusView({
    super.key,
    required this.postId,
    this.initialPost,
    this.autofocusComposer = false,
    this.onRemixSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    required String postId,
    SocialMusicPost? initialPost,
    bool autofocusComposer = false,
    VoidCallback? onRemixSuccess,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => KineticPostFocusView(
          postId: postId,
          initialPost: initialPost,
          autofocusComposer: autofocusComposer,
          onRemixSuccess: onRemixSuccess,
        ),
      ),
    );
  }

  @override
  ConsumerState<KineticPostFocusView> createState() =>
      _KineticPostFocusViewState();
}

class _KineticPostFocusViewState extends ConsumerState<KineticPostFocusView> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _composerFocusNode = FocusNode();
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(reelsCommentsProvider.notifier)
          .syncCommentsForClip(widget.postId, isKineticPost: true);
      if (widget.autofocusComposer) {
        _composerFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _composerFocusNode.dispose();
    super.dispose();
  }

  SocialMusicPost? _resolvePost(List<SocialMusicPost> feedPosts) {
    for (final p in feedPosts) {
      if (p.id == widget.postId) return p;
    }
    return widget.initialPost;
  }

  void _handleShare(SocialMusicPost post) {
    Clipboard.setData(ClipboardData(text: post.track.audioUrl ?? ''));
    ref.read(notificationsProvider.notifier).addNotification(
          NotificationEntity(
            id: 'notif_share_${DateTime.now().millisecondsSinceEpoch}',
            title: 'Social Link Shared',
            message:
                'Shared "${post.track.title}" by ${post.creatorHandle} to your network.',
            createdAt: DateTime.now(),
            category: NotificationCategory.creatorActivity,
            targetRoute: '/post/${post.id}',
            targetEntityId: post.id,
            isRead: false,
          ),
        );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Post link copied to clipboard!'),
        backgroundColor: AppColors.brandPrimary,
      ),
    );
  }

  void _submitComment(SocialMusicPost post) {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.mediumImpact();
    ref.read(reelsCommentsProvider.notifier).addComment(
          clipId: post.id,
          text: text,
          contentCreatorId: post.creatorId,
          contentCreatorHandle: post.creatorHandle,
          isKineticPost: true,
        );
    _commentController.clear();
    _composerFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final feedPosts = ref.watch(socialFeedPostsProvider);
    final post = _resolvePost(feedPosts);

    if (post == null) {
      return Scaffold(
        backgroundColor: AppColors.surfaceCanvasOf(context),
        appBar: AppBar(
          backgroundColor: AppColors.surfaceElevatedOf(context),
          leading: IconButton(
            key: const Key('kpost_focus_back_btn'),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: PhosphorIcon(
              AppIcons.arrowLeft,
              color: AppColors.textPrimaryOf(context),
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'Post',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.textPrimaryOf(context),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Center(
          child: Text(
            'Post not found',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondaryOf(context),
            ),
          ),
        ),
      );
    }

    final followingIds = ref.watch(followingCreatorIdsProvider);
    final isFollowing = followingIds.contains(post.creatorId);
    final ownerProfile = ref.watch(ownerProfileProvider);
    final isOwner =
        post.creatorHandle.toLowerCase() == ownerProfile.handle.toLowerCase() ||
        post.creatorId == ownerProfile.id ||
        post.creatorId == 'me';
    final comments = ref.watch(clipCommentsFamilyProvider(post.id));
    final effectiveCommentCount = comments.length > post.commentCount
        ? comments.length
        : post.commentCount;
    final images = post.allImageAttachments;
    final hasImages = images.isNotEmpty;
    final headerHandle = post.creatorHandle.startsWith('@')
        ? post.creatorHandle
        : '@${post.creatorHandle}';

    return Scaffold(
      key: Key('kinetic_post_focus_view_${post.id}'),
      backgroundColor: AppColors.surfaceCanvasOf(context),
      appBar: AppBar(
        backgroundColor: AppColors.surfaceElevatedOf(context),
        elevation: 0,
        leading: IconButton(
          key: const Key('kpost_focus_back_btn'),
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          icon: PhosphorIcon(
            AppIcons.arrowLeft,
            color: AppColors.textPrimaryOf(context),
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Text(
          '$headerHandle\'s Post',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimaryOf(context),
          ),
        ),
        actions: [
          IconButton(
            key: const Key('kpost_focus_tip_btn'),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            tooltip: 'Tip Creator',
            icon: const PhosphorIcon(
              AppIcons.coin,
              color: AppColors.coinGold,
              size: 20,
            ),
            onPressed: () => CreatorTippingSheet.show(
              context,
              clip: post.toPublishedClip,
            ),
          ),
          IconButton(
            key: const Key('kpost_focus_share_btn'),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            tooltip: 'Share Post',
            icon: PhosphorIcon(
              AppIcons.share,
              color: AppColors.textSecondaryOf(context),
              size: 20,
            ),
            onPressed: () => _handleShare(post),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Container(
                    color: AppColors.surfaceElevatedOf(context),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (post.isRepost)
                          Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.xs),
                            child: Row(
                              children: [
                                PhosphorIcon(
                                  PhosphorIconsRegular.repeat,
                                  size: 13,
                                  color: AppColors.textSecondaryOf(context),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Reposted from ${post.repostedFromCreatorHandle ?? 'creator'}',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textSecondaryOf(context),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Creator Header
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => ArtistProfileView(
                                        artistId: post.creatorId,
                                      ),
                                    ),
                                  );
                                },
                                child: Row(
                                  children: [
                                    SafeNetworkAvatar(
                                      radius: 22,
                                      backgroundColor:
                                          AppColors.surfaceSecondaryOf(context),
                                      imageUrl: post.creatorAvatarUrl,
                                      fallbackLabel: post.creatorName,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  post.creatorName,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: AppTypography
                                                      .titleSmall
                                                      .copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors
                                                        .textPrimaryOf(context),
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
                                            style:
                                                AppTypography.caption.copyWith(
                                              color: AppColors.textSecondaryOf(
                                                context,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (!isOwner)
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 44,
                                  minWidth: 44,
                                ),
                                child: TextButton(
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    ref
                                        .read(
                                          followingCreatorIdsProvider.notifier,
                                        )
                                        .toggleFollow(post.creatorId);
                                  },
                                  child: Text(
                                    isFollowing ? 'Following' : '+ Follow',
                                    style: AppTypography.caption.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isFollowing
                                          ? AppColors.textPrimaryOf(context)
                                          : AppColors.brandPrimary,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (post.caption.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            post.caption,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textPrimaryOf(context),
                              height: 1.45,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        // Visual Media + Sonic Pill
                        if (hasImages)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: AspectRatio(
                              aspectRatio: post.effectiveAspectRatio.ratio,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  PageView.builder(
                                    itemCount: images.length,
                                    onPageChanged: (idx) {
                                      setState(() => _currentImageIndex = idx);
                                    },
                                    itemBuilder: (context, idx) {
                                      final normalizedUrl = AppConstants
                                          .normalizeCloudMediaUrl(
                                        images[idx].imageUrl,
                                      );
                                      return Image.network(
                                        normalizedUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) =>
                                            VhunambiTrackArtwork(
                                          coverUrl: post.track.coverUrl,
                                          genre: post.track.genre,
                                          trackId: post.track.id,
                                          borderRadius: BorderRadius.zero,
                                          showSubtleBorder: false,
                                        ),
                                      );
                                    },
                                  ),
                                  if (images.length > 1)
                                    Positioned(
                                      top: 10,
                                      right: 10,
                                      child: Container(
                                        key: Key(
                                          'kpost_focus_image_counter_${post.id}',
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black
                                              .withValues(alpha: 0.65),
                                          borderRadius:
                                              BorderRadius.circular(12),
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
                                  Positioned(
                                    left: 10,
                                    right: 10,
                                    bottom: 10,
                                    child: KineticPostSonicPill(
                                      post: post,
                                      isOverlay: true,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          KineticPostSonicPill(post: post, isOverlay: false),
                        const SizedBox(height: AppSpacing.sm),
                        // Lineage & Co-Sign Row
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            InkWell(
                              onTap: () => RemixLineageTreeSheet.show(
                                context,
                                trackOrClipId: post.id,
                                clip: post.toPublishedClip,
                              ),
                              borderRadius: AppRadius.pillBorder,
                              child: Container(
                                constraints: const BoxConstraints(minHeight: 36),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.brandPrimary
                                      .withValues(alpha: 0.12),
                                  borderRadius: AppRadius.pillBorder,
                                  border: Border.all(
                                    color: AppColors.brandPrimary
                                        .withValues(alpha: 0.3),
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
                                    Text(
                                      post.isRemix
                                          ? 'Remix of ${post.parentCreatorHandle} · 70/30 Split'
                                          : 'Open Stems · ${post.remixCount} Remixes',
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.brandPrimary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                ref
                                    .read(socialFeedPostsProvider.notifier)
                                    .cosignPost(post.id);
                              },
                              borderRadius: AppRadius.pillBorder,
                              child: Container(
                                constraints: const BoxConstraints(minHeight: 36),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: post.isCosigned
                                      ? AppColors.brandPrimary
                                          .withValues(alpha: 0.15)
                                      : AppColors.surfaceSecondaryOf(context),
                                  borderRadius: AppRadius.pillBorder,
                                  border: Border.all(
                                    color: post.isCosigned
                                        ? AppColors.brandPrimary
                                        : AppColors.borderSubtleOf(context),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    PhosphorIcon(
                                      PhosphorIconsFill.fire,
                                      size: 13,
                                      color: post.isCosigned
                                          ? AppColors.coinGold
                                          : AppColors.textSecondaryOf(context),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      post.cosignCount >= 25
                                          ? 'Graduated · ${post.cosignCount}'
                                          : 'Co-Sign · ${post.cosignCount}/25',
                                      style: AppTypography.caption.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: post.isCosigned
                                            ? AppColors.brandPrimary
                                            : AppColors.textPrimaryOf(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Divider(
                          height: 1,
                          color: AppColors.borderSubtleOf(context),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              const PhosphorIcon(
                                AppIcons.heart,
                                size: 14,
                                color: AppColors.brandPrimary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${post.likeCount} Likes',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textSecondaryOf(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              Flexible(
                                child: Text(
                                  '$effectiveCommentCount Comments · ${post.repostCount} Reposts · ${post.remixCount} Remixes',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textSecondaryOf(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Divider(
                          height: 1,
                          color: AppColors.borderSubtleOf(context),
                        ),
                        // Equal-width Action Bar
                        Row(
                          children: [
                            Expanded(
                              child: TextButton.icon(
                                key: Key('kpost_focus_like_btn_${post.id}'),
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  ref
                                      .read(socialFeedPostsProvider.notifier)
                                      .toggleLike(post.id);
                                },
                                icon: PhosphorIcon(
                                  post.isLikedByMe
                                      ? AppIcons.heart
                                      : AppIcons.heartOutline,
                                  size: 16,
                                  color: post.isLikedByMe
                                      ? AppColors.brandPrimary
                                      : AppColors.textSecondaryOf(context),
                                ),
                                label: Text(
                                  'Like',
                                  style: AppTypography.caption.copyWith(
                                    color: post.isLikedByMe
                                        ? AppColors.brandPrimary
                                        : AppColors.textSecondaryOf(context),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: TextButton.icon(
                                key: Key('kpost_focus_comment_btn_${post.id}'),
                                onPressed: () =>
                                    _composerFocusNode.requestFocus(),
                                icon: PhosphorIcon(
                                  AppIcons.chat,
                                  size: 16,
                                  color: AppColors.textSecondaryOf(context),
                                ),
                                label: Text(
                                  'Comment',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textSecondaryOf(context),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: TextButton.icon(
                                key: Key('kpost_focus_repost_btn_${post.id}'),
                                onPressed: () => RepostKineticPostSheet.show(
                                  context,
                                  originalPost: post,
                                ),
                                icon: PhosphorIcon(
                                  PhosphorIconsRegular.repeat,
                                  size: 16,
                                  color: AppColors.textSecondaryOf(context),
                                ),
                                label: Text(
                                  'Repost',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textSecondaryOf(context),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: TextButton.icon(
                                key: Key('kpost_focus_remix_btn_${post.id}'),
                                onPressed: () {
                                  OpenVerseRemixCockpitSheet.show(
                                    context,
                                    clip: post.toPublishedClip,
                                  );
                                  widget.onRemixSuccess?.call();
                                },
                                icon: const PhosphorIcon(
                                  AppIcons.remix,
                                  size: 16,
                                  color: AppColors.brandPrimary,
                                ),
                                label: Text(
                                  'Remix',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.brandPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Integrated Threaded Discussion Section
                SliverToBoxAdapter(
                  child: ThreadedCommentsSection(
                    clipOrPostId: post.id,
                    contentCreatorId: post.creatorId,
                    contentCreatorHandle: post.creatorHandle,
                    onRequestReplyFocus: () =>
                        _composerFocusNode.requestFocus(),
                  ),
                ),
              ],
            ),
          ),
          // Sticky Reply-Aware Bottom Composer
          StudioReactionComposerBar(
            clipOrPostId: post.id,
            creatorHandle: post.creatorHandle,
            controller: _commentController,
            focusNode: _composerFocusNode,
            onSubmit: () => _submitComment(post),
          ),
        ],
      ),
    );
  }
}

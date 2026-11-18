import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/safe_network_avatar.dart';
import '../../domain/models/reel_comment.dart';
import '../providers/reels_comments_provider.dart';

/// Immutable descriptor for a `STD-UIUX-001` Phosphor studio reaction chip (`REQ-P69-STD-01`).
@immutable
class StudioReactionChipSpec {
  final String id;
  final String label;
  final String insertText;
  final IconData icon;
  final Color iconColor;

  const StudioReactionChipSpec({
    required this.id,
    required this.label,
    required this.insertText,
    required this.icon,
    required this.iconColor,
  });
}

const List<StudioReactionChipSpec> kStudioReactionChips = <StudioReactionChipSpec>[
  StudioReactionChipSpec(
    id: 'fire',
    label: 'Fire',
    insertText: 'Pure fire!',
    icon: AppIcons.flame,
    iconColor: AppColors.brandPrimary,
  ),
  StudioReactionChipSpec(
    id: 'crown',
    label: 'Crown',
    insertText: 'Royalty!',
    icon: AppIcons.crown,
    iconColor: AppColors.coinGold,
  ),
  StudioReactionChipSpec(
    id: 'log_drum',
    label: 'Log Drum',
    insertText: 'Heavy log drum!',
    icon: AppIcons.piano,
    iconColor: AppColors.badgeCyan,
  ),
  StudioReactionChipSpec(
    id: 'soul',
    label: 'Soul',
    insertText: 'Deep soul',
    icon: AppIcons.heart,
    iconColor: AppColors.accentElectric,
  ),
  StudioReactionChipSpec(
    id: 'vocals',
    label: 'Vocals',
    insertText: 'Vocal mastery',
    icon: AppIcons.vocals,
    iconColor: AppColors.success,
  ),
  StudioReactionChipSpec(
    id: 'sa_vibe',
    label: 'SA Vibe',
    insertText: 'Proudly SA sound',
    icon: AppIcons.navExploreActive,
    iconColor: AppColors.brandPrimary,
  ),
];

const List<String> kStudioPraisePhrases = <String>[
  'Hits different!',
  'Makhado sunrise',
  'Top tier production',
  'Proudly SA',
];

/// Reusable threaded comment discussion list used in both `KineticPostFocusView`
/// and `ReelsCommentSheet` (`REQ-P69-THREAD-02` .. `REQ-P69-THREAD-05`).
class ThreadedCommentsSection extends ConsumerWidget {
  final String clipOrPostId;
  final String? contentCreatorId;
  final String? contentCreatorHandle;
  final VoidCallback? onRequestReplyFocus;
  final EdgeInsetsGeometry padding;

  const ThreadedCommentsSection({
    super.key,
    required this.clipOrPostId,
    this.contentCreatorId,
    this.contentCreatorHandle,
    this.onRequestReplyFocus,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commentsState = ref.watch(reelsCommentsProvider);
    final notifier = ref.read(reelsCommentsProvider.notifier);
    final allComments =
        commentsState.commentsByClipId[clipOrPostId] ?? const <ReelComment>[];
    final threads = notifier.threadsForClip(clipOrPostId);
    final sortOrder = commentsState.sortOrderFor(clipOrPostId);
    final normalizedCreatorHandle = contentCreatorHandle
        ?.trim()
        .toLowerCase()
        .replaceFirst(RegExp(r'^@'), '');

    ReelComment? topSupporter;
    for (final c in allComments) {
      if (c.userReelLoves >= 3) {
        if (topSupporter == null ||
            c.userReelLoves > topSupporter.userReelLoves) {
          topSupporter = c;
        }
      }
    }

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Comments Count + Most Relevant / Newest Sort Selector
          Row(
            key: Key('threaded_comments_header_$clipOrPostId'),
            children: [
              Text(
                'Comments (${allComments.length})',
                style: AppTypography.titleSmall.copyWith(
                  color: AppColors.textPrimaryOf(context),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              PopupMenuButton<CommentSortOrder>(
                key: const Key('comment_sort_toggle_btn'),
                initialValue: sortOrder,
                tooltip: 'Sort comments',
                color: AppColors.surfaceElevatedOf(context),
                onSelected: (selected) {
                  HapticFeedback.selectionClick();
                  notifier.setSortOrder(clipOrPostId, selected);
                },
                itemBuilder: (ctx) => [
                  for (final option in CommentSortOrder.values)
                    PopupMenuItem<CommentSortOrder>(
                      key: Key('comment_sort_option_${option.name}'),
                      value: option,
                      child: Row(
                        children: [
                          PhosphorIcon(
                            option == sortOrder
                                ? AppIcons.checkCircle
                                : PhosphorIconsRegular.circle,
                            size: 16,
                            color: option == sortOrder
                                ? AppColors.brandPrimary
                                : AppColors.textSecondaryOf(ctx),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            option.label,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textPrimaryOf(ctx),
                              fontWeight: option == sortOrder
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                child: Container(
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondaryOf(context),
                    borderRadius: AppRadius.pillBorder,
                    border: Border.all(
                      color: AppColors.borderSubtleOf(context),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        sortOrder.label,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textPrimaryOf(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      PhosphorIcon(
                        AppIcons.caretDown,
                        size: 13,
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (topSupporter != null) ...[
            const SizedBox(height: AppSpacing.xs),
            _HonestSupporterBanner(supporter: topSupporter),
          ],
          const SizedBox(height: AppSpacing.sm),
          if (threads.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PhosphorIcon(
                      AppIcons.chat,
                      size: 32,
                      color: AppColors.textSecondaryOf(context)
                          .withValues(alpha: 0.45),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No comments yet. Start the studio conversation!',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            for (final node in threads) ...[
              _ThreadedCommentTile(
                comment: node.parent,
                isCreatorOverride: _isCreatorComment(
                  node.parent,
                  contentCreatorId: contentCreatorId,
                  normalizedCreatorHandle: normalizedCreatorHandle,
                ),
                isChildReply: false,
                onReplyTap: () {
                  HapticFeedback.selectionClick();
                  notifier.setActiveReplyTarget(
                    clipOrPostId,
                    ActiveReplyTarget(
                      parentCommentId: node.parent.id,
                      replyToCommentId: node.parent.id,
                      replyToHandle: '@${node.parent.username}',
                      replyToDisplayName: node.parent.displayName,
                    ),
                  );
                  onRequestReplyFocus?.call();
                },
                onLikeTap: () {
                  HapticFeedback.lightImpact();
                  notifier.toggleCommentLike(
                    clipId: clipOrPostId,
                    commentId: node.parent.id,
                  );
                },
              ),
              if (node.replies.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 44, bottom: 4),
                  child: InkWell(
                    key: Key('comment_toggle_replies_${node.parent.id}'),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      notifier.toggleThreadExpanded(
                        clipOrPostId,
                        node.parent.id,
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 18,
                              height: 1.5,
                              color: AppColors.borderSubtleOf(context),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              node.isExpanded
                                  ? 'Hide replies'
                                  : 'View ${node.replyCount} ${node.replyCount == 1 ? 'reply' : 'replies'}',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.brandPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (node.isExpanded)
                  Padding(
                    padding: const EdgeInsets.only(left: 36, bottom: 6),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: AppColors.borderSubtleOf(context),
                            width: 1.5,
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.only(left: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final reply in node.replies)
                            _ThreadedCommentTile(
                              comment: reply,
                              isCreatorOverride: _isCreatorComment(
                                reply,
                                contentCreatorId: contentCreatorId,
                                normalizedCreatorHandle:
                                    normalizedCreatorHandle,
                              ),
                              isChildReply: true,
                              onReplyTap: () {
                                HapticFeedback.selectionClick();
                                notifier.setActiveReplyTarget(
                                  clipOrPostId,
                                  ActiveReplyTarget(
                                    parentCommentId: node.parent.id,
                                    replyToCommentId: reply.id,
                                    replyToHandle: '@${reply.username}',
                                    replyToDisplayName: reply.displayName,
                                  ),
                                );
                                onRequestReplyFocus?.call();
                              },
                              onLikeTap: () {
                                HapticFeedback.lightImpact();
                                notifier.toggleCommentLike(
                                  clipId: clipOrPostId,
                                  commentId: reply.id,
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
        ],
      ),
    );
  }

  bool _isCreatorComment(
    ReelComment comment, {
    required String? contentCreatorId,
    required String? normalizedCreatorHandle,
  }) {
    if (comment.isCreator) return true;
    if (contentCreatorId != null &&
        contentCreatorId.isNotEmpty &&
        comment.userId == contentCreatorId) {
      return true;
    }
    if (normalizedCreatorHandle != null &&
        normalizedCreatorHandle.isNotEmpty &&
        comment.username
                .trim()
                .toLowerCase()
                .replaceFirst(RegExp(r'^@'), '') ==
            normalizedCreatorHandle) {
      return true;
    }
    return false;
  }
}

class _HonestSupporterBanner extends StatelessWidget {
  final ReelComment supporter;

  const _HonestSupporterBanner({required this.supporter});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.coinGold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.coinGold.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        children: [
          const PhosphorIcon(
            AppIcons.flame,
            color: AppColors.coinGold,
            size: 15,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Honest Community: @${supporter.username} loved this ${supporter.userReelLoves}x',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
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

class _ThreadedCommentTile extends StatelessWidget {
  final ReelComment comment;
  final bool isCreatorOverride;
  final bool isChildReply;
  final VoidCallback onReplyTap;
  final VoidCallback onLikeTap;

  const _ThreadedCommentTile({
    required this.comment,
    required this.isCreatorOverride,
    required this.isChildReply,
    required this.onReplyTap,
    required this.onLikeTap,
  });

  @override
  Widget build(BuildContext context) {
    final showCreatorBadge = comment.isCreator || isCreatorOverride;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SafeNetworkAvatar(
            radius: isChildReply ? 14 : 16,
            imageUrl: comment.avatarUrl,
            fallbackLabel: comment.displayName.isNotEmpty
                ? comment.displayName
                : comment.username,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Text(
                      '@${comment.username}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textPrimaryOf(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (showCreatorBadge)
                      Container(
                        key: Key('comment_author_badge_${comment.id}'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brandPrimary.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color:
                                AppColors.brandPrimary.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          'Author',
                          style: AppTypography.badge.copyWith(
                            color: AppColors.brandPrimary,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    if (comment.userReelLoves >= 2)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.coinGold.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const PhosphorIcon(
                              AppIcons.heart,
                              size: 9,
                              color: AppColors.coinGold,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Loved ${comment.userReelLoves}x',
                              style: AppTypography.badge.copyWith(
                                color: AppColors.coinGold,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Text(
                      comment.timeAgo,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondaryOf(context),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textPrimaryOf(context),
                      height: 1.35,
                    ),
                    children: [
                      if (comment.replyToHandle != null &&
                          comment.replyToHandle!.isNotEmpty)
                        TextSpan(
                          text: '${comment.replyToHandle} ',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.brandPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      TextSpan(text: comment.text),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    InkWell(
                      key: Key('comment_reply_btn_${comment.id}'),
                      onTap: onReplyTap,
                      borderRadius: BorderRadius.circular(8),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Reply',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondaryOf(context),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            key: ValueKey('comment_like_${comment.id}'),
            onTap: onLikeTap,
            borderRadius: BorderRadius.circular(10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PhosphorIcon(
                    comment.isLikedByMe
                        ? AppIcons.heart
                        : AppIcons.heartOutline,
                    size: 16,
                    color: comment.isLikedByMe
                        ? AppColors.error
                        : AppColors.textSecondaryOf(context),
                  ),
                  if (comment.likeCount > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${comment.likeCount}',
                      style: AppTypography.caption.copyWith(
                        color: comment.isLikedByMe
                            ? AppColors.error
                            : AppColors.textSecondaryOf(context),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sticky bottom reply-aware comment composer bar with `STD-UIUX-001` Phosphor
/// studio reaction chips (`REQ-P69-STD-01`, `REQ-P69-THREAD-03`).
class StudioReactionComposerBar extends ConsumerWidget {
  final String clipOrPostId;
  final String? creatorHandle;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;
  final ValueChanged<String>? onAppendReactionText;

  const StudioReactionComposerBar({
    super.key,
    required this.clipOrPostId,
    this.creatorHandle,
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    this.onAppendReactionText,
  });

  void _appendText(String snippet) {
    if (onAppendReactionText != null) {
      onAppendReactionText!(snippet);
      return;
    }
    final current = controller.text.trimRight();
    controller.text = current.isEmpty ? snippet : '$current $snippet';
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
    focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commentsState = ref.watch(reelsCommentsProvider);
    final activeReply = commentsState.activeReplyFor(clipOrPostId);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final cleanHandle = creatorHandle != null && creatorHandle!.trim().isNotEmpty
        ? (creatorHandle!.trim().startsWith('@')
            ? creatorHandle!.trim()
            : '@${creatorHandle!.trim()}')
        : null;

    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: 8,
        bottom: bottomInset > 0 ? bottomInset + 8 : 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevatedOf(context),
        border: Border(
          top: BorderSide(color: AppColors.borderSubtleOf(context)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (activeReply != null)
              Container(
                key: const Key('comment_active_reply_banner'),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.brandPrimary.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    const PhosphorIcon(
                      PhosphorIconsRegular.arrowBendUpLeft,
                      size: 14,
                      color: AppColors.brandPrimary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Replying to ${activeReply.replyToHandle}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textPrimaryOf(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    InkWell(
                      key: const Key('comment_cancel_reply_btn'),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref
                            .read(reelsCommentsProvider.notifier)
                            .clearActiveReplyTarget(clipOrPostId);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        child: Center(
                          child: PhosphorIcon(
                            AppIcons.close,
                            size: 15,
                            color: AppColors.textSecondaryOf(context),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // STD-UIUX-001 Studio Reaction Chip Strip
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  for (final spec in kStudioReactionChips)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        key: Key('comment_reaction_chip_${spec.id}'),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _appendText(spec.insertText);
                        },
                        borderRadius: AppRadius.pillBorder,
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 36,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSecondaryOf(context),
                            borderRadius: AppRadius.pillBorder,
                            border: Border.all(
                              color: AppColors.borderSubtleOf(context),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PhosphorIcon(
                                spec.icon,
                                size: 13,
                                color: spec.iconColor,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                spec.label,
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textPrimaryOf(context),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  for (final phrase in kStudioPraisePhrases)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _appendText(phrase);
                        },
                        borderRadius: AppRadius.pillBorder,
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 36,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSecondaryOf(context),
                            borderRadius: AppRadius.pillBorder,
                            border: Border.all(
                              color: AppColors.borderSubtleOf(context),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              phrase,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondaryOf(context),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // Input Row
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondaryOf(context),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: AppColors.borderSubtleOf(context),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      key: const Key('comment_input'),
                      controller: controller,
                      focusNode: focusNode,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => onSubmit(),
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimaryOf(context),
                      ),
                      decoration: InputDecoration(
                        hintText: activeReply != null
                            ? 'Reply to ${activeReply.replyToHandle}...'
                            : (cleanHandle != null
                                ? 'Add a comment for $cleanHandle...'
                                : 'Write a studio comment...'),
                        hintStyle: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondaryOf(context),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  key: const Key('comment_send_btn'),
                  onTap: onSubmit,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: AppColors.brandPrimary,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: PhosphorIcon(
                            PhosphorIconsBold.arrowUp,
                            color: AppColors.brandContrast,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

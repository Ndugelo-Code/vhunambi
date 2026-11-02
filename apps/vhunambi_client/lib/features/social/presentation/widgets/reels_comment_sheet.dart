import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/published_clip.dart';
import '../../domain/models/reel_comment.dart';
import '../providers/reels_comments_provider.dart';

/// TikTok-style comment sheet for a kinetic reel (REQ-COM-01 / REQ-COM-02).
///
/// Renders the clip's comment thread, honest "loved Nx" community badges,
/// cultural reaction chips, and an optimistic composer.
class ReelsCommentSheet extends ConsumerStatefulWidget {
  final PublishedClip clip;
  const ReelsCommentSheet({super.key, required this.clip});

  static Future<void> show(
    BuildContext context, {
    required PublishedClip clip,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReelsCommentSheet(clip: clip),
    );
  }

  @override
  ConsumerState<ReelsCommentSheet> createState() => _ReelsCommentSheetState();
}

class _ReelsCommentSheetState extends ConsumerState<ReelsCommentSheet> {
  final TextEditingController _controller = TextEditingController();

  static const List<String> _emojis = ['🔥', '👑', '🇿🇦', '🎹', '🐐', '❤️'];
  static const List<String> _praise = [
    'Hits different! 🎹',
    'Makhado sunrise 🌅',
    'Top tier production 🔥',
    'Proudly SA 🇿🇦',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _insert(String text) {
    final current = _controller.text;
    _controller.text = current.isEmpty ? text : '$current $text';
    _controller.selection =
        TextSelection.collapsed(offset: _controller.text.length);
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.mediumImpact();
    ref.read(reelsCommentsProvider.notifier).addComment(
          clipId: widget.clip.id,
          text: text,
          userReelLoves: widget.clip.userReactionCount,
        );
    _controller.clear();
    FocusScope.of(context).unfocus();
  }

  ReelComment? _topSupporter(List<ReelComment> comments) {
    ReelComment? top;
    for (final c in comments) {
      if (top == null || c.userReelLoves > top.userReelLoves) top = c;
    }
    return (top != null && top.userReelLoves >= 3) ? top : null;
  }

  @override
  Widget build(BuildContext context) {
    final comments = ref.watch(clipCommentsFamilyProvider(widget.clip.id));
    final media = MediaQuery.of(context);
    final topSupporter = _topSupporter(comments);

    return Container(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.75),
      decoration: BoxDecoration(
        color: AppColors.surfaceModal,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderSubtle,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm, AppSpacing.xs, AppSpacing.xs),
            child: Row(
              children: [
                Text('Comments (${comments.length})',
                    style: AppTypography.titleMedium
                        .copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  key: const Key('comment_sheet_close'),
                  icon: Icon(Icons.close_rounded,
                      color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          if (topSupporter != null)
            _SupporterBanner(comment: topSupporter),
          Flexible(
            child: comments.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Text('Be the first to comment!',
                        style: AppTypography.bodyMuted),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                    itemCount: comments.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) => _CommentTile(
                      comment: comments[i],
                      onLike: () {
                        HapticFeedback.lightImpact();
                        ref
                            .read(reelsCommentsProvider.notifier)
                            .toggleCommentLike(
                              clipId: widget.clip.id,
                              commentId: comments[i].id,
                            );
                      },
                    ),
                  ),
          ),
          _ReactionRow(
            emojis: _emojis,
            praise: _praise,
            onInsert: _insert,
          ),
          _Composer(
            controller: _controller,
            hint: 'Add a comment for @${widget.clip.creatorUsername}...',
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }
}


class _SupporterBanner extends StatelessWidget {
  final ReelComment comment;
  const _SupporterBanner({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.inputBorder,
        border: Border.all(color: AppColors.coinGold.withAlpha(90)),
      ),
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Honest Community: @${comment.username} loved this reel ${comment.userReelLoves}x ❤️',
              style: AppTypography.caption.copyWith(
                  color: AppColors.coinGold, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final ReelComment comment;
  final VoidCallback onLike;
  const _CommentTile({required this.comment, required this.onLike});

  @override
  Widget build(BuildContext context) {
    final initial = comment.displayName.isNotEmpty
        ? comment.displayName[0].toUpperCase()
        : '?';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.surfaceSecondary,
          child: Text(initial,
              style: AppTypography.caption.copyWith(
                  color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                children: [
                  Text('@${comment.username}',
                      style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600)),
                  if (comment.isCreator)
                    const _Badge(label: 'Creator', color: AppColors.brandPrimary),
                  if (comment.userReelLoves >= 3)
                    _Badge(
                        label: 'Loved ${comment.userReelLoves}x ❤️',
                        color: AppColors.coinGold),
                  Text(comment.timeAgo,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textTertiary)),
                ],
              ),
              const SizedBox(height: 3),
              Text(comment.text, style: AppTypography.bodySmall),
              const SizedBox(height: 3),
              Text('Reply',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textTertiary)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          children: [
            IconButton(
              key: ValueKey('comment_like_${comment.id}'),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: onLike,
              icon: Icon(
                comment.isLikedByMe
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                size: 16,
                color: comment.isLikedByMe
                    ? AppColors.brandPrimary
                    : AppColors.textTertiary,
              ),
            ),
            Text('${comment.likeCount}',
                style: AppTypography.caption
                    .copyWith(color: AppColors.textTertiary, fontSize: 10)),
          ],
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: AppRadius.pillBorder,
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ReactionRow extends StatelessWidget {
  final List<String> emojis;
  final List<String> praise;
  final ValueChanged<String> onInsert;
  const _ReactionRow(
      {required this.emojis, required this.praise, required this.onInsert});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        children: [
          for (final emoji in emojis)
            _ReactionChip(label: emoji, onTap: () => onInsert(emoji)),
          const SizedBox(width: 6),
          for (final phrase in praise)
            _ReactionChip(label: phrase, onTap: () => onInsert(phrase)),
        ],
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ReactionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: AppRadius.pillBorder,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceSecondary,
            borderRadius: AppRadius.pillBorder,
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Text(label,
              style:
                  AppTypography.caption.copyWith(color: AppColors.textPrimary)),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final VoidCallback onSubmit;
  const _Composer(
      {required this.controller, required this.hint, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.xs,
        bottom: bottomInset + 12,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('comment_input'),
              controller: controller,
              style: AppTypography.bodySmall,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSubmit(),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppTypography.caption
                    .copyWith(color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.surfaceSecondary,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: const OutlineInputBorder(
                  borderRadius: AppRadius.pillBorder,
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          GestureDetector(
            key: const Key('comment_send_btn'),
            onTap: onSubmit,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.brandPrimary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_upward_rounded,
                  color: AppColors.brandContrast, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

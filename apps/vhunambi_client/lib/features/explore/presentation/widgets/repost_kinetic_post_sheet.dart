import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/social_music_post.dart';
import '../providers/explore_providers.dart';
import 'kinetic_post_sonic_pill.dart';

/// Modal sheet for Reposting / Quote-Posting a Kinetic Post (REQ-KPOST-REPOST-01).
/// Enforces immutable audio locking while allowing optional user commentary.
class RepostKineticPostSheet extends ConsumerStatefulWidget {
  final SocialMusicPost originalPost;

  const RepostKineticPostSheet({super.key, required this.originalPost});

  static Future<void> show(
    BuildContext context, {
    required SocialMusicPost originalPost,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RepostKineticPostSheet(originalPost: originalPost),
    );
  }

  @override
  ConsumerState<RepostKineticPostSheet> createState() =>
      _RepostKineticPostSheetState();
}

class _RepostKineticPostSheetState
    extends ConsumerState<RepostKineticPostSheet> {
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submitRepost() {
    HapticFeedback.mediumImpact();
    final quote = _commentController.text.trim();
    final now = DateTime.now();

    final repost = SocialMusicPost(
      id: 'kpost_repost_${now.millisecondsSinceEpoch}',
      creatorId: 'current_user',
      creatorName: 'You',
      creatorHandle: '@current_user',
      publishedAt: now,
      caption: quote,
      quoteComment: quote.isNotEmpty ? quote : null,
      repostedFromPostId: widget.originalPost.id,
      repostedFromCreatorHandle: widget.originalPost.creatorHandle,
      track: widget.originalPost.track,
      imageAttachment: widget.originalPost.imageAttachment,
      imageAttachments: widget.originalPost.imageAttachments,
      audioAttachment: widget.originalPost.audioAttachment,
      location: 'South Africa',
    );

    ref.read(socialFeedPostsProvider.notifier).repostPost(
          originalPostId: widget.originalPost.id,
          repostPost: repost,
        );

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Reposted ${widget.originalPost.creatorHandle}\'s post!',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.brandPrimary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.borderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            children: [
              const PhosphorIcon(
                PhosphorIconsRegular.repeat,
                color: AppColors.brandPrimary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Repost to Feed',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const PhosphorIcon(PhosphorIconsRegular.x, size: 20),
                color: AppColors.textSecondary,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),

          // Quote commentary input
          TextField(
            key: const Key('kpost_quote_comment_input'),
            controller: _commentController,
            maxLines: 3,
            minLines: 1,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Add your thoughts or quote (optional)...',
              hintStyle: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              filled: true,
              fillColor: AppColors.surfaceSecondary,
              border: OutlineInputBorder(
                borderRadius: AppRadius.cardBorder,
                borderSide: BorderSide(color: AppColors.borderSubtle),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.cardBorder,
                borderSide: BorderSide(color: AppColors.borderSubtle),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.cardBorder,
                borderSide: const BorderSide(color: AppColors.brandPrimary),
              ),
              contentPadding: const EdgeInsets.all(AppSpacing.sm),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Original Post Preview Card with Locked Audio Attribution
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              borderRadius: AppRadius.cardBorder,
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: AppColors.surfaceElevated,
                      child: Text(
                        widget.originalPost.creatorName.isNotEmpty
                            ? widget.originalPost.creatorName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.brandPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.originalPost.creatorHandle,
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.brandPrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const PhosphorIcon(
                            PhosphorIconsRegular.lockKey,
                            size: 11,
                            color: AppColors.brandPrimary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Original Sound',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.brandPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (widget.originalPost.caption.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    widget.originalPost.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                KineticPostSonicPill(
                  post: widget.originalPost,
                  isOverlay: false,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Submit Repost Button
          ElevatedButton.icon(
            key: const Key('kpost_submit_repost_btn'),
            onPressed: _submitRepost,
            icon: const PhosphorIcon(
              PhosphorIconsBold.repeat,
              size: 18,
              color: AppColors.brandContrast,
            ),
            label: Text(
              'Repost Now',
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.brandContrast,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: AppColors.brandContrast,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.pillBorder,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


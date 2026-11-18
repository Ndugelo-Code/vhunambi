import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/published_clip.dart';
import '../providers/reels_comments_provider.dart';
import 'threaded_comments_section.dart';

/// Modal bottom comment sheet for kinetic reels (`REQ-COM-01`, `REQ-P69-THREAD-01..05`).
///
/// Shares [ThreadedCommentsSection] and [StudioReactionComposerBar] with
/// `KineticPostFocusView` for 100% unified nested reply threading, relevance sorting,
/// and `STD-UIUX-001` Phosphor studio reaction chips.
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
  final FocusNode _composerFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(reelsCommentsProvider.notifier)
          .syncCommentsForClip(widget.clip.id);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _composerFocusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.mediumImpact();
    ref.read(reelsCommentsProvider.notifier).addComment(
          clipId: widget.clip.id,
          text: text,
          userReelLoves: widget.clip.userReactionCount,
          contentCreatorId: widget.clip.creatorId,
          contentCreatorHandle: '@${widget.clip.creatorUsername}',
        );
    _controller.clear();
    _composerFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Container(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.78),
      decoration: BoxDecoration(
        color: AppColors.surfaceModalOf(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderSubtleOf(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.xs,
              0,
            ),
            child: Row(
              children: [
                Text(
                  '@${widget.clip.creatorUsername} · Discussion',
                  style: AppTypography.titleSmall.copyWith(
                    color: AppColors.textPrimaryOf(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  key: const Key('comment_sheet_close'),
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  icon: PhosphorIcon(
                    AppIcons.close,
                    color: AppColors.textSecondaryOf(context),
                    size: 20,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: ThreadedCommentsSection(
                clipOrPostId: widget.clip.id,
                contentCreatorId: widget.clip.creatorId,
                contentCreatorHandle: '@${widget.clip.creatorUsername}',
                onRequestReplyFocus: () => _composerFocusNode.requestFocus(),
              ),
            ),
          ),
          StudioReactionComposerBar(
            clipOrPostId: widget.clip.id,
            creatorHandle: '@${widget.clip.creatorUsername}',
            controller: _controller,
            focusNode: _composerFocusNode,
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }
}

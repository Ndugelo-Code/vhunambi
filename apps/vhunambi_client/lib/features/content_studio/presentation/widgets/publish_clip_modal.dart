import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/content_studio_provider.dart';
import '../../../social/domain/models/published_clip.dart';
import '../../../social/presentation/providers/stem_remix_provider.dart';

/// In-house "Publish to Profile" dialog (REQ-SOC-01 / REQ-SOC-02 / Phase D).
///
/// Captures the caption, hashtags, and visibility for a freshly rendered
/// clip, carries forward viral remix lineage if [stemRemixProvider] is active,
/// then hands off to `ContentStudioNotifier.publishClipToProfile`, which
/// optimistically injects the clip into the social feed (REQ-SOC-04) — no MP4
/// upload required (REQ-SOC-26).
class PublishClipModal extends ConsumerStatefulWidget {
  const PublishClipModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PublishClipModal(),
    );
  }

  @override
  ConsumerState<PublishClipModal> createState() => _PublishClipModalState();
}

class _PublishClipModalState extends ConsumerState<PublishClipModal> {
  static const int _maxCaption = 140;
  static const List<String> _tagSuggestions = [
    'Amapiano',
    'Tshivenḓa',
    'AfroHouse',
    'Gqom',
    'Vocal',
    'Chill',
  ];

  final TextEditingController _captionController = TextEditingController();
  final Set<String> _selectedTags = <String>{};
  ClipVisibility _visibility = ClipVisibility.public;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  void _toggleTag(String tag) {
    setState(() {
      if (!_selectedTags.add(tag)) {
        _selectedTags.remove(tag);
      }
    });
  }

  void _publish() {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final remixContext = ref.read(stemRemixProvider);

    final clip = ref.read(contentStudioProvider.notifier).publishClipToProfile(
          caption: _captionController.text.trim(),
          tags: _selectedTags.toList(),
          visibility: _visibility,
          remixedFromClipId: remixContext?.parentClipId,
          remixAttribution: remixContext?.attributionLineage,
        );

    if (clip == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Finish rendering your clip before publishing.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (remixContext != null) {
      ref.read(stemRemixProvider.notifier).clearRemix();
    }

    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          remixContext != null
              ? 'Remix published with attribution! 🔁 ${clip.shareUrl}'
              : 'Published to your profile! ${clip.shareUrl}',
        ),
        backgroundColor: AppColors.brandPrimary,
        action: SnackBarAction(
          label: 'COPY',
          textColor: AppColors.brandContrast,
          onPressed: () =>
              Clipboard.setData(ClipboardData(text: clip.shareUrl)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(contentStudioProvider);
    final remixContext = ref.watch(stemRemixProvider);
    final genre = state.dna?.genre ?? 'Amapiano';
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceModal,
        borderRadius: AppRadius.modalBorder,
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.md,
        bottom: AppSpacing.md + viewInsets,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Publish to Vhunambi Profile', style: AppTypography.titleLarge),
              IconButton(
                key: const Key('publish_modal_close'),
                icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          if (remixContext != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: AppColors.badgeCyan.withAlpha(30),
                borderRadius: AppRadius.pillBorder,
                border: Border.all(color: AppColors.badgeCyan.withAlpha(80)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.alt_route_rounded,
                    size: 14,
                    color: AppColors.badgeCyan,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Remixing @${remixContext.parentCreatorUsername}\'s "${remixContext.parentTrackTitle}"',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.badgeCyan,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildThumbnail(state.coverArtUrl, genre),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      key: const Key('publish_caption_field'),
                      controller: _captionController,
                      maxLength: _maxCaption,
                      maxLines: 3,
                      minLines: 2,
                      style: AppTypography.bodyLarge,
                      decoration: InputDecoration(
                        hintText: "What's this song about?",
                        hintStyle: AppTypography.bodyMuted,
                        filled: true,
                        fillColor: AppColors.surfaceSecondary,
                        border: const OutlineInputBorder(
                          borderRadius: AppRadius.inputBorder,
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _buildTagSelector(),
                    const SizedBox(height: AppSpacing.sm),
                    _buildVisibilitySelector(),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  key: const Key('publish_reel_btn'),
                  onPressed: _publish,
                  icon: const Icon(Icons.rocket_launch_rounded,
                      color: AppColors.brandContrast, size: 18),
                  label: Text(
                    'Publish Reel',
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.brandContrast,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    minimumSize: const Size.fromHeight(48),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.inputBorder,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(String? coverUrl, String genre) {
    return ClipRRect(
      borderRadius: AppRadius.inputBorder,
      child: Container(
        width: 88,
        height: 88 * 16 / 9,
        decoration: BoxDecoration(gradient: AppGradients.forGenre(genre)),
        child: coverUrl == null
            ? const Icon(Icons.music_note_rounded,
                color: AppColors.textPrimary, size: 32)
            : Image.network(
                coverUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.music_note_rounded,
                  color: AppColors.textPrimary,
                  size: 32,
                ),
              ),
      ),
    );
  }

  Widget _buildTagSelector() {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final tag in _tagSuggestions)
          _ChoicePill(
            label: '#$tag',
            selected: _selectedTags.contains(tag),
            onTap: () => _toggleTag(tag),
          ),
      ],
    );
  }

  Widget _buildVisibilitySelector() {
    return Row(
      children: [
        Expanded(
          child: _ChoicePill(
            label: 'Public',
            icon: Icons.public_rounded,
            selected: _visibility == ClipVisibility.public,
            onTap: () => setState(() => _visibility = ClipVisibility.public),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _ChoicePill(
            label: 'Followers',
            icon: Icons.lock_outline_rounded,
            selected: _visibility == ClipVisibility.followers,
            onTap: () =>
                setState(() => _visibility = ClipVisibility.followers),
          ),
        ),
      ],
    );
  }
}

class _ChoicePill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.pillBorder,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandPrimary : AppColors.surfaceSecondary,
          borderRadius: AppRadius.pillBorder,
          border: Border.all(
            color: selected ? AppColors.brandPrimary : AppColors.borderSubtle,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: selected
                    ? AppColors.brandContrast
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: selected
                    ? AppColors.brandContrast
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/vhunambi_track_artwork.dart';
import '../../../../shared/models/track.dart';
import '../../../explore/domain/models/social_music_post.dart';
import '../../../explore/presentation/providers/explore_providers.dart';
import '../../../social/domain/models/published_clip.dart';
import '../../../social/presentation/providers/stem_remix_provider.dart';
import '../providers/content_studio_provider.dart';

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
  bool _alsoShareToExplore = false;

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

    final clip = ref
        .read(contentStudioProvider.notifier)
        .publishClipToProfile(
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

    // Opt-in ONLY — never auto-inject promotional feed copy into Explore Feed (REQ-P74-STU-05)
    if (_alsoShareToExplore) {
      ref
          .read(socialFeedPostsProvider.notifier)
          .addPost(
            SocialMusicPost(
              id: 'post_${clip.id}',
              creatorId: clip.creatorId,
              creatorName: clip.creatorDisplayName,
              creatorHandle: '@${clip.creatorUsername}',
              creatorAvatarUrl: clip.creatorAvatarUrl,
              isCreatorVerified: clip.isCreatorVerified,
              publishedAt: clip.publishedAt,
              location: 'South Africa',
              caption: clip.caption.isNotEmpty ? clip.caption : clip.title,
              track: Track(
                id: clip.trackId,
                title: clip.title,
                creatorName: clip.creatorDisplayName,
                creatorHandle: '@${clip.creatorUsername}',
                genre: clip.genre,
                duration: Duration(seconds: clip.dna.musical.durationSec),
                audioUrl: clip.audioUrl,
                coverUrl: clip.coverUrl,
                isNew: true,
              ),
              likeCount: 0,
              commentCount: 0,
              remixCount: 0,
              tipCountCoins: 0,
              isFollowingCreator: false,
            ),
          );
    }

    if (remixContext != null) {
      ref.read(stemRemixProvider.notifier).clearRemix();
    }

    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            remixContext != null
                ? 'Remix published with attribution!'
                : 'Published to your profile!',
          ),
          backgroundColor: AppColors.brandPrimary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 2500),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(contentStudioProvider);
    final remixContext = ref.watch(stemRemixProvider);
    final genre = state.dna?.genre ?? 'Amapiano';
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;

    return Material(
      color: AppColors.surfaceModal,
      borderRadius: AppRadius.modalBorder,
      child: SingleChildScrollView(
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
              Text(
                'Publish to Vhunambi Profile',
                style: AppTypography.titleLarge,
              ),
              IconButton(
                key: const Key('publish_modal_close'),
                icon: PhosphorIcon(
                  AppIcons.close,
                  color: AppColors.textSecondary,
                ),
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
                  const PhosphorIcon(
                    PhosphorIconsRegular.gitFork,
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
                        hintText:
                            'Describe this reel or credit collaborators...',
                        hintStyle: AppTypography.bodyLarge.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: AppRadius.inputBorder,
                          borderSide: BorderSide(color: AppColors.borderSubtle),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: AppRadius.inputBorder,
                          borderSide: BorderSide(
                            color: AppColors.textPrimaryOf(
                              context,
                            ).withValues(alpha: 0.22),
                            width: 1.0,
                          ),
                        ),
                        contentPadding: const EdgeInsets.all(AppSpacing.sm),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _buildTagSelector(),
                    const SizedBox(height: AppSpacing.sm),
                    _buildVisibilitySelector(),
                    SwitchListTile(
                      key: const Key('publish_modal_share_to_explore_switch'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(
                        'Also share to Explore Feed',
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      value: _alsoShareToExplore,
                      onChanged: (v) => setState(() => _alsoShareToExplore = v),
                    ),
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
                  icon: const PhosphorIcon(
                    AppIcons.upload,
                    color: AppColors.brandContrast,
                    size: 18,
                  ),
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
      ),
    );
  }

  Widget _buildThumbnail(String? coverUrl, String genre) {
    return VhunambiTrackArtwork(
      coverUrl: coverUrl,
      genre: genre,
      width: 88,
      height: 88 * 16 / 9,
      borderRadius: AppRadius.inputBorder,
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
            icon: PhosphorIconsRegular.globe,
            selected: _visibility == ClipVisibility.public,
            onTap: () => setState(() => _visibility = ClipVisibility.public),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _ChoicePill(
            label: 'Followers',
            icon: PhosphorIconsRegular.lockSimple,
            selected: _visibility == ClipVisibility.followers,
            onTap: () => setState(() => _visibility = ClipVisibility.followers),
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
              PhosphorIcon(
                icon!,
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

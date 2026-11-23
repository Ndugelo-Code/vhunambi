import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/design_system/tokens/app_icons.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/core/utils/responsive_utils.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_bottom_dock_kit.dart';
import 'package:vhunambi_client/features/content_studio/presentation/views/kinetic_reel_studio_view.dart';
import 'package:vhunambi_client/features/library/domain/models/library_models.dart';
import 'package:vhunambi_client/features/library/presentation/providers/library_providers.dart';
import 'package:vhunambi_client/features/library/presentation/widgets/library_empty_state.dart';
import 'package:vhunambi_client/features/player/presentation/providers/player_provider.dart';
import 'package:vhunambi_client/features/social/domain/models/published_clip.dart';
import 'package:vhunambi_client/features/social/presentation/providers/social_feed_provider.dart';
import 'package:vhunambi_client/features/social/presentation/widgets/creator_reel_thumbnail_card.dart';
import 'package:vhunambi_client/features/social/presentation/widgets/kinetic_reels_modal.dart';

/// Creator's published Kinetic Reels hub inside Library Asset Vault (`EP-P78-CREATOR-REELS-HUB`).
class ReelsVaultView extends ConsumerWidget {
  final VoidCallback? onCreateRequested;

  const ReelsVaultView({super.key, this.onCreateRequested});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clips = ref.watch(ownerVaultReelsProvider);
    final query = ref.watch(librarySearchQueryProvider);
    final hasActiveTrack = ref.watch(
      playerStateProvider.select((s) => s.hasActiveTrack),
    );
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final crossAxisCount = isDesktop ? 4 : 2;
    final bottomInset = VhunambiBottomDockMetrics.scrollInset(
      hasActiveTrack: hasActiveTrack,
    );

    if (clips.isEmpty) {
      return LibraryEmptyState(
        key: const Key('library_reels_vault_view'),
        category: LibraryCategory.reels,
        searchQuery: query,
        onCreateRequested: () => KineticReelStudioView.show(context),
      );
    }

    return Padding(
      key: const Key('library_reels_vault_view'),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                Text(
                  '${clips.length} Published ${clips.length == 1 ? 'Reel' : 'Reels'}',
                  style: AppTypography.bodySmall.copyWith(
                    color: textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: FilledButton.icon(
                    key: const Key('library_reels_create_btn'),
                    onPressed: () => KineticReelStudioView.show(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      foregroundColor: AppColors.brandContrast,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.pillBorder,
                      ),
                    ),
                    icon: const PhosphorIcon(AppIcons.reels, size: 16),
                    label: Text(
                      'Create Reel',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.brandContrast,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.only(bottom: bottomInset),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: AppSpacing.sm,
                mainAxisSpacing: AppSpacing.sm,
                childAspectRatio: 9 / 16,
              ),
              itemCount: clips.length,
              itemBuilder: (context, index) {
                final clip = clips[index];
                return _VaultReelTile(
                  clip: clip,
                  allClips: clips,
                  textPrimary: textPrimary,
                  onShare: () {
                    Clipboard.setData(ClipboardData(text: clip.shareUrl));
                    ScaffoldMessenger.maybeOf(context)
                      ?..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          content: Text('Share link copied for "${clip.title}"'),
                          backgroundColor: AppColors.brandPrimary,
                        ),
                      );
                  },
                  onDelete: () {
                    ref.read(socialFeedProvider.notifier).deleteClip(clip.id);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _VaultReelTile extends StatelessWidget {
  final PublishedClip clip;
  final List<PublishedClip> allClips;
  final Color textPrimary;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  const _VaultReelTile({
    required this.clip,
    required this.allClips,
    required this.textPrimary,
    required this.onShare,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CreatorReelThumbnailCard(
          clip: clip,
          onTap: () => KineticReelsModal.show(
            context,
            clips: allClips,
            initialClipId: clip.id,
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TinyActionButton(
                tooltip: 'Share Reel',
                icon: AppIcons.share,
                onTap: onShare,
              ),
              const SizedBox(width: 4),
              _TinyActionButton(
                tooltip: 'Remove Reel',
                icon: AppIcons.trash,
                onTap: onDelete,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TinyActionButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  const _TinyActionButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.56),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 32,
            height: 32,
            child: Center(
              child: PhosphorIcon(icon, size: 15, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/vhunambi_glass_surface.dart';
import '../../domain/models/library_models.dart';
import '../providers/library_providers.dart';

/// Universal vault empty state (`REQ-LIB-03`, `STD-UIUX-001`).
class LibraryEmptyState extends ConsumerWidget {
  final LibraryCategory category;
  final String searchQuery;
  final VoidCallback? onCreateRequested;

  const LibraryEmptyState({
    super.key,
    required this.category,
    this.searchQuery = '',
    this.onCreateRequested,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = searchQuery.trim();
    final copy = query.isEmpty
        ? _EmptyStateCopy.forCategory(category)
        : _EmptyStateCopy.forSearch(query);

    void handleCtaTap() {
      if (query.isNotEmpty) {
        ref.read(librarySearchQueryProvider.notifier).state = '';
        return;
      }
      if (category == LibraryCategory.trash) {
        ref.read(libraryCategoryProvider.notifier).state = LibraryCategory.songs;
        return;
      }
      onCreateRequested?.call();
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: VhunambiGlassSurface(
            variant: VhunambiGlassVariant.card,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondaryOf(context),
                    borderRadius: AppRadius.squircleBorder,
                    border: Border.all(color: AppColors.borderSubtleOf(context)),
                  ),
                  child: Center(
                    child: PhosphorIcon(
                      copy.icon,
                      size: 22,
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  copy.headline,
                  textAlign: TextAlign.center,
                  style: AppTypography.titleLarge.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  copy.description,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMuted.copyWith(
                    height: 1.5,
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                ElevatedButton(
                  onPressed: handleCtaTap,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: AppColors.brandContrast,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.pillBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PhosphorIcon(
                        copy.ctaIcon,
                        size: 18,
                        color: AppColors.brandContrast,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          copy.ctaLabel,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyLarge.copyWith(
                            color: AppColors.brandContrast,
                            fontWeight: FontWeight.bold,
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
      ),
    );
  }
}

class _EmptyStateCopy {
  final IconData icon;
  final String headline;
  final String description;
  final String ctaLabel;
  final IconData ctaIcon;

  const _EmptyStateCopy({
    required this.icon,
    required this.headline,
    required this.description,
    required this.ctaLabel,
    required this.ctaIcon,
  });

  factory _EmptyStateCopy.forCategory(LibraryCategory category) {
    return switch (category) {
      LibraryCategory.songs => const _EmptyStateCopy(
          icon: AppIcons.songs,
          headline: 'No songs yet',
          description:
              "Head to the Studio and generate your first song — it'll appear here instantly.",
          ctaLabel: 'Create your first song',
          ctaIcon: PhosphorIconsRegular.sparkle,
        ),
      LibraryCategory.reels => const _EmptyStateCopy(
          icon: AppIcons.reels,
          headline: 'No reels yet',
          description:
              'Record or craft a 9:16 Kinetic Reel in Studio — it will appear here and on Explore.',
          ctaLabel: 'Create your first reel',
          ctaIcon: AppIcons.reels,
        ),
      LibraryCategory.playlists => const _EmptyStateCopy(
          icon: PhosphorIconsRegular.queue,
          headline: 'No playlists yet',
          description:
              'Group your favourite tracks into playlists for every mood, session and stage.',
          ctaLabel: 'Create your first playlist',
          ctaIcon: PhosphorIconsRegular.sparkle,
        ),
      LibraryCategory.collections => const _EmptyStateCopy(
          icon: PhosphorIconsRegular.disc,
          headline: 'No collections yet',
          description:
              'Bundle your tracks into EPs, albums and concept projects with unified artwork.',
          ctaLabel: 'Start a collection',
          ctaIcon: PhosphorIconsRegular.sparkle,
        ),
      LibraryCategory.beats => const _EmptyStateCopy(
          icon: PhosphorIconsRegular.shoppingBag,
          headline: 'No beats yet',
          description:
              'Generate an instrumental beat in the Studio — it will land here, ready to license.',
          ctaLabel: 'Create your first beat',
          ctaIcon: PhosphorIconsRegular.sparkle,
        ),
      LibraryCategory.licensing => const _EmptyStateCopy(
          icon: PhosphorIconsRegular.scales,
          headline: 'No licenses yet',
          description:
              'Commercial certificates and split sheets appear here after your first release.',
          ctaLabel: 'Create your first song',
          ctaIcon: PhosphorIconsRegular.sparkle,
        ),
      LibraryCategory.trash => const _EmptyStateCopy(
          icon: AppIcons.trash,
          headline: 'Trash is empty',
          description:
              'Deleted assets stay here for 30 days before they are permanently wiped.',
          ctaLabel: 'Back to Songs',
          ctaIcon: AppIcons.caretLeft,
        ),
    };
  }

  factory _EmptyStateCopy.forSearch(String query) {
    return _EmptyStateCopy(
      icon: PhosphorIconsRegular.magnifyingGlassMinus,
      headline: 'No matches for "$query"',
      description: 'Try a different title, creator, genre or language.',
      ctaLabel: 'Clear search',
      ctaIcon: PhosphorIconsRegular.x,
    );
  }
}

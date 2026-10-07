import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/library_models.dart';
import '../providers/library_providers.dart';

/// Universal vault empty state (REQ-LIB-03 / Blueprint 04 §3.1).
///
/// Renders a 48x48 squircle glyph container, a category headline, muted helper
/// copy, and a solid orange pill call-to-action.
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Squircle glyph container
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: AppRadius.squircleBorder,
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Icon(copy.icon, size: 22, color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.md),

              // Headline
              Text(
                copy.headline,
                textAlign: TextAlign.center,
                style: AppTypography.titleLarge.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),

              // Helper copy
              Text(
                copy.description,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMuted.copyWith(height: 1.5),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Primary CTA
              ElevatedButton(
                onPressed: handleCtaTap,
                style: ElevatedButton.styleFrom(
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
                    Icon(copy.ctaIcon, size: 18, color: AppColors.brandContrast),
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
          icon: Icons.music_note_rounded,
          headline: 'No songs yet',
          description:
              "Head to the Studio and generate your first song — it'll appear here instantly.",
          ctaLabel: 'Create your first song',
          ctaIcon: Icons.auto_awesome,
        ),
      LibraryCategory.playlists => const _EmptyStateCopy(
          icon: Icons.queue_music_rounded,
          headline: 'No playlists yet',
          description:
              'Group your favourite tracks into playlists for every mood, session and stage.',
          ctaLabel: 'Create your first playlist',
          ctaIcon: Icons.auto_awesome,
        ),
      LibraryCategory.collections => const _EmptyStateCopy(
          icon: Icons.album_outlined,
          headline: 'No collections yet',
          description:
              'Bundle your tracks into EPs, albums and concept projects with unified artwork.',
          ctaLabel: 'Start a collection',
          ctaIcon: Icons.auto_awesome,
        ),
      LibraryCategory.beats => const _EmptyStateCopy(
          icon: Icons.shopping_bag_outlined,
          headline: 'No beats yet',
          description:
              'Generate an instrumental beat in the Studio — it will land here, ready to license.',
          ctaLabel: 'Create your first beat',
          ctaIcon: Icons.auto_awesome,
        ),
      LibraryCategory.licensing => const _EmptyStateCopy(
          icon: Icons.balance_rounded,
          headline: 'No licenses yet',
          description:
              'Commercial certificates and split sheets appear here after your first release.',
          ctaLabel: 'Create your first song',
          ctaIcon: Icons.auto_awesome,
        ),
      LibraryCategory.trash => const _EmptyStateCopy(
          icon: Icons.delete_outline_rounded,
          headline: 'Trash is empty',
          description:
              'Deleted assets stay here for 30 days before they are permanently wiped.',
          ctaLabel: 'Back to Songs',
          ctaIcon: Icons.arrow_back_rounded,
        ),
    };
  }

  factory _EmptyStateCopy.forSearch(String query) {
    return _EmptyStateCopy(
      icon: Icons.search_off_rounded,
      headline: 'No matches for "$query"',
      description: 'Try a different title, creator, genre or language.',
      ctaLabel: 'Clear search',
      ctaIcon: Icons.close_rounded,
    );
  }
}

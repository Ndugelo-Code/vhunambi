import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/explore_providers.dart';
import 'genre_glyph.dart';

/// Genre radio tile with a centered glassmorphic `((•)) Play Radio` overlay
/// (REQ-EXP-07 / Blueprint 01 §5 Section E).
class GenreRadioTile extends ConsumerWidget {
  final String genre;

  const GenreRadioTile({super.key, required this.genre});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void handlePlayRadio() {
      final queued = playExploreGenreRadio(ref, genre);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceModal,
          duration: const Duration(seconds: 3),
          content: Row(
            children: [
              const Icon(
                Icons.radio_rounded,
                size: 18,
                color: AppColors.brandPrimary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  queued.isEmpty
                      ? 'No $genre tracks in the catalog yet.'
                      : 'Playing $genre radio — ${queued.length} tracks queued.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: handlePlayRadio,
      borderRadius: AppRadius.cardBorder,
      child: Container(
        decoration: BoxDecoration(
          gradient: AppGradients.forGenre(genre),
          borderRadius: AppRadius.cardBorder,
        ),
        child: Stack(
          children: [
            // Genre label + heritage glyph
            Positioned(
              top: AppSpacing.xs,
              left: AppSpacing.sm,
              right: AppSpacing.sm,
              child: Row(
                children: [
                  Icon(
                    exploreGenreGlyph(genre),
                    size: 14,
                    color: AppColors.textPrimary.withAlpha(230),
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  Flexible(
                    child: Text(
                      genre,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Glassmorphic Play Radio overlay
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCanvas.withAlpha(153),
                  borderRadius: AppRadius.pillBorder,
                  border: Border.all(
                    color: AppColors.textPrimary.withAlpha(51),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.radio_button_checked_rounded,
                      size: 13,
                      color: AppColors.textPrimary,
                    ),
                    const SizedBox(width: AppSpacing.xxs + 2),
                    Flexible(
                      child: Text(
                        '((•)) Play Radio',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.badge.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

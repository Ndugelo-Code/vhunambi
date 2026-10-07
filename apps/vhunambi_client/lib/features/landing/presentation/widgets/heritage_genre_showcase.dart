import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/landing_models.dart';
import '../providers/landing_providers.dart';

/// Heritage genre showcase with regional tabs and audition playback
/// (REQ-MKT-09).
class HeritageGenreShowcase extends ConsumerWidget {
  static const String title = 'Every Sound on Earth';
  static const String subtitle =
      'Tap a genre to audition an authentic African production.';

  const HeritageGenreShowcase({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeRegion = ref.watch(landingRegionProvider);
    final activeGenre = ref.watch(landingShowcaseGenreProvider);
    final genres = ref.watch(filteredLandingGenresProvider);

    void audition(String genre) {
      final messenger = ScaffoldMessenger.of(context);
      final preview = auditionGenrePreview(ref, genre);
      ref.read(landingShowcaseGenreProvider.notifier).state = genre;

      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceModal,
          duration: const Duration(seconds: 3),
          content: Text(
            preview == null
                ? 'No $genre preview in the marketplace yet — explore other genres.'
                : 'Auditioning "$preview" — $genre preview.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.titleLarge),
          const SizedBox(height: AppSpacing.xxs),
          Text(subtitle, style: AppTypography.bodyMuted),
          const SizedBox(height: AppSpacing.sm),

          // Regional tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final region in landingRegionCatalog) ...[
                  InkWell(
                    onTap: () => ref.read(landingRegionProvider.notifier).state =
                        region,
                    borderRadius: AppRadius.pillBorder,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: region == activeRegion
                            ? AppColors.brandPrimary
                            : Colors.transparent,
                        borderRadius: AppRadius.pillBorder,
                      ),
                      child: Text(
                        region,
                        style: AppTypography.bodySmall.copyWith(
                          color: region == activeRegion
                              ? AppColors.brandContrast
                              : AppColors.textSecondary,
                          fontWeight: region == activeRegion
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Genre chips
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final genre in genres)
                InkWell(
                  onTap: () => audition(genre.name),
                  borderRadius: AppRadius.pillBorder,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: genre.name == activeGenre
                          ? AppColors.brandPrimary
                          : AppColors.surfaceSecondary,
                      borderRadius: AppRadius.pillBorder,
                      border: Border.all(
                        color: genre.name == activeGenre
                            ? AppColors.brandPrimary
                            : AppColors.borderSubtle,
                      ),
                    ),
                    child: Text(
                      genre.name,
                      style: AppTypography.bodySmall.copyWith(
                        fontSize: 12,
                        color: genre.name == activeGenre
                            ? AppColors.brandContrast
                            : AppColors.textSecondary,
                        fontWeight: genre.name == activeGenre
                            ? FontWeight.w700
                            : FontWeight.w500,
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
}

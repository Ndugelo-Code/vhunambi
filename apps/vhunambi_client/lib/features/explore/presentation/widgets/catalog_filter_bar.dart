import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../domain/models/explore_models.dart';
import '../providers/explore_providers.dart';
import '../../../creator_dna/domain/models/behavior_event.dart';
import '../../../creator_dna/presentation/providers/creator_dna_provider.dart';

/// Catalog filter engine: genre rail, mood chip wrap, language selector and
/// sorting pills (REQ-EXP-08 / Blueprint 01 §5 Section F).
class CatalogFilterBar extends ConsumerWidget {
  static const String sectionTitle = 'All Songs';

  const CatalogFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeGenre = ref.watch(exploreGenreFilterProvider);
    final activeMood = ref.watch(exploreMoodFilterProvider);
    final activeLanguage = ref.watch(exploreLanguageFilterProvider);
    final activeSort = ref.watch(exploreSortByProvider);
    final resultCount = ref.watch(filteredExploreTracksProvider).length;
    final query = ref.watch(exploreSearchQueryProvider);

    final hasActiveFilters =
        activeGenre != exploreAllFilter ||
            activeMood != null ||
            activeLanguage != exploreAllFilter ||
            activeSort != ExploreSortBy.newest ||
            query.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header + adaptive result count + clear action
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(sectionTitle, style: AppTypography.titleLarge),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        '$resultCount ${resultCount == 1 ? 'track' : 'tracks'}',
                        style: AppTypography.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasActiveFilters)
                InkWell(
                  onTap: () => clearExploreFilters(ref),
                  borderRadius: AppRadius.pillBorder,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: AppSpacing.xxs,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: AppColors.brandPrimary,
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        Text(
                          'Clear filters',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.brandPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),

          // 1. Genre filter pill rail
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterPill(
                  label: exploreAllFilter,
                  isActive: activeGenre == exploreAllFilter,
                  onTap: () {
                    ref.read(exploreGenreFilterProvider.notifier).state =
                        exploreAllFilter;
                    resetExploreCatalogCursor(ref);
                  },
                ),
                for (final genre in exploreGenreCatalog) ...[
                  const SizedBox(width: AppSpacing.xs),
                  _FilterPill(
                    label: genre,
                    isActive: genre == activeGenre,
                    onTap: () {
                      ref.read(exploreGenreFilterProvider.notifier).state =
                          genre;
                      resetExploreCatalogCursor(ref);
                      // T6.9: Record genre filter telemetry for Creator DNA
                      // (REQ-DNA-CAP-03). Best-effort, never blocks UI.
                      try {
                        ref.read(creatorDnaProvider.notifier).recordEvent(
                          BehaviorEvent.genreFilterTap(genre),
                        );
                      } catch (_) {}
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),

          // 2. Mood chip wrap + 3. Language selector
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final mood in exploreMoodCatalog)
                _FilterPill(
                  label: mood.label,
                  isActive: mood.value == activeMood,
                  inactiveSurface: AppColors.surfaceElevated,
                  onTap: () {
                    ref.read(exploreMoodFilterProvider.notifier).state =
                        mood.value == activeMood ? null : mood.value;
                    resetExploreCatalogCursor(ref);
                  },
                ),
              _LanguageDropdown(activeLanguage: activeLanguage),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),

          // 4. Sorting pills
          Row(
            children: [
              _FilterPill(
                label: '🔥 Newest',
                isActive: activeSort == ExploreSortBy.newest,
                onTap: () {
                  ref.read(exploreSortByProvider.notifier).state =
                      ExploreSortBy.newest;
                  resetExploreCatalogCursor(ref);
                },
              ),
              const SizedBox(width: AppSpacing.xs),
              _FilterPill(
                label: '❤️ Most Liked',
                isActive: activeSort == ExploreSortBy.mostLiked,
                onTap: () {
                  ref.read(exploreSortByProvider.notifier).state =
                      ExploreSortBy.mostLiked;
                  resetExploreCatalogCursor(ref);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Language selector covering the South African official languages.
class _LanguageDropdown extends ConsumerWidget {
  final String activeLanguage;

  const _LanguageDropdown({required this.activeLanguage});

  String get _label =>
      activeLanguage == exploreAllFilter ? 'All' : activeLanguage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFiltered = activeLanguage != exploreAllFilter;

    return PopupMenuButton<String>(
      tooltip: 'Filter by language',
      color: AppColors.surfaceModal,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.inputBorder,
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      onSelected: (value) {
        ref.read(exploreLanguageFilterProvider.notifier).state = value;
        resetExploreCatalogCursor(ref);
      },
      itemBuilder: (_) => [
        for (final language in [
          exploreAllFilter,
          ...exploreLanguageCatalog,
        ])
          PopupMenuItem<String>(
            value: language,
            height: 40,
            child: Row(
              children: [
                Icon(
                  Icons.translate_rounded,
                  size: 15,
                  color: language == activeLanguage
                      ? AppColors.brandPrimary
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    language == exploreAllFilter ? 'All languages' : language,
                    style: AppTypography.bodySmall.copyWith(
                      color: language == activeLanguage
                          ? AppColors.brandPrimary
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (language == activeLanguage)
                  const Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: AppColors.brandPrimary,
                  ),
              ],
            ),
          ),
      ],
      child: Container(
        constraints: BoxConstraints(
          minHeight: ResponsiveUtils.isMobile(context) ? 44 : 28,
        ),
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: ResponsiveUtils.isMobile(context) ? 8 : 6,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceSecondary,
          borderRadius: AppRadius.pillBorder,
          border: Border.all(
            color: isFiltered ? AppColors.brandPrimary : AppColors.borderSubtle,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.language_rounded,
              size: 14,
              color: isFiltered
                  ? AppColors.brandPrimary
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.xxs + 2),
            Text(
              'Language: $_label',
              style: AppTypography.bodySmall.copyWith(
                fontSize: 12,
                color: isFiltered
                    ? AppColors.brandPrimary
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 14,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color? inactiveSurface;

  const _FilterPill({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.inactiveSurface,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.pillBorder,
      child: Container(
        constraints: BoxConstraints(
          minHeight: isMobile ? 44 : 28,
        ),
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: isMobile ? 8 : 6,
        ),
        decoration: BoxDecoration(
          color: isActive ? AppColors.brandPrimary : (inactiveSurface ?? AppColors.surfaceSecondary),
          borderRadius: AppRadius.pillBorder,
          border: Border.all(
            color: isActive ? AppColors.brandPrimary : AppColors.borderSubtle,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            fontSize: 12,
            color: isActive ? AppColors.brandContrast : AppColors.textSecondary,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

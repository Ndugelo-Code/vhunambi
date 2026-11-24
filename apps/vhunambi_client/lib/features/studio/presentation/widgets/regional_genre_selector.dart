import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/design_system/theme/vhunambi_theme_extension.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/design_system/tokens/design_enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../core/widgets/vhunambi_glass_surface.dart';
import '../../domain/models/studio_genre_catalog.dart';
import '../providers/studio_form_provider.dart';

class RegionalGenreSelector extends ConsumerStatefulWidget {
  const RegionalGenreSelector({super.key});

  @override
  ConsumerState<RegionalGenreSelector> createState() =>
      _RegionalGenreSelectorState();
}

class _RegionalGenreSelectorState extends ConsumerState<RegionalGenreSelector> {
  bool _isExpanded = true;
  String _searchQuery = '';
  final TextEditingController _customGenreController = TextEditingController();

  static const List<String> _regions = kStudioRegions;
  static const List<StudioGenreEntry> _allGenres = kStudioGenreCatalog;

  @override
  void dispose() {
    _customGenreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeGenre = ref.watch(studioFormProvider.select((s) => s.genre));
    final activeRegion = ref.watch(studioFormProvider.select((s) => s.region));
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final genre = _mapStringToGenre(activeGenre);
    final extension = VhunambiThemeExtension.of(context);
    final accent = extension.genreAccent(genre);

    final filteredGenres = _allGenres.where((g) {
      final matchesSearch =
          g.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesRegion = _searchQuery.isNotEmpty || g.region == activeRegion;
      return matchesSearch && matchesRegion;
    }).toList();

    return VhunambiGlassSurface(
      borderRadius: AppRadius.cardBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Accordion Toggle
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: AppRadius.cardBorder,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  const PhosphorIcon(
                    AppIcons.songs,
                    size: 20,
                    color: AppColors.brandPrimary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Genre',
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSecondaryOf(context),
                        borderRadius: AppRadius.pillBorder,
                        border: Border.all(
                          color: AppColors.borderSubtleOf(context),
                        ),
                      ),
                      child: Text(
                        activeGenre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.badge.copyWith(
                          color: AppColors.brandPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  PhosphorIcon(
                    _isExpanded ? AppIcons.caretUp : AppIcons.caretDown,
                    color: AppColors.textSecondaryOf(context),
                  ),
                ],
              ),
            ),
          ),

          if (_isExpanded) ...[
            Divider(color: AppColors.borderSubtleOf(context), height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Pill
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondaryOf(context),
                      borderRadius: AppRadius.pillBorder,
                      border: Border.all(
                        color: AppColors.borderSubtleOf(context),
                      ),
                    ),
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimaryOf(context),
                      ),
                      cursorColor: AppColors.brandPrimary,
                      decoration: InputDecoration(
                        prefixIcon: PhosphorIcon(
                          AppIcons.search,
                          size: 18,
                          color: AppColors.textSecondaryOf(context),
                        ),
                        hintText: 'Search 42 genres (e.g. Ama, Ethio, K-Pop...)',
                        hintStyle: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondaryOf(
                            context,
                          ).withValues(alpha: 0.7),
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Regional Segment Rail
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _regions.map((region) {
                        final isSelected = region == activeRegion;
                        return Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.xs),
                          child: InkWell(
                            key: Key(
                              'genre_region_${region.toLowerCase().replaceAll(' ', '_')}',
                            ),
                            onTap: () {
                              ref
                                  .read(studioFormProvider.notifier)
                                  .setRegion(region);
                            },
                            borderRadius: AppRadius.pillBorder,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              constraints: const BoxConstraints(minHeight: 44),
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.brandPrimary
                                    : AppColors.surfaceSecondaryOf(context),
                                borderRadius: AppRadius.pillBorder,
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.brandPrimary
                                      : AppColors.borderSubtleOf(context),
                                ),
                              ),
                              child: Text(
                                region,
                                style: AppTypography.bodySmall.copyWith(
                                  color: isSelected
                                      ? AppColors.brandContrast
                                      : AppColors.textSecondaryOf(context),
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Genre Grid (2-column on mobile, 4-column on desktop)
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isDesktop ? 4 : 2,
                      crossAxisSpacing: AppSpacing.xs,
                      mainAxisSpacing: AppSpacing.xs,
                      childAspectRatio: isDesktop ? 2.2 : 2.0,
                    ),
                    itemCount: filteredGenres.length,
                    itemBuilder: (context, index) {
                      final item = filteredGenres[index];
                      final isSelected = item.name == activeGenre;

                      return InkWell(
                        onTap: () {
                          ref
                              .read(studioFormProvider.notifier)
                              .setGenre(item.name);
                        },
                        borderRadius: AppRadius.cardBorder,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSecondaryOf(context),
                            borderRadius: AppRadius.cardBorder,
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.brandPrimary
                                  : AppColors.borderSubtleOf(context),
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: AppColors.brandPrimary
                                          .withAlpha(50),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  gradient:
                                      AppGradients.forGenre(item.name),
                                  borderRadius: AppRadius.thumbBorder,
                                ),
                                alignment: Alignment.center,
                                child: PhosphorIcon(
                                  item.icon,
                                  size: 16,
                                  color: AppColors.brandContrast,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: AppTypography.bodySmall.copyWith(
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? AppColors.textPrimaryOf(context)
                                        : AppColors.textSecondaryOf(context),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isSelected)
                                PhosphorIcon(
                                  AppIcons.checkCircle,
                                  size: 16,
                                  color: accent,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Custom Genre Input Row
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSecondaryOf(context),
                            borderRadius: AppRadius.inputBorder,
                            border: Border.all(
                              color: AppColors.borderSubtleOf(context),
                            ),
                          ),
                          child: TextField(
                            controller: _customGenreController,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textPrimaryOf(context),
                            ),
                            cursorColor: AppColors.brandPrimary,
                            decoration: InputDecoration(
                              hintText: '+ Add a genre not in the list...',
                              hintStyle: AppTypography.caption.copyWith(
                                color: AppColors.textSecondaryOf(context),
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: () {
                            final custom = _customGenreController.text.trim();
                            if (custom.isNotEmpty) {
                              ref
                                  .read(studioFormProvider.notifier)
                                  .setGenre(custom);
                              _customGenreController.clear();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent.withAlpha(30),
                            foregroundColor: accent,
                            side: BorderSide(color: accent),
                            shape: const RoundedRectangleBorder(
                              borderRadius: AppRadius.inputBorder,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                            ),
                          ),
                          child: Text(
                            'Add',
                            style: TextStyle(color: accent),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Maps a free-form [genre] string from [StudioFormState] to a
  /// [Genre] enum for the design system token registry.
  ///
  /// Unknown genres fall back to [Genre.amapiano].
  Genre _mapStringToGenre(String genre) {
    final normalized = genre.trim().toLowerCase();
    return switch (normalized) {
      'amapiano' => Genre.amapiano,
      'afro house' => Genre.afroHouse,
      'afrohouse' => Genre.afroHouse,
      'gqom' => Genre.gqom,
      'kwaito' => Genre.kwaito,
      'afro pop' => Genre.afroPop,
      'afropop' => Genre.afroPop,
      'afrobeats' => Genre.afroPop,
      'afro beats' => Genre.afroPop,
      'maskandi' => Genre.maskandi,
      'hip hop' => Genre.hipHop,
      'hiphop' => Genre.hipHop,
      'gospel' => Genre.gospel,
      _ => Genre.amapiano,
    };
  }
}

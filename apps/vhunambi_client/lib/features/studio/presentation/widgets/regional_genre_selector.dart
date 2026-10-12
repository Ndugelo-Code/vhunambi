import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive_utils.dart';
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

  static const List<String> _regions = [
    'South Africa',
    'Africa',
    'Americas',
    'Global',
    'Asia',
  ];

  static const List<_GenreItem> _allGenres = [
    _GenreItem(name: 'Amapiano', icon: '🎹', region: 'South Africa'),
    _GenreItem(name: 'Kwaito', icon: '💿', region: 'South Africa'),
    _GenreItem(name: 'Gqom', icon: '💥', region: 'South Africa'),
    _GenreItem(name: 'Maskandi', icon: '🎸', region: 'South Africa'),
    _GenreItem(name: 'Mbaqanga', icon: '🪕', region: 'South Africa'),
    _GenreItem(name: 'Marabi', icon: '🎹', region: 'South Africa'),
    _GenreItem(name: 'Bubblegum', icon: '🍬', region: 'South Africa'),
    _GenreItem(name: 'Afro House', icon: '🥁', region: 'South Africa'),
    _GenreItem(name: 'Afrobeats', icon: '🔥', region: 'Africa'),
    _GenreItem(name: 'Afro Jazz', icon: '🎷', region: 'Africa'),
    _GenreItem(name: 'Afro Soul', icon: '🎙️', region: 'Africa'),
    _GenreItem(name: 'Highlife', icon: '🎺', region: 'Africa'),
    _GenreItem(name: 'Coupé-Décalé', icon: '⚡', region: 'Africa'),
    _GenreItem(name: 'Bongo Flava', icon: '🌴', region: 'Africa'),
    _GenreItem(name: 'Reggae', icon: '🟢', region: 'Americas'),
    _GenreItem(name: 'Dancehall', icon: '🔊', region: 'Americas'),
    _GenreItem(name: 'Hip Hop', icon: '🎤', region: 'Global'),
    _GenreItem(name: 'R&B', icon: '✨', region: 'Global'),
  ];

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

    final filteredGenres = _allGenres.where((g) {
      final matchesSearch =
          g.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesRegion = _searchQuery.isNotEmpty || g.region == activeRegion;
      return matchesSearch && matchesRegion;
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
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
                  const Icon(
                    Icons.music_note_rounded,
                    size: 20,
                    color: AppColors.brandPrimary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Genre',
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondary,
                      borderRadius: AppRadius.pillBorder,
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Text(
                      activeGenre,
                      style: AppTypography.badge.copyWith(
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),

          if (_isExpanded) ...[
            const Divider(color: AppColors.borderSubtle, height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Pill
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondary,
                      borderRadius: AppRadius.pillBorder,
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      cursorColor: AppColors.brandPrimary,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        hintText: 'Search genres (e.g. Ama, Hip...)',
                        hintStyle: AppTypography.bodySmall.copyWith(
                          color: AppColors.textTertiary,
                        ),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10),
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
                                    : AppColors.surfaceSecondary,
                                borderRadius: AppRadius.pillBorder,
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.brandPrimary
                                      : AppColors.borderSubtle,
                                ),
                              ),
                              child: Text(
                                region,
                                style: AppTypography.bodySmall.copyWith(
                                  color: isSelected
                                      ? AppColors.brandContrast
                                      : AppColors.textSecondary,
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
                            color: AppColors.surfaceSecondary,
                            borderRadius: AppRadius.cardBorder,
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.brandPrimary
                                  : AppColors.borderSubtle,
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
                                child: Text(
                                  item.icon,
                                  style: const TextStyle(fontSize: 14),
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
                                        ? AppColors.textPrimary
                                        : AppColors.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  size: 16,
                                  color: AppColors.brandPrimary,
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
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSecondary,
                            borderRadius: AppRadius.inputBorder,
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: TextField(
                            controller: _customGenreController,
                            style: AppTypography.bodySmall,
                            cursorColor: AppColors.brandPrimary,
                            decoration: InputDecoration(
                              hintText: '+ Add a genre not in the list...',
                              hintStyle: AppTypography.caption,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      ElevatedButton(
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
                          backgroundColor: AppColors.surfaceSecondary,
                          foregroundColor: AppColors.brandPrimary,
                          side: const BorderSide(
                              color: AppColors.brandPrimary),
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.inputBorder,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                        ),
                        child: const Text('Add'),
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
}

class _GenreItem {
  final String name;
  final String icon;
  final String region;

  const _GenreItem({
    required this.name,
    required this.icon,
    required this.region,
  });
}

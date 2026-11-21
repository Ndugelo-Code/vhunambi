import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/vhunambi_glass_surface.dart';
import '../../domain/models/library_models.dart';
import '../providers/library_providers.dart';

/// Horizontally scrollable glass category pill rail (`REQ-LIB-02`, `STD-UIUX-001`).
class LibraryCategoryRail extends ConsumerWidget {
  const LibraryCategoryRail({super.key});

  static const List<_CategoryPillSpec> _specs = [
    _CategoryPillSpec(
      category: LibraryCategory.songs,
      label: 'Songs',
      icon: AppIcons.songs,
    ),
    _CategoryPillSpec(
      category: LibraryCategory.playlists,
      label: 'Playlists',
      icon: PhosphorIconsRegular.queue,
    ),
    _CategoryPillSpec(
      category: LibraryCategory.collections,
      label: 'Collections',
      icon: PhosphorIconsRegular.disc,
    ),
    _CategoryPillSpec(
      category: LibraryCategory.beats,
      label: 'Beats',
      icon: PhosphorIconsRegular.shoppingBag,
    ),
    _CategoryPillSpec(
      category: LibraryCategory.licensing,
      label: 'Licensing',
      icon: PhosphorIconsRegular.scales,
    ),
    _CategoryPillSpec(
      category: LibraryCategory.trash,
      label: 'Trash',
      icon: AppIcons.trash,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCategory = ref.watch(libraryCategoryProvider);
    final counts = ref.watch(libraryCategoryCountsProvider);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          for (var index = 0; index < _specs.length; index++) ...[
            _CategoryPill(
              spec: _specs[index],
              isActive: _specs[index].category == activeCategory,
              count: counts[_specs[index].category] ?? 0,
              onTap: () {
                HapticFeedback.selectionClick();
                ref.read(libraryCategoryProvider.notifier).state =
                    _specs[index].category;
                ref.read(librarySearchQueryProvider.notifier).state = '';
              },
            ),
            if (index != _specs.length - 1)
              const SizedBox(width: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final _CategoryPillSpec spec;
  final bool isActive;
  final int count;
  final VoidCallback onTap;

  const _CategoryPill({
    required this.spec,
    required this.isActive,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = isActive
        ? AppColors.brandContrast
        : AppColors.textSecondaryOf(context);

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PhosphorIcon(spec.icon, size: 16, color: foreground),
        const SizedBox(width: AppSpacing.xxs + 2),
        Text(
          spec.label,
          style: AppTypography.bodySmall.copyWith(
            color: foreground,
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        if (count > 0) ...[
          const SizedBox(width: AppSpacing.xxs + 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.brandContrast.withAlpha(38)
                  : AppColors.surfaceElevatedOf(context),
              borderRadius: AppRadius.pillBorder,
              border: isActive
                  ? null
                  : Border.all(color: AppColors.borderSubtleOf(context)),
            ),
            child: Text(
              '$count',
              style: AppTypography.badge.copyWith(color: foreground),
            ),
          ),
        ],
      ],
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Center(
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.pillBorder,
          child: isActive
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary,
                    borderRadius: AppRadius.pillBorder,
                    border: Border.all(color: AppColors.brandPrimary),
                  ),
                  child: content,
                )
              : VhunambiGlassSurface(
                  variant: VhunambiGlassVariant.pill,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 9,
                  ),
                  child: content,
                ),
        ),
      ),
    );
  }
}

class _CategoryPillSpec {
  final LibraryCategory category;
  final String label;
  final IconData icon;

  const _CategoryPillSpec({
    required this.category,
    required this.label,
    required this.icon,
  });
}

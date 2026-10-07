import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/library_models.dart';
import '../providers/library_providers.dart';

/// Horizontally scrollable category pill rail (REQ-LIB-02 / Blueprint 04 §2).
///
/// Active pill: `brandPrimary` surface with `brandContrast` label.
/// Inactive pill: `surfaceSecondary` surface with `borderSubtle` outline.
class LibraryCategoryRail extends ConsumerWidget {
  const LibraryCategoryRail({super.key});

  static const List<_CategoryPillSpec> _specs = [
    _CategoryPillSpec(
      category: LibraryCategory.songs,
      label: 'Songs',
      icon: Icons.music_note_rounded,
    ),
    _CategoryPillSpec(
      category: LibraryCategory.playlists,
      label: 'Playlists',
      icon: Icons.queue_music_rounded,
    ),
    _CategoryPillSpec(
      category: LibraryCategory.collections,
      label: 'Collections',
      icon: Icons.album_outlined,
    ),
    _CategoryPillSpec(
      category: LibraryCategory.beats,
      label: 'Beats',
      icon: Icons.shopping_bag_outlined,
    ),
    _CategoryPillSpec(
      category: LibraryCategory.licensing,
      label: 'Licensing',
      icon: Icons.balance_rounded,
    ),
    _CategoryPillSpec(
      category: LibraryCategory.trash,
      label: 'Trash',
      icon: Icons.delete_outline_rounded,
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
                ref.read(libraryCategoryProvider.notifier).state =
                    _specs[index].category;
                // Reset the vault query so the new category reveals its own records.
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
    final background =
        isActive ? AppColors.brandPrimary : AppColors.surfaceSecondary;
    final foreground =
        isActive ? AppColors.brandContrast : AppColors.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.pillBorder,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: AppRadius.pillBorder,
          border: Border.all(
            color: isActive ? AppColors.brandPrimary : AppColors.borderSubtle,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(spec.icon, size: 16, color: foreground),
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
                      : AppColors.surfaceElevated,
                  borderRadius: AppRadius.pillBorder,
                  border: isActive
                      ? null
                      : Border.all(color: AppColors.borderSubtle),
                ),
                child: Text(
                  '$count',
                  style: AppTypography.badge.copyWith(color: foreground),
                ),
              ),
            ],
          ],
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

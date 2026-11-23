import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/vhunambi_glass_tab_bar.dart';
import '../../domain/models/library_models.dart';
import '../providers/library_providers.dart';

/// Horizontally scrollable glass category pill rail (`REQ-LIB-02`, `REQ-P78-UX-03`).
class LibraryCategoryRail extends ConsumerWidget {
  const LibraryCategoryRail({super.key});

  static const List<_CategoryPillSpec> _specs = [
    _CategoryPillSpec(
      category: LibraryCategory.songs,
      label: 'Songs',
      icon: AppIcons.songs,
    ),
    _CategoryPillSpec(
      category: LibraryCategory.reels,
      label: 'Reels',
      icon: AppIcons.reels,
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
    final selectedIndex = _specs.indexWhere(
      (spec) => spec.category == activeCategory,
    );

    return VhunambiGlassTabBar(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
      items: _specs
          .map(
            (spec) => VhunambiGlassTabItem(
              key: Key('library_category_${spec.category.name}'),
              label: spec.label,
              icon: spec.icon,
              badgeCount: counts[spec.category] ?? 0,
            ),
          )
          .toList(),
      onSelected: (index) {
        ref.read(libraryCategoryProvider.notifier).state =
            _specs[index].category;
        ref.read(librarySearchQueryProvider.notifier).state = '';
      },
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

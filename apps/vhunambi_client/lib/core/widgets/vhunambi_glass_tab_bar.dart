import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';

/// Descriptor for a single segment inside [VhunambiGlassTabBar] (`REQ-P78-UX-03`).
class VhunambiGlassTabItem {
  final Key? key;
  final String label;
  final IconData? icon;
  final int? badgeCount;

  const VhunambiGlassTabItem({
    this.key,
    required this.label,
    this.icon,
    this.badgeCount,
  });
}

/// Unified dual-theme frosted glass tab bar (`EP-P78-GLASS-TABS`, `REQ-P78-UX-03`).
///
/// Replaces fragmented boxy / M2 underline tab bars across OwnerProfileView,
/// ArtistProfileView, LibraryView, and ExploreView. Guarantees `44dp` minimum
/// touch height, Light/Dark adaptive glass borders, amber accent active capsule,
/// zero raw emojis, and `HapticFeedback.selectionClick()` on tap.
class VhunambiGlassTabBar extends StatelessWidget {
  final List<VhunambiGlassTabItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Color? accentColor;
  final EdgeInsetsGeometry? padding;
  final bool scrollable;

  const VhunambiGlassTabBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.accentColor,
    this.padding,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveAccent = accentColor ?? AppColors.brandPrimary;

    final trackColor = isDark
        ? AppColors.darkSurfaceElevated.withValues(alpha: 0.72)
        : AppColors.lightSurfaceElevated.withValues(alpha: 0.78);
    final trackBorder = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.08);

    final row = Row(
      mainAxisSize: scrollable ? MainAxisSize.min : MainAxisSize.max,
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          if (scrollable)
            _buildSegment(context, items[i], i, isDark, effectiveAccent)
          else
            Expanded(
              child: _buildSegment(
                context,
                items[i],
                i,
                isDark,
                effectiveAccent,
              ),
            ),
        ],
      ],
    );

    final shell = Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: AppRadius.pillBorder,
        border: Border.all(color: trackBorder),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.24)
                : const Color(0xFF121216).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: row,
    );

    final Widget content = scrollable
        ? SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: shell,
          )
        : shell;

    if (padding != null) {
      return Padding(padding: padding!, child: content);
    }
    return content;
  }

  Widget _buildSegment(
    BuildContext context,
    VhunambiGlassTabItem item,
    int index,
    bool isDark,
    Color effectiveAccent,
  ) {
    final isSelected = index == selectedIndex;
    final labelColor = isSelected
        ? (isDark ? Colors.white : AppColors.lightTextPrimary)
        : AppColors.textSecondaryOf(context);
    final iconColor = isSelected
        ? effectiveAccent
        : AppColors.textSecondaryOf(context);
    final activeBg = effectiveAccent.withValues(alpha: isDark ? 0.22 : 0.16);
    final activeBorder = effectiveAccent.withValues(alpha: 0.65);

    return GestureDetector(
      key: item.key,
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onSelected(index);
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(
            horizontal: 11,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: isSelected ? activeBg : Colors.transparent,
            borderRadius: AppRadius.pillBorder,
            border: Border.all(
              color: isSelected ? activeBorder : Colors.transparent,
              width: 1,
            ),
            boxShadow: isSelected
                ? <BoxShadow>[
                    BoxShadow(
                      color: effectiveAccent.withValues(
                        alpha: isDark ? 0.25 : 0.14,
                      ),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : const <BoxShadow>[],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (item.icon != null) ...[
                PhosphorIcon(item.icon!, size: 14, color: iconColor),
                const SizedBox(width: 5),
              ],
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall.copyWith(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: labelColor,
                ),
              ),
              if (item.badgeCount != null && item.badgeCount! > 0) ...[
                const SizedBox(width: AppSpacing.xxs + 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? effectiveAccent
                        : AppColors.surfaceSecondaryOf(context),
                    borderRadius: AppRadius.pillBorder,
                  ),
                  child: Text(
                    '${item.badgeCount}',
                    style: AppTypography.badge.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.black
                          : AppColors.textSecondaryOf(context),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Pinned sliver delegate wrapping [VhunambiGlassTabBar] synced with a [TabController]
/// (used by `ArtistProfileView` so horizontal `TabBarView` swipes stay locked in sync).
class VhunambiGlassTabBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  final List<VhunambiGlassTabItem> items;
  final TabController? controller;
  final Color surfaceColor;
  final Color? accentColor;

  const VhunambiGlassTabBarHeaderDelegate({
    required this.items,
    required this.surfaceColor,
    this.controller,
    this.accentColor,
  });

  @override
  double get minExtent => 64;

  @override
  double get maxExtent => 64;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final effectiveController =
        controller ?? DefaultTabController.maybeOf(context);
    if (effectiveController == null) {
      return Container(
        color: surfaceColor,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 6,
        ),
        child: VhunambiGlassTabBar(
          items: items,
          selectedIndex: 0,
          accentColor: accentColor,
          onSelected: (_) {},
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(
          bottom: BorderSide(color: AppColors.borderSubtleOf(context)),
        ),
      ),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 6,
      ),
      child: AnimatedBuilder(
        animation: effectiveController,
        builder: (context, _) {
          return VhunambiGlassTabBar(
            items: items,
            selectedIndex: effectiveController.index.clamp(0, items.length - 1),
            accentColor: accentColor,
            onSelected: (index) {
              effectiveController.animateTo(index);
            },
          );
        },
      ),
    );
  }

  @override
  bool shouldRebuild(covariant VhunambiGlassTabBarHeaderDelegate oldDelegate) {
    return oldDelegate.surfaceColor != surfaceColor ||
        oldDelegate.controller != controller ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.items != items;
  }
}

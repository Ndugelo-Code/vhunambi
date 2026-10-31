import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../design_system/services/haptics_service.dart';
import '../design_system/tokens/app_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import '../theme/app_typography.dart';

/// Item configuration for [VhunambiMobileBottomNav].
class VhunambiBottomNavItem {
  final IconData idleIcon;
  final IconData activeIcon;
  final String label;
  final Key key;
  final bool isHero;

  const VhunambiBottomNavItem({
    required this.idleIcon,
    required this.activeIcon,
    required this.label,
    required this.key,
    this.isHero = false,
  });
}

/// Purpose-built zero-flash mobile bottom navigation bar for the Vhunambi shell.
///
/// Eliminates the default Material [InkResponse] milky flash-glow bleed on dark frosted glass,
/// providing an organic sliding capsule highlight, an elevated center "Create" hero orb,
/// single-channel curated haptic feedback, and rigid 48x48dp touch targets.
class VhunambiMobileBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final ValueChanged<int>? onReselect;

  static const double height = 56.0;

  static const List<VhunambiBottomNavItem> items = [
    VhunambiBottomNavItem(
      idleIcon: AppIcons.navHome,
      activeIcon: AppIcons.navHomeActive,
      label: 'Home',
      key: Key('mobile_nav_tab_0'),
    ),
    VhunambiBottomNavItem(
      idleIcon: AppIcons.navExplore,
      activeIcon: AppIcons.navExploreActive,
      label: 'Explore',
      key: Key('mobile_nav_tab_1'),
    ),
    VhunambiBottomNavItem(
      idleIcon: AppIcons.navCreate,
      activeIcon: AppIcons.navCreateActive,
      label: 'Create',
      key: Key('mobile_nav_tab_2'),
      isHero: true,
    ),
    VhunambiBottomNavItem(
      idleIcon: AppIcons.navLibrary,
      activeIcon: AppIcons.navLibraryActive,
      label: 'Library',
      key: Key('mobile_nav_tab_3'),
    ),
    VhunambiBottomNavItem(
      idleIcon: AppIcons.navMarket,
      activeIcon: AppIcons.navMarketActive,
      label: 'Market',
      key: Key('mobile_nav_tab_4'),
    ),
  ];

  const VhunambiMobileBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.onReselect,
  });

  void _handleTabTap(int index) {
    if (index == currentIndex) {
      HapticsService().lightImpact();
      onReselect?.call(index);
      return;
    }

    HapticsService().selectionClick();
    onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: true,
      child: SizedBox(
        height: height,
        child: Row(
          children: List.generate(items.length, (index) {
            final item = items[index];
            final isSelected = index == currentIndex;

            return Expanded(
              child: _BottomNavTab(
                item: item,
                index: index,
                isSelected: isSelected,
                onTap: () => _handleTabTap(index),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _BottomNavTab extends StatelessWidget {
  final VhunambiBottomNavItem item;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;

  const _BottomNavTab({
    required this.item,
    required this.index,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (item.isHero) {
      return _buildHeroTab(context);
    }

    return Semantics(
      selected: isSelected,
      button: true,
      label: '${item.label} tab, ${index + 1} of 5',
      child: InkResponse(
        key: item.key,
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        containedInkWell: true,
        radius: 28,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minWidth: 54, minHeight: 46),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.brandPrimary.withAlpha(25)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: isSelected
                  ? Border.all(
                      color: AppColors.brandPrimary.withAlpha(55),
                      width: 1.0,
                    )
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  scale: isSelected ? 1.12 : 1.0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutBack,
                  child: PhosphorIcon(
                    isSelected ? item.activeIcon : item.idleIcon,
                    size: 20,
                    color: isSelected
                        ? AppColors.brandPrimary
                        : AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.label,
                  maxLines: 1,
                  style: AppTypography.caption.copyWith(
                    fontSize: 10.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? AppColors.brandPrimary
                        : AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroTab(BuildContext context) {
    return Semantics(
      selected: isSelected,
      button: true,
      label: '${item.label} tab, ${index + 1} of 5',
      child: InkResponse(
        key: item.key,
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        containedInkWell: true,
        radius: 28,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minWidth: 54, minHeight: 46),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: isSelected
                ? BoxDecoration(
                    color: AppColors.brandPrimary.withAlpha(25),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.brandPrimary.withAlpha(55),
                      width: 1.0,
                    ),
                  )
                : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 22,
                  decoration: BoxDecoration(
                    gradient: AppGradients.primaryButton,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.brandPrimary.withAlpha(80),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: PhosphorIcon(
                      item.activeIcon,
                      size: 15,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  maxLines: 1,
                  style: AppTypography.caption.copyWith(
                    fontSize: 10.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected
                        ? AppColors.brandPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

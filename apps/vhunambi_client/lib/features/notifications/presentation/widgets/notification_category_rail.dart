import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/notification_enums.dart';
import '../providers/notifications_provider.dart';
import '../utils/notification_category_style.dart';
import '../utils/notifications_haptics.dart';

/// Horizontally scrolling category filter rail for the Notifications Center.
///
/// Renders an "All" chip plus one chip per [NotificationCategory], each with a
/// token-tinted glyph, a bouncing unread-count badge, and a guaranteed
/// 44×44px touch target (WCAG 2.1 AA / Apple HIG).
class NotificationCategoryRail extends ConsumerWidget {
  const NotificationCategoryRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedCategoryProvider);
    final unreadByCategory = ref.watch(unreadCountByCategoryProvider);
    final totalUnread = ref.watch(unreadNotificationsCountProvider);

    void select(NotificationCategory? category) {
      NotificationsHaptics.categorySwitch();
      ref.read(selectedCategoryProvider.notifier).state = category;
    }

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        children: <Widget>[
          _CategoryChip(
            key: const Key('category_chip_all'),
            label: 'All',
            icon: Icons.inbox_rounded,
            accent: AppColors.brandPrimary,
            count: totalUnread,
            isSelected: selected == null,
            onTap: () => select(null),
          ),
          for (final category in NotificationCategory.values)
            _CategoryChip(
              key: Key('category_chip_${category.name}'),
              label: NotificationCategoryStyle.label(category),
              icon: NotificationCategoryStyle.icon(category),
              accent: NotificationCategoryStyle.color(category),
              count: unreadByCategory[category] ?? 0,
              isSelected: selected == category,
              onTap: () => select(category),
            ),
        ],
      ),
    );
  }
}

/// A single animated category pill: sliding indicator tint + bouncing badge.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    super.key,
    required this.label,
    required this.icon,
    required this.accent,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: Semantics(
        selected: isSelected,
        button: true,
        label: '$label${count > 0 ? ', $count unread' : ''}',
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.pillBorder,
          child: ConstrainedBox(
            // Guaranteed 44×44px touch target.
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? accent.withValues(alpha: 0.18)
                    : AppColors.surfaceSecondary,
                borderRadius: AppRadius.pillBorder,
                border: Border.all(
                  color: isSelected ? accent : AppColors.borderSubtle,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    icon,
                    size: 16,
                    color: isSelected ? accent : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: AppTypography.caption.copyWith(
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  if (count > 0) ...<Widget>[
                    const SizedBox(width: 6),
                    _CountBadge(count: count, accent: accent),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


/// Unread-count pill that springs (`1.0 → 1.25 → 1.0`) whenever its [count]
/// changes, giving the rail its tactile bounce.
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.accent});

  final int count;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 1.25, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Transform.scale(
        scale: scale,
        child: child,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        constraints: const BoxConstraints(minWidth: 18),
        decoration: BoxDecoration(
          color: accent,
          borderRadius: AppRadius.pillBorder,
        ),
        child: Text(
          count > 99 ? '99+' : '$count',
          textAlign: TextAlign.center,
          style: AppTypography.badge.copyWith(color: AppColors.brandContrast),
        ),
      ),
    );
  }
}
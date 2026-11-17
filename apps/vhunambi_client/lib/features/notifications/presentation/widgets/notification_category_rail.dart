import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/notification_enums.dart';
import '../providers/notifications_provider.dart';
import '../utils/notification_category_style.dart';
import '../utils/notifications_haptics.dart';

/// Horizontally scrolling category filter rail with right-edge fade affordance,
/// auto-scroll-into-view, Phosphor icons, and automatic keyboard unfocus.
class NotificationCategoryRail extends ConsumerStatefulWidget {
  const NotificationCategoryRail({super.key});

  @override
  ConsumerState<NotificationCategoryRail> createState() =>
      _NotificationCategoryRailState();
}

class _NotificationCategoryRailState
    extends ConsumerState<NotificationCategoryRail> {
  final Map<String, GlobalKey> _chipKeys = <String, GlobalKey>{
    'all': GlobalKey(),
    for (final c in NotificationCategory.values) c.name: GlobalKey(),
  };

  void _select(NotificationCategory? category) {
    FocusManager.instance.primaryFocus?.unfocus();
    NotificationsHaptics.categorySwitch();
    ref.read(selectedCategoryProvider.notifier).state = category;
    final key = _chipKeys[category?.name ?? 'all'];
    final ctx = key?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        alignment: 0.5,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectedCategoryProvider);
    final unreadByCategory = ref.watch(unreadCountByCategoryProvider);
    final totalUnread = ref.watch(unreadNotificationsCountProvider);

    return SizedBox(
      height: 52,
      child: ShaderMask(
        shaderCallback: (Rect bounds) {
          return const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            stops: <double>[0.0, 0.92, 1.0],
            colors: <Color>[Colors.white, Colors.white, Colors.transparent],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstIn,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          children: <Widget>[
            KeyedSubtree(
              key: _chipKeys['all'],
              child: _CategoryChip(
                key: const Key('category_chip_all'),
                label: 'All',
                icon: PhosphorIconsRegular.tray,
                accent: AppColors.brandPrimary,
                count: totalUnread,
                isSelected: selected == null,
                onTap: () => _select(null),
              ),
            ),
            for (final category in NotificationCategory.values)
              KeyedSubtree(
                key: _chipKeys[category.name],
                child: _CategoryChip(
                  key: Key('category_chip_${category.name}'),
                  label: NotificationCategoryStyle.label(category),
                  icon: NotificationCategoryStyle.icon(category),
                  accent: NotificationCategoryStyle.color(category),
                  count: unreadByCategory[category] ?? 0,
                  isSelected: selected == category,
                  onTap: () => _select(category),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

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
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? accent.withValues(alpha: 0.18)
                    : AppColors.surfaceSecondaryOf(context),
                borderRadius: AppRadius.pillBorder,
                border: Border.all(
                  color: isSelected
                      ? accent
                      : AppColors.borderSubtleOf(context),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  PhosphorIcon(
                    icon,
                    size: 16,
                    color: isSelected
                        ? accent
                        : AppColors.textSecondaryOf(context),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: AppTypography.caption.copyWith(
                      color: isSelected
                          ? AppColors.textPrimaryOf(context)
                          : AppColors.textSecondaryOf(context),
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
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

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.accent});

  final int count;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey<int>(count),
      tween: Tween<double>(begin: 1.25, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
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

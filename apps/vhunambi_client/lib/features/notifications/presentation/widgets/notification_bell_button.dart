import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/notifications_provider.dart';
import 'notifications_popover.dart';

/// Reusable header bell with a live unread badge (T11.4).
///
/// Binds to [unreadNotificationsCountProvider]; tapping opens the alerts drawer.
class NotificationBellButton extends ConsumerWidget {
  /// Tooltip retained from the Phase 2/3 headers.
  static const String tooltip = 'Notifications';

  final VoidCallback? onPressed;
  final Color? color;
  final double iconSize;

  const NotificationBellButton({
    super.key,
    this.onPressed,
    this.color,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed ?? () => NotificationsPopover.show(context),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                Icons.notifications_none_rounded,
                size: iconSize,
                color: color ?? AppColors.textSecondary,
              ),
              if (unreadCount > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: const BoxDecoration(
                      color: AppColors.brandPrimary,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 14,
                      minHeight: 14,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: const TextStyle(
                        color: AppColors.brandContrast,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

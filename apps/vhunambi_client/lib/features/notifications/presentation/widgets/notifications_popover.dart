import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../track/presentation/views/track_detail_view.dart';
import '../../domain/models/notification_entity.dart';
import '../providers/notifications_provider.dart';
import '../utils/time_ago_utils.dart';
import '../views/notifications_view.dart';

/// Live in-app alert centre (T11.3).
///
/// Phase 2 shell, Phase 11 wiring: every row is bound to
/// [notificationsProvider] and every action mutates it through
/// [NotificationsNotifier].
class NotificationsPopover extends ConsumerWidget {
  const NotificationsPopover({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => const Dialog(
        backgroundColor: Colors.transparent,
        alignment: Alignment.topRight,
        insetPadding: EdgeInsets.only(top: 70, right: 16),
        // SizedBox pins the width so nested Rows always receive bounded
        // constraints — prevents unconstrained-layout test failures.
        child: SizedBox(width: 360, child: NotificationsPopover()),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final unreadCount = ref.watch(unreadNotificationsCountProvider);
    final notifier = ref.read(notificationsProvider.notifier);

    return Container(
      // Width is constrained by the SizedBox injected in show(); keeping
      // double.infinity here makes the widget fill that bounded slot cleanly.
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceModal,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.notifications_outlined,
                  size: 20,
                  color: AppColors.brandPrimary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Notifications',
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleMedium,
                  ),
                ),
                if (unreadCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: const BoxDecoration(
                      color: AppColors.brandPrimary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$unreadCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brandContrast,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: notifier.markAllAsRead,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: Icon(
                    Icons.check,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  label: Text(
                    'Mark all read',
                    style: AppTypography.caption,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Live alert list (T11.3)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400),
            child: notifications.isEmpty
                ? const _EmptyNotificationsState()
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(12),
                    itemCount: notifications.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      return _NotificationCard(
                        notification: notification,
                        onTap: () =>
                            _openNotification(context, notifier, notification),
                        onDismiss: () =>
                            notifier.removeNotification(notification.id),
                      );
                    },
                  ),
          ),

          const Divider(height: 1),

          // Footer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Dual-surface coexistence CTA → dedicated NotificationsView.
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    key: const Key('notifications_view_all_btn'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      foregroundColor: AppColors.brandContrast,
                      elevation: 0,
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.pillBorder,
                      ),
                    ),
                    onPressed: () {
                      // Capture the navigator before popping the dialog so the
                      // subsequent push never targets a deactivated element.
                      final navigator = Navigator.of(context);
                      navigator.pop();
                      navigator.push(
                        MaterialPageRoute<void>(
                          builder: (_) => const NotificationsView(),
                        ),
                      );
                    },
                    child: Text(
                      'View All Alerts in Center ➔',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.brandContrast,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: notifier.clearAll,
                      child: Text(
                        'Clear all',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.brandPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      child: Text('Close', style: AppTypography.caption),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Marks the alert read, dismisses the drawer and deep-links to the track.
  ///
  /// The [Navigator] is captured *before* `pop()` so the subsequent `push`
  /// never looks up the ancestor of a deactivated element (T11.3 fix).
  void _openNotification(
    BuildContext context,
    NotificationsNotifier notifier,
    NotificationEntity notification,
  ) {
    final navigator = Navigator.of(context);
    final targetTrackId = notification.targetTrackId;

    notifier.markAsRead(notification.id);
    navigator.pop();

    if (targetTrackId == null || targetTrackId.isEmpty) return;

    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => TrackDetailView(trackId: targetTrackId),
      ),
    );
  }
}

/// Single alert row: icon, title, `message • time ago`, unread dot, dismiss.
class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  final NotificationEntity notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.cardBorder,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: AppRadius.cardBorder,
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.music_note_rounded,
                color: AppColors.brandPrimary,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: AppTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${notification.message} • '
                    '${TimeAgoUtils.format(notification.createdAt)}',
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
            if (!notification.isRead) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.brandPrimary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onDismiss,
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rendered when the alert list is empty.
class _EmptyNotificationsState extends StatelessWidget {
  const _EmptyNotificationsState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Column(
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 32,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 10),
          Text(
            'No notifications yet',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Rendered songs and studio updates will appear here.',
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

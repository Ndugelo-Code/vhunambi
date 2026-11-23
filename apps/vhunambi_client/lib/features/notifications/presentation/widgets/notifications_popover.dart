import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/vhunambi_glass_surface.dart';
import '../../domain/models/notification_entity.dart';
import '../providers/notifications_provider.dart';
import '../utils/notification_deep_link_router.dart';
import '../utils/time_ago_utils.dart';
import '../views/notifications_view.dart';

/// Live in-app alert centre (`T11.3` / `Phase 76` Glass & Full Deep-Link Routing).
///
/// Bound to [notificationsProvider] and delegates deep-link taps through
/// [NotificationDeepLinkRouter.handleCardTap].
class NotificationsPopover extends ConsumerWidget {
  final BuildContext? hostContext;

  const NotificationsPopover({super.key, this.hostContext});

  static void show(BuildContext context) {
    final capturedHostContext = context;
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        alignment: Alignment.topRight,
        insetPadding: const EdgeInsets.only(top: 70, right: 16),
        // SizedBox pins the width so nested Rows always receive bounded
        // constraints — prevents unconstrained-layout test failures.
        child: SizedBox(
          width: 360,
          child: NotificationsPopover(hostContext: capturedHostContext),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final unreadCount = ref.watch(unreadNotificationsCountProvider);
    final notifier = ref.read(notificationsProvider.notifier);

    return VhunambiGlassSurface(
      key: const Key('notifications_popover_glass'),
      variant: VhunambiGlassVariant.chrome,
      width: double.infinity,
      borderRadius: BorderRadius.circular(16),
      enableLiveBlur: false,
      borderColorOverride: AppColors.borderSubtleOf(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const PhosphorIcon(
                  AppIcons.bell,
                  size: 20,
                  color: AppColors.brandPrimary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Notifications',
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.textPrimaryOf(context),
                    ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: const Size(44, 44),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: PhosphorIcon(
                    AppIcons.check,
                    size: 14,
                    color: AppColors.textSecondaryOf(context),
                  ),
                  label: Text(
                    'Mark all read',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.borderSubtleOf(context)),

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
                        onTap: () => _openNotification(
                          context,
                          ref,
                          notifier,
                          notification,
                        ),
                        onDismiss: () =>
                            notifier.removeNotification(notification.id),
                      );
                    },
                  ),
          ),

          Divider(height: 1, color: AppColors.borderSubtleOf(context)),

          // Footer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Dual-surface coexistence CTA -> dedicated NotificationsView.
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    key: const Key('notifications_view_all_btn'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      foregroundColor: AppColors.brandContrast,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            'View All Alerts in Center',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.brandContrast,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const PhosphorIcon(
                          AppIcons.arrowRight,
                          size: 14,
                          color: AppColors.brandContrast,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      child: InkWell(
                        onTap: notifier.clearAll,
                        borderRadius: AppRadius.pillBorder,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              'Clear all',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.brandPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: AppRadius.pillBorder,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              'Close',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondaryOf(context),
                              ),
                            ),
                          ),
                        ),
                      ),
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

  /// Marks the alert read, dismisses the popover, and delegates any non-empty
  /// [NotificationEntity.effectiveRoute] to [NotificationDeepLinkRouter].
  void _openNotification(
    BuildContext context,
    WidgetRef ref,
    NotificationsNotifier notifier,
    NotificationEntity notification,
  ) {
    final navigator = Navigator.of(context);
    final effectiveHost = (hostContext != null && hostContext!.mounted)
        ? hostContext!
        : (navigator.overlay?.context ?? context);
    final effectiveRoute = notification.effectiveRoute;

    notifier.markAsRead(notification.id);
    navigator.pop();

    if (effectiveRoute == null || effectiveRoute.isEmpty) {
      return;
    }

    NotificationDeepLinkRouter.handleCardTap(
      effectiveHost,
      ref,
      notification,
      navigator: navigator,
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
      child: VhunambiGlassSurface(
        variant: VhunambiGlassVariant.card,
        padding: const EdgeInsets.all(12),
        borderRadius: AppRadius.cardBorder,
        enableLiveBlur: false,
        borderColorOverride: AppColors.borderSubtleOf(context),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondaryOf(context),
                shape: BoxShape.circle,
              ),
              child: const PhosphorIcon(
                AppIcons.songs,
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
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${notification.message} • '
                    '${TimeAgoUtils.format(notification.createdAt)}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondaryOf(context),
                    ),
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
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: PhosphorIcon(
                  AppIcons.close,
                  size: 14,
                  color: AppColors.textSecondaryOf(context),
                ),
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
          PhosphorIcon(
            PhosphorIconsRegular.bellSlash,
            size: 32,
            color: AppColors.textSecondaryOf(context),
          ),
          const SizedBox(height: 10),
          Text(
            'No notifications yet',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textPrimaryOf(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Rendered songs and studio updates will appear here.',
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondaryOf(context),
            ),
          ),
        ],
      ),
    );
  }
}

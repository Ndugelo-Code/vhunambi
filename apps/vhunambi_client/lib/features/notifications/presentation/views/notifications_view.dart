import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../core/widgets/vhunambi_bottom_dock_kit.dart';
import '../../../../core/widgets/vhunambi_top_bar_kit.dart';
import '../../domain/models/notification_entity.dart';
import '../../domain/models/notification_enums.dart';
import '../providers/notifications_provider.dart';
import '../utils/notification_deep_link_router.dart';
import '../utils/notifications_haptics.dart';
import '../widgets/notification_category_rail.dart';
import '../widgets/notification_empty_state.dart';
import '../widgets/notification_item_tile.dart';
import '../widgets/notification_search_bar.dart';

/// Full-screen, category-driven Accessible Notifications Center (M8).
///
/// A dedicated pushed route (never a 6th RootShell tab). Combines the frosted
/// [VhunambiTopBarSurface] header, the [NotificationCategoryRail], a
/// [NotificationSearchBar], bulk "Mark all read", and a swipeable list that
/// respects [VhunambiBottomDockMetrics] safe-area insets.
class NotificationsView extends ConsumerWidget {
  const NotificationsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(filteredNotificationsProvider);
    final unreadCount = ref.watch(unreadNotificationsCountProvider);
    final bottomInset = VhunambiBottomDockMetrics.scrollInset(
      hasActiveTrack: false,
    );

    void openNotification(NotificationEntity notification) {
      NotificationDeepLinkRouter.handleCardTap(context, ref, notification);
    }

    void markAllRead() {
      FocusManager.instance.primaryFocus?.unfocus();
      NotificationsHaptics.markAllReadPulse();
      ref.read(notificationsProvider.notifier).markAllAsRead();
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvasOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            VhunambiTopBarSurface(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Row(
                  children: <Widget>[
                    const VhunambiBackButton(),
                    const SizedBox(width: AppSpacing.xxs),
                    Expanded(
                      child: Text(
                        'Notifications',
                        key: const Key('notifications_view_title'),
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.textPrimaryOf(context),
                        ),
                      ),
                    ),
                    _MarkAllReadButton(
                      enabled: unreadCount > 0,
                      onPressed: markAllRead,
                    ),
                  ],
                ),
              ),
            ),
            const NotificationCategoryRail(),
            const NotificationSearchBar(),
            Divider(height: 1, color: AppColors.borderSubtleOf(context)),
            Expanded(
              child: notifications.isEmpty
                  ? const NotificationEmptyState()
                  : Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: ResponsiveUtils.isDesktop(context)
                              ? 840
                              : double.infinity,
                        ),
                        child: ListView.builder(
                          key: const Key('notifications_list'),
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: EdgeInsets.only(
                            top: AppSpacing.xs,
                            bottom: bottomInset + AppSpacing.md,
                          ),
                          itemCount: notifications.length,
                          itemBuilder: (context, index) {
                            final notification = notifications[index];
                            return NotificationItemTile(
                              notification: notification,
                              onTap: () => openNotification(notification),
                              onAction: (action) => _handleAction(
                                context,
                                ref,
                                notification,
                                action,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Routes a contextual action through [NotificationDeepLinkRouter].
  void _handleAction(
    BuildContext context,
    WidgetRef ref,
    NotificationEntity notification,
    NotificationAction action,
  ) {
    NotificationsHaptics.itemTap();
    ref.read(notificationsProvider.notifier).markAsRead(notification.id);
    final route = action.actionData['route'] as String?;
    final targetNotification = (route != null && route.isNotEmpty)
        ? notification.copyWith(targetRoute: route)
        : notification;
    NotificationDeepLinkRouter.navigateDirect(context, ref, targetNotification);
  }
}

/// "Mark all read" pill with a guaranteed 44×44px target and a check glyph.
class _MarkAllReadButton extends StatelessWidget {
  const _MarkAllReadButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      key: const Key('notifications_mark_all_read'),
      onPressed: enabled ? onPressed : null,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.brandPrimary,
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      ),
      icon: const PhosphorIcon(PhosphorIconsRegular.checks, size: 18),
      label: Text(
        'Mark all read',
        style: AppTypography.caption.copyWith(
          color: enabled
              ? AppColors.brandPrimary
              : AppColors.textSecondaryOf(context),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../core/widgets/vhunambi_bottom_dock_kit.dart';
import '../../../../core/widgets/vhunambi_top_bar_kit.dart';
import '../../../track/presentation/views/track_detail_view.dart';
import '../../domain/models/notification_entity.dart';
import '../../domain/models/notification_enums.dart';
import '../providers/notifications_provider.dart';
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
    final rawNotifications = ref.watch(notificationsProvider);
    if (rawNotifications.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ref.read(notificationsProvider).isEmpty) {
          ref.read(notificationsProvider.notifier).seedDemoAlerts();
        }
      });
    }
    final notifications = ref.watch(filteredNotificationsProvider);
    final unreadCount = ref.watch(unreadNotificationsCountProvider);
    final bottomInset = VhunambiBottomDockMetrics.scrollInset(
      hasActiveTrack: false,
    );

    void openNotification(NotificationEntity notification) {
      final navigator = Navigator.of(context);
      final targetTrackId = notification.targetTrackId ??
          notification.metadata['trackId'] as String?;
      if (targetTrackId == null || targetTrackId.isEmpty) return;
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => TrackDetailView(trackId: targetTrackId),
        ),
      );
    }

    void markAllRead() {
      NotificationsHaptics.markAllReadPulse();
      ref.read(notificationsProvider.notifier).markAllAsRead();
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
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
                        style: AppTypography.titleMedium,
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
            Divider(height: 1, color: AppColors.borderSubtle),
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
                              onAction: (action) =>
                                  _handleAction(context, ref, notification, action),
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

  /// Routes a contextual action. Deep-link actions carrying a `route` payload
  /// navigate to the track detail surface; other kinds are no-ops in this
  /// offline-first milestone.
  void _handleAction(
    BuildContext context,
    WidgetRef ref,
    NotificationEntity notification,
    NotificationAction action,
  ) {
    NotificationsHaptics.itemTap();
    ref.read(notificationsProvider.notifier).markAsRead(notification.id);
    final route = action.actionData['route'] as String?;
    if (route != null && route.startsWith('/track/')) {
      final trackId = route.substring('/track/'.length);
      if (trackId.isNotEmpty) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TrackDetailView(trackId: trackId),
          ),
        );
      }
    }
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
      icon: const Icon(Icons.done_all_rounded, size: 18),
      label: Text(
        'Mark all read',
        style: AppTypography.caption.copyWith(
          color: enabled ? AppColors.brandPrimary : AppColors.textTertiary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
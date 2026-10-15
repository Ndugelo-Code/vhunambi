import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/notification_entity.dart';
import '../../domain/models/notification_enums.dart';
import '../providers/notifications_provider.dart';
import '../utils/notification_category_style.dart';
import '../utils/notifications_haptics.dart';
import '../utils/time_ago_utils.dart';

/// Swipeable, accessible notification card for the Notifications Center.
///
/// Features (blueprint §8.2):
/// - [Dismissible] swipe-to-dismiss with an elastic trash icon that scales
///   `0.8 → 1.2` (`Curves.easeOutBack`) as the drag crosses 80px, firing
///   [NotificationsHaptics.dismissSnap] at the threshold.
/// - Category glyph badge tinted by the category accent token.
/// - Unread dot with a smooth 300ms fade-out when read.
/// - Contextual action rail with 44px-tall buttons.
/// - Tap marks read and invokes [onTap] (deep link).
class NotificationItemTile extends ConsumerStatefulWidget {
  const NotificationItemTile({
    super.key,
    required this.notification,
    this.onTap,
    this.onAction,
  });

  final NotificationEntity notification;

  /// Invoked (after marking read) when the card body is tapped.
  final VoidCallback? onTap;

  /// Invoked when a contextual action button is pressed.
  final void Function(NotificationAction action)? onAction;

  @override
  ConsumerState<NotificationItemTile> createState() =>
      _NotificationItemTileState();
}

class _NotificationItemTileState extends ConsumerState<NotificationItemTile> {
  /// 0.0 → 1.0 drag progress toward the dismiss threshold, drives the icon.
  final ValueNotifier<double> _dragProgress = ValueNotifier<double>(0);
  bool _snapFired = false;

  @override
  void dispose() {
    _dragProgress.dispose();
    super.dispose();
  }

  void _onMove(DismissUpdateDetails details) {
    final progress = (details.progress).clamp(0.0, 1.0);
    _dragProgress.value = progress;
    if (progress >= 0.5 && !_snapFired) {
      _snapFired = true;
      NotificationsHaptics.dismissSnap();
    } else if (progress < 0.5) {
      _snapFired = false;
    }
  }

  void _handleTap() {
    NotificationsHaptics.itemTap();
    ref.read(notificationsProvider.notifier).markAsRead(widget.notification.id);
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final notification = widget.notification;
    final accent = NotificationCategoryStyle.color(notification.category);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xxs,
      ),
      child: Dismissible(
        key: Key('notif_tile_${notification.id}'),
        direction: DismissDirection.horizontal,
        onUpdate: _onMove,
        onDismissed: (_) {
          _dragProgress.value = 1;
          ref
              .read(notificationsProvider.notifier)
              .removeNotification(notification.id);
        },
        background: _SwipeDismissBackground(
          dragProgress: _dragProgress,
          alignment: Alignment.centerLeft,
        ),
        secondaryBackground: _SwipeDismissBackground(
          dragProgress: _dragProgress,
          alignment: Alignment.centerRight,
        ),
        child: _NotificationCardBody(
          notification: notification,
          accent: accent,
          onTap: _handleTap,
          onAction: widget.onAction,
        ),
      ),
    );
  }
}


/// Red/brand delete backdrop whose trash icon elastically scales with drag.
class _SwipeDismissBackground extends StatelessWidget {
  const _SwipeDismissBackground({
    required this.dragProgress,
    required this.alignment,
  });

  final ValueNotifier<double> dragProgress;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.16),
        borderRadius: AppRadius.cardBorder,
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: ValueListenableBuilder<double>(
        valueListenable: dragProgress,
        builder: (context, progress, child) {
          // Elastic scale 0.8 → 1.2 across the 80px threshold.
          final scale = 0.8 + (progress.clamp(0.0, 1.0) * 0.4);
          return Transform.scale(
            scale: scale,
            child: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.error,
              size: 26,
            ),
          );
        },
      ),
    );
  }
}

/// The card surface: category glyph, title, message, timestamp, unread dot,
/// and the contextual action rail.
class _NotificationCardBody extends StatelessWidget {
  const _NotificationCardBody({
    required this.notification,
    required this.accent,
    required this.onTap,
    this.onAction,
  });

  final NotificationEntity notification;
  final Color accent;
  final VoidCallback onTap;
  final void Function(NotificationAction action)? onAction;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardBorder,
        side: const BorderSide(color: AppColors.borderSubtle),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardBorder,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _CategoryGlyphBadge(notification: notification, accent: accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            notification.title,
                            key: const Key('notification_tile_title'),
                            style: AppTypography.bodySmall.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        _UnreadDot(isRead: notification.isRead),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${notification.message} • '
                      '${TimeAgoUtils.format(notification.createdAt)}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (notification.actions.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      _ActionRail(
                        actions: notification.actions,
                        accent: accent,
                        onAction: onAction,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Circular category-tinted glyph container.
class _CategoryGlyphBadge extends StatelessWidget {
  const _CategoryGlyphBadge({required this.notification, required this.accent});

  final NotificationEntity notification;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      child: Icon(
        NotificationCategoryStyle.icon(notification.category),
        color: accent,
        size: 20,
      ),
    );
  }
}

/// Unread indicator that fades out smoothly (300ms) once the alert is read.
class _UnreadDot extends StatelessWidget {
  const _UnreadDot({required this.isRead});

  final bool isRead;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isRead ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: Container(
        key: const Key('notification_unread_dot'),
        width: 8,
        height: 8,
        margin: const EdgeInsets.only(left: AppSpacing.xs),
        decoration: const BoxDecoration(
          color: AppColors.brandPrimary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Horizontal rail of contextual action buttons (44px touch target).
class _ActionRail extends StatelessWidget {
  const _ActionRail({
    required this.actions,
    required this.accent,
    this.onAction,
  });

  final List<NotificationAction> actions;
  final Color accent;
  final void Function(NotificationAction action)? onAction;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xxs,
      children: <Widget>[
        for (final action in actions)
          OutlinedButton(
            key: Key('notification_action_${action.actionId}'),
            onPressed: () => onAction?.call(action),
            style: OutlinedButton.styleFrom(
              foregroundColor: accent,
              side: BorderSide(color: accent.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              minimumSize: const Size(44, 36),
              tapTargetSize: MaterialTapTargetSize.padded,
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.pillBorder,
              ),
            ),
            child: Text(
              action.label,
              style: AppTypography.caption.copyWith(
                color: accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

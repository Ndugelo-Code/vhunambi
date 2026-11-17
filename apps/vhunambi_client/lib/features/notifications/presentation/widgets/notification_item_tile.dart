import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/notification_entity.dart';
import '../../domain/models/notification_enums.dart';
import '../providers/notifications_provider.dart';
import '../utils/notification_category_style.dart';
import '../utils/notifications_haptics.dart';
import '../utils/time_ago_utils.dart';

/// Swipeable, accessible notification card for the Notifications Center (Phase 67).
class NotificationItemTile extends ConsumerStatefulWidget {
  const NotificationItemTile({
    super.key,
    required this.notification,
    this.onTap,
    this.onAction,
  });

  final NotificationEntity notification;
  final VoidCallback? onTap;
  final void Function(NotificationAction action)? onAction;

  @override
  ConsumerState<NotificationItemTile> createState() =>
      _NotificationItemTileState();
}

class _NotificationItemTileState extends ConsumerState<NotificationItemTile> {
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
    FocusManager.instance.primaryFocus?.unfocus();
    NotificationsHaptics.itemTap();
    ref.read(notificationsProvider.notifier).markAsRead(widget.notification.id);
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final notification = widget.notification;
    final accent = NotificationCategoryStyle.entityColor(notification);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 5,
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

/// Red/brand delete backdrop whose Phosphor trash icon elastically scales with drag.
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
          final scale = 0.8 + (progress.clamp(0.0, 1.0) * 0.4);
          return Transform.scale(
            scale: scale,
            child: const PhosphorIcon(
              AppIcons.trash,
              color: AppColors.error,
              size: 24,
            ),
          );
        },
      ),
    );
  }
}

/// Refined LODA obsidian card surface with directional left-edge glow,
/// category pill badge, inline category timestamp dot, and trailing chevron.
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
    final isUnread = !notification.isRead;
    final baseSurface = isUnread
        ? AppColors.surfaceElevatedOf(context)
        : AppColors.surfaceCanvasOf(context);
    final borderColor = isUnread
        ? accent.withValues(alpha: 0.28)
        : AppColors.borderSubtleOf(context);
    final washAlpha = isUnread ? 0.13 : 0.05;

    return Container(
      decoration: BoxDecoration(
        color: baseSurface,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: borderColor, width: 1),
      ),
      child: ClipRRect(
        borderRadius: AppRadius.cardBorder,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.cardBorder,
            child: Stack(
              children: <Widget>[
                // Subtle directional left-edge radial/linear color wash (8%–14% alpha)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          stops: const <double>[0.0, 0.48, 1.0],
                          colors: <Color>[
                            accent.withValues(alpha: washAlpha),
                            accent.withValues(alpha: washAlpha * 0.22),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // 3px vertical left-edge semantic category glow bar
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 3,
                  child: Container(
                    key: Key('notification_left_glow_bar_${notification.id}'),
                    decoration: BoxDecoration(
                      color: isUnread ? accent : accent.withValues(alpha: 0.45),
                      boxShadow: isUnread
                          ? <BoxShadow>[
                              BoxShadow(
                                color: accent.withValues(alpha: 0.45),
                                blurRadius: 8,
                                spreadRadius: 0.5,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.sm,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      _CategoryGlyphBadge(
                        notification: notification,
                        accent: accent,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    notification.title,
                                    key: const Key('notification_tile_title'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.bodySmall.copyWith(
                                      fontWeight: isUnread
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      color: AppColors.textPrimaryOf(context),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  TimeAgoUtils.format(notification.createdAt),
                                  style: AppTypography.caption.copyWith(
                                    color: isUnread
                                        ? AppColors.textSecondaryOf(context)
                                        : AppColors.textTertiary,
                                    fontWeight: isUnread
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                                _UnreadDot(
                                  isRead: notification.isRead,
                                  accent: accent,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              notification.message,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondaryOf(context),
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: <Widget>[
                                _CategoryPillBadge(
                                  notification: notification,
                                  accent: accent,
                                ),
                                if (notification.ctaLabel != null &&
                                    notification.ctaLabel!.isNotEmpty) ...<Widget>[
                                  const SizedBox(width: AppSpacing.xs),
                                  Flexible(
                                    child: Text(
                                      notification.ctaLabel!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.badge.copyWith(
                                        color: accent,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
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
                      const SizedBox(width: AppSpacing.xs),
                      PhosphorIcon(
                        PhosphorIconsRegular.caretRight,
                        key: Key(
                          'notification_trailing_chevron_${notification.id}',
                        ),
                        size: 16,
                        color: isUnread
                            ? accent.withValues(alpha: 0.85)
                            : AppColors.textTertiary,
                      ),
                    ],
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
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.28), width: 1),
      ),
      child: Center(
        child: PhosphorIcon(
          NotificationCategoryStyle.entityIcon(notification),
          color: accent,
          size: 20,
        ),
      ),
    );
  }
}

class _CategoryPillBadge extends StatelessWidget {
  const _CategoryPillBadge({
    required this.notification,
    required this.accent,
  });

  final NotificationEntity notification;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('notification_category_pill_${notification.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: AppRadius.pillBorder,
        border: Border.all(color: accent.withValues(alpha: 0.28), width: 0.8),
      ),
      child: Text(
        NotificationCategoryStyle.pillLabel(notification),
        style: AppTypography.badge.copyWith(
          color: accent,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Unread indicator tinted by the notification's semantic category accent.
class _UnreadDot extends StatelessWidget {
  const _UnreadDot({required this.isRead, required this.accent});

  final bool isRead;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isRead ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: Container(
        key: const Key('notification_unread_dot'),
        width: 7,
        height: 7,
        margin: const EdgeInsets.only(left: 6),
        decoration: BoxDecoration(
          color: accent,
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: accent.withValues(alpha: 0.5),
              blurRadius: 4,
            ),
          ],
        ),
      ),
    );
  }
}

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
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
              onAction?.call(action);
            },
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

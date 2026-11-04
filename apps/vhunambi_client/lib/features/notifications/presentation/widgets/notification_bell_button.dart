import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/notification_entity.dart';
import '../providers/notifications_provider.dart';
import '../utils/notifications_haptics.dart';
import '../views/notifications_view.dart';

/// Reusable header bell with a live unread badge (T11.4).
///
/// Binds to [unreadNotificationsCountProvider]; tapping opens the alerts
/// drawer. Phase 3 wraps the glyph in a [WobblingNotificationBell] that
/// performs a 3-cycle dampened sine ring (`±14°` over 320ms) on tap or when a
/// high-priority alert arrives.
class NotificationBellButton extends ConsumerStatefulWidget {
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
  ConsumerState<NotificationBellButton> createState() =>
      _NotificationBellButtonState();
}

class _NotificationBellButtonState
    extends ConsumerState<NotificationBellButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wobbleController;
  int _lastEscalatedUnread = 0;

  @override
  void initState() {
    super.initState();
    _wobbleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
  }

  @override
  void dispose() {
    _wobbleController.dispose();
    super.dispose();
  }

  void _ring() {
    if (!mounted) return;
    // Respect reduced-motion: skip the animation, keep the haptic.
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return;
    _wobbleController.forward(from: 0);
  }

  void _handleTap() {
    NotificationsHaptics.bellRing();
    _ring();
    final onPressed = widget.onPressed;
    if (onPressed != null) {
      onPressed();
    } else {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const NotificationsView()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    // Ring when a new high/urgent unread alert arrives (not on mount/read).
    ref.listen<List<NotificationEntity>>(notificationsProvider, (prev, next) {
      final escalated = next
          .where((n) => !n.isRead && n.priority.isEscalated)
          .length;
      if (escalated > _lastEscalatedUnread) _ring();
      _lastEscalatedUnread = escalated;
    });
    // Seed the baseline so a mount-time escalated alert doesn't auto-ring.
    final seededEscalated = ref
        .read(notificationsProvider)
        .where((n) => !n.isRead && n.priority.isEscalated)
        .length;
    if (_lastEscalatedUnread == 0 && seededEscalated > 0) {
      _lastEscalatedUnread = seededEscalated;
    }

    return Tooltip(
      message: NotificationBellButton.tooltip,
      child: InkWell(
        onTap: _handleTap,
        borderRadius: BorderRadius.circular(22),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                WobblingNotificationBell(
                  controller: _wobbleController,
                  iconSize: widget.iconSize,
                  color: widget.color ?? AppColors.textSecondaryOf(context),
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
      ),
    );
  }
}

/// The bell glyph with a 3-cycle dampened sine rotation (`±14°` / 320ms).
///
/// Extracted as its own widget so the controller lifecycle stays isolated and
/// the public [NotificationBellButton] API is unchanged.
class WobblingNotificationBell extends AnimatedWidget {
  const WobblingNotificationBell({
    super.key,
    required this.controller,
    required this.iconSize,
    required this.color,
  }) : super(listenable: controller);

  final AnimationController controller;
  final double iconSize;
  final Color color;

  /// Maximum rotational amplitude in radians (~14°).
  static const double _maxAngle = 14 * math.pi / 180;

  @override
  Widget build(BuildContext context) {
    final t = controller.value;
    // Dampened sine: 3 full cycles, amplitude decaying to 0 by t = 1.
    final angle = _maxAngle * math.sin(t * 3 * 2 * math.pi) * (1 - t);
    return Transform.rotate(
      angle: angle,
      child: Icon(
        Icons.notifications_none_rounded,
        size: iconSize,
        color: color,
      ),
    );
  }
}


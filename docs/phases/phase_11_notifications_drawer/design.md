# Phase 11 · Design — Notifications Drawer & Real-Time Alert System

> **Phase:** 11  
> **Codename:** `notifications-drawer`  
> **Target Package:** `apps/vhunambi_client`  
> **Status:** 🟡 SPECIFICATION  

---

## 1. Provider & State Architecture

### `features/notifications/presentation/providers/notifications_provider.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/notification_entity.dart';

/// Seeded notifications for demonstration and initial presentation.
List<NotificationEntity> get seededNotifications => [
  NotificationEntity(
    id: 'notif_seed_1',
    title: 'Your song "ZaYN" is ready!',
    message: 'House • 3:20',
    targetTrackId: 'trk_pipeline_001',
    createdAt: DateTime.now().subtract(const Duration(minutes: 9)),
    isRead: false,
  ),
  NotificationEntity(
    id: 'notif_seed_2',
    title: 'Your song "Shikisha" is ready!',
    message: 'Amapiano • 4:12',
    targetTrackId: 'trk_pipeline_002',
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    isRead: false,
  ),
  NotificationEntity(
    id: 'notif_seed_3',
    title: 'Welcome to Vhunambi!',
    message: 'Start generating high-fidelity African regional music.',
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    isRead: true,
  ),
];

/// StateNotifier that manages in-app notifications (newest first).
class NotificationsNotifier extends StateNotifier<List<NotificationEntity>> {
  NotificationsNotifier([List<NotificationEntity>? initial])
      : super(initial ?? seededNotifications);

  /// Prepends a new notification to the top of the list.
  void addNotification(NotificationEntity notification) {
    state = [notification, ...state];
  }

  /// Backward-compatible adapter for Phase 10's StateProvider `.update()` calls.
  void update(List<NotificationEntity> Function(List<NotificationEntity>) updater) {
    state = updater(state);
  }

  /// Marks a single notification as read by [id].
  void markAsRead(String id) {
    state = state
        .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
        .toList();
  }

  /// Marks every existing notification as read.
  void markAllAsRead() {
    state = state.map((n) => n.copyWith(isRead: true)).toList();
  }

  /// Removes an individual notification by [id].
  void removeNotification(String id) {
    state = state.where((n) => n.id != id).toList();
  }

  /// Clears all notifications.
  void clearAll() {
    state = const [];
  }
}

/// Global provider for the notification list.
final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, List<NotificationEntity>>(
  (ref) => NotificationsNotifier(),
);

/// Computed count of unread notifications.
final unreadNotificationsCountProvider = Provider<int>((ref) {
  final list = ref.watch(notificationsProvider);
  return list.where((n) => !n.isRead).length;
});
```

---

## 2. Utility: Relative Timestamp Formatter

### `features/notifications/presentation/utils/time_ago_utils.dart`

```dart
class TimeAgoUtils {
  /// Converts a [DateTime] into a concise relative string.
  static String format(DateTime dateTime, {DateTime? clock}) {
    final now = clock ?? DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.isNegative || difference.inSeconds < 45) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
```

---

## 3. Popover Interface: `NotificationsPopover`

### `features/notifications/presentation/widgets/notifications_popover.dart`

`NotificationsPopover` is refactored from `StatelessWidget` to `ConsumerWidget`:

```dart
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
        child: NotificationsPopover(),
      ),
    );
  }
...
```

**Key UI Behaviors:**
1. **Header Row:**
   - Bell icon (`Icons.notifications_outlined`, `AppColors.brandPrimary`).
   - Title `"Notifications"`.
   - Dynamic counter badge `[ unreadCount ]` if `unreadCount > 0`.
   - `"Mark all read"` link calling `ref.read(notificationsProvider.notifier).markAllAsRead()`.
2. **List Area:**
   - Constrained to `maxHeight: 400` with `SingleChildScrollView` or `ListView.separated`.
   - If `notifications.isEmpty`: renders `_EmptyNotificationsState`.
   - Each item renders `_NotificationCard`:
     - Icon container (36x36 circular, `Icons.music_note_rounded`).
     - Title (`notification.title`).
     - Subtitle (`"${notification.message} • ${TimeAgoUtils.format(notification.createdAt)}"`).
     - Trailing 8x8 orange dot when `!notification.isRead`.
     - Tap:
       1. `ref.read(notificationsProvider.notifier).markAsRead(notification.id)`
       2. `Navigator.of(context).pop()`
       3. If `notification.targetTrackId != null`:
          `Navigator.of(context).push(MaterialPageRoute(builder: (_) => TrackDetailView(trackId: notification.targetTrackId!)))`
3. **Footer Row:**
   - `"Clear all"` button: calls `ref.read(notificationsProvider.notifier).clearAll()`.
   - `"Close"` button: dismisses dialog via `Navigator.of(context).pop()`.

---

## 4. Top Bar Bell Button: `NotificationBellButton`

### `features/notifications/presentation/widgets/notification_bell_button.dart`

```dart
class NotificationBellButton extends ConsumerWidget {
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

    return InkWell(
      onTap: onPressed ?? () => NotificationsPopover.show(context),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
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
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
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
                      color: Colors.black,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

---

## 5. Top Bar Integrations

1. **`lib/features/explore/presentation/widgets/explore_top_bar.dart`:**
   Replace the notification `_HeaderIconButton` with `NotificationBellButton()`.
2. **`lib/features/library/presentation/widgets/library_app_bar.dart`:**
   Replace both desktop and mobile notification `_HeaderIconButton` with `NotificationBellButton()`.
3. **`lib/features/marketplace/presentation/widgets/marketplace_top_bar.dart`:**
   Replace notification `IconButton` with `NotificationBellButton()`.
4. **`lib/features/studio/presentation/views/studio_view.dart`:**
   Replace empty `IconButton` with `NotificationBellButton()`.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/notification_entity.dart';

/// Seeded notifications for demonstration and preview surfaces.
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
      : super(initial ?? const <NotificationEntity>[]);

  /// Prepends a new notification to the top of the list.
  void addNotification(NotificationEntity notification) {
    state = <NotificationEntity>[notification, ...state];
  }

  /// Backward-compatible adapter for Phase 10's StateProvider `.update()` calls.
  void update(
    List<NotificationEntity> Function(List<NotificationEntity>) updater,
  ) {
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

  /// Clears all notifications from the state list.
  void clearAll() {
    state = const <NotificationEntity>[];
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

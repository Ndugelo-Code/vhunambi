import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../creator_dna/presentation/providers/creator_dna_provider.dart';
import '../../domain/models/notification_entity.dart';
import '../../domain/models/notification_enums.dart';

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

/// Currently selected category filter in the Notifications Center.
///
/// `null` represents the "All" tab (no category filtering).
final selectedCategoryProvider = StateProvider<NotificationCategory?>(
  (ref) => null,
);

/// Active search query for the Notifications Center list.
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Unread count per category — powers the bouncing rail badges.
final unreadCountByCategoryProvider =
    Provider<Map<NotificationCategory, int>>((ref) {
  final list = ref.watch(notificationsProvider);
  final counts = <NotificationCategory, int>{
    for (final c in NotificationCategory.values) c: 0,
  };
  for (final n in list) {
    if (!n.isRead) {
      counts[n.category] = (counts[n.category] ?? 0) + 1;
    }
  }
  return counts;
});

/// Category + search + DNA-ranked view of the notification list.
///
/// - Filters by the active [selectedCategoryProvider] (null = all).
/// - Filters by the [searchQueryProvider] (case-insensitive title/message).
/// - Boosts `algorithmic` notifications whose `metadata['genre']` matches one
///   of the creator's top DNA genres so they surface first.
/// - Otherwise sorts by `priority` (desc) then `createdAt` (desc).
final filteredNotificationsProvider = Provider<List<NotificationEntity>>((ref) {
  final list = ref.watch(notificationsProvider);
  final category = ref.watch(selectedCategoryProvider);
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();
  final dna = ref.watch(creatorDnaProvider);

  Iterable<NotificationEntity> filtered = list;

  if (category != null) {
    filtered = filtered.where((n) => n.category == category);
  }

  if (query.isNotEmpty) {
    filtered = filtered.where(
      (n) =>
          n.title.toLowerCase().contains(query) ||
          n.message.toLowerCase().contains(query),
    );
  }

  final result = filtered.toList();

  // DNA affinity weight for algorithmic discovery alerts.
  double dnaAffinity(NotificationEntity n) {
    if (n.category != NotificationCategory.algorithmic) return 0;
    if (!dna.onboardingCompleted) return 0;
    final genre = n.metadata['genre'] as String?;
    if (genre == null || genre.isEmpty) return 0;
    // Weight = accumulated DNA affinity for that genre (0 when unknown).
    return dna.genreWeights[genre] ?? 0;
  }

  result.sort((a, b) {
    final affinityDelta = dnaAffinity(b).compareTo(dnaAffinity(a));
    if (affinityDelta != 0) return affinityDelta;

    final priorityDelta = b.priority.weight.compareTo(a.priority.weight);
    if (priorityDelta != 0) return priorityDelta;

    return b.createdAt.compareTo(a.createdAt);
  });

  return result;
});

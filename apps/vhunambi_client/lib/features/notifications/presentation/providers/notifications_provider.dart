import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/core/storage/sovereign_domain_repositories.dart';
import '../../../creator_dna/presentation/providers/creator_dna_provider.dart';
import '../../data/repositories/notification_repository.dart';
import '../../domain/models/notification_entity.dart';
import '../../domain/models/notification_enums.dart';

/// Phase 40 authentic seeded notifications spanning all 4 canonical categories:
/// Social, System, Activity (creatorActivity), and Discovery (algorithmic).
List<NotificationEntity> get phase40SeededNotifications => [
  NotificationEntity(
    id: 'notif_p40_soc_1',
    title: 'New Cultural Gift Received!',
    message: '@lerato_piano sent Royal Venda Crown (200 Coins)',
    category: NotificationCategory.social,
    priority: NotificationPriority.high,
    createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
    metadata: const {'sender': '@lerato_piano', 'coins': 200},
  ),
  NotificationEntity(
    id: 'notif_p40_soc_2',
    title: 'Open Stems Collaboration',
    message: '@makhadzi opened stems on "Ndo Mufuna Matibe"',
    category: NotificationCategory.social,
    priority: NotificationPriority.normal,
    createdAt: DateTime.now().subtract(const Duration(hours: 1)),
  ),
  NotificationEntity(
    id: 'notif_p40_soc_3',
    title: 'New Open-Verse Remix',
    message: '@fifi dropped an energetic remix on your Private School beat',
    category: NotificationCategory.social,
    priority: NotificationPriority.normal,
    createdAt: DateTime.now().subtract(const Duration(hours: 3)),
  ),
  NotificationEntity(
    id: 'notif_p40_act_1',
    title: 'Marketplace License Sold!',
    message: 'Beat license sold: Township Heat (+42 Coins / R38)',
    category: NotificationCategory.creatorActivity,
    priority: NotificationPriority.high,
    createdAt: DateTime.now().subtract(const Duration(hours: 4)),
  ),
  NotificationEntity(
    id: 'notif_p40_act_2',
    title: 'Fresh Crate Graduation Alert!',
    message:
        'Your track reached 25/25 A&R Co-Signs and graduated to Rising Breakout!',
    category: NotificationCategory.creatorActivity,
    priority: NotificationPriority.high,
    createdAt: DateTime.now().subtract(const Duration(hours: 8)),
  ),
  NotificationEntity(
    id: 'notif_p40_act_3',
    title: 'Studio Render Complete',
    message: 'Your song "ZaYN" is ready! House • 3:20 (44.1 kHz 24-bit WAV)',
    category: NotificationCategory.creatorActivity,
    priority: NotificationPriority.normal,
    targetTrackId: 'trk_pipeline_001',
    createdAt: DateTime.now().subtract(const Duration(hours: 12)),
  ),
  NotificationEntity(
    id: 'notif_p40_sys_1',
    title: 'VHU-SIG Continuous Phase DSP Active',
    message:
        'Continuous phase 44.1 kHz audio engine & acoustic resonance active',
    category: NotificationCategory.system,
    priority: NotificationPriority.normal,
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
  ),
  NotificationEntity(
    id: 'notif_p40_sys_2',
    title: 'Welcome to Vhunambi Creator Suite!',
    message:
        'Start generating high-fidelity African regional music and licensing sound stems.',
    category: NotificationCategory.system,
    priority: NotificationPriority.normal,
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
    isRead: true,
  ),
  NotificationEntity(
    id: 'notif_p40_alg_1',
    title: 'Regional Trend Alert',
    message:
        'Maskandi & Private School Amapiano trending in Gauteng (+420% plays)',
    category: NotificationCategory.algorithmic,
    priority: NotificationPriority.normal,
    createdAt: DateTime.now().subtract(const Duration(hours: 6)),
    metadata: const {'genre': 'Amapiano'},
  ),
  NotificationEntity(
    id: 'notif_p40_alg_2',
    title: 'Sonic DNA Affinity Match',
    message:
        'Your vocal timbres match 94% with Tshivenḓa folk and Afro-house rhythms',
    category: NotificationCategory.algorithmic,
    priority: NotificationPriority.normal,
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    metadata: const {'genre': 'Tshivenḓa'},
  ),
];

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

/// StateNotifier that manages in-app notifications (newest first) with
/// Hive O(1) `notif_<id>` persistence.
class NotificationsNotifier extends StateNotifier<List<NotificationEntity>> {
  final NotificationRepository _repo;
  bool _autoSeedPending;

  NotificationsNotifier([
    List<NotificationEntity>? initial,
    NotificationRepository? repository,
  ]) : _repo = repository ?? NotificationRepository(),
       _autoSeedPending = initial == null,
       super(
         initial ??
             _hydrateInitialNotifications(
               repository ?? NotificationRepository(),
             ),
       ) {
    if (state.isNotEmpty) {
      _autoSeedPending = false;
    }
    if (initial == null &&
        SovereignDomainStorageMode.canHydrateFromStorage(
          AppConstants.notificationsBoxKey,
        )) {
      Future<void>.microtask(hydrateFromStorage);
    }
  }

  /// Whether opening [NotificationsView] should auto-seed demo alerts on an
  /// empty default store without overriding explicit test seeds or cleared state.
  bool get shouldAutoSeedDemoAlerts => _autoSeedPending && state.isEmpty;

  static List<NotificationEntity> _hydrateInitialNotifications(
    NotificationRepository repo,
  ) {
    if (!SovereignDomainStorageMode.canHydrateFromStorage(
      AppConstants.notificationsBoxKey,
    )) {
      return const <NotificationEntity>[];
    }
    return repo.getNotificationsSync();
  }

  /// Hydrates from persistent storage asynchronously (migrating any legacy list).
  Future<void> hydrateFromStorage() async {
    final loaded = await _repo.getNotifications();
    if (!mounted || loaded.isEmpty) return;
    _autoSeedPending = false;
    if (state.isEmpty) {
      state = loaded;
    } else {
      final byId = <String, NotificationEntity>{
        for (final n in loaded) n.id: n,
        for (final n in state) n.id: n,
      };
      final merged = byId.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = merged;
    }
  }

  /// Seeds authentic multi-category alerts across Social, System, Activity & Discovery
  /// only if the persisted notification store is empty.
  void seedDemoAlerts() {
    _autoSeedPending = false;
    if (state.isEmpty) {
      final seeds = phase40SeededNotifications;
      state = seeds;
      unawaited(_repo.saveNotifications(seeds));
    }
  }

  /// Prepends a new notification to the top of the list and persists it in O(1).
  void addNotification(NotificationEntity notification) {
    _autoSeedPending = false;
    state = <NotificationEntity>[notification, ...state];
    unawaited(_repo.saveNotification(notification));
  }

  /// Backward-compatible adapter for Phase 10's StateProvider `.update()` calls.
  void update(
    List<NotificationEntity> Function(List<NotificationEntity>) updater,
  ) {
    _autoSeedPending = false;
    final prevIds = state.map((e) => e.id).toSet();
    final next = updater(state);
    state = next;
    final nextIds = next.map((e) => e.id).toSet();
    for (final removedId in prevIds.difference(nextIds)) {
      unawaited(_repo.deleteNotification(removedId));
    }
    if (next.isNotEmpty) {
      unawaited(_repo.saveNotifications(next));
    }
  }

  /// Marks a single notification as read by [id] and writes through in O(1).
  void markAsRead(String id) {
    NotificationEntity? updatedItem;
    state = state.map((n) {
      if (n.id == id) {
        updatedItem = n.copyWith(isRead: true);
        return updatedItem!;
      }
      return n;
    }).toList();
    if (updatedItem != null) {
      unawaited(_repo.saveNotification(updatedItem!));
    }
  }

  /// Marks every existing notification as read and persists the update.
  void markAllAsRead() {
    final updated = state.map((n) => n.copyWith(isRead: true)).toList();
    state = updated;
    if (updated.isNotEmpty) {
      unawaited(_repo.saveNotifications(updated));
    }
  }

  /// Removes an individual notification by [id].
  void removeNotification(String id) {
    _autoSeedPending = false;
    state = state.where((n) => n.id != id).toList();
    unawaited(_repo.deleteNotification(id));
  }

  /// Alias matching NotificationRepository contract.
  void deleteNotification(String id) => removeNotification(id);

  /// Clears all notifications from state and persistent storage.
  void clearAll() {
    _autoSeedPending = false;
    state = const <NotificationEntity>[];
    unawaited(_repo.clearAll());
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
final unreadCountByCategoryProvider = Provider<Map<NotificationCategory, int>>((
  ref,
) {
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

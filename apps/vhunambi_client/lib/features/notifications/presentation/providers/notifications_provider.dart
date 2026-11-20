import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vhunambi_client/core/auth/auth_providers.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/core/resilience/safe_notifier_mixin.dart';
import 'package:vhunambi_client/core/storage/sovereign_domain_repositories.dart';
import '../../../creator_dna/presentation/providers/creator_dna_provider.dart';
import '../../data/repositories/http_notification_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../domain/models/notification_entity.dart';
import '../../domain/models/notification_enums.dart';

/// StateNotifier that manages in-app notifications (newest first) with
/// Hive O(1) `notif_<id>` persistence and bidirectional `/api/notifications` sync.
class NotificationsNotifier extends StateNotifier<List<NotificationEntity>>
    with SafeNotifierMixin<List<NotificationEntity>> {
  final NotificationRepository _repo;
  final HttpNotificationRepository? _remoteRepo;

  NotificationsNotifier([
    List<NotificationEntity>? initial,
    NotificationRepository? repository,
    HttpNotificationRepository? remoteRepository,
  ]) : _repo = repository ?? NotificationRepository(),
       _remoteRepo = remoteRepository,
       super(
         initial ??
             _hydrateInitialNotifications(
               repository ?? NotificationRepository(),
             ),
       ) {
    if (initial == null &&
        SovereignDomainStorageMode.canHydrateFromStorage(
          AppConstants.notificationsBoxKey,
        )) {
      Future<void>.microtask(hydrateFromStorage);
    }
  }

  static List<NotificationEntity> _hydrateInitialNotifications(
    NotificationRepository repo,
  ) {
    if (!SovereignDomainStorageMode.canHydrateFromStorage(
      AppConstants.notificationsBoxKey,
    )) {
      return const <NotificationEntity>[];
    }
    return repo
        .getNotificationsSync()
        .where((n) => !NotificationRepository.isLegacyDemoMockId(n.id))
        .toList();
  }

  /// Hydrates from persistent storage asynchronously, scrubbing legacy Phase 40
  /// demo mocks (`notif_p40_*`, `notif_seed_*`) and preserving in-memory read states,
  /// then reconciles server alerts via `EP-P67-NOTIF-API`.
  Future<void> hydrateFromStorage() async {
    await _repo.scrubLegacyDemoMocks();
    final loaded = (await _repo.getNotifications())
        .where((n) => !NotificationRepository.isLegacyDemoMockId(n.id))
        .toList();
    if (!mounted) return;
    final cleanCurrent = state
        .where((n) => !NotificationRepository.isLegacyDemoMockId(n.id))
        .toList();
    if (loaded.isNotEmpty) {
      if (cleanCurrent.isEmpty) {
        state = loaded;
      } else {
        state = _mergeNotificationLists(base: loaded, overlay: cleanCurrent);
      }
    } else if (cleanCurrent.length != state.length) {
      state = cleanCurrent;
    }
    await syncFromCloud();
  }

  /// Pulls server-emitted notifications (`GET /api/notifications`) and merges
  /// preserving local `isRead` flags without disturbing offline Hive data.
  Future<void> syncFromCloud() async {
    final remote = _remoteRepo;
    if (remote == null || remote.shouldSkipNetwork) return;
    final remoteList = await remote.fetchNotifications();
    if (!mounted || remoteList == null) return;

    final cleanRemote = remoteList
        .where((n) => !NotificationRepository.isLegacyDemoMockId(n.id))
        .toList(growable: false);
    if (cleanRemote.isEmpty) return;

    final merged = _mergeNotificationLists(base: cleanRemote, overlay: state);
    state = merged;
    await _repo.saveNotifications(merged);
  }

  static List<NotificationEntity> _mergeNotificationLists({
    required List<NotificationEntity> base,
    required List<NotificationEntity> overlay,
  }) {
    final byId = <String, NotificationEntity>{for (final n in base) n.id: n};
    for (final current in overlay) {
      if (NotificationRepository.isLegacyDemoMockId(current.id)) continue;
      final stored = byId[current.id];
      if (stored == null) {
        byId[current.id] = current;
      } else {
        byId[current.id] = stored.copyWith(
          isRead: current.isRead || stored.isRead,
        );
      }
    }
    return byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Prepends a new notification (deduplicated by `id`) and persists in O(1).
  void addNotification(NotificationEntity notification) {
    final withoutDup = state.where((n) => n.id != notification.id).toList();
    state = <NotificationEntity>[notification, ...withoutDup];
    unawaited(_repo.saveNotification(notification));
    if (_remoteRepo != null) {
      unawaited(_remoteRepo.upsertNotification(notification));
    }
  }

  /// Upserts a notification while preserving its existing `isRead` flag if present.
  void upsertNotification(NotificationEntity notification) {
    final existingIdx = state.indexWhere((n) => n.id == notification.id);
    if (existingIdx < 0) {
      addNotification(notification);
      return;
    }
    final existing = state[existingIdx];
    final merged = notification.copyWith(isRead: existing.isRead);
    final next = <NotificationEntity>[...state];
    next[existingIdx] = merged;
    state = next;
    unawaited(_repo.saveNotification(merged));
    if (_remoteRepo != null) {
      unawaited(_remoteRepo.upsertNotification(merged));
    }
  }

  /// Backward-compatible adapter for Phase 10's StateProvider `.update()` calls.
  void update(
    List<NotificationEntity> Function(List<NotificationEntity>) updater,
  ) {
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
      if (_remoteRepo != null) {
        unawaited(_remoteRepo.markRead(id));
      }
    }
  }

  /// Marks every existing notification as read and persists the update.
  void markAllAsRead() {
    final updated = state.map((n) => n.copyWith(isRead: true)).toList();
    state = updated;
    if (updated.isNotEmpty) {
      unawaited(_repo.saveNotifications(updated));
      if (_remoteRepo != null) {
        unawaited(_remoteRepo.markAllRead());
      }
    }
  }

  /// Removes an individual notification by [id].
  void removeNotification(String id) {
    state = state.where((n) => n.id != id).toList();
    unawaited(_repo.deleteNotification(id));
    if (_remoteRepo != null) {
      unawaited(_remoteRepo.deleteNotification(id));
    }
  }

  /// Alias matching NotificationRepository contract.
  void deleteNotification(String id) => removeNotification(id);

  /// Clears all notifications from state and persistent storage.
  void clearAll() {
    state = const <NotificationEntity>[];
    unawaited(_repo.clearAll());
  }
}

/// Global provider for the notification list, scoped cleanly per tenant creator.
final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, List<NotificationEntity>>((
      ref,
    ) {
      ref.watch(currentCreatorIdProvider);
      final remoteRepo = ref.watch(httpNotificationRepositoryProvider);
      return NotificationsNotifier(null, null, remoteRepo);
    });

/// Unread count per category — single partition source of truth (`REQ-P67-ONB-03`).
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

/// Total unread count derived directly from [unreadCountByCategoryProvider]
/// so `All` and per-category badges can never disagree (`REQ-P67-ONB-03`).
final unreadNotificationsCountProvider = Provider<int>((ref) {
  final byCategory = ref.watch(unreadCountByCategoryProvider);
  return byCategory.values.fold<int>(0, (sum, count) => sum + count);
});

/// Currently selected category filter in the Notifications Center.
///
/// `null` represents the "All" tab (no category filtering).
final selectedCategoryProvider = StateProvider<NotificationCategory?>(
  (ref) => null,
);

/// Active search query for the Notifications Center list.
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Category + search + DNA-ranked view of the notification list.
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

  double dnaAffinity(NotificationEntity n) {
    if (n.category != NotificationCategory.algorithmic) return 0;
    if (!dna.onboardingCompleted) return 0;
    final genre = n.metadata['genre'] as String?;
    if (genre == null || genre.isEmpty) return 0;
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

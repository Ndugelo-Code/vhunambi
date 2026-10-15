import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/models/notification_entity.dart';

/// Offline persistence layer for the Accessible Notifications Center (M8).
///
/// Adheres strictly to the Vhunambi repository standard (see
/// [CreatorDnaRepository], `PlaylistRepository`, `BeatRepository`):
/// - An **untyped** `Box?` opened only when already available.
/// - An automatic in-memory fallback map so headless VM / widget tests never
///   touch Hive's uninitialized path (no unhandled zone exceptions).
/// - Hand-rolled JSON (`toJson` / `fromJson`) — **zero** `build_runner` or
///   `@HiveType` codegen.
class NotificationRepository {
  /// Single collection key holding the serialized notification list.
  static const String _collectionKey = 'notifications';

  /// Upper bound to keep the persisted store from growing unbounded.
  static const int maxNotifications = 500;

  Box? _box;
  final Map<String, dynamic> _inMemoryStore = <String, dynamic>{};
  bool _initialized = false;

  NotificationRepository([Box? box]) : _box = box;

  /// Lazily binds to the notifications Hive box when it is already open.
  ///
  /// Mirrors the safe-storage invariant from the master handoff: never call
  /// `Hive.openBox()` unconditionally — only adopt an already-open box, else
  /// silently degrade to the in-memory fallback.
  Future<void> _ensureInit() async {
    if (_initialized) return;
    if (_box != null) {
      _initialized = true;
      return;
    }
    try {
      if (!kIsWeb && Hive.isBoxOpen(AppConstants.notificationsBoxKey)) {
        _box = Hive.box(AppConstants.notificationsBoxKey);
      }
    } catch (e) {
      debugPrint('NotificationRepository running in-memory fallback: $e');
    }
    _initialized = true;
  }

  /// Reads every stored notification, newest-first.
  ///
  /// Returns an empty list when nothing is persisted or on a read failure
  /// (defensive — never throws into the UI).
  Future<List<NotificationEntity>> getNotifications() async {
    await _ensureInit();
    try {
      final raw =
          _box != null ? _box!.get(_collectionKey) : _inMemoryStore[_collectionKey];
      if (raw == null) return <NotificationEntity>[];
      final decoded = (raw as List)
          .whereType<Map>()
          .map((e) => NotificationEntity.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      decoded.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return decoded;
    } catch (_) {
      return <NotificationEntity>[];
    }
  }

  /// Inserts or replaces a single notification (keyed by `id`).
  Future<void> saveNotification(NotificationEntity notification) async {
    await saveNotifications(<NotificationEntity>[notification]);
  }

  /// Bulk upsert that enforces the [maxNotifications] ceiling by evicting the
  /// oldest read notifications first, then the oldest overall.
  Future<void> saveNotifications(List<NotificationEntity> notifications) async {
    await _ensureInit();
    try {
      final existing = await getNotifications();
      final byId = <String, NotificationEntity>{
        for (final n in existing) n.id: n,
      };
      for (final n in notifications) {
        byId[n.id] = n;
      }

      var merged = byId.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (merged.length > maxNotifications) {
        // Evict oldest read entries first, preserving unread context.
        final read = merged.where((n) => n.isRead).toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        final overflow = merged.length - maxNotifications;
        final evictIds = <String>{};
        for (final n in read) {
          if (evictIds.length >= overflow) break;
          evictIds.add(n.id);
        }
        if (evictIds.length < overflow) {
          for (final n in merged.reversed) {
            if (evictIds.length >= overflow) break;
            evictIds.add(n.id);
          }
        }
        merged = merged.where((n) => !evictIds.contains(n.id)).toList();
      }

      await _persist(merged);
    } catch (_) {
      // Swallow write failures — offline degradation is silent by design.
    }
  }

  /// Removes a single notification by [id].
  Future<void> deleteNotification(String id) async {
    await _ensureInit();
    try {
      final existing = await getNotifications();
      await _persist(existing.where((n) => n.id != id).toList());
    } catch (_) {}
  }

  /// Wipes the entire notification collection.
  Future<void> clearAll() async {
    await _ensureInit();
    try {
      if (_box != null) {
        await _box!.delete(_collectionKey);
      } else {
        _inMemoryStore.remove(_collectionKey);
      }
    } catch (_) {}
  }

  /// Shared write path serializing the list into the active store.
  Future<void> _persist(List<NotificationEntity> notifications) async {
    final serialized = notifications.map((n) => n.toJson()).toList();
    if (_box != null) {
      await _box!.put(_collectionKey, serialized);
    } else {
      _inMemoryStore[_collectionKey] = serialized;
    }
  }
}

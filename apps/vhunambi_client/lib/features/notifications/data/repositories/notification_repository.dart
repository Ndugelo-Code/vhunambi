import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/storage/hive_compaction_scheduler.dart';
import '../../domain/models/notification_entity.dart';

/// Offline persistence layer for the Accessible Notifications Center (M8 / Phase 60 O(1) Upgrade).
///
/// Adheres strictly to the Vhunambi repository standard:
/// - An **untyped** `Box?` adopted only when already available.
/// - $O(1)$ per-entity keys `notif_<id>` instead of monolithic list rewrites,
///   plus automatic one-time migration from legacy `'notifications'` list key.
/// - Instance-scoped in-memory fallback map so headless VM / widget tests never
///   touch Hive's uninitialized path or leak across tests.
class NotificationRepository {
  /// Legacy single collection key retained solely for automatic migration.
  static const String _legacyCollectionKey = 'notifications';

  /// O(1) entity key prefix (`notif_<id>`).
  static const String _entityPrefix = 'notif_';

  /// Upper bound to keep the persisted store from growing unbounded.
  static const int maxNotifications = 500;

  Box? _box;
  final Map<String, dynamic> _inMemoryStore = <String, dynamic>{};
  bool _initialized = false;

  NotificationRepository([Box? box]) : _box = box;

  void _resolveBoxSync() {
    if (_box != null && _box!.isOpen) return;
    try {
      if (!kIsWeb && Hive.isBoxOpen(AppConstants.notificationsBoxKey)) {
        _box = Hive.box(AppConstants.notificationsBoxKey);
      }
    } catch (_) {}
  }

  /// Lazily binds to the notifications Hive box when it is already open.
  Future<void> _ensureInit() async {
    if (_initialized && (_box == null || _box!.isOpen)) {
      _resolveBoxSync();
      return;
    }
    if (_box != null && _box!.isOpen) {
      await _migrateLegacyListIfPresent();
      _initialized = true;
      return;
    }
    try {
      if (!kIsWeb && Hive.isBoxOpen(AppConstants.notificationsBoxKey)) {
        _box = Hive.box(AppConstants.notificationsBoxKey);
        await _migrateLegacyListIfPresent();
      }
    } catch (e) {
      debugPrint('NotificationRepository running in-memory fallback: $e');
    }
    _initialized = true;
  }

  Future<void> _migrateLegacyListIfPresent() async {
    final box = _box;
    if (box == null || !box.isOpen || !box.containsKey(_legacyCollectionKey)) {
      return;
    }
    try {
      final raw = box.get(_legacyCollectionKey);
      if (raw is List) {
        for (final item in raw) {
          if (item is Map) {
            final entity = NotificationEntity.fromJson(
              Map<String, dynamic>.from(item),
            );
            if (entity.id.isNotEmpty) {
              await box.put('$_entityPrefix${entity.id}', entity.toJson());
            }
          }
        }
      }
      await box.delete(_legacyCollectionKey);
    } catch (_) {}
  }

  /// Synchronous read path for cold-boot provider hydration (reads Hive when open).
  List<NotificationEntity> getNotificationsSync() {
    _resolveBoxSync();
    return _readAllDecoded();
  }

  List<NotificationEntity> _readAllDecoded() {
    final decodedById = <String, NotificationEntity>{};
    try {
      if (_box != null && _box!.isOpen) {
        for (final rawKey in _box!.keys) {
          final key = rawKey.toString();
          if (key.startsWith(_entityPrefix)) {
            final val = _box!.get(key);
            if (val is Map) {
              final entity = NotificationEntity.fromJson(
                Map<String, dynamic>.from(val),
              );
              decodedById[entity.id] = entity;
            }
          } else if (key == _legacyCollectionKey) {
            final raw = _box!.get(_legacyCollectionKey);
            if (raw is List) {
              for (final item in raw.whereType<Map>()) {
                final entity = NotificationEntity.fromJson(
                  Map<String, dynamic>.from(item),
                );
                decodedById[entity.id] = entity;
              }
            }
          }
        }
      } else {
        for (final entry in _inMemoryStore.entries) {
          if (entry.key.startsWith(_entityPrefix) && entry.value is Map) {
            final entity = NotificationEntity.fromJson(
              Map<String, dynamic>.from(entry.value as Map),
            );
            decodedById[entity.id] = entity;
          }
        }
      }
      final list = decodedById.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (_) {
      return <NotificationEntity>[];
    }
  }

  /// Reads every stored notification, newest-first.
  Future<List<NotificationEntity>> getNotifications() async {
    await _ensureInit();
    await _migrateLegacyListIfPresent();
    return _readAllDecoded();
  }

  /// Inserts or replaces a single notification in O(1) (keyed by `notif_<id>`).
  Future<void> saveNotification(NotificationEntity notification) async {
    await _ensureInit();
    if (notification.id.isEmpty) return;
    try {
      final key = '$_entityPrefix${notification.id}';
      final serialized = notification.toJson();
      if (_box != null && _box!.isOpen) {
        await _box!.put(key, serialized);
        await _evictOverflowIfNeeded();
        await HiveCompactionScheduler.recordMutation(
          AppConstants.notificationsBoxKey,
        );
      } else {
        _inMemoryStore[key] = serialized;
        await _evictOverflowIfNeeded();
      }
    } catch (_) {}
  }

  /// Bulk upsert that enforces [maxNotifications] ceiling by evicting only
  /// overflow keys (oldest read notifications first, then oldest overall).
  Future<void> saveNotifications(List<NotificationEntity> notifications) async {
    await _ensureInit();
    try {
      for (final n in notifications) {
        if (n.id.isEmpty) continue;
        final key = '$_entityPrefix${n.id}';
        final serialized = n.toJson();
        if (_box != null && _box!.isOpen) {
          await _box!.put(key, serialized);
        } else {
          _inMemoryStore[key] = serialized;
        }
      }
      await _evictOverflowIfNeeded();
      if (_box != null && _box!.isOpen && notifications.isNotEmpty) {
        await HiveCompactionScheduler.recordMutation(
          AppConstants.notificationsBoxKey,
        );
      }
    } catch (_) {}
  }

  Future<void> _evictOverflowIfNeeded() async {
    final currentCount = _box != null && _box!.isOpen
        ? _box!.keys.where((k) => k.toString().startsWith(_entityPrefix)).length
        : _inMemoryStore.keys.where((k) => k.startsWith(_entityPrefix)).length;
    if (currentCount <= maxNotifications) return;

    final all = _readAllDecoded();
    if (all.length <= maxNotifications) return;
    final overflow = all.length - maxNotifications;
    final evictIds = <String>{};

    final read = all.where((n) => n.isRead).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    for (final n in read) {
      if (evictIds.length >= overflow) break;
      evictIds.add(n.id);
    }
    if (evictIds.length < overflow) {
      for (final n in all.reversed) {
        if (evictIds.length >= overflow) break;
        evictIds.add(n.id);
      }
    }

    for (final id in evictIds) {
      final key = '$_entityPrefix$id';
      if (_box != null && _box!.isOpen) {
        await _box!.delete(key);
      } else {
        _inMemoryStore.remove(key);
      }
    }
  }

  /// Removes a single notification by [id] in O(1).
  Future<void> deleteNotification(String id) async {
    await _ensureInit();
    try {
      final key = '$_entityPrefix$id';
      if (_box != null && _box!.isOpen) {
        await _box!.delete(key);
        await HiveCompactionScheduler.recordMutation(
          AppConstants.notificationsBoxKey,
        );
      } else {
        _inMemoryStore.remove(key);
      }
    } catch (_) {}
  }

  /// Wipes the entire notification collection.
  Future<void> clearAll() async {
    await _ensureInit();
    try {
      if (_box != null && _box!.isOpen) {
        final keysToDelete = _box!.keys
            .where((k) {
              final s = k.toString();
              return s.startsWith(_entityPrefix) || s == _legacyCollectionKey;
            })
            .toList(growable: false);
        await _box!.deleteAll(keysToDelete);
      } else {
        _inMemoryStore.clear();
      }
    } catch (_) {}
  }
}

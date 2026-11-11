import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../features/profile/domain/models/profile_models.dart';
import '../constants/app_constants.dart';
import 'cache_entry.dart';

/// In-memory and persistent Hive-backed cache for profile data.
/// Seamlessly falls back to in-memory storage in headless test environments.
class ProfileCache {
  static const int maxCacheSize = 20;
  static const Duration staleThreshold = Duration(hours: 24);

  final Map<String, CacheEntry<ArtistProfileEntity>> _memoryCache = {};
  final Map<String, dynamic> _inMemoryPersistentStore = {};
  Box? _box;
  bool _initialized = false;

  ProfileCache([this._box]);

  Future<void> _ensureInit() async {
    if (_initialized) return;

    if (_box != null) {
      _initialized = true;
      return;
    }

    try {
      if (!kIsWeb && Hive.isBoxOpen(AppConstants.profileBoxKey)) {
        _box = Hive.box(AppConstants.profileBoxKey);
      }
    } catch (e) {
      debugPrint('ProfileCache running in-memory fallback: $e');
    }
    _initialized = true;
  }

  /// Retrieve cached profile by artistId, checking memory first then persistent storage.
  Future<CacheEntry<ArtistProfileEntity>?> get(String artistId) async {
    await _ensureInit();

    // 1. Check in-memory cache
    if (_memoryCache.containsKey(artistId)) {
      return _memoryCache[artistId];
    }

    // 2. Check persistent storage (Hive box or fallback)
    dynamic raw;
    if (_box != null) {
      raw = _box!.get('profile_$artistId');
    } else {
      raw = _inMemoryPersistentStore['profile_$artistId'];
    }

    if (raw != null) {
      try {
        final Map<String, dynamic> data = raw is String
            ? jsonDecode(raw) as Map<String, dynamic>
            : Map<String, dynamic>.from(raw as Map);

        final profile = ArtistProfileEntity.fromJson(
          Map<String, dynamic>.from(data['profile'] as Map),
        );
        final timestamp = DateTime.parse(data['timestamp'] as String);
        final entry = CacheEntry(data: profile, timestamp: timestamp);

        _memoryCache[artistId] = entry;
        return entry;
      } catch (e) {
        debugPrint('Invalid profile cache entry for $artistId: $e');
        if (_box != null) {
          await _box!.delete('profile_$artistId');
        } else {
          _inMemoryPersistentStore.remove('profile_$artistId');
        }
      }
    }

    return null;
  }

  /// Store profile in both memory and persistent cache, enforcing size limits.
  Future<void> put(String artistId, ArtistProfileEntity profile) async {
    await _ensureInit();

    final entry = CacheEntry.now(profile);
    _memoryCache[artistId] = entry;

    final payload = {
      'profile': profile.toJson(),
      'timestamp': entry.timestamp.toIso8601String(),
    };

    if (_box != null) {
      await _box!.put('profile_$artistId', payload);
    } else {
      _inMemoryPersistentStore['profile_$artistId'] = payload;
    }

    await _enforceSizeLimit();
  }

  /// Enforces maxCacheSize (20) by evicting oldest cached entries.
  ///
  /// Permanently pins `'profile_me'` (the signed-in creator owner profile) so
  /// browsing external artist profiles never evicts local owner customizations.
  Future<void> _enforceSizeLimit() async {
    final keys = <String>[];
    if (_box != null) {
      keys.addAll(
        _box!.keys
            .map((k) => k.toString())
            .where((k) => k.startsWith('profile_') && k != 'profile_me'),
      );
    } else {
      keys.addAll(
        _inMemoryPersistentStore.keys.where((k) => k != 'profile_me'),
      );
    }

    if (keys.length <= maxCacheSize) return;

    final entries = <String, DateTime>{};
    for (final key in keys) {
      final raw = _box != null ? _box!.get(key) : _inMemoryPersistentStore[key];
      if (raw != null) {
        try {
          final Map<String, dynamic> data = raw is String
              ? jsonDecode(raw) as Map<String, dynamic>
              : Map<String, dynamic>.from(raw as Map);
          entries[key] = DateTime.parse(data['timestamp'] as String);
        } catch (_) {
          if (_box != null) {
            await _box!.delete(key);
          } else {
            _inMemoryPersistentStore.remove(key);
          }
        }
      }
    }

    final sorted = entries.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    final countToRemove = sorted.length - maxCacheSize;
    if (countToRemove <= 0) return;

    final toRemove = sorted.take(countToRemove);
    for (final entry in toRemove) {
      if (_box != null) {
        await _box!.delete(entry.key);
      } else {
        _inMemoryPersistentStore.remove(entry.key);
      }
      final artistId = entry.key.replaceFirst('profile_', '');
      _memoryCache.remove(artistId);
    }
  }

  /// Remove all cached profile data.
  Future<void> clear() async {
    await _ensureInit();
    _memoryCache.clear();

    if (_box != null) {
      final keys = _box!.keys
          .map((k) => k.toString())
          .where((k) => k.startsWith('profile_'))
          .toList();
      for (final key in keys) {
        await _box!.delete(key);
      }
    } else {
      _inMemoryPersistentStore.clear();
    }
  }
}

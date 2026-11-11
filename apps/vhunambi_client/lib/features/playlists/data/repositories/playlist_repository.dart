import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/core/sync/sync_outbox_service.dart';
import 'package:vhunambi_client/core/utils/creator_id_utils.dart';
import 'package:vhunambi_client/features/playlists/domain/models/playlist_entity.dart';
import 'package:vhunambi_client/features/playlists/domain/repositories/i_playlist_repository.dart';

/// Production Hive + HTTP REST [IPlaylistRepository] (REQ-PV-01 + Phase 59).
///
/// Persists playlist entities locally in [AppConstants.playlistsBoxKey] (or an
/// in-memory fallback map when Hive is uninitialized in headless tests) and
/// synchronizes bidirectionally with `apps/vhunambi_api` (`/api/playlists*`).
class PlaylistRepository implements IPlaylistRepository {
  PlaylistRepository({
    this._box,
    Dio? dio,
    this._outbox,
    String? baseUrl,
    bool? isTestMode,
    this._creatorId = 'creator_cern',
    this._creatorIdReader,
    Interceptor? authInterceptor,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 4),
               receiveTimeout: const Duration(seconds: 4),
               headers: <String, dynamic>{
                 'Content-Type': 'application/json',
                 'Accept': 'application/json',
               },
             ),
           ),
       _baseUrl = baseUrl ?? _resolveDefaultBaseUrl(),
       isTestMode = isTestMode ?? _detectTestMode(),
       _hasCustomDio = dio != null {
    if (dio == null && authInterceptor != null) {
      _dio.interceptors.add(authInterceptor);
    }
  }

  Box? _box;
  final Dio _dio;
  final SyncOutboxService? _outbox;
  final String _creatorId;
  final String Function()? _creatorIdReader;
  final String _baseUrl;
  final bool isTestMode;
  final bool _hasCustomDio;
  final Map<String, PlaylistEntity> _inMemoryFallback =
      <String, PlaylistEntity>{};
  bool _initialized = false;

  String get _activeCreatorId =>
      canonicalizeCreatorId(_creatorIdReader?.call() ?? _creatorId);

  bool get _shouldSkipNetwork => isTestMode && !_hasCustomDio;

  static bool _detectTestMode() {
    if (const bool.fromEnvironment('FLUTTER_TEST')) return true;
    try {
      if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  static String _resolveDefaultBaseUrl() => AppConstants.apiRestBaseUrl;

  Future<void> _ensureInit() async {
    if (_initialized) return;

    if (_box != null) {
      _initialized = true;
      return;
    }

    try {
      if (!kIsWeb && Hive.isBoxOpen(AppConstants.playlistsBoxKey)) {
        _box = Hive.box(AppConstants.playlistsBoxKey);
      }
    } catch (e) {
      debugPrint('PlaylistRepository running in-memory fallback: $e');
    }
    _initialized = true;
  }

  @override
  Future<List<PlaylistEntity>> getAllPlaylists() async {
    await _ensureInit();
    if (_box != null) {
      final list = <PlaylistEntity>[];
      for (final raw in _box!.values) {
        if (raw is Map) {
          list.add(PlaylistEntity.fromJson(Map<String, dynamic>.from(raw)));
        }
      }
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return list;
    }

    final list = _inMemoryFallback.values.toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  @override
  Future<PlaylistEntity?> getPlaylistById(String id) async {
    await _ensureInit();
    if (_box != null) {
      final raw = _box!.get(id);
      if (raw is Map) {
        return PlaylistEntity.fromJson(Map<String, dynamic>.from(raw));
      }
      return null;
    }
    return _inMemoryFallback[id];
  }

  @override
  Future<void> savePlaylist(PlaylistEntity playlist) async {
    await _ensureInit();
    final existed = await getPlaylistById(playlist.id) != null;
    if (_box != null) {
      await _box!.put(playlist.id, playlist.toJson());
    } else {
      _inMemoryFallback[playlist.id] = playlist;
    }

    await _outbox?.enqueue(
      SyncMutationRecord(
        idempotencyKey:
            'mut_pl_${playlist.id}_${playlist.updatedAt.millisecondsSinceEpoch}',
        entityType: 'playlist',
        action: existed ? 'update' : 'create',
        payload: <String, dynamic>{
          ...playlist.toJson(),
          'creatorId': _activeCreatorId,
        },
        createdAt: DateTime.now(),
      ),
    );

    if (!_shouldSkipNetwork) {
      try {
        await _dio.put<Map<String, dynamic>>(
          '$_baseUrl/playlists/${playlist.id}',
          data: <String, dynamic>{
            ...playlist.toJson(),
            'creatorId': _activeCreatorId,
          },
        );
      } catch (e) {
        debugPrint('[PlaylistRepository] remote save fallback: $e');
      }
    }
  }

  @override
  Future<void> deletePlaylist(String id) async {
    await _ensureInit();
    if (_box != null) {
      await _box!.delete(id);
    } else {
      _inMemoryFallback.remove(id);
    }

    await _outbox?.enqueue(
      SyncMutationRecord(
        idempotencyKey:
            'mut_pl_del_${id}_${DateTime.now().millisecondsSinceEpoch}',
        entityType: 'playlist',
        action: 'delete',
        payload: <String, dynamic>{'id': id, 'creatorId': _activeCreatorId},
        createdAt: DateTime.now(),
      ),
    );

    if (!_shouldSkipNetwork) {
      try {
        await _dio.delete<Map<String, dynamic>>(
          '$_baseUrl/playlists/$id',
          queryParameters: <String, dynamic>{'creatorId': _activeCreatorId},
        );
      } catch (e) {
        debugPrint('[PlaylistRepository] remote delete fallback: $e');
      }
    }
  }

  /// Applies a server delta playlist upsert or deletion locally without re-enqueueing outbox mutations.
  Future<void> applySyncDelta({
    PlaylistEntity? upsert,
    String? deleteId,
  }) async {
    await _ensureInit();
    if (deleteId != null && deleteId.isNotEmpty) {
      if (_box != null) {
        await _box!.delete(deleteId);
      } else {
        _inMemoryFallback.remove(deleteId);
      }
    }
    if (upsert != null) {
      if (_box != null) {
        await _box!.put(upsert.id, upsert.toJson());
      } else {
        _inMemoryFallback[upsert.id] = upsert;
      }
    }
  }

  @override
  Future<void> addTrackToPlaylist(String playlistId, String trackId) async {
    final playlist = await getPlaylistById(playlistId);
    if (playlist == null || playlist.trackIds.contains(trackId)) return;

    final updated = playlist.copyWith(
      trackIds: <String>[...playlist.trackIds, trackId],
      updatedAt: DateTime.now(),
    );
    await savePlaylist(updated);
  }

  @override
  Future<void> removeTrackFromPlaylist(
    String playlistId,
    String trackId,
  ) async {
    final playlist = await getPlaylistById(playlistId);
    if (playlist == null || !playlist.trackIds.contains(trackId)) return;

    final updated = playlist.copyWith(
      trackIds: playlist.trackIds
          .where((id) => id != trackId)
          .toList(growable: false),
      updatedAt: DateTime.now(),
    );
    await savePlaylist(updated);
  }

  @override
  Future<void> reorderTracksInPlaylist(
    String playlistId,
    int oldIndex,
    int newIndex,
  ) async {
    final playlist = await getPlaylistById(playlistId);
    if (playlist == null) return;
    if (oldIndex < 0 || oldIndex >= playlist.trackIds.length) return;

    final trackIds = List<String>.of(playlist.trackIds);
    final item = trackIds.removeAt(oldIndex);
    final clampedIndex = newIndex.clamp(0, trackIds.length);
    trackIds.insert(clampedIndex, item);

    await savePlaylist(
      playlist.copyWith(trackIds: trackIds, updatedAt: DateTime.now()),
    );
  }

  @override
  Future<List<PlaylistEntity>> syncPlaylistsWithCloud({
    String? creatorId,
  }) async {
    final resolvedCreatorId = canonicalizeCreatorId(
      creatorId ?? _activeCreatorId,
    );
    final local = await getAllPlaylists();
    if (_shouldSkipNetwork) return local;

    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/playlists',
        queryParameters: <String, dynamic>{'creatorId': resolvedCreatorId},
      );
      if (res.statusCode == 200 && res.data != null) {
        final rawList =
            (res.data!['items'] ?? res.data!['playlists']) as List<dynamic>? ??
            const <dynamic>[];
        final remote = rawList
            .whereType<Map>()
            .map((e) => PlaylistEntity.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false);

        final mergedById = <String, PlaylistEntity>{
          for (final p in local) p.id: p,
        };
        for (final r in remote) {
          final existing = mergedById[r.id];
          if (existing == null || !existing.updatedAt.isAfter(r.updatedAt)) {
            mergedById[r.id] = r;
          }
        }

        // Push local-only or newer local playlists up to cloud
        final remoteById = {for (final r in remote) r.id: r};
        for (final p in local) {
          final r = remoteById[p.id];
          if (r == null || p.updatedAt.isAfter(r.updatedAt)) {
            try {
              await _dio.post<Map<String, dynamic>>(
                '$_baseUrl/playlists',
                data: <String, dynamic>{
                  ...p.toJson(),
                  'creatorId': resolvedCreatorId,
                },
              );
            } catch (_) {}
          }
        }

        await _ensureInit();
        for (final p in mergedById.values) {
          if (_box != null) {
            await _box!.put(p.id, p.toJson());
          } else {
            _inMemoryFallback[p.id] = p;
          }
        }
        final sorted = mergedById.values.toList(growable: false)
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return sorted;
      }
    } catch (e) {
      debugPrint('[PlaylistRepository] syncPlaylistsWithCloud fallback: $e');
    }
    return local;
  }

  @override
  Future<PlaylistEntity?> sharePlaylist(String id) async {
    final local = await getPlaylistById(id);
    if (!_shouldSkipNetwork) {
      try {
        final res = await _dio.post<Map<String, dynamic>>(
          '$_baseUrl/playlists/$id/share',
          data: <String, dynamic>{},
        );
        if (res.statusCode == 200 &&
            res.data != null &&
            res.data!['playlist'] is Map) {
          final shared = PlaylistEntity.fromJson(
            Map<String, dynamic>.from(res.data!['playlist'] as Map),
          );
          await _ensureInit();
          if (_box != null) {
            await _box!.put(shared.id, shared.toJson());
          } else {
            _inMemoryFallback[shared.id] = shared;
          }
          return shared;
        }
      } catch (e) {
        debugPrint('[PlaylistRepository] sharePlaylist offline fallback: $e');
      }
    }

    if (local == null) return null;
    final cleanId = id.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final code =
        local.shareCode ?? 'VH-${cleanId.padRight(6, '0').substring(0, 6)}';
    final sharedLocal = local.copyWith(
      isPublic: true,
      shareCode: code,
      shareUrl: 'https://vhunambi.za/p/$code',
      updatedAt: DateTime.now(),
    );
    await savePlaylist(sharedLocal);
    return sharedLocal;
  }
}

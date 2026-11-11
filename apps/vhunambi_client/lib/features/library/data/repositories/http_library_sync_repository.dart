import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/features/library/domain/models/library_models.dart';

/// Hive box key backing persistent Vault tracks in production (Phase 59).
const String kLibraryTracksHiveBoxKey = 'vhunambi_library_tracks_v1';

/// Outcome summary of a cloud delta sync operation.
@immutable
class LibraryDeltaSyncResult {
  final bool syncedFromCloud;
  final List<LibraryTrack> mergedTracks;
  final int serverSeq;
  final int appliedCount;
  final DateTime syncedAt;
  final String? errorMessage;

  const LibraryDeltaSyncResult({
    required this.syncedFromCloud,
    required this.mergedTracks,
    this.serverSeq = 0,
    this.appliedCount = 0,
    required this.syncedAt,
    this.errorMessage,
  });
}

/// Persistent Hive + HTTP delta-sync repository for User Library Vault (Phase 59).
class HttpLibrarySyncRepository {
  final Dio _dio;
  final String _baseUrl;
  final bool isTestMode;
  final bool _hasCustomDio;
  Box? _box;
  final Map<String, LibraryTrack> _inMemoryFallback = <String, LibraryTrack>{};
  bool _initialized = false;

  HttpLibrarySyncRepository({
    this._box,
    Dio? dio,
    String? baseUrl,
    bool? isTestMode,
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
      if (!kIsWeb && Hive.isBoxOpen(kLibraryTracksHiveBoxKey)) {
        _box = Hive.box(kLibraryTracksHiveBoxKey);
      }
    } catch (e) {
      debugPrint('[HttpLibrarySyncRepository] hive fallback active: $e');
    }
    _initialized = true;
  }

  /// Reads all locally persisted tracks (from Hive box or in-memory fallback).
  Future<List<LibraryTrack>> loadLocalTracks() async {
    await _ensureInit();
    final List<LibraryTrack> items = <LibraryTrack>[];
    if (_box != null) {
      for (final raw in _box!.values) {
        if (raw is Map) {
          items.add(LibraryTrack.fromJson(Map<String, dynamic>.from(raw)));
        }
      }
    } else {
      items.addAll(_inMemoryFallback.values);
    }
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  /// Persists a single [track] locally into Hive (or in-memory fallback).
  Future<void> saveTrackLocal(LibraryTrack track) async {
    await _ensureInit();
    if (_box != null) {
      await _box!.put(track.id, track.toJson());
    } else {
      _inMemoryFallback[track.id] = track;
    }
  }

  /// Persists the full merged collection into local storage.
  Future<void> saveAllLocal(List<LibraryTrack> tracks) async {
    await _ensureInit();
    if (_box != null) {
      final entries = <String, Map<String, dynamic>>{
        for (final t in tracks) t.id: t.toJson(),
      };
      await _box!.putAll(entries);
    } else {
      for (final t in tracks) {
        _inMemoryFallback[t.id] = t;
      }
    }
  }

  /// Permanently removes a local track from Hive (or in-memory fallback).
  Future<void> deleteTrackLocal(String id) async {
    await _ensureInit();
    if (_box != null) {
      await _box!.delete(id);
    } else {
      _inMemoryFallback.remove(id);
    }
  }

  /// Last-Write-Wins deterministic conflict resolution preserving Phase 58
  /// licensing certificates, offline local paths, and monotonic play counts.
  static List<LibraryTrack> mergeTracksLww(
    List<LibraryTrack> local,
    List<LibraryTrack> remote,
  ) {
    final mergedById = <String, LibraryTrack>{for (final t in local) t.id: t};

    for (final r in remote) {
      final existing = mergedById[r.id];
      if (existing == null) {
        mergedById[r.id] = r;
        continue;
      }

      final rTs = r.effectiveUpdatedAtMs;
      final lTs = existing.effectiveUpdatedAtMs;
      final winner = rTs >= lTs ? r : existing;
      final loser = identical(winner, r) ? existing : r;

      mergedById[r.id] = winner.copyWith(
        playCount: math.max(existing.playCount, r.playCount),
        localAudioFilePath: existing.localAudioFilePath ?? r.localAudioFilePath,
        syncStatus:
            (existing.localAudioFilePath != null ||
                    existing.masterAudioFilePath != null) &&
                winner.syncStatus == TrackSyncStatus.cloudOnly
            ? TrackSyncStatus.cachedLocally
            : winner.syncStatus,
        licenseCertificateIdOverride:
            winner.licenseCertificateIdOverride ??
            loser.licenseCertificateIdOverride,
        licenseHash: winner.licenseHash ?? loser.licenseHash,
        licenseTierId: winner.licenseTierId ?? loser.licenseTierId,
        masterAudioFilePath:
            winner.masterAudioFilePath ?? loser.masterAudioFilePath,
        stemPaths: winner.stemPaths.isNotEmpty
            ? winner.stemPaths
            : loser.stemPaths,
        updatedAtMs: math.max(rTs, lTs),
      );
    }

    final result = mergedById.values.toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  /// Fetches remote library items via `GET /api/library/sync`.
  Future<List<LibraryTrack>> fetchCloudSnapshot({
    String creatorId = 'creator_cern',
  }) async {
    if (_shouldSkipNetwork) return loadLocalTracks();
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/library/sync',
        queryParameters: <String, dynamic>{'creatorId': creatorId},
      );
      if (response.statusCode == 200 && response.data != null) {
        final items =
            response.data!['items'] as List<dynamic>? ?? const <dynamic>[];
        return items
            .whereType<Map>()
            .map((e) => LibraryTrack.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false);
      }
    } catch (e) {
      debugPrint('[HttpLibrarySyncRepository] fetchCloudSnapshot fallback: $e');
    }
    return const <LibraryTrack>[];
  }

  /// Performs bidirectional delta sync via `POST /api/library/sync` + LWW merge.
  Future<LibraryDeltaSyncResult> syncDelta({
    required String creatorId,
    required List<LibraryTrack> localTracks,
  }) async {
    final storedLocal = await loadLocalTracks();
    final combinedLocal = mergeTracksLww(storedLocal, localTracks);
    await saveAllLocal(combinedLocal);

    if (_shouldSkipNetwork) {
      return LibraryDeltaSyncResult(
        syncedFromCloud: false,
        mergedTracks: combinedLocal,
        syncedAt: DateTime.now(),
      );
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_baseUrl/library/sync',
        data: <String, dynamic>{
          'creatorId': creatorId,
          'items': combinedLocal.map((t) => t.toJson()).toList(growable: false),
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data!;
        final rawItems = data['items'] as List<dynamic>? ?? const <dynamic>[];
        final remoteTracks = rawItems
            .whereType<Map>()
            .map((e) => LibraryTrack.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false);
        final merged = mergeTracksLww(combinedLocal, remoteTracks);
        await saveAllLocal(merged);
        return LibraryDeltaSyncResult(
          syncedFromCloud: true,
          mergedTracks: merged,
          serverSeq: (data['serverSeq'] as num?)?.toInt() ?? 0,
          appliedCount: (data['appliedCount'] as num?)?.toInt() ?? 0,
          syncedAt: DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('[HttpLibrarySyncRepository] syncDelta offline fallback: $e');
      return LibraryDeltaSyncResult(
        syncedFromCloud: false,
        mergedTracks: combinedLocal,
        syncedAt: DateTime.now(),
        errorMessage: e.toString(),
      );
    }

    return LibraryDeltaSyncResult(
      syncedFromCloud: false,
      mergedTracks: combinedLocal,
      syncedAt: DateTime.now(),
    );
  }

  /// Hard-deletes a purged record on the backend (`DELETE /api/library/:id`).
  Future<bool> deleteFromCloud(
    String id, {
    String creatorId = 'creator_cern',
  }) async {
    await deleteTrackLocal(id);
    if (_shouldSkipNetwork) return true;
    try {
      final response = await _dio.delete<Map<String, dynamic>>(
        '$_baseUrl/library/$id',
        queryParameters: <String, dynamic>{'creatorId': creatorId},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[HttpLibrarySyncRepository] deleteFromCloud fallback: $e');
      return false;
    }
  }
}

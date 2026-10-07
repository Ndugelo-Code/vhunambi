import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/models/playlist_entity.dart';
import '../../domain/repositories/i_playlist_repository.dart';

/// Production Hive-backed [IPlaylistRepository] (REQ-PV-01).
///
/// Persists playlist entities as JSON maps in [AppConstants.playlistsBoxKey].
/// If a box is explicitly passed or already opened (e.g. via `Hive.openBox`),
/// it persists records to disk. Otherwise, in headless/uninitialized test
/// environments, it seamlessly falls back to an in-memory store.
class PlaylistRepository implements IPlaylistRepository {
  PlaylistRepository({Box? box}) {
    _box = box;
  }

  Box? _box;
  final Map<String, PlaylistEntity> _inMemoryFallback = <String, PlaylistEntity>{};
  bool _initialized = false;

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
          list.add(
            PlaylistEntity.fromJson(Map<String, dynamic>.from(raw)),
          );
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
    if (_box != null) {
      await _box!.put(playlist.id, playlist.toJson());
    } else {
      _inMemoryFallback[playlist.id] = playlist;
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
  Future<void> removeTrackFromPlaylist(String playlistId, String trackId) async {
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
}

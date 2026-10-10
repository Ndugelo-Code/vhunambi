import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/in_memory_playlist_repository.dart';
import '../../data/repositories/playlist_repository.dart';
import '../../domain/models/playlist_entity.dart';
import '../../domain/repositories/i_playlist_repository.dart';

/// Injectable playlist repository (REQ-PL-01 / REQ-PV-01).
///
/// Backed by production [PlaylistRepository] with automatic headless fallback;
/// override with [InMemoryPlaylistRepository] when isolation is preferred.
final playlistRepositoryProvider = Provider<IPlaylistRepository>(
  (ref) => PlaylistRepository(),
);

/// The user's playlist vault, newest first (REQ-PL-02).
final playlistsProvider =
    StateNotifierProvider<PlaylistsNotifier, List<PlaylistEntity>>((ref) {
  final notifier = PlaylistsNotifier(ref.watch(playlistRepositoryProvider));
  notifier.loadPlaylists();
  return notifier;
});

/// Full playlist CRUD engine backing the vault, queue drawer and picker sheet.
class PlaylistsNotifier extends StateNotifier<List<PlaylistEntity>> {
  PlaylistsNotifier(this._repository) : super(const <PlaylistEntity>[]);

  final IPlaylistRepository _repository;

  /// Re-reads the persisted vault.
  Future<void> loadPlaylists() async {
    final playlists = await _repository.getAllPlaylists();
    if (!mounted) return;
    state = playlists;
  }

  /// Creates a playlist, prepends it to the vault and returns it.
  Future<PlaylistEntity> createPlaylist(
    String title, {
    String? description,
  }) async {
    final now = DateTime.now();
    final playlist = PlaylistEntity(
      id: 'pl_${now.microsecondsSinceEpoch}',
      title: title.trim(),
      description: description?.trim() ?? '',
      createdAt: now,
      updatedAt: now,
    );

    await _repository.savePlaylist(playlist);
    if (mounted) {
      state = <PlaylistEntity>[playlist, ...state];
    }
    return playlist;
  }

  /// Renames / re-describes an existing playlist.
  Future<void> updatePlaylist(
    String id, {
    String? title,
    String? description,
  }) async {
    final index = state.indexWhere((playlist) => playlist.id == id);
    if (index < 0) return;

    final updated = state[index].copyWith(
      title: title?.trim(),
      description: description?.trim(),
      updatedAt: DateTime.now(),
    );

    await _repository.savePlaylist(updated);
    if (!mounted) return;

    final next = List<PlaylistEntity>.of(state);
    next[index] = updated;
    state = next;
  }

  /// Deletes a playlist from storage and the vault.
  Future<void> deletePlaylist(String id) async {
    await _repository.deletePlaylist(id);
    if (!mounted) return;
    state = state
        .where((playlist) => playlist.id != id)
        .toList(growable: false);
  }

  /// Appends [trackId] to a playlist, ignoring duplicates / unknown ids.
  Future<void> addTrackToPlaylist(String playlistId, String trackId) async {
    final playlist = _find(playlistId);
    if (playlist == null || playlist.trackIds.contains(trackId)) return;

    await _repository.addTrackToPlaylist(playlistId, trackId);
    await loadPlaylists();
  }

  /// Removes [trackId] from a playlist.
  Future<void> removeTrackFromPlaylist(
    String playlistId,
    String trackId,
  ) async {
    final playlist = _find(playlistId);
    if (playlist == null || !playlist.trackIds.contains(trackId)) return;

    await _repository.removeTrackFromPlaylist(playlistId, trackId);
    await loadPlaylists();
  }

  /// Checkbox behaviour for `AddToPlaylistSheet` (REQ-PL-08).
  Future<void> toggleTrackInPlaylist(String playlistId, String trackId) async {
    final playlist = _find(playlistId);
    if (playlist == null) return;

    if (playlist.trackIds.contains(trackId)) {
      await removeTrackFromPlaylist(playlistId, trackId);
    } else {
      await addTrackToPlaylist(playlistId, trackId);
    }
  }

  /// Reorders a playlist's tracks by moving the item at [oldIndex] to
  /// [newIndex] and persists the new running order (Mission 7).
  ///
  /// The drag surfaces use `ReorderableListView.onReorderItem`, whose
  /// `newIndex` is already adjusted for the removed item, so this is a plain
  /// remove-then-insert. (The classic `oldIndex < newIndex` decrement belongs
  /// to the deprecated `onReorder` callback and would double-shift here.)
  Future<void> reorderTracksInPlaylist(
    String playlistId,
    int oldIndex,
    int newIndex,
  ) async {
    final playlist = _find(playlistId);
    if (playlist == null) return;
    if (oldIndex < 0 || oldIndex >= playlist.trackIds.length) return;

    await _repository.reorderTracksInPlaylist(playlistId, oldIndex, newIndex);
    await loadPlaylists();
  }

  /// `true` when [trackId] already lives in [playlistId].
  bool containsTrack(String playlistId, String trackId) =>
      _find(playlistId)?.trackIds.contains(trackId) ?? false;

  PlaylistEntity? _find(String id) {
    for (final playlist in state) {
      if (playlist.id == id) return playlist;
    }
    return null;
  }
}

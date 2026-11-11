import 'package:vhunambi_client/features/playlists/domain/models/playlist_entity.dart';
import 'package:vhunambi_client/features/playlists/domain/repositories/i_playlist_repository.dart';

/// In-memory [IPlaylistRepository] double (NFR-12-02).
///
/// Zero disk, zero Hive, zero timers — safe for headless `flutter_test` runs
/// and for provider/widget tests that need a warm playlist vault.
class InMemoryPlaylistRepository implements IPlaylistRepository {
  InMemoryPlaylistRepository({List<PlaylistEntity> seed = const []}) {
    for (final playlist in seed) {
      _playlists[playlist.id] = playlist;
    }
  }

  final Map<String, PlaylistEntity> _playlists = <String, PlaylistEntity>{};

  @override
  Future<List<PlaylistEntity>> getAllPlaylists() async =>
      List<PlaylistEntity>.unmodifiable(
        _playlists.values.toList(growable: false),
      );

  @override
  Future<PlaylistEntity?> getPlaylistById(String id) async => _playlists[id];

  @override
  Future<void> savePlaylist(PlaylistEntity playlist) async {
    _playlists[playlist.id] = playlist;
  }

  @override
  Future<void> deletePlaylist(String id) async {
    _playlists.remove(id);
  }

  @override
  Future<void> addTrackToPlaylist(String playlistId, String trackId) async {
    final playlist = _playlists[playlistId];
    if (playlist == null || playlist.trackIds.contains(trackId)) return;

    _playlists[playlistId] = playlist.copyWith(
      trackIds: <String>[...playlist.trackIds, trackId],
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> removeTrackFromPlaylist(
    String playlistId,
    String trackId,
  ) async {
    final playlist = _playlists[playlistId];
    if (playlist == null || !playlist.trackIds.contains(trackId)) return;

    _playlists[playlistId] = playlist.copyWith(
      trackIds: playlist.trackIds
          .where((id) => id != trackId)
          .toList(growable: false),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> reorderTracksInPlaylist(
    String playlistId,
    int oldIndex,
    int newIndex,
  ) async {
    final playlist = _playlists[playlistId];
    if (playlist == null) return;
    if (oldIndex < 0 || oldIndex >= playlist.trackIds.length) return;

    final trackIds = List<String>.of(playlist.trackIds);
    final item = trackIds.removeAt(oldIndex);
    final clampedIndex = newIndex.clamp(0, trackIds.length);
    trackIds.insert(clampedIndex, item);

    _playlists[playlistId] = playlist.copyWith(
      trackIds: trackIds,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<List<PlaylistEntity>> syncPlaylistsWithCloud({
    String? creatorId,
  }) async {
    return getAllPlaylists();
  }

  @override
  Future<PlaylistEntity?> sharePlaylist(String id) async {
    final playlist = _playlists[id];
    if (playlist == null) return null;
    final code =
        playlist.shareCode ??
        'VH-${id.toUpperCase().replaceAll('_', '').padRight(6, 'X').substring(0, 6)}';
    final updated = playlist.copyWith(
      isPublic: true,
      shareCode: code,
      shareUrl: 'https://vhunambi.za/p/$code',
      updatedAt: DateTime.now(),
    );
    _playlists[id] = updated;
    return updated;
  }
}

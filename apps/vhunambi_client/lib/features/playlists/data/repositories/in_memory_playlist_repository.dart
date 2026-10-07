import '../../domain/models/playlist_entity.dart';
import '../../domain/repositories/i_playlist_repository.dart';

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
}

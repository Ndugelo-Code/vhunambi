import '../models/playlist_entity.dart';

/// Playlist persistence contract (REQ-PL-01).
///
/// `InMemoryPlaylistRepository` backs headless tests; the Hive-backed
/// implementation (`AppConstants.playlistsBoxKey`) backs production.
abstract class IPlaylistRepository {
  Future<List<PlaylistEntity>> getAllPlaylists();
  Future<PlaylistEntity?> getPlaylistById(String id);
  Future<void> savePlaylist(PlaylistEntity playlist);
  Future<void> deletePlaylist(String id);
  Future<void> addTrackToPlaylist(String playlistId, String trackId);
  Future<void> removeTrackFromPlaylist(String playlistId, String trackId);
}

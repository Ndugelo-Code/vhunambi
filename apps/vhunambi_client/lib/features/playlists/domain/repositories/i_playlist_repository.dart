import 'package:vhunambi_client/features/playlists/domain/models/playlist_entity.dart';

/// Playlist persistence contract (REQ-PL-01 + Phase 59 cloud CRUD & sharing).
///
/// `InMemoryPlaylistRepository` backs headless tests; [PlaylistRepository]
/// (`AppConstants.playlistsBoxKey` + Hono REST `/api/playlists`) backs production.
abstract class IPlaylistRepository {
  Future<List<PlaylistEntity>> getAllPlaylists();
  Future<PlaylistEntity?> getPlaylistById(String id);
  Future<void> savePlaylist(PlaylistEntity playlist);
  Future<void> deletePlaylist(String id);
  Future<void> addTrackToPlaylist(String playlistId, String trackId);
  Future<void> removeTrackFromPlaylist(String playlistId, String trackId);
  Future<void> reorderTracksInPlaylist(
    String playlistId,
    int oldIndex,
    int newIndex,
  );
  Future<List<PlaylistEntity>> syncPlaylistsWithCloud({String? creatorId});
  Future<PlaylistEntity?> sharePlaylist(String id);
}

import '../models/profile_models.dart';

/// Contract for profile remote data operations.
abstract class ProfileRepository {
  /// Fetches an artist or owner profile by ID or handle.
  Future<ArtistProfileEntity> fetchProfile(String artistId);

  /// Toggles follow state for an artist.
  Future<void> toggleFollow(String artistId, bool isFollowing);

  /// Sends a credit tip to the artist.
  Future<void> tipArtist(String artistId, int credits);

  /// Updates the creator's avatar image URL.
  Future<void> updateAvatar(String artistId, String? avatarUrl);

  /// Toggles whether tips are enabled on the profile.
  Future<void> toggleTipsEnabled(String artistId, bool enabled);

  /// Adds a music release to the artist discography.
  Future<void> addRelease(String artistId, MusicReleaseEntity release);
}

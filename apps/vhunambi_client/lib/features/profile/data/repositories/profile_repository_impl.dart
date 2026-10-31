import 'dart:async';
import '../../../../core/utils/creator_id_utils.dart';
import '../../domain/models/profile_models.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../presentation/providers/profile_providers.dart';

/// Default local-first repository implementation using seeded profiles.
class ProfileRepositoryImpl implements ProfileRepository {
  final List<ArtistProfileEntity> _profiles;
  final Duration networkLatency;

  ProfileRepositoryImpl({
    List<ArtistProfileEntity>? initialProfiles,
    this.networkLatency = const Duration(milliseconds: 50),
  }) : _profiles = initialProfiles ?? List.from(seededArtistProfiles);

  @override
  Future<ArtistProfileEntity> fetchProfile(String artistId) async {
    if (networkLatency > Duration.zero) {
      await Future.delayed(networkLatency);
    }

    final cleanId = artistId.toLowerCase().trim();
    final rawId = extractRawCreatorId(cleanId);
    final match = _profiles.firstWhere(
      (p) =>
          p.id.toLowerCase() == cleanId ||
          p.username.toLowerCase() == cleanId ||
          p.id.toLowerCase() == rawId ||
          p.username.toLowerCase() == rawId ||
          p.id.toLowerCase() == 'creator_$rawId',
      orElse: () => ArtistProfileEntity(
        id: cleanId,
        username: cleanId,
        displayName: cleanId.isEmpty
            ? 'Artist'
            : cleanId[0].toUpperCase() + cleanId.substring(1),
        monogram:
            cleanId.length >= 2 ? cleanId.substring(0, 2).toUpperCase() : 'AR',
        bio: 'African music producer and songwriter composing on Vhunambi.',
        isVerified: true,
        songCount: 3,
        likeCount: 140,
        playCount: 1200,
        followerCount: 85,
        dayStreak: 2,
        topGenres: const ['Amapiano', 'Afro House'],
      ),
    );
    return match;
  }

  @override
  Future<void> toggleFollow(String artistId, bool isFollowing) async {
    if (networkLatency > Duration.zero) {
      await Future.delayed(networkLatency);
    }
    final index = _profiles.indexWhere((p) => p.id == artistId);
    if (index != -1) {
      final p = _profiles[index];
      _profiles[index] = p.copyWith(
        isFollowing: isFollowing,
        followerCount: p.followerCount + (isFollowing ? 1 : -1),
      );
    }
  }

  @override
  Future<void> tipArtist(String artistId, int credits) async {
    if (networkLatency > Duration.zero) {
      await Future.delayed(networkLatency);
    }
  }

  @override
  Future<void> updateAvatar(String artistId, String? avatarUrl) async {
    if (networkLatency > Duration.zero) {
      await Future.delayed(networkLatency);
    }
    final index = _profiles.indexWhere((p) => p.id == artistId);
    if (index != -1) {
      _profiles[index] = _profiles[index].copyWith(avatarUrl: avatarUrl);
    }
  }

  @override
  Future<void> toggleTipsEnabled(String artistId, bool enabled) async {
    if (networkLatency > Duration.zero) {
      await Future.delayed(networkLatency);
    }
    final index = _profiles.indexWhere((p) => p.id == artistId);
    if (index != -1) {
      _profiles[index] = _profiles[index].copyWith(tipsEnabled: enabled);
    }
  }

  @override
  Future<void> addRelease(String artistId, MusicReleaseEntity release) async {
    if (networkLatency > Duration.zero) {
      await Future.delayed(networkLatency);
    }
    final index = _profiles.indexWhere((p) => p.id == artistId);
    if (index != -1) {
      final p = _profiles[index];
      _profiles[index] = p.copyWith(releases: [release, ...p.releases]);
    }
  }
}

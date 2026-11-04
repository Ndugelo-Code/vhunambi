import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/cache/profile_cache.dart';
import '../../../../core/utils/creator_id_utils.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/models/profile_models.dart';
import '../../domain/models/profile_operation_state.dart';
import '../../domain/repositories/profile_repository.dart';
import 'profile_operation_notifier.dart';

/// Public artist profile provider family for `/profile/:id` (REQ-TRK-12).
final artistProfileFamilyProvider =
    StateNotifierProvider.family<
      ArtistProfileNotifier,
      ArtistProfileEntity,
      String
    >((ref, artistId) {
      return ArtistProfileNotifier(artistId);
    });

/// Account owner creator studio profile provider for `/profile/me` (REQ-TRK-15).
final ownerProfileProvider =
    StateNotifierProvider<ArtistProfileNotifier, ArtistProfileEntity>((ref) {
      return ArtistProfileNotifier('me');
    });

/// Global profile repository provider.
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepositoryImpl();
});

/// Global profile cache provider.
final profileCacheProvider = Provider<ProfileCache>((ref) {
  return ProfileCache();
});

/// Companion resilience provider for async operation tracking on `/profile/:id`.
final profileOperationProvider =
    StateNotifierProvider.family<
      ProfileOperationNotifier,
      ProfileOperationState,
      String
    >((ref, artistId) {
      return ProfileOperationNotifier(
        artistId: artistId,
        repository: ref.watch(profileRepositoryProvider),
        cache: ref.watch(profileCacheProvider),
        profileNotifier: ref.watch(
          artistProfileFamilyProvider(artistId).notifier,
        ),
      );
    });

/// Companion resilience provider for async operation tracking on `/profile/me`.
final ownerProfileOperationProvider =
    StateNotifierProvider<ProfileOperationNotifier, ProfileOperationState>((
      ref,
    ) {
      return ProfileOperationNotifier(
        artistId: 'me',
        repository: ref.watch(profileRepositoryProvider),
        cache: ref.watch(profileCacheProvider),
        profileNotifier: ref.watch(ownerProfileProvider.notifier),
      );
    });

/// Manages local optimistic state updates for an artist profile entity.
///
/// **Migration Notice**:
/// In accordance with Phase 1 Resilient Profile Architecture:
/// - To perform network-aware mutations with retry, rollback, and caching, invoke operations
///   via [ProfileOperationNotifier] using `ref.read(profileOperationProvider(artistId).notifier)`.
/// - Direct unhandled mutations on this class remain backward-compatible for existing synchronous tests
///   and fallback scenarios.
class ArtistProfileNotifier extends StateNotifier<ArtistProfileEntity> {
  final String artistId;

  ArtistProfileNotifier(this.artistId) : super(_lookupProfile(artistId));

  /// Toggles following state and updates the follower counter (REQ-TRK-12).
  void toggleFollow() {
    final nextFollowing = !state.isFollowing;
    state = state.copyWith(
      isFollowing: nextFollowing,
      followerCount: state.followerCount + (nextFollowing ? 1 : -1),
    );
  }

  /// Tips credits to the artist and adds a ledger entry (REQ-TRK-14).
  void tipArtist(
    int credits, {
    String senderName = 'cern',
    String senderHandle = '@cern',
  }) {
    if (credits <= 0) return;
    final tipRecord = TipRecordEntity(
      id: 'tip_${DateTime.now().millisecondsSinceEpoch}',
      senderName: senderName,
      senderHandle: senderHandle,
      recipientName: state.displayName,
      amountCredits: credits,
      trackTitle: 'Direct Artist Tip',
      timestamp: DateTime.now(),
      isReceived: true,
    );
    state = state.copyWith(tipHistory: [tipRecord, ...state.tipHistory]);
  }

  /// Toggles whether fans can send direct credit tips (REQ-TRK-16).
  void toggleTipsEnabled() {
    state = state.copyWith(tipsEnabled: !state.tipsEnabled);
  }

  /// Updates the creator's profile picture or AI-synthesized avatar.
  void updateAvatar(String? url) {
    if (url == null || url.isEmpty) {
      state = state.copyWith(clearAvatar: true);
    } else {
      state = state.copyWith(avatarUrl: url);
    }
  }

  /// Adds an Album, EP, or Single to the artist discography (REQ-TRK-15).
  void addRelease(MusicReleaseEntity release) {
    state = state.copyWith(releases: [release, ...state.releases]);
  }

  /// Updates profile metadata details (display name, username, bio, signature genres) (Phase 33 REQ-PRF-02).
  void updateProfileDetails({
    String? displayName,
    String? username,
    String? bio,
    List<String>? topGenres,
    CreatorIdentityArchetype? archetype,
  }) {
    state = state.copyWith(
      displayName: displayName,
      username: username,
      bio: bio,
      topGenres: topGenres,
      archetype: archetype,
    );
  }

  /// Sets or clears the pinned featured spotlight track (Phase 33 REQ-PRF-03).
  void setPinnedTrack(String? trackId) {
    if (trackId == null) {
      state = state.copyWith(clearPinnedTrack: true);
    } else {
      state = state.copyWith(pinnedTrackId: trackId);
    }
  }

  /// Synchronizes dynamic cross-platform analytics metrics onto profile state.
  void updateMetrics({
    int? songCount,
    int? playCount,
    int? likeCount,
    List<String>? topGenres,
  }) {
    state = state.copyWith(
      songCount: songCount,
      playCount: playCount,
      likeCount: likeCount,
      topGenres: topGenres,
    );
  }

  /// Seeds or updates the profile state from a cached or fresh entity.
  void seedFromCache(ArtistProfileEntity cached) {
    state = cached;
  }

  /// Rolls back an optimistic follow toggle.
  void rollbackFollow(bool wasFollowing, int previousFollowerCount) {
    state = state.copyWith(
      isFollowing: wasFollowing,
      followerCount: previousFollowerCount,
    );
  }
}

ArtistProfileEntity _lookupProfile(String id) {
  final cleanId = id.toLowerCase().trim();
  final rawId = extractRawCreatorId(cleanId);
  final match = seededArtistProfiles.firstWhere(
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
      monogram: cleanId.length >= 2
          ? cleanId.substring(0, 2).toUpperCase()
          : 'AR',
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

/// Seeded artist and creator profiles (design.md §1.3).
final List<ArtistProfileEntity> seededArtistProfiles = [
  ArtistProfileEntity(
    id: 'fifi',
    username: 'fifi',
    displayName: 'Fifi',
    monogram: 'FI',
    bio:
        'Modern Amapiano songstress blending Tshivenḓa poetry with private school piano log drums and atmospheric jazz chords.',
    isVerified: true,
    songCount: 8,
    likeCount: 1240,
    playCount: 45200,
    followerCount: 1820,
    dayStreak: 4,
    isFollowing: false,
    tipsEnabled: true,
    topGenres: const ['Amapiano', 'Afro Soul', 'House'],
    topSupporters: const [
      SupporterEntity(
        id: 'sup_01',
        name: 'Sipho Beats',
        handle: '@sipho_beats',
        totalCreditsTipped: 500,
        rank: 1,
      ),
      SupporterEntity(
        id: 'sup_02',
        name: 'Lerato K',
        handle: '@lerato_k',
        totalCreditsTipped: 350,
        rank: 2,
      ),
      SupporterEntity(
        id: 'sup_03',
        name: 'DJ Thabo',
        handle: '@djthabo',
        totalCreditsTipped: 200,
        rank: 3,
      ),
    ],
    releases: [
      MusicReleaseEntity(
        id: 'rel_01',
        title: 'Matibe Epilogue',
        releaseType: ReleaseType.ep,
        trackCount: 4,
        releaseDate: DateTime(2026, 8, 14),
        genre: 'Amapiano',
      ),
      MusicReleaseEntity(
        id: 'rel_02',
        title: 'Ndo Mufuna Matibe',
        releaseType: ReleaseType.single,
        trackCount: 1,
        releaseDate: DateTime(2026, 9, 20),
        genre: 'Amapiano',
      ),
    ],
    tipHistory: [
      TipRecordEntity(
        id: 'tip_01',
        senderName: 'Sipho Beats',
        senderHandle: '@sipho_beats',
        recipientName: 'Fifi',
        amountCredits: 50,
        trackTitle: 'Ndo Mufuna Matibe',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        isReceived: true,
      ),
      TipRecordEntity(
        id: 'tip_02',
        senderName: 'Lerato K',
        senderHandle: '@lerato_k',
        recipientName: 'Fifi',
        amountCredits: 70,
        trackTitle: 'Tshikona Morning',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        isReceived: true,
      ),
    ],
  ),
  ArtistProfileEntity(
    id: 'me',
    username: 'cern',
    displayName: 'cern',
    monogram: 'CE',
    bio:
        'Multi-genre electronic and indigenous rhythms producer from Johannesburg. Building the future of generative African sound.',
    isVerified: true,
    songCount: 7,
    likeCount: 480,
    playCount: 18400,
    followerCount: 940,
    dayStreak: 5,
    isFollowing: false,
    tipsEnabled: true,
    topGenres: const ['House', 'Amapiano', 'Maskandi'],
    topSupporters: const [
      SupporterEntity(
        id: 'sup_me_01',
        name: 'Fan Jabu',
        handle: '@fan_jabu',
        totalCreditsTipped: 50,
        rank: 1,
      ),
      SupporterEntity(
        id: 'sup_me_02',
        name: 'Sarah Music',
        handle: '@sarah_music',
        totalCreditsTipped: 70,
        rank: 2,
      ),
    ],
    releases: [
      MusicReleaseEntity(
        id: 'rel_me_01',
        title: 'Genesis Sessions',
        releaseType: ReleaseType.album,
        trackCount: 8,
        releaseDate: DateTime(2026, 7, 10),
        genre: 'House',
      ),
    ],
    tipHistory: [
      TipRecordEntity(
        id: 'tip_me_01',
        senderName: 'Fan Jabu',
        senderHandle: '@fan_jabu',
        recipientName: 'cern',
        amountCredits: 50,
        trackTitle: 'Ndo Mufuna Matibe',
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
        isReceived: true,
      ),
      TipRecordEntity(
        id: 'tip_me_02',
        senderName: 'Sarah Music',
        senderHandle: '@sarah_music',
        recipientName: 'cern',
        amountCredits: 70,
        trackTitle: 'ZaYN',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        isReceived: true,
      ),
      TipRecordEntity(
        id: 'tip_me_03',
        senderName: 'cern',
        senderHandle: '@cern',
        recipientName: 'Fifi',
        amountCredits: 35,
        trackTitle: 'Ndo Mufuna Matibe',
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        isReceived: false,
      ),
    ],
  ),
  const ArtistProfileEntity(
    id: 'sigwa_inaf',
    username: 'sigwa',
    displayName: 'Sigwa & Inaf',
    monogram: 'SI',
    bio:
        'Soulful duo bridging acoustic African instruments with modern electronic club rhythms.',
    isVerified: true,
    songCount: 14,
    likeCount: 3800,
    playCount: 84000,
    followerCount: 4200,
    dayStreak: 7,
    topGenres: ['Amapiano', 'Afro House', 'Kwaito'],
  ),
  const ArtistProfileEntity(
    id: 'dj_vibe',
    username: 'djvibe',
    displayName: 'DJ Vibe',
    monogram: 'DV',
    bio:
        'Durban underground Gqom pioneer. Heavy raw percussions and warehouse synth stabs.',
    isVerified: true,
    songCount: 19,
    likeCount: 5200,
    playCount: 110000,
    followerCount: 6100,
    dayStreak: 12,
    topGenres: ['Gqom', 'Kwaito'],
  ),
  const ArtistProfileEntity(
    id: 'ndugelo',
    username: 'ndugelo',
    displayName: 'Ndugelo',
    monogram: 'ND',
    bio:
        'Acoustic Zulu folk and Maskandi maestro celebrating indigenous heritage.',
    isVerified: true,
    songCount: 6,
    likeCount: 1100,
    playCount: 22000,
    followerCount: 1540,
    dayStreak: 3,
    pinnedTrackId: 'beat_zulu_acoustic',
    topGenres: ['Maskandi', 'Mbaqanga'],
  ),
  const ArtistProfileEntity(
    id: 'creator_makhadzi',
    username: 'makhadzi',
    displayName: 'Makhadzi',
    monogram: 'MA',
    bio:
        'Queen of African dance music and Limpopo heritage. Royal high-energy Amapiano.',
    isVerified: true,
    songCount: 22,
    likeCount: 9400,
    playCount: 195000,
    followerCount: 14200,
    dayStreak: 15,
    topGenres: ['Amapiano', 'Afro House', 'Tshivenḓa Folk'],
    vocalArchetypeTitle: 'Venda Royal Matriarch',
    vocalArchetypeLanguage: 'Tshivenḓa',
  ),
  const ArtistProfileEntity(
    id: 'creator_khakhathi',
    username: 'khakhathi',
    displayName: 'Khakhathi',
    monogram: 'KH',
    bio: 'Maskandi storyteller and acoustic acoustic warrior.',
    isVerified: true,
    songCount: 11,
    likeCount: 3100,
    playCount: 48000,
    followerCount: 3400,
    dayStreak: 6,
    topGenres: ['Maskandi', 'Mbaqanga'],
    vocalArchetypeTitle: 'Zulu Maskandi Tenor',
    vocalArchetypeLanguage: 'isiZulu',
  ),
];

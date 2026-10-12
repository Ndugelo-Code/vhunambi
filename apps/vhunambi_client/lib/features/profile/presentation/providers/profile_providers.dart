import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/profile_models.dart';

/// Public artist profile provider family for `/profile/:id` (REQ-TRK-12).
final artistProfileFamilyProvider = StateNotifierProvider.family<
    ArtistProfileNotifier, ArtistProfileEntity, String>((ref, artistId) {
  return ArtistProfileNotifier(artistId);
});

/// Account owner creator studio profile provider for `/profile/me` (REQ-TRK-15).
final ownerProfileProvider =
    StateNotifierProvider<ArtistProfileNotifier, ArtistProfileEntity>((ref) {
  return ArtistProfileNotifier('me');
});

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
  void tipArtist(int credits, {String senderName = 'cern', String senderHandle = '@cern'}) {
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
    state = state.copyWith(
      tipHistory: [tipRecord, ...state.tipHistory],
    );
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
    state = state.copyWith(
      releases: [release, ...state.releases],
    );
  }
}

ArtistProfileEntity _lookupProfile(String id) {
  final cleanId = id.toLowerCase().trim();
  final match = seededArtistProfiles.firstWhere(
    (p) => p.id == cleanId || p.username == cleanId,
    orElse: () => ArtistProfileEntity(
      id: cleanId,
      username: cleanId,
      displayName: cleanId.isEmpty ? 'Artist' : cleanId[0].toUpperCase() + cleanId.substring(1),
      monogram: cleanId.length >= 2 ? cleanId.substring(0, 2).toUpperCase() : 'AR',
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
    bio: 'Modern Amapiano songstress blending Tshivenḓa poetry with private school piano log drums and atmospheric jazz chords.',
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
    bio: 'Multi-genre electronic and indigenous rhythms producer from Johannesburg. Building the future of generative African sound.',
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
    bio: 'Soulful duo bridging acoustic African instruments with modern electronic club rhythms.',
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
    bio: 'Durban underground Gqom pioneer. Heavy raw percussions and warehouse synth stabs.',
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
    bio: 'Acoustic Zulu folk and Maskandi maestro celebrating indigenous heritage.',
    isVerified: true,
    songCount: 6,
    likeCount: 1100,
    playCount: 22000,
    followerCount: 1540,
    dayStreak: 3,
    topGenres: ['Maskandi', 'Mbaqanga'],
  ),
];

# Phase 7 Design Specification: Track Details & Creator Profiles

> **Target Package:** `apps/vhunambi_client`  
> **Route Paths:** `/track/:id`, `/profile/:id`, `/profile/me`  
> **State Engine:** Flutter Riverpod 2.x+  
> **Parent Blueprint:** [`docs/foundation_blueprints/06_TRACK_AND_CREATOR_PROFILES_SPEC.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/foundation_blueprints/06_TRACK_AND_CREATOR_PROFILES_SPEC.md)

---

## 1. Domain Entities & Models

### 1.1 Track Details Entity (`lib/features/track/domain/models/track_detail_models.dart`)

```dart
import 'package:flutter/foundation.dart';

enum LicenseType { personal, commercial }

@immutable
class StemTrackEntity {
  final String id;
  final String name; // 'Vocals', 'Drums', 'Bass', 'Instrumental'
  final String audioUrl;
  final Duration duration;
  final bool isMuted;
  final bool isSoloed;
  final double volume;

  const StemTrackEntity({
    required this.id,
    required this.name,
    required this.audioUrl,
    required this.duration,
    this.isMuted = false,
    this.isSoloed = false,
    this.volume = 1.0,
  });

  StemTrackEntity copyWith({
    bool? isMuted,
    bool? isSoloed,
    double? volume,
  }) {
    return StemTrackEntity(
      id: id,
      name: name,
      audioUrl: audioUrl,
      duration: duration,
      isMuted: isMuted ?? this.isMuted,
      isSoloed: isSoloed ?? this.isSoloed,
      volume: volume ?? this.volume,
    );
  }
}

enum StemSeparationStatus {
  idle,
  isolatingVocals,
  isolatingDrums,
  isolatingBass,
  isolatingInstrumental,
  ready,
  error,
}

@immutable
class StemSeparationState {
  final StemSeparationStatus status;
  final double progress; // 0.0 to 1.0
  final List<StemTrackEntity> stems;
  final String? errorMessage;

  const StemSeparationState({
    this.status = StemSeparationStatus.idle,
    this.progress = 0.0,
    this.stems = const [],
    this.errorMessage,
  });

  bool get isProcessing =>
      status != StemSeparationStatus.idle &&
      status != StemSeparationStatus.ready &&
      status != StemSeparationStatus.error;

  String get stepLabel {
    switch (status) {
      case StemSeparationStatus.isolatingVocals:
        return 'Isolating Vocals (1/4)...';
      case StemSeparationStatus.isolatingDrums:
        return 'Extracting Drum Transient (2/4)...';
      case StemSeparationStatus.isolatingBass:
        return 'Filtering Sub-Bass / Log Drums (3/4)...';
      case StemSeparationStatus.isolatingInstrumental:
        return 'Synthesizing Backing Instrumental (4/4)...';
      case StemSeparationStatus.ready:
        return 'All 4 stems isolated and ready';
      case StemSeparationStatus.error:
        return 'Stem separation failed';
      case StemSeparationStatus.idle:
        return 'Ready to extract 4 stems';
    }
  }

  StemSeparationState copyWith({
    StemSeparationStatus? status,
    double? progress,
    List<StemTrackEntity>? stems,
    String? errorMessage,
  }) {
    return StemSeparationState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      stems: stems ?? this.stems,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

@immutable
class TrackDetailEntity {
  final String id;
  final String title;
  final String genre;
  final String language;
  final Duration duration;
  final String creatorId;
  final String creatorName;
  final String creatorHandle;
  final LicenseType licenseType;
  final bool isLiked;
  final int likesCount;
  final int playCount;
  final Map<String, int> reactions; // {'fire': 0, 'love': 1, 'rhythm': 0, 'hands': 0, 'globe': 0}
  final Set<String> userReactions;
  final String lyrics;
  final String prompt;
  final StemSeparationState stemState;

  const TrackDetailEntity({
    required this.id,
    required this.title,
    required this.genre,
    required this.language,
    required this.duration,
    required this.creatorId,
    required this.creatorName,
    required this.creatorHandle,
    this.licenseType = LicenseType.personal,
    this.isLiked = false,
    this.likesCount = 0,
    this.playCount = 0,
    this.reactions = const {
      'fire': 0,
      'love': 1,
      'rhythm': 0,
      'hands': 0,
      'globe': 0,
    },
    this.userReactions = const {'love'},
    this.lyrics = '',
    this.prompt = '',
    this.stemState = const StemSeparationState(),
  });

  TrackDetailEntity copyWith({
    bool? isLiked,
    int? likesCount,
    int? playCount,
    Map<String, int>? reactions,
    Set<String>? userReactions,
    StemSeparationState? stemState,
  }) {
    return TrackDetailEntity(
      id: id,
      title: title,
      genre: genre,
      language: language,
      duration: duration,
      creatorId: creatorId,
      creatorName: creatorName,
      creatorHandle: creatorHandle,
      licenseType: licenseType,
      isLiked: isLiked ?? this.isLiked,
      likesCount: likesCount ?? this.likesCount,
      playCount: playCount ?? this.playCount,
      reactions: reactions ?? this.reactions,
      userReactions: userReactions ?? this.userReactions,
      lyrics: lyrics,
      prompt: prompt,
      stemState: stemState ?? this.stemState,
    );
  }
}
```

### 1.2 Comment Entity

```dart
@immutable
class CommentEntity {
  final String id;
  final String trackId;
  final String authorName;
  final String authorHandle;
  final String content;
  final DateTime createdAt;
  final int likesCount;
  final bool isLiked;

  const CommentEntity({
    required this.id,
    required this.trackId,
    required this.authorName,
    required this.authorHandle,
    required this.content,
    required this.createdAt,
    this.likesCount = 0,
    this.isLiked = false,
  });
}
```

### 1.3 Artist & Owner Profile Entities (`lib/features/profile/domain/models/profile_models.dart`)

```dart
import 'package:flutter/foundation.dart';

@immutable
class SupporterEntity {
  final String id;
  final String name;
  final String handle;
  final int totalCreditsTipped;
  final int rank; // 1, 2, 3

  const SupporterEntity({
    required this.id,
    required this.name,
    required this.handle,
    required this.totalCreditsTipped,
    required this.rank,
  });

  String get rankBadge {
    switch (rank) {
      case 1:
        return '🥇 Gold';
      case 2:
        return '🥈 Silver';
      case 3:
        return '🥉 Bronze';
      default:
        return 'Fan';
    }
  }
}

@immutable
class TipRecordEntity {
  final String id;
  final String senderName;
  final String senderHandle;
  final String recipientName;
  final int amountCredits;
  final String trackTitle;
  final DateTime timestamp;
  final bool isReceived;

  const TipRecordEntity({
    required this.id,
    required this.senderName,
    required this.senderHandle,
    required this.recipientName,
    required this.amountCredits,
    required this.trackTitle,
    required this.timestamp,
    required this.isReceived,
  });
}

enum ReleaseType { single, ep, album }

@immutable
class MusicReleaseEntity {
  final String id;
  final String title;
  final ReleaseType releaseType;
  final int trackCount;
  final DateTime releaseDate;
  final String genre;

  const MusicReleaseEntity({
    required this.id,
    required this.title,
    required this.releaseType,
    required this.trackCount,
    required this.releaseDate,
    required this.genre,
  });

  String get typeLabel {
    switch (releaseType) {
      case ReleaseType.single:
        return 'Single';
      case ReleaseType.ep:
        return 'EP';
      case ReleaseType.album:
        return 'Album';
    }
  }
}

@immutable
class ArtistProfileEntity {
  final String id;
  final String username;
  final String displayName;
  final String monogram;
  final String bio;
  final bool isVerified;
  final int songCount;
  final int likeCount;
  final int playCount;
  final int followerCount;
  final int dayStreak;
  final bool isFollowing;
  final bool tipsEnabled;
  final List<String> topGenres;
  final List<SupporterEntity> topSupporters;
  final List<MusicReleaseEntity> releases;
  final List<TipRecordEntity> tipHistory;

  const ArtistProfileEntity({
    required this.id,
    required this.username,
    required this.displayName,
    required this.monogram,
    this.bio = '',
    this.isVerified = true,
    this.songCount = 0,
    this.likeCount = 0,
    this.playCount = 0,
    this.followerCount = 0,
    this.dayStreak = 1,
    this.isFollowing = false,
    this.tipsEnabled = true,
    this.topGenres = const [],
    this.topSupporters = const [],
    this.releases = const [],
    this.tipHistory = const [],
  });

  ArtistProfileEntity copyWith({
    bool? isFollowing,
    bool? tipsEnabled,
    int? followerCount,
    List<MusicReleaseEntity>? releases,
    List<TipRecordEntity>? tipHistory,
  }) {
    return ArtistProfileEntity(
      id: id,
      username: username,
      displayName: displayName,
      monogram: monogram,
      bio: bio,
      isVerified: isVerified,
      songCount: songCount,
      likeCount: likeCount,
      playCount: playCount,
      followerCount: followerCount ?? this.followerCount,
      dayStreak: dayStreak,
      isFollowing: isFollowing ?? this.isFollowing,
      tipsEnabled: tipsEnabled ?? this.tipsEnabled,
      topGenres: topGenres,
      topSupporters: topSupporters,
      releases: releases ?? this.releases,
      tipHistory: tipHistory ?? this.tipHistory,
    );
  }
}
```

---

## 2. Riverpod State Providers

### 2.1 Track Detail Notifier (`lib/features/track/presentation/providers/track_providers.dart`)

```dart
final trackDetailFamilyProvider =
    StateNotifierProvider.family<TrackDetailNotifier, TrackDetailEntity, String>(
        (ref, trackId) {
  return TrackDetailNotifier(trackId);
});

class TrackDetailNotifier extends StateNotifier<TrackDetailEntity> {
  final String trackId;

  TrackDetailNotifier(this.trackId)
      : super(_lookupInitialTrack(trackId));

  void toggleLike() {
    final newLiked = !state.isLiked;
    state = state.copyWith(
      isLiked: newLiked,
      likesCount: state.likesCount + (newLiked ? 1 : -1),
    );
  }

  void toggleReaction(String reactionKey) {
    final userReactions = Set<String>.from(state.userReactions);
    final reactions = Map<String, int>.from(state.reactions);

    if (userReactions.contains(reactionKey)) {
      userReactions.remove(reactionKey);
      reactions[reactionKey] = (reactions[reactionKey] ?? 1) - 1;
    } else {
      userReactions.add(reactionKey);
      reactions[reactionKey] = (reactions[reactionKey] ?? 0) + 1;
    }

    state = state.copyWith(
      userReactions: userReactions,
      reactions: reactions,
    );
  }

  Future<void> separateStems() async {
    state = state.copyWith(
      stemState: state.stemState.copyWith(
        status: StemSeparationStatus.isolatingVocals,
        progress: 0.25,
      ),
    );
    await Future.delayed(const Duration(milliseconds: 300));

    state = state.copyWith(
      stemState: state.stemState.copyWith(
        status: StemSeparationStatus.isolatingDrums,
        progress: 0.50,
      ),
    );
    await Future.delayed(const Duration(milliseconds: 300));

    state = state.copyWith(
      stemState: state.stemState.copyWith(
        status: StemSeparationStatus.isolatingBass,
        progress: 0.75,
      ),
    );
    await Future.delayed(const Duration(milliseconds: 300));

    state = state.copyWith(
      stemState: state.stemState.copyWith(
        status: StemSeparationStatus.isolatingInstrumental,
        progress: 0.90,
      ),
    );
    await Future.delayed(const Duration(milliseconds: 300));

    state = state.copyWith(
      stemState: StemSeparationState(
        status: StemSeparationStatus.ready,
        progress: 1.0,
        stems: [
          StemTrackEntity(id: '${trackId}_vocals', name: 'Vocals', audioUrl: '', duration: state.duration),
          StemTrackEntity(id: '${trackId}_drums', name: 'Drums', audioUrl: '', duration: state.duration),
          StemTrackEntity(id: '${trackId}_bass', name: 'Bass & Log Drums', audioUrl: '', duration: state.duration),
          StemTrackEntity(id: '${trackId}_inst', name: 'Instrumental', audioUrl: '', duration: state.duration),
        ],
      ),
    );
  }

  void toggleMuteStem(String stemId) {
    final stems = state.stemState.stems.map((s) {
      if (s.id == stemId) return s.copyWith(isMuted: !s.isMuted);
      return s;
    }).toList();
    state = state.copyWith(stemState: state.stemState.copyWith(stems: stems));
  }

  void toggleSoloStem(String stemId) {
    final stems = state.stemState.stems.map((s) {
      if (s.id == stemId) return s.copyWith(isSoloed: !s.isSoloed);
      return s;
    }).toList();
    state = state.copyWith(stemState: state.stemState.copyWith(stems: stems));
  }
}
```

### 2.2 Artist Profile & Owner Providers (`lib/features/profile/presentation/providers/profile_providers.dart`)

```dart
final artistProfileFamilyProvider =
    StateNotifierProvider.family<ArtistProfileNotifier, ArtistProfileEntity, String>(
        (ref, artistId) {
  return ArtistProfileNotifier(artistId);
});

final ownerProfileProvider =
    StateNotifierProvider<ArtistProfileNotifier, ArtistProfileEntity>((ref) {
  return ArtistProfileNotifier('me');
});

class ArtistProfileNotifier extends StateNotifier<ArtistProfileEntity> {
  final String artistId;

  ArtistProfileNotifier(this.artistId)
      : super(_lookupProfile(artistId));

  void toggleFollow() {
    final newFollowing = !state.isFollowing;
    state = state.copyWith(
      isFollowing: newFollowing,
      followerCount: state.followerCount + (newFollowing ? 1 : -1),
    );
  }

  void toggleTipsEnabled() {
    state = state.copyWith(tipsEnabled: !state.tipsEnabled);
  }

  void addRelease(MusicReleaseEntity release) {
    state = state.copyWith(releases: [release, ...state.releases]);
  }
}
```

---

## 3. UI Widget Tree & Hierarchy

### 3.1 `TrackDetailView` (`lib/features/track/presentation/views/track_detail_view.dart`)
* `Scaffold`
  * `AppBar` with `< Back`, `VHUNAMBI`, and `Share`
  * `SafeArea`
    * `CustomScrollView` (max-width `860px` centered on Desktop)
      * `SliverToBoxAdapter` $\rightarrow$ `TrackHeroSection`: 1:1 artwork, genre gradient, ambient amber glow, title, metadata, `[ 🛡️ Personal Use ]` badge, ownership text, and creator link.
      * `SliverToBoxAdapter` $\rightarrow$ `TrackActionsBar`: Primary row (`❤️ Like`, `▶ Plays`, `🔀 Remix`, `💰 Tip`).
      * `SliverToBoxAdapter` $\rightarrow$ `UtilityToolDock`: Horizontal scroll dock (`⬇ Download`, `➕ Playlist`, `📻 Radio`, `📝 Lyrics`, `🔀 Variation`, `💬 Comments`, `</> Embed`).
      * `SliverToBoxAdapter` $\rightarrow$ `EmojiReactionDeck`: 5 reaction pills (`🔥`, `❤️`, `🎵`, `🙌`, `🌍`).
      * `SliverToBoxAdapter` $\rightarrow$ `WaveformScrubber`: High-resolution amplitude waveform scrubber.
      * `SliverToBoxAdapter` $\rightarrow$ `LyricsTeleprompter`: Bracketed tag formatting with active highlight.
      * `SliverToBoxAdapter` $\rightarrow$ `StemSeparationLab`: 4-stem extraction FSM card, stem cards with Solo/Mute audition and download.
      * `SliverToBoxAdapter` $\rightarrow$ `PromptAttributionCard`: Seed prompt box with `"Remix Prompt ✨"`.
      * `SliverToBoxAdapter` $\rightarrow$ `CommentsSection`: Comments stream with composer.
      * `SliverToBoxAdapter` $\rightarrow$ `MoreLikeThisShelf`: Related recommendation cards.

### 3.2 `ArtistProfileView` (`lib/features/profile/presentation/views/artist_profile_view.dart`)
* `Scaffold`
  * `AppBar` with `< Back`, `VHUNAMBI`, and `Notifications`
  * `CustomScrollView`
    * `SliverToBoxAdapter` $\rightarrow$ `ProfileBannerHeader`: Ambient cover banner with musical watermark glyphs, 84px monogram avatar, verified badge, bio, and follow/tip action strip.
    * `SliverToBoxAdapter` $\rightarrow$ `ProfileStatsGrid`: 5-metric statistical grid (`Songs`, `Likes`, `Plays`, `Followers`, `Day Streak`).
    * `SliverToBoxAdapter` $\rightarrow$ `TopSongsShelf`: Top tracks ranked by play count with play triggers.
    * `SliverToBoxAdapter` $\rightarrow$ `TopSupportersLeaderboard`: Top tipping supporters with `🥇`, `🥈`, `🥉` badges.
    * `SliverToBoxAdapter` $\rightarrow$ `RecentActivityStream`: Chronological release list.

### 3.3 `OwnerProfileView` (`lib/features/profile/presentation/views/owner_profile_view.dart`)
* `Scaffold`
  * `AppBar` with `< Back`, `VHUNAMBI`, and `Studio Settings`
  * `CustomScrollView`
    * `SliverToBoxAdapter` $\rightarrow$ `OwnerHeader`: Monogram avatar, `Edit Profile`, `Pin Song`, `Studio Analytics`.
    * `SliverToBoxAdapter` $\rightarrow$ `TopGenresChips`: Distribution of genres generated.
    * `SliverToBoxAdapter` $\rightarrow$ `YourSongsManager`: Track list with inline `Public / Private` visibility toggle.
    * `SliverToBoxAdapter` $\rightarrow$ `ReleasesManagerCard`: Album, EP, Single discography creator.
    * `SliverToBoxAdapter` $\rightarrow$ `TipHistoryLedger`: Tips on switch, `Received` vs `Sent` tabs.
    * `SliverToBoxAdapter` $\rightarrow$ `ProfileReferralCard`: One-tap copy link card.

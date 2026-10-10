import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/published_clip.dart';
import '../../../content_studio/domain/models/song_metadata_dna.dart';

/// Immutable state for the in-house Kinetic Reels discovery feed (REQ-SOC-16).
class SocialFeedState {
  final List<PublishedClip> clips;
  final bool isLoading;
  final bool hasReachedEnd;
  final String? errorMessage;

  const SocialFeedState({
    this.clips = const [],
    this.isLoading = false,
    this.hasReachedEnd = false,
    this.errorMessage,
  });

  SocialFeedState copyWith({
    List<PublishedClip>? clips,
    bool? isLoading,
    bool? hasReachedEnd,
    String? errorMessage,
  }) {
    return SocialFeedState(
      clips: clips ?? this.clips,
      isLoading: isLoading ?? this.isLoading,
      hasReachedEnd: hasReachedEnd ?? this.hasReachedEnd,
      errorMessage: errorMessage,
    );
  }
}

/// Drives the social feed: seeded catalogue, optimistic clip publishing,
/// cursor pagination, and like toggling (REQ-SOC-13 / REQ-SOC-16).
///
/// Follows the client-only in-memory architecture of `library_providers` /
/// `explore_providers` — no live network call, so it stays testable and
/// offline-safe. Swapping in an HTTP repository is a drop-in behind these fns.
class SocialFeedNotifier extends StateNotifier<SocialFeedState> {
  SocialFeedNotifier() : super(const SocialFeedState()) {
    state = state.copyWith(clips: _seedClips());
  }

  /// Optimistically prepends a freshly published clip (REQ-SOC-04).
  void prependClip(PublishedClip clip) {
    state = state.copyWith(clips: [clip, ...state.clips]);
  }

  /// Toggles the current user's like on a clip with an optimistic count bump.
  void toggleLike(String clipId) {
    state = state.copyWith(
      clips: [
        for (final clip in state.clips)
          if (clip.id == clipId)
            clip.copyWith(
              isLikedByMe: !clip.isLikedByMe,
              likeCount: clip.likeCount + (clip.isLikedByMe ? -1 : 1),
              userReactionCount: clip.isLikedByMe ? 0 : 1,
            )
          else
            clip,
      ],
    );
  }

  /// Records a love tap in TikTok-familiar multi-tap bursts (REQ-COM-04).
  ///
  /// Increments the total [likeCount], ensures [isLikedByMe] is true, and
  /// increments the user's specific [userReactionCount] for honest community tracking.
  int recordLove(String clipId) {
    var newReactionCount = 1;
    state = state.copyWith(
      clips: [
        for (final clip in state.clips)
          if (clip.id == clipId) () {
            final nextCount = clip.userReactionCount + 1;
            newReactionCount = nextCount;
            return clip.copyWith(
              isLikedByMe: true,
              likeCount: clip.likeCount + 1,
              userReactionCount: nextCount,
            );
          }()
          else
            clip,
      ],
    );
    return newReactionCount;
  }

  /// Loads the next cursor page. The seeded catalogue is fully in-memory, so
  /// this marks the end of the feed; a networked repo would append here.
  Future<void> loadMore() async {
    if (state.isLoading || state.hasReachedEnd) return;
    state = state.copyWith(isLoading: true);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    state = state.copyWith(isLoading: false, hasReachedEnd: true);
  }

  /// Finds a clip by id (used by the reels modal / profile deep links).
  PublishedClip? clipById(String clipId) {
    for (final clip in state.clips) {
      if (clip.id == clipId) return clip;
    }
    return null;
  }
}

final socialFeedProvider =
    StateNotifierProvider<SocialFeedNotifier, SocialFeedState>((ref) {
  return SocialFeedNotifier();
});


// ---------------------------------------------------------------------------
// Seed catalogue — mirrors the backend `social_service` seeds so the client
// shell renders a lively feed before any user publishing occurs.
// ---------------------------------------------------------------------------

SongMetadataDna _seedDna({
  required String id,
  required String title,
  required String genre,
  required int bpm,
  required int durationSec,
  String mood = 'Uplifting',
}) {
  return SongMetadataDna(
    id: id,
    title: title,
    genre: genre,
    language: 'Tshivenḓa',
    musical: MusicalDna(
      bpm: bpm,
      key: 'Am',
      energyBracket: 'mid',
      durationSec: durationSec,
    ),
    vocals: const VocalsDna(
      deliveryMode: 'melodic',
      gender: 'female',
      energy: 'mid',
    ),
    visualTheme: VisualThemeDna(
      mood: mood,
      comfyPrompt: '$genre aesthetic, vibrant, cinematic',
      seed: bpm,
      aspectRatio: '9:16',
    ),
  );
}

PublishedClip _seedClip({
  required String id,
  required String title,
  required String creatorId,
  required String creatorUsername,
  required String creatorDisplayName,
  required String genre,
  required int bpm,
  required int durationSec,
  required String caption,
  required List<String> tags,
  bool verified = true,
  String mood = 'Uplifting',
  int playCount = 0,
  int likeCount = 0,
  int commentCount = 0,
  int remixCount = 0,
}) {
  final suffix = id.split('_').last;
  return PublishedClip(
    id: id,
    trackId: 'track_$suffix',
    creatorId: creatorId,
    creatorUsername: creatorUsername,
    creatorDisplayName: creatorDisplayName,
    isCreatorVerified: verified,
    title: title,
    caption: caption,
    tags: tags,
    genre: genre,
    audioUrl: 'https://cdn.vhunambi.com/social/track_$suffix.mp3',
    coverUrl: 'https://cdn.vhunambi.com/social/track_$suffix.jpg',
    dna: _seedDna(
      id: 'dna_$suffix',
      title: title,
      genre: genre,
      bpm: bpm,
      durationSec: durationSec,
      mood: mood,
    ),
    playCount: playCount,
    likeCount: likeCount,
    commentCount: commentCount,
    remixCount: remixCount,
    publishedAt: DateTime.now().subtract(const Duration(hours: 3)),
  );
}

List<PublishedClip> _seedClips() {
  return [
    _seedClip(
      id: 'clip_pub_makhadzi_1',
      title: 'Ndo Mufuna Matibe',
      creatorId: 'creator_makhadzi',
      creatorUsername: 'makhadzi',
      creatorDisplayName: 'Makhadzi',
      genre: 'Amapiano',
      bpm: 113,
      durationSec: 198,
      caption: 'New late-night piano vibe featuring indigenous live percussion! 🎹🔥',
      tags: const ['Amapiano', 'Tshivenḓa', 'DeepSoul'],
      playCount: 24500,
      likeCount: 1840,
      commentCount: 96,
      remixCount: 12,
    ),
    _seedClip(
      id: 'clip_pub_makhadzi_2',
      title: 'Township Log Drum Heat',
      creatorId: 'creator_makhadzi',
      creatorUsername: 'makhadzi',
      creatorDisplayName: 'Makhadzi',
      genre: 'Gqom',
      bpm: 127,
      durationSec: 180,
      caption: 'Durban energy, straight from the shins. #Gqom',
      tags: const ['Gqom', 'Durban'],
      mood: 'Intense',
      playCount: 9800,
      likeCount: 742,
      commentCount: 41,
      remixCount: 8,
    ),
    _seedClip(
      id: 'clip_pub_fifi_1',
      title: 'Sunset Gold Sessions',
      creatorId: 'creator_fifi',
      creatorUsername: 'fifi',
      creatorDisplayName: 'Fifi Cooper',
      genre: 'Afro House',
      bpm: 122,
      durationSec: 210,
      caption: 'Afro House for golden hour drives 🌅',
      tags: const ['AfroHouse', 'Sunset'],
      mood: 'Dreamy',
      playCount: 15200,
      likeCount: 1290,
      commentCount: 73,
      remixCount: 5,
    ),
    _seedClip(
      id: 'clip_pub_fifi_2',
      title: 'Venda Sunrise',
      creatorId: 'creator_fifi',
      creatorUsername: 'fifi',
      creatorDisplayName: 'Fifi Cooper',
      genre: 'Amapiano',
      bpm: 112,
      durationSec: 192,
      caption: 'Waking the village with log drums ☀️',
      tags: const ['Amapiano', 'Morning'],
      playCount: 4300,
      likeCount: 388,
      commentCount: 22,
      remixCount: 3,
    ),
  ];
}

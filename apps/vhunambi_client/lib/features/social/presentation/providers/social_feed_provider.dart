import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/auth_providers.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/storage/sovereign_domain_repositories.dart';
import '../../domain/models/published_clip.dart';
import '../../domain/repositories/i_social_repository.dart';
import 'social_repository_provider.dart';
import '../../../content_studio/domain/models/lyric_word_timestamp.dart';
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
/// Backed by [ISocialRepository] with instant local seeding and offline resilience.
class SocialFeedNotifier extends StateNotifier<SocialFeedState> {
  final ISocialRepository? _repo;
  static final Set<String> _seedClipIds = _seedClips().map((c) => c.id).toSet();

  SocialFeedNotifier([this._repo])
    : super(SocialFeedState(clips: _initialClips()));

  static List<PublishedClip> _initialClips() {
    final seeds = _seedClips();
    if (!SovereignDomainStorageMode.canHydrateFromStorage(
      AppConstants.socialReelsBoxKey,
    )) {
      return seeds;
    }

    final merged = <PublishedClip>[];
    final seenIds = <String>{};

    final customRaw = SocialReelsCacheRepository.loadCustomClips();
    if (customRaw != null && customRaw.isNotEmpty) {
      for (final raw in customRaw) {
        try {
          final clip = PublishedClip.fromJson(raw);
          if (seenIds.add(clip.id)) {
            merged.add(clip);
          }
        } catch (_) {}
      }
    }

    for (final seed in seeds) {
      if (seenIds.add(seed.id)) {
        merged.add(seed);
      }
    }

    final loveCounts = SocialReelsCacheRepository.loadReelLoveCounts();
    final likedIds = SocialReelsCacheRepository.loadReelLikedIds();
    if (loveCounts == null && likedIds == null) {
      return merged;
    }

    return [
      for (final clip in merged)
        () {
          final persistedLoves = loveCounts?[clip.id];
          final persistedLiked = likedIds?.contains(clip.id);
          if (persistedLoves == null && persistedLiked == null) {
            return clip;
          }
          final targetLoves = persistedLoves ?? clip.userReactionCount;
          final delta = targetLoves - clip.userReactionCount;
          return clip.copyWith(
            userReactionCount: targetLoves,
            isLikedByMe: persistedLiked ?? clip.isLikedByMe,
            likeCount: (clip.likeCount + delta).clamp(0, 9999999),
          );
        }(),
    ];
  }

  void _persistCustomClips() {
    final custom = [
      for (final clip in state.clips)
        if (!_seedClipIds.contains(clip.id)) clip.toJson(),
    ];
    unawaited(SocialReelsCacheRepository.saveCustomClips(custom));
  }

  void _persistEngagement() {
    final loveCounts = <String, int>{
      for (final clip in state.clips)
        if (clip.userReactionCount > 0) clip.id: clip.userReactionCount,
    };
    final likedIds = <String>{
      for (final clip in state.clips)
        if (clip.isLikedByMe) clip.id,
    };
    unawaited(
      SocialReelsCacheRepository.saveReelEngagement(
        loveCounts: loveCounts,
        likedIds: likedIds,
      ),
    );
  }

  /// Refreshes the feed from the backend if a repository is provided.
  Future<void> refreshFeed() async {
    if (_repo == null) return;
    try {
      final remoteClips = await _repo.getFeed(limit: 20);
      if (remoteClips.isNotEmpty) {
        final existingIds = state.clips.map((c) => c.id).toSet();
        final newClips = remoteClips
            .where((c) => !existingIds.contains(c.id))
            .toList();
        if (newClips.isNotEmpty) {
          state = state.copyWith(clips: [...state.clips, ...newClips]);
          _persistCustomClips();
        }
      }
    } catch (_) {}
  }

  /// Optimistically prepends a freshly published clip (REQ-SOC-04).
  void prependClip(PublishedClip clip) {
    final filtered = state.clips.where((c) => c.id != clip.id).toList();
    state = state.copyWith(clips: [clip, ...filtered]);
    _persistCustomClips();
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
    _persistEngagement();
    _repo?.toggleLikeClip(clipId);
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
          if (clip.id == clipId)
            () {
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
    _persistEngagement();
    _repo?.toggleLikeClip(clipId);
    return newReactionCount;
  }

  /// Loads the next cursor page.
  Future<void> loadMore() async {
    if (state.isLoading || state.hasReachedEnd) return;
    state = state.copyWith(isLoading: true);
    if (_repo != null) {
      try {
        final nextClips = await _repo.getFeed(
          cursor: state.clips.length.toString(),
          limit: 10,
        );
        if (nextClips.isEmpty) {
          state = state.copyWith(isLoading: false, hasReachedEnd: true);
        } else {
          final existingIds = state.clips.map((c) => c.id).toSet();
          final filtered = nextClips
              .where((c) => !existingIds.contains(c.id))
              .toList();
          state = state.copyWith(
            clips: [...state.clips, ...filtered],
            isLoading: false,
            hasReachedEnd: filtered.isEmpty,
          );
        }
        return;
      } catch (_) {}
    }
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
      ref.watch(currentCreatorIdProvider);
      final repo = ref.watch(socialRepositoryProvider);
      return SocialFeedNotifier(repo);
    });

// ---------------------------------------------------------------------------
// Seed catalogue — mirrors the backend `social_service` seeds so the client
// shell renders a lively feed before any user publishing occurs.
// ---------------------------------------------------------------------------

List<LyricWordTimestamp> _buildSeedLyrics(
  List<String> words, {
  required int bpm,
}) {
  const idioms = <String>{
    'ndo',
    'mufuna',
    'matibe',
    'venda',
    'vhunambi',
    'woza',
    'sgubhu',
    'amapiano',
    'gqom',
    'durban',
    'makhado',
    'mbilu',
  };
  final stepSec = (60.0 / bpm.clamp(80, 160)).clamp(0.42, 0.70);
  return List<LyricWordTimestamp>.generate(words.length, (i) {
    final start = double.parse((i * stepSec).toStringAsFixed(2));
    final end = double.parse(((i + 1) * stepSec - 0.04).toStringAsFixed(2));
    final clean = words[i]
        .replaceAll(RegExp(r'[^a-zA-Zḓṋḽṱ]'), '')
        .toLowerCase();
    return LyricWordTimestamp(
      word: words[i],
      start: start,
      end: end,
      stanzaIndex: i ~/ 5,
      phoneticStress: (i % 2 == 0) ? 0.92 : 0.65,
      isCulturalIdiom: idioms.contains(clean),
    );
  });
}

SongMetadataDna _seedDna({
  required String id,
  required String title,
  required String genre,
  required int bpm,
  required int durationSec,
  String mood = 'Uplifting',
  List<String> lyricTokens = const [],
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
    alignment: lyricTokens.isNotEmpty
        ? _buildSeedLyrics(lyricTokens, bpm: bpm)
        : const [],
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
  List<String> lyricTokens = const [],
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
      lyricTokens: lyricTokens,
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
      id: 'clip_pub_sigwa_1',
      title: 'Limpopo Guitar Grooves',
      creatorId: 'creator_sigwa',
      creatorUsername: 'sigwa',
      creatorDisplayName: 'Sigwa',
      genre: 'Afro-fusion',
      bpm: 118,
      durationSec: 185,
      caption:
          'Testing the live nylon-string acoustic riffs with rolling basslines 🎸✨',
      tags: const ['Afro-fusion', 'Guitar', 'Limpopo'],
      mood: 'Groovy',
      playCount: 11200,
      likeCount: 890,
      commentCount: 45,
      remixCount: 7,
      lyricTokens: const [
        'Limpopo',
        'Guitar',
        'Grooves',
        'Vhunambi',
        'Sound',
        'Strings',
        'Resonate',
        'Rhythm',
      ],
    ),
    _seedClip(
      id: 'clip_pub_makhadzi_1',
      title: 'Ndo Mufuna Matibe',
      creatorId: 'creator_makhadzi',
      creatorUsername: 'makhadzi',
      creatorDisplayName: 'Makhadzi',
      genre: 'Amapiano',
      bpm: 113,
      durationSec: 198,
      caption:
          'New late-night piano vibe featuring indigenous live percussion! 🎹🔥',
      tags: const ['Amapiano', 'Tshivenḓa', 'DeepSoul'],
      playCount: 24500,
      likeCount: 1840,
      commentCount: 96,
      remixCount: 12,
      lyricTokens: const [
        'Ndo',
        'Mufuna',
        'Matibe',
        'Mbilu',
        'Yanga',
        'Iya',
        'Pembelela',
        'Woza',
        'Amapiano',
        'Sgubhu',
        'Vhunambi',
        'Ndo',
        'Mufuna',
        'Matibe',
      ],
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
      lyricTokens: const [
        'Woza',
        'Durban',
        'Gqom',
        'Sgubhu',
        'Township',
        'Log',
        'Drum',
        'Heat',
        'Asambe',
        'Vhunambi',
        'Woza',
        'Gqom',
      ],
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
      lyricTokens: const [
        'Sunset',
        'Gold',
        'Sessions',
        'Rising',
        'Over',
        'Makhado',
        'Vhunambi',
        'Rhythm',
        'In',
        'Our',
        'Soul',
        'Sunset',
        'Gold',
      ],
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
      lyricTokens: const [
        'Venda',
        'Sunrise',
        'Ndi',
        'Matsheloni',
        'Makhado',
        'Log',
        'Drum',
        'Amapiano',
        'Vhunambi',
        'Venda',
        'Sunrise',
      ],
    ),
  ];
}

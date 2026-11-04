import '../../../../core/sync/sync_outbox_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/track.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../domain/models/explore_models.dart';
import '../../domain/models/social_music_post.dart';
import '../../domain/services/discovery_hierarchy_ranker.dart';
import '../../../social/domain/models/published_clip.dart';
import '../../../social/presentation/providers/trending_reels_provider.dart';

/// Catalog page size driving the `Load more` pagination cursor (REQ-EXP-08).
const int exploreCatalogPageSize = 6;

/// Active Explore discovery sub-tab (REQ-EXP-02).

/// Active 3-Stage Discovery Hierarchy Tier filter (Phase 39 REQ-DISC-TIER-01).
/// `null` means unconstrained (all tiers).
final selectedDiscoveryTierProvider =
    StateProvider<DiscoveryStageTier?>((ref) => null);

final exploreTabProvider =
    StateProvider<ExploreTab>((ref) => ExploreTab.discover);

/// Real-time Explore search text (REQ-EXP-01).
final exploreSearchQueryProvider = StateProvider<String>((ref) => '');

/// Genre filter pill selection — `'All'` disables genre filtering.
final exploreGenreFilterProvider = StateProvider<String>((ref) => 'All');

/// Mood filter chip selection — `null` disables mood filtering.
final exploreMoodFilterProvider = StateProvider<String?>((ref) => null);

/// Language dropdown selection — `'All'` disables language filtering.
final exploreLanguageFilterProvider = StateProvider<String>((ref) => 'All');

/// Catalog ordering (REQ-EXP-08).
final exploreSortByProvider =
    StateProvider<ExploreSortBy>((ref) => ExploreSortBy.newest);

/// Featured Creator deck records (REQ-EXP-06).
final exploreCreatorsProvider = Provider<List<CreatorProfile>>((ref) {
  return const [
    CreatorProfile(
      id: 'creator_sigwa',
      name: 'Sigwa & Inaf',
      handle: '@sigwa_inaf',
      initials: 'SI',
      trackCount: 96,
      primaryGenres: ['Amapiano'],
      isVerified: true,
    ),
    CreatorProfile(
      id: 'creator_ndugelo',
      name: 'Ndugelo',
      handle: '@ndugelo',
      initials: 'ND',
      trackCount: 21,
      primaryGenres: ['Maskandi'],
    ),
    CreatorProfile(
      id: 'creator_djvibe',
      name: 'DJ Vibe',
      handle: '@djvibe',
      initials: 'DJ',
      trackCount: 45,
      primaryGenres: ['Gqom'],
      isVerified: true,
    ),
    CreatorProfile(
      id: 'creator_fifi',
      name: 'Fifi',
      handle: '@fifi',
      initials: 'FI',
      trackCount: 32,
      primaryGenres: ['Amapiano'],
    ),
    CreatorProfile(
      id: 'creator_sipho',
      name: 'Sipho',
      handle: '@sipho',
      initials: 'SP',
      trackCount: 18,
      primaryGenres: ['Kwaito'],
    ),
    CreatorProfile(
      id: 'creator_lerato',
      name: 'Lerato',
      handle: '@lerato',
      initials: 'LR',
      trackCount: 64,
      primaryGenres: ['Afro House'],
      isVerified: true,
    ),
  ];
});

/// The discovery catalog (REQ-EXP-09).
final exploreTracksProvider =
    StateNotifierProvider<ExploreTracksNotifier, List<Track>>((ref) {
  return ExploreTracksNotifier();
});

/// Pagination cursor for the `All Songs` catalog browser.
final exploreVisibleCountProvider =
    StateProvider<int>((ref) => exploreCatalogPageSize);

/// Filtered + sorted catalog projection across all filter dimensions.
final filteredExploreTracksProvider = Provider<List<Track>>((ref) {
  return filterExploreTracks(
    tracks: ref.watch(exploreTracksProvider),
    query: ref.watch(exploreSearchQueryProvider),
    genre: ref.watch(exploreGenreFilterProvider),
    mood: ref.watch(exploreMoodFilterProvider),
    language: ref.watch(exploreLanguageFilterProvider),
    sortBy: ref.watch(exploreSortByProvider),
  );
});

/// The currently rendered catalog page.
final visibleExploreTracksProvider = Provider<List<Track>>((ref) {
  final filtered = ref.watch(filteredExploreTracksProvider);
  final visibleCount = ref.watch(exploreVisibleCountProvider);
  if (filtered.length <= visibleCount) return filtered;
  return List.unmodifiable(filtered.sublist(0, visibleCount));
});

/// True while the catalog holds further pages.
final hasMoreExploreTracksProvider = Provider<bool>((ref) {
  return ref.watch(filteredExploreTracksProvider).length >
      ref.watch(exploreVisibleCountProvider);
});

/// `New This Week` slice — the newest curated drops (Blueprint 01 §5 Section B).
final newThisWeekTracksProvider = Provider<List<Track>>((ref) {
  final tracks = ref.watch(exploreTracksProvider);
  if (tracks.length <= exploreCatalogPageSize) return tracks;
  return List.unmodifiable(tracks.sublist(0, exploreCatalogPageSize));
});

/// `Rising` slice — trending ranked tracks ordered by rank (REQ-EXP-05).
final risingTracksProvider = Provider<List<Track>>((ref) {
  final rising = ref
      .watch(exploreTracksProvider)
      .where((track) => track.trendingRank != null)
      .toList();
  rising.sort((a, b) => a.trendingRank!.compareTo(b.trendingRank!));
  return List.unmodifiable(rising);
});

class ExploreTracksNotifier extends StateNotifier<List<Track>> {
  ExploreTracksNotifier() : super(_seedTracks());

  /// Prepends a newly published track to the catalog.
  void addTrack(Track track) {
    state = [track, ...state];
  }
}

/// Resets the `All Songs` pagination cursor whenever a filter dimension changes.
void resetExploreCatalogCursor(WidgetRef ref) {
  ref.read(exploreVisibleCountProvider.notifier).state = exploreCatalogPageSize;
}

/// Advances the `All Songs` pagination cursor (`Load more`, REQ-EXP-08).
void loadMoreExploreTracks(WidgetRef ref) {
  final total = ref.read(filteredExploreTracksProvider).length;
  final next = ref.read(exploreVisibleCountProvider) + exploreCatalogPageSize;
  ref.read(exploreVisibleCountProvider.notifier).state =
      next > total ? total : next;
}

/// Clears every catalog filter dimension and the search query (REQ-EXP-08).
void clearExploreFilters(WidgetRef ref) {
  ref.read(exploreSearchQueryProvider.notifier).state = '';
  ref.read(exploreGenreFilterProvider.notifier).state = 'All';
  ref.read(exploreMoodFilterProvider.notifier).state = null;
  ref.read(exploreLanguageFilterProvider.notifier).state = 'All';
  ref.read(exploreSortByProvider.notifier).state = ExploreSortBy.newest;
  resetExploreCatalogCursor(ref);
}

/// Pure discovery projection: genre → mood → language → search → ordering.
///
/// `ExploreSortBy.newest` preserves the curated seed order (newest first),
/// because the shared `Track` entity carries no publication timestamp.
List<Track> filterExploreTracks({
  required List<Track> tracks,
  String query = '',
  String genre = 'All',
  String? mood,
  String language = 'All',
  ExploreSortBy sortBy = ExploreSortBy.newest,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  final normalizedGenre = genre.trim().toLowerCase();
  final normalizedMood = (mood ?? '').trim().toLowerCase();
  final normalizedLanguage = language.trim().toLowerCase();

  final scoped = tracks.where((track) {
    if (normalizedGenre.isNotEmpty &&
        normalizedGenre != 'all' &&
        track.genre.toLowerCase() != normalizedGenre) {
      return false;
    }
    if (normalizedMood.isNotEmpty &&
        (track.mood ?? '').toLowerCase() != normalizedMood) {
      return false;
    }
    if (normalizedLanguage.isNotEmpty &&
        normalizedLanguage != 'all' &&
        track.language.toLowerCase() != normalizedLanguage) {
      return false;
    }
    if (normalizedQuery.isEmpty) return true;

    return track.title.toLowerCase().contains(normalizedQuery) ||
        track.creatorName.toLowerCase().contains(normalizedQuery) ||
        track.genre.toLowerCase().contains(normalizedQuery) ||
        track.language.toLowerCase().contains(normalizedQuery) ||
        (track.mood ?? '').toLowerCase().contains(normalizedQuery);
  }).toList();

  if (sortBy == ExploreSortBy.mostLiked) {
    scoped.sort((a, b) => b.likeCount.compareTo(a.likeCount));
  }

  return List.unmodifiable(scoped);
}

/// Builds the playback queue for [track] from the discovery catalog.
List<Track> exploreQueueFor(List<Track> catalog, Track track) {
  if (catalog.any((candidate) => candidate.id == track.id)) return catalog;
  return [track, ...catalog];
}

/// Queues [track] inside the catalog and starts playback in the persistent
/// bottom transport dock (REQ-EXP-04, guardrail 7).
void playExploreTrack(WidgetRef ref, Track track) {
  final catalog = ref.read(exploreTracksProvider);
  ref
      .read(playerStateProvider.notifier)
      .playTrack(track, queue: exploreQueueFor(catalog, track));
}

/// Queues continuous playback of every catalog track in [genre] (REQ-EXP-07).
/// Returns the queued slice so callers can surface feedback when it is empty.
List<Track> playExploreGenreRadio(WidgetRef ref, String genre) {
  final matches = ref
      .read(exploreTracksProvider)
      .where((track) => track.genre.toLowerCase() == genre.toLowerCase())
      .toList();

  if (matches.isEmpty) return const [];

  ref
      .read(playerStateProvider.notifier)
      .playTrack(matches.first, queue: matches);
  return List.unmodifiable(matches);
}

/// Seeded production discovery catalog (Phase 5 handoff §2).
List<Track> _seedTracks() {
  const origin = 'https://cdn.vhunambi.com/audio';

  return const [
    Track(
      id: 'exp_track_001',
      title: 'Grateful in the Light',
      creatorName: 'Sigwa & Inaf',
      creatorHandle: '@sigwa_inaf',
      genre: 'Amapiano',
      language: 'English',
      duration: Duration(minutes: 3, seconds: 36),
      audioUrl: '$origin/grateful-in-the-light.mp3',
      likeCount: 1002,
      playCount: 3420,
      isNew: true,
      mood: 'Uplifting',
    ),
    Track(
      id: 'exp_track_002',
      title: 'Ndo Mufuna Matibe',
      creatorName: 'Fifi',
      creatorHandle: '@fifi',
      genre: 'Amapiano',
      language: 'Tshivenḓa',
      duration: Duration(minutes: 3, seconds: 18),
      audioUrl: '$origin/ndo-mufuna-matibe.mp3',
      likeCount: 840,
      playCount: 2800,
      trendingRank: 1,
      mood: 'Nostalgic',
    ),
    Track(
      id: 'exp_track_003',
      title: 'Township Log Drum Heat',
      creatorName: 'Sipho',
      creatorHandle: '@sipho',
      genre: 'Amapiano',
      language: 'Instrumental',
      duration: Duration(minutes: 3),
      audioUrl: '$origin/township-log-drum-heat.mp3',
      likeCount: 620,
      playCount: 1950,
      trendingRank: 2,
      mood: 'Energetic',
    ),
    Track(
      id: 'exp_track_004',
      title: 'Durban Midnight Bass',
      creatorName: 'DJ Vibe',
      creatorHandle: '@djvibe',
      genre: 'Gqom',
      language: 'Instrumental',
      duration: Duration(minutes: 2, seconds: 30),
      audioUrl: '$origin/durban-midnight-bass.mp3',
      likeCount: 950,
      playCount: 4100,
      trendingRank: 3,
      mood: 'Dark',
    ),
    Track(
      id: 'exp_track_005',
      title: 'Kwaito Renaissance',
      creatorName: 'Muzi',
      creatorHandle: '@muzi',
      genre: 'Kwaito',
      language: 'isiZulu',
      duration: Duration(minutes: 3, seconds: 30),
      audioUrl: '$origin/kwaito-renaissance.mp3',
      likeCount: 430,
      playCount: 1200,
      mood: 'Party',
    ),
    Track(
      id: 'exp_track_006',
      title: 'Maskandi Strings of Natal',
      creatorName: 'Ndugelo',
      creatorHandle: '@ndugelo',
      genre: 'Maskandi',
      language: 'isiZulu',
      duration: Duration(minutes: 4),
      audioUrl: '$origin/maskandi-strings-of-natal.mp3',
      likeCount: 780,
      playCount: 2600,
      mood: 'Peaceful',
    ),
    Track(
      id: 'exp_track_007',
      title: 'Afro Sunset Melodies',
      creatorName: 'Lerato',
      creatorHandle: '@lerato',
      genre: 'Afro House',
      language: 'English',
      duration: Duration(minutes: 3, seconds: 45),
      audioUrl: '$origin/afro-sunset-melodies.mp3',
      likeCount: 890,
      playCount: 3100,
      mood: 'Romantic',
    ),
    Track(
      id: 'exp_track_008',
      title: 'Lagos Pulse',
      creatorName: 'Ade',
      creatorHandle: '@ade',
      genre: 'Afrobeats',
      language: 'Yoruba',
      duration: Duration(minutes: 3, seconds: 10),
      audioUrl: '$origin/lagos-pulse.mp3',
      likeCount: 1120,
      playCount: 4800,
      mood: 'Energetic',
    ),
  ];
}

/// Controls the transient 4-second title pill visibility (REQ-EXP-TOPBAR-02).
final exploreTitlePillVisibleProvider = StateProvider<bool>((ref) => true);

/// Helper to trigger / reset the transient 4s title pill whenever Tab 1 (Explore)
/// becomes the active visible tab in RootShell's IndexedStack.
void resetExploreTitleFade(WidgetRef ref) {
  ref.read(exploreTitlePillVisibleProvider.notifier).state = true;
}

/// Active reel feed filter tab inside [KineticReelsModal] (REQ-EXP-REEL-TABS-01).
final activeReelTabProvider =
    StateProvider<ReelFeedTab>((ref) => ReelFeedTab.trending);

/// Returns the reels stream sorted/filtered by [activeReelTabProvider] (REQ-EXP-REEL-TABS-02).
final filteredReelsByTabProvider = Provider<List<PublishedClip>>((ref) {
  final tab = ref.watch(activeReelTabProvider);
  final allClips = ref.watch(trendingReelsProvider);
  final following = ref.watch(followingCreatorIdsProvider);

  return switch (tab) {
    ReelFeedTab.trending => [...allClips]
      ..sort((a, b) => b.likeCount.compareTo(a.likeCount)),
    ReelFeedTab.forYou => allClips,
    ReelFeedTab.following =>
      allClips.where((c) => following.contains(c.creatorId)).toList(),
    ReelFeedTab.newest => [...allClips]
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt)),
  };
});

/// Set of creator IDs that the current user is following.
final followingCreatorIdsProvider =
    StateNotifierProvider<FollowingCreatorsNotifier, Set<String>>((ref) {
  return FollowingCreatorsNotifier();
});

class FollowingCreatorsNotifier extends StateNotifier<Set<String>> {
  FollowingCreatorsNotifier() : super({'creator_makhadzi'});

  void toggleFollow(String creatorId) {
    if (state.contains(creatorId)) {
      state = state.where((id) => id != creatorId).toSet();
    } else {
      state = {...state, creatorId};
    }
  }

  bool isFollowing(String creatorId) => state.contains(creatorId);
}

/// Social music posts feed provider (REQ-EXP-FEED-01).
final socialFeedPostsProvider =
    StateNotifierProvider<SocialFeedPostsNotifier, List<SocialMusicPost>>(
        (ref) {
  final outbox = ref.watch(syncOutboxServiceProvider);
  return SocialFeedPostsNotifier(outbox: outbox);
});

class SocialFeedPostsNotifier extends StateNotifier<List<SocialMusicPost>> {
  final SyncOutboxService? outbox;

  SocialFeedPostsNotifier({this.outbox})
      : super(seedSocialPosts());

  SyncOutboxService? get _outbox => outbox;

  void toggleLike(String postId) {
    state = [
      for (final post in state)
        if (post.id == postId)
          post.copyWith(
            isLikedByMe: !post.isLikedByMe,
            likeCount:
                post.isLikedByMe ? post.likeCount - 1 : post.likeCount + 1,
          )
        else
          post,
    ];
    _outbox?.enqueue(SyncMutationRecord(
      idempotencyKey: 'mut_like_${postId}_${DateTime.now().millisecondsSinceEpoch}',
      entityType: 'post',
      action: 'like',
      payload: {'postId': postId},
      createdAt: DateTime.now(),
    ));
  }

  void addPost(SocialMusicPost post) {
    state = [post, ...state];
    _outbox?.enqueue(SyncMutationRecord(
      idempotencyKey: 'mut_post_${post.id}',
      entityType: 'post',
      action: 'create',
      payload: post.toJson(),
      createdAt: DateTime.now(),
    ));
  }

  void repostPost({
    required String originalPostId,
    required SocialMusicPost repostPost,
  }) {
    state = [
      repostPost,
      for (final post in state)
        if (post.id == originalPostId)
          post.copyWith(repostCount: post.repostCount + 1)
        else
          post,
    ];
    _outbox?.enqueue(SyncMutationRecord(
      idempotencyKey: 'mut_repost_${repostPost.id}',
      entityType: 'post',
      action: 'repost',
      payload: {
        'originalPostId': originalPostId,
        'repost': repostPost.toJson(),
      },
      createdAt: DateTime.now(),
    ));
  }

  /// Toggles community A&R co-sign on a post and triggers live graduation (REQ-COSIGN-GRAD-02, REQ-P46-SYNC-01).
  void cosignPost(String postId) {
    state = [
      for (final post in state)
        if (post.id == postId)
          post.copyWith(
            cosignCount: post.isCosigned
                ? (post.cosignCount - 1).clamp(0, 9999)
                : post.cosignCount + 1,
            isCosigned: !post.isCosigned,
          )
        else
          post,
    ];
    _outbox?.enqueue(SyncMutationRecord(
      idempotencyKey: 'mut_cosign_${postId}_${DateTime.now().millisecondsSinceEpoch}',
      entityType: 'cosign',
      action: 'cosign',
      payload: {'postId': postId},
      createdAt: DateTime.now(),
    ));
  }
}

/// Persisted recent searches provider (REQ-EXP-SEARCH-02).
final recentSearchesProvider =
    StateNotifierProvider<RecentSearchesNotifier, List<String>>((ref) {
  return RecentSearchesNotifier();
});

class RecentSearchesNotifier extends StateNotifier<List<String>> {
  RecentSearchesNotifier()
      : super(const [
          'Kabza de Small log drum',
          'Amapiano 2026 drops',
          'Makhadzi live vocals',
          'Gqom bass kick',
        ]);

  void addQuery(String query) {
    final clean = query.trim();
    if (clean.isEmpty) return;
    state = [
      clean,
      ...state.where((q) => q.toLowerCase() != clean.toLowerCase())
    ].take(10).toList();
  }

  void removeQuery(String query) {
    state = state.where((q) => q != query).toList();
  }

  void clearAll() {
    state = const [];
  }
}

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vhunambi_client/core/auth/auth_providers.dart';
import 'package:vhunambi_client/core/constants/app_assets.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/core/design_system/tokens/vhunambi_mood.dart';
import 'package:vhunambi_client/core/resilience/safe_notifier_mixin.dart';
import 'package:vhunambi_client/core/storage/sovereign_domain_repositories.dart';
import 'package:vhunambi_client/core/sync/sync_outbox_service.dart';
import 'package:vhunambi_client/features/explore/data/repositories/http_explore_repository.dart';
import 'package:vhunambi_client/features/explore/domain/models/explore_models.dart';
import 'package:vhunambi_client/features/explore/domain/models/social_music_post.dart';
import 'package:vhunambi_client/features/explore/domain/services/discovery_hierarchy_ranker.dart';
import 'package:vhunambi_client/features/notifications/domain/models/notification_entity.dart';
import 'package:vhunambi_client/features/notifications/domain/models/notification_enums.dart';
import 'package:vhunambi_client/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:vhunambi_client/features/player/presentation/providers/player_provider.dart';
import 'package:vhunambi_client/features/social/domain/models/kinetic_reaction.dart';
import 'package:vhunambi_client/features/social/domain/models/published_clip.dart';
import 'package:vhunambi_client/features/social/presentation/providers/trending_reels_provider.dart';
import 'package:vhunambi_client/shared/models/track.dart';

/// Catalog page size driving the `Load more` pagination cursor (REQ-EXP-08).
const int exploreCatalogPageSize = 6;

/// Active Explore discovery sub-tab (REQ-EXP-02).

/// Active 3-Stage Discovery Hierarchy Tier filter (Phase 39 REQ-DISC-TIER-01).
/// `null` means unconstrained (all tiers).
final selectedDiscoveryTierProvider = StateProvider<DiscoveryStageTier?>(
  (ref) => null,
);

final exploreTabProvider = StateProvider<ExploreTab>(
  (ref) => ExploreTab.discover,
);

/// Real-time Explore search text (REQ-EXP-01).
final exploreSearchQueryProvider = StateProvider<String>((ref) => '');

/// Genre filter pill selection — `'All'` disables genre filtering.
final exploreGenreFilterProvider = StateProvider<String>((ref) => 'All');

/// Mood filter chip selection — `null` disables mood filtering.
final exploreMoodFilterProvider = StateProvider<String?>((ref) => null);

/// Language dropdown selection — `'All'` disables language filtering.
final exploreLanguageFilterProvider = StateProvider<String>((ref) => 'All');

/// Catalog ordering (REQ-EXP-08).
final exploreSortByProvider = StateProvider<ExploreSortBy>(
  (ref) => ExploreSortBy.newest,
);

/// Featured + cloud-hydrated Creator directory deck (REQ-EXP-06).
final exploreCreatorsProvider =
    StateNotifierProvider<ExploreCreatorsNotifier, List<CreatorProfile>>((ref) {
      final repo = ref.watch(exploreRepositoryProvider);
      final notifier = ExploreCreatorsNotifier(repository: repo);
      Future<void>.microtask(notifier.refreshFromCloud);
      return notifier;
    });

class ExploreCreatorsNotifier extends StateNotifier<List<CreatorProfile>>
    with SafeNotifierMixin<List<CreatorProfile>> {
  static const List<CreatorProfile> _seededCreators = [
    CreatorProfile(
      id: 'creator_zania_catalog',
      name: 'Zania Music Catalog',
      handle: '@zania_catalog',
      initials: 'ZM',
      trackCount: 186,
      primaryGenres: ['Afrobeats', 'Amapiano', 'Mzansi Pop'],
      isVerified: true,
    ),
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

  final HttpExploreRepository? repository;

  ExploreCreatorsNotifier({this.repository}) : super(_seededCreators);

  Future<void> refreshFromCloud() async {
    final repo = repository;
    if (repo == null) return;
    final remote = await repo.fetchExploreCreators(limit: 100);
    if (!mounted || remote.isEmpty) return;

    final byId = <String, CreatorProfile>{};
    for (final c in remote) {
      if (c.id.isNotEmpty) byId[c.id] = c;
    }
    for (final c in _seededCreators) {
      byId.putIfAbsent(c.id, () => c);
    }
    final merged = byId.values.toList()
      ..sort((a, b) => b.trackCount.compareTo(a.trackCount));
    state = List<CreatorProfile>.unmodifiable(merged);
  }
}

/// HTTP repository backing dynamic Explore discovery feeds & genre radio (Phase 59).
final exploreRepositoryProvider = Provider<HttpExploreRepository>((ref) {
  return HttpExploreRepository(
    baseUrl: AppConstants.apiRestBaseUrl,
    authInterceptor: ref.watch(authDioInterceptorProvider),
  );
});

/// Dynamic Genre Radio harmonic rotation with seamless offline catalog fallback (Phase 59).
final exploreGenreRadioProvider =
    FutureProvider.family<ExploreRadioStation, String>((ref, genre) async {
      final repo = ref.watch(exploreRepositoryProvider);
      final remote = await repo.fetchGenreRadio(genre);
      if (remote != null && remote.rotation.isNotEmpty) {
        return remote;
      }

      final catalog = ref.watch(exploreTracksProvider);
      final normalized = genre.trim().toLowerCase();
      final matches = normalized.isEmpty || normalized == 'all'
          ? catalog
          : catalog
                .where((t) => t.genre.toLowerCase() == normalized)
                .toList(growable: false);
      final pool = matches.isNotEmpty ? matches : catalog;
      return ExploreRadioStation(
        genre: genre.isEmpty ? 'All' : genre,
        stationTitle: genre.isEmpty || normalized == 'all'
            ? 'Vhunambi Sovereign Pan-African Radio'
            : '$genre Sovereign Radio',
        description: 'Curated $genre rotation with offline Vault resilience.',
        rotation: pool,
      );
    });

/// The discovery catalog (REQ-EXP-09 + Phase 59 cloud hydration).
final exploreTracksProvider =
    StateNotifierProvider<ExploreTracksNotifier, List<Track>>((ref) {
      ref.watch(currentCreatorIdProvider);
      final repo = ref.watch(exploreRepositoryProvider);
      final outbox = ref.watch(syncOutboxServiceProvider);
      final notifier = ExploreTracksNotifier(
        repository: repo,
        outbox: outbox,
        ref: ref,
      );
      Future<void>.microtask(notifier.refreshFromCloud);
      return notifier;
    });

/// Pagination cursor for the `All Songs` catalog browser.
final exploreVisibleCountProvider = StateProvider<int>(
  (ref) => exploreCatalogPageSize,
);

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

class ExploreTracksNotifier extends StateNotifier<List<Track>>
    with SafeNotifierMixin<List<Track>> {
  final HttpExploreRepository? _repository;
  final SyncOutboxService? _outbox;
  final Ref? ref;
  Set<String> _likedTrackIds = <String>{};

  ExploreTracksNotifier({this._repository, this._outbox, this.ref})
    : super(_initialTracks()) {
    if (SovereignDomainStorageMode.canHydrateFromStorage(
      AppConstants.tracksBoxKey,
    )) {
      _likedTrackIds = Set<String>.from(
        ExploreCacheRepository.loadLikedTrackIds() ?? const <String>{},
      );
    }
  }

  static List<Track> _initialTracks() {
    if (SovereignDomainStorageMode.canHydrateFromStorage(
      AppConstants.tracksBoxKey,
    )) {
      final cached = ExploreCacheRepository.loadCachedTracks();
      if (cached != null && cached.isNotEmpty) {
        return List<Track>.unmodifiable(cached.map(Track.fromJson));
      }
    }
    return _seedTracks();
  }

  Set<String> get likedTrackIds => Set<String>.unmodifiable(_likedTrackIds);

  bool isTrackLiked(String trackId) => _likedTrackIds.contains(trackId);

  /// Toggles like status on an Explore track and persists both track cache and liked IDs.
  void toggleTrackLike(String trackId) {
    final alreadyLiked = _likedTrackIds.contains(trackId);
    if (alreadyLiked) {
      _likedTrackIds.remove(trackId);
    } else {
      _likedTrackIds.add(trackId);
    }
    Track? likedTrack;
    state = [
      for (final track in state)
        if (track.id == trackId)
          () {
            final updated = track.copyWith(
              likeCount: alreadyLiked
                  ? (track.likeCount - 1).clamp(0, 9999999)
                  : track.likeCount + 1,
            );
            if (!alreadyLiked) likedTrack = updated;
            return updated;
          }()
        else
          track,
    ];
    if (likedTrack != null) {
      final track = likedTrack!;
      try {
        ref
            ?.read(notificationsProvider.notifier)
            .addNotification(
              NotificationEntity(
                id: 'notif_exp_track_like_${track.id}',
                title: 'Liked "${track.title}"',
                message: 'Hearted ${track.creatorName}\'s track in Explore.',
                category: NotificationCategory.social,
                priority: NotificationPriority.normal,
                subtype: 'post_like',
                targetRoute: '/track/${track.id}',
                targetEntityId: track.id,
                ctaLabel: 'Open Track Cockpit',
                createdAt: DateTime.now(),
              ),
            );
      } catch (_) {}
    }
    unawaited(ExploreCacheRepository.saveLikedTrackIds(_likedTrackIds));
    unawaited(
      ExploreCacheRepository.saveCachedTracks(
        state.map((t) => t.toJson()).toList(),
      ),
    );
  }

  /// Prepends a newly published track to the catalog.
  void addTrack(Track track) {
    state = [track, ...state];
    unawaited(
      ExploreCacheRepository.saveCachedTracks(
        state.map((t) => t.toJson()).toList(),
      ),
    );
  }

  /// Hydrates dynamic African catalog tracks from `GET /api/explore/tracks`
  /// across cursor pages so large creator catalogs (e.g. Zania 186-track drop)
  /// populate Explore completely with non-destructive offline seed fallback.
  Future<bool> refreshFromCloud({
    String? genre,
    String? stage,
    String sort = 'newest',
    bool mergeWithSeeds = true,
  }) async {
    final repo = _repository;
    if (repo == null) return false;
    final collected = <Track>[];
    final seenIds = <String>{};
    String? cursor;
    for (var page = 0; page < 4; page++) {
      final res = await repo.fetchExploreTracksPage(
        genre: genre,
        stage: stage,
        sort: sort,
        cursor: cursor,
        limit: 100,
      );
      if (res.items.isEmpty) break;
      for (final track in res.items) {
        if (seenIds.add(track.id)) {
          collected.add(track);
        }
      }
      cursor = res.nextCursor;
      if (cursor == null || cursor.isEmpty) break;
    }
    if (!mounted || collected.isEmpty) return false;

    if (!mergeWithSeeds) {
      state = List<Track>.unmodifiable(collected);
    } else {
      final retainedLocal = state
          .where((t) => !seenIds.contains(t.id))
          .toList(growable: false);
      state = List<Track>.unmodifiable([...collected, ...retainedLocal]);
    }
    unawaited(
      ExploreCacheRepository.saveCachedTracks(
        state.map((t) => t.toJson()).toList(),
      ),
    );
    return true;
  }

  /// Optimistically adds [track], queues outbox mutation, and publishes to cloud.
  Future<Track> publishTrackToCloud(Track track) async {
    addTrack(track);
    await _outbox?.enqueue(
      SyncMutationRecord(
        idempotencyKey: 'mut_track_${track.id}',
        entityType: 'track',
        action: 'create',
        payload: track.toJson(),
        createdAt: DateTime.now(),
      ),
    );
    final published = await _repository?.publishTrack(track);
    if (published != null && mounted) {
      state = [
        for (final t in state)
          if (t.id == track.id) published else t,
      ];
      unawaited(
        ExploreCacheRepository.saveCachedTracks(
          state.map((t) => t.toJson()).toList(),
        ),
      );
      return published;
    }
    return track;
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
  ref.read(exploreVisibleCountProvider.notifier).state = next > total
      ? total
      : next;
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
    if (normalizedMood.isNotEmpty) {
      final canonicalFilterMood = VhunambiMood.tryNormalize(normalizedMood);
      if (canonicalFilterMood == null) {
        if ((track.mood ?? '').trim().toLowerCase() != normalizedMood) {
          return false;
        }
      } else if (VhunambiMood.normalize(track.mood).moodId !=
          canonicalFilterMood.moodId) {
        return false;
      }
    }
    if (normalizedLanguage.isNotEmpty &&
        normalizedLanguage != 'all' &&
        track.language.toLowerCase() != normalizedLanguage) {
      return false;
    }
    if (normalizedQuery.isEmpty) return true;

    return track.title.toLowerCase().contains(normalizedQuery) ||
        track.creatorName.toLowerCase().contains(normalizedQuery) ||
        (track.creatorHandle ?? '').toLowerCase().contains(normalizedQuery) ||
        (track.creatorId ?? '').toLowerCase().contains(normalizedQuery) ||
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
      coverUrl: 'asset:${AppAssets.sunsetMelodiesCover}',
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
      coverUrl: 'asset:${AppAssets.timbreCantor}',
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
      coverUrl: 'asset:${AppAssets.musicFeelEscapeCover}',
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
      coverUrl: 'asset:${AppAssets.timbreProducer}',
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
      coverUrl: 'asset:${AppAssets.heritageCrateCover}',
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
      coverUrl: 'asset:${AppAssets.timbreElder}',
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
      coverUrl: 'asset:${AppAssets.fiveVoicesCover}',
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
      coverUrl: 'asset:${AppAssets.timbreCrooner}',
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
final activeReelTabProvider = StateProvider<ReelFeedTab>(
  (ref) => ReelFeedTab.trending,
);

/// Returns the reels stream sorted/filtered by [activeReelTabProvider] (REQ-EXP-REEL-TABS-02).
final filteredReelsByTabProvider = Provider<List<PublishedClip>>((ref) {
  final tab = ref.watch(activeReelTabProvider);
  final allClips = ref.watch(trendingReelsProvider);
  final following = ref.watch(followingCreatorIdsProvider);

  return switch (tab) {
    ReelFeedTab.trending => [
      ...allClips,
    ]..sort((a, b) => b.likeCount.compareTo(a.likeCount)),
    ReelFeedTab.forYou => allClips,
    ReelFeedTab.following =>
      allClips.where((c) => following.contains(c.creatorId)).toList(),
    ReelFeedTab.newest => [
      ...allClips,
    ]..sort((a, b) => b.publishedAt.compareTo(a.publishedAt)),
  };
});

/// Set of creator IDs that the current user is following.
final followingCreatorIdsProvider =
    StateNotifierProvider<FollowingCreatorsNotifier, Set<String>>((ref) {
      ref.watch(currentCreatorIdProvider);
      return FollowingCreatorsNotifier(ref);
    });

class FollowingCreatorsNotifier extends StateNotifier<Set<String>> {
  final Ref? _ref;

  FollowingCreatorsNotifier([this._ref]) : super(_initialFollowing());

  static Set<String> _initialFollowing() {
    if (SovereignDomainStorageMode.canHydrateFromStorage(
      AppConstants.tracksBoxKey,
    )) {
      final saved = ExploreCacheRepository.loadFollowingIds();
      if (saved != null) return Set<String>.from(saved);
    }
    return {'creator_makhadzi'};
  }

  void toggleFollow(String creatorId) {
    final wasFollowing = state.contains(creatorId);
    if (wasFollowing) {
      state = state.where((id) => id != creatorId).toSet();
    } else {
      state = {...state, creatorId};
      try {
        final display = creatorId.startsWith('@') ? creatorId : '@$creatorId';
        _ref
            ?.read(notificationsProvider.notifier)
            .addNotification(
              NotificationEntity(
                id: 'notif_follow_${creatorId}_${DateTime.now().millisecondsSinceEpoch}',
                title: 'Following $display',
                message:
                    'You will see new drops, posts, and reels from $display.',
                category: NotificationCategory.social,
                priority: NotificationPriority.normal,
                subtype: 'follow',
                targetRoute: '/creator/$creatorId',
                targetEntityId: creatorId,
                ctaLabel: 'View Creator Profile',
                createdAt: DateTime.now(),
              ),
            );
      } catch (_) {}
    }
    unawaited(ExploreCacheRepository.saveFollowingIds(state));
  }

  bool isFollowing(String creatorId) => state.contains(creatorId);
}

/// Community A&R Co-Sign vote counts indexed by post ID (REQ-P60-DOM-05).
final coSignVotesProvider = Provider<Map<String, int>>((ref) {
  final posts = ref.watch(socialFeedPostsProvider);
  return {for (final post in posts) post.id: post.cosignCount};
});

/// Social music posts feed provider (REQ-EXP-FEED-01 + Phase 59 cloud sync).
final socialFeedPostsProvider =
    StateNotifierProvider<SocialFeedPostsNotifier, List<SocialMusicPost>>((
      ref,
    ) {
      ref.watch(currentCreatorIdProvider);
      final outbox = ref.watch(syncOutboxServiceProvider);
      final repo = ref.watch(exploreRepositoryProvider);
      return SocialFeedPostsNotifier(
        outbox: outbox,
        repository: repo,
        ref: ref,
      );
    });

class SocialFeedPostsNotifier extends StateNotifier<List<SocialMusicPost>> {
  final SyncOutboxService? outbox;
  final HttpExploreRepository? repository;
  final Ref? ref;

  SocialFeedPostsNotifier({this.outbox, this.repository, this.ref})
    : super(_initialPosts());

  static List<SocialMusicPost> _initialPosts() {
    final seeds = seedSocialPosts();
    if (!SovereignDomainStorageMode.canHydrateFromStorage(
      AppConstants.tracksBoxKey,
    )) {
      return seeds;
    }

    final merged = <SocialMusicPost>[];
    final seenIds = <String>{};

    final customRaw = ExploreCacheRepository.loadCustomPosts();
    if (customRaw != null && customRaw.isNotEmpty) {
      for (final raw in customRaw) {
        try {
          final post = SocialMusicPost.fromJson(raw);
          if (seenIds.add(post.id)) {
            merged.add(post);
          }
        } catch (_) {}
      }
    }

    for (final seed in seeds) {
      if (seenIds.add(seed.id)) {
        merged.add(seed);
      }
    }

    final likedPostIds = ExploreCacheRepository.loadLikedPostIds();
    final coSignStates = ExploreCacheRepository.loadCoSignStates();
    final coSignVotes = ExploreCacheRepository.loadCoSignVotes();

    if (likedPostIds == null && coSignStates == null && coSignVotes == null) {
      return List<SocialMusicPost>.unmodifiable(merged);
    }

    return List<SocialMusicPost>.unmodifiable([
      for (final post in merged)
        () {
          var next = post;
          if (likedPostIds != null) {
            final shouldBeLiked = likedPostIds.contains(post.id);
            if (shouldBeLiked != post.isLikedByMe) {
              next = next.copyWith(
                isLikedByMe: shouldBeLiked,
                likeCount: shouldBeLiked
                    ? post.likeCount + 1
                    : (post.likeCount - 1).clamp(0, 9999999),
              );
            }
          }
          final csState = coSignStates?[post.id];
          if (csState != null) {
            next = next.copyWith(
              cosignCount:
                  (csState['cosignCount'] as num?)?.toInt() ?? next.cosignCount,
              isCosigned: (csState['isCosigned'] as bool?) ?? next.isCosigned,
            );
          } else if (coSignVotes != null && coSignVotes.containsKey(post.id)) {
            next = next.copyWith(cosignCount: coSignVotes[post.id]!);
          }
          return next;
        }(),
    ]);
  }

  void _persistPostsSnapshot() {
    unawaited(
      ExploreCacheRepository.saveCustomPosts([
        for (final post in state) post.toJson(),
      ]),
    );
  }

  void _persistLikesSnapshot() {
    final likedIds = {
      for (final post in state)
        if (post.isLikedByMe) post.id,
    };
    unawaited(ExploreCacheRepository.saveLikedPostIds(likedIds));
    _persistPostsSnapshot();
  }

  void _persistCoSignSnapshot() {
    final states = <String, Map<String, dynamic>>{
      for (final post in state)
        if (post.isCosigned || post.cosignCount > 0)
          post.id: <String, dynamic>{
            'cosignCount': post.cosignCount,
            'isCosigned': post.isCosigned,
          },
    };
    unawaited(ExploreCacheRepository.saveCoSignStates(states));
    _persistPostsSnapshot();
  }

  SyncOutboxService? get _outbox => outbox;

  /// Hydrates cloud posts from `GET /api/explore` without disturbing offline seeds on failure.
  Future<bool> refreshFromCloud({String? genre, String? stage}) async {
    final repo = repository;
    if (repo == null) return false;
    final bundle = await repo.fetchExploreBundle(genre: genre, stage: stage);
    if (!mounted || !bundle.isFromCloud || bundle.posts.isEmpty) return false;
    return mergeCloudPosts(bundle.posts);
  }

  @visibleForTesting
  bool mergeRemotePostsPayloadForTest(List<Map<String, dynamic>> rawPosts) =>
      mergeCloudPosts(rawPosts);

  bool mergeCloudPosts(List<Map<String, dynamic>> rawPosts) {
    final existingById = {for (final p in state) p.id: p};
    final hydrated = <SocialMusicPost>[];
    for (final raw in rawPosts) {
      final id = (raw['id'] ?? '').toString();
      if (id.isEmpty) continue;
      final existing = existingById[id];
      if (existing != null) {
        final hasReactionCounts =
            raw.containsKey('reactionCounts') ||
            raw.containsKey('reaction_counts_json');
        final parsedCounts = hasReactionCounts
            ? KineticReactionType.parseCounts(
                raw['reactionCounts'] ?? raw['reaction_counts_json'],
              )
            : existing.reactionCounts;
        final hasMyReaction =
            raw.containsKey('myReaction') || raw.containsKey('my_reaction');
        final parsedMyReaction = hasMyReaction
            ? KineticReactionType.fromWire(
                raw['myReaction'] ?? raw['my_reaction'],
              )
            : existing.myReaction;
        hydrated.add(
          existing.copyWith(
            likeCount:
                (raw['likeCount'] as num?)?.toInt() ?? existing.likeCount,
            isLikedByMe: (raw['isLikedByMe'] as bool?) ?? existing.isLikedByMe,
            reactionCounts: parsedCounts,
            myReaction: parsedMyReaction,
            clearMyReaction: hasMyReaction && parsedMyReaction == null,
            commentCount:
                (raw['commentCount'] as num?)?.toInt() ?? existing.commentCount,
            cosignCount:
                (raw['cosignCount'] as num?)?.toInt() ?? existing.cosignCount,
            repostCount:
                (raw['repostCount'] as num?)?.toInt() ?? existing.repostCount,
          ),
        );
      } else {
        final parsedMyReaction = KineticReactionType.fromWire(
          raw['myReaction'] ?? raw['my_reaction'],
        );
        final rawImages = raw['imageAttachments'] ?? raw['image_attachments'];
        final parsedImages = <KineticPostImageAttachment>[
          if (rawImages is List)
            ...rawImages
                .map((item) {
                  if (item is Map) {
                    final map = Map<String, dynamic>.from(item);
                    final url = AppConstants.normalizeCloudMediaUrl(
                      (map['imageUrl'] ?? map['image_url'] ?? '').toString(),
                    );
                    return KineticPostImageAttachment.fromJson(
                      <String, dynamic>{...map, 'imageUrl': url},
                    );
                  }
                  final url = AppConstants.normalizeCloudMediaUrl(
                    item.toString(),
                  );
                  return KineticPostImageAttachment(imageUrl: url);
                })
                .where((att) => att.imageUrl.isNotEmpty),
        ];
        final rawPrimaryObj = raw['imageAttachment'] ?? raw['image_attachment'];
        KineticPostImageAttachment? parsedPrimaryImage;
        if (rawPrimaryObj is Map) {
          final map = Map<String, dynamic>.from(rawPrimaryObj);
          final url = AppConstants.normalizeCloudMediaUrl(
            (map['imageUrl'] ?? map['image_url'] ?? '').toString(),
          );
          if (url.isNotEmpty) {
            parsedPrimaryImage = KineticPostImageAttachment.fromJson(
              <String, dynamic>{...map, 'imageUrl': url},
            );
          }
        } else if (rawPrimaryObj is String && rawPrimaryObj.trim().isNotEmpty) {
          parsedPrimaryImage = KineticPostImageAttachment(
            imageUrl: AppConstants.normalizeCloudMediaUrl(rawPrimaryObj.trim()),
          );
        }
        parsedPrimaryImage ??= parsedImages.isNotEmpty
            ? parsedImages.first
            : null;

        final rawAudioMap = raw['audioAttachment'] ?? raw['audio_attachment'];
        final parsedAudioAttachment = rawAudioMap is Map
            ? KineticPostAudioAttachment.fromJson(
                Map<String, dynamic>.from(rawAudioMap),
              )
            : null;
        final rawAudioUrl =
            (raw['audioUrl'] ??
                    raw['audio_url'] ??
                    raw['audioPreviewUrl'] ??
                    raw['audio_preview_url'] ??
                    '')
                .toString()
                .trim();
        final rawCoverUrl = (raw['coverUrl'] ?? raw['cover_url'] ?? '')
            .toString()
            .trim();

        hydrated.add(
          SocialMusicPost(
            id: id,
            creatorId: (raw['creatorId'] ?? raw['creator_id'] ?? 'creator_cern')
                .toString(),
            creatorName:
                (raw['creatorName'] ?? raw['creator_name'] ?? 'Creator')
                    .toString(),
            creatorHandle:
                (raw['creatorHandle'] ?? raw['creator_handle'] ?? '@creator')
                    .toString(),
            publishedAt:
                DateTime.tryParse(
                  (raw['createdAt'] ?? raw['created_at'] ?? '').toString(),
                ) ??
                DateTime.now(),
            caption: (raw['caption'] ?? '').toString(),
            imageAttachment: parsedPrimaryImage,
            imageAttachments: parsedImages.isNotEmpty
                ? parsedImages
                : (parsedPrimaryImage != null
                      ? <KineticPostImageAttachment>[parsedPrimaryImage]
                      : const <KineticPostImageAttachment>[]),
            audioAttachment: parsedAudioAttachment,
            track: Track.fromJson(<String, dynamic>{
              'id':
                  raw['trackId'] ??
                  raw['track_id'] ??
                  raw['attachmentId'] ??
                  id,
              'title':
                  raw['trackTitle'] ??
                  raw['track_title'] ??
                  raw['caption'] ??
                  'Cloud Post',
              'creatorName':
                  raw['creatorName'] ?? raw['creator_name'] ?? 'Creator',
              'genre': raw['genre'] ?? 'Amapiano',
              if (rawAudioUrl.isNotEmpty)
                'audioUrl': AppConstants.normalizeCloudMediaUrl(rawAudioUrl),
              if (rawCoverUrl.isNotEmpty)
                'coverUrl': AppConstants.normalizeCloudMediaUrl(rawCoverUrl),
            }),
            likeCount: (raw['likeCount'] as num?)?.toInt() ?? 0,
            isLikedByMe:
                (raw['isLikedByMe'] as bool?) ?? (parsedMyReaction != null),
            reactionCounts: KineticReactionType.parseCounts(
              raw['reactionCounts'] ?? raw['reaction_counts_json'],
            ),
            myReaction: parsedMyReaction,
            commentCount: (raw['commentCount'] as num?)?.toInt() ?? 0,
            cosignCount: (raw['cosignCount'] as num?)?.toInt() ?? 0,
            repostCount: (raw['repostCount'] as num?)?.toInt() ?? 0,
          ),
        );
      }
    }

    if (hydrated.isEmpty) return false;
    final hydratedIds = hydrated.map((p) => p.id).toSet();
    final remaining = state
        .where((p) => !hydratedIds.contains(p.id))
        .toList(growable: false);
    state = List<SocialMusicPost>.unmodifiable([...hydrated, ...remaining]);
    _persistPostsSnapshot();
    return true;
  }

  void toggleLike(String postId) {
    final target = state.cast<SocialMusicPost?>().firstWhere(
      (p) => p?.id == postId,
      orElse: () => null,
    );
    if (target == null) return;
    final currentlyActive = target.myReaction != null || target.isLikedByMe;
    reactToPost(postId, currentlyActive ? null : KineticReactionType.love);
  }

  /// Applies, switches, or clears a multi-reaction on [postId] while preserving legacy like counts.
  void reactToPost(String postId, KineticReactionType? reaction) {
    SocialMusicPost? newlyReacted;
    KineticReactionType? effectiveApplied;
    var found = false;

    state = [
      for (final post in state)
        if (post.id == postId)
          () {
            found = true;
            final counts = Map<KineticReactionType, int>.from(
              post.reactionCounts,
            );
            final sum = counts.values.fold<int>(0, (a, b) => a + b);
            if (sum == 0 && post.likeCount > 0) {
              counts[KineticReactionType.love] = post.likeCount;
            }
            final prevReaction =
                post.myReaction ??
                (post.isLikedByMe ? KineticReactionType.love : null);
            if (prevReaction != null) {
              final nextPrev = (counts[prevReaction] ?? 0) - 1;
              if (nextPrev > 0) {
                counts[prevReaction] = nextPrev;
              } else {
                counts.remove(prevReaction);
              }
            }
            final effectiveNext =
                (reaction != null &&
                    reaction == prevReaction &&
                    post.myReaction != null)
                ? null
                : reaction;
            effectiveApplied = effectiveNext;
            if (effectiveNext != null) {
              counts[effectiveNext] = (counts[effectiveNext] ?? 0) + 1;
            }
            final nextTotal = counts.values.fold<int>(0, (a, b) => a + b);
            final updated = post.copyWith(
              reactionCounts: Map<KineticReactionType, int>.unmodifiable(
                counts,
              ),
              myReaction: effectiveNext,
              clearMyReaction: effectiveNext == null,
              isLikedByMe: effectiveNext != null,
              likeCount: nextTotal,
            );
            if (effectiveNext != null && prevReaction == null) {
              newlyReacted = updated;
            }
            return updated;
          }()
        else
          post,
    ];
    if (!found) return;

    if (newlyReacted != null) {
      final post = newlyReacted!;
      final label = (effectiveApplied ?? KineticReactionType.love).label;
      try {
        ref
            ?.read(notificationsProvider.notifier)
            .addNotification(
              NotificationEntity(
                id: 'notif_post_like_${post.id}',
                title: 'Reacted ($label) to ${post.creatorHandle}\'s Post',
                message: 'You reacted to "${post.track.title}" in Explore.',
                category: NotificationCategory.social,
                priority: NotificationPriority.normal,
                subtype: 'post_like',
                targetRoute: '/track/${post.track.id}',
                targetEntityId: post.track.id,
                ctaLabel: 'Open Track Cockpit',
                createdAt: DateTime.now(),
              ),
            );
      } catch (_) {}
    }
    _persistLikesSnapshot();
    _persistPostsSnapshot();
    unawaited(_syncReactionToCloud(postId, effectiveApplied));
  }

  Future<void> _syncReactionToCloud(
    String postId,
    KineticReactionType? reaction,
  ) async {
    final repo = repository;
    if (repo != null && !repo.shouldSkipNetwork) {
      final result = await repo.reactToPost(postId, reaction);
      if (result != null) {
        if (!mounted) return;
        state = [
          for (final post in state)
            if (post.id == postId)
              post.copyWith(
                isLikedByMe: result.isLikedByMe,
                likeCount: result.likeCount,
                reactionCounts: result.reactionCounts,
                myReaction: result.myReaction,
                clearMyReaction: result.myReaction == null,
              )
            else
              post,
        ];
        _persistLikesSnapshot();
        _persistPostsSnapshot();
        return;
      }
    }
    _outbox?.enqueue(
      SyncMutationRecord(
        idempotencyKey:
            'mut_react_${postId}_${DateTime.now().millisecondsSinceEpoch}',
        entityType: 'post',
        action: 'react',
        payload: {'postId': postId, 'reactionType': reaction?.wireId},
        createdAt: DateTime.now(),
      ),
    );
  }

  /// Increments [commentCount] on [postId] when a comment or reply is added (`REQ-P69-THREAD-05`).
  void incrementCommentCount(String postId, {int delta = 1}) {
    state = [
      for (final post in state)
        if (post.id == postId)
          post.copyWith(
            commentCount: (post.commentCount + delta).clamp(0, 9999999),
          )
        else
          post,
    ];
    _persistPostsSnapshot();
  }

  void addPost(SocialMusicPost post) {
    state = [post, ...state];
    _persistPostsSnapshot();
    unawaited(_syncAddPostToCloud(post));
  }

  Future<void> _syncAddPostToCloud(SocialMusicPost post) async {
    final repo = repository;
    if (repo != null && !repo.shouldSkipNetwork) {
      final published = await repo.publishPost(post.toJson());
      if (published != null) return;
    }
    _outbox?.enqueue(
      SyncMutationRecord(
        idempotencyKey: 'mut_post_${post.id}',
        entityType: 'post',
        action: 'create',
        payload: post.toJson(),
        createdAt: DateTime.now(),
      ),
    );
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
    _persistPostsSnapshot();
    unawaited(_syncRepostToCloud(originalPostId, repostPost));
  }

  Future<void> _syncRepostToCloud(
    String originalPostId,
    SocialMusicPost repostPost,
  ) async {
    final repo = repository;
    if (repo != null && !repo.shouldSkipNetwork) {
      final result = await repo.repostPost(
        originalPostId,
        repost: repostPost.toJson(),
      );
      if (result != null) {
        if (!mounted) return;
        state = [
          for (final post in state)
            if (post.id == originalPostId)
              post.copyWith(repostCount: result.repostCount)
            else
              post,
        ];
        _persistPostsSnapshot();
        return;
      }
    }
    _outbox?.enqueue(
      SyncMutationRecord(
        idempotencyKey: 'mut_repost_${repostPost.id}',
        entityType: 'post',
        action: 'repost',
        payload: {
          'originalPostId': originalPostId,
          'repost': repostPost.toJson(),
        },
        createdAt: DateTime.now(),
      ),
    );
  }

  /// Toggles community A&R co-sign on a post and triggers live graduation (REQ-COSIGN-GRAD-02, REQ-P46-SYNC-01).
  void cosignPost(String postId) {
    SocialMusicPost? newlyCosigned;
    state = [
      for (final post in state)
        if (post.id == postId)
          () {
            final updated = post.copyWith(
              cosignCount: post.isCosigned
                  ? (post.cosignCount - 1).clamp(0, 9999)
                  : post.cosignCount + 1,
              isCosigned: !post.isCosigned,
            );
            if (!post.isCosigned) newlyCosigned = updated;
            return updated;
          }()
        else
          post,
    ];
    if (newlyCosigned != null) {
      final post = newlyCosigned!;
      try {
        ref
            ?.read(notificationsProvider.notifier)
            .addNotification(
              NotificationEntity(
                id: 'notif_cosign_${post.id}',
                title: 'A&R Co-Signed ${post.creatorHandle}',
                message:
                    'Backed "${post.track.title}" in Fresh Crate (${post.cosignCount}/25 votes).',
                category: NotificationCategory.social,
                priority: NotificationPriority.normal,
                subtype: 'ar_cosign',
                targetRoute: '/track/${post.track.id}',
                targetEntityId: post.track.id,
                ctaLabel: 'Open Track Cockpit',
                createdAt: DateTime.now(),
              ),
            );
      } catch (_) {}
    }
    _persistCoSignSnapshot();
    unawaited(_syncCosignToCloud(postId));
  }

  Future<void> _syncCosignToCloud(String postId) async {
    final repo = repository;
    if (repo != null && !repo.shouldSkipNetwork) {
      String? creatorId;
      try {
        creatorId = ref?.read(currentCreatorIdProvider);
      } catch (_) {}
      final result = await repo.cosignPost(postId, creatorId: creatorId);
      if (result != null) {
        if (!mounted) return;
        state = [
          for (final post in state)
            if (post.id == postId)
              post.copyWith(cosignCount: result.cosignCount)
            else
              post,
        ];
        _persistCoSignSnapshot();
        return;
      }
    }
    _outbox?.enqueue(
      SyncMutationRecord(
        idempotencyKey:
            'mut_cosign_${postId}_${DateTime.now().millisecondsSinceEpoch}',
        entityType: 'cosign',
        action: 'cosign',
        payload: {'postId': postId},
        createdAt: DateTime.now(),
      ),
    );
  }
}

/// Persisted recent searches provider (REQ-EXP-SEARCH-02).
final recentSearchesProvider =
    StateNotifierProvider<RecentSearchesNotifier, List<String>>((ref) {
      ref.watch(currentCreatorIdProvider);
      return RecentSearchesNotifier();
    });

class RecentSearchesNotifier extends StateNotifier<List<String>> {
  RecentSearchesNotifier() : super(_initialSearches());

  static List<String> _initialSearches() {
    if (SovereignDomainStorageMode.canHydrateFromStorage(
      AppConstants.tracksBoxKey,
    )) {
      final saved = ExploreCacheRepository.loadRecentSearches();
      if (saved != null) return List<String>.unmodifiable(saved);
    }
    return const <String>[];
  }

  void addQuery(String query) {
    final clean = query.trim();
    if (clean.isEmpty) return;
    state = [
      clean,
      ...state.where((q) => q.toLowerCase() != clean.toLowerCase()),
    ].take(10).toList();
    unawaited(ExploreCacheRepository.saveRecentSearches(state));
  }

  void removeQuery(String query) {
    state = state.where((q) => q != query).toList();
    unawaited(ExploreCacheRepository.saveRecentSearches(state));
  }

  void clearAll() {
    state = const [];
    unawaited(ExploreCacheRepository.saveRecentSearches(state));
  }
}

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vhunambi_client/core/auth/auth_providers.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/core/storage/sovereign_domain_repositories.dart';
import 'package:vhunambi_client/core/sync/sync_outbox_service.dart';
import 'package:vhunambi_client/features/library/data/repositories/http_library_sync_repository.dart';
import 'package:vhunambi_client/features/library/domain/models/library_models.dart';
import 'package:vhunambi_client/features/offline/presentation/providers/offline_providers.dart';
import 'package:vhunambi_client/features/player/presentation/providers/player_provider.dart';

/// Cloud sync status indicator for the Library Vault (Phase 59).
enum LibraryCloudSyncStatus { idle, syncing, synced, offline, error }

/// Injectable repository backing Library Vault local Hive persistence & cloud delta sync.
final librarySyncRepositoryProvider = Provider<HttpLibrarySyncRepository>((
  ref,
) {
  return HttpLibrarySyncRepository(
    authInterceptor: ref.watch(authDioInterceptorProvider),
  );
});

/// Reactive Library Vault cloud sync status pill state.
final libraryCloudSyncStatusProvider = StateProvider<LibraryCloudSyncStatus>(
  (ref) => LibraryCloudSyncStatus.idle,
);

/// Active vault category tab (REQ-LIB-02, Blueprint 04 §2).
final libraryCategoryProvider = StateProvider<LibraryCategory>(
  (ref) => LibraryCategory.songs,
);

/// Real-time vault search text (REQ-LIB-04).
final librarySearchQueryProvider = StateProvider<String>((ref) => '');

/// Dense list vs. square grid rendering mode (REQ-LIB-04).
final libraryViewModeProvider = StateProvider<LibraryViewMode>(
  (ref) => LibraryViewMode.list,
);

/// Vault ordering, driven by the header overflow control (`⋮`).
final librarySortProvider = StateProvider<LibrarySortOrder>(
  (ref) => LibrarySortOrder.newestFirst,
);

/// Local vs. cloud presence filter driven by the search strip filter control.
final librarySyncFilterProvider = StateProvider<LibrarySyncFilter>(
  (ref) => LibrarySyncFilter.any,
);

/// The user vault asset collection, soft-deleted records included (REQ-LIB-08 + Phase 59 cloud sync).
final libraryTracksProvider =
    StateNotifierProvider<LibraryTracksNotifier, List<LibraryTrack>>((ref) {
      final creatorId = ref.watch(currentCreatorIdProvider);
      final repo = ref.watch(librarySyncRepositoryProvider);
      final outbox = ref.watch(syncOutboxServiceProvider);
      final notifier = LibraryTracksNotifier(
        syncRepository: repo,
        outbox: outbox,
        ref: ref,
        creatorId: creatorId,
      );
      Future<void>.microtask(notifier.hydrateFromLocalBox);
      return notifier;
    });

/// Category + search + sync-filter scoped and sorted vault projection.
final filteredLibraryTracksProvider = Provider<List<LibraryTrack>>((ref) {
  return filterLibraryTracks(
    tracks: ref.watch(libraryTracksProvider),
    category: ref.watch(libraryCategoryProvider),
    searchQuery: ref.watch(librarySearchQueryProvider),
    syncFilter: ref.watch(librarySyncFilterProvider),
    sortOrder: ref.watch(librarySortProvider),
  );
});

/// Record count per vault category (drives the Trash rail badge).
final libraryCategoryCountsProvider = Provider<Map<LibraryCategory, int>>((
  ref,
) {
  final tracks = ref.watch(libraryTracksProvider);
  return {
    for (final category in LibraryCategory.values)
      category: filterLibraryTracks(tracks: tracks, category: category).length,
  };
});

/// Every hearted vault record, newest first (favourites rail / quick filter).
final favoriteTracksProvider = Provider<List<LibraryTrack>>((ref) {
  final favorites =
      ref
          .watch(libraryTracksProvider)
          .where((track) => track.isFavorite && !track.isDeleted)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return List.unmodifiable(favorites);
});

/// Recently-played vault ids, newest first, capped at [_recentlyPlayedLimit
/// unique entries (Mission 11).
final recentlyPlayedIdsProvider =
    StateNotifierProvider<RecentlyPlayedNotifier, List<String>>((ref) {
      return RecentlyPlayedNotifier();
    });

/// Resolves [recentlyPlayedIdsProvider] into live vault records, dropping ids
/// that no longer exist or have been soft-deleted.
final recentlyPlayedTracksProvider = Provider<List<LibraryTrack>>((ref) {
  final ids = ref.watch(recentlyPlayedIdsProvider);
  final byId = {
    for (final track in ref.watch(libraryTracksProvider)) track.id: track,
  };
  return [
    for (final id in ids)
      if (byId[id] case final track? when !track.isDeleted) track,
  ];
});

/// Pushes a vault asset into the global persistent player and starts playback.
/// Backs the `▶ Play Now` action (REQ-LIB-06).
void playLibraryTrack(WidgetRef ref, LibraryTrack track) {
  ref.read(playerStateProvider.notifier).playTrack(track.toTrack());
}

/// Maximum number of unique ids retained by [RecentlyPlayedNotifier].
const int _recentlyPlayedLimit = 20;

/// Tracks the most-recently-played vault ids, newest first (Mission 11).
///
/// [register] de-duplicates, moves the id to the front and trims to
/// [_recentlyPlayedLimit] entries.
class RecentlyPlayedNotifier extends StateNotifier<List<String>> {
  RecentlyPlayedNotifier() : super(_hydrateInitial());

  static List<String> _hydrateInitial() {
    if (!SovereignDomainStorageMode.canHydrateFromStorage(
      AppConstants.playbackSessionBoxKey,
    )) {
      return const <String>[];
    }
    return PlaybackSessionRepository.loadRecentlyPlayedIds() ??
        const <String>[];
  }

  /// Records a play of [trackId]: de-dupe, prepend, cap the history length.
  void register(String trackId) {
    if (trackId.isEmpty) return;
    final next = <String>[trackId, ...state.where((id) => id != trackId)];
    state = next.length > _recentlyPlayedLimit
        ? next.sublist(0, _recentlyPlayedLimit)
        : next;
    unawaited(PlaybackSessionRepository.saveRecentlyPlayedIds(state));
  }

  /// Clears the entire recently-played history.
  void clear() {
    state = const <String>[];
    unawaited(PlaybackSessionRepository.saveRecentlyPlayedIds(state));
  }
}

class LibraryTracksNotifier extends StateNotifier<List<LibraryTrack>> {
  final HttpLibrarySyncRepository? _syncRepository;
  final SyncOutboxService? _outbox;
  final Ref? _ref;
  final String _creatorId;
  int _outboxSeq = 0;
  final Set<String> _localMutatedIds = <String>{};

  LibraryTracksNotifier({
    this._syncRepository,
    this._outbox,
    this._ref,
    this._creatorId = 'creator_cern',
  }) : super(_seedTracks());

  String get activeCreatorId => _creatorId;

  void _persistAndQueue(LibraryTrack track, {String action = 'update'}) {
    _syncRepository?.saveTrackLocal(track);
    _outbox?.enqueue(
      SyncMutationRecord(
        idempotencyKey:
            'mut_lib_${track.id}_${track.effectiveUpdatedAtMs}_${action}_${_outboxSeq++}',
        entityType: 'library_track',
        action: action,
        payload: <String, dynamic>{...track.toJson(), 'creatorId': _creatorId},
        createdAt: DateTime.now(),
      ),
    );
  }

  /// Hydrates locally persisted tracks from Hive without erasing initial seeds.
  Future<void> hydrateFromLocalBox() async {
    final repo = _syncRepository;
    if (repo == null) return;
    final stored = await repo.loadLocalTracks();
    if (!mounted || stored.isEmpty) return;
    final safeStored = stored
        .where((t) => !_localMutatedIds.contains(t.id))
        .toList(growable: false);
    if (safeStored.isEmpty) return;
    state = HttpLibrarySyncRepository.mergeTracksLww(state, safeStored);
  }

  /// Replaces/merges remote or delta-hydrated tracks into the live vault.
  void applyMergedTracks(List<LibraryTrack> merged) {
    if (!mounted) return;
    state = List<LibraryTrack>.unmodifiable(merged);
  }

  /// Runs full bidirectional cloud delta sync (`POST /api/library/sync` + LWW merge).
  Future<bool> syncWithCloud() async {
    final repo = _syncRepository;
    if (repo == null) return false;
    _ref?.read(libraryCloudSyncStatusProvider.notifier).state =
        LibraryCloudSyncStatus.syncing;

    final result = await repo.syncDelta(
      creatorId: _creatorId,
      localTracks: state,
    );
    if (!mounted) return result.syncedFromCloud;

    if (result.mergedTracks.isNotEmpty) {
      state = List<LibraryTrack>.unmodifiable(result.mergedTracks);
    }

    _ref
        ?.read(libraryCloudSyncStatusProvider.notifier)
        .state = result.syncedFromCloud
        ? LibraryCloudSyncStatus.synced
        : (result.errorMessage != null
              ? LibraryCloudSyncStatus.offline
              : LibraryCloudSyncStatus.idle);
    return result.syncedFromCloud;
  }

  /// Inserts a freshly generated asset at the top of the vault.
  void addTrack(LibraryTrack track) {
    _localMutatedIds.add(track.id);
    final remaining = state.where((t) => t.id != track.id).toList();
    state = [track, ...remaining];
    _persistAndQueue(track, action: 'create');
  }

  /// Inserts or cleanly upgrades an existing licensed beat/track in the vault (Phase 58).
  void upsertLicensedTrack(LibraryTrack track, {bool enqueueOutbox = true}) {
    _localMutatedIds.add(track.id);
    final remaining = state.where((t) => t.id != track.id).toList();
    state = [track, ...remaining];
    if (enqueueOutbox) {
      _persistAndQueue(track, action: 'create');
    } else {
      _syncRepository?.saveTrackLocal(track);
    }
  }

  /// Soft-deletes the record: `isDeleted: true` + purge timestamp (REQ-LIB-07).
  void deleteTrack(String id) {
    _localMutatedIds.add(id);
    final now = DateTime.now();
    LibraryTrack? updated;
    state = [
      for (final track in state)
        if (track.id == id)
          updated = track.copyWith(
            isDeleted: true,
            deletedAt: now,
            updatedAtMs: now.millisecondsSinceEpoch,
          )
        else
          track,
    ];
    if (updated != null) {
      _persistAndQueue(updated, action: 'delete');
    }
  }

  /// Restores a soft-deleted record back into its original category.
  void restoreTrack(String id) {
    _localMutatedIds.add(id);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    LibraryTrack? updated;
    state = [
      for (final track in state)
        if (track.id == id)
          updated = track.copyWith(
            isDeleted: false,
            clearDeletedAt: true,
            updatedAtMs: nowMs,
          )
        else
          track,
    ];
    if (updated != null) {
      _persistAndQueue(updated, action: 'update');
    }
  }

  /// Permanently wipes the record (30-day Trash grace period is enforced by the cloud)
  /// along with any cached offline `.vmf` file and vault metadata.
  void purgeTrackPermanently(String id) {
    _localMutatedIds.add(id);
    state = state.where((track) => track.id != id).toList(growable: false);
    _syncRepository?.deleteFromCloud(id, creatorId: _creatorId);
    try {
      final offlineStorage = _ref?.read(offlineStorageServiceProvider);
      if (offlineStorage != null) {
        unawaited(offlineStorage.removeTrackMetadata(id));
      }
    } catch (_) {}
    _outbox?.enqueue(
      SyncMutationRecord(
        idempotencyKey:
            'mut_lib_purge_${id}_${DateTime.now().millisecondsSinceEpoch}',
        entityType: 'library_track',
        action: 'delete',
        payload: <String, dynamic>{
          'id': id,
          'creatorId': _creatorId,
          'hardDelete': true,
        },
        createdAt: DateTime.now(),
      ),
    );
  }

  /// Bumps the lifetime play count by one (jukebox stat badge / Most Played sort).
  void incrementPlayCount(String id) {
    _localMutatedIds.add(id);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    LibraryTrack? updated;
    state = [
      for (final track in state)
        if (track.id == id)
          updated = track.copyWith(
            playCount: track.playCount + 1,
            updatedAtMs: nowMs,
          )
        else
          track,
    ];
    if (updated != null) {
      _persistAndQueue(updated, action: 'update');
    }
  }

  /// Flips the quick heart / favourite flag for a vault record.
  void toggleFavorite(String id) {
    _localMutatedIds.add(id);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    LibraryTrack? updated;
    state = [
      for (final track in state)
        if (track.id == id)
          updated = track.copyWith(
            isFavorite: !track.isFavorite,
            updatedAtMs: nowMs,
          )
        else
          track,
    ];
    if (updated != null) {
      _persistAndQueue(updated, action: 'update');
    }
  }

  /// Updates the offline cache integrity state of a record.
  void setSyncStatus(String id, TrackSyncStatus status) {
    _localMutatedIds.add(id);
    state = [
      for (final track in state)
        if (track.id == id) track.copyWith(syncStatus: status) else track,
    ];
  }

  /// Unified sync status updater per Phase 08 specification.
  void updateTrackSyncStatus(
    String id,
    TrackSyncStatus status, {
    String? localAudioFilePath,
  }) {
    if (status == TrackSyncStatus.cachedLocally && localAudioFilePath != null) {
      setTrackOfflinePath(id, localAudioFilePath);
    } else if (status == TrackSyncStatus.cloudOnly) {
      clearTrackOfflinePath(id);
    } else {
      setSyncStatus(id, status);
    }
  }

  /// Marks the record as cached locally once the vault audio file is written.
  void setTrackOfflinePath(String id, String path) {
    _localMutatedIds.add(id);
    LibraryTrack? updated;
    state = [
      for (final track in state)
        if (track.id == id)
          updated = track.copyWith(
            localAudioFilePath: path,
            syncStatus: TrackSyncStatus.cachedLocally,
          )
        else
          track,
    ];
    if (updated != null) {
      _syncRepository?.saveTrackLocal(updated);
    }
  }

  /// Evicts the local audio copy and returns the record to cloud-only streaming.
  void clearTrackOfflinePath(String id) {
    _localMutatedIds.add(id);
    LibraryTrack? updated;
    state = [
      for (final track in state)
        if (track.id == id)
          updated = track.copyWith(
            clearLocalAudioFilePath: true,
            syncStatus: TrackSyncStatus.cloudOnly,
          )
        else
          track,
    ];
    if (updated != null) {
      _syncRepository?.saveTrackLocal(updated);
    }
  }
}

/// Pure vault projection used by [filteredLibraryTracksProvider]:
/// category scope → local/cloud filter → free-text search → ordering.
///
/// Category scope follows Blueprint 04 §2.1: `songs` holds vocal releases,
/// `beats` holds standalone instrumentals, `trash` holds soft-deleted records.
/// Playlist, collection and license-certificate aggregates are modelled in
/// later phases, so those categories resolve to their universal empty state.
List<LibraryTrack> filterLibraryTracks({
  required List<LibraryTrack> tracks,
  required LibraryCategory category,
  String searchQuery = '',
  LibrarySyncFilter syncFilter = LibrarySyncFilter.any,
  LibrarySortOrder sortOrder = LibrarySortOrder.newestFirst,
}) {
  final query = searchQuery.trim().toLowerCase();

  final scoped = tracks
      .where((track) => _matchesCategory(track, category))
      .where((track) => _matchesSyncFilter(track, syncFilter))
      .where((track) => _matchesQuery(track, query))
      .toList();

  scoped.sort(
    (a, b) => switch (sortOrder) {
      LibrarySortOrder.newestFirst => b.createdAt.compareTo(a.createdAt),
      LibrarySortOrder.oldestFirst => a.createdAt.compareTo(b.createdAt),
      LibrarySortOrder.titleAscending => a.title.toLowerCase().compareTo(
        b.title.toLowerCase(),
      ),
      LibrarySortOrder.mostPlayed => b.playCount.compareTo(a.playCount),
    },
  );

  return List.unmodifiable(scoped);
}

bool _matchesCategory(LibraryTrack track, LibraryCategory category) {
  return switch (category) {
    LibraryCategory.songs => !track.isDeleted && !track.isInstrumental,
    LibraryCategory.beats => !track.isDeleted && track.isInstrumental,
    LibraryCategory.trash => track.isDeleted,
    LibraryCategory.licensing =>
      !track.isDeleted &&
          (track.id.startsWith('market_') ||
              (track.licenseType.trim().isNotEmpty &&
                  track.licenseType != 'Commercial')),
    LibraryCategory.playlists || LibraryCategory.collections => false,
  };
}

bool _matchesSyncFilter(LibraryTrack track, LibrarySyncFilter filter) {
  return switch (filter) {
    LibrarySyncFilter.any => true,
    LibrarySyncFilter.offlineOnly => track.isOfflineAvailable,
    LibrarySyncFilter.cloudOnly => !track.isOfflineAvailable,
  };
}

bool _matchesQuery(LibraryTrack track, String query) {
  if (query.isEmpty) return true;
  return track.title.toLowerCase().contains(query) ||
      track.creatorName.toLowerCase().contains(query) ||
      track.genre.toLowerCase().contains(query) ||
      track.language.toLowerCase().contains(query);
}

/// Seeded production vault records (Blueprint 04 §3.2 reference assets).
List<LibraryTrack> _seedTracks() {
  final now = DateTime.now();
  const origin = AppConstants.defaultOrigin;
  const vaultAudio = AppConstants.vaultAudioDirectory;

  return [
    LibraryTrack(
      id: 'lib_track_001',
      title: 'Grateful in the Light',
      creatorName: 'cern',
      genre: 'Amapiano',
      language: 'English',
      durationSeconds: 216,
      remoteAudioUrl: '$origin/audio/grateful-in-the-light.mp3',
      localAudioFilePath: '$vaultAudio/grateful-in-the-light.mp3',
      createdAt: now.subtract(const Duration(hours: 2)),
      syncStatus: TrackSyncStatus.cachedLocally,
      playCount: 0,
      lyrics:
          '[Intro]\nYebo! Woza!\n\n[Verse 1]\nWalking through the morning mist where memories stay\nListening to the elders teaching us the ancient way\n\n[Chorus]\nThis is our song, this is our sacred beat\nVhunambi rising strong on every township street\n\n[Outro]\nShisa!',
    ),
    LibraryTrack(
      id: 'lib_track_002',
      title: 'Ndo Mufuna Matibe',
      creatorName: 'Fifi',
      genre: 'Amapiano',
      language: 'Tshivenḓa',
      durationSeconds: 198,
      remoteAudioUrl: '$origin/audio/ndo-mufuna-matibe.mp3',
      createdAt: now.subtract(const Duration(hours: 26)),
    ),
    LibraryTrack(
      id: 'lib_track_003',
      title: 'Township Log Drum Heat',
      creatorName: 'Sipho',
      genre: 'Amapiano',
      language: 'Instrumental',
      durationSeconds: 180,
      remoteAudioUrl: '$origin/audio/township-log-drum-heat.mp3',
      createdAt: now.subtract(const Duration(days: 4)),
      isInstrumental: true,
    ),
    LibraryTrack(
      id: 'lib_track_004',
      title: 'Durban Midnight Bass',
      creatorName: 'DJ Vibe',
      genre: 'Gqom',
      language: 'Instrumental',
      durationSeconds: 150,
      remoteAudioUrl: '$origin/audio/durban-midnight-bass.mp3',
      createdAt: now.subtract(const Duration(days: 9)),
      syncStatus: TrackSyncStatus.synced,
      isInstrumental: true,
    ),
  ];
}

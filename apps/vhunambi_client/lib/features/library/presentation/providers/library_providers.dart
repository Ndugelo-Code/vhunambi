import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../domain/models/library_models.dart';

/// Active vault category tab (REQ-LIB-02, Blueprint 04 §2).
final libraryCategoryProvider =
    StateProvider<LibraryCategory>((ref) => LibraryCategory.songs);

/// Real-time vault search text (REQ-LIB-04).
final librarySearchQueryProvider = StateProvider<String>((ref) => '');

/// Dense list vs. square grid rendering mode (REQ-LIB-04).
final libraryViewModeProvider =
    StateProvider<LibraryViewMode>((ref) => LibraryViewMode.list);

/// Vault ordering, driven by the header overflow control (`⋮`).
final librarySortProvider =
    StateProvider<LibrarySortOrder>((ref) => LibrarySortOrder.newestFirst);

/// Local vs. cloud presence filter driven by the search strip filter control.
final librarySyncFilterProvider =
    StateProvider<LibrarySyncFilter>((ref) => LibrarySyncFilter.any);

/// The user vault asset collection, soft-deleted records included (REQ-LIB-08).
final libraryTracksProvider =
    StateNotifierProvider<LibraryTracksNotifier, List<LibraryTrack>>((ref) {
  return LibraryTracksNotifier();
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
final libraryCategoryCountsProvider =
    Provider<Map<LibraryCategory, int>>((ref) {
  final tracks = ref.watch(libraryTracksProvider);
  return {
    for (final category in LibraryCategory.values)
      category: filterLibraryTracks(tracks: tracks, category: category).length,
  };
});

/// Every hearted vault record, newest first (favourites rail / quick filter).
final favoriteTracksProvider = Provider<List<LibraryTrack>>((ref) {
  final favorites = ref
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
  RecentlyPlayedNotifier() : super(const <String>[]);

  /// Records a play of [trackId]: de-dupe, prepend, cap the history length.
  void register(String trackId) {
    if (trackId.isEmpty) return;
    final next = <String>[
      trackId,
      ...state.where((id) => id != trackId),
    ];
    state = next.length > _recentlyPlayedLimit
        ? next.sublist(0, _recentlyPlayedLimit)
        : next;
  }

  /// Clears the entire recently-played history.
  void clear() => state = const <String>[];
}

class LibraryTracksNotifier extends StateNotifier<List<LibraryTrack>> {
  LibraryTracksNotifier() : super(_seedTracks());

  /// Inserts a freshly generated asset at the top of the vault.
  void addTrack(LibraryTrack track) {
    state = [track, ...state];
  }

  /// Soft-deletes the record: `isDeleted: true` + purge timestamp (REQ-LIB-07).
  void deleteTrack(String id) {
    state = [
      for (final track in state)
        if (track.id == id)
          track.copyWith(isDeleted: true, deletedAt: DateTime.now())
        else
          track,
    ];
  }

  /// Restores a soft-deleted record back into its original category.
  void restoreTrack(String id) {
    state = [
      for (final track in state)
        if (track.id == id)
          track.copyWith(isDeleted: false, clearDeletedAt: true)
        else
          track,
    ];
  }

  /// Permanently wipes the record (30-day Trash grace period is enforced by the cloud).
  void purgeTrackPermanently(String id) {
    state = state.where((track) => track.id != id).toList(growable: false);
  }

  /// Bumps the lifetime play count by one (jukebox stat badge / Most Played sort).
  void incrementPlayCount(String id) {
    state = [
      for (final track in state)
        if (track.id == id)
          track.copyWith(playCount: track.playCount + 1)
        else
          track,
    ];
  }

  /// Flips the quick heart / favourite flag for a vault record.
  void toggleFavorite(String id) {
    state = [
      for (final track in state)
        if (track.id == id)
          track.copyWith(isFavorite: !track.isFavorite)
        else
          track,
    ];
  }

  /// Updates the offline cache integrity state of a record.
  void setSyncStatus(String id, TrackSyncStatus status) {
    state = [
      for (final track in state)
        if (track.id == id) track.copyWith(syncStatus: status) else track,
    ];
  }

  /// Marks the record as cached locally once the vault audio file is written.
  void setTrackOfflinePath(String id, String path) {
    state = [
      for (final track in state)
        if (track.id == id)
          track.copyWith(
            localAudioFilePath: path,
            syncStatus: TrackSyncStatus.cachedLocally,
          )
        else
          track,
    ];
  }

  /// Evicts the local audio copy and returns the record to cloud-only streaming.
  void clearTrackOfflinePath(String id) {
    state = [
      for (final track in state)
        if (track.id == id)
          track.copyWith(
            clearLocalAudioFilePath: true,
            syncStatus: TrackSyncStatus.cloudOnly,
          )
        else
          track,
    ];
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
      LibrarySortOrder.titleAscending =>
        a.title.toLowerCase().compareTo(b.title.toLowerCase()),
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
    LibraryCategory.playlists ||
    LibraryCategory.collections ||
    LibraryCategory.licensing =>
      false,
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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/library/domain/models/library_models.dart';
import 'package:vhunambi_client/features/library/presentation/providers/library_providers.dart';

void main() {
  group('LibraryTrack domain model', () {
    test('formats duration as mm:ss with padded seconds', () {
      expect(_track(durationSeconds: 216).formattedDuration, '3:36');
      expect(_track(durationSeconds: 150).formattedDuration, '2:30');
      expect(_track(durationSeconds: 65).formattedDuration, '1:05');
    });

    test('derives offline availability from the local audio path', () {
      expect(_track().isOfflineAvailable, isFalse);
      expect(
        _track(localAudioFilePath: '/vault/a.mp3').isOfflineAvailable,
        isTrue,
      );
    });

    test('derives relative creation labels', () {
      final now = DateTime.now();
      expect(
        _track(createdAt: now.subtract(const Duration(hours: 2))).createdAgoLabel,
        'Created 2 hours ago',
      );
      expect(
        _track(createdAt: now.subtract(const Duration(minutes: 5)))
            .createdAgoLabel,
        'Created 5 minutes ago',
      );
      expect(
        _track(createdAt: now.subtract(const Duration(days: 1))).createdAgoLabel,
        'Created yesterday',
      );
      expect(
        _track(createdAt: now.subtract(const Duration(days: 9))).createdAgoLabel,
        'Created 9 days ago',
      );
    });

    test('builds the public share link and license certificate id', () {
      final track = _track(id: 'lib_track_001');
      expect(
        track.publicShareUrl,
        'https://vhunambi.com/track/lib_track_001',
      );
      expect(track.licenseCertificateId, 'VHB-COMMERCIAL-LIB_TRACK_001');
    });

    test('copyWith updates fields and honours the explicit clear flags', () {
      final track = _track(localAudioFilePath: '/vault/a.mp3');
      final updated = track.copyWith(
        title: 'Renamed',
        syncStatus: TrackSyncStatus.downloading,
      );
      expect(updated.title, 'Renamed');
      expect(updated.syncStatus, TrackSyncStatus.downloading);
      expect(updated.localAudioFilePath, '/vault/a.mp3');

      final cleared = updated.copyWith(clearLocalAudioFilePath: true);
      expect(cleared.localAudioFilePath, isNull);
      expect(cleared.isOfflineAvailable, isFalse);

      final trashed = track.copyWith(
        isDeleted: true,
        deletedAt: DateTime(2026, 2, 1),
      );
      expect(trashed.isDeleted, isTrue);
      expect(trashed.deletedAt, DateTime(2026, 2, 1));
      expect(trashed.copyWith(isDeleted: false, clearDeletedAt: true).deletedAt,
          isNull);
    });

    test('toTrack bridges into the shared persistent player model', () {
      final track = _track(
        id: 'lib_test_009',
        title: 'Bridge Test',
        durationSeconds: 198,
        language: 'Tshivenḓa',
        localAudioFilePath: '/vault/local.mp3',
      );
      final playerTrack = track.toTrack();

      expect(playerTrack.id, 'lib_test_009');
      expect(playerTrack.title, 'Bridge Test');
      expect(playerTrack.duration, const Duration(seconds: 198));
      expect(playerTrack.language, 'Tshivenḓa');
      // The player prefers the cached local copy when one exists.
      expect(playerTrack.audioUrl, '/vault/local.mp3');
      expect(track.copyWith(clearLocalAudioFilePath: true).toTrack().audioUrl,
          track.remoteAudioUrl);
    });

    test('equality considers every persisted field', () {
      final base = _track();
      expect(base, _track());
      expect(base.hashCode, _track().hashCode);
      expect(base == base.copyWith(title: 'Other'), isFalse);
      expect(base == base.copyWith(isInstrumental: true), isFalse);
      expect(base == base.copyWith(isDeleted: true), isFalse);
      expect(base == base.copyWith(syncStatus: TrackSyncStatus.error), isFalse);
    });
  });

  group('LibraryTracksNotifier', () {
    late LibraryTracksNotifier notifier;

    setUp(() => notifier = LibraryTracksNotifier());

    test('seeds the production demo vault', () {
      expect(notifier.state.length, 4);
      expect(
        notifier.state.map((track) => track.title),
        containsAll([
          'Grateful in the Light',
          'Ndo Mufuna Matibe',
          'Township Log Drum Heat',
          'Durban Midnight Bass',
        ]),
      );

      final fifi = notifier.state
          .firstWhere((track) => track.creatorName == 'Fifi');
      expect(fifi.title, 'Ndo Mufuna Matibe');
      expect(fifi.genre, 'Amapiano');
      expect(fifi.language, 'Tshivenḓa');
      expect(fifi.durationSeconds, 198);
      expect(fifi.formattedDuration, '3:18');
      expect(fifi.licenseType, 'Commercial');
    });

    test('seeds one cached asset and two instrumental beats', () {
      expect(
        notifier.state.where((track) => track.isOfflineAvailable).length,
        1,
      );
      expect(notifier.state.where((track) => track.isInstrumental).length, 2);
      expect(notifier.state.first.syncStatus, TrackSyncStatus.cachedLocally);
    });

    test('addTrack prepends a newly generated asset', () {
      final fresh = _track(id: 'lib_track_999', title: 'Fresh Drop');
      notifier.addTrack(fresh);
      expect(notifier.state.length, 5);
      expect(notifier.state.first, fresh);
    });

    test('deleteTrack soft-deletes with a purge timestamp', () {
      notifier.deleteTrack('lib_track_001');
      final trashed = notifier.state.firstWhere((t) => t.id == 'lib_track_001');
      expect(trashed.isDeleted, isTrue);
      expect(trashed.deletedAt, isNotNull);
      // The record is retained for the 30-day grace period.
      expect(notifier.state.length, 4);
    });

    test('restoreTrack clears the deletion markers', () {
      notifier.deleteTrack('lib_track_002');
      notifier.restoreTrack('lib_track_002');
      final restored =
          notifier.state.firstWhere((t) => t.id == 'lib_track_002');
      expect(restored.isDeleted, isFalse);
      expect(restored.deletedAt, isNull);
    });

    test('purgeTrackPermanently removes the record', () {
      notifier.purgeTrackPermanently('lib_track_003');
      expect(notifier.state.length, 3);
      expect(notifier.state.any((t) => t.id == 'lib_track_003'), isFalse);
    });

    test('setTrackOfflinePath caches the asset locally', () {
      notifier.setTrackOfflinePath(
        'lib_track_002',
        '/vault/ndo-mufuna-matibe.mp3',
      );
      final cached = notifier.state.firstWhere((t) => t.id == 'lib_track_002');
      expect(cached.isOfflineAvailable, isTrue);
      expect(cached.syncStatus, TrackSyncStatus.cachedLocally);
    });

    test('setSyncStatus updates the cache integrity state', () {
      notifier.setSyncStatus('lib_track_001', TrackSyncStatus.downloading);
      expect(notifier.state.first.syncStatus, TrackSyncStatus.downloading);
      notifier.setSyncStatus('lib_track_001', TrackSyncStatus.error);
      expect(notifier.state.first.syncStatus, TrackSyncStatus.error);
    });

    test('clearTrackOfflinePath evicts the local copy', () {
      notifier.clearTrackOfflinePath('lib_track_001');
      final evicted = notifier.state.first;
      expect(evicted.isOfflineAvailable, isFalse);
      expect(evicted.syncStatus, TrackSyncStatus.cloudOnly);
    });
  });

  group('filterLibraryTracks', () {
    test('songs expose vocal releases only', () {
      final songs = filterLibraryTracks(
        tracks: LibraryTracksNotifier().state,
        category: LibraryCategory.songs,
      );
      expect(
        songs.map((track) => track.title),
        ['Grateful in the Light', 'Ndo Mufuna Matibe'],
      );
    });

    test('beats expose instrumentals only', () {
      final beats = filterLibraryTracks(
        tracks: LibraryTracksNotifier().state,
        category: LibraryCategory.beats,
      );
      expect(beats.length, 2);
      expect(beats.every((track) => track.isInstrumental), isTrue);
      expect(beats.first.title, 'Township Log Drum Heat');
    });

    test('trash exposes soft-deleted records only', () {
      final notifier = LibraryTracksNotifier();
      notifier.deleteTrack('lib_track_004');
      final trash = filterLibraryTracks(
        tracks: notifier.state,
        category: LibraryCategory.trash,
      );
      expect(trash.length, 1);
      expect(trash.single.title, 'Durban Midnight Bass');
    });

    test('playlists, collections and licensing resolve to empty projections',
        () {
      for (final category in [
        LibraryCategory.playlists,
        LibraryCategory.collections,
        LibraryCategory.licensing,
      ]) {
        expect(
          filterLibraryTracks(
            tracks: LibraryTracksNotifier().state,
            category: category,
          ),
          isEmpty,
        );
      }
    });

    test('search matches title, creator, genre and language', () {
      final tracks = LibraryTracksNotifier().state;
      expect(
        filterLibraryTracks(
          tracks: tracks,
          category: LibraryCategory.songs,
          searchQuery: 'MATIBE',
        ).length,
        1,
      );
      expect(
        filterLibraryTracks(
          tracks: tracks,
          category: LibraryCategory.songs,
          searchQuery: 'fifi',
        ).length,
        1,
      );
      expect(
        filterLibraryTracks(
          tracks: tracks,
          category: LibraryCategory.beats,
          searchQuery: 'gqom',
        ).length,
        1,
      );
      expect(
        filterLibraryTracks(
          tracks: tracks,
          category: LibraryCategory.songs,
          searchQuery: 'english',
        ).length,
        1,
      );
      expect(
        filterLibraryTracks(
          tracks: tracks,
          category: LibraryCategory.songs,
          searchQuery: 'zzz',
        ),
        isEmpty,
      );
    });

    test('sync filter isolates offline and cloud assets', () {
      final tracks = LibraryTracksNotifier().state;
      expect(
        filterLibraryTracks(
          tracks: tracks,
          category: LibraryCategory.songs,
          syncFilter: LibrarySyncFilter.offlineOnly,
        ).length,
        1,
      );
      expect(
        filterLibraryTracks(
          tracks: tracks,
          category: LibraryCategory.songs,
          syncFilter: LibrarySyncFilter.cloudOnly,
        ).length,
        1,
      );
      expect(
        filterLibraryTracks(tracks: tracks, category: LibraryCategory.songs)
            .length,
        2,
      );
    });

    test('ordering options re-sort the projection', () {
      final tracks = LibraryTracksNotifier().state;
      expect(
        filterLibraryTracks(
          tracks: tracks,
          category: LibraryCategory.beats,
          sortOrder: LibrarySortOrder.oldestFirst,
        ).first.title,
        'Durban Midnight Bass',
      );
      expect(
        filterLibraryTracks(
          tracks: tracks,
          category: LibraryCategory.beats,
          sortOrder: LibrarySortOrder.titleAscending,
        ).first.title,
        'Durban Midnight Bass',
      );
      expect(
        filterLibraryTracks(tracks: tracks, category: LibraryCategory.beats)
            .first
            .title,
        'Township Log Drum Heat',
      );
    });
  });

  group('Library provider tree', () {
    test('defaults match the blueprint state contract', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(libraryCategoryProvider), LibraryCategory.songs);
      expect(container.read(librarySearchQueryProvider), '');
      expect(container.read(libraryViewModeProvider), LibraryViewMode.list);
      expect(container.read(librarySortProvider), LibrarySortOrder.newestFirst);
      expect(container.read(librarySyncFilterProvider), LibrarySyncFilter.any);
      expect(container.read(filteredLibraryTracksProvider).length, 2);
    });

    test('category, search and view-mode state recompute the projection', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(libraryCategoryProvider.notifier).state =
          LibraryCategory.beats;
      expect(container.read(filteredLibraryTracksProvider).length, 2);

      container.read(librarySearchQueryProvider.notifier).state = 'log drum';
      expect(
        container.read(filteredLibraryTracksProvider).single.title,
        'Township Log Drum Heat',
      );

      container.read(libraryViewModeProvider.notifier).state =
          LibraryViewMode.grid;
      expect(container.read(libraryViewModeProvider), LibraryViewMode.grid);

      container.read(librarySyncFilterProvider.notifier).state =
          LibrarySyncFilter.cloudOnly;
      expect(
        container.read(filteredLibraryTracksProvider).single.title,
        'Township Log Drum Heat',
      );
    });

    test('category counts follow soft deletion', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      var counts = container.read(libraryCategoryCountsProvider);
      expect(counts[LibraryCategory.songs], 2);
      expect(counts[LibraryCategory.beats], 2);
      expect(counts[LibraryCategory.trash], 0);

      final victim = container.read(filteredLibraryTracksProvider).first;
      container.read(libraryTracksProvider.notifier).deleteTrack(victim.id);

      counts = container.read(libraryCategoryCountsProvider);
      expect(counts[LibraryCategory.songs], 1);
      expect(counts[LibraryCategory.trash], 1);
    });
  });
}

LibraryTrack _track({
  String id = 'lib_test_001',
  String title = 'Test Anthem',
  String creatorName = 'Test Creator',
  String genre = 'Amapiano',
  String language = 'English',
  int durationSeconds = 216,
  String? localAudioFilePath,
  DateTime? createdAt,
  String licenseType = 'Commercial',
  bool isInstrumental = false,
}) {
  return LibraryTrack(
    id: id,
    title: title,
    creatorName: creatorName,
    genre: genre,
    language: language,
    durationSeconds: durationSeconds,
    remoteAudioUrl: 'https://vhunambi.com/audio/$id.mp3',
    localAudioFilePath: localAudioFilePath,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
    licenseType: licenseType,
    isInstrumental: isInstrumental,
  );
}

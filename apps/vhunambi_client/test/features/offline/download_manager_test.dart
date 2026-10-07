import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vhunambi_client/features/library/domain/models/library_models.dart';
import 'package:vhunambi_client/features/library/presentation/providers/library_providers.dart';
import 'package:vhunambi_client/features/offline/data/services/audio_download_service.dart';
import 'package:vhunambi_client/features/offline/data/services/offline_storage_service.dart';
import 'package:vhunambi_client/features/offline/domain/models/offline_models.dart';
import 'package:vhunambi_client/features/offline/presentation/providers/offline_providers.dart';

/// T8.6 — Offline download manager suite.
///
/// Drives `DownloadManagerNotifier` through its full FSM
/// (`queued → downloading → completed | failed | idle`), verifying queue
/// idempotency, progress emission, vault synchronisation, eviction and the
/// storage quota projection.
///
/// Every container override points the storage service at a throw-away temp
/// directory (with Hive re-homed into the same sandbox), so simulated transfers
/// never write into the repository checkout.
late Directory _vaultDir;
late OfflineStorageService _storage;

void main() {
  setUp(() {
    _vaultDir = Directory.systemTemp.createTempSync('vhunambi_download_test_');
    // Re-home Hive so the box backend opens cleanly: `HiveImpl._openBox` reports
    // a missing-home-path error through an unlistened completer, which
    // flutter_test surfaces as an uncaught error.
    Hive.init(_vaultDir.path);
    _storage = OfflineStorageService(customVaultDirectory: _vaultDir.path);
    addTearDown(_closeHiveAndDisposeVaultDir);
  });

  group('DownloadManagerNotifier', () {
    test('downloadTrack drives queued → downloading → completed', () async {
      final container = _container();
      final notifier = container.read(downloadManagerProvider.notifier);
      final track = _vaultTrack(container, id: 'lib_off_100');
      final statuses = _watchStatuses(container, track.id);

      await notifier.downloadTrack(track);

      expect(
        statuses,
        containsAllInOrder(<DownloadStatus>[
          DownloadStatus.queued,
          DownloadStatus.downloading,
          DownloadStatus.completed,
        ]),
      );

      final task = container.read(downloadManagerProvider)[track.id]!;
      expect(task.status, DownloadStatus.completed);
      expect(task.isCompleted, isTrue);
      expect(task.isActive, isFalse);
      expect(task.progress, 1.0);
      expect(task.receivedBytes, 8500000);
      expect(task.totalBytes, 8500000);
      expect(task.completedAt, isNotNull);
      expect(task.errorMessage, isNull);
      expect(task.localAudioFilePath, '${_vaultDir.path}/${track.id}.mp3');
    });

    test('downloadTrack writes the vault record and syncs the library',
        () async {
      final container = _container();
      final notifier = container.read(downloadManagerProvider.notifier);
      final track = _vaultTrack(container, id: 'lib_off_101');
      final statsBefore = container.read(cacheStorageStatsProvider);

      await notifier.downloadTrack(track);

      final synced = _vaultRecord(container.read(libraryTracksProvider), track.id);
      expect(synced.syncStatus, TrackSyncStatus.cachedLocally);
      expect(synced.isOfflineAvailable, isTrue);
      expect(synced.localAudioFilePath, '${_vaultDir.path}/${track.id}.mp3');

      final record = await _storage.getTrackMetadata(track.id);
      expect(record, isNotNull);
      expect(record!['syncStatus'], TrackSyncStatus.cachedLocally.name);
      expect(record['fileSizeBytes'], 8500000);
      expect(record['title'], track.title);
      expect(File(record['localAudioFilePath'] as String).existsSync(), isTrue);

      final statsAfter = container.read(cacheStorageStatsProvider);
      expect(statsAfter.cachedTrackCount, statsBefore.cachedTrackCount + 1);
      expect(statsAfter.totalBytesUsed, statsBefore.totalBytesUsed + 8500000);
      expect(
        statsAfter.quotaUsagePercentage,
        greaterThan(statsBefore.quotaUsagePercentage),
      );
    });

    test('downloadTrack emits monotonic progress samples', () async {
      final container = _container();
      final notifier = container.read(downloadManagerProvider.notifier);
      final track = _vaultTrack(container, id: 'lib_off_103');

      final samples = <double>[];
      final subscription = container.listen<Map<String, DownloadTask>>(
        downloadManagerProvider,
        (previous, next) {
          final task = next[track.id];
          // Skip the transition frame that announces `downloading` with a still
          // zeroed progress meter.
          if (task != null &&
              task.status == DownloadStatus.downloading &&
              task.progress > 0) {
            samples.add(task.progress);
          }
        },
      );
      addTearDown(subscription.close);

      await notifier.downloadTrack(track);

      expect(samples.length, greaterThanOrEqualTo(3));
      expect(samples.first, 0.25);
      expect(samples.last, 1.0);
      for (var index = 1; index < samples.length; index++) {
        expect(samples[index], greaterThanOrEqualTo(samples[index - 1]));
      }
    });

    test('duplicate downloadTrack calls are idempotent (single queue entry)',
        () async {
      final container = _container();
      final notifier = container.read(downloadManagerProvider.notifier);
      final track = _vaultTrack(container, id: 'lib_off_102');
      final statuses = _watchStatuses(container, track.id);

      final firstAttempt = notifier.downloadTrack(track);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(
        container.read(downloadManagerProvider)[track.id]!.isActive,
        isTrue,
      );

      // The guard must swallow the second request while the first is in flight.
      await notifier.downloadTrack(track);
      await firstAttempt;

      expect(
        statuses.where((status) => status == DownloadStatus.queued).length,
        1,
      );
      expect(
        container.read(downloadManagerProvider)[track.id]!.status,
        DownloadStatus.completed,
      );
      expect(
        container
            .read(libraryTracksProvider)
            .where((candidate) =>
                candidate.id == track.id &&
                candidate.syncStatus == TrackSyncStatus.cachedLocally)
            .length,
        1,
      );
    });

    test('cancelDownload delegates to the service and resets task + vault state',
        () async {
      final hangService = HangingDownloadService();
      final container = _container(downloadService: hangService);
      final notifier = container.read(downloadManagerProvider.notifier);
      final track = _vaultTrack(container, id: 'lib_off_104');

      unawaited(notifier.downloadTrack(track));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final inFlight = container.read(downloadManagerProvider)[track.id]!;
      expect(inFlight.status, DownloadStatus.downloading);
      expect(inFlight.progress, closeTo(2000000 / 8500000, 0.0001));

      await notifier.cancelDownload(track.id);

      expect(hangService.cancelledTrackIds, <String>[track.id]);

      final cancelled = container.read(downloadManagerProvider)[track.id]!;
      expect(cancelled.status, DownloadStatus.idle);
      expect(cancelled.isActive, isFalse);
      expect(cancelled.progress, 0.0);
      expect(cancelled.errorMessage, 'Download cancelled');

      final synced = _vaultRecord(container.read(libraryTracksProvider), track.id);
      expect(synced.syncStatus, TrackSyncStatus.cloudOnly);
      expect(synced.isOfflineAvailable, isFalse);
      expect(await _storage.getTrackMetadata(track.id), isNull);
    });

    test('a failed transfer marks the task failed and the vault track as error',
        () async {
      final scripted =
          ScriptedDownloadService(failSequence: const <bool>[true]);
      final container = _container(downloadService: scripted);
      final track = _vaultTrack(container, id: 'lib_off_105');
      final statuses = _watchStatuses(container, track.id);

      await container
          .read(downloadManagerProvider.notifier)
          .downloadTrack(track);

      expect(scripted.calls, 1);
      expect(statuses.last, DownloadStatus.failed);

      final task = container.read(downloadManagerProvider)[track.id]!;
      expect(task.status, DownloadStatus.failed);
      expect(task.isFailed, isTrue);
      expect(task.isActive, isFalse);
      expect(task.errorMessage, contains('Network unreachable'));

      final synced = _vaultRecord(container.read(libraryTracksProvider), track.id);
      expect(synced.syncStatus, TrackSyncStatus.error);
      expect(await _storage.getTrackMetadata(track.id), isNull);
    });

    test('retryDownload re-drives a failed transfer through to completion',
        () async {
      final scripted = ScriptedDownloadService(
        failSequence: const <bool>[true, false],
      );
      final container = _container(downloadService: scripted);
      final notifier = container.read(downloadManagerProvider.notifier);
      final track = _vaultTrack(container, id: 'lib_off_106');

      await notifier.downloadTrack(track);
      expect(
        container.read(downloadManagerProvider)[track.id]!.isFailed,
        isTrue,
      );

      await notifier.retryDownload(track);

      expect(scripted.calls, 2);
      final task = container.read(downloadManagerProvider)[track.id]!;
      expect(task.status, DownloadStatus.completed);
      expect(task.errorMessage, isNull);
      expect(task.progress, 1.0);
      expect(
        _vaultRecord(container.read(libraryTracksProvider), track.id).syncStatus,
        TrackSyncStatus.cachedLocally,
      );
      expect(await _storage.getTrackMetadata(track.id), isNotNull);
    });

    test('activeDownloadsCount tracks the in-flight transfer count', () async {
      final hangService = HangingDownloadService();
      final container = _container(downloadService: hangService);
      final notifier = container.read(downloadManagerProvider.notifier);
      final track = _vaultTrack(container, id: 'lib_off_109');

      expect(notifier.activeDownloadsCount, 0);

      unawaited(notifier.downloadTrack(track));
      await Future<void>.delayed(Duration.zero);
      expect(notifier.activeDownloadsCount, 1);

      await notifier.cancelDownload(track.id);
      expect(notifier.activeDownloadsCount, 0);
    });

    test('removeOfflineTrack evicts the task, the vault record and the file',
        () async {
      final container = _container();
      final notifier = container.read(downloadManagerProvider.notifier);
      final track = _vaultTrack(container, id: 'lib_off_107');

      await notifier.downloadTrack(track);
      final path = container
          .read(downloadManagerProvider)[track.id]!
          .localAudioFilePath!;
      expect(File(path).existsSync(), isTrue);
      expect(await _storage.getTrackMetadata(track.id), isNotNull);

      await notifier.removeOfflineTrack(track.id);

      expect(
        container.read(downloadManagerProvider).containsKey(track.id),
        isFalse,
      );
      expect(File(path).existsSync(), isFalse);
      expect(await _storage.getTrackMetadata(track.id), isNull);

      final synced = _vaultRecord(container.read(libraryTracksProvider), track.id);
      expect(synced.syncStatus, TrackSyncStatus.cloudOnly);
      expect(synced.localAudioFilePath, isNull);
      expect(synced.isOfflineAvailable, isFalse);
    });

    test('clearAllOfflineTracks purges every locally cached vault track',
        () async {
      final container = _container();
      final notifier = container.read(downloadManagerProvider.notifier);
      final track = _vaultTrack(container, id: 'lib_off_108');

      await notifier.downloadTrack(track);
      final path = container
          .read(downloadManagerProvider)[track.id]!
          .localAudioFilePath!;

      // The seeded vault already ships a cached master alongside the download.
      expect(
        container
            .read(libraryTracksProvider)
            .where((candidate) =>
                candidate.syncStatus == TrackSyncStatus.cachedLocally)
            .length,
        greaterThanOrEqualTo(2),
      );

      await notifier.clearAllOfflineTracks();

      expect(container.read(downloadManagerProvider), isEmpty);
      expect(
        container
            .read(libraryTracksProvider)
            .where((candidate) =>
                candidate.syncStatus == TrackSyncStatus.cachedLocally),
        isEmpty,
      );
      expect(container.read(cacheStorageStatsProvider).cachedTrackCount, 0);
      expect(container.read(cacheStorageStatsProvider).totalBytesUsed, 0);
      expect(await _storage.getAllCachedMetadata(), isEmpty);
      expect(File(path).existsSync(), isFalse);
    });

    test('downloadTrack honours the lossless WAV quality destination', () async {
      final container = _container();
      final notifier = container.read(downloadManagerProvider.notifier);
      final track = _vaultTrack(container, id: 'lib_off_110');

      await notifier.downloadTrack(
        track,
        quality: AudioDownloadQuality.wavLossless,
      );

      final task = container.read(downloadManagerProvider)[track.id]!;
      expect(task.status, DownloadStatus.completed);
      expect(task.localAudioFilePath, endsWith('${track.id}.wav'));
      expect(File(task.localAudioFilePath!).existsSync(), isTrue);
    });

  });

  group('DownloadTask model', () {
    test('formattedProgressPercentage truncates and clamps to a whole percent',
        () {
      expect(_task(progress: 0).formattedProgressPercentage, '0%');
      expect(_task(progress: 0.75).formattedProgressPercentage, '75%');
      expect(_task(progress: 0.336).formattedProgressPercentage, '33%');
      expect(_task(progress: 1).formattedProgressPercentage, '100%');
      expect(_task(progress: 1.4).formattedProgressPercentage, '100%');
    });

    test('isActive is true only while queued or downloading', () {
      const active = <DownloadStatus>[
        DownloadStatus.queued,
        DownloadStatus.downloading,
      ];
      const resting = <DownloadStatus>[
        DownloadStatus.idle,
        DownloadStatus.paused,
        DownloadStatus.completed,
        DownloadStatus.failed,
      ];

      for (final status in active) {
        expect(_task(status: status).isActive, isTrue);
      }
      for (final status in resting) {
        expect(_task(status: status).isActive, isFalse);
      }

      expect(_task(status: DownloadStatus.completed).isCompleted, isTrue);
      expect(_task(status: DownloadStatus.failed).isFailed, isTrue);
      expect(_task(status: DownloadStatus.paused).isPaused, isTrue);
      expect(_task(status: DownloadStatus.queued).isPaused, isFalse);
    });

    test('copyWith preserves untouched fields and clears the error on demand',
        () {
      final original = _task(
        status: DownloadStatus.failed,
        progress: 0.4,
        receivedBytes: 100,
        totalBytes: 250,
        errorMessage: 'boom',
      );

      final resumed = original.copyWith(status: DownloadStatus.downloading);
      expect(resumed.status, DownloadStatus.downloading);
      expect(resumed.progress, 0.4);
      expect(resumed.receivedBytes, 100);
      expect(resumed.totalBytes, 250);
      expect(resumed.errorMessage, 'boom');
      expect(resumed.trackId, original.trackId);
      expect(resumed.title, original.title);
      expect(resumed.startedAt, original.startedAt);

      final cleared = resumed.copyWith(clearError: true);
      expect(cleared.errorMessage, isNull);
      expect(cleared.status, DownloadStatus.downloading);

      final completed = original.copyWith(
        status: DownloadStatus.completed,
        progress: 1.0,
        completedAt: DateTime(2026, 9, 2),
      );
      expect(completed.isCompleted, isTrue);
      expect(completed.completedAt, DateTime(2026, 9, 2));

      expect(
        _task(progress: 0.5).copyWith(status: DownloadStatus.downloading),
        _task(progress: 0.5, status: DownloadStatus.downloading),
      );
    });

    test('formattedBytesProgress renders received and total byte labels', () {
      expect(_task(receivedBytes: 2048).formattedBytesProgress, '2.0 KB');
      expect(
        _task(receivedBytes: 8388608, totalBytes: 8388608)
            .formattedBytesProgress,
        '8.0 MB / 8.0 MB',
      );
      expect(
        _task(receivedBytes: 512, totalBytes: 1024).formattedBytesProgress,
        '512 B / 1.0 KB',
      );
    });
  });

  group('cacheStorageStatsProvider', () {
    test('projects the locally cached vault onto the quota ceiling', () {
      final container = _container();
      final cachedCount = container
          .read(libraryTracksProvider)
          .where((track) => track.syncStatus == TrackSyncStatus.cachedLocally)
          .length;
      expect(cachedCount, greaterThan(0));

      final stats = container.read(cacheStorageStatsProvider);
      expect(stats.cachedTrackCount, cachedCount);
      expect(stats.totalBytesUsed, cachedCount * 8500000);
      expect(stats.storageLimitBytes, 5 * 1024 * 1024 * 1024);
      expect(stats.formattedStorageLimit, '5.00 GB');
      expect(
        stats.quotaUsagePercentage,
        closeTo(cachedCount * 8500000 / (5 * 1024 * 1024 * 1024), 1e-12),
      );
      expect(
        stats.remainingBytes,
        stats.storageLimitBytes - stats.totalBytesUsed,
      );
      expect(stats.formattedBytesUsed, isNotEmpty);
    });

    test('honours the storage ceiling set through the preferences', () {
      final container = _container();
      container
          .read(offlinePreferencesProvider.notifier)
          .setStorageLimitBytes(2 * 1024 * 1024 * 1024);

      final stats = container.read(cacheStorageStatsProvider);
      expect(stats.storageLimitBytes, 2147483648);
      expect(stats.formattedStorageLimit, '2.00 GB');
      expect(stats.quotaUsagePercentage, lessThan(0.01));
      expect(stats.remainingBytes, 2147483648 - stats.totalBytesUsed);
    });
  });

  group('OfflinePreferencesNotifier', () {
    test('toggles offline mode, wifi-only and download quality', () {
      final container = _container();
      final notifier = container.read(offlinePreferencesProvider.notifier);

      expect(
        container.read(offlinePreferencesProvider).isOfflineModeForced,
        isFalse,
      );
      notifier.toggleOfflineMode();
      expect(
        container.read(offlinePreferencesProvider).isOfflineModeForced,
        isTrue,
      );

      expect(container.read(offlinePreferencesProvider).wifiOnlyDownload, isTrue);
      notifier.toggleWifiOnly();
      expect(container.read(offlinePreferencesProvider).wifiOnlyDownload, isFalse);

      notifier.setDownloadQuality(AudioDownloadQuality.wavLossless);
      expect(
        container.read(offlinePreferencesProvider).downloadQuality,
        AudioDownloadQuality.wavLossless,
      );

      notifier.setStorageLimitBytes(1024);
      expect(container.read(offlinePreferencesProvider).storageLimitBytes, 1024);

      // Unrelated fields survive every mutation.
      expect(
        container.read(offlinePreferencesProvider).isOfflineModeForced,
        isTrue,
      );
    });
  });
}

DownloadTask _task({
  String trackId = 'lib_off_900',
  String title = 'Task Under Test',
  DownloadStatus status = DownloadStatus.idle,
  double progress = 0.0,
  int receivedBytes = 0,
  int totalBytes = 0,
  String? errorMessage,
}) {
  return DownloadTask(
    trackId: trackId,
    title: title,
    creatorName: 'Vhusi Test',
    genre: 'Amapiano',
    remoteAudioUrl: 'https://vhunambi.com/audio/$trackId.mp3',
    status: status,
    progress: progress,
    receivedBytes: receivedBytes,
    totalBytes: totalBytes,
    errorMessage: errorMessage,
    startedAt: DateTime(2026, 9, 1),
  );
}

/// Builds a container whose offline services are sandboxed to [_vaultDir].
ProviderContainer _container({IAudioDownloadService? downloadService}) {
  final container = ProviderContainer(
    overrides: <Override>[
      offlineStorageServiceProvider.overrideWithValue(_storage),
      audioDownloadServiceProvider.overrideWithValue(
        downloadService ?? AudioDownloadService(simulateDownloads: true),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Pushes [track] into the vault and returns the stored record.
LibraryTrack _vaultTrack(
  ProviderContainer container, {
  String id = 'lib_off_100',
  String? title,
}) {
  final track = _track(id: id, title: title);
  container.read(libraryTracksProvider.notifier).addTrack(track);
  return track;
}

/// Records the `DownloadStatus` transitions emitted for [trackId].
List<DownloadStatus> _watchStatuses(ProviderContainer container, String trackId) {
  final statuses = <DownloadStatus>[];
  final subscription = container.listen<Map<String, DownloadTask>>(
    downloadManagerProvider,
    (previous, next) {
      final task = next[trackId];
      if (task == null) return;
      if (statuses.isEmpty || statuses.last != task.status) {
        statuses.add(task.status);
      }
    },
  );
  addTearDown(subscription.close);
  return statuses;
}

LibraryTrack _track({
  required String id,
  String? title,
  String genre = 'Amapiano',
  String language = 'Tshivenḓa',
  int durationSeconds = 216,
}) {
  return LibraryTrack(
    id: id,
    title: title ?? 'Offline Test Master',
    creatorName: 'Vhusi Test',
    genre: genre,
    language: language,
    durationSeconds: durationSeconds,
    remoteAudioUrl: 'https://vhunambi.com/audio/$id.mp3',
    createdAt: DateTime(2026, 9, 1),
  );
}

LibraryTrack _vaultRecord(List<LibraryTrack> tracks, String id) =>
    tracks.firstWhere((track) => track.id == id);

/// Releases the Hive file locks before removing the sandbox directory.
Future<void> _closeHiveAndDisposeVaultDir() async {
  await Hive.close();
  if (_vaultDir.existsSync()) {
    _vaultDir.deleteSync(recursive: true);
  }
}

/// Download service that never completes an in-flight transfer, letting the
/// suite assert the cancellation path without racing the simulated progress
/// ticks of [AudioDownloadService].
class HangingDownloadService implements IAudioDownloadService {
  final List<String> cancelledTrackIds = <String>[];
  final Completer<int> _pending = Completer<int>();

  @override
  Future<int> downloadFile({
    required String trackId,
    required String remoteUrl,
    required String destinationPath,
    required void Function(int received, int total) onProgress,
  }) {
    onProgress(2000000, 8500000);
    return _pending.future;
  }

  @override
  Future<void> cancelDownload(String trackId) async {
    cancelledTrackIds.add(trackId);
  }
}

/// Scripted download service: consumes [failSequence] one attempt at a time and
/// succeeds once the sequence is exhausted.
class ScriptedDownloadService implements IAudioDownloadService {
  ScriptedDownloadService({this.failSequence = const <bool>[true, false]});

  final List<bool> failSequence;
  final List<String> cancelledTrackIds = <String>[];
  int calls = 0;

  @override
  Future<int> downloadFile({
    required String trackId,
    required String remoteUrl,
    required String destinationPath,
    required void Function(int received, int total) onProgress,
  }) async {
    final shouldFail =
        calls < failSequence.length ? failSequence[calls] : false;
    calls++;

    onProgress(2125000, 8500000);
    if (shouldFail) {
      throw Exception('Network unreachable');
    }

    onProgress(8500000, 8500000);
    return 8500000;
  }

  @override
  Future<void> cancelDownload(String trackId) async {
    cancelledTrackIds.add(trackId);
  }
}

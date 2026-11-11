import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/features/library/domain/models/library_models.dart';
import 'package:vhunambi_client/features/offline/data/services/offline_storage_service.dart';
import 'package:vhunambi_client/features/offline/domain/models/offline_models.dart';

/// T8.6 — Offline vault persistence suite.
///
/// Covers [OfflineStorageService] metadata persistence, physical file eviction
/// and the offline domain models (T8.1/T8.2 verification gates for Phase 8).
///
/// The service is always pointed at a throw-away temp directory and the global
/// Hive home path is re-homed into that same sandbox, so the suite exercises the
/// real box backend without ever touching the device vault.
///
/// Hive must be initialised: `HiveImpl._openBox` reports a missing-home-path
/// error through an unlistened `Completer` before rethrowing, and flutter_test
/// surfaces that as an uncaught error even though `OfflineStorageService.init()`
/// swallows the exception.
late Directory _vaultDir;
late OfflineStorageService _service;

void main() {
  setUp(() async {
    _vaultDir = Directory.systemTemp.createTempSync('vhunambi_vault_test_');
    Hive.init(_vaultDir.path);
    _service = OfflineStorageService(customVaultDirectory: _vaultDir.path);
    await _service.init();
    // Deterministic starting point for every test in the file.
    await _service.clearAllMetadata();
    addTearDown(_closeHiveAndDisposeVaultDir);
  });

  group('OfflineStorageService', () {
    test('init() opens the vault boxes and is safe to call repeatedly',
        () async {
      final service =
          OfflineStorageService(customVaultDirectory: _vaultDir.path);

      await expectLater(service.init(), completes);
      // Idempotent: the second call short-circuits on the initialised flag.
      await expectLater(service.init(), completes);

      expect(service.customVaultDirectory, _vaultDir.path);
      expect(await service.getAllCachedMetadata(), isEmpty);
    });

    test('resolveVaultAudioDirectory honours the configured vault directory',
        () async {
      expect(await _service.resolveVaultAudioDirectory(), _vaultDir.path);

      // Without an explicit override the service must degrade to the vault
      // relative fallback instead of throwing in a headless test process.
      final headless = OfflineStorageService();
      expect(
        await headless.resolveVaultAudioDirectory(),
        contains(AppConstants.vaultAudioDirectory),
      );
    });

    test('saveTrackMetadata persists a fully retrievable vault record',
        () async {
      final track = _track(id: 'lib_off_001', title: 'Sunrise Log Drum');
      final localPath = '${_vaultDir.path}/lib_off_001.mp3';

      await _service.saveTrackMetadata(
        track: track,
        localPath: localPath,
        fileSizeBytes: 8500000,
      );

      final record = await _service.getTrackMetadata('lib_off_001');
      expect(record, isNotNull);
      expect(record!['id'], 'lib_off_001');
      expect(record['title'], 'Sunrise Log Drum');
      expect(record['creatorName'], 'Vhusi Test');
      expect(record['genre'], 'Amapiano');
      expect(record['language'], 'Tshivenḓa');
      expect(record['durationSeconds'], 216);
      expect(
        record['remoteAudioUrl'],
        'https://vhunambi.com/audio/lib_off_001.mp3',
      );
      expect(record['localAudioFilePath'], localPath);
      expect(record['fileSizeBytes'], 8500000);
      expect(record['syncStatus'], TrackSyncStatus.cachedLocally.name);
      expect(record['downloadedAt'], isA<String>());
      expect(
        DateTime.parse(record['downloadedAt'] as String),
        isA<DateTime>(),
      );
    });

    test('getTrackMetadata returns null for an unknown vault record', () async {
      expect(await _service.getTrackMetadata('lib_off_missing'), isNull);
    });

    test('getAllCachedMetadata lists every persisted record', () async {
      await _persist(_service, id: 'lib_off_010');
      await _persist(_service, id: 'lib_off_011');

      final all = await _service.getAllCachedMetadata();
      expect(all, hasLength(2));
      expect(
        all.map((record) => record['id']),
        containsAll(<String>['lib_off_010', 'lib_off_011']),
      );
    });

    test('getTotalCachedSizeBytes sums the persisted file sizes', () async {
      expect(await _service.getTotalCachedSizeBytes(), 0);

      await _persist(_service, id: 'lib_off_012', fileSizeBytes: 8500000);
      await _persist(_service, id: 'lib_off_013', fileSizeBytes: 4000000);

      expect(await _service.getTotalCachedSizeBytes(), 12500000);
    });

    test('removeTrackMetadata evicts a single record and keeps the rest',
        () async {
      await _persist(_service, id: 'lib_off_020');
      await _persist(_service, id: 'lib_off_021');

      await _service.removeTrackMetadata('lib_off_020');

      expect(await _service.getTrackMetadata('lib_off_020'), isNull);
      final remaining = await _service.getAllCachedMetadata();
      expect(remaining, hasLength(1));
      expect(remaining.single['id'], 'lib_off_021');
      expect(await _service.getTotalCachedSizeBytes(), 8500000);
    });

    test('removeTrackMetadata deletes the cached audio file from disk',
        () async {
      final file = File('${_vaultDir.path}/lib_off_022.mp3')
        ..writeAsBytesSync(List.filled(2048, 0));
      await _service.saveTrackMetadata(
        track: _track(id: 'lib_off_022'),
        localPath: file.path,
        fileSizeBytes: 2048,
      );

      expect(file.existsSync(), isTrue);
      expect(await _service.isTrackCachedLocally('lib_off_022'), isTrue);

      await _service.removeTrackMetadata('lib_off_022');

      expect(file.existsSync(), isFalse);
      expect(await _service.isTrackCachedLocally('lib_off_022'), isFalse);
    });

    test('clearAllMetadata purges every record and cached file', () async {
      final first = File('${_vaultDir.path}/lib_off_030.mp3')
        ..writeAsBytesSync(List.filled(1024, 0));
      final second = File('${_vaultDir.path}/lib_off_031.wav')
        ..writeAsBytesSync(List.filled(2048, 0));
      await _service.saveTrackMetadata(
        track: _track(id: 'lib_off_030'),
        localPath: first.path,
        fileSizeBytes: 1024,
      );
      await _service.saveTrackMetadata(
        track: _track(id: 'lib_off_031'),
        localPath: second.path,
        fileSizeBytes: 2048,
      );

      await _service.clearAllMetadata();

      expect(await _service.getAllCachedMetadata(), isEmpty);
      expect(await _service.getTotalCachedSizeBytes(), 0);
      expect(first.existsSync(), isFalse);
      expect(second.existsSync(), isFalse);
    });

    test('isTrackCachedLocally requires both vault metadata and file on disk',
        () async {
      expect(await _service.isTrackCachedLocally('lib_off_040'), isFalse);

      // Metadata alone without a materialized .vmf/audio file must report false
      // per Phase 08 physical cache verification (SovereignOfflineStorageService).
      await _persist(_service, id: 'lib_off_040');
      expect(await _service.isTrackCachedLocally('lib_off_040'), isFalse);

      final cachedFile = File('${_vaultDir.path}/lib_off_040.mp3')
        ..writeAsBytesSync(List<int>.filled(512, 0x2A));
      expect(cachedFile.existsSync(), isTrue);
      expect(await _service.isTrackCachedLocally('lib_off_040'), isTrue);
    });

    test('preferences round-trip through the storage service', () async {
      expect(await _service.getPreference('wifiOnlyDownload'), isNull);

      await _service.savePreference('wifiOnlyDownload', false);
      await _service.savePreference(
        'storageLimitBytes',
        2 * 1024 * 1024 * 1024,
      );

      expect(await _service.getPreference('wifiOnlyDownload'), isFalse);
      expect(await _service.getPreference('storageLimitBytes'), 2147483648);
      expect(await _service.getPreference('unknownKey'), isNull);
    });
  });

  group('Offline domain models', () {
    test('CacheStorageStats.formatBytes renders B, KB, MB and GB units', () {
      expect(CacheStorageStats.formatBytes(0), '0 B');
      expect(CacheStorageStats.formatBytes(512), '512 B');
      expect(CacheStorageStats.formatBytes(2048), '2.0 KB');
      expect(CacheStorageStats.formatBytes(5 * 1024 * 1024), '5.0 MB');
      expect(CacheStorageStats.formatBytes(8500000), '8.1 MB');
      expect(CacheStorageStats.formatBytes(5 * 1024 * 1024 * 1024), '5.00 GB');
    });

    test('CacheStorageStats derives quota usage, remaining space and labels',
        () {
      const stats = CacheStorageStats(
        totalBytesUsed: 25 * 1024 * 1024,
        cachedTrackCount: 1,
        storageLimitBytes: 100 * 1024 * 1024,
      );

      expect(stats.quotaUsagePercentage, 0.25);
      expect(stats.remainingBytes, 75 * 1024 * 1024);
      expect(stats.formattedBytesUsed, '25.0 MB');
      expect(stats.formattedRemainingBytes, '75.0 MB');
      expect(stats.formattedStorageLimit, '100.0 MB');
    });

    test('CacheStorageStats clamps a saturated and a zeroed quota', () {
      const saturated = CacheStorageStats(
        totalBytesUsed: 200 * 1024 * 1024,
        storageLimitBytes: 100 * 1024 * 1024,
      );
      expect(saturated.quotaUsagePercentage, 1.0);
      expect(saturated.remainingBytes, 0);

      // A zeroed ceiling must never divide by zero.
      const unlimited = CacheStorageStats(storageLimitBytes: 0);
      expect(unlimited.quotaUsagePercentage, 0.0);
      expect(unlimited.remainingBytes, 0);
    });

    test('CacheStorageStats.copyWith preserves untouched fields', () {
      const original = CacheStorageStats(
        totalBytesUsed: 1024,
        cachedTrackCount: 2,
        storageLimitBytes: 4096,
      );

      final updated = original.copyWith(totalBytesUsed: 2048);
      expect(updated.totalBytesUsed, 2048);
      expect(updated.cachedTrackCount, 2);
      expect(updated.storageLimitBytes, 4096);
      expect(updated, isNot(original));

      final rebuilt = original.copyWith(
        totalBytesUsed: 1024,
        cachedTrackCount: 2,
        storageLimitBytes: 4096,
      );
      expect(rebuilt, original);
      expect(rebuilt.hashCode, original.hashCode);
    });

    test('OfflinePreferenceState ships the documented defaults', () {
      const prefs = OfflinePreferenceState();

      expect(prefs.isOfflineModeForced, isFalse);
      expect(prefs.downloadQuality, AudioDownloadQuality.mp3HighQuality);
      expect(prefs.wifiOnlyDownload, isTrue);
      expect(prefs.storageLimitBytes, 5 * 1024 * 1024 * 1024);
    });

    test('OfflinePreferenceState.copyWith preserves untouched fields', () {
      const prefs = OfflinePreferenceState();

      final forced = prefs.copyWith(isOfflineModeForced: true);
      expect(forced.isOfflineModeForced, isTrue);
      expect(forced.downloadQuality, AudioDownloadQuality.mp3HighQuality);
      expect(forced.wifiOnlyDownload, isTrue);
      expect(forced.storageLimitBytes, 5 * 1024 * 1024 * 1024);
      expect(forced, isNot(prefs));

      final lossless = prefs.copyWith(
        downloadQuality: AudioDownloadQuality.wavLossless,
        wifiOnlyDownload: false,
        storageLimitBytes: 2 * 1024 * 1024 * 1024,
      );
      expect(lossless.isOfflineModeForced, isFalse);
      expect(lossless.downloadQuality, AudioDownloadQuality.wavLossless);
      expect(lossless.wifiOnlyDownload, isFalse);
      expect(lossless.storageLimitBytes, 2 * 1024 * 1024 * 1024);
    });

    test('AudioDownloadQuality exposes labels and file extensions', () {
      expect(AudioDownloadQuality.mp3HighQuality.label, 'MP3 (320 kbps)');
      expect(AudioDownloadQuality.mp3HighQuality.fileExtension, 'mp3');
      expect(AudioDownloadQuality.wavLossless.label, 'WAV (Lossless 24-bit)');
      expect(AudioDownloadQuality.wavLossless.fileExtension, 'wav');
    });
  });
}

Future<void> _persist(
  OfflineStorageService service, {
  required String id,
  int fileSizeBytes = 8500000,
}) {
  return service.saveTrackMetadata(
    track: _track(id: id),
    localPath: '${_vaultDir.path}/$id.mp3',
    fileSizeBytes: fileSizeBytes,
  );
}

LibraryTrack _track({
  required String id,
  String title = 'Sunrise Log Drum',
  String creatorName = 'Vhusi Test',
  String genre = 'Amapiano',
  String language = 'Tshivenḓa',
  int durationSeconds = 216,
}) {
  return LibraryTrack(
    id: id,
    title: title,
    creatorName: creatorName,
    genre: genre,
    language: language,
    durationSeconds: durationSeconds,
    remoteAudioUrl: 'https://vhunambi.com/audio/$id.mp3',
    createdAt: DateTime(2026, 9, 1),
  );
}

/// Releases the Hive file locks before removing the sandbox directory.
Future<void> _closeHiveAndDisposeVaultDir() async {
  await Hive.close();
  if (_vaultDir.existsSync()) {
    _vaultDir.deleteSync(recursive: true);
  }
}

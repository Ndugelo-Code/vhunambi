import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/library/domain/models/library_models.dart';
import 'package:vhunambi_client/features/library/presentation/providers/library_providers.dart';
import 'package:vhunambi_client/features/library/presentation/views/library_view.dart';
import 'package:vhunambi_client/features/offline/data/services/audio_download_service.dart';
import 'package:vhunambi_client/features/offline/data/services/offline_storage_service.dart';
import 'package:vhunambi_client/features/offline/domain/models/offline_models.dart';
import 'package:vhunambi_client/features/offline/domain/services/vault_envelope_crypto.dart';
import 'package:vhunambi_client/features/offline/presentation/providers/offline_providers.dart';
import 'package:vhunambi_client/features/offline/presentation/widgets/vault_storage_modal.dart';
import 'package:vhunambi_client/features/player/data/services/audio_source_resolver.dart';
import 'package:vhunambi_client/shared/models/track.dart';

/// Phase 08 Sovereign Offline Audio Vault & Encrypted Caching Pipeline
/// Comprehensive Verification Suite covering Gates P08-T01 through P08-T08.
void main() {
  late Directory testTempDir;

  setUp(() {
    testTempDir = Directory.systemTemp.createTempSync('vhunambi_p08_test_');
  });

  tearDown(() {
    if (testTempDir.existsSync()) {
      testTempDir.deleteSync(recursive: true);
    }
  });

  group('Phase 08 Sovereign Offline Audio Vault Suite', () {
    // -------------------------------------------------------------------------
    // P08-T01: VaultEnvelopeCrypto symmetric AES-CTR encryption and envelope layout
    // -------------------------------------------------------------------------
    test('P08-T01: VaultEnvelopeCrypto encrypts raw bytes to .vmf and decrypts symmetrically', () {
      final crypto = VaultEnvelopeCrypto();
      final rawData = Uint8List.fromList(List<int>.generate(2048, (i) => (i * 7) % 256));

      // 1. Encrypt to envelope
      final envelope = crypto.encryptToEnvelope(rawData);

      // Verify envelope binary specification
      expect(envelope.length, rawData.length + 30);
      expect(envelope[0], 0x56); // 'V'
      expect(envelope[1], 0x48); // 'H'
      expect(envelope[2], 0x55); // 'U'
      expect(envelope[3], 0x4E); // 'N'
      expect(envelope[4], 0x00); // version MSB
      expect(envelope[5], 0x01); // version LSB

      // 2. Symmetrical decryption
      final decrypted = crypto.decryptFromEnvelope(envelope);
      expect(decrypted, equals(rawData));

      // 3. Arbitrary seekable byte slice decryption
      const start = 120;
      const end = 570;
      final slice = crypto.decryptSlice(envelope, start, end);
      expect(slice, equals(rawData.sublist(start, end)));
    });

    // -------------------------------------------------------------------------
    // P08-T02: ResilientAudioDownloadService writes real bytes and commits swap atomically
    // -------------------------------------------------------------------------
    test('P08-T02: ResilientAudioDownloadService writes real bytes to disk and commits swap file atomically', () async {
      final crypto = VaultEnvelopeCrypto();
      final service = ResilientAudioDownloadService(crypto: crypto, simulateDownloads: true);

      final targetPath = '${testTempDir.path}/track_001.vmf';
      final swapPath = '$targetPath.vswap';

      final downloadedBytes = await service.downloadFile(
        trackId: 'track_001',
        remoteUrl: 'test://audio/track_001.mp3',
        destinationPath: targetPath,
        onProgress: (received, total, [speed]) {},
      );

      expect(downloadedBytes, greaterThan(0));
      expect(File(targetPath).existsSync(), isTrue);
      expect(File(swapPath).existsSync(), isFalse);

      final fileBytes = await File(targetPath).readAsBytes();
      expect(fileBytes.length, downloadedBytes);
      expect(fileBytes[0], 0x56);
      expect(fileBytes[1], 0x48);
      expect(fileBytes[2], 0x55);
      expect(fileBytes[3], 0x4E);
    });

    // -------------------------------------------------------------------------
    // P08-T03: ResilientAudioDownloadService resumes interrupted downloads via Range header
    // -------------------------------------------------------------------------
    test('P08-T03: ResilientAudioDownloadService resumes interrupted downloads via HTTP Range headers', () async {
      final crypto = VaultEnvelopeCrypto();
      final destinationPath = '${testTempDir.path}/track_resume.vmf';
      final swapFile = File('$destinationPath.vswap');

      // Stage an existing partial swap file of 512 bytes
      await swapFile.writeAsBytes(List<int>.filled(512, 0xAA));

      // Mock Dio capturing requested Range headers
      RequestOptions? capturedOptions;
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedOptions = options;
            final responseData = ResponseBody.fromBytes(
              List<int>.filled(512, 0xBB),
              206, // Partial Content
              headers: {
                Headers.contentLengthHeader: ['512'],
              },
            );
            return handler.resolve(
              Response<ResponseBody>(
                requestOptions: options,
                data: responseData,
                statusCode: 206,
              ),
            );
          },
        ),
      );

      final service = ResilientAudioDownloadService(dio: dio, crypto: crypto, simulateDownloads: false);

      await service.downloadFile(
        trackId: 'track_resume',
        remoteUrl: 'https://cdn.vhunambi.com/audio/track_resume.mp3',
        destinationPath: destinationPath,
        onProgress: (r, t, [s]) {},
      );

      expect(capturedOptions, isNotNull);
      expect(capturedOptions!.headers['Range'], 'bytes=512-');
      expect(File(destinationPath).existsSync(), isTrue);
      expect(swapFile.existsSync(), isFalse);
    });

    // -------------------------------------------------------------------------
    // P08-T04: DownloadManagerNotifier concurrency cap and speed/ETA telemetry
    // -------------------------------------------------------------------------
    test('P08-T04: DownloadManagerNotifier enforces concurrency cap of 2 active downloads and calculates speed/ETA', () async {
      final storage = _FakeStorage();
      final downloadService = _ControllableDownloadService();

      final container = ProviderContainer(
        overrides: [
          offlineStorageServiceProvider.overrideWithValue(storage),
          audioDownloadServiceProvider.overrideWithValue(downloadService),
        ],
      );
      addTearDown(container.dispose);

      final manager = container.read(downloadManagerProvider.notifier);

      final t1 = _makeTestTrack('track_c1', 'Song 1');
      final t2 = _makeTestTrack('track_c2', 'Song 2');
      final t3 = _makeTestTrack('track_c3', 'Song 3');

      // Request downloads concurrently
      unawaited(manager.requestDownload(t1));
      unawaited(manager.requestDownload(t2));
      unawaited(manager.requestDownload(t3));

      // Allow microtasks to settle
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final state = container.read(downloadManagerProvider);

      // Concurrency check: exactly 2 downloading, 1 queued
      expect(state[t1.id]?.status, DownloadStatus.downloading);
      expect(state[t2.id]?.status, DownloadStatus.downloading);
      expect(state[t3.id]?.status, DownloadStatus.queued);

      // Telemetry emission on t1
      downloadService.emitProgress(t1.id, 4000000, 8000000, 1000000.0);
      final updatedT1 = container.read(downloadManagerProvider)[t1.id]!;
      expect(updatedT1.bytesPerSecond, 1000000.0);
      expect(updatedT1.etaSeconds, 4);
      expect(updatedT1.formattedSpeed, contains('/s'));
      expect(updatedT1.formattedEta, contains('4s'));

      // Complete t1 -> t3 must transition from queued to downloading automatically
      downloadService.completeDownload(t1.id, 8000000);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final stateAfterT1 = container.read(downloadManagerProvider);
      expect(stateAfterT1[t1.id]?.status, DownloadStatus.completed);
      expect(stateAfterT1[t3.id]?.status, DownloadStatus.downloading);
    });

    // -------------------------------------------------------------------------
    // P08-T05: AudioSourceResolver prioritizes local .vmf envelope over remote URL
    // -------------------------------------------------------------------------
    test('P08-T05: AudioSourceResolver prioritizes local .vmf envelope over remote URL', () async {
      final crypto = VaultEnvelopeCrypto();
      final localVmf = File('${testTempDir.path}/track_p05.vmf');
      final envelope = crypto.encryptToEnvelope(Uint8List.fromList(List.filled(1024, 0x01)));
      await localVmf.writeAsBytes(envelope, flush: true);

      final storage = _FakeStorage();
      storage.seedTrack('track_p05', localVmf.path, 1024);

      final resolver = AudioSourceResolver(
        offlineStorage: storage,
        crypto: crypto,
      );

      final resolved = await resolver.resolveSource(
        _makePlayerTrack('track_p05', 'Cached Master', 'https://cdn.vhunambi.com/audio/track_p05.mp3'),
      );

      expect(resolved.isLocalFile, isTrue);
      expect(resolved.localFilePath, localVmf.path);
      expect(resolved.localFilePath, endsWith('.vmf'));
      expect(resolved.streamSource, isA<EncryptedVmfStreamSource>());
      expect(resolved.sourceLabel, 'vault');
    });

    // -------------------------------------------------------------------------
    // P08-T06: AudioSourceResolver throws AudioSourceException for uncached track in forced offline
    // -------------------------------------------------------------------------
    test('P08-T06: AudioSourceResolver throws AudioSourceException when forced offline mode is enabled for uncached track', () async {
      final storage = _FakeStorage();

      final resolver = AudioSourceResolver(
        offlineStorage: storage,
        offlineModeGuard: () => true, // Forced offline enabled
      );

      expect(
        () => resolver.resolveSource(
          _makePlayerTrack('track_uncached', 'Uncached Stream', 'https://cdn.vhunambi.com/audio/track_uncached.mp3'),
        ),
        throwsA(
          isA<AudioSourceException>()
              .having((e) => e.trackId, 'trackId', 'track_uncached')
              .having((e) => e.requiresConnectivity, 'requiresConnectivity', isTrue),
        ),
      );
    });

    // -------------------------------------------------------------------------
    // P08-T07: VaultStorageModal renders quota progress meter and executes Clear All
    // -------------------------------------------------------------------------
    testWidgets('P08-T07: VaultStorageModal renders quota progress meter and executes Clear All cache purging', (tester) async {
      tester.view.physicalSize = const Size(420, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final storage = _FakeStorage();
      final container = ProviderContainer(
        overrides: [
          offlineStorageServiceProvider.overrideWithValue(storage),
          audioDownloadServiceProvider.overrideWithValue(AudioDownloadService(simulateDownloads: true)),
        ],
      );
      addTearDown(container.dispose);

      // Seed a cached track in the library
      final cachedTrack = _makeTestTrack('t_seed', 'Seed Song').copyWith(
        syncStatus: TrackSyncStatus.cachedLocally,
        localAudioFilePath: 'test_vault/audio/t_seed.vmf',
      );
      container.read(libraryTracksProvider.notifier).addTrack(cachedTrack);
      storage.seedTrack(cachedTrack.id, 'test_vault/audio/t_seed.vmf', 8500000);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(body: VaultStorageModal()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check quota meter presence
      expect(find.byKey(const Key('vault_storage_meter')), findsOneWidget);
      expect(find.byKey(const Key('vault_clear_all_downloads_btn')), findsOneWidget);

      // Execute Clear All
      await tester.tap(find.byKey(const Key('vault_clear_all_downloads_btn')));
      await tester.pumpAndSettle();

      // Confirmation dialog pops up
      expect(find.text('Delete All'), findsOneWidget);
      await tester.tap(find.text('Delete All'));
      await tester.pumpAndSettle();

      // Verify all cached tracks reset
      expect(container.read(cacheStorageStatsProvider).cachedTrackCount, 0);
      final tracks = container.read(libraryTracksProvider);
      expect(tracks.where((t) => t.syncStatus == TrackSyncStatus.cachedLocally), isEmpty);
    });

    // -------------------------------------------------------------------------
    // P08-T08: LibraryView scopes list correctly when TrackSyncFilter.cachedOnly is selected
    // -------------------------------------------------------------------------
    testWidgets('P08-T08: LibraryView scopes list correctly when TrackSyncFilter.cachedOnly is selected', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final storage = _FakeStorage();
      final container = ProviderContainer(
        overrides: [
          offlineStorageServiceProvider.overrideWithValue(storage),
          audioDownloadServiceProvider.overrideWithValue(AudioDownloadService(simulateDownloads: true)),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const LibraryView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Select Cached Only filter
      expect(find.byKey(const Key('vault_filter_cached_only')), findsOneWidget);
      await tester.tap(find.byKey(const Key('vault_filter_cached_only')));
      await tester.pumpAndSettle();

      // Filtered projection must now contain only cachedLocally tracks
      final filteredTracks = container.read(filteredLibraryTracksProvider);
      expect(filteredTracks, isNotEmpty);
      expect(filteredTracks.every((t) => t.syncStatus == TrackSyncStatus.cachedLocally), isTrue);
    });
  });
}

// =============================================================================
// Test Doubles and Helper Functions
// =============================================================================

LibraryTrack _makeTestTrack(String id, String title) {
  return LibraryTrack(
    id: id,
    title: title,
    creatorName: 'Vhusi Test',
    genre: 'Amapiano',
    language: 'isiZulu',
    durationSeconds: 210,
    remoteAudioUrl: 'https://cdn.vhunambi.com/audio/$id.mp3',
    createdAt: DateTime.now(),
  );
}

Track _makePlayerTrack(String id, String title, String url) {
  return Track(
    id: id,
    title: title,
    creatorName: 'Vhusi Test',
    genre: 'Amapiano',
    audioUrl: url,
    duration: const Duration(seconds: 210),
  );
}

class _ControllableDownloadService implements IAudioDownloadService {
  final Map<String, Completer<int>> _completers = {};
  final Map<String, Function> _callbacks = {};

  @override
  Future<int> downloadFile({
    required String trackId,
    required String remoteUrl,
    required String destinationPath,
    required Function onProgress,
  }) {
    final completer = Completer<int>();
    _completers[trackId] = completer;
    _callbacks[trackId] = onProgress;
    return completer.future;
  }

  @override
  Future<void> cancelDownload(String trackId) async {
    _completers[trackId]?.completeError(Exception('Cancelled'));
    _completers.remove(trackId);
    _callbacks.remove(trackId);
  }

  void emitProgress(String trackId, int received, int total, double speed) {
    final cb = _callbacks[trackId];
    if (cb != null) {
      if (cb is void Function(int, int, [double?])) {
        cb(received, total, speed);
      } else if (cb is void Function(int, int, double)) {
        cb(received, total, speed);
      } else if (cb is void Function(int, int)) {
        cb(received, total);
      }
    }
  }

  void completeDownload(String trackId, int totalBytes) {
    _completers[trackId]?.complete(totalBytes);
    _completers.remove(trackId);
    _callbacks.remove(trackId);
  }
}

/// Pure in-memory IOfflineStorageService for instantaneous deterministic testing.
class _FakeStorage implements IOfflineStorageService {
  final Map<String, Map<String, dynamic>> _vault = {};
  final Map<String, dynamic> _prefs = {};

  void seedTrack(String trackId, String path, int size) {
    _vault[trackId] = {
      'id': trackId,
      'title': 'Seeded Track',
      'localAudioFilePath': path,
      'fileSizeBytes': size,
      'syncStatus': TrackSyncStatus.cachedLocally.name,
    };
  }

  @override
  Future<void> init() async {}

  @override
  Future<void> saveTrackMetadata({
    required LibraryTrack track,
    required String localPath,
    required int fileSizeBytes,
  }) async {
    _vault[track.id] = {
      'id': track.id,
      'title': track.title,
      'creatorName': track.creatorName,
      'localAudioFilePath': localPath,
      'fileSizeBytes': fileSizeBytes,
      'syncStatus': TrackSyncStatus.cachedLocally.name,
    };
  }

  @override
  Future<Map<String, dynamic>?> getTrackMetadata(String trackId) async => _vault[trackId];

  @override
  Future<List<Map<String, dynamic>>> getAllCachedMetadata() async => _vault.values.toList();

  @override
  Future<void> removeTrackMetadata(String trackId) async {
    _vault.remove(trackId);
  }

  @override
  Future<void> clearAllMetadata() async {
    _vault.clear();
  }

  @override
  Future<int> getTotalCachedSizeBytes() async {
    return _vault.values.fold<int>(0, (sum, item) => sum + ((item['fileSizeBytes'] as int?) ?? 0));
  }

  @override
  Future<bool> isTrackCachedLocally(String trackId) async => _vault.containsKey(trackId);

  @override
  Future<String> resolveVaultAudioDirectory() async => 'test_vault/audio';

  @override
  Future<void> savePreference(String key, dynamic value) async {
    _prefs[key] = value;
  }

  @override
  Future<dynamic> getPreference(String key) async => _prefs[key];
}

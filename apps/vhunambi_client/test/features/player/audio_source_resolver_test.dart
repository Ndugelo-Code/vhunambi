import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/features/library/domain/models/library_models.dart';
import 'package:vhunambi_client/features/offline/data/services/offline_storage_service.dart';
import 'package:vhunambi_client/features/player/data/services/audio_source_resolver.dart';
import 'package:vhunambi_client/shared/models/track.dart';

/// T9.6 — Hybrid asset source resolution suite (T9.2 / REQ-AUD-09).
///
/// Phase 8's Hive vault is replaced by [_MemoryOfflineStorage] so resolution
/// ordering (vault → forced-offline failure → cloud stream) is asserted without
/// touching a real box, while the "file present on disk" branch uses genuine
/// temp files.
void main() {
  late Directory vaultDir;
  late _MemoryOfflineStorage storage;

  setUp(() {
    vaultDir = Directory.systemTemp.createTempSync('vhunambi_resolver_test_');
    storage = _MemoryOfflineStorage();
    addTearDown(() {
      if (vaultDir.existsSync()) vaultDir.deleteSync(recursive: true);
    });
  });

  AudioSourceResolver resolver({bool offlineModeForced = false}) =>
      AudioSourceResolver(
        offlineStorage: storage,
        offlineModeGuard: () => offlineModeForced,
      );

  group('AudioSourceResolver', () {
    test('resolves a cached vault master to a local file uri', () async {
      final file = File('${vaultDir.path}/cached_master.mp3')
        ..writeAsBytesSync(List.filled(2048, 0));
      storage.cacheTrack('trk_cached', file.path, fileSizeBytes: 2048);

      final resolved = await resolver().resolveSource(_track(id: 'trk_cached'));

      expect(resolved.isLocalFile, isTrue);
      expect(resolved.uri, Uri.file(file.path));
      expect(resolved.uri.scheme, 'file');
      expect(resolved.localFilePath, file.path);
      expect(resolved.sourceLabel, 'vault');
    });

    test('falls back to the remote stream for uncached tracks', () async {
      final resolved = await resolver().resolveSource(_track(id: 'trk_cloud'));

      expect(resolved.isLocalFile, isFalse);
      expect(resolved.localFilePath, isNull);
      expect(
        resolved.uri.toString(),
        'https://vhunambi.com/audio/trk_cloud.mp3',
      );
      expect(resolved.sourceLabel, 'stream');
    });

    test('uses the catalog convention when a track has no audio url', () async {
      final resolved = await resolver()
          .resolveSource(_track(id: 'trk_no_url', withAudioUrl: false));

      expect(
        resolved.uri.toString(),
        '${AppConstants.defaultOrigin}/audio/trk_no_url.mp3',
      );
      expect(resolved.isLocalFile, isFalse);
    });

    test('ignores vault metadata whose local file was evicted', () async {
      storage.cacheTrack(
        'trk_stale',
        '${vaultDir.path}/missing_master.mp3',
        fileSizeBytes: 1024,
      );

      final resolved = await resolver().resolveSource(_track(id: 'trk_stale'));

      expect(resolved.isLocalFile, isFalse);
      expect(resolved.uri.scheme, 'https');
    });

    test('raises a clean AudioSourceException while offline mode is forced',
        () async {
      await expectLater(
        resolver(offlineModeForced: true).resolveSource(_track(id: 'trk_offline')),
        throwsA(
          isA<AudioSourceException>()
              .having((error) => error.trackId, 'trackId', 'trk_offline')
              .having(
                (error) => error.requiresConnectivity,
                'requiresConnectivity',
                isTrue,
              )
              .having(
                (error) => error.message,
                'message',
                contains('not cached'),
              ),
        ),
      );
    });

    test('prefers the vault copy even while offline mode is forced', () async {
      final file = File('${vaultDir.path}/forced_master.wav')
        ..writeAsBytesSync(List.filled(512, 0));
      storage.cacheTrack('trk_forced_cached', file.path, fileSizeBytes: 512);

      final resolved = await resolver(offlineModeForced: true)
          .resolveSource(_track(id: 'trk_forced_cached'));

      expect(resolved.isLocalFile, isTrue);
      expect(resolved.localFilePath, file.path);
    });

    test('exposes the live forced-offline preference through the guard', () {
      var offlineModeForced = false;
      final live = AudioSourceResolver(
        offlineStorage: storage,
        offlineModeGuard: () => offlineModeForced,
      );

      expect(live.isOfflineModeForced, isFalse);
      offlineModeForced = true;
      expect(live.isOfflineModeForced, isTrue);
    });
  });

  group('ResolvedAudioSource value semantics', () {
    test('compares by uri, locality and local path', () {
      final first = ResolvedAudioSource(
        uri: Uri.parse('file:///vault/a.mp3'),
        isLocalFile: true,
        localFilePath: '/vault/a.mp3',
      );
      final same = ResolvedAudioSource(
        uri: Uri.parse('file:///vault/a.mp3'),
        isLocalFile: true,
        localFilePath: '/vault/a.mp3',
      );
      final streamed = ResolvedAudioSource(
        uri: Uri.parse('https://vhunambi.com/audio/a.mp3'),
        isLocalFile: false,
      );

      expect(first, same);
      expect(first.hashCode, same.hashCode);
      expect(first, isNot(streamed));
      expect(first.sourceLabel, 'vault');
      expect(streamed.sourceLabel, 'stream');
      expect(first.toString(), contains('isLocalFile: true'));
    });

    test('AudioSourceException renders its track id and connectivity flag', () {
      const error = AudioSourceException(
        'Offline mode is enabled',
        trackId: 'trk_x',
        requiresConnectivity: true,
      );

      expect(
        error.toString(),
        'AudioSourceException(trk_x): Offline mode is enabled',
      );
      expect(error.requiresConnectivity, isTrue);
      expect(
        const AudioSourceException('boom', trackId: 'trk_y')
            .requiresConnectivity,
        isFalse,
      );
    });
  });
}

/// In-memory `IOfflineStorageService` double used by the resolution suite.
class _MemoryOfflineStorage implements IOfflineStorageService {
  final Map<String, Map<String, dynamic>> _vault =
      <String, Map<String, dynamic>>{};
  final Map<String, dynamic> _prefs = <String, dynamic>{};

  /// Registers a cached master at [localPath].
  void cacheTrack(
    String trackId,
    String localPath, {
    required int fileSizeBytes,
  }) {
    _vault[trackId] = <String, dynamic>{
      'id': trackId,
      'localAudioFilePath': localPath,
      'fileSizeBytes': fileSizeBytes,
      'syncStatus': TrackSyncStatus.cachedLocally.name,
    };
  }

  @override
  Future<void> init() => Future<void>.value();

  @override
  Future<void> saveTrackMetadata({
    required LibraryTrack track,
    required String localPath,
    required int fileSizeBytes,
  }) {
    cacheTrack(track.id, localPath, fileSizeBytes: fileSizeBytes);
    return Future<void>.value();
  }

  @override
  Future<Map<String, dynamic>?> getTrackMetadata(String trackId) =>
      Future<Map<String, dynamic>?>.value(_vault[trackId]);

  @override
  Future<List<Map<String, dynamic>>> getAllCachedMetadata() =>
      Future<List<Map<String, dynamic>>>.value(_vault.values.toList());

  @override
  Future<void> removeTrackMetadata(String trackId) {
    _vault.remove(trackId);
    return Future<void>.value();
  }

  @override
  Future<void> clearAllMetadata() {
    _vault.clear();
    return Future<void>.value();
  }

  @override
  Future<int> getTotalCachedSizeBytes() => Future<int>.value(
        _vault.values.fold<int>(
          0,
          (total, record) => total + (record['fileSizeBytes'] as int? ?? 0),
        ),
      );

  @override
  Future<bool> isTrackCachedLocally(String trackId) =>
      Future<bool>.value(_vault.containsKey(trackId));

  @override
  Future<String> resolveVaultAudioDirectory() =>
      Future<String>.value('test_vault/audio');

  @override
  Future<void> savePreference(String key, dynamic value) {
    _prefs[key] = value;
    return Future<void>.value();
  }

  @override
  Future<dynamic> getPreference(String key) =>
      Future<dynamic>.value(_prefs[key]);
}

Track _track({String id = 'trk_cloud', bool withAudioUrl = true}) {
  return Track(
    id: id,
    title: 'Offline Pipeline Master',
    creatorName: 'Vhusi Test',
    genre: 'Amapiano',
    language: 'Tshivenḓa',
    duration: const Duration(minutes: 3, seconds: 29),
    audioUrl: withAudioUrl ? 'https://vhunambi.com/audio/$id.mp3' : null,
    coverUrl: 'https://vhunambi.com/covers/$id.jpg',
    mood: 'Energetic',
  );
}

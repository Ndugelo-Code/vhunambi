import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../library/domain/models/library_models.dart';
import '../../../library/presentation/providers/library_providers.dart';
import '../../data/services/audio_download_service.dart';
import '../../data/services/offline_storage_service.dart';
import '../../domain/models/offline_models.dart';
import '../../domain/services/vault_envelope_crypto.dart';

/// Vault envelope crypto provider.
final vaultEnvelopeCryptoProvider = Provider<VaultEnvelopeCrypto>((ref) {
  return VaultEnvelopeCrypto();
});

/// Offline storage service dependency provider.
final offlineStorageServiceProvider = Provider<IOfflineStorageService>((ref) {
  final service = OfflineStorageService();
  service.init();
  return service;
});

/// Audio download service dependency provider.
/// Explicitly simulateDownloads: false in production per Invariant 1.
final audioDownloadServiceProvider = Provider<IAudioDownloadService>((ref) {
  final crypto = ref.watch(vaultEnvelopeCryptoProvider);
  return AudioDownloadService(crypto: crypto, simulateDownloads: false);
});

/// Central download manager managing queue, progress emission, and local vault sync.
final downloadManagerProvider =
    StateNotifierProvider<DownloadManagerNotifier, Map<String, DownloadTask>>((ref) {
  final storageService = ref.watch(offlineStorageServiceProvider);
  final downloadService = ref.watch(audioDownloadServiceProvider);
  return DownloadManagerNotifier(ref, storageService, downloadService);
});

/// Aggregated storage quota analytics computed across cached vault audio.
final cacheStorageStatsProvider = Provider<CacheStorageStats>((ref) {
  final tracks = ref.watch(libraryTracksProvider);
  final prefs = ref.watch(offlinePreferencesProvider);

  final cachedTracks = tracks
      .where((t) => t.syncStatus == TrackSyncStatus.cachedLocally)
      .toList(growable: false);

  const avgTrackSizeBytes = 8500000;
  final totalBytes = cachedTracks.length * avgTrackSizeBytes;

  return CacheStorageStats(
    totalBytesUsed: totalBytes,
    cachedTrackCount: cachedTracks.length,
    storageLimitBytes: prefs.storageLimitBytes,
  );
});

/// User preferences governing offline playback, storage limits, and download quality.
final offlinePreferencesProvider =
    StateNotifierProvider<OfflinePreferencesNotifier, OfflinePreferenceState>((ref) {
  return OfflinePreferencesNotifier();
});

class OfflinePreferencesNotifier extends StateNotifier<OfflinePreferenceState> {
  final IOfflineStorageService? _storage;

  OfflinePreferencesNotifier([this._storage]) : super(const OfflinePreferenceState());

  Future<void> loadFromStorage() async {
    if (_storage == null) return;
    try {
      final forced = await _storage.getPreference('isOfflineModeForced') as bool?;
      final wifiOnly = await _storage.getPreference('downloadWifiOnly') as bool?;
      final limit = await _storage.getPreference('storageLimitBytes') as int?;
      if (!mounted) return;
      state = state.copyWith(
        isOfflineModeForced: forced ?? state.isOfflineModeForced,
        downloadWifiOnly: wifiOnly ?? state.downloadWifiOnly,
        storageLimitBytes: limit ?? state.storageLimitBytes,
      );
    } catch (_) {}
  }

  void toggleOfflineMode() {
    final next = !state.isOfflineModeForced;
    state = state.copyWith(isOfflineModeForced: next);
    _storage?.savePreference('isOfflineModeForced', next);
  }

  void toggleWifiOnly() {
    final next = !state.downloadWifiOnly;
    state = state.copyWith(downloadWifiOnly: next);
    _storage?.savePreference('downloadWifiOnly', next);
  }

  void setStorageLimit(int bytes) {
    state = state.copyWith(storageLimitBytes: bytes);
    _storage?.savePreference('storageLimitBytes', bytes);
  }

  void setStorageLimitBytes(int bytes) => setStorageLimit(bytes);

  void setDownloadQuality(AudioDownloadQuality quality) {
    state = state.copyWith(downloadQuality: quality);
  }
}

class DownloadManagerNotifier extends StateNotifier<Map<String, DownloadTask>> {
  final Ref _ref;
  final IOfflineStorageService _storageService;
  final IAudioDownloadService _downloadService;
  final Map<String, Completer<void>> _completers = {};

  DownloadManagerNotifier(
    this._ref,
    this._storageService,
    this._downloadService,
  ) : super(const <String, DownloadTask>{});

  /// Returns total number of active downloads in progress or queued.
  int get activeDownloadsCount =>
      state.values.where((task) => task.isActive).length;

  /// Initiates or queues an offline download for the given vault track (awaits completion).
  Future<void> downloadTrack(
    LibraryTrack track, {
    AudioDownloadQuality quality = AudioDownloadQuality.mp3HighQuality,
  }) async {
    final dir = await _storageService.resolveVaultAudioDirectory();
    final localPath = '$dir/${track.id}.${quality.fileExtension}';
    return _enqueue(track, localPath, waitForCompletion: true);
  }

  /// Non-blocking request to queue an offline download per Phase 8 specification.
  Future<void> requestDownload(
    LibraryTrack track, {
    AudioDownloadQuality? quality,
  }) async {
    if (track.syncStatus == TrackSyncStatus.cachedLocally) return;
    final dir = await _storageService.resolveVaultAudioDirectory();
    final ext = quality?.fileExtension ?? 'vmf';
    final localPath = '$dir/${track.id}.$ext';
    await _enqueue(track, localPath, waitForCompletion: false);
  }

  Future<void> _enqueue(
    LibraryTrack track,
    String localPath, {
    required bool waitForCompletion,
  }) async {
    final existing = state[track.id];
    if (existing != null && existing.isActive) {
      if (waitForCompletion && _completers.containsKey(track.id)) {
        await _completers[track.id]?.future;
      }
      return;
    }

    final completer = Completer<void>();
    _completers[track.id] = completer;

    final task = DownloadTask(
      trackId: track.id,
      title: track.title,
      creatorName: track.creatorName,
      genre: track.genre,
      remoteAudioUrl: track.remoteAudioUrl,
      localAudioFilePath: localPath,
      status: DownloadStatus.queued,
      startedAt: DateTime.now(),
    );

    state = {...state, track.id: task};
    _updateLibrarySyncStatus(track.id, TrackSyncStatus.downloading);

    _processNextInQueue();

    if (waitForCompletion) {
      await completer.future;
    }
  }

  void _processNextInQueue() {
    while (true) {
      final activeDownloadingCount = state.values
          .where((t) => t.status == DownloadStatus.downloading)
          .length;

      // Strict concurrency limit of 2 parallel downloads
      if (activeDownloadingCount >= 2) break;

      DownloadTask? nextQueued;
      for (final task in state.values) {
        if (task.status == DownloadStatus.queued) {
          nextQueued = task;
          break;
        }
      }

      if (nextQueued == null) break;
      _executeDownload(nextQueued);
    }
  }

  Future<void> _executeDownload(DownloadTask queuedTask) async {
    final trackId = queuedTask.trackId;

    state = {
      ...state,
      trackId: queuedTask.copyWith(status: DownloadStatus.downloading),
    };

    try {
      final totalBytes = await _downloadService.downloadFile(
        trackId: trackId,
        remoteUrl: queuedTask.remoteAudioUrl,
        destinationPath: queuedTask.localFilePath,
        onProgress: (int received, int total, [dynamic speed]) {
          final current = state[trackId];
          if (current != null && current.status == DownloadStatus.downloading) {
            final progress = total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;
            final double sp = (speed is num) ? speed.toDouble() : 0.0;
            final int eta = sp > 0 ? ((total - received) / sp).round() : 0;
            state = {
              ...state,
              trackId: current.copyWith(
                progress: progress,
                receivedBytes: received,
                totalBytes: total,
                bytesPerSecond: sp,
                etaSeconds: eta,
              ),
            };
          }
        },
      );

      final completedTask = state[trackId]?.copyWith(
            status: DownloadStatus.completed,
            progress: 1.0,
            receivedBytes: totalBytes,
            totalBytes: totalBytes,
            completedAt: DateTime.now(),
          ) ??
          queuedTask.copyWith(
            status: DownloadStatus.completed,
            progress: 1.0,
            receivedBytes: totalBytes,
            totalBytes: totalBytes,
            completedAt: DateTime.now(),
          );

      state = {...state, trackId: completedTask};
      _processNextInQueue();

      final trackList = _ref.read(libraryTracksProvider);
      final track = trackList.firstWhere(
        (t) => t.id == trackId,
        orElse: () => LibraryTrack(
          id: trackId,
          title: queuedTask.title,
          creatorName: queuedTask.creatorName,
          genre: queuedTask.genre,
          language: 'isiZulu',
          durationSeconds: 210,
          remoteAudioUrl: queuedTask.remoteAudioUrl,
          createdAt: DateTime.now(),
        ),
      );

      await _storageService.saveTrackMetadata(
        track: track,
        localPath: queuedTask.localFilePath,
        fileSizeBytes: totalBytes,
      );

      _updateLibrarySyncStatus(
        trackId,
        TrackSyncStatus.cachedLocally,
        localPath: queuedTask.localFilePath,
      );

      _completers[trackId]?.complete();
      _completers.remove(trackId);
    } catch (e) {
      final failedTask = state[trackId]?.copyWith(
            status: DownloadStatus.failed,
            errorMessage: e.toString(),
          ) ??
          queuedTask.copyWith(
            status: DownloadStatus.failed,
            errorMessage: e.toString(),
          );

      state = {...state, trackId: failedTask};

      _updateLibrarySyncStatus(trackId, TrackSyncStatus.error);

      _completers[trackId]?.complete();
      _completers.remove(trackId);
    } finally {
      _processNextInQueue();
    }
  }

  /// Cancels an in-flight download and resets vault sync status back to cloudOnly.
  Future<void> cancelDownload(String trackId) async {
    await _downloadService.cancelDownload(trackId);

    final current = state[trackId];
    if (current != null) {
      state = {
        ...state,
        trackId: current.copyWith(
          status: DownloadStatus.idle,
          progress: 0.0,
          errorMessage: 'Download cancelled',
        ),
      };
    }

    _updateLibrarySyncStatus(trackId, TrackSyncStatus.cloudOnly);

    _completers[trackId]?.complete();
    _completers.remove(trackId);

    _processNextInQueue();
  }

  /// Retries a previously failed or idle download.
  Future<void> retryDownload(LibraryTrack track) async {
    await downloadTrack(track);
  }

  /// Evicts the local cached file from disk, removes Hive metadata,
  /// and returns vault track back to cloudOnly status.
  Future<void> removeOfflineTrack(String trackId) async {
    await _storageService.removeTrackMetadata(trackId);

    final updated = Map<String, DownloadTask>.from(state)..remove(trackId);
    state = updated;

    _updateLibrarySyncStatus(trackId, TrackSyncStatus.cloudOnly);
  }

  /// Alias per Phase 08 spec.
  Future<void> removeOfflineDownload(String trackId) => removeOfflineTrack(trackId);

  /// Purges all downloaded audio files from disk, clears Hive metadata,
  /// and updates all vault tracks to cloudOnly status.
  Future<void> clearAllOfflineTracks() async {
    for (final task in state.values) {
      if (task.isActive) {
        await _downloadService.cancelDownload(task.trackId);
      }
    }

    await _storageService.clearAllMetadata();
    state = const <String, DownloadTask>{};

    final tracks = _ref.read(libraryTracksProvider);
    for (final track in tracks) {
      if (track.syncStatus == TrackSyncStatus.cachedLocally) {
        _updateLibrarySyncStatus(track.id, TrackSyncStatus.cloudOnly);
      }
    }
  }

  /// Alias per Phase 08 spec.
  Future<void> clearAllDownloads() => clearAllOfflineTracks();

  void _updateLibrarySyncStatus(
    String trackId,
    TrackSyncStatus status, {
    String? localPath,
  }) {
    try {
      final notifier = _ref.read(libraryTracksProvider.notifier);
      notifier.updateTrackSyncStatus(
        trackId,
        status,
        localAudioFilePath: localPath,
      );
    } catch (_) {}
  }
}

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../library/domain/models/library_models.dart';
import '../../../library/presentation/providers/library_providers.dart';
import '../../data/services/audio_download_service.dart';
import '../../data/services/offline_storage_service.dart';
import '../../domain/models/offline_models.dart';

/// Offline storage service dependency provider.
final offlineStorageServiceProvider = Provider<IOfflineStorageService>((ref) {
  final service = OfflineStorageService();
  service.init();
  return service;
});

/// Audio download service dependency provider.
/// Default enables simulated mode for reliable, fast local testing and offline emulation.
final audioDownloadServiceProvider = Provider<IAudioDownloadService>((ref) {
  return AudioDownloadService(simulateDownloads: true);
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

  // Each studio-quality cached audio master averages ~8.5 MB
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
  OfflinePreferencesNotifier() : super(const OfflinePreferenceState());

  void toggleOfflineMode() {
    state = state.copyWith(isOfflineModeForced: !state.isOfflineModeForced);
  }

  void setDownloadQuality(AudioDownloadQuality quality) {
    state = state.copyWith(downloadQuality: quality);
  }

  void toggleWifiOnly() {
    state = state.copyWith(wifiOnlyDownload: !state.wifiOnlyDownload);
  }

  void setStorageLimitBytes(int bytes) {
    state = state.copyWith(storageLimitBytes: bytes);
  }
}

class DownloadManagerNotifier extends StateNotifier<Map<String, DownloadTask>> {
  final Ref _ref;
  final IOfflineStorageService _storageService;
  final IAudioDownloadService _downloadService;

  DownloadManagerNotifier(
    this._ref,
    this._storageService,
    this._downloadService,
  ) : super({});

  /// Returns total number of active downloads in progress or queued.
  int get activeDownloadsCount =>
      state.values.where((task) => task.isActive).length;

  /// Initiates or queues an offline download for the given vault track.
  Future<void> downloadTrack(
    LibraryTrack track, {
    AudioDownloadQuality quality = AudioDownloadQuality.mp3HighQuality,
  }) async {
    // If already downloading or queued, avoid duplicate trigger
    final existing = state[track.id];
    if (existing != null && existing.isActive) return;

    final dir = await _storageService.resolveVaultAudioDirectory();
    final localPath = '$dir/${track.id}.${quality.fileExtension}';

    // 1. Immediately register task in queued state
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

    // Update vault track syncStatus to downloading
    _ref
        .read(libraryTracksProvider.notifier)
        .setSyncStatus(track.id, TrackSyncStatus.downloading);

    // 2. Transition to downloading
    state = {
      ...state,
      track.id: task.copyWith(status: DownloadStatus.downloading),
    };

    try {
      final totalBytes = await _downloadService.downloadFile(
        trackId: track.id,
        remoteUrl: track.remoteAudioUrl,
        destinationPath: localPath,
        onProgress: (received, total) {
          final current = state[track.id];
          if (current != null && current.status == DownloadStatus.downloading) {
            final progress = total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;
            state = {
              ...state,
              track.id: current.copyWith(
                progress: progress,
                receivedBytes: received,
                totalBytes: total,
              ),
            };
          }
        },
      );

      // 3. Mark completed in task registry
      final completedTask = state[track.id]?.copyWith(
            status: DownloadStatus.completed,
            progress: 1.0,
            receivedBytes: totalBytes,
            totalBytes: totalBytes,
            completedAt: DateTime.now(),
          ) ??
          task.copyWith(status: DownloadStatus.completed, progress: 1.0);

      state = {...state, track.id: completedTask};

      // 4. Persist metadata to Hive storage service
      await _storageService.saveTrackMetadata(
        track: track,
        localPath: localPath,
        fileSizeBytes: totalBytes,
      );

      // 5. Update vault track to cachedLocally
      _ref
          .read(libraryTracksProvider.notifier)
          .setTrackOfflinePath(track.id, localPath);
    } catch (e) {
      // If error or cancellation occurs
      final failedTask = state[track.id]?.copyWith(
            status: DownloadStatus.failed,
            errorMessage: e.toString(),
          ) ??
          task.copyWith(
            status: DownloadStatus.failed,
            errorMessage: e.toString(),
          );

      state = {...state, track.id: failedTask};

      _ref
          .read(libraryTracksProvider.notifier)
          .setSyncStatus(track.id, TrackSyncStatus.error);
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

    _ref
        .read(libraryTracksProvider.notifier)
        .setSyncStatus(trackId, TrackSyncStatus.cloudOnly);
  }

  /// Retries a previously failed or idle download.
  Future<void> retryDownload(LibraryTrack track) async {
    await downloadTrack(track);
  }

  /// Evicts the local cached file from disk, removes Hive metadata,
  /// and returns vault track back to cloudOnly status.
  Future<void> removeOfflineTrack(String trackId) async {
    await _storageService.removeTrackMetadata(trackId);

    // Remove from task state or mark idle
    final updated = Map<String, DownloadTask>.from(state)..remove(trackId);
    state = updated;

    _ref.read(libraryTracksProvider.notifier).clearTrackOfflinePath(trackId);
  }

  /// Purges all downloaded audio files from disk, clears Hive metadata,
  /// and updates all vault tracks to cloudOnly status.
  Future<void> clearAllOfflineTracks() async {
    await _storageService.clearAllMetadata();
    state = {};

    final tracks = _ref.read(libraryTracksProvider);
    for (final track in tracks) {
      if (track.syncStatus == TrackSyncStatus.cachedLocally) {
        _ref
            .read(libraryTracksProvider.notifier)
            .clearTrackOfflinePath(track.id);
      }
    }
  }
}

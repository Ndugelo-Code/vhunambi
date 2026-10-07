# Phase 8 Design: Offline Audio Persistence & Hive Cache

> **Target Package:** `apps/vhunambi_client`  
> **Parent Blueprint:** [`docs/foundation_blueprints/04_LIBRARY_VAULT_SPEC.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/foundation_blueprints/04_LIBRARY_VAULT_SPEC.md) §5  
> **Requirements Reference:** [`docs/phases/phase_08_offline_cache/requirements.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_08_offline_cache/requirements.md)  

---

## 1. Domain Models (`lib/features/offline/domain/models/offline_models.dart`)

```dart
enum DownloadStatus {
  idle,
  queued,
  downloading,
  paused,
  completed,
  failed,
}

enum AudioDownloadQuality {
  mp3HighQuality,  // 320 kbps MP3
  wavLossless,     // 24-bit Lossless WAV
}

@immutable
class DownloadTask {
  final String trackId;
  final String title;
  final String creatorName;
  final String genre;
  final String remoteAudioUrl;
  final String? localAudioFilePath;
  final double progress; // 0.0 to 1.0
  final DownloadStatus status;
  final int receivedBytes;
  final int totalBytes;
  final String? errorMessage;
  final DateTime startedAt;
  final DateTime? completedAt;

  const DownloadTask({
    required this.trackId,
    required this.title,
    required this.creatorName,
    required this.genre,
    required this.remoteAudioUrl,
    this.localAudioFilePath,
    this.progress = 0.0,
    this.status = DownloadStatus.idle,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.errorMessage,
    required this.startedAt,
    this.completedAt,
  });

  bool get isActive => status == DownloadStatus.queued || status == DownloadStatus.downloading;
  bool get isCompleted => status == DownloadStatus.completed;
  bool get isFailed => status == DownloadStatus.failed;

  DownloadTask copyWith({...});
}

@immutable
class CacheStorageStats {
  final int totalBytesUsed;
  final int cachedTrackCount;
  final int storageLimitBytes;

  const CacheStorageStats({
    this.totalBytesUsed = 0,
    this.cachedTrackCount = 0,
    this.storageLimitBytes = 5 * 1024 * 1024 * 1024, // 5 GB
  });

  double get quotaUsagePercentage =>
      storageLimitBytes == 0 ? 0.0 : (totalBytesUsed / storageLimitBytes).clamp(0.0, 1.0);

  String get formattedBytesUsed {
    if (totalBytesUsed < 1024) return '$totalBytesUsed B';
    if (totalBytesUsed < 1024 * 1024) return '${(totalBytesUsed / 1024).toStringAsFixed(1)} KB';
    if (totalBytesUsed < 1024 * 1024 * 1024) return '${(totalBytesUsed / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(totalBytesUsed / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String get formattedStorageLimit {
    return '${(storageLimitBytes / (1024 * 1024 * 1024)).toStringAsFixed(0)} GB';
  }
}

@immutable
class OfflinePreferenceState {
  final bool isOfflineModeForced;
  final AudioDownloadQuality downloadQuality;
  final bool wifiOnlyDownload;
  final int storageLimitBytes;

  const OfflinePreferenceState({
    this.isOfflineModeForced = false,
    this.downloadQuality = AudioDownloadQuality.mp3HighQuality,
    this.wifiOnlyDownload = true,
    this.storageLimitBytes = 5 * 1024 * 1024 * 1024,
  });

  OfflinePreferenceState copyWith({...});
}
```

---

## 2. Service Layer Contracts

### 2.1 `OfflineStorageService`
```dart
abstract class IOfflineStorageService {
  Future<void> init();
  Future<void> saveTrackMetadata(LibraryTrack track, int fileSizeBytes);
  Future<Map<String, dynamic>?> getTrackMetadata(String trackId);
  Future<List<Map<String, dynamic>>> getAllCachedMetadata();
  Future<void> removeTrackMetadata(String trackId);
  Future<void> clearAllMetadata();
  Future<int> getTotalCachedSizeBytes();
  Future<bool> isTrackCachedLocally(String trackId);
  Future<String> resolveVaultAudioDirectory();
}
```

### 2.2 `AudioDownloadService`
```dart
abstract class IAudioDownloadService {
  Future<void> downloadFile({
    required String remoteUrl,
    required String destinationPath,
    required void Function(int received, int total) onProgress,
  });
  Future<void> cancelDownload(String trackId);
}
```

---

## 3. Riverpod Providers (`lib/features/offline/presentation/providers/offline_providers.dart`)

```dart
final offlineStorageServiceProvider = Provider<IOfflineStorageService>((ref) {
  return OfflineStorageService();
});

final audioDownloadServiceProvider = Provider<IAudioDownloadService>((ref) {
  return AudioDownloadService();
});

final downloadManagerProvider =
    StateNotifierProvider<DownloadManagerNotifier, Map<String, DownloadTask>>((ref) {
  final storageService = ref.watch(offlineStorageServiceProvider);
  final downloadService = ref.watch(audioDownloadServiceProvider);
  return DownloadManagerNotifier(ref, storageService, downloadService);
});

final cacheStorageStatsProvider = Provider<CacheStorageStats>((ref) {
  final tracks = ref.watch(libraryTracksProvider);
  final cached = tracks.where((t) => t.syncStatus == TrackSyncStatus.cachedLocally).toList();
  // Compute total bytes from cached tracks or storage service
  ...
});

final offlinePreferencesProvider =
    StateNotifierProvider<OfflinePreferencesNotifier, OfflinePreferenceState>((ref) {
  return OfflinePreferencesNotifier();
});
```

---

## 4. UI Widgets & Integration

1. `VaultStorageModal` (`lib/features/offline/presentation/widgets/vault_storage_modal.dart`):
   - Shows progress bar, total size used, list of cached tracks with file size chip, and `Clear All Downloads` action button.
2. `OfflineIndicatorBadge` (`lib/features/offline/presentation/widgets/offline_indicator_badge.dart`):
   - Mini pill for cached tracks / offline status.
3. Updated `TrackActionsSheet`:
   - Live download progress or cached status.
4. Updated `LibraryTrackTile` & `LibraryTrackGridCard`:
   - Download progress indicator and cached badge.
5. Updated `ExpandedCockpitModal`:
   - Offline badge when playing from local cache.

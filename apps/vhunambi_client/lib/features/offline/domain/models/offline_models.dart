import 'package:flutter/foundation.dart';

/// Status lifecycle for an audio download task.
enum DownloadStatus {
  idle,
  queued,
  downloading,
  paused,
  completed,
  failed,
}

/// Available audio formats and bitrates for offline download.
enum AudioDownloadQuality {
  mp3HighQuality, // 320 kbps MP3 stereo
  wavLossless, // 24-bit Lossless WAV studio master
}

extension AudioDownloadQualityExtension on AudioDownloadQuality {
  String get label => switch (this) {
        AudioDownloadQuality.mp3HighQuality => 'MP3 (320 kbps)',
        AudioDownloadQuality.wavLossless => 'WAV (Lossless 24-bit)',
      };

  String get fileExtension => switch (this) {
        AudioDownloadQuality.mp3HighQuality => 'mp3',
        AudioDownloadQuality.wavLossless => 'wav',
      };
}

/// Immutable record tracking an active or completed download task.
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

  bool get isActive =>
      status == DownloadStatus.queued || status == DownloadStatus.downloading;

  bool get isCompleted => status == DownloadStatus.completed;

  bool get isFailed => status == DownloadStatus.failed;

  bool get isPaused => status == DownloadStatus.paused;

  String get formattedProgressPercentage =>
      '${(progress * 100).clamp(0, 100).toInt()}%';

  String get formattedBytesProgress {
    if (totalBytes <= 0) return _formatBytes(receivedBytes);
    return '${_formatBytes(receivedBytes)} / ${_formatBytes(totalBytes)}';
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  DownloadTask copyWith({
    String? trackId,
    String? title,
    String? creatorName,
    String? genre,
    String? remoteAudioUrl,
    String? localAudioFilePath,
    double? progress,
    DownloadStatus? status,
    int? receivedBytes,
    int? totalBytes,
    String? errorMessage,
    DateTime? startedAt,
    DateTime? completedAt,
    bool clearError = false,
  }) {
    return DownloadTask(
      trackId: trackId ?? this.trackId,
      title: title ?? this.title,
      creatorName: creatorName ?? this.creatorName,
      genre: genre ?? this.genre,
      remoteAudioUrl: remoteAudioUrl ?? this.remoteAudioUrl,
      localAudioFilePath: localAudioFilePath ?? this.localAudioFilePath,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadTask &&
          runtimeType == other.runtimeType &&
          trackId == other.trackId &&
          status == other.status &&
          progress == other.progress &&
          receivedBytes == other.receivedBytes &&
          totalBytes == other.totalBytes;

  @override
  int get hashCode => Object.hash(trackId, status, progress, receivedBytes, totalBytes);
}

/// Aggregated storage statistics and quota usage across locally cached vault audio.
@immutable
class CacheStorageStats {
  final int totalBytesUsed;
  final int cachedTrackCount;
  final int storageLimitBytes;

  const CacheStorageStats({
    this.totalBytesUsed = 0,
    this.cachedTrackCount = 0,
    this.storageLimitBytes = 5 * 1024 * 1024 * 1024, // 5 GB default ceiling
  });

  double get quotaUsagePercentage => storageLimitBytes == 0
      ? 0.0
      : (totalBytesUsed / storageLimitBytes).clamp(0.0, 1.0);

  int get remainingBytes =>
      (storageLimitBytes - totalBytesUsed).clamp(0, storageLimitBytes);

  String get formattedBytesUsed => formatBytes(totalBytesUsed);

  String get formattedRemainingBytes => formatBytes(remainingBytes);

  String get formattedStorageLimit => formatBytes(storageLimitBytes);

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  CacheStorageStats copyWith({
    int? totalBytesUsed,
    int? cachedTrackCount,
    int? storageLimitBytes,
  }) {
    return CacheStorageStats(
      totalBytesUsed: totalBytesUsed ?? this.totalBytesUsed,
      cachedTrackCount: cachedTrackCount ?? this.cachedTrackCount,
      storageLimitBytes: storageLimitBytes ?? this.storageLimitBytes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CacheStorageStats &&
          runtimeType == other.runtimeType &&
          totalBytesUsed == other.totalBytesUsed &&
          cachedTrackCount == other.cachedTrackCount &&
          storageLimitBytes == other.storageLimitBytes;

  @override
  int get hashCode => Object.hash(totalBytesUsed, cachedTrackCount, storageLimitBytes);
}

/// Configurable user preferences governing offline storage and downloads.
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

  OfflinePreferenceState copyWith({
    bool? isOfflineModeForced,
    AudioDownloadQuality? downloadQuality,
    bool? wifiOnlyDownload,
    int? storageLimitBytes,
  }) {
    return OfflinePreferenceState(
      isOfflineModeForced: isOfflineModeForced ?? this.isOfflineModeForced,
      downloadQuality: downloadQuality ?? this.downloadQuality,
      wifiOnlyDownload: wifiOnlyDownload ?? this.wifiOnlyDownload,
      storageLimitBytes: storageLimitBytes ?? this.storageLimitBytes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OfflinePreferenceState &&
          runtimeType == other.runtimeType &&
          isOfflineModeForced == other.isOfflineModeForced &&
          downloadQuality == other.downloadQuality &&
          wifiOnlyDownload == other.wifiOnlyDownload &&
          storageLimitBytes == other.storageLimitBytes;

  @override
  int get hashCode => Object.hash(
        isOfflineModeForced,
        downloadQuality,
        wifiOnlyDownload,
        storageLimitBytes,
      );
}

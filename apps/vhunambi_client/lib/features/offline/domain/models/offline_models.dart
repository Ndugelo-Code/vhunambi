import 'package:flutter/foundation.dart';

/// Status lifecycle for an audio download task.
enum DownloadStatus {
  idle,
  queued,
  downloading,
  paused,
  retrying,
  verifying,
  completed,
  failed,
}

/// Backward-compatible alias for Phase 8 requirements.
typedef DownloadTaskStatus = DownloadStatus;

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
  final double bytesPerSecond;
  final int etaSeconds;
  final int retryCount;
  final String? errorMessage;
  final DateTime startedAt;
  final DateTime? completedAt;

  const DownloadTask({
    required this.trackId,
    required this.title,
    required this.creatorName,
    this.genre = 'Amapiano',
    required this.remoteAudioUrl,
    this.localAudioFilePath,
    this.progress = 0.0,
    this.status = DownloadStatus.idle,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.bytesPerSecond = 0.0,
    this.etaSeconds = 0,
    this.retryCount = 0,
    this.errorMessage,
    DateTime? startedAt,
    this.completedAt,
  }) : startedAt = startedAt ?? const _ConstDateTime();

  /// Alias for local file path.
  String get localFilePath => localAudioFilePath ?? '';

  bool get isActive =>
      status == DownloadStatus.queued ||
      status == DownloadStatus.downloading ||
      status == DownloadStatus.retrying ||
      status == DownloadStatus.verifying;

  bool get isCompleted => status == DownloadStatus.completed;

  bool get isFailed => status == DownloadStatus.failed;

  bool get isPaused => status == DownloadStatus.paused;

  String get formattedProgressPercentage =>
      '${(progress * 100).clamp(0, 100).toInt()}%';

  String get formattedSpeed {
    if (bytesPerSecond <= 0) return '0 KB/s';
    if (bytesPerSecond >= 1048576) {
      return '${(bytesPerSecond / 1048576).toStringAsFixed(1)} MB/s';
    }
    return '${(bytesPerSecond / 1024).toStringAsFixed(0)} KB/s';
  }

  String get formattedEta {
    if (etaSeconds <= 0 || !isActive) return '';
    if (etaSeconds < 60) return '${etaSeconds}s remaining';
    final mins = etaSeconds ~/ 60;
    final secs = etaSeconds % 60;
    return '${mins}m ${secs}s remaining';
  }

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
    double? bytesPerSecond,
    int? etaSeconds,
    int? retryCount,
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
      bytesPerSecond: bytesPerSecond ?? this.bytesPerSecond,
      etaSeconds: etaSeconds ?? this.etaSeconds,
      retryCount: retryCount ?? this.retryCount,
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
          totalBytes == other.totalBytes &&
          retryCount == other.retryCount;

  @override
  int get hashCode => Object.hash(trackId, status, progress, receivedBytes, totalBytes, retryCount);
}

class _ConstDateTime implements DateTime {
  const _ConstDateTime();
  @override
  bool isAfter(DateTime other) => false;
  @override
  bool isBefore(DateTime other) => false;
  @override
  bool isAtSameMomentAs(DateTime other) => false;
  @override
  int compareTo(DateTime other) => 0;
  @override
  int get millisecondsSinceEpoch => 0;
  @override
  int get microsecondsSinceEpoch => 0;
  @override
  String toIso8601String() => '1970-01-01T00:00:00.000Z';
  @override
  DateTime toLocal() => DateTime.fromMillisecondsSinceEpoch(0);
  @override
  DateTime toUtc() => DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  @override
  String get timeZoneName => 'UTC';
  @override
  Duration get timeZoneOffset => Duration.zero;
  @override
  int get year => 1970;
  @override
  int get month => 1;
  @override
  int get day => 1;
  @override
  int get hour => 0;
  @override
  int get minute => 0;
  @override
  int get second => 0;
  @override
  int get millisecond => 0;
  @override
  int get microsecond => 0;
  @override
  int get weekday => 4;
  @override
  bool get isUtc => true;
  @override
  DateTime add(Duration duration) => DateTime.fromMillisecondsSinceEpoch(duration.inMilliseconds);
  @override
  DateTime subtract(Duration duration) => DateTime.fromMillisecondsSinceEpoch(-duration.inMilliseconds);
  @override
  Duration difference(DateTime other) => Duration.zero;
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

  bool get downloadWifiOnly => wifiOnlyDownload;

  OfflinePreferenceState copyWith({
    bool? isOfflineModeForced,
    AudioDownloadQuality? downloadQuality,
    bool? wifiOnlyDownload,
    bool? downloadWifiOnly,
    int? storageLimitBytes,
  }) {
    return OfflinePreferenceState(
      isOfflineModeForced: isOfflineModeForced ?? this.isOfflineModeForced,
      downloadQuality: downloadQuality ?? this.downloadQuality,
      wifiOnlyDownload: downloadWifiOnly ?? wifiOnlyDownload ?? this.wifiOnlyDownload,
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

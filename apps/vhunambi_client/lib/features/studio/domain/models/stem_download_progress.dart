import 'package:flutter/foundation.dart';

/// Progress tick emitted while the studio master MP3 is streamed to the device
/// (T10.5).
@immutable
class StemDownloadProgress {
  final String url;
  final int receivedBytes;
  final int totalBytes;

  /// Absolute path of the materialised file once the transfer completes.
  final String? localPath;

  final String? error;

  const StemDownloadProgress({
    required this.url,
    required this.receivedBytes,
    required this.totalBytes,
    this.localPath,
    this.error,
  });

  /// `0.0` when the server never advertised a content length.
  double get progress => totalBytes > 0 ? receivedBytes / totalBytes : 0.0;

  bool get isComplete => localPath != null;

  bool get hasError => error != null;

  StemDownloadProgress copyWith({
    String? url,
    int? receivedBytes,
    int? totalBytes,
    String? localPath,
    String? error,
  }) {
    return StemDownloadProgress(
      url: url ?? this.url,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      localPath: localPath ?? this.localPath,
      error: error ?? this.error,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StemDownloadProgress &&
          runtimeType == other.runtimeType &&
          url == other.url &&
          receivedBytes == other.receivedBytes &&
          totalBytes == other.totalBytes &&
          localPath == other.localPath &&
          error == other.error;

  @override
  int get hashCode =>
      Object.hash(url, receivedBytes, totalBytes, localPath, error);

  @override
  String toString() =>
      'StemDownloadProgress($url, $receivedBytes/$totalBytes, '
      'localPath: $localPath, error: $error)';
}

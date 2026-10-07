import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';

abstract class IAudioDownloadService {
  Future<int> downloadFile({
    required String trackId,
    required String remoteUrl,
    required String destinationPath,
    required void Function(int received, int total) onProgress,
  });

  Future<void> cancelDownload(String trackId);
}

/// Download service supporting streaming network transfers via Dio
/// and deterministic simulated transfers for tests and demo environments.
class AudioDownloadService implements IAudioDownloadService {
  final Dio _dio;
  final Map<String, CancelToken> _cancelTokens = {};
  final bool simulateDownloads;

  AudioDownloadService({
    Dio? dio,
    this.simulateDownloads = false,
  }) : _dio = dio ?? Dio();

  @override
  Future<int> downloadFile({
    required String trackId,
    required String remoteUrl,
    required String destinationPath,
    required void Function(int received, int total) onProgress,
  }) async {
    final cancelToken = CancelToken();
    _cancelTokens[trackId] = cancelToken;

    // Check if network simulation should be used (e.g., in unit tests or mock urls)
    if (simulateDownloads || remoteUrl.isEmpty || remoteUrl.startsWith('test://') || remoteUrl.startsWith('mock://')) {
      return _runSimulatedDownload(
        trackId: trackId,
        destinationPath: destinationPath,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    }

    try {
      int totalBytes = 0;
      final response = await _dio.download(
        remoteUrl,
        destinationPath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          totalBytes = total;
          onProgress(received, total > 0 ? total : 8000000);
        },
      );

      _cancelTokens.remove(trackId);
      if (response.statusCode == 200 || response.statusCode == 206) {
        return totalBytes > 0 ? totalBytes : 8388608; // ~8MB default
      }
      throw Exception('Failed to download audio file: HTTP ${response.statusCode}');
    } catch (e) {
      _cancelTokens.remove(trackId);
      if (CancelToken.isCancel(e as DioException)) {
        // Clean up partial file on cancel
        try {
          final file = File(destinationPath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {}
        throw Exception('Download cancelled by user.');
      }
      rethrow;
    }
  }

  @override
  Future<void> cancelDownload(String trackId) async {
    final token = _cancelTokens.remove(trackId);
    if (token != null && !token.isCancelled) {
      token.cancel('User cancelled download');
    }
  }

  /// Deterministic simulated download executing progress steps without external network dependency.
  Future<int> _runSimulatedDownload({
    required String trackId,
    required String destinationPath,
    required void Function(int received, int total) onProgress,
    required CancelToken cancelToken,
  }) async {
    const totalBytes = 8500000; // ~8.5 MB
    const steps = 4;
    const stepBytes = totalBytes ~/ steps;

    for (int i = 1; i <= steps; i++) {
      if (cancelToken.isCancelled) {
        _cancelTokens.remove(trackId);
        throw Exception('Download cancelled by user.');
      }

      await Future<void>.delayed(const Duration(milliseconds: 30));

      if (cancelToken.isCancelled) {
        _cancelTokens.remove(trackId);
        throw Exception('Download cancelled by user.');
      }

      final received = (stepBytes * i).clamp(0, totalBytes);
      onProgress(received, totalBytes);
    }

    _cancelTokens.remove(trackId);

    // Write empty binary file placeholder if local filesystem is accessible
    try {
      final file = File(destinationPath);
      await file.parent.create(recursive: true);
      if (!await file.exists()) {
        await file.writeAsBytes(List.filled(1024, 0));
      }
    } catch (_) {}

    return totalBytes;
  }
}

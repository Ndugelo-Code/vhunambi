import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/models/stem_download_progress.dart';
import '../../domain/services/i_stem_download_service.dart';

/// Streams rendered studio masters onto the device (T10.5).
///
/// Uses the project's existing `dio` client (Phase 8 dependency) to stream the
/// MP3 into `<temp>/vhunambi_downloads/<file>` while emitting
/// [StemDownloadProgress] ticks. Every failure is surfaced as an error tick —
/// the service never throws into the pipeline FSM.
class StemDownloadService implements IStemDownloadService {
  static const String downloadDirectoryName = 'vhunambi_downloads';

  final Dio _dio;
  final Directory Function()? directoryOverride;
  final Map<String, CancelToken> _cancelTokens = <String, CancelToken>{};

  StemDownloadService({Dio? dio, this.directoryOverride}) : _dio = dio ?? Dio();

  /// Resolves the download directory (overridable for manual QA builds).
  Future<Directory> resolveDownloadDirectory() async {
    final override = directoryOverride;
    if (override != null) return override();

    final tempDir = await getTemporaryDirectory();
    final directory = Directory('${tempDir.path}/$downloadDirectoryName');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  /// Deterministic file name for a master url.
  static String fileNameForUrl(String url) {
    final path = Uri.tryParse(url)?.path ?? url;
    final trimmed =
        path.endsWith('/') ? path.substring(0, path.length - 1) : path;
    final lastSlash = trimmed.lastIndexOf('/');
    final segment =
        lastSlash >= 0 ? trimmed.substring(lastSlash + 1) : trimmed;

    if (segment.isEmpty) return 'master.mp3';
    return segment.contains('.') ? segment : '$segment.mp3';
  }

  /// Destination path for [url] inside [directory].
  static String destinationFor(Directory directory, String url) =>
      '${directory.path}/${fileNameForUrl(url)}';

  @override
  Stream<StemDownloadProgress> downloadMaster(String url) =>
      _download(url, isStemBundle: false);

  @override
  Stream<StemDownloadProgress> downloadStems(String url) =>
      _download(url, isStemBundle: true);

  Stream<StemDownloadProgress> _download(
    String url, {
    required bool isStemBundle,
  }) async* {
    final cancelToken = CancelToken();
    _cancelTokens[url] = cancelToken;

    IOSink? sink;
    try {
      final directory = await resolveDownloadDirectory();
      final destination = destinationFor(directory, url);

      final response = await _dio.get<ResponseBody>(
        url,
        cancelToken: cancelToken,
        options: Options(responseType: ResponseType.stream),
      );

      final body = response.data;
      if (body == null) {
        yield StemDownloadProgress(
          url: url,
          receivedBytes: 0,
          totalBytes: 0,
          error: 'Empty response body.',
        );
        return;
      }

      final advertisedTotal = body.contentLength > 0 ? body.contentLength : 0;
      yield StemDownloadProgress(
        url: url,
        receivedBytes: 0,
        totalBytes: advertisedTotal,
      );

      final file = File(destination);
      await file.parent.create(recursive: true);
      sink = file.openWrite();

      var received = 0;
      await for (final chunk in body.stream) {
        sink.add(chunk);
        received += chunk.length;
        yield StemDownloadProgress(
          url: url,
          receivedBytes: received,
          totalBytes: advertisedTotal > 0 ? advertisedTotal : received,
        );
      }

      await sink.flush();
      await sink.close();
      sink = null;

      yield StemDownloadProgress(
        url: url,
        receivedBytes: received,
        totalBytes: advertisedTotal > 0 ? advertisedTotal : received,
        localPath: destination,
      );
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        yield StemDownloadProgress(
          url: url,
          receivedBytes: 0,
          totalBytes: 0,
          error: 'Download cancelled.',
        );
      } else {
        yield StemDownloadProgress(
          url: url,
          receivedBytes: 0,
          totalBytes: 0,
          error: error.message ?? 'Download failed.',
        );
      }
    } catch (error) {
      yield StemDownloadProgress(
        url: url,
        receivedBytes: 0,
        totalBytes: 0,
        error: isStemBundle
            ? 'Stem bundle download failed: $error'
            : 'Master download failed: $error',
      );
    } finally {
      try {
        await sink?.close();
      } catch (error) {
        debugPrint('StemDownloadService sink close failed: $error');
      }
      _cancelTokens.remove(url);
    }
  }

  @override
  Future<void> cancelDownload(String url) async {
    final token = _cancelTokens.remove(url);
    if (token != null && !token.isCancelled) {
      token.cancel('User cancelled download');
    }
  }
}

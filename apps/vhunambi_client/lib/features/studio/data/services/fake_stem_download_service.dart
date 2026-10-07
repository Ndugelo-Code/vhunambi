import 'dart:async';

import '../../domain/models/stem_download_progress.dart';
import '../../domain/services/i_stem_download_service.dart';

/// Deterministic, IO-free stem downloader used by every studio test
/// (T10.5).
///
/// Emits exactly three ticks — 25 %, 75 %, 100 % — inside [stepDelay] and never
/// touches the network or the file system. Ships in production builds as the
/// offline/demo fallback.
class FakeStemDownloadService implements IStemDownloadService {
  FakeStemDownloadService({
    this.stepDelay = const Duration(milliseconds: 50),
    this.localPath = '/tmp/fake_track.mp3',
    this.totalBytes = 8500000,
  });

  /// Delay applied between the three emitted ticks.
  final Duration stepDelay;

  /// Path reported on the terminal tick.
  final String localPath;

  /// Advertised content length.
  final int totalBytes;

  final List<String> downloadedUrls = <String>[];
  final List<String> cancelledUrls = <String>[];

  @override
  Stream<StemDownloadProgress> downloadMaster(String url) =>
      _emit(url);

  @override
  Stream<StemDownloadProgress> downloadStems(String url) => _emit(url);

  Stream<StemDownloadProgress> _emit(String url) async* {
    downloadedUrls.add(url);

    yield StemDownloadProgress(
      url: url,
      receivedBytes: (totalBytes * 0.25).round(),
      totalBytes: totalBytes,
    );

    await Future<void>.delayed(stepDelay);
    yield StemDownloadProgress(
      url: url,
      receivedBytes: (totalBytes * 0.75).round(),
      totalBytes: totalBytes,
    );

    await Future<void>.delayed(stepDelay);
    yield StemDownloadProgress(
      url: url,
      receivedBytes: totalBytes,
      totalBytes: totalBytes,
      localPath: localPath,
    );
  }

  @override
  Future<void> cancelDownload(String url) async {
    cancelledUrls.add(url);
  }
}

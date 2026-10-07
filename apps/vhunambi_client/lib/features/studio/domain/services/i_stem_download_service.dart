import '../models/stem_download_progress.dart';

/// Contract for streaming rendered studio masters onto the device (T10.5).
abstract class IStemDownloadService {
  /// Streams the MP3 master at [url] into the device download directory.
  Stream<StemDownloadProgress> downloadMaster(String url);

  /// Streams the full stem bundle at [url] into the device download directory.
  Stream<StemDownloadProgress> downloadStems(String url);

  /// Aborts an in-flight transfer for [url].
  Future<void> cancelDownload(String url);
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/stem_download_service.dart';
import '../../domain/services/i_stem_download_service.dart';

/// Injectable stem downloader (T10.5).
///
/// Override with `FakeStemDownloadService` in tests so no HTTP transfer is ever
/// scheduled from the suite.
final stemDownloadServiceProvider = Provider<IStemDownloadService>(
  (ref) => StemDownloadService(),
);

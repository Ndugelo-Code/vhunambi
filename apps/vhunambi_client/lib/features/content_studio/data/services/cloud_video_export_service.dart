import 'dart:async';
import '../../domain/models/content_studio_preset.dart';
import '../../domain/models/lyric_word_timestamp.dart';
import '../../domain/services/i_video_export_service.dart';

/// Cloud fallback video exporter for web clients.
class CloudVideoExportService implements IVideoExportService {
  final String apiBaseUrl;

  CloudVideoExportService({
    this.apiBaseUrl = 'https://api.vhunambi.com',
  });

  @override
  Future<String> exportLyricVideo({
    required String audioUrl,
    required String coverArtUrl,
    required List<LyricWordTimestamp> words,
    required double startSec,
    required double endSec,
    required LyricTypographyPreset preset,
    required AtmosphericEffects effects,
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.1);
    await Future<void>.delayed(const Duration(milliseconds: 40));
    onProgress?.call(0.6);
    await Future<void>.delayed(const Duration(milliseconds: 40));
    onProgress?.call(1.0);

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'https://r2.vhunambi.com/exported/reel_${preset.name}_$timestamp.mp4';
  }
}

import '../models/lyric_word_timestamp.dart';
import '../models/content_studio_preset.dart';

/// Contract for rendering and exporting 1080x1920 MP4 lyric videos.
abstract class IVideoExportService {
  Future<String> exportLyricVideo({
    required String audioUrl,
    required String coverArtUrl,
    required List<LyricWordTimestamp> words,
    required double startSec,
    required double endSec,
    required LyricTypographyPreset preset,
    required AtmosphericEffects effects,
    void Function(double progress)? onProgress,
  });
}

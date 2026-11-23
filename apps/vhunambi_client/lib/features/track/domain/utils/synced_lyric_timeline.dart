/// Pure-Dart playback-to-lyric line synchronization helper (`REQ-P77-LYR-02`).
abstract final class SyncedLyricTimeline {
  /// Splits sanitized lyrics into non-empty displayable lines.
  static List<String> extractLines(String sanitizedLyrics) {
    return sanitizedLyrics
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
  }

  /// Resolves the 0-based active line index for [position] inside [duration].
  /// Returns `-1` when [lineCount] <= 0 or [duration] <= Duration.zero.
  static int resolveActiveLineIndex({
    required int lineCount,
    required Duration position,
    required Duration duration,
  }) {
    if (lineCount <= 0 || duration.inMilliseconds <= 0) return -1;
    final ratio = (position.inMilliseconds / duration.inMilliseconds).clamp(
      0.0,
      0.9999,
    );
    return (ratio * lineCount).floor().clamp(0, lineCount - 1);
  }

  /// Computes the playback seek target corresponding to tapping [lineIndex].
  static Duration seekTargetForLine({
    required int lineIndex,
    required int lineCount,
    required Duration duration,
  }) {
    if (lineCount <= 0 || duration.inMilliseconds <= 0) return Duration.zero;
    final clampedIdx = lineIndex.clamp(0, lineCount - 1);
    final ms = ((clampedIdx / lineCount) * duration.inMilliseconds).floor();
    return Duration(milliseconds: ms);
  }
}

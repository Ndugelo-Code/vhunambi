import 'dart:async';
import 'package:flutter/widgets.dart';

/// Progress telemetry emitted during offline frame rendering (REQ-VIDEO-RENDER-05).
@immutable
class VideoExportProgress {
  final double progress; // 0.0 to 1.0
  final int currentFrame;
  final int totalFrames;
  final double fps;
  final String status;

  const VideoExportProgress({
    required this.progress,
    required this.currentFrame,
    required this.totalFrames,
    this.fps = 30.0,
    this.status = 'Rendering frames...',
  });

  @override
  String toString() =>
      'VideoExportProgress(${((progress * 100).toInt())}%, frame $currentFrame/$totalFrames, $status)';
}

/// Abstract contract for deterministic offscreen video frame rendering.
abstract class IOfflineVideoFrameRenderer {
  /// Steps through an offscreen RepaintBoundary and renders frames deterministically.
  Future<String> renderVideo({
    required GlobalKey repaintBoundaryKey,
    required double startSec,
    required double endSec,
    required int fps,
    required String audioPath,
    required String outputPath,
    void Function(VideoExportProgress progress)? onProgress,
    bool Function()? isCancelled,
  });
}

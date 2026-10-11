import 'package:flutter/foundation.dart';

/// Video aspect ratio and resolution targets.
enum VideoExportResolution {
  vertical9x16('9:16 Kinetic Reel', 1080, 1920),
  square1x1('1:1 Cover Art Video', 1080, 1080);

  final String label;
  final int width;
  final int height;
  const VideoExportResolution(this.label, this.width, this.height);
}

/// Target social platforms for 1-tap direct syndication.
enum SocialShareTarget {
  tiktok('TikTok', '🎵'),
  instagramReels('Instagram Reels', '📸'),
  youtubeShorts('YouTube Shorts', '▶️'),
  cameraRoll('Save to Gallery', '💾');

  final String label;
  final String emoji;
  const SocialShareTarget(this.label, this.emoji);
}

/// Lifecycle status of the hardware video export job.
enum VideoExportStatus { idle, muxing, completed, failed }

/// Configuration specification for an offscreen hardware video rendering job.
@immutable
class VideoExportJob {
  final String id;
  final String title;
  final String creatorHandle;
  final String genre;
  final String audioPath;
  final VideoExportResolution resolution;
  final int fps; // 30 or 60
  final bool includeHolographicWatermark;
  final double durationSec;

  const VideoExportJob({
    required this.id,
    required this.title,
    required this.creatorHandle,
    required this.genre,
    required this.audioPath,
    this.resolution = VideoExportResolution.vertical9x16,
    this.fps = 60,
    this.includeHolographicWatermark = true,
    this.durationSec = 15.0,
  });

  VideoExportJob copyWith({
    VideoExportResolution? resolution,
    int? fps,
    bool? includeHolographicWatermark,
  }) {
    return VideoExportJob(
      id: id,
      title: title,
      creatorHandle: creatorHandle,
      genre: genre,
      audioPath: audioPath,
      resolution: resolution ?? this.resolution,
      fps: fps ?? this.fps,
      includeHolographicWatermark:
          includeHolographicWatermark ?? this.includeHolographicWatermark,
      durationSec: durationSec,
    );
  }
}

/// Immutable state of the Video Export & Direct Syndication engine.
@immutable
class VideoExportState {
  final VideoExportJob? activeJob;
  final VideoExportStatus status;
  final double progress; // 0.0 to 1.0
  final String? outputPath;
  final String? errorMessage;
  final String? generatedCaption;
  final SocialShareTarget? lastSharedTarget;

  const VideoExportState({
    this.activeJob,
    this.status = VideoExportStatus.idle,
    this.progress = 0.0,
    this.outputPath,
    this.errorMessage,
    this.generatedCaption,
    this.lastSharedTarget,
  });

  bool get isMuxing => status == VideoExportStatus.muxing;
  bool get isCompleted => status == VideoExportStatus.completed;

  VideoExportState copyWith({
    VideoExportJob? activeJob,
    VideoExportStatus? status,
    double? progress,
    String? outputPath,
    String? errorMessage,
    String? generatedCaption,
    SocialShareTarget? lastSharedTarget,
    bool clearError = false,
  }) {
    return VideoExportState(
      activeJob: activeJob ?? this.activeJob,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      outputPath: outputPath ?? this.outputPath,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      generatedCaption: generatedCaption ?? this.generatedCaption,
      lastSharedTarget: lastSharedTarget ?? this.lastSharedTarget,
    );
  }
}

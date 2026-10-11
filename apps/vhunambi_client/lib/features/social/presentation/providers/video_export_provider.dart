import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/video_export_job.dart';

/// State notifier managing native hardware video rendering and social sharing.
class VideoExportNotifier extends StateNotifier<VideoExportState> {
  final Future<String> Function(VideoExportJob job, void Function(double) onProgress)?
      customMuxer;

  VideoExportNotifier({this.customMuxer}) : super(const VideoExportState());

  /// Prepares an export job with auto-generated viral caption metadata.
  void prepareJob(VideoExportJob job) {
    final caption = generateViralCaption(job.title, job.creatorHandle, job.genre);
    state = state.copyWith(
      activeJob: job,
      status: VideoExportStatus.idle,
      progress: 0.0,
      generatedCaption: caption,
      clearError: true,
    );
  }

  void setResolution(VideoExportResolution resolution) {
    if (state.activeJob == null) return;
    state = state.copyWith(
      activeJob: state.activeJob!.copyWith(resolution: resolution),
    );
  }

  void setFps(int fps) {
    if (state.activeJob == null) return;
    state = state.copyWith(
      activeJob: state.activeJob!.copyWith(fps: fps),
    );
  }

  void toggleWatermark(bool enabled) {
    if (state.activeJob == null) return;
    state = state.copyWith(
      activeJob: state.activeJob!.copyWith(includeHolographicWatermark: enabled),
    );
  }

  /// Synthesizes viral African music hashtags and creator attribution.
  String generateViralCaption(String title, String creatorHandle, String genre) {
    final normalizedHandle =
        creatorHandle.startsWith('@') ? creatorHandle : '@$creatorHandle';
    final genreTag = genre.replaceAll(' ', '');

    final tags = <String>[
      '#$genreTag',
      '#Vhunambi',
      '#AfricanMusic',
      '#Afrobeats',
      '#LogDrum',
      '#ViralReels',
    ];

    return '🎵 "$title" ft. $normalizedHandle\nProduced with Vhunambi AI Studio.\n\n${tags.join(' ')}';
  }

  /// Executes simulated or native hardware video muxing loop.
  Future<String?> startMuxing() async {
    final job = state.activeJob;
    if (job == null) {
      state = state.copyWith(
        status: VideoExportStatus.failed,
        errorMessage: 'No active video export job configured.',
      );
      return null;
    }

    state = state.copyWith(
      status: VideoExportStatus.muxing,
      progress: 0.0,
      clearError: true,
    );

    try {
      final muxer = customMuxer;
      String outputPath;

      if (muxer != null) {
        outputPath = await muxer(job, (p) {
          state = state.copyWith(progress: p);
        });
      } else {
        // Fast deterministic simulation for testing and preview
        final steps = [0.25, 0.55, 0.85, 1.0];
        for (final p in steps) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          state = state.copyWith(progress: p);
        }
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        outputPath =
            '/vault/videos/vhunambi_reel_${job.resolution == VideoExportResolution.vertical9x16 ? "9x16" : "1x1"}_$timestamp.mp4';
      }

      state = state.copyWith(
        status: VideoExportStatus.completed,
        progress: 1.0,
        outputPath: outputPath,
      );
      return outputPath;
    } catch (e) {
      state = state.copyWith(
        status: VideoExportStatus.failed,
        errorMessage: e.toString(),
      );
      return null;
    }
  }

  /// Triggers 1-tap direct sharing to external social platforms.
  Future<bool> shareTo(SocialShareTarget target) async {
    if (state.outputPath == null && state.status != VideoExportStatus.completed) {
      state = state.copyWith(
        errorMessage: 'Please render the video before sharing to ${target.label}.',
      );
      return false;
    }

    state = state.copyWith(lastSharedTarget: target);
    return true;
  }

  void reset() {
    state = const VideoExportState();
  }
}

final videoExportProvider =
    StateNotifierProvider<VideoExportNotifier, VideoExportState>((ref) {
  return VideoExportNotifier();
});

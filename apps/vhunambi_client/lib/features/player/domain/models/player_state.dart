import 'package:flutter/foundation.dart';
import '../../../../shared/models/track.dart';

enum PlaybackStatus { idle, buffering, playing, paused, completed, error }
enum AudioRepeatMode { off, all, one }

@immutable
class PlayerState {
  final Track? currentTrack;
  final PlaybackStatus playbackStatus;
  final Duration position;
  final Duration duration;
  final Duration bufferedPosition;
  final List<Track> queue;
  final int currentIndex;
  final bool isShuffle;
  final AudioRepeatMode repeatMode;
  final double playbackSpeed;
  final double volume;
  final bool isExpanded;
  final String? errorMessage;

  const PlayerState({
    this.currentTrack,
    this.playbackStatus = PlaybackStatus.idle,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.bufferedPosition = Duration.zero,
    this.queue = const [],
    this.currentIndex = -1,
    this.isShuffle = false,
    this.repeatMode = AudioRepeatMode.off,
    this.playbackSpeed = 1.0,
    this.volume = 1.0,
    this.isExpanded = false,
    this.errorMessage,
  });

  bool get isPlaying => playbackStatus == PlaybackStatus.playing;
  bool get hasActiveTrack => currentTrack != null;

  double get progressRatio {
    if (duration.inMilliseconds == 0) return 0.0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  String get formattedPosition {
    final minutes = position.inMinutes;
    final seconds = position.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String get formattedDuration {
    if (currentTrack != null) return currentTrack!.formattedDuration;
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  PlayerState copyWith({
    Track? currentTrack,
    PlaybackStatus? playbackStatus,
    Duration? position,
    Duration? duration,
    Duration? bufferedPosition,
    List<Track>? queue,
    int? currentIndex,
    bool? isShuffle,
    AudioRepeatMode? repeatMode,
    double? playbackSpeed,
    double? volume,
    bool? isExpanded,
    String? errorMessage,
    bool clearTrack = false,
  }) {
    return PlayerState(
      currentTrack: clearTrack ? null : (currentTrack ?? this.currentTrack),
      playbackStatus: playbackStatus ?? this.playbackStatus,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      bufferedPosition: bufferedPosition ?? this.bufferedPosition,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      isShuffle: isShuffle ?? this.isShuffle,
      repeatMode: repeatMode ?? this.repeatMode,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      volume: volume ?? this.volume,
      isExpanded: isExpanded ?? this.isExpanded,
      errorMessage: errorMessage,
    );
  }
}

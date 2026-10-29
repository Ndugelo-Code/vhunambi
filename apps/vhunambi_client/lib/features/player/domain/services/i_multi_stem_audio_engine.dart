import 'dart:async';
import '../models/stem_mixer_state.dart';

/// Contract for multi-channel synchronized stem audio playback (REQ-STEM-AUDIO-01 .. 06).
abstract class IMultiStemAudioEngine {
  /// Stream of playback state changes (playing vs paused).
  Stream<bool> get isPlayingStream;

  /// Stream of current synchronized playback position.
  Stream<Duration> get positionStream;

  /// Current playback position.
  Duration get currentPosition;

  /// Total duration of loaded stems.
  Duration get totalDuration;

  /// Whether the engine is currently playing.
  bool get isPlaying;

  /// Whether real stems are loaded. When false, the engine is in master-only mode
  /// and per-stem gain/mute/solo have no audible effect.
  bool get hasRealStems;

  /// Most recent measured inter-channel drift (null in master-only mode).
  Duration? get measuredDrift;

  /// Loads stem audio sources from the Master Media Object (MMO) manifest.
  /// If [stemUrls] is empty or does not contain all required stems, the engine
  /// gracefully falls back to [masterUrl] in master-only mode.
  Future<void> loadFromManifest({
    required Map<StemType, String> stemUrls,
    required String masterUrl,
  });

  /// Starts synchronized playback on all active unmuted channels.
  Future<void> play();

  /// Pauses playback on all channels while preserving exact position.
  Future<void> pause();

  /// Seeks all stem channels to the specified position simultaneously.
  Future<void> seek(Duration position);

  /// Synchronizes volume and mute states from the [StemMixerState] matrix.
  void applyMixerState(StemMixerState state);

  /// Cleans up players and releases audio session resources.
  Future<void> dispose();
}

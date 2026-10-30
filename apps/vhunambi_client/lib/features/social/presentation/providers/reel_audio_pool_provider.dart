import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/reel_audio_pool_service.dart';
import '../../domain/models/published_clip.dart';
import '../../../player/presentation/providers/player_provider.dart';

/// Immutable state of the 3-Slot Recycled Reel Audio Controller Pool (Phase A).
@immutable
class ReelAudioPoolState {
  final int activeIndex;
  final String? activeClipId;
  final bool isPlaying;
  final double playbackPositionSec;
  final double cycleDurationSec;
  final Set<int> pooledIndices;
  final bool wasGlobalPlayerDucked;

  const ReelAudioPoolState({
    this.activeIndex = 0,
    this.activeClipId,
    this.isPlaying = true,
    this.playbackPositionSec = 0.0,
    this.cycleDurationSec = 15.0,
    this.pooledIndices = const <int>{},
    this.wasGlobalPlayerDucked = false,
  });

  ReelAudioPoolState copyWith({
    int? activeIndex,
    String? activeClipId,
    bool? isPlaying,
    double? playbackPositionSec,
    double? cycleDurationSec,
    Set<int>? pooledIndices,
    bool? wasGlobalPlayerDucked,
  }) {
    return ReelAudioPoolState(
      activeIndex: activeIndex ?? this.activeIndex,
      activeClipId: activeClipId ?? this.activeClipId,
      isPlaying: isPlaying ?? this.isPlaying,
      playbackPositionSec: playbackPositionSec ?? this.playbackPositionSec,
      cycleDurationSec: cycleDurationSec ?? this.cycleDurationSec,
      pooledIndices: pooledIndices ?? this.pooledIndices,
      wasGlobalPlayerDucked:
          wasGlobalPlayerDucked ?? this.wasGlobalPlayerDucked,
    );
  }
}

final reelAudioPoolServiceProvider = Provider<IReelAudioPoolService>((ref) {
  final service = RealReelAudioPoolService();
  ref.onDispose(service.dispose);
  return service;
});

/// Coordinates the 3-slot reel audio pool (`Index - 1`, `Index`, `Index + 1`)
/// and arbitrates audio focus against the global `playerStateProvider`
/// (ducks/pauses the background mini-player on reel entry and restores on exit).
class ReelAudioPoolNotifier extends StateNotifier<ReelAudioPoolState> {
  final IReelAudioPoolService _poolService;
  final PlayerNotifier? _globalPlayer;

  ReelAudioPoolNotifier(this._poolService, [this._globalPlayer])
    : super(const ReelAudioPoolState());

  /// Enters a full-screen Kinetic Reels session:
  /// 1. Ducks/pauses the global background player if it was actively playing.
  /// 2. Allocates the 3-slot window `{initialIndex - 1, initialIndex, initialIndex + 1}`.
  /// 3. Starts hardware playback and 60 FPS lyric/MMO synchronization on `initialIndex`.
  Future<void> enterReelsSession(
    List<PublishedClip> clips, {
    int initialIndex = 0,
  }) async {
    if (!mounted || clips.isEmpty) return;

    var duckedGlobal = false;
    final global = _globalPlayer;
    if (global != null && global.state.isPlaying) {
      global.pause();
      duckedGlobal = true;
    }

    final clamped = initialIndex.clamp(0, clips.length - 1);
    final activeClip = clips[clamped];
    final cycleSec = RealReelAudioPoolService.resolveCycleDurationSec(
      activeClip,
    );

    await _poolService.activateWindow(
      clips: clips,
      activeIndex: clamped,
      autoPlay: true,
      onStateTick: _handlePoolStateTick,
    );

    if (!mounted) return;
    state = state.copyWith(
      activeIndex: clamped,
      activeClipId: activeClip.id,
      isPlaying: _poolService.isPlaying,
      playbackPositionSec: _poolService.currentPositionSec,
      cycleDurationSec: cycleSec,
      pooledIndices: _poolService.pooledIndices,
      wasGlobalPlayerDucked: duckedGlobal || state.wasGlobalPlayerDucked,
    );
  }

  /// Shifts the 3-slot pool window when the user swipes vertically to [newIndex].
  /// Immediately evicts any slot outside `[newIndex - 1, newIndex + 1]`.
  Future<void> onPageChanged(int newIndex, List<PublishedClip> clips) async {
    if (!mounted || clips.isEmpty) return;
    final clamped = newIndex.clamp(0, clips.length - 1);
    final activeClip = clips[clamped];
    final cycleSec = RealReelAudioPoolService.resolveCycleDurationSec(
      activeClip,
    );

    await _poolService.activateWindow(
      clips: clips,
      activeIndex: clamped,
      autoPlay: true,
      onStateTick: _handlePoolStateTick,
    );

    if (!mounted) return;
    state = state.copyWith(
      activeIndex: clamped,
      activeClipId: activeClip.id,
      isPlaying: _poolService.isPlaying,
      playbackPositionSec: 0.0,
      cycleDurationSec: cycleSec,
      pooledIndices: _poolService.pooledIndices,
    );
  }

  void _handlePoolStateTick(double positionSec, bool isPlaying) {
    if (!mounted) return;
    state = state.copyWith(
      playbackPositionSec: positionSec,
      isPlaying: isPlaying,
      pooledIndices: _poolService.pooledIndices,
    );
  }

  /// Toggles play/pause on the active reel slot.
  Future<void> togglePlayPause() async {
    if (!mounted) return;
    final playing = await _poolService.togglePlayPause();
    if (!mounted) return;
    state = state.copyWith(isPlaying: playing);
  }

  /// Explicitly pauses active reel playback.
  Future<void> pause() async {
    if (!mounted) return;
    await _poolService.pause();
    if (!mounted) return;
    state = state.copyWith(isPlaying: false);
  }

  /// Explicitly resumes active reel playback.
  Future<void> resume() async {
    if (!mounted) return;
    await _poolService.resume();
    if (!mounted) return;
    state = state.copyWith(isPlaying: true);
  }

  /// Seeks the active reel to [positionSec] and synchronizes the kinetic canvas.
  Future<void> seekTo(double positionSec) async {
    if (!mounted) return;
    await _poolService.seek(positionSec);
    if (!mounted) return;
    state = state.copyWith(
      playbackPositionSec: _poolService.currentPositionSec,
    );
  }

  /// Stops all pooled reel players and restores the global background player
  /// if it was ducked upon entering the reels modal.
  Future<void> exitReelsSession() async {
    final shouldRestoreGlobal = mounted ? state.wasGlobalPlayerDucked : false;
    final global = _globalPlayer;
    if (shouldRestoreGlobal && global != null && global.mounted) {
      global.resume();
    }
    await _poolService.stopAll();
    if (!mounted) return;
    state = const ReelAudioPoolState(
      isPlaying: false,
      playbackPositionSec: 0.0,
      pooledIndices: <int>{},
      wasGlobalPlayerDucked: false,
    );
  }
}

final reelAudioPoolProvider =
    StateNotifierProvider<ReelAudioPoolNotifier, ReelAudioPoolState>((ref) {
      final service = ref.watch(reelAudioPoolServiceProvider);
      final globalPlayer = ref.read(playerStateProvider.notifier);
      return ReelAudioPoolNotifier(service, globalPlayer);
    });

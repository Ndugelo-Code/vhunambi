import 'dart:async';
import 'package:audio_service/audio_service.dart' show MediaItem, PlaybackState;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/track.dart';
import '../../../playlists/domain/models/playlist_entity.dart';
import '../../data/services/vhunambi_audio_handler.dart';
import '../../domain/models/player_state.dart';
import 'audio_bridge_providers.dart';

final playerStateProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  return PlayerNotifier(audioHandler: ref.watch(audioHandlerProvider));
});

class PlayerNotifier extends StateNotifier<PlayerState> {
  /// Hardware position deltas smaller than this are treated as the UI ticker's
  /// own interpolation; larger deltas are engine-authoritative (lockscreen seek).
  static const Duration hardwareSeekThreshold = Duration(milliseconds: 1500);

  Timer? _positionTimer;
  final IVhunambiAudioHandler _audioHandler;

  /// `true` when this notifier created the handler and must therefore dispose it.
  final bool _ownsHandler;

  StreamSubscription<PlaybackState>? _playbackStateSubscription;
  StreamSubscription<MediaItem?>? _mediaItemSubscription;

  PlayerNotifier({IVhunambiAudioHandler? audioHandler})
      : _ownsHandler = audioHandler == null,
        _audioHandler = audioHandler ?? TestVhunambiAudioHandler(),
        super(
          const PlayerState(
            currentTrack: Track(
              id: 'track_default_1',
              title: 'Grateful in the Light',
              creatorName: 'Sigwa & Inaf',
              genre: 'Amapiano',
              language: 'English',
              duration: Duration(minutes: 3, seconds: 29),
              likeCount: 1002,
              playCount: 1200,
              isNew: true,
            ),
            playbackStatus: PlaybackStatus.playing,
            position: Duration(seconds: 13),
            duration: Duration(minutes: 3, seconds: 29),
          ),
        ) {
    _initHardwareSubscriptions();
    _startPositionTicker();
  }

  /// The OS transport handler this notifier is synchronized with.
  IVhunambiAudioHandler get audioHandler => _audioHandler;

  /// Subscribes to OS transport events so lockscreen / bluetooth / SMTC
  /// commands update the Riverpod player state (REQ-AUD-10).
  void _initHardwareSubscriptions() {
    _playbackStateSubscription =
        _audioHandler.playbackState.listen(_onHardwarePlaybackState);
    _mediaItemSubscription =
        _audioHandler.mediaItem.listen(_onHardwareMediaItem);
  }

  void _onHardwarePlaybackState(PlaybackState playbackState) {
    if (!mounted) return;

    final mappedStatus = mapProcessingStateToPlaybackStatus(
      playbackState.processingState,
      playing: playbackState.playing,
    );

    final hardwarePosition = playbackState.updatePosition;
    final isEngineAuthoritative =
        (hardwarePosition - state.position).abs() >= hardwareSeekThreshold;

    // Echo suppression: a hardware event that merely replays the state this
    // notifier just published must not trigger a redundant UI rebuild.
    if (state.playbackStatus == mappedStatus &&
        !isEngineAuthoritative &&
        state.playbackSpeed == playbackState.speed &&
        state.bufferedPosition == playbackState.bufferedPosition) {
      return;
    }

    state = state.copyWith(
      playbackStatus: mappedStatus,
      position: isEngineAuthoritative ? hardwarePosition : null,
      bufferedPosition: playbackState.bufferedPosition,
      playbackSpeed: playbackState.speed,
      errorMessage: playbackState.errorMessage,
    );
  }

  void _onHardwareMediaItem(MediaItem? mediaItem) {
    if (!mounted || mediaItem == null) return;

    final duration = mediaItem.duration;
    if (duration == null || duration == state.duration) return;

    state = state.copyWith(duration: duration);
  }

  /// Mirrors a UI command into the platform transport without ever letting a
  /// handler failure escape into the synchronous UI path.
  Future<void> _dispatchSafely(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      debugPrint('Vhunambi audio handler dispatch failed: $error');
    }
  }

  void _startPositionTicker() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.isPlaying && state.hasActiveTrack) {
        final newSecs = state.position.inSeconds + 1;
        if (newSecs >= state.duration.inSeconds) {
          skipNext();
        } else {
          state = state.copyWith(position: Duration(seconds: newSecs));
        }
      }
    });
  }

  void playTrack(Track track, {List<Track>? queue}) {
    final effectiveQueue = queue ?? (state.queue.isEmpty ? [track] : state.queue);
    final index = effectiveQueue.indexWhere((t) => t.id == track.id);

    state = state.copyWith(
      currentTrack: track,
      playbackStatus: PlaybackStatus.playing,
      position: Duration.zero,
      duration: track.duration,
      queue: effectiveQueue,
      currentIndex: index >= 0 ? index : 0,
    );

    unawaited(
      _dispatchSafely(
        () => _audioHandler.playTrack(track, queue: effectiveQueue),
      ),
    );
  }

  /// Appends [track] to the end of the playback queue (REQ-PL-07).
  ///
  /// With no active session the track starts playing immediately; when the
  /// player is seeded with a lone track the queue is opened with that track so
  /// the active row always exists inside `state.queue`.
  void addToQueue(Track track) {
    final current = state.currentTrack;
    if (current == null) {
      playTrack(track, queue: <Track>[track]);
      return;
    }

    if (state.queue.isEmpty) {
      state = state.copyWith(
        queue: <Track>[current, track],
        currentIndex: 0,
      );
      return;
    }

    state = state.copyWith(
      queue: <Track>[...state.queue, track],
      currentIndex: state.currentIndex < 0 ? 0 : state.currentIndex,
    );
  }

  /// Inserts [track] immediately after the active track (REQ-PL-07).
  void playNext(Track track) {
    final current = state.currentTrack;
    if (current == null) {
      playTrack(track, queue: <Track>[track]);
      return;
    }

    if (state.queue.isEmpty) {
      state = state.copyWith(
        queue: <Track>[current, track],
        currentIndex: 0,
      );
      return;
    }

    final newQueue = List<Track>.of(state.queue)
      ..insert((state.currentIndex + 1).clamp(0, state.queue.length), track);

    state = state.copyWith(queue: newQueue);
  }

  /// Removes the queue entry at [index], keeping the active track consistent
  /// (REQ-PL-06).
  void removeFromQueue(int index) {
    if (index < 0 || index >= state.queue.length) return;

    final newQueue = List<Track>.from(state.queue)..removeAt(index);

    var newIndex = state.currentIndex;
    if (index < state.currentIndex) {
      newIndex--;
    } else if (index == state.currentIndex && newQueue.isNotEmpty) {
      newIndex = newIndex % newQueue.length;
    }

    if (newQueue.isEmpty) newIndex = -1;

    state = state.copyWith(queue: newQueue, currentIndex: newIndex);
  }

  /// Re-orders the queue for the drag-and-drop drawer (REQ-PL-05).
  ///
  /// [newIndex] follows `ReorderableListView` semantics: it is the insertion
  /// slot *before* removal, so it is decremented when dragging downwards.
  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= state.queue.length) return;

    var targetIndex = newIndex;
    if (targetIndex > oldIndex) targetIndex -= 1;

    final newQueue = List<Track>.from(state.queue);
    final item = newQueue.removeAt(oldIndex);
    targetIndex = targetIndex.clamp(0, newQueue.length);
    newQueue.insert(targetIndex, item);

    var updatedCurrent = state.currentIndex;
    if (state.currentIndex == oldIndex) {
      updatedCurrent = targetIndex;
    } else if (oldIndex < state.currentIndex && targetIndex >= state.currentIndex) {
      updatedCurrent--;
    } else if (oldIndex > state.currentIndex && targetIndex <= state.currentIndex) {
      updatedCurrent++;
    }

    state = state.copyWith(queue: newQueue, currentIndex: updatedCurrent);
  }

  /// Drops every upcoming track while the active track keeps playing
  /// (REQ-PL-06).
  void clearUpcomingQueue() {
    if (state.currentTrack == null) {
      state = state.copyWith(queue: const <Track>[], currentIndex: -1);
      return;
    }

    state = state.copyWith(
      queue: <Track>[state.currentTrack!],
      currentIndex: 0,
    );
  }

  /// Replaces the queue with an entire playlist and starts track 0
  /// (REQ-PL-10).
  void playPlaylist(PlaylistEntity playlist, List<Track> tracks) {
    if (tracks.isEmpty) return;
    playTrack(tracks.first, queue: tracks);
  }

  void togglePlayPause() {
    if (!state.hasActiveTrack) return;
    if (state.isPlaying) {
      state = state.copyWith(playbackStatus: PlaybackStatus.paused);
      unawaited(_dispatchSafely(_audioHandler.pause));
    } else {
      state = state.copyWith(playbackStatus: PlaybackStatus.playing);
      unawaited(_dispatchSafely(_audioHandler.play));
    }
  }

  void pause() {
    if (state.isPlaying) {
      state = state.copyWith(playbackStatus: PlaybackStatus.paused);
      unawaited(_dispatchSafely(_audioHandler.pause));
    }
  }

  void seek(Duration position) {
    state = state.copyWith(position: position);
    unawaited(_dispatchSafely(() => _audioHandler.seek(position)));
  }

  void seekByRatio(double ratio) {
    if (state.duration.inMilliseconds == 0) return;
    final targetMs = (state.duration.inMilliseconds * ratio).toInt();
    seek(Duration(milliseconds: targetMs));
  }

  void skipNext() {
    if (state.queue.isEmpty) return;
    final nextIndex = (state.currentIndex + 1) % state.queue.length;
    final nextTrack = state.queue[nextIndex];
    playTrack(nextTrack, queue: state.queue);
  }

  void skipPrevious() {
    if (state.queue.isEmpty) return;
    final prevIndex = (state.currentIndex - 1 + state.queue.length) % state.queue.length;
    final prevTrack = state.queue[prevIndex];
    playTrack(prevTrack, queue: state.queue);
  }

  void toggleShuffle() {
    state = state.copyWith(isShuffle: !state.isShuffle);
  }

  void cycleRepeatMode() {
    final next = switch (state.repeatMode) {
      AudioRepeatMode.off => AudioRepeatMode.all,
      AudioRepeatMode.all => AudioRepeatMode.one,
      AudioRepeatMode.one => AudioRepeatMode.off,
    };
    state = state.copyWith(repeatMode: next);
    unawaited(
      _dispatchSafely(() => _audioHandler.setVhunambiRepeatMode(next)),
    );
  }

  void setPlaybackSpeed(double speed) {
    state = state.copyWith(playbackSpeed: speed);
    unawaited(_dispatchSafely(() => _audioHandler.setSpeed(speed)));
  }

  void setVolume(double volume) {
    final clamped = volume.clamp(0.0, 1.0);
    state = state.copyWith(volume: clamped);
    unawaited(_dispatchSafely(() => _audioHandler.setVolume(clamped)));
  }

  void toggleExpanded() {
    state = state.copyWith(isExpanded: !state.isExpanded);
  }

  void dismiss() {
    _positionTimer?.cancel();
    state = state.copyWith(
      clearTrack: true,
      playbackStatus: PlaybackStatus.idle,
      position: Duration.zero,
    );
    unawaited(_dispatchSafely(_audioHandler.stop));
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    _playbackStateSubscription?.cancel();
    _mediaItemSubscription?.cancel();
    if (_ownsHandler) unawaited(_audioHandler.dispose());
    super.dispose();
  }
}

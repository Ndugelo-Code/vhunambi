import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:just_audio/just_audio.dart';

import '../../../../shared/models/track.dart';
import '../../domain/models/player_state.dart';
import 'audio_session_manager.dart';
import 'audio_source_resolver.dart';

/// Bi-directional transport contract shared by the production platform handler
/// and the headless test handler (REQ-AUD-01, REQ-AUD-02, REQ-AUD-05).
abstract class IVhunambiAudioHandler {
  /// Real-time playback state published to the OS transport.
  Stream<PlaybackState> get playbackState;

  /// Currently published media metadata (`null` once the session is dismissed).
  Stream<MediaItem?> get mediaItem;

  /// Playlist projection published to the OS transport.
  Stream<List<MediaItem>> get queue;

  /// Latest synchronization snapshot without waiting for a stream event.
  PlaybackState get currentPlaybackState;

  /// Latest published metadata without waiting for a stream event.
  MediaItem? get currentMediaItem;

  /// The Vhunambi track currently loaded into the transport.
  Track? get currentTrack;

  /// Loads a track (and optional playlist queue) and starts playback.
  Future<void> playTrack(Track track, {List<Track>? queue});

  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> skipToNext();
  Future<void> skipToPrevious();
  Future<void> setSpeed(double speed);

  /// Domain-typed repeat mode, mapped onto the OS transport contract.
  Future<void> setVhunambiRepeatMode(AudioRepeatMode mode);

  /// OS-facing repeat-mode contract (mirrors `BaseAudioHandler.setRepeatMode`).
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode);

  Future<void> setVolume(double volume);
  Future<void> dispose();
}

/// Android notification channel identity (REQ-AUD-01).
const String kAudioNotificationChannelId = 'com.vhunambi.app.audio';
const String kAudioNotificationChannelName = 'Vhunambi Music Playback';
const String kAudioNotificationChannelDescription =
    'African AI Music Synthesis & Creator Playback';
const String kAudioNotificationIcon = 'drawable/ic_stat_music';

/// Compact notification action slots: previous, play/pause, next (blueprint §2.1).
const List<int> kAndroidCompactActionIndices = <int>[0, 1, 2];

/// System actions advertised to the OS transport (REQ-AUD-04).
const Set<MediaAction> kAudioSystemActions = <MediaAction>{
  MediaAction.seek,
  MediaAction.skipToPrevious,
  MediaAction.skipToNext,
  MediaAction.stop,
};

/// `true` when a Vhunambi playback status renders audio (blueprint §5.2).
bool isPlayingStatus(PlaybackStatus status) =>
    status == PlaybackStatus.playing || status == PlaybackStatus.buffering;

/// `Track` → `MediaItem` metadata mapping (REQ-AUD-03).
MediaItem buildMediaItemForTrack(
  Track track, {
  bool isOffline = false,
  String? localFilePath,
}) {
  final coverUrl = track.coverUrl;
  return MediaItem(
    id: track.id,
    album: track.genre,
    title: track.title,
    artist: track.creatorName,
    duration: track.duration,
    artUri: (coverUrl != null && coverUrl.isNotEmpty)
        ? Uri.tryParse(coverUrl)
        : null,
    displayTitle: track.title,
    displaySubtitle: '${track.genre} • ${track.language}',
    displayDescription: isOffline
        ? '${track.handleLabel} • Offline vault'
        : '${track.handleLabel} • Vhunambi stream',
    extras: <String, dynamic>{
      'language': track.language,
      'mood': track.mood,
      'isOffline': isOffline,
      'localFilePath': localFilePath,
      'remoteAudioUrl': track.audioUrl,
      'source': isOffline ? 'vault' : 'stream',
    },
  );
}

/// Vhunambi `PlaybackStatus` → `audio_service` processing state (blueprint §5.2).
AudioProcessingState mapPlaybackStatusToProcessingState(
  PlaybackStatus status,
) =>
    switch (status) {
      PlaybackStatus.idle => AudioProcessingState.idle,
      PlaybackStatus.buffering => AudioProcessingState.buffering,
      PlaybackStatus.playing ||
      PlaybackStatus.paused =>
        AudioProcessingState.ready,
      PlaybackStatus.completed => AudioProcessingState.completed,
      PlaybackStatus.error => AudioProcessingState.error,
    };

/// `audio_service` processing state → Vhunambi [PlaybackStatus]
/// (reverse hardware→UI synchronization, REQ-AUD-10).
PlaybackStatus mapProcessingStateToPlaybackStatus(
  AudioProcessingState state, {
  required bool playing,
}) =>
    switch (state) {
      AudioProcessingState.idle => PlaybackStatus.idle,
      AudioProcessingState.loading ||
      AudioProcessingState.buffering =>
        PlaybackStatus.buffering,
      AudioProcessingState.ready =>
        playing ? PlaybackStatus.playing : PlaybackStatus.paused,
      AudioProcessingState.completed => PlaybackStatus.completed,
      AudioProcessingState.error => PlaybackStatus.error,
    };

/// Vhunambi repeat mode → `audio_service` repeat mode (REQ-AUD-05).
AudioServiceRepeatMode mapAudioRepeatMode(AudioRepeatMode mode) =>
    switch (mode) {
      AudioRepeatMode.off => AudioServiceRepeatMode.none,
      AudioRepeatMode.all => AudioServiceRepeatMode.all,
      AudioRepeatMode.one => AudioServiceRepeatMode.one,
    };

/// `audio_service` repeat mode → Vhunambi repeat mode (reverse sync).
AudioRepeatMode mapAudioServiceRepeatMode(
  AudioServiceRepeatMode repeatMode,
) =>
    switch (repeatMode) {
      AudioServiceRepeatMode.none => AudioRepeatMode.off,
      AudioServiceRepeatMode.all ||
      AudioServiceRepeatMode.group =>
        AudioRepeatMode.all,
      AudioServiceRepeatMode.one => AudioRepeatMode.one,
    };

/// Vhunambi repeat mode → `just_audio` loop mode.
LoopMode mapAudioRepeatModeToLoopMode(AudioRepeatMode mode) =>
    switch (mode) {
      AudioRepeatMode.off => LoopMode.off,
      AudioRepeatMode.all => LoopMode.all,
      AudioRepeatMode.one => LoopMode.one,
    };

/// `just_audio` processing state → `audio_service` processing state.
AudioProcessingState mapJustAudioProcessingState(ProcessingState state) =>
    switch (state) {
      ProcessingState.idle => AudioProcessingState.idle,
      ProcessingState.loading => AudioProcessingState.loading,
      ProcessingState.buffering => AudioProcessingState.buffering,
      ProcessingState.ready => AudioProcessingState.ready,
      ProcessingState.completed => AudioProcessingState.completed,
    };

/// Transport controls published to the OS, ordered so that
/// [kAndroidCompactActionIndices] surfaces previous / play-pause / next.
List<MediaControl> buildMediaControls({required bool playing}) {
  return <MediaControl>[
    MediaControl.skipToPrevious,
    if (playing) MediaControl.pause else MediaControl.play,
    MediaControl.skipToNext,
    MediaControl.stop,
  ];
}

/// Builds the OS-facing [PlaybackState] for a Vhunambi playback snapshot
/// (REQ-AUD-04). Shared by the production and headless handlers.
PlaybackState buildOsPlaybackState({
  required PlaybackStatus status,
  required Duration position,
  Duration bufferedPosition = Duration.zero,
  double speed = 1.0,
  int? queueIndex,
  AudioRepeatMode repeatMode = AudioRepeatMode.off,
  String? errorMessage,
}) {
  final playing = isPlayingStatus(status);
  return PlaybackState(
    controls: buildMediaControls(playing: playing),
    systemActions: kAudioSystemActions,
    androidCompactActionIndices: kAndroidCompactActionIndices,
    processingState: mapPlaybackStatusToProcessingState(status),
    playing: playing,
    updatePosition: position,
    bufferedPosition: bufferedPosition,
    speed: speed,
    queueIndex: queueIndex,
    repeatMode: mapAudioRepeatMode(repeatMode),
    errorMessage: errorMessage,
  );
}

/// Headless-safe handler implementing the full transport contract in memory
/// (REQ-AUD-02).
///
/// Never touches `AudioService`, `just_audio` or any platform channel, so the
/// Riverpod bridge and every widget test run green under `flutter test` while
/// still emitting genuine `PlaybackState` / `MediaItem` stream events.
class TestVhunambiAudioHandler implements IVhunambiAudioHandler {
  TestVhunambiAudioHandler({this.sourceResolver, this.sessionManager}) {
    _wireSessionEvents();
  }

  final IAudioSourceResolver? sourceResolver;
  final IAudioSessionManager? sessionManager;

  final StreamController<PlaybackState> _playbackStateController =
      StreamController<PlaybackState>.broadcast(sync: true);
  final StreamController<MediaItem?> _mediaItemController =
      StreamController<MediaItem?>.broadcast(sync: true);
  final StreamController<List<MediaItem>> _queueController =
      StreamController<List<MediaItem>>.broadcast(sync: true);

  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  PlaybackState _playbackState = buildOsPlaybackState(
    status: PlaybackStatus.idle,
    position: Duration.zero,
  );
  MediaItem? _mediaItem;
  List<MediaItem> _queueItems = const <MediaItem>[];
  List<Track> _tracks = const <Track>[];
  int _queueIndex = -1;
  Track? _track;
  Duration _position = Duration.zero;
  Duration _bufferedPosition = Duration.zero;
  double _speed = 1.0;
  double _volume = 1.0;
  AudioRepeatMode _repeatMode = AudioRepeatMode.off;
  bool _disposed = false;

  @override
  Stream<PlaybackState> get playbackState => _playbackStateController.stream;

  @override
  Stream<MediaItem?> get mediaItem => _mediaItemController.stream;

  @override
  Stream<List<MediaItem>> get queue => _queueController.stream;

  @override
  PlaybackState get currentPlaybackState => _playbackState;

  @override
  MediaItem? get currentMediaItem => _mediaItem;

  @override
  Track? get currentTrack => _track;

  /// Loaded playlist queue as Vhunambi domain objects.
  List<Track> get trackQueue => List<Track>.unmodifiable(_tracks);

  int get queueIndex => _queueIndex;
  Duration get position => _position;
  Duration get bufferedPosition => _bufferedPosition;
  double get speed => _speed;
  double get volume => _volume;
  AudioRepeatMode get repeatMode => _repeatMode;
  bool get isDisposed => _disposed;

  /// Current Vhunambi playback status derived from the OS-facing state.
  PlaybackStatus get playbackStatus => mapProcessingStateToPlaybackStatus(
        _playbackState.processingState,
        playing: _playbackState.playing,
      );

  @override
  Future<void> playTrack(Track track, {List<Track>? queue}) async {
    if (_disposed) return;

    final effectiveQueue =
        (queue != null && queue.isNotEmpty) ? queue : <Track>[track];
    _tracks = List<Track>.unmodifiable(effectiveQueue);
    _queueIndex =
        effectiveQueue.indexWhere((candidate) => candidate.id == track.id);
    if (_queueIndex < 0) _queueIndex = 0;

    var isOffline = false;
    String? localFilePath;
    final resolver = sourceResolver;
    if (resolver != null) {
      // A `null` result means resolution already published an error state.
      final source = await _resolve(track);
      if (source == null) return;
      isOffline = source.isLocalFile;
      localFilePath = source.localFilePath;
    }

    _track = track;
    _position = Duration.zero;
    _bufferedPosition = track.duration;

    _mediaItem = buildMediaItemForTrack(
      track,
      isOffline: isOffline,
      localFilePath: localFilePath,
    );
    _queueItems = effectiveQueue
        .map((candidate) => buildMediaItemForTrack(candidate))
        .toList(growable: false);

    _emitMediaItem(_mediaItem);
    _emitQueue(_queueItems);
    _publish(PlaybackStatus.playing);
  }

  /// Resolves the hybrid vault/cloud source, publishing an error state when the
  /// track cannot be played (REQ-AUD-09).
  Future<ResolvedAudioSource?> _resolve(Track track) async {
    final resolver = sourceResolver;
    if (resolver == null) return null;

    try {
      return await resolver.resolveSource(track);
    } on AudioSourceException catch (error) {
      _publishError(error.message);
      return null;
    } catch (error) {
      _publishError('Unable to resolve audio source: $error');
      return null;
    }
  }

  Future<void> _loadIndex(int index) async {
    if (index < 0 || index >= _tracks.length) return;

    final track = _tracks[index];
    var isOffline = false;
    String? localFilePath;
    final resolver = sourceResolver;
    if (resolver != null) {
      final source = await _resolve(track);
      if (source != null) {
        isOffline = source.isLocalFile;
        localFilePath = source.localFilePath;
      }
    }

    _queueIndex = index;
    _track = track;
    _position = Duration.zero;
    _bufferedPosition = track.duration;

    _mediaItem = buildMediaItemForTrack(
      track,
      isOffline: isOffline,
      localFilePath: localFilePath,
    );
    _emitMediaItem(_mediaItem);
    _publish(PlaybackStatus.playing);
  }

  @override
  Future<void> play() async {
    if (_disposed || _track == null) return;
    _publish(PlaybackStatus.playing);
  }

  @override
  Future<void> pause() async {
    if (_disposed || _track == null) return;
    _publish(PlaybackStatus.paused);
  }

  @override
  Future<void> stop() async {
    if (_disposed) return;
    // "Dismiss the active notification session" (REQ-AUD-05).
    _position = Duration.zero;
    _bufferedPosition = Duration.zero;
    _track = null;
    _queueIndex = -1;
    _mediaItem = null;
    _emitMediaItem(null);
    _publish(PlaybackStatus.idle);
  }

  @override
  Future<void> seek(Duration position) async {
    if (_disposed) return;
    _position = position < Duration.zero ? Duration.zero : position;
    _publish(playbackStatus);
  }

  @override
  Future<void> skipToNext() async {
    if (_disposed || _tracks.isEmpty) return;
    await _loadIndex((_queueIndex + 1) % _tracks.length);
  }

  @override
  Future<void> skipToPrevious() async {
    if (_disposed || _tracks.isEmpty) return;

    // REQ-AUD-05: restart the current track when elapsed > 3 seconds.
    if (_position > const Duration(seconds: 3)) {
      await seek(Duration.zero);
      return;
    }

    await _loadIndex((_queueIndex - 1 + _tracks.length) % _tracks.length);
  }

  @override
  Future<void> setSpeed(double speed) async {
    if (_disposed) return;
    _speed = speed.clamp(0.5, 3.0);
    _publish(playbackStatus);
  }

  @override
  Future<void> setVhunambiRepeatMode(AudioRepeatMode mode) async {
    if (_disposed) return;
    _repeatMode = mode;
    _publish(playbackStatus);
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) =>
      setVhunambiRepeatMode(mapAudioServiceRepeatMode(repeatMode));

  @override
  Future<void> setVolume(double volume) async {
    if (_disposed) return;
    _volume = volume.clamp(0.0, 1.0);
  }

  /// Bridges OS audio focus events into transport commands (REQ-AUD-07/08).
  void _wireSessionEvents() {
    final session = sessionManager;
    if (session == null) return;

    _subscriptions.add(
      session.interruptionStream.listen((event) {
        unawaited(
          session.handleInterruption(
            event,
            onPause: () => unawaited(pause()),
            onResume: () => unawaited(play()),
            isCurrentlyPlaying: _playbackState.playing,
          ),
        );
      }),
    );

    _subscriptions.add(
      session.becomingNoisyStream.listen((event) {
        if (event.shouldPause) unawaited(pause());
      }),
    );
  }

  void _publish(
    PlaybackStatus status, {
    Duration? position,
    Duration? bufferedPosition,
    String? errorMessage,
  }) {
    _position = position ?? _position;
    _bufferedPosition = bufferedPosition ?? _bufferedPosition;

    _playbackState = buildOsPlaybackState(
      status: status,
      position: _position,
      bufferedPosition: _bufferedPosition,
      speed: _speed,
      queueIndex: _queueIndex >= 0 ? _queueIndex : null,
      repeatMode: _repeatMode,
      errorMessage: errorMessage,
    );

    _emitPlaybackState(_playbackState);
  }

  void _publishError(String message) {
    _publish(PlaybackStatus.error, errorMessage: message);
  }

  void _emitPlaybackState(PlaybackState playbackState) {
    if (_playbackStateController.isClosed) return;
    _playbackStateController.add(playbackState);
  }

  void _emitMediaItem(MediaItem? item) {
    if (_mediaItemController.isClosed) return;
    _mediaItemController.add(item);
  }

  void _emitQueue(List<MediaItem> items) {
    if (_queueController.isClosed) return;
    _queueController.add(items);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();

    await _playbackStateController.close();
    await _mediaItemController.close();
    await _queueController.close();
  }
}

/// Production platform audio handler.
///
/// Bridges `just_audio` into the operating system media services (Android
/// `MediaSession` + `NotificationCompat.MediaStyle`, iOS
/// `MPNowPlayingInfoCenter` / `MPRemoteCommandCenter`, desktop SMTC) through
/// `audio_service` (REQ-AUD-01, REQ-AUD-03, REQ-AUD-04, REQ-AUD-05).
///
/// Instantiate it through [bootstrapPlatformAudioHandler] so the notification
/// channel and compact-action config are registered with `AudioService.init`.
class VhunambiAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler
    implements IVhunambiAudioHandler {
  final AudioPlayer player;
  final IAudioSourceResolver sourceResolver;
  final IAudioSessionManager sessionManager;

  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  List<Track> _tracks = <Track>[];
  int _index = -1;
  Track? _track;
  double _speed = 1.0;
  double _volume = 1.0;
  AudioRepeatMode _repeatMode = AudioRepeatMode.off;
  bool _disposed = false;

  VhunambiAudioHandler({
    required this.player,
    required this.sourceResolver,
    required this.sessionManager,
  }) {
    _wirePlayerStreams();
    _wireSessionEvents();
  }

  @override
  PlaybackState get currentPlaybackState => super.playbackState.value;

  @override
  MediaItem? get currentMediaItem => super.mediaItem.value;

  @override
  Track? get currentTrack => _track;

  /// Loaded playlist queue as Vhunambi domain objects.
  List<Track> get trackQueue => List<Track>.unmodifiable(_tracks);

  int get queueIndex => _index;
  double get speed => _speed;
  double get volume => _volume;
  AudioRepeatMode get repeatMode => _repeatMode;
  bool get isDisposed => _disposed;

  @override
  Future<void> playTrack(Track track, {List<Track>? queue}) async {
    if (_disposed) return;

    final effectiveQueue = (queue != null && queue.isNotEmpty)
        ? List<Track>.from(queue)
        : <Track>[track];
    _tracks = effectiveQueue;
    _track = track;
    _index = effectiveQueue.indexWhere((candidate) => candidate.id == track.id);
    if (_index < 0) _index = 0;

    // Hardware focus must be configured and acquired before rendering audio.
    await sessionManager.configureSession();
    await sessionManager.activate();

    final resolved = await sourceResolver.resolveSource(track);
    final item = buildMediaItemForTrack(
      track,
      isOffline: resolved.isLocalFile,
      localFilePath: resolved.localFilePath,
    );

    mediaItem.add(item);
    super.queue.add(
      effectiveQueue
          .map((candidate) => buildMediaItemForTrack(candidate))
          .toList(growable: false),
    );

    await player.setAudioSource(
      AudioSource.uri(resolved.uri, tag: item),
      initialIndex: _index,
      initialPosition: Duration.zero,
    );
    await player.play();
  }

  void _wirePlayerStreams() {
    _subscriptions.add(
      player.playbackEventStream.listen(
        _broadcastPlaybackEvent,
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('VhunambiAudioHandler player error: $error');
          playbackState.add(
            buildOsPlaybackState(
              status: PlaybackStatus.error,
              position: player.position,
              speed: player.speed,
              errorMessage: error.toString(),
            ),
          );
        },
      ),
    );

    _subscriptions.add(
      player.currentIndexStream.listen((index) {
        if (index != null) _index = index;
      }),
    );
  }

  void _broadcastPlaybackEvent(PlaybackEvent event) {
    playbackState.add(
      buildOsPlaybackState(
        status: _statusFor(event.processingState),
        position: player.position,
        bufferedPosition: player.bufferedPosition,
        speed: player.speed,
        queueIndex: _index >= 0 ? _index : null,
        repeatMode: _repeatMode,
      ),
    );
  }

  PlaybackStatus _statusFor(ProcessingState processingState) {
    if (processingState == ProcessingState.completed) {
      return PlaybackStatus.completed;
    }
    if (player.playing) {
      return processingState == ProcessingState.ready
          ? PlaybackStatus.playing
          : PlaybackStatus.buffering;
    }
    if (processingState == ProcessingState.idle) return PlaybackStatus.idle;
    return PlaybackStatus.paused;
  }

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> stop() async {
    if (_disposed) return;
    await player.stop();
    _track = null;
    mediaItem.add(null);
    playbackState.add(
      buildOsPlaybackState(
        status: PlaybackStatus.idle,
        position: Duration.zero,
      ),
    );
  }

  @override
  Future<void> seek(Duration position) async {
    if (_disposed) return;
    await player.seek(position);
    playbackState.add(
      buildOsPlaybackState(
        status: _statusFor(player.processingState),
        position: position,
        bufferedPosition: player.bufferedPosition,
        speed: player.speed,
        queueIndex: _index >= 0 ? _index : null,
        repeatMode: _repeatMode,
      ),
    );
  }

  @override
  Future<void> skipToNext() async {
    if (_disposed || !player.hasNext) return;
    await player.seekToNext();
  }

  @override
  Future<void> skipToPrevious() async {
    if (_disposed) return;

    // REQ-AUD-05: restart the current track when elapsed > 3 seconds.
    if (player.position > const Duration(seconds: 3)) {
      await seek(Duration.zero);
      return;
    }
    if (player.hasPrevious) await player.seekToPrevious();
  }

  @override
  Future<void> setSpeed(double speed) async {
    _speed = speed.clamp(0.5, 3.0);
    await player.setSpeed(_speed);
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) =>
      setVhunambiRepeatMode(mapAudioServiceRepeatMode(repeatMode));

  @override
  Future<void> setVhunambiRepeatMode(AudioRepeatMode mode) async {
    _repeatMode = mode;
    await player.setLoopMode(mapAudioRepeatModeToLoopMode(mode));
  }

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await player.setVolume(_volume);
  }

  /// Bridges OS audio focus events into the `just_audio` transport
  /// (REQ-AUD-07/08).
  void _wireSessionEvents() {
    _subscriptions.add(
      sessionManager.interruptionStream.listen((event) {
        unawaited(
          sessionManager.handleInterruption(
            event,
            onPause: () => unawaited(player.pause()),
            onResume: () => unawaited(player.play()),
            isCurrentlyPlaying: player.playing,
          ),
        );
      }),
    );

    _subscriptions.add(
      sessionManager.becomingNoisyStream.listen((event) {
        if (event.shouldPause) unawaited(player.pause());
      }),
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();

    sessionManager.dispose();
    await player.dispose();
  }
}

/// Registers the OS media service and returns the active audio handler
/// (REQ-AUD-01).
///
/// Falls back to the headless [TestVhunambiAudioHandler] when the platform
/// channel is unavailable (`MissingPluginException` in tests, on headless CI, or
/// on an unsupported desktop), guaranteeing metadata still flows to Riverpod.
Future<IVhunambiAudioHandler> bootstrapPlatformAudioHandler({
  required AudioPlayer player,
  required IAudioSourceResolver sourceResolver,
  required IAudioSessionManager sessionManager,
}) async {
  final handler = VhunambiAudioHandler(
    player: player,
    sourceResolver: sourceResolver,
    sessionManager: sessionManager,
  );

  try {
    return await AudioService.init<VhunambiAudioHandler>(
      builder: () => handler,
      config: const AudioServiceConfig(
        androidNotificationChannelId: kAudioNotificationChannelId,
        androidNotificationChannelName: kAudioNotificationChannelName,
        androidNotificationChannelDescription:
            kAudioNotificationChannelDescription,
        androidNotificationIcon: kAudioNotificationIcon,
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
  } on MissingPluginException catch (error) {
    debugPrint('AudioService unavailable, using headless handler: $error');
  } catch (error) {
    debugPrint('AudioService bootstrap failed, using headless handler: $error');
  }

  return TestVhunambiAudioHandler(
    sourceResolver: sourceResolver,
    sessionManager: sessionManager,
  );
}


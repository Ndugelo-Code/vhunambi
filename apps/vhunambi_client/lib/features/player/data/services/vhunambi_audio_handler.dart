import 'dart:async';
import 'dart:io' show Directory, File, Platform;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MissingPluginException, rootBundle;
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/resilience/safe_audio_orchestrator.dart';
import '../../../../core/theme/app_colors.dart';
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

  /// Broadcasts active track IDs when the user taps the notification heart.
  Stream<String> get favoriteToggleRequests;

  /// Updates the notification heart button state to mirror in-app likes.
  Future<void> setFavoriteState(bool isFavorite);

  Future<void> dispose();
}

/// Android notification channel identity (REQ-AUD-01).
const String kAudioNotificationChannelId = 'com.vhunambi.app.audio';
const String kAudioNotificationChannelName = 'Vhunambi Playback';
const String kAudioNotificationChannelDescription =
    'African AI Music Synthesis & Creator Playback';
const String kAudioNotificationIcon = 'drawable/ic_stat_vhunambi';

/// Custom notification transport actions wired through `MediaControl.custom`.
const String kAudioCustomActionToggleFavorite = 'toggle_favorite';
const String kAudioCustomActionCloseDismiss = 'close_dismiss';

/// Compact notification action slots indexing into `AudioService.java`'s
/// `nativeActions` list (`[0]=previous`, `[1]=play/pause`, `[2]=next`).
/// `MediaControl.custom` actions live in `PlaybackStateCompat.CustomAction`
/// (`customActions`), not `nativeActions`, so indexing past 2 causes
/// `IndexOutOfBoundsException: Index: 3, Size: 3` on Android < 13 SystemUI.
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

bool _isFlutterTestEnvironment() {
  if (const bool.fromEnvironment('FLUTTER_TEST')) return true;
  if (!kIsWeb) {
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) return true;
    } catch (_) {}
  }
  try {
    return WidgetsBinding.instance.runtimeType.toString().contains('Test');
  } catch (_) {
    return false;
  }
}

/// Resolves a cover art source into a synchronous OS-readable `Uri` when it is
/// already an HTTPS URL or `file://` path (returns `null` when only a Flutter
/// asset path is available synchronously so callers can cache it to disk first).
Uri? resolveNotificationArtUri(Track track, {Uri? cachedAssetArtUri}) {
  if (cachedAssetArtUri != null) return cachedAssetArtUri;

  final resolved = AppAssets.resolveTrackCoverSource(
    coverUrl: track.coverUrl,
    genre: track.genre,
    seedId: track.id,
  );
  if (resolved.startsWith('http://') || resolved.startsWith('https://')) {
    return Uri.tryParse(resolved);
  }
  if (resolved.startsWith('file://')) {
    return Uri.tryParse(resolved);
  }
  if (!kIsWeb &&
      !resolved.startsWith('assets/') &&
      !resolved.startsWith('asset:') &&
      resolved.isNotEmpty) {
    try {
      if (File(resolved).existsSync()) return Uri.file(resolved);
    } catch (_) {}
  }
  return null;
}

String _stableArtHash(String input) {
  var hash = 0x811c9dc5;
  for (final unit in input.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

/// Resolves and caches Flutter `asset:` / bundled cover artwork into a
/// temporary file so Android `NotificationManager` renders artwork and auto-tints
/// the chromatic `MediaStyle` card even when a track relies on genre art.
Future<Uri?> resolveNativeNotificationArtUri(
  Track track, {
  Future<ByteData> Function(String assetKey)? assetLoader,
  Future<Directory> Function()? tempDirProvider,
  bool allowUnderTest = false,
}) async {
  final direct = resolveNotificationArtUri(track);
  if (direct != null) return direct;

  if (kIsWeb || (!allowUnderTest && _isFlutterTestEnvironment())) {
    return null;
  }

  final assetPath = AppAssets.resolveTrackCoverSource(
    coverUrl: track.coverUrl,
    genre: track.genre,
    seedId: track.id,
  );
  if (assetPath.isEmpty) return null;

  try {
    final baseDir = await (tempDirProvider ?? getTemporaryDirectory)();
    final cacheDir = Directory('${baseDir.path}/vhunambi_notif_art');
    if (!cacheDir.existsSync()) {
      cacheDir.createSync(recursive: true);
    }
    final dotIdx = assetPath.lastIndexOf('.');
    final ext = (dotIdx != -1 && assetPath.length - dotIdx <= 5)
        ? assetPath.substring(dotIdx).toLowerCase()
        : '.png';
    final outFile = File(
      '${cacheDir.path}/cover_${_stableArtHash(assetPath)}$ext',
    );
    if (!outFile.existsSync() || outFile.lengthSync() == 0) {
      final data = await (assetLoader ?? rootBundle.load)(assetPath);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      await outFile.writeAsBytes(bytes, flush: true);
    }
    return Uri.file(outFile.path);
  } catch (error) {
    debugPrint('Notification artwork cache failed ($assetPath): $error');
    return null;
  }
}

/// `Track` → `MediaItem` metadata mapping (REQ-AUD-03).
MediaItem buildMediaItemForTrack(
  Track track, {
  bool isOffline = false,
  String? localFilePath,
  Uri? resolvedArtUri,
}) {
  final rawCreator = track.creatorName.trim();
  final cleanCreator = rawCreator.isEmpty
      ? 'Vhunambi'
      : rawCreator.replaceFirst(RegExp(r'^@+'), '');
  final cleanGenre = track.genre.trim().isEmpty ? 'Studio' : track.genre.trim();
  final cleanLanguage = track.language.trim();
  final subtitle = cleanLanguage.isNotEmpty
      ? '$cleanGenre • $cleanLanguage'
      : cleanGenre;

  return MediaItem(
    id: track.id,
    album: isOffline ? '$cleanGenre • Offline' : cleanGenre,
    title: track.title,
    artist: cleanCreator,
    duration: track.duration,
    artUri: resolveNotificationArtUri(track, cachedAssetArtUri: resolvedArtUri),
    displayTitle: track.title,
    displaySubtitle: cleanCreator,
    displayDescription: isOffline
        ? '$cleanCreator • Offline Vault'
        : '$cleanCreator • $subtitle',
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
) => switch (status) {
  PlaybackStatus.idle => AudioProcessingState.idle,
  PlaybackStatus.buffering => AudioProcessingState.buffering,
  PlaybackStatus.playing || PlaybackStatus.paused => AudioProcessingState.ready,
  PlaybackStatus.completed => AudioProcessingState.completed,
  PlaybackStatus.error => AudioProcessingState.error,
};

/// `audio_service` processing state → Vhunambi [PlaybackStatus]
/// (reverse hardware→UI synchronization, REQ-AUD-10).
PlaybackStatus mapProcessingStateToPlaybackStatus(
  AudioProcessingState state, {
  required bool playing,
}) => switch (state) {
  AudioProcessingState.idle => PlaybackStatus.idle,
  AudioProcessingState.loading ||
  AudioProcessingState.buffering => PlaybackStatus.buffering,
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
AudioRepeatMode mapAudioServiceRepeatMode(AudioServiceRepeatMode repeatMode) =>
    switch (repeatMode) {
      AudioServiceRepeatMode.none => AudioRepeatMode.off,
      AudioServiceRepeatMode.all ||
      AudioServiceRepeatMode.group => AudioRepeatMode.all,
      AudioServiceRepeatMode.one => AudioRepeatMode.one,
    };

/// Vhunambi repeat mode → `just_audio` loop mode.
LoopMode mapAudioRepeatModeToLoopMode(AudioRepeatMode mode) => switch (mode) {
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

/// Transport controls published to the OS in a 5-button strip:
/// `[ ♡, ⏮, ⏸/▶, ⏭, ✕ ]`, where [kAndroidCompactActionIndices] keeps
/// previous / play-pause / next centered in compact mode.
List<MediaControl> buildMediaControls({
  required bool playing,
  bool isFavorite = false,
}) {
  return <MediaControl>[
    MediaControl.custom(
      androidIcon: isFavorite
          ? 'drawable/ic_vh_heart_filled'
          : 'drawable/ic_vh_heart_outline',
      label: isFavorite ? 'Unlike' : 'Like',
      name: kAudioCustomActionToggleFavorite,
    ),
    const MediaControl(
      androidIcon: 'drawable/ic_vh_prev',
      label: 'Previous',
      action: MediaAction.skipToPrevious,
    ),
    if (playing)
      const MediaControl(
        androidIcon: 'drawable/ic_vh_pause',
        label: 'Pause',
        action: MediaAction.pause,
      )
    else
      const MediaControl(
        androidIcon: 'drawable/ic_vh_play',
        label: 'Play',
        action: MediaAction.play,
      ),
    const MediaControl(
      androidIcon: 'drawable/ic_vh_next',
      label: 'Next',
      action: MediaAction.skipToNext,
    ),
    MediaControl.custom(
      androidIcon: 'drawable/ic_vh_close',
      label: 'Close',
      name: kAudioCustomActionCloseDismiss,
    ),
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
  bool isFavorite = false,
  String? errorMessage,
}) {
  final playing = isPlayingStatus(status);
  return PlaybackState(
    controls: buildMediaControls(playing: playing, isFavorite: isFavorite),
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
  final StreamController<String> _favoriteToggleController =
      StreamController<String>.broadcast(sync: true);

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
  bool _isFavorite = false;
  bool _disposed = false;

  @override
  Stream<PlaybackState> get playbackState => _playbackStateController.stream;

  @override
  Stream<MediaItem?> get mediaItem => _mediaItemController.stream;

  @override
  Stream<List<MediaItem>> get queue => _queueController.stream;

  @override
  Stream<String> get favoriteToggleRequests => _favoriteToggleController.stream;

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

    final effectiveQueue = (queue != null && queue.isNotEmpty)
        ? queue
        : <Track>[track];
    _tracks = List<Track>.unmodifiable(effectiveQueue);
    _queueIndex = effectiveQueue.indexWhere(
      (candidate) => candidate.id == track.id,
    );
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

  @override
  Future<void> setFavoriteState(bool isFavorite) async {
    if (_disposed || _isFavorite == isFavorite) return;
    _isFavorite = isFavorite;
    _publish(playbackStatus);
  }

  Future<dynamic> customAction(
    String name, [
    Map<String, dynamic>? extras,
  ]) async {
    if (_disposed) return null;
    if (name == kAudioCustomActionToggleFavorite) {
      _isFavorite = !_isFavorite;
      _publish(playbackStatus);
      final activeId = _track?.id;
      if (activeId != null && !_favoriteToggleController.isClosed) {
        _favoriteToggleController.add(activeId);
      }
      return _isFavorite;
    }
    if (name == kAudioCustomActionCloseDismiss) {
      await stop();
      return true;
    }
    return null;
  }

  /// Emits an updated track duration as `just_audio.durationStream` would.
  void updateDurationForTesting(Duration duration) {
    if (_disposed || duration <= Duration.zero) return;
    final current = _mediaItem;
    if (current != null && current.duration != duration) {
      _mediaItem = current.copyWith(duration: duration);
      _emitMediaItem(_mediaItem);
    }
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
      isFavorite: _isFavorite,
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
    await _favoriteToggleController.close();
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
  final StreamController<String> _favoriteToggleController =
      StreamController<String>.broadcast(sync: true);
  final Map<String, Uri> _cachedArtUris = <String, Uri>{};

  List<Track> _tracks = <Track>[];
  int _index = -1;
  Track? _track;
  double _speed = 1.0;
  double _volume = 1.0;
  AudioRepeatMode _repeatMode = AudioRepeatMode.off;
  bool _isFavorite = false;
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

  @override
  Stream<String> get favoriteToggleRequests => _favoriteToggleController.stream;

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

    // Hardware focus must be configured and acquired before rendering audio,
    // and any competing audio engine slot (stemMixer/reelPool/sketchpad) paused.
    await SafeAudioOrchestrator.instance.acquireSlot(
      AudioEngineSlot.masterPlayer,
      onPreemptPause: () => pause(),
    );
    await sessionManager.configureSession();
    await sessionManager.activate();

    final resolved = await sourceResolver.resolveSource(track);
    final normalizedUri = resolved.isLocalFile
        ? resolved.uri
        : Uri.parse(
            AppConstants.normalizeCloudMediaUrl(resolved.uri.toString()),
          );
    final nativeArtUri = await _resolveAndCacheArtUri(track);
    final item = buildMediaItemForTrack(
      track,
      isOffline: resolved.isLocalFile,
      localFilePath: resolved.localFilePath,
      resolvedArtUri: nativeArtUri,
    );

    mediaItem.add(item);
    super.queue.add(
      effectiveQueue
          .map(
            (candidate) => buildMediaItemForTrack(
              candidate,
              resolvedArtUri: _cachedArtUris[candidate.id],
            ),
          )
          .toList(growable: false),
    );

    final audioSource =
        resolved.streamSource ?? AudioSource.uri(normalizedUri, tag: item);

    final loadedDuration = await SafeAudioOrchestrator.guardAudioOp<Duration?>(
      source: 'vhunambi_audio_handler:setAudioSource',
      action: () => player.setAudioSource(
        audioSource,
        initialIndex: _index,
        initialPosition: Duration.zero,
      ),
    );
    if (loadedDuration != null &&
        loadedDuration > Duration.zero &&
        item.duration != loadedDuration) {
      mediaItem.add(item.copyWith(duration: loadedDuration));
    }
    await SafeAudioOrchestrator.guardAudioOp<void>(
      source: 'vhunambi_audio_handler:play',
      action: () => player.play(),
    );
  }

  Future<Uri?> _resolveAndCacheArtUri(Track track) async {
    final cached = _cachedArtUris[track.id];
    if (cached != null) return cached;
    final resolved = await resolveNativeNotificationArtUri(track);
    if (resolved != null) {
      _cachedArtUris[track.id] = resolved;
    }
    return resolved;
  }

  void _wirePlayerStreams() {
    SafeAudioOrchestrator.instance.registerSlot(
      AudioEngineSlot.masterPlayer,
      () => pause(),
    );

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
              isFavorite: _isFavorite,
              errorMessage: error.toString(),
            ),
          );
        },
      ),
    );

    _subscriptions.add(
      player.durationStream.listen(
        (Duration? decodedDuration) {
          if (decodedDuration == null || decodedDuration <= Duration.zero) {
            return;
          }
          final currentItem = mediaItem.valueOrNull;
          if (currentItem != null && currentItem.duration != decodedDuration) {
            mediaItem.add(currentItem.copyWith(duration: decodedDuration));
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('VhunambiAudioHandler durationStream error: $error');
        },
      ),
    );

    _subscriptions.add(
      player.currentIndexStream.listen(
        (index) {
          if (index == null || index < 0 || index >= _tracks.length) return;
          final changed = index != _index;
          _index = index;
          if (changed) {
            final nextTrack = _tracks[index];
            _track = nextTrack;
            unawaited(
              _resolveAndCacheArtUri(nextTrack).then((art) {
                if (_disposed || _track?.id != nextTrack.id) return;
                mediaItem.add(
                  buildMediaItemForTrack(nextTrack, resolvedArtUri: art),
                );
              }),
            );
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('VhunambiAudioHandler currentIndexStream error: $error');
        },
      ),
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
        isFavorite: _isFavorite,
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
  Future<void> play() async {
    if (_disposed) return;
    await SafeAudioOrchestrator.instance.acquireSlot(
      AudioEngineSlot.masterPlayer,
      onPreemptPause: () => pause(),
    );
    await SafeAudioOrchestrator.guardAudioOp<void>(
      source: 'vhunambi_audio_handler:play',
      action: () => player.play(),
    );
  }

  @override
  Future<void> pause() async {
    if (_disposed) return;
    await SafeAudioOrchestrator.guardAudioOp<void>(
      source: 'vhunambi_audio_handler:pause',
      action: () => player.pause(),
    );
  }

  @override
  Future<void> stop() async {
    if (_disposed) return;
    await SafeAudioOrchestrator.guardAudioOp<void>(
      source: 'vhunambi_audio_handler:stop',
      action: () => player.stop(),
    );
    SafeAudioOrchestrator.instance.releaseSlot(AudioEngineSlot.masterPlayer);
    _track = null;
    mediaItem.add(null);
    playbackState.add(
      buildOsPlaybackState(
        status: PlaybackStatus.idle,
        position: Duration.zero,
        isFavorite: _isFavorite,
      ),
    );
  }

  @override
  Future<void> seek(Duration position) async {
    if (_disposed) return;
    await SafeAudioOrchestrator.guardAudioOp<void>(
      source: 'vhunambi_audio_handler:seek',
      action: () => player.seek(position),
    );
    playbackState.add(
      buildOsPlaybackState(
        status: _statusFor(player.processingState),
        position: position,
        bufferedPosition: player.bufferedPosition,
        speed: player.speed,
        queueIndex: _index >= 0 ? _index : null,
        repeatMode: _repeatMode,
        isFavorite: _isFavorite,
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

  @override
  Future<void> setFavoriteState(bool isFavorite) async {
    if (_disposed || _isFavorite == isFavorite) return;
    _isFavorite = isFavorite;
    playbackState.add(
      buildOsPlaybackState(
        status: _statusFor(player.processingState),
        position: player.position,
        bufferedPosition: player.bufferedPosition,
        speed: player.speed,
        queueIndex: _index >= 0 ? _index : null,
        repeatMode: _repeatMode,
        isFavorite: _isFavorite,
      ),
    );
  }

  @override
  Future<dynamic> customAction(
    String name, [
    Map<String, dynamic>? extras,
  ]) async {
    if (_disposed) return null;
    if (name == kAudioCustomActionToggleFavorite) {
      await setFavoriteState(!_isFavorite);
      final activeId = _track?.id;
      if (activeId != null && !_favoriteToggleController.isClosed) {
        _favoriteToggleController.add(activeId);
      }
      return _isFavorite;
    }
    if (name == kAudioCustomActionCloseDismiss) {
      await stop();
      return true;
    }
    return super.customAction(name, extras);
  }

  /// Bridges OS audio focus events into the `just_audio` transport
  /// (REQ-AUD-07/08).
  void _wireSessionEvents() {
    _subscriptions.add(
      sessionManager.interruptionStream.listen(
        (event) {
          unawaited(
            sessionManager.handleInterruption(
              event,
              onPause: () => unawaited(pause()),
              onResume: () => unawaited(play()),
              isCurrentlyPlaying: player.playing,
            ),
          );
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('VhunambiAudioHandler interruptionStream error: $error');
        },
      ),
    );

    _subscriptions.add(
      sessionManager.becomingNoisyStream.listen(
        (event) {
          if (event.shouldPause) unawaited(pause());
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('VhunambiAudioHandler becomingNoisyStream error: $error');
        },
      ),
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    SafeAudioOrchestrator.instance.unregisterSlot(AudioEngineSlot.masterPlayer);

    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();

    sessionManager.dispose();
    await _favoriteToggleController.close();
    await player.dispose();
  }
}

const AudioServiceConfig vhunambiAudioServiceConfig = AudioServiceConfig(
  androidNotificationChannelId: kAudioNotificationChannelId,
  androidNotificationChannelName: kAudioNotificationChannelName,
  androidNotificationChannelDescription: kAudioNotificationChannelDescription,
  androidNotificationIcon: kAudioNotificationIcon,
  notificationColor: AppColors.brandPrimary,
  artDownscaleWidth: 512,
  artDownscaleHeight: 512,
  preloadArtwork: true,
  androidNotificationOngoing: true,
  androidStopForegroundOnPause: true,
);

class _DefaultCloudAudioSourceResolver implements IAudioSourceResolver {
  const _DefaultCloudAudioSourceResolver();

  @override
  Future<ResolvedAudioSource> resolveSource(Track track) async {
    final rawUrl = (track.audioUrl != null && track.audioUrl!.trim().isNotEmpty)
        ? track.audioUrl!.trim()
        : '${AppConstants.resolveMediaBaseUrl()}/audio/${track.id}.wav';
    final normalized = AppConstants.normalizeCloudMediaUrl(rawUrl);
    return ResolvedAudioSource(uri: Uri.parse(normalized), isLocalFile: false);
  }
}

/// Registers the OS media service and returns the active audio handler
/// (REQ-AUD-01 / REQ-P64-AUD-01).
///
/// Falls back to [TestVhunambiAudioHandler] when the platform channel is
/// unavailable (`MissingPluginException` in headless CI/unit tests), or keeps
/// direct `just_audio` speaker playback alive via [VhunambiAudioHandler] if
/// OS notification initialization throws.
Future<IVhunambiAudioHandler> bootstrapPlatformAudioHandler({
  AudioPlayer? player,
  IAudioSourceResolver? sourceResolver,
  IAudioSessionManager? sessionManager,
  Future<IVhunambiAudioHandler> Function()? initializerOverride,
}) async {
  final effectivePlayer = player ?? AudioPlayer();
  final effectiveResolver =
      sourceResolver ?? const _DefaultCloudAudioSourceResolver();
  final effectiveSession = sessionManager ?? AudioSessionManager();

  final handler = VhunambiAudioHandler(
    player: effectivePlayer,
    sourceResolver: effectiveResolver,
    sessionManager: effectiveSession,
  );

  try {
    if (initializerOverride != null) {
      return await initializerOverride();
    }
    return await AudioService.init<VhunambiAudioHandler>(
      builder: () => handler,
      config: vhunambiAudioServiceConfig,
    );
  } on MissingPluginException catch (error) {
    debugPrint('AudioService unavailable, using headless handler: $error');
    return TestVhunambiAudioHandler(
      sourceResolver: effectiveResolver,
      sessionManager: effectiveSession,
    );
  } catch (error) {
    debugPrint(
      'AudioService notification init bypassed, using direct hardware handler: $error',
    );
    return handler;
  }
}

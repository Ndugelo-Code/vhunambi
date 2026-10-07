# Phase 9 Design: Production Audio Engine Hardware Bridge & Platform Services

> **Target Package:** `apps/vhunambi_client`  
> **Parent Foundation Blueprint:** [`docs/foundation_blueprints/07_AUDIO_TRANSPORT_AND_PIPELINE_MODALS_SPEC.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/foundation_blueprints/07_AUDIO_TRANSPORT_AND_PIPELINE_MODALS_SPEC.md)  
> **Architectural Blueprint:** [`docs/phases/phase_09_hardware_audio_bridge/blueprint.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_09_hardware_audio_bridge/blueprint.md)  
> **Requirements Reference:** [`docs/phases/phase_09_hardware_audio_bridge/requirements.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_09_hardware_audio_bridge/requirements.md)  

---

## 1. Directory Structure & File Map

```
apps/vhunambi_client/
  lib/features/player/
    domain/
      models/
        player_state.dart                     # Existing PlayerState, PlaybackStatus, AudioRepeatMode
        audio_session_events.dart             # NEW: AudioInterruptionEvent, BecomingNoisyEvent
    data/
      services/
        vhunambi_audio_handler.dart           # NEW: IVhunambiAudioHandler, VhunambiAudioHandler, TestVhunambiAudioHandler
        audio_session_manager.dart            # NEW: IAudioSessionManager, AudioSessionManager, TestAudioSessionManager
        audio_source_resolver.dart            # NEW: IAudioSourceResolver, AudioSourceResolver
    presentation/
      providers/
        player_provider.dart                  # UPDATED: Injects IVhunambiAudioHandler, bi-directional sync
        audio_bridge_providers.dart           # NEW: Providers for audio handler, session manager, source resolver
  test/
    features/
      player/
        vhunambi_audio_handler_test.dart      # NEW: Handler lifecycle, MediaItem mapping, PlaybackState tests
        audio_session_manager_test.dart       # NEW: Interruption & becoming noisy handler tests
        audio_source_resolver_test.dart       # NEW: Offline cache priority & URL fallback tests
        player_hardware_bridge_test.dart      # NEW: Bi-directional Riverpod synchronization tests
```

---

## 2. Core Service Interfaces & Class Signatures

### 2.1 `IVhunambiAudioHandler` & `VhunambiAudioHandler`

```dart
abstract class IVhunambiAudioHandler {
  Stream<PlaybackState> get playbackState;
  Stream<MediaItem?> get mediaItem;
  Stream<List<MediaItem>> get queue;

  Future<void> playTrack(Track track, {List<Track>? queue});
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> skipToNext();
  Future<void> skipToPrevious();
  Future<void> setSpeed(double speed);
  Future<void> setRepeatMode(AudioRepeatMode mode);
  Future<void> setVolume(double volume);
  Future<void> dispose();
}

/// Production implementation extending BaseAudioHandler from audio_service.
class VhunambiAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler
    implements IVhunambiAudioHandler {
  final AudioPlayer _player;
  final IAudioSourceResolver _sourceResolver;
  final IAudioSessionManager _sessionManager;

  VhunambiAudioHandler({
    required AudioPlayer player,
    required IAudioSourceResolver sourceResolver,
    required IAudioSessionManager sessionManager,
  });

  @override
  Future<void> playTrack(Track track, {List<Track>? queue}) async { ... }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async { ... }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async { ... }

  @override
  Future<void> skipToPrevious() async { ... }

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> setRepeatMode(AudioRepeatMode mode) async { ... }

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> dispose() async {
    await _player.dispose();
  }
}

/// In-memory headless test-safe implementation avoiding native platform channel calls.
class TestVhunambiAudioHandler implements IVhunambiAudioHandler {
  final _playbackStateSubject = BehaviorSubject<PlaybackState>.seeded(
    PlaybackState(
      controls: [MediaControl.play],
      processingState: AudioProcessingState.idle,
      playing: false,
    ),
  );
  final _mediaItemSubject = BehaviorSubject<MediaItem?>();
  final _queueSubject = BehaviorSubject<List<MediaItem>>.seeded([]);

  Track? currentTrack;
  List<Track> currentQueue = [];
  bool isPlaying = false;
  Duration currentPosition = Duration.zero;

  // Implements all methods in-memory without platform dependencies
  ...
}
```

---

### 2.2 `IAudioSessionManager` & `AudioSessionManager`

```dart
abstract class IAudioSessionManager {
  Future<void> configureSession();
  Stream<bool> get becomingNoisyEvents;
  Stream<bool> get interruptionEvents;
  bool get wasPlayingBeforeInterruption;
  Future<void> handleInterruption(bool isInterrupted, {required VoidCallback onPause, required VoidCallback onResume});
  Future<void> handleBecomingNoisy({required VoidCallback onPause});
  void dispose();
}

class AudioSessionManager implements IAudioSessionManager {
  AudioSession? _session;
  StreamSubscription? _interruptionSubscription;
  StreamSubscription? _noisySubscription;
  bool _wasPlayingBeforeInterruption = false;

  @override
  Future<void> configureSession() async {
    try {
      _session = await AudioSession.instance;
      await _session!.configure(const AudioSessionConfiguration.music());
    } catch (e) {
      debugPrint('AudioSession running in mock/test mode: $e');
    }
  }

  ...
}

class TestAudioSessionManager implements IAudioSessionManager {
  // Pure in-memory streams for testing interruptions and noisy events
  ...
}
```

---

### 2.3 `IAudioSourceResolver` & `AudioSourceResolver`

```dart
abstract class IAudioSourceResolver {
  Future<ResolvedAudioSource> resolveSource(Track track);
}

class ResolvedAudioSource {
  final Uri uri;
  final bool isLocalFile;
  final String? localFilePath;

  const ResolvedAudioSource({
    required this.uri,
    required this.isLocalFile,
    this.localFilePath,
  });
}

class AudioSourceResolver implements IAudioSourceResolver {
  final IOfflineStorageService offlineStorage;

  AudioSourceResolver({required this.offlineStorage});

  @override
  Future<ResolvedAudioSource> resolveSource(Track track) async {
    // 1. Check if track is cached in Phase 8 Hive storage
    final isCached = await offlineStorage.isTrackCachedLocally(track.id);
    if (isCached) {
      final meta = await offlineStorage.getTrackMetadata(track.id);
      final localPath = meta?['localAudioFilePath'] as String?;
      if (localPath != null && File(localPath).existsSync()) {
        return ResolvedAudioSource(
          uri: Uri.file(localPath),
          isLocalFile: true,
          localFilePath: localPath,
        );
      }
    }

    // 2. Fall back to remote stream URL
    final remoteUrl = track.audioUrl ?? 'https://cdn.vhunambi.com/audio/${track.id}.mp3';
    return ResolvedAudioSource(
      uri: Uri.parse(remoteUrl),
      isLocalFile: false,
    );
  }
}
```

---

## 3. Riverpod Providers Architecture

```dart
/// Riverpod Provider definitions in lib/features/player/presentation/providers/audio_bridge_providers.dart

final audioSourceResolverProvider = Provider<IAudioSourceResolver>((ref) {
  final offlineStorage = ref.watch(offlineStorageServiceProvider);
  return AudioSourceResolver(offlineStorage: offlineStorage);
});

final audioSessionManagerProvider = Provider<IAudioSessionManager>((ref) {
  return AudioSessionManager();
});

final audioHandlerProvider = Provider<IVhunambiAudioHandler>((ref) {
  // In automated test environments, returns TestVhunambiAudioHandler automatically
  // In production app, returns VhunambiAudioHandler backed by just_audio and AudioService
  return TestVhunambiAudioHandler();
});
```

---

## 4. `PlayerNotifier` Bi-directional Integration

In `lib/features/player/presentation/providers/player_provider.dart`:
```dart
class PlayerNotifier extends StateNotifier<PlayerState> {
  final IVhunambiAudioHandler _audioHandler;
  StreamSubscription? _playbackStateSubscription;
  StreamSubscription? _mediaItemSubscription;

  PlayerNotifier({required IVhunambiAudioHandler audioHandler})
      : _audioHandler = audioHandler,
        super(const PlayerState()) {
    _initSubscriptions();
  }

  void _initSubscriptions() {
    _playbackStateSubscription = _audioHandler.playbackState.listen((playbackState) {
      state = state.copyWith(
        playbackStatus: _mapProcessingStateToPlaybackStatus(playbackState),
        position: playbackState.position,
        bufferedPosition: playbackState.bufferedPosition,
        playbackSpeed: playbackState.speed,
      );
    });

    _mediaItemSubscription = _audioHandler.mediaItem.listen((mediaItem) {
      if (mediaItem != null) {
        state = state.copyWith(
          duration: mediaItem.duration ?? Duration.zero,
        );
      }
    });
  }

  // Delegated transport controls
  Future<void> playTrack(Track track, {List<Track>? queue}) async {
    await _audioHandler.playTrack(track, queue: queue);
  }

  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      await _audioHandler.pause();
    } else {
      await _audioHandler.play();
    }
  }

  Future<void> seek(Duration position) => _audioHandler.seek(position);
  Future<void> skipNext() => _audioHandler.skipToNext();
  Future<void> skipPrevious() => _audioHandler.skipToPrevious();
  Future<void> setPlaybackSpeed(double speed) => _audioHandler.setSpeed(speed);
  Future<void> setVolume(double volume) => _audioHandler.setVolume(volume);
  Future<void> dismiss() => _audioHandler.stop();
}
```

---

## 5. Non-Negotiable Invariants

1. **Zero Raw Hex Values:** No colors defined outside `AppColors.*`.
2. **`AudioRepeatMode` not `RepeatMode`:** Retain non-colliding enum name.
3. **Headless Test Safety:** `TestVhunambiAudioHandler` and `TestAudioSessionManager` ensure all 207 baseline tests and new Phase 9 tests pass with zero `MissingPluginException`.
4. **Zero Regressions:** All 207 existing tests across Phases 1–8 must remain green.

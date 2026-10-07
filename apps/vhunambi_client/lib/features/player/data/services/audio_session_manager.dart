import 'dart:async';

import 'package:audio_session/audio_session.dart' as audio_session;
import 'package:flutter/foundation.dart';
import '../../domain/models/audio_session_events.dart';

/// Contract for hardware audio focus and session lifecycle management
/// (REQ-AUD-06, REQ-AUD-07, REQ-AUD-08).
abstract class IAudioSessionManager {
  /// Configures the platform audio session for music playback.
  Future<void> configureSession();

  /// Requests (and holds) audio focus for active playback.
  Future<void> activate();

  /// `true` once [configureSession] completed on a supported platform.
  bool get isConfigured;

  /// `true` while the app logically holds audio focus.
  bool get isSessionActive;

  /// `true` when playback was running as an interruption began.
  bool get wasPlayingBeforeInterruption;

  /// Rich interruption events (telephony calls, assistant activation, alerts).
  Stream<AudioInterruptionEvent> get interruptionStream;

  /// Rich "becoming noisy" events (headphone / bluetooth disconnection).
  Stream<BecomingNoisyEvent> get becomingNoisyStream;

  /// Boolean projection of [interruptionStream]
  /// (`true` == interruption began).
  Stream<bool> get interruptionEvents;

  /// Boolean projection of [becomingNoisyStream] (always `true` on emit).
  Stream<bool> get becomingNoisyEvents;

  /// Applies the pause/resume policy for an interruption event.
  ///
  /// A pause-type interruption that begins while playing pauses the transport
  /// and records [wasPlayingBeforeInterruption]; when it ends and
  /// [AudioInterruptionEvent.isResumable] is `true`, `onResume` is invoked.
  /// Duck-type interruptions never pause the transport.
  Future<void> handleInterruption(
    AudioInterruptionEvent event, {
    required VoidCallback onPause,
    required VoidCallback onResume,
    bool isCurrentlyPlaying = true,
  });

  /// Applies the becoming-noisy policy: pause immediately, never auto-resume.
  Future<void> handleBecomingNoisy({required VoidCallback onPause});

  void dispose();
}

/// Production audio session manager wrapping `audio_session`.
///
/// Every native call degrades gracefully: on headless CI / unsupported
/// platforms (`MissingPluginException`) the manager keeps its in-memory focus
/// state machine fully operational instead of throwing (REQ-AUD-02).
class AudioSessionManager implements IAudioSessionManager {
  /// Canonical music playback configuration (REQ-AUD-06):
  /// iOS `playback` category / `defaultMode`, Android audio attributes
  /// `contentType: music`, `usage: media`, audio focus gain `gain`.
  static const audio_session.AudioSessionConfiguration musicConfiguration =
      audio_session.AudioSessionConfiguration.music();

  final _interruptionController =
      StreamController<AudioInterruptionEvent>.broadcast();
  final _noisyController = StreamController<BecomingNoisyEvent>.broadcast();

  audio_session.AudioSession? _session;
  StreamSubscription<audio_session.AudioInterruptionEvent>?
      _nativeInterruptionSubscription;
  StreamSubscription<void>? _nativeNoisySubscription;

  bool _isConfigured = false;
  bool _isSessionActive = false;
  bool _wasPlayingBeforeInterruption = false;
  bool _disposed = false;

  @override
  bool get isConfigured => _isConfigured;

  @override
  bool get isSessionActive => _isSessionActive;

  @override
  bool get wasPlayingBeforeInterruption => _wasPlayingBeforeInterruption;

  @override
  Stream<AudioInterruptionEvent> get interruptionStream =>
      _interruptionController.stream;

  @override
  Stream<BecomingNoisyEvent> get becomingNoisyStream =>
      _noisyController.stream;

  @override
  Stream<bool> get interruptionEvents =>
      interruptionStream.map((event) => event.isInterrupted);

  @override
  Stream<bool> get becomingNoisyEvents =>
      becomingNoisyStream.map((event) => event.shouldPause);

  @override
  Future<void> configureSession() async {
    if (_disposed) return;

    try {
      audio_session.AudioSession? session = _session;
      session ??= await audio_session.AudioSession.instance;
      _session = session;

      await session.configure(musicConfiguration);

      _nativeInterruptionSubscription ??=
          session.interruptionEventStream.listen(_onNativeInterruption);
      _nativeNoisySubscription ??= session.becomingNoisyEventStream
          .listen((_) => _emitBecomingNoisy(const BecomingNoisyEvent()));

      _isConfigured = true;
    } catch (error) {
      // Headless tests and unsupported desktops: keep the Dart-side focus
      // machine alive without native bindings.
      debugPrint('AudioSessionManager running in headless mode: $error');
      _isConfigured = false;
    }
  }

  @override
  Future<void> activate() async {
    if (_disposed) return;

    try {
      await _session?.setActive(true);
    } catch (error) {
      debugPrint('AudioSessionManager could not activate native focus: $error');
    }

    // Logical focus intent is retained even when the channel is absent.
    _isSessionActive = true;
  }

  @override
  Future<void> handleInterruption(
    AudioInterruptionEvent event, {
    required VoidCallback onPause,
    required VoidCallback onResume,
    bool isCurrentlyPlaying = true,
  }) async {
    if (event.isInterrupted) {
      _wasPlayingBeforeInterruption = isCurrentlyPlaying;
      if (isCurrentlyPlaying && event.type == AudioInterruptionType.pause) {
        onPause();
      }
      return;
    }

    final shouldResume = _wasPlayingBeforeInterruption && event.isResumable;
    _wasPlayingBeforeInterruption = false;
    if (shouldResume) onResume();
  }

  @override
  Future<void> handleBecomingNoisy({required VoidCallback onPause}) async {
    // REQ-AUD-08: pause immediately; never auto-resume without a user gesture.
    _wasPlayingBeforeInterruption = false;
    onPause();
  }

  void _onNativeInterruption(audio_session.AudioInterruptionEvent event) {
    _emitInterruption(
      AudioInterruptionEvent(
        isInterrupted: event.begin,
        type: event.type == audio_session.AudioInterruptionType.duck
            ? AudioInterruptionType.duck
            : AudioInterruptionType.pause,
        shouldResume: !event.begin &&
            event.type == audio_session.AudioInterruptionType.pause,
      ),
    );
  }

  void _emitInterruption(AudioInterruptionEvent event) {
    if (_interruptionController.isClosed) return;
    _interruptionController.add(event);
  }

  void _emitBecomingNoisy(BecomingNoisyEvent event) {
    if (_noisyController.isClosed) return;
    _noisyController.add(event);
  }

  /// Broadcasts an interruption on behalf of a native bridge.
  ///
  /// Lets tests exercise the production native-event translation path without
  /// a platform channel.
  @visibleForTesting
  void emitInterruption(AudioInterruptionEvent event) =>
      _emitInterruption(event);

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _isSessionActive = false;
    _nativeInterruptionSubscription?.cancel();
    _nativeNoisySubscription?.cancel();
    _interruptionController.close();
    _noisyController.close();
  }
}

/// Headless-safe audio session simulator used by tests and demo builds.
///
/// Mirrors the production focus state machine exactly, but every native call is
/// replaced with an in-memory counter so `flutter test` never touches a platform
/// channel (REQ-AUD-02).
class TestAudioSessionManager implements IAudioSessionManager {
  final _interruptionController =
      StreamController<AudioInterruptionEvent>.broadcast();
  final _noisyController = StreamController<BecomingNoisyEvent>.broadcast();

  /// Interruptions observed through [handleInterruption].
  final List<AudioInterruptionEvent> handledInterruptions =
      <AudioInterruptionEvent>[];

  /// Becoming-noisy signals observed through [handleBecomingNoisy].
  final List<BecomingNoisyEvent> handledBecomingNoisy = <BecomingNoisyEvent>[];

  int configureCallCount = 0;
  int activateCallCount = 0;

  bool _isConfigured = false;
  bool _isSessionActive = false;
  bool _wasPlayingBeforeInterruption = false;
  bool _disposed = false;

  @override
  bool get isConfigured => _isConfigured;

  @override
  bool get isSessionActive => _isSessionActive;

  @override
  bool get wasPlayingBeforeInterruption => _wasPlayingBeforeInterruption;

  @override
  Stream<AudioInterruptionEvent> get interruptionStream =>
      _interruptionController.stream;

  @override
  Stream<BecomingNoisyEvent> get becomingNoisyStream =>
      _noisyController.stream;

  @override
  Stream<bool> get interruptionEvents =>
      interruptionStream.map((event) => event.isInterrupted);

  @override
  Stream<bool> get becomingNoisyEvents =>
      becomingNoisyStream.map((event) => event.shouldPause);

  @override
  Future<void> configureSession() async {
    if (_disposed) return;
    configureCallCount++;
    _isConfigured = true;
  }

  @override
  Future<void> activate() async {
    if (_disposed) return;
    activateCallCount++;
    _isSessionActive = true;
  }

  @override
  Future<void> handleInterruption(
    AudioInterruptionEvent event, {
    required VoidCallback onPause,
    required VoidCallback onResume,
    bool isCurrentlyPlaying = true,
  }) async {
    handledInterruptions.add(event);

    if (event.isInterrupted) {
      _wasPlayingBeforeInterruption = isCurrentlyPlaying;
      if (isCurrentlyPlaying && event.type == AudioInterruptionType.pause) {
        onPause();
      }
      return;
    }

    final shouldResume = _wasPlayingBeforeInterruption && event.isResumable;
    _wasPlayingBeforeInterruption = false;
    if (shouldResume) onResume();
  }

  @override
  Future<void> handleBecomingNoisy({required VoidCallback onPause}) async {
    _wasPlayingBeforeInterruption = false;
    handledBecomingNoisy.add(const BecomingNoisyEvent());
    onPause();
  }

  /// Pushes a simulated OS interruption into [interruptionStream].
  void simulateInterruption(AudioInterruptionEvent event) {
    if (_interruptionController.isClosed) return;
    _interruptionController.add(event);
  }

  /// Pushes a simulated headphone / bluetooth disconnection.
  void simulateBecomingNoisy([
    BecomingNoisyEvent event = const BecomingNoisyEvent(),
  ]) {
    if (_noisyController.isClosed) return;
    _noisyController.add(event);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _isSessionActive = false;
    _interruptionController.close();
    _noisyController.close();
  }
}

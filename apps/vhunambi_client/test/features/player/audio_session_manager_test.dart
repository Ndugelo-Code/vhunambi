import 'package:audio_session/audio_session.dart' as audio_session;
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/player/data/services/audio_session_manager.dart';
import 'package:vhunambi_client/features/player/domain/models/audio_session_events.dart';

/// T9.6 — Audio session focus suite (T9.3 / REQ-AUD-06 → REQ-AUD-08).
void main() {
  group('Audio session domain models', () {
    test('classifies begin, end and duck interruptions', () {
      const begin = AudioInterruptionEvent.begin();
      expect(begin.isInterrupted, isTrue);
      expect(begin.type, AudioInterruptionType.pause);
      expect(begin.shouldResume, isFalse);
      expect(begin.isResumable, isFalse);
      expect(begin.isDuck, isFalse);

      const end = AudioInterruptionEvent.end();
      expect(end.isInterrupted, isFalse);
      expect(end.shouldResume, isTrue);
      expect(end.isResumable, isTrue);

      const duck = AudioInterruptionEvent.begin(
        type: AudioInterruptionType.duck,
      );
      expect(duck.isDuck, isTrue);
      expect(duck.isInterrupted, isTrue);

      // A ducked focus never resumes the transport; only volume is restored.
      const duckEnd = AudioInterruptionEvent.end(
        type: AudioInterruptionType.duck,
      );
      expect(duckEnd.isResumable, isFalse);
    });

    test('copyWith preserves untouched fields and value equality holds', () {
      const original = AudioInterruptionEvent.begin();
      final updated = original.copyWith(
        isInterrupted: false,
        shouldResume: true,
      );

      expect(updated.isInterrupted, isFalse);
      expect(updated.shouldResume, isTrue);
      expect(updated.type, AudioInterruptionType.pause);
      expect(updated, isNot(original));
      expect(original.copyWith(), original);
      expect(original.copyWith().hashCode, original.hashCode);
      expect(original.toString(), contains('isInterrupted: true'));

      const noisy = BecomingNoisyEvent();
      expect(noisy.shouldPause, isTrue);
      expect(noisy.copyWith(shouldPause: false).shouldPause, isFalse);
      expect(noisy.copyWith(), noisy);
      expect(noisy.toString(), contains('shouldPause: true'));
    });
  });

  group('TestAudioSessionManager', () {
    test('configureSession and activate drive the focus state machine',
        () async {
      final manager = TestAudioSessionManager();
      addTearDown(manager.dispose);

      expect(manager.isConfigured, isFalse);
      expect(manager.isSessionActive, isFalse);

      await manager.configureSession();
      await manager.activate();

      expect(manager.configureCallCount, 1);
      expect(manager.activateCallCount, 1);
      expect(manager.isConfigured, isTrue);
      expect(manager.isSessionActive, isTrue);
    });

    test('a pause-type interruption pauses playback and arms auto-resume',
        () async {
      final manager = TestAudioSessionManager();
      addTearDown(manager.dispose);

      var pauses = 0;
      var resumes = 0;

      await manager.handleInterruption(
        const AudioInterruptionEvent.begin(),
        onPause: () => pauses++,
        onResume: () => resumes++,
        isCurrentlyPlaying: true,
      );

      expect(pauses, 1);
      expect(resumes, 0);
      expect(manager.wasPlayingBeforeInterruption, isTrue);
      expect(manager.handledInterruptions, hasLength(1));
    });

    test('resumes playback when focus returns and resumption is permitted',
        () async {
      final manager = TestAudioSessionManager();
      addTearDown(manager.dispose);

      var pauses = 0;
      var resumes = 0;

      await manager.handleInterruption(
        const AudioInterruptionEvent.begin(),
        onPause: () => pauses++,
        onResume: () => resumes++,
      );
      await manager.handleInterruption(
        const AudioInterruptionEvent.end(),
        onPause: () => pauses++,
        onResume: () => resumes++,
        isCurrentlyPlaying: false,
      );

      expect(pauses, 1);
      expect(resumes, 1);
      expect(manager.wasPlayingBeforeInterruption, isFalse);
    });

    test('never auto-resumes when playback was already paused', () async {
      final manager = TestAudioSessionManager();
      addTearDown(manager.dispose);

      var pauses = 0;
      var resumes = 0;

      await manager.handleInterruption(
        const AudioInterruptionEvent.begin(),
        onPause: () => pauses++,
        onResume: () => resumes++,
        isCurrentlyPlaying: false,
      );
      await manager.handleInterruption(
        const AudioInterruptionEvent.end(),
        onPause: () => pauses++,
        onResume: () => resumes++,
      );

      expect(pauses, 0);
      expect(resumes, 0);
    });

    test('duck interruptions leave the transport playing', () async {
      final manager = TestAudioSessionManager();
      addTearDown(manager.dispose);

      var pauses = 0;
      var resumes = 0;

      await manager.handleInterruption(
        const AudioInterruptionEvent.begin(
          type: AudioInterruptionType.duck,
        ),
        onPause: () => pauses++,
        onResume: () => resumes++,
      );
      await manager.handleInterruption(
        const AudioInterruptionEvent.end(type: AudioInterruptionType.duck),
        onPause: () => pauses++,
        onResume: () => resumes++,
      );

      expect(pauses, 0);
      expect(resumes, 0);
    });

    test('simulated OS events surface on the rich and boolean streams',
        () async {
      final manager = TestAudioSessionManager();
      addTearDown(manager.dispose);

      final richEvents = <AudioInterruptionEvent>[];
      final booleanEvents = <bool>[];
      final noisyEvents = <bool>[];

      final richSubscription = manager.interruptionStream.listen(
        richEvents.add,
      );
      final booleanSubscription = manager.interruptionEvents.listen(
        booleanEvents.add,
      );
      final noisySubscription = manager.becomingNoisyEvents.listen(
        noisyEvents.add,
      );
      addTearDown(() async {
        await richSubscription.cancel();
        await booleanSubscription.cancel();
        await noisySubscription.cancel();
      });

      manager.simulateInterruption(const AudioInterruptionEvent.begin());
      manager.simulateBecomingNoisy();
      await Future<void>.delayed(Duration.zero);

      expect(richEvents, hasLength(1));
      expect(richEvents.single.isInterrupted, isTrue);
      expect(booleanEvents, <bool>[true]);
      expect(noisyEvents, <bool>[true]);
    });

    test('dispose drops focus, closes streams and is idempotent', () async {
      final manager = TestAudioSessionManager();

      await manager.configureSession();
      await manager.activate();
      expect(manager.isSessionActive, isTrue);

      manager.dispose();
      expect(manager.isSessionActive, isFalse);
      expect(manager.isConfigured, isTrue);

      // Post-disposal simulated native calls are inert.
      await manager.configureSession();
      expect(manager.configureCallCount, 1);
      manager.simulateInterruption(const AudioInterruptionEvent.begin());
      manager.dispose();
    });
  });

  group('AudioSessionManager (headless degradation)', () {
    test('configureSession and activate never throw without platform channels',
        () async {
      final manager = AudioSessionManager();
      addTearDown(manager.dispose);

      await expectLater(manager.configureSession(), completes);
      await expectLater(manager.activate(), completes);

      // No native bindings exist under `flutter test`, so configuration is
      // reported as unavailable while logical focus intent is still retained.
      expect(manager.isConfigured, isFalse);
      expect(manager.isSessionActive, isTrue);
    });

    test('declares the music configuration required for hardware focus', () {
      final configuration = AudioSessionManager.musicConfiguration;

      expect(
        configuration.avAudioSessionCategory,
        audio_session.AVAudioSessionCategory.playback,
      );
      expect(
        configuration.avAudioSessionMode,
        audio_session.AVAudioSessionMode.defaultMode,
      );
      expect(
        configuration.androidAudioAttributes?.contentType,
        audio_session.AndroidAudioContentType.music,
      );
      expect(
        configuration.androidAudioAttributes?.usage,
        audio_session.AndroidAudioUsage.media,
      );
      expect(
        configuration.androidAudioFocusGainType,
        audio_session.AndroidAudioFocusGainType.gain,
      );
    });

    test('translates interruptions broadcast by the native bridge', () async {
      final manager = AudioSessionManager();
      addTearDown(manager.dispose);

      final received = <bool>[];
      final subscription = manager.interruptionEvents.listen(received.add);
      addTearDown(subscription.cancel);

      manager.emitInterruption(const AudioInterruptionEvent.begin());
      manager.emitInterruption(const AudioInterruptionEvent.end());
      await Future<void>.delayed(Duration.zero);

      expect(received, <bool>[true, false]);
    });

    test('applies the same pause/resume policy as the headless manager',
        () async {
      final manager = AudioSessionManager();
      addTearDown(manager.dispose);

      var pauses = 0;
      var resumes = 0;

      await manager.handleInterruption(
        const AudioInterruptionEvent.begin(),
        onPause: () => pauses++,
        onResume: () => resumes++,
      );
      await manager.handleInterruption(
        const AudioInterruptionEvent.end(),
        onPause: () => pauses++,
        onResume: () => resumes++,
      );

      expect(pauses, 1);
      expect(resumes, 1);
      expect(manager.wasPlayingBeforeInterruption, isFalse);
    });
  });
}

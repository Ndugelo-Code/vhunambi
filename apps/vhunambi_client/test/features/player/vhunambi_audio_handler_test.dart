import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' show LoopMode, ProcessingState;
import 'package:vhunambi_client/features/player/data/services/audio_session_manager.dart';
import 'package:vhunambi_client/features/player/data/services/audio_source_resolver.dart';
import 'package:vhunambi_client/features/player/data/services/vhunambi_audio_handler.dart';
import 'package:vhunambi_client/features/player/domain/models/audio_session_events.dart';
import 'package:vhunambi_client/features/player/domain/models/player_state.dart';
import 'package:vhunambi_client/shared/models/track.dart';

/// T9.6 — Platform audio handler suite (T9.4 / REQ-AUD-01 → REQ-AUD-05).
///
/// Exercises the OS-facing mapping contract plus the complete in-memory
/// transport of [TestVhunambiAudioHandler]; the production
/// [VhunambiAudioHandler] needs a live `just_audio` engine and is verified by
/// the same shared mapping functions it delegates to.
void main() {
  group('Track → MediaItem mapping (REQ-AUD-03)', () {
    test('maps every required metadata field and extras payload', () {
      final item = buildMediaItemForTrack(_track());

      expect(item.id, 'trk_handler_001');
      expect(item.title, 'Lockscreen Master');
      expect(item.artist, 'Vhusi Test');
      expect(item.album, 'Amapiano');
      expect(item.duration, const Duration(minutes: 3, seconds: 29));
      expect(
        item.artUri,
        Uri.parse('https://vhunambi.com/covers/trk_handler_001.jpg'),
      );
      expect(item.displayTitle, 'Lockscreen Master');
      expect(item.displaySubtitle, 'Amapiano • Tshivenḓa');
      expect(item.displayDescription, '@vhusi_test • Vhunambi stream');
      expect(item.extras?['language'], 'Tshivenḓa');
      expect(item.extras?['mood'], 'Energetic');
      expect(item.extras?['isOffline'], isFalse);
      expect(item.extras?['source'], 'stream');
      expect(
        item.extras?['remoteAudioUrl'],
        'https://vhunambi.com/audio/trk_handler_001.mp3',
      );
      expect(item.extras?['localFilePath'], isNull);
    });

    test('flags offline vault playback and carries the local path', () {
      final item = buildMediaItemForTrack(
        _track(),
        isOffline: true,
        localFilePath: '/vault/audio/trk_handler_001.mp3',
      );

      expect(item.extras?['isOffline'], isTrue);
      expect(item.extras?['source'], 'vault');
      expect(
        item.extras?['localFilePath'],
        '/vault/audio/trk_handler_001.mp3',
      );
      expect(item.displayDescription, contains('Offline vault'));
      expect(item.displayDescription, startsWith('@vhusi_test'));
    });

    test('omits artwork when the track has no cover url', () {
      final item = buildMediaItemForTrack(_track(coverUrl: null));

      expect(item.artUri, isNull);
    });
  });

  group('Playback state mapping (blueprint §5.2)', () {
    test('maps every Vhunambi playback status onto a processing state', () {
      expect(
        mapPlaybackStatusToProcessingState(PlaybackStatus.idle),
        AudioProcessingState.idle,
      );
      expect(
        mapPlaybackStatusToProcessingState(PlaybackStatus.buffering),
        AudioProcessingState.buffering,
      );
      expect(
        mapPlaybackStatusToProcessingState(PlaybackStatus.playing),
        AudioProcessingState.ready,
      );
      expect(
        mapPlaybackStatusToProcessingState(PlaybackStatus.paused),
        AudioProcessingState.ready,
      );
      expect(
        mapPlaybackStatusToProcessingState(PlaybackStatus.completed),
        AudioProcessingState.completed,
      );
      expect(
        mapPlaybackStatusToProcessingState(PlaybackStatus.error),
        AudioProcessingState.error,
      );

      expect(isPlayingStatus(PlaybackStatus.playing), isTrue);
      expect(isPlayingStatus(PlaybackStatus.buffering), isTrue);
      expect(isPlayingStatus(PlaybackStatus.paused), isFalse);
      expect(isPlayingStatus(PlaybackStatus.idle), isFalse);
    });

    test('maps OS processing states back onto Vhunambi status', () {
      expect(
        mapProcessingStateToPlaybackStatus(
          AudioProcessingState.idle,
          playing: false,
        ),
        PlaybackStatus.idle,
      );
      expect(
        mapProcessingStateToPlaybackStatus(
          AudioProcessingState.loading,
          playing: true,
        ),
        PlaybackStatus.buffering,
      );
      expect(
        mapProcessingStateToPlaybackStatus(
          AudioProcessingState.buffering,
          playing: true,
        ),
        PlaybackStatus.buffering,
      );
      expect(
        mapProcessingStateToPlaybackStatus(
          AudioProcessingState.ready,
          playing: true,
        ),
        PlaybackStatus.playing,
      );
      expect(
        mapProcessingStateToPlaybackStatus(
          AudioProcessingState.ready,
          playing: false,
        ),
        PlaybackStatus.paused,
      );
      expect(
        mapProcessingStateToPlaybackStatus(
          AudioProcessingState.completed,
          playing: false,
        ),
        PlaybackStatus.completed,
      );
      expect(
        mapProcessingStateToPlaybackStatus(
          AudioProcessingState.error,
          playing: false,
        ),
        PlaybackStatus.error,
      );
    });
  });

  group('OS transport contract (REQ-AUD-01/04/05)', () {
    test('round-trips repeat modes and just_audio processing states', () {
      expect(
        mapAudioRepeatMode(AudioRepeatMode.off),
        AudioServiceRepeatMode.none,
      );
      expect(
        mapAudioRepeatMode(AudioRepeatMode.all),
        AudioServiceRepeatMode.all,
      );
      expect(
        mapAudioRepeatMode(AudioRepeatMode.one),
        AudioServiceRepeatMode.one,
      );

      expect(
        mapAudioServiceRepeatMode(AudioServiceRepeatMode.none),
        AudioRepeatMode.off,
      );
      expect(
        mapAudioServiceRepeatMode(AudioServiceRepeatMode.group),
        AudioRepeatMode.all,
      );
      expect(
        mapAudioServiceRepeatMode(AudioServiceRepeatMode.one),
        AudioRepeatMode.one,
      );

      expect(mapAudioRepeatModeToLoopMode(AudioRepeatMode.off), LoopMode.off);
      expect(mapAudioRepeatModeToLoopMode(AudioRepeatMode.all), LoopMode.all);
      expect(mapAudioRepeatModeToLoopMode(AudioRepeatMode.one), LoopMode.one);

      expect(
        mapJustAudioProcessingState(ProcessingState.idle),
        AudioProcessingState.idle,
      );
      expect(
        mapJustAudioProcessingState(ProcessingState.loading),
        AudioProcessingState.loading,
      );
      expect(
        mapJustAudioProcessingState(ProcessingState.buffering),
        AudioProcessingState.buffering,
      );
      expect(
        mapJustAudioProcessingState(ProcessingState.ready),
        AudioProcessingState.ready,
      );
      expect(
        mapJustAudioProcessingState(ProcessingState.completed),
        AudioProcessingState.completed,
      );
    });

    test('builds compact OS controls with system actions', () {
      final playing = buildOsPlaybackState(
        status: PlaybackStatus.playing,
        position: const Duration(seconds: 42),
        bufferedPosition: const Duration(seconds: 90),
        speed: 1.25,
        queueIndex: 2,
      );

      expect(
        playing.controls.map((control) => control.action).toList(),
        <MediaAction>[
          MediaAction.skipToPrevious,
          MediaAction.pause,
          MediaAction.skipToNext,
          MediaAction.stop,
        ],
      );
      expect(playing.androidCompactActionIndices, <int>[0, 1, 2]);
      expect(playing.systemActions, contains(MediaAction.seek));
      expect(playing.processingState, AudioProcessingState.ready);
      expect(playing.playing, isTrue);
      expect(playing.updatePosition, const Duration(seconds: 42));
      expect(playing.bufferedPosition, const Duration(seconds: 90));
      expect(playing.speed, 1.25);
      expect(playing.queueIndex, 2);

      final paused = buildOsPlaybackState(
        status: PlaybackStatus.paused,
        position: Duration.zero,
      );
      expect(paused.controls.first.action, MediaAction.skipToPrevious);
      expect(paused.controls[1].action, MediaAction.play);
      expect(paused.playing, isFalse);
      expect(paused.repeatMode, AudioServiceRepeatMode.none);

      final failed = buildOsPlaybackState(
        status: PlaybackStatus.error,
        position: Duration.zero,
        errorMessage: 'boom',
      );
      expect(failed.processingState, AudioProcessingState.error);
      expect(failed.errorMessage, 'boom');
    });

    test('declares the notification channel identity', () {
      expect(kAudioNotificationChannelId, 'com.vhunambi.app.audio');
      expect(kAudioNotificationChannelName, 'Vhunambi Music Playback');
      expect(
        kAudioNotificationChannelDescription,
        'African AI Music Synthesis & Creator Playback',
      );
      expect(kAudioNotificationIcon, 'drawable/ic_stat_music');
      expect(kAndroidCompactActionIndices, <int>[0, 1, 2]);
    });
  });

  group('TestVhunambiAudioHandler transport', () {
    test('playTrack publishes metadata, queue and a playing state', () async {
      final handler = TestVhunambiAudioHandler();
      addTearDown(handler.dispose);

      final items = <MediaItem?>[];
      final queues = <List<MediaItem>>[];
      handler.mediaItem.listen(items.add);
      handler.queue.listen(queues.add);

      await handler.playTrack(
        _track(),
        queue: <Track>[_track(), _track(id: 'trk_handler_002')],
      );
      await _settle();

      expect(handler.currentTrack?.id, 'trk_handler_001');
      expect(handler.playbackStatus, PlaybackStatus.playing);
      expect(handler.currentMediaItem?.id, 'trk_handler_001');
      expect(handler.currentPlaybackState.playing, isTrue);
      expect(
        handler.currentPlaybackState.processingState,
        AudioProcessingState.ready,
      );
      expect(handler.currentPlaybackState.updatePosition, Duration.zero);
      expect(handler.currentPlaybackState.queueIndex, 0);
      expect(handler.trackQueue, hasLength(2));
      expect(handler.queueIndex, 0);
      expect(items.last?.title, 'Lockscreen Master');
      expect(queues.last, hasLength(2));
      expect(handler.isDisposed, isFalse);
    });

    test('pause, play, seek and stop drive the published state', () async {
      final handler = TestVhunambiAudioHandler();
      addTearDown(handler.dispose);

      final items = <MediaItem?>[];
      handler.mediaItem.listen(items.add);

      await handler.playTrack(_track());

      await handler.pause();
      expect(handler.playbackStatus, PlaybackStatus.paused);
      expect(handler.currentPlaybackState.playing, isFalse);

      await handler.play();
      expect(handler.playbackStatus, PlaybackStatus.playing);

      await handler.seek(const Duration(seconds: 45));
      expect(handler.position, const Duration(seconds: 45));
      expect(
        handler.currentPlaybackState.updatePosition,
        const Duration(seconds: 45),
      );

      await handler.stop();
      await _settle();

      expect(handler.playbackStatus, PlaybackStatus.idle);
      expect(handler.currentTrack, isNull);
      expect(handler.currentMediaItem, isNull);
      expect(items.last, isNull);
    });

    test('skipToNext and skipToPrevious navigate the queue cyclically',
        () async {
      final handler = TestVhunambiAudioHandler();
      addTearDown(handler.dispose);

      await handler.playTrack(
        _track(),
        queue: <Track>[
          _track(),
          _track(id: 'trk_handler_002'),
          _track(id: 'trk_handler_003'),
        ],
      );

      await handler.skipToNext();
      expect(handler.currentTrack?.id, 'trk_handler_002');
      expect(handler.queueIndex, 1);
      expect(handler.currentMediaItem?.id, 'trk_handler_002');

      await handler.skipToNext();
      await handler.skipToNext();
      expect(handler.currentTrack?.id, 'trk_handler_001');
      expect(handler.queueIndex, 0);
      expect(handler.position, Duration.zero);
    });

    test('skipToPrevious restarts the track when elapsed exceeds 3 seconds',
        () async {
      final handler = TestVhunambiAudioHandler();
      addTearDown(handler.dispose);

      await handler.playTrack(
        _track(),
        queue: <Track>[_track(), _track(id: 'trk_handler_002')],
      );

      await handler.seek(const Duration(seconds: 5));
      await handler.skipToPrevious();

      expect(handler.currentTrack?.id, 'trk_handler_001');
      expect(handler.position, Duration.zero);

      await handler.seek(const Duration(seconds: 1));
      await handler.skipToPrevious();

      expect(handler.currentTrack?.id, 'trk_handler_002');
      expect(handler.queueIndex, 1);
    });

    test('setSpeed, repeat modes and volume clamp then republish', () async {
      final handler = TestVhunambiAudioHandler();
      addTearDown(handler.dispose);

      await handler.playTrack(_track());

      await handler.setSpeed(1.25);
      expect(handler.speed, 1.25);
      expect(handler.currentPlaybackState.speed, 1.25);

      await handler.setSpeed(9);
      expect(handler.speed, 3.0);

      await handler.setVhunambiRepeatMode(AudioRepeatMode.all);
      expect(handler.repeatMode, AudioRepeatMode.all);
      expect(
        handler.currentPlaybackState.repeatMode,
        AudioServiceRepeatMode.all,
      );

      await handler.setRepeatMode(AudioServiceRepeatMode.one);
      expect(handler.repeatMode, AudioRepeatMode.one);

      await handler.setVolume(0.4);
      expect(handler.volume, 0.4);
      await handler.setVolume(2);
      expect(handler.volume, 1.0);
    });

    test('publishes an error state when the source cannot be resolved',
        () async {
      final handler = TestVhunambiAudioHandler(
        sourceResolver: const _FailingSourceResolver(
          'Offline mode is enabled and this track is not cached.',
        ),
      );
      addTearDown(handler.dispose);

      await handler.playTrack(_track(id: 'trk_unresolved'));

      expect(handler.playbackStatus, PlaybackStatus.error);
      expect(
        handler.currentPlaybackState.processingState,
        AudioProcessingState.error,
      );
      expect(
        handler.currentPlaybackState.errorMessage,
        contains('Offline mode is enabled'),
      );
      expect(handler.currentTrack, isNull);
      expect(handler.currentMediaItem, isNull);
    });

    test('interruptions pause the transport and resume when focus returns',
        () async {
      final session = TestAudioSessionManager();
      addTearDown(session.dispose);

      final handler = TestVhunambiAudioHandler(sessionManager: session);
      addTearDown(handler.dispose);

      await handler.playTrack(_track());
      expect(handler.playbackStatus, PlaybackStatus.playing);

      session.simulateInterruption(const AudioInterruptionEvent.begin());
      await _settle();

      expect(handler.playbackStatus, PlaybackStatus.paused);
      expect(session.wasPlayingBeforeInterruption, isTrue);

      session.simulateInterruption(const AudioInterruptionEvent.end());
      await _settle();

      expect(handler.playbackStatus, PlaybackStatus.playing);
    });

    test('becoming noisy pauses immediately', () async {
      final session = TestAudioSessionManager();
      addTearDown(session.dispose);

      final handler = TestVhunambiAudioHandler(sessionManager: session);
      addTearDown(handler.dispose);

      await handler.playTrack(_track());

      session.simulateBecomingNoisy();
      await _settle();

      expect(handler.playbackStatus, PlaybackStatus.paused);
      expect(session.wasPlayingBeforeInterruption, isFalse);
    });

    test('dispose closes the streams and makes further calls inert', () async {
      final handler = TestVhunambiAudioHandler();

      await handler.playTrack(_track());
      await handler.dispose();

      expect(handler.isDisposed, isTrue);

      // Late commands from a killed OS session must not throw.
      await handler.playTrack(_track(id: 'trk_after_dispose'));
      await handler.pause();
      await handler.seek(const Duration(seconds: 30));
      await handler.stop();
      await handler.dispose();

      expect(handler.currentTrack?.id, 'trk_handler_001');
    });
  });
}

/// Lets queued stream deliveries and handler futures settle.
Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

/// Source resolver that always fails, mimicking forced-offline playback.
class _FailingSourceResolver implements IAudioSourceResolver {
  const _FailingSourceResolver(this.message);

  final String message;

  @override
  Future<ResolvedAudioSource> resolveSource(Track track) {
    throw AudioSourceException(message, trackId: track.id);
  }
}

Track _track({
  String id = 'trk_handler_001',
  String? coverUrl = 'https://vhunambi.com/covers/trk_handler_001.jpg',
}) {
  return Track(
    id: id,
    title: 'Lockscreen Master',
    creatorName: 'Vhusi Test',
    genre: 'Amapiano',
    language: 'Tshivenḓa',
    duration: const Duration(minutes: 3, seconds: 29),
    audioUrl: 'https://vhunambi.com/audio/$id.mp3',
    coverUrl: coverUrl,
    mood: 'Energetic',
  );
}

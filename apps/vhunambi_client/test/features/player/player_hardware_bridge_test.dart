import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vhunambi_client/features/offline/presentation/providers/offline_providers.dart';
import 'package:vhunambi_client/features/player/data/services/audio_session_manager.dart';
import 'package:vhunambi_client/features/player/data/services/audio_source_resolver.dart';
import 'package:vhunambi_client/features/player/data/services/vhunambi_audio_handler.dart';
import 'package:vhunambi_client/features/player/domain/models/audio_session_events.dart';
import 'package:vhunambi_client/features/player/domain/models/player_state.dart';
import 'package:vhunambi_client/features/player/presentation/providers/audio_bridge_providers.dart';
import 'package:vhunambi_client/features/player/presentation/providers/player_provider.dart';
import 'package:vhunambi_client/shared/models/track.dart';

/// T9.6 — Bi-directional Riverpod ⇄ OS transport bridge suite
/// (T9.5 / REQ-AUD-10).
///
/// Verifies that UI commands reach the audio handler and that hardware events
/// (lockscreen, bluetooth remote, SMTC, audio focus changes) flow back into
/// `playerStateProvider` — including the zero-regression contract that the
/// seeded player state and synchronous UI mutations are preserved.
void main() {
  late Directory vaultDir;

  setUp(() {
    vaultDir = Directory.systemTemp.createTempSync('vhunambi_bridge_test_');
    // Hive is re-homed so the Phase 8 storage service can open its boxes when a
    // bridge provider pulls it in (see the resolver-preference test below).
    Hive.init(vaultDir.path);
    addTearDown(() async {
      await Hive.close();
      if (vaultDir.existsSync()) vaultDir.deleteSync(recursive: true);
    });
  });

  group('PlayerNotifier hardware bridge', () {
    test('keeps the seeded player state while binding the injected handler', () {
      final handler = _handler();
      addTearDown(handler.dispose);
      final container = _container(handler);
      addTearDown(container.dispose);

      final state = container.read(playerStateProvider);
      expect(state.currentTrack?.id, 'track_default_1');
      expect(state.currentTrack?.title, 'Grateful in the Light');
      expect(state.playbackStatus, PlaybackStatus.playing);
      expect(state.position, const Duration(seconds: 13));
      expect(state.duration, const Duration(minutes: 3, seconds: 29));

      expect(
        container.read(playerStateProvider.notifier).audioHandler,
        same(handler),
      );
    });

    test('UI transport commands are delegated to the audio handler', () async {
      final handler = _handler();
      addTearDown(handler.dispose);
      final container = _container(handler);
      addTearDown(container.dispose);
      final notifier = container.read(playerStateProvider.notifier);
      final track = _track();

      notifier.playTrack(track);
      await _settle();

      expect(container.read(playerStateProvider).currentTrack?.id, track.id);
      expect(handler.currentTrack?.id, track.id);
      expect(handler.currentPlaybackState.playing, isTrue);

      notifier.togglePlayPause();
      await _settle();

      expect(handler.currentPlaybackState.playing, isFalse);
      expect(container.read(playerStateProvider).isPlaying, isFalse);
    });

    test('hardware play and pause update the UI state', () async {
      final handler = _handler();
      addTearDown(handler.dispose);
      final container = _container(handler);
      addTearDown(container.dispose);

      // A lockscreen pause arrives on the handler, not through the UI.
      await handler.playTrack(_track());
      expect(container.read(playerStateProvider).isPlaying, isTrue);

      await handler.pause();
      expect(
        container.read(playerStateProvider).playbackStatus,
        PlaybackStatus.paused,
      );

      await handler.play();
      expect(
        container.read(playerStateProvider).playbackStatus,
        PlaybackStatus.playing,
      );
    });

    test('hardware seek jumps are mirrored into the UI position', () async {
      final handler = _handler();
      addTearDown(handler.dispose);
      final container = _container(handler);
      addTearDown(container.dispose);

      // Materialise the notifier first: it is what subscribes to the streams.
      container.read(playerStateProvider.notifier);

      await handler.playTrack(_track());
      await handler.seek(const Duration(minutes: 2, seconds: 10));

      final state = container.read(playerStateProvider);
      expect(state.position, const Duration(minutes: 2, seconds: 10));
      expect(state.bufferedPosition, const Duration(minutes: 3, seconds: 29));
    });

    test('sub-threshold hardware ticks leave the UI clock untouched', () async {
      final handler = _handler();
      addTearDown(handler.dispose);
      final container = _container(handler);
      addTearDown(container.dispose);

      container.read(playerStateProvider.notifier);

      await handler.playTrack(_track());
      final before = container.read(playerStateProvider).position;

      // A one-second delta stays with the UI ticker's own interpolation.
      await handler.seek(before + const Duration(seconds: 1));

      expect(container.read(playerStateProvider).position, before);
    });

    test('audio focus interruptions drive the UI through pause and resume',
        () async {
      final session = TestAudioSessionManager();
      addTearDown(session.dispose);
      final handler = _handler(sessionManager: session);
      addTearDown(handler.dispose);
      final container = _container(handler);
      addTearDown(container.dispose);

      await handler.playTrack(_track());
      expect(
        container.read(playerStateProvider).playbackStatus,
        PlaybackStatus.playing,
      );

      session.simulateInterruption(const AudioInterruptionEvent.begin());
      await _settle();

      expect(session.wasPlayingBeforeInterruption, isTrue);
      expect(
        container.read(playerStateProvider).playbackStatus,
        PlaybackStatus.paused,
      );

      session.simulateInterruption(const AudioInterruptionEvent.end());
      await _settle();

      expect(
        container.read(playerStateProvider).playbackStatus,
        PlaybackStatus.playing,
      );
    });

    test('a disconnecting audio peripheral pauses the UI state', () async {
      final session = TestAudioSessionManager();
      addTearDown(session.dispose);
      final handler = _handler(sessionManager: session);
      addTearDown(handler.dispose);
      final container = _container(handler);
      addTearDown(container.dispose);

      container.read(playerStateProvider.notifier);

      await handler.playTrack(_track());
      session.simulateBecomingNoisy();
      await _settle();

      expect(
        container.read(playerStateProvider).playbackStatus,
        PlaybackStatus.paused,
      );
      expect(session.wasPlayingBeforeInterruption, isFalse);
    });

    test('bridge providers expose the offline-aware resolver and handler', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(audioHandlerProvider),
        isA<TestVhunambiAudioHandler>(),
      );
      expect(
        container.read(audioSessionManagerProvider),
        isA<AudioSessionManager>(),
      );

      final resolver =
          container.read(audioSourceResolverProvider) as AudioSourceResolver;
      expect(resolver.isOfflineModeForced, isFalse);

      // The guard reads the live Phase 8 preference without rebuilding.
      container.read(offlinePreferencesProvider.notifier).toggleOfflineMode();
      expect(resolver.isOfflineModeForced, isTrue);
    });
  });
}

/// Builds a headless handler backed by a stub resolver (no vault, no IO).
TestVhunambiAudioHandler _handler({IAudioSessionManager? sessionManager}) {
  return TestVhunambiAudioHandler(
    sourceResolver: const _StubSourceResolver(),
    sessionManager: sessionManager,
  );
}

/// Container whose only override is the OS transport handler.
ProviderContainer _container(IVhunambiAudioHandler handler) {
  return ProviderContainer(
    overrides: <Override>[audioHandlerProvider.overrideWithValue(handler)],
  );
}

/// Lets queued stream deliveries and handler futures settle.
Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

/// Resolver that always streams from the cloud.
class _StubSourceResolver implements IAudioSourceResolver {
  const _StubSourceResolver();

  @override
  Future<ResolvedAudioSource> resolveSource(Track track) {
    final url = track.audioUrl ?? 'https://vhunambi.com/audio/${track.id}.mp3';
    return Future<ResolvedAudioSource>.value(
      ResolvedAudioSource(uri: Uri.parse(url), isLocalFile: false),
    );
  }
}

Track _track({String id = 'trk_bridge_001'}) {
  return Track(
    id: id,
    title: 'Bridge Master',
    creatorName: 'Vhusi Test',
    genre: 'Amapiano',
    language: 'Tshivenḓa',
    duration: const Duration(minutes: 3, seconds: 29),
    audioUrl: 'https://vhunambi.com/audio/$id.mp3',
  );
}
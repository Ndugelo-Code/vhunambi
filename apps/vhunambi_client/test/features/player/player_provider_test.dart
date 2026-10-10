import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/player/data/services/vhunambi_audio_handler.dart';
import 'package:vhunambi_client/features/player/domain/models/player_state.dart';
import 'package:vhunambi_client/features/player/presentation/providers/player_provider.dart';
import 'package:vhunambi_client/shared/models/track.dart';

/// Mission 9 — smart repeat / shuffle / end-of-track playback logic.
///
/// The randomness source is injected so shuffle selection is deterministic.
void main() {
  late TestVhunambiAudioHandler handler;
  late PlayerNotifier notifier;

  setUp(() {
    handler = TestVhunambiAudioHandler();
    notifier = PlayerNotifier(
      audioHandler: handler,
      randomInt: (_) => 2,
    );
    addTearDown(notifier.dispose);
    addTearDown(handler.dispose);
  });

  void seedQueue(List<Track> tracks, {int startAt = 0}) {
    notifier.playTrack(tracks[startAt], queue: tracks);
  }

  test('repeat-one rewinds the active track and keeps playing', () {
    seedQueue(<Track>[_track('trk_1'), _track('trk_2')]);
    notifier.cycleRepeatMode(); // off -> all
    notifier.cycleRepeatMode(); // all -> one
    expect(notifier.state.repeatMode, AudioRepeatMode.one);

    notifier.seek(const Duration(seconds: 199));
    notifier.handleTrackEnd();

    expect(notifier.state.position, Duration.zero);
    expect(notifier.state.isPlaying, isTrue);
    expect(notifier.state.currentTrack?.id, 'trk_1');
  });

  test('repeat-off stops at the end of the queue without wrapping', () {
    seedQueue(<Track>[_track('trk_1'), _track('trk_2')], startAt: 1);
    expect(notifier.state.repeatMode, AudioRepeatMode.off);
    expect(notifier.state.currentIndex, 1);

    notifier.seek(const Duration(seconds: 199));
    notifier.handleTrackEnd();

    expect(notifier.state.playbackStatus, PlaybackStatus.paused);
    expect(notifier.state.position, Duration.zero);
    // Stays on the final track — does not loop back to trk_1.
    expect(notifier.state.currentTrack?.id, 'trk_2');
  });

  test('repeat-off advances when the queue still has tracks left', () {
    seedQueue(<Track>[_track('trk_1'), _track('trk_2'), _track('trk_3')]);
    expect(notifier.state.currentIndex, 0);

    notifier.seek(const Duration(seconds: 199));
    notifier.handleTrackEnd();

    expect(notifier.state.currentTrack?.id, 'trk_2');
    expect(notifier.state.currentIndex, 1);
    expect(notifier.state.isPlaying, isTrue);
  });

  test('repeat-all wraps from the last track back to the first', () {
    seedQueue(<Track>[_track('trk_1'), _track('trk_2')], startAt: 1);
    notifier.cycleRepeatMode(); // off -> all

    notifier.seek(const Duration(seconds: 199));
    notifier.handleTrackEnd();

    expect(notifier.state.currentTrack?.id, 'trk_1');
    expect(notifier.state.currentIndex, 0);
  });

  test('shuffle selects a non-sequential track', () {
    // Queue of 5; injected randomInt always returns index 2, so a shuffle
    // skip from index 0 must land on index 2 (sequential would be 1).
    seedQueue(<Track>[
      _track('trk_1'),
      _track('trk_2'),
      _track('trk_3'),
      _track('trk_4'),
      _track('trk_5'),
    ]);
    notifier.toggleShuffle();
    expect(notifier.state.isShuffle, isTrue);

    notifier.skipNext();

    expect(notifier.state.currentIndex, 2);
    expect(notifier.state.currentTrack?.id, 'trk_3');
  });

  test('shuffle retries when the first draw matches the current track', () {
    // First draw returns the active index (0); the guard must redraw and land
    // on a different index (1).
    var calls = 0;
    final redrawOnce = PlayerNotifier(
      audioHandler: handler,
      randomInt: (_) => calls++ == 0 ? 0 : 1,
    );
    addTearDown(redrawOnce.dispose);
    redrawOnce.playTrack(_track('trk_1'), queue: <Track>[
      _track('trk_1'),
      _track('trk_2'),
      _track('trk_3'),
    ]);
    redrawOnce.toggleShuffle();

    redrawOnce.skipNext();

    expect(redrawOnce.state.currentIndex, 1);
    expect(redrawOnce.state.currentTrack?.id, 'trk_2');
  });

  test('sequential skipNext is unaffected when shuffle is off', () {
    seedQueue(<Track>[_track('trk_1'), _track('trk_2'), _track('trk_3')]);

    notifier.skipNext();

    expect(notifier.state.currentIndex, 1);
    expect(notifier.state.currentTrack?.id, 'trk_2');
  });
}

Track _track(String id) => Track(
      id: id,
      title: 'Track $id',
      creatorName: 'Sigwa & Inaf',
      genre: 'Amapiano',
      duration: const Duration(minutes: 3, seconds: 20),
    );

import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/player/data/services/vhunambi_audio_handler.dart';
import 'package:vhunambi_client/features/player/domain/models/player_state.dart';
import 'package:vhunambi_client/features/player/presentation/providers/player_provider.dart';
import 'package:vhunambi_client/features/playlists/domain/models/playlist_entity.dart';
import 'package:vhunambi_client/shared/models/track.dart';

/// T12.4 — PlayerNotifier queue management suite.
///
/// Covers appending, play-next insertion, removal, drag-and-drop reordering,
/// clearing the upcoming queue and whole-playlist playback (REQ-PL-05 → 07,
/// REQ-PL-10).
void main() {
  late TestVhunambiAudioHandler handler;
  late PlayerNotifier notifier;

  setUp(() {
    // Injected => the notifier does not own (and therefore will not dispose)
    // the handler, so the test disposes both explicitly.
    handler = TestVhunambiAudioHandler();
    notifier = PlayerNotifier(audioHandler: handler);
    addTearDown(notifier.dispose);
    addTearDown(handler.dispose);
  });

  /// Seeds a live queue so the active row sits inside `state.queue`.
  void seedQueue(List<Track> tracks, {int startAt = 0}) {
    notifier.playTrack(tracks[startAt], queue: tracks);
  }

  test('the seeded player starts with an active track but no queue', () {
    expect(notifier.state.currentTrack?.id, 'track_default_1');
    expect(notifier.state.queue, isEmpty);
    expect(notifier.state.currentIndex, -1);
  });

  test('addToQueue opens the queue with the active track first', () {
    notifier.addToQueue(_track('trk_new'));

    expect(
      notifier.state.queue.map((track) => track.id),
      <String>['track_default_1', 'trk_new'],
    );
    expect(notifier.state.currentIndex, 0);
    expect(notifier.state.currentTrack?.id, 'track_default_1');
  });

  test('addToQueue appends to an existing queue', () {
    seedQueue(<Track>[_track('trk_1'), _track('trk_2')]);

    notifier.addToQueue(_track('trk_3'));

    expect(
      notifier.state.queue.map((track) => track.id),
      <String>['trk_1', 'trk_2', 'trk_3'],
    );
    expect(notifier.state.currentIndex, 0);
  });

  test('addToQueue starts playback when nothing is loaded', () {
    notifier.dismiss();

    notifier.addToQueue(_track('trk_1'));

    expect(notifier.state.currentTrack?.id, 'trk_1');
    expect(notifier.state.queue, hasLength(1));
    expect(notifier.state.currentIndex, 0);
  });

  test('playNext inserts straight after the active index', () {
    seedQueue(<Track>[_track('trk_1'), _track('trk_2'), _track('trk_3')]);

    notifier.playNext(_track('trk_next'));

    expect(
      notifier.state.queue.map((track) => track.id),
      <String>['trk_1', 'trk_next', 'trk_2', 'trk_3'],
    );
    expect(notifier.state.currentTrack?.id, 'trk_1');
    expect(notifier.state.currentIndex, 0);
  });

  test('playNext opens the queue when only the active track exists', () {
    notifier.playNext(_track('trk_next'));

    expect(
      notifier.state.queue.map((track) => track.id),
      <String>['track_default_1', 'trk_next'],
    );
    expect(notifier.state.currentTrack?.id, 'track_default_1');
  });

  test('removeFromQueue drops an earlier row and re-aligns the active index',
      () {
    seedQueue(
      <Track>[_track('trk_1'), _track('trk_2'), _track('trk_3')],
      startAt: 1,
    );

    notifier.removeFromQueue(0);

    expect(
      notifier.state.queue.map((track) => track.id),
      <String>['trk_2', 'trk_3'],
    );
    expect(notifier.state.currentIndex, 0);
    expect(notifier.state.currentTrack?.id, 'trk_2');
  });

  test('removeFromQueue on the active row advances to the next entry', () {
    seedQueue(<Track>[_track('trk_1'), _track('trk_2'), _track('trk_3')]);

    notifier.removeFromQueue(0);

    expect(
      notifier.state.queue.map((track) => track.id),
      <String>['trk_2', 'trk_3'],
    );
    expect(notifier.state.currentIndex, 0);
  });

  test('removeFromQueue clears the index once the queue empties', () {
    seedQueue(<Track>[_track('trk_1')]);

    notifier.removeFromQueue(0);

    expect(notifier.state.queue, isEmpty);
    expect(notifier.state.currentIndex, -1);
  });

  test('removeFromQueue ignores out-of-range indices', () {
    seedQueue(<Track>[_track('trk_1'), _track('trk_2')]);

    notifier.removeFromQueue(9);
    notifier.removeFromQueue(-1);

    expect(notifier.state.queue, hasLength(2));
    expect(notifier.state.currentIndex, 0);
  });

  test('reorderQueue drags a row downwards and follows the active track', () {
    seedQueue(<Track>[_track('trk_1'), _track('trk_2'), _track('trk_3')]);

    // ReorderableListView reports the slot *before* removal: row 0 → end.
    notifier.reorderQueue(0, 3);

    expect(
      notifier.state.queue.map((track) => track.id),
      <String>['trk_2', 'trk_3', 'trk_1'],
    );
    expect(notifier.state.currentIndex, 2);
    expect(notifier.state.currentTrack?.id, 'trk_1');
  });

  test('reorderQueue drags a row upwards without losing the active track', () {
    seedQueue(<Track>[_track('trk_1'), _track('trk_2'), _track('trk_3')]);

    notifier.reorderQueue(2, 0);

    expect(
      notifier.state.queue.map((track) => track.id),
      <String>['trk_3', 'trk_1', 'trk_2'],
    );
    expect(notifier.state.currentIndex, 1);
    expect(notifier.state.queue[notifier.state.currentIndex].id, 'trk_1');
  });

  test('reorderQueue ignores invalid indices', () {
    seedQueue(<Track>[_track('trk_1'), _track('trk_2')]);

    notifier.reorderQueue(5, 0);
    notifier.reorderQueue(-1, 1);

    expect(
      notifier.state.queue.map((track) => track.id),
      <String>['trk_1', 'trk_2'],
    );
  });

  test('clearUpcomingQueue keeps only the active track playing', () {
    seedQueue(
      <Track>[
        _track('trk_1'),
        _track('trk_2'),
        _track('trk_3'),
        _track('trk_4'),
      ],
      startAt: 2,
    );

    notifier.clearUpcomingQueue();

    expect(notifier.state.queue, hasLength(1));
    expect(notifier.state.queue.single.id, 'trk_3');
    expect(notifier.state.currentIndex, 0);
    expect(notifier.state.isPlaying, isTrue);
  });

  test('clearUpcomingQueue empties the queue with no active track', () {
    seedQueue(<Track>[_track('trk_1'), _track('trk_2')]);
    notifier.dismiss();

    notifier.clearUpcomingQueue();

    expect(notifier.state.queue, isEmpty);
    expect(notifier.state.currentIndex, -1);
  });

  test('playPlaylist replaces the queue and starts track 0', () async {
    final tracks = <Track>[_track('trk_1'), _track('trk_2'), _track('trk_3')];

    notifier.playPlaylist(_playlist(<String>['trk_1', 'trk_2', 'trk_3']), tracks);
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.queue, tracks);
    expect(notifier.state.currentIndex, 0);
    expect(notifier.state.currentTrack?.id, 'trk_1');
    expect(notifier.state.playbackStatus, PlaybackStatus.playing);
    expect(handler.currentTrack?.id, 'trk_1');
  });

  test('playPlaylist ignores an empty playlist', () {
    seedQueue(<Track>[_track('trk_1')]);

    notifier.playPlaylist(_playlist(const <String>[]), const <Track>[]);

    expect(notifier.state.queue, hasLength(1));
    expect(notifier.state.currentTrack?.id, 'trk_1');
  });
}

/// Local fixture helpers.
Track _track(String id) => Track(
      id: id,
      title: 'Track $id',
      creatorName: 'Sigwa & Inaf',
      genre: 'Amapiano',
      duration: const Duration(minutes: 3, seconds: 20),
    );

PlaylistEntity _playlist(List<String> trackIds) => PlaylistEntity(
      id: 'pl_1',
      title: 'Late Night Amapiano',
      trackIds: trackIds,
      createdAt: DateTime(2026, 9, 26, 20),
      updatedAt: DateTime(2026, 9, 26, 21),
    );

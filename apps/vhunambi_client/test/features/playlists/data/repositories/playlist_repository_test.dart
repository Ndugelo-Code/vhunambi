import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/playlists/data/repositories/in_memory_playlist_repository.dart';
import 'package:vhunambi_client/features/playlists/domain/models/playlist_entity.dart';

/// T12.2 — In-memory playlist repository suite.
void main() {
  late InMemoryPlaylistRepository repository;

  setUp(() {
    repository = InMemoryPlaylistRepository(seed: <PlaylistEntity>[_playlist()]);
  });

  test('seeded playlists are returned newest-agnostic but complete', () async {
    final playlists = await repository.getAllPlaylists();

    expect(playlists, hasLength(1));
    expect(playlists.single.title, 'Late Night Amapiano');
    expect(playlists.single.trackIds, <String>['trk_1', 'trk_2']);
  });

  test('getAllPlaylists returns an unmodifiable view', () async {
    final playlists = await repository.getAllPlaylists();

    expect(
      () => playlists.add(_playlist(id: 'pl_2')),
      throwsUnsupportedError,
    );
  });

  test('getPlaylistById resolves known ids and nulls unknown ones', () async {
    expect((await repository.getPlaylistById('pl_1'))?.title,
        'Late Night Amapiano');
    expect(await repository.getPlaylistById('missing'), isNull);
  });

  test('savePlaylist inserts new playlists and replaces existing ones',
      () async {
    await repository.savePlaylist(_playlist(id: 'pl_2', title: 'Roadtrip'));
    await repository.savePlaylist(_playlist(title: 'Renamed'));

    final playlists = await repository.getAllPlaylists();

    expect(playlists, hasLength(2));
    expect((await repository.getPlaylistById('pl_1'))?.title, 'Renamed');
    expect((await repository.getPlaylistById('pl_2'))?.isEmpty, isTrue);
  });

  test('deletePlaylist removes the playlist and is idempotent', () async {
    await repository.deletePlaylist('pl_1');
    await repository.deletePlaylist('pl_1');

    expect(await repository.getAllPlaylists(), isEmpty);
    expect(await repository.getPlaylistById('pl_1'), isNull);
  });

  test('addTrackToPlaylist appends once and ignores duplicates', () async {
    await repository.addTrackToPlaylist('pl_1', 'trk_3');
    await repository.addTrackToPlaylist('pl_1', 'trk_3');
    await repository.addTrackToPlaylist('unknown', 'trk_3');

    final playlist = (await repository.getPlaylistById('pl_1'))!;

    expect(playlist.trackIds, <String>['trk_1', 'trk_2', 'trk_3']);
    expect(playlist.updatedAt.isAfter(playlist.createdAt), isTrue);
  });

  test('removeTrackFromPlaylist drops a track and tolerates misses', () async {
    await repository.removeTrackFromPlaylist('pl_1', 'trk_1');
    await repository.removeTrackFromPlaylist('pl_1', 'trk_9');
    await repository.removeTrackFromPlaylist('unknown', 'trk_2');

    expect((await repository.getPlaylistById('pl_1'))?.trackIds, <String>['trk_2']);
  });

  test('an empty repository starts with no playlists', () async {
    final empty = InMemoryPlaylistRepository();

    expect(await empty.getAllPlaylists(), isEmpty);
    expect(
      await empty.getPlaylistById('pl_1'),
      isNull,
    );
  });
}

PlaylistEntity _playlist({String id = 'pl_1', String title = 'Late Night Amapiano'}) =>
    PlaylistEntity(
      id: id,
      title: title,
      description: 'Deep log-drum sessions',
      trackIds: id == 'pl_1' ? const <String>['trk_1', 'trk_2'] : const <String>[],
      createdAt: DateTime(2026, 9, 26, 20),
      updatedAt: DateTime(2026, 9, 26, 21),
    );

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/playlists/data/repositories/in_memory_playlist_repository.dart';
import 'package:vhunambi_client/features/playlists/domain/models/playlist_entity.dart';
import 'package:vhunambi_client/features/playlists/presentation/providers/playlists_provider.dart';

/// T12.3 — Playlist vault notifier suite.
void main() {
  late InMemoryPlaylistRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = InMemoryPlaylistRepository(
      seed: <PlaylistEntity>[_playlist()],
    );
    container = ProviderContainer(
      overrides: <Override>[
        playlistRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
  });

  PlaylistsNotifier notifier() => container.read(playlistsProvider.notifier);

  test('loadPlaylists mirrors the persisted vault', () async {
    await notifier().loadPlaylists();

    final playlists = container.read(playlistsProvider);

    expect(playlists, hasLength(1));
    expect(playlists.single.title, 'Late Night Amapiano');
    expect(playlists.single.trackIds, <String>['trk_1', 'trk_2']);
  });

  test('createPlaylist persists, prepends and trims the title', () async {
    await notifier().loadPlaylists();

    final created = await notifier().createPlaylist(
      '  Roadtrip Bangers  ',
      description: '  Long drive  ',
    );

    expect(created.title, 'Roadtrip Bangers');
    expect(created.description, 'Long drive');
    expect(created.trackIds, isEmpty);
    expect(created.id, startsWith('pl_'));

    final playlists = container.read(playlistsProvider);
    expect(playlists, hasLength(2));
    expect(playlists.first, created);
    expect(await repository.getPlaylistById(created.id), created);
  });

  test('updatePlaylist renames without touching the track list', () async {
    await notifier().loadPlaylists();

    await notifier().updatePlaylist('pl_1', title: 'Renamed', description: 'New');

    final playlist = container.read(playlistsProvider).single;

    expect(playlist.title, 'Renamed');
    expect(playlist.description, 'New');
    expect(playlist.trackIds, <String>['trk_1', 'trk_2']);
    expect((await repository.getPlaylistById('pl_1'))?.title, 'Renamed');
  });

  test('updatePlaylist ignores unknown ids', () async {
    await notifier().loadPlaylists();

    await notifier().updatePlaylist('missing', title: 'Nope');

    expect(container.read(playlistsProvider).single.title, 'Late Night Amapiano');
  });

  test('deletePlaylist removes it from the vault and the repository',
      () async {
    await notifier().loadPlaylists();

    await notifier().deletePlaylist('pl_1');

    expect(container.read(playlistsProvider), isEmpty);
    expect(await repository.getPlaylistById('pl_1'), isNull);
  });

  test('toggleTrackInPlaylist adds then removes the same track', () async {
    await notifier().loadPlaylists();

    await notifier().toggleTrackInPlaylist('pl_1', 'trk_9');
    expect(container.read(playlistsProvider).single.trackIds, hasLength(3));
    expect(notifier().containsTrack('pl_1', 'trk_9'), isTrue);

    await notifier().toggleTrackInPlaylist('pl_1', 'trk_9');
    expect(container.read(playlistsProvider).single.trackIds, hasLength(2));
    expect(notifier().containsTrack('pl_1', 'trk_9'), isFalse);
  });

  test('addTrackToPlaylist ignores duplicates and unknown playlists',
      () async {
    await notifier().loadPlaylists();

    await notifier().addTrackToPlaylist('pl_1', 'trk_1');
    await notifier().addTrackToPlaylist('missing', 'trk_9');

    expect(container.read(playlistsProvider).single.trackIds, hasLength(2));
  });

  test('removeTrackFromPlaylist tolerates absent tracks and unknown ids',
      () async {
    await notifier().loadPlaylists();

    await notifier().removeTrackFromPlaylist('pl_1', 'trk_3');
    await notifier().removeTrackFromPlaylist('missing', 'trk_1');

    expect(container.read(playlistsProvider).single.trackIds, hasLength(2));
  });

  test('a fresh container starts with an empty vault', () {
    final fresh = ProviderContainer(
      overrides: <Override>[
        playlistRepositoryProvider.overrideWithValue(
          InMemoryPlaylistRepository(),
        ),
      ],
    );
    addTearDown(fresh.dispose);

    expect(fresh.read(playlistsProvider), isEmpty);
  });
}

PlaylistEntity _playlist() => PlaylistEntity(
      id: 'pl_1',
      title: 'Late Night Amapiano',
      description: 'Deep log-drum sessions',
      trackIds: const <String>['trk_1', 'trk_2'],
      createdAt: DateTime(2026, 9, 26, 20),
      updatedAt: DateTime(2026, 9, 26, 21),
    );

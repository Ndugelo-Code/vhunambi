import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/features/playlists/data/repositories/playlist_repository.dart';
import 'package:vhunambi_client/features/playlists/domain/models/playlist_entity.dart';

void main() {
  group('PlaylistRepository (Hive-backed)', () {
    late Directory tempDir;
    late Box hiveBox;
    late PlaylistRepository repo;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vhunambi_playlist_hive_');
      Hive.init(tempDir.path);
      hiveBox = await Hive.openBox(AppConstants.playlistsBoxKey);
      repo = PlaylistRepository(box: hiveBox);
    });

    tearDown(() async {
      await hiveBox.close();
      await Hive.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('saves and retrieves playlists sorted by updatedAt descending', () async {
      final now = DateTime.now();
      final p1 = PlaylistEntity(
        id: 'p1',
        title: 'Amapiano Grooves',
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now.subtract(const Duration(hours: 2)),
      );
      final p2 = PlaylistEntity(
        id: 'p2',
        title: 'Deep House Sunset',
        createdAt: now.subtract(const Duration(hours: 1)),
        updatedAt: now.subtract(const Duration(minutes: 30)),
      );

      await repo.savePlaylist(p1);
      await repo.savePlaylist(p2);

      final list = await repo.getAllPlaylists();
      expect(list.length, equals(2));
      expect(list.first.id, equals('p2')); // Most recently updated
      expect(list.last.id, equals('p1'));
    });

    test('getPlaylistById returns matching entity or null', () async {
      final p = PlaylistEntity(
        id: 'find_me',
        title: 'Maskandi Folk',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repo.savePlaylist(p);

      final found = await repo.getPlaylistById('find_me');
      expect(found, isNotNull);
      expect(found!.title, equals('Maskandi Folk'));

      final notFound = await repo.getPlaylistById('unknown_id');
      expect(notFound, isNull);
    });

    test('deletePlaylist removes entity from store', () async {
      final p = PlaylistEntity(
        id: 'delete_me',
        title: 'To Be Deleted',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repo.savePlaylist(p);
      expect(await repo.getPlaylistById('delete_me'), isNotNull);

      await repo.deletePlaylist('delete_me');
      expect(await repo.getPlaylistById('delete_me'), isNull);
    });

    test('addTrackToPlaylist appends track and ignores duplicates', () async {
      final p = PlaylistEntity(
        id: 'track_test',
        title: 'Tracks Playlist',
        trackIds: const ['t1'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repo.savePlaylist(p);

      await repo.addTrackToPlaylist('track_test', 't2');
      var updated = await repo.getPlaylistById('track_test');
      expect(updated!.trackIds, equals(['t1', 't2']));

      // Adding duplicate should be ignored
      await repo.addTrackToPlaylist('track_test', 't2');
      updated = await repo.getPlaylistById('track_test');
      expect(updated!.trackIds, equals(['t1', 't2']));
    });

    test('removeTrackFromPlaylist removes existing track', () async {
      final p = PlaylistEntity(
        id: 'remove_test',
        title: 'Remove Playlist',
        trackIds: const ['t1', 't2', 't3'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repo.savePlaylist(p);

      await repo.removeTrackFromPlaylist('remove_test', 't2');
      final updated = await repo.getPlaylistById('remove_test');
      expect(updated!.trackIds, equals(['t1', 't3']));
    });
  });

  group('PlaylistRepository (In-memory fallback)', () {
    test('works seamlessly when Hive is not open', () async {
      final repo = PlaylistRepository();
      expect(await repo.getAllPlaylists(), isEmpty);

      final p = PlaylistEntity(
        id: 'mem_1',
        title: 'In Memory Playlist',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repo.savePlaylist(p);

      final list = await repo.getAllPlaylists();
      expect(list.length, equals(1));
      expect(list.first.title, equals('In Memory Playlist'));

      await repo.deletePlaylist('mem_1');
      expect(await repo.getAllPlaylists(), isEmpty);
    });
  });
}

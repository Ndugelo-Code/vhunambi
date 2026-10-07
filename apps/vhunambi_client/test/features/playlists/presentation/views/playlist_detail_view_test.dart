import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/player/presentation/providers/player_provider.dart';
import 'package:vhunambi_client/features/playlists/data/repositories/in_memory_playlist_repository.dart';
import 'package:vhunambi_client/features/playlists/domain/models/playlist_entity.dart';
import 'package:vhunambi_client/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:vhunambi_client/features/playlists/presentation/views/playlist_detail_view.dart';

Widget _buildDetailTestWidget({
  required PlaylistEntity playlist,
  required InMemoryPlaylistRepository repository,
}) {
  return ProviderScope(
    overrides: [
      playlistRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp(
      home: PlaylistDetailView(playlist: playlist),
    ),
  );
}

void main() {
  group('PlaylistDetailView', () {
    testWidgets('renders playlist header, title, and description', (tester) async {
      final now = DateTime.now();
      final playlist = PlaylistEntity(
        id: 'pl_test',
        title: 'Soulful Sundays',
        description: 'Vocal deep cuts',
        trackIds: const [],
        createdAt: now,
        updatedAt: now,
      );
      final repo = InMemoryPlaylistRepository(seed: [playlist]);

      await tester.pumpWidget(_buildDetailTestWidget(playlist: playlist, repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('Soulful Sundays'), findsWidgets);
      expect(find.text('Vocal deep cuts'), findsOneWidget);
      expect(find.text('0 songs • 0 mins'), findsOneWidget);
      expect(find.text('Play All'), findsOneWidget);
      expect(find.text('Shuffle'), findsOneWidget);
    });

    testWidgets('renders empty placeholder when playlist has no tracks', (tester) async {
      final playlist = PlaylistEntity(
        id: 'pl_empty',
        title: 'Empty Playlist',
        trackIds: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final repo = InMemoryPlaylistRepository(seed: [playlist]);

      await tester.pumpWidget(_buildDetailTestWidget(playlist: playlist, repository: repo));
      await tester.pumpAndSettle();

      expect(find.textContaining('No songs in this playlist yet'), findsOneWidget);
    });

    testWidgets('resolves and renders tracks from library', (tester) async {
      final now = DateTime.now();
      // 'lib_track_001' is seeded in libraryTracksProvider as "Grateful in the Light"
      final playlist = PlaylistEntity(
        id: 'pl_populated',
        title: 'Amapiano Kings',
        trackIds: const ['lib_track_001'],
        createdAt: now,
        updatedAt: now,
      );
      final repo = InMemoryPlaylistRepository(seed: [playlist]);

      await tester.pumpWidget(_buildDetailTestWidget(
        playlist: playlist,
        repository: repo,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Grateful in the Light'), findsOneWidget);
      expect(find.text('cern • Amapiano'), findsOneWidget);
      expect(find.text('1 song • 3 mins'), findsOneWidget);
    });

    testWidgets('tapping Play All triggers playback engine', (tester) async {
      final now = DateTime.now();
      final playlist = PlaylistEntity(
        id: 'pl_play',
        title: 'Play Me',
        trackIds: const ['lib_track_001'],
        createdAt: now,
        updatedAt: now,
      );
      final repo = InMemoryPlaylistRepository(seed: [playlist]);

      late WidgetRef capturedRef;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playlistRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                return PlaylistDetailView(playlist: playlist);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Play All'));
      await tester.pump();

      final player = capturedRef.read(playerStateProvider);
      expect(player.currentTrack?.id, equals('lib_track_001'));
      expect(player.queue.length, equals(1));
    });

    testWidgets('removing a track calls repository removeTrackFromPlaylist', (tester) async {
      final now = DateTime.now();
      final playlist = PlaylistEntity(
        id: 'pl_remove_action',
        title: 'Remove Action Playlist',
        trackIds: const ['lib_track_001'],
        createdAt: now,
        updatedAt: now,
      );
      final repo = InMemoryPlaylistRepository(seed: [playlist]);

      await tester.pumpWidget(_buildDetailTestWidget(
        playlist: playlist,
        repository: repo,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Grateful in the Light'), findsOneWidget);

      await tester.tap(find.byTooltip('Remove from playlist'));
      await tester.pumpAndSettle();

      final updated = await repo.getPlaylistById('pl_remove_action');
      expect(updated!.trackIds, isEmpty);
    });
  });
}

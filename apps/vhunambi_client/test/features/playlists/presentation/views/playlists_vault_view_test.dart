import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/library/domain/models/library_models.dart';
import 'package:vhunambi_client/features/library/presentation/providers/library_providers.dart';
import 'package:vhunambi_client/features/playlists/data/repositories/in_memory_playlist_repository.dart';
import 'package:vhunambi_client/features/playlists/domain/models/playlist_entity.dart';
import 'package:vhunambi_client/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:vhunambi_client/features/playlists/presentation/views/playlist_detail_view.dart';
import 'package:vhunambi_client/features/playlists/presentation/views/playlists_vault_view.dart';

Widget _buildTestWidget({
  required InMemoryPlaylistRepository repository,
  LibraryViewMode viewMode = LibraryViewMode.grid,
}) {
  return ProviderScope(
    overrides: [
      playlistRepositoryProvider.overrideWithValue(repository),
      libraryViewModeProvider.overrideWith((ref) => viewMode),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: PlaylistsVaultView(),
      ),
    ),
  );
}

void main() {
  group('PlaylistsVaultView', () {
    testWidgets('renders empty state when there are no playlists', (tester) async {
      final repo = InMemoryPlaylistRepository();
      await tester.pumpWidget(_buildTestWidget(repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('No playlists yet'), findsOneWidget);
      expect(find.text('Create your first playlist'), findsOneWidget);
    });

    testWidgets('tapping empty state CTA opens creation dialog', (tester) async {
      final repo = InMemoryPlaylistRepository();
      await tester.pumpWidget(_buildTestWidget(repository: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create your first playlist'));
      await tester.pumpAndSettle();

      expect(find.text('Create New Playlist'), findsOneWidget);
      expect(find.text('Playlist Title'), findsOneWidget);
    });

    testWidgets('renders grid cards when playlists exist in grid view mode', (tester) async {
      final now = DateTime.now();
      final repo = InMemoryPlaylistRepository(seed: [
        PlaylistEntity(
          id: 'pl_1',
          title: 'Amapiano Sunday',
          description: 'Log drum vibes',
          trackIds: const ['t1', 't2'],
          createdAt: now,
          updatedAt: now,
        ),
      ]);

      await tester.pumpWidget(_buildTestWidget(repository: repo, viewMode: LibraryViewMode.grid));
      await tester.pumpAndSettle();

      expect(find.text('Amapiano Sunday'), findsOneWidget);
      expect(find.text('2 songs'), findsOneWidget);
      expect(find.text('New Playlist'), findsOneWidget);
    });

    testWidgets('renders list rows when playlists exist in list view mode', (tester) async {
      final now = DateTime.now();
      final repo = InMemoryPlaylistRepository(seed: [
        PlaylistEntity(
          id: 'pl_1',
          title: 'Kwaito Classics',
          description: '90s nostalgia',
          trackIds: const ['t1'],
          createdAt: now,
          updatedAt: now,
        ),
      ]);

      await tester.pumpWidget(_buildTestWidget(repository: repo, viewMode: LibraryViewMode.list));
      await tester.pumpAndSettle();

      expect(find.text('Kwaito Classics'), findsOneWidget);
      expect(find.text('1 song • 90s nostalgia'), findsOneWidget);
    });

    testWidgets('search query filters playlist items', (tester) async {
      final now = DateTime.now();
      final repo = InMemoryPlaylistRepository(seed: [
        PlaylistEntity(
          id: 'pl_1',
          title: 'Amapiano Grooves',
          createdAt: now,
          updatedAt: now,
        ),
        PlaylistEntity(
          id: 'pl_2',
          title: 'Maskandi Heritage',
          createdAt: now,
          updatedAt: now,
        ),
      ]);

      await tester.pumpWidget(_buildTestWidget(repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('Amapiano Grooves'), findsOneWidget);
      expect(find.text('Maskandi Heritage'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Grooves');
      await tester.pumpAndSettle();

      expect(find.text('Amapiano Grooves'), findsOneWidget);
      expect(find.text('Maskandi Heritage'), findsNothing);
    });

    testWidgets('tapping a playlist card navigates to PlaylistDetailView', (tester) async {
      final now = DateTime.now();
      final repo = InMemoryPlaylistRepository(seed: [
        PlaylistEntity(
          id: 'pl_1',
          title: 'Deep House Sunset',
          createdAt: now,
          updatedAt: now,
        ),
      ]);

      await tester.pumpWidget(_buildTestWidget(repository: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Deep House Sunset'));
      await tester.pumpAndSettle();

      expect(find.byType(PlaylistDetailView), findsOneWidget);
      expect(find.text('Deep House Sunset'), findsWidgets);
    });
  });
}

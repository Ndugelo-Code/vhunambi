import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/playlists/data/repositories/in_memory_playlist_repository.dart';
import 'package:vhunambi_client/features/playlists/domain/models/playlist_entity.dart';
import 'package:vhunambi_client/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:vhunambi_client/features/playlists/presentation/widgets/add_to_playlist_sheet.dart';
import 'package:vhunambi_client/shared/models/track.dart';

/// T12.7 — Add to Playlist sheet widget suite.
void main() {
  testWidgets('renders the track title and the vault checkbox state',
      (tester) async {
    await _openSheet(tester, seed: _vault());

    expect(find.text('Add to Playlist'), findsOneWidget);
    expect(find.text('Track trk_1'), findsOneWidget);
    expect(find.text('Late Night Amapiano'), findsOneWidget);
    expect(find.text('Roadtrip Bangers'), findsOneWidget);

    expect(
      tester.widget<Checkbox>(find.byKey(const Key('playlist_check_pl_1'))).value,
      isTrue,
    );
    expect(
      tester.widget<Checkbox>(find.byKey(const Key('playlist_check_pl_2'))).value,
      isFalse,
    );
  });

  testWidgets('tapping a row files the track into that playlist',
      (tester) async {
    final container = await _openSheet(tester, seed: _vault());

    await tester.tap(find.byKey(const Key('playlist_tile_pl_2')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final playlist = container
        .read(playlistsProvider)
        .firstWhere((item) => item.id == 'pl_2');

    expect(playlist.trackIds, contains('trk_1'));
    expect(
      tester.widget<Checkbox>(find.byKey(const Key('playlist_check_pl_2'))).value,
      isTrue,
    );
  });

  testWidgets('tapping a checked row removes the track again', (tester) async {
    final container = await _openSheet(tester, seed: _vault());

    await tester.tap(find.byKey(const Key('playlist_tile_pl_1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final playlist = container
        .read(playlistsProvider)
        .firstWhere((item) => item.id == 'pl_1');

    expect(playlist.trackIds, isNot(contains('trk_1')));
    expect(
      tester.widget<Checkbox>(find.byKey(const Key('playlist_check_pl_1'))).value,
      isFalse,
    );
  });

  testWidgets('the search field filters the playlist vault', (tester) async {
    await _openSheet(tester, seed: _vault());

    await tester.enterText(find.byKey(const Key('playlist_search')), 'road');
    await tester.pump();

    expect(find.text('Roadtrip Bangers'), findsOneWidget);
    expect(find.text('Late Night Amapiano'), findsNothing);
  });

  testWidgets('the inline creator adds a playlist and files the track',
      (tester) async {
    final container = await _openSheet(tester, seed: _vault());

    await tester.tap(find.byKey(const Key('new_playlist_toggle')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('new_playlist_title')),
      'Gqom Heat',
    );
    await tester.tap(find.byKey(const Key('new_playlist_submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final created = container
        .read(playlistsProvider)
        .firstWhere((playlist) => playlist.title == 'Gqom Heat');

    expect(created.trackIds, <String>['trk_1']);
    expect(find.text('Gqom Heat'), findsOneWidget);
  });

  testWidgets('an empty vault invites the first playlist', (tester) async {
    await _openSheet(tester);

    expect(find.text('No playlists yet'), findsOneWidget);
    expect(find.text('Create your first playlist above.'), findsOneWidget);
  });

  testWidgets('Done dismisses the sheet', (tester) async {
    await _openSheet(tester, seed: _vault());

    await tester.tap(find.byKey(const Key('playlist_sheet_done')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Add to Playlist'), findsNothing);
  });
}

List<PlaylistEntity> _vault() => <PlaylistEntity>[
      PlaylistEntity(
        id: 'pl_1',
        title: 'Late Night Amapiano',
        trackIds: const <String>['trk_1', 'trk_2'],
        createdAt: DateTime(2026, 9, 26, 20),
        updatedAt: DateTime(2026, 9, 26, 21),
      ),
      PlaylistEntity(
        id: 'pl_2',
        title: 'Roadtrip Bangers',
        createdAt: DateTime(2026, 9, 26, 20),
        updatedAt: DateTime(2026, 9, 26, 21),
      ),
    ];

/// Opens the sheet from a host button with a deterministic vault.
Future<ProviderContainer> _openSheet(
  WidgetTester tester, {
  List<PlaylistEntity> seed = const <PlaylistEntity>[],
  Size size = const Size(1280, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  final container = ProviderContainer(
    overrides: <Override>[
      playlistRepositoryProvider.overrideWithValue(
        InMemoryPlaylistRepository(seed: seed),
      ),
    ],
  );
  addTearDown(container.dispose);

  await container.read(playlistsProvider.notifier).loadPlaylists();

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => AddToPlaylistSheet.show(
                  context,
                  const Track(
                    id: 'trk_1',
                    title: 'Track trk_1',
                    creatorName: 'Sigwa & Inaf',
                    genre: 'Amapiano',
                    duration: Duration(minutes: 3, seconds: 20),
                  ),
                ),
                child: const Text('add to playlist'),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('add to playlist'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  return container;
}

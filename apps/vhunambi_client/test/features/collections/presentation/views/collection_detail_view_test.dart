import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/collections/data/repositories/in_memory_collection_repository.dart';
import 'package:vhunambi_client/features/collections/domain/models/collection_entity.dart';
import 'package:vhunambi_client/features/collections/presentation/providers/collections_provider.dart';
import 'package:vhunambi_client/features/collections/presentation/views/collection_detail_view.dart';
import 'package:vhunambi_client/features/library/domain/models/library_models.dart';
import 'package:vhunambi_client/features/player/presentation/providers/player_provider.dart';

/// T13 — CollectionDetailView widget suite (REQ-COL-32).
void main() {
  group('resolveCollectionTracks', () {
    test('resolves vault ids in collection order', () {
      final tracks = resolveCollectionTracks(
        const ['lib_track_002', 'lib_track_001'],
        _vault(),
      );

      expect(tracks, hasLength(2));
      expect(tracks.first.id, equals('lib_track_002'));
      expect(tracks.first.title, equals('Ndo Mufuna Matibe'));
      expect(tracks.last.id, equals('lib_track_001'));
    });

    test('substitutes a placeholder for missing vault ids', () {
      final tracks = resolveCollectionTracks(const ['ghost_track'], _vault());

      expect(tracks.single.id, equals('ghost_track'));
      expect(tracks.single.title, equals('Track ghost_track'));
      expect(tracks.single.creatorName, equals('Vhunambi Artist'));
    });
  });

  group('CollectionDetailView', () {
    testWidgets('renders the hero header, badge and action deck',
        (tester) async {
      await _pumpDetail(tester, collection: _collection(trackIds: const ['lib_track_001']));

      expect(find.text('Ẓe Amapiano EP'), findsWidgets);
      expect(find.text('EP'), findsOneWidget);
      expect(find.text('Amapiano'), findsOneWidget);
      expect(find.text('1 song • 3 mins'), findsOneWidget);
      expect(find.text('Play All'), findsOneWidget);
      expect(find.text('Shuffle'), findsOneWidget);
      expect(find.text('📄 Split Sheet'), findsOneWidget);
    });

    testWidgets('renders the empty track placeholder', (tester) async {
      await _pumpDetail(tester, collection: _collection(trackIds: const []));

      expect(find.textContaining('No songs added yet.'), findsOneWidget);
      expect(find.text('+ Add Track from Library'), findsOneWidget);
      expect(
        find.text('No collaborators added yet.'),
        findsOneWidget,
      );
    });

    testWidgets('resolves vault tracks and renders their metadata',
        (tester) async {
      await _pumpDetail(
        tester,
        collection: _collection(trackIds: const ['lib_track_001', 'lib_track_002']),
      );

      expect(find.text('Grateful in the Light'), findsOneWidget);
      expect(find.text('cern • Amapiano'), findsOneWidget);
      expect(find.text('Ndo Mufuna Matibe'), findsOneWidget);
      expect(find.text('Fifi • Amapiano'), findsOneWidget);
      expect(find.text('2 songs • 6 mins'), findsOneWidget);
    });

    testWidgets('removing a track calls removeTrack on the repository',
        (tester) async {
      final container = await _pumpDetail(
        tester,
        collection: _collection(trackIds: const ['lib_track_001']),
      );

      await tester.tap(find.byKey(const Key('collection_remove_lib_track_001')));
      await tester.pumpAndSettle();

      final repository = container.read(collectionRepositoryProvider)
          as InMemoryCollectionRepository;
      final updated = await repository.getCollectionById('col_1');
      expect(updated!.trackIds, isEmpty);
    });

    testWidgets('Play All queues the collection tracks', (tester) async {
      final collection = _collection(
        trackIds: const ['lib_track_001', 'lib_track_002'],
      );
      late WidgetRef capturedRef;

      tester.view.physicalSize = const Size(1440, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            collectionRepositoryProvider.overrideWithValue(
              InMemoryCollectionRepository(seed: [collection]),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                return CollectionDetailView(collection: collection);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('collection_play_all')));
      await tester.pump();

      final player = capturedRef.read(playerStateProvider);
      expect(player.currentTrack?.id, equals('lib_track_001'));
      expect(player.queue, hasLength(2));
    });

    testWidgets('renders participant rows and the balanced total indicator',
        (tester) async {
      await _pumpDetail(
        tester,
        collection: _collection(
          trackIds: const ['lib_track_001'],
          participants: [
            _participant('Ndugelo Makwela', 'Producer', 50),
            _participant('MusiQ AI', 'Composer', 50),
          ],
        ),
      );

      expect(find.text('Split Sheet Participants'), findsOneWidget);
      expect(find.text('Ndugelo Makwela'), findsOneWidget);
      expect(find.text('Producer'), findsOneWidget);
      expect(find.text('MusiQ AI'), findsOneWidget);
      expect(find.text('Composer'), findsOneWidget);
      expect(find.text('50%'), findsNWidgets(2));

      final total = tester.widget<Text>(
        find.byKey(const Key('collection_total_share')),
      );
      expect(total.data, equals('Total: 100%'));
      expect(total.style?.color, equals(AppColors.success));
    });

    testWidgets('flags an unbalanced split sheet in the error colour',
        (tester) async {
      await _pumpDetail(
        tester,
        collection: _collection(
          trackIds: const ['lib_track_001'],
          participants: [_participant('Ndugelo Makwela', 'Producer', 45)],
        ),
      );

      final total = tester.widget<Text>(
        find.byKey(const Key('collection_total_share')),
      );
      expect(total.data, equals('Total: 45%'));
      expect(total.style?.color, equals(AppColors.error));
    });

    testWidgets('saving a collaborator persists it through the notifier',
        (tester) async {
      final container = await _pumpDetail(
        tester,
        collection: _collection(trackIds: const ['lib_track_001']),
      );

      await tester.tap(find.byKey(const Key('collection_add_participant')));
      await tester.pumpAndSettle();

      expect(find.text('Add Collaborator'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('participant_name_field')),
        'Ndugelo Makwela',
      );
      await tester.enterText(
        find.byKey(const Key('participant_role_field')),
        'Producer',
      );
      await tester.enterText(
        find.byKey(const Key('participant_share_field')),
        '100',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('participant_save')));
      await tester.pumpAndSettle();

      expect(find.text('Ndugelo Makwela'), findsOneWidget);

      final repository = container.read(collectionRepositoryProvider)
          as InMemoryCollectionRepository;
      final stored = await repository.getCollectionById('col_1');
      expect(stored!.participants, hasLength(1));
      expect(stored.isSplitBalanced, isTrue);
    });

    testWidgets('editing a collaborator updates the stored share',
        (tester) async {
      final container = await _pumpDetail(
        tester,
        collection: _collection(
          trackIds: const ['lib_track_001'],
          participants: [_participant('Ndugelo Makwela', 'Producer', 40)],
        ),
      );

      await tester.tap(
        find.byKey(const Key('participant_edit_Ndugelo Makwela')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit Collaborator'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('participant_share_field')),
        '100',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('participant_save')));
      await tester.pumpAndSettle();

      final repository = container.read(collectionRepositoryProvider)
          as InMemoryCollectionRepository;
      final stored = await repository.getCollectionById('col_1');
      expect(stored!.participants.single.sharePercent, equals(100));
    });

    testWidgets('tapping Split Sheet opens the summary modal', (tester) async {
      await _pumpDetail(
        tester,
        collection: _collection(
          trackIds: const ['lib_track_001'],
          participants: [_participant('Ndugelo Makwela', 'Producer', 50)],
        ),
      );

      await tester.tap(find.byKey(const Key('collection_split_sheet')));
      await tester.pumpAndSettle();

      expect(find.text('📄 Split Sheet — Ẓe Amapiano EP'), findsOneWidget);
      expect(find.text('PARTICIPANTS'), findsOneWidget);
      expect(find.text('⚠ Shares must sum to 100%'), findsOneWidget);
      expect(find.text('Copy to Clipboard'), findsOneWidget);

      await tester.tap(find.byKey(const Key('split_sheet_close')));
      await tester.pumpAndSettle();

      expect(find.text('📄 Split Sheet — Ẓe Amapiano EP'), findsNothing);
    });
  });
}

/// Pumps [CollectionDetailView] on a deterministic desktop viewport.
Future<ProviderContainer> _pumpDetail(
  WidgetTester tester, {
  required CollectionEntity collection,
}) async {
  tester.view.physicalSize = const Size(1440, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  final container = ProviderContainer(
    overrides: <Override>[
      collectionRepositoryProvider.overrideWithValue(
        InMemoryCollectionRepository(seed: [collection]),
      ),
    ],
  );
  addTearDown(container.dispose);

  await container.read(collectionsProvider.notifier).loadCollections();

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: CollectionDetailView(collection: collection),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return container;
}

List<LibraryTrack> _vault() => [
      LibraryTrack(
        id: 'lib_track_001',
        title: 'Grateful in the Light',
        creatorName: 'cern',
        genre: 'Amapiano',
        language: 'English',
        durationSeconds: 216,
        remoteAudioUrl: 'https://vhunambi.com/audio/grateful-in-the-light.mp3',
        createdAt: DateTime(2026, 9, 27),
      ),
      LibraryTrack(
        id: 'lib_track_002',
        title: 'Ndo Mufuna Matibe',
        creatorName: 'Fifi',
        genre: 'Amapiano',
        language: 'Tshivenḓa',
        durationSeconds: 198,
        remoteAudioUrl: 'https://vhunambi.com/audio/ndo-mufuna-matibe.mp3',
        createdAt: DateTime(2026, 9, 27),
      ),
    ];

CollectionEntity _collection({
  List<String> trackIds = const ['lib_track_001'],
  List<SplitParticipant> participants = const [],
}) =>
    CollectionEntity(
      id: 'col_1',
      title: 'Ẓe Amapiano EP',
      genre: 'Amapiano',
      trackIds: trackIds,
      participants: participants,
      releaseDate: DateTime(2026, 10, 1),
      createdAt: DateTime(2026, 9, 27),
      updatedAt: DateTime(2026, 9, 27),
    );

SplitParticipant _participant(String name, String role, double share) =>
    SplitParticipant(name: name, role: role, sharePercent: share);

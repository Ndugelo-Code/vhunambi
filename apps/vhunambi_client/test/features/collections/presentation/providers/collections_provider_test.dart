import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/collections/data/repositories/in_memory_collection_repository.dart';
import 'package:vhunambi_client/features/collections/domain/models/collection_entity.dart';
import 'package:vhunambi_client/features/collections/presentation/providers/collections_provider.dart';

/// T13 — Collections provider suite (REQ-COL-30).
void main() {
  late InMemoryCollectionRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = InMemoryCollectionRepository(seed: [_collection()]);
    container = ProviderContainer(
      overrides: <Override>[
        collectionRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
  });

  CollectionsNotifier notifier() => container.read(collectionsProvider.notifier);

  test('a fresh container starts with an empty vault', () {
    final fresh = ProviderContainer(
      overrides: <Override>[
        collectionRepositoryProvider
            .overrideWithValue(InMemoryCollectionRepository()),
      ],
    );
    addTearDown(fresh.dispose);

    expect(fresh.read(collectionsProvider), isEmpty);
  });

  test('loadCollections mirrors the persisted vault newest-first', () async {
    await notifier().loadCollections();

    final collections = container.read(collectionsProvider);
    expect(collections, hasLength(1));
    expect(collections.single.title, equals('Ẓe Amapiano EP'));
    expect(collections.single.trackIds, equals(const ['t1']));
  });

  test('createCollection persists, prepends and trims its input', () async {
    await notifier().loadCollections();

    final created = await notifier().createCollection(
      '  Sunset Log Drum EP  ',
      CollectionType.ep,
      genre: '  Amapiano  ',
      description: '  Deep night sessions  ',
    );

    expect(created.id, startsWith('col_'));
    expect(created.title, equals('Sunset Log Drum EP'));
    expect(created.genre, equals('Amapiano'));
    expect(created.description, equals('Deep night sessions'));
    expect(created.trackIds, isEmpty);

    final collections = container.read(collectionsProvider);
    expect(collections, hasLength(2));
    expect(collections.first, equals(created));
    expect(await repository.getCollectionById(created.id), equals(created));
  });

  test('createCollection forwards the optional release date', () async {
    final release = DateTime(2026, 12, 1);

    final created = await notifier().createCollection(
      'Festive Album',
      CollectionType.album,
      releaseDate: release,
    );

    expect(created.releaseDate, equals(release));
    expect(created.type, equals(CollectionType.album));
  });

  test('updateCollection renames without touching the track list', () async {
    await notifier().loadCollections();

    await notifier().updateCollection(
      'col_1',
      title: 'Renamed EP',
      type: CollectionType.album,
      genre: 'Gqom',
    );

    final collection = container.read(collectionsProvider).single;
    expect(collection.title, equals('Renamed EP'));
    expect(collection.type, equals(CollectionType.album));
    expect(collection.genre, equals('Gqom'));
    expect(collection.trackIds, equals(const ['t1']));
    expect(
      (await repository.getCollectionById('col_1'))?.title,
      equals('Renamed EP'),
    );
  });

  test('updateCollection ignores unknown ids', () async {
    await notifier().loadCollections();

    await notifier().updateCollection('missing', title: 'Nope');

    expect(container.read(collectionsProvider).single.title,
        equals('Ẓe Amapiano EP'));
  });

  test('deleteCollection removes it from the vault and the repository',
      () async {
    await notifier().loadCollections();

    await notifier().deleteCollection('col_1');

    expect(container.read(collectionsProvider), isEmpty);
    expect(await repository.getCollectionById('col_1'), isNull);
  });

  test('addTrack ignores duplicates and unknown collections', () async {
    await notifier().loadCollections();

    await notifier().addTrack('col_1', 't1');
    await notifier().addTrack('col_1', 't2');
    await notifier().addTrack('missing', 't3');

    final collection = container.read(collectionsProvider).single;
    expect(collection.trackIds, equals(const ['t1', 't2']));
    expect(notifier().containsTrack('col_1', 't2'), isTrue);
    expect(notifier().containsTrack('missing', 't1'), isFalse);
  });

  test('removeTrack tolerates absent tracks and unknown ids', () async {
    await notifier().loadCollections();

    await notifier().removeTrack('col_1', 't9');
    await notifier().removeTrack('missing', 't1');
    expect(container.read(collectionsProvider).single.trackIds, hasLength(1));

    await notifier().removeTrack('col_1', 't1');
    expect(container.read(collectionsProvider).single.trackIds, isEmpty);
  });

  test('reorderTracks mirrors the new order into the vault', () async {
    repository = InMemoryCollectionRepository(
      seed: [_collection(trackIds: const ['t1', 't2', 't3'])],
    );
    container = ProviderContainer(
      overrides: <Override>[
        collectionRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    await container.read(collectionsProvider.notifier).loadCollections();

    await container
        .read(collectionsProvider.notifier)
        .reorderTracks('col_1', const ['t3', 't1', 't2']);

    expect(
      container.read(collectionsProvider).single.trackIds,
      equals(const ['t3', 't1', 't2']),
    );
    expect(
      (await repository.getCollectionById('col_1'))?.trackIds,
      equals(const ['t3', 't1', 't2']),
    );
  });

  test('participant mutations reflect in the vault state', () async {
    await notifier().loadCollections();

    await notifier().addParticipant(
      'col_1',
      const SplitParticipant(
        name: 'Ndugelo Makwela',
        role: 'Producer',
        sharePercent: 60,
      ),
    );
    await notifier().addParticipant(
      'col_1',
      const SplitParticipant(name: 'MusiQ AI', role: 'Composer', sharePercent: 40),
    );

    var collection = container.read(collectionsProvider).single;
    expect(collection.participants, hasLength(2));
    expect(collection.isSplitBalanced, isTrue);

    await notifier().updateParticipant(
      'col_1',
      const SplitParticipant(name: 'MusiQ AI', role: 'Composer', sharePercent: 30),
    );

    collection = container.read(collectionsProvider).single;
    expect(collection.participants.last.sharePercent, equals(30));
    expect(collection.isSplitBalanced, isFalse);

    await notifier().removeParticipant('col_1', 'Ndugelo Makwela');
    await notifier().removeParticipant('col_1', 'Unknown');
    await notifier().addParticipant(
      'missing',
      const SplitParticipant(name: 'Ghost', role: 'Producer', sharePercent: 10),
    );

    collection = container.read(collectionsProvider).single;
    expect(collection.participants, hasLength(1));
    expect(collection.participants.single.name, equals('MusiQ AI'));
  });
}

CollectionEntity _collection({
  String id = 'col_1',
  String title = 'Ẓe Amapiano EP',
  List<String> trackIds = const ['t1'],
  List<SplitParticipant> participants = const [],
}) =>
    CollectionEntity(
      id: id,
      title: title,
      genre: 'Amapiano',
      trackIds: trackIds,
      participants: participants,
      createdAt: DateTime(2026, 9, 27),
      updatedAt: DateTime(2026, 9, 27),
    );

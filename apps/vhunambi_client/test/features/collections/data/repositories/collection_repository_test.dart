import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/features/collections/data/repositories/collection_repository.dart';
import 'package:vhunambi_client/features/collections/data/repositories/in_memory_collection_repository.dart';
import 'package:vhunambi_client/features/collections/domain/models/collection_entity.dart';

/// T13 — Collections repository suite (REQ-COL-29).
void main() {
  group('InMemoryCollectionRepository', () {
    test('starts empty and seeds supplied collections', () async {
      final empty = InMemoryCollectionRepository();
      expect(await empty.getAllCollections(), isEmpty);

      final seeded = InMemoryCollectionRepository(seed: [_collection()]);
      expect(await seeded.getAllCollections(), hasLength(1));
    });

    test('saveCollection upserts by id', () async {
      final repository = InMemoryCollectionRepository();

      await repository.saveCollection(_collection(title: 'First'));
      await repository.saveCollection(_collection(title: 'Replaced'));

      final collections = await repository.getAllCollections();
      expect(collections, hasLength(1));
      expect(collections.single.title, equals('Replaced'));
    });

    test('getAllCollections returns the newest update first', () async {
      final repository = InMemoryCollectionRepository();
      final now = DateTime(2026, 9, 27, 12);

      await repository.saveCollection(
        _collection(
          id: 'older',
          updatedAt: now.subtract(const Duration(hours: 3)),
        ),
      );
      await repository.saveCollection(_collection(id: 'newer', updatedAt: now));
      await repository.saveCollection(
        _collection(
          id: 'middle',
          updatedAt: now.subtract(const Duration(hours: 1)),
        ),
      );

      final collections = await repository.getAllCollections();
      expect(
        collections.map((c) => c.id).toList(),
        equals(['newer', 'middle', 'older']),
      );
    });

    test('getCollectionById resolves a match or null', () async {
      final repository = InMemoryCollectionRepository(seed: [_collection()]);

      expect(
        (await repository.getCollectionById('col_1'))?.title,
        equals('Ẓe Amapiano EP'),
      );
      expect(await repository.getCollectionById('missing'), isNull);
    });

    test('deleteCollection removes the entity and is idempotent', () async {
      final repository = InMemoryCollectionRepository(seed: [_collection()]);

      await repository.deleteCollection('col_1');
      await repository.deleteCollection('col_1');

      expect(await repository.getAllCollections(), isEmpty);
    });

    test('addTrackToCollection appends once and ignores duplicates', () async {
      final repository = InMemoryCollectionRepository(
        seed: [_collection(trackIds: const ['t1'])],
      );

      await repository.addTrackToCollection('col_1', 't2');
      await repository.addTrackToCollection('col_1', 't2');
      await repository.addTrackToCollection('missing', 't3');

      final collection = await repository.getCollectionById('col_1');
      expect(collection!.trackIds, equals(const ['t1', 't2']));
    });

    test('removeTrackFromCollection removes and tolerates misses', () async {
      final repository = InMemoryCollectionRepository(
        seed: [
          _collection(trackIds: const ['t1', 't2', 't3']),
        ],
      );

      await repository.removeTrackFromCollection('col_1', 't2');
      await repository.removeTrackFromCollection('col_1', 't9');
      await repository.removeTrackFromCollection('missing', 't1');

      final collection = await repository.getCollectionById('col_1');
      expect(collection!.trackIds, equals(const ['t1', 't3']));
    });

    test('reorderTracks replaces the stored order', () async {
      final repository = InMemoryCollectionRepository(
        seed: [
          _collection(trackIds: const ['t1', 't2', 't3']),
        ],
      );

      await repository.reorderTracks('col_1', const ['t3', 't1', 't2']);

      final collection = await repository.getCollectionById('col_1');
      expect(collection!.trackIds, equals(const ['t3', 't1', 't2']));
    });

    test('addParticipant appends a collaborator', () async {
      final repository = InMemoryCollectionRepository(seed: [_collection()]);

      await repository.addParticipant('col_1', _participant('Producer', 60));
      await repository.addParticipant('col_1', _participant('Composer', 40));

      final collection = await repository.getCollectionById('col_1');
      expect(collection!.participants, hasLength(2));
      expect(collection.isSplitBalanced, isTrue);
    });

    test('removeParticipant matches by name and tolerates misses', () async {
      final repository = InMemoryCollectionRepository(
        seed: [
          _collection(
            participants: [
              _participant('Producer', 50),
              _participant('Composer', 50),
            ],
          ),
        ],
      );

      await repository.removeParticipant('col_1', 'Ndugelo Producer');
      await repository.removeParticipant('col_1', 'Unknown');

      final collection = await repository.getCollectionById('col_1');
      expect(collection!.participants.single.name, equals('Ndugelo Composer'));
    });

    test('updateParticipant replaces the matching collaborator', () async {
      final repository = InMemoryCollectionRepository(
        seed: [
          _collection(
            participants: [
              _participant('Producer', 50),
              _participant('Composer', 50),
            ],
          ),
        ],
      );

      await repository.updateParticipant('col_1', _participant('Producer', 70));

      final collection = await repository.getCollectionById('col_1');
      expect(collection!.participants.first.sharePercent, equals(70));
      expect(collection.participants.last.sharePercent, equals(50));
    });
  });

  group('CollectionRepository (Hive-backed)', () {
    late Directory tempDir;
    late Box hiveBox;
    late CollectionRepository repository;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vhunambi_collections_');
      Hive.init(tempDir.path);
      hiveBox = await Hive.openBox(AppConstants.collectionsBoxKey);
      repository = CollectionRepository(box: hiveBox);
    });

    tearDown(() async {
      await hiveBox.close();
      await Hive.close();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('persists and rehydrates collections newest-first', () async {
      final now = DateTime(2026, 9, 27, 12);

      await repository.saveCollection(
        _collection(
          id: 'ep_1',
          updatedAt: now.subtract(const Duration(hours: 2)),
        ),
      );
      await repository.saveCollection(_collection(id: 'ep_2', updatedAt: now));

      final collections = await repository.getAllCollections();
      expect(collections.map((c) => c.id).toList(), equals(['ep_2', 'ep_1']));
      expect(collections.first.title, equals('Ẓe Amapiano EP'));
      expect(hiveBox.get('ep_2'), isA<Map>());
    });

    test('track and participant mutations round-trip through the box',
        () async {
      await repository.saveCollection(
        _collection(trackIds: const ['t1'], genre: 'Amapiano'),
      );

      await repository.addTrackToCollection('col_1', 't2');
      await repository.addTrackToCollection('col_1', 't2');
      await repository.reorderTracks('col_1', const ['t2', 't1']);
      await repository.addParticipant('col_1', _participant('Producer', 100));

      final collection = await repository.getCollectionById('col_1');
      expect(collection!.trackIds, equals(const ['t2', 't1']));
      expect(collection.participants.single.shareLabel, equals('100%'));
      expect(collection.genre, equals('Amapiano'));

      await repository.removeTrackFromCollection('col_1', 't1');
      await repository.removeParticipant('col_1', 'Ndugelo Producer');
      await repository.deleteCollection('col_1');

      expect(await repository.getCollectionById('col_1'), isNull);
    });
  });

  group('CollectionRepository (in-memory fallback)', () {
    test('works seamlessly when Hive is not initialized', () async {
      final repository = CollectionRepository();
      expect(await repository.getAllCollections(), isEmpty);

      await repository.saveCollection(_collection(trackIds: const ['t1']));
      await repository.addTrackToCollection('col_1', 't2');

      final collections = await repository.getAllCollections();
      expect(collections.single.trackIds, equals(const ['t1', 't2']));

      await repository.deleteCollection('col_1');
      expect(await repository.getAllCollections(), isEmpty);
    });
  });
}

CollectionEntity _collection({
  String id = 'col_1',
  String title = 'Ẓe Amapiano EP',
  String genre = '',
  List<String> trackIds = const ['t1'],
  List<SplitParticipant> participants = const [],
  DateTime? updatedAt,
}) =>
    CollectionEntity(
      id: id,
      title: title,
      genre: genre,
      trackIds: trackIds,
      participants: participants,
      createdAt: DateTime(2026, 9, 27),
      updatedAt: updatedAt ?? DateTime(2026, 9, 27),
    );

SplitParticipant _participant(String role, double share) => SplitParticipant(
      name: 'Ndugelo $role',
      role: role,
      sharePercent: share,
    );

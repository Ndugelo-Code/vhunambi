import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/collections/domain/models/collection_entity.dart';

/// T13 — Collections domain model suite (REQ-COL-28).
void main() {
  group('CollectionType', () {
    test('exposes blueprint labels and recommended ranges', () {
      expect(CollectionType.single.label, equals('Single'));
      expect(CollectionType.ep.label, equals('EP'));
      expect(CollectionType.album.label, equals('Album'));
      expect(CollectionType.conceptProject.label, equals('Concept Project'));

      expect(CollectionType.single.recommendedRange, equals((1, 1)));
      expect(CollectionType.ep.recommendedRange, equals((2, 7)));
      expect(CollectionType.album.recommendedRange, equals((8, 20)));
      expect(CollectionType.conceptProject.recommendedRange, equals((1, 30)));
    });

    test('renders the compact badge caption for concept projects', () {
      expect(CollectionType.conceptProject.badgeLabel, equals('Concept'));
      expect(CollectionType.ep.badgeLabel, equals('EP'));
      expect(CollectionType.album.badgeLabel, equals('Album'));
      expect(CollectionType.single.badgeLabel, equals('Single'));
    });

    test('serialises to snake_case and round-trips every value', () {
      expect(CollectionType.single.toJson(), equals('single'));
      expect(CollectionType.ep.toJson(), equals('ep'));
      expect(CollectionType.album.toJson(), equals('album'));
      expect(CollectionType.conceptProject.toJson(), equals('concept_project'));

      for (final type in CollectionType.values) {
        expect(CollectionType.fromJson(type.toJson()), equals(type));
      }
    });

    test('fromJson maps unknown payloads to single', () {
      expect(CollectionType.fromJson('mixtape'), equals(CollectionType.single));
      expect(CollectionType.fromJson(''), equals(CollectionType.single));
    });
  });

  group('SplitParticipant', () {
    test('toJson uses snake_case keys and round-trips', () {
      const participant = SplitParticipant(
        name: 'Ndugelo Makwela',
        role: 'Producer',
        sharePercent: 62.5,
      );

      expect(participant.toJson(), equals(<String, dynamic>{
        'name': 'Ndugelo Makwela',
        'role': 'Producer',
        'share_percent': 62.5,
      }));
      expect(
        SplitParticipant.fromJson(participant.toJson()),
        equals(participant),
      );
    });

    test('fromJson tolerates partial payloads', () {
      final participant = SplitParticipant.fromJson(<String, dynamic>{
        'name': 'MusiQ AI',
      });

      expect(participant.name, equals('MusiQ AI'));
      expect(participant.role, isEmpty);
      expect(participant.sharePercent, equals(0.0));
    });

    test('shareLabel trims trailing zeros', () {
      expect(_participant(50).shareLabel, equals('50%'));
      expect(_participant(12.5).shareLabel, equals('12.5%'));
      expect(_participant(33.33).shareLabel, equals('33.33%'));
      expect(_participant(0).shareLabel, equals('0%'));
    });

    test('copyWith replaces only the supplied fields', () {
      final participant = _participant(40);
      final updated = participant.copyWith(sharePercent: 60);

      expect(updated.name, equals(participant.name));
      expect(updated.role, equals(participant.role));
      expect(updated.sharePercent, equals(60));
    });

    test('equality is structural', () {
      expect(_participant(50), equals(_participant(50)));
      expect(_participant(50).hashCode, equals(_participant(50).hashCode));
      expect(_participant(50), isNot(equals(_participant(49))));
    });
  });

  group('CollectionEntity', () {
    test('default fields match the blueprint contract', () {
      final collection = CollectionEntity(
        id: 'col_1',
        title: 'Untitled',
        createdAt: DateTime(2026, 9, 27),
        updatedAt: DateTime(2026, 9, 27),
      );

      expect(collection.type, equals(CollectionType.ep));
      expect(collection.genre, isEmpty);
      expect(collection.description, isEmpty);
      expect(collection.releaseDate, isNull);
      expect(collection.coverImageUrl, isNull);
      expect(collection.trackIds, isEmpty);
      expect(collection.participants, isEmpty);
    });

    test('computed properties derive from tracks and the split sheet', () {
      final collection = _collection(
        trackIds: const ['t1', 't2', 't3'],
        participants: [_participant(50), _split('MusiQ AI', 'Composer', 50)],
      );

      expect(collection.trackCount, equals(3));
      expect(collection.trackCountLabel, equals('3 songs'));
      expect(collection.typeLabel, equals('EP'));
      expect(collection.totalSharePercent, equals(100.0));
      expect(collection.isSplitBalanced, isTrue);
      expect(collection.isWithinRecommendedRange, isTrue);
    });

    test('flags a split sheet that does not sum to 100%', () {
      final collection = _collection(participants: [_participant(45)]);

      expect(collection.totalSharePercent, equals(45.0));
      expect(collection.isSplitBalanced, isFalse);
    });

    test('flags track counts outside the recommended range', () {
      expect(
        _collection(trackIds: const ['t1']).isWithinRecommendedRange,
        isFalse,
      );
      expect(
        _collection(
          type: CollectionType.single,
          trackIds: const ['t1'],
        ).isWithinRecommendedRange,
        isTrue,
      );
      expect(
        _collection(
          type: CollectionType.single,
          trackIds: const ['t1', 't2'],
        ).isWithinRecommendedRange,
        isFalse,
      );
    });

    test('copyWith replaces only the supplied fields', () {
      final collection = _collection(trackIds: const ['t1', 't2']);
      final updated = collection.copyWith(
        title: 'Renamed',
        type: CollectionType.album,
      );

      expect(updated.title, equals('Renamed'));
      expect(updated.type, equals(CollectionType.album));
      expect(updated.trackIds, equals(const ['t1', 't2']));
      expect(updated.createdAt, equals(collection.createdAt));
    });

    test('toJson serialises snake_case storage keys', () {
      final collection = _collection(
        releaseDate: DateTime(2026, 10, 1),
        participants: [_participant(100)],
      );

      final json = collection.toJson();

      expect(json['type'], equals('ep'));
      expect(json['release_date'], equals('2026-10-01T00:00:00.000'));
      expect(json['track_ids'], equals(const ['t1']));
      expect(json['participants'], hasLength(1));
      expect(json['created_at'], isA<String>());
      expect(json['updated_at'], isA<String>());
    });

    test('fromJson(toJson()) round-trips every field', () {
      final collection = _collection(
        genre: 'Amapiano',
        description: 'Log drum sessions',
        releaseDate: DateTime(2026, 10, 1),
        participants: [_participant(100)],
      );

      expect(
        CollectionEntity.fromJson(collection.toJson()),
        equals(collection),
      );
    });

    test('fromJson tolerates partial payloads', () {
      final collection = CollectionEntity.fromJson(<String, dynamic>{
        'id': 'col_legacy',
        'title': 'Legacy EP',
        'type': 'concept_project',
        'created_at': '2026-09-27T10:00:00.000',
        'updated_at': '2026-09-27T10:00:00.000',
      });

      expect(collection.id, equals('col_legacy'));
      expect(collection.type, equals(CollectionType.conceptProject));
      expect(collection.trackIds, isEmpty);
      expect(collection.participants, isEmpty);
      expect(collection.releaseDate, isNull);
    });

    test('equality is structural across every stored field', () {
      final collection = _collection(trackIds: const ['t1', 't2']);

      expect(collection, equals(_collection(trackIds: const ['t1', 't2'])));
      expect(
        collection.hashCode,
        equals(_collection(trackIds: const ['t1', 't2']).hashCode),
      );
      expect(
        collection,
        isNot(equals(_collection(trackIds: const ['t2', 't1']))),
      );
      expect(collection, isNot(equals(_collection(title: 'Other'))));
    });
  });
}

SplitParticipant _participant(double share) => SplitParticipant(
      name: 'Ndugelo Makwela',
      role: 'Producer',
      sharePercent: share,
    );

SplitParticipant _split(String name, String role, double share) =>
    SplitParticipant(name: name, role: role, sharePercent: share);

CollectionEntity _collection({
  String id = 'col_1',
  String title = 'Ẓe Amapiano EP',
  CollectionType type = CollectionType.ep,
  String genre = '',
  String description = '',
  DateTime? releaseDate,
  List<String> trackIds = const ['t1'],
  List<SplitParticipant> participants = const [],
}) =>
    CollectionEntity(
      id: id,
      title: title,
      type: type,
      genre: genre,
      description: description,
      releaseDate: releaseDate,
      trackIds: trackIds,
      participants: participants,
      createdAt: DateTime(2026, 9, 27),
      updatedAt: DateTime(2026, 9, 27),
    );

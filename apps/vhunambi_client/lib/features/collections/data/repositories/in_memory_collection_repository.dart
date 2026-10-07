import '../../domain/models/collection_entity.dart';
import '../../domain/repositories/i_collection_repository.dart';

/// In-memory [ICollectionRepository] double (REQ-COL-06).
///
/// Zero disk, zero Hive, zero timers — safe for headless `flutter_test` runs
/// and for provider/widget tests that need a warm collection vault.
class InMemoryCollectionRepository implements ICollectionRepository {
  InMemoryCollectionRepository({List<CollectionEntity> seed = const []}) {
    for (final collection in seed) {
      _store[collection.id] = collection;
    }
  }

  final Map<String, CollectionEntity> _store = <String, CollectionEntity>{};

  @override
  Future<List<CollectionEntity>> getAllCollections() async {
    final collections = _store.values.toList();
    collections.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return collections;
  }

  @override
  Future<CollectionEntity?> getCollectionById(String id) async => _store[id];

  @override
  Future<void> saveCollection(CollectionEntity entity) async {
    _store[entity.id] = entity;
  }

  @override
  Future<void> deleteCollection(String id) async {
    _store.remove(id);
  }

  @override
  Future<void> addTrackToCollection(String collectionId, String trackId) async {
    final collection = _store[collectionId];
    if (collection == null || collection.trackIds.contains(trackId)) return;

    _store[collectionId] = collection.copyWith(
      trackIds: <String>[...collection.trackIds, trackId],
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> removeTrackFromCollection(
    String collectionId,
    String trackId,
  ) async {
    final collection = _store[collectionId];
    if (collection == null || !collection.trackIds.contains(trackId)) return;

    _store[collectionId] = collection.copyWith(
      trackIds: collection.trackIds
          .where((id) => id != trackId)
          .toList(growable: false),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> reorderTracks(
    String collectionId,
    List<String> orderedTrackIds,
  ) async {
    final collection = _store[collectionId];
    if (collection == null) return;

    _store[collectionId] = collection.copyWith(
      trackIds: List<String>.of(orderedTrackIds),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> addParticipant(
    String collectionId,
    SplitParticipant participant,
  ) async {
    final collection = _store[collectionId];
    if (collection == null) return;

    _store[collectionId] = collection.copyWith(
      participants: <SplitParticipant>[
        ...collection.participants,
        participant,
      ],
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> removeParticipant(
    String collectionId,
    String participantName,
  ) async {
    final collection = _store[collectionId];
    if (collection == null) return;
    if (!collection.participants.any((p) => p.name == participantName)) return;

    _store[collectionId] = collection.copyWith(
      participants: collection.participants
          .where((p) => p.name != participantName)
          .toList(growable: false),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> updateParticipant(
    String collectionId,
    SplitParticipant updated,
  ) async {
    final collection = _store[collectionId];
    if (collection == null) return;
    if (!collection.participants.any((p) => p.name == updated.name)) return;

    _store[collectionId] = collection.copyWith(
      participants: <SplitParticipant>[
        for (final participant in collection.participants)
          if (participant.name == updated.name) updated else participant,
      ],
      updatedAt: DateTime.now(),
    );
  }
}

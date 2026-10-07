import '../models/collection_entity.dart';

/// Storage contract for collection bundles (REQ-COL-05).
///
/// Implemented by `InMemoryCollectionRepository` (headless tests, provider
/// isolation) and `CollectionRepository` (Hive `collectionsBoxKey` with an
/// in-memory fallback when Hive is uninitialized).
abstract interface class ICollectionRepository {
  /// Every stored collection, newest `updatedAt` first.
  Future<List<CollectionEntity>> getAllCollections();

  Future<CollectionEntity?> getCollectionById(String id);

  /// Upsert keyed on `CollectionEntity.id`.
  Future<void> saveCollection(CollectionEntity entity);

  /// Idempotent delete — missing ids are ignored.
  Future<void> deleteCollection(String id);

  /// Appends [trackId] to the bundle, ignoring duplicates (REQ-COL-05).
  Future<void> addTrackToCollection(String collectionId, String trackId);

  Future<void> removeTrackFromCollection(String collectionId, String trackId);

  /// Replaces the whole ordered track id list.
  Future<void> reorderTracks(String collectionId, List<String> orderedTrackIds);

  Future<void> addParticipant(
    String collectionId,
    SplitParticipant participant,
  );

  /// Removes the participant matching [participantName].
  Future<void> removeParticipant(String collectionId, String participantName);

  /// Replaces the participant matching [updated] by name.
  Future<void> updateParticipant(
    String collectionId,
    SplitParticipant updated,
  );
}

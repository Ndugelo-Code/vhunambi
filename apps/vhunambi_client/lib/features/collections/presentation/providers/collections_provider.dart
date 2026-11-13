import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vhunambi_client/core/resilience/safe_notifier_mixin.dart';

import '../../data/repositories/collection_repository.dart';
import '../../data/repositories/in_memory_collection_repository.dart';
import '../../domain/models/collection_entity.dart';
import '../../domain/repositories/i_collection_repository.dart';

/// Injectable collection repository (REQ-COL-11).
///
/// Backed by production [CollectionRepository] with automatic headless
/// fallback; override with [InMemoryCollectionRepository] in tests.
final collectionRepositoryProvider = Provider<ICollectionRepository>(
  (ref) => CollectionRepository(),
);

/// The user's collection vault, newest first (REQ-COL-09).
final collectionsProvider =
    StateNotifierProvider<CollectionsNotifier, List<CollectionEntity>>((ref) {
      final notifier = CollectionsNotifier(
        ref.watch(collectionRepositoryProvider),
      );
      notifier.loadCollections();
      return notifier;
    });

/// Full collection CRUD engine backing the vault, detail view and split sheet.
class CollectionsNotifier extends StateNotifier<List<CollectionEntity>>
    with SafeNotifierMixin<List<CollectionEntity>> {
  CollectionsNotifier(this._repository) : super(const <CollectionEntity>[]);

  final ICollectionRepository _repository;

  /// Re-reads the persisted vault.
  Future<void> loadCollections() async {
    final collections = await _repository.getAllCollections();
    if (!mounted) return;
    state = collections;
  }

  /// Creates a collection, prepends it to the vault and returns it.
  Future<CollectionEntity> createCollection(
    String title,
    CollectionType type, {
    String genre = '',
    String description = '',
    DateTime? releaseDate,
  }) async {
    final now = DateTime.now();
    final collection = CollectionEntity(
      id: 'col_${now.microsecondsSinceEpoch}',
      title: title.trim(),
      type: type,
      genre: genre.trim(),
      description: description.trim(),
      releaseDate: releaseDate,
      createdAt: now,
      updatedAt: now,
    );

    await _repository.saveCollection(collection);
    if (mounted) {
      state = <CollectionEntity>[collection, ...state];
    }
    return collection;
  }

  /// Renames / re-types / re-describes an existing collection.
  Future<void> updateCollection(
    String id, {
    String? title,
    CollectionType? type,
    String? genre,
    String? description,
    DateTime? releaseDate,
  }) async {
    final index = state.indexWhere((collection) => collection.id == id);
    if (index < 0) return;

    final updated = state[index].copyWith(
      title: title?.trim(),
      type: type,
      genre: genre?.trim(),
      description: description?.trim(),
      releaseDate: releaseDate,
      updatedAt: DateTime.now(),
    );

    await _repository.saveCollection(updated);
    if (!mounted) return;

    final next = List<CollectionEntity>.of(state);
    next[index] = updated;
    state = next;
  }

  /// Deletes a collection from storage and the vault. Vault tracks remain.
  Future<void> deleteCollection(String id) async {
    await _repository.deleteCollection(id);
    if (!mounted) return;
    state = state
        .where((collection) => collection.id != id)
        .toList(growable: false);
  }

  /// Appends [trackId] to a collection, ignoring duplicates / unknown ids.
  Future<void> addTrack(String collectionId, String trackId) async {
    if (_find(collectionId) == null) return;
    if (containsTrack(collectionId, trackId)) return;

    await _repository.addTrackToCollection(collectionId, trackId);
    await _refresh(collectionId);
  }

  /// Removes [trackId] from a collection.
  Future<void> removeTrack(String collectionId, String trackId) async {
    final collection = _find(collectionId);
    if (collection == null || !collection.trackIds.contains(trackId)) return;

    await _repository.removeTrackFromCollection(collectionId, trackId);
    await _refresh(collectionId);
  }

  /// Applies a drag-to-reorder result to the stored track list.
  Future<void> reorderTracks(String collectionId, List<String> newOrder) async {
    if (_find(collectionId) == null) return;

    await _repository.reorderTracks(collectionId, newOrder);
    await _refresh(collectionId);
  }

  /// Appends a split-sheet collaborator.
  Future<void> addParticipant(
    String collectionId,
    SplitParticipant participant,
  ) async {
    if (_find(collectionId) == null) return;

    await _repository.addParticipant(collectionId, participant);
    await _refresh(collectionId);
  }

  /// Removes the collaborator matching [name].
  Future<void> removeParticipant(String collectionId, String name) async {
    final collection = _find(collectionId);
    if (collection == null) return;
    if (!collection.participants.any((p) => p.name == name)) return;

    await _repository.removeParticipant(collectionId, name);
    await _refresh(collectionId);
  }

  /// Replaces the collaborator matching [updated] by name.
  Future<void> updateParticipant(
    String collectionId,
    SplitParticipant updated,
  ) async {
    final collection = _find(collectionId);
    if (collection == null) return;
    if (!collection.participants.any((p) => p.name == updated.name)) return;

    await _repository.updateParticipant(collectionId, updated);
    await _refresh(collectionId);
  }

  /// `true` when [trackId] already lives in [collectionId].
  bool containsTrack(String collectionId, String trackId) =>
      _find(collectionId)?.trackIds.contains(trackId) ?? false;

  /// Live lookup used by the detail view to survive vault refreshes.
  CollectionEntity? collectionById(String id) => _find(id);

  CollectionEntity? _find(String id) {
    for (final collection in state) {
      if (collection.id == id) return collection;
    }
    return null;
  }

  /// Mirrors a repository mutation back into the in-memory vault.
  Future<void> _refresh(String id) async {
    final updated = await _repository.getCollectionById(id);
    if (!mounted || updated == null) return;

    final index = state.indexWhere((collection) => collection.id == id);
    if (index < 0) return;

    final next = List<CollectionEntity>.of(state);
    next[index] = updated;
    setStateIfMounted(next);
  }
}

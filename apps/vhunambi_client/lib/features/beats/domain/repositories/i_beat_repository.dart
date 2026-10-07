import '../models/producer_beat_entity.dart';

/// Pure repository contract for the Producer Beats Vault (REQ-BEAT-07).
///
/// Implementations must return beats newest-first and must be safe to call
/// from headless `flutter_test` environments.
abstract class IBeatRepository {
  /// Vault catalogue ordered by `createdAt` descending.
  Future<List<ProducerBeatEntity>> getAllBeats();

  Future<ProducerBeatEntity?> getBeatById(String id);

  /// Inserts or replaces [beat] (upsert).
  Future<void> saveBeat(ProducerBeatEntity beat);

  /// Idempotent removal.
  Future<void> deleteBeat(String id);

  /// Transitions the beat to `published` and returns the stored record.
  Future<ProducerBeatEntity> publishBeat(String id);

  /// Transitions the beat to `draft` and returns the stored record.
  Future<ProducerBeatEntity> unpublishBeat(String id);

  /// Appends [sale] to the royalty ledger.
  Future<ProducerBeatEntity> recordSale(String id, BeatSaleRecord sale);

  /// Increments the audition preview counter.
  Future<ProducerBeatEntity> incrementAuditions(String id);

  Future<void> clearAll();
}

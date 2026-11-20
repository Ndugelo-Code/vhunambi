import '../../domain/models/marketplace_models.dart';

abstract class IMarketplaceRepository {
  Future<List<BeatListingEntity>> getBeats({
    String? genre,
    String? search,
    int? minBpm,
    int? maxBpm,
    int? maxPrice,
  });

  Future<BeatListingEntity?> getBeatById(String id);

  /// Fetches beats published by [producerId] via
  /// `GET /api/marketplace/producers/:producerId/beats` (`EP-P58-MKT-VERIFY-PRODUCER`).
  Future<List<BeatListingEntity>> getProducerBeats(String producerId);

  Future<BeatListingEntity> publishBeat(BeatListingEntity beat);

  Future<bool> unpublishBeat(String id);

  Future<Map<String, dynamic>> licenseBeat({
    required String beatId,
    required String buyerId,
    required String tier,
    String paymentMethod = 'coins',
  });
}


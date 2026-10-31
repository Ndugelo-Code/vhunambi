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

  Future<BeatListingEntity> publishBeat(BeatListingEntity beat);

  Future<bool> unpublishBeat(String id);

  Future<Map<String, dynamic>> licenseBeat({
    required String beatId,
    required String buyerId,
    required String tier,
    String paymentMethod = 'coins',
  });
}


import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/creator_id_utils.dart';
import '../../../../shared/models/track.dart';
import '../../../library/domain/models/library_models.dart';
import '../../../library/presentation/providers/library_providers.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../domain/models/marketplace_models.dart';
import '../../domain/repositories/i_marketplace_repository.dart';
import '../../data/repositories/http_marketplace_repository.dart';
import '../../../beats/domain/models/producer_beat_entity.dart';
import '../../../beats/presentation/providers/beats_provider.dart';

/// Production marketplace repository provider.
final marketplaceRepositoryProvider = Provider<IMarketplaceRepository>((ref) {
  return HttpMarketplaceRepository();
});

/// Outcome of a marketplace licensing transaction (REQ-MKT-04).
enum BeatLicenseOutcome { licensed, insufficientCredits }

/// Real-time marketplace filter dimensions (REQ-MKT-05).
final marketplaceFilterProvider =
    StateProvider<MarketplaceFilterState>((ref) => const MarketplaceFilterState());

/// Platform credit balance shown in the marketplace header chip.
final marketplaceCreditsProvider = StateProvider<int>((ref) => 10);

/// Beat listings available for licensing (REQ-MKT-03).
final marketplaceBeatsProvider =
    StateNotifierProvider<MarketplaceBeatsNotifier, List<BeatListingEntity>>(
  (ref) => MarketplaceBeatsNotifier(),
);

/// Listings matching the active search / genre / BPM / price filters.
/// Beat listings by a specific producer/creator (Phase 30 REQ-PROF-BEAT-CAT-01).
final creatorBeatsFamilyProvider =
    Provider.family<List<BeatListingEntity>, String>((ref, creatorId) {
  final allBeats = ref.watch(marketplaceBeatsProvider);
  final normalized = normalizeCreatorId(creatorId).toLowerCase();
  final raw = extractRawCreatorId(creatorId).toLowerCase();

  return allBeats.where((beat) {
    final prodId = beat.producerId.toLowerCase();
    final handle = beat.producerHandle.toLowerCase();
    final name = beat.producerName.toLowerCase();
    return prodId == normalized ||
        prodId == raw ||
        prodId == 'creator_$raw' ||
        handle == '@$raw' ||
        handle == raw ||
        name == raw;
  }).toList();
});

final filteredBeatsProvider = Provider<List<BeatListingEntity>>((ref) {
  return filterBeats(
    beats: ref.watch(marketplaceBeatsProvider),
    filter: ref.watch(marketplaceFilterProvider),
  );
});

/// Auditions a beat preview inside the persistent player dock (guardrail 7).
void auditionBeat(WidgetRef ref, BeatListingEntity beat) {
  ref.read(playerStateProvider.notifier).playTrack(
        Track(
          id: beat.id,
          title: beat.title,
          creatorName: beat.producerName,
          creatorHandle: beat.producerHandle,
          genre: beat.genre,
          language: 'Instrumental',
          duration: beat.previewDuration,
          audioUrl: beat.previewAudioUrl,
          mood: null,
        ),
      );
}

/// Licenses [beat]: deducts credits, registers the sale, and stores the beat in
/// the user's Library vault under its commercial licence (REQ-MKT-04).
BeatLicenseOutcome licenseBeat(WidgetRef ref, BeatListingEntity beat) {
  final balance = ref.read(marketplaceCreditsProvider);
  if (balance < beat.priceInCredits) {
    return BeatLicenseOutcome.insufficientCredits;
  }

  ref.read(marketplaceCreditsProvider.notifier).state =
      balance - beat.priceInCredits;

  ref.read(libraryTracksProvider.notifier).addTrack(
        LibraryTrack(
          id: 'market_${beat.id}',
          title: beat.title,
          creatorName: beat.producerName,
          genre: beat.genre,
          language: 'Instrumental',
          durationSeconds: beatPreviewDurationSeconds,
          remoteAudioUrl: beat.previewAudioUrl,
          createdAt: DateTime.now(),
          licenseType: beat.licenseType,
          isInstrumental: true,
        ),
      );

  ref.read(marketplaceBeatsProvider.notifier).registerSale(beat.id);
  ref.read(beatsProvider.notifier).recordSale(
        beat.id,
        '@buyer_user',
        beat.priceInCredits,
        BeatLicenseTier.nonExclusiveCommercial,
      );
  ref.read(marketplaceRepositoryProvider).licenseBeat(
        beatId: beat.id,
        buyerId: 'buyer_user',
        tier: 'basic_lease',
      );

  return BeatLicenseOutcome.licensed;
}

/// Clears every marketplace filter dimension (REQ-MKT-05).
void clearMarketplaceFilters(WidgetRef ref) {
  ref.read(marketplaceFilterProvider.notifier).state =
      const MarketplaceFilterState();
}

class MarketplaceBeatsNotifier extends StateNotifier<List<BeatListingEntity>> {
  MarketplaceBeatsNotifier() : super(_seedBeats());

  /// Records a completed licensing transaction against the listing.
  void registerSale(String beatId) {
    state = [
      for (final beat in state)
        if (beat.id == beatId)
          beat.copyWith(totalSales: beat.totalSales + 1)
        else
          beat,
    ];
  }

  /// Publishes a new listing to the marketplace (producer uploads, Phase 7+).
  void addListing(BeatListingEntity beat) {
    state = [beat, ...state];
  }

  /// Inserts or refreshes the producer beat listing (Phase 14 REQ-BEAT-21).
  ///
  /// Publishing the same beat twice never duplicates the public listing.
  void upsertListing(BeatListingEntity beat) {
    final index = state.indexWhere((listing) => listing.id == beat.id);
    if (index < 0) {
      state = [beat, ...state];
      return;
    }

    final next = List<BeatListingEntity>.of(state);
    next[index] = beat;
    state = next;
  }

  /// Removes a listing once the beat is unpublished, archived or deleted
  /// (Phase 14 REQ-BEAT-21).
  void removeListing(String beatId) {
    if (!isListed(beatId)) return;
    state = state
        .where((listing) => listing.id != beatId)
        .toList(growable: false);
  }

  /// `true` while [beatId] is visible on the public marketplace.
  bool isListed(String beatId) => state.any((listing) => listing.id == beatId);
}

/// Pure marketplace projection: search → genre → BPM range → credit price,
/// ordered newest-first (`createdAt` descending).
List<BeatListingEntity> filterBeats({
  required List<BeatListingEntity> beats,
  MarketplaceFilterState filter = const MarketplaceFilterState(),
}) {
  final query = filter.searchQuery.trim().toLowerCase();
  final genre = filter.genre.trim().toLowerCase();
  final filtersByGenre = filter.genre != MarketplaceFilterState.allGenres;

  final scoped = beats.where((beat) {
    if (filtersByGenre && genre.isNotEmpty && beat.genre.toLowerCase() != genre) {
      return false;
    }
    if (filter.minBpm != null && beat.bpm < filter.minBpm!) return false;
    if (filter.maxBpm != null && beat.bpm > filter.maxBpm!) return false;
    if (filter.maxPriceCredits != null &&
        beat.priceInCredits > filter.maxPriceCredits!) {
      return false;
    }
    if (query.isEmpty) return true;

    return beat.title.toLowerCase().contains(query) ||
        beat.producerName.toLowerCase().contains(query) ||
        beat.producerHandle.toLowerCase().contains(query) ||
        beat.genre.toLowerCase().contains(query);
  }).toList();

  scoped.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return List.unmodifiable(scoped);
}

/// Seeded marketplace listings (Phase 6 handoff §2).
List<BeatListingEntity> _seedBeats() {
  final now = DateTime.now();
  const origin = 'https://cdn.vhunambi.com/beats';

  return [
    BeatListingEntity(
      id: 'beat_township_heat',
      title: 'Township Heat',
      producerId: 'creator_sipho',
      producerName: 'Sipho',
      producerHandle: '@sipho_beats',
      genre: 'Amapiano',
      bpm: 112,
      musicalKey: 'F# Minor',
      priceInCredits: 5,
      previewAudioUrl: '$origin/township-heat.mp3',
      stemZipUrl: '$origin/township-heat-stems.zip',
      totalSales: 18,
      createdAt: now.subtract(const Duration(hours: 2)),
    ),
    BeatListingEntity(
      id: 'beat_durban_midnight',
      title: 'Durban Midnight Bass',
      producerId: 'creator_djvibe',
      producerName: 'DJ Vibe',
      producerHandle: '@djvibe',
      genre: 'Gqom',
      bpm: 128,
      musicalKey: 'A Minor',
      priceInCredits: 5,
      previewAudioUrl: '$origin/durban-midnight-bass.mp3',
      stemZipUrl: '$origin/durban-midnight-bass-stems.zip',
      totalSales: 24,
      createdAt: now.subtract(const Duration(hours: 6)),
    ),
    BeatListingEntity(
      id: 'beat_zulu_acoustic',
      title: 'Zulu Acoustic Flow',
      producerId: 'creator_ndugelo',
      producerName: 'Ndugelo',
      producerHandle: '@ndugelo',
      genre: 'Maskandi',
      bpm: 115,
      musicalKey: 'C Major',
      priceInCredits: 5,
      previewAudioUrl: '$origin/zulu-acoustic-flow.mp3',
      stemZipUrl: '$origin/zulu-acoustic-flow-stems.zip',
      totalSales: 11,
      createdAt: now.subtract(const Duration(hours: 12)),
    ),
    BeatListingEntity(
      id: 'beat_soweto_sunset',
      title: 'Soweto Sunset Groove',
      producerId: 'creator_lerato',
      producerName: 'Lerato',
      producerHandle: '@lerato_prod',
      genre: 'Afro House',
      bpm: 120,
      musicalKey: 'G Minor',
      priceInCredits: 5,
      previewAudioUrl: '$origin/soweto-sunset-groove.mp3',
      stemZipUrl: '$origin/soweto-sunset-groove-stems.zip',
      totalSales: 9,
      createdAt: now.subtract(const Duration(days: 1)),
    ),
    BeatListingEntity(
      id: 'beat_limpopo_log_drum',
      title: 'Limpopo Log Drum Rush',
      producerId: 'creator_fifi',
      producerName: 'Fifi',
      producerHandle: '@fifi_music',
      genre: 'Amapiano',
      bpm: 114,
      musicalKey: 'E Minor',
      priceInCredits: 5,
      previewAudioUrl: '$origin/limpopo-log-drum-rush.mp3',
      stemZipUrl: '$origin/limpopo-log-drum-rush-stems.zip',
      totalSales: 15,
      createdAt: now.subtract(const Duration(days: 2)),
    ),
    BeatListingEntity(
      id: 'beat_lagos_horns',
      title: 'Lagos Afrobeat Horns',
      producerId: 'creator_ade',
      producerName: 'Ade',
      producerHandle: '@ade_sound',
      genre: 'Afrobeats',
      bpm: 105,
      musicalKey: 'D Minor',
      priceInCredits: 5,
      previewAudioUrl: '$origin/lagos-afrobeat-horns.mp3',
      stemZipUrl: '$origin/lagos-afrobeat-horns-stems.zip',
      totalSales: 31,
      createdAt: now.subtract(const Duration(days: 4)),
    ),
  ];
}

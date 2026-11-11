import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../library/domain/models/library_models.dart';
import '../../../marketplace/domain/models/marketplace_models.dart';
import '../../../marketplace/presentation/providers/marketplace_providers.dart';
import '../../../player/domain/models/player_state.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../../shared/models/track.dart';
import '../../data/repositories/beat_repository.dart';
import '../../data/repositories/in_memory_beat_repository.dart';
import '../../domain/models/producer_beat_entity.dart';
import '../../domain/repositories/i_beat_repository.dart';

/// Vault ordering applied by `filteredBeatsVaultProvider` (REQ-BEAT-11).
enum BeatsSortOrder {
  newest,
  bpmAsc,
  bpmDesc,
  mostSales,
  highestEarnings;

  String get label => switch (this) {
        BeatsSortOrder.newest => 'Newest',
        BeatsSortOrder.bpmAsc => 'BPM: Low to High',
        BeatsSortOrder.bpmDesc => 'BPM: High to Low',
        BeatsSortOrder.mostSales => 'Most Sold',
        BeatsSortOrder.highestEarnings => 'Highest Earnings',
      };
}

/// Real-time beat vault filter dimensions (REQ-BEAT-11).
@immutable
class BeatsVaultFilterState {
  /// Sentinel genre meaning "no genre restriction".
  static const String allGenres = 'All';

  final String searchQuery;

  /// `null` renders the `All` status chip.
  final BeatStatus? statusFilter;
  final String genreFilter;
  final BeatsSortOrder sortOrder;

  const BeatsVaultFilterState({
    this.searchQuery = '',
    this.statusFilter,
    this.genreFilter = allGenres,
    this.sortOrder = BeatsSortOrder.newest,
  });

  bool get hasActiveFilters =>
      searchQuery.trim().isNotEmpty ||
      statusFilter != null ||
      genreFilter != allGenres;

  BeatsVaultFilterState copyWith({
    String? searchQuery,
    BeatStatus? statusFilter,
    bool clearStatus = false,
    String? genreFilter,
    BeatsSortOrder? sortOrder,
  }) {
    return BeatsVaultFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: clearStatus ? null : (statusFilter ?? this.statusFilter),
      genreFilter: genreFilter ?? this.genreFilter,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  /// Clears every dimension back to the default `All / Newest` projection.
  BeatsVaultFilterState cleared() => const BeatsVaultFilterState();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BeatsVaultFilterState &&
          other.searchQuery == searchQuery &&
          other.statusFilter == statusFilter &&
          other.genreFilter == genreFilter &&
          other.sortOrder == sortOrder;

  @override
  int get hashCode =>
      Object.hash(searchQuery, statusFilter, genreFilter, sortOrder);
}

/// Producer analytics aggregate backing `BeatStatsBanner` (REQ-BEAT-13).
@immutable
class BeatsVaultStats {
  final int totalBeats;
  final int publishedCount;
  final int draftCount;
  final int totalSalesCount;
  final int totalCreditsEarned;

  const BeatsVaultStats({
    required this.totalBeats,
    required this.publishedCount,
    required this.draftCount,
    required this.totalSalesCount,
    required this.totalCreditsEarned,
  });

  /// Count of beats hidden from the live marketplace (draft + archived).
  int get vaultOnlyCount => totalBeats - publishedCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BeatsVaultStats &&
          other.totalBeats == totalBeats &&
          other.publishedCount == publishedCount &&
          other.draftCount == draftCount &&
          other.totalSalesCount == totalSalesCount &&
          other.totalCreditsEarned == totalCreditsEarned;

  @override
  int get hashCode => Object.hash(
        totalBeats,
        publishedCount,
        draftCount,
        totalSalesCount,
        totalCreditsEarned,
      );
}

/// Injectable beat repository (REQ-BEAT-10).
///
/// Backed by the production [BeatRepository] with automatic headless fallback;
/// override with [InMemoryBeatRepository] in tests.
final beatRepositoryProvider = Provider<IBeatRepository>(
  (ref) => BeatRepository(),
);

/// The producer's beat vault (REQ-BEAT-10).
final beatsProvider =
    StateNotifierProvider<BeatsNotifier, List<ProducerBeatEntity>>((ref) {
  final notifier = BeatsNotifier(
    repository: ref.watch(beatRepositoryProvider),
    marketplace: ref.read(marketplaceBeatsProvider.notifier),
  );
  notifier.loadBeats();
  return notifier;
});

/// Real-time search / status / genre / ordering dimensions (REQ-BEAT-11).
final beatsVaultFilterProvider = StateProvider<BeatsVaultFilterState>(
  (ref) => const BeatsVaultFilterState(),
);

/// Filtered + sorted vault projection (REQ-BEAT-12).
final filteredBeatsVaultProvider = Provider<List<ProducerBeatEntity>>((ref) {
  return filterBeatsVault(
    beats: ref.watch(beatsProvider),
    filter: ref.watch(beatsVaultFilterProvider),
  );
});

/// Producer sales, publication and royalty analytics (REQ-BEAT-13).
final beatsVaultStatsProvider = Provider<BeatsVaultStats>((ref) {
  return beatsVaultStatsFor(ref.watch(beatsProvider));
});

/// Projects a [ProducerBeatEntity] into the public marketplace listing model
/// (REQ-BEAT-21).
BeatListingEntity beatListingFromEntity(ProducerBeatEntity beat) {
  return BeatListingEntity(
    id: beat.id,
    title: beat.title,
    producerId: beat.producerId,
    producerName: beat.producerName,
    producerHandle: beat.producerHandle,
    genre: beat.genre,
    bpm: beat.bpm,
    musicalKey: beat.musicalKey,
    priceInCredits: beat.priceInCredits,
    previewAudioUrl: beat.previewAudioUrl,
    stemZipUrl: beat.stemPackage.hasAllStems
        ? '$beatCdnOrigin/stems/${beat.id}_stems.zip'
        : null,
    licenseType: beat.licenseTier.label,
    totalSales: beat.totalSales,
    isExclusiveSold: beat.isExclusiveSold,
    exclusiveBuyerId: beat.exclusiveBuyerId,
    createdAt: beat.createdAt,
  );
}

/// Pure vault projection used by [filteredBeatsVaultProvider]: status scope →
/// genre scope → free-text search → ordering (REQ-BEAT-12).
List<ProducerBeatEntity> filterBeatsVault({
  required List<ProducerBeatEntity> beats,
  BeatsVaultFilterState filter = const BeatsVaultFilterState(),
}) {
  final query = filter.searchQuery.trim().toLowerCase();

  final scoped = beats.where((beat) {
    if (filter.statusFilter != null && beat.status != filter.statusFilter) {
      return false;
    }

    final genre = filter.genreFilter;
    if (genre != BeatsVaultFilterState.allGenres &&
        genre.isNotEmpty &&
        beat.genre != genre) {
      return false;
    }

    if (query.isEmpty) return true;

    return beat.title.toLowerCase().contains(query) ||
        beat.genre.toLowerCase().contains(query) ||
        beat.musicalKey.toLowerCase().contains(query) ||
        beat.producerHandle.toLowerCase().contains(query) ||
        beat.tags.any((tag) => tag.toLowerCase().contains(query));
  }).toList();

  switch (filter.sortOrder) {
    case BeatsSortOrder.newest:
      scoped.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    case BeatsSortOrder.bpmAsc:
      scoped.sort((a, b) {
        final byBpm = a.bpm.compareTo(b.bpm);
        return byBpm != 0 ? byBpm : a.title.compareTo(b.title);
      });
    case BeatsSortOrder.bpmDesc:
      scoped.sort((a, b) {
        final byBpm = b.bpm.compareTo(a.bpm);
        return byBpm != 0 ? byBpm : a.title.compareTo(b.title);
      });
    case BeatsSortOrder.mostSales:
      scoped.sort((a, b) => b.totalSales.compareTo(a.totalSales));
    case BeatsSortOrder.highestEarnings:
      scoped.sort(
        (a, b) => b.totalEarningsCredits.compareTo(a.totalEarningsCredits),
      );
  }

  return List<ProducerBeatEntity>.unmodifiable(scoped);
}

/// Pure analytics aggregate used by [beatsVaultStatsProvider] (REQ-BEAT-13).
BeatsVaultStats beatsVaultStatsFor(List<ProducerBeatEntity> beats) {
  return BeatsVaultStats(
    totalBeats: beats.length,
    publishedCount: beats.where((beat) => beat.isPublished).length,
    draftCount: beats.where((beat) => beat.isDraft).length,
    totalSalesCount: beats.fold<int>(0, (sum, beat) => sum + beat.totalSales),
    totalCreditsEarned:
        beats.fold<int>(0, (sum, beat) => sum + beat.totalEarningsCredits),
  );
}

/// Full beat CRUD, authoring and marketplace-synchronisation engine
/// (REQ-BEAT-10 / REQ-BEAT-21).
class BeatsNotifier extends StateNotifier<List<ProducerBeatEntity>> {
  BeatsNotifier({
    required IBeatRepository repository,
    MarketplaceBeatsNotifier? marketplace,
  }) : this._(repository, marketplace);

  BeatsNotifier._(this._repository, this._marketplace)
      : super(const <ProducerBeatEntity>[]);

  final IBeatRepository _repository;

  /// Public marketplace sink; `null` keeps the notifier usable in pure unit
  /// tests that do not wire the marketplace graph.
  final MarketplaceBeatsNotifier? _marketplace;

  /// Re-reads the persisted vault (newest first).
  Future<void> loadBeats() async {
    final beats = await _repository.getAllBeats();
    if (!mounted) return;
    state = beats;
  }

  /// Creates a beat record and prepends it to the vault.
  Future<ProducerBeatEntity> createBeat({
    required String title,
    required String genre,
    int bpm = defaultBeatBpm,
    String musicalKey = 'F# Minor',
    List<String> tags = const <String>[],
    int priceInCredits = 10,
    BeatLicenseTier licenseTier = BeatLicenseTier.nonExclusiveCommercial,
    BeatStatus status = BeatStatus.draft,
    String previewAudioUrl = '',
    BeatStemPackage stemPackage = const BeatStemPackage(),
    String? trackId,
  }) async {
    final now = DateTime.now();
    final beat = ProducerBeatEntity(
      id: 'beat_${now.microsecondsSinceEpoch}',
      trackId: trackId,
      title: title.trim(),
      genre: genre.trim(),
      bpm: _clampBpm(bpm),
      musicalKey: musicalKey.trim(),
      tags: List<String>.unmodifiable(tags),
      priceInCredits: priceInCredits,
      licenseTier: licenseTier,
      status: status,
      previewAudioUrl: previewAudioUrl,
      stemPackage: stemPackage,
      createdAt: now,
      updatedAt: now,
    );

    await _repository.saveBeat(beat);
    if (mounted) {
      state = <ProducerBeatEntity>[beat, ...state];
    }
    if (beat.isPublished) {
      _marketplace?.upsertListing(beatListingFromEntity(beat));
    }
    return beat;
  }

  /// Persists an edited beat and mirrors the change into the marketplace
  /// listing when the beat is currently published.
  Future<void> updateBeat(ProducerBeatEntity beat) async {
    final updated = beat.copyWith(updatedAt: DateTime.now());
    await _repository.saveBeat(updated);

    if (mounted) {
      final index = state.indexWhere((candidate) => candidate.id == beat.id);
      if (index >= 0) {
        final next = List<ProducerBeatEntity>.of(state);
        next[index] = updated;
        state = next;
      } else {
        state = <ProducerBeatEntity>[updated, ...state];
      }
    }

    if (updated.isPublished) {
      _marketplace?.upsertListing(beatListingFromEntity(updated));
    } else {
      _marketplace?.removeListing(updated.id);
    }
  }

  /// Deletes the beat and pulls the listing from the public marketplace.
  Future<void> deleteBeat(String id) async {
    await _repository.deleteBeat(id);
    if (mounted) {
      state = state.where((beat) => beat.id != id).toList(growable: false);
    }
    _marketplace?.removeListing(id);
  }

  /// Publishes the beat publicly and injects its listing (REQ-BEAT-21).
  Future<void> publishToMarket(String id) async {
    final index = state.indexWhere((beat) => beat.id == id);
    if (index < 0) return;

    final updated = await _repository.publishBeat(id);
    if (!mounted) return;

    final next = List<ProducerBeatEntity>.of(state);
    next[index] = updated;
    state = next;

    _marketplace?.upsertListing(beatListingFromEntity(updated));
  }

  /// Reverts the beat to a vault-only draft and removes its listing.
  Future<void> unpublishFromMarket(String id) async {
    final index = state.indexWhere((beat) => beat.id == id);
    if (index < 0) return;

    final updated = await _repository.unpublishBeat(id);
    if (!mounted) return;

    final next = List<ProducerBeatEntity>.of(state);
    next[index] = updated;
    state = next;

    _marketplace?.removeListing(id);
  }

  /// Archives the beat: hidden from the marketplace and the default vault view.
  Future<void> archiveBeat(String id) async {
    final index = state.indexWhere((beat) => beat.id == id);
    if (index < 0) return;

    final archived = state[index].copyWith(
      status: BeatStatus.archived,
      updatedAt: DateTime.now(),
    );
    await _repository.saveBeat(archived);
    if (!mounted) return;

    final next = List<ProducerBeatEntity>.of(state);
    next[index] = archived;
    state = next;

    _marketplace?.removeListing(id);
  }

  /// Restores an archived beat back to a vault-only draft.
  Future<void> restoreToDraft(String id) async {
    final index = state.indexWhere((beat) => beat.id == id);
    if (index < 0) return;

    final restored = state[index].copyWith(
      status: BeatStatus.draft,
      updatedAt: DateTime.now(),
    );
    await _repository.saveBeat(restored);
    if (!mounted) return;

    final next = List<ProducerBeatEntity>.of(state);
    next[index] = restored;
    state = next;
  }

  /// Registers a completed license purchase in the producer royalty ledger.
  Future<void> recordSale(
    String id,
    String buyerHandle,
    int credits,
    BeatLicenseTier tier, {
    String? markExclusiveBuyerId,
  }) async {
    final index = state.indexWhere((beat) => beat.id == id);
    if (index < 0) return;

    final now = DateTime.now();
    final handle =
        buyerHandle.trim().isEmpty ? '@anonymous' : buyerHandle.trim();
    final sale = BeatSaleRecord(
      saleId: 'sale_${now.microsecondsSinceEpoch}',
      buyerId: handle.replaceFirst('@', ''),
      buyerHandle: handle,
      licenseTier: tier,
      creditsEarned: credits,
      timestamp: now,
    );

    var updated = await _repository.recordSale(id, sale);
    if (markExclusiveBuyerId != null ||
        tier == BeatLicenseTier.exclusiveOwnership) {
      updated = updated.copyWith(
        isExclusiveSold: true,
        exclusiveBuyerId: markExclusiveBuyerId ?? sale.buyerId,
        updatedAt: DateTime.now(),
      );
      await _repository.saveBeat(updated);
    }
    if (!mounted) return;

    final next = List<ProducerBeatEntity>.of(state);
    next[index] = updated;
    state = next;

    if (updated.isPublished) {
      _marketplace?.upsertListing(beatListingFromEntity(updated));
    }
  }

  /// Increments the audition preview counter for the beat.
  Future<void> recordAudition(String id) async {
    final index = state.indexWhere((beat) => beat.id == id);
    if (index < 0) return;

    final updated = await _repository.incrementAuditions(id);
    if (!mounted) return;

    final next = List<ProducerBeatEntity>.of(state);
    next[index] = updated;
    state = next;
  }

  /// Converts an existing vault asset into a license-ready beat listing
  /// (Blueprint 14 §2.3).
  Future<ProducerBeatEntity> convertTrackToBeat(
    LibraryTrack track, {
    int bpm = defaultBeatBpm,
    String key = 'F# Minor',
    int price = 10,
  }) async {
    final tags = <String>[
      if (track.isInstrumental) 'Instrumental',
      if (track.genre.trim().isNotEmpty) track.genre.trim(),
    ];

    return createBeat(
      title: track.title,
      genre: track.genre,
      bpm: bpm,
      musicalKey: key,
      tags: tags,
      priceInCredits: price,
      licenseTier: BeatLicenseTier.nonExclusiveCommercial,
      previewAudioUrl: track.remoteAudioUrl,
      trackId: track.id,
    );
  }

  /// Live lookup used by the cockpit view to survive vault refreshes.
  ProducerBeatEntity? beatById(String id) {
    for (final beat in state) {
      if (beat.id == id) return beat;
    }
    return null;
  }

  /// Tap-tempo / free-text BPM values are clamped into `40–260`.
  int _clampBpm(int bpm) {
    if (bpm < minBeatBpm) return minBeatBpm;
    if (bpm > maxBeatBpm) return maxBeatBpm;
    return bpm;
  }
}

/// Bridges a producer beat into the persistent player queue (REQ-BEAT-22).
///
/// Previews always stream as a 180 second instrumental.
Track beatPreviewTrack(ProducerBeatEntity beat) {
  return Track(
    id: beat.id,
    title: beat.title,
    creatorName: beat.producerName,
    creatorHandle: beat.producerHandle,
    genre: beat.genre,
    language: 'Instrumental',
    duration: const Duration(seconds: ProducerBeatEntity.previewSeconds),
    audioUrl: beat.previewAudioUrl,
  );
}

/// Starts the preview and increments the beat audition counter (REQ-BEAT-22).
void auditionBeatPreview(WidgetRef ref, ProducerBeatEntity beat) {
  ref.read(playerStateProvider.notifier).playTrack(beatPreviewTrack(beat));
  ref.read(beatsProvider.notifier).recordAudition(beat.id);
}

/// `true` while [beat] owns the preview currently playing in the player dock.
bool isBeatAuditioning(PlayerState state, ProducerBeatEntity beat) =>
    state.currentTrack?.id == beat.id &&
    state.playbackStatus == PlaybackStatus.playing;

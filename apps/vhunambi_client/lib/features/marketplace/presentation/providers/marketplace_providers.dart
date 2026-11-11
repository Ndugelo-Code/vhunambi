import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/auth_providers.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/storage/sovereign_domain_repositories.dart';
import '../../../../core/sync/sync_outbox_service.dart';
import '../../../../core/utils/creator_id_utils.dart';
import '../../../../shared/models/track.dart';
import '../../../library/domain/models/library_models.dart';
import '../../../library/presentation/providers/library_providers.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../domain/models/licensing_models.dart';
import '../../domain/models/marketplace_models.dart';
import '../../domain/repositories/i_marketplace_repository.dart';
import '../../domain/services/license_agreement_engine.dart';
import '../../domain/services/sovereign_certificate_signer.dart';
import '../../data/repositories/http_marketplace_repository.dart';
import '../../../beats/domain/models/producer_beat_entity.dart';
import '../../../beats/presentation/providers/beats_provider.dart';
import '../../../social/presentation/providers/creator_wallet_provider.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../../notifications/domain/models/notification_entity.dart';
import '../../../notifications/domain/models/notification_enums.dart';
import 'beat_checkout_provider.dart';

/// Production marketplace repository provider.
final marketplaceRepositoryProvider = Provider<IMarketplaceRepository>((ref) {
  return HttpMarketplaceRepository(
    authInterceptor: ref.watch(authDioInterceptorProvider),
  );
});

/// Outcome of a marketplace licensing transaction (REQ-MKT-04).
enum BeatLicenseOutcome { licensed, insufficientCredits }

/// Real-time marketplace filter dimensions (REQ-MKT-05).
final marketplaceFilterProvider = StateProvider<MarketplaceFilterState>(
  (ref) => const MarketplaceFilterState(),
);

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
  ref
      .read(playerStateProvider.notifier)
      .playTrack(
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

/// Licenses [beat] synchronously (compatibility bridge for Phase 39/40 callers) while
/// signing a real SHA-256 certificate, debiting wallet coins when funded, crediting the
/// producer royalty split, and queuing critical outbox sync (Phase 58).
BeatLicenseOutcome licenseBeat(WidgetRef ref, BeatListingEntity beat) {
  final balance = ref.read(marketplaceCreditsProvider);
  if (balance < beat.priceInCredits || beat.isExclusiveSold) {
    return BeatLicenseOutcome.insufficientCredits;
  }

  final tier = BeatCheckoutTier.fromWire(beat.licenseType);
  const engine = LicenseAgreementEngine();
  const signer = SovereignCertificateSigner();
  final pricing = engine.calculateTierPricing(
    baseCredits: beat.priceInCredits,
    tier: tier,
  );

  final walletNotifier = ref.read(creatorWalletProvider.notifier);
  walletNotifier.debitForBeatPurchase(
    coins: pricing.grossCoins,
    beatTitle: beat.title,
    tierLabel: tier.displayName,
  );
  ref.read(marketplaceCreditsProvider.notifier).state =
      balance - beat.priceInCredits;

  final session = ref.read(authSessionProvider);
  final buyerId = session.canonicalCreatorId;
  final buyerHandle = session.handle;

  final nowUtc = DateTime.now().toUtc();
  final issuedAtIso = nowUtc.toIso8601String();
  final certId = SovereignCertificateSigner.generateCertificateId(
    beatId: beat.id,
    buyerId: buyerId,
    timestampUtc: nowUtc,
  );
  final rights = engine.buildRightsProfile(
    beatTitle: beat.title,
    producerName: beat.producerName,
    producerHandle: beat.producerHandle,
    buyerHandle: buyerHandle,
    genre: beat.genre,
    bpm: beat.bpm,
    musicalKey: beat.musicalKey,
    pricing: pricing,
    issuedAtIso8601: issuedAtIso,
  );
  final vaultTrackId = 'market_${beat.id}';
  final masterDigest = SovereignCertificateSigner.sha256HexUtf8(beat.id);
  final cert = signer.signCertificate(
    certificateId: certId,
    beatId: beat.id,
    beatTitle: beat.title,
    producerId: beat.producerId,
    producerHandle: beat.producerHandle,
    producerName: beat.producerName,
    buyerId: buyerId,
    buyerHandle: buyerHandle,
    genre: beat.genre,
    bpm: beat.bpm,
    musicalKey: beat.musicalKey,
    pricing: pricing,
    issuedAtIso8601: issuedAtIso,
    commercialTerms: rights.fullLegalText,
    vaultTrackId: vaultTrackId,
    masterAudioFilePath: '',
    stemPaths: const <String, String>{},
    masterFileSha256: masterDigest,
  );

  ref
      .read(libraryTracksProvider.notifier)
      .upsertLicensedTrack(
        LibraryTrack(
          id: vaultTrackId,
          title: beat.title,
          creatorName: beat.producerName,
          genre: beat.genre,
          language: 'Instrumental',
          durationSeconds: beatPreviewDurationSeconds,
          remoteAudioUrl: beat.previewAudioUrl,
          createdAt: nowUtc.toLocal(),
          licenseType: beat.licenseType,
          licenseTierId: tier.wireSlug,
          licenseCertificateIdOverride: cert.certificateId,
          licenseHash: cert.licenseHash,
          isInstrumental:
              beat.assetCategory == MarketplaceAssetCategory.beats ||
              beat.assetCategory == MarketplaceAssetCategory.liveInstruments,
        ),
      );
  unawaited(
    ref.read(licenseCertificatesProvider.notifier).recordCertificate(cert),
  );

  ref.read(marketplaceBeatsProvider.notifier).registerSale(beat.id);
  if (tier.grantsExclusivity) {
    ref
        .read(marketplaceBeatsProvider.notifier)
        .markSoldExclusive(beatId: beat.id, buyerId: buyerId);
  }
  ref
      .read(beatsProvider.notifier)
      .recordSale(
        beat.id,
        buyerHandle,
        beat.priceInCredits,
        BeatLicenseTier.nonExclusiveCommercial,
      );
  walletNotifier.recordMarketplaceRoyalty(
    assetTitle: beat.title,
    amountCoins: pricing.producerRoyaltyCoins,
    netZar: pricing.producerRoyaltyZar,
  );
  unawaited(
    ref
        .read(syncOutboxServiceProvider)
        .enqueue(
          SyncMutationRecord(
            idempotencyKey: 'lic_${cert.certificateId}',
            entityType: 'beat_license',
            action: 'purchase',
            payload: cert.toJson(),
            createdAt: nowUtc,
            priority: SyncPriority.critical,
          ),
        ),
  );
  unawaited(
    ref
        .read(marketplaceRepositoryProvider)
        .licenseBeat(beatId: beat.id, buyerId: buyerId, tier: tier.wireSlug),
  );
  ref
      .read(notificationsProvider.notifier)
      .addNotification(
        NotificationEntity(
          id: 'notif_mkt_${nowUtc.millisecondsSinceEpoch}',
          title: 'Marketplace License Acquired!',
          message:
              'Unlocked "${beat.title}" by ${beat.producerName} (Certificate ${cert.certificateId} in Vault).',
          category: NotificationCategory.creatorActivity,
          priority: NotificationPriority.high,
          createdAt: nowUtc.toLocal(),
        ),
      );

  return BeatLicenseOutcome.licensed;
}

/// Clears every marketplace filter dimension (REQ-MKT-05).
void clearMarketplaceFilters(WidgetRef ref) {
  ref.read(marketplaceFilterProvider.notifier).state =
      const MarketplaceFilterState();
}

class MarketplaceBeatsNotifier extends StateNotifier<List<BeatListingEntity>> {
  MarketplaceBeatsNotifier() : super(_initialBeats());

  static List<BeatListingEntity> _initialBeats() {
    final seeds = _seedBeats();
    if (!SovereignDomainStorageMode.canHydrateFromStorage(
      AppConstants.marketplaceCatalogBoxKey,
    )) {
      return seeds;
    }

    final removedIds =
        MarketplaceCatalogCacheRepository.loadRemovedListingIds();
    final byId = <String, BeatListingEntity>{
      for (final b in seeds)
        if (!removedIds.contains(b.id)) b.id: b,
    };

    final orderedCustom = <BeatListingEntity>[];
    for (final customJson
        in MarketplaceCatalogCacheRepository.loadCustomListings()) {
      try {
        final parsed = BeatListingEntity.fromJson(customJson);
        if (!removedIds.contains(parsed.id)) {
          if (!byId.containsKey(parsed.id)) {
            orderedCustom.add(parsed);
          }
          byId[parsed.id] = parsed;
        }
      } catch (_) {}
    }

    final merged = <BeatListingEntity>[
      ...orderedCustom,
      for (final s in seeds)
        if (byId.containsKey(s.id)) byId[s.id]!,
    ];

    return [
      for (final beat in merged)
        () {
          final isSold =
              MarketplaceCatalogCacheRepository.isExclusiveSold(beat.id) ||
              beat.isExclusiveSold;
          final buyerId =
              MarketplaceCatalogCacheRepository.loadExclusiveBuyerId(beat.id) ??
              beat.exclusiveBuyerId;
          final totalSales =
              MarketplaceCatalogCacheRepository.loadSalesCount(beat.id) ??
              beat.totalSales;
          if (isSold == beat.isExclusiveSold &&
              buyerId == beat.exclusiveBuyerId &&
              totalSales == beat.totalSales) {
            return beat;
          }
          return beat.copyWith(
            isExclusiveSold: isSold,
            exclusiveBuyerId: buyerId,
            totalSales: totalSales,
          );
        }(),
    ];
  }

  /// Records a completed licensing transaction against the listing.
  void registerSale(String beatId) {
    int? updatedCount;
    state = [
      for (final beat in state)
        if (beat.id == beatId)
          () {
            updatedCount = beat.totalSales + 1;
            return beat.copyWith(totalSales: updatedCount);
          }()
        else
          beat,
    ];
    if (updatedCount != null) {
      unawaited(
        MarketplaceCatalogCacheRepository.saveSalesCount(beatId, updatedCount!),
      );
    }
  }

  /// Atomically marks an exclusively purchased beat as sold & locked (Phase 58).
  void markSoldExclusive({required String beatId, required String buyerId}) {
    state = [
      for (final beat in state)
        if (beat.id == beatId)
          beat.copyWith(isExclusiveSold: true, exclusiveBuyerId: buyerId)
        else
          beat,
    ];
    unawaited(
      MarketplaceCatalogCacheRepository.markExclusiveSold(
        beatId,
        buyerId: buyerId,
      ),
    );
  }

  /// Publishes a new listing to the marketplace (producer uploads, Phase 7+).
  void addListing(BeatListingEntity beat) {
    state = [beat, ...state];
    unawaited(MarketplaceCatalogCacheRepository.saveBeatListing(beat.toJson()));
  }

  /// Inserts or refreshes the producer beat listing (Phase 14 REQ-BEAT-21).
  ///
  /// Publishing the same beat twice never duplicates the public listing.
  void upsertListing(BeatListingEntity beat) {
    final index = state.indexWhere((listing) => listing.id == beat.id);
    if (index < 0) {
      state = [beat, ...state];
    } else {
      final next = List<BeatListingEntity>.of(state);
      next[index] = beat;
      state = next;
    }
    unawaited(MarketplaceCatalogCacheRepository.saveBeatListing(beat.toJson()));
  }

  /// Removes a listing once the beat is unpublished, archived or deleted
  /// (Phase 14 REQ-BEAT-21).
  void removeListing(String beatId) {
    if (!isListed(beatId)) return;
    state = state
        .where((listing) => listing.id != beatId)
        .toList(growable: false);
    unawaited(MarketplaceCatalogCacheRepository.removeBeatListing(beatId));
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
    if (beat.isExclusiveSold) {
      return false;
    }
    if (filter.category != MarketplaceAssetCategory.all &&
        beat.assetCategory != filter.category) {
      return false;
    }
    if (filtersByGenre &&
        genre.isNotEmpty &&
        beat.genre.toLowerCase() != genre) {
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
      assetCategory: MarketplaceAssetCategory.beats,
      provenanceType: AudioProvenanceType.humanDawMaster,
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
      assetCategory: MarketplaceAssetCategory.beats,
      provenanceType: AudioProvenanceType.humanDawMaster,
    ),
    BeatListingEntity(
      id: 'vocal_makhadzi_hook',
      title: 'Tshivenḓa Amapiano Vocal Hook',
      producerId: 'creator_makhadzi',
      producerName: 'Makhadzi',
      producerHandle: '@makhadzi',
      genre: 'Amapiano',
      bpm: 112,
      musicalKey: 'F# Minor',
      priceInCredits: 4,
      previewAudioUrl: '$origin/makhadzi-vocal-hook.mp3',
      stemZipUrl: '$origin/makhadzi-vocal-hook-stems.zip',
      totalSales: 42,
      createdAt: now.subtract(const Duration(hours: 8)),
      assetCategory: MarketplaceAssetCategory.vocals,
      provenanceType: AudioProvenanceType.liveVocalRecording,
    ),
    BeatListingEntity(
      id: 'vocal_zulu_soul_harmonies',
      title: 'isiZulu Maskandi Vocal Cry',
      producerId: 'creator_sigwa_inaf',
      producerName: 'Sigwa Inaf',
      producerHandle: '@sigwa_inaf',
      genre: 'Maskandi',
      bpm: 115,
      musicalKey: 'C Major',
      priceInCredits: 5,
      previewAudioUrl: '$origin/sigwa-vocal-cry.mp3',
      totalSales: 19,
      createdAt: now.subtract(const Duration(hours: 10)),
      assetCategory: MarketplaceAssetCategory.vocals,
      provenanceType: AudioProvenanceType.liveVocalRecording,
    ),
    BeatListingEntity(
      id: 'inst_maskandi_acoustic_lead',
      title: 'Zululand Maskandi 12-String Lead',
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
      assetCategory: MarketplaceAssetCategory.liveInstruments,
      provenanceType: AudioProvenanceType.liveInstrumentStem,
    ),
    BeatListingEntity(
      id: 'inst_pretoria_jazz_sax',
      title: 'Pretoria Barcadi Tenor Sax Riff',
      producerId: 'creator_djvibe',
      producerName: 'DJ Vibe',
      producerHandle: '@djvibe',
      genre: 'Amapiano',
      bpm: 112,
      musicalKey: 'F# Minor',
      priceInCredits: 4,
      previewAudioUrl: '$origin/pretoria-sax-riff.mp3',
      totalSales: 27,
      createdAt: now.subtract(const Duration(hours: 18)),
      assetCategory: MarketplaceAssetCategory.liveInstruments,
      provenanceType: AudioProvenanceType.liveInstrumentStem,
    ),
    BeatListingEntity(
      id: 'dna_vhu_sig_amapiano_pack',
      title: 'VHU-SIG Amapiano Voice & Percussion DNA Pack',
      producerId: 'creator_lerato',
      producerName: 'Lerato',
      producerHandle: '@lerato_prod',
      genre: 'Amapiano',
      bpm: 114,
      musicalKey: 'E Minor',
      priceInCredits: 8,
      previewAudioUrl: '$origin/vhu-sig-pack.mp3',
      stemZipUrl: '$origin/vhu-sig-pack-stems.zip',
      totalSales: 35,
      createdAt: now.subtract(const Duration(days: 1)),
      assetCategory: MarketplaceAssetCategory.voiceDnaAndPacks,
      provenanceType: AudioProvenanceType.hybridCoCreation,
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

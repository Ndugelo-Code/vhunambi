import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/auth_providers.dart';
import '../../../../core/storage/checkout_write_ahead_journal.dart';
import '../../../../core/sync/sync_outbox_service.dart';
import '../../../../core/utils/creator_id_utils.dart';
import '../../../beats/domain/models/producer_beat_entity.dart';
import '../../../beats/presentation/providers/beats_provider.dart';
import '../../../library/domain/models/library_models.dart';
import '../../../library/presentation/providers/library_providers.dart';
import '../../../notifications/domain/models/notification_entity.dart';
import '../../../notifications/domain/models/notification_enums.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../../offline/presentation/providers/offline_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../social/presentation/providers/creator_wallet_provider.dart';
import '../../data/repositories/license_certificate_repository.dart';
import '../../data/services/beat_delivery_unpacker_service.dart';
import '../../data/services/certificate_share_exporter.dart';
import '../../domain/models/licensing_models.dart';
import '../../domain/models/marketplace_models.dart';
import '../../domain/services/license_agreement_engine.dart';
import '../../domain/services/sovereign_certificate_signer.dart';
import 'marketplace_providers.dart';

final licenseAgreementEngineProvider = Provider<LicenseAgreementEngine>((ref) {
  return const LicenseAgreementEngine();
});

final sovereignCertificateSignerProvider = Provider<SovereignCertificateSigner>(
  (ref) {
    return const SovereignCertificateSigner();
  },
);

final licenseCertificateRepositoryProvider =
    Provider<LicenseCertificateRepository>((ref) {
      ref.watch(currentCreatorIdProvider);
      final repo = LicenseCertificateRepository();
      repo.init();
      return repo;
    });

final beatDeliveryUnpackerProvider = Provider<BeatDeliveryUnpackerService>((
  ref,
) {
  final offlineStorage = ref.watch(offlineStorageServiceProvider);
  return BeatDeliveryUnpackerService(offlineStorage: offlineStorage);
});

final certificateShareExporterProvider = Provider<CertificateShareExporter>((
  ref,
) {
  final offlineStorage = ref.watch(offlineStorageServiceProvider);
  return CertificateShareExporter(offlineStorage: offlineStorage);
});

/// Reactive list of issued cryptographic certificates stored locally.
final licenseCertificatesProvider =
    StateNotifierProvider<
      LicenseCertificatesNotifier,
      List<SovereignLicenseCertificate>
    >((ref) {
      final repo = ref.watch(licenseCertificateRepositoryProvider);
      return LicenseCertificatesNotifier(repo);
    });

class LicenseCertificatesNotifier
    extends StateNotifier<List<SovereignLicenseCertificate>> {
  final LicenseCertificateRepository _repo;

  LicenseCertificatesNotifier(this._repo) : super(_repo.getAllSync());

  Future<void> recordCertificate(SovereignLicenseCertificate cert) async {
    await _repo.save(cert);
    state = [
      cert,
      ...state.where((c) => c.certificateId != cert.certificateId),
    ];
  }

  SovereignLicenseCertificate? findForTrack(LibraryTrack track) {
    final overrideId = track.licenseCertificateIdOverride;
    if (overrideId != null) {
      for (final cert in state) {
        if (cert.certificateId == overrideId) return cert;
      }
    }
    return _repo.findByBeatOrTrackSync(track.id);
  }
}

/// Orchestrates multi-tier checkout, debit, signing, stem unpacking, and rollback.
final beatCheckoutProvider =
    StateNotifierProvider<BeatCheckoutNotifier, BeatCheckoutState>((ref) {
      return BeatCheckoutNotifier(ref);
    });

class BeatCheckoutNotifier extends StateNotifier<BeatCheckoutState> {
  final Ref _ref;

  BeatCheckoutNotifier(this._ref) : super(const BeatCheckoutState());

  void resetForBeat(BeatListingEntity beat) {
    final defaultTier = beat.availableTiers.isNotEmpty
        ? beat.availableTiers.first
        : BeatCheckoutTier.basicMp3;
    state = BeatCheckoutState(
      phase: beat.isExclusiveSold
          ? CheckoutPhase.exclusiveAlreadySold
          : CheckoutPhase.idle,
      selectedTier: defaultTier,
    );
  }

  void selectTier(BeatCheckoutTier tier) {
    state = state.copyWith(
      selectedTier: tier,
      phase: CheckoutPhase.idle,
      deficitCoins: 0,
      deficitZar: 0.0,
      clearError: true,
    );
  }

  Future<CheckoutPhase> purchaseBeat({
    required BeatListingEntity beat,
    BeatCheckoutTier? tierOverride,
  }) async {
    final tier = tierOverride ?? state.selectedTier;
    final engine = _ref.read(licenseAgreementEngineProvider);
    final signer = _ref.read(sovereignCertificateSignerProvider);
    final unpacker = _ref.read(beatDeliveryUnpackerProvider);
    final walletNotifier = _ref.read(creatorWalletProvider.notifier);
    final walletState = _ref.read(creatorWalletProvider);
    final ownerProfile = _ref.read(ownerProfileProvider);

    if (beat.isExclusiveSold) {
      state = state.copyWith(
        phase: CheckoutPhase.exclusiveAlreadySold,
        errorMessage:
            'This beat has already been purchased under an Exclusive license.',
      );
      return state.phase;
    }

    final pricing = engine.calculateTierPricing(
      baseCredits: beat.priceInCredits,
      tier: tier,
    );

    final affordability = engine.evaluateAffordability(
      walletCoins: walletState.userCoinsBalance,
      pricing: pricing,
    );

    if (!affordability.canAfford) {
      state = state.copyWith(
        phase: CheckoutPhase.insufficientFunds,
        selectedTier: tier,
        deficitCoins: affordability.deficitCoins,
        deficitZar: affordability.deficitZar,
        errorMessage:
            'Short by ${affordability.deficitCoins} Coins (R${affordability.deficitZar.toStringAsFixed(2)})',
      );
      return state.phase;
    }

    // Step 1: Atomic Buyer Debit
    state = state.copyWith(
      phase: CheckoutPhase.authorizingDebit,
      selectedTier: tier,
      clearError: true,
      rolledBack: false,
    );

    final debited = walletNotifier.debitForBeatPurchase(
      coins: pricing.grossCoins,
      beatTitle: beat.title,
      tierLabel: tier.displayName,
    );
    if (!debited) {
      state = state.copyWith(
        phase: CheckoutPhase.insufficientFunds,
        deficitCoins:
            pricing.grossCoins -
            _ref.read(creatorWalletProvider).userCoinsBalance,
      );
      return state.phase;
    }

    final creditsLeft =
        _ref.read(creatorWalletProvider).userCoinsBalance ~/ kCoinsPerCredit;
    _ref.read(marketplaceCreditsProvider.notifier).state = creditsLeft;

    var debitedActive = true;
    try {
      // Step 2: Unpack un-tagged 44.1 kHz master + stems
      state = state.copyWith(phase: CheckoutPhase.unpackingMasterAndStems);
      final package = await unpacker.unpackPurchasedBeat(
        beat: beat,
        tier: tier,
      );

      // Step 3: Sign FIPS 180-4 SHA-256 Ownership Deed
      state = state.copyWith(phase: CheckoutPhase.signingCertificate);
      final nowUtc = DateTime.now().toUtc();
      final issuedAtIso = nowUtc.toIso8601String();
      final session = _ref.read(authSessionProvider);
      final buyerId = session.canonicalCreatorId;
      final buyerHandle = ownerProfile.handle.isNotEmpty
          ? ownerProfile.handle
          : session.handle;

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
        masterAudioFilePath: package.masterPath,
        stemPaths: package.stemPaths,
        masterFileSha256: package.masterFileSha256,
      );

      // Step 4: Vault Injection & Offline Cache Registration
      final vaultTrack = LibraryTrack(
        id: vaultTrackId,
        title: beat.title,
        creatorName: beat.producerName,
        genre: beat.genre,
        language: 'Instrumental',
        durationSeconds: beatPreviewDurationSeconds,
        remoteAudioUrl: beat.previewAudioUrl,
        localAudioFilePath: package.masterPath,
        masterAudioFilePath: package.masterPath,
        stemPaths: package.stemPaths,
        createdAt: nowUtc.toLocal(),
        licenseType: tier.displayName,
        licenseTierId: tier.wireSlug,
        licenseCertificateIdOverride: cert.certificateId,
        licenseHash: cert.licenseHash,
        syncStatus: TrackSyncStatus.cachedLocally,
        isInstrumental:
            beat.assetCategory == MarketplaceAssetCategory.beats ||
            beat.assetCategory == MarketplaceAssetCategory.liveInstruments,
      );

      // Step 3.5: Write-Ahead Journal (REQ-P60-UPG-04) before mutating downstream boxes
      final walTxId = 'tx_${beat.id}_${nowUtc.millisecondsSinceEpoch}';
      await CheckoutWriteAheadJournal.prepareCheckout(
        CheckoutWalEntry(
          transactionId: walTxId,
          beatId: beat.id,
          beatTitle: beat.title,
          producerName: beat.producerName,
          licenseTierId: tier.wireSlug,
          coinPrice: pricing.grossCoins,
          certificateJson: jsonEncode(cert.toJson()),
          vaultTrackJson: jsonEncode(vaultTrack.toJson()),
          isExclusive: tier.grantsExclusivity,
          preparedAt: nowUtc,
        ),
      );

      _ref
          .read(libraryTracksProvider.notifier)
          .upsertLicensedTrack(vaultTrack, enqueueOutbox: false);
      await _ref
          .read(offlineStorageServiceProvider)
          .saveTrackMetadata(
            track: vaultTrack,
            localPath: package.masterPath,
            fileSizeBytes: package.totalBytes,
          );
      await _ref
          .read(licenseCertificatesProvider.notifier)
          .recordCertificate(cert);

      // Step 5: Marketplace Sale & Exclusive Buyout Lock
      final marketNotifier = _ref.read(marketplaceBeatsProvider.notifier);
      marketNotifier.registerSale(beat.id);
      if (tier.grantsExclusivity) {
        marketNotifier.markSoldExclusive(beatId: beat.id, buyerId: buyerId);
      }

      final mappedBeatTier = BeatLicenseTier.values.firstWhere(
        (t) => t.name == tier.legacyBeatTierName,
        orElse: () => BeatLicenseTier.nonExclusiveCommercial,
      );
      _ref
          .read(beatsProvider.notifier)
          .recordSale(
            beat.id,
            buyerHandle,
            pricing.producerRoyaltyCoins ~/ kCoinsPerCredit,
            mappedBeatTier,
            markExclusiveBuyerId: tier.grantsExclusivity ? buyerId : null,
          );

      if (beat.producerId == ownerProfile.id ||
          canonicalizeCreatorId(beat.producerId) == buyerId) {
        walletNotifier.recordMarketplaceRoyalty(
          assetTitle: beat.title,
          amountCoins: pricing.producerRoyaltyCoins,
          netZar: pricing.producerRoyaltyZar,
        );
      }

      // Step 5.5: Commit WAL now that Certificate, Vault Track & Exclusive Lock are persisted
      await CheckoutWriteAheadJournal.commitCheckout(walTxId);

      // Step 6: Critical Sync Outbox & Notification
      await _ref
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
          );

      unawaited(
        _ref
            .read(marketplaceRepositoryProvider)
            .licenseBeat(
              beatId: beat.id,
              buyerId: buyerId,
              tier: tier.wireSlug,
            ),
      );

      _ref
          .read(notificationsProvider.notifier)
          .addNotification(
            NotificationEntity(
              id: 'notif_mkt_${nowUtc.millisecondsSinceEpoch}',
              title: 'Marketplace License Acquired!',
              message:
                  'Unlocked "${beat.title}" (${tier.displayName}) — Certificate ${cert.certificateId} & 44.1 kHz assets saved to Vault.',
              category: NotificationCategory.creatorActivity,
              priority: NotificationPriority.high,
              createdAt: nowUtc.toLocal(),
            ),
          );

      debitedActive = false;
      state = state.copyWith(
        phase: CheckoutPhase.completed,
        certificate: cert,
        package: package,
        clearError: true,
        rolledBack: false,
      );
      return state.phase;
    } catch (e) {
      if (debitedActive) {
        walletNotifier.refundCoins(
          coins: pricing.grossCoins,
          reason: 'Asset unpacking interrupted',
        );
        _ref.read(marketplaceCreditsProvider.notifier).state =
            _ref.read(creatorWalletProvider).userCoinsBalance ~/
            kCoinsPerCredit;
      }
      state = state.copyWith(
        phase: CheckoutPhase.failed,
        errorMessage: 'Checkout rolled back safely: $e',
        rolledBack: true,
      );
      return state.phase;
    }
  }
}

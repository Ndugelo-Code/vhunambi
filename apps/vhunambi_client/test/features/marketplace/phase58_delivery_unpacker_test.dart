import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/sync/sync_outbox_service.dart';
import 'package:vhunambi_client/features/library/presentation/providers/library_providers.dart';
import 'package:vhunambi_client/features/marketplace/data/services/beat_delivery_unpacker_service.dart';
import 'package:vhunambi_client/features/marketplace/domain/models/licensing_models.dart';
import 'package:vhunambi_client/features/marketplace/domain/models/marketplace_models.dart';
import 'package:vhunambi_client/features/marketplace/domain/services/sovereign_certificate_signer.dart';
import 'package:vhunambi_client/features/marketplace/presentation/providers/beat_checkout_provider.dart';
import 'package:vhunambi_client/features/marketplace/presentation/providers/marketplace_providers.dart';
import 'package:vhunambi_client/features/offline/data/services/offline_storage_service.dart';
import 'package:vhunambi_client/features/offline/presentation/providers/offline_providers.dart';
import 'package:vhunambi_client/features/profile/presentation/providers/profile_providers.dart';
import 'package:vhunambi_client/features/social/presentation/providers/creator_wallet_provider.dart';

BeatListingEntity _sampleBeat({
  String id = 'beat_township_heat',
  String producerId = 'creator_sipho',
  int priceInCredits = 5,
}) {
  return BeatListingEntity(
    id: id,
    title: 'Township Heat',
    producerId: producerId,
    producerName: 'Sipho',
    producerHandle: '@sipho_beats',
    genre: 'Amapiano',
    bpm: 112,
    musicalKey: 'F# Minor',
    priceInCredits: priceInCredits,
    previewAudioUrl: 'https://cdn.vhunambi.com/beats/township-heat.mp3',
    stemZipUrl: 'https://cdn.vhunambi.com/beats/township-heat-stems.zip',
    totalSales: 18,
    createdAt: DateTime(2026, 11, 9),
  );
}

void _assertValidWav44100(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: 'Expected WAV at $path');
  final bytes = file.readAsBytesSync();
  expect(bytes.length, greaterThan(44));
  expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
  expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
  final data = ByteData.sublistView(bytes);
  expect(data.getUint32(24, Endian.little), 44100);
}

void main() {
  group('Phase 58 Delivery Unpacker, Exporter & Checkout Orchestrator', () {
    late Directory tempDir;
    late OfflineStorageService offlineStorage;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('vhunambi_p58_deliv_');
      offlineStorage = OfflineStorageService(customVaultDirectory: tempDir.path);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('unpacks untagged master and 4 isolated stems at 44.1 kHz RIFF WAV', () async {
      final unpacker = BeatDeliveryUnpackerService(
        offlineStorage: offlineStorage,
        allowNetworkFetch: false,
      );
      final beat = _sampleBeat();

      final basicPkg = await unpacker.unpackPurchasedBeat(
        beat: beat,
        tier: BeatCheckoutTier.basicMp3,
      );
      expect(basicPkg.masterPath.endsWith('untagged_master.wav'), isTrue);
      expect(basicPkg.hasStems, isFalse);
      _assertValidWav44100(basicPkg.masterPath);
      final expectedHash = SovereignCertificateSigner.sha256HexBytes(
        File(basicPkg.masterPath).readAsBytesSync(),
      );
      expect(basicPkg.masterFileSha256, expectedHash);

      final exclPkg = await unpacker.unpackPurchasedBeat(
        beat: beat,
        tier: BeatCheckoutTier.exclusiveStem,
      );
      expect(exclPkg.masterPath.endsWith('master_44k1.wav'), isTrue);
      expect(exclPkg.hasStems, isTrue);
      expect(exclPkg.stemPaths.keys, containsAll(['drums', 'bass', 'melody', 'other']));
      _assertValidWav44100(exclPkg.masterPath);
      for (final stemPath in exclPkg.stemPaths.values) {
        _assertValidWav44100(stemPath);
      }
    });

    test('BeatCheckoutNotifier completes exclusive checkout, writes Vault + Outbox, and hides beat', () async {
      final outbox = SyncOutboxService(isInMemoryOnly: true);
      final container = ProviderContainer(
        overrides: [
          offlineStorageServiceProvider.overrideWithValue(offlineStorage),
          syncOutboxServiceProvider.overrideWithValue(outbox),
        ],
      );
      addTearDown(container.dispose);

      final beat = container.read(marketplaceBeatsProvider).first;
      expect(container.read(creatorWalletProvider).userCoinsBalance, 250);
      final initialOwnerZar =
          container.read(creatorWalletProvider).creatorEarnedZar;

      final phase = await container.read(beatCheckoutProvider.notifier).purchaseBeat(
            beat: beat,
            tierOverride: BeatCheckoutTier.exclusiveStem,
          );

      expect(phase, CheckoutPhase.completed);
      final checkoutState = container.read(beatCheckoutProvider);
      final cert = checkoutState.certificate!;
      expect(checkoutState.rolledBack, isFalse);
      expect(cert.tier, BeatCheckoutTier.exclusiveStem);
      expect(cert.amountPaidCoins, 150);

      // Buyer wallet debited 250 -> 100; non-owned beat didn't credit buyer's creatorEarnedZar
      final wallet = container.read(creatorWalletProvider);
      expect(wallet.userCoinsBalance, 100);
      expect(wallet.creatorEarnedZar, initialOwnerZar);

      // Library track upserted with real WAV master & 4 stems
      final track = container
          .read(libraryTracksProvider)
          .firstWhere((t) => t.id == 'market_${beat.id}');
      expect(track.isOfflineAvailable, isTrue);
      expect(track.hasUnpackedStems, isTrue);
      expect(track.licenseCertificateId, cert.certificateId);
      _assertValidWav44100(track.effectiveAudioPath!);

      // Critical SyncOutbox enqueued
      final pending = outbox.getPendingMutations();
      expect(pending.length, 1);
      expect(pending.first.entityType, 'beat_license');
      expect(pending.first.priority, SyncPriority.critical);

      // Certificate exporter writes deed files cleanly
      final exported = await container
          .read(certificateShareExporterProvider)
          .exportDeedFiles(cert);
      expect(File(exported.jsonPath).existsSync(), isTrue);
      expect(File(exported.textPath).readAsStringSync(), contains(cert.licenseHash));

      // Exclusive buyout removed beat from filtered public marketplace list
      final visible = container.read(filteredBeatsProvider);
      expect(visible.any((b) => b.id == beat.id), isFalse);
    });

    test('credits producer royalties conditionally only when beat.producerId matches owner', () async {
      final outbox = SyncOutboxService(isInMemoryOnly: true);
      final container = ProviderContainer(
        overrides: [
          offlineStorageServiceProvider.overrideWithValue(offlineStorage),
          syncOutboxServiceProvider.overrideWithValue(outbox),
        ],
      );
      addTearDown(container.dispose);

      final ownerId = container.read(ownerProfileProvider).id;
      final selfBeat = _sampleBeat(id: 'beat_self_owned', producerId: ownerId);
      final beforeZar = container.read(creatorWalletProvider).creatorEarnedZar;

      final phase = await container.read(beatCheckoutProvider.notifier).purchaseBeat(
            beat: selfBeat,
            tierOverride: BeatCheckoutTier.basicMp3,
          );
      expect(phase, CheckoutPhase.completed);
      expect(
        container.read(creatorWalletProvider).creatorEarnedZar,
        greaterThan(beforeZar),
      );
    });

    test('rolls back Coins cleanly when file unpacking throws an IO exception', () async {
      final failingUnpacker = BeatDeliveryUnpackerService(
        offlineStorage: offlineStorage,
        allowNetworkFetch: false,
        fileWriter: (_, _) async => throw const FileSystemException('Disk full'),
      );
      final outbox = SyncOutboxService(isInMemoryOnly: true);
      final container = ProviderContainer(
        overrides: [
          offlineStorageServiceProvider.overrideWithValue(offlineStorage),
          beatDeliveryUnpackerProvider.overrideWithValue(failingUnpacker),
          syncOutboxServiceProvider.overrideWithValue(outbox),
        ],
      );
      addTearDown(container.dispose);

      final beat = _sampleBeat(id: 'beat_fail_rollback');
      final phase = await container.read(beatCheckoutProvider.notifier).purchaseBeat(
            beat: beat,
            tierOverride: BeatCheckoutTier.premiumWav,
          );

      expect(phase, CheckoutPhase.failed);
      expect(container.read(beatCheckoutProvider).rolledBack, isTrue);
      expect(container.read(creatorWalletProvider).userCoinsBalance, 250);
      expect(outbox.getPendingMutations(), isEmpty);
    });
  });
}


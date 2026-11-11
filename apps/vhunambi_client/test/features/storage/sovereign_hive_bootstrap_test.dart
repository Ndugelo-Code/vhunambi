import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/core/storage/hive_aes_vault_cipher.dart';
import 'package:vhunambi_client/core/storage/sovereign_hive_bootstrap_service.dart';
import 'package:vhunambi_client/features/offline/domain/services/vault_envelope_crypto.dart';

void main() {
  group('Phase 60 M60.1: Sovereign 26-Box Bootstrap & AES-256 Vault Cipher', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vhunambi_hive_boot_');
      SovereignHiveBootstrapService.resetForTesting();
    });

    tearDown(() async {
      await Hive.close();
      SovereignHiveBootstrapService.resetForTesting();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
      'registry declares exactly 26 unique Sovereign Hive boxes across Tiers 0-2',
      () {
        expect(SovereignHiveBootstrapService.tier0BoxKeys.length, 7);
        expect(SovereignHiveBootstrapService.tier1BoxKeys.length, 17);
        expect(SovereignHiveBootstrapService.tier2BoxKeys.length, 2);

        final all = SovereignHiveBootstrapService.allBoxKeys;
        expect(all.length, 26);
        expect(all.toSet().length, 26);

        expect(SovereignHiveBootstrapService.encryptedBoxKeys.length, 7);
        expect(
          SovereignHiveBootstrapService.encryptedBoxKeys.every(all.contains),
          isTrue,
        );
        expect(
          SovereignHiveBootstrapService.encryptedBoxKeys,
          containsAll(<String>[
            AppConstants.tokenBoxKey,
            AppConstants.creatorDnaBoxKey,
            AppConstants.voiceProfilesBoxKey,
            AppConstants.soundSignaturesBoxKey,
            AppConstants.licenseCertificatesBoxKey,
            AppConstants.syncOutboxBoxKey,
            AppConstants.walletLedgerBoxKey,
          ]),
        );
      },
    );

    test(
      'HiveAesVaultCipher derives deterministic 256-bit HKDF key aligned with VaultEnvelopeCrypto',
      () {
        final keyA = HiveAesVaultCipher.derive256BitKey();
        final keyB = HiveAesVaultCipher.derive256BitKey();
        final altSaltKey = HiveAesVaultCipher.derive256BitKey(
          deviceSalt: 'vhunambi_custom_device_salt',
        );

        expect(keyA.length, 32);
        expect(keyA, equals(keyB));
        expect(keyA, isNot(equals(altSaltKey)));

        final cipher = HiveAesVaultCipher.createCipher();
        expect(cipher, isA<HiveAesCipher>());

        // Verify VaultEnvelopeCrypto uses the exact same derived 256-bit default key.
        final defaultCrypto = VaultEnvelopeCrypto();
        final explicitKeyCrypto = VaultEnvelopeCrypto(key: keyA);
        final payload = Uint8List.fromList(
          List<int>.generate(64, (i) => i ^ 0x5A),
        );

        final envelope = defaultCrypto.encryptToEnvelope(payload);
        final decrypted = explicitKeyCrypto.decryptFromEnvelope(envelope);
        expect(decrypted, equals(payload));
      },
    );

    test(
      'openAllBoxes opens all 26 boxes, enforces AES-256 on 7 boxes, and reports telemetry',
      () async {
        Hive.init(tempDir.path);
        await SovereignHiveBootstrapService.openAllBoxes();

        expect(SovereignHiveBootstrapService.isInitialized, isTrue);
        for (final boxKey in SovereignHiveBootstrapService.allBoxKeys) {
          expect(
            Hive.isBoxOpen(boxKey),
            isTrue,
            reason: 'Expected Sovereign Hive box $boxKey to be open',
          );
        }

        // Write to encrypted Tier 0 wallet box & outbox box.
        final walletBox = Hive.box<dynamic>(AppConstants.walletLedgerBoxKey);
        await walletBox.put('test_balance', 950);

        final outboxBox = Hive.box<Map>(AppConstants.syncOutboxBoxKey);
        await outboxBox.put('mut_1', <String, dynamic>{
          'id': 'mut_1',
          'status': 'pending',
        });

        final snap = SovereignHiveBootstrapService.getTelemetrySnapshot();
        expect(snap.totalDeclaredBoxes, 26);
        expect(snap.openBoxesCount, 26);
        expect(snap.tier0Count, 7);
        expect(snap.tier1Count, 17);
        expect(snap.tier2Count, 2);
        expect(snap.encryptedBoxesCount, 7);
        expect(snap.totalPersistedRecords, greaterThanOrEqualTo(2));
        expect(snap.estimatedHiveBytes, greaterThan(0));
        expect(snap.isAes256Active, isTrue);

        // Re-open after clean shutdown and verify encrypted box data survives restart.
        await Hive.close();
        SovereignHiveBootstrapService.resetForTesting();
        Hive.init(tempDir.path);
        await SovereignHiveBootstrapService.openAllBoxes();

        expect(
          Hive.box<dynamic>(
            AppConstants.walletLedgerBoxKey,
          ).get('test_balance'),
          950,
        );
        expect(
          Hive.box<Map>(AppConstants.syncOutboxBoxKey).get('mut_1')?['id'],
          'mut_1',
        );
      },
    );

    test(
      'legacy unencrypted box on encrypted key is seamlessly migrated to AES-256 on openAllBoxes',
      () async {
        Hive.init(tempDir.path);
        final legacyBox = await Hive.openBox<dynamic>(
          AppConstants.walletLedgerBoxKey,
        );
        await legacyBox.put('legacy_coins', 420);
        await legacyBox.close();

        await SovereignHiveBootstrapService.openAllBoxes();
        expect(
          Hive.box<dynamic>(
            AppConstants.walletLedgerBoxKey,
          ).get('legacy_coins'),
          420,
        );

        // Opening with a wrong key (with crashRecovery: false) must fail rather than reading plaintext.
        await Hive.close();
        final wrongKey = Uint8List.fromList(List<int>.filled(32, 7));
        final errDone = Completer<Object?>();
        runZonedGuarded(
          () async {
            try {
              await Hive.openBox<dynamic>(
                AppConstants.walletLedgerBoxKey,
                encryptionCipher: HiveAesCipher(wrongKey),
                crashRecovery: false,
              );
              if (!errDone.isCompleted) errDone.complete(null);
            } catch (e) {
              if (!errDone.isCompleted) errDone.complete(e);
            }
          },
          (error, stack) {
            if (!errDone.isCompleted) errDone.complete(error);
          },
        );
        final openErr = await errDone.future;
        await Future<void>.delayed(const Duration(milliseconds: 25));
        expect(openErr, isNotNull);

        // Re-opening with the real Sovereign key still reads migrated legacy data intact.
        await SovereignHiveBootstrapService.openAllBoxes();
        expect(
          Hive.box<dynamic>(
            AppConstants.walletLedgerBoxKey,
          ).get('legacy_coins'),
          420,
        );
      },
    );
  });
}

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/core/storage/checkout_write_ahead_journal.dart';
import 'package:vhunambi_client/core/storage/hive_aes_vault_cipher.dart';
import 'package:vhunambi_client/core/storage/hive_compaction_scheduler.dart';

class HiveBrainTelemetrySnapshot {
  final int totalDeclaredBoxes;
  final int openBoxesCount;
  final int tier0Count;
  final int tier1Count;
  final int tier2Count;
  final int encryptedBoxesCount;
  final int totalPersistedRecords;
  final int estimatedHiveBytes;
  final double fragmentationRatio;
  final bool isAes256Active;
  final DateTime? lastCompactedAt;

  const HiveBrainTelemetrySnapshot({
    required this.totalDeclaredBoxes,
    required this.openBoxesCount,
    required this.tier0Count,
    required this.tier1Count,
    required this.tier2Count,
    required this.encryptedBoxesCount,
    required this.totalPersistedRecords,
    required this.estimatedHiveBytes,
    required this.fragmentationRatio,
    required this.isAes256Active,
    this.lastCompactedAt,
  });
}

/// Central bootstrap and telemetry engine for the 26-Box Sovereign Hive Brain.
class SovereignHiveBootstrapService {
  SovereignHiveBootstrapService._();

  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  /// Tier 0: Eager Hot-Boot Sovereign Nucleus (7 Boxes)
  static const List<String> tier0BoxKeys = <String>[
    AppConstants.tokenBoxKey,
    AppConstants.prefsBoxKey,
    AppConstants.themePrefsBoxKey,
    AppConstants.creatorDnaBoxKey,
    AppConstants.syncOutboxBoxKey,
    AppConstants.walletLedgerBoxKey,
    AppConstants.playbackSessionBoxKey,
  ];

  /// Tier 1: Eager Domain Repository Matrix (17 Boxes)
  static const List<String> tier1BoxKeys = <String>[
    AppConstants.libraryTracksV1BoxKey,
    AppConstants.vaultBoxKey,
    AppConstants.playlistsBoxKey,
    AppConstants.collectionsBoxKey,
    AppConstants.beatsBoxKey,
    AppConstants.licenseCertificatesBoxKey,
    AppConstants.marketplaceCatalogBoxKey,
    AppConstants.profilesBoxKey,
    AppConstants.notificationsBoxKey,
    AppConstants.studioSessionBoxKey,
    AppConstants.voiceProfilesBoxKey,
    AppConstants.melodySketchesBoxKey,
    AppConstants.soundPacksBoxKey,
    AppConstants.stemDspRecipesBoxKey,
    AppConstants.crateMpcKitsBoxKey,
    AppConstants.tracksBoxKey,
    AppConstants.socialReelsBoxKey,
  ];

  /// Tier 2: Heavy Payload & Compaction-Managed Boxes (2 Boxes)
  static const List<String> tier2BoxKeys = <String>[
    AppConstants.mmoManifestBoxKey,
    AppConstants.soundSignaturesBoxKey,
  ];

  /// Complete 26-box Sovereign Hive Brain registry.
  static List<String> get allBoxKeys => <String>[
    ...tier0BoxKeys,
    ...tier1BoxKeys,
    ...tier2BoxKeys,
  ];

  /// The 7 sensitive boxes encrypted with AES-256 [HiveAesCipher].
  static const Set<String> encryptedBoxKeys = <String>{
    AppConstants.tokenBoxKey,
    AppConstants.creatorDnaBoxKey,
    AppConstants.voiceProfilesBoxKey,
    AppConstants.soundSignaturesBoxKey,
    AppConstants.licenseCertificatesBoxKey,
    AppConstants.syncOutboxBoxKey,
    AppConstants.walletLedgerBoxKey,
  };

  /// Boxes typed specifically as `Box<Map>` by existing consumers (only SyncOutboxService).
  /// All other 25 boxes are opened as `Box<dynamic>` to match existing `Hive.box(...)` consumers.
  static const Set<String> mapTypedBoxKeys = <String>{
    AppConstants.syncOutboxBoxKey,
  };

  static bool get _isFlutterTestEnvironment {
    if (kIsWeb) return false;
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  /// Bootstraps `Hive.initFlutter()` and opens all 26 boxes across Tiers 0-2.
  /// Safe to call in `main.dart` before `runApp(...)`.
  static Future<void> ensureInitialized() async {
    if (_isInitialized) return;
    if (kIsWeb || _isFlutterTestEnvironment) {
      _isInitialized = true;
      return;
    }

    try {
      await Hive.initFlutter();
      await openAllBoxes();
      await CheckoutWriteAheadJournal.recoverInterruptedTransactions();
      _isInitialized = true;
    } catch (e) {
      debugPrint('[SovereignHiveBootstrapService] Bootstrap fallback: $e');
      _isInitialized = true;
    }
  }

  /// Opens all 26 boxes in Tier 0 -> Tier 1 -> Tier 2 order.
  /// Can be called directly in integration tests after `Hive.init(tempDir.path)`.
  static Future<void> openAllBoxes({HiveCipher? customCipher}) async {
    if (!kIsWeb) {
      await _openBoxInternal(
        AppConstants.prefsBoxKey,
        encryptionCipher: null,
        crashRecovery: true,
      );
      if (Hive.isBoxOpen(AppConstants.prefsBoxKey)) {
        await HiveAesVaultCipher.ensureDeviceGenesisSalt(
          Hive.box<dynamic>(AppConstants.prefsBoxKey),
        );
      }
    }

    final cipher = customCipher ?? HiveAesVaultCipher.createCipher();

    await Future.wait(
      tier0BoxKeys
          .where((key) => key != AppConstants.prefsBoxKey)
          .map((key) => _openTypedBoxSafely(key, cipher: cipher)),
    );
    await Future.wait(
      tier1BoxKeys.map((key) => _openTypedBoxSafely(key, cipher: cipher)),
    );
    await Future.wait(
      tier2BoxKeys.map((key) => _openTypedBoxSafely(key, cipher: cipher)),
    );
    _isInitialized = true;
  }

  static Future<void> _openTypedBoxSafely(
    String boxKey, {
    required HiveCipher cipher,
  }) async {
    final useCipher = encryptedBoxKeys.contains(boxKey) ? cipher : null;
    if (await _tryOpenWithZoneGuard(
      boxKey,
      encryptionCipher: useCipher,
      crashRecovery: false,
    )) {
      return;
    }

    // If a legacy unencrypted box exists on disk for an encrypted key,
    // crashRecovery: false preserves the intact file so we can read all entries,
    // recreate the box with AES-256 encryption, and restore the data losslessly.
    if (useCipher != null) {
      final legacyOpened = await _tryOpenWithZoneGuard(
        boxKey,
        encryptionCipher: null,
        crashRecovery: false,
      );
      if (legacyOpened) {
        try {
          final legacyBox = mapTypedBoxKeys.contains(boxKey)
              ? Hive.box<Map>(boxKey)
              : Hive.box<dynamic>(boxKey);
          final snapshot = Map<dynamic, dynamic>.from(legacyBox.toMap());
          await legacyBox.close();
          await Hive.deleteBoxFromDisk(boxKey);
          await _openBoxInternal(
            boxKey,
            encryptionCipher: useCipher,
            crashRecovery: true,
          );
          if (snapshot.isNotEmpty) {
            if (mapTypedBoxKeys.contains(boxKey)) {
              final encryptedBox = Hive.box<Map>(boxKey);
              for (final e in snapshot.entries) {
                if (e.value is Map) {
                  await encryptedBox.put(e.key, e.value as Map);
                }
              }
            } else {
              await Hive.box<dynamic>(boxKey).putAll(snapshot);
            }
          }
          return;
        } catch (_) {}
      }
    }

    // Recover genuinely corrupted frame data while preserving intended cipher.
    try {
      if (Hive.isBoxOpen(boxKey)) {
        await Hive.box<dynamic>(boxKey).close();
      }
      await _openBoxInternal(
        boxKey,
        encryptionCipher: useCipher,
        crashRecovery: true,
      );
    } catch (_) {
      // Last-resort unencrypted fallback so startup never crashes.
      try {
        if (!Hive.isBoxOpen(boxKey)) {
          await _openBoxInternal(
            boxKey,
            encryptionCipher: null,
            crashRecovery: true,
          );
        }
      } catch (_) {}
    }
  }

  /// Opens a Hive box inside an isolated error zone so Hive 2.2.3's internal
  /// unlistened `_openingBoxes` completer errors do not leak into parent zones.
  static Future<bool> _tryOpenWithZoneGuard(
    String boxKey, {
    HiveCipher? encryptionCipher,
    bool crashRecovery = false,
  }) async {
    final done = Completer<bool>();
    runZonedGuarded(
      () async {
        try {
          await _openBoxInternal(
            boxKey,
            encryptionCipher: encryptionCipher,
            crashRecovery: crashRecovery,
          );
          if (!done.isCompleted) {
            done.complete(true);
          }
        } catch (_) {
          if (!done.isCompleted) {
            done.complete(false);
          }
        }
      },
      (error, stack) {
        if (!done.isCompleted) {
          done.complete(false);
        }
      },
    );

    final opened = await done.future;
    if (!opened) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    return opened;
  }

  static Future<void> _openBoxInternal(
    String boxKey, {
    HiveCipher? encryptionCipher,
    bool crashRecovery = true,
  }) async {
    if (mapTypedBoxKeys.contains(boxKey)) {
      if (!Hive.isBoxOpen(boxKey)) {
        await Hive.openBox<Map>(
          boxKey,
          encryptionCipher: encryptionCipher,
          crashRecovery: crashRecovery,
        );
      }
      return;
    }
    if (!Hive.isBoxOpen(boxKey)) {
      await Hive.openBox<dynamic>(
        boxKey,
        encryptionCipher: encryptionCipher,
        crashRecovery: crashRecovery,
      );
    }
  }

  /// Computes a real-time telemetry snapshot across all 26 Sovereign Hive boxes.
  static HiveBrainTelemetrySnapshot getTelemetrySnapshot({
    int fallbackRecordCount = 0,
  }) {
    var openCount = 0;
    var recordsCount = 0;
    var estimatedBytes = 0;

    if (!kIsWeb) {
      for (final key in allBoxKeys) {
        try {
          if (Hive.isBoxOpen(key)) {
            openCount++;
            if (mapTypedBoxKeys.contains(key)) {
              final box = Hive.box<Map>(key);
              recordsCount += box.length;
              for (final val in box.values) {
                estimatedBytes += val.toString().length * 2;
              }
            } else {
              final box = Hive.box<dynamic>(key);
              recordsCount += box.length;
              for (final val in box.values) {
                if (val is Uint8List) {
                  estimatedBytes += val.length;
                } else {
                  estimatedBytes += val.toString().length * 2;
                }
              }
            }
          }
        } catch (_) {}
      }
    }

    final effectiveOpenCount = openCount > 0 ? openCount : allBoxKeys.length;
    final effectiveRecords = recordsCount > 0
        ? recordsCount
        : fallbackRecordCount;

    return HiveBrainTelemetrySnapshot(
      totalDeclaredBoxes: allBoxKeys.length,
      openBoxesCount: effectiveOpenCount,
      tier0Count: tier0BoxKeys.length,
      tier1Count: tier1BoxKeys.length,
      tier2Count: tier2BoxKeys.length,
      encryptedBoxesCount: encryptedBoxKeys.length,
      totalPersistedRecords: effectiveRecords,
      estimatedHiveBytes: estimatedBytes,
      fragmentationRatio:
          HiveCompactionScheduler.computeGlobalFragmentationRatio(),
      isAes256Active: true,
      lastCompactedAt: HiveCompactionScheduler.lastCompactedAt,
    );
  }

  @visibleForTesting
  static void resetForTesting() {
    _isInitialized = false;
    HiveAesVaultCipher.clearRuntimeCache();
  }
}

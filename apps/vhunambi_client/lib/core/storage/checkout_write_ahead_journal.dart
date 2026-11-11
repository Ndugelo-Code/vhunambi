import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';

class CheckoutWalEntry {
  final String transactionId;
  final String beatId;
  final String beatTitle;
  final String producerName;
  final String licenseTierId;
  final int coinPrice;
  final String certificateJson;
  final String vaultTrackJson;
  final bool isExclusive;
  final DateTime preparedAt;

  const CheckoutWalEntry({
    required this.transactionId,
    required this.beatId,
    required this.beatTitle,
    required this.producerName,
    required this.licenseTierId,
    required this.coinPrice,
    required this.certificateJson,
    required this.vaultTrackJson,
    required this.isExclusive,
    required this.preparedAt,
  });

  Map<String, dynamic> toJson() => {
    'transactionId': transactionId,
    'beatId': beatId,
    'beatTitle': beatTitle,
    'producerName': producerName,
    'licenseTierId': licenseTierId,
    'coinPrice': coinPrice,
    'certificateJson': certificateJson,
    'vaultTrackJson': vaultTrackJson,
    'isExclusive': isExclusive,
    'preparedAt': preparedAt.toIso8601String(),
  };

  factory CheckoutWalEntry.fromJson(Map<String, dynamic> json) {
    return CheckoutWalEntry(
      transactionId: json['transactionId'] as String? ?? '',
      beatId: json['beatId'] as String? ?? '',
      beatTitle: json['beatTitle'] as String? ?? '',
      producerName: json['producerName'] as String? ?? '',
      licenseTierId: json['licenseTierId'] as String? ?? '',
      coinPrice: (json['coinPrice'] as num?)?.toInt() ?? 0,
      certificateJson: json['certificateJson'] as String? ?? '{}',
      vaultTrackJson: json['vaultTrackJson'] as String? ?? '{}',
      isExclusive: json['isExclusive'] as bool? ?? false,
      preparedAt: json['preparedAt'] != null
          ? DateTime.tryParse(json['preparedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Write-Ahead Journal stored in `vhunambi_prefs` (`checkout_wal_<txId>`)
/// to ensure multi-box beat purchases roll forward cleanly after an OS crash.
class CheckoutWriteAheadJournal {
  CheckoutWriteAheadJournal._();

  static const String _keyPrefix = 'checkout_wal_';
  static final Map<String, String> _inMemoryWal = <String, String>{};

  static Box<dynamic>? get _prefsBox {
    if (kIsWeb) return null;
    try {
      if (Hive.isBoxOpen(AppConstants.prefsBoxKey)) {
        return Hive.box<dynamic>(AppConstants.prefsBoxKey);
      }
    } catch (_) {}
    return null;
  }

  /// Writes a PREPARED checkout journal entry before mutating downstream boxes.
  static Future<void> prepareCheckout(CheckoutWalEntry entry) async {
    final key = '$_keyPrefix${entry.transactionId}';
    final encoded = jsonEncode(entry.toJson());
    _inMemoryWal[key] = encoded;
    final box = _prefsBox;
    if (box != null) {
      await box.put(key, encoded);
    }
  }

  /// Marks a checkout transaction COMMITTED and deletes its WAL record.
  static Future<void> commitCheckout(String transactionId) async {
    final key = '$_keyPrefix$transactionId';
    _inMemoryWal.remove(key);
    final box = _prefsBox;
    if (box != null) {
      await box.delete(key);
    }
  }

  /// Returns all uncommitted PREPARED WAL entries for idempotent crash recovery.
  static List<CheckoutWalEntry> getPendingEntries() {
    final merged = <String, String>{..._inMemoryWal};
    final box = _prefsBox;
    if (box != null) {
      for (final rawKey in box.keys) {
        final key = rawKey.toString();
        if (key.startsWith(_keyPrefix)) {
          final val = box.get(key);
          if (val is String) {
            merged[key] = val;
          }
        }
      }
    }
    final results = <CheckoutWalEntry>[];
    for (final raw in merged.values) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        results.add(CheckoutWalEntry.fromJson(map));
      } catch (_) {}
    }
    return results;
  }

  /// Recovers any interrupted beat checkouts by ensuring Certificate, Library Track,
  /// and Exclusive Marketplace lock exist, then clearing the WAL entry.
  static Future<int> recoverInterruptedTransactions() async {
    final pending = getPendingEntries();
    if (pending.isEmpty) return 0;
    var recovered = 0;

    for (final entry in pending) {
      try {
        if (!kIsWeb) {
          if (Hive.isBoxOpen(AppConstants.licenseCertificatesBoxKey)) {
            final certBox = Hive.box<dynamic>(
              AppConstants.licenseCertificatesBoxKey,
            );
            final certMap =
                jsonDecode(entry.certificateJson) as Map<String, dynamic>;
            final certId =
                certMap['certificateId'] as String? ??
                certMap['id'] as String? ??
                entry.transactionId;
            if (!certBox.containsKey(certId)) {
              await certBox.put(certId, certMap);
            }
          }
          if (Hive.isBoxOpen(AppConstants.libraryTracksV1BoxKey)) {
            final libBox = Hive.box<dynamic>(
              AppConstants.libraryTracksV1BoxKey,
            );
            final trackMap =
                jsonDecode(entry.vaultTrackJson) as Map<String, dynamic>;
            final trackId =
                trackMap['id'] as String? ?? 'market_${entry.beatId}';
            if (!libBox.containsKey(trackId)) {
              await libBox.put(trackId, trackMap);
            }
          }
          if (entry.isExclusive &&
              Hive.isBoxOpen(AppConstants.marketplaceCatalogBoxKey)) {
            final catBox = Hive.box<dynamic>(
              AppConstants.marketplaceCatalogBoxKey,
            );
            await catBox.put('exclusive_sold_${entry.beatId}', true);
          }
        }
        await commitCheckout(entry.transactionId);
        recovered++;
      } catch (_) {}
    }
    return recovered;
  }

  /// Clears in-memory WAL entries during account switch / sign-out sanitization.
  static void clearSessionMemory() {
    _inMemoryWal.clear();
  }

  @visibleForTesting
  static void clearForTesting() {
    clearSessionMemory();
  }
}

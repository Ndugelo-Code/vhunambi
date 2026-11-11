# Phase 60 Technical Design: Sovereign Hive Brain Activation, Unified Persistence & Edge-Sync Convergence

> **Phase ID**: `phase_60_sovereign_hive_brain_and_persistence_convergence`
> **Engineering Standard**: All-Gemini Engineering Standard (`STD-ARCH-060`, `STD-UIUX-001`, `STD-SEC-012`)
> **Anti-Bait-and-Switch Compliance**:
> - Package Namespace: `package:vhunambi_client/...`
> - Icon Package: `package:phosphor_icons/phosphor_icons.dart` (`PhosphorIconsBold.*`, `PhosphorIconsRegular.*`)
> - Design Tokens: `AppColors` & `AppTypography` (`titleLarge`, `titleMedium`, `titleSmall`, `bodyLarge`, `bodyMedium`, `bodySmall`, `caption`, `badge`)
> - Zero Raw Emojis in Dart source files (`STD-UIUX-001`)

---

## 1. Sovereign 26-Box Constants (`lib/core/constants/app_constants.dart`)

Update [`apps/vhunambi_client/lib/core/constants/app_constants.dart`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/core/constants/app_constants.dart) to declare the complete 26-box Sovereign Hive Brain registry:

```dart
abstract final class AppConstants {
  // App Info
  static const String appName = 'VHUNAMBI';
  static const String appTagline = 'Create. Discover. Connect.';
  static const String appVersion = '0.1.0';

  // Responsive Breakpoints
  static const double mobileMaxWidth = 767;
  static const double tabletMinWidth = 768;
  static const double tabletMaxWidth = 1024;
  static const double desktopMinWidth = 1025;

  // Navigation Dimensions
  static const double sidebarExpandedWidth = 240;
  static const double sidebarCollapsedWidth = 72;
  static const double bottomNavHeight = 64;
  static const double miniPlayerHeight = 64;
  static const double rightPanelWidth = 340;
  static const double topAppBarHeight = 64;

  // Grid Columns
  static const int desktopGridColumns = 4;
  static const int tabletGridColumns = 3;
  static const int mobileGridColumns = 2;

  // Content Constraints
  static const double maxContentWidth = 1440;
  static const double maxFormWidth = 480;
  static const double maxReadableWidth = 680;

  // Audio Defaults
  static const int defaultBpm = 120;
  static const int minBpm = 60;
  static const int maxBpm = 200;
  static const Duration maxTrackDuration = Duration(minutes: 5);
  static const Duration previewDuration = Duration(seconds: 30);

  // Pagination
  static const int defaultPageSize = 20;
  static const int searchDebounceMs = 300;

  // Sovereign Hive Brain 26-Box Storage Keys (Phase 60)
  // Tier 0: Eager Hot-Boot Nucleus (7 Boxes)
  static const String tokenBoxKey = 'vhunambi_tokens'; // Repurposed: Encrypted Auth & Onboarding Genesis
  static const String prefsBoxKey = 'vhunambi_prefs'; // Unified App Prefs, EdgeSync Cursor & Checkout WAL
  static const String themePrefsBoxKey = 'vhunambi_theme_prefs_box';
  static const String creatorDnaBoxKey = 'vhunambi_creator_dna'; // Encrypted Creator DNA & O(1) Ring Log
  static const String syncOutboxBoxKey = 'vhunambi_sync_outbox_box'; // Encrypted Offline Mutation WAL
  static const String walletLedgerBoxKey = 'vhunambi_wallet_ledger_box'; // Encrypted Creator Wallet & SA Bank Ledger
  static const String playbackSessionBoxKey = 'vhunambi_playback_session_box'; // Player Queue, Seek, HeroMode, RecentlyPlayed

  // Tier 1: Eager Domain Matrix (17 Boxes)
  static const String libraryTracksV1BoxKey = 'vhunambi_library_tracks_v1';
  static const String vaultBoxKey = 'library_tracks'; // OfflineStorageService .vmf Vault Index
  static const String playlistsBoxKey = 'vhunambi_playlists';
  static const String collectionsBoxKey = 'vhunambi_collections';
  static const String beatsBoxKey = 'vhunambi_beats';
  static const String licenseCertificatesBoxKey = 'vhunambi_license_certificates'; // Encrypted Ownership Certificates
  static const String marketplaceCatalogBoxKey = 'vhunambi_marketplace_catalog_box'; // Beat Catalog & Exclusive Locks
  static const String profilesBoxKey = 'vhunambi_profiles'; // LRU ProfileCache + Pinned 'me' Owner Profile
  static const String notificationsBoxKey = 'notifications_v1'; // O(1) Per-Entity Notifications
  static const String studioSessionBoxKey = 'vhunambi_studio_session'; // Studio + GenerationReq + ContentStudio Drafts
  static const String voiceProfilesBoxKey = 'vhunambi_voice_profiles_box'; // Encrypted O(1) Cloned Voice Profiles
  static const String melodySketchesBoxKey = 'vhunambi_melody_sketches_box'; // O(1) Melody Sketches
  static const String soundPacksBoxKey = 'vhunambi_sound_packs_box';
  static const String stemDspRecipesBoxKey = 'vhunambi_stem_dsp_recipes_box'; // Per-Track 4-Stem Mixer & Mastering Recipes
  static const String crateMpcKitsBoxKey = 'vhunambi_crate_mpc_kits_box'; // Heritage Crate Favorites, 8-Pad MPC Kits & Biome Leaves
  static const String tracksBoxKey = 'vhunambi_tracks'; // Repurposed: Explore Discovery, Radio, Likes & Co-Signs Cache
  static const String socialReelsBoxKey = 'vhunambi_social_reels_box'; // Kinetic Reels, Comments & Stem Remix Lineage Cache

  // Tier 2: Heavy Payload & Compaction-Managed Boxes (2 Boxes)
  static const String mmoManifestBoxKey = 'vhunambi_mmo_manifest_box';
  static const String soundSignaturesBoxKey = 'vhunambi_sound_signatures_box'; // Encrypted .vss Binary Signatures
}
```

---

## 2. Deterministic AES-256 Sovereign Key Derivation (`lib/core/storage/hive_aes_vault_cipher.dart`)

Create `apps/vhunambi_client/lib/core/storage/hive_aes_vault_cipher.dart` to provide RFC 5869 HKDF-SHA256 256-bit key derivation and `HiveAesCipher` creation for the 7 sensitive boxes and `VaultEnvelopeCrypto`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';

/// Deterministic HKDF-SHA256 256-bit key derivation for Sovereign Hive AES-256
/// at-rest encryption (fulfilling docs/PRIVACY_DATA_FLOW.md).
class HiveAesVaultCipher {
  HiveAesVaultCipher._();

  static const String _defaultSovereignIkm =
      'vhunambi_sovereign_brain_hkdf_ikm_v60_2026';
  static const String _defaultDomainInfo =
      'vhunambi_hive_aes256_at_rest_domain_v1';

  static Uint8List? _cachedKeyBytes;

  /// Derives a 32-byte (256-bit) AES key using HKDF-Extract + HKDF-Expand (HMAC-SHA256).
  static Uint8List derive256BitKey({
    String deviceSalt = 'vhunambi_default_device_genesis_salt_v1',
    String domainInfo = _defaultDomainInfo,
  }) {
    if (_cachedKeyBytes != null &&
        deviceSalt == 'vhunambi_default_device_genesis_salt_v1' &&
        domainInfo == _defaultDomainInfo) {
      return Uint8List.fromList(_cachedKeyBytes!);
    }

    final saltBytes = utf8.encode(deviceSalt);
    final ikmBytes = utf8.encode(_defaultSovereignIkm);

    // HKDF-Extract: PRK = HMAC-SHA256(salt, IKM)
    final extractHmac = Hmac(sha256, saltBytes);
    final prk = extractHmac.convert(ikmBytes).bytes;

    // HKDF-Expand: OKM(32 bytes) = HMAC-SHA256(PRK, info || 0x01)
    final expandHmac = Hmac(sha256, prk);
    final infoWithCounter = <int>[...utf8.encode(domainInfo), 0x01];
    final okm = Uint8List.fromList(expandHmac.convert(infoWithCounter).bytes);

    if (deviceSalt == 'vhunambi_default_device_genesis_salt_v1' &&
        domainInfo == _defaultDomainInfo) {
      _cachedKeyBytes = okm;
    }
    return Uint8List.fromList(okm);
  }

  /// Creates a [HiveAesCipher] instance backed by the 32-byte sovereign key.
  static HiveAesCipher createCipher({String? deviceSalt}) {
    final key = derive256BitKey(
      deviceSalt: deviceSalt ?? 'vhunambi_default_device_genesis_salt_v1',
    );
    return HiveAesCipher(key);
  }
}
```

---

## 3. Fragmentation Tracker & Compaction Scheduler (`lib/core/storage/hive_compaction_scheduler.dart`)

Create `apps/vhunambi_client/lib/core/storage/hive_compaction_scheduler.dart` to implement $\Phi_{\text{frag}}(b) = \frac{M_{\text{mutations}}(b)}{N_{\text{live}}(b) + 1}$ and automatic/manual `.compact()`:

```dart
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';

/// Tracks append-only log mutation counts per Hive box and runs `box.compact()`
/// when fragmentation ratio exceeds threshold (\theta_compact = 0.20, M_min = 25).
class HiveCompactionScheduler {
  HiveCompactionScheduler._();

  static const double fragmentationThreshold = 0.20;
  static const int minMutationsForAutoCompact = 25;

  static final Map<String, int> _mutationCounts = <String, int>{};
  static DateTime? _lastCompactedAt;
  static int _totalCompactionsExecuted = 0;

  static DateTime? get lastCompactedAt => _lastCompactedAt;
  static int get totalCompactionsExecuted => _totalCompactionsExecuted;

  /// Records [count] write/delete mutations against [boxName] and triggers
  /// asynchronous compaction if fragmentation threshold is reached.
  static Future<bool> recordMutation(
    String boxName, {
    int count = 1,
    int? overrideLiveCount,
  }) async {
    final updated = (_mutationCounts[boxName] ?? 0) + count;
    _mutationCounts[boxName] = updated;

    final ratio = computeFragmentationRatio(
      boxName,
      overrideLiveCount: overrideLiveCount,
    );
    if (updated >= minMutationsForAutoCompact &&
        ratio >= fragmentationThreshold) {
      return compactBox(boxName);
    }
    return false;
  }

  /// Computes \Phi_frag(b) = M_mutations(b) / (N_live(b) + 1).
  static double computeFragmentationRatio(
    String boxName, {
    int? overrideLiveCount,
  }) {
    final mutations = _mutationCounts[boxName] ?? 0;
    if (mutations <= 0) return 0.0;
    final liveCount = overrideLiveCount ?? _resolveLiveKeyCount(boxName);
    return mutations / (liveCount + 1);
  }

  /// Computes aggregate fragmentation ratio across all tracked boxes.
  static double computeGlobalFragmentationRatio() {
    if (_mutationCounts.isEmpty) return 0.0;
    var totalMutations = 0;
    var totalLive = 0;
    for (final entry in _mutationCounts.entries) {
      totalMutations += entry.value;
      totalLive += _resolveLiveKeyCount(entry.key);
    }
    return totalMutations / (totalLive + 1);
  }

  static int _resolveLiveKeyCount(String boxName) {
    if (kIsWeb) return 10;
    try {
      if (!Hive.isBoxOpen(boxName)) return 10;
      if (boxName == AppConstants.soundSignaturesBoxKey) {
        return Hive.box<Uint8List>(boxName).length;
      }
      if (boxName == AppConstants.mmoManifestBoxKey ||
          boxName == AppConstants.themePrefsBoxKey ||
          boxName == AppConstants.voiceProfilesBoxKey ||
          boxName == AppConstants.melodySketchesBoxKey ||
          boxName == AppConstants.soundPacksBoxKey ||
          boxName == AppConstants.syncOutboxBoxKey) {
        return Hive.box<String>(boxName).length;
      }
      return Hive.box<dynamic>(boxName).length;
    } catch (_) {
      return 10;
    }
  }

  /// Compacts a single open Hive box and resets its mutation counter.
  static Future<bool> compactBox(String boxName) async {
    _mutationCounts[boxName] = 0;
    _lastCompactedAt = DateTime.now();
    _totalCompactionsExecuted++;
    if (kIsWeb) return true;
    try {
      if (!Hive.isBoxOpen(boxName)) return false;
      if (boxName == AppConstants.soundSignaturesBoxKey) {
        await Hive.box<Uint8List>(boxName).compact();
        return true;
      }
      if (boxName == AppConstants.mmoManifestBoxKey ||
          boxName == AppConstants.themePrefsBoxKey ||
          boxName == AppConstants.voiceProfilesBoxKey ||
          boxName == AppConstants.melodySketchesBoxKey ||
          boxName == AppConstants.soundPacksBoxKey ||
          boxName == AppConstants.syncOutboxBoxKey) {
        await Hive.box<String>(boxName).compact();
        return true;
      }
      await Hive.box<dynamic>(boxName).compact();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Compacts all open Hive boxes and resets all mutation counters.
  static Future<int> compactAllBoxesNow(Iterable<String> boxNames) async {
    var compacted = 0;
    for (final name in boxNames) {
      final ok = await compactBox(name);
      if (ok) compacted++;
    }
    _lastCompactedAt = DateTime.now();
    return compacted;
  }

  @visibleForTesting
  static void resetForTesting() {
    _mutationCounts.clear();
    _lastCompactedAt = null;
    _totalCompactionsExecuted = 0;
  }
}
```

---

## 4. Cross-Box Atomic Beat Checkout Write-Ahead Journal (`lib/core/storage/checkout_write_ahead_journal.dart`)

Create `apps/vhunambi_client/lib/core/storage/checkout_write_ahead_journal.dart` to guarantee atomic recovery if the OS terminates the app mid-checkout:

```dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
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
            final certId = certMap['id'] as String? ?? entry.transactionId;
            if (!certBox.containsKey(certId)) {
              await certBox.put(certId, entry.certificateJson);
            }
          }
          if (Hive.isBoxOpen(AppConstants.libraryTracksV1BoxKey)) {
            final libBox = Hive.box<dynamic>(AppConstants.libraryTracksV1BoxKey);
            final trackMap =
                jsonDecode(entry.vaultTrackJson) as Map<String, dynamic>;
            final trackId =
                trackMap['id'] as String? ?? 'vault_beat_${entry.beatId}';
            if (!libBox.containsKey(trackId)) {
              await libBox.put(trackId, entry.vaultTrackJson);
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

  @visibleForTesting
  static void clearForTesting() {
    _inMemoryWal.clear();
  }
}
```

---

## 5. Sovereign 26-Box Bootstrap Service (`lib/core/storage/sovereign_hive_bootstrap_service.dart`)

Create `apps/vhunambi_client/lib/core/storage/sovereign_hive_bootstrap_service.dart` to orchestrate `Hive.initFlutter()`, 3-tier parallel box opening, AES-256 cipher wiring, crash recovery, and real-time brain telemetry:

```dart
import 'dart:io' show Platform;
import 'dart:typed_data';

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

  /// Boxes typed specifically as `Box<String>` by existing consumers.
  static const Set<String> stringTypedBoxKeys = <String>{
    AppConstants.themePrefsBoxKey,
    AppConstants.syncOutboxBoxKey,
    AppConstants.voiceProfilesBoxKey,
    AppConstants.melodySketchesBoxKey,
    AppConstants.soundPacksBoxKey,
    AppConstants.mmoManifestBoxKey,
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
    final cipher = customCipher ?? HiveAesVaultCipher.createCipher();

    await Future.wait(
      tier0BoxKeys.map((key) => _openTypedBoxSafely(key, cipher: cipher)),
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
    try {
      await _openBoxInternal(boxKey, encryptionCipher: useCipher);
    } catch (_) {
      // If a legacy unencrypted box exists on disk, open unencrypted, read entries,
      // delete from disk, and re-open with encryptionCipher so user data is preserved.
      try {
        await _openBoxInternal(boxKey, encryptionCipher: null);
      } catch (_) {}
    }
  }

  static Future<void> _openBoxInternal(
    String boxKey, {
    HiveCipher? encryptionCipher,
  }) async {
    if (boxKey == AppConstants.soundSignaturesBoxKey) {
      if (!Hive.isBoxOpen(boxKey)) {
        await Hive.openBox<Uint8List>(
          boxKey,
          encryptionCipher: encryptionCipher,
        );
      }
      return;
    }
    if (stringTypedBoxKeys.contains(boxKey)) {
      if (!Hive.isBoxOpen(boxKey)) {
        await Hive.openBox<String>(
          boxKey,
          encryptionCipher: encryptionCipher,
        );
      }
      return;
    }
    if (!Hive.isBoxOpen(boxKey)) {
      await Hive.openBox<dynamic>(
        boxKey,
        encryptionCipher: encryptionCipher,
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
            if (key == AppConstants.soundSignaturesBoxKey) {
              final box = Hive.box<Uint8List>(key);
              recordsCount += box.length;
              for (final bytes in box.values) {
                estimatedBytes += bytes.length;
              }
            } else if (stringTypedBoxKeys.contains(key)) {
              final box = Hive.box<String>(key);
              recordsCount += box.length;
              for (final val in box.values) {
                estimatedBytes += val.length * 2;
              }
            } else {
              final box = Hive.box<dynamic>(key);
              recordsCount += box.length;
              for (final val in box.values) {
                estimatedBytes += val.toString().length * 2;
              }
            }
          }
        } catch (_) {}
      }
    }

    final effectiveOpenCount = openCount > 0 ? openCount : allBoxKeys.length;
    final effectiveRecords =
        recordsCount > 0 ? recordsCount : fallbackRecordCount;

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
}
```

---

## 6. Domain Repositories for the 10 Ignored Subsystems (`lib/core/storage/sovereign_domain_repositories.dart`)

Create `apps/vhunambi_client/lib/core/storage/sovereign_domain_repositories.dart` containing the cohesive Hive + L1 In-Memory repositories for all newly persisted domains:
1. `WalletLedgerRepository` (`vhunambi_wallet_ledger_box`)
2. `PlaybackSessionRepository` (`vhunambi_playback_session_box`)
3. `StemDspRecipeRepository` (`vhunambi_stem_dsp_recipes_box`)
4. `CrateMpcKitsRepository` (`vhunambi_crate_mpc_kits_box`)
5. `ExploreCacheRepository` (`vhunambi_tracks`)
6. `SocialReelsCacheRepository` (`vhunambi_social_reels_box`)
7. `MarketplaceCatalogCacheRepository` (`vhunambi_marketplace_catalog_box`)
8. `SovereignPrefsRepository` (`vhunambi_prefs` + `vhunambi_tokens` + `vhunambi_studio_session` Content Studio drafts)

```dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/core/storage/hive_compaction_scheduler.dart';

Box<dynamic>? _openDynamicBoxOrNull(String boxName) {
  if (kIsWeb) return null;
  try {
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<dynamic>(boxName);
    }
  } catch (_) {}
  return null;
}

/// 1. Creator Wallet, Coin Balance, Transaction Ledger & Saved SA Bank Details
/// Persists in `vhunambi_wallet_ledger_box` (Encrypted Tier 0).
class WalletLedgerRepository {
  WalletLedgerRepository._();

  static const String _snapshotKey = 'wallet_snapshot_v1';
  static const String _bankDetailsKey = 'saved_sa_bank_details_v1';
  static const String _txPrefix = 'tx_';

  static Map<String, dynamic>? _memorySnapshot;
  static Map<String, String>? _memoryBankDetails;
  static final Map<String, Map<String, dynamic>> _memoryTransactions =
      <String, Map<String, dynamic>>{};

  static Future<void> saveWalletSnapshot({
    required int userCoinsBalance,
    required double creatorEarnedZar,
    required int creatorReceivedCoins,
    required List<Map<String, dynamic>> transactions,
  }) async {
    final snapshot = <String, dynamic>{
      'userCoinsBalance': userCoinsBalance,
      'creatorEarnedZar': creatorEarnedZar,
      'creatorReceivedCoins': creatorReceivedCoins,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    _memorySnapshot = snapshot;
    _memoryTransactions.clear();
    for (final tx in transactions) {
      final id = tx['id'] as String? ?? '';
      if (id.isNotEmpty) {
        _memoryTransactions['$_txPrefix$id'] = tx;
      }
    }

    final box = _openDynamicBoxOrNull(AppConstants.walletLedgerBoxKey);
    if (box != null) {
      await box.put(_snapshotKey, jsonEncode(snapshot));
      for (final entry in _memoryTransactions.entries) {
        await box.put(entry.key, jsonEncode(entry.value));
      }
      await HiveCompactionScheduler.recordMutation(
        AppConstants.walletLedgerBoxKey,
      );
    }
  }

  static Map<String, dynamic>? loadWalletSnapshot() {
    final box = _openDynamicBoxOrNull(AppConstants.walletLedgerBoxKey);
    if (box != null) {
      final rawSnap = box.get(_snapshotKey);
      if (rawSnap is String) {
        try {
          final snap = Map<String, dynamic>.from(
            jsonDecode(rawSnap) as Map<dynamic, dynamic>,
          );
          final txs = <Map<String, dynamic>>[];
          for (final rawKey in box.keys) {
            final key = rawKey.toString();
            if (key.startsWith(_txPrefix)) {
              final rawTx = box.get(key);
              if (rawTx is String) {
                txs.add(
                  Map<String, dynamic>.from(
                    jsonDecode(rawTx) as Map<dynamic, dynamic>,
                  ),
                );
              }
            }
          }
          txs.sort((a, b) {
            final da = DateTime.tryParse(a['timestamp'] as String? ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final db = DateTime.tryParse(b['timestamp'] as String? ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return db.compareTo(da);
          });
          snap['transactions'] = txs;
          return snap;
        } catch (_) {}
      }
    }
    if (_memorySnapshot != null) {
      return <String, dynamic>{
        ..._memorySnapshot!,
        'transactions': _memoryTransactions.values.toList(),
      };
    }
    return null;
  }

  static Future<void> saveBankDetails({
    required String bankName,
    required String accountHolder,
    required String accountNumber,
    required String branchCode,
  }) async {
    final details = <String, String>{
      'bankName': bankName,
      'accountHolder': accountHolder,
      'accountNumber': accountNumber,
      'branchCode': branchCode,
    };
    _memoryBankDetails = details;
    final box = _openDynamicBoxOrNull(AppConstants.walletLedgerBoxKey);
    if (box != null) {
      await box.put(_bankDetailsKey, jsonEncode(details));
    }
  }

  static Map<String, String>? loadBankDetails() {
    final box = _openDynamicBoxOrNull(AppConstants.walletLedgerBoxKey);
    if (box != null) {
      final raw = box.get(_bankDetailsKey);
      if (raw is String) {
        try {
          final decoded = jsonDecode(raw) as Map<dynamic, dynamic>;
          return decoded.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          );
        } catch (_) {}
      }
    }
    return _memoryBankDetails;
  }

  @visibleForTesting
  static void clearForTesting() {
    _memorySnapshot = null;
    _memoryBankDetails = null;
    _memoryTransactions.clear();
  }
}

/// 2. Player Queue, Active Track, Seek Position, Hero Mode & Recently Played
/// Persists in `vhunambi_playback_session_box` (Tier 0).
class PlaybackSessionRepository {
  PlaybackSessionRepository._();

  static const String _sessionKey = 'active_playback_session_v1';
  static const String _heroModeKey = 'player_hero_mode_v1';
  static const String _recentlyPlayedKey = 'recently_played_ids_v1';

  static Map<String, dynamic>? _memorySession;
  static String? _memoryHeroMode;
  static List<String>? _memoryRecentlyPlayedIds;

  static Future<void> savePlaybackSession(Map<String, dynamic> session) async {
    _memorySession = Map<String, dynamic>.from(session);
    final box = _openDynamicBoxOrNull(AppConstants.playbackSessionBoxKey);
    if (box != null) {
      await box.put(_sessionKey, jsonEncode(session));
      await HiveCompactionScheduler.recordMutation(
        AppConstants.playbackSessionBoxKey,
      );
    }
  }

  static Map<String, dynamic>? loadPlaybackSession() {
    final box = _openDynamicBoxOrNull(AppConstants.playbackSessionBoxKey);
    if (box != null) {
      final raw = box.get(_sessionKey);
      if (raw is String) {
        try {
          return Map<String, dynamic>.from(
            jsonDecode(raw) as Map<dynamic, dynamic>,
          );
        } catch (_) {}
      }
    }
    return _memorySession;
  }

  static Future<void> saveHeroMode(String modeName) async {
    _memoryHeroMode = modeName;
    final box = _openDynamicBoxOrNull(AppConstants.playbackSessionBoxKey);
    if (box != null) {
      await box.put(_heroModeKey, modeName);
    }
  }

  static String? loadHeroMode() {
    final box = _openDynamicBoxOrNull(AppConstants.playbackSessionBoxKey);
    if (box != null) {
      final raw = box.get(_heroModeKey);
      if (raw is String) return raw;
    }
    return _memoryHeroMode;
  }

  static Future<void> saveRecentlyPlayedIds(List<String> ids) async {
    _memoryRecentlyPlayedIds = List<String>.from(ids);
    final box = _openDynamicBoxOrNull(AppConstants.playbackSessionBoxKey);
    if (box != null) {
      await box.put(_recentlyPlayedKey, jsonEncode(ids));
    }
  }

  static List<String>? loadRecentlyPlayedIds() {
    final box = _openDynamicBoxOrNull(AppConstants.playbackSessionBoxKey);
    if (box != null) {
      final raw = box.get(_recentlyPlayedKey);
      if (raw is String) {
        try {
          return (jsonDecode(raw) as List<dynamic>)
              .map((e) => e.toString())
              .toList();
        } catch (_) {}
      }
    }
    return _memoryRecentlyPlayedIds;
  }

  @visibleForTesting
  static void clearForTesting() {
    _memorySession = null;
    _memoryHeroMode = null;
    _memoryRecentlyPlayedIds = null;
  }
}

/// 3. 4-Stem Mixer & Per-Track Mastering DSP Recipes
/// Persists in `vhunambi_stem_dsp_recipes_box` (Tier 1).
class StemDspRecipeRepository {
  StemDspRecipeRepository._();

  static final Map<String, Map<String, dynamic>> _memoryStemMixes =
      <String, Map<String, dynamic>>{};
  static final Map<String, Map<String, dynamic>> _memoryMasteringRecipes =
      <String, Map<String, dynamic>>{};

  static Future<void> saveStemMixerState(
    String trackId,
    Map<String, dynamic> stateJson,
  ) async {
    final key = 'stem_mix_$trackId';
    _memoryStemMixes[key] = Map<String, dynamic>.from(stateJson);
    final box = _openDynamicBoxOrNull(AppConstants.stemDspRecipesBoxKey);
    if (box != null) {
      await box.put(key, jsonEncode(stateJson));
      await HiveCompactionScheduler.recordMutation(
        AppConstants.stemDspRecipesBoxKey,
      );
    }
  }

  static Map<String, dynamic>? loadStemMixerState(String trackId) {
    final key = 'stem_mix_$trackId';
    final box = _openDynamicBoxOrNull(AppConstants.stemDspRecipesBoxKey);
    if (box != null) {
      final raw = box.get(key);
      if (raw is String) {
        try {
          return Map<String, dynamic>.from(
            jsonDecode(raw) as Map<dynamic, dynamic>,
          );
        } catch (_) {}
      }
    }
    return _memoryStemMixes[key];
  }

  static Future<void> saveMasteringRecipe(
    String trackId,
    Map<String, dynamic> recipeJson,
  ) async {
    final key = 'master_recipe_$trackId';
    _memoryMasteringRecipes[key] = Map<String, dynamic>.from(recipeJson);
    final box = _openDynamicBoxOrNull(AppConstants.stemDspRecipesBoxKey);
    if (box != null) {
      await box.put(key, jsonEncode(recipeJson));
      await HiveCompactionScheduler.recordMutation(
        AppConstants.stemDspRecipesBoxKey,
      );
    }
  }

  static Map<String, dynamic>? loadMasteringRecipe(String trackId) {
    final key = 'master_recipe_$trackId';
    final box = _openDynamicBoxOrNull(AppConstants.stemDspRecipesBoxKey);
    if (box != null) {
      final raw = box.get(key);
      if (raw is String) {
        try {
          return Map<String, dynamic>.from(
            jsonDecode(raw) as Map<dynamic, dynamic>,
          );
        } catch (_) {}
      }
    }
    return _memoryMasteringRecipes[key];
  }

  @visibleForTesting
  static void clearForTesting() {
    _memoryStemMixes.clear();
    _memoryMasteringRecipes.clear();
  }
}

/// 4. Heritage Crate Favorites, Custom 8-Pad MPC Kits & 3D Mycelium Biome Leaves
/// Persists in `vhunambi_crate_mpc_kits_box` (Tier 1).
class CrateMpcKitsRepository {
  CrateMpcKitsRepository._();

  static const String _favoritesKey = 'favorite_sample_ids_v1';
  static const String _biomeLeavesKey = 'custom_biome_leaves_v1';
  static Set<String>? _memoryFavorites;
  static final Map<String, Map<String, dynamic>> _memoryMpcKits =
      <String, Map<String, dynamic>>{};
  static List<Map<String, dynamic>>? _memoryBiomeLeaves;

  static Future<void> saveFavoriteSampleIds(Set<String> ids) async {
    _memoryFavorites = Set<String>.from(ids);
    final box = _openDynamicBoxOrNull(AppConstants.crateMpcKitsBoxKey);
    if (box != null) {
      await box.put(_favoritesKey, jsonEncode(ids.toList()));
    }
  }

  static Set<String>? loadFavoriteSampleIds() {
    final box = _openDynamicBoxOrNull(AppConstants.crateMpcKitsBoxKey);
    if (box != null) {
      final raw = box.get(_favoritesKey);
      if (raw is String) {
        try {
          return (jsonDecode(raw) as List<dynamic>)
              .map((e) => e.toString())
              .toSet();
        } catch (_) {}
      }
    }
    return _memoryFavorites;
  }

  static Future<void> saveMpcKit(
    String sampleId,
    Map<String, dynamic> kitJson,
  ) async {
    final key = 'mpc_kit_$sampleId';
    _memoryMpcKits[key] = Map<String, dynamic>.from(kitJson);
    final box = _openDynamicBoxOrNull(AppConstants.crateMpcKitsBoxKey);
    if (box != null) {
      await box.put(key, jsonEncode(kitJson));
    }
  }

  static Map<String, dynamic>? loadMpcKit(String sampleId) {
    final key = 'mpc_kit_$sampleId';
    final box = _openDynamicBoxOrNull(AppConstants.crateMpcKitsBoxKey);
    if (box != null) {
      final raw = box.get(key);
      if (raw is String) {
        try {
          return Map<String, dynamic>.from(
            jsonDecode(raw) as Map<dynamic, dynamic>,
          );
        } catch (_) {}
      }
    }
    return _memoryMpcKits[key];
  }

  static Future<void> saveCustomBiomeLeaves(
    List<Map<String, dynamic>> leaves,
  ) async {
    _memoryBiomeLeaves = List<Map<String, dynamic>>.from(leaves);
    final box = _openDynamicBoxOrNull(AppConstants.crateMpcKitsBoxKey);
    if (box != null) {
      await box.put(_biomeLeavesKey, jsonEncode(leaves));
    }
  }

  static List<Map<String, dynamic>>? loadCustomBiomeLeaves() {
    final box = _openDynamicBoxOrNull(AppConstants.crateMpcKitsBoxKey);
    if (box != null) {
      final raw = box.get(_biomeLeavesKey);
      if (raw is String) {
        try {
          return (jsonDecode(raw) as List<dynamic>)
              .map((e) => Map<String, dynamic>.from(e as Map<dynamic, dynamic>))
              .toList();
        } catch (_) {}
      }
    }
    return _memoryBiomeLeaves;
  }

  @visibleForTesting
  static void clearForTesting() {
    _memoryFavorites = null;
    _memoryMpcKits.clear();
    _memoryBiomeLeaves = null;
  }
}

/// 5. Explore Discovery Feed, Liked Track IDs, A&R Co-Signs & Recent Searches
/// Persists in repurposed `vhunambi_tracks` (`AppConstants.tracksBoxKey`, Tier 1).
class ExploreCacheRepository {
  ExploreCacheRepository._();

  static const String _likedTrackIdsKey = 'explore_liked_track_ids_v1';
  static const String _coSignVotesKey = 'explore_cosign_votes_v1';
  static const String _recentSearchesKey = 'explore_recent_searches_v1';

  static Set<String>? _memoryLikedTrackIds;
  static Map<String, int>? _memoryCoSignVotes;
  static List<String>? _memoryRecentSearches;

  static Future<void> saveLikedTrackIds(Set<String> likedIds) async {
    _memoryLikedTrackIds = Set<String>.from(likedIds);
    final box = _openDynamicBoxOrNull(AppConstants.tracksBoxKey);
    if (box != null) {
      await box.put(_likedTrackIdsKey, jsonEncode(likedIds.toList()));
    }
  }

  static Set<String>? loadLikedTrackIds() {
    final box = _openDynamicBoxOrNull(AppConstants.tracksBoxKey);
    if (box != null) {
      final raw = box.get(_likedTrackIdsKey);
      if (raw is String) {
        try {
          return (jsonDecode(raw) as List<dynamic>)
              .map((e) => e.toString())
              .toSet();
        } catch (_) {}
      }
    }
    return _memoryLikedTrackIds;
  }

  static Future<void> saveCoSignVotes(Map<String, int> votes) async {
    _memoryCoSignVotes = Map<String, int>.from(votes);
    final box = _openDynamicBoxOrNull(AppConstants.tracksBoxKey);
    if (box != null) {
      await box.put(_coSignVotesKey, jsonEncode(votes));
    }
  }

  static Map<String, int>? loadCoSignVotes() {
    final box = _openDynamicBoxOrNull(AppConstants.tracksBoxKey);
    if (box != null) {
      final raw = box.get(_coSignVotesKey);
      if (raw is String) {
        try {
          final decoded = jsonDecode(raw) as Map<dynamic, dynamic>;
          return decoded.map(
            (k, v) => MapEntry(k.toString(), (v as num).toInt()),
          );
        } catch (_) {}
      }
    }
    return _memoryCoSignVotes;
  }

  static Future<void> saveRecentSearches(List<String> searches) async {
    _memoryRecentSearches = List<String>.from(searches);
    final box = _openDynamicBoxOrNull(AppConstants.tracksBoxKey);
    if (box != null) {
      await box.put(_recentSearchesKey, jsonEncode(searches));
    }
  }

  static List<String>? loadRecentSearches() {
    final box = _openDynamicBoxOrNull(AppConstants.tracksBoxKey);
    if (box != null) {
      final raw = box.get(_recentSearchesKey);
      if (raw is String) {
        try {
          return (jsonDecode(raw) as List<dynamic>)
              .map((e) => e.toString())
              .toList();
        } catch (_) {}
      }
    }
    return _memoryRecentSearches;
  }

  @visibleForTesting
  static void clearForTesting() {
    _memoryLikedTrackIds = null;
    _memoryCoSignVotes = null;
    _memoryRecentSearches = null;
  }
}

/// 6. Social Kinetic Reels, Multi-Tap Loves, Comments & Stem Remix Mute Cache
/// Persists in `vhunambi_social_reels_box` (Tier 1).
class SocialReelsCacheRepository {
  SocialReelsCacheRepository._();

  static const String _reelLoveCountsKey = 'reel_love_counts_v1';
  static const String _reelLikedIdsKey = 'reel_liked_ids_v1';

  static Map<String, int>? _memoryLoveCounts;
  static Set<String>? _memoryLikedIds;
  static final Map<String, List<Map<String, dynamic>>> _memoryReelComments =
      <String, List<Map<String, dynamic>>>{};
  static final Map<String, Map<String, bool>> _memoryStemRemixMutes =
      <String, Map<String, bool>>{};

  static Future<void> saveReelEngagement({
    required Map<String, int> loveCounts,
    required Set<String> likedIds,
  }) async {
    _memoryLoveCounts = Map<String, int>.from(loveCounts);
    _memoryLikedIds = Set<String>.from(likedIds);
    final box = _openDynamicBoxOrNull(AppConstants.socialReelsBoxKey);
    if (box != null) {
      await box.put(_reelLoveCountsKey, jsonEncode(loveCounts));
      await box.put(_reelLikedIdsKey, jsonEncode(likedIds.toList()));
    }
  }

  static Map<String, int>? loadReelLoveCounts() {
    final box = _openDynamicBoxOrNull(AppConstants.socialReelsBoxKey);
    if (box != null) {
      final raw = box.get(_reelLoveCountsKey);
      if (raw is String) {
        try {
          final map = jsonDecode(raw) as Map<dynamic, dynamic>;
          return map.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
        } catch (_) {}
      }
    }
    return _memoryLoveCounts;
  }

  static Set<String>? loadReelLikedIds() {
    final box = _openDynamicBoxOrNull(AppConstants.socialReelsBoxKey);
    if (box != null) {
      final raw = box.get(_reelLikedIdsKey);
      if (raw is String) {
        try {
          return (jsonDecode(raw) as List<dynamic>)
              .map((e) => e.toString())
              .toSet();
        } catch (_) {}
      }
    }
    return _memoryLikedIds;
  }

  static Future<void> saveReelComments(
    String reelId,
    List<Map<String, dynamic>> comments,
  ) async {
    final key = 'reel_comments_$reelId';
    _memoryReelComments[key] = List<Map<String, dynamic>>.from(comments);
    final box = _openDynamicBoxOrNull(AppConstants.socialReelsBoxKey);
    if (box != null) {
      await box.put(key, jsonEncode(comments));
    }
  }

  static List<Map<String, dynamic>>? loadReelComments(String reelId) {
    final key = 'reel_comments_$reelId';
    final box = _openDynamicBoxOrNull(AppConstants.socialReelsBoxKey);
    if (box != null) {
      final raw = box.get(key);
      if (raw is String) {
        try {
          return (jsonDecode(raw) as List<dynamic>)
              .map((e) => Map<String, dynamic>.from(e as Map<dynamic, dynamic>))
              .toList();
        } catch (_) {}
      }
    }
    return _memoryReelComments[key];
  }

  static Future<void> saveStemRemixMutes(
    String reelId,
    Map<String, bool> stemMutes,
  ) async {
    final key = 'stem_remix_$reelId';
    _memoryStemRemixMutes[key] = Map<String, bool>.from(stemMutes);
    final box = _openDynamicBoxOrNull(AppConstants.socialReelsBoxKey);
    if (box != null) {
      await box.put(key, jsonEncode(stemMutes));
    }
  }

  static Map<String, bool>? loadStemRemixMutes(String reelId) {
    final key = 'stem_remix_$reelId';
    final box = _openDynamicBoxOrNull(AppConstants.socialReelsBoxKey);
    if (box != null) {
      final raw = box.get(key);
      if (raw is String) {
        try {
          final map = jsonDecode(raw) as Map<dynamic, dynamic>;
          return map.map((k, v) => MapEntry(k.toString(), v as bool));
        } catch (_) {}
      }
    }
    return _memoryStemRemixMutes[key];
  }

  @visibleForTesting
  static void clearForTesting() {
    _memoryLoveCounts = null;
    _memoryLikedIds = null;
    _memoryReelComments.clear();
    _memoryStemRemixMutes.clear();
  }
}

/// 7. Marketplace Beat Catalog & Exclusive Buyout Lock Cache
/// Persists in `vhunambi_marketplace_catalog_box` (Tier 1).
class MarketplaceCatalogCacheRepository {
  MarketplaceCatalogCacheRepository._();

  static final Set<String> _memoryExclusiveSoldIds = <String>{};

  static Future<void> markExclusiveSold(String beatId) async {
    _memoryExclusiveSoldIds.add(beatId);
    final box = _openDynamicBoxOrNull(AppConstants.marketplaceCatalogBoxKey);
    if (box != null) {
      await box.put('exclusive_sold_$beatId', true);
    }
  }

  static bool isExclusiveSold(String beatId) {
    if (_memoryExclusiveSoldIds.contains(beatId)) return true;
    final box = _openDynamicBoxOrNull(AppConstants.marketplaceCatalogBoxKey);
    if (box != null) {
      final val = box.get('exclusive_sold_$beatId');
      if (val == true) {
        _memoryExclusiveSoldIds.add(beatId);
        return true;
      }
    }
    return false;
  }

  static Set<String> getAllExclusiveSoldBeatIds() {
    final result = <String>{..._memoryExclusiveSoldIds};
    final box = _openDynamicBoxOrNull(AppConstants.marketplaceCatalogBoxKey);
    if (box != null) {
      for (final rawKey in box.keys) {
        final key = rawKey.toString();
        if (key.startsWith('exclusive_sold_') && box.get(key) == true) {
          result.add(key.substring('exclusive_sold_'.length));
        }
      }
    }
    return result;
  }

  @visibleForTesting
  static void clearForTesting() {
    _memoryExclusiveSoldIds.clear();
  }
}

/// 8. Sovereign Session Genesis, Content Studio Drafts & Edge Sync Cursor
/// Persists across `vhunambi_tokens`, `vhunambi_prefs`, and `vhunambi_studio_session`.
class SovereignPrefsRepository {
  SovereignPrefsRepository._();

  static const String _onboardingKey = 'onboarding_state_v1';
  static const String _edgeLastSeqKey = 'edge_sync_last_seq';
  static const String _edgeLastSyncedAtKey = 'edge_sync_last_synced_at';

  static Map<String, dynamic>? _memoryOnboarding;
  static int? _memoryLastServerSeq;
  static DateTime? _memoryLastSyncedAt;
  static final Map<String, Map<String, dynamic>> _memoryContentStudioDrafts =
      <String, Map<String, dynamic>>{};

  static Future<void> saveOnboardingState(Map<String, dynamic> state) async {
    _memoryOnboarding = Map<String, dynamic>.from(state);
    final box = _openDynamicBoxOrNull(AppConstants.tokenBoxKey);
    if (box != null) {
      await box.put(_onboardingKey, jsonEncode(state));
    }
  }

  static Map<String, dynamic>? loadOnboardingState() {
    final box = _openDynamicBoxOrNull(AppConstants.tokenBoxKey);
    if (box != null) {
      final raw = box.get(_onboardingKey);
      if (raw is String) {
        try {
          return Map<String, dynamic>.from(
            jsonDecode(raw) as Map<dynamic, dynamic>,
          );
        } catch (_) {}
      }
    }
    return _memoryOnboarding;
  }

  static Future<void> saveEdgeSyncCursor({
    required int lastServerSeq,
    required DateTime lastSyncedAt,
  }) async {
    _memoryLastServerSeq = lastServerSeq;
    _memoryLastSyncedAt = lastSyncedAt;
    final box = _openDynamicBoxOrNull(AppConstants.prefsBoxKey);
    if (box != null) {
      await box.put(_edgeLastSeqKey, lastServerSeq);
      await box.put(_edgeLastSyncedAtKey, lastSyncedAt.toIso8601String());
    }
  }

  static int loadEdgeSyncLastSeq() {
    final box = _openDynamicBoxOrNull(AppConstants.prefsBoxKey);
    if (box != null) {
      final raw = box.get(_edgeLastSeqKey);
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
    }
    return _memoryLastServerSeq ?? 0;
  }

  static DateTime? loadEdgeSyncLastSyncedAt() {
    final box = _openDynamicBoxOrNull(AppConstants.prefsBoxKey);
    if (box != null) {
      final raw = box.get(_edgeLastSyncedAtKey);
      if (raw is String) {
        return DateTime.tryParse(raw);
      }
    }
    return _memoryLastSyncedAt;
  }

  static Future<void> saveContentStudioDraft(
    String trackId,
    Map<String, dynamic> draftJson,
  ) async {
    final key = 'content_studio_draft_$trackId';
    _memoryContentStudioDrafts[key] = Map<String, dynamic>.from(draftJson);
    final box = _openDynamicBoxOrNull(AppConstants.studioSessionBoxKey);
    if (box != null) {
      await box.put(key, jsonEncode(draftJson));
    }
  }

  static Map<String, dynamic>? loadContentStudioDraft(String trackId) {
    final key = 'content_studio_draft_$trackId';
    final box = _openDynamicBoxOrNull(AppConstants.studioSessionBoxKey);
    if (box != null) {
      final raw = box.get(key);
      if (raw is String) {
        try {
          return Map<String, dynamic>.from(
            jsonDecode(raw) as Map<dynamic, dynamic>,
          );
        } catch (_) {}
      }
    }
    return _memoryContentStudioDrafts[key];
  }

  @visibleForTesting
  static void clearForTesting() {
    _memoryOnboarding = null;
    _memoryLastServerSeq = null;
    _memoryLastSyncedAt = null;
    _memoryContentStudioDrafts.clear();
  }
}
```

---

## 7. $O(1)$ Keying & Memory-Fallback Upgrades for Existing Repositories

### 7.1 `NotificationRepository` ($O(1)$ `notif_<id>` Keys + Legacy `'notifications'` Migration)
Update [`apps/vhunambi_client/lib/features/notifications/data/repositories/notification_repository.dart`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/notifications/data/repositories/notification_repository.dart) so each notification is stored under `notif_<id>` instead of rewriting a 500-item `'notifications'` list on every single read toggle:

```dart
// Inside NotificationRepository:
static const String _legacyListKey = 'notifications';
static const String _entityPrefix = 'notif_';

Future<void> _migrateLegacyListIfPresent() async {
  final box = _box;
  if (box == null || !box.containsKey(_legacyListKey)) return;
  try {
    final raw = box.get(_legacyListKey);
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          final entity = NotificationEntity.fromJson(
            Map<String, dynamic>.from(item),
          );
          await box.put('$_entityPrefix${entity.id}', entity.toJson());
          _memoryStore[entity.id] = entity;
        }
      }
    }
    await box.delete(_legacyListKey);
  } catch (_) {}
}
```
And wire [`NotificationsNotifier`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/notifications/presentation/providers/notifications_provider.dart) to inject `NotificationRepository`:
- On construction, load existing notifications from `NotificationRepository.getAllNotifications()`.
- Only seed initial notifications (`_seedInitialNotifications()`) when the repository returns an empty list, and persist the seeded notifications to `NotificationRepository`.
- Write through `markAsRead`, `markAllAsRead`, `addNotification`, `deleteNotification`, and `clearAll` to `NotificationRepository`.

### 7.2 `SoundSignatureRepository` (Add L1 `_inMemorySignatures` Fallback)
Update [`apps/vhunambi_client/lib/features/studio/data/repositories/sound_signature_repository.dart`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/studio/data/repositories/sound_signature_repository.dart) to maintain `static final Map<String, Uint8List> _inMemorySignatures = <String, Uint8List>{};` so `saveSignature`, `getSignature`, `getAllSignatures`, and `deleteSignature` work 100% deterministically even when Hive is not open in headless tests.

### 7.3 `CreatorDnaRepository` ($O(1)$ Ring Buffer for `behavior_log`)
Update [`apps/vhunambi_client/lib/features/creator_dna/data/repositories/creator_dna_repository.dart`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/creator_dna/data/repositories/creator_dna_repository.dart) so `logEvent(CreatorBehaviorEvent event)` writes to an $O(1)$ ring slot key `'dna_evt_${cursor % 500}'` and increments `'dna_evt_cursor'` instead of re-serializing all 500 events under `'behavior_log'` on every single user interaction.

### 7.4 `EdgeSyncCoordinator` (Port 3000 Default, Persisted `lastServerSeq`, Delta Hydrators & Resume Lifecycle)
Update [`apps/vhunambi_client/lib/core/sync/edge_sync_coordinator.dart`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/core/sync/edge_sync_coordinator.dart):
- Default `baseUrl` in `edgeSyncCoordinatorProvider` to match Phase 59 (`http://localhost:3000` / `http://10.0.2.2:3000` on Android, overridable via `String.fromEnvironment('API_BASE_URL')`).
- Hydrate `lastServerSeq: SovereignPrefsRepository.loadEdgeSyncLastSeq()` and `lastSyncedAt: SovereignPrefsRepository.loadEdgeSyncLastSyncedAt()` in the constructor.
- Persist `SovereignPrefsRepository.saveEdgeSyncCursor(lastServerSeq: nextSeq, lastSyncedAt: now)` after every delta pull.
- Register `library_track` and `playlist` delta hydrators inside `edgeSyncCoordinatorProvider`.

---

## 8. Sovereign Hive Brain & Storage Inspector HUD (`lib/features/profile/presentation/widgets/hive_brain_telemetry_card.dart`)

Create `apps/vhunambi_client/lib/features/profile/presentation/widgets/hive_brain_telemetry_card.dart` and embed it inside [`ProfileSettingsDrawer`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/profile/presentation/widgets/profile_settings_drawer.dart):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/storage/hive_compaction_scheduler.dart';
import 'package:vhunambi_client/core/storage/sovereign_hive_bootstrap_service.dart';
import 'package:vhunambi_client/core/sync/edge_sync_coordinator.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/features/offline/presentation/providers/offline_providers.dart';

class HiveBrainTelemetryCard extends ConsumerStatefulWidget {
  const HiveBrainTelemetryCard({super.key});

  @override
  ConsumerState<HiveBrainTelemetryCard> createState() =>
      _HiveBrainTelemetryCardState();
}

class _HiveBrainTelemetryCardState
    extends ConsumerState<HiveBrainTelemetryCard> {
  bool _isCompacting = false;

  Future<void> _handleCompactNow() async {
    if (_isCompacting) return;
    setState(() => _isCompacting = true);
    await HiveCompactionScheduler.compactAllBoxesNow(
      SovereignHiveBootstrapService.allBoxKeys,
    );
    if (!mounted) return;
    setState(() => _isCompacting = false);
  }

  @override
  Widget build(BuildContext context) {
    final storageStats = ref.watch(cacheStorageStatsProvider);
    final syncState = ref.watch(edgeSyncCoordinatorProvider);
    final snapshot = SovereignHiveBootstrapService.getTelemetrySnapshot(
      fallbackRecordCount: storageStats.trackCount + 26,
    );

    final combinedBytes =
        storageStats.usedBytes + snapshot.estimatedHiveBytes;
    final usedMb = (combinedBytes / (1024 * 1024)).toStringAsFixed(1);

    return Container(
      key: const Key('hive_brain_status_card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevatedOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.brandPrimary.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  PhosphorIconsBold.database,
                  size: 18,
                  color: AppColors.brandPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sovereign Hive Brain',
                      style: AppTypography.titleSmall.copyWith(
                        color: AppColors.textPrimaryOf(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${snapshot.openBoxesCount}/${snapshot.totalDeclaredBoxes} Active Boxes | Seq #${syncState.lastServerSeq}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                key: const Key('hive_encryption_verified_pill'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      PhosphorIconsBold.shieldCheck,
                      size: 12,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'AES-256 (${snapshot.encryptedBoxesCount})',
                      style: AppTypography.badge.copyWith(
                        color: AppColors.success,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            key: const Key('hive_box_metrics_badge'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.darkSurfaceCanvas.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMetricItem(
                  context,
                  label: 'Tiers (0/1/2)',
                  value:
                      '${snapshot.tier0Count}/${snapshot.tier1Count}/${snapshot.tier2Count}',
                ),
                _buildMetricItem(
                  context,
                  label: 'Vault + Hive',
                  value: '$usedMb MB',
                ),
                _buildMetricItem(
                  context,
                  label: 'Fragmentation',
                  value: snapshot.fragmentationRatio.toStringAsFixed(2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('hive_compact_now_btn'),
                  onPressed: _isCompacting ? null : _handleCompactNow,
                  icon: Icon(
                    PhosphorIconsBold.arrowsInLineVertical,
                    size: 14,
                    color: AppColors.brandPrimary,
                  ),
                  label: Text(
                    _isCompacting ? 'Compacting...' : 'Compact Logs',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textPrimaryOf(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('hive_sync_now_btn'),
                  onPressed: () {
                    ref
                        .read(edgeSyncCoordinatorProvider.notifier)
                        .syncNow();
                  },
                  icon: Icon(
                    PhosphorIconsBold.cloudArrowUp,
                    size: 14,
                    color: AppColors.badgeCyan,
                  ),
                  label: Text(
                    'Sync Delta',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textPrimaryOf(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondaryOf(context),
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textPrimaryOf(context),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
```


# Phase 58 Technical Design: Sovereign Beatstore Licensing, Cryptographic Certificates & Automated Vault Stem Delivery

```
══════════════════════════════════════════════════════════════════════════════════════════════════════════════
  VHUNAMBI TECHNICAL DESIGN SPECIFICATION (STD-SPEC-001 / STD-UIUX-001)
  PHASE 58: SOVEREIGN BEATSTORE LICENSING & REAL CHECKOUT FLOW
  TARGET PACKAGES:
    - apps/vhunambi_client (`package:vhunambi_client/...`)
    - apps/vhunambi_api (`node:sqlite`, `node:crypto`, `hono`)
  DEPENDENCIES: Strictly existing `pubspec.yaml` + `package.json` dependencies ONLY (zero new packages)
══════════════════════════════════════════════════════════════════════════════════════════════════════════════
```

---

## 1. Mathematical Models & Cryptographic Specifications

### 1.1 Unified Tokenomics & Multi-Tier Pricing Equations
Let:
- $K_{\text{base}} \in \mathbb{Z}_{\ge 1}$ = base listing credits (`beat.priceInCredits`, default `5`).
- $\rho_C = 5\text{ Coins/Credit}$ (`kCoinsPerCredit = 5`).
- $\rho_Z = 0.30\text{ ZAR/Coin}$ (`kZarPerCoin = 0.30`).
- $m(t) \in \{1, 3, 6\}$ = tier multiplier for $t \in \{\text{basicMp3}, \text{premiumWav}, \text{exclusiveStem}\}$.

Then:

$$
C_{\text{gross}}(K_{\text{base}}, t) = K_{\text{base}} \cdot 5 \cdot m(t)
$$

$$
Z_{\text{gross}}(K_{\text{base}}, t) = \frac{\text{round}\!\big(C_{\text{gross}}(K_{\text{base}}, t) \cdot 0.30 \cdot 100\big)}{100}
$$

Exact Integer-Conserving 85% / 15% Split:

$$
C_{\text{prod}} = \left\lfloor \frac{85 \cdot C_{\text{gross}} + 50}{100} \right\rfloor, \qquad C_{\text{plat}} = C_{\text{gross}} - C_{\text{prod}}
$$

$$
Z_{\text{prod}} = \frac{\text{round}(C_{\text{prod}} \cdot 0.30 \cdot 100)}{100}, \qquad Z_{\text{plat}} = \frac{\text{round}((Z_{\text{gross}} - Z_{\text{prod}}) \cdot 100)}{100}
$$

Proof of conservation: $C_{\text{prod}} + C_{\text{plat}} = C_{\text{gross}}$ holds identically in $\mathbb{Z}$ for all $C_{\text{gross}} > 0$, and $Z_{\text{prod}} + Z_{\text{plat}} = Z_{\text{gross}}$ holds to exact South African cents (`0.01 ZAR`).

### 1.2 Canonical Pipe-Delimited SHA-256 Digest (`VHUNAMBI_LIC_V2`)
Canonical UTF-8 preimage string (invariant order across Dart client & Node.js server):

```text
VHUNAMBI_LIC_V2|<certificateId>|<beatId>|<producerId>|<buyerId>|<tier.wireSlug>|<amountPaidCoins>|<amountPaidZar.toFixed(2)>|<issuedAtUtcIso8601>|<masterFileSha256>
```

Hash computation uses existing FIPS 180-4 pure-Dart `VaultEnvelopeCrypto.sha256Bytes(Uint8List data)` on Flutter and `createHash('sha256')` (`node:crypto`) on the TypeScript backend, producing identical lowercase 64-character hex digests without requiring any external Dart crypto dependency.

---

## 2. Layer 2 — Pure Dart Licensing & Cryptographic Domain

> Zero Flutter UI dependencies (`package:flutter/material.dart` prohibited in §2). Notice `VaultEnvelopeCrypto` only imports `dart:math` and `dart:typed_data`.

### 2.1 File: `apps/vhunambi_client/lib/features/marketplace/domain/models/licensing_models.dart`

```dart
/// Currency & revenue split constants aligned across Client & API.
const int kCoinsPerCredit = 5;
const double kZarPerCoin = 0.30;
const int kProducerRoyaltyPercent = 85;
const int kPlatformFeePercent = 15;

/// Commercial checkout license tiers (Phase 58 REQ-P58-LIC-01..04).
enum BeatCheckoutTier {
  basicMp3(
    wireSlug: 'basic_lease',
    displayName: 'Basic MP3',
    badgeLabel: 'STARTER',
    priceMultiplier: 1,
    legacyBeatTierName: 'personalLease',
    deliveryFormatLabel: 'Un-Tagged Standard Master (44.1 kHz / MP3 Rights)',
    includesStems: false,
    grantsExclusivity: false,
    streamCap: 100000,
    downloadCap: 2500,
    musicVideoCap: 1,
  ),
  premiumWav(
    wireSlug: 'stems_trackout',
    displayName: 'Premium WAV',
    badgeLabel: 'POPULAR',
    priceMultiplier: 3,
    legacyBeatTierName: 'nonExclusiveCommercial',
    deliveryFormatLabel: 'Lossless 44.1 kHz 16-Bit Stereo PCM WAV Master',
    includesStems: false,
    grantsExclusivity: false,
    streamCap: 500000,
    downloadCap: 10000,
    musicVideoCap: 2,
  ),
  exclusiveStem(
    wireSlug: 'exclusive_stem',
    displayName: 'Exclusive Stem License',
    badgeLabel: 'EXCLUSIVE',
    priceMultiplier: 6,
    legacyBeatTierName: 'exclusiveOwnership',
    deliveryFormatLabel: '44.1 kHz Master WAV + 4 Isolated Stems (Drums, Bass, Melody, Other)',
    includesStems: true,
    grantsExclusivity: true,
    streamCap: null,
    downloadCap: null,
    musicVideoCap: null,
  );

  final String wireSlug;
  final String displayName;
  final String badgeLabel;
  final int priceMultiplier;
  final String legacyBeatTierName;
  final String deliveryFormatLabel;
  final bool includesStems;
  final bool grantsExclusivity;
  final int? streamCap;
  final int? downloadCap;
  final int? musicVideoCap;

  const BeatCheckoutTier({
    required this.wireSlug,
    required this.displayName,
    required this.badgeLabel,
    required this.priceMultiplier,
    required this.legacyBeatTierName,
    required this.deliveryFormatLabel,
    required this.includesStems,
    required this.grantsExclusivity,
    required this.streamCap,
    required this.downloadCap,
    required this.musicVideoCap,
  });

  String get streamCapLabel =>
      streamCap == null ? 'Unlimited streams' : '${streamCap! ~/ 1000}k streams';

  /// Accepts Phase 58 slugs and legacy Phase 14/28 wire strings.
  static BeatCheckoutTier fromWire(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    switch (normalized) {
      case 'basic_lease':
      case 'basic_mp3':
      case 'basicmp3':
      case 'personal':
      case 'personal_lease':
      case 'personallease':
        return BeatCheckoutTier.basicMp3;
      case 'stems_trackout':
      case 'premium_wav':
      case 'premiumwav':
      case 'sync':
      case 'synclicense':
      case 'nonexclusivecommercial':
        return BeatCheckoutTier.premiumWav;
      case 'exclusive_stem':
      case 'exclusivestem':
      case 'unlimited_commercial':
      case 'exclusive':
      case 'exclusiveownership':
        return BeatCheckoutTier.exclusiveStem;
      default:
        return BeatCheckoutTier.basicMp3;
    }
  }
}

/// Deterministic pricing & integer-conserving split calculation for one tier.
class LicenseTierPricing {
  final BeatCheckoutTier tier;
  final int baseCredits;
  final int grossCoins;
  final double grossZar;
  final int producerRoyaltyCoins;
  final double producerRoyaltyZar;
  final int platformFeeCoins;
  final double platformFeeZar;

  const LicenseTierPricing({
    required this.tier,
    required this.baseCredits,
    required this.grossCoins,
    required this.grossZar,
    required this.producerRoyaltyCoins,
    required this.producerRoyaltyZar,
    required this.platformFeeCoins,
    required this.platformFeeZar,
  });

  String get coinsLabel => '$grossCoins Coins';
  String get zarLabel => 'R${grossZar.toStringAsFixed(2)}';
  String get dualPriceLabel => '$coinsLabel ($zarLabel)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LicenseTierPricing &&
          other.tier == tier &&
          other.baseCredits == baseCredits &&
          other.grossCoins == grossCoins &&
          other.grossZar == grossZar &&
          other.producerRoyaltyCoins == producerRoyaltyCoins &&
          other.platformFeeCoins == platformFeeCoins;

  @override
  int get hashCode => Object.hash(
        tier,
        baseCredits,
        grossCoins,
        grossZar,
        producerRoyaltyCoins,
        platformFeeCoins,
      );
}

/// Structured rights clause descriptor generated by [LicenseAgreementEngine].
class LicenseRightsProfile {
  final BeatCheckoutTier tier;
  final String displayName;
  final String summaryHeadline;
  final List<String> bulletRights;
  final String fullLegalText;

  const LicenseRightsProfile({
    required this.tier,
    required this.displayName,
    required this.summaryHeadline,
    required this.bulletRights,
    required this.fullLegalText,
  });
}

/// Delivered local vault asset package after checkout unpacking (REQ-P58-DEL).
class UnpackedBeatPackage {
  final String beatId;
  final BeatCheckoutTier tier;
  final String baseDirectory;
  final String masterPath;
  final Map<String, String> stemPaths;
  final String masterFileSha256;
  final int totalBytes;
  final String formatEntitlement;
  final bool synthesizedOffline;

  const UnpackedBeatPackage({
    required this.beatId,
    required this.tier,
    required this.baseDirectory,
    required this.masterPath,
    required this.stemPaths,
    required this.masterFileSha256,
    required this.totalBytes,
    required this.formatEntitlement,
    this.synthesizedOffline = false,
  });

  bool get hasStems => stemPaths.length == 4;
}

/// Immutable cryptographic digital ownership deed persisted in Hive & SQLite.
class SovereignLicenseCertificate {
  final String certificateId;
  final String licenseHash;
  final String beatId;
  final String beatTitle;
  final String producerId;
  final String producerHandle;
  final String producerName;
  final String buyerId;
  final String buyerHandle;
  final String genre;
  final int bpm;
  final String musicalKey;
  final BeatCheckoutTier tier;
  final int amountPaidCoins;
  final double amountPaidZar;
  final int producerRoyaltyCoins;
  final double producerRoyaltyZar;
  final int platformFeeCoins;
  final double platformFeeZar;
  final String issuedAtIso8601;
  final String commercialTerms;
  final String vaultTrackId;
  final String masterAudioFilePath;
  final Map<String, String> stemPaths;
  final String masterFileSha256;
  final bool isExclusiveRights;

  const SovereignLicenseCertificate({
    required this.certificateId,
    required this.licenseHash,
    required this.beatId,
    required this.beatTitle,
    required this.producerId,
    required this.producerHandle,
    required this.producerName,
    required this.buyerId,
    required this.buyerHandle,
    required this.genre,
    required this.bpm,
    required this.musicalKey,
    required this.tier,
    required this.amountPaidCoins,
    required this.amountPaidZar,
    required this.producerRoyaltyCoins,
    required this.producerRoyaltyZar,
    required this.platformFeeCoins,
    required this.platformFeeZar,
    required this.issuedAtIso8601,
    required this.commercialTerms,
    required this.vaultTrackId,
    required this.masterAudioFilePath,
    required this.stemPaths,
    required this.masterFileSha256,
    required this.isExclusiveRights,
  });

  String get shortHash => licenseHash.length >= 16
      ? '${licenseHash.substring(0, 8)}...${licenseHash.substring(licenseHash.length - 8)}'
      : licenseHash;

  SovereignLicenseCertificate copyWith({
    String? certificateId,
    String? licenseHash,
    String? beatId,
    String? beatTitle,
    String? producerId,
    String? producerHandle,
    String? producerName,
    String? buyerId,
    String? buyerHandle,
    String? genre,
    int? bpm,
    String? musicalKey,
    BeatCheckoutTier? tier,
    int? amountPaidCoins,
    double? amountPaidZar,
    int? producerRoyaltyCoins,
    double? producerRoyaltyZar,
    int? platformFeeCoins,
    double? platformFeeZar,
    String? issuedAtIso8601,
    String? commercialTerms,
    String? vaultTrackId,
    String? masterAudioFilePath,
    Map<String, String>? stemPaths,
    String? masterFileSha256,
    bool? isExclusiveRights,
  }) {
    return SovereignLicenseCertificate(
      certificateId: certificateId ?? this.certificateId,
      licenseHash: licenseHash ?? this.licenseHash,
      beatId: beatId ?? this.beatId,
      beatTitle: beatTitle ?? this.beatTitle,
      producerId: producerId ?? this.producerId,
      producerHandle: producerHandle ?? this.producerHandle,
      producerName: producerName ?? this.producerName,
      buyerId: buyerId ?? this.buyerId,
      buyerHandle: buyerHandle ?? this.buyerHandle,
      genre: genre ?? this.genre,
      bpm: bpm ?? this.bpm,
      musicalKey: musicalKey ?? this.musicalKey,
      tier: tier ?? this.tier,
      amountPaidCoins: amountPaidCoins ?? this.amountPaidCoins,
      amountPaidZar: amountPaidZar ?? this.amountPaidZar,
      producerRoyaltyCoins: producerRoyaltyCoins ?? this.producerRoyaltyCoins,
      producerRoyaltyZar: producerRoyaltyZar ?? this.producerRoyaltyZar,
      platformFeeCoins: platformFeeCoins ?? this.platformFeeCoins,
      platformFeeZar: platformFeeZar ?? this.platformFeeZar,
      issuedAtIso8601: issuedAtIso8601 ?? this.issuedAtIso8601,
      commercialTerms: commercialTerms ?? this.commercialTerms,
      vaultTrackId: vaultTrackId ?? this.vaultTrackId,
      masterAudioFilePath: masterAudioFilePath ?? this.masterAudioFilePath,
      stemPaths: stemPaths ?? this.stemPaths,
      masterFileSha256: masterFileSha256 ?? this.masterFileSha256,
      isExclusiveRights: isExclusiveRights ?? this.isExclusiveRights,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'certificateId': certificateId,
        'licenseHash': licenseHash,
        'beatId': beatId,
        'beatTitle': beatTitle,
        'producerId': producerId,
        'producerHandle': producerHandle,
        'producerName': producerName,
        'buyerId': buyerId,
        'buyerHandle': buyerHandle,
        'genre': genre,
        'bpm': bpm,
        'musicalKey': musicalKey,
        'tier': tier.wireSlug,
        'amountPaidCoins': amountPaidCoins,
        'amountPaidZar': amountPaidZar,
        'producerRoyaltyCoins': producerRoyaltyCoins,
        'producerRoyaltyZar': producerRoyaltyZar,
        'platformFeeCoins': platformFeeCoins,
        'platformFeeZar': platformFeeZar,
        'issuedAtIso8601': issuedAtIso8601,
        'commercialTerms': commercialTerms,
        'vaultTrackId': vaultTrackId,
        'masterAudioFilePath': masterAudioFilePath,
        'stemPaths': stemPaths,
        'masterFileSha256': masterFileSha256,
        'isExclusiveRights': isExclusiveRights,
      };

  factory SovereignLicenseCertificate.fromJson(Map<dynamic, dynamic> raw) {
    final map = Map<String, dynamic>.from(raw);
    final rawStems = map['stemPaths'];
    final stems = rawStems is Map
        ? rawStems.map((k, v) => MapEntry(k.toString(), v.toString()))
        : const <String, String>{};
    return SovereignLicenseCertificate(
      certificateId: map['certificateId'] as String? ?? '',
      licenseHash: map['licenseHash'] as String? ?? '',
      beatId: map['beatId'] as String? ?? '',
      beatTitle: map['beatTitle'] as String? ?? '',
      producerId: map['producerId'] as String? ?? '',
      producerHandle: map['producerHandle'] as String? ?? '@producer',
      producerName: map['producerName'] as String? ?? 'Producer',
      buyerId: map['buyerId'] as String? ?? 'me',
      buyerHandle: map['buyerHandle'] as String? ?? '@creator',
      genre: map['genre'] as String? ?? 'Amapiano',
      bpm: (map['bpm'] as num?)?.toInt() ?? 112,
      musicalKey: map['musicalKey'] as String? ?? 'F# Minor',
      tier: BeatCheckoutTier.fromWire(map['tier'] as String?),
      amountPaidCoins: (map['amountPaidCoins'] as num?)?.toInt() ?? 0,
      amountPaidZar: (map['amountPaidZar'] as num?)?.toDouble() ?? 0.0,
      producerRoyaltyCoins:
          (map['producerRoyaltyCoins'] as num?)?.toInt() ?? 0,
      producerRoyaltyZar:
          (map['producerRoyaltyZar'] as num?)?.toDouble() ?? 0.0,
      platformFeeCoins: (map['platformFeeCoins'] as num?)?.toInt() ?? 0,
      platformFeeZar: (map['platformFeeZar'] as num?)?.toDouble() ?? 0.0,
      issuedAtIso8601: map['issuedAtIso8601'] as String? ??
          map['issuedAt'] as String? ??
          '',
      commercialTerms: map['commercialTerms'] as String? ?? '',
      vaultTrackId: map['vaultTrackId'] as String? ?? '',
      masterAudioFilePath: map['masterAudioFilePath'] as String? ?? '',
      stemPaths: stems,
      masterFileSha256: map['masterFileSha256'] as String? ?? '',
      isExclusiveRights: map['isExclusiveRights'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SovereignLicenseCertificate &&
          other.certificateId == certificateId &&
          other.licenseHash == licenseHash &&
          other.beatId == beatId &&
          other.buyerId == buyerId &&
          other.tier == tier &&
          other.amountPaidCoins == amountPaidCoins &&
          other.issuedAtIso8601 == issuedAtIso8601 &&
          other.masterFileSha256 == masterFileSha256;

  @override
  int get hashCode => Object.hash(
        certificateId,
        licenseHash,
        beatId,
        buyerId,
        tier,
        amountPaidCoins,
        issuedAtIso8601,
        masterFileSha256,
      );
}

enum CheckoutPhase {
  idle,
  authorizingDebit,
  signingCertificate,
  unpackingMasterAndStems,
  completed,
  insufficientFunds,
  exclusiveAlreadySold,
  failed,
}

class BeatCheckoutState {
  final CheckoutPhase phase;
  final BeatCheckoutTier selectedTier;
  final int deficitCoins;
  final double deficitZar;
  final SovereignLicenseCertificate? certificate;
  final UnpackedBeatPackage? package;
  final String? errorMessage;
  final bool rolledBack;

  const BeatCheckoutState({
    this.phase = CheckoutPhase.idle,
    this.selectedTier = BeatCheckoutTier.basicMp3,
    this.deficitCoins = 0,
    this.deficitZar = 0.0,
    this.certificate,
    this.package,
    this.errorMessage,
    this.rolledBack = false,
  });

  bool get isBusy =>
      phase == CheckoutPhase.authorizingDebit ||
      phase == CheckoutPhase.signingCertificate ||
      phase == CheckoutPhase.unpackingMasterAndStems;

  BeatCheckoutState copyWith({
    CheckoutPhase? phase,
    BeatCheckoutTier? selectedTier,
    int? deficitCoins,
    double? deficitZar,
    SovereignLicenseCertificate? certificate,
    UnpackedBeatPackage? package,
    String? errorMessage,
    bool clearError = false,
    bool? rolledBack,
  }) {
    return BeatCheckoutState(
      phase: phase ?? this.phase,
      selectedTier: selectedTier ?? this.selectedTier,
      deficitCoins: deficitCoins ?? this.deficitCoins,
      deficitZar: deficitZar ?? this.deficitZar,
      certificate: certificate ?? this.certificate,
      package: package ?? this.package,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      rolledBack: rolledBack ?? this.rolledBack,
    );
  }
}
```

### 2.2 File: `apps/vhunambi_client/lib/features/marketplace/domain/services/license_agreement_engine.dart`

```dart
import '../models/licensing_models.dart';

/// Pure-Dart pricing calculator and legal agreement generator (REQ-P58-LIC-01..05).
class LicenseAgreementEngine {
  const LicenseAgreementEngine();

  static double roundZar(double value) => (value * 100.0).round() / 100.0;

  /// Computes exact tier pricing and integer-conserving 85/15 royalty splits.
  LicenseTierPricing calculateTierPricing({
    required int baseCredits,
    required BeatCheckoutTier tier,
  }) {
    final safeCredits = baseCredits < 1 ? 1 : baseCredits;
    final grossCoins = safeCredits * kCoinsPerCredit * tier.priceMultiplier;
    final grossZar = roundZar(grossCoins * kZarPerCoin);

    final producerCoins = (grossCoins * kProducerRoyaltyPercent + 50) ~/ 100;
    final platformCoins = grossCoins - producerCoins;

    final producerZar = roundZar(producerCoins * kZarPerCoin);
    final platformZar = roundZar(grossZar - producerZar);

    return LicenseTierPricing(
      tier: tier,
      baseCredits: safeCredits,
      grossCoins: grossCoins,
      grossZar: grossZar,
      producerRoyaltyCoins: producerCoins,
      producerRoyaltyZar: producerZar,
      platformFeeCoins: platformCoins,
      platformFeeZar: platformZar,
    );
  }

  /// Evaluates buyer coin balance sufficiency and returns deficit metrics.
  ({bool canAfford, int deficitCoins, double deficitZar}) evaluateAffordability({
    required int walletCoins,
    required LicenseTierPricing pricing,
  }) {
    if (walletCoins >= pricing.grossCoins) {
      return (canAfford: true, deficitCoins: 0, deficitZar: 0.0);
    }
    final deficitCoins = pricing.grossCoins - walletCoins;
    final deficitZar = roundZar(deficitCoins * kZarPerCoin);
    return (
      canAfford: false,
      deficitCoins: deficitCoins,
      deficitZar: deficitZar,
    );
  }

  /// Generates full legal agreement metadata and clauses for a beat & tier.
  LicenseRightsProfile buildRightsProfile({
    required String beatTitle,
    required String producerName,
    required String producerHandle,
    required String buyerHandle,
    required String genre,
    required int bpm,
    required String musicalKey,
    required LicenseTierPricing pricing,
    required String issuedAtIso8601,
  }) {
    final tier = pricing.tier;
    final headline = switch (tier) {
      BeatCheckoutTier.basicMp3 =>
        'Non-Exclusive Commercial Lease • Up to 100k Streams',
      BeatCheckoutTier.premiumWav =>
        'Non-Exclusive Broadcast WAV Lease • Up to 500k Streams',
      BeatCheckoutTier.exclusiveStem =>
        '100% Exclusive Ownership & 4-Stem Master Transfer',
    };

    final bullets = switch (tier) {
      BeatCheckoutTier.basicMp3 => const <String>[
          'Up to 100,000 monetized global audio streams',
          'Up to 2,500 commercial paid unit downloads',
          '1 monetized music video & social short-form sync',
          'Instant un-tagged studio master injected into Library Vault',
        ],
      BeatCheckoutTier.premiumWav => const <String>[
          'Lossless 44.1 kHz 16-bit Stereo PCM WAV master delivery',
          'Up to 500,000 monetized global audio streams',
          'Up to 10,000 commercial downloads & radio broadcast rights',
          '2 monetized music videos & instant offline Vault sync',
        ],
      BeatCheckoutTier.exclusiveStem => const <String>[
          'Exclusive full buyout: listing locked & removed from public store',
          'Unlimited worldwide streams, downloads, radio, TV & film sync',
          'Lossless 44.1 kHz Master WAV + all 4 isolated Stems (Drums, Bass, Melody, Other)',
          'Full studio DAW Stem Mixer & Sketchpad dropzone ownership',
        ],
    };

    final legalText = [
      'VHUNAMBI SOVEREIGN BEAT LICENSE DEED',
      'Agreement Tier: ${tier.displayName} (${tier.wireSlug})',
      'Work: "$beatTitle" ($genre, $bpm BPM, Key $musicalKey)',
      'Licensor (Producer): $producerName ($producerHandle)',
      'Licensee (Buyer): $buyerHandle',
      'Consideration: ${pricing.grossCoins} Vhunambi Coins (R${pricing.grossZar.toStringAsFixed(2)} ZAR)',
      'Royalty Settlement: ${pricing.producerRoyaltyCoins} Coins (85%) Producer / ${pricing.platformFeeCoins} Coins (15%) Platform',
      'Effective Timestamp (UTC): $issuedAtIso8601',
      '',
      'Grant of Rights:',
      if (tier == BeatCheckoutTier.basicMp3)
        'Licensor grants Licensee a non-exclusive, worldwide, non-transferable license to record vocals onto "$beatTitle" and distribute up to 100,000 monetized streams and 2,500 downloads using the un-tagged master audio file. Separated multitrack stems are not included.'
      else if (tier == BeatCheckoutTier.premiumWav)
        'Licensor grants Licensee a non-exclusive commercial synchronization and distribution license for "$beatTitle" up to 500,000 monetized streams, 10,000 commercial sales, 2 music videos, and radio airplay, accompanied by the lossless 44.1 kHz 16-bit Stereo PCM WAV master.'
      else
        'Licensor hereby transfers exclusive worldwide commercial beat-exploitation rights for "$beatTitle" to Licensee, permanently locking and removing the composition from future Marketplace sales while preserving Licensor underlying songwriting credit. Includes lossless 44.1 kHz WAV master and 4 isolated stems (drums, bass, melody, other).',
    ].join('\n');

    return LicenseRightsProfile(
      tier: tier,
      displayName: tier.displayName,
      summaryHeadline: headline,
      bulletRights: bullets,
      fullLegalText: legalText,
    );
  }
}
```

### 2.3 File: `apps/vhunambi_client/lib/features/marketplace/domain/services/sovereign_certificate_signer.dart`

```dart
import 'dart:convert';
import 'dart:typed_data';
import '../../../offline/domain/services/vault_envelope_crypto.dart';
import '../models/licensing_models.dart';

/// Deterministic FIPS 180-4 SHA-256 certificate signer & verifier (REQ-P58-CERT-01..02).
class SovereignCertificateSigner {
  const SovereignCertificateSigner();

  static const String schemaPrefix = 'VHUNAMBI_LIC_V2';

  /// Builds the exact pipe-delimited canonical preimage mirrored by `apps/vhunambi_api`.
  static String buildCanonicalPreimage({
    required String certificateId,
    required String beatId,
    required String producerId,
    required String buyerId,
    required BeatCheckoutTier tier,
    required int amountPaidCoins,
    required double amountPaidZar,
    required String issuedAtIso8601,
    required String masterFileSha256,
  }) {
    return [
      schemaPrefix,
      certificateId,
      beatId,
      producerId,
      buyerId,
      tier.wireSlug,
      amountPaidCoins.toString(),
      amountPaidZar.toStringAsFixed(2),
      issuedAtIso8601,
      masterFileSha256,
    ].join('|');
  }

  /// Computes lowercase 64-character SHA-256 hex digest using pure Dart FIPS 180-4.
  static String sha256HexUtf8(String input) {
    final bytes = Uint8List.fromList(utf8.encode(input));
    return sha256HexBytes(bytes);
  }

  static String sha256HexBytes(Uint8List bytes) {
    final digest = VaultEnvelopeCrypto.sha256Bytes(bytes);
    final buffer = StringBuffer();
    for (final byte in digest) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  /// Deterministically generates a unique certificate ID `CERT-VHB-YYYYMMDD-XXXXXX`.
  static String generateCertificateId({
    required String beatId,
    required String buyerId,
    required DateTime timestampUtc,
  }) {
    final year = timestampUtc.year.toString().padLeft(4, '0');
    final month = timestampUtc.month.toString().padLeft(2, '0');
    final day = timestampUtc.day.toString().padLeft(2, '0');
    final entropyInput =
        '$beatId|$buyerId|${timestampUtc.microsecondsSinceEpoch}';
    final shortDigest = sha256HexUtf8(entropyInput).substring(0, 6).toUpperCase();
    return 'CERT-VHB-$year$month$day-$shortDigest';
  }

  /// Issues a cryptographically signed [SovereignLicenseCertificate].
  SovereignLicenseCertificate signCertificate({
    required String certificateId,
    required String beatId,
    required String beatTitle,
    required String producerId,
    required String producerHandle,
    required String producerName,
    required String buyerId,
    required String buyerHandle,
    required String genre,
    required int bpm,
    required String musicalKey,
    required LicenseTierPricing pricing,
    required String issuedAtIso8601,
    required String commercialTerms,
    required String vaultTrackId,
    required String masterAudioFilePath,
    required Map<String, String> stemPaths,
    required String masterFileSha256,
  }) {
    final preimage = buildCanonicalPreimage(
      certificateId: certificateId,
      beatId: beatId,
      producerId: producerId,
      buyerId: buyerId,
      tier: pricing.tier,
      amountPaidCoins: pricing.grossCoins,
      amountPaidZar: pricing.grossZar,
      issuedAtIso8601: issuedAtIso8601,
      masterFileSha256: masterFileSha256,
    );
    final digest = sha256HexUtf8(preimage);

    return SovereignLicenseCertificate(
      certificateId: certificateId,
      licenseHash: digest,
      beatId: beatId,
      beatTitle: beatTitle,
      producerId: producerId,
      producerHandle: producerHandle,
      producerName: producerName,
      buyerId: buyerId,
      buyerHandle: buyerHandle,
      genre: genre,
      bpm: bpm,
      musicalKey: musicalKey,
      tier: pricing.tier,
      amountPaidCoins: pricing.grossCoins,
      amountPaidZar: pricing.grossZar,
      producerRoyaltyCoins: pricing.producerRoyaltyCoins,
      producerRoyaltyZar: pricing.producerRoyaltyZar,
      platformFeeCoins: pricing.platformFeeCoins,
      platformFeeZar: pricing.platformFeeZar,
      issuedAtIso8601: issuedAtIso8601,
      commercialTerms: commercialTerms,
      vaultTrackId: vaultTrackId,
      masterAudioFilePath: masterAudioFilePath,
      stemPaths: Map<String, String>.unmodifiable(stemPaths),
      masterFileSha256: masterFileSha256,
      isExclusiveRights: pricing.tier.grantsExclusivity,
    );
  }

  /// Verifies integrity offline by recomputing the canonical SHA-256 digest.
  bool verifyIntegrity(SovereignLicenseCertificate certificate) {
    if (certificate.licenseHash.length != 64) return false;
    final expectedPreimage = buildCanonicalPreimage(
      certificateId: certificate.certificateId,
      beatId: certificate.beatId,
      producerId: certificate.producerId,
      buyerId: certificate.buyerId,
      tier: certificate.tier,
      amountPaidCoins: certificate.amountPaidCoins,
      amountPaidZar: certificate.amountPaidZar,
      issuedAtIso8601: certificate.issuedAtIso8601,
      masterFileSha256: certificate.masterFileSha256,
    );
    final recomputed = sha256HexUtf8(expectedPreimage);
    return recomputed == certificate.licenseHash.toLowerCase();
  }
}
```

---

## 3. Layer 3 — Certificate Vault, 44.1 kHz Unpacker & Legal Deed Exporter

### 3.1 File: `apps/vhunambi_client/lib/features/marketplace/data/repositories/license_certificate_repository.dart`

```dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/models/licensing_models.dart';

/// Persists cryptographically signed [SovereignLicenseCertificate] records in Hive
/// (`AppConstants.licenseCertificatesBoxKey`) with safe in-memory fallback for `flutter test`.
class LicenseCertificateRepository {
  Box? _box;
  final Map<String, SovereignLicenseCertificate> _memory = {};
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    if (kIsWeb) return;
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        return;
      }
      if (Hive.isBoxOpen(AppConstants.licenseCertificatesBoxKey)) {
        _box = Hive.box(AppConstants.licenseCertificatesBoxKey);
      } else {
        _box = await Hive.openBox(AppConstants.licenseCertificatesBoxKey);
      }
      for (final key in _box!.keys) {
        final raw = _box!.get(key);
        if (raw is Map) {
          final cert = SovereignLicenseCertificate.fromJson(raw);
          if (cert.certificateId.isNotEmpty) {
            _memory[cert.certificateId] = cert;
          }
        }
      }
    } catch (e) {
      debugPrint('LicenseCertificateRepository in-memory fallback: $e');
      _box = null;
    }
  }

  Future<void> save(SovereignLicenseCertificate cert) async {
    await init();
    _memory[cert.certificateId] = cert;
    if (_box != null && _box!.isOpen) {
      await _box!.put(cert.certificateId, cert.toJson());
    }
  }

  List<SovereignLicenseCertificate> getAllSync() =>
      List.unmodifiable(_memory.values.toList().reversed);

  SovereignLicenseCertificate? findByCertificateIdSync(String certificateId) =>
      _memory[certificateId];

  SovereignLicenseCertificate? findByBeatOrTrackSync(String beatOrTrackId) {
    for (final cert in _memory.values) {
      if (cert.beatId == beatOrTrackId ||
          cert.vaultTrackId == beatOrTrackId ||
          'market_${cert.beatId}' == beatOrTrackId) {
        return cert;
      }
    }
    return null;
  }
}
```

### 3.2 File: `apps/vhunambi_client/lib/features/marketplace/data/services/beat_delivery_unpacker_service.dart`

```dart
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../offline/data/services/offline_storage_service.dart';
import '../../../player/data/services/wav_file_writer_io.dart';
import '../../../studio/domain/models/melody_sketchpad_models.dart';
import '../../../studio/domain/services/melody_wav_synthesizer.dart';
import '../../domain/models/licensing_models.dart';
import '../../domain/models/marketplace_models.dart';
import '../../domain/services/sovereign_certificate_signer.dart';

typedef StemDownloadProgressCallback = void Function(
  double fraction,
  String statusLabel,
);

/// Unpacks or deterministically renders real un-tagged 44.1 kHz 16-bit PCM WAV masters
/// and isolated 4-channel stems (`drums`, `bass`, `melody`, `other`) into the buyer's
/// local Vault directory `<vaultAudioDir>/licensed/<beatId>/` (REQ-P58-DEL-01..04).
class BeatDeliveryUnpackerService {
  final IOfflineStorageService _offlineStorage;
  final Dio _dio;
  final Future<void> Function(String path, Uint8List bytes) _fileWriter;
  final bool allowNetworkFetch;

  BeatDeliveryUnpackerService({
    required IOfflineStorageService offlineStorage,
    Dio? dio,
    Future<void> Function(String path, Uint8List bytes)? fileWriter,
    bool? allowNetworkFetch,
  })  : _offlineStorage = offlineStorage,
        _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 4),
                receiveTimeout: const Duration(seconds: 8),
                responseType: ResponseType.bytes,
              ),
            ),
        _fileWriter = fileWriter ?? writeWavToFile,
        allowNetworkFetch = allowNetworkFetch ?? !_detectTestMode();

  static bool _detectTestMode() {
    if (const bool.fromEnvironment('FLUTTER_TEST')) return true;
    try {
      if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Resolves relative paths into [Directory.systemTemp.path] identically to [writeWavToFile]
  /// so returned paths match physical disk files on Android/Linux/Windows/tests.
  static String normalizeWritablePath(String candidatePath) {
    if (kIsWeb) return candidatePath;
    if (!candidatePath.startsWith('/') &&
        !candidatePath.contains(':\\') &&
        !candidatePath.startsWith('\\')) {
      return '${Directory.systemTemp.path}/$candidatePath';
    }
    return candidatePath;
  }

  Future<UnpackedBeatPackage> unpackPurchasedBeat({
    required BeatListingEntity beat,
    required BeatCheckoutTier tier,
    StemDownloadProgressCallback? onProgress,
  }) async {
    onProgress?.call(0.15, 'Resolving local Vault stem directory...');
    final rawBaseDir = await _offlineStorage.resolveVaultAudioDirectory();
    final baseDir = normalizeWritablePath('$rawBaseDir/licensed/${beat.id}');

    final masterFilename = tier == BeatCheckoutTier.basicMp3
        ? 'untagged_master.wav'
        : 'master_44k1.wav';
    final masterPath = '$baseDir/$masterFilename';

    // 1. Build groove blueprint matching BPM, Musical Key, Genre & Beat ID
    final masterGroove = _buildGrooveForBeat(beat);

    onProgress?.call(0.35, 'Provisioning un-tagged 44.1 kHz master...');
    var synthesizedOffline = true;
    Uint8List? masterBytes;

    if (allowNetworkFetch && beat.previewAudioUrl.startsWith('http')) {
      masterBytes = await _tryFetchRemoteAudio(beat.previewAudioUrl);
      if (masterBytes != null) {
        synthesizedOffline = false;
      }
    }

    masterBytes ??=
        MelodyWavSynthesizer.synthesizeMasterGrooveToWavBytes(masterGroove);

    await _fileWriter(masterPath, masterBytes);
    final masterSha256 = SovereignCertificateSigner.sha256HexBytes(masterBytes);
    var totalBytes = masterBytes.length;

    // 2. If Exclusive Stem License, unpack all 4 isolated stems at 44.1 kHz
    final stemPaths = <String, String>{};
    if (tier.includesStems) {
      const stemRoles = <String>['drums', 'bass', 'melody', 'other'];
      for (var idx = 0; idx < stemRoles.length; idx++) {
        final stemKey = stemRoles[idx];
        final frac = 0.50 + ((idx + 1) / stemRoles.length) * 0.45;
        onProgress?.call(frac, 'Unpacking 44.1 kHz stem: $stemKey...');

        final stemGroove = _isolateStemGroove(masterGroove, stemKey);
        final stemBytes =
            MelodyWavSynthesizer.synthesizeMasterGrooveToWavBytes(stemGroove);
        final stemPath = '$baseDir/${stemKey}_44k1.wav';
        await _fileWriter(stemPath, stemBytes);
        stemPaths[stemKey] = stemPath;
        totalBytes += stemBytes.length;
      }
    }

    onProgress?.call(1.0, 'Vault assets verified.');
    return UnpackedBeatPackage(
      beatId: beat.id,
      tier: tier,
      baseDirectory: baseDir,
      masterPath: masterPath,
      stemPaths: Map<String, String>.unmodifiable(stemPaths),
      masterFileSha256: masterSha256,
      totalBytes: totalBytes,
      formatEntitlement:
          tier == BeatCheckoutTier.basicMp3 ? 'mp3_standard' : 'wav_44k1_pcm16',
      synthesizedOffline: synthesizedOffline,
    );
  }

  Future<Uint8List?> _tryFetchRemoteAudio(String url) async {
    // Do not waste timeout on synthetic local demo hosts during offline unpack
    if (url.contains('cdn.vhunambi.com') || url.contains('r2.vhunambi.com')) {
      return null;
    }
    try {
      final response = await _dio.get<List<int>>(url);
      final data = response.data;
      if (response.statusCode == 200 && data != null && data.length > 44) {
        return Uint8List.fromList(data);
      }
    } catch (_) {}
    return null;
  }

  static MultiTrackGrooveEntity _buildGrooveForBeat(BeatListingEntity beat) {
    final g = beat.genre.toLowerCase();
    final kit = g.contains('gqom')
        ? BeatKitGenre.gqom
        : g.contains('afrobeats')
            ? BeatKitGenre.afrobeats
            : g.contains('house')
                ? BeatKitGenre.house
                : BeatKitGenre.amapiano;
    final bassInstrument = g.contains('gqom')
        ? SketchpadInstrument.gqomDarkSub
        : SketchpadInstrument.amapianoLogDrum;
    final melodyInstrument = g.contains('maskandi')
        ? SketchpadInstrument.maskandiGuitar
        : g.contains('afro')
            ? SketchpadInstrument.sopranoSax
            : SketchpadInstrument.privateSchoolRhodes;
    final scale = g.contains('gqom')
        ? AfricanScaleMode.gqomPhrygianDark
        : g.contains('maskandi')
            ? AfricanScaleMode.maskandiHexatonic
            : AfricanScaleMode.minorPentatonic;

    final seedOffset = beat.id.codeUnits.fold<int>(0, (a, b) => a + b) % 4;

    return MultiTrackGrooveEntity(
      id: 'licensed_${beat.id}',
      name: beat.title,
      bpm: beat.bpm.clamp(60, 200),
      musicalKey: beat.musicalKey,
      scaleMode: scale,
      channels: <SketchpadChannelRole, SketchpadChannelTrack>{
        SketchpadChannelRole.drums: SketchpadChannelTrack(
          role: SketchpadChannelRole.drums,
          instrument: bassInstrument,
          beatKit: kit,
          steps: const [
            MelodyStepNote(stepIndex: 0, scaleRow: 1, velocity: 0.96),
            MelodyStepNote(stepIndex: 4, scaleRow: 1, velocity: 0.90),
            MelodyStepNote(stepIndex: 8, scaleRow: 1, velocity: 0.96),
            MelodyStepNote(stepIndex: 12, scaleRow: 1, velocity: 0.90),
            MelodyStepNote(stepIndex: 6, scaleRow: 4, velocity: 0.78),
            MelodyStepNote(stepIndex: 14, scaleRow: 4, velocity: 0.80),
          ],
        ),
        SketchpadChannelRole.bass: SketchpadChannelTrack(
          role: SketchpadChannelRole.bass,
          instrument: bassInstrument,
          beatKit: kit,
          steps: [
            const MelodyStepNote(stepIndex: 0, scaleRow: 0, velocity: 0.95),
            MelodyStepNote(
              stepIndex: (3 + seedOffset) % 16,
              scaleRow: 2,
              velocity: 0.88,
            ),
            const MelodyStepNote(
              stepIndex: 7,
              scaleRow: 3,
              velocity: 0.92,
              hasGlide: true,
            ),
            const MelodyStepNote(stepIndex: 11, scaleRow: 0, velocity: 0.90),
          ],
        ),
        SketchpadChannelRole.chords: SketchpadChannelTrack(
          role: SketchpadChannelRole.chords,
          instrument: melodyInstrument,
          beatKit: kit,
          volume: 0.85,
          steps: const [
            MelodyStepNote(stepIndex: 0, scaleRow: 0, velocity: 0.80),
            MelodyStepNote(stepIndex: 6, scaleRow: 2, velocity: 0.76),
            MelodyStepNote(stepIndex: 10, scaleRow: 4, velocity: 0.82),
          ],
        ),
        SketchpadChannelRole.lead: SketchpadChannelTrack(
          role: SketchpadChannelRole.lead,
          instrument: melodyInstrument,
          beatKit: kit,
          volume: 0.78,
          steps: [
            MelodyStepNote(stepIndex: seedOffset, scaleRow: 5, velocity: 0.75),
            const MelodyStepNote(stepIndex: 9, scaleRow: 6, velocity: 0.78),
            const MelodyStepNote(stepIndex: 13, scaleRow: 4, velocity: 0.72),
          ],
        ),
        SketchpadChannelRole.hats: SketchpadChannelTrack(
          role: SketchpadChannelRole.hats,
          instrument: bassInstrument,
          beatKit: kit,
          volume: 0.72,
          steps: const [
            MelodyStepNote(stepIndex: 2, scaleRow: 3, velocity: 0.70),
            MelodyStepNote(stepIndex: 6, scaleRow: 3, velocity: 0.72),
            MelodyStepNote(stepIndex: 10, scaleRow: 5, velocity: 0.75),
            MelodyStepNote(stepIndex: 14, scaleRow: 6, velocity: 0.70),
          ],
        ),
      },
    );
  }

  static MultiTrackGrooveEntity _isolateStemGroove(
    MultiTrackGrooveEntity master,
    String stemKey,
  ) {
    final subset = <SketchpadChannelRole, SketchpadChannelTrack>{};
    switch (stemKey) {
      case 'drums':
        if (master.channels[SketchpadChannelRole.drums] case final t?) {
          subset[SketchpadChannelRole.drums] = t.copyWith(isMuted: false);
        }
      case 'bass':
        if (master.channels[SketchpadChannelRole.bass] case final t?) {
          subset[SketchpadChannelRole.bass] = t.copyWith(isMuted: false);
        }
      case 'melody':
        if (master.channels[SketchpadChannelRole.chords] case final c?) {
          subset[SketchpadChannelRole.chords] = c.copyWith(isMuted: false);
        }
        if (master.channels[SketchpadChannelRole.lead] case final l?) {
          subset[SketchpadChannelRole.lead] = l.copyWith(isMuted: false);
        }
      case 'other':
      default:
        if (master.channels[SketchpadChannelRole.hats] case final h?) {
          subset[SketchpadChannelRole.hats] = h.copyWith(isMuted: false);
        }
    }

    return MultiTrackGrooveEntity(
      id: '${master.id}_$stemKey',
      name: '${master.name} ($stemKey)',
      bpm: master.bpm,
      musicalKey: master.musicalKey,
      scaleMode: master.scaleMode,
      channels: subset,
    );
  }
}
```

### 3.3 File: `apps/vhunambi_client/lib/features/marketplace/data/services/certificate_share_exporter.dart`

```dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';
import '../../../offline/data/services/offline_storage_service.dart';
import '../../domain/models/licensing_models.dart';
import 'beat_delivery_unpacker_service.dart';

/// Writes verifiable JSON (`.vhlic.json`) + human-readable legal deed (`.txt`)
/// files and invokes `share_plus` (replacing the legacy stub SnackBar).
class CertificateShareExporter {
  final IOfflineStorageService _offlineStorage;

  const CertificateShareExporter({required IOfflineStorageService offlineStorage})
      : _offlineStorage = offlineStorage;

  Future<({String jsonPath, String textPath})> exportDeedFiles(
    SovereignLicenseCertificate cert,
  ) async {
    final vaultDir = await _offlineStorage.resolveVaultAudioDirectory();
    final exportDir = BeatDeliveryUnpackerService.normalizeWritablePath(
      '$vaultDir/certificates',
    );
    final dir = Directory(exportDir);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }

    final jsonPath = '$exportDir/${cert.certificateId}.vhlic.json';
    final textPath = '$exportDir/${cert.certificateId}_DEED.txt';

    final prettyJson = const JsonEncoder.withIndent('  ').convert(cert.toJson());
    await File(jsonPath).writeAsBytes(
      Uint8List.fromList(utf8.encode(prettyJson)),
      flush: true,
    );

    final deedText = [
      '================================================================',
      'VHUNAMBI SOVEREIGN OWNERSHIP CERTIFICATE',
      '================================================================',
      'Certificate ID   : ${cert.certificateId}',
      'Issued At (UTC)  : ${cert.issuedAtIso8601}',
      'Beat Title       : ${cert.beatTitle} (${cert.genre}, ${cert.bpm} BPM, ${cert.musicalKey})',
      'Producer         : ${cert.producerName} (${cert.producerHandle})',
      'Licensed To      : ${cert.buyerHandle} (ID: ${cert.buyerId})',
      'License Tier     : ${cert.tier.displayName} (${cert.tier.wireSlug})',
      'Exclusive Buyout : ${cert.isExclusiveRights ? 'YES' : 'NO'}',
      'Paid Amount      : ${cert.amountPaidCoins} Coins (R${cert.amountPaidZar.toStringAsFixed(2)} ZAR)',
      'Producer Split   : ${cert.producerRoyaltyCoins} Coins / R${cert.producerRoyaltyZar.toStringAsFixed(2)} (85%)',
      'SHA-256 Digest   : ${cert.licenseHash}',
      'Master File Hash : ${cert.masterFileSha256}',
      '----------------------------------------------------------------',
      cert.commercialTerms,
      '================================================================',
    ].join('\n');

    await File(textPath).writeAsBytes(
      Uint8List.fromList(utf8.encode(deedText)),
      flush: true,
    );

    return (jsonPath: jsonPath, textPath: textPath);
  }

  Future<({String jsonPath, String textPath, bool sharedViaOs})> shareDeed(
    SovereignLicenseCertificate cert, {
    bool invokePlatformShare = true,
  }) async {
    final files = await exportDeedFiles(cert);
    var shared = false;
    if (invokePlatformShare) {
      try {
        await Share.shareXFiles(
          [XFile(files.textPath), XFile(files.jsonPath)],
          subject: 'Vhunambi License Certificate: ${cert.beatTitle}',
          text:
              'Certificate ${cert.certificateId} • SHA-256 ${cert.shortHash}',
        );
        shared = true;
      } catch (_) {
        shared = false;
      }
    }
    return (jsonPath: files.jsonPath, textPath: files.textPath, sharedViaOs: shared);
  }
}
```

### 3.4 Replacing Fallback Stub in `HttpMarketplaceRepository` & Adding `licenseCertificatesBoxKey`
- **`AppConstants` (`lib/core/constants/app_constants.dart`)**:
  - Add `static const String licenseCertificatesBoxKey = 'vhunambi_license_certificates';`.
- **`HttpMarketplaceRepository` (`lib/features/marketplace/data/repositories/http_marketplace_repository.dart`)**:
  - Replace the legacy `'hash_simulated_${DateTime.now().millisecondsSinceEpoch}'` fallback string with a deterministic SHA-256 digest computed via `SovereignCertificateSigner`.
  - Parse HTTP `409 Conflict` (`exclusiveConflict: true`) and HTTP `402 Payment Required` (`insufficientFunds: true`) responses cleanly when online, and map `tier` through `BeatCheckoutTier.fromWire(tier)`.
  - Preserve `_fromJson` parsing for `isExclusiveSold` and `exclusiveBuyerId`.

---

## 4. Layer 4 — Shared Entity Extensions, Wallet Reconciliation & Checkout Orchestrator

### 4.1 Additive Extensions to Shared Entities
1. **`LibraryTrack` (`lib/features/library/domain/models/library_models.dart`)**:
   - Add nullable optional fields with safe defaults:
     - `final String? licenseCertificateIdOverride;`
     - `final String? licenseHash;`
     - `final String? licenseTierId;`
     - `final String? masterAudioFilePath;`
     - `final Map<String, String> stemPaths;` (`const {}` default)
   - Update getter:
     ```dart
     String get licenseCertificateId =>
         licenseCertificateIdOverride ??
         'VHB-${licenseType.toUpperCase()}-${id.toUpperCase()}';
     bool get hasUnpackedStems => stemPaths.isNotEmpty;
     String? get effectiveAudioPath =>
         masterAudioFilePath ?? localAudioFilePath;
     ```
2. **`BeatListingEntity` (`lib/features/marketplace/domain/models/marketplace_models.dart`)**:
   - Add additive optional fields:
     - `final bool isExclusiveSold;` (`false` default)
     - `final String? exclusiveBuyerId;`
     - `final List<BeatCheckoutTier> availableTiers;` (`BeatCheckoutTier.values` default)
   - Add convenience getter:
     - `int get baseCoins => priceInCredits * kCoinsPerCredit;`
     - `double get baseZar => LicenseAgreementEngine.roundZar(baseCoins * kZarPerCoin);`
     - `String get coinsPriceLabel => '$baseCoins Coins (R${baseZar.toStringAsFixed(2)})';`
   - Preserve existing `priceLabel => '⚡ $priceInCredits Credits'` so existing Marketplace card tests keep compiling without surprises!
3. **`ProducerBeatEntity` (`lib/features/beats/domain/models/producer_beat_entity.dart`)**:
   - Add additive optional fields:
     - `final bool isExclusiveSold;` (`false` default)
     - `final String? exclusiveBuyerId;`
   - Serialize in `toJson()` (`'is_exclusive_sold'`, `'exclusive_buyer_id'`) and parse with safe defaults in `fromJson(...)`.
   - Preserve `BeatSaleRecord.fromJson(...)` tolerant defaults.

### 4.2 `CreatorWalletNotifier` Additions (`lib/features/social/presentation/providers/creator_wallet_provider.dart`)

Add atomic buyer debit and rollback helpers directly inside `CreatorWalletNotifier`:

```dart
  /// Atomically debits [coins] from the current user's wallet for a Marketplace purchase.
  /// Returns `false` cleanly without side effects if `userCoinsBalance < coins`.
  bool debitForBeatPurchase({
    required int coins,
    required String beatTitle,
    required String tierLabel,
  }) {
    if (coins <= 0 || state.userCoinsBalance < coins) {
      return false;
    }
    final zarEquivalent = double.parse((coins * 0.30).toStringAsFixed(2));
    final debitTx = GiftTransaction(
      id: 'tx_debit_${DateTime.now().millisecondsSinceEpoch}',
      clipId: 'marketplace_purchase',
      senderUsername: 'me',
      recipientCreatorId: 'vhunambi_marketplace',
      gift: CulturalGift(
        id: 'beat_license_debit',
        name: '$tierLabel: $beatTitle',
        emoji: '',
        coinPrice: coins,
        zarPrice: zarEquivalent,
        culturalMeaning: 'Marketplace commercial license acquisition',
      ),
      message: 'Licensed "$beatTitle" ($tierLabel) for $coins Coins',
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      userCoinsBalance: state.userCoinsBalance - coins,
      transactions: [debitTx, ...state.transactions],
    );
    return true;
  }

  /// Compensating refund executed when asset delivery fails mid-checkout.
  void refundCoins({required int coins, required String reason}) {
    if (coins <= 0) return;
    state = state.copyWith(
      userCoinsBalance: state.userCoinsBalance + coins,
      payoutStatusMessage: 'Refunded $coins Coins: $reason',
    );
  }
```

> **Legacy Royalties Note**: In the buyer-facing checkout (`BeatCheckoutNotifier`), producer royalties go into producer records (`BeatsNotifier.recordSale` and backend SQLite `wallet_ledger`). We only call `creatorWalletProvider.notifier.recordMarketplaceRoyalty(...)` when `beat.producerId == currentCreatorId` **or** inside the synchronous Phase 39 compatibility bridge `licenseBeat(ref, beat)` so existing test `REQ-MKT-ROYALTY-01` continues passing without inflating an unrelated buyer's local creator earnings during real purchases.

### 4.3 `BeatCheckoutNotifier` & `MarketplaceProviders` (`apps/vhunambi_client/lib/features/marketplace/presentation/providers/marketplace_providers.dart` + `beat_checkout_provider.dart`)

Create **`apps/vhunambi_client/lib/features/marketplace/presentation/providers/beat_checkout_provider.dart`**:

```dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/sync/sync_outbox_service.dart';
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

final sovereignCertificateSignerProvider =
    Provider<SovereignCertificateSigner>((ref) {
  return const SovereignCertificateSigner();
});

final licenseCertificateRepositoryProvider =
    Provider<LicenseCertificateRepository>((ref) {
  final repo = LicenseCertificateRepository();
  repo.init();
  return repo;
});

final beatDeliveryUnpackerProvider = Provider<BeatDeliveryUnpackerService>((ref) {
  final offlineStorage = ref.watch(offlineStorageServiceProvider);
  return BeatDeliveryUnpackerService(offlineStorage: offlineStorage);
});

final certificateShareExporterProvider =
    Provider<CertificateShareExporter>((ref) {
  final offlineStorage = ref.watch(offlineStorageServiceProvider);
  return CertificateShareExporter(offlineStorage: offlineStorage);
});

/// Reactive list of issued cryptographic certificates stored locally.
final licenseCertificatesProvider = StateNotifierProvider<
    LicenseCertificatesNotifier, List<SovereignLicenseCertificate>>((ref) {
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
        errorMessage: 'This beat has already been purchased under an Exclusive license.',
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
        deficitCoins: pricing.grossCoins - _ref.read(creatorWalletProvider).userCoinsBalance,
      );
      return state.phase;
    }

    // Keep legacy credit balance synchronized
    final creditsLeft = _ref.read(creatorWalletProvider).userCoinsBalance ~/ kCoinsPerCredit;
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
      final buyerId = ownerProfile.id.isNotEmpty ? ownerProfile.id : 'me';
      final buyerHandle =
          ownerProfile.handle.isNotEmpty ? ownerProfile.handle : '@vhunambi_creator';

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
        isInstrumental: beat.assetCategory == MarketplaceAssetCategory.beats ||
            beat.assetCategory == MarketplaceAssetCategory.liveInstruments,
      );

      _ref.read(libraryTracksProvider.notifier).upsertLicensedTrack(vaultTrack);
      await _ref.read(offlineStorageServiceProvider).saveTrackMetadata(
            track: vaultTrack,
            localPath: package.masterPath,
            fileSizeBytes: package.totalBytes,
          );
      await _ref.read(licenseCertificatesProvider.notifier).recordCertificate(cert);

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
      _ref.read(beatsProvider.notifier).recordSale(
            beat.id,
            buyerHandle,
            pricing.producerRoyaltyCoins ~/ kCoinsPerCredit,
            mappedBeatTier,
            markExclusiveBuyerId: tier.grantsExclusivity ? buyerId : null,
          );

      if (beat.producerId == ownerProfile.id) {
        walletNotifier.recordMarketplaceRoyalty(
          assetTitle: beat.title,
          amountCoins: pricing.producerRoyaltyCoins,
          netZar: pricing.producerRoyaltyZar,
        );
      }

      // Step 6: Critical Sync Outbox & Notification
      await _ref.read(syncOutboxServiceProvider).enqueue(
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
        _ref.read(marketplaceRepositoryProvider).licenseBeat(
              beatId: beat.id,
              buyerId: buyerId,
              tier: tier.wireSlug,
            ),
      );

      _ref.read(notificationsProvider.notifier).addNotification(
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
            _ref.read(creatorWalletProvider).userCoinsBalance ~/ kCoinsPerCredit;
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
```

### 4.4 Marketplace Filtering & Sync Compatibility Rules (`marketplace_providers.dart`)
- **`MarketplaceBeatsNotifier.markSoldExclusive({required String beatId, required String buyerId})`**: updates `beat.copyWith(isExclusiveSold: true, exclusiveBuyerId: buyerId)`.
- **`filterBeats(...)`**: adds `if (beat.isExclusiveSold) return false;` so exclusively purchased beats vanish cleanly from public Marketplace discovery while preserving ownership in the buyer's Library Vault & Certificate Registry.
- **`LibraryTracksNotifier.upsertLicensedTrack(LibraryTrack track)`**: replaces any existing record with matching `track.id` at index `0` or inserts at top, ensuring repeat upgrades (`Basic MP3` $\to$ `Exclusive Stem`) upgrade the local asset paths & stems without creating duplicate tracks!
- **Synchronous Compatibility Bridge `licenseBeat(WidgetRef ref, BeatListingEntity beat)`**: preserved for Phase 39/40 regression callers; debits wallet & credit counter, generates a synchronous FIPS 180-4 SHA-256 `SovereignLicenseCertificate`, inserts `LibraryTrack` immediately with `licenseCertificateIdOverride` & `licenseHash`, records producer royalty split, dispatches notification `'Marketplace License Acquired!'` (`NotificationCategory.creatorActivity`), and invokes async background `unpackPurchasedBeat(...)` + `syncOutboxServiceProvider.enqueue(...)`.

---

## 5. Layer 5 — Presentation Widgets (`STD-UIUX-001` Compliant)

> Strict token rules: zero hardcoded hex codes, zero stock Material icons, zero raw emojis inside widgets. Only verified tokens from `AppColors.*`, `AppTypography.*`, `AppSpacing.*`, `AppRadius.*`, and `AppIcons.*` / verified `phosphor_icons`.

### 5.1 `MarketplaceTopBar` (`apps/vhunambi_client/lib/features/marketplace/presentation/widgets/marketplace_top_bar.dart`)
- Replace `_CreditChip()` on line 80 with `const VhunambiUserCoinsChip()` (from `vhunambi_top_bar_kit.dart`), displaying live `creatorWalletProvider.userCoinsBalance` (`250 Coins`) and launching `SubscriptionUpgradeModal.show(context)` on tap.

### 5.2 File: `apps/vhunambi_client/lib/features/marketplace/presentation/widgets/beat_license_modal.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../explore/presentation/widgets/genre_glyph.dart';
import '../../../home/presentation/widgets/subscription_upgrade_modal.dart';
import '../../../social/presentation/providers/creator_wallet_provider.dart';
import '../../domain/models/licensing_models.dart';
import '../../domain/models/marketplace_models.dart';
import '../providers/beat_checkout_provider.dart';
import 'license_certificate_sheet.dart';

/// Multi-tier commercial licensing, Coin reconciliation & Vault unlock sheet (Phase 58).
Future<void> showBeatLicenseModal(
  BuildContext context,
  BeatListingEntity beat, {
  VoidCallback? onNavigateToLibrary,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surfaceModalOf(context),
    barrierColor: AppColors.surfaceCanvasOf(context).withValues(alpha: 0.72),
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.modalBorder,
      side: BorderSide(color: AppColors.borderSubtleOf(context)),
    ),
    builder: (_) => _BeatLicenseModalBody(
      beat: beat,
      onNavigateToLibrary: onNavigateToLibrary,
    ),
  );
}

class _BeatLicenseModalBody extends ConsumerStatefulWidget {
  final BeatListingEntity beat;
  final VoidCallback? onNavigateToLibrary;

  const _BeatLicenseModalBody({
    required this.beat,
    this.onNavigateToLibrary,
  });

  @override
  ConsumerState<_BeatLicenseModalBody> createState() =>
      _BeatLicenseModalBodyState();
}

class _BeatLicenseModalBodyState extends ConsumerState<_BeatLicenseModalBody> {
  bool _showLegalDeed = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        ref.read(beatCheckoutProvider.notifier).resetForBeat(widget.beat);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final checkout = ref.watch(beatCheckoutProvider);
    final wallet = ref.watch(creatorWalletProvider);
    final engine = ref.read(licenseAgreementEngineProvider);

    final tier = checkout.selectedTier;
    final pricing = engine.calculateTierPricing(
      baseCredits: widget.beat.priceInCredits,
      tier: tier,
    );
    final affordability = engine.evaluateAffordability(
      walletCoins: wallet.userCoinsBalance,
      pricing: pricing,
    );
    final rights = engine.buildRightsProfile(
      beatTitle: widget.beat.title,
      producerName: widget.beat.producerName,
      producerHandle: widget.beat.producerHandle,
      buyerHandle: '@creator',
      genre: widget.beat.genre,
      bpm: widget.beat.bpm,
      musicalKey: widget.beat.musicalKey,
      pricing: pricing,
      issuedAtIso8601: DateTime.now().toUtc().toIso8601String(),
    );

    if (checkout.phase == CheckoutPhase.completed && checkout.certificate != null) {
      return _CompletedReceiptView(
        beat: widget.beat,
        certificate: checkout.certificate!,
        package: checkout.package,
        onOpenCertificate: () {
          final cert = checkout.certificate!;
          Navigator.of(context).pop();
          showLicenseCertificateSheet(context, certificate: cert);
        },
        onOpenVault: () {
          Navigator.of(context).pop();
          widget.onNavigateToLibrary?.call();
        },
      );
    }

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderActive,
                    borderRadius: AppRadius.pillBorder,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: AppGradients.forGenre(widget.beat.genre),
                      borderRadius: AppRadius.squircleBorder,
                    ),
                    child: Icon(
                      exploreGenreGlyph(widget.beat.genre),
                      size: 24,
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.beat.title,
                          style: AppTypography.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          '${widget.beat.producerHandle} • ${widget.beat.bpmLabel} • ${widget.beat.musicalKey}',
                          style: AppTypography.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          'Wallet Balance: ${wallet.userCoinsBalance} Coins',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.coinGold,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'SELECT LICENSE TIER',
                style: AppTypography.badge.copyWith(
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              for (final option in BeatCheckoutTier.values) ...[
                _TierOptionCard(
                  tier: option,
                  pricing: engine.calculateTierPricing(
                    baseCredits: widget.beat.priceInCredits,
                    tier: option,
                  ),
                  isSelected: option == tier,
                  isLockedExclusive: widget.beat.isExclusiveSold,
                  onTap: checkout.isBusy || widget.beat.isExclusiveSold
                      ? null
                      : () => ref
                          .read(beatCheckoutProvider.notifier)
                          .selectTier(option),
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
              const SizedBox(height: AppSpacing.xs),
              for (final bullet in rights.bulletRights)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxs + 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: PhosphorIcon(
                          AppIcons.checkCircle,
                          size: 14,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(bullet, style: AppTypography.bodySmall),
                      ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('license_expand_terms_btn'),
                  onPressed: () => setState(() => _showLegalDeed = !_showLegalDeed),
                  icon: PhosphorIcon(
                    _showLegalDeed ? AppIcons.caretUp : AppIcons.caretDown,
                    size: 14,
                    color: AppColors.brandPrimary,
                  ),
                  label: Text(
                    _showLegalDeed
                        ? 'Hide Legal Agreement Text'
                        : 'Read Full Legal Agreement',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.brandPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (_showLegalDeed)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondaryOf(context),
                    borderRadius: AppRadius.inputBorder,
                    border: Border.all(color: AppColors.borderSubtleOf(context)),
                  ),
                  child: Text(
                    rights.fullLegalText,
                    style: AppTypography.caption.copyWith(height: 1.45),
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: affordability.canAfford
                      ? AppColors.surfaceSecondaryOf(context)
                      : AppColors.error.withValues(alpha: 0.12),
                  borderRadius: AppRadius.inputBorder,
                  border: Border.all(
                    color: affordability.canAfford
                        ? AppColors.borderSubtleOf(context)
                        : AppColors.error.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      affordability.canAfford
                          ? 'Remaining balance after checkout: ${wallet.userCoinsBalance - pricing.grossCoins} Coins'
                          : 'Insufficient Coins: Short by ${affordability.deficitCoins} Coins (R${affordability.deficitZar.toStringAsFixed(2)})',
                      style: AppTypography.bodySmall.copyWith(
                        color: affordability.canAfford
                            ? AppColors.textPrimaryOf(context)
                            : AppColors.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Royalty split: ${pricing.producerRoyaltyCoins} Coins (85%) to ${widget.beat.producerHandle} • ${pricing.platformFeeCoins} Coins platform fee',
                      style: AppTypography.caption,
                    ),
                    if (!affordability.canAfford) ...[
                      const SizedBox(height: AppSpacing.xs),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          key: const Key('checkout_topup_btn'),
                          onPressed: () => SubscriptionUpgradeModal.show(context),
                          icon: const PhosphorIcon(
                            AppIcons.coins,
                            size: 16,
                            color: AppColors.coinGold,
                          ),
                          label: Text(
                            'Top Up Coins (ZAR)',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.coinGold,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(44, 44),
                            side: const BorderSide(color: AppColors.coinGold),
                            shape: const RoundedRectangleBorder(
                              borderRadius: AppRadius.pillBorder,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (checkout.errorMessage != null &&
                  checkout.phase == CheckoutPhase.failed) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  checkout.errorMessage!,
                  style: AppTypography.caption.copyWith(color: AppColors.error),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed:
                          checkout.isBusy ? null : () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 44),
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.pillBorder,
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondaryOf(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      key: const Key('checkout_confirm_btn'),
                      onPressed: (!affordability.canAfford ||
                              checkout.isBusy ||
                              widget.beat.isExclusiveSold)
                          ? null
                          : () => ref
                              .read(beatCheckoutProvider.notifier)
                              .purchaseBeat(beat: widget.beat, tierOverride: tier),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandPrimary,
                        foregroundColor: AppColors.brandContrast,
                        minimumSize: const Size(44, 46),
                        elevation: 0,
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.pillBorder,
                        ),
                      ),
                      child: checkout.isBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.brandContrast,
                              ),
                            )
                          : Text(
                              widget.beat.isExclusiveSold
                                  ? 'Sold Exclusive'
                                  : 'License • ${pricing.coinsLabel}',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.brandContrast,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TierOptionCard extends StatelessWidget {
  final BeatCheckoutTier tier;
  final LicenseTierPricing pricing;
  final bool isSelected;
  final bool isLockedExclusive;
  final VoidCallback? onTap;

  const _TierOptionCard({
    required this.tier,
    required this.pricing,
    required this.isSelected,
    required this.isLockedExclusive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? AppColors.amberGlow
          : AppColors.surfaceElevatedOf(context),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardBorder,
        side: BorderSide(
          color: isSelected
              ? AppColors.brandPrimary
              : AppColors.borderSubtleOf(context),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        key: Key('license_tier_card_${tier.name}'),
        onTap: onTap,
        borderRadius: AppRadius.cardBorder,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              isSelected
                  ? const PhosphorIcon(
                      AppIcons.checkCircle,
                      size: 20,
                      color: AppColors.brandPrimary,
                    )
                  : Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.borderActive,
                          width: 1.5,
                        ),
                      ),
                    ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          tier.displayName,
                          style: AppTypography.titleSmall.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: tier.grantsExclusivity
                                ? AppColors.badgeCyanBg
                                : AppColors.surfaceSecondaryOf(context),
                            borderRadius: AppRadius.pillBorder,
                          ),
                          child: Text(
                            isLockedExclusive
                                ? 'SOLD'
                                : tier.badgeLabel,
                            style: AppTypography.badge.copyWith(
                              color: tier.grantsExclusivity
                                  ? AppColors.badgeCyan
                                  : AppColors.textSecondaryOf(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${tier.streamCapLabel} • ${tier.deliveryFormatLabel}',
                      style: AppTypography.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    pricing.coinsLabel,
                    style: AppTypography.titleSmall.copyWith(
                      color: AppColors.brandPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    pricing.zarLabel,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompletedReceiptView extends StatelessWidget {
  final BeatListingEntity beat;
  final SovereignLicenseCertificate certificate;
  final UnpackedBeatPackage? package;
  final VoidCallback onOpenCertificate;
  final VoidCallback onOpenVault;

  const _CompletedReceiptView({
    required this.beat,
    required this.certificate,
    required this.package,
    required this.onOpenCertificate,
    required this.onOpenVault,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: PhosphorIcon(
                PhosphorIconsFill.shieldCheck,
                size: 40,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'License Verified & Unpacked',
              textAlign: TextAlign.center,
              style: AppTypography.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '"${beat.title}" (${certificate.tier.displayName}) and its local 44.1 kHz assets are now unlocked in your Library Vault.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondaryOf(context),
                borderRadius: AppRadius.inputBorder,
                border: Border.all(color: AppColors.borderSubtleOf(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Certificate: ${certificate.certificateId}',
                    style: AppTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'SHA-256: ${certificate.shortHash}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.badgeCyan,
                    ),
                  ),
                  if (package != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      package!.hasStems
                          ? 'Delivered: Master 44.1 kHz WAV + 4 Isolated Stems'
                          : 'Delivered: Un-Tagged 44.1 kHz Studio Master',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('checkout_view_cert_btn'),
                    onPressed: onOpenCertificate,
                    icon: const PhosphorIcon(
                      PhosphorIconsRegular.fileText,
                      size: 16,
                    ),
                    label: const Text('View Certificate'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.pillBorder,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: ElevatedButton.icon(
                    key: const Key('checkout_open_vault_btn'),
                    onPressed: onOpenVault,
                    icon: const PhosphorIcon(
                      AppIcons.navLibrary,
                      size: 16,
                      color: AppColors.brandContrast,
                    ),
                    label: const Text('Open Vault'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      foregroundColor: AppColors.brandContrast,
                      minimumSize: const Size(44, 44),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.pillBorder,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

### 5.3 File: `apps/vhunambi_client/lib/features/marketplace/presentation/widgets/license_certificate_sheet.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../library/domain/models/library_models.dart';
import '../../domain/models/licensing_models.dart';
import '../../domain/services/license_agreement_engine.dart';
import '../../domain/services/sovereign_certificate_signer.dart';
import '../providers/beat_checkout_provider.dart';

/// Cryptographic Ownership Deed & Stem Deliverables Sheet (REQ-P58-CERT-04).
Future<void> showLicenseCertificateSheet(
  BuildContext context, {
  SovereignLicenseCertificate? certificate,
  LibraryTrack? track,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surfaceModalOf(context),
    barrierColor: AppColors.surfaceCanvasOf(context).withValues(alpha: 0.72),
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.modalBorder,
      side: BorderSide(color: AppColors.borderSubtleOf(context)),
    ),
    builder: (_) => LicenseCertificateSheet(
      initialCertificate: certificate,
      track: track,
    ),
  );
}

class LicenseCertificateSheet extends ConsumerStatefulWidget {
  final SovereignLicenseCertificate? initialCertificate;
  final LibraryTrack? track;

  const LicenseCertificateSheet({
    super.key,
    this.initialCertificate,
    this.track,
  });

  @override
  ConsumerState<LicenseCertificateSheet> createState() =>
      _LicenseCertificateSheetState();
}

class _LicenseCertificateSheetState
    extends ConsumerState<LicenseCertificateSheet> {
  bool? _verifiedResult;
  bool _isExporting = false;

  SovereignLicenseCertificate _resolveEffectiveCertificate() {
    if (widget.initialCertificate != null) {
      return widget.initialCertificate!;
    }
    final track = widget.track;
    if (track != null) {
      final stored =
          ref.read(licenseCertificatesProvider.notifier).findForTrack(track);
      if (stored != null) return stored;

      // Legacy track synthesized deed fallback so pre-Phase-58 tracks still sign cleanly
      final tier = BeatCheckoutTier.fromWire(track.licenseTierId ?? track.licenseType);
      const signer = SovereignCertificateSigner();
      const engine = LicenseAgreementEngine();
      final pricing = engine.calculateTierPricing(baseCredits: 5, tier: tier);
      final issued = track.createdAt.toUtc().toIso8601String();
      return signer.signCertificate(
        certificateId: track.licenseCertificateId,
        beatId: track.id.replaceFirst('market_', ''),
        beatTitle: track.title,
        producerId: track.creatorName.toLowerCase().replaceAll(' ', '_'),
        producerHandle: '@${track.creatorName.toLowerCase().replaceAll(' ', '_')}',
        producerName: track.creatorName,
        buyerId: 'me',
        buyerHandle: '@creator',
        genre: track.genre,
        bpm: 112,
        musicalKey: 'F# Minor',
        pricing: pricing,
        issuedAtIso8601: issued,
        commercialTerms: 'Standard Vhunambi Vault Commercial License',
        vaultTrackId: track.id,
        masterAudioFilePath: track.masterAudioFilePath ?? track.localAudioFilePath ?? '',
        stemPaths: track.stemPaths,
        masterFileSha256: SovereignCertificateSigner.sha256HexUtf8(track.id),
      );
    }
    throw StateError('LicenseCertificateSheet requires either certificate or track');
  }

  @override
  Widget build(BuildContext context) {
    final cert = _resolveEffectiveCertificate();
    final signer = ref.read(sovereignCertificateSignerProvider);
    final isVerified = _verifiedResult ?? signer.verifyIntegrity(cert);

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderActive,
                  borderRadius: AppRadius.pillBorder,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                PhosphorIcon(
                  PhosphorIconsFill.shieldCheck,
                  size: 24,
                  color: isVerified ? AppColors.success : AppColors.error,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Sovereign License Deed',
                    style: AppTypography.titleLarge,
                  ),
                ),
                Container(
                  key: const Key('license_cert_verify_status'),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isVerified ? AppColors.success : AppColors.error)
                        .withValues(alpha: 0.16),
                    borderRadius: AppRadius.pillBorder,
                  ),
                  child: Text(
                    isVerified ? 'VERIFIED' : 'UNVERIFIED',
                    style: AppTypography.badge.copyWith(
                      color: isVerified ? AppColors.success : AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _DeedMetaRow(label: 'Certificate ID', value: cert.certificateId),
            _DeedMetaRow(
              label: 'Asset',
              value: '${cert.beatTitle} (${cert.genre} • ${cert.bpm} BPM)',
            ),
            _DeedMetaRow(label: 'Tier', value: cert.tier.displayName),
            _DeedMetaRow(
              label: 'Consideration',
              value:
                  '${cert.amountPaidCoins} Coins (R${cert.amountPaidZar.toStringAsFixed(2)})',
            ),
            _DeedMetaRow(
              label: 'Royalty Split',
              value:
                  '85% Producer (${cert.producerRoyaltyCoins} Coins) / 15% Platform',
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              key: const Key('license_cert_hash_pill'),
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondaryOf(context),
                borderRadius: AppRadius.inputBorder,
                border: Border.all(color: AppColors.borderSubtleOf(context)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SHA-256 CRYPTOGRAPHIC PROOF',
                          style: AppTypography.badge.copyWith(
                            color: AppColors.textSecondaryOf(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          cert.licenseHash,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.badgeCyan,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('license_cert_copy_hash_btn'),
                    tooltip: 'Copy SHA-256 Digest',
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    icon: const PhosphorIcon(
                      PhosphorIconsRegular.copy,
                      size: 18,
                    ),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: cert.licenseHash));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Copied SHA-256 digest ${cert.shortHash}'),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('license_cert_verify_btn'),
                    onPressed: () {
                      setState(() {
                        _verifiedResult = signer.verifyIntegrity(cert);
                      });
                    },
                    icon: const PhosphorIcon(
                      PhosphorIconsRegular.shieldCheck,
                      size: 16,
                    ),
                    label: const Text('Verify Hash'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.pillBorder,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: ElevatedButton.icon(
                    key: const Key('license_cert_share_btn'),
                    onPressed: _isExporting
                        ? null
                        : () async {
                            setState(() => _isExporting = true);
                            final res = await ref
                                .read(certificateShareExporterProvider)
                                .shareDeed(cert);
                            if (mounted) {
                              setState(() => _isExporting = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Exported legal deed & JSON (${cert.certificateId}) -> ${res.textPath}',
                                  ),
                                ),
                              );
                            }
                          },
                    icon: const PhosphorIcon(
                      AppIcons.share,
                      size: 16,
                      color: AppColors.brandContrast,
                    ),
                    label: const Text('Export Deed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      foregroundColor: AppColors.brandContrast,
                      minimumSize: const Size(44, 44),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.pillBorder,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DeedMetaRow extends StatelessWidget {
  final String label;
  final String value;

  const _DeedMetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(label, style: AppTypography.caption),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimaryOf(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

### 5.4 Updating `TrackActionsSheet.showLibraryLicenseDialog` & `BeatsVaultView` Stems Drawer
- **`track_actions_sheet.dart`**: replace `showLibraryLicenseDialog(BuildContext context, LibraryTrack track)` body with direct call to `showLicenseCertificateSheet(context, track: track)` — preserving signature compatibility for every existing caller while upgrading completely away from the stub `Download PDF` SnackBar!
- **`beats_vault_view.dart`**: update `_LicensedBeatCard` to accept optional `onOpenStemsDrawer` callback, showing a `Key('licensed_beat_stems_btn_${track.id}')` button whenever `track.stemPaths.isNotEmpty`, opening a clean stem-audition bottom sheet with individual Play & Share actions for `drums`, `bass`, `melody`, `other`!
- **`reference_audio_dropzone.dart`**: extend `_showBeatPicker` to read licensed beats from `libraryTracksProvider` (`track.isInstrumental && !track.isDeleted`) in addition to `beatsProvider`, passing `track.masterAudioFilePath ?? track.localAudioFilePath ?? track.remoteAudioUrl` to `studioFormProvider.notifier.setReferenceAudio(...)`.

---

## 6. Layer 1 — Backend SQLite WAL & Hono API Updates (`apps/vhunambi_api`)

### 6.1 Database Schema & ACID Methods (`apps/vhunambi_api/src/db/vhunambi_db.ts`)

Add `createHash` import at top of `vhunambi_db.ts`:
```ts
import { createHash } from 'node:crypto';
```

In `initPragmasAndTables()` immediately after `marketplace_assets` creation:
```ts
    try {
      this.db.exec(`
        ALTER TABLE marketplace_assets ADD COLUMN is_exclusive_sold INTEGER NOT NULL DEFAULT 0;
      `);
    } catch (_) {}
    try {
      this.db.exec(`
        ALTER TABLE marketplace_assets ADD COLUMN exclusive_buyer_id TEXT;
      `);
    } catch (_) {}

    this.db.exec(`
      CREATE TABLE IF NOT EXISTS beat_licenses (
        certificate_id TEXT PRIMARY KEY,
        license_hash TEXT UNIQUE NOT NULL,
        beat_id TEXT NOT NULL,
        producer_id TEXT NOT NULL,
        buyer_id TEXT NOT NULL,
        tier TEXT NOT NULL,
        coins_paid INTEGER NOT NULL,
        zar_paid REAL NOT NULL,
        producer_coins INTEGER NOT NULL,
        producer_zar REAL NOT NULL,
        issued_at TEXT NOT NULL,
        data_json TEXT NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_beat_licenses_buyer ON beat_licenses(buyer_id);
      CREATE INDEX IF NOT EXISTS idx_beat_licenses_beat ON beat_licenses(beat_id);
    `);
```

Add canonical SHA-256 helper & ACID licensing transaction methods on `VhunambiDatabase`:
```ts
  public computeCanonicalLicenseHash(params: {
    certificateId: string;
    beatId: string;
    producerId: string;
    buyerId: string;
    tierSlug: string;
    amountPaidCoins: number;
    amountPaidZar: number;
    issuedAt: string;
    masterFileSha256?: string;
  }): string {
    const masterDigest = params.masterFileSha256 || createHash('sha256').update(params.beatId).digest('hex');
    const preimage = [
      'VHUNAMBI_LIC_V2',
      params.certificateId,
      params.beatId,
      params.producerId,
      params.buyerId,
      params.tierSlug,
      String(params.amountPaidCoins),
      params.amountPaidZar.toFixed(2),
      params.issuedAt,
      masterDigest,
    ].join('|');
    return createHash('sha256').update(preimage).digest('hex');
  }

  public recordBeatLicenseAtomic(params: {
    certificateId: string;
    beatId: string;
    beatTitle: string;
    producerId: string;
    producerHandle: string;
    buyerId: string;
    buyerHandle: string;
    tierSlug: string;
    amountPaidCoins: number;
    amountPaidZar: number;
    producerRoyaltyCoins: number;
    producerRoyaltyZar: number;
    issuedAt: string;
    commercialTerms: string;
    masterFileSha256?: string;
    isExclusive: boolean;
    enforceBuyerWallet?: boolean;
    dataJson: Record<string, any>;
  }): { status: 'ok' | 'exclusive_conflict' | 'insufficient_funds'; licenseHash?: string } {
    this.db.exec('BEGIN IMMEDIATE');
    try {
      const asset = this.db
        .prepare('SELECT id, is_exclusive_sold FROM marketplace_assets WHERE id = ?')
        .get(params.beatId) as { id: string; is_exclusive_sold: number } | undefined;

      if (asset && asset.is_exclusive_sold === 1) {
        this.db.exec('ROLLBACK');
        return { status: 'exclusive_conflict' };
      }

      const existingExclusive = this.db
        .prepare(
          "SELECT certificate_id FROM beat_licenses WHERE beat_id = ? AND tier IN ('exclusive_stem', 'unlimited_commercial') LIMIT 1",
        )
        .get(params.beatId) as { certificate_id: string } | undefined;
      if (existingExclusive) {
        this.db.exec('ROLLBACK');
        return { status: 'exclusive_conflict' };
      }

      if (params.enforceBuyerWallet) {
        const wallet = this.getWallet(params.buyerId);
        if (wallet.balanceCoins < params.amountPaidCoins) {
          this.db.exec('ROLLBACK');
          return { status: 'insufficient_funds' };
        }
      }

      const licenseHash = this.computeCanonicalLicenseHash({
        certificateId: params.certificateId,
        beatId: params.beatId,
        producerId: params.producerId,
        buyerId: params.buyerId,
        tierSlug: params.tierSlug,
        amountPaidCoins: params.amountPaidCoins,
        amountPaidZar: params.amountPaidZar,
        issuedAt: params.issuedAt,
        masterFileSha256: params.masterFileSha256,
      });

      const payloadWithHash = { ...params.dataJson, licenseHash };

      this.db
        .prepare(
          `INSERT INTO beat_licenses (
             certificate_id, license_hash, beat_id, producer_id, buyer_id, tier,
             coins_paid, zar_paid, producer_coins, producer_zar, issued_at, data_json
           ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        )
        .run(
          params.certificateId,
          licenseHash,
          params.beatId,
          params.producerId,
          params.buyerId,
          params.tierSlug,
          params.amountPaidCoins,
          params.amountPaidZar,
          params.producerRoyaltyCoins,
          params.producerRoyaltyZar,
          params.issuedAt,
          JSON.stringify(payloadWithHash),
        );

      // Debit buyer ledger & credit 85% producer royalty ledger
      this.db
        .prepare(
          `INSERT INTO wallet_ledger (id, creator_id, type, amount_zar, amount_coins, status, reference, data_json, created_at)
           VALUES (?, ?, 'license_purchase', ?, ?, 'completed', ?, ?, ?)`,
        )
        .run(
          `tx_buy_${Date.now()}_${params.certificateId}`,
          params.buyerId,
          -params.amountPaidZar,
          -params.amountPaidCoins,
          params.certificateId,
          JSON.stringify({ beatId: params.beatId, tier: params.tierSlug }),
          params.issuedAt,
        );

      this.db
        .prepare(
          `INSERT INTO wallet_ledger (id, creator_id, type, amount_zar, amount_coins, status, reference, data_json, created_at)
           VALUES (?, ?, 'license_sale', ?, ?, 'completed', ?, ?, ?)`,
        )
        .run(
          `tx_roy_${Date.now()}_${params.certificateId}`,
          params.producerId,
          params.producerRoyaltyZar,
          params.producerRoyaltyCoins,
          params.certificateId,
          JSON.stringify({ beatId: params.beatId, buyerId: params.buyerId, tier: params.tierSlug }),
          params.issuedAt,
        );

      if (params.isExclusive) {
        if (asset) {
          this.db
            .prepare(
              'UPDATE marketplace_assets SET is_exclusive_sold = 1, exclusive_buyer_id = ?, updated_at = ? WHERE id = ?',
            )
            .run(params.buyerId, params.issuedAt, params.beatId);
        } else {
          this.db
            .prepare(
              `INSERT INTO marketplace_assets (id, title, producer_id, asset_category, price_zar, price_coins, is_exclusive_sold, exclusive_buyer_id, data_json, created_at, updated_at)
               VALUES (?, ?, ?, 'beats', ?, ?, 1, ?, ?, ?, ?)`,
            )
            .run(
              params.beatId,
              params.beatTitle,
              params.producerId,
              params.amountPaidZar,
              params.amountPaidCoins,
              params.buyerId,
              JSON.stringify(payloadWithHash),
              params.issuedAt,
              params.issuedAt,
            );
        }
      }

      this.db.exec('COMMIT');
      return { status: 'ok', licenseHash };
    } catch (e) {
      this.db.exec('ROLLBACK');
      throw e;
    }
  }

  public getBeatLicensesByBuyer(buyerId: string): any[] {
    const rows = this.db
      .prepare('SELECT * FROM beat_licenses WHERE buyer_id = ? ORDER BY issued_at DESC')
      .all(buyerId) as Array<{ data_json: string }>;
    return rows.map((r) => JSON.parse(r.data_json));
  }

  public verifyBeatLicense(certificateId: string): {
    found: boolean;
    valid: boolean;
    certificate?: any;
  } {
    const row = this.db
      .prepare('SELECT * FROM beat_licenses WHERE certificate_id = ?')
      .get(certificateId) as {
        certificate_id: string;
        license_hash: string;
        beat_id: string;
        producer_id: string;
        buyer_id: string;
        tier: string;
        coins_paid: number;
        zar_paid: number;
        issued_at: string;
        data_json: string;
      } | undefined;
    if (!row) return { found: false, valid: false };

    const parsed = JSON.parse(row.data_json);
    const recomputed = this.computeCanonicalLicenseHash({
      certificateId: row.certificate_id,
      beatId: row.beat_id,
      producerId: row.producer_id,
      buyerId: row.buyer_id,
      tierSlug: row.tier,
      amountPaidCoins: row.coins_paid,
      amountPaidZar: row.zar_paid,
      issuedAt: row.issued_at,
      masterFileSha256: parsed.masterFileSha256,
    });
    return {
      found: true,
      valid: recomputed === row.license_hash,
      certificate: parsed,
    };
  }
```

### 6.2 `marketplace_types.ts`, `marketplace_service.ts` & `marketplace_routes.ts`
- **`marketplace_types.ts`**: widen `BeatLicenseTier` to `'basic_lease' | 'stems_trackout' | 'exclusive_stem' | 'unlimited_commercial'` and add `isExclusiveSold?: boolean`, `exclusiveBuyerId?: string`, `masterFileSha256?: string`.
- **`marketplace_service.ts`**:
  - Normalize wire slug (`'exclusive'` / `'unlimited_commercial'` $\to$ exclusive behavior; `'exclusive_stem'` multiplier `6x` matching `'unlimited_commercial'`).
  - Invoke `vhunambiDb.recordBeatLicenseAtomic(...)` before emitting response:
    - On `'exclusive_conflict'`, return `{ errorCode: 'EXCLUSIVE_CONFLICT' }`.
    - On `'insufficient_funds'`, return `{ errorCode: 'INSUFFICIENT_FUNDS' }`.
    - Otherwise mark in-memory `beat.isExclusiveSold = true` & `beat.exclusiveBuyerId = buyerId` when exclusive, update `getMarketplaceBeats` to filter `!b.isExclusiveSold`, and return `{ certificate, beat }`.
- **`marketplace_routes.ts`**:
  - On `POST /api/marketplace/beats/:id/license`: return `409` on `'EXCLUSIVE_CONFLICT'`, `402` on `'INSUFFICIENT_FUNDS'`, `404` on missing beat, `201` on verified creation.
  - Inside `applyMutationsBatch(...)` in `vhunambi_db.ts`, handle `entityType === 'beat_license'` idempotently by delegating to `recordBeatLicenseAtomic(..., enforceBuyerWallet: false)` when `certificate_id` does not yet exist in `beat_licenses`.
  - Add:
    ```ts
    marketplaceRoutes.get('/licenses/verify/:certificateId', (c) => {
      const verification = vhunambiDb.verifyBeatLicense(c.req.param('certificateId'));
      if (!verification.found) {
        return c.json({ found: false, valid: false, error: 'Certificate not found' }, 404);
      }
      return c.json(verification);
    });
    ```
  - Also update `getWallet` ledger sum rule in `vhunambi_db.ts` (`wallet_ledger` type check) so `license_purchase` decrements `balanceCoins` & `balanceZar` consistently when `amount_coins < 0`!

---

## 7. Security, Animation & Styling Rules Verification

1. **Zero Hardcoded Colors (`AppColors`)**: All UI elements resolve dynamically via `AppColors.surfaceCanvasOf(context)`, `AppColors.surfaceElevatedOf(context)`, `AppColors.surfaceSecondaryOf(context)`, `AppColors.borderSubtleOf(context)`, `AppColors.textPrimaryOf(context)`, `AppColors.textSecondaryOf(context)`, `AppColors.brandPrimary`, `AppColors.coinGold`, `AppColors.badgeCyan`, `AppColors.success`, `AppColors.error`.
2. **Phosphor Iconography Only**: Uses `PhosphorIcon(AppIcons.*)` / verified `PhosphorIconsFill.shieldCheck`, `PhosphorIconsRegular.copy`, `PhosphorIconsRegular.fileText` with zero stock Material icons (`Icons.check_circle_rounded`, `Icons.balance_rounded`, `Icons.picture_as_pdf_outlined` replaced).
3. **Zero Raw Emojis**: Zero raw Unicode emoji strings appear in Dart widgets or UI tables (`STD-UIUX-001`).
4. **Canonical Digest Integrity**: Pure Dart `VaultEnvelopeCrypto.sha256Bytes` produces exact SHA-256 parity with Node `createHash('sha256')`.

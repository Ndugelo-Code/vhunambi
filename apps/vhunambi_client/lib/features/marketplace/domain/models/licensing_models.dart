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
    deliveryFormatLabel:
        '44.1 kHz Master WAV + 4 Isolated Stems (Drums, Bass, Melody, Other)',
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

  String get streamCapLabel => streamCap == null
      ? 'Unlimited streams'
      : '${streamCap! ~/ 1000}k streams';

  /// Accepts Phase 58 slugs and legacy Phase 14/28 wire strings.
  static BeatCheckoutTier fromWire(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    switch (normalized) {
      case 'basic_lease':
      case 'basic_mp3':
      case 'basicmp3':
      case 'basic mp3':
      case 'basic mp3 lease':
      case 'personal':
      case 'personal_lease':
      case 'personallease':
      case 'non-exclusive commercial':
      case 'nonexclusive commercial':
        return BeatCheckoutTier.basicMp3;
      case 'stems_trackout':
      case 'premium_wav':
      case 'premiumwav':
      case 'premium wav':
      case 'premium wav license':
      case 'sync':
      case 'synclicense':
      case 'nonexclusivecommercial':
        return BeatCheckoutTier.premiumWav;
      case 'exclusive_stem':
      case 'exclusivestem':
      case 'exclusive stem':
      case 'exclusive stem license':
      case 'unlimited_commercial':
      case 'exclusive':
      case 'exclusiveownership':
      case 'exclusive commercial master license':
        return BeatCheckoutTier.exclusiveStem;
      default:
        if (normalized.contains('non-exclusive') ||
            normalized.contains('nonexclusive') ||
            normalized.contains('basic')) {
          return BeatCheckoutTier.basicMp3;
        }
        if (normalized.contains('premium') || normalized.contains('trackout')) {
          return BeatCheckoutTier.premiumWav;
        }
        if (normalized.contains('exclusive') ||
            normalized.contains('unlimited')) {
          return BeatCheckoutTier.exclusiveStem;
        }
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
      producerRoyaltyCoins: (map['producerRoyaltyCoins'] as num?)?.toInt() ?? 0,
      producerRoyaltyZar:
          (map['producerRoyaltyZar'] as num?)?.toDouble() ?? 0.0,
      platformFeeCoins: (map['platformFeeCoins'] as num?)?.toInt() ?? 0,
      platformFeeZar: (map['platformFeeZar'] as num?)?.toDouble() ?? 0.0,
      issuedAtIso8601:
          map['issuedAtIso8601'] as String? ?? map['issuedAt'] as String? ?? '',
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

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


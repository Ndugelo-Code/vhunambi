import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/marketplace/domain/models/licensing_models.dart';
import 'package:vhunambi_client/features/marketplace/domain/services/license_agreement_engine.dart';
import 'package:vhunambi_client/features/marketplace/domain/services/sovereign_certificate_signer.dart';

void main() {
  group('Phase 58 Licensing Domain & Cryptography', () {
    const engine = LicenseAgreementEngine();
    const signer = SovereignCertificateSigner();

    test('BeatCheckoutTier multipliers and wire slug compatibility', () {
      expect(BeatCheckoutTier.basicMp3.priceMultiplier, 1);
      expect(BeatCheckoutTier.premiumWav.priceMultiplier, 3);
      expect(BeatCheckoutTier.exclusiveStem.priceMultiplier, 6);

      expect(BeatCheckoutTier.fromWire('basic_lease'), BeatCheckoutTier.basicMp3);
      expect(
        BeatCheckoutTier.fromWire('stems_trackout'),
        BeatCheckoutTier.premiumWav,
      );
      expect(
        BeatCheckoutTier.fromWire('exclusive_stem'),
        BeatCheckoutTier.exclusiveStem,
      );
      expect(
        BeatCheckoutTier.fromWire('exclusive'),
        BeatCheckoutTier.exclusiveStem,
      );
      expect(
        BeatCheckoutTier.fromWire('unlimited_commercial'),
        BeatCheckoutTier.exclusiveStem,
      );
      expect(
        BeatCheckoutTier.fromWire('Exclusive Commercial Master License'),
        BeatCheckoutTier.exclusiveStem,
      );
      expect(
        BeatCheckoutTier.fromWire('Non-Exclusive Commercial'),
        BeatCheckoutTier.basicMp3,
      );
    });

    test('LicenseAgreementEngine enforces exact integer 85/15 conservation', () {
      for (final credits in [1, 5, 7, 13, 99]) {
        for (final tier in BeatCheckoutTier.values) {
          final pricing = engine.calculateTierPricing(
            baseCredits: credits,
            tier: tier,
          );
          expect(
            pricing.grossCoins,
            credits * kCoinsPerCredit * tier.priceMultiplier,
          );
          expect(
            pricing.producerRoyaltyCoins + pricing.platformFeeCoins,
            pricing.grossCoins,
          );
          expect(
            (pricing.producerRoyaltyZar + pricing.platformFeeZar - pricing.grossZar)
                .abs(),
            lessThan(0.011),
          );
        }
      }

      final affLow = engine.evaluateAffordability(
        walletCoins: 40,
        pricing: engine.calculateTierPricing(
          baseCredits: 5,
          tier: BeatCheckoutTier.premiumWav,
        ),
      );
      expect(affLow.canAfford, isFalse);
      expect(affLow.deficitCoins, 35);
      expect(affLow.deficitZar, closeTo(10.50, 0.001));
    });

    test('SovereignCertificateSigner matches NIST SHA-256 vectors', () {
      expect(
        SovereignCertificateSigner.sha256HexUtf8(''),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
      expect(
        SovereignCertificateSigner.sha256HexUtf8('abc'),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('Signed certificate verifies cleanly and rejects any 1-char tamper', () {
      final pricing = engine.calculateTierPricing(
        baseCredits: 5,
        tier: BeatCheckoutTier.exclusiveStem,
      );
      final masterHash = SovereignCertificateSigner.sha256HexUtf8('master_pcm');
      final cert = signer.signCertificate(
        certificateId: 'CERT-VHB-20261109-ABC123',
        beatId: 'beat_township_heat',
        beatTitle: 'Township Heat',
        producerId: 'creator_sipho',
        producerHandle: '@sipho_beats',
        producerName: 'Sipho',
        buyerId: 'user_ndugelo',
        buyerHandle: '@ndugelo',
        genre: 'Amapiano',
        bpm: 112,
        musicalKey: 'F# Minor',
        pricing: pricing,
        issuedAtIso8601: '2026-11-09T10:00:00.000Z',
        commercialTerms: 'Exclusive Terms',
        vaultTrackId: 'market_beat_township_heat',
        masterAudioFilePath: '/tmp/master_44k1.wav',
        stemPaths: const {'drums': '/tmp/drums_44k1.wav'},
        masterFileSha256: masterHash,
      );

      expect(cert.licenseHash.length, 64);
      expect(cert.isExclusiveRights, isTrue);
      expect(signer.verifyIntegrity(cert), isTrue);

      // Tampering amount, beatId, hash, or master hash breaks verification
      expect(
        signer.verifyIntegrity(cert.copyWith(amountPaidCoins: 1)),
        isFalse,
      );
      expect(
        signer.verifyIntegrity(cert.copyWith(beatId: 'beat_other')),
        isFalse,
      );
      expect(
        signer.verifyIntegrity(cert.copyWith(masterFileSha256: '0' * 64)),
        isFalse,
      );

      // JSON round-trip preserves hash & equality
      final decoded = SovereignLicenseCertificate.fromJson(cert.toJson());
      expect(decoded, equals(cert));
      expect(signer.verifyIntegrity(decoded), isTrue);
    });
  });
}


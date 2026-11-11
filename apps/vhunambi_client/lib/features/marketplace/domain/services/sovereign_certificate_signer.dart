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


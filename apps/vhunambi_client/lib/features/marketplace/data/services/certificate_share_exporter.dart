import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';
import '../../../offline/data/services/offline_storage_service.dart';
import '../../domain/models/licensing_models.dart';
import 'beat_delivery_unpacker_service.dart';

typedef DeedFileWriter = Future<void> Function(String path, Uint8List bytes);
typedef DeedPlatformSharer = Future<void> Function(
  List<XFile> files, {
  String? subject,
  String? text,
});

/// Writes verifiable JSON (`.vhlic.json`) + human-readable legal deed (`.txt`)
/// files and invokes `share_plus` (replacing the legacy stub SnackBar).
class CertificateShareExporter {
  final IOfflineStorageService _offlineStorage;
  final DeedFileWriter? _fileWriter;
  final DeedPlatformSharer? _platformSharer;

  const CertificateShareExporter({
    required this._offlineStorage,
    this._fileWriter,
    this._platformSharer,
  });

  Future<({String jsonPath, String textPath})> exportDeedFiles(
    SovereignLicenseCertificate cert,
  ) async {
    final vaultDir = await _offlineStorage.resolveVaultAudioDirectory();
    final exportDir = BeatDeliveryUnpackerService.normalizeWritablePath(
      '$vaultDir/certificates',
    );
    final writer = _fileWriter;
    if (writer == null) {
      final dir = Directory(exportDir);
      if (!dir.existsSync()) {
        await dir.create(recursive: true);
      }
    }

    final jsonPath = '$exportDir/${cert.certificateId}.vhlic.json';
    final textPath = '$exportDir/${cert.certificateId}_DEED.txt';

    final prettyJson = const JsonEncoder.withIndent('  ').convert(cert.toJson());
    final jsonBytes = Uint8List.fromList(utf8.encode(prettyJson));
    if (writer != null) {
      await writer(jsonPath, jsonBytes);
    } else {
      await File(jsonPath).writeAsBytes(jsonBytes, flush: true);
    }

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

    final deedBytes = Uint8List.fromList(utf8.encode(deedText));
    if (writer != null) {
      await writer(textPath, deedBytes);
    } else {
      await File(textPath).writeAsBytes(deedBytes, flush: true);
    }

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
        final sharer = _platformSharer;
        if (sharer != null) {
          await sharer(
            [XFile(files.textPath), XFile(files.jsonPath)],
            subject: 'Vhunambi License Certificate: ${cert.beatTitle}',
            text:
                'Certificate ${cert.certificateId} • SHA-256 ${cert.shortHash}',
          );
        } else {
          await Share.shareXFiles(
            [XFile(files.textPath), XFile(files.jsonPath)],
            subject: 'Vhunambi License Certificate: ${cert.beatTitle}',
            text:
                'Certificate ${cert.certificateId} • SHA-256 ${cert.shortHash}',
          );
        }
        shared = true;
      } catch (_) {
        shared = false;
      }
    }
    return (jsonPath: files.jsonPath, textPath: files.textPath, sharedViaOs: shared);
  }
}


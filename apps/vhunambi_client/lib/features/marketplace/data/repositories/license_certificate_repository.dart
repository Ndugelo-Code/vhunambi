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


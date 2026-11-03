import 'dart:typed_data';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../domain/codec/sig_codec.dart';
import '../domain/models/sound_signature_dna.dart';

/// Sovereign Hive repository for local [SoundSignatureDna] persistence (REQ-SIG-DNA-04 / Design 2.5).
///
/// Stores binary encoded signature records (< 8 KB) in `vhunambi_sound_signatures_box`
/// with headless test protection.
class SoundSignatureRepository {
  const SoundSignatureRepository();

  /// Retrieves a signature by canonical [id].
  SoundSignatureDna? getSignature(String id) {
    if (!Hive.isBoxOpen(AppConstants.soundSignaturesBoxKey)) return null;
    final box = Hive.box<dynamic>(AppConstants.soundSignaturesBoxKey);
    final raw = box.get(id);
    if (raw == null) return null;

    if (raw is Uint8List) {
      try {
        return SigCodec.decode(raw);
      } catch (_) {
        return null;
      }
    } else if (raw is List) {
      try {
        return SigCodec.decode(Uint8List.fromList(List<int>.from(raw)));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Lists all locally persisted signatures ordered newest first.
  List<SoundSignatureDna> getAllSignatures() {
    if (!Hive.isBoxOpen(AppConstants.soundSignaturesBoxKey)) return const [];
    final box = Hive.box<dynamic>(AppConstants.soundSignaturesBoxKey);

    final results = <SoundSignatureDna>[];
    for (final key in box.keys) {
      final item = getSignature(key.toString());
      if (item != null) {
        results.add(item);
      }
    }

    results.sort((a, b) => b.createdAtIso.compareTo(a.createdAtIso));
    return results;
  }

  /// Persists or updates a [SoundSignatureDna] entity.
  Future<void> saveSignature(SoundSignatureDna dna) async {
    if (!Hive.isBoxOpen(AppConstants.soundSignaturesBoxKey)) return;
    final box = Hive.box<dynamic>(AppConstants.soundSignaturesBoxKey);
    final bytes = SigCodec.encode(dna);
    await box.put(dna.id, bytes);
  }

  /// Deletes a signature from Hive by [id].
  Future<void> deleteSignature(String id) async {
    if (!Hive.isBoxOpen(AppConstants.soundSignaturesBoxKey)) return;
    final box = Hive.box<dynamic>(AppConstants.soundSignaturesBoxKey);
    await box.delete(id);
  }
}

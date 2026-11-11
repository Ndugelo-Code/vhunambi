import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../studio/data/services/pre_gen_r2_upload_service.dart';
import '../domain/codec/sig_codec.dart';
import '../domain/models/sound_signature_dna.dart';

/// Sovereign Hive repository for local [SoundSignatureDna] persistence (REQ-SIG-DNA-04 / Design 2.5).
///
/// Stores binary encoded signature records (< 8 KB) in `vhunambi_sound_signatures_box`
/// with L1 in-memory cache and headless test fallback.
class SoundSignatureRepository {
  const SoundSignatureRepository();

  static final Map<String, Uint8List> _inMemorySignatures =
      <String, Uint8List>{};

  /// Clears L1 memory cache on tenant switch or sign-out (`Phase 61`).
  static void clearSessionMemory() {
    _inMemorySignatures.clear();
  }

  @visibleForTesting
  static void clearInMemoryForTesting() {
    clearSessionMemory();
  }

  /// Retrieves a signature by canonical [id].
  SoundSignatureDna? getSignature(String id) {
    final cachedBytes = _inMemorySignatures[id];
    if (cachedBytes != null) {
      try {
        return SigCodec.decode(cachedBytes);
      } catch (_) {}
    }

    if (!Hive.isBoxOpen(AppConstants.soundSignaturesBoxKey)) return null;
    final box = Hive.box<dynamic>(AppConstants.soundSignaturesBoxKey);
    final raw = box.get(id);
    if (raw == null) return null;

    if (raw is Uint8List) {
      try {
        _inMemorySignatures[id] = raw;
        return SigCodec.decode(raw);
      } catch (_) {
        return null;
      }
    } else if (raw is List) {
      try {
        final bytes = Uint8List.fromList(List<int>.from(raw));
        _inMemorySignatures[id] = bytes;
        return SigCodec.decode(bytes);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Lists all locally persisted signatures ordered newest first.
  List<SoundSignatureDna> getAllSignatures() {
    final byId = <String, SoundSignatureDna>{};

    for (final entry in _inMemorySignatures.entries) {
      try {
        byId[entry.key] = SigCodec.decode(entry.value);
      } catch (_) {}
    }

    if (Hive.isBoxOpen(AppConstants.soundSignaturesBoxKey)) {
      final box = Hive.box<dynamic>(AppConstants.soundSignaturesBoxKey);
      for (final key in box.keys) {
        final id = key.toString();
        final item = getSignature(id);
        if (item != null) {
          byId[id] = item;
        }
      }
    }

    final results = byId.values.toList()
      ..sort((a, b) => b.createdAtIso.compareTo(a.createdAtIso));
    return results;
  }

  /// Persists or updates a [SoundSignatureDna] entity.
  Future<void> saveSignature(SoundSignatureDna dna) async {
    final bytes = SigCodec.encode(dna);
    _inMemorySignatures[dna.id] = bytes;
    if (!Hive.isBoxOpen(AppConstants.soundSignaturesBoxKey)) return;
    final box = Hive.box<dynamic>(AppConstants.soundSignaturesBoxKey);
    await box.put(dna.id, bytes);
  }

  /// Phase 63: Best-effort upload of a captured sound signature WAV + metadata to R2.
  Future<String?> uploadSignatureTakeToCloud({
    required SoundSignatureDna dna,
    required Uint8List wavBytes,
    PreGenR2UploadService? uploader,
  }) async {
    final service = uploader ?? PreGenR2UploadService();
    try {
      return await service.uploadSoundSignatureTake(
        signature: dna,
        wavBytes: wavBytes,
      );
    } catch (err) {
      debugPrint('[SoundSignatureRepository] R2 upload skipped: $err');
      return null;
    }
  }

  /// Deletes a signature from memory and Hive by [id].
  Future<void> deleteSignature(String id) async {
    _inMemorySignatures.remove(id);
    if (!Hive.isBoxOpen(AppConstants.soundSignaturesBoxKey)) return;
    final box = Hive.box<dynamic>(AppConstants.soundSignaturesBoxKey);
    await box.delete(id);
  }
}

final soundSignatureRepositoryProvider = Provider<SoundSignatureRepository>((
  ref,
) {
  return const SoundSignatureRepository();
});

final soundSignaturesListProvider = Provider<List<SoundSignatureDna>>((ref) {
  final repo = ref.watch(soundSignatureRepositoryProvider);
  return repo.getAllSignatures();
});

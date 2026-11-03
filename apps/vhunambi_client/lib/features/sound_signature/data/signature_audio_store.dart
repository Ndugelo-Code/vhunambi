import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

/// Local file storage manager for raw audio WAV takes (REQ-SIG-INTAKE-07 / Blueprint 5).
///
/// Stores uncompressed PCM16 takes at `<appDocs>/signatures/<id>/raw.wav` and tracks
/// the 50 MB local storage budget managed via VaultStorageModal.
class SignatureAudioStore {
  /// Maximum recommended local storage for raw sound signature takes (50 MB).
  static const int kMaxStorageQuotaBytes = 50 * 1024 * 1024;

  const SignatureAudioStore();

  /// Gets the base directory for sound signature audio files.
  Future<Directory> _getBaseDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final sigDir = Directory('${docsDir.path}/signatures');
    if (!await sigDir.exists()) {
      await sigDir.create(recursive: true);
    }
    return sigDir;
  }

  /// Gets the dedicated folder for a specific signature [id].
  Future<Directory> _getDirectoryForSignature(String id) async {
    final base = await _getBaseDirectory();
    final dir = Directory('${base.path}/$id');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Writes raw [wavBytes] for signature [id] and returns the relative file path.
  Future<String> saveRawAudio({
    required String id,
    required Uint8List wavBytes,
  }) async {
    final dir = await _getDirectoryForSignature(id);
    final file = File('${dir.path}/raw.wav');
    await file.writeAsBytes(wavBytes, flush: true);
    return 'signatures/$id/raw.wav';
  }

  /// Reads the raw WAV bytes for the given [id] or [relativeAudioPath].
  Future<Uint8List?> loadRawAudio({
    required String id,
    String? relativeAudioPath,
  }) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final path = relativeAudioPath != null && relativeAudioPath.isNotEmpty
          ? '${docsDir.path}/$relativeAudioPath'
          : '${docsDir.path}/signatures/$id/raw.wav';

      final file = File(path);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Checks if raw audio exists locally on device for signature [id].
  Future<bool> hasRawAudio({
    required String id,
    String? relativeAudioPath,
  }) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final path = relativeAudioPath != null && relativeAudioPath.isNotEmpty
          ? '${docsDir.path}/$relativeAudioPath'
          : '${docsDir.path}/signatures/$id/raw.wav';
      return await File(path).exists();
    } catch (_) {
      return false;
    }
  }

  /// Deletes the local raw audio file and its folder for signature [id].
  Future<bool> deleteRawAudio(String id) async {
    try {
      final dir = await _getDirectoryForSignature(id);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Calculates total bytes used across all stored raw audio takes.
  Future<int> computeTotalStorageUsedBytes() async {
    try {
      final base = await _getBaseDirectory();
      if (!await base.exists()) return 0;

      var total = 0;
      await for (final entity in base.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          total += await entity.length();
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }
}


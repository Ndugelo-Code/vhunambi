import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vhunambi_client/features/social/domain/repositories/i_social_repository.dart';

/// Validated R2 upload result returned by [VhunambiMediaUploadService].
@immutable
class VhunambiUploadedMedia {
  final String url;
  final String filename;
  final String mimeType;
  final int sizeBytes;

  const VhunambiUploadedMedia({
    required this.url,
    required this.filename,
    required this.mimeType,
    required this.sizeBytes,
  });
}

/// Unified gallery image picker + Cloudflare R2 uploader (`EP-P77-UNIFIED-R2-IMAGE-UPLOAD`,
/// consuming `EP-P74-SOCIAL-MEDIA-R2-UPLOAD` -> `POST /api/social/media/upload`).
class VhunambiMediaUploadService {
  static const int maxImageBytes = 25 * 1024 * 1024; // Matches social_routes.ts
  static const Set<String> allowedImageMimes = <String>{
    'image/jpeg',
    'image/png',
    'image/webp',
  };

  static bool get _isTestEnv {
    if (const bool.fromEnvironment('FLUTTER_TEST')) return true;
    try {
      if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  static String inferImageMimeType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  /// Picks an image from the device gallery (or deterministic stub in tests),
  /// validates MIME/size, and uploads bytes to R2 via [socialRepository.uploadReelMedia].
  static Future<VhunambiUploadedMedia?> pickAndUploadImage({
    required ISocialRepository socialRepository,
    required String purposePrefix,
    Uint8List? testBytesOverride,
    String? testFilenameOverride,
  }) async {
    Uint8List bytes;
    String filename;
    String mimeType;

    if (testBytesOverride != null || _isTestEnv) {
      bytes = testBytesOverride ??
          Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
      filename = testFilenameOverride ??
          '${purposePrefix}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      mimeType = inferImageMimeType(filename);
    } else {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 88,
      );
      if (picked == null) return null;
      bytes = await picked.readAsBytes();
      filename = picked.name.isNotEmpty
          ? picked.name
          : '${purposePrefix}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      mimeType = inferImageMimeType(filename);
    }

    if (bytes.isEmpty) {
      throw const FormatException('Selected image is empty.');
    }
    if (bytes.length > maxImageBytes) {
      throw const FormatException(
        'Selected image exceeds the 25 MB R2 upload limit.',
      );
    }
    if (!allowedImageMimes.contains(mimeType)) {
      throw FormatException('Unsupported image format: $mimeType');
    }

    final uploaded = await socialRepository.uploadReelMedia(
      bytes: bytes,
      filename: filename,
      mimeType: mimeType,
    );

    return VhunambiUploadedMedia(
      url: uploaded.url,
      filename: filename,
      mimeType: uploaded.mimeType,
      sizeBytes: uploaded.sizeBytes,
    );
  }
}

import 'package:vhunambi_client/features/media/domain/models/uploaded_media_asset.dart';

const Map<String, String> kExtensionToMimeMap = <String, String>{
  'mp4': 'video/mp4',
  'm4v': 'video/mp4',
  'mov': 'video/quicktime',
  'webm': 'video/webm',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
  'mp3': 'audio/mpeg',
  'wav': 'audio/wav',
  'm4a': 'audio/mp4',
  'aac': 'audio/aac',
  'ogg': 'audio/ogg',
  'flac': 'audio/flac',
};

/// Resolves canonical MIME type from declared MIME or file extension.
/// Prevents hardcoding 'video/mp4' or 'image/jpeg' on PNG/WebP/MOV/MP3 files.
String inferMimeTypeFromMedia({
  required String filename,
  String? declaredMime,
  MediaAssetKind? fallbackKind,
}) {
  final normalizedDeclared =
      (declaredMime ?? '').split(';').first.trim().toLowerCase();
  if (normalizedDeclared.isNotEmpty &&
      normalizedDeclared != 'application/octet-stream') {
    if (normalizedDeclared == 'image/jpg') return 'image/jpeg';
    if (kExtensionToMimeMap.values.contains(normalizedDeclared) ||
        normalizedDeclared == 'audio/x-wav' ||
        normalizedDeclared == 'audio/wave') {
      return normalizedDeclared;
    }
  }

  final dotIdx = filename.lastIndexOf('.');
  if (dotIdx != -1 && dotIdx < filename.length - 1) {
    final ext = filename.substring(dotIdx + 1).trim().toLowerCase();
    final mapped = kExtensionToMimeMap[ext];
    if (mapped != null) return mapped;
  }

  return switch (fallbackKind) {
    MediaAssetKind.video => 'video/mp4',
    MediaAssetKind.audio => 'audio/mpeg',
    MediaAssetKind.image || null => 'image/jpeg',
  };
}

bool isVideoFilenameOrMime(String filename, [String? declaredMime]) {
  return inferMimeTypeFromMedia(
    filename: filename,
    declaredMime: declaredMime,
  ).startsWith('video/');
}

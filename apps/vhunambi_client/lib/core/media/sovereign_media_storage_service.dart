import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/core/utils/creator_id_utils.dart';
import 'package:vhunambi_client/features/media/domain/models/uploaded_media_asset.dart';

/// Local-first sandbox file vault + multi-tenant Hive persistence for user media
/// (`EP-P79-MEDIA-UPLOAD-ENGINE`, `REQ-P79-VLT-01`).
class SovereignMediaStorageService {
  static final Map<String, Map<String, dynamic>> _sessionFallbackStore =
      <String, Map<String, dynamic>>{};

  static bool get isTestEnv {
    if (const bool.fromEnvironment('FLUTTER_TEST')) return true;
    try {
      if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  static void clearTenantSessionMemory() {
    _sessionFallbackStore.clear();
  }

  static String compositeKey(String creatorId, String assetId) {
    final cid = canonicalizeCreatorId(creatorId);
    return '$cid::$assetId';
  }

  static String sanitizeExtension(String filename, String mimeType) {
    final lowerName = filename.toLowerCase();
    final dotIdx = lowerName.lastIndexOf('.');
    if (dotIdx != -1 && dotIdx < lowerName.length - 1) {
      final candidate = lowerName
          .substring(dotIdx + 1)
          .replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (candidate.isNotEmpty && candidate.length <= 5) {
        return candidate;
      }
    }
    return switch (mimeType.toLowerCase()) {
      'audio/mpeg' => 'mp3',
      'audio/mp4' => 'm4a',
      'audio/wav' || 'audio/x-wav' || 'audio/wave' => 'wav',
      'audio/aac' => 'aac',
      'audio/ogg' => 'ogg',
      'video/quicktime' => 'mov',
      'video/webm' => 'webm',
      'video/mp4' => 'mp4',
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
  }

  /// Copies [bytes] into persistent sandbox storage (`AppDocs/vhunambi_media/...`
  /// on device, or deterministic system temp directory under `FLUTTER_TEST`).
  static Future<String?> stageMediaBytes({
    required String creatorId,
    required String assetId,
    required MediaAssetKind kind,
    required String filename,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    if (kIsWeb || bytes.isEmpty) return null;
    final cid = canonicalizeCreatorId(creatorId);
    final ext = sanitizeExtension(filename, mimeType);
    final folder = switch (kind) {
      MediaAssetKind.audio => 'audio',
      MediaAssetKind.video => 'video',
      MediaAssetKind.image => 'images',
    };

    Directory rootDir;
    if (isTestEnv) {
      rootDir = Directory(
        '${Directory.systemTemp.path}${Platform.pathSeparator}vhunambi_test_media${Platform.pathSeparator}$cid${Platform.pathSeparator}$folder',
      );
      if (!rootDir.existsSync()) {
        rootDir.createSync(recursive: true);
      }
      final targetFile = File(
        '${rootDir.path}${Platform.pathSeparator}$assetId.$ext',
      );
      targetFile.writeAsBytesSync(bytes);
      return targetFile.path;
    }

    final docs = await getApplicationDocumentsDirectory();
    rootDir = Directory(
      '${docs.path}${Platform.pathSeparator}vhunambi_media${Platform.pathSeparator}$cid${Platform.pathSeparator}$folder',
    );
    if (!rootDir.existsSync()) {
      await rootDir.create(recursive: true);
    }
    final targetFile = File(
      '${rootDir.path}${Platform.pathSeparator}$assetId.$ext',
    );
    await targetFile.writeAsBytes(bytes, flush: true);
    return targetFile.path;
  }

  static Future<void> saveAsset(UploadedMediaAsset asset) async {
    final key = compositeKey(asset.creatorId, asset.id);
    final payload = asset.toJson();
    _sessionFallbackStore[key] = payload;
    if (!kIsWeb && Hive.isBoxOpen(AppConstants.mediaUploadsBoxKey)) {
      final box = Hive.box<dynamic>(AppConstants.mediaUploadsBoxKey);
      await box.put(key, jsonEncode(payload));
    }
  }

  static List<UploadedMediaAsset> loadCreatorAssets(String creatorId) {
    final cid = canonicalizeCreatorId(creatorId);
    final prefix = '$cid::';
    final merged = <String, UploadedMediaAsset>{};

    for (final entry in _sessionFallbackStore.entries) {
      if (entry.key.startsWith(prefix)) {
        final asset = UploadedMediaAsset.fromJson(entry.value);
        if (asset.id.isNotEmpty) merged[asset.id] = asset;
      }
    }

    if (!kIsWeb && Hive.isBoxOpen(AppConstants.mediaUploadsBoxKey)) {
      final box = Hive.box<dynamic>(AppConstants.mediaUploadsBoxKey);
      for (final dynamic rawKey in box.keys) {
        final k = rawKey.toString();
        if (!k.startsWith(prefix)) continue;
        final dynamic rawVal = box.get(rawKey);
        try {
          Map<String, dynamic>? map;
          if (rawVal is String && rawVal.isNotEmpty) {
            map = jsonDecode(rawVal) as Map<String, dynamic>;
          } else if (rawVal is Map) {
            map = Map<String, dynamic>.from(rawVal);
          }
          if (map != null) {
            final asset = UploadedMediaAsset.fromJson(map);
            if (asset.id.isNotEmpty) merged[asset.id] = asset;
          }
        } catch (_) {}
      }
    }

    final list = merged.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  static Future<void> removeAsset(UploadedMediaAsset asset) async {
    final key = compositeKey(asset.creatorId, asset.id);
    _sessionFallbackStore.remove(key);
    if (!kIsWeb && Hive.isBoxOpen(AppConstants.mediaUploadsBoxKey)) {
      final box = Hive.box<dynamic>(AppConstants.mediaUploadsBoxKey);
      await box.delete(key);
    }
    if (!kIsWeb &&
        asset.localFilePath != null &&
        asset.localFilePath!.isNotEmpty) {
      try {
        final f = File(asset.localFilePath!);
        if (f.existsSync()) {
          if (isTestEnv) {
            f.deleteSync();
          } else {
            await f.delete();
          }
        }
      } catch (_) {}
    }
  }
}

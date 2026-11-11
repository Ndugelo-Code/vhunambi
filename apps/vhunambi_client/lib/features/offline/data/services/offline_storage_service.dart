import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../library/domain/models/library_models.dart';

abstract class IOfflineStorageService {
  Future<void> init();
  Future<void> saveTrackMetadata({
    required LibraryTrack track,
    required String localPath,
    required int fileSizeBytes,
  });
  Future<Map<String, dynamic>?> getTrackMetadata(String trackId);
  Future<List<Map<String, dynamic>>> getAllCachedMetadata();
  Future<void> removeTrackMetadata(String trackId);
  Future<void> clearAllMetadata();
  Future<int> getTotalCachedSizeBytes();
  Future<bool> isTrackCachedLocally(String trackId);
  Future<String> resolveVaultAudioDirectory();
  Future<void> savePreference(String key, dynamic value);
  Future<dynamic> getPreference(String key);
}

/// Hive-backed offline storage service managing metadata and local audio persistence.
/// Includes an in-memory fallback to support headless unit and widget testing environments.
class OfflineStorageService implements IOfflineStorageService {
  Box? _vaultBox;
  Box? _prefsBox;
  final Map<String, Map<String, dynamic>> _inMemoryVault = {};
  final Map<String, dynamic> _inMemoryPrefs = {};
  final String? customVaultDirectory;
  bool _isInitialized = false;

  OfflineStorageService({this.customVaultDirectory});

  @override
  Future<void> init() async {
    if (_isInitialized) return;
    await _getVaultBox();
    await _getPrefsBox();
    _isInitialized = true;
  }

  Future<Box?> _getVaultBox() async {
    if (_vaultBox != null && _vaultBox!.isOpen) return _vaultBox;
    if (kIsWeb) return null;
    try {
      if (Hive.isBoxOpen(AppConstants.vaultBoxKey)) {
        _vaultBox = Hive.box(AppConstants.vaultBoxKey);
        return _vaultBox;
      }
      if (const bool.fromEnvironment('FLUTTER_TEST') ||
          Platform.environment.containsKey('FLUTTER_TEST')) {
        return null;
      }
      if (customVaultDirectory != null &&
          !Directory(customVaultDirectory!).existsSync()) {
        return null;
      }
      _vaultBox = await Hive.openBox(AppConstants.vaultBoxKey);
      return _vaultBox;
    } catch (e) {
      debugPrint('OfflineStorageService running with in-memory vault store: $e');
      return null;
    }
  }

  Future<Box?> _getPrefsBox() async {
    if (_prefsBox != null && _prefsBox!.isOpen) return _prefsBox;
    if (kIsWeb) return null;
    try {
      if (Hive.isBoxOpen(AppConstants.preferencesBoxKey)) {
        _prefsBox = Hive.box(AppConstants.preferencesBoxKey);
        return _prefsBox;
      }
      if (const bool.fromEnvironment('FLUTTER_TEST') ||
          Platform.environment.containsKey('FLUTTER_TEST')) {
        return null;
      }
      if (customVaultDirectory != null &&
          !Directory(customVaultDirectory!).existsSync()) {
        return null;
      }
      _prefsBox = await Hive.openBox(AppConstants.preferencesBoxKey);
      return _prefsBox;
    } catch (e) {
      debugPrint('OfflineStorageService running with in-memory prefs store: $e');
      return null;
    }
  }

  @override
  Future<String> resolveVaultAudioDirectory() async {
    if (customVaultDirectory != null) {
      return customVaultDirectory!;
    }

    try {
      if (!kIsWeb) {
        final docsDir = await getApplicationDocumentsDirectory();
        final path = '${docsDir.path}/${AppConstants.vaultAudioDirectory}';
        final dir = Directory(path);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return path;
      }
    } catch (_) {
      // Test environment fallback
    }

    return 'vhunambi_vault/audio';
  }

  @override
  Future<void> saveTrackMetadata({
    required LibraryTrack track,
    required String localPath,
    required int fileSizeBytes,
  }) async {
    await init();

    final record = <String, dynamic>{
      'id': track.id,
      'title': track.title,
      'creatorName': track.creatorName,
      'genre': track.genre,
      'language': track.language,
      'durationSeconds': track.durationSeconds,
      'remoteAudioUrl': track.remoteAudioUrl,
      'localAudioFilePath': localPath,
      'coverImageUrl': track.coverImageUrl,
      'createdAt': track.createdAt.toIso8601String(),
      'licenseType': track.licenseType,
      'syncStatus': TrackSyncStatus.cachedLocally.name,
      'fileSizeBytes': fileSizeBytes,
      'downloadedAt': DateTime.now().toIso8601String(),
    };

    _inMemoryVault[track.id] = record;

    if (_vaultBox != null && _vaultBox!.isOpen) {
      await _vaultBox!.put(track.id, record);
    }
  }

  @override
  Future<Map<String, dynamic>?> getTrackMetadata(String trackId) async {
    await init();

    if (_vaultBox != null && _vaultBox!.isOpen) {
      final data = _vaultBox!.get(trackId);
      if (data != null && data is Map) {
        return Map<String, dynamic>.from(data);
      }
    }

    return _inMemoryVault[trackId];
  }

  @override
  Future<List<Map<String, dynamic>>> getAllCachedMetadata() async {
    await init();

    if (_vaultBox != null && _vaultBox!.isOpen) {
      final records = <Map<String, dynamic>>[];
      for (final key in _vaultBox!.keys) {
        final item = _vaultBox!.get(key);
        if (item is Map) {
          records.add(Map<String, dynamic>.from(item));
        }
      }
      if (records.isNotEmpty) return records;
    }

    return _inMemoryVault.values.toList();
  }

  @override
  Future<void> removeTrackMetadata(String trackId) async {
    await init();

    final meta = await getTrackMetadata(trackId);
    if (meta != null && meta['localAudioFilePath'] != null) {
      final filePath = meta['localAudioFilePath'] as String;
      try {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // Ignored if file already removed or in test
      }
    }

    _inMemoryVault.remove(trackId);

    if (_vaultBox != null && _vaultBox!.isOpen) {
      await _vaultBox!.delete(trackId);
    }
  }

  @override
  Future<void> clearAllMetadata() async {
    await init();

    final all = await getAllCachedMetadata();
    for (final item in all) {
      final path = item['localAudioFilePath'] as String?;
      if (path != null) {
        try {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {}
      }
    }

    _inMemoryVault.clear();

    if (_vaultBox != null && _vaultBox!.isOpen) {
      await _vaultBox!.clear();
    }
  }

  @override
  Future<int> getTotalCachedSizeBytes() async {
    final all = await getAllCachedMetadata();
    int total = 0;
    for (final item in all) {
      final size = item['fileSizeBytes'];
      if (size is int) {
        total += size;
      }
    }
    return total;
  }

  @override
  Future<bool> isTrackCachedLocally(String trackId) async {
    final meta = await getTrackMetadata(trackId);
    if (meta == null) return false;
    final path = meta['localAudioFilePath'] as String?;
    if (path == null || path.isEmpty) return false;

    // Check file presence strictly if physical disk access is supported
    try {
      final file = File(path);
      return await file.exists();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> savePreference(String key, dynamic value) async {
    _inMemoryPrefs[key] = value;
    try {
      final box = await _getPrefsBox();
      if (box != null && box.isOpen) {
        await box.put(key, value);
      }
    } catch (_) {}
  }

  @override
  Future<dynamic> getPreference(String key) async {
    try {
      final box = await _getPrefsBox();
      if (box != null && box.isOpen) {
        final value = box.get(key);
        if (value != null) return value;
      }
    } catch (_) {}
    return _inMemoryPrefs[key];
  }
}

/// Alias for SovereignOfflineStorageService per Phase 08 spec
typedef SovereignOfflineStorageService = OfflineStorageService;


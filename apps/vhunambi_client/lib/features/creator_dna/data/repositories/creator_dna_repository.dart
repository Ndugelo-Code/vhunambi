import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/creator_dna_profile.dart';
import '../../domain/models/behavior_event.dart';

/// Repository managing persistence of Creator DNA profile and behavioral telemetry log
/// using an untyped Hive box with headless in-memory fallback.
class CreatorDnaRepository {
  static const _profileKey = 'dna_profile';
  static const _behaviorLogKey = 'behavior_log';
  static const _maxLogSize = 500;

  Box? _box;
  final Map<String, dynamic> _inMemoryStore = {};
  bool _initialized = false;

  CreatorDnaRepository([this._box]);

  Future<void> _ensureOpen() async {
    if (_initialized) return;

    if (_box != null) {
      _initialized = true;
      return;
    }

    try {
      if (!kIsWeb && Hive.isBoxOpen(AppConstants.creatorDnaBoxKey)) {
        _box = Hive.box(AppConstants.creatorDnaBoxKey);
      }
    } catch (e) {
      debugPrint('CreatorDnaRepository running in-memory fallback: $e');
    }
    _initialized = true;
  }

  /// Loads the persisted DNA profile, or returns an unseeded initial profile.
  Future<CreatorDnaProfile> loadProfile() async {
    await _ensureOpen();
    try {
      final raw = _box != null ? _box!.get(_profileKey) : _inMemoryStore[_profileKey];
      if (raw == null) return CreatorDnaProfile.initial();
      return CreatorDnaProfile.fromJson(Map<String, dynamic>.from(raw as Map));
    } catch (_) {
      return CreatorDnaProfile.initial();
    }
  }

  /// Persists the DNA profile state.
  Future<void> saveProfile(CreatorDnaProfile profile) async {
    await _ensureOpen();
    try {
      final json = profile.toJson();
      if (_box != null) {
        await _box!.put(_profileKey, json);
      } else {
        _inMemoryStore[_profileKey] = json;
      }
    } catch (_) {}
  }

  /// Loads the historical behavior event log.
  Future<List<BehaviorEvent>> loadEventLog() async {
    await _ensureOpen();
    try {
      final raw = _box != null ? _box!.get(_behaviorLogKey) : _inMemoryStore[_behaviorLogKey];
      if (raw == null) return [];
      return (raw as List)
          .map((e) => BehaviorEvent.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Appends an event to the persistent event log with 500-event FIFO sliding window.
  Future<void> appendEvent(BehaviorEvent event, List<BehaviorEvent> existingLog) async {
    await _ensureOpen();
    final updatedLog = [...existingLog, event];
    final trimmed = updatedLog.length > _maxLogSize
        ? updatedLog.sublist(updatedLog.length - _maxLogSize)
        : updatedLog;
    try {
      final serialized = trimmed.map((e) => e.toJson()).toList();
      if (_box != null) {
        await _box!.put(_behaviorLogKey, serialized);
      } else {
        _inMemoryStore[_behaviorLogKey] = serialized;
      }
    } catch (_) {}
  }

  /// Clears all stored DNA and telemetry records.
  Future<void> clearAll() async {
    await _ensureOpen();
    try {
      if (_box != null) {
        await _box!.clear();
      } else {
        _inMemoryStore.clear();
      }
    } catch (_) {}
  }
}

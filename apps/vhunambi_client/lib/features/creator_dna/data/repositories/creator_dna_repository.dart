import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/storage/hive_compaction_scheduler.dart';
import '../../domain/entities/creator_dna_profile.dart';
import '../../domain/models/behavior_event.dart';

/// Repository managing persistence of Creator DNA profile and behavioral telemetry log
/// using O(1) ring-buffer keys (`dna_evt_<0..499>` + `dna_evt_cursor`) with
/// automatic legacy migration and headless in-memory fallback.
class CreatorDnaRepository {
  static const _profileKey = 'dna_profile';
  static const _behaviorLogKey = 'behavior_log';
  static const _eventCursorKey = 'dna_evt_cursor';
  static const _eventPrefix = 'dna_evt_';
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

  dynamic _getRaw(String key) =>
      _box != null ? _box!.get(key) : _inMemoryStore[key];

  Future<void> _putRaw(String key, dynamic value) async {
    if (_box != null) {
      await _box!.put(key, value);
    } else {
      _inMemoryStore[key] = value;
    }
  }

  Future<void> _deleteRaw(String key) async {
    if (_box != null) {
      await _box!.delete(key);
    } else {
      _inMemoryStore.remove(key);
    }
  }

  Iterable<String> _allKeys() {
    if (_box != null) {
      return _box!.keys.map((k) => k.toString());
    }
    return _inMemoryStore.keys.toList(growable: false);
  }

  bool _hasRingKeys() => _allKeys().any((k) => k.startsWith(_eventPrefix));

  /// Migrates legacy monolithic `'behavior_log'` list into O(1) ring slots.
  Future<void> _migrateLegacyLogIfNeeded() async {
    final legacyRaw = _getRaw(_behaviorLogKey);
    if (legacyRaw is! List) return;

    final start = legacyRaw.length > _maxLogSize
        ? legacyRaw.length - _maxLogSize
        : 0;
    final slice = legacyRaw.sublist(start);
    var seq = 0;
    for (final item in slice) {
      if (item is Map) {
        await _putRaw('$_eventPrefix${seq % _maxLogSize}', <String, dynamic>{
          'seq': seq,
          'event': Map<String, dynamic>.from(item),
        });
        seq++;
      }
    }
    await _putRaw(_eventCursorKey, seq);
    await _deleteRaw(_behaviorLogKey);
  }

  /// Loads the persisted DNA profile, or returns an unseeded initial profile.
  Future<CreatorDnaProfile> loadProfile() async {
    await _ensureOpen();
    try {
      final raw = _getRaw(_profileKey);
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
      await _putRaw(_profileKey, json);
      await HiveCompactionScheduler.recordMutation(
        AppConstants.creatorDnaBoxKey,
      );
    } catch (_) {}
  }

  /// Loads the historical behavior event log from O(1) ring-buffer slots.
  Future<List<BehaviorEvent>> loadEventLog() async {
    await _ensureOpen();
    try {
      await _migrateLegacyLogIfNeeded();
      final entries = <({int seq, BehaviorEvent event})>[];
      for (final key in _allKeys()) {
        if (!key.startsWith(_eventPrefix)) continue;
        final raw = _getRaw(key);
        if (raw is Map) {
          final map = Map<String, dynamic>.from(raw);
          final seq = (map['seq'] as num?)?.toInt();
          final rawEvent = map['event'];
          if (seq != null && rawEvent is Map) {
            entries.add((
              seq: seq,
              event: BehaviorEvent.fromJson(
                Map<String, dynamic>.from(rawEvent),
              ),
            ));
          }
        }
      }
      if (entries.isEmpty) return [];
      entries.sort((a, b) => a.seq.compareTo(b.seq));
      final trimmed = entries.length > _maxLogSize
          ? entries.sublist(entries.length - _maxLogSize)
          : entries;
      return trimmed.map((e) => e.event).toList();
    } catch (_) {
      return [];
    }
  }

  /// Appends a single event in O(1) to the 500-slot FIFO ring buffer.
  Future<void> appendEvent(
    BehaviorEvent event,
    List<BehaviorEvent> existingLog,
  ) async {
    await _ensureOpen();
    try {
      await _migrateLegacyLogIfNeeded();

      var cursor = (_getRaw(_eventCursorKey) as num?)?.toInt();
      if (cursor == null && !_hasRingKeys() && existingLog.isNotEmpty) {
        final start = existingLog.length > _maxLogSize
            ? existingLog.length - _maxLogSize
            : 0;
        var seedSeq = 0;
        for (final existing in existingLog.sublist(start)) {
          await _putRaw(
            '$_eventPrefix${seedSeq % _maxLogSize}',
            <String, dynamic>{'seq': seedSeq, 'event': existing.toJson()},
          );
          seedSeq++;
        }
        cursor = seedSeq;
      }

      final seq = cursor ?? 0;
      final slotKey = '$_eventPrefix${seq % _maxLogSize}';
      await _putRaw(slotKey, <String, dynamic>{
        'seq': seq,
        'event': event.toJson(),
      });
      await _putRaw(_eventCursorKey, seq + 1);
      await HiveCompactionScheduler.recordMutation(
        AppConstants.creatorDnaBoxKey,
      );
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

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/models/producer_beat_entity.dart';
import '../../domain/repositories/i_beat_repository.dart';

/// Production Hive-backed [IBeatRepository] (REQ-BEAT-09).
///
/// Persists producer beats as JSON maps in [AppConstants.beatsBoxKey]. When the
/// box has not been opened (headless test runs, cold start, web without
/// persistence) it silently falls back to an internal memory map so no
/// unhandled async zone exception ever escapes the Hive plugin.
class BeatRepository implements IBeatRepository {
  BeatRepository({Box? box}) {
    _box = box;
  }

  Box? _box;
  final Map<String, ProducerBeatEntity> _inMemoryFallback =
      <String, ProducerBeatEntity>{};
  bool _initialized = false;

  Future<void> _ensureInit() async {
    if (_initialized) return;

    if (_box != null) {
      _initialized = true;
      return;
    }

    try {
      if (!kIsWeb && Hive.isBoxOpen(AppConstants.beatsBoxKey)) {
        _box = Hive.box(AppConstants.beatsBoxKey);
      }
    } catch (e) {
      debugPrint('BeatRepository running in-memory fallback: $e');
    }
    _initialized = true;
  }

  @override
  Future<List<ProducerBeatEntity>> getAllBeats() async {
    await _ensureInit();

    if (_box != null) {
      final beats = <ProducerBeatEntity>[];
      for (final raw in _box!.values) {
        if (raw is Map) {
          beats.add(ProducerBeatEntity.fromJson(Map<String, dynamic>.from(raw)));
        }
      }
      beats.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return beats;
    }

    final beats = _inMemoryFallback.values.toList();
    beats.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return beats;
  }

  @override
  Future<ProducerBeatEntity?> getBeatById(String id) async {
    await _ensureInit();

    if (_box != null) {
      final raw = _box!.get(id);
      if (raw is Map) {
        return ProducerBeatEntity.fromJson(Map<String, dynamic>.from(raw));
      }
      return null;
    }
    return _inMemoryFallback[id];
  }

  @override
  Future<void> saveBeat(ProducerBeatEntity beat) async {
    await _ensureInit();

    if (_box != null) {
      await _box!.put(beat.id, beat.toJson());
    } else {
      _inMemoryFallback[beat.id] = beat;
    }
  }

  @override
  Future<void> deleteBeat(String id) async {
    await _ensureInit();

    if (_box != null) {
      await _box!.delete(id);
    } else {
      _inMemoryFallback.remove(id);
    }
  }

  @override
  Future<ProducerBeatEntity> publishBeat(String id) async {
    final beat = await _requireBeat(id);
    return _persist(
      beat.copyWith(
        status: BeatStatus.published,
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<ProducerBeatEntity> unpublishBeat(String id) async {
    final beat = await _requireBeat(id);
    return _persist(
      beat.copyWith(
        status: BeatStatus.draft,
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<ProducerBeatEntity> recordSale(String id, BeatSaleRecord sale) async {
    final beat = await _requireBeat(id);
    return _persist(
      beat.copyWith(
        salesRecords: <BeatSaleRecord>[...beat.salesRecords, sale],
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<ProducerBeatEntity> incrementAuditions(String id) async {
    final beat = await _requireBeat(id);
    return _persist(beat.copyWith(auditionCount: beat.auditionCount + 1));
  }

  @override
  Future<void> clearAll() async {
    await _ensureInit();

    if (_box != null) {
      await _box!.clear();
    } else {
      _inMemoryFallback.clear();
    }
  }

  Future<ProducerBeatEntity> _requireBeat(String id) async {
    final beat = await getBeatById(id);
    if (beat == null) {
      throw StateError('Unknown beat: $id');
    }
    return beat;
  }

  Future<ProducerBeatEntity> _persist(ProducerBeatEntity beat) async {
    await saveBeat(beat);
    return beat;
  }
}

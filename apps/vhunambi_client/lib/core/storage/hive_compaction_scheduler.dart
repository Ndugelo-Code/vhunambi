import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';

/// Tracks append-only log mutation counts per Hive box and runs `box.compact()`
/// when fragmentation ratio exceeds threshold (`\theta_compact = 0.20`, `M_min = 25`).
class HiveCompactionScheduler {
  HiveCompactionScheduler._();

  static const double fragmentationThreshold = 0.20;
  static const int minMutationsForAutoCompact = 25;

  static final Map<String, int> _mutationCounts = <String, int>{};
  static DateTime? _lastCompactedAt;
  static int _totalCompactionsExecuted = 0;

  static DateTime? get lastCompactedAt => _lastCompactedAt;
  static int get totalCompactionsExecuted => _totalCompactionsExecuted;

  /// Records [count] write/delete mutations against [boxName] and triggers
  /// asynchronous compaction if fragmentation threshold is reached.
  static Future<bool> recordMutation(
    String boxName, {
    int count = 1,
    int? overrideLiveCount,
  }) async {
    final updated = (_mutationCounts[boxName] ?? 0) + count;
    _mutationCounts[boxName] = updated;

    final ratio = computeFragmentationRatio(
      boxName,
      overrideLiveCount: overrideLiveCount,
    );
    if (updated >= minMutationsForAutoCompact &&
        ratio >= fragmentationThreshold) {
      return compactBox(boxName);
    }
    return false;
  }

  /// Computes `Phi_frag(b) = M_mutations(b) / (N_live(b) + 1)`.
  static double computeFragmentationRatio(
    String boxName, {
    int? overrideLiveCount,
  }) {
    final mutations = _mutationCounts[boxName] ?? 0;
    if (mutations <= 0) return 0.0;
    final liveCount = overrideLiveCount ?? _resolveLiveKeyCount(boxName);
    return mutations / (liveCount + 1);
  }

  /// Computes aggregate fragmentation ratio across all tracked boxes.
  static double computeGlobalFragmentationRatio() {
    if (_mutationCounts.isEmpty) return 0.0;
    var totalMutations = 0;
    var totalLive = 0;
    for (final entry in _mutationCounts.entries) {
      totalMutations += entry.value;
      totalLive += _resolveLiveKeyCount(entry.key);
    }
    return totalMutations / (totalLive + 1);
  }

  static int _resolveLiveKeyCount(String boxName) {
    if (kIsWeb) return 10;
    try {
      if (!Hive.isBoxOpen(boxName)) return 10;
      if (boxName == AppConstants.syncOutboxBoxKey) {
        return Hive.box<Map>(boxName).length;
      }
      return Hive.box<dynamic>(boxName).length;
    } catch (_) {
      return 10;
    }
  }

  /// Compacts a single open Hive box and resets its mutation counter.
  static Future<bool> compactBox(String boxName) async {
    _mutationCounts[boxName] = 0;
    _lastCompactedAt = DateTime.now();
    _totalCompactionsExecuted++;
    if (kIsWeb) return true;
    try {
      if (!Hive.isBoxOpen(boxName)) return false;
      if (boxName == AppConstants.syncOutboxBoxKey) {
        await Hive.box<Map>(boxName).compact();
        return true;
      }
      await Hive.box<dynamic>(boxName).compact();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Compacts all open Hive boxes and resets all mutation counters.
  static Future<int> compactAllBoxesNow(Iterable<String> boxNames) async {
    var compacted = 0;
    for (final name in boxNames) {
      final ok = await compactBox(name);
      if (ok) compacted++;
    }
    _lastCompactedAt = DateTime.now();
    return compacted;
  }

  @visibleForTesting
  static void resetForTesting() {
    _mutationCounts.clear();
    _lastCompactedAt = null;
    _totalCompactionsExecuted = 0;
  }
}

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Priority ordering for outbox drain: financial transactions first.
enum SyncPriority { critical, normal, background }

/// Lifecycle status of an outbox record.
enum SyncRecordStatus { pending, failedRetryable, deadLetter }

/// A durable, idempotent mutation record stored in the client outbox (REQ-P44-SYNC-02).
/// Schema v2: adds priority, baseSeq, and schemaVersion for graceful v1 migration.
class SyncMutationRecord {
  final String idempotencyKey;
  final String entityType; // 'post' | 'track' | 'tip' | 'cosign' | 'remix'
  final String action;     // 'create' | 'update' | 'delete' | 'cosign' | 'tip'
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int retryCount;
  final SyncRecordStatus status;
  final SyncPriority priority;
  final int? baseSeq;
  final int schemaVersion;

  const SyncMutationRecord({
    required this.idempotencyKey,
    required this.entityType,
    required this.action,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
    this.status = SyncRecordStatus.pending,
    this.priority = SyncPriority.background,
    this.baseSeq,
    this.schemaVersion = 2,
  });

  SyncMutationRecord copyWith({
    String? idempotencyKey,
    String? entityType,
    String? action,
    Map<String, dynamic>? payload,
    DateTime? createdAt,
    int? retryCount,
    SyncRecordStatus? status,
    SyncPriority? priority,
    int? baseSeq,
    int? schemaVersion,
  }) {
    return SyncMutationRecord(
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      entityType: entityType ?? this.entityType,
      action: action ?? this.action,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      baseSeq: baseSeq ?? this.baseSeq,
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }

  Map<String, dynamic> toJson() => {
    'idempotencyKey': idempotencyKey,
    'entityType': entityType,
    'action': action,
    'payload': payload,
    'createdAt': createdAt.toIso8601String(),
    'retryCount': retryCount,
    'status': status.name,
    'priority': priority.name,
    'baseSeq': baseSeq,
    'schemaVersion': schemaVersion,
  };

  /// Graceful v1 → v2 migration: missing priority/baseSeq/schemaVersion default safely.
  factory SyncMutationRecord.fromJson(Map<dynamic, dynamic> map) {
    final version = (map['schemaVersion'] as num?)?.toInt() ?? 1;
    final priorityName = map['priority'] as String? ?? 'background';
    final statusName = map['status'] as String? ?? 'pending';

    return SyncMutationRecord(
      idempotencyKey: map['idempotencyKey'] as String? ?? 'unknown_key',
      entityType: map['entityType'] as String? ?? 'unknown',
      action: map['action'] as String? ?? 'unknown',
      payload: Map<String, dynamic>.from(map['payload'] as Map? ?? {}),
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      retryCount: (map['retryCount'] as num?)?.toInt() ?? 0,
      status: SyncRecordStatus.values.firstWhere(
        (e) => e.name == statusName,
        orElse: () => SyncRecordStatus.pending,
      ),
      priority: SyncPriority.values.firstWhere(
        (e) => e.name == priorityName,
        orElse: () => SyncPriority.background,
      ),
      baseSeq: (map['baseSeq'] as num?)?.toInt(),
      schemaVersion: version,
    );
  }
}

/// A failed mutation item from a partial-failure batch response.
class SyncFailedItem {
  final String idempotencyKey;
  final String code;
  final String message;
  final bool retryable;

  const SyncFailedItem({
    required this.idempotencyKey,
    required this.code,
    required this.message,
    required this.retryable,
  });
}

/// Result of an edge flush to the backend API (REQ-P44-SYNC-05).
class SyncFlushResult {
  final List<String> applied;
  final List<String> skipped;
  final List<SyncFailedItem> failed;
  final int latestSeq;

  const SyncFlushResult({
    required this.applied,
    required this.skipped,
    this.failed = const [],
    required this.latestSeq,
  });

  // Backward-compatible accessors for Phase 45/46 tests.
  int get appliedCount => applied.length;
  int get skippedCount => skipped.length;
}

/// Offline-First Client Mutation Outbox Engine (REQ-P44-SYNC-01..06).
/// Backed by Hive box `vhunambi_sync_outbox_box` with in-memory test fallback.
///
/// Phase 48 additions: priority queueing, schema v2, compaction, size cap,
/// dead-letter handling, and partial-failure flush processing.
class SyncOutboxService {
  static const String boxName = 'vhunambi_sync_outbox_box';

  /// Phase 48: maximum outbox size before eviction begins.
  static const int maxOutboxSize = 1000;

  /// Phase 48: maximum retry count before a record moves to deadLetter.
  static const int maxRetries = 5;

  /// Phase 48: TTL in days before a record moves to deadLetter.
  static const int ttlDays = 7;

  final Map<String, SyncMutationRecord> _inMemoryQueue = {};
  Box<Map>? _hiveBox;
  final bool isInMemoryOnly;
  bool _isInitialized = false;

  SyncOutboxService({Box<Map>? testBox, this.isInMemoryOnly = false})
      : _hiveBox = testBox;

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;
    if (isInMemoryOnly || _hiveBox != null) return;

    // Headless test guard: prevent HiveImpl._openBox unhandled Completer crash
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      _hiveBox = null;
      return;
    }
    try {
      if (Hive.isBoxOpen(boxName)) {
        _hiveBox = Hive.box<Map>(boxName);
      } else {
        _hiveBox = await Hive.openBox<Map>(boxName);
      }
    } catch (_) {
      // In-memory fallback if Hive is not initialized in tests or restricted OS sandbox
      _hiveBox = null;
    }
  }

  /// Enqueues a mutation record with idempotent deduplication (REQ-P44-SYNC-03).
  Future<void> enqueue(SyncMutationRecord record) async {
    await init();
    _inMemoryQueue[record.idempotencyKey] = record;
    if (_hiveBox != null && _hiveBox!.isOpen) {
      await _hiveBox!.put(record.idempotencyKey, record.toJson());
    }
  }

  /// Returns list of all pending mutations awaiting synchronization.
  /// Alias for getPendingMutations.
  List<SyncMutationRecord> getPending() => getPendingMutations();

  /// Returns all records eligible for flushing: `pending` or `failedRetryable`,
  /// excluding `deadLetter`. Does NOT apply priority ordering.
  List<SyncMutationRecord> getPendingMutations() {
    if (_hiveBox != null && _hiveBox!.isOpen) {
      return _hiveBox!.values
          .map((m) => SyncMutationRecord.fromJson(m))
          .where((r) =>
              r.status == SyncRecordStatus.pending ||
              r.status == SyncRecordStatus.failedRetryable)
          .toList();
    }
    return _inMemoryQueue.values
        .where((r) =>
            r.status == SyncRecordStatus.pending ||
            r.status == SyncRecordStatus.failedRetryable)
        .toList();
  }

  /// Phase 48: Returns up to [maxBatchSize] records sorted by priority
  /// (critical → normal → background), then chronological `createdAt`.
  /// Excludes `deadLetter` records.
  List<SyncMutationRecord> getPendingBatch({int maxBatchSize = 50}) {
    final pending = getPendingMutations()
      ..sort((a, b) {
        final pa = a.priority.index;
        final pb = b.priority.index;
        if (pa != pb) return pa.compareTo(pb);
        return a.createdAt.compareTo(b.createdAt);
      });
    return pending.take(maxBatchSize).toList();
  }

  /// Phase 48: Returns all records in `deadLetter` status for inspection/clearing.
  List<SyncMutationRecord> get deadLetterRecords {
    if (_hiveBox != null && _hiveBox!.isOpen) {
      return _hiveBox!.values
          .map((m) => SyncMutationRecord.fromJson(m))
          .where((r) => r.status == SyncRecordStatus.deadLetter)
          .toList();
    }
    return _inMemoryQueue.values
        .where((r) => r.status == SyncRecordStatus.deadLetter)
        .toList();
  }

  /// Phase 48: Flushes pending mutations in priority batches to the backend API transport.
  /// Processes `applied`/`skipped`/`failed` results per-item:
  ///   - applied/skipped → removed from outbox (markSynced)
  ///   - failed retryable → increment retryCount (markFailed)
  ///   - failed non-retryable → move to deadLetter (markFailed)
  Future<SyncFlushResult> flush({
    Future<SyncFlushResult> Function(List<SyncMutationRecord> batch)? transport,
  }) async {
    await init();
    final pending = getPendingBatch();
    if (pending.isEmpty) {
      return const SyncFlushResult(applied: [], skipped: [], failed: [], latestSeq: 0);
    }

    if (transport != null) {
      final result = await transport(pending);

      // Remove applied and skipped keys from outbox.
      for (final key in result.applied) {
        await markSynced(key);
      }
      for (final key in result.skipped) {
        await markSynced(key);
      }

      // Handle partial failures.
      for (final failed in result.failed) {
        await markFailed(failed.idempotencyKey, failed.retryable);
      }

      // Enforce outbox size cap after all mutations processed.
      await _compact();

      return result;
    }

    // Default simulated transport if no custom HTTP transport provided.
    final keys = pending.map((p) => p.idempotencyKey).toList();
    for (final key in keys) {
      await markSynced(key);
    }
    await _compact();
    return SyncFlushResult(applied: keys, skipped: [], failed: [], latestSeq: 100);
  }

  /// Marks a mutation record as successfully synchronized (removed from outbox).
  Future<void> markSynced(String idempotencyKey) async {
    await init();
    if (_inMemoryQueue.containsKey(idempotencyKey)) {
      _inMemoryQueue.remove(idempotencyKey);
    }
    if (_hiveBox != null && _hiveBox!.isOpen) {
      await _hiveBox!.delete(idempotencyKey);
    }
  }

  /// Phase 48: Handles a failed mutation — increments retryCount, or moves to
  /// deadLetter if maxRetries exceeded or non-retryable.
  Future<void> markFailed(String idempotencyKey, bool retryable) async {
    await init();

    SyncMutationRecord? current;
    if (_inMemoryQueue.containsKey(idempotencyKey)) {
      current = _inMemoryQueue[idempotencyKey];
    } else if (_hiveBox != null && _hiveBox!.isOpen) {
      final raw = _hiveBox!.get(idempotencyKey);
      if (raw != null) {
        current = SyncMutationRecord.fromJson(raw);
      }
    }

    if (current == null) return;

    final now = DateTime.now();
    final ttlExpired = now.difference(current.createdAt).inDays >= ttlDays;

    if (!retryable || current.retryCount + 1 >= maxRetries || ttlExpired) {
      // Move to deadLetter.
      if (_inMemoryQueue.containsKey(idempotencyKey)) {
        _inMemoryQueue[idempotencyKey] = current.copyWith(
          status: SyncRecordStatus.deadLetter,
          retryCount: current.retryCount + 1,
        );
      }
      if (_hiveBox != null && _hiveBox!.isOpen) {
        await _hiveBox!.put(
          idempotencyKey,
          current.copyWith(
            status: SyncRecordStatus.deadLetter,
            retryCount: current.retryCount + 1,
          ).toJson(),
        );
      }
    } else {
      // Increment retryCount, stay in failedRetryable.
      if (_inMemoryQueue.containsKey(idempotencyKey)) {
        _inMemoryQueue[idempotencyKey] = current.copyWith(
          status: SyncRecordStatus.failedRetryable,
          retryCount: current.retryCount + 1,
        );
      }
      if (_hiveBox != null && _hiveBox!.isOpen) {
        await _hiveBox!.put(
          idempotencyKey,
          current.copyWith(
            status: SyncRecordStatus.failedRetryable,
            retryCount: current.retryCount + 1,
          ).toJson(),
        );
      }
    }
  }

  /// Phase 48: Enforces outbox size cap by evicting oldest `background` records
  /// first. Never evicts `critical` records. Called after every flush.
  Future<void> _compact() async {
    final all = <SyncMutationRecord>[];
    if (_hiveBox != null && _hiveBox!.isOpen) {
      all.addAll(_hiveBox!.values.map((m) => SyncMutationRecord.fromJson(m)));
    } else {
      all.addAll(_inMemoryQueue.values);
    }

    if (all.length <= maxOutboxSize) return;

    // Sort: background first (oldest first), then normal, then critical (never evict).
    final toEvict = <String>[];
    final backgroundRecords = all
        .where((r) => r.priority == SyncPriority.background)
        .toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final normalRecords = all
        .where((r) => r.priority == SyncPriority.normal)
        .toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final excess = all.length - maxOutboxSize;
    var evicted = 0;

    for (final r in backgroundRecords) {
      if (evicted >= excess) break;
      toEvict.add(r.idempotencyKey);
      evicted++;
    }

    for (final r in normalRecords) {
      if (evicted >= excess) break;
      toEvict.add(r.idempotencyKey);
      evicted++;
    }

    // Never evict critical records.

    for (final key in toEvict) {
      _inMemoryQueue.remove(key);
      if (_hiveBox != null && _hiveBox!.isOpen) {
        await _hiveBox!.delete(key);
      }
    }
  }

  /// Total count of pending items in queue.
  int get pendingCount => getPendingMutations().length;

  /// Clears the outbox (used in tests).
  Future<void> clear() async {
    _inMemoryQueue.clear();
    if (_hiveBox != null && _hiveBox!.isOpen) {
      await _hiveBox!.clear();
    }
  }
}

/// Global provider for SyncOutboxService
final syncOutboxServiceProvider = Provider<SyncOutboxService>((ref) {
  return SyncOutboxService();
});

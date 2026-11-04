import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Status of a local offline mutation record (REQ-P44-SYNC-02).
enum SyncStatus {
  pending,
  syncing,
  synced,
  failed,
}

/// A durable, idempotent mutation record stored in the client outbox (REQ-P44-SYNC-02).
class SyncMutationRecord {
  final String idempotencyKey;
  final String entityType; // 'post' | 'track' | 'tip' | 'cosign' | 'remix'
  final String action;     // 'create' | 'update' | 'delete' | 'cosign' | 'tip'
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int retryCount;
  final SyncStatus status;

  const SyncMutationRecord({
    required this.idempotencyKey,
    required this.entityType,
    required this.action,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
    this.status = SyncStatus.pending,
  });

  SyncMutationRecord copyWith({
    String? idempotencyKey,
    String? entityType,
    String? action,
    Map<String, dynamic>? payload,
    DateTime? createdAt,
    int? retryCount,
    SyncStatus? status,
  }) {
    return SyncMutationRecord(
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      entityType: entityType ?? this.entityType,
      action: action ?? this.action,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
      status: status ?? this.status,
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
  };

  factory SyncMutationRecord.fromJson(Map<dynamic, dynamic> map) {
    return SyncMutationRecord(
      idempotencyKey: map['idempotencyKey'] as String? ?? 'unknown_key',
      entityType: map['entityType'] as String? ?? 'unknown',
      action: map['action'] as String? ?? 'unknown',
      payload: Map<String, dynamic>.from(map['payload'] as Map? ?? {}),
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      retryCount: (map['retryCount'] as num?)?.toInt() ?? 0,
      status: SyncStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => SyncStatus.pending,
      ),
    );
  }
}

/// Result of an edge flush to the backend API (REQ-P44-SYNC-05).
class SyncFlushResult {
  final List<String> applied;
  final List<String> skipped;
  final int latestSeq;

  const SyncFlushResult({
    required this.applied,
    required this.skipped,
    required this.latestSeq,
  });
}

/// Offline-First Client Mutation Outbox Engine (REQ-P44-SYNC-01..06).
/// Backed by Hive box `vhunambi_sync_outbox_box` with in-memory test fallback.
class SyncOutboxService {
  static const String boxName = 'vhunambi_sync_outbox_box';
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
    try {
      if (Hive.isBoxOpen(boxName)) {
        _hiveBox = Hive.box<Map>(boxName);
      } else {
        _hiveBox = await Hive.openBox<Map>(boxName);
      }
    } on Object {
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
  List<SyncMutationRecord> getPendingMutations() {
    if (_hiveBox != null && _hiveBox!.isOpen) {
      return _hiveBox!.values
          .map((m) => SyncMutationRecord.fromJson(m))
          .where((r) => r.status == SyncStatus.pending || r.status == SyncStatus.failed)
          .toList();
    }
    return _inMemoryQueue.values
        .where((r) => r.status == SyncStatus.pending || r.status == SyncStatus.failed)
        .toList();
  }

  /// Flushes pending mutations to the backend API transport (REQ-P44-SYNC-04).
  Future<SyncFlushResult> flush({
    Future<SyncFlushResult> Function(List<SyncMutationRecord> batch)? transport,
  }) async {
    final pending = getPendingMutations();
    if (pending.isEmpty) {
      return const SyncFlushResult(applied: [], skipped: [], latestSeq: 0);
    }

    if (transport != null) {
      final result = await transport(pending);
      for (final key in result.applied) {
        await markSynced(key);
      }
      for (final key in result.skipped) {
        await markSynced(key);
      }
      return result;
    }

    // Default simulated transport if no custom HTTP transport provided
    final keys = pending.map((p) => p.idempotencyKey).toList();
    for (final key in keys) {
      await markSynced(key);
    }
    return SyncFlushResult(applied: keys, skipped: [], latestSeq: 100);
  }

  /// Marks a mutation record as successfully synchronized.
  Future<void> markSynced(String idempotencyKey) async {
    await init();
    if (_inMemoryQueue.containsKey(idempotencyKey)) {
      _inMemoryQueue[idempotencyKey] = _inMemoryQueue[idempotencyKey]!.copyWith(
        status: SyncStatus.synced,
      );
    }
    if (_hiveBox != null && _hiveBox!.isOpen) {
      await _hiveBox!.delete(idempotencyKey);
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

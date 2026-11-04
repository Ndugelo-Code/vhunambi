# Phase 48 Technical Design: Edge Sync Production Hardening

## 1. Domain Models & State Management

### 1.1 `SyncMutationRecord` (Schema v2)

```dart
enum SyncPriority { critical, normal, background }

enum SyncRecordStatus { pending, failedRetryable, deadLetter }

class SyncMutationRecord {
  final String idempotencyKey;
  final String entityType;
  final String action;
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
    if (baseSeq != null) 'baseSeq': baseSeq,
    'schemaVersion': schemaVersion,
  };

  /// Graceful v1 -> v2 migration: missing priority/baseSeq/schemaVersion default safely.
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
```

### 1.2 `SyncFlushResult` (Extended with Partial Failure & Backward Compatibility)

```dart
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

  // Backward-compatible accessors for Phase 44/45/46 tests
  int get appliedCount => applied.length;
  int get skippedCount => skipped.length;
}

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

  factory SyncFailedItem.fromJson(Map<String, dynamic> json) {
    return SyncFailedItem(
      idempotencyKey: json['idempotencyKey'] as String? ?? '',
      code: json['code'] as String? ?? 'UNKNOWN_ERROR',
      message: json['message'] as String? ?? '',
      retryable: json['retryable'] as bool? ?? true,
    );
  }
}
```

### 1.3 `SyncTelemetryEvent` & Bounded Ring Buffer

```dart
enum SyncTelemetryEventType {
  enqueued,
  batchFlushed,
  partialFailure,
  deltaHydrated,
  deadLetterMoved,
}

@immutable
class SyncTelemetryEvent {
  final SyncTelemetryEventType type;
  final DateTime timestamp;
  final int? latencyMs;
  final Map<String, dynamic>? metadata;

  const SyncTelemetryEvent({
    required this.type,
    required this.timestamp,
    this.latencyMs,
    this.metadata,
  });
}

/// Bounded 50-item ring buffer. Oldest evicted when full.
class SyncTelemetryRingBuffer {
  static const int _maxSize = 50;
  final List<SyncTelemetryEvent> _events = [];

  void record(SyncTelemetryEvent event) {
    _events.add(event);
    if (_events.length > _maxSize) {
      _events.removeAt(0);
    }
  }

  List<SyncTelemetryEvent> get all => List.unmodifiable(_events);
}
```

### 1.4 `EdgeSyncState` (Extended)

```dart
@immutable
class EdgeSyncState {
  final EdgeSyncStatus status;
  final int lastServerSeq;
  final int pendingOutboxCount;
  final DateTime? lastSyncedAt;
  final String? errorMessage;
  final int deadLetterCount;
  final int lastSyncLatencyMs;
  final List<SyncTelemetryEvent> telemetry;

  const EdgeSyncState({
    this.status = EdgeSyncStatus.idle,
    this.lastServerSeq = 0,
    this.pendingOutboxCount = 0,
    this.lastSyncedAt,
    this.errorMessage,
    this.deadLetterCount = 0,
    this.lastSyncLatencyMs = 0,
    this.telemetry = const [],
  });

  EdgeSyncState copyWith({
    EdgeSyncStatus? status,
    int? lastServerSeq,
    int? pendingOutboxCount,
    DateTime? lastSyncedAt,
    String? errorMessage,
    int? deadLetterCount,
    int? lastSyncLatencyMs,
    List<SyncTelemetryEvent>? telemetry,
  }) {
    return EdgeSyncState(
      status: status ?? this.status,
      lastServerSeq: lastServerSeq ?? this.lastServerSeq,
      pendingOutboxCount: pendingOutboxCount ?? this.pendingOutboxCount,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      errorMessage: errorMessage ?? this.errorMessage,
      deadLetterCount: deadLetterCount ?? this.deadLetterCount,
      lastSyncLatencyMs: lastSyncLatencyMs ?? this.lastSyncLatencyMs,
      telemetry: telemetry ?? this.telemetry,
    );
  }
}
```

---

## 2. Client Component Architecture

```
[ SyncOutboxService ]
  ├── Box: vhunambi_sync_outbox_box (Hive, JSON maps, schemaVersion: 2)
  ├── enqueue(record) — idempotent dedup by idempotencyKey
  ├── getPendingBatch({maxBatchSize = 50}) — priority-ordered, excludes deadLetter
  ├── flush({transport}) — sends batch, processes applied/skipped/failed
  ├── markSynced(key) — removes applied/skipped from box
  ├── markFailed(key, retryable) — increments retryCount or moves to deadLetter
  ├── get pendingCount — pending + failedRetryable only
  ├── get deadLetterRecords — all deadLetter records
  └── clear() — test only

[ EdgeSyncCoordinator : StateNotifier<EdgeSyncState> ]
  ├── syncNow() — flush outbox → multi-page delta drain loop → update state + telemetry
  ├── onAppResumed() — auto-flush when pendingCount > 0
  ├── Stream<bool> connectivityStream (injectable, defaults to Stream.empty())
  └── EdgeSyncState — includes telemetry ring buffer + lastSyncLatencyMs
```

---

## 3. Backend Component Architecture & SQLite Statements

```
[ sync_routes.ts ]
  ├── POST /api/v1/sync/mutations
  │   ├── Body: { mutations: SyncMutationRecord[] }
  │   ├── Calls vhunambiDb.applyMutationsBatch(mutations)
  │   └── Response: { applied, skipped, failed[], latestSeq, appliedCount, skippedCount }
  └── GET /api/v1/sync/delta?since_seq=X&limit=Y
      ├── limit: 1..200 (default 100)
      ├── Response: { changes, latestSeq, nextCursorSeq, hasMore, mutations, latest_seq }
      └── ETag: "cursor-<latestSeq>" / 304 Not Modified preserved

[ vhunambi_db.ts ]
  ├── applyMutationsBatch(mutations)
  │   ├── Per-item SQLite SAVEPOINT
  │   ├── Commutative counters: SET count = count + 1
  │   ├── Versioned edits: baseSeq stale -> conflict, skip
  │   └── Returns { applied, skipped, failed[], latestSeq }
  └── getDelta(sinceSeq, limit)
      ├── SELECT * FROM mutations WHERE seq > ? ORDER BY seq ASC LIMIT ?
      └── Returns { changes, latestSeq, nextCursorSeq, hasMore }
```

### 3.1 SQLite SAVEPOINT Statement Patterns

```sql
-- For each mutation item:
SAVEPOINT mutation_sp;

-- If item succeeds:
INSERT OR IGNORE INTO mutations (seq, idempotency_key, entity_type, action, payload, created_at)
VALUES (?, ?, ?, ?, ?, ?);
RELEASE SAVEPOINT mutation_sp;

-- If item fails validation:
ROLLBACK TO SAVEPOINT mutation_sp;
RELEASE SAVEPOINT mutation_sp;
```

---

## 4. Priority Ordering Matrix

| Priority | Entity Types & Actions | Drain Order |
|---|---|---|
| `critical` | wallet topup, payout, beat license, remix royalty split | 1st (Immediate) |
| `normal` | post create, repost, profile edit, Open-Verse publish | 2nd |
| `background` | like, cosign, play count increment | 3rd |

*Rule:* Items within the same priority rank are ordered by `createdAt` ascending (chronological).

---

## 5. Deterministic Widget Keys Table

| Widget Component | Target File | Key Value |
|---|---|---|
| Sync Now button | `profile_settings_drawer.dart` | `const Key('settings_sync_now_btn')` |
| Dead-letter count chip | `profile_settings_drawer.dart` | `const Key('settings_dead_letter_count')` |
| Telemetry latency text | `profile_settings_drawer.dart` | `const Key('settings_sync_latency_ms')` |

---

## 6. Geometry & Invariant Limits

- **Outbox size cap:** 1,000 records; evict oldest `background` first; never evict `critical`.
- **Dead-letter TTL:** 7 days (`ttlDays = 7`); max retries: `maxRetries = 5`.
- **Delta page limit:** 1–200 items (default 100); max 10 pages per sync cycle.
- **Telemetry ring buffer:** 50 events maximum.

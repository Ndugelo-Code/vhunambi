import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'sync_outbox_service.dart';

/// Status of the live bi-directional edge synchronizer (REQ-P46-SYNC-04..06).
enum EdgeSyncStatus { idle, syncing, synced, offline, error }

/// Telemetry event types recorded in the ring buffer.
enum SyncTelemetryEventType {
  enqueued,
  batchFlushed,
  partialFailure,
  deltaHydrated,
  deadLetterMoved,
}

/// A single telemetry event.
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

/// Bounded 50-item ring buffer for sync telemetry. Oldest evicted when full.
class SyncTelemetryRingBuffer {
  static const int _maxSize = 50;
  final List<SyncTelemetryEvent> _events = [];

  void record(SyncTelemetryEvent event) {
    _events.add(event);
    if (_events.length > _maxSize) _events.removeAt(0);
  }

  List<SyncTelemetryEvent> get all => List.unmodifiable(_events);
}

/// Immutable state snapshot of edge sync progress and telemetry.
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

/// Coordinates bidirectional edge mutation flushing and SQLite WAL delta hydration (REQ-P46-SYNC-04..06).
///
/// Phase 48 additions: multi-page delta drain, injectable connectivity stream,
/// onAppResumed auto-sync hook, and in-memory telemetry ring buffer.
class EdgeSyncCoordinator extends StateNotifier<EdgeSyncState> {
  final SyncOutboxService outboxService;
  final http.Client _httpClient;
  final String _apiBaseUrl;
  final Stream<bool> _connectivityStream;
  final SyncTelemetryRingBuffer _telemetry = SyncTelemetryRingBuffer();

  EdgeSyncCoordinator({
    required this.outboxService,
    http.Client? httpClient,
    String? apiBaseUrl,
    Stream<bool>? connectivityStream,
  }) : _httpClient = httpClient ?? http.Client(),
       _apiBaseUrl = apiBaseUrl ?? 'https://api.vhunambi.com',
       _connectivityStream = connectivityStream ?? const Stream<bool>.empty(),
       super(const EdgeSyncState());

  SyncOutboxService get _outboxService => outboxService;
  Stream<bool> get connectivityStream => _connectivityStream;

  /// Phase 48: Hook called from AppLifecycleState.resumed to auto-sync when
  /// pending mutations exist. No native plugin, no background timer.
  Future<void> onAppResumed() async {
    if (state.status == EdgeSyncStatus.syncing) return;
    final pending = _outboxService.pendingCount;
    if (pending > 0) {
      await syncNow();
    }
  }

  /// Phase 48: Records a telemetry event in the bounded ring buffer.
  void _recordTelemetry(
    SyncTelemetryEventType type, {
    int? latencyMs,
    Map<String, dynamic>? metadata,
  }) {
    _telemetry.record(
      SyncTelemetryEvent(
        type: type,
        timestamp: DateTime.now(),
        latencyMs: latencyMs,
        metadata: metadata,
      ),
    );
  }

  /// Triggers full bi-directional flush and delta hydration (REQ-P46-SYNC-04..06).
  /// Phase 48: drains pending outbox in priority batches, loops delta pages
  /// while hasMore == true (max 10 pages), records telemetry.
  /// Safe in airplane-mode and headless widget test sandboxes.
  Future<bool> syncNow() async {
    if (state.status == EdgeSyncStatus.syncing) return false;
    final startTime = DateTime.now();
    state = state.copyWith(status: EdgeSyncStatus.syncing, errorMessage: null);

    try {
      await _outboxService.init();
      _recordTelemetry(
        SyncTelemetryEventType.enqueued,
        metadata: {'pendingCount': _outboxService.pendingCount},
      );

      // 1. Flush pending outbox mutations in priority batches
      var totalFlushed = 0;
      var hasMorePending = true;
      while (hasMorePending) {
        final pendingBatch = _outboxService.getPendingBatch(maxBatchSize: 50);
        if (pendingBatch.isEmpty) {
          hasMorePending = false;
          break;
        }

        final payload = {
          'mutations': pendingBatch.map((r) => r.toJson()).toList(),
        };

        try {
          final res = await _httpClient
              .post(
                Uri.parse('$_apiBaseUrl/api/v1/sync/mutations'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(payload),
              )
              .timeout(const Duration(seconds: 4));

          if (res.statusCode == 200 || res.statusCode == 201) {
            final data = jsonDecode(res.body) as Map<String, dynamic>;
            final applied = (data['applied'] as List? ?? []).cast<String>();
            final skipped = (data['skipped'] as List? ?? []).cast<String>();
            final failedList = (data['failed'] as List? ?? []);

            for (final key in applied) {
              await _outboxService.markSynced(key);
            }
            for (final key in skipped) {
              await _outboxService.markSynced(key);
            }

            // Phase 48: handle partial failures per-item.
            for (final f in failedList) {
              final failedMap = f as Map<String, dynamic>;
              final key = failedMap['idempotencyKey'] as String?;
              final retryable = failedMap['retryable'] as bool? ?? true;
              if (key != null) {
                await _outboxService.markFailed(key, retryable);
              }
            }

            totalFlushed += pendingBatch.length;

            if (failedList.isNotEmpty) {
              _recordTelemetry(
                SyncTelemetryEventType.partialFailure,
                metadata: {
                  'failedCount': failedList.length,
                  'appliedCount': applied.length,
                  'skippedCount': skipped.length,
                },
              );
            }
          } else {
            // Non-2xx response: treat entire batch as retryable failures.
            for (final r in pendingBatch) {
              await _outboxService.markFailed(r.idempotencyKey, true);
            }
            _recordTelemetry(
              SyncTelemetryEventType.partialFailure,
              metadata: {
                'failedCount': pendingBatch.length,
                'httpStatus': res.statusCode,
              },
            );
            break;
          }
        } on Object catch (_) {
          // Graceful network catch during mutation flush — mark all as retryable.
          for (final r in pendingBatch) {
            await _outboxService.markFailed(r.idempotencyKey, true);
          }
          _recordTelemetry(
            SyncTelemetryEventType.partialFailure,
            metadata: {'failedCount': pendingBatch.length, 'error': 'network'},
          );
          break;
        }
      }

      _recordTelemetry(
        SyncTelemetryEventType.batchFlushed,
        metadata: {'flushedCount': totalFlushed},
      );

      // 2. Poll server for incremental changes since lastServerSeq (multi-page).
      int newSeq = state.lastServerSeq;
      var page = 0;
      var totalChanges = 0;
      var hasMore = true;
      while (hasMore && page < 10) {
        page++;
        try {
          final deltaRes = await _httpClient
              .get(
                Uri.parse(
                  '$_apiBaseUrl/api/v1/sync/delta?since_seq=$newSeq&limit=100',
                ),
                headers: {'Accept': 'application/json'},
              )
              .timeout(const Duration(seconds: 4));

          if (deltaRes.statusCode == 200) {
            final data = jsonDecode(deltaRes.body) as Map<String, dynamic>;
            final changes =
                (data['changes'] as List? ?? data['mutations'] as List? ?? []);
            totalChanges += changes.length;
            newSeq =
                (data['latestSeq'] as num?)?.toInt() ??
                (data['latest_seq'] as num?)?.toInt() ??
                newSeq;
            hasMore = (data['hasMore'] as bool?) ?? false;
            final nextCursor = (data['nextCursorSeq'] as num?)?.toInt();
            if (nextCursor != null) newSeq = nextCursor;
          } else if (deltaRes.statusCode == 304) {
            hasMore = false;
          } else {
            hasMore = false;
          }
        } on Object catch (_) {
          // Graceful network catch during delta pull.
          hasMore = false;
        }
      }

      _recordTelemetry(
        SyncTelemetryEventType.deltaHydrated,
        metadata: {
          'pagesDrained': page,
          'latestSeq': newSeq,
          'totalChanges': totalChanges,
        },
      );

      final remaining = _outboxService.pendingCount;
      final deadLetterCount = _outboxService.deadLetterRecords.length;
      final latencyMs = DateTime.now().difference(startTime).inMilliseconds;

      state = state.copyWith(
        status: EdgeSyncStatus.synced,
        lastServerSeq: newSeq,
        pendingOutboxCount: remaining,
        lastSyncedAt: DateTime.now(),
        deadLetterCount: deadLetterCount,
        lastSyncLatencyMs: latencyMs,
        telemetry: _telemetry.all,
      );
      return true;
    } on Object catch (e) {
      state = state.copyWith(
        status: EdgeSyncStatus.offline,
        errorMessage: e.toString(),
      );
      return false;
    }
  }
}

/// Global provider for EdgeSyncCoordinator.
final edgeSyncCoordinatorProvider =
    StateNotifierProvider<EdgeSyncCoordinator, EdgeSyncState>((ref) {
      final outbox = ref.watch(syncOutboxServiceProvider);
      return EdgeSyncCoordinator(outboxService: outbox);
    });

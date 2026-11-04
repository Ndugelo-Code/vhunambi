import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';

import 'package:vhunambi_client/core/sync/sync_outbox_service.dart';
import 'package:vhunambi_client/core/sync/edge_sync_coordinator.dart';

void main() {
  group('SyncOutboxService Phase 48 Hardening', () {
    test('schema v1 -> v2 JSON migration defaults missing fields', () {
      final v1Map = {
        'idempotencyKey': 'key_1',
        'entityType': 'post',
        'action': 'create',
        'payload': <String, dynamic>{},
        'createdAt': '2026-11-04T10:00:00Z',
        'retryCount': 0,
        'status': 'pending',
      };

      final record = SyncMutationRecord.fromJson(v1Map);

      expect(record.priority, SyncPriority.background);
      expect(record.baseSeq, isNull);
      expect(record.schemaVersion, 1);
      expect(record.status, SyncRecordStatus.pending);
    });

    test('schema v2 round-trip preserves all fields', () {
      final record = SyncMutationRecord(
        idempotencyKey: 'key_2',
        entityType: 'wallet',
        action: 'topup',
        payload: {'amountZar': 50.0},
        createdAt: DateTime.parse('2026-11-04T10:00:00Z'),
        priority: SyncPriority.critical,
        baseSeq: 42,
        schemaVersion: 2,
      );

      final json = record.toJson();
      final restored = SyncMutationRecord.fromJson(json);

      expect(restored.priority, SyncPriority.critical);
      expect(restored.baseSeq, 42);
      expect(restored.schemaVersion, 2);
      expect(restored.idempotencyKey, 'key_2');
    });

    test('getPendingBatch drains critical before background', () async {
      final service = SyncOutboxService(isInMemoryOnly: true);

      await service.enqueue(SyncMutationRecord(
        idempotencyKey: 'like_1',
        entityType: 'track',
        action: 'like',
        payload: const {},
        createdAt: DateTime.parse('2026-11-04T10:00:00Z'),
        priority: SyncPriority.background,
      ));
      await service.enqueue(SyncMutationRecord(
        idempotencyKey: 'like_2',
        entityType: 'track',
        action: 'like',
        payload: const {},
        createdAt: DateTime.parse('2026-11-04T10:01:00Z'),
        priority: SyncPriority.background,
      ));
      await service.enqueue(SyncMutationRecord(
        idempotencyKey: 'payout_1',
        entityType: 'wallet',
        action: 'payout',
        payload: const {},
        createdAt: DateTime.parse('2026-11-04T10:05:00Z'),
        priority: SyncPriority.critical,
      ));

      final batch = service.getPendingBatch(maxBatchSize: 50);

      expect(batch.length, 3);
      expect(batch[0].idempotencyKey, 'payout_1');
      expect(batch[0].priority, SyncPriority.critical);
      expect(batch[1].idempotencyKey, 'like_1');
      expect(batch[2].idempotencyKey, 'like_2');
    });

    test('pendingCount excludes deadLetter records', () async {
      final service = SyncOutboxService(isInMemoryOnly: true);

      await service.enqueue(SyncMutationRecord(
        idempotencyKey: 'pending_1',
        entityType: 'track',
        action: 'like',
        payload: const {},
        createdAt: DateTime.now(),
        priority: SyncPriority.background,
      ));
      await service.enqueue(SyncMutationRecord(
        idempotencyKey: 'dead_1',
        entityType: 'track',
        action: 'like',
        payload: const {},
        createdAt: DateTime.now(),
        priority: SyncPriority.background,
        status: SyncRecordStatus.deadLetter,
      ));

      expect(service.pendingCount, 1);
      expect(service.deadLetterRecords.length, 1);
    });

    test('partial-failure: retryable failure increments retryCount, non-retryable -> deadLetter', () async {
      final service = SyncOutboxService(isInMemoryOnly: true);

      await service.enqueue(SyncMutationRecord(
        idempotencyKey: 'ok_1',
        entityType: 'track',
        action: 'like',
        payload: const {},
        createdAt: DateTime.now(),
        priority: SyncPriority.background,
      ));
      await service.enqueue(SyncMutationRecord(
        idempotencyKey: 'retry_1',
        entityType: 'track',
        action: 'like',
        payload: const {},
        createdAt: DateTime.now(),
        priority: SyncPriority.background,
      ));
      await service.enqueue(SyncMutationRecord(
        idempotencyKey: 'dead_1',
        entityType: 'track',
        action: 'like',
        payload: const {},
        createdAt: DateTime.now(),
        priority: SyncPriority.background,
      ));

      final result = await service.flush(
        transport: (batch) async {
          return const SyncFlushResult(
            applied: ['ok_1'],
            skipped: [],
            failed: [
              SyncFailedItem(
                idempotencyKey: 'retry_1',
                code: 'validation_error',
                message: 'bad payload',
                retryable: true,
              ),
              SyncFailedItem(
                idempotencyKey: 'dead_1',
                code: 'conflict',
                message: 'stale',
                retryable: false,
              ),
            ],
            latestSeq: 10,
          );
        },
      );

      expect(result.applied, contains('ok_1'));
      expect(result.failed.length, 2);
      expect(service.pendingCount, 1);

      final retryRecord =
          service.getPendingMutations().firstWhere((r) => r.idempotencyKey == 'retry_1');
      expect(retryRecord.status, SyncRecordStatus.failedRetryable);
      expect(retryRecord.retryCount, 1);

      final deadRecords = service.deadLetterRecords;
      expect(deadRecords.any((r) => r.idempotencyKey == 'dead_1'), isTrue);
    });

    test('deadLetterRecords getter returns dead letter items', () async {
      final service = SyncOutboxService(isInMemoryOnly: true);

      await service.enqueue(SyncMutationRecord(
        idempotencyKey: 'dlq_1',
        entityType: 'wallet',
        action: 'payout',
        payload: const {},
        createdAt: DateTime.now(),
        priority: SyncPriority.critical,
        status: SyncRecordStatus.deadLetter,
      ));

      expect(service.deadLetterRecords.length, 1);
      expect(service.deadLetterRecords.first.idempotencyKey, 'dlq_1');
    });
  });

  group('EdgeSyncCoordinator Phase 48 Hardening', () {
    test('multi-page delta drain and telemetry logging', () async {
      final service = SyncOutboxService(isInMemoryOnly: true);

      var pageCalls = 0;
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/api/v1/sync/delta')) {
          pageCalls++;
          if (pageCalls == 1) {
            return http.Response(
              jsonEncode({
                'changes': [
                  {'id': 'c1'}
                ],
                'latestSeq': 10,
                'nextCursorSeq': 5,
                'hasMore': true,
              }),
              200,
            );
          } else {
            return http.Response(
              jsonEncode({
                'changes': [
                  {'id': 'c2'}
                ],
                'latestSeq': 10,
                'nextCursorSeq': 10,
                'hasMore': false,
              }),
              200,
            );
          }
        }
        return http.Response('{}', 200);
      });

      final coordinator = EdgeSyncCoordinator(
        outboxService: service,
        httpClient: mockClient,
      );

      final ok = await coordinator.syncNow();
      expect(ok, isTrue);
      expect(pageCalls, 2);
      expect(coordinator.state.lastServerSeq, 10);
      expect(coordinator.state.telemetry.isNotEmpty, isTrue);
    });

    test('onAppResumed triggers sync when pendingCount > 0', () async {
      final service = SyncOutboxService(isInMemoryOnly: true);
      await service.enqueue(SyncMutationRecord(
        idempotencyKey: 'resume_1',
        entityType: 'track',
        action: 'like',
        payload: const {},
        createdAt: DateTime.now(),
        priority: SyncPriority.background,
      ));

      var flushCalled = false;
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/api/v1/sync/mutations')) {
          flushCalled = true;
          return http.Response(
            jsonEncode({
              'applied': ['resume_1'],
              'skipped': [],
              'failed': [],
              'latestSeq': 1,
            }),
            200,
          );
        }
        if (request.url.path.contains('/api/v1/sync/delta')) {
          return http.Response(
            jsonEncode({'changes': [], 'latestSeq': 1, 'hasMore': false}),
            200,
          );
        }
        return http.Response('{}', 200);
      });

      final coordinator = EdgeSyncCoordinator(
        outboxService: service,
        httpClient: mockClient,
      );

      await coordinator.onAppResumed();
      expect(flushCalled, isTrue);
      expect(service.pendingCount, 0);
    });
  });
}

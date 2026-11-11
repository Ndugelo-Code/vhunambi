import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:vhunambi_client/core/auth/auth_providers.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/core/storage/sovereign_domain_repositories.dart';
import 'package:vhunambi_client/features/library/domain/models/library_models.dart';
import 'package:vhunambi_client/features/library/presentation/providers/library_providers.dart';
import 'package:vhunambi_client/features/playlists/data/repositories/playlist_repository.dart';
import 'package:vhunambi_client/features/playlists/domain/models/playlist_entity.dart';
import 'package:vhunambi_client/features/playlists/presentation/providers/playlists_provider.dart';
import 'sync_outbox_service.dart';

/// Status of the live bi-directional edge synchronizer (REQ-P46-SYNC-04..06).
enum EdgeSyncStatus { idle, syncing, synced, offline, error }

/// Callback invoked when incremental changes are pulled from `/api/v1/sync/delta` (Phase 59).
typedef SyncDeltaHydrator =
    FutureOr<void> Function(List<Map<String, dynamic>> mutations);

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
  final Map<String, String> Function()? _authHeadersBuilder;
  final String Function()? _creatorIdReader;
  final SyncTelemetryRingBuffer _telemetry = SyncTelemetryRingBuffer();
  final List<SyncDeltaHydrator> _deltaHydrators = [];

  EdgeSyncCoordinator({
    required this.outboxService,
    http.Client? httpClient,
    String? apiBaseUrl,
    Stream<bool>? connectivityStream,
    this._authHeadersBuilder,
    this._creatorIdReader,
  }) : _httpClient = httpClient ?? http.Client(),
       _apiBaseUrl = apiBaseUrl ?? resolveDefaultBaseUrl(),
       _connectivityStream = connectivityStream ?? const Stream<bool>.empty(),
       super(_initialSyncState());

  static String resolveDefaultBaseUrl() => AppConstants.resolveApiRootUrl();

  static EdgeSyncState _initialSyncState() {
    if (SovereignDomainStorageMode.canHydrateFromStorage(
      AppConstants.prefsBoxKey,
    )) {
      return EdgeSyncState(
        lastServerSeq: SovereignPrefsRepository.loadEdgeSyncLastSeq(),
        lastSyncedAt: SovereignPrefsRepository.loadEdgeSyncLastSyncedAt(),
      );
    }
    return const EdgeSyncState();
  }

  String get apiBaseUrl => _apiBaseUrl;
  SyncOutboxService get _outboxService => outboxService;
  Stream<bool> get connectivityStream => _connectivityStream;

  /// Registers a feature hydrator invoked whenever `/api/v1/sync/delta` yields changes.
  void registerDeltaHydrator(SyncDeltaHydrator hydrator) {
    if (!_deltaHydrators.contains(hydrator)) {
      _deltaHydrators.add(hydrator);
    }
  }

  /// Removes a previously registered delta hydrator.
  void unregisterDeltaHydrator(SyncDeltaHydrator hydrator) {
    _deltaHydrators.remove(hydrator);
  }

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
      var batchIterations = 0;
      while (hasMorePending && batchIterations < 50) {
        batchIterations++;
        final pendingBatch = _outboxService.getPendingBatch(maxBatchSize: 50);
        if (pendingBatch.isEmpty) {
          hasMorePending = false;
          break;
        }

        final payload = {
          'mutations': pendingBatch.map((r) => r.toJson()).toList(),
        };

        try {
          final dynamicHeaders =
              _authHeadersBuilder?.call() ?? const <String, String>{};
          final res = await _httpClient
              .post(
                Uri.parse('$_apiBaseUrl/api/v1/sync/mutations'),
                headers: <String, String>{
                  'Content-Type': 'application/json',
                  ...dynamicHeaders,
                },
                body: jsonEncode(payload),
              )
              .timeout(const Duration(seconds: 4));

          if (res.statusCode == 200 || res.statusCode == 201) {
            final data = jsonDecode(res.body) as Map<String, dynamic>;
            final applied = (data['applied'] as List? ?? []).cast<String>();
            final skipped = (data['skipped'] as List? ?? []).cast<String>();
            final failedList = (data['failed'] as List? ?? []);
            final acknowledgedKeys = <String>{...applied, ...skipped};

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
                acknowledgedKeys.add(key);
                await _outboxService.markFailed(key, retryable);
              }
            }

            // Safety guard: defer unacknowledged keys so the loop cannot stall on partial/empty 2xx replies.
            var unacknowledgedCount = 0;
            for (final r in pendingBatch) {
              if (!acknowledgedKeys.contains(r.idempotencyKey)) {
                unacknowledgedCount++;
                await _outboxService.markFailed(r.idempotencyKey, true);
              }
            }

            totalFlushed += pendingBatch.length - unacknowledgedCount;

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

            if (acknowledgedKeys.isEmpty ||
                unacknowledgedCount == pendingBatch.length) {
              break;
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
      final hydratedChanges = <Map<String, dynamic>>[];
      while (hasMore && page < 10) {
        page++;
        try {
          final dynamicHeaders =
              _authHeadersBuilder?.call() ?? const <String, String>{};
          final creatorId = _creatorIdReader?.call();
          final deltaUrl = creatorId != null && creatorId.isNotEmpty
              ? '$_apiBaseUrl/api/v1/sync/delta?since_seq=$newSeq&limit=100&creatorId=$creatorId'
              : '$_apiBaseUrl/api/v1/sync/delta?since_seq=$newSeq&limit=100';
          final deltaRes = await _httpClient
              .get(
                Uri.parse(deltaUrl),
                headers: <String, String>{
                  'Accept': 'application/json',
                  ...dynamicHeaders,
                },
              )
              .timeout(const Duration(seconds: 4));

          if (deltaRes.statusCode == 200) {
            final data = jsonDecode(deltaRes.body) as Map<String, dynamic>;
            final changes =
                (data['changes'] as List? ?? data['mutations'] as List? ?? []);
            for (final item in changes) {
              if (item is Map) {
                hydratedChanges.add(Map<String, dynamic>.from(item));
              }
            }
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

      if (hydratedChanges.isNotEmpty && _deltaHydrators.isNotEmpty) {
        final snapshot = List<Map<String, dynamic>>.unmodifiable(
          hydratedChanges,
        );
        for (final hydrator in List<SyncDeltaHydrator>.of(_deltaHydrators)) {
          try {
            await hydrator(snapshot);
          } catch (e) {
            debugPrint('[EdgeSyncCoordinator] delta hydrator error: $e');
          }
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
      final syncedAt = DateTime.now();

      await SovereignPrefsRepository.saveEdgeSyncCursor(
        lastServerSeq: newSeq,
        lastSyncedAt: syncedAt,
      );

      state = state.copyWith(
        status: EdgeSyncStatus.synced,
        lastServerSeq: newSeq,
        pendingOutboxCount: remaining,
        lastSyncedAt: syncedAt,
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

/// Optional HTTP client override for deterministic testing of [edgeSyncCoordinatorProvider].
final edgeSyncHttpClientProvider = Provider<http.Client?>((ref) => null);

/// Global provider for EdgeSyncCoordinator wired with library_track & playlist delta hydrators.
final edgeSyncCoordinatorProvider =
    StateNotifierProvider<EdgeSyncCoordinator, EdgeSyncState>((ref) {
      ref.watch(currentCreatorIdProvider);
      final outbox = ref.watch(syncOutboxServiceProvider);
      final httpClient = ref.watch(edgeSyncHttpClientProvider);
      final coordinator = EdgeSyncCoordinator(
        outboxService: outbox,
        httpClient: httpClient,
        authHeadersBuilder: () => ref.read(authHeadersProvider),
        creatorIdReader: () => ref.read(currentCreatorIdProvider),
      );

      coordinator.registerDeltaHydrator((mutations) async {
        var playlistMutated = false;
        for (final mutation in mutations) {
          final entityType =
              (mutation['entityType'] ?? mutation['entity_type'] ?? '')
                  .toString();
          final action = (mutation['action'] ?? 'upsert').toString();
          final rawPayload = mutation['payload'];
          final payload = rawPayload is Map
              ? Map<String, dynamic>.from(rawPayload)
              : Map<String, dynamic>.from(mutation);

          if (entityType == 'library_track' || entityType == 'track') {
            final id = (payload['id'] ?? mutation['entityId'] ?? '').toString();
            if (id.isEmpty) continue;
            if (action == 'delete') {
              if (payload['hardDelete'] == true) {
                ref
                    .read(libraryTracksProvider.notifier)
                    .purgeTrackPermanently(id);
              } else {
                ref.read(libraryTracksProvider.notifier).deleteTrack(id);
              }
            } else {
              final track = LibraryTrack.fromJson(payload);
              ref
                  .read(libraryTracksProvider.notifier)
                  .upsertLicensedTrack(track, enqueueOutbox: false);
            }
          } else if (entityType == 'playlist') {
            final id = (payload['id'] ?? mutation['entityId'] ?? '').toString();
            if (id.isEmpty) continue;
            final playlistRepo = ref.read(playlistRepositoryProvider);
            if (action == 'delete') {
              if (playlistRepo is PlaylistRepository) {
                await playlistRepo.applySyncDelta(deleteId: id);
              } else {
                await playlistRepo.deletePlaylist(id);
              }
              playlistMutated = true;
            } else {
              final playlist = PlaylistEntity.fromJson(payload);
              if (playlistRepo is PlaylistRepository) {
                await playlistRepo.applySyncDelta(upsert: playlist);
              } else {
                await playlistRepo.savePlaylist(playlist);
              }
              playlistMutated = true;
            }
          }
        }
        if (playlistMutated) {
          await ref.read(playlistsProvider.notifier).loadPlaylists();
        }
      });

      return coordinator;
    });

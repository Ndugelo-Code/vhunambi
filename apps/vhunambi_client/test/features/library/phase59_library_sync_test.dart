import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vhunambi_client/core/sync/edge_sync_coordinator.dart';
import 'package:vhunambi_client/core/sync/sync_outbox_service.dart';
import 'package:vhunambi_client/features/library/data/repositories/http_library_sync_repository.dart';
import 'package:vhunambi_client/features/library/domain/models/library_models.dart';
import 'package:vhunambi_client/features/library/presentation/providers/library_providers.dart';

class _StubDioAdapter implements HttpClientAdapter {
  _StubDioAdapter(this._handler);

  final Future<ResponseBody> Function(RequestOptions options) _handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return _handler(options);
  }
}

ResponseBody _jsonResponse(Map<String, dynamic> body, {int statusCode = 200}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

LibraryTrack _sampleTrack({
  required String id,
  String title = 'Baseline Anthem',
  int playCount = 0,
  bool isFavorite = false,
  String? localPath,
  String? licenseCert,
  String? licenseHash,
  String? licenseTierId,
  String? masterPath,
  Map<String, String> stems = const <String, String>{},
  int updatedAtMs = 1000,
}) {
  return LibraryTrack(
    id: id,
    title: title,
    creatorName: 'Ndugelo',
    genre: 'Amapiano',
    language: 'Tshivenḓa',
    durationSeconds: 205,
    remoteAudioUrl: 'https://cdn.vhunambi.za/audio/$id.mp3',
    localAudioFilePath: localPath,
    createdAt: DateTime(2026, 3, 1, 12),
    syncStatus: localPath != null
        ? TrackSyncStatus.cachedLocally
        : TrackSyncStatus.cloudOnly,
    playCount: playCount,
    isFavorite: isFavorite,
    licenseCertificateIdOverride: licenseCert,
    licenseHash: licenseHash,
    licenseTierId: licenseTierId,
    masterAudioFilePath: masterPath,
    stemPaths: stems,
    updatedAtMs: updatedAtMs,
  );
}

void main() {
  group('Phase 59 M59.3 & M59.5.2: Library Delta Sync & EdgeSyncCoordinator', () {
    test(
      'LibraryTrack JSON round-trip preserves Phase 58 licenses & updatedAtMs',
      () {
        final original = _sampleTrack(
          id: 'lib_p58_roundtrip',
          title: 'Venda Gold Master',
          playCount: 14,
          isFavorite: true,
          localPath: '/vault/venda_gold.wav',
          licenseCert: 'VHB-EXCL-2026-001',
          licenseHash: 'sha256_deadbeef',
          licenseTierId: 'exclusive_stem',
          masterPath: '/vault/masters/venda_gold_master.wav',
          stems: const <String, String>{
            'drums': '/vault/stems/drums.wav',
            'bass': '/vault/stems/bass.wav',
          },
          updatedAtMs: 1700001234567,
        );

        final json = original.toJson();
        final decoded = LibraryTrack.fromJson(json);

        expect(decoded, original);
        expect(decoded.licenseCertificateId, 'VHB-EXCL-2026-001');
        expect(decoded.licenseHash, 'sha256_deadbeef');
        expect(
          decoded.masterAudioFilePath,
          '/vault/masters/venda_gold_master.wav',
        );
        expect(decoded.stemPaths['drums'], '/vault/stems/drums.wav');
        expect(decoded.effectiveUpdatedAtMs, 1700001234567);
      },
    );

    test(
      'mergeTracksLww resolves conflicts by updatedAtMs, monotonic plays, & license preservation',
      () {
        final localNewer = _sampleTrack(
          id: 'trk_1',
          title: 'Local Renamed Cut',
          playCount: 5,
          isFavorite: true,
          localPath: '/vault/trk_1.mp3',
          licenseCert: 'VHB-LOCAL-CERT',
          licenseHash: 'hash_local',
          licenseTierId: 'stems_trackout',
          masterPath: '/vault/masters/trk_1.wav',
          stems: const <String, String>{'drums': '/vault/stems/d.wav'},
          updatedAtMs: 5000,
        );
        final remoteOlder = _sampleTrack(
          id: 'trk_1',
          title: 'Stale Cloud Title',
          playCount: 12,
          isFavorite: false,
          updatedAtMs: 2000,
        );
        final remoteOnly = _sampleTrack(
          id: 'trk_2',
          title: 'Cloud Drop Only',
          playCount: 3,
          updatedAtMs: 6000,
        );

        final merged = HttpLibrarySyncRepository.mergeTracksLww(
          <LibraryTrack>[localNewer],
          <LibraryTrack>[remoteOlder, remoteOnly],
        );

        expect(merged.length, 2);
        final trk1 = merged.firstWhere((t) => t.id == 'trk_1');
        expect(trk1.title, 'Local Renamed Cut');
        expect(trk1.isFavorite, isTrue);
        // Monotonic playCount picks higher count even from older remote record
        expect(trk1.playCount, 12);
        // Preserves Phase 58 licenses & local offline asset state
        expect(trk1.licenseCertificateIdOverride, 'VHB-LOCAL-CERT');
        expect(trk1.masterAudioFilePath, '/vault/masters/trk_1.wav');
        expect(trk1.stemPaths['drums'], '/vault/stems/d.wav');
        expect(trk1.isOfflineAvailable, isTrue);

        final trk2 = merged.firstWhere((t) => t.id == 'trk_2');
        expect(trk2.title, 'Cloud Drop Only');
      },
    );

    test(
      'HttpLibrarySyncRepository & LibraryTracksNotifier sync delta & enqueue outbox',
      () async {
        final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000/api'));
        var syncPostCount = 0;
        dio.httpClientAdapter = _StubDioAdapter((options) async {
          if (options.path.endsWith('/library/sync') &&
              options.method == 'POST') {
            syncPostCount++;
            return _jsonResponse(<String, dynamic>{
              'success': true,
              'serverSeq': 77,
              'appliedCount': 1,
              'items': <Map<String, dynamic>>[
                _sampleTrack(
                  id: 'lib_remote_77',
                  title: 'Synced From Cloud',
                  playCount: 8,
                  updatedAtMs: 9999999999999,
                ).toJson(),
              ],
            });
          }
          if (options.path.contains('/library/') &&
              options.method == 'DELETE') {
            return _jsonResponse(<String, dynamic>{'success': true});
          }
          return _jsonResponse(<String, dynamic>{});
        });

        final repo = HttpLibrarySyncRepository(
          dio: dio,
          baseUrl: 'http://localhost:3000/api',
        );
        final outbox = SyncOutboxService(isInMemoryOnly: true);
        await outbox.init();

        final container = ProviderContainer(
          overrides: <Override>[
            librarySyncRepositoryProvider.overrideWithValue(repo),
            syncOutboxServiceProvider.overrideWithValue(outbox),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(libraryTracksProvider.notifier);
        final added = _sampleTrack(id: 'lib_local_new', title: 'Soweto Bounce');
        notifier.addTrack(added);
        notifier.toggleFavorite('lib_local_new');
        notifier.incrementPlayCount('lib_local_new');
        await Future<void>.delayed(Duration.zero);

        final pending = outbox.getPendingMutations();
        expect(
          pending.where((m) => m.entityType == 'library_track').length,
          greaterThanOrEqualTo(3),
        );

        final synced = await notifier.syncWithCloud();
        expect(synced, isTrue);
        expect(syncPostCount, 1);
        expect(
          container.read(libraryCloudSyncStatusProvider),
          LibraryCloudSyncStatus.synced,
        );
        expect(
          container
              .read(libraryTracksProvider)
              .any((t) => t.id == 'lib_remote_77'),
          isTrue,
        );
        expect(
          container
              .read(libraryTracksProvider)
              .any((t) => t.id == 'lib_local_new'),
          isTrue,
        );
      },
    );

    test(
      'EdgeSyncCoordinator.registerDeltaHydrator dispatches multi-page delta changes & handles unregistration',
      () async {
        final outbox = SyncOutboxService(isInMemoryOnly: true);
        await outbox.init();

        var page = 0;
        final mockHttp = MockClient((request) async {
          if (request.url.path.contains('/api/v1/sync/delta')) {
            page++;
            if (page == 1) {
              return http.Response(
                jsonEncode(<String, dynamic>{
                  'changes': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'entityType': 'library_track',
                      'entityId': 'lib_1',
                    },
                  ],
                  'latestSeq': 20,
                  'nextCursorSeq': 15,
                  'hasMore': true,
                }),
                200,
              );
            }
            return http.Response(
              jsonEncode(<String, dynamic>{
                'changes': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'entityType': 'playlist',
                    'entityId': 'pl_1',
                  },
                ],
                'latestSeq': 20,
                'nextCursorSeq': 20,
                'hasMore': false,
              }),
              200,
            );
          }
          return http.Response('{}', 200);
        });

        final coordinator = EdgeSyncCoordinator(
          outboxService: outbox,
          httpClient: mockHttp,
        );

        final capturedBatches = <List<Map<String, dynamic>>>[];
        void hydrator(List<Map<String, dynamic>> changes) {
          capturedBatches.add(changes);
        }

        void failingHydrator(List<Map<String, dynamic>> changes) {
          throw StateError('transient hydrator fault');
        }

        coordinator.registerDeltaHydrator(hydrator);
        coordinator.registerDeltaHydrator(failingHydrator);

        final ok = await coordinator.syncNow();
        expect(ok, isTrue);
        expect(capturedBatches.length, 1);
        expect(capturedBatches.first.length, 2);
        expect(capturedBatches.first[0]['entityType'], 'library_track');
        expect(capturedBatches.first[1]['entityType'], 'playlist');

        coordinator.unregisterDeltaHydrator(hydrator);
        page = 0;
        await coordinator.syncNow();
        expect(capturedBatches.length, 1);
      },
    );
  });
}

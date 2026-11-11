import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/core/storage/checkout_write_ahead_journal.dart';
import 'package:vhunambi_client/core/storage/hive_compaction_scheduler.dart';
import 'package:vhunambi_client/core/storage/sovereign_domain_repositories.dart';
import 'package:vhunambi_client/core/storage/sovereign_hive_bootstrap_service.dart';
import 'package:vhunambi_client/core/sync/edge_sync_coordinator.dart';
import 'package:vhunambi_client/core/sync/sync_outbox_service.dart';
import 'package:vhunambi_client/features/creator_dna/data/repositories/creator_dna_repository.dart';
import 'package:vhunambi_client/features/creator_dna/domain/models/behavior_event.dart';
import 'package:vhunambi_client/features/library/domain/models/library_models.dart';
import 'package:vhunambi_client/features/library/presentation/providers/library_providers.dart';
import 'package:vhunambi_client/features/notifications/data/repositories/notification_repository.dart';
import 'package:vhunambi_client/features/notifications/domain/models/notification_entity.dart';
import 'package:vhunambi_client/features/notifications/domain/models/notification_enums.dart';
import 'package:vhunambi_client/features/offline/data/services/offline_storage_service.dart';
import 'package:vhunambi_client/features/offline/presentation/providers/offline_providers.dart';
import 'package:vhunambi_client/features/playlists/domain/models/playlist_entity.dart';
import 'package:vhunambi_client/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:vhunambi_client/features/studio/domain/models/melody_sketchpad_models.dart';
import 'package:vhunambi_client/features/studio/domain/models/vocal_identity_models.dart';
import 'package:vhunambi_client/features/studio/domain/services/i_voice_calibration_recorder.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/melody_sketchpad_provider.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/vocal_identity_provider.dart';

void main() {
  group(
    'Phase 60 M60.1-M60.5: Hive Fixes, O(1) Upgrades, WAL, Compaction & Edge Sync',
    () {
      late Directory tempDir;

      Future<void> restartHiveSession() async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        await Hive.close();
        SovereignDomainStorageMode.clearAllForTesting();
        CheckoutWriteAheadJournal.clearForTesting();
        SovereignHiveBootstrapService.resetForTesting();
        Hive.init(tempDir.path);
        await SovereignHiveBootstrapService.openAllBoxes();
      }

      setUp(() async {
        tempDir = Directory.systemTemp.createTempSync('vhunambi_upgrades_p60_');
        SovereignDomainStorageMode.clearAllForTesting();
        CheckoutWriteAheadJournal.clearForTesting();
        HiveCompactionScheduler.resetForTesting();
        SovereignHiveBootstrapService.resetForTesting();
        Hive.init(tempDir.path);
        await SovereignHiveBootstrapService.openAllBoxes();
      });

      tearDown(() async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        await Hive.close();
        SovereignDomainStorageMode.clearAllForTesting();
        CheckoutWriteAheadJournal.clearForTesting();
        HiveCompactionScheduler.resetForTesting();
        SovereignHiveBootstrapService.resetForTesting();
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      test(
        'CreatorDnaRepository migrates legacy behavior_log and enforces 500-slot O(1) FIFO ring buffer',
        () async {
          final dnaBox = Hive.box<dynamic>(AppConstants.creatorDnaBoxKey);
          final legacyEvent = BehaviorEvent.trackLike(
            trackId: 'legacy_trk_1',
            genreHint: 'Amapiano',
            languageHint: 'Tshivenḓa',
          );
          await dnaBox.put('behavior_log', <Map<String, dynamic>>[
            legacyEvent.toJson(),
          ]);

          final repo = CreatorDnaRepository(dnaBox);
          final migratedLog = await repo.loadEventLog();
          expect(migratedLog.length, 1);
          expect(migratedLog.first.payload['trackId'], 'legacy_trk_1');
          expect(dnaBox.containsKey('behavior_log'), isFalse);
          expect(dnaBox.containsKey('dna_evt_0'), isTrue);
          expect(dnaBox.get('dna_evt_cursor'), 1);

          // Push 505 additional events (total cursor = 506 -> wraps slots 0..5, tail = 500 entries).
          for (var i = 0; i < 505; i++) {
            await repo.appendEvent(
              BehaviorEvent.trackPlay(
                trackId: 'ring_trk_$i',
                genreHint: 'Gqom',
                listenRatioPercent: 90,
              ),
              const [],
            );
          }

          expect(dnaBox.get('dna_evt_cursor'), 506);
          final fullRing = await repo.loadEventLog();
          expect(fullRing.length, 500);
          // Oldest surviving entry should be ring_trk_5 (since legacy + ring_trk_0..4 were overwritten).
          expect(fullRing.first.payload['trackId'], 'ring_trk_5');
          expect(fullRing.last.payload['trackId'], 'ring_trk_504');
        },
      );

      test(
        'VocalIdentityNotifier migrates legacy cloned_voice_profiles_json to voice_<id> and persists create/delete',
        () async {
          final voiceBox = Hive.box<dynamic>(AppConstants.voiceProfilesBoxKey);
          const legacyClone = CreatorVoiceCloneProfile(
            id: 'legacy_voice_1',
            creatorName: 'Makhado Legacy Voice',
            nativeLanguage: 'Tshivenḓa',
            calibrationLines: ['Ndaa! Vhunambi i khou tshila'],
            timbreEmbeddingPreview: [0.1, 0.2, 0.3],
            phonemeCadenceMap: {'ḓ': 1.1},
            cadenceWpm: 110,
            clarityScore: 0.95,
            recordingDurationSec: 18.0,
            createdAtIso: '2026-11-01T10:00:00.000Z',
          );
          await voiceBox.put(
            'cloned_voice_profiles_json',
            jsonEncode([legacyClone.toJson()]),
          );

          final container1 = ProviderContainer(
            overrides: [
              voiceCalibrationRecorderProvider.overrideWithValue(
                DeterministicVoiceCalibrationRecorder(),
              ),
            ],
          );
          addTearDown(container1.dispose);

          final migratedState = container1.read(vocalIdentityProvider);
          expect(
            migratedState.clonedProfiles.any((p) => p.id == 'legacy_voice_1'),
            isTrue,
          );
          expect(migratedState.activeClonedProfile?.id, 'legacy_voice_1');

          await Future<void>.delayed(const Duration(milliseconds: 20));
          expect(voiceBox.containsKey('cloned_voice_profiles_json'), isFalse);
          expect(voiceBox.containsKey('voice_legacy_voice_1'), isTrue);

          // Finalize a brand-new clone -> persists under voice_<id>
          final notifier1 = container1.read(vocalIdentityProvider.notifier);
          await notifier1.startCalibrationRecording();
          final created = await notifier1.finalizeVoiceClone(
            creatorName: 'Thohoyandou Sovereign',
            nativeLanguage: 'Tshivenḓa',
          );
          expect(voiceBox.containsKey('voice_${created.id}'), isTrue);

          await restartHiveSession();

          final container2 = ProviderContainer(
            overrides: [
              voiceCalibrationRecorderProvider.overrideWithValue(
                DeterministicVoiceCalibrationRecorder(),
              ),
            ],
          );
          addTearDown(container2.dispose);
          final restoredState = container2.read(vocalIdentityProvider);
          expect(restoredState.clonedProfiles.length, 2);
          expect(restoredState.activeClonedProfile?.id, created.id);

          // Delete the new clone -> removed on disk too
          await container2
              .read(vocalIdentityProvider.notifier)
              .deleteClonedProfile(created.id);
          await restartHiveSession();

          final container3 = ProviderContainer(
            overrides: [
              voiceCalibrationRecorderProvider.overrideWithValue(
                DeterministicVoiceCalibrationRecorder(),
              ),
            ],
          );
          addTearDown(container3.dispose);
          final afterDelete = container3.read(vocalIdentityProvider);
          expect(
            afterDelete.clonedProfiles.any((p) => p.id == created.id),
            isFalse,
          );
          expect(
            afterDelete.clonedProfiles.any((p) => p.id == 'legacy_voice_1'),
            isTrue,
          );
        },
      );

      test(
        'MelodySketchpadNotifier migrates legacy saved_melody_patterns_json to sketch_<id> and persists save/delete',
        () async {
          final sketchBox = Hive.box<dynamic>(
            AppConstants.melodySketchesBoxKey,
          );
          const legacyPattern = MelodyPatternEntity(
            id: 'skp_legacy_1',
            name: 'Legacy Log Groove',
            genre: 'Amapiano',
            musicalKey: 'F#m',
            bpm: 113,
          );
          await sketchBox.put(
            'saved_melody_patterns_json',
            jsonEncode([legacyPattern.toJson()]),
          );

          final container1 = ProviderContainer();
          addTearDown(container1.dispose);

          final initialState = container1.read(melodySketchpadProvider);
          expect(
            initialState.savedPatterns.any((p) => p.id == 'skp_legacy_1'),
            isTrue,
          );
          await Future<void>.delayed(const Duration(milliseconds: 20));
          expect(sketchBox.containsKey('saved_melody_patterns_json'), isFalse);
          expect(sketchBox.containsKey('sketch_skp_legacy_1'), isTrue);

          final saved = await container1
              .read(melodySketchpadProvider.notifier)
              .saveCurrentToVault(customName: 'Vhembe Private Cut');
          expect(sketchBox.containsKey('sketch_${saved.id}'), isTrue);

          await restartHiveSession();

          final container2 = ProviderContainer();
          addTearDown(container2.dispose);
          final restored = container2.read(melodySketchpadProvider);
          expect(restored.savedPatterns.any((p) => p.id == saved.id), isTrue);

          await container2
              .read(melodySketchpadProvider.notifier)
              .deleteSavedPattern(saved.id);
          await restartHiveSession();

          final container3 = ProviderContainer();
          addTearDown(container3.dispose);
          expect(
            container3
                .read(melodySketchpadProvider)
                .savedPatterns
                .any((p) => p.id == saved.id),
            isFalse,
          );
        },
      );

      test(
        'CheckoutWriteAheadJournal prepares WAL entry and idempotently recovers crash on restart',
        () async {
          final entry = CheckoutWalEntry(
            transactionId: 'tx_crash_p60',
            beatId: 'beat_exclusive_99',
            beatTitle: 'Limpopo Dawn Log',
            producerName: 'cern',
            licenseTierId: 'exclusive_stem',
            coinPrice: 800,
            certificateJson: jsonEncode(<String, dynamic>{
              'certificateId': 'VHB-EXCL-99',
              'beatId': 'beat_exclusive_99',
              'buyerName': 'Ndugelo',
            }),
            vaultTrackJson: jsonEncode(<String, dynamic>{
              'id': 'market_beat_exclusive_99',
              'title': 'Limpopo Dawn Log',
              'creatorName': 'cern',
              'genre': 'Amapiano',
              'language': 'Instrumental',
              'durationSeconds': 185,
              'remoteAudioUrl': 'https://cdn.vhunambi.za/beats/99.mp3',
              'createdAt': '2026-11-09T12:00:00.000Z',
            }),
            isExclusive: true,
            preparedAt: DateTime.parse('2026-11-09T12:00:00.000Z'),
          );

          await CheckoutWriteAheadJournal.prepareCheckout(entry);
          expect(
            Hive.box<dynamic>(
              AppConstants.prefsBoxKey,
            ).containsKey('checkout_wal_tx_crash_p60'),
            isTrue,
          );
          expect(CheckoutWriteAheadJournal.getPendingEntries().length, 1);

          // Simulate hard kill + restart before commitCheckout completed.
          await restartHiveSession();

          final pendingAfterRestart =
              CheckoutWriteAheadJournal.getPendingEntries();
          expect(pendingAfterRestart.length, 1);
          expect(pendingAfterRestart.first.transactionId, 'tx_crash_p60');

          final recovered =
              await CheckoutWriteAheadJournal.recoverInterruptedTransactions();
          expect(recovered, 1);

          // Verify certificate, library track, exclusive lock all committed and WAL cleaned.
          expect(
            Hive.box<dynamic>(
              AppConstants.licenseCertificatesBoxKey,
            ).containsKey('VHB-EXCL-99'),
            isTrue,
          );
          expect(
            Hive.box<dynamic>(
              AppConstants.libraryTracksV1BoxKey,
            ).containsKey('market_beat_exclusive_99'),
            isTrue,
          );
          expect(
            MarketplaceCatalogCacheRepository.isExclusiveSold(
              'beat_exclusive_99',
            ),
            isTrue,
          );
          expect(
            Hive.box<dynamic>(
              AppConstants.prefsBoxKey,
            ).containsKey('checkout_wal_tx_crash_p60'),
            isFalse,
          );

          // Idempotent second run recovers 0 entries.
          expect(
            await CheckoutWriteAheadJournal.recoverInterruptedTransactions(),
            0,
          );
        },
      );

      test(
        'HiveCompactionScheduler triggers auto-compaction when mutation & fragmentation thresholds are crossed',
        () async {
          HiveCompactionScheduler.resetForTesting();
          expect(HiveCompactionScheduler.totalCompactionsExecuted, 0);

          // Below minMutationsForAutoCompact (25): no compaction
          for (var i = 0; i < 24; i++) {
            final triggered = await HiveCompactionScheduler.recordMutation(
              AppConstants.tracksBoxKey,
              overrideLiveCount: 5,
            );
            expect(triggered, isFalse);
          }
          expect(HiveCompactionScheduler.totalCompactionsExecuted, 0);
          expect(
            HiveCompactionScheduler.computeFragmentationRatio(
              AppConstants.tracksBoxKey,
              overrideLiveCount: 5,
            ),
            closeTo(24 / 6, 0.001),
          );

          // 25th mutation exceeds threshold (25 >= 25, 25/6 >= 0.20) -> triggers compactBox!
          final triggered25 = await HiveCompactionScheduler.recordMutation(
            AppConstants.tracksBoxKey,
            overrideLiveCount: 5,
          );
          expect(triggered25, isTrue);
          expect(HiveCompactionScheduler.totalCompactionsExecuted, 1);
          expect(HiveCompactionScheduler.lastCompactedAt, isNotNull);
          expect(
            HiveCompactionScheduler.computeFragmentationRatio(
              AppConstants.tracksBoxKey,
              overrideLiveCount: 5,
            ),
            0.0,
          );
        },
      );

      test(
        'purgeTrackPermanently deletes cached .vmf file & vault metadata and cacheStorageStatsProvider reflects real bytes',
        () async {
          final vmfDir = Directory('${tempDir.path}/vault_audio')
            ..createSync(recursive: true);
          final vmfFile = File('${vmfDir.path}/trk_purge_vmf.vmf');
          final payloadBytes = List<int>.filled(4096, 7);
          await vmfFile.writeAsBytes(payloadBytes);
          expect(vmfFile.existsSync(), isTrue);

          final offlineStorage = OfflineStorageService(
            customVaultDirectory: vmfDir.path,
          );
          await offlineStorage.init();

          final track = LibraryTrack(
            id: 'trk_purge_vmf',
            title: 'Cached Vault Cut',
            creatorName: 'Ndugelo',
            genre: 'Amapiano',
            language: 'Tshivenḓa',
            durationSeconds: 180,
            remoteAudioUrl: 'https://cdn.vhunambi.za/audio/trk_purge_vmf.mp3',
            localAudioFilePath: vmfFile.path,
            createdAt: DateTime(2026, 11, 9),
            syncStatus: TrackSyncStatus.cachedLocally,
          );
          await offlineStorage.saveTrackMetadata(
            track: track,
            localPath: vmfFile.path,
            fileSizeBytes: payloadBytes.length,
          );
          expect(await offlineStorage.getTotalCachedSizeBytes(), 4096);

          final container = ProviderContainer(
            overrides: [
              offlineStorageServiceProvider.overrideWithValue(offlineStorage),
            ],
          );
          addTearDown(container.dispose);

          // Replace library state cleanly so only our test cached track is cachedLocally.
          container.read(libraryTracksProvider.notifier).applyMergedTracks([
            track,
          ]);

          final statsBefore = container.read(cacheStorageStatsProvider);
          expect(statsBefore.cachedTrackCount, 1);
          // Real file bytes (4096) + live Hive overhead (not hardcoded 8.5 MB fallback!).
          expect(statsBefore.totalBytesUsed, greaterThanOrEqualTo(4096));
          expect(statsBefore.totalBytesUsed, lessThan(8500000));

          // Purge permanently -> removes library record, vault Hive metadata, AND .vmf file on disk!
          container
              .read(libraryTracksProvider.notifier)
              .purgeTrackPermanently(track.id);
          for (var i = 0; i < 40; i++) {
            if (!vmfFile.existsSync() &&
                await offlineStorage.getTrackMetadata(track.id) == null) {
              break;
            }
            await Future<void>.delayed(const Duration(milliseconds: 25));
          }

          expect(
            container
                .read(libraryTracksProvider)
                .any((t) => t.id == 'trk_purge_vmf'),
            isFalse,
          );
          expect(vmfFile.existsSync(), isFalse);
          expect(await offlineStorage.getTrackMetadata(track.id), isNull);
          expect(await offlineStorage.getTotalCachedSizeBytes(), 0);
          expect(
            Hive.box<dynamic>(AppConstants.vaultBoxKey).containsKey(track.id),
            isFalse,
          );
        },
      );

      test(
        'EdgeSyncCoordinator defaults to port 3000, persists lastServerSeq across restarts, and hydrates library_track & playlist deltas',
        () async {
          expect(
            EdgeSyncCoordinator.resolveDefaultBaseUrl(),
            endsWith(':3000'),
          );

          final outbox = SyncOutboxService(isInMemoryOnly: true);
          await outbox.init();

          final deltaTrack = LibraryTrack(
            id: 'lib_delta_42',
            title: 'Delta Hydrated Song',
            creatorName: 'Vhunambi Cloud',
            genre: 'Amapiano',
            language: 'Tshivenḓa',
            durationSeconds: 204,
            remoteAudioUrl: 'https://cdn.vhunambi.za/audio/lib_delta_42.mp3',
            createdAt: DateTime(2026, 11, 9, 14),
            updatedAtMs: 1700000042000,
          );
          final deltaPlaylist = PlaylistEntity(
            id: 'pl_delta_42',
            title: 'Sovereign Edge Playlist',
            trackIds: const ['lib_delta_42'],
            createdAt: DateTime(2026, 11, 9, 14),
            updatedAt: DateTime(2026, 11, 9, 14),
          );

          final mockClient = MockClient((request) async {
            expect(request.url.port, 3000);
            if (request.url.path == '/api/v1/sync/delta') {
              return http.Response(
                jsonEncode(<String, dynamic>{
                  'latestSeq': 42,
                  'hasMore': false,
                  'changes': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'entityType': 'library_track',
                      'action': 'upsert',
                      'payload': deltaTrack.toJson(),
                    },
                    <String, dynamic>{
                      'entityType': 'playlist',
                      'action': 'upsert',
                      'payload': deltaPlaylist.toJson(),
                    },
                  ],
                }),
                200,
                headers: const {
                  'content-type': 'application/json; charset=utf-8',
                },
              );
            }
            return http.Response(
              '{}',
              200,
              headers: const {
                'content-type': 'application/json; charset=utf-8',
              },
            );
          });

          final container = ProviderContainer(
            overrides: [
              syncOutboxServiceProvider.overrideWithValue(outbox),
              edgeSyncHttpClientProvider.overrideWithValue(mockClient),
            ],
          );
          addTearDown(container.dispose);

          final coordinator = container.read(
            edgeSyncCoordinatorProvider.notifier,
          );
          expect(coordinator.apiBaseUrl, endsWith(':3000'));

          final ok = await coordinator.syncNow();
          expect(ok, isTrue);

          final syncState = container.read(edgeSyncCoordinatorProvider);
          expect(syncState.lastServerSeq, 42);
          expect(syncState.lastSyncedAt, isNotNull);

          // Delta hydrators applied library track & playlist without enqueuing duplicate outbox mutations
          expect(
            container
                .read(libraryTracksProvider)
                .any((t) => t.id == 'lib_delta_42'),
            isTrue,
          );
          expect(
            container
                .read(playlistsProvider)
                .any((p) => p.id == 'pl_delta_42'),
            isTrue,
          );
          expect(outbox.pendingCount, 0);

          // Restart Hive session and verify EdgeSyncCoordinator hydrates persisted lastServerSeq == 42
          await restartHiveSession();

          final containerAfterRestart = ProviderContainer(
            overrides: [syncOutboxServiceProvider.overrideWithValue(outbox)],
          );
          addTearDown(containerAfterRestart.dispose);

          final restartedSyncState = containerAfterRestart.read(
            edgeSyncCoordinatorProvider,
          );
          expect(restartedSyncState.lastServerSeq, 42);
          expect(restartedSyncState.lastSyncedAt, isNotNull);
        },
      );

      test(
        'NotificationRepository migrates legacy notifications list key into O(1) notif_<id> keys',
        () async {
          final notifBox = Hive.box<dynamic>(AppConstants.notificationsBoxKey);
          final legacyAlert = NotificationEntity(
            id: 'legacy_notif_1',
            title: 'Legacy Alert',
            message: 'Stored in monolithic list',
            category: NotificationCategory.system,
            createdAt: DateTime(2026, 11, 1, 9),
          );
          await notifBox.put('notifications', <Map<String, dynamic>>[
            legacyAlert.toJson(),
          ]);

          final repo = NotificationRepository(notifBox);
          final loaded = await repo.getNotifications();
          expect(loaded.length, 1);
          expect(loaded.first.id, 'legacy_notif_1');
          expect(notifBox.containsKey('notifications'), isFalse);
          expect(notifBox.containsKey('notif_legacy_notif_1'), isTrue);
        },
      );
    },
  );
}

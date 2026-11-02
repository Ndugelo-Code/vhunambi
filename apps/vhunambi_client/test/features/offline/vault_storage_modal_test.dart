import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/library/domain/models/library_models.dart';
import 'package:vhunambi_client/features/library/presentation/providers/library_providers.dart';
import 'package:vhunambi_client/features/offline/data/services/audio_download_service.dart';
import 'package:vhunambi_client/features/offline/data/services/offline_storage_service.dart';
import 'package:vhunambi_client/features/offline/presentation/providers/offline_providers.dart';
import 'package:vhunambi_client/features/offline/presentation/widgets/offline_indicator_badge.dart';
import 'package:vhunambi_client/features/offline/presentation/widgets/vault_storage_modal.dart';

/// T8.6 — Offline vault presentation suite (T8.4 verification).
///
/// Covers [VaultStorageModal] quota rendering, cached-master shelf, eviction
/// controls and preference wiring, plus the [OfflineIndicatorBadge] companion
/// widget shipped in T8.4.
///
/// Vault state is mutated directly through `libraryTracksProvider` and the
/// storage dependency is replaced by [_FakeOfflineStorage], so every vault
/// mutation resolves through microtasks only. No Hive or file IO is scheduled
/// while a fake-async widget pump is in flight, which keeps the suite
/// deterministic: awaiting a single `pumpAndSettle()` is always enough for the
/// `DownloadManagerNotifier` futures to land.
const String _vaultPath = 'test_vault/audio';

late ProviderContainer _container;

void main() {
  setUp(() {
    _container = ProviderContainer(
      overrides: <Override>[
        offlineStorageServiceProvider.overrideWithValue(_FakeOfflineStorage()),
        audioDownloadServiceProvider.overrideWithValue(
          AudioDownloadService(simulateDownloads: true),
        ),
      ],
    );
    addTearDown(_container.dispose);
  });

  group('VaultStorageModal', () {
    testWidgets('renders the vault storage header and quota summary',
        (WidgetTester tester) async {
      await _pumpModal(tester);

      expect(find.text('Vault Storage Quota'), findsOneWidget);
      expect(find.text('Storage Used'), findsOneWidget);
      expect(
        find.textContaining('free space remaining in your vault quota'),
        findsOneWidget,
      );
      expect(find.text('CACHED AUDIO MASTERS'), findsOneWidget);
      expect(find.byIcon(Icons.storage_rounded), findsOneWidget);
      // Quota rail (REQ-OFF-11).
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('binds the quota rail and byte labels to the storage stats',
        (WidgetTester tester) async {
      _cacheTrack('lib_track_002');
      await _pumpModal(tester);

      final stats = _container.read(cacheStorageStatsProvider);
      expect(stats.cachedTrackCount, greaterThan(0));

      expect(
        find.text(
          '${stats.formattedBytesUsed} / ${stats.formattedStorageLimit}',
        ),
        findsOneWidget,
      );

      final rail = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(rail.value, closeTo(stats.quotaUsagePercentage, 0.0001));
    });

    testWidgets('lists every cached audio master in the shelf',
        (WidgetTester tester) async {
      _cacheTrack('lib_track_002');
      await _pumpModal(tester);

      final stats = _container.read(cacheStorageStatsProvider);
      final cachedCount = _container
          .read(libraryTracksProvider)
          .where((track) => track.syncStatus == TrackSyncStatus.cachedLocally)
          .length;

      expect(cachedCount, greaterThan(0));
      expect(
        find.text(
          '${stats.cachedTrackCount} songs cached offline • Playable anywhere',
        ),
        findsOneWidget,
      );
      expect(find.text('Grateful in the Light'), findsOneWidget);
      expect(find.text('Ndo Mufuna Matibe'), findsOneWidget);
      expect(find.textContaining('~8.5 MB'), findsNWidgets(cachedCount));
      expect(
        find.byIcon(Icons.delete_outline_rounded),
        findsNWidgets(cachedCount),
      );
      expect(find.text('Clear All'), findsOneWidget);
      expect(find.text('No tracks cached offline yet'), findsNothing);
    });

    testWidgets('renders the empty state once every master is evicted',
        (WidgetTester tester) async {
      final notifier = _container.read(libraryTracksProvider.notifier);
      for (final track in _container.read(libraryTracksProvider)) {
        if (track.syncStatus == TrackSyncStatus.cachedLocally) {
          notifier.clearTrackOfflinePath(track.id);
        }
      }

      await _pumpModal(tester);

      expect(find.text('No tracks cached offline yet'), findsOneWidget);
      expect(
        find.textContaining('without an internet connection'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.cloud_download_outlined), findsOneWidget);
      expect(find.text('Clear All'), findsNothing);
      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
      expect(_container.read(cacheStorageStatsProvider).cachedTrackCount, 0);
    });

    testWidgets('Clear All confirms before purging the cached vault',
        (WidgetTester tester) async {
      _cacheTrack('lib_track_002');
      await _pumpModal(tester);

      await tester.tap(find.text('Clear All'));
      await tester.pumpAndSettle();

      expect(find.text('Clear all downloaded audio?'), findsOneWidget);
      expect(
        find.textContaining('delete all offline audio files'),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);

      await tester.tap(find.text('Delete All'));
      await tester.pumpAndSettle();

      expect(find.text('No tracks cached offline yet'), findsOneWidget);
      expect(_container.read(cacheStorageStatsProvider).cachedTrackCount, 0);
      expect(
        _container
            .read(libraryTracksProvider)
            .where((track) => track.syncStatus == TrackSyncStatus.cachedLocally),
        isEmpty,
      );
      expect(
        find.text('All offline audio files cleared from device.'),
        findsOneWidget,
      );
    });

    testWidgets('toggles the forced offline simulation preference',
        (WidgetTester tester) async {
      await _pumpModal(tester);

      final toggle = find.byType(Switch);
      expect(toggle, findsOneWidget);
      expect(tester.widget<Switch>(toggle).value, isFalse);

      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(
        _container.read(offlinePreferencesProvider).isOfflineModeForced,
        isTrue,
      );
      expect(tester.widget<Switch>(toggle).value, isTrue);
    });

    testWidgets('reflects a storage ceiling set through the preferences',
        (WidgetTester tester) async {
      _container
          .read(offlinePreferencesProvider.notifier)
          .setStorageLimitBytes(2 * 1024 * 1024 * 1024);

      await _pumpModal(tester);

      final stats = _container.read(cacheStorageStatsProvider);
      expect(stats.formattedStorageLimit, '2.00 GB');
      expect(
        find.text(
          '${stats.formattedBytesUsed} / ${stats.formattedStorageLimit}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the shelf delete action evicts a single cached master',
        (WidgetTester tester) async {
      await _pumpModal(tester);

      final target = _container.read(libraryTracksProvider).firstWhere(
            (track) => track.syncStatus == TrackSyncStatus.cachedLocally,
          );

      await tester.tap(find.byTooltip('Remove offline file').first);
      await tester.pumpAndSettle();

      final evicted = _container
          .read(libraryTracksProvider)
          .firstWhere((track) => track.id == target.id);
      expect(evicted.syncStatus, TrackSyncStatus.cloudOnly);
      expect(evicted.localAudioFilePath, isNull);
      expect(find.text(target.title), findsNothing);
      expect(
        find.text('Removed "${target.title}" from offline vault.'),
        findsOneWidget,
      );
    });
  });

  group('OfflineIndicatorBadge', () {
    testWidgets('renders the offline pin with its default label',
        (WidgetTester tester) async {
      await _pumpBadge(tester);

      expect(find.byType(OfflineIndicatorBadge), findsOneWidget);
      expect(find.byIcon(Icons.offline_pin_rounded), findsOneWidget);
      expect(find.text('Offline'), findsOneWidget);
    });

    testWidgets('compact mode drops the label but keeps the pin',
        (WidgetTester tester) async {
      await _pumpBadge(tester, isCompact: true);

      expect(find.byIcon(Icons.offline_pin_rounded), findsOneWidget);
      expect(find.text('Offline'), findsNothing);
    });

    testWidgets('honours a custom label', (WidgetTester tester) async {
      await _pumpBadge(tester, label: 'Playing offline');

      expect(find.text('Playing offline'), findsOneWidget);
      expect(find.text('Offline'), findsNothing);
    });
  });
}

Future<void> _pumpModal(WidgetTester tester) async {
  tester.view.physicalSize = const Size(420, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: _container,
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          backgroundColor: AppColors.surfaceCanvas,
          body: VaultStorageModal(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Marks a vault asset as locally cached without touching the file system.
void _cacheTrack(String trackId) {
  _container
      .read(libraryTracksProvider.notifier)
      .setTrackOfflinePath(trackId, '$_vaultPath/$trackId.mp3');
}

Future<void> _pumpBadge(
  WidgetTester tester, {
  bool isCompact = false,
  String label = 'Offline',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        backgroundColor: AppColors.surfaceCanvas,
        body: Center(
          child: OfflineIndicatorBadge(isCompact: isCompact, label: label),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Pure in-memory `IOfflineStorageService` double.
///
/// Every method completes through microtasks only (no Hive, no `dart:io`), so
/// the `DownloadManagerNotifier` futures triggered from widget callbacks settle
/// deterministically inside the widget-test fake-async zone.
class _FakeOfflineStorage implements IOfflineStorageService {
  final Map<String, Map<String, dynamic>> _vault =
      <String, Map<String, dynamic>>{};
  final Map<String, dynamic> _prefs = <String, dynamic>{};

  @override
  Future<void> init() => Future<void>.value();

  @override
  Future<void> saveTrackMetadata({
    required LibraryTrack track,
    required String localPath,
    required int fileSizeBytes,
  }) {
    _vault[track.id] = <String, dynamic>{
      'id': track.id,
      'title': track.title,
      'creatorName': track.creatorName,
      'genre': track.genre,
      'language': track.language,
      'durationSeconds': track.durationSeconds,
      'remoteAudioUrl': track.remoteAudioUrl,
      'localAudioFilePath': localPath,
      'coverImageUrl': track.coverImageUrl,
      'createdAt': track.createdAt.toIso8601String(),
      'licenseType': track.licenseType,
      'syncStatus': TrackSyncStatus.cachedLocally.name,
      'fileSizeBytes': fileSizeBytes,
      'downloadedAt': '2026-09-25T00:00:00.000',
    };
    return Future<void>.value();
  }

  @override
  Future<Map<String, dynamic>?> getTrackMetadata(String trackId) =>
      Future<Map<String, dynamic>?>.value(_vault[trackId]);

  @override
  Future<List<Map<String, dynamic>>> getAllCachedMetadata() =>
      Future<List<Map<String, dynamic>>>.value(_vault.values.toList());

  @override
  Future<void> removeTrackMetadata(String trackId) {
    _vault.remove(trackId);
    return Future<void>.value();
  }

  @override
  Future<void> clearAllMetadata() {
    _vault.clear();
    return Future<void>.value();
  }

  @override
  Future<int> getTotalCachedSizeBytes() => Future<int>.value(
        _vault.values.fold<int>(
          0,
          (total, record) => total + (record['fileSizeBytes'] as int? ?? 0),
        ),
      );

  @override
  Future<bool> isTrackCachedLocally(String trackId) =>
      Future<bool>.value(_vault.containsKey(trackId));

  @override
  Future<String> resolveVaultAudioDirectory() => Future<String>.value(_vaultPath);

  @override
  Future<void> savePreference(String key, dynamic value) {
    _prefs[key] = value;
    return Future<void>.value();
  }

  @override
  Future<dynamic> getPreference(String key) =>
      Future<dynamic>.value(_prefs[key]);
}

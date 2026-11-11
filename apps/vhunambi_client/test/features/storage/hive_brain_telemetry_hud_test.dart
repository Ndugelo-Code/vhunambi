import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/core/storage/hive_compaction_scheduler.dart';
import 'package:vhunambi_client/core/storage/sovereign_domain_repositories.dart';
import 'package:vhunambi_client/core/storage/sovereign_hive_bootstrap_service.dart';
import 'package:vhunambi_client/core/sync/edge_sync_coordinator.dart';
import 'package:vhunambi_client/core/sync/sync_outbox_service.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/hive_brain_telemetry_card.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/profile_settings_drawer.dart';

Uint8List? _resolveSdkMaterialFontBytes() {
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 6; i++) {
    final candidate = File(
      '${dir.path}${Platform.pathSeparator}material_fonts${Platform.pathSeparator}roboto-regular.ttf',
    );
    if (candidate.existsSync()) {
      return candidate.readAsBytesSync();
    }
    final cacheCandidate = File(
      '${dir.path}${Platform.pathSeparator}bin${Platform.pathSeparator}cache${Platform.pathSeparator}artifacts${Platform.pathSeparator}material_fonts${Platform.pathSeparator}roboto-regular.ttf',
    );
    if (cacheCandidate.existsSync()) {
      return cacheCandidate.readAsBytesSync();
    }
    dir = dir.parent;
  }
  return null;
}

ByteData _buildGoogleFontsAssetManifestBin() {
  const variants = <String>[
    'Thin',
    'ExtraLight',
    'Light',
    'Regular',
    'Medium',
    'SemiBold',
    'Bold',
    'ExtraBold',
    'Black',
    'Italic',
    'ThinItalic',
    'ExtraLightItalic',
    'LightItalic',
    'MediumItalic',
    'SemiBoldItalic',
    'BoldItalic',
    'ExtraBoldItalic',
    'BlackItalic',
  ];
  final manifest = <String, List<Map<String, Object?>>>{};
  for (final family in const ['Inter', 'Outfit']) {
    for (final variant in variants) {
      final key = 'assets/google_fonts/$family-$variant.ttf';
      manifest[key] = <Map<String, Object?>>[
        <String, Object?>{'asset': key},
      ];
    }
  }
  return const StandardMessageCodec().encodeMessage(manifest)!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 60 M60.6: Sovereign Hive Brain Telemetry HUD Widget Tests', () {
    late Directory tempDir;
    late bool prevAllowRuntimeFetching;

    setUpAll(() {
      prevAllowRuntimeFetching = GoogleFonts.config.allowRuntimeFetching;
      GoogleFonts.config.allowRuntimeFetching = false;

      final manifestBin = _buildGoogleFontsAssetManifestBin();
      final fontBytes = _resolveSdkMaterialFontBytes();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', (ByteData? message) async {
        if (message == null) return null;
        final key = utf8.decode(Uint8List.sublistView(message));
        if (key == 'AssetManifest.bin') {
          return manifestBin;
        }
        if (key.startsWith('assets/google_fonts/') && fontBytes != null) {
          return ByteData.sublistView(fontBytes);
        }
        final assetFile = File('build/unit_test_assets/$key');
        if (assetFile.existsSync()) {
          return ByteData.sublistView(assetFile.readAsBytesSync());
        }
        return null;
      });
    });

    tearDownAll(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', null);
      GoogleFonts.config.allowRuntimeFetching = prevAllowRuntimeFetching;
    });

    Future<void> pumpRealAsyncUntil(
      WidgetTester tester,
      bool Function() condition, {
      int maxSteps = 500,
    }) async {
      for (var i = 0; i < maxSteps; i++) {
        if (condition()) return;
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 4)),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    Future<void> closeAllOpenBoxesSequentially() async {
      final orderedKeys = <String>[
        if (Hive.isBoxOpen(AppConstants.prefsBoxKey)) AppConstants.prefsBoxKey,
        ...SovereignHiveBootstrapService.allBoxKeys.where(
          (k) => k != AppConstants.prefsBoxKey && Hive.isBoxOpen(k),
        ),
      ];
      for (final boxKey in orderedKeys) {
        final box = SovereignHiveBootstrapService.mapTypedBoxKeys.contains(boxKey)
            ? Hive.box<Map>(boxKey)
            : Hive.box<dynamic>(boxKey);
        await box.flush();
        await box.close();
      }
      await Hive.close();
    }

    setUp(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => null,
      );
      tempDir = Directory.systemTemp.createTempSync('vhunambi_hud_p60_');
      SovereignDomainStorageMode.clearAllForTesting();
      HiveCompactionScheduler.resetForTesting();
      SovereignHiveBootstrapService.resetForTesting();
      Hive.init(tempDir.path);
      await SovereignHiveBootstrapService.openAllBoxes();
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
      await closeAllOpenBoxesSequentially();
      SovereignDomainStorageMode.clearAllForTesting();
      HiveCompactionScheduler.resetForTesting();
      SovereignHiveBootstrapService.resetForTesting();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    testWidgets(
      'ProfileSettingsDrawer embeds HiveBrainTelemetryCard displaying 26/26 boxes, AES-256 pill, and triggers compact/sync actions',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        try {
          await tester.runAsync(() async {
            await Hive.box<dynamic>(AppConstants.tracksBoxKey).put(
              'hud_probe_track',
              <String, dynamic>{'id': 'hud_probe_track'},
            );
          });

          final outbox = SyncOutboxService(isInMemoryOnly: true);
          await tester.runAsync(() => outbox.init());
          final mockHttp = MockClient((request) async {
            return http.Response(
              '{"latestSeq": 12, "hasMore": false, "changes": []}',
              200,
            );
          });
          final coordinator = EdgeSyncCoordinator(
            outboxService: outbox,
            httpClient: mockHttp,
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                syncOutboxServiceProvider.overrideWithValue(outbox),
                edgeSyncCoordinatorProvider.overrideWith((ref) => coordinator),
              ],
              child: MaterialApp(
                theme: AppTheme.darkTheme,
                home: const Scaffold(body: ProfileSettingsDrawer()),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(HiveBrainTelemetryCard), findsOneWidget);
          expect(
            find.byKey(const Key('hive_brain_status_card')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('hive_encryption_verified_pill')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('hive_box_metrics_badge')),
            findsOneWidget,
          );
          expect(find.byKey(const Key('hive_compact_now_btn')), findsOneWidget);
          expect(find.byKey(const Key('hive_sync_now_btn')), findsOneWidget);

          expect(find.text('Sovereign Hive Brain'), findsOneWidget);
          expect(find.text('26 / 26 Boxes'), findsOneWidget);
          expect(find.text('AES-256 Encrypted (7 Boxes)'), findsOneWidget);
          expect(find.text('Tier 0: 7 | Tier 1: 17 | Tier 2: 2'), findsOneWidget);

          // Tap Compact Now -> invokes HiveCompactionScheduler.compactAllBoxesNow
          await tester.tap(find.byKey(const Key('hive_compact_now_btn')));
          await tester.pump();
          await pumpRealAsyncUntil(
            tester,
            () => find.byType(SnackBar).evaluate().isNotEmpty,
          );
          expect(HiveCompactionScheduler.totalCompactionsExecuted, 26);
          expect(find.byType(SnackBar), findsOneWidget);

          // Dismiss first SnackBar before tapping Sync Brain
          ScaffoldMessenger.of(
            tester.element(find.byType(HiveBrainTelemetryCard)),
          ).clearSnackBars();
          await tester.pumpAndSettle();

          // Tap Sync Brain -> invokes EdgeSyncCoordinator.syncNow() and updates Seq #12
          await tester.tap(find.byKey(const Key('hive_sync_now_btn')));
          await tester.pump();
          await pumpRealAsyncUntil(
            tester,
            () => find.text('Sovereign Hive synchronized with Edge WAL')
                .evaluate()
                .isNotEmpty,
          );
          expect(coordinator.state.lastServerSeq, 12);
          expect(find.textContaining('Seq #12'), findsOneWidget);
          expect(
            find.text('Sovereign Hive synchronized with Edge WAL'),
            findsOneWidget,
          );
        } finally {
          await tester.runAsync(closeAllOpenBoxesSequentially);
        }
      },
    );
  });
}


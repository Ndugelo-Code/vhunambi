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
import 'package:vhunambi_client/core/auth/auth_providers.dart';
import 'package:vhunambi_client/core/auth/sovereign_auth_repository.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/core/storage/hive_compaction_scheduler.dart';
import 'package:vhunambi_client/core/storage/sovereign_domain_repositories.dart';
import 'package:vhunambi_client/core/storage/sovereign_hive_bootstrap_service.dart';
import 'package:vhunambi_client/core/sync/edge_sync_coordinator.dart';
import 'package:vhunambi_client/core/sync/sync_outbox_service.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/auth/presentation/widgets/sovereign_auth_sheet.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/account_identity_security_card.dart';
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

  group('Phase 61 M61.6: Sovereign Identity HUD & Auth Sheet Widget Tests', () {
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
      int maxSteps = 800,
      String failureLabel = 'condition',
    }) async {
      for (var i = 0; i < maxSteps; i++) {
        if (condition()) return;
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      fail('Timed out waiting for $failureLabel');
    }

    Future<void> closeAllOpenBoxesInWidgetTest(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));

      final openBoxes = <BoxBase<dynamic>>[
        if (Hive.isBoxOpen(AppConstants.prefsBoxKey))
          Hive.box<dynamic>(AppConstants.prefsBoxKey),
        for (final boxKey in SovereignHiveBootstrapService.allBoxKeys)
          if (boxKey != AppConstants.prefsBoxKey && Hive.isBoxOpen(boxKey))
            SovereignHiveBootstrapService.mapTypedBoxKeys.contains(boxKey)
                ? Hive.box<Map>(boxKey)
                : Hive.box<dynamic>(boxKey),
      ];

      if (openBoxes.isNotEmpty) {
        var remaining = openBoxes.length;
        for (final box in openBoxes) {
          box.close().whenComplete(() {
            remaining--;
          });
        }
        await pumpRealAsyncUntil(
          tester,
          () => remaining <= 0,
          maxSteps: 2000,
          failureLabel: 'all open Hive boxes to close in widget test teardown',
        );
      }

      var hiveClosed = false;
      Hive.close().whenComplete(() {
        hiveClosed = true;
      });
      await pumpRealAsyncUntil(
        tester,
        () => hiveClosed,
        maxSteps: 600,
        failureLabel: 'Hive.close() in widget test teardown',
      );
    }

    Future<void> closeAllOpenBoxesSequentially() async {
      final orderedKeys = <String>[
        if (Hive.isBoxOpen(AppConstants.prefsBoxKey)) AppConstants.prefsBoxKey,
        ...SovereignHiveBootstrapService.allBoxKeys.where(
          (k) => k != AppConstants.prefsBoxKey && Hive.isBoxOpen(k),
        ),
      ];
      for (final boxKey in orderedKeys) {
        if (!Hive.isBoxOpen(boxKey)) continue;
        final box =
            SovereignHiveBootstrapService.mapTypedBoxKeys.contains(boxKey)
            ? Hive.box<Map>(boxKey)
            : Hive.box<dynamic>(boxKey);
        if (!box.isOpen) continue;
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
      tempDir = Directory.systemTemp.createTempSync('vhunambi_hud_p61_');
      SovereignDomainStorageMode.clearAllForTesting();
      SovereignAuthRepository.clearSessionMemory();
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
      SovereignAuthRepository.clearSessionMemory();
      HiveCompactionScheduler.resetForTesting();
      SovereignHiveBootstrapService.resetForTesting();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    testWidgets(
      'ProfileSettingsDrawer shows AccountIdentitySecurityCard, opens SovereignAuthSheet, handles auth error, switches account & signs out',
      timeout: const Timeout(Duration(seconds: 90)),
      (tester) async {
        tester.view.physicalSize = const Size(1280, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final mockHttp = MockClient((req) async {
          if (req.url.path.endsWith('/api/auth/login')) {
            final body = jsonDecode(req.body) as Map<String, dynamic>;
            if (body['password'] == 'WrongPass') {
              return http.Response(
                jsonEncode(<String, dynamic>{
                  'code': 'AUTH_INVALID_CREDENTIALS',
                  'message': 'Invalid creator credentials',
                }),
                401,
              );
            }
            return http.Response(
              jsonEncode(<String, dynamic>{
                'user': <String, dynamic>{
                  'userId': 'usr_makhadzi',
                  'creatorId': 'creator_makhadzi',
                  'handle': '@makhadzi',
                  'displayName': 'Makhadzi',
                  'email': 'makhadzi@vhunambi.za',
                  'role': 'creator',
                },
                'session': <String, dynamic>{'sessionId': 'sess_hud_1'},
                'accessToken': 'jwt_hud_makhadzi',
                'refreshToken': 'vrt_hud_makhadzi',
                'expiresAt': DateTime.now()
                    .toUtc()
                    .add(const Duration(minutes: 15))
                    .toIso8601String(),
              }),
              200,
            );
          }
          if (req.url.path.endsWith('/api/auth/logout')) {
            return http.Response('{"success":true}', 200);
          }
          return http.Response('{}', 200);
        });

        final outbox = SyncOutboxService(isInMemoryOnly: true);
        await tester.runAsync(() => outbox.init());
        final coordinator = EdgeSyncCoordinator(
          outboxService: outbox,
          httpClient: mockHttp,
        );

        await tester.runAsync(() async {
          await Hive.box<dynamic>(
            AppConstants.playlistsBoxKey,
          ).put('pl_guest_1', <String, dynamic>{'id': 'pl_guest_1'});
          await Hive.box<dynamic>(
            AppConstants.tracksBoxKey,
          ).put('shared_track_1', <String, dynamic>{'id': 'shared_track_1'});
        });

        try {
          await tester.pumpWidget(
            ProviderScope(
              overrides: <Override>[
                sovereignAuthHttpClientProvider.overrideWithValue(mockHttp),
                syncOutboxServiceProvider.overrideWithValue(outbox),
                edgeSyncCoordinatorProvider.overrideWith((ref) => coordinator),
              ],
              child: MaterialApp(
                theme: AppTheme.darkTheme,
                home: const Scaffold(body: ProfileSettingsDrawer()),
              ),
            ),
          );
          await tester.pumpAndSettle(
            const Duration(milliseconds: 100),
            EnginePhase.sendSemanticsUpdate,
            const Duration(seconds: 5),
          );

          expect(find.byType(AccountIdentitySecurityCard), findsOneWidget);
          expect(
            find.byKey(const Key('account_identity_security_card')),
            findsOneWidget,
          );
          expect(find.text('@cern'), findsOneWidget);
          expect(find.text('Local Studio Guest'), findsOneWidget);

          // Open SovereignAuthSheet
          final openBtn = find.byKey(const Key('account_switch_signin_btn'));
          await tester.ensureVisible(openBtn);
          await tester.tap(openBtn);
          await tester.pump();
          await pumpRealAsyncUntil(
            tester,
            () => find.byType(SovereignAuthSheet).evaluate().isNotEmpty,
            failureLabel: 'SovereignAuthSheet to open',
          );
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.byType(SovereignAuthSheet), findsOneWidget);
          expect(find.byKey(const Key('auth_tab_signin')), findsOneWidget);
          expect(find.byKey(const Key('auth_tab_register')), findsOneWidget);

          // Invalid credentials display inline error banner
          await tester.enterText(
            find.byKey(const Key('auth_identifier_input')),
            '@makhadzi',
          );
          await tester.enterText(
            find.byKey(const Key('auth_password_input')),
            'WrongPass',
          );
          final submitBtn = find.byKey(const Key('auth_submit_btn'));
          await tester.ensureVisible(submitBtn);
          await tester.tap(submitBtn);
          await tester.pump();
          await pumpRealAsyncUntil(
            tester,
            () => find
                .byKey(const Key('auth_error_banner'))
                .evaluate()
                .isNotEmpty,
            failureLabel: 'auth_error_banner',
          );

          expect(find.byKey(const Key('auth_error_banner')), findsOneWidget);
          expect(find.text('Invalid creator credentials'), findsOneWidget);

          // Switch via Quick Studio Chip @makhadzi -> updates HUD + sanitizes guest playlist
          final makhadziChip = find.byKey(
            const Key('auth_quick_chip_makhadzi'),
          );
          await tester.ensureVisible(makhadziChip);
          await tester.tap(makhadziChip);
          await tester.pump();
          await pumpRealAsyncUntil(
            tester,
            () =>
                find.byType(SovereignAuthSheet).evaluate().isEmpty &&
                find.text('Makhadzi').evaluate().isNotEmpty,
            failureLabel: 'Makhadzi HUD update after quick switch',
          );
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.byType(SovereignAuthSheet), findsNothing);
          expect(find.text('Makhadzi'), findsOneWidget);
          expect(find.text('@makhadzi'), findsOneWidget);
          expect(find.text('Tenant: creator_makhadzi'), findsOneWidget);
          expect(find.text('JWT + AES-256 Active'), findsOneWidget);
          expect(find.byKey(const Key('account_sign_out_btn')), findsOneWidget);
          expect(
            Hive.box<dynamic>(AppConstants.playlistsBoxKey).isEmpty,
            isTrue,
          );
          expect(
            Hive.box<dynamic>(AppConstants.tracksBoxKey).get('shared_track_1'),
            isNotNull,
          );

          // Sign out reverts back to guest @cern
          final signOutBtn = find.byKey(const Key('account_sign_out_btn'));
          await tester.ensureVisible(signOutBtn);
          await tester.tap(signOutBtn);
          await tester.pump();
          await pumpRealAsyncUntil(
            tester,
            () =>
                find.text('Local Studio Guest').evaluate().isNotEmpty &&
                find
                    .byKey(const Key('account_sign_out_btn'))
                    .evaluate()
                    .isEmpty,
            failureLabel: 'Sign Out revert to @cern guest',
          );
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.text('@cern'), findsOneWidget);
          expect(find.text('Local Studio Guest'), findsOneWidget);
          expect(find.byKey(const Key('account_sign_out_btn')), findsNothing);
        } finally {
          await closeAllOpenBoxesInWidgetTest(tester);
        }
      },
    );

    testWidgets(
      'SovereignAuthSheet Create Account tab registers new creator and updates HUD',
      timeout: const Timeout(Duration(seconds: 90)),
      (tester) async {
        tester.view.physicalSize = const Size(1280, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final mockHttp = MockClient((req) async {
          if (req.url.path.endsWith('/api/auth/register')) {
            return http.Response(
              jsonEncode(<String, dynamic>{
                'user': <String, dynamic>{
                  'userId': 'usr_zulu_prince',
                  'creatorId': 'creator_zulu_prince',
                  'handle': '@zulu_prince',
                  'displayName': 'Zulu Prince',
                  'email': 'zulu@vhunambi.za',
                  'role': 'creator',
                },
                'session': <String, dynamic>{'sessionId': 'sess_reg_1'},
                'accessToken': 'jwt_zulu_prince',
                'refreshToken': 'vrt_zulu_prince',
                'expiresAt': DateTime.now()
                    .toUtc()
                    .add(const Duration(minutes: 15))
                    .toIso8601String(),
              }),
              201,
            );
          }
          return http.Response('{}', 200);
        });

        final outbox = SyncOutboxService(isInMemoryOnly: true);
        await tester.runAsync(() => outbox.init());
        final coordinator = EdgeSyncCoordinator(
          outboxService: outbox,
          httpClient: mockHttp,
        );

        try {
          await tester.pumpWidget(
            ProviderScope(
              overrides: <Override>[
                sovereignAuthHttpClientProvider.overrideWithValue(mockHttp),
                syncOutboxServiceProvider.overrideWithValue(outbox),
                edgeSyncCoordinatorProvider.overrideWith((ref) => coordinator),
              ],
              child: MaterialApp(
                theme: AppTheme.darkTheme,
                home: const Scaffold(body: ProfileSettingsDrawer()),
              ),
            ),
          );
          await tester.pumpAndSettle(
            const Duration(milliseconds: 100),
            EnginePhase.sendSemanticsUpdate,
            const Duration(seconds: 5),
          );

          final switchBtn = find.byKey(const Key('account_switch_signin_btn'));
          await tester.ensureVisible(switchBtn);
          await tester.tap(switchBtn);
          await tester.pump();
          await pumpRealAsyncUntil(
            tester,
            () => find.byType(SovereignAuthSheet).evaluate().isNotEmpty,
            failureLabel: 'SovereignAuthSheet to open for Create Account',
          );
          await tester.pump(const Duration(milliseconds: 300));

          final registerTab = find.byKey(const Key('auth_tab_register'));
          await tester.ensureVisible(registerTab);
          await tester.tap(registerTab);
          await tester.pump(const Duration(milliseconds: 250));

          await tester.enterText(
            find.byKey(const Key('auth_handle_input')),
            '@zulu_prince',
          );
          await tester.enterText(
            find.byKey(const Key('auth_display_name_input')),
            'Zulu Prince',
          );
          await tester.enterText(
            find.byKey(const Key('auth_email_input')),
            'zulu@vhunambi.za',
          );
          await tester.enterText(
            find.byKey(const Key('auth_password_input')),
            'StrongPass!99',
          );

          final submitBtn = find.byKey(const Key('auth_submit_btn'));
          await tester.ensureVisible(submitBtn);
          await tester.tap(submitBtn);
          await tester.pump();
          await pumpRealAsyncUntil(
            tester,
            () =>
                find.byType(SovereignAuthSheet).evaluate().isEmpty &&
                find.text('Zulu Prince').evaluate().isNotEmpty,
            failureLabel: 'Create Account HUD update',
          );
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.byType(SovereignAuthSheet), findsNothing);
          expect(find.text('Zulu Prince'), findsOneWidget);
          expect(find.text('@zulu_prince'), findsOneWidget);
          expect(find.text('Tenant: creator_zulu_prince'), findsOneWidget);
          expect(find.text('JWT + AES-256 Active'), findsOneWidget);
        } finally {
          await closeAllOpenBoxesInWidgetTest(tester);
        }
      },
    );
  });
}

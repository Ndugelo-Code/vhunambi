import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vhunambi_client/core/auth/auth_providers.dart';
import 'package:vhunambi_client/core/auth/sovereign_auth_repository.dart';
import 'package:vhunambi_client/core/auth/sovereign_auth_session.dart';
import 'package:vhunambi_client/core/auth/sovereign_hive_account_sanitizer.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/core/network/sovereign_api_client.dart';
import 'package:vhunambi_client/core/storage/checkout_write_ahead_journal.dart';
import 'package:vhunambi_client/core/storage/hive_aes_vault_cipher.dart';
import 'package:vhunambi_client/core/storage/hive_compaction_scheduler.dart';
import 'package:vhunambi_client/core/storage/sovereign_domain_repositories.dart';
import 'package:vhunambi_client/core/storage/sovereign_hive_bootstrap_service.dart';
import 'package:vhunambi_client/core/sync/edge_sync_coordinator.dart';
import 'package:vhunambi_client/core/sync/sync_outbox_service.dart';
import 'package:vhunambi_client/core/utils/creator_id_utils.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/song_metadata_dna.dart';
import 'package:vhunambi_client/features/content_studio/presentation/providers/content_studio_provider.dart';
import 'package:vhunambi_client/features/creator_dna/domain/entities/creator_dna_profile.dart';
import 'package:vhunambi_client/features/creator_dna/presentation/providers/creator_dna_provider.dart';
import 'package:vhunambi_client/features/explore/presentation/providers/explore_providers.dart';
import 'package:vhunambi_client/features/library/presentation/providers/library_providers.dart';
import 'package:vhunambi_client/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:vhunambi_client/features/profile/presentation/providers/profile_providers.dart';
import 'package:vhunambi_client/features/social/presentation/providers/creator_wallet_provider.dart';
import 'package:vhunambi_client/features/social/presentation/providers/reels_comments_provider.dart';

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

Map<String, dynamic> _authBundle({
  String userId = 'usr_makhadzi',
  String creatorId = 'creator_makhadzi',
  String handle = '@makhadzi',
  String displayName = 'Makhadzi',
  String accessToken = 'jwt_access_1',
  String refreshToken = 'vrt_refresh_1',
}) {
  return <String, dynamic>{
    'user': <String, dynamic>{
      'userId': userId,
      'creatorId': creatorId,
      'handle': handle,
      'displayName': displayName,
      'email': '${extractRawCreatorId(creatorId)}@vhunambi.za',
      'role': 'creator',
    },
    'session': <String, dynamic>{'sessionId': 'sess_01'},
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresAt': DateTime.now()
        .toUtc()
        .add(const Duration(minutes: 15))
        .toIso8601String(),
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 61: Sovereign Auth, Crypto & Multi-Tenant Security Convergence', () {
    late Directory tempDir;

    Future<void> closeAllBoxesSequentially() async {
      final ordered = <String>[
        if (Hive.isBoxOpen(AppConstants.prefsBoxKey)) AppConstants.prefsBoxKey,
        ...SovereignHiveBootstrapService.allBoxKeys.where(
          (k) => k != AppConstants.prefsBoxKey && Hive.isBoxOpen(k),
        ),
      ];
      for (final key in ordered) {
        final box = SovereignHiveBootstrapService.mapTypedBoxKeys.contains(key)
            ? Hive.box<Map>(key)
            : Hive.box<dynamic>(key);
        await box.flush();
        await box.close();
      }
      await Hive.close();
    }

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vhunambi_p61_auth_');
      SovereignDomainStorageMode.clearAllForTesting();
      CheckoutWriteAheadJournal.clearSessionMemory();
      SovereignAuthRepository.clearSessionMemory();
      HiveCompactionScheduler.resetForTesting();
      SovereignHiveBootstrapService.resetForTesting();
      Hive.init(tempDir.path);
      await SovereignHiveBootstrapService.openAllBoxes();
    });

    tearDown(() async {
      await closeAllBoxesSequentially();
      SovereignDomainStorageMode.clearAllForTesting();
      CheckoutWriteAheadJournal.clearSessionMemory();
      SovereignAuthRepository.clearSessionMemory();
      HiveCompactionScheduler.resetForTesting();
      SovereignHiveBootstrapService.resetForTesting();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
      'CSPRNG per-device genesis salt persists across restart and isolates keys per installation',
      timeout: const Timeout(Duration(seconds: 90)),
      () async {
        final prefsA = Hive.box<dynamic>(AppConstants.prefsBoxKey);
        final saltA =
            prefsA.get(HiveAesVaultCipher.deviceGenesisSaltPrefsKey) as String?;
        expect(saltA, isNotNull);
        expect(saltA!.length, greaterThanOrEqualTo(32));

        final keyA1 = HiveAesVaultCipher.derive256BitKey(
          deviceSalt: saltA,
          domainInfo: AppConstants.tokenBoxKey,
        );

        await closeAllBoxesSequentially();
        SovereignHiveBootstrapService.resetForTesting();
        Hive.init(tempDir.path);
        await SovereignHiveBootstrapService.openAllBoxes();

        final saltA2 =
            Hive.box<dynamic>(
                  AppConstants.prefsBoxKey,
                ).get(HiveAesVaultCipher.deviceGenesisSaltPrefsKey)
                as String?;
        expect(saltA2, saltA);
        final keyA2 = HiveAesVaultCipher.derive256BitKey(
          deviceSalt: saltA2!,
          domainInfo: AppConstants.tokenBoxKey,
        );
        expect(keyA2, orderedEquals(keyA1));

        // Second fresh installation directory derives a distinct CSPRNG salt + key
        final tempDirB = Directory.systemTemp.createTempSync('vhunambi_p61_b_');
        try {
          await closeAllBoxesSequentially();
          SovereignHiveBootstrapService.resetForTesting();
          Hive.init(tempDirB.path);
          await SovereignHiveBootstrapService.openAllBoxes();

          final saltB =
              Hive.box<dynamic>(
                    AppConstants.prefsBoxKey,
                  ).get(HiveAesVaultCipher.deviceGenesisSaltPrefsKey)
                  as String?;
          expect(saltB, isNotNull);
          expect(saltB, isNot(saltA));

          final keyB = HiveAesVaultCipher.derive256BitKey(
            deviceSalt: saltB!,
            domainInfo: AppConstants.tokenBoxKey,
          );
          expect(keyB, isNot(orderedEquals(keyA1)));
        } finally {
          await closeAllBoxesSequentially();
          if (tempDirB.existsSync()) {
            tempDirB.deleteSync(recursive: true);
          }
          // Reopen tempDir cleanly for tearDown
          SovereignHiveBootstrapService.resetForTesting();
          Hive.init(tempDir.path);
          await SovereignHiveBootstrapService.openAllBoxes();
        }
      },
    );

    test(
      'SovereignAuthRepository persists JWT session across cold restart while preserving onboarding state',
      () async {
        await SovereignPrefsRepository.saveOnboardingState(<String, dynamic>{
          'completed': true,
          'birthYear': 1995,
          'culturalHeritage': 'Tshivenḓa',
        });

        final mockHttp = MockClient((req) async {
          if (req.url.path.endsWith('/api/auth/login')) {
            return http.Response(jsonEncode(_authBundle()), 200);
          }
          if (req.url.path.endsWith('/api/auth/logout')) {
            return http.Response('{"success":true}', 200);
          }
          return http.Response('{}', 404);
        });

        final repo = SovereignAuthRepository(httpClient: mockHttp);
        final signedIn = await repo.login(
          identifier: '@makhadzi',
          password: AuthSessionNotifier.defaultSeededPassword,
        );
        expect(signedIn.canonicalCreatorId, 'creator_makhadzi');
        expect(signedIn.accessToken, 'jwt_access_1');
        expect(signedIn.isAuthenticated, isTrue);

        // Restart Hive completely
        await closeAllBoxesSequentially();
        SovereignAuthRepository.clearSessionMemory();
        SovereignHiveBootstrapService.resetForTesting();
        Hive.init(tempDir.path);
        await SovereignHiveBootstrapService.openAllBoxes();

        final reloadedRepo = SovereignAuthRepository(httpClient: mockHttp);
        final restored = reloadedRepo.loadSession();
        expect(restored.canonicalCreatorId, 'creator_makhadzi');
        expect(restored.handle, '@makhadzi');
        expect(restored.accessToken, 'jwt_access_1');

        final onboarding = SovereignPrefsRepository.loadOnboardingState();
        expect(onboarding?['completed'], isTrue);
        expect(onboarding?['birthYear'], 1995);

        await reloadedRepo.logout(
          accessToken: restored.accessToken,
          refreshToken: restored.refreshToken,
        );
        expect(reloadedRepo.loadSession().isGuest, isTrue);
        expect(
          SovereignPrefsRepository.loadOnboardingState()?['completed'],
          isTrue,
        );
      },
    );

    test(
      'SovereignHiveAccountSanitizer purges all 20 private boxes & Box<Map> WAL while preserving catalogs & genesis salt',
      () async {
        // Seed private domains (both Box<dynamic> and Box<Map>)
        await Hive.box<dynamic>(
          AppConstants.playlistsBoxKey,
        ).put('pl_priv_1', <String, dynamic>{'id': 'pl_priv_1'});
        await Hive.box<Map>(
          AppConstants.syncOutboxBoxKey,
        ).put('mut_priv_1', <String, dynamic>{'idempotencyKey': 'mut_priv_1'});
        await SovereignPrefsRepository.saveOwnerProfile(<String, dynamic>{
          'id': 'creator_makhadzi',
          'username': 'makhadzi',
          'displayName': 'Makhadzi',
        });
        await SovereignPrefsRepository.saveEdgeSyncCursor(
          lastServerSeq: 77,
          lastSyncedAt: DateTime.utc(2026, 11, 10),
        );
        await SovereignPrefsRepository.saveOnboardingState(<String, dynamic>{
          'completed': true,
        });

        // Seed shared public catalogs (must NOT be wiped)
        await Hive.box<dynamic>(
          AppConstants.tracksBoxKey,
        ).put('explore_shared_1', <String, dynamic>{'id': 'explore_shared_1'});
        await Hive.box<dynamic>(
          AppConstants.marketplaceCatalogBoxKey,
        ).put('listing_shared_1', <String, dynamic>{'id': 'listing_shared_1'});
        await Hive.box<dynamic>(
          AppConstants.socialReelsBoxKey,
        ).put('social_shared_1', <String, dynamic>{'id': 'social_shared_1'});

        final cleared =
            await SovereignHiveAccountSanitizer.purgeTenantPrivateBoxes(
              clearAuthSession: true,
            );

        expect(cleared, contains(AppConstants.playlistsBoxKey));
        expect(cleared, contains(AppConstants.syncOutboxBoxKey));
        expect(Hive.box<dynamic>(AppConstants.playlistsBoxKey).isEmpty, isTrue);
        expect(Hive.box<Map>(AppConstants.syncOutboxBoxKey).isEmpty, isTrue);
        expect(SovereignPrefsRepository.loadOwnerProfile(), isNull);
        expect(SovereignPrefsRepository.loadEdgeSyncLastSeq(), 0);

        // Shared catalogs, genesis salt & onboarding preserved
        expect(
          Hive.box<dynamic>(AppConstants.tracksBoxKey).get('explore_shared_1'),
          isNotNull,
        );
        expect(
          Hive.box<dynamic>(
            AppConstants.marketplaceCatalogBoxKey,
          ).get('listing_shared_1'),
          isNotNull,
        );
        expect(
          Hive.box<dynamic>(
            AppConstants.socialReelsBoxKey,
          ).get('social_shared_1'),
          isNotNull,
        );
        expect(
          Hive.box<dynamic>(
            AppConstants.prefsBoxKey,
          ).get(HiveAesVaultCipher.deviceGenesisSaltPrefsKey),
          isNotNull,
        );
        expect(
          SovereignPrefsRepository.loadOnboardingState()?['completed'],
          isTrue,
        );
      },
    );

    test(
      'SovereignApiClient executes single-flight 401 refresh once across concurrent HTTP & Dio calls',
      () async {
        var session = SovereignAuthSession.fromJson(
          _authBundle(accessToken: 'expired_jwt_1', refreshToken: 'vrt_rt_1'),
        );
        var refreshCalls = 0;

        final mockHttp = MockClient((req) async {
          if (req.url.path.endsWith('/api/protected/a') ||
              req.url.path.endsWith('/api/protected/b')) {
            if (req.headers['Authorization'] == 'Bearer expired_jwt_1') {
              return http.Response('{"code":"AUTH_TOKEN_EXPIRED"}', 401);
            }
            if (req.headers['Authorization'] == 'Bearer rotated_jwt_2') {
              return http.Response('{"ok":true}', 200);
            }
          }
          return http.Response('{"ok":false}', 500);
        });

        final apiClient = SovereignApiClient(
          httpClient: mockHttp,
          readSession: () => session,
          refreshSession: () async {
            refreshCalls++;
            await Future<void>.delayed(const Duration(milliseconds: 20));
            session = session.copyWith(
              accessToken: 'rotated_jwt_2',
              refreshToken: 'vrt_rt_2',
            );
            return session;
          },
        );

        final responses =
            await Future.wait<http.Response>(<Future<http.Response>>[
              apiClient.get(Uri.parse('http://localhost:3000/api/protected/a')),
              apiClient.post(
                Uri.parse('http://localhost:3000/api/protected/b'),
                body: '{}',
              ),
            ]);

        expect(responses[0].statusCode, 200);
        expect(responses[1].statusCode, 200);
        expect(refreshCalls, 1);

        // Verify Dio interceptor single-flight 401 replay as well
        session = session.copyWith(accessToken: 'expired_jwt_3');
        var dioRefreshCalls = 0;
        final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000/api'));
        dio.httpClientAdapter = _StubDioAdapter((options) async {
          if (options.headers['Authorization'] == 'Bearer expired_jwt_3') {
            return ResponseBody.fromString('{"error":"expired"}', 401);
          }
          return ResponseBody.fromString(
            '{"ok":true}',
            200,
            headers: <String, List<String>>{
              Headers.contentTypeHeader: <String>[Headers.jsonContentType],
            },
          );
        });
        final dioClient = SovereignApiClient(
          readSession: () => session,
          refreshSession: () async {
            dioRefreshCalls++;
            await Future<void>.delayed(const Duration(milliseconds: 10));
            session = session.copyWith(accessToken: 'rotated_jwt_4');
            return session;
          },
        );
        dio.interceptors.add(dioClient.buildDioInterceptor(retryDio: dio));

        final dioResults = await Future.wait(<Future<Response<dynamic>>>[
          dio.get<dynamic>('/one'),
          dio.get<dynamic>('/two'),
        ]);
        expect(dioResults[0].statusCode, 200);
        expect(dioResults[1].statusCode, 200);
        expect(dioRefreshCalls, 1);
      },
    );

    test(
      '6-domain identity convergence propagates currentCreatorIdProvider & sanitizes stale cache on switch',
      () async {
        expect(canonicalizeCreatorId('usr_me'), 'creator_cern');
        expect(canonicalizeCreatorId('buyer_user'), 'creator_cern');
        expect(canonicalizeCreatorId('@makhadzi'), 'creator_makhadzi');

        String? capturedDeltaQuery;
        Map<String, String>? capturedDeltaHeaders;
        final mockHttp = MockClient((req) async {
          if (req.url.path.endsWith('/api/auth/login')) {
            return http.Response(
              jsonEncode(
                _authBundle(
                  userId: 'usr_makhadzi',
                  creatorId: 'creator_makhadzi',
                  handle: '@makhadzi',
                  displayName: 'Makhadzi',
                  accessToken: 'jwt_makhadzi_live',
                  refreshToken: 'vrt_makhadzi_live',
                ),
              ),
              200,
            );
          }
          if (req.url.path.endsWith('/api/v1/sync/mutations')) {
            final decoded = jsonDecode(req.body) as Map<String, dynamic>;
            final muts = decoded['mutations'] as List<dynamic>? ?? const [];
            final appliedKeys = muts
                .map((m) => (m as Map<String, dynamic>)['idempotencyKey'])
                .whereType<String>()
                .toList();
            return http.Response(
              jsonEncode(<String, dynamic>{
                'applied': appliedKeys,
                'skipped': const <String>[],
                'latestSeq': 1,
              }),
              200,
            );
          }
          if (req.url.path.endsWith('/api/v1/sync/delta')) {
            capturedDeltaQuery = req.url.toString();
            capturedDeltaHeaders = req.headers;
            return http.Response(
              '{"changes":[],"latestSeq":5,"hasMore":false}',
              200,
            );
          }
          return http.Response('{}', 200);
        });

        final outbox = SyncOutboxService(isInMemoryOnly: true);
        await outbox.init();

        final container = ProviderContainer(
          overrides: <Override>[
            sovereignAuthHttpClientProvider.overrideWithValue(mockHttp),
            edgeSyncHttpClientProvider.overrideWithValue(mockHttp),
            syncOutboxServiceProvider.overrideWithValue(outbox),
          ],
        );
        addTearDown(container.dispose);

        // Seed private playlist as guest @cern before switching
        await container
            .read(playlistsProvider.notifier)
            .createPlaylist('Guest Mix');
        expect(container.read(currentCreatorIdProvider), 'creator_cern');
        expect(container.read(playlistsProvider).length, 1);

        // Sign in as @makhadzi -> triggers sanitizer + rebuilds tenant providers
        await container
            .read(authSessionProvider.notifier)
            .signIn(
              identifier: '@makhadzi',
              password: AuthSessionNotifier.defaultSeededPassword,
            );

        expect(container.read(currentCreatorIdProvider), 'creator_makhadzi');
        expect(container.read(currentCreatorHandleProvider), '@makhadzi');
        expect(
          container.read(libraryTracksProvider.notifier).activeCreatorId,
          'creator_makhadzi',
        );
        expect(
          container.read(creatorWalletProvider.notifier).activeCreatorId,
          'creator_makhadzi',
        );
        expect(container.read(ownerProfileProvider).username, 'makhadzi');

        // Stale @cern private playlist box purged & provider refreshed
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(container.read(playlistsProvider), isEmpty);

        // Create playlist under @makhadzi -> outbox carries creator_makhadzi
        await container
            .read(playlistsProvider.notifier)
            .createPlaylist('Limpopo Gold');
        expect(
          outbox.getPendingMutations().last.payload['creatorId'],
          'creator_makhadzi',
        );

        // Comment & Content Studio publish attribute cleanly to @makhadzi
        await container
            .read(reelsCommentsProvider.notifier)
            .addComment(
              clipId: 'clip_seed_01',
              text: 'Converged identity comment',
            );
        final comment = container
            .read(reelsCommentsProvider)
            .commentsByClipId['clip_seed_01']!
            .first;
        expect(comment.userId, 'creator_makhadzi');
        expect(comment.username, 'makhadzi');

        final studio = container.read(contentStudioProvider.notifier);
        studio.initializeWithDna(
          dna: SongMetadataDna.fromTrackInfo(
            id: 'dna_p61',
            title: 'Tshikona Surge',
            genre: 'Amapiano',
            language: 'Tshivenḓa',
            durationSec: 120,
          ),
          audioUrl: 'https://cdn.vhunambi.com/p61.mp3',
          coverArtUrl: 'https://cdn.vhunambi.com/p61.jpg',
        );
        final published = studio.publishClipToProfile(
          caption: 'Multi-tenant converged',
          tags: const <String>['Amapiano'],
        );
        expect(published?.creatorId, 'creator_makhadzi');
        expect(published?.creatorUsername, 'makhadzi');

        // EdgeSyncCoordinator sends Bearer JWT + X-Vhunambi-Creator-Id + creatorId query
        final synced = await container
            .read(edgeSyncCoordinatorProvider.notifier)
            .syncNow();
        expect(synced, isTrue);
        expect(capturedDeltaQuery, contains('creatorId=creator_makhadzi'));
        expect(
          capturedDeltaHeaders?['Authorization'],
          'Bearer jwt_makhadzi_live',
        );
        expect(
          capturedDeltaHeaders?['X-Vhunambi-Creator-Id'],
          'creator_makhadzi',
        );
      },
    );

    test(
      'Phase 60<->61 Intersection Guards: buildCipher/createCipher parity, L1 cache purge, and onboarding preservation on signOut',
      () async {
        // Intersection 1: HiveAesVaultCipher.buildCipher & createCipher parity + key alias
        expect(
          HiveAesVaultCipher.deviceGenesisSaltPrefKey,
          HiveAesVaultCipher.deviceGenesisSaltPrefsKey,
        );
        final builtCipher = HiveAesVaultCipher.buildCipher(
          deviceSaltOverride: 'custom_salt_test_61',
        );
        final createdCipher = HiveAesVaultCipher.createCipher(
          deviceSalt: 'custom_salt_test_61',
        );
        expect(builtCipher, isA<HiveAesCipher>());
        expect(createdCipher, isA<HiveAesCipher>());

        // Seed onboarding completion inside vhunambi_tokens before sign-in / sign-out
        await SovereignPrefsRepository.saveOnboardingState(<String, dynamic>{
          'completed': true,
          'birthYear': 1998,
          'culturalHeritage': 'Tshivenḓa',
        });

        final mockHttp = MockClient((req) async {
          if (req.url.path.endsWith('/api/auth/login')) {
            return http.Response(jsonEncode(_authBundle()), 200);
          }
          if (req.url.path.endsWith('/api/auth/logout')) {
            return http.Response('{"success":true}', 200);
          }
          return http.Response('{}', 200);
        });

        final outbox = SyncOutboxService(isInMemoryOnly: true);
        await outbox.init();

        final container = ProviderContainer(
          overrides: <Override>[
            sovereignAuthHttpClientProvider.overrideWithValue(mockHttp),
            syncOutboxServiceProvider.overrideWithValue(outbox),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(authSessionProvider.notifier)
            .signIn(
              identifier: '@makhadzi',
              password: AuthSessionNotifier.defaultSeededPassword,
            );
        expect(container.read(currentCreatorIdProvider), 'creator_makhadzi');

        // Seed User A L1 + Hive state across wallet, WAL journal, edge cursor, DNA & following
        container.read(creatorWalletProvider.notifier).topUpCoins(500);
        expect(container.read(creatorWalletProvider).userCoinsBalance, 750);

        await CheckoutWriteAheadJournal.prepareCheckout(
          CheckoutWalEntry(
            transactionId: 'wal_guard_1',
            beatId: 'beat_guard_1',
            beatTitle: 'Guard Test',
            producerName: 'Makhadzi',
            licenseTierId: 'basic_lease',
            coinPrice: 50,
            certificateJson: '{}',
            vaultTrackJson: '{}',
            isExclusive: false,
            preparedAt: DateTime.utc(2026, 11, 10),
          ),
        );
        expect(CheckoutWriteAheadJournal.getPendingEntries(), isNotEmpty);

        await SovereignPrefsRepository.saveEdgeSyncCursor(
          lastServerSeq: 88,
          lastSyncedAt: DateTime.utc(2026, 11, 10),
        );

        await container
            .read(creatorDnaProvider.notifier)
            .seedFromOnboarding(
              role: CreativeRole.producer,
              experienceLevel: ExperienceLevel.pro,
              selectedGenres: const <String>['Amapiano'],
              primaryLanguage: 'Tshivenḓa',
              secondaryLanguages: const <String>['English'],
              tempoPreference: 'fast',
              vocalEnergyPreference: 'intense',
              selectedMoods: const <String>['Uplifting'],
              completeness: 1.0,
            );
        expect(container.read(creatorDnaProvider).onboardingCompleted, isTrue);

        container
            .read(followingCreatorIdsProvider.notifier)
            .toggleFollow('creator_kabza');
        expect(
          container.read(followingCreatorIdsProvider),
          contains('creator_kabza'),
        );

        // Execute end-to-end AuthSessionNotifier.signOut() -> sanitizeForAccountTransition
        await container.read(authSessionProvider.notifier).signOut();

        // Intersection 2 assertions: L1 & Hive tenant state completely purged
        expect(container.read(currentCreatorIdProvider), 'creator_cern');
        expect(container.read(creatorWalletProvider).userCoinsBalance, 250);
        expect(WalletLedgerRepository.loadWalletSnapshot(), isNull);
        expect(CheckoutWriteAheadJournal.getPendingEntries(), isEmpty);
        expect(SovereignPrefsRepository.loadEdgeSyncLastSeq(), 0);
        expect(container.read(creatorDnaProvider).onboardingCompleted, isFalse);
        expect(
          container.read(followingCreatorIdsProvider),
          isNot(contains('creator_kabza')),
        );

        // Intersection 3 assertion: onboarding_state_v1 stays intact inside vhunambi_tokens
        final onboardingAfterLogout =
            SovereignPrefsRepository.loadOnboardingState();
        expect(onboardingAfterLogout?['completed'], isTrue);
        expect(onboardingAfterLogout?['birthYear'], 1998);

        // Verify sanitizeForAccountTransition short-circuits for same creator when !forcePurge
        await Hive.box<dynamic>(
          AppConstants.playlistsBoxKey,
        ).put('pl_same_1', <String, dynamic>{'id': 'pl_same_1'});
        final skipped =
            await SovereignHiveAccountSanitizer.sanitizeForAccountTransition(
              previousCreatorId: 'creator_cern',
              nextCreatorId: 'creator_cern',
            );
        expect(skipped, isEmpty);
        expect(
          Hive.box<dynamic>(AppConstants.playlistsBoxKey).get('pl_same_1'),
          isNotNull,
        );

        final purged =
            await SovereignHiveAccountSanitizer.sanitizeForAccountTransition(
              previousCreatorId: 'creator_cern',
              nextCreatorId: 'creator_makhadzi',
            );
        expect(purged, contains(AppConstants.playlistsBoxKey));
        expect(Hive.box<dynamic>(AppConstants.playlistsBoxKey).isEmpty, isTrue);
      },
    );
  });
}

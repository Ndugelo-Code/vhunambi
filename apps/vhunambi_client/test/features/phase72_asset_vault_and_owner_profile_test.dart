import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/auth/auth_providers.dart';
import 'package:vhunambi_client/core/auth/viewer_role.dart';
import 'package:vhunambi_client/core/navigation/navigation_providers.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_ambient_mesh_backdrop.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_track_artwork.dart';
import 'package:vhunambi_client/features/explore/domain/models/social_music_post.dart';
import 'package:vhunambi_client/features/explore/presentation/providers/explore_providers.dart';
import 'package:vhunambi_client/features/explore/presentation/views/kinetic_post_focus_view.dart';
import 'package:vhunambi_client/features/home/domain/models/creator_allowance_state.dart';
import 'package:vhunambi_client/features/home/presentation/providers/creator_allowance_provider.dart';
import 'package:vhunambi_client/features/library/domain/models/library_models.dart';
import 'package:vhunambi_client/features/library/presentation/providers/library_providers.dart';
import 'package:vhunambi_client/features/library/presentation/views/library_view.dart';
import 'package:vhunambi_client/features/library/presentation/widgets/track_actions_sheet.dart';
import 'package:vhunambi_client/features/marketplace/data/repositories/http_marketplace_repository.dart';
import 'package:vhunambi_client/features/profile/presentation/views/owner_profile_view.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/creator_wallet_deck.dart';
import 'package:vhunambi_client/features/track/presentation/providers/track_providers.dart';
import 'package:vhunambi_client/features/track/presentation/views/track_detail_view.dart';
import 'package:vhunambi_client/shared/models/track.dart';

class _MockLicensesAdapter implements HttpClientAdapter {
  RequestOptions? lastOptions;
  final Map<String, dynamic> responsePayload;

  _MockLicensesAdapter(this.responsePayload);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    return ResponseBody.fromString(
      jsonEncode(responsePayload),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<void> _boundedPump(WidgetTester tester, {int ticks = 8}) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  group('Phase 72 Backend/Client Contracts & ViewerRole Parity', () {
    test(
      'HttpMarketplaceRepository.getBuyerLicenses parses GET /licenses/:buyerId certificates',
      () async {
        final adapter = _MockLicensesAdapter({
          'certificates': [
            {
              'certificateId': 'CERT-P72-001',
              'licenseHash': 'sha256_abc',
              'beatId': 'beat_amapiano_01',
              'beatTitle': 'Soweto Log Drum Anthem',
              'producerId': 'creator_ndugelo',
              'producerHandle': '@ndugelo',
              'producerName': 'Ndugelo',
              'buyerId': 'creator_cern',
              'buyerHandle': '@cern',
              'genre': 'Amapiano',
              'bpm': 114,
              'musicalKey': 'F# Minor',
              'tier': 'stems_trackout',
              'amountPaidCoins': 150,
              'amountPaidZar': 45.0,
              'issuedAtIso8601': '2026-11-21T00:00:00.000Z',
              'vaultTrackId': 'market_beat_amapiano_01',
              'masterAudioFilePath': '/vault/soweto-log-drum.wav',
              'masterFileSha256': 'deadbeef',
              'isExclusiveRights': false,
            },
          ],
        });
        final dio = Dio()..httpClientAdapter = adapter;
        final repo = HttpMarketplaceRepository(
          dio: dio,
          baseUrl: 'https://api.vhunambi.test/api/marketplace',
          isTestMode: false,
        );

        final certs = await repo.getBuyerLicenses('cern');
        expect(
          adapter.lastOptions?.path,
          'https://api.vhunambi.test/api/marketplace/licenses/creator_cern',
        );
        expect(certs, hasLength(1));
        expect(certs.first.certificateId, 'CERT-P72-001');
        expect(certs.first.beatTitle, 'Soweto Log Drum Anthem');
        expect(certs.first.bpm, 114);
      },
    );

    test(
      'LibraryTrack JSON round-trip and TrackDetailNotifier ViewerRole.owner resolution',
      () {
        final container = ProviderContainer(
          overrides: [
            currentCreatorIdProvider.overrideWith((_) => 'creator_cern'),
          ],
        );
        addTearDown(container.dispose);

        final seedTwo = container
            .read(libraryTracksProvider)
            .firstWhere((t) => t.id == 'lib_track_002');
        final decoded = LibraryTrack.fromJson(seedTwo.toJson());
        expect(decoded.creatorId, 'creator_cern');
        expect(decoded.creatorHandle, '@cern');
        expect(decoded.moodId, 'soulful');
        expect(decoded.bpm, 112);
        expect(decoded.isPublic, isTrue);

        // Even though creatorName is 'Fifi', creatorId 'creator_cern' resolves to owner!
        final detail = container.read(trackDetailFamilyProvider('lib_track_002'));
        expect(detail.creatorId, 'creator_cern');
        expect(detail.moodId, 'soulful');
        expect(detail.bpm, 112);
        expect(
          resolveViewerRole(
            ownerCreatorId: detail.creatorId,
            ownerHandle: detail.creatorHandle,
            activeCreatorId: 'creator_cern',
          ),
          ViewerRole.owner,
        );
        expect(
          resolveViewerRole(
            ownerCreatorId: detail.creatorId,
            ownerHandle: detail.creatorHandle,
            activeCreatorId: 'creator_lerato',
          ),
          ViewerRole.visitor,
        );
      },
    );
  });

  group('Phase 72 Asset Vault (LibraryView) Glass Overhaul', () {
    testWidgets(
      'Mobile 360x800 LibraryView renders artwork, Cached Only filter, clearable search, and Cockpit action',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const LibraryView(),
            ),
          ),
        );
        await _boundedPump(tester);

        expect(find.byType(VhunambiAmbientMeshBackdrop), findsOneWidget);
        expect(find.byType(VhunambiTrackArtwork), findsWidgets);
        expect(find.byKey(const Key('library_allowance_chip')), findsOneWidget);
        expect(find.byKey(const Key('vault_filter_cached_only')), findsOneWidget);

        // Toggle Cached Only on mobile -> scopes to cached track (lib_track_001)
        await tester.tap(find.byKey(const Key('vault_filter_cached_only')));
        await _boundedPump(tester);
        expect(find.text('Grateful in the Light'), findsOneWidget);
        expect(find.text('Ndo Mufuna Matibe'), findsNothing);

        // Reset filter
        await tester.tap(find.byKey(const Key('vault_filter_cached_only')));
        await _boundedPump(tester);

        // Enter & clear search via clear button
        await tester.enterText(find.byType(TextField), 'Fifi');
        await _boundedPump(tester);
        expect(find.byKey(const Key('vault_search_clear_btn')), findsOneWidget);
        await tester.tap(find.byKey(const Key('vault_search_clear_btn')));
        await _boundedPump(tester);
        expect(container.read(librarySearchQueryProvider), '');
      },
    );

    testWidgets(
      'TrackActionsSheet opens Song Cockpit (TrackDetailView) for owned LibraryTrack',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const LibraryView(),
            ),
          ),
        );
        await _boundedPump(tester);

        // Open TrackActionsSheet and tap Cockpit action
        await tester.tap(find.byTooltip('Asset actions').first);
        await _boundedPump(tester);
        expect(find.byType(TrackActionsSheet), findsOneWidget);
        expect(
          find.byKey(const Key('track_action_open_cockpit')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('track_action_open_cockpit')));
        await _boundedPump(tester, ticks: 10);
        expect(find.byType(TrackDetailView), findsOneWidget);
      },
    );
  });

  group('Phase 72 Owner Studio Profile (OwnerProfileView) Overhaul', () {
    testWidgets(
      'Renders in Light & Dark themes, suppresses MiniPlayer overlay counter, and syncs live songs/visibility/posts/allowance',
      (tester) async {
        tester.view.physicalSize = const Size(420, 960);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final container = ProviderContainer(
          overrides: [
            currentCreatorIdProvider.overrideWith((_) => 'creator_cern'),
            creatorAllowanceProvider.overrideWith(
              (_) => CreatorAllowanceNotifier.withInitial(
                const CreatorAllowanceState(
                  creatorId: 'creator_cern',
                  freeMonthlySongsLimit: 10,
                  freeMonthlySongsRemaining: 7,
                  freeMonthlySongsUsed: 3,
                ),
              ),
            ),
            socialFeedPostsProvider.overrideWith((ref) {
              final notifier = SocialFeedPostsNotifier();
              notifier.state = [
                SocialMusicPost(
                  id: 'post_owner_p72_1',
                  creatorId: 'creator_cern',
                  creatorName: 'cern',
                  creatorHandle: '@cern',
                  publishedAt: DateTime(2026, 11, 20),
                  caption: 'Fresh log-drum bounce from the Pretoria session.',
                  track: const Track(
                    id: 'lib_track_001',
                    title: 'Grateful in the Light',
                    creatorName: 'cern',
                    genre: 'Amapiano',
                    duration: Duration(minutes: 3, seconds: 36),
                    audioUrl: 'https://r2.vhunambi.com/audio/grateful.mp3',
                  ),
                  cosignCount: 19,
                  commentCount: 4,
                ),
              ];
              return notifier;
            }),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: Navigator(
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('Root')),
                ),
              ),
            ),
          ),
        );
        await _boundedPump(tester);

        // Push OwnerProfileView onto navigator so pop can verify overlay decrement
        final nav = tester.state<NavigatorState>(find.byType(Navigator).last);
        nav.push(
          MaterialPageRoute<void>(builder: (_) => const OwnerProfileView()),
        );
        await _boundedPump(tester, ticks: 10);

        expect(container.read(pushedFullScreenOverlayCountProvider), 1);
        expect(find.byType(VhunambiAmbientMeshBackdrop), findsOneWidget);
        expect(find.text('Grateful in the Light'), findsWidgets);
        expect(find.text('Ndo Mufuna Matibe'), findsOneWidget);
        expect(find.byKey(const Key('owner_kinetic_posts_section')), findsOneWidget);
        expect(find.byKey(const Key('wallet_monthly_allowance_card')), findsOneWidget);
        expect(find.text('Monthly Free Songs (7/10 left)'), findsOneWidget);

        // Toggle visibility on lib_track_001 and verify libraryTracksProvider mutates
        final visBtn = find.byKey(
          const Key('owner_song_visibility_lib_track_001'),
        );
        await tester.ensureVisible(visBtn);
        await tester.tap(visBtn);
        await _boundedPump(tester);
        expect(
          container
              .read(libraryTracksProvider)
              .firstWhere((t) => t.id == 'lib_track_001')
              .isPublic,
          isFalse,
        );

        // Verify dark theme wallet deck also renders cleanly
        expect(find.byType(CreatorWalletDeck), findsOneWidget);

        // Tap owner Kinetic Post card -> pushes KineticPostFocusView
        final kpCard = find.byKey(
          const Key('owner_kinetic_post_card_post_owner_p72_1'),
        );
        await tester.ensureVisible(kpCard);
        await tester.tap(kpCard);
        await _boundedPump(tester, ticks: 8);
        expect(find.byType(KineticPostFocusView), findsOneWidget);

        // Pop KineticPostFocusView & OwnerProfileView -> wait >300ms route pop + microtask
        nav.pop();
        await _boundedPump(tester, ticks: 12);
        nav.pop();
        await _boundedPump(tester, ticks: 12);
        expect(container.read(pushedFullScreenOverlayCountProvider), 0);
      },
    );

    testWidgets(
      'OwnerProfileView renders Dark Mode glass surfaces cleanly and pushes PinnedSpotlightCard into TrackDetailView',
      (tester) async {
        tester.view.physicalSize = const Size(420, 960);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const OwnerProfileView(),
            ),
          ),
        );
        await _boundedPump(tester, ticks: 8);

        expect(find.byType(VhunambiAmbientMeshBackdrop), findsOneWidget);
        expect(find.text('CREATOR STUDIO'), findsOneWidget);
        expect(find.byType(CreatorWalletDeck), findsOneWidget);
      },
    );
  });
}

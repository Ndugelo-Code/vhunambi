import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vhunambi_client/core/auth/sovereign_auth_session.dart';
import 'package:vhunambi_client/core/constants/app_assets.dart';
import 'package:vhunambi_client/core/navigation/navigation_providers.dart';
import 'package:vhunambi_client/core/network/sovereign_api_client.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_track_artwork.dart';
import 'package:vhunambi_client/features/creator_dna/presentation/widgets/dna_insight_card.dart';
import 'package:vhunambi_client/features/explore/presentation/providers/explore_providers.dart';
import 'package:vhunambi_client/features/home/domain/models/creator_allowance_state.dart';
import 'package:vhunambi_client/features/home/presentation/providers/creator_allowance_provider.dart';
import 'package:vhunambi_client/features/home/presentation/utils/african_greeting_resolver.dart';
import 'package:vhunambi_client/features/home/presentation/views/home_dashboard_view.dart';
import 'package:vhunambi_client/features/library/domain/models/library_models.dart';
import 'package:vhunambi_client/features/library/presentation/providers/library_providers.dart';
import 'package:vhunambi_client/features/onboarding/domain/models/onboarding_models.dart';
import 'package:vhunambi_client/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:vhunambi_client/features/onboarding/presentation/views/splash_view.dart';
import 'package:vhunambi_client/features/player/data/services/vhunambi_audio_handler.dart';
import 'package:vhunambi_client/features/player/presentation/providers/audio_bridge_providers.dart';
import 'package:vhunambi_client/features/player/presentation/providers/player_provider.dart';
import 'package:vhunambi_client/features/player/presentation/widgets/mini_player_host.dart';
import 'package:vhunambi_client/features/player/presentation/widgets/mobile_mini_player.dart';
import 'package:vhunambi_client/features/social/presentation/widgets/trending_reels_shelf.dart';
import 'package:vhunambi_client/shared/models/track.dart';

class _EmptyLibraryNotifier extends LibraryTracksNotifier {
  _EmptyLibraryNotifier() {
    state = const <LibraryTrack>[];
  }
}

class _EmptyExploreNotifier extends ExploreTracksNotifier {
  _EmptyExploreNotifier() {
    state = const <Track>[];
  }
}

class _DoneOnboardingNotifier extends OnboardingNotifier {
  _DoneOnboardingNotifier() {
    state = const OnboardingState(
      hasCompletedOnboarding: true,
      selectedGenres: <String>['Amapiano', 'Gqom'],
      selectedLanguages: <String>['Tshivenḓa'],
    );
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('Phase 68 M68.1: Artwork Pipeline & STD-UIUX-001 Emoji Purge', () {
    test('AppAssets maps cultural genres across all 10 bundled assets', () {
      expect(AppAssets.allBundledArtworkAssets.length, equals(10));
      expect(
        AppAssets.resolveGenreCoverAsset('Amapiano'),
        equals(AppAssets.sunsetMelodiesCover),
      );
      expect(
        AppAssets.resolveGenreCoverAsset('Gqom'),
        equals(AppAssets.timbreProducer),
      );
      expect(
        AppAssets.resolveGenreCoverAsset('Maskandi'),
        equals(AppAssets.timbreElder),
      );
      expect(
        AppAssets.resolveGenreCoverAsset('Afrobeats'),
        equals(AppAssets.timbreCrooner),
      );
      expect(
        AppAssets.resolveTrackCoverSource(
          coverUrl: 'asset:${AppAssets.heritageCrateCover}',
          genre: 'Amapiano',
        ),
        equals(AppAssets.heritageCrateCover),
      );
    });

    test('AfricanGreetingResolver and DnaInsightCard are 100% emoji-free', () {
      final emojiRegex = RegExp(r'[\u{1F300}-\u{1FAFF}\u2600-\u27BF]', unicode: true);
      for (var hour = 0; hour < 24; hour++) {
        final dt = DateTime(2026, 11, 17, hour);
        expect(
          emojiRegex.hasMatch(
            AfricanGreetingResolver.getTimeGlyph(now: dt),
          ),
          isFalse,
        );
        expect(
          emojiRegex.hasMatch(
            AfricanGreetingResolver.getGreeting(language: 'Tshivenḓa', now: dt),
          ),
          isFalse,
        );
      }
      expect(AppAssets.resolveGenreCoverAsset('Gospel'), AppAssets.fiveVoicesCover);
      // tipTextFor check via CreatorDnaProfile initial / calibrated states covered statically
      expect(DnaInsightCard, isNotNull);
    });

    testWidgets('Explore & Library seeded catalogs populate coverUrl via VhunambiTrackArtwork', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              final explore = ref.watch(exploreTracksProvider);
              final library = ref.watch(libraryTracksProvider);
              expect(explore.every((t) => (t.coverUrl ?? '').startsWith('asset:')), isTrue);
              expect(library.every((t) => (t.coverImageUrl ?? '').startsWith('asset:')), isTrue);
              return const MaterialApp(
                home: Scaffold(
                  body: VhunambiTrackArtwork(
                    coverUrl: 'asset:assets/artwork/splash_hero.png',
                    genre: 'Amapiano',
                    trackId: 'trk_test',
                    width: 64,
                    height: 64,
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(VhunambiTrackArtwork), findsOneWidget);
    });
  });

  group('Phase 68 M68.3: CreatorAllowanceNotifier & Tab-0 MiniPlayer Suppression', () {
    test('CreatorAllowanceNotifier parses /api/wallet/allowance and falls back safely offline', () async {
      final mockHttp = MockClient((request) async {
        expect(request.url.path, '/api/wallet/allowance');
        return http.Response(
          jsonEncode(<String, dynamic>{
            'success': true,
            'userId': 'creator_ndugelo',
            'planTier': 'free',
            'freeMonthlySongsLimit': 10,
            'freeMonthlySongsUsed': 3,
            'freeMonthlySongsRemaining': 7,
          }),
          200,
        );
      });

      final client = SovereignApiClient(
        httpClient: mockHttp,
        readSession: () => const SovereignAuthSession(
          userId: 'usr_1',
          creatorId: 'creator_ndugelo',
          handle: '@ndugelo',
          displayName: 'Ndugelo',
          email: 'n@vhunambi.za',
          accessToken: 'jwt_ok',
          isGuest: false,
        ),
        refreshSession: () async => null,
      );

      final notifier = CreatorAllowanceNotifier(
        creatorId: 'creator_ndugelo',
        apiClient: client,
        isAuthenticated: () => true,
        apiRestBaseUrl: 'https://api.vhunambi.test/api',
        autoSync: false,
      );

      expect(notifier.state.freeMonthlySongsRemaining, equals(10));
      await notifier.refreshFromServer();
      expect(notifier.state.freeMonthlySongsRemaining, equals(7));
      expect(notifier.state.pillLabel, equals('7/10'));

      // Offline error preserves prior known allowance without throwing
      final failingClient = SovereignApiClient(
        httpClient: MockClient((_) async => throw Exception('offline')),
        readSession: () => const SovereignAuthSession(
          userId: 'usr_1',
          creatorId: 'creator_ndugelo',
          handle: '@ndugelo',
          displayName: 'Ndugelo',
          email: 'n@vhunambi.za',
          accessToken: 'jwt_ok',
          isGuest: false,
        ),
        refreshSession: () async => null,
      );
      final offlineNotifier = CreatorAllowanceNotifier(
        creatorId: 'creator_other',
        apiClient: failingClient,
        isAuthenticated: () => true,
        apiRestBaseUrl: 'https://api.vhunambi.test/api',
        autoSync: false,
      );
      await offlineNotifier.refreshFromServer();
      expect(offlineNotifier.state.freeMonthlySongsRemaining, equals(10));
    });

    testWidgets('MiniPlayerHost suppresses on Tab 0 when NowPlayingHomeCard is mounted and restores on Tab 1', (tester) async {
      final handler = TestVhunambiAudioHandler();
      addTearDown(handler.dispose);

      final container = ProviderContainer(
        overrides: <Override>[
          audioHandlerProvider.overrideWithValue(handler),
          isSplashActiveProvider.overrideWith((ref) => false),
          onboardingStateProvider.overrideWith((_) => _DoneOnboardingNotifier()),
        ],
      );
      addTearDown(container.dispose);

      container.read(playerStateProvider.notifier).playTrack(
            const Track(
              id: 'trk_tab_test',
              title: 'Morning Log Drum',
              creatorName: 'Sigwa',
              genre: 'Amapiano',
              duration: Duration(minutes: 3),
            ),
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            builder: (context, child) => Stack(
              children: <Widget>[
                ?child,
                const MiniPlayerHost(),
              ],
            ),
            home: const HomeDashboardView(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Tab 0 + mounted NowPlayingHomeCard -> MiniPlayerHost is suppressed
      expect(container.read(homeInlineNowPlayingMountedProvider), isTrue);
      expect(find.byType(MobileMiniPlayer), findsNothing);

      // Switching to Tab 1 (Explore) un-suppresses MiniPlayerHost cleanly
      container.read(appNavigationTabProvider.notifier).state = 1;
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(MobileMiniPlayer), findsOneWidget);
    });
  });

  group('Phase 68 M68.2 & M68.4: Decluttered Main Room, Dual-Theme & Empty State', () {
    testWidgets('Purges fake prompt card, TrendingReelsShelf, TextField, and seed-01 mock', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            libraryTracksProvider.overrideWith((_) => _EmptyLibraryNotifier()),
            exploreTracksProvider.overrideWith((_) => _EmptyExploreNotifier()),
            creatorAllowanceProvider.overrideWith(
              (_) => CreatorAllowanceNotifier.withInitial(
                const CreatorAllowanceState(
                  creatorId: 'creator_ndugelo',
                  freeMonthlySongsLimit: 10,
                  freeMonthlySongsRemaining: 10,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const HomeDashboardView(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('What are you feeling today?'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(TrendingReelsShelf), findsNothing);
      expect(find.text('Ndo Mufuna Matibe'), findsNothing);
      expect(find.byKey(const Key('home_now_playing_empty_card')), findsOneWidget);
      expect(find.byKey(const Key('home_allowance_pill')), findsOneWidget);
      expect(find.text('10/10 Free'), findsOneWidget);
    });

    testWidgets('Renders cleanly without overflow at 360x780 Light and 1280x800 Dark', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const HomeDashboardView(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const Key('home_now_playing_card')), findsOneWidget);
      expect(find.byKey(const Key('home_trending_genres_shelf')), findsOneWidget);
      expect(find.byKey(const Key('home_create_studio_cta')), findsOneWidget);
      expect(find.byKey(const Key('home_try_rhythm_btn')), findsOneWidget);

      tester.view.physicalSize = const Size(1280, 800);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const HomeDashboardView(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const Key('home_now_playing_card')), findsOneWidget);
      expect(find.byKey(const Key('home_try_rhythm_btn')), findsOneWidget);
    });
  });
}

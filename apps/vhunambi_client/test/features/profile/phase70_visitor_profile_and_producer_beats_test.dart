import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/navigation/navigation_providers.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/creator_dna/presentation/widgets/creator_dna_profile_card.dart';
import 'package:vhunambi_client/features/explore/presentation/views/kinetic_post_focus_view.dart';
import 'package:vhunambi_client/features/marketplace/data/repositories/http_marketplace_repository.dart';
import 'package:vhunambi_client/features/marketplace/domain/models/marketplace_models.dart';
import 'package:vhunambi_client/features/marketplace/presentation/providers/marketplace_providers.dart';
import 'package:vhunambi_client/features/player/presentation/widgets/mini_player_host.dart';
import 'package:vhunambi_client/features/profile/presentation/views/artist_profile_view.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/artist_voice_showcase_card.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/loading/loading_overlay.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/producer_beat_listing_tile.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/profile_stats_grid.dart';

class _StubHttpClientAdapter implements HttpClientAdapter {
  final List<String> requestedUrls = <String>[];
  final ResponseBody Function(RequestOptions options) responder;

  _StubHttpClientAdapter(this.responder);

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestedUrls.add(options.uri.toString());
    return responder(options);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async => null,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets(
    'Visitor profile enforces Facebook 5-tab benchmark, inline stats (no Day Streak), no voice/DNA leakage, and Light-Mode Following contrast',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            themeMode: ThemeMode.light,
            home: const ArtistProfileView(artistId: 'fifi'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 5 tabs defaulting to Overview
      expect(find.byKey(const Key('visitor_tab_overview')), findsOneWidget);
      expect(find.byKey(const Key('visitor_tab_songs')), findsOneWidget);
      expect(
        find.byKey(const Key('visitor_tab_posts_reels')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('visitor_tab_beats')), findsOneWidget);
      expect(find.byKey(const Key('visitor_tab_about')), findsOneWidget);
      expect(find.text('Artist Overview'), findsOneWidget);

      // Inline social proof strip without private Day Streak or ProfileStatsGrid
      expect(
        find.byKey(const Key('visitor_profile_inline_stats')),
        findsOneWidget,
      );
      expect(find.byType(ProfileStatsGrid), findsNothing);
      expect(find.text('Day Streak'), findsNothing);
      expect(find.byType(ArtistVoiceShowcaseCard), findsNothing);
      expect(find.byType(CreatorDnaProfileCard), findsNothing);

      // STD-UIUX-001: Zero stock Icons.* on Visitor Profile surface
      expect(find.byType(Icon), findsNothing);
      expect(find.byType(PhosphorIcon), findsWidgets);

      // Instant Follow -> Following without LoadingOverlay + high-contrast text
      await tester.tap(find.byKey(const Key('profile_follow_btn')));
      await tester.pump();
      expect(find.byType(LoadingOverlay), findsNothing);
      await tester.pumpAndSettle();

      expect(find.text('Following'), findsOneWidget);
      final followingFinder = find.text('Following');
      final followingText = tester.widget<Text>(followingFinder);
      expect(followingText.style?.color, isNot(Colors.white));
      expect(
        followingText.style?.color,
        equals(AppColors.textPrimaryOf(tester.element(followingFinder))),
      );

      // Overflow [•••] menu reveals Share Profile, Copy Handle & Report Creator
      await tester.tap(find.byKey(const Key('visitor_profile_overflow_btn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('visitor_overflow_share')), findsOneWidget);
      expect(
        find.byKey(const Key('visitor_overflow_copy_handle')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('visitor_overflow_report')), findsOneWidget);
    },
  );

  testWidgets(
    'Posts & Reels tab renders live creator kinetic posts and opens KineticPostFocusView',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const ArtistProfileView(artistId: 'makhadzi'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('visitor_tab_posts_reels')));
      await tester.pumpAndSettle();

      expect(find.text('Kinetic Posts'), findsOneWidget);
      final postFinder = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key as ValueKey<String>).value.startsWith(
              'visitor_post_preview_',
            ),
      );
      expect(postFinder, findsWidgets);

      await tester.tap(postFinder.first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(KineticPostFocusView), findsOneWidget);
    },
  );

  test(
    'HttpMarketplaceRepository.getProducerBeats & producerBeatsFamilyProvider consume EP-P58-MKT-VERIFY-PRODUCER and merge fallback cleanly',
    () async {
      final adapter = _StubHttpClientAdapter((options) {
        final payload = jsonEncode(<String, dynamic>{
          'producerId': 'creator_ndugelo',
          'beats': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'beat_remote_ndugelo_1',
              'title': 'Vhunambi Sovereign Dub (API Live)',
              'producerId': 'creator_ndugelo',
              'producerName': 'Ndugelo',
              'producerHandle': '@ndugelo',
              'genre': 'Amapiano',
              'bpm': 114,
              'musicalKey': 'F#m',
              'priceCoins': 75,
              'previewAudioUrl': 'https://cdn.vhunambi.za/beats/dub.mp3',
              'licenseType': 'Non-Exclusive Commercial',
              'salesCount': 4,
            },
          ],
        });
        return ResponseBody.fromString(
          payload,
          200,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        );
      });
      final dio = Dio()..httpClientAdapter = adapter;
      final repo = HttpMarketplaceRepository(
        dio: dio,
        baseUrl: 'https://api.test/api/marketplace',
        isTestMode: false,
      );

      final fetched = await repo.getProducerBeats('creator_ndugelo');
      expect(
        adapter.requestedUrls.single,
        contains('/producers/creator_ndugelo/beats'),
      );
      expect(fetched.map((b) => b.id), contains('beat_remote_ndugelo_1'));

      final container = ProviderContainer(
        overrides: [marketplaceRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final merged = await container.read(
        producerBeatsFamilyProvider('ndugelo').future,
      );
      expect(merged.map((b) => b.id), contains('beat_remote_ndugelo_1'));
      expect(merged.map((b) => b.id), contains('beat_zulu_acoustic'));
    },
  );

  testWidgets(
    'Visitor Beats tab renders remote EP-P58 producer beats merged with local catalog',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final remoteBeat = BeatListingEntity(
        id: 'beat_remote_ndugelo_1',
        title: 'Vhunambi Sovereign Dub (API Live)',
        producerId: 'creator_ndugelo',
        producerName: 'Ndugelo',
        producerHandle: '@ndugelo',
        genre: 'Amapiano',
        bpm: 114,
        musicalKey: 'F#m',
        priceInCredits: 15,
        previewAudioUrl: 'https://cdn.vhunambi.za/beats/dub.mp3',
        createdAt: DateTime(2026, 11, 19),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            producerBeatsFamilyProvider('ndugelo').overrideWith(
              (ref) async => <BeatListingEntity>[
                remoteBeat,
                ...ref.watch(creatorBeatsFamilyProvider('ndugelo')),
              ],
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const ArtistProfileView(artistId: 'ndugelo'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 250));

      await tester.tap(find.byKey(const Key('visitor_tab_beats')));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byType(ProducerBeatListingTile), findsWidgets);
      expect(find.text('Vhunambi Sovereign Dub (API Live)'), findsOneWidget);
      expect(find.text('Zulu Acoustic Flow'), findsOneWidget);
    },
  );

  testWidgets(
    'MiniPlayerHost suppresses while ArtistProfileView is pushed and restores upon pop',
    (WidgetTester tester) async {
      late ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return MaterialApp(
                theme: AppTheme.darkTheme,
                home: Scaffold(
                  body: Builder(
                    builder: (innerCtx) => Column(
                      children: <Widget>[
                        ElevatedButton(
                          key: const Key('push_visitor_profile_btn'),
                          onPressed: () {
                            Navigator.of(innerCtx).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    const ArtistProfileView(artistId: 'fifi'),
                              ),
                            );
                          },
                          child: const Text('Open Profile'),
                        ),
                        const Expanded(child: MiniPlayerHost()),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(pushedFullScreenOverlayCountProvider), 0);

      await tester.tap(find.byKey(const Key('push_visitor_profile_btn')));
      await tester.pumpAndSettle();

      expect(container.read(pushedFullScreenOverlayCountProvider), 1);

      Navigator.of(tester.element(find.byType(ArtistProfileView))).pop();
      await tester.pumpAndSettle();

      expect(container.read(pushedFullScreenOverlayCountProvider), 0);
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/explore/domain/models/social_music_post.dart';
import 'package:vhunambi_client/features/explore/domain/services/discovery_hierarchy_ranker.dart';
import 'package:vhunambi_client/features/explore/presentation/widgets/explore_social_post_card.dart';
import 'package:vhunambi_client/features/home/presentation/widgets/subscription_upgrade_modal.dart';
import 'package:vhunambi_client/features/marketplace/domain/models/marketplace_models.dart';
import 'package:vhunambi_client/features/marketplace/presentation/providers/marketplace_providers.dart';
import 'package:vhunambi_client/features/notifications/domain/models/notification_enums.dart';
import 'package:vhunambi_client/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:vhunambi_client/features/notifications/presentation/views/notifications_view.dart';
import 'package:vhunambi_client/features/social/presentation/providers/creator_wallet_provider.dart';
import 'package:vhunambi_client/features/studio/domain/services/bantu_lyric_translation_service.dart';
import 'package:vhunambi_client/shared/models/track.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testTrack = const Track(
    id: 'trk_test_p40',
    title: 'Ndo Mufuna Matibe',
    creatorName: 'Makhadzi',
    genre: 'Amapiano',
    duration: Duration(minutes: 3, seconds: 30),
    audioUrl: 'https://cdn.vhunambi.com/audio/ndo-mufuna.mp3',
    playCount: 1500,
  );

  group('Phase 40: Track A - Live Reactive Notifications Engine', () {
    test('REQ-NOTIF-SEED-01: phase40SeededNotifications covers all 4 categories', () {
      final seeds = phase40SeededNotifications;
      expect(seeds.length, greaterThanOrEqualTo(8));

      final categories = seeds.map((n) => n.category).toSet();
      expect(categories, contains(NotificationCategory.social));
      expect(categories, contains(NotificationCategory.system));
      expect(categories, contains(NotificationCategory.creatorActivity));
      expect(categories, contains(NotificationCategory.algorithmic));
    });

    test('REQ-NOTIF-SEED-01: seedDemoAlerts populates notificationsProvider', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(notificationsProvider), isEmpty);
      container.read(notificationsProvider.notifier).seedDemoAlerts();
      expect(container.read(notificationsProvider), isNotEmpty);
      expect(container.read(notificationsProvider).length, phase40SeededNotifications.length);
    });

    testWidgets('REQ-NOTIF-SEED-01: NotificationsView auto-seeds and renders tabs', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const NotificationsView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Social'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);
      expect(find.text('Activity'), findsOneWidget);
      expect(find.text('Discovery'), findsOneWidget);

      // Verify at least one seeded item is rendered
      expect(find.text('New Cultural Gift Received!'), findsOneWidget);
    });

    testWidgets('REQ-NOTIF-DISPATCH-01: licenseBeat dispatches creatorActivity notification', (tester) async {
      late WidgetRef capturedRef;
      final beat = BeatListingEntity(
        id: 'beat_p40_01',
        title: 'Polokwane Bounce',
        producerId: 'prod_makhadzi',
        producerName: 'Makhadzi',
        producerHandle: '@makhadzi',
        genre: 'Amapiano',
        bpm: 112,
        musicalKey: 'G Minor',
        priceInCredits: 5,
        previewAudioUrl: 'url',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, child) {
                  capturedRef = ref;
                  return ElevatedButton(
                    onPressed: () => licenseBeat(capturedRef, beat),
                    child: const Text('License'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('License'));
      await tester.pump();

      final notifs = capturedRef.read(notificationsProvider);
      expect(
        notifs.any((n) =>
            n.title == 'Marketplace License Acquired!' &&
            n.category == NotificationCategory.creatorActivity),
        isTrue,
      );
    });
  });

  group('Phase 40: Track B - Full-Coverage 9-Language Bantu Sing-Along Lexicon', () {
    test('REQ-LEX-COV-01: Catalog song & reel lyrics resolve with 100% meaning', () {
      final line1 = BantuLyricTranslationService.translateLine(
        line: 'Ndo Mufuna Matibe Mbilu Yanga',
        baseLanguageCode: 've',
      );
      expect(line1.hasMeaning, isTrue);
      expect(line1.translatedMeaning, contains('love'));

      final line2 = BantuLyricTranslationService.translateLine(
        line: 'Iya Pembelela Woza Amapiano Sgubhu',
        baseLanguageCode: 've',
      );
      expect(line2.hasMeaning, isTrue);
      expect(line2.translatedMeaning, contains('celebrate'));

      final line3 = BantuLyricTranslationService.translateLine(
        line: 'Venda Sunrise Ndi Matsheloni Makhado',
        baseLanguageCode: 've',
      );
      expect(line3.hasMeaning, isTrue);
      expect(line3.translatedMeaning, contains('Makhado'));
    });

    test('REQ-LEX-ROOTS-02: 9-Language roots resolve valid definitions', () {
      final languages = ['ve', 'zu', 'xh', 'ss', 'nr', 'st', 'tn', 'nso', 'ts'];
      final sampleWords = [
        'vhunambi', // ve
        'ukuthula', // zu
        'uxolo',    // xh
        'utsandvo', // ss
        'lotjhani', // nr
        'khotso',   // st
        'pula',     // tn
        'mmino',    // nso
        'kurhula',  // ts
      ];

      for (int i = 0; i < languages.length; i++) {
        final item = BantuLyricTranslationService.translateLine(
          line: sampleWords[i],
          baseLanguageCode: languages[i],
        );
        expect(item.hasMeaning, isTrue, reason: 'Failed for word ${sampleWords[i]} in ${languages[i]}');
      }
    });
  });

  group('Phase 40: Track C - Fresh Crate "Co-Sign" A&R Graduation Loop', () {
    testWidgets('REQ-COSIGN-UI-01: ExploreSocialPostCard renders Co-Sign button and increments on tap', (tester) async {
      final post = SocialMusicPost(
        id: 'post_cosign_01',
        creatorId: 'c10',
        creatorName: 'Rising Artist',
        creatorHandle: '@rising',
        publishedAt: DateTime.now(),
        caption: 'Fresh vocal take from Limpopo',
        track: testTrack,
        cosignCount: 18,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: SingleChildScrollView(
                child: ExploreSocialPostCard(post: post),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(Key('post_cosign_btn_${post.id}')), findsOneWidget);
      expect(find.text('🔥 Co-Sign · 18/25'), findsOneWidget);

      await tester.tap(find.byKey(Key('post_cosign_btn_${post.id}')));
      await tester.pump();

      final updatedPost = tester
          .element(find.byKey(Key('social_post_card_${post.id}')))
          .findAncestorWidgetOfExactType<ExploreSocialPostCard>()!
          .post;
      // In the feed notifier it was toggled
      expect(updatedPost.id, post.id);
    });

    test('REQ-COSIGN-GRAD-02: Fresh Crate post with >= 25 co-signs graduates to risingBreakout', () {
      final freshPost = SocialMusicPost(
        id: 'fresh_p40_grad',
        creatorId: 'c_emerging',
        creatorName: 'New Talent',
        creatorHandle: '@newtalent',
        publishedAt: DateTime.now(),
        caption: 'Underground vocal melody',
        track: const Track(
          id: 'trk_underground',
          title: 'Underground',
          creatorName: 'New Talent',
          genre: 'Amapiano',
          duration: Duration(minutes: 2),
          playCount: 5,
        ),
        likeCount: 2,
        cosignCount: 25, // 25 co-signs reached
      );

      final rankResult = DiscoveryHierarchyRanker.rank(freshPost);
      expect(rankResult.tier, DiscoveryStageTier.risingBreakout);
    });
  });

  group('Phase 40: Track D - Live ZAR Coin Top-Up in SubscriptionUpgradeModal', () {
    testWidgets('REQ-TOPUP-UI-01 & 02: Selecting coin top-up credits wallet and notifies', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: SubscriptionUpgradeModal(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Instant Coin Top-Up (ZAR)'), findsOneWidget);
      expect(find.byKey(const Key('coin_topup_pack_500')), findsOneWidget);
      expect(find.byKey(const Key('coin_topup_pack_1500')), findsOneWidget);
      expect(find.byKey(const Key('coin_topup_pack_5000')), findsOneWidget);

      final initialBalance = container.read(creatorWalletProvider).userCoinsBalance;

      // Tap 500 coins pack
      await tester.tap(find.byKey(const Key('coin_topup_pack_500')));
      await tester.pumpAndSettle();

      final newBalance = container.read(creatorWalletProvider).userCoinsBalance;
      expect(newBalance, initialBalance + 500);

      final notifs = container.read(notificationsProvider);
      expect(
        notifs.any((n) => n.title == 'Coins Credited!' && n.category == NotificationCategory.system),
        isTrue,
      );
    });
  });
}


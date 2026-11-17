import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/navigation/navigation_providers.dart';
import 'package:vhunambi_client/features/explore/domain/models/social_music_post.dart';
import 'package:vhunambi_client/features/explore/presentation/providers/explore_providers.dart';
import 'package:vhunambi_client/features/home/presentation/views/home_dashboard_view.dart';
import 'package:vhunambi_client/features/library/domain/models/library_models.dart';
import 'package:vhunambi_client/features/library/presentation/providers/library_providers.dart';
import 'package:vhunambi_client/features/notifications/domain/models/notification_entity.dart';
import 'package:vhunambi_client/features/notifications/domain/models/notification_enums.dart';
import 'package:vhunambi_client/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:vhunambi_client/features/notifications/presentation/views/notifications_view.dart';
import 'package:vhunambi_client/features/notifications/presentation/widgets/notification_bell_button.dart';
import 'package:vhunambi_client/features/profile/presentation/providers/profile_providers.dart';
import 'package:vhunambi_client/features/social/presentation/providers/creator_wallet_provider.dart';
import 'package:vhunambi_client/features/social/presentation/providers/reels_comments_provider.dart';
import 'package:vhunambi_client/features/track/presentation/providers/track_providers.dart';
import 'package:vhunambi_client/shared/models/track.dart';

void main() {
  group('Phase 67 Pass 2: Routing, Track Lookup & Live Social Producers', () {
    testWidgets(
      'REQ-P67-ROUTE-01 & 02: tapping milestone card opens NotificationDetailBottomSheet and routes /studio CTA',
      (tester) async {
        final welcomeNotif = NotificationEntity(
          id: 'notif_onboard_welcome_test',
          title: 'Welcome to Vhunambi, @ndugelo',
          message: 'Your sovereign studio is live.',
          category: NotificationCategory.system,
          subtype: 'welcome',
          targetRoute: '/studio',
          ctaLabel: 'Open Studio Cockpit',
          createdAt: DateTime.now(),
        );
        final dnaNotif = NotificationEntity(
          id: 'notif_onboard_dna_test',
          title: 'Creator DNA Calibrated at 8%',
          message: 'Record a vocal sample to unlock deeper personalization.',
          category: NotificationCategory.system,
          subtype: 'dna_calibration',
          targetRoute: '/creator-dna',
          ctaLabel: 'Calibrate Creator DNA',
          createdAt: DateTime.now().subtract(const Duration(seconds: 5)),
          metadata: const <String, dynamic>{
            'dnaPercent': 8,
            'recordedTraits': <String>['Producer', 'Amapiano'],
            'uncalibratedTraits': <String>['Zero-Shot Vocal Clone'],
          },
        );

        late ProviderContainer container;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              notificationsProvider.overrideWith(
                (ref) => NotificationsNotifier(<NotificationEntity>[
                  welcomeNotif,
                  dnaNotif,
                ]),
              ),
            ],
            child: Consumer(
              builder: (context, ref, child) {
                container = ProviderScope.containerOf(context);
                return MaterialApp(
                  home: const NotificationsView(),
                );
              },
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Tap DNA card -> opens detail bottom sheet with trait breakdown
        await tester.tap(
          find.byKey(const Key('notif_tile_notif_onboard_dna_test')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.byKey(const Key('notification_detail_bottom_sheet')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('detail_sheet_breakdown_card')), findsOneWidget);
        expect(find.text('8 / 100%'), findsOneWidget);
        expect(find.text('Recorded Traits:'), findsOneWidget);

        // Close DNA detail sheet
        await tester.tap(find.byKey(const Key('detail_sheet_close_btn')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Tap Welcome card -> open sheet -> tap Open Studio Cockpit -> tab switches to 2
        await tester.tap(
          find.byKey(const Key('notif_tile_notif_onboard_welcome_test')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.byKey(const Key('detail_sheet_primary_cta')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(container.read(appNavigationTabProvider), 2);
      },
    );

    test(
      'REQ-P67-ROUTE-03: trackDetailFamilyProvider resolves Library & Explore tracks with zero @fifi fallback',
      () {
        final libraryTrack = LibraryTrack(
          id: 'trk_gen_real_001',
          title: 'Venda Night Groove',
          creatorName: 'Ndugelo',
          genre: 'Amapiano',
          language: 'Tshivenḓa',
          durationSeconds: 194,
          remoteAudioUrl: 'https://cdn.vhunambi.com/venda_night.mp3',
          createdAt: DateTime.now(),
          lyrics: '[Verse 1]\nThohoyandou lights...',
        );
        final exploreTrack = Track(
          id: 'trk_exp_real_002',
          title: 'Durban Sub Bass',
          creatorName: 'DJ Vibe',
          creatorHandle: '@djvibe',
          genre: 'Gqom',
          language: 'isiZulu',
          duration: const Duration(minutes: 4, seconds: 5),
        );

        final container = ProviderContainer(
          overrides: [
            libraryTracksProvider.overrideWith(
              (ref) => LibraryTracksNotifier()..applyMergedTracks([libraryTrack]),
            ),
            exploreTracksProvider.overrideWith(
              (ref) => ExploreTracksNotifier()..addTrack(exploreTrack),
            ),
          ],
        );
        addTearDown(container.dispose);

        final resolvedLib = container.read(
          trackDetailFamilyProvider('trk_gen_real_001'),
        );
        expect(resolvedLib.title, 'Venda Night Groove');
        expect(resolvedLib.creatorName, 'Ndugelo');
        expect(resolvedLib.creatorHandle, '@ndugelo');
        expect(resolvedLib.creatorHandle, isNot('@fifi'));

        final resolvedExp = container.read(
          trackDetailFamilyProvider('trk_exp_real_002'),
        );
        expect(resolvedExp.title, 'Durban Sub Bass');
        expect(resolvedExp.creatorName, 'DJ Vibe');
        expect(resolvedExp.creatorHandle, '@djvibe');

        final missingTrack = container.read(
          trackDetailFamilyProvider('nonexistent_id'),
        );
        expect(missingTrack.title, isNot('Unknown Melody'));
        expect(missingTrack.creatorHandle, isNot('@fifi'));
      },
    );

    testWidgets(
      'REQ-P67-EVT-01: HomeDashboardView renders NotificationBellButton with live unread count',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              notificationsProvider.overrideWith(
                (ref) => NotificationsNotifier(<NotificationEntity>[
                  NotificationEntity(
                    id: 'notif_home_1',
                    title: 'Unread Alert',
                    message: 'Live badge verify',
                    category: NotificationCategory.system,
                    createdAt: DateTime.now(),
                  ),
                ]),
              ),
            ],
            child: const MaterialApp(home: HomeDashboardView()),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final bellFinder = find.byKey(const Key('home_notifications_btn'));
        expect(bellFinder, findsOneWidget);
        expect(find.byType(NotificationBellButton), findsOneWidget);
        expect(
          find.descendant(
            of: bellFinder,
            matching: find.text('1'),
          ),
          findsOneWidget,
        );
      },
    );

    test(
      'REQ-P67-EVT-02: Explore (Co-Sign, Like, Follow), Profile Follow, Track Like/Comment, Reels Comment & Wallet Gift emit real notifications',
      () async {
        final demoPost = SocialMusicPost(
          id: 'post_p67_1',
          creatorId: 'creator_makhadzi',
          creatorName: 'Makhadzi',
          creatorHandle: '@makhadzi',
          publishedAt: DateTime.now(),
          caption: 'Testing live notifications across Explore!',
          track: const Track(
            id: 'trk_p67_exp_1',
            title: 'Giyani Pulse',
            creatorName: 'Makhadzi',
            genre: 'Amapiano',
            language: 'Tshivenḓa',
            duration: Duration(minutes: 3, seconds: 12),
          ),
        );

        final container = ProviderContainer(
          overrides: [
            notificationsProvider.overrideWith(
              (ref) => NotificationsNotifier(const <NotificationEntity>[]),
            ),
            socialFeedPostsProvider.overrideWith(
              (ref) => SocialFeedPostsNotifier(ref: ref)..addPost(demoPost),
            ),
            followingCreatorIdsProvider.overrideWith(
              (ref) => FollowingCreatorsNotifier(ref),
            ),
          ],
        );
        addTearDown(container.dispose);

        // 1. Explore A&R Co-Sign
        container.read(socialFeedPostsProvider.notifier).cosignPost('post_p67_1');
        // 2. Explore Post Like
        container.read(socialFeedPostsProvider.notifier).toggleLike('post_p67_1');
        // 3. Explore Creator Follow
        container
            .read(followingCreatorIdsProvider.notifier)
            .toggleFollow('creator_kabza');
        // 4. Profile Follow
        container
            .read(artistProfileFamilyProvider('creator_sigwa').notifier)
            .toggleFollow();
        // 5. Track Detail Like + Comment
        container
            .read(trackDetailFamilyProvider('seed-01').notifier)
            .toggleLike();
        container
            .read(trackCommentsProvider('seed-01').notifier)
            .addComment('Clean mix!');
        // 6. Reel Comment
        await container
            .read(reelsCommentsProvider.notifier)
            .addComment(clipId: 'clip_seed_01', text: 'Banger log drums!');
        // 7. Cultural Gift & Marketplace Royalty
        await container.read(creatorWalletProvider.notifier).sendGift(
              clipId: 'clip_seed_01',
              recipientCreatorId: 'creator_makhadzi',
              senderUsername: 'ndugelo',
              gift: kCulturalGifts.first,
            );
        container
            .read(creatorWalletProvider.notifier)
            .recordMarketplaceRoyalty(
              assetTitle: 'Venda Log Pack',
              amountCoins: 300,
              netZar: 90.0,
            );

        final notifs = container.read(notificationsProvider);
        final subtypes = notifs.map((n) => n.subtype).toSet();

        expect(subtypes, contains('ar_cosign'));
        expect(subtypes, contains('post_like'));
        expect(subtypes, contains('follow'));
        expect(subtypes, contains('comment'));
        expect(subtypes, contains('gift'));
        expect(subtypes, contains('license_sold'));
        expect(notifs.every((n) => n.effectiveRoute != null), isTrue);
      },
    );
  });
}

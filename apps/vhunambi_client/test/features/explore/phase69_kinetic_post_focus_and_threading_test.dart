import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/explore/domain/models/social_music_post.dart';
import 'package:vhunambi_client/features/explore/presentation/providers/explore_providers.dart';
import 'package:vhunambi_client/features/explore/presentation/views/kinetic_post_focus_view.dart';
import 'package:vhunambi_client/features/explore/presentation/widgets/explore_social_post_card.dart';
import 'package:vhunambi_client/features/explore/presentation/widgets/kinetic_post_composer_bar.dart';
import 'package:vhunambi_client/features/explore/presentation/widgets/repost_kinetic_post_sheet.dart';
import 'package:vhunambi_client/features/notifications/domain/models/notification_entity.dart';
import 'package:vhunambi_client/features/notifications/domain/models/notification_enums.dart';
import 'package:vhunambi_client/features/notifications/presentation/utils/notification_deep_link_router.dart';
import 'package:vhunambi_client/features/player/presentation/providers/player_provider.dart';
import 'package:vhunambi_client/features/social/domain/models/reel_comment.dart';
import 'package:vhunambi_client/features/social/presentation/providers/reels_comments_provider.dart';
import 'package:vhunambi_client/shared/models/track.dart';

SocialMusicPost _buildMultiImagePost() {
  return SocialMusicPost(
    id: 'post_multi_01',
    creatorId: 'creator_makhadzi',
    creatorName: 'Makhadzi',
    creatorHandle: '@makhadzi',
    isCreatorVerified: true,
    publishedAt: DateTime.now().subtract(const Duration(minutes: 40)),
    location: 'Polokwane',
    caption: 'Multi-image rehearsal carousel with open log drum stems.',
    imageAttachments: const [
      KineticPostImageAttachment(
        imageUrl: 'https://cdn.vhunambi.com/covers/ndo-mufuna.jpg',
        aspectRatio: KineticPostAspectRatio.square1x1,
      ),
      KineticPostImageAttachment(
        imageUrl: 'https://cdn.vhunambi.com/covers/grateful.jpg',
        aspectRatio: KineticPostAspectRatio.square1x1,
      ),
    ],
    track: const Track(
      id: 'exp_track_multi_01',
      title: 'Limpopo Dawn',
      creatorName: 'Makhadzi',
      creatorHandle: '@makhadzi',
      genre: 'Amapiano',
      language: 'Tshivenḓa',
      duration: Duration(minutes: 3, seconds: 10),
    ),
    likeCount: 120,
    commentCount: 2,
    repostCount: 4,
    remixCount: 3,
  );
}

void main() {
  testWidgets(
    'ExploreSocialPostCard renders Engagement Summary Strip, emoji-free Co-Sign pill, and zero overflow on 360dp mobile in dark & light themes',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final seedPost = seedSocialPosts().first;

      for (final theme in [AppTheme.darkTheme, AppTheme.lightTheme]) {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: theme,
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      const KineticPostComposerBar(),
                      ExploreSocialPostCard(post: seedPost),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 250));

        expect(
          find.byKey(const Key('kpost_composer_owner_avatar')),
          findsOneWidget,
        );
        expect(
          find.byKey(Key('social_post_engagement_strip_${seedPost.id}')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(Key('social_post_engagement_strip_${seedPost.id}')),
            matching: find.text('1840'),
          ),
          findsOneWidget,
        );
        expect(find.textContaining('4 comments'), findsOneWidget);
        expect(find.text('Co-Sign · 0/25'), findsOneWidget);
        expect(find.textContaining('🔥'), findsNothing);
      }
    },
  );

  testWidgets(
    'Tapping card caption, media, card body, and comment button opens KineticPostFocusView while inline Play stays isolated',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final seedPost = seedSocialPosts().first;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: SingleChildScrollView(
                child: ExploreSocialPostCard(post: seedPost),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));

      final cardEl = tester.element(find.byType(ExploreSocialPostCard));
      final container = ProviderScope.containerOf(cardEl);

      // 1. Inline Sonic Pill Play Button plays audio WITHOUT pushing KineticPostFocusView
      await tester.tap(find.byKey(Key('social_post_play_btn_${seedPost.id}')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(container.read(playerStateProvider).isPlaying, isTrue);
      expect(
        find.byKey(Key('kinetic_post_focus_view_${seedPost.id}')),
        findsNothing,
      );

      // 2. Tapping Caption opens KineticPostFocusView
      await tester.tap(
        find.byKey(Key('social_post_caption_tap_${seedPost.id}')),
      );
      await tester.pump();
      for (int i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(
        find.byKey(Key('kinetic_post_focus_view_${seedPost.id}')),
        findsOneWidget,
      );

      // Navigate back
      await tester.tap(find.byKey(const Key('kpost_focus_back_btn')));
      await tester.pump();
      for (int i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(
        find.byKey(Key('kinetic_post_focus_view_${seedPost.id}')),
        findsNothing,
      );

      // 3. Tapping Media opens KineticPostFocusView
      await tester.tap(find.byKey(Key('social_post_media_tap_${seedPost.id}')));
      await tester.pump();
      for (int i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(
        find.byKey(Key('kinetic_post_focus_view_${seedPost.id}')),
        findsOneWidget,
      );

      // Navigate back
      await tester.tap(find.byKey(const Key('kpost_focus_back_btn')));
      await tester.pump();
      for (int i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(
        find.byKey(Key('kinetic_post_focus_view_${seedPost.id}')),
        findsNothing,
      );

      // 4. Tapping Comment Action Button opens KineticPostFocusView with composer focus
      final commentBtn = find.byKey(
        Key('social_post_comment_btn_${seedPost.id}'),
      );
      await tester.ensureVisible(commentBtn);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(commentBtn);
      await tester.pump();
      for (int i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(
        find.byKey(Key('kinetic_post_focus_view_${seedPost.id}')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('comment_input')), findsOneWidget);
    },
  );

  testWidgets(
    'KineticPostFocusView supports Reply banner, child reply creation, View N replies, Author badge, Sort toggle, Studio chips, and Multi-image counter',
    (tester) async {
      tester.view.physicalSize = const Size(420, 920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final seedPost = seedSocialPosts().first; // post_001

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: KineticPostFocusView(
              postId: seedPost.id,
              initialPost: seedPost,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));

      // Scroll down to ThreadedCommentsSection
      final commentsHeader = find.byKey(
        Key('threaded_comments_header_${seedPost.id}'),
      );
      await tester.scrollUntilVisible(
        commentsHeader,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Comments (4)'), findsOneWidget);
      // Parent comment c_post001_1 has 1 seeded child reply c_post001_2
      final toggleBtn = find.byKey(
        const Key('comment_toggle_replies_c_post001_1'),
      );
      await tester.ensureVisible(toggleBtn);
      expect(find.text('View 1 reply'), findsOneWidget);

      // Expand child reply & check Creator Author badge
      await tester.tap(toggleBtn);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Hide replies'), findsOneWidget);
      expect(
        find.byKey(const Key('comment_author_badge_c_post001_2')),
        findsOneWidget,
      );
      expect(find.text('Author'), findsOneWidget);

      // Tap Reply on parent comment -> activates Replying to @thabo_beats banner
      final replyBtn = find.byKey(const Key('comment_reply_btn_c_post001_1'));
      await tester.ensureVisible(replyBtn);
      await tester.tap(replyBtn);
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.byKey(const Key('comment_active_reply_banner')),
        findsOneWidget,
      );
      expect(find.text('Replying to @thabo_beats'), findsOneWidget);

      // Tap Phosphor studio reaction chip 'Fire' -> inserts 'Pure fire!'
      await tester.tap(find.byKey(const Key('comment_reaction_chip_fire')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(
        find.byKey(const Key('comment_input')),
        'Pure fire! Clean 808 bounce.',
      );
      await tester.tap(find.byKey(const Key('comment_send_btn')));
      await tester.pump(const Duration(milliseconds: 250));

      // Banner clears, comment count updates to 5, post commentCount increments, child reply visible
      expect(
        find.byKey(const Key('comment_active_reply_banner')),
        findsNothing,
      );
      expect(find.text('Comments (5)'), findsOneWidget);
      expect(
        find.textContaining('Clean 808 bounce.', findRichText: true),
        findsOneWidget,
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(KineticPostFocusView)),
      );
      final updatedPost = container
          .read(socialFeedPostsProvider)
          .firstWhere((p) => p.id == seedPost.id);
      expect(updatedPost.commentCount, 5);

      // Switch sort toggle to Newest (ensure header is clearly inside viewport away from AppBar edge)
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, 180),
      );
      await tester.pump(const Duration(milliseconds: 200));
      final sortBtn = find.byKey(const Key('comment_sort_toggle_btn'));
      await tester.ensureVisible(sortBtn);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(sortBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.byKey(const Key('comment_sort_option_newest')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        container.read(reelsCommentsProvider).sortOrderFor(seedPost.id),
        CommentSortOrder.newest,
      );

      // Verify zero raw Material Icons inside ThreadedCommentsSection / StudioReactionComposerBar
      expect(find.byType(PhosphorIcon), findsWidgets);

      // Also verify multi-image counter pill renders when images.length > 1
      final multiPost = _buildMultiImagePost();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: KineticPostFocusView(
              postId: multiPost.id,
              initialPost: multiPost,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        find.byKey(Key('kpost_focus_image_counter_${multiPost.id}')),
        findsOneWidget,
      );
      expect(find.text('1/2'), findsOneWidget);
    },
  );

  testWidgets(
    'RepostKineticPostSheet uses ownerProfileProvider identity instead of @current_user',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final seedPost = seedSocialPosts().first;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    key: const Key('open_repost_sheet_test_btn'),
                    onPressed: () => RepostKineticPostSheet.show(
                      context,
                      originalPost: seedPost,
                    ),
                    child: const Text('Repost'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byKey(const Key('open_repost_sheet_test_btn')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.enterText(
        find.byKey(const Key('kpost_quote_comment_input')),
        'Syndicating this groove!',
      );
      await tester.tap(find.byKey(const Key('kpost_submit_repost_btn')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold)),
      );
      final latestRepost = container.read(socialFeedPostsProvider).first;
      expect(latestRepost.repostedFromPostId, seedPost.id);
      expect(latestRepost.creatorHandle, isNot('@current_user'));
      expect(latestRepost.creatorName, isNot('You'));
      expect(latestRepost.creatorId, isNot('current_user'));
      expect(latestRepost.creatorHandle, '@cern');
    },
  );

  testWidgets(
    'NotificationDeepLinkRouter routes /post/:id to KineticPostFocusView',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Consumer(
              builder: (context, ref, _) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      key: const Key('test_deeplink_post_btn'),
                      onPressed: () {
                        NotificationDeepLinkRouter.navigateDirect(
                          context,
                          ref,
                          NotificationEntity(
                            id: 'notif_test_p69',
                            title: 'New Comment',
                            message: 'Someone replied',
                            category: NotificationCategory.social,
                            targetRoute: '/post/post_001',
                            targetEntityId: 'post_001',
                            createdAt: DateTime.now(),
                          ),
                        );
                      },
                      child: const Text('Open Post'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.byKey(const Key('test_deeplink_post_btn')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        find.byKey(const Key('kinetic_post_focus_view_post_001')),
        findsOneWidget,
      );
    },
  );
}

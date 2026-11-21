import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/navigation/profile_navigation_helper.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/core/theme/post_chromatic_palette_resolver.dart';
import 'package:vhunambi_client/features/explore/domain/models/social_music_post.dart';
import 'package:vhunambi_client/features/explore/presentation/providers/explore_providers.dart';
import 'package:vhunambi_client/features/explore/presentation/views/kinetic_post_focus_view.dart';
import 'package:vhunambi_client/features/explore/presentation/widgets/create_kinetic_post_sheet.dart';
import 'package:vhunambi_client/features/onboarding/presentation/views/splash_view.dart';
import 'package:vhunambi_client/features/profile/presentation/views/artist_profile_view.dart';
import 'package:vhunambi_client/features/profile/presentation/views/owner_profile_view.dart';
import 'package:vhunambi_client/features/social/domain/models/kinetic_reaction.dart';
import 'package:vhunambi_client/features/social/domain/models/sovereign_sticker_pack.dart';
import 'package:vhunambi_client/features/social/presentation/providers/reels_comments_provider.dart';
import 'package:vhunambi_client/shared/models/track.dart';

SocialMusicPost _buildTestPost({
  String id = 'post_p73_01',
  int likeCount = 1840,
  bool isLikedByMe = false,
  String? mood = 'amapiano_sunset',
  String? coverUrl = 'https://cdn.vhunambi.com/covers/ndo-mufuna.jpg',
  bool withAudio = true,
  String creatorId = 'creator_makhadzi',
  String creatorHandle = '@makhadzi',
}) {
  return SocialMusicPost(
    id: id,
    creatorId: creatorId,
    creatorName: creatorId == 'creator_cern' ? 'Cern' : 'Makhadzi',
    creatorHandle: creatorHandle,
    isCreatorVerified: true,
    publishedAt: DateTime(2026, 11, 21, 2, 0),
    location: 'Polokwane / Limpopo',
    caption: 'Testing Phase 73 chromatic world and multi-reactions.',
    track: Track(
      id: 'trk_p73_01',
      title: 'Limpopo Log Drum Session',
      creatorName: creatorId == 'creator_cern' ? 'Cern' : 'Makhadzi',
      creatorHandle: creatorHandle,
      genre: 'Amapiano',
      mood: mood,
      coverUrl: coverUrl,
      audioUrl: withAudio ? 'https://cdn.vhunambi.com/audio/session.mp3' : null,
      duration: const Duration(minutes: 3, seconds: 15),
    ),
    audioAttachment: withAudio
        ? KineticPostAudioAttachment(
            sourceType: KineticAudioSourceType.librarySong,
            clipStartSec: 12,
            clipDurationSec: 30,
            originalCreatorId: creatorId,
            originalCreatorHandle: creatorHandle,
          )
        : null,
    likeCount: likeCount,
    isLikedByMe: isLikedByMe,
    commentCount: 0,
    repostCount: 0,
    remixCount: 3,
  );
}

void main() {
  group('Phase 73: Focus v2, 3-Tier Chromatics, Multi-Reactions, GIFs & Hygiene', () {
    testWidgets('Global AppTheme purges bright brandPrimary focus rectangles', (
      tester,
    ) async {
      for (final theme in [AppTheme.darkTheme, AppTheme.lightTheme]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: const Scaffold(body: TextField()),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));

        final border = theme.inputDecorationTheme.focusedBorder;
        expect(border, isA<OutlineInputBorder>());
        final outline = border! as OutlineInputBorder;
        expect(
          outline.borderSide.color.toARGB32(),
          isNot(AppColors.brandPrimary.toARGB32()),
        );
        expect(outline.borderSide.width, 1.0);
      }
    });

    test('3-Tier PostChromaticPaletteResolver tiers & WCAG AA lightness clamping', () async {
      PostChromaticPaletteResolver.clearCache();

      // Tier 1: mood + artwork when audio attached
      final t1Dark = await PostChromaticPaletteResolver.resolveAsync(
        brightness: Brightness.dark,
        rawMood: 'chill_lounge',
        artworkUrl: 'https://cdn.vhunambi.com/covers/ndo-mufuna.jpg',
        hasAudioAttachment: true,
      );
      expect(t1Dark.tier, ChromaticSynthesisTier.moodAndArtwork);
      expect(
        HSLColor.fromColor(t1Dark.accent).lightness,
        greaterThanOrEqualTo(0.615),
      );

      final t1Light = await PostChromaticPaletteResolver.resolveAsync(
        brightness: Brightness.light,
        rawMood: 'chill_lounge',
        artworkUrl: 'https://cdn.vhunambi.com/covers/ndo-mufuna.jpg',
        hasAudioAttachment: true,
      );
      expect(t1Light.tier, ChromaticSynthesisTier.moodAndArtwork);
      expect(
        HSLColor.fromColor(t1Light.accent).lightness,
        lessThanOrEqualTo(0.425),
      );

      // Tier 2: artwork-only when no mood / audio
      final t2 = await PostChromaticPaletteResolver.resolveAsync(
        brightness: Brightness.dark,
        rawMood: null,
        artworkUrl: 'https://cdn.vhunambi.com/covers/unique-cover.jpg',
        hasAudioAttachment: false,
      );
      expect(t2.tier, ChromaticSynthesisTier.artworkOnly);

      // Tier 3: themeDefault when neither mood nor artwork exists
      final t3 = await PostChromaticPaletteResolver.resolveAsync(
        brightness: Brightness.light,
        rawMood: null,
        artworkUrl: null,
        hasAudioAttachment: false,
      );
      expect(t3.tier, ChromaticSynthesisTier.themeDefault);
    });

    testWidgets(
      'KineticPostFocusView renders cleanly on 320dp & 360dp Dark/Light without overflow or wrapped labels',
      (tester) async {
        final post = _buildTestPost();

        for (final width in [320.0, 360.0]) {
          tester.view.physicalSize = Size(width, 780);
          tester.view.devicePixelRatio = 1.0;

          for (final theme in [AppTheme.darkTheme, AppTheme.lightTheme]) {
            await tester.pumpWidget(
              ProviderScope(
                child: MaterialApp(
                  theme: theme,
                  home: KineticPostFocusView(postId: post.id, initialPost: post),
                ),
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 50));

            expect(tester.takeException(), isNull);
            expect(find.byKey(const Key('kpost_focus_ambient_backdrop')), findsOneWidget);
            expect(find.byKey(const Key('kpost_focus_summary_strip')), findsOneWidget);
            expect(find.text('0 Reposts'), findsOneWidget);
            expect(find.text('Like'), findsOneWidget);
            expect(find.text('Comment'), findsOneWidget);
            expect(find.text('Repost'), findsOneWidget);
            expect(find.text('Remix'), findsOneWidget);

            for (final label in ['Like', 'Comment', 'Repost', 'Remix']) {
              final textWidget = tester.widget<Text>(find.text(label));
              expect(textWidget.maxLines, 1);
              expect(textWidget.softWrap, isFalse);
            }
          }
        }
        tester.view.reset();
      },
    );

    testWidgets(
      'Long-press ReactionTrayOverlay applies Fire reaction and preserves legacy 1,840 -> 1,841 count',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final seededPost = _buildTestPost(id: 'post_react_legacy', likeCount: 1840);
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.read(socialFeedPostsProvider.notifier).addPost(seededPost);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: KineticPostFocusView(
                postId: seededPost.id,
                initialPost: seededPost,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        final likeBtn = find.byKey(Key('kpost_focus_like_btn_${seededPost.id}'));
        await tester.longPress(likeBtn);
        await tester.pump(const Duration(milliseconds: 220));

        expect(find.byKey(const Key('reaction_tray_overlay')), findsOneWidget);
        expect(find.byKey(const Key('reaction_tray_item_fire')), findsOneWidget);

        await tester.tap(find.byKey(const Key('reaction_tray_item_fire')));
        await tester.pump(const Duration(milliseconds: 50));

        final updatedPost = container
            .read(socialFeedPostsProvider)
            .firstWhere((p) => p.id == seededPost.id);
        expect(updatedPost.likeCount, 1841);
        expect(updatedPost.totalReactionCount, 1841);
        expect(updatedPost.myReaction, KineticReactionType.fire);
        expect(updatedPost.reactionCounts[KineticReactionType.love], 1840);
        expect(updatedPost.reactionCounts[KineticReactionType.fire], 1);
        expect(find.text('1841 Reactions'), findsOneWidget);
        expect(
          find.descendant(
            of: likeBtn,
            matching: find.text('Fire'),
          ),
          findsOneWidget,
        );

        // Switch reaction to Wow -> count remains 1841 without losing legacy count
        container
            .read(socialFeedPostsProvider.notifier)
            .reactToPost(seededPost.id, KineticReactionType.wow);
        await tester.pump();
        final switched = container
            .read(socialFeedPostsProvider)
            .firstWhere((p) => p.id == seededPost.id);
        expect(switched.totalReactionCount, 1841);
        expect(switched.myReaction, KineticReactionType.wow);
        expect(switched.reactionCounts[KineticReactionType.fire], isNull);

        // Toggle Wow off -> returns to legacy baseline 1840
        container
            .read(socialFeedPostsProvider.notifier)
            .reactToPost(seededPost.id, KineticReactionType.wow);
        await tester.pump();
        final cleared = container
            .read(socialFeedPostsProvider)
            .firstWhere((p) => p.id == seededPost.id);
        expect(cleared.totalReactionCount, 1840);
        expect(cleared.myReaction, isNull);
      },
    );

    testWidgets(
      'Comment composer allows Sovereign Sticker and GIF selection + media-only posting',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final post = _buildTestPost(id: 'post_media_comment');
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.read(socialFeedPostsProvider.notifier).addPost(post);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: KineticPostFocusView(postId: post.id, initialPost: post),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Open GIF & Sticker picker
        await tester.tap(find.byKey(const Key('comment_media_picker_btn')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byKey(const Key('gif_sticker_picker_sheet')), findsOneWidget);

        // Pick bundled Sovereign Sticker (offline-safe, zero Unicode emojis)
        final stickerId = SovereignStickerPack.all.first.id;
        final stickerFinder = find.byKey(Key('sticker_option_$stickerId'));
        await tester.ensureVisible(stickerFinder);
        await tester.pump();
        await tester.tap(stickerFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byKey(const Key('composer_pending_media_chip')), findsOneWidget);

        // Submit sticker-only comment without requiring text
        await tester.tap(find.byKey(const Key('comment_send_btn')));
        await tester.pump(const Duration(milliseconds: 100));

        final comments = container.read(clipCommentsFamilyProvider(post.id));
        expect(comments, isNotEmpty);
        expect(comments.first.stickerId, stickerId);
        expect(find.byKey(Key('comment_sticker_media_${comments.first.id}')), findsOneWidget);

        // Verify GIF tab loads offline fallback catalog & attaches cleanly
        await tester.tap(find.byKey(const Key('comment_media_picker_btn')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.byKey(const Key('picker_tab_gifs')));
        await tester.pump(const Duration(milliseconds: 100));
        final gifFinder = find.byKey(const Key('gif_option_curated_groove_01'));
        expect(gifFinder, findsOneWidget);
        await tester.ensureVisible(gifFinder);
        await tester.pump();
        await tester.tap(gifFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.byKey(const Key('comment_send_btn')));
        await tester.pump(const Duration(milliseconds: 100));

        final afterGif = container.read(clipCommentsFamilyProvider(post.id));
        expect(afterGif.first.gifUrl, isNotNull);
        expect(find.byKey(Key('comment_gif_media_${afterGif.first.id}')), findsOneWidget);
      },
    );

    testWidgets(
      'navigateToCreatorProfile routes own handle/ID to OwnerProfileView & others to ArtistProfileView',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        late WidgetRef capturedRef;
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: Consumer(
                builder: (context, ref, _) {
                  capturedRef = ref;
                  return Scaffold(
                    body: Column(
                      children: [
                        TextButton(
                          key: const Key('nav_self_btn'),
                          onPressed: () => navigateToCreatorProfile(
                            context,
                            ref,
                            creatorId: 'creator_cern',
                            creatorHandle: '@cern',
                          ),
                          child: const Text('Self'),
                        ),
                        TextButton(
                          key: const Key('nav_visitor_btn'),
                          onPressed: () => navigateToCreatorProfile(
                            context,
                            ref,
                            creatorId: 'creator_makhadzi',
                            creatorHandle: '@makhadzi',
                          ),
                          child: const Text('Visitor'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pump();

        expect(
          isOwnedByActiveUser(
            capturedRef,
            creatorId: 'creator_cern',
            creatorHandle: '@cern',
          ),
          isTrue,
        );
        expect(
          isOwnedByActiveUser(
            capturedRef,
            creatorId: 'creator_makhadzi',
            creatorHandle: '@makhadzi',
          ),
          isFalse,
        );

        await tester.tap(find.byKey(const Key('nav_self_btn')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.byType(OwnerProfileView), findsOneWidget);

        Navigator.of(tester.element(find.byType(OwnerProfileView))).pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        await tester.tap(find.byKey(const Key('nav_visitor_btn')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.byType(ArtistProfileView), findsOneWidget);
      },
    );

    testWidgets(
      'SplashView keeps isSplashActiveProvider true during intro so MiniPlayer stays hidden',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: SplashView(duration: Duration(milliseconds: 800)),
            ),
          ),
        );
        expect(container.read(isSplashActiveProvider), isTrue);
        await tester.pump(const Duration(milliseconds: 300));
        expect(container.read(isSplashActiveProvider), isTrue);
      },
    );

    testWidgets(
      'CreateKineticPostSheet propagates aspect ratio to existing images & disables at 4/4 without error snackbar',
      (tester) async {
        tester.view.physicalSize = const Size(390, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const Scaffold(body: CreateKineticPostSheet()),
            ),
          ),
        );
        await tester.pump();

        // Add 4 photos via mock picker
        final addBtn = find.byKey(const Key('kpost_upload_photo_btn'));
        for (var i = 0; i < 4; i++) {
          await tester.ensureVisible(addBtn);
          await tester.pump();
          await tester.tap(addBtn);
          await tester.pump(const Duration(milliseconds: 30));
        }

        // Buttons cleanly disabled & badge appears with zero error snackbar
        expect(find.byKey(const Key('kpost_max_images_badge')), findsOneWidget);
        expect(
          find.textContaining('Maximum 4 images allowed'),
          findsNothing,
        );

        // Toggle aspect ratio to 16:9 Wide after attaching images and publish
        final wideBtn = find.text(KineticPostAspectRatio.landscape16x9.label);
        await tester.ensureVisible(wideBtn);
        await tester.pump();
        await tester.tap(wideBtn);
        await tester.pump();

        final publishBtn = find.byKey(const Key('kpost_publish_submit_btn'));
        await tester.ensureVisible(publishBtn);
        await tester.pump();
        await tester.tap(publishBtn);
        await tester.pump(const Duration(milliseconds: 100));

        final latestPost = container.read(socialFeedPostsProvider).first;
        expect(latestPost.allImageAttachments.length, 4);
        for (final img in latestPost.allImageAttachments) {
          expect(img.aspectRatio, KineticPostAspectRatio.landscape16x9);
        }
      },
    );

    test('RecentSearchesNotifier starts cleanly empty when storage is fresh', () {
      final notifier = RecentSearchesNotifier();
      expect(notifier.state, isEmpty);
    });
  });
}

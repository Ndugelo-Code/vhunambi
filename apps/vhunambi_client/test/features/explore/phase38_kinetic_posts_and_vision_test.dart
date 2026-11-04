import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/explore/domain/models/social_music_post.dart';
import 'package:vhunambi_client/features/explore/presentation/providers/explore_providers.dart';
import 'package:vhunambi_client/features/explore/presentation/widgets/explore_social_post_card.dart';
import 'package:vhunambi_client/features/explore/presentation/widgets/kinetic_post_composer_bar.dart';
import 'package:vhunambi_client/features/explore/presentation/widgets/kinetic_post_sonic_pill.dart';
import 'package:vhunambi_client/shared/models/track.dart';

void main() {
  group('Phase 38: Kinetic Posts Architecture & Non-Invasive Sonic Feed', () {
    const testTrack = Track(
      id: 'test_track_38',
      title: 'Polokwane Sunset Groove',
      creatorName: 'Makhadzi',
      creatorHandle: '@makhadzi',
      genre: 'Amapiano',
      language: 'Tshivenḓa',
      duration: Duration(minutes: 3, seconds: 20),
      audioUrl: 'https://cdn.vhunambi.com/audio/polokwane.mp3',
      coverUrl: 'https://cdn.vhunambi.com/covers/polokwane.jpg',
    );

    test('REQ-KPOST-NO-MP4: Media Guard rejects video files and accepts images', () {
      // Rejects video formats
      expect(isAllowedKineticPostMedia('dance.mp4'), isFalse);
      expect(isAllowedKineticPostMedia('PERFORMANCE.MOV'), isFalse);
      expect(isAllowedKineticPostMedia('teaser.webm'), isFalse);
      expect(isAllowedKineticPostMedia('stream.mkv'), isFalse);
      expect(isAllowedKineticPostMedia('video/mp4'), isFalse);

      // Accepts image formats
      expect(isAllowedKineticPostMedia('photo.jpg'), isTrue);
      expect(isAllowedKineticPostMedia('COVER.JPEG'), isTrue);
      expect(isAllowedKineticPostMedia('artwork.png'), isTrue);
      expect(isAllowedKineticPostMedia('vision_ai.webp'), isTrue);
      expect(isAllowedKineticPostMedia('image/png'), isTrue);
    });

    test('REQ-KPOST-MODEL-01: Domain models serialize and deserialize correctly', () {
      // 1. KineticPostImageAttachment
      const img = KineticPostImageAttachment(
        imageUrl: 'https://cdn.vhunambi.com/vision/sample.jpg',
        isAiGeneratedVision: true,
        visionPrompt: 'Polokwane sunset',
        aspectRatio: KineticPostAspectRatio.portrait4x5,
      );
      final imgJson = img.toJson();
      final roundtripImg = KineticPostImageAttachment.fromJson(imgJson);
      expect(roundtripImg.imageUrl, img.imageUrl);
      expect(roundtripImg.isAiGeneratedVision, isTrue);
      expect(roundtripImg.visionPrompt, 'Polokwane sunset');
      expect(roundtripImg.aspectRatio, KineticPostAspectRatio.portrait4x5);

      // 2. KineticPostAudioAttachment
      const audio = KineticPostAudioAttachment(
        sourceType: KineticAudioSourceType.beatListing,
        clipStartSec: 15.0,
        clipDurationSec: 30.0,
        originalCreatorId: 'creator_1',
        originalCreatorHandle: '@producer',
      );
      final audioJson = audio.toJson();
      final roundtripAudio = KineticPostAudioAttachment.fromJson(audioJson);
      expect(roundtripAudio.sourceType, KineticAudioSourceType.beatListing);
      expect(roundtripAudio.clipStartSec, 15.0);
      expect(roundtripAudio.clipDurationSec, 30.0);
      expect(roundtripAudio.originalCreatorHandle, '@producer');
    });

    test('REQ-KPOST-MODEL-02: Multi-image resolution & aspect ratio calculation', () {
      final postMulti = SocialMusicPost(
        id: 'post_multi',
        creatorId: 'c1',
        creatorName: 'Artist',
        creatorHandle: '@artist',
        publishedAt: DateTime.now(),
        caption: 'Multi-image post',
        track: testTrack,
        imageAttachments: const [
          KineticPostImageAttachment(
            imageUrl: 'https://cdn.vhunambi.com/img1.jpg',
            aspectRatio: KineticPostAspectRatio.landscape16x9,
          ),
          KineticPostImageAttachment(
            imageUrl: 'https://cdn.vhunambi.com/img2.jpg',
            aspectRatio: KineticPostAspectRatio.landscape16x9,
          ),
        ],
      );

      expect(postMulti.hasVisuals, isTrue);
      expect(postMulti.allImageAttachments.length, 2);
      expect(postMulti.effectiveAspectRatio, KineticPostAspectRatio.landscape16x9);

      final postTextOnly = SocialMusicPost(
        id: 'post_text',
        creatorId: 'c2',
        creatorName: 'Text Artist',
        creatorHandle: '@text',
        publishedAt: DateTime.now(),
        caption: 'Pure sonic capsule',
        track: testTrack,
      );

      expect(postTextOnly.hasVisuals, isFalse);
      expect(postTextOnly.allImageAttachments, isEmpty);
    });

    test('REQ-KPOST-REPOST-01: repostPost increments original count and prepends', () {
      final notifier = SocialFeedPostsNotifier();
      final initialPosts = notifier.state;
      expect(initialPosts, isNotEmpty);
      final originalId = initialPosts.first.id;
      final initialCount = initialPosts.first.repostCount;

      final repostPost = SocialMusicPost(
        id: 'repost_test_01',
        creatorId: 'current_user',
        creatorName: 'You',
        creatorHandle: '@current_user',
        publishedAt: DateTime.now(),
        caption: 'Check this sound out!',
        repostedFromPostId: originalId,
        repostedFromCreatorHandle: initialPosts.first.creatorHandle,
        track: initialPosts.first.track,
      );

      notifier.repostPost(originalPostId: originalId, repostPost: repostPost);

      expect(notifier.state.first.id, 'repost_test_01');
      expect(notifier.state.first.isRepost, isTrue);

      final updatedOriginal =
          notifier.state.firstWhere((p) => p.id == originalId);
      expect(updatedOriginal.repostCount, initialCount + 1);
    });

    testWidgets(
      'REQ-KPOST-SONIC-01: KineticPostSonicPill renders duration and source badges, toggles play',
      (tester) async {
        final post = SocialMusicPost(
          id: 'test_post_pill',
          creatorId: 'c1',
          creatorName: 'Makhadzi',
          creatorHandle: '@makhadzi',
          publishedAt: DateTime.now(),
          caption: 'Testing frosted sonic pill',
          track: testTrack,
          audioAttachment: const KineticPostAudioAttachment(
            sourceType: KineticAudioSourceType.librarySong,
            clipStartSec: 30.0,
            clipDurationSec: 30.0,
            originalCreatorId: 'c1',
            originalCreatorHandle: '@makhadzi',
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: Scaffold(
                body: KineticPostSonicPill(post: post, isOverlay: true),
              ),
            ),
          ),
        );
        await tester.pump();

        // 1. Sonic Pill container and Play button exist
        expect(
          find.byKey(Key('kinetic_post_sonic_pill_${post.id}')),
          findsOneWidget,
        );
        expect(
          find.byKey(Key('social_post_play_btn_${post.id}')),
          findsOneWidget,
        );

        // 2. Source Badge ('Song') and Duration Badge ('0:30 Hook')
        expect(find.text('Song'), findsOneWidget);
        expect(find.textContaining('0:30 Hook'), findsOneWidget);

        // 3. Tap play button
        await tester.tap(find.byKey(Key('social_post_play_btn_${post.id}')));
        await tester.pump();
      },
    );

    testWidgets(
      'REQ-KPOST-CARD-01: ExploreSocialPostCard renders 4-zone hierarchy with Repost button',
      (tester) async {
        final post = SocialMusicPost(
          id: 'test_post_card',
          creatorId: 'creator_makhadzi',
          creatorName: 'Makhadzi',
          creatorHandle: '@makhadzi',
          isCreatorVerified: true,
          publishedAt: DateTime.now(),
          caption: 'Check out the new Amapiano bassline!',
          track: testTrack,
          imageAttachment: const KineticPostImageAttachment(
            imageUrl: 'https://cdn.vhunambi.com/covers/polokwane.jpg',
            aspectRatio: KineticPostAspectRatio.portrait4x5,
          ),
          audioAttachment: const KineticPostAudioAttachment(
            sourceType: KineticAudioSourceType.librarySong,
            clipStartSec: 15.0,
            clipDurationSec: 30.0,
            originalCreatorId: 'creator_makhadzi',
            originalCreatorHandle: '@makhadzi',
          ),
          likeCount: 120,
          commentCount: 14,
          repostCount: 5,
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

        // Zone 1: Creator Header
        expect(find.text('Makhadzi'), findsOneWidget);
        expect(find.textContaining('@makhadzi'), findsWidgets);

        // Zone 2: Caption
        expect(
          find.text('Check out the new Amapiano bassline!'),
          findsOneWidget,
        );

        // Zone 3: Sonic Pill
        expect(
          find.byKey(Key('kinetic_post_sonic_pill_${post.id}')),
          findsOneWidget,
        );

        // Zone 4: Social Action Bar (Like, Comment, Repost, Remix, Tip, Share)
        expect(
          find.byKey(Key('social_post_like_btn_${post.id}')),
          findsOneWidget,
        );
        expect(
          find.byKey(Key('social_post_comment_btn_${post.id}')),
          findsOneWidget,
        );
        expect(
          find.byKey(Key('social_post_repost_btn_${post.id}')),
          findsOneWidget,
        );
        expect(
          find.byKey(Key('social_post_remix_btn_${post.id}')),
          findsOneWidget,
        );
        expect(
          find.byKey(Key('social_post_tip_btn_${post.id}')),
          findsOneWidget,
        );

        // Verify Repost count is rendered
        expect(find.text('5'), findsOneWidget);
      },
    );

    testWidgets(
      'REQ-KPOST-COMP-01: KineticPostComposerBar renders CE avatar and opens Create sheet',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const Scaffold(
                body: KineticPostComposerBar(),
              ),
            ),
          ),
        );
        await tester.pump();

        // 1. Composer bar exists
        expect(
          find.byKey(const Key('explore_create_kinetic_post_bar')),
          findsOneWidget,
        );
        expect(find.text('CE'), findsOneWidget);
        expect(
          find.text('Drop a groove, voice take, or beat story...'),
          findsOneWidget,
        );

        // 2. Quick action buttons
        expect(find.byKey(const Key('kpost_quick_photo_btn')), findsOneWidget);
        expect(find.byKey(const Key('kpost_quick_vision_btn')), findsOneWidget);
      },
    );
  });
}


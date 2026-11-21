import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/navigation/navigation_providers.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/content_studio_preset.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/lyric_word_timestamp.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/song_metadata_dna.dart';
import 'package:vhunambi_client/features/content_studio/domain/utils/lyric_karaoke_sanitizer.dart';
import 'package:vhunambi_client/features/content_studio/presentation/views/kinetic_reel_studio_view.dart';
import 'package:vhunambi_client/features/content_studio/presentation/widgets/reel_audio_picker_sheet.dart';
import 'package:vhunambi_client/features/explore/presentation/providers/explore_providers.dart';
import 'package:vhunambi_client/features/social/domain/models/kinetic_reaction.dart';
import 'package:vhunambi_client/features/social/domain/models/published_clip.dart';
import 'package:vhunambi_client/features/social/domain/models/sovereign_sticker_pack.dart';
import 'package:vhunambi_client/features/social/presentation/providers/social_feed_provider.dart';
import 'package:vhunambi_client/features/social/presentation/widgets/kinetic_reels_modal.dart';
import 'package:vhunambi_client/features/social/presentation/widgets/trending_reels_shelf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('Phase 74 LyricKaraokeSanitizer & PublishedClip Schema', () {
    test('strips structural brackets, studio cues, and metadata headers', () {
      const raw = '''
Title: Makhado Sunrise
Genre: Amapiano
[Intro]
[Crisp soft shakers, airy synth pads]
Woza (x2) Vhunambi (Chorus)
[Bridge]
Ndi mufunwa tonight
''';
      final cleaned = LyricKaraokeSanitizer.cleanLyricTextForKaraoke(raw);
      expect(cleaned, 'Woza Vhunambi Ndi mufunwa tonight');

      final dna = SongMetadataDna.fromTrackInfo(
        id: 'trk_clean_1',
        title: 'Makhado Sunrise',
        genre: 'Amapiano',
        language: 'Tshivenḓa',
        durationSec: 120,
        lyrics: raw,
      );
      expect(
        dna.alignment.map((e) => e.word).toList(),
        <String>['Woza', 'Vhunambi', 'Ndi', 'mufunwa', 'tonight'],
      );
    });

    test('sanitizeAlignment removes legacy multi-word bracket tokens', () {
      final sanitized = LyricKaraokeSanitizer.sanitizeAlignment(
        const <LyricWordTimestamp>[
          LyricWordTimestamp(word: '[Crisp', start: 0.0, end: 0.4),
          LyricWordTimestamp(word: 'soft', start: 0.4, end: 0.8),
          LyricWordTimestamp(word: 'shakers]', start: 0.8, end: 1.2),
          LyricWordTimestamp(word: 'Makhado', start: 1.2, end: 1.8),
          LyricWordTimestamp(word: 'Groove', start: 1.8, end: 2.4),
        ],
      );
      expect(
        sanitized.map((w) => w.word).toList(),
        <String>['Makhado', 'Groove'],
      );
    });

    test('DurationPreset includes 60s and 90s presets', () {
      expect(DurationPreset.reel60s.targetSeconds, 60);
      expect(DurationPreset.reel90s.targetSeconds, 90);
    });
  });

  group('Phase 74 KineticReelStudioView 4-Stage Creation Flow', () {
    testWidgets(
      'launches from + Post Reel card, suppresses MiniPlayer, cycles tools, and defaults Explore share to false',
      (tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: TrendingReelsShelf()),
            ),
          ),
        );
        await tester.pump();

        expect(container.read(pushedFullScreenOverlayCountProvider), 0);

        await tester.tap(find.byKey(const Key('explore_post_kinetic_reel_card')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.byType(KineticReelStudioView), findsOneWidget);
        expect(find.byKey(const Key('kinetic_reel_studio_view')), findsOneWidget);
        expect(find.byKey(const Key('reel_studio_stage_capture')), findsOneWidget);
        expect(container.read(pushedFullScreenOverlayCountProvider), 1);

        // Toggle FX intensity slider & swap rail side
        await tester.tap(find.byKey(const Key('reel_rail_effects_btn')));
        await tester.pump();
        expect(find.byKey(const Key('reel_studio_intensity_slider')), findsOneWidget);

        await tester.tap(find.byKey(const Key('reel_studio_rail_side_btn')));
        await tester.pump();

        // Select Super 8mm orb & open Audio Picker Sheet
        await tester.tap(find.byKey(const Key('reel_preset_orb_super_8mm')));
        await tester.pump();

        await tester.tap(find.byKey(const Key('reel_studio_audio_pill')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(ReelAudioPickerSheet), findsOneWidget);
        expect(find.byKey(const Key('reel_audio_search_input')), findsOneWidget);
        expect(find.byKey(const Key('reel_audio_import_btn')), findsOneWidget);

        // Close sheet and enter Stage 2 Editor
        Navigator.of(tester.element(find.byType(ReelAudioPickerSheet))).pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        await tester.tap(find.byKey(const Key('reel_studio_next_to_editor_btn')));
        await tester.pump();
        expect(find.byKey(const Key('reel_studio_stage_editor')), findsOneWidget);

        // Pick Sovereign Sticker in Stage 2 Editor
        await tester.tap(find.byKey(const Key('reel_editor_tab_stickers')));
        await tester.pump();
        await tester.tap(
          find.byKey(Key('reel_editor_sticker_${SovereignStickerPack.all.first.id}')),
        );
        await tester.pump();
        expect(
          find.byKey(Key('reel_studio_canvas_sticker_${SovereignStickerPack.all.first.id}')),
          findsOneWidget,
        );

        // Advance to Stage 3 Publish
        await tester.tap(find.byKey(const Key('reel_editor_next_to_publish_btn')));
        await tester.pump();
        expect(find.byKey(const Key('reel_studio_stage_publish')), findsOneWidget);

        final exploreBefore = container.read(socialFeedPostsProvider).length;
        final reelsBefore = container.read(socialFeedProvider).clips.length;

        final switchWidget = tester.widget<SwitchListTile>(
          find.byKey(const Key('reel_publish_share_to_explore_switch')),
        );
        expect(switchWidget.value, isFalse);

        await tester.enterText(
          find.byKey(const Key('reel_publish_caption_input')),
          'Studio v4 Live Take',
        );
        await tester.pump();

        await tester.ensureVisible(find.byKey(const Key('reel_publish_submit_btn')));
        await tester.tap(find.byKey(const Key('reel_publish_submit_btn')));
        await tester.pump();
        for (int i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 120));
        }

        expect(find.byType(KineticReelStudioView), findsNothing);
        expect(container.read(socialFeedProvider).clips.length, reelsBefore + 1);
        expect(container.read(socialFeedPostsProvider).length, exploreBefore);
        expect(container.read(pushedFullScreenOverlayCountProvider), 0);
      },
    );
  });

  group('Phase 74 KineticReelsModal V4 Playback, Contrast & Multi-Reactions', () {
    testWidgets(
      'renders explicit white top tabs in Light Mode, video backing layer, canvas sticker, and 6-type reaction tray preserving legacy likes',
      (tester) async {
        final clip = PublishedClip(
          id: 'clip_v4_test',
          trackId: 'trk_v4',
          creatorId: 'creator_makhadzi',
          creatorUsername: 'makhadzi',
          creatorDisplayName: 'Makhadzi',
          isCreatorVerified: true,
          title: 'V4 Studio Drop',
          caption: 'Custom video + sticker',
          genre: 'Amapiano',
          audioUrl: 'https://cdn.vhunambi.com/audio/v4.mp3',
          coverUrl: '',
          videoUrl: '/r2/social/creator_makhadzi/v4.mp4',
          mediaKind: 'camera_video',
          stickerId: SovereignStickerPack.all.first.id,
          likeCount: 1840,
          dna: SongMetadataDna.fromTrackInfo(
            id: 'trk_v4',
            title: 'V4 Studio Drop',
            genre: 'Amapiano',
            language: 'Tshivenḓa',
            durationSec: 120,
            lyrics: '[Intro] Woza Makhado groove tonight',
          ),
          publishedAt: DateTime.now(),
        );

        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.read(socialFeedProvider.notifier).prependClip(clip);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: KineticReelsModal(clips: <PublishedClip>[clip]),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));

        // 1. Light-Mode tab legibility check (Trending is active by default -> white, For You -> white70)
        final trendingTabText = tester.widget<Text>(find.text('Trending'));
        expect(trendingTabText.style?.color, Colors.white);
        final forYouTabText = tester.widget<Text>(find.text('For You'));
        expect(forYouTabText.style?.color, Colors.white70);

        // 2. Native video backing layer + Sovereign Sticker overlay rendered
        expect(
          find.byKey(const Key('reel_video_backing_layer_clip_v4_test')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('reel_canvas_sticker_clip_v4_test')),
          findsOneWidget,
        );

        // 3. Long-press reel_like_btn opens ReactionTrayOverlay & preserves 1840 legacy likes -> 1841
        await tester.longPress(find.byKey(const Key('reel_like_btn')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 220));
        expect(find.byKey(const Key('reaction_tray_overlay')), findsOneWidget);

        await tester.tap(find.byKey(const Key('reaction_tray_item_fire')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));

        final updated = container.read(socialFeedProvider.notifier).clipById('clip_v4_test')!;
        expect(updated.myReaction, KineticReactionType.fire);
        expect(updated.likeCount, 1841);
        expect(find.byType(KineticReactionBadge), findsWidgets);
      },
    );
  });
}

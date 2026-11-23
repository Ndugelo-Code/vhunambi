import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/auth/auth_providers.dart';
import 'package:vhunambi_client/core/auth/viewer_role.dart';
import 'package:vhunambi_client/core/navigation/navigation_providers.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_glass_tab_bar.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_track_artwork.dart';
import 'package:vhunambi_client/features/content_studio/domain/utils/lyric_karaoke_sanitizer.dart';
import 'package:vhunambi_client/features/content_studio/presentation/views/kinetic_reel_studio_view.dart';
import 'package:vhunambi_client/features/explore/domain/models/social_music_post.dart';
import 'package:vhunambi_client/features/explore/presentation/providers/explore_providers.dart';
import 'package:vhunambi_client/features/explore/presentation/views/kinetic_post_focus_view.dart';
import 'package:vhunambi_client/features/explore/presentation/widgets/catalog_filter_bar.dart';
import 'package:vhunambi_client/features/explore/presentation/widgets/track_list_tile.dart';
import 'package:vhunambi_client/features/library/domain/models/library_models.dart';
import 'package:vhunambi_client/features/library/presentation/providers/library_providers.dart';
import 'package:vhunambi_client/features/library/presentation/views/library_view.dart';
import 'package:vhunambi_client/features/player/presentation/providers/mini_player_controller.dart';
import 'package:vhunambi_client/features/profile/presentation/views/owner_profile_view.dart';
import 'package:vhunambi_client/features/social/domain/models/published_clip.dart';
import 'package:vhunambi_client/features/social/domain/repositories/i_social_repository.dart';
import 'package:vhunambi_client/features/social/presentation/providers/social_feed_provider.dart';
import 'package:vhunambi_client/features/social/presentation/providers/social_repository_provider.dart';
import 'package:vhunambi_client/features/social/presentation/providers/trending_reels_provider.dart';
import 'package:vhunambi_client/features/social/presentation/widgets/creator_reel_thumbnail_card.dart';
import 'package:vhunambi_client/features/social/presentation/widgets/kinetic_reels_modal.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/direct_daw_vocal_upload_sheet.dart';
import 'package:vhunambi_client/features/track/domain/models/track_detail_models.dart';
import 'package:vhunambi_client/features/track/presentation/widgets/lyrics_teleprompter.dart';
import 'package:vhunambi_client/shared/models/track.dart';

class _RecordingSocialRepository implements ISocialRepository {
  int uploadCalls = 0;
  String? lastFilename;
  String? lastMimeType;

  @override
  Future<({String url, String mediaKind, String mimeType, int sizeBytes})>
  uploadReelMedia({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    uploadCalls += 1;
    lastFilename = filename;
    lastMimeType = mimeType;
    return (
      url: 'https://cdn.vhunambi.test/r2/$filename',
      mediaKind: mimeType.startsWith('audio/') ? 'audio' : 'image',
      mimeType: mimeType,
      sizeBytes: bytes.length,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PublishedClip _cloneClip(
  PublishedClip base, {
  required String id,
  String? creatorId,
  String? title,
  String? caption,
  String? coverUrl,
  String? localVideoPath,
  String? mediaKind,
  DateTime? publishedAt,
}) {
  return PublishedClip(
    id: id,
    trackId: base.trackId,
    creatorId: creatorId ?? base.creatorId,
    creatorUsername: base.creatorUsername,
    creatorDisplayName: base.creatorDisplayName,
    creatorAvatarUrl: base.creatorAvatarUrl,
    isCreatorVerified: base.isCreatorVerified,
    title: title ?? base.title,
    caption: caption ?? base.caption,
    tags: base.tags,
    genre: base.genre,
    audioUrl: base.audioUrl,
    coverUrl: coverUrl ?? base.coverUrl,
    videoUrl: base.videoUrl,
    localVideoPath: localVideoPath ?? base.localVideoPath,
    mediaKind: mediaKind ?? base.mediaKind,
    audioStartMs: base.audioStartMs,
    audioEndMs: base.audioEndMs,
    effectPreset: base.effectPreset,
    effectIntensity: base.effectIntensity,
    typographyPreset: base.typographyPreset,
    speedRate: base.speedRate,
    stickerId: base.stickerId,
    dna: base.dna,
    publishedAt: publishedAt ?? base.publishedAt,
  );
}

void main() {
  group('Phase 78 Vault Continuity, Uploads & Glass Tabs', () {
    test(
      'resolveViewerRole rescues legacy @aistudio / AI Studio assets to owner while failing closed on other artists',
      () {
        expect(
          resolveViewerRole(
            ownerCreatorId: 'creator_aistudio',
            ownerHandle: '@aistudio',
            activeCreatorId: 'user_ndugelo',
            activeHandle: '@ndugelo',
          ),
          ViewerRole.owner,
        );
        expect(
          resolveViewerRole(
            ownerCreatorId: 'ai_studio',
            ownerHandle: null,
            activeCreatorId: 'user_ndugelo',
            activeHandle: '@ndugelo',
          ),
          ViewerRole.owner,
        );
        expect(
          resolveViewerRole(
            ownerCreatorId: 'creator_lerato',
            ownerHandle: '@lerato',
            activeCreatorId: 'user_ndugelo',
            activeHandle: '@ndugelo',
          ),
          ViewerRole.visitor,
        );
      },
    );

    test(
      'SocialMusicPost.fromJson normalizes @current_user handles away cleanly',
      () {
        final post = SocialMusicPost.fromJson(<String, dynamic>{
          'id': 'post_p78_norm',
          'creatorId': 'creator_current_user',
          'creatorName': 'Ndugelo',
          'creatorHandle': '@current_user',
          'caption': 'Testing handle normalization',
          'publishedAt': '2026-11-23T00:00:00Z',
          'track': <String, dynamic>{
            'id': 'trk_p78_post',
            'title': 'Venda Horizon',
            'creatorName': 'Ndugelo',
            'genre': 'Amapiano',
            'language': 've',
            'durationSeconds': 180,
          },
        });

        expect(post.creatorHandle, isNot('@current_user'));
        expect(post.creatorHandle.startsWith('@'), isTrue);
      },
    );

    test(
      'LyricKaraokeSanitizer strips bracketed section tags and unclosed stage directions',
      () {
        const raw =
            '[INTRO]\n(Sacred drum; soft shakers enter)\n(Sacred drum; echo\nVhunambi ri a imba';
        final cleaned = LyricKaraokeSanitizer.cleanLyricsForPlayback(raw);

        expect(cleaned, isNot(contains('[INTRO]')));
        expect(cleaned, isNot(contains('Sacred drum')));
        expect(cleaned, contains('Vhunambi ri a imba'));
      },
    );

    test(
      'trendingReelsProvider pins newly published non-seed clips at index 0 ahead of viral seeds',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final initialClips = container.read(socialFeedProvider).clips;
        expect(initialClips, isNotEmpty);

        final freshClip = _cloneClip(
          initialClips.first,
          id: 'clip_p78_fresh_pin',
          creatorId: 'creator_me',
          title: 'Love this one',
          caption: 'Fresh hardware pin',
          publishedAt: DateTime.now(),
        );

        container.read(socialFeedProvider.notifier).prependClip(freshClip);
        final trending = container.read(trendingReelsProvider);

        expect(trending.first.id, 'clip_p78_fresh_pin');
        expect(trending.first.title, 'Love this one');
      },
    );

    test(
      'MiniPlayerController.resetToDock snaps manual mode back to auto dock',
      () {
        final controller = MiniPlayerController();
        addTearDown(controller.dispose);

        controller.startDrag(const Offset(120, 340));
        controller.setForm(PlayerForm.pill);
        expect(controller.mode, PlayerMode.manual);
        expect(controller.form, PlayerForm.pill);
        expect(controller.position, const Offset(120, 340));

        controller.resetToDock(const Size(390, 844));
        expect(controller.mode, PlayerMode.auto);
        expect(controller.form, PlayerForm.bar);
      },
    );

    test(
      'PublishedClip preserves localVideoPath across copyWith and JSON round-trip',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final seed = container.read(socialFeedProvider).clips.first;
        final recorded = seed.copyWith(
          id: 'clip_p78_video',
          localVideoPath: '/tmp/recorded_dance_reel.mp4',
          mediaKind: 'video',
        );

        final decoded = PublishedClip.fromJson(recorded.toJson());
        expect(decoded.localVideoPath, '/tmp/recorded_dance_reel.mp4');
        expect(decoded.mediaKind, 'video');
      },
    );

    testWidgets(
      'DirectDawVocalUploadSheet real file pick uploads WAV/MP3 via R2 and appends owned track to Library',
      (tester) async {
        final repo = _RecordingSocialRepository();
        final container = ProviderContainer(
          overrides: [
            socialRepositoryProvider.overrideWithValue(repo),
            currentCreatorIdProvider.overrideWithValue('user_ndugelo'),
            currentCreatorHandleProvider.overrideWithValue('@ndugelo'),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const Scaffold(body: DirectDawVocalUploadSheet()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final pickBtn = find.byKey(const Key('direct_upload_pick_file_btn'));
        expect(pickBtn, findsOneWidget);
        await tester.ensureVisible(pickBtn);
        await tester.tap(pickBtn);
        await tester.pumpAndSettle();

        expect(find.textContaining('daw_master_import.mp3'), findsWidgets);

        final submitBtn = find.byType(ElevatedButton).last;
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        expect(repo.uploadCalls, 1);
        final libraryTracks = container.read(libraryTracksProvider);
        expect(
          libraryTracks.any(
            (t) => t.title == 'daw master import' && !t.isInstrumental,
          ),
          isTrue,
        );
      },
    );

    testWidgets(
      'KineticReelStudioView renders legible audio pill (>= 168px) and opens Capture stage cleanly',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const KineticReelStudioView(initialCameraMode: true),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        final audioPill = find.byKey(const Key('reel_studio_audio_pill'));
        expect(audioPill, findsOneWidget);
        final pillSize = tester.getSize(audioPill);
        expect(pillSize.width, greaterThanOrEqualTo(168));
      },
    );

    testWidgets(
      'KineticReelsModal suppresses SnackBars using ephemeral love pill and ref-counts pushedFullScreenOverlayCountProvider',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final clips = container.read(socialFeedProvider).clips.take(2).toList();
        expect(container.read(pushedFullScreenOverlayCountProvider), 0);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    key: const Key('open_reels_modal_btn'),
                    onPressed: () => KineticReelsModal.show(
                      context,
                      clips: clips,
                    ),
                    child: const Text('Open Reels'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.byKey(const Key('open_reels_modal_btn')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(container.read(pushedFullScreenOverlayCountProvider), 1);

        final loveBtn = find.byKey(const Key('reel_like_btn'));
        expect(loveBtn, findsOneWidget);

        await tester.tap(loveBtn);
        await tester.tap(loveBtn);
        await tester.tap(loveBtn);
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byType(SnackBar), findsNothing);
        expect(find.byKey(const Key('reel_ephemeral_love_pill')), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 900));
        expect(find.byKey(const Key('reel_ephemeral_love_pill')), findsNothing);

        Navigator.of(tester.element(find.byType(KineticReelsModal))).pop();
        await tester.pumpAndSettle();
        expect(container.read(pushedFullScreenOverlayCountProvider), 0);
      },
    );

    testWidgets(
      'LibraryView includes Reels tab with newly published clip and ReelsVaultView',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            currentCreatorIdProvider.overrideWithValue('creator_me'),
          ],
        );
        addTearDown(container.dispose);

        final seed = container.read(socialFeedProvider).clips.first;
        container.read(socialFeedProvider.notifier).prependClip(
          _cloneClip(
            seed,
            id: 'clip_p78_vault_reel',
            creatorId: 'creator_me',
            title: 'Vault Pin Test Reel',
            publishedAt: DateTime.now(),
          ),
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const Scaffold(body: LibraryView()),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        final reelsTab = find.byKey(
          Key('library_category_${LibraryCategory.reels.name}'),
        );
        expect(reelsTab, findsOneWidget);

        await tester.tap(reelsTab);
        await tester.pump(const Duration(milliseconds: 150));

        expect(find.byKey(const Key('library_reels_vault_view')), findsOneWidget);
        expect(find.text('Vault Pin Test Reel'), findsWidgets);
      },
    );

    testWidgets(
      'CreatorReelThumbnailCard uses VhunambiTrackArtwork fallback and zero Material Icons',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final clip = _cloneClip(
          container.read(socialFeedProvider).clips.first,
          id: 'clip_p78_thumb_fallback',
          coverUrl: '',
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: SizedBox(
                width: 140,
                child: CreatorReelThumbnailCard(clip: clip, onTap: () {}),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(VhunambiTrackArtwork), findsOneWidget);
        expect(find.byType(Icon), findsNothing);
      },
    );

    testWidgets(
      'OwnerProfileView Songs tab does not duplicate My Clips & Reels shelf',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            currentCreatorIdProvider.overrideWithValue('user_ndugelo'),
            currentCreatorHandleProvider.overrideWithValue('@ndugelo'),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const OwnerProfileView(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('My Clips & Reels'), findsNothing);

        final reelsSegment = find.byKey(const Key('owner_studio_tab_reels'));
        await tester.ensureVisible(reelsSegment);
        await tester.tap(reelsSegment);
        await tester.pump(const Duration(milliseconds: 150));

        expect(find.text('My Clips & Reels'), findsOneWidget);
      },
    );

    testWidgets(
      'VhunambiGlassTabBar renders Light & Dark themes with 44dp touch height and triggers callbacks',
      (tester) async {
        int selected = 0;

        for (final theme in [AppTheme.darkTheme, AppTheme.lightTheme]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: Scaffold(
                body: Center(
                  child: VhunambiGlassTabBar(
                    selectedIndex: selected,
                    items: const [
                      VhunambiGlassTabItem(key: Key('tab_a'), label: 'Songs'),
                      VhunambiGlassTabItem(
                        key: Key('tab_b'),
                        label: 'Reels',
                        badgeCount: 3,
                      ),
                    ],
                    onSelected: (idx) => selected = idx,
                  ),
                ),
              ),
            ),
          );
          await tester.pump();

          final sizeA = tester.getSize(find.byKey(const Key('tab_a')));
          expect(sizeA.height, greaterThanOrEqualTo(44));
        }

        await tester.tap(find.byKey(const Key('tab_b')));
        expect(selected, 1);
      },
    );

    testWidgets(
      'CatalogFilterBar horizontal mood rail, TrackListTile artwork, and KineticPostFocusView Tip pill render without Material Icons',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final posts = container.read(socialFeedPostsProvider);
        const track = Track(
          id: 'trk_p78_tile',
          title: 'Venda Dawn',
          creatorName: 'Ndugelo',
          genre: 'Maskandi',
          language: 'Tshivenḓa',
          duration: Duration(minutes: 3, seconds: 10),
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      CatalogFilterBar(),
                      TrackListTile(track: track),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byKey(const Key('catalog_mood_rail')), findsOneWidget);
        expect(
          find.byKey(const Key('track_list_tile_artwork_trk_p78_tile')),
          findsOneWidget,
        );
        expect(find.byType(VhunambiTrackArtwork), findsOneWidget);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: KineticPostFocusView(
                postId: posts.first.id,
                initialPost: posts.first,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byKey(const Key('kpost_focus_tip_btn')), findsOneWidget);
        expect(find.text('Tip'), findsOneWidget);
      },
    );

    testWidgets(
      'LyricsTeleprompter strips raw tags during active rendering',
      (tester) async {
        const entity = TrackDetailEntity(
          id: 'trk_p78_lyr',
          title: 'Venda Dawn',
          genre: 'Amapiano',
          language: 'Tshivenḓa',
          duration: Duration(minutes: 3),
          creatorId: 'user_ndugelo',
          creatorName: 'Ndugelo',
          creatorHandle: '@ndugelo',
          lyrics: '[INTRO]\n(Sacred drum; soft\nVenda sunrise melody',
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const Scaffold(
                body: LyricsTeleprompter(track: entity),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.textContaining('[INTRO]'), findsNothing);
        expect(find.textContaining('Sacred drum'), findsNothing);
        expect(find.textContaining('Venda sunrise melody'), findsOneWidget);
      },
    );
  });
}

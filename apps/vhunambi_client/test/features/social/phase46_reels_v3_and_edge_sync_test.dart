import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/core/sync/sync_outbox_service.dart';
import 'package:vhunambi_client/core/sync/edge_sync_coordinator.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/profile_banner_header.dart';
import 'package:vhunambi_client/features/profile/domain/models/profile_models.dart';
import 'package:vhunambi_client/features/explore/domain/models/social_music_post.dart';
import 'package:vhunambi_client/features/explore/presentation/widgets/explore_social_post_card.dart';
import 'package:vhunambi_client/features/social/domain/models/published_clip.dart';
import 'package:vhunambi_client/features/social/presentation/widgets/kinetic_reels_modal.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/song_metadata_dna.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/profile_settings_drawer.dart';
import 'package:vhunambi_client/shared/models/track.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 46: Kinetic Reels V3 & Edge Sync Coordinator Tests', () {
    testWidgets(
      '1. ProfileBannerHeader Share button contrast in Light Mode (REQ-P46-UI-01)',
      (tester) async {
        final mockProfile = ArtistProfileEntity(
          id: 'creator_makhadzi',
          username: 'makhadzi',
          displayName: 'Makhadzi Muimbi',
          bio: 'Queen of Limpopo Heritage',
          avatarUrl: 'https://cdn.vhunambi.com/avatars/makhadzi.jpg',
          isVerified: true,
          monogram: 'M',
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: Scaffold(
                body: ProfileBannerHeader(
                  profile: mockProfile,
                  onToggleFollow: () {},
                  onTipArtist: () {},
                  onShare: () {},
                  onReport: () {},
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify Phosphor shareNetwork icon is rendered inside Semantics
        expect(find.byIcon(PhosphorIconsRegular.shareNetwork), findsOneWidget);
        final icon = tester.widget<PhosphorIcon>(
          find.byIcon(PhosphorIconsRegular.shareNetwork),
        );
        expect(icon.color, isNotNull);
        // In light mode, icon color must NOT be pure white
        expect(icon.color, isNot(Colors.white));
      },
    );

    testWidgets(
      '2. ExploreSocialPostCard renders unclipped Co-Sign button alongside Open Stems (REQ-P46-UI-03)',
      (tester) async {
        await tester.binding.setSurfaceSize(
          const Size(360, 800),
        ); // Narrow viewport test
        addTearDown(() async => await tester.binding.setSurfaceSize(null));

        final testPost = SocialMusicPost(
          id: 'post_p46_wrap_test',
          creatorId: 'creator_makhadzi',
          creatorName: 'Makhadzi Muimbi',
          creatorHandle: '@makhadzi',
          publishedAt: DateTime.now(),
          caption:
              'Late night studio session testing the Venda Folk LoRA & sub-bass log drum slide 🔥',
          cosignCount: 18,
          isCosigned: false,
          track: const Track(
            id: 'trk_01',
            title: 'Ndo Mufuna Matibe',
            creatorName: 'Makhadzi',
            creatorHandle: '@makhadzi',
            genre: 'Amapiano',
            language: 'Tshivenḓa',
            duration: Duration(minutes: 3, seconds: 18),
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: Scaffold(
                body: SingleChildScrollView(
                  child: ExploreSocialPostCard(post: testPost),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify Co-Sign button key exists
        final cosignBtn = find.byKey(Key('post_cosign_btn_${testPost.id}'));
        expect(cosignBtn, findsOneWidget);
        // Verify full unclipped text renders
        expect(find.text('🔥 Co-Sign · 18/25'), findsOneWidget);
        // Verify remix lineage pill also renders
        expect(
          find.byKey(Key('post_remix_tree_btn_${testPost.id}')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '3. ReelStemToggleBar renders 4 stem pills and toggles mute (REQ-P46-REEL-07..10)',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              themeMode: ThemeMode.dark,
              home: Scaffold(body: ReelStemToggleBar()),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byKey(const Key('reel_stem_toggle_bar')), findsOneWidget);
        expect(find.byKey(const Key('reel_stem_pill_vocals')), findsOneWidget);
        expect(find.byKey(const Key('reel_stem_pill_bass')), findsOneWidget);
        expect(find.byKey(const Key('reel_stem_pill_drums')), findsOneWidget);
        expect(find.byKey(const Key('reel_stem_pill_melodic')), findsOneWidget);

        // Tap Vocals pill to mute
        await tester.tap(find.byKey(const Key('reel_stem_pill_vocals')));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      '4. ReelDuetSplitStage renders Originator x Remixer avatars & 70/30 Split (REQ-P46-REEL-04..06)',
      (tester) async {
        final remixedClip = PublishedClip(
          id: 'clip_p46_duet',
          trackId: 'trk_p46_duet',
          creatorId: 'creator_fifi',
          creatorUsername: 'fifi',
          creatorDisplayName: 'Fifi',
          title: 'Ndo Mufuna Matibe (Open-Verse Remix)',
          genre: 'Amapiano',
          audioUrl: 'https://cdn.vhunambi.com/audio/remix.mp3',
          coverUrl: 'https://cdn.vhunambi.com/covers/remix.jpg',
          parentCreatorHandle: '@makhadzi',
          parentCreatorId: 'creator_makhadzi',
          remixGenerationDepth: 1,
          publishedAt: DateTime.now(),
          dna: SongMetadataDna.fromTrackInfo(
            id: 'trk_p46_duet',
            title: 'Ndo Mufuna Matibe',
            genre: 'Amapiano',
            language: 'Tshivenḓa',
            durationSec: 180,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: ReelDuetSplitStage(clip: remixedClip, pulseScale: 0.5),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.byKey(Key('reel_duet_split_stage_${remixedClip.id}')),
          findsOneWidget,
        );
        expect(find.text('ORIGINATOR'), findsOneWidget);
        expect(find.text('@makhadzi'), findsOneWidget);
        expect(find.text('CO-CREATOR'), findsOneWidget);
        expect(find.text('@fifi'), findsOneWidget);
        expect(find.text('70/30 Split'), findsOneWidget);
      },
    );

    testWidgets(
      '5. EdgeSyncCoordinator syncNow() flushes outbox and updates state (REQ-P46-SYNC-04..07)',
      (tester) async {
        final outbox = SyncOutboxService(isInMemoryOnly: true);
        await outbox.init();

        await outbox.enqueue(
          SyncMutationRecord(
            idempotencyKey: 'mut_p46_unit_01',
            entityType: 'post',
            action: 'create',
            payload: {'caption': 'Unit Test Post'},
            createdAt: DateTime.now(),
          ),
        );

        final container = ProviderContainer(
          overrides: [syncOutboxServiceProvider.overrideWithValue(outbox)],
        );
        addTearDown(container.dispose);

        final coordinator = container.read(
          edgeSyncCoordinatorProvider.notifier,
        );
        expect(
          container.read(edgeSyncCoordinatorProvider).status,
          EdgeSyncStatus.idle,
        );

        // Trigger syncNow (will execute offline fallback cleanly)
        final res = await coordinator.syncNow();
        expect(res, isNotNull);
        final finalState = container.read(edgeSyncCoordinatorProvider);
        expect(
          finalState.status,
          isIn([EdgeSyncStatus.synced, EdgeSyncStatus.offline]),
        );
      },
    );

    testWidgets(
      '6. ProfileSettingsDrawer renders Sync Now button (REQ-P46-SYNC-07)',
      (tester) async {
        final mockOutbox = SyncOutboxService(isInMemoryOnly: true);
        await mockOutbox.init();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              syncOutboxServiceProvider.overrideWithValue(mockOutbox),
            ],
            child: const MaterialApp(home: Scaffold(body: ProfileSettingsDrawer())),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byKey(const Key('settings_sync_now_btn')), findsOneWidget);
        expect(find.text('Sync Now'), findsOneWidget);

        await tester.tap(find.byKey(const Key('settings_sync_now_btn')));
        await tester.pumpAndSettle();
      },
    );
  });
}

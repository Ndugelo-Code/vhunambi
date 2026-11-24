import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/auth/auth_providers.dart';
import 'package:vhunambi_client/core/media/sovereign_media_storage_service.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_glass_surface.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_track_artwork.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/content_studio_preset.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/song_metadata_dna.dart';
import 'package:vhunambi_client/features/content_studio/presentation/views/kinetic_reel_publish_view.dart';
import 'package:vhunambi_client/features/content_studio/presentation/views/kinetic_reel_studio_view.dart';
import 'package:vhunambi_client/features/content_studio/presentation/widgets/reel_audio_picker_sheet.dart';
import 'package:vhunambi_client/features/content_studio/presentation/widgets/reel_audio_trimmer_sheet.dart';
import 'package:vhunambi_client/features/explore/presentation/widgets/create_kinetic_post_sheet.dart';
import 'package:vhunambi_client/features/library/domain/models/library_models.dart';
import 'package:vhunambi_client/features/library/presentation/views/library_view.dart';
import 'package:vhunambi_client/features/media/data/repositories/http_media_upload_repository.dart';
import 'package:vhunambi_client/features/media/domain/models/uploaded_media_asset.dart';
import 'package:vhunambi_client/features/media/presentation/providers/media_upload_queue_provider.dart';
import 'package:vhunambi_client/features/offline/data/services/offline_storage_service.dart';
import 'package:vhunambi_client/features/player/data/services/audio_source_resolver.dart';
import 'package:vhunambi_client/features/social/presentation/widgets/trending_reels_shelf.dart';
import 'package:vhunambi_client/shared/models/track.dart';

class _FakeMediaUploadRepository implements IMediaUploadRepository {
  bool shouldFail = false;
  int uploadAttempts = 0;
  final List<double> reportedFractions = <double>[];

  @override
  Future<UploadedMediaAsset> uploadMedia({
    required UploadedMediaAsset staged,
    required Uint8List bytes,
    void Function(int sent, int total)? onProgress,
  }) async {
    uploadAttempts++;
    onProgress?.call(40, 100);
    reportedFractions.add(0.4);
    onProgress?.call(80, 100);
    reportedFractions.add(0.8);
    if (shouldFail) {
      throw const SocketException('Simulated Vodacom cellular drop');
    }
    return staged.copyWith(
      remoteUrl: 'https://cdn.vhunambi.test/r2/media/${staged.filename}',
      remoteKey: 'media/${staged.creatorId}/${staged.id}',
      status: MediaUploadStatus.synced,
      progress: 1.0,
      clearError: true,
    );
  }

  @override
  Future<List<UploadedMediaAsset>> fetchUploads({
    required String creatorId,
    MediaAssetKind? kind,
  }) async => const <UploadedMediaAsset>[];

  @override
  Future<bool> deleteRemoteUpload(String assetId) async => true;
}

class _StubOfflineStorage implements IOfflineStorageService {
  @override
  Future<bool> isTrackCachedLocally(String trackId) async => false;

  @override
  Future<Map<String, dynamic>?> getTrackMetadata(String trackId) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    SovereignMediaStorageService.clearTenantSessionMemory();
  });

  group('Phase 79: Sovereign Media Upload Engine, Post Cockpit v2 & Studio Polish', () {
    test(
      'SovereignMediaStorageService stages real local file and isolates tenants (REQ-P79-VLT-01)',
      () async {
        final bytes = Uint8List.fromList(<int>[0x52, 0x49, 0x46, 0x46, 0x11, 0x22]);
        final path = await SovereignMediaStorageService.stageMediaBytes(
          creatorId: 'creator_alice',
          assetId: 'upl_p79_alice_1',
          kind: MediaAssetKind.audio,
          filename: 'Abafana.wav',
          mimeType: 'audio/wav',
          bytes: bytes,
        );
        expect(path, isNotNull);
        expect(File(path!).existsSync(), isTrue);

        await SovereignMediaStorageService.saveAsset(
          UploadedMediaAsset(
            id: 'upl_p79_alice_1',
            creatorId: 'creator_alice',
            kind: MediaAssetKind.audio,
            title: 'Abafana',
            filename: 'Abafana.wav',
            mimeType: 'audio/wav',
            sizeBytes: bytes.length,
            localFilePath: path,
            createdAt: DateTime.now(),
          ),
        );

        expect(
          SovereignMediaStorageService.loadCreatorAssets('creator_alice').length,
          1,
        );
        expect(
          SovereignMediaStorageService.loadCreatorAssets('creator_bob'),
          isEmpty,
        );
      },
    );

    test(
      'MediaUploadQueueNotifier preserves local file on cellular drop (zero fake URL) and recovers on retry (REQ-P79-VLT-02)',
      () async {
        final fakeRepo = _FakeMediaUploadRepository()..shouldFail = true;
        final container = ProviderContainer(
          overrides: [
            currentCreatorIdProvider.overrideWithValue('creator_ndugelo'),
            customMediaUploadRepositoryProvider.overrideWithValue(fakeRepo),
          ],
        );
        addTearDown(container.dispose);

        final failed = await container
            .read(mediaUploadQueueProvider.notifier)
            .stageAndEnqueue(
              bytes: Uint8List.fromList(<int>[1, 2, 3, 4, 5]),
              filename: 'abafana_take.mp3',
              mimeType: 'audio/mpeg',
              kind: MediaAssetKind.audio,
              title: 'Abafana',
              awaitUpload: true,
            );

        expect(failed.status, MediaUploadStatus.failed);
        expect(failed.remoteUrl, isNull);
        expect(failed.localFilePath, isNotNull);
        expect(File(failed.localFilePath!).existsSync(), isTrue);
        expect(fakeRepo.reportedFractions, contains(0.4));

        // Recover when network returns
        fakeRepo.shouldFail = false;
        final retried = await container
            .read(mediaUploadQueueProvider.notifier)
            .retryUpload(failed.id);

        expect(retried, isNotNull);
        expect(retried!.status, MediaUploadStatus.synced);
        expect(retried.progress, 1.0);
        expect(
          retried.remoteUrl,
          'https://cdn.vhunambi.test/r2/media/abafana_take.mp3',
        );
        expect(fakeRepo.uploadAttempts, 2);
      },
    );

    test(
      'AudioSourceResolver prioritizes readable unencrypted local file even in offline mode (REQ-P79-AUD-01)',
      () async {
        final localPath = await SovereignMediaStorageService.stageMediaBytes(
          creatorId: 'creator_ndugelo',
          assetId: 'upl_p79_local_audio',
          kind: MediaAssetKind.audio,
          filename: 'abafana_offline.mp3',
          mimeType: 'audio/mpeg',
          bytes: Uint8List.fromList(<int>[0x49, 0x44, 0x33, 0x03]),
        );
        final resolver = AudioSourceResolver(
          offlineStorage: _StubOfflineStorage(),
          offlineModeGuard: () => true,
        );
        final resolved = await resolver.resolveSource(
          Track(
            id: 'trk_local_abafana',
            title: 'Abafana',
            creatorName: 'Ndugelo',
            genre: 'Amapiano',
            duration: const Duration(seconds: 90),
            audioUrl: localPath,
          ),
        );

        expect(resolved.isLocalFile, isTrue);
        expect(resolved.localFilePath, localPath);
        expect(resolved.uri, Uri.file(localPath!));
      },
    );

    testWidgets(
      'VhunambiTrackArtwork renders Image.file for existing local image path (REQ-P79-AUD-01)',
      (tester) async {
        final localImg = await SovereignMediaStorageService.stageMediaBytes(
          creatorId: 'creator_ndugelo',
          assetId: 'upl_p79_local_img',
          kind: MediaAssetKind.image,
          filename: 'studio_cover.jpg',
          mimeType: 'image/jpeg',
          bytes: Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xD9]),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: VhunambiTrackArtwork(
                coverUrl: localImg,
                genre: 'Amapiano',
                trackId: 'trk_img',
                width: 80,
                height: 80,
              ),
            ),
          ),
        );
        await tester.pump();

        final imageWidget = tester.widget<Image>(find.byType(Image));
        expect(imageWidget.image, isA<FileImage>());
      },
    );

    testWidgets(
      'KineticReelPublishView renders Stage 3 video poster and non-destructive Retry Publish on cellular drop (REQ-P79-AUD-03)',
      (tester) async {
        final fakeRepo = _FakeMediaUploadRepository()..shouldFail = true;
        final container = ProviderContainer(
          overrides: [
            currentCreatorIdProvider.overrideWithValue('creator_ndugelo'),
            customMediaUploadRepositoryProvider.overrideWithValue(fakeRepo),
          ],
        );
        addTearDown(container.dispose);

        bool published = false;
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: KineticReelPublishView(
                audio: ReelStudioAudioSelection(
                  trackId: 'trk_abafana',
                  title: 'Abafana',
                  creatorHandle: '@ndugelo',
                  genre: 'Amapiano',
                  mood: 'uplifting',
                  audioUrl: '/r2/audio/abafana.mp3',
                  coverUrl: '',
                  durationSeconds: 90,
                  dna: SongMetadataDna.fromTrackInfo(
                    id: 'trk_abafana',
                    title: 'Abafana',
                    genre: 'Amapiano',
                    language: 'English',
                    durationSec: 90,
                  ),
                ),
                mediaKind: 'camera_video',
                customMediaBytes: Uint8List.fromList(<int>[0, 0, 0, 24, 102, 116]),
                customMediaFilename: 'camera_take.mp4',
                customMediaMime: 'video/mp4',
                audioStartMs: 0,
                audioEndMs: 30000,
                effectPreset: 'kinetic_gold',
                effectIntensity: 0.65,
                typographyPreset: LyricTypographyPreset.kineticBounce,
                speedRate: 1.0,
                onBackToEditor: () {},
                onPublishComplete: () => published = true,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byKey(const Key('publish_video_poster_preview')), findsOneWidget);

        await tester.tap(find.byKey(const Key('reel_publish_submit_btn')));
        await tester.pump(const Duration(milliseconds: 200));

        expect(published, isFalse);
        expect(find.byKey(const Key('reel_publish_error_card')), findsOneWidget);
        expect(find.byKey(const Key('reel_publish_retry_btn')), findsOneWidget);
      },
    );

    testWidgets(
      'CreateKineticPostSheet v2 renders above-the-fold carousel, My Uploads trigger, and auditionable audio card (REQ-P79-KPOST-01..02)',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const Scaffold(body: CreateKineticPostSheet()),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        await tester.tap(find.byKey(const Key('kpost_pick_photo_btn')));
        await tester.pump(const Duration(milliseconds: 150));

        final carouselFinder = find.byKey(const Key('kpost_media_preview_carousel'));
        final aspectFinder = find.byKey(const Key('kpost_aspect_ratio_selector'));
        expect(carouselFinder, findsOneWidget);
        expect(
          tester.getTopLeft(carouselFinder).dy,
          lessThan(tester.getTopLeft(aspectFinder).dy),
        );

        expect(find.byKey(const Key('kpost_pick_from_uploads_btn')), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byKey(const Key('kpost_audio_attachment_card')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        expect(find.byKey(const Key('kpost_audio_source_tabs')), findsOneWidget);
        expect(find.byKey(const Key('kpost_audio_attachment_card')), findsOneWidget);
        expect(find.byKey(const Key('kpost_audio_audition_btn')), findsOneWidget);

        await tester.tap(find.byKey(const Key('kpost_audio_audition_btn')));
        await tester.pump();
      },
    );

    testWidgets(
      'LibraryView includes Uploads category routing to UploadsVaultView and supports staging uploads (REQ-P79-HUB-01)',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const LibraryView(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        final uploadsTab = find.byKey(const Key('library_category_uploads'));
        expect(uploadsTab, findsOneWidget);
        await tester.tap(uploadsTab);
        await tester.pump(const Duration(milliseconds: 150));

        expect(find.byKey(const Key('library_uploads_vault_view')), findsOneWidget);
        await tester.tap(find.text('Upload audio or media'));
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Abafana Master'), findsOneWidget);
      },
    );

    testWidgets(
      'ReelAudioPickerSheet uses 5-tab VhunambiGlassTabBar and scrubs legacy AI Studio labels (REQ-P79-HUB-02)',
      (tester) async {
        final legacyTrack = LibraryTrack(
          id: 'trk_legacy_ai',
          title: 'Underground Durban Club',
          creatorName: 'AI Studio',
          creatorHandle: '@aistudio',
          genre: 'Amapiano',
          language: 'English',
          durationSeconds: 120,
          remoteAudioUrl: '/r2/audio/durban.mp3',
          createdAt: DateTime.now(),
        );
        final sanitized = ReelStudioAudioSelection.fromLibraryTrack(
          legacyTrack,
          fallbackCreatorHandle: '@ndugelo',
        );
        expect(sanitized.creatorHandle, '@ndugelo');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentCreatorHandleProvider.overrideWithValue('@ndugelo'),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: Scaffold(
                body: ReelAudioPickerSheet(onSelected: (_) {}),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byKey(const Key('reel_audio_picker_glass_tabs')), findsOneWidget);
        expect(find.byKey(const Key('reel_audio_tab_uploads')), findsOneWidget);
        expect(find.text('Trending'), findsOneWidget);
      },
    );

    testWidgets(
      'Dark Mode Post Reel card uses VhunambiGlassSurface, trimmer fits 360x740 with dual handles, and Stage 2 drawer <= 34% with draggable sticker (REQ-P79-STU-01..03)',
      (tester) async {
        tester.view.physicalSize = const Size(360, 740);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // 1. Dark Mode _PostKineticReelCard
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const Scaffold(body: TrendingReelsShelf()),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          find.descendant(
            of: find.byKey(const Key('explore_post_kinetic_reel_card')),
            matching: find.byType(VhunambiGlassSurface),
          ),
          findsOneWidget,
        );

        // 2. SafeArea Dual-Handle Trimmer unclipped on 360x740
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: ReelAudioTrimmerSheet(
                  trackTitle: 'Abafana',
                  totalDurationSec: 120,
                  initialStartMs: 0,
                  initialEndMs: 30000,
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byKey(const Key('reel_audio_trim_range_slider')), findsOneWidget);
        final doneBtn = find.byKey(const Key('reel_audio_trimmer_done_btn'));
        expect(doneBtn, findsOneWidget);
        expect(tester.getBottomLeft(doneBtn).dy, lessThanOrEqualTo(740.0));

        // 3. KineticReelStudioView bounded rail + <=34% Stage 2 drawer + draggable sticker
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const KineticReelStudioView(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byKey(const Key('reel_studio_tool_rail_scroll')), findsOneWidget);
        final railRect = tester.getRect(
          find.byKey(const Key('reel_studio_tool_rail_scroll')),
        );
        expect(railRect.bottom, lessThanOrEqualTo(740.0 - 150.0));

        await tester.tap(find.byKey(const Key('reel_studio_next_to_editor_btn')));
        await tester.pump(const Duration(milliseconds: 150));

        final drawerRect = tester.getRect(
          find.byKey(const Key('reel_studio_stage2_bottom_drawer')),
        );
        expect(drawerRect.height, lessThanOrEqualTo(740.0 * 0.34 + 1.0));

        await tester.tap(find.byKey(const Key('reel_editor_tab_stickers')));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(
          find.byKey(const Key('reel_editor_sticker_stk_log_drum_hit')),
        );
        await tester.pump(const Duration(milliseconds: 100));

        final stickerFinder = find.byKey(
          const Key('reel_studio_canvas_sticker_stk_log_drum_hit'),
        );
        expect(stickerFinder, findsOneWidget);
        final beforePos = tester.getTopLeft(stickerFinder);
        await tester.drag(stickerFinder, const Offset(-40, 30));
        await tester.pump(const Duration(milliseconds: 100));
        final afterPos = tester.getTopLeft(stickerFinder);
        expect(afterPos, isNot(equals(beforePos)));
      },
    );
  });
}

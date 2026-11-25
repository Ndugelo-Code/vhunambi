import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/auth/auth_providers.dart';
import 'package:vhunambi_client/core/auth/sovereign_auth_session.dart';
import 'package:vhunambi_client/core/media/sovereign_media_storage_service.dart';
import 'package:vhunambi_client/core/network/sovereign_api_client.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/content_studio_preset.dart';
import 'package:vhunambi_client/features/content_studio/presentation/views/kinetic_reel_publish_view.dart';
import 'package:vhunambi_client/features/content_studio/presentation/widgets/reel_audio_picker_sheet.dart';
import 'package:vhunambi_client/features/explore/presentation/providers/explore_providers.dart';
import 'package:vhunambi_client/features/explore/presentation/widgets/create_kinetic_post_sheet.dart';
import 'package:vhunambi_client/features/media/data/repositories/http_media_upload_repository.dart';
import 'package:vhunambi_client/features/media/domain/models/uploaded_media_asset.dart';
import 'package:vhunambi_client/features/media/domain/utils/media_mime_utils.dart';
import 'package:vhunambi_client/features/media/presentation/providers/media_upload_queue_provider.dart';
import 'package:vhunambi_client/features/social/data/repositories/http_social_repository.dart';
import 'package:vhunambi_client/features/social/presentation/providers/social_repository_provider.dart';

class _StubHttpClientAdapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions options) responder;

  _StubHttpClientAdapter(this.responder);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return responder(options);
  }

  @override
  void close({bool force = false}) {}
}

class _CountingMediaUploadRepo implements IMediaUploadRepository {
  int uploadCalls = 0;

  @override
  Future<UploadedMediaAsset> uploadMedia({
    required UploadedMediaAsset staged,
    required Uint8List bytes,
    void Function(int sent, int total)? onProgress,
  }) async {
    uploadCalls++;
    onProgress?.call(50, 100);
    onProgress?.call(100, 100);
    return staged.copyWith(
      remoteUrl: 'https://cdn.vhunambi.test/r2/media/${staged.filename}',
      remoteKey: 'media/${staged.creatorId}/${staged.id}.mp3',
      thumbnailUrl: 'https://cdn.vhunambi.test/r2/covers/${staged.id}.jpg',
      artist: 'Zania Artist',
      genre: 'Afrobeats',
      bpm: 116,
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

class _CapturingSocialRepo extends HttpSocialRepository {
  int publishCalls = 0;
  bool shouldThrowOnPublish = false;
  final List<Map<String, dynamic>> postedPayloads = <Map<String, dynamic>>[];

  _CapturingSocialRepo() : super(isTestMode: true);

  @override
  Future<({String clipId, String shareUrl, DateTime publishedAt})> publishClip(
    Map<String, dynamic> payload,
  ) async {
    publishCalls++;
    if (shouldThrowOnPublish) {
      throw StateError('Simulated HTTP 500 publish failure');
    }
    return (
      clipId: 'clip_p84_real_1',
      shareUrl: 'https://vhunambi.com/@creator/reels/clip_p84_real_1',
      publishedAt: DateTime.now(),
    );
  }
}

void main() {
  setUp(() {
    SovereignMediaStorageService.clearTenantSessionMemory();
  });

  group('Phase 84: Media MIME, 401 Replay Safety, Reels Dedupe, KPost Uploads & Feed Hydration', () {
    test('inferMimeTypeFromMedia resolves PNG/WebP/MOV/FLAC/MP3 accurately', () {
      expect(inferMimeTypeFromMedia(filename: 'clip.MOV'), 'video/quicktime');
      expect(inferMimeTypeFromMedia(filename: 'art.PNG'), 'image/png');
      expect(inferMimeTypeFromMedia(filename: 'cover.webp'), 'image/webp');
      expect(inferMimeTypeFromMedia(filename: 'master.flac'), 'audio/flac');
      expect(
        inferMimeTypeFromMedia(
          filename: 'photo.jpg',
          declaredMime: 'image/jpg',
        ),
        'image/jpeg',
      );
    });

    test('SovereignApiClient 401 interceptor rebuilds binary payload via _p84BodyBuilder without FormData crash', () async {
      int attempt = 0;
      final dio = Dio();
      dio.httpClientAdapter = _StubHttpClientAdapter((opts) {
        attempt++;
        if (attempt == 1) {
          return ResponseBody.fromString('{"error":"expired"}', 401);
        }
        return ResponseBody.fromString('{"ok":true}', 200);
      });

      final client = SovereignApiClient(
        readSession: () => const SovereignAuthSession(
          userId: 'usr_cern',
          creatorId: 'creator_cern',
          handle: '@cern',
          displayName: 'Cern',
          email: 'cern@vhunambi.za',
          accessToken: 'expired_tok',
          refreshToken: 'valid_refresh',
          isGuest: false,
        ),
        refreshSession: () async => const SovereignAuthSession(
          userId: 'usr_cern',
          creatorId: 'creator_cern',
          handle: '@cern',
          displayName: 'Cern',
          email: 'cern@vhunambi.za',
          accessToken: 'fresh_tok',
          refreshToken: 'valid_refresh',
          isGuest: false,
        ),
      );
      dio.interceptors.add(client.buildDioInterceptor(retryDio: dio));

      final bytes = Uint8List.fromList(<int>[1, 2, 3, 4]);
      final res = await dio.post<String>(
        'https://api.vhunambi.test/api/media/upload',
        data: bytes,
        options: Options(extra: <String, dynamic>{'_p84BodyBuilder': () => bytes}),
      );
      expect(res.statusCode, 200);
      expect(attempt, 2);
    });

    test('HttpMediaUploadRepository falls back cleanly on 404 presign-put & hydrates ID3 fields', () async {
      final dio = Dio();
      dio.httpClientAdapter = _StubHttpClientAdapter((opts) {
        if (opts.path.endsWith('/media/presign-put')) {
          return ResponseBody.fromString(
            '{"error":"NOT_FOUND"}',
            404,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        }
        return ResponseBody.fromString(
          jsonEncode({
            'success': true,
            'key': 'media/creator_cern/upl_1.mp3',
            'url': '/r2/media/creator_cern/upl_1.mp3',
            'thumbnailUrl': '/r2/covers/creator_cern/upl_1.jpg',
            'id3Metadata': {
              'title': 'Mufunwa',
              'artist': 'Zania Venda',
              'genre': 'Afrobeats',
              'bpm': 118,
            },
            'asset': {
              'id': 'upl_1',
              'title': 'Mufunwa',
              'r2Key': 'media/creator_cern/upl_1.mp3',
              'remoteUrl': '/r2/media/creator_cern/upl_1.mp3',
              'thumbnailUrl': '/r2/covers/creator_cern/upl_1.jpg',
            },
          }),
          201,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      });

      final repo = HttpMediaUploadRepository(dio: dio, baseUrl: 'https://api.test/api');
      final synced = await repo.uploadMedia(
        staged: UploadedMediaAsset(
          id: 'upl_1',
          creatorId: 'creator_cern',
          kind: MediaAssetKind.audio,
          title: 'mufunwa',
          filename: 'mufunwa.mp3',
          mimeType: 'audio/mpeg',
          sizeBytes: 6,
          createdAt: DateTime.now(),
        ),
        bytes: Uint8List.fromList(<int>[0x49, 0x44, 0x33, 4, 0, 0]),
      );

      expect(synced.status, MediaUploadStatus.synced);
      expect(synced.title, 'Mufunwa');
      expect(synced.artist, 'Zania Venda');
      expect(synced.genre, 'Afrobeats');
      expect(synced.bpm, 118);
      expect(synced.thumbnailUrl, endsWith('/r2/covers/creator_cern/upl_1.jpg'));
    });

    testWidgets(
      'KineticReelPublishView reuses pre-staged audio without duplicate upload & surfaces publish errors',
      (tester) async {
        final uploadRepo = _CountingMediaUploadRepo();
        final socialRepo = _CapturingSocialRepo()..shouldThrowOnPublish = true;
        final container = ProviderContainer(
          overrides: [
            currentCreatorIdProvider.overrideWithValue('creator_cern'),
            customMediaUploadRepositoryProvider.overrideWithValue(uploadRepo),
            socialRepositoryProvider.overrideWithValue(socialRepo),
          ],
        );
        addTearDown(container.dispose);

        final preStaged = await container
            .read(mediaUploadQueueProvider.notifier)
            .stageAndEnqueue(
              bytes: Uint8List.fromList(<int>[0x49, 0x44, 0x33, 4, 0, 0]),
              filename: 'mulalo.mp3',
              mimeType: 'audio/mpeg',
              kind: MediaAssetKind.audio,
              title: 'Mulalo',
              awaitUpload: true,
            );
        expect(uploadRepo.uploadCalls, 1);

        bool completed = false;
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: KineticReelPublishView(
                audio: ReelStudioAudioSelection.fromUploadedAsset(preStaged),
                mediaKind: 'camera_photo',
                audioStartMs: 0,
                audioEndMs: 15000,
                effectPreset: 'none',
                effectIntensity: 0.0,
                typographyPreset: LyricTypographyPreset.kineticBounce,
                speedRate: 1.0,
                onBackToEditor: () {},
                onPublishComplete: () => completed = true,
              ),
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('reel_publish_submit_btn')));
        await tester.pump(const Duration(milliseconds: 200));

        // Zero duplicate upload & error card surfaced cleanly
        expect(uploadRepo.uploadCalls, 1);
        expect(completed, isFalse);
        expect(find.byKey(const Key('reel_publish_error_card')), findsOneWidget);
        expect(find.byKey(const Key('reel_publish_retry_btn')), findsOneWidget);
      },
    );

    testWidgets(
      'CreateKineticPostSheet renders kpost_upload_audio_btn, removes Vhunambi Sonic Groove mock & uploads audio cleanly',
      (tester) async {
        final uploadRepo = _CountingMediaUploadRepo();
        final container = ProviderContainer(
          overrides: [
            currentCreatorIdProvider.overrideWithValue('creator_cern'),
            customMediaUploadRepositoryProvider.overrideWithValue(uploadRepo),
          ],
        );
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
        await tester.pump(const Duration(milliseconds: 80));

        expect(find.text('Vhunambi Sonic Groove'), findsNothing);
        expect(find.text('Midnight Log Drum Pattern A'), findsNothing);

        final uploadAudioBtn = find.byKey(const Key('kpost_upload_audio_btn'));
        await tester.scrollUntilVisible(
          uploadAudioBtn,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        await tester.tap(uploadAudioBtn);
        await tester.pump(const Duration(milliseconds: 150));

        expect(uploadRepo.uploadCalls, 1);
        expect(find.text('No Track Attached'), findsNothing);
      },
    );

    test('SocialFeedPostsNotifier hydrates imageAttachment, imageAttachments, audioUrl & coverUrl', () {
      final notifier = SocialFeedPostsNotifier();
      final changed = notifier.mergeRemotePostsPayloadForTest(<Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'kpost_hydrated_1',
          'creatorId': 'creator_cern',
          'creatorName': 'Cern',
          'creatorHandle': '@cern',
          'caption': 'Fresh from Zania Music',
          'trackId': 'trk_1',
          'trackTitle': 'Muthu Wanga',
          'genre': 'Afrobeats',
          'audioUrl': '/r2/media/creator_cern/muthu.mp3',
          'coverUrl': '/r2/covers/creator_cern/muthu.jpg',
          'imageAttachments': <String>['/r2/media/creator_cern/photo1.jpg'],
        },
      ]);
      expect(changed, isTrue);
      final post = notifier.state.firstWhere((p) => p.id == 'kpost_hydrated_1');
      expect(post.imageAttachment, isNotNull);
      expect(post.imageAttachments.length, 1);
      expect(post.track.audioUrl, contains('/r2/media/creator_cern/muthu.mp3'));
      expect(post.track.coverUrl, contains('/r2/covers/creator_cern/muthu.jpg'));
    });
  });
}

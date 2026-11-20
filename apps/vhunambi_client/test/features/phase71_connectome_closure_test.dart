import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vhunambi_client/core/auth/sovereign_auth_session.dart';
import 'package:vhunambi_client/core/network/sovereign_api_client.dart';
import 'package:vhunambi_client/core/sync/sync_outbox_service.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/song_metadata_dna.dart';
import 'package:vhunambi_client/features/explore/data/repositories/http_explore_repository.dart';
import 'package:vhunambi_client/features/explore/domain/models/social_music_post.dart';
import 'package:vhunambi_client/features/explore/presentation/providers/explore_providers.dart';
import 'package:vhunambi_client/features/home/domain/models/creator_allowance_state.dart';
import 'package:vhunambi_client/features/home/presentation/providers/creator_allowance_provider.dart';
import 'package:vhunambi_client/features/notifications/data/repositories/http_notification_repository.dart';
import 'package:vhunambi_client/features/notifications/data/repositories/notification_repository.dart';
import 'package:vhunambi_client/features/notifications/domain/models/notification_entity.dart';
import 'package:vhunambi_client/features/notifications/domain/models/notification_enums.dart';
import 'package:vhunambi_client/features/social/data/repositories/http_social_repository.dart';
import 'package:vhunambi_client/features/social/domain/models/published_clip.dart';
import 'package:vhunambi_client/features/social/domain/models/reel_comment.dart';
import 'package:vhunambi_client/features/social/presentation/providers/reels_comments_provider.dart';
import 'package:vhunambi_client/features/social/presentation/providers/remix_lineage_provider.dart';
import 'package:vhunambi_client/features/social/presentation/widgets/remix_lineage_tree_sheet.dart';
import 'package:vhunambi_client/features/studio/data/services/fake_generation_socket_service.dart';
import 'package:vhunambi_client/features/studio/data/services/http_generation_submission_service.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/generation_pipeline_providers.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/studio_action_bar.dart';

class _RecordingDioAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) onRequest;
  final List<({String method, String path})> calls = [];

  _RecordingDioAdapter(this.onRequest);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add((method: options.method, path: options.path));
    return onRequest(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonBody(Map<String, dynamic> body, {int statusCode = 200}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('Phase 71 Group 1 (EP-P67-NOTIF-API): Bidirectional Cloud Notifications', () {
    test(
      'HttpNotificationRepository & NotificationsNotifier merge server alerts while preserving local isRead',
      () async {
        final recordedRequests = <String>[];
        final mockClient = http_testing.MockClient((request) async {
          recordedRequests.add('${request.method} ${request.url.path}');
          if (request.method == 'GET' &&
              request.url.path.endsWith('/notifications')) {
            return http.Response(
              jsonEncode(<String, dynamic>{
                'success': true,
                'notifications': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 'notif_gen_server_01',
                    'title': 'Studio Track Ready',
                    'body': 'Your Amapiano track finished rendering.',
                    'category': 'creatorActivity',
                    'subtype': 'studio_render',
                    'priority': 'high',
                    'isRead': false,
                    'targetRoute': '/track/gen_01',
                    'createdAt': '2026-11-20T01:00:00.000Z',
                  },
                  <String, dynamic>{
                    'id': 'notif_local_existing',
                    'title': 'Welcome',
                    'body': 'Already read locally',
                    'category': 'system',
                    'subtype': 'welcome',
                    'priority': 'normal',
                    'isRead': false,
                    'createdAt': '2026-11-19T12:00:00.000Z',
                  },
                ],
              }),
              200,
              headers: const <String, String>{'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode(<String, dynamic>{'success': true}),
            200,
            headers: const <String, String>{'content-type': 'application/json'},
          );
        });

        final apiClient = SovereignApiClient(
          httpClient: mockClient,
          readSession: () => SovereignAuthSession.guestDefault(),
          refreshSession: () async => null,
        );
        final remoteRepo = HttpNotificationRepository(
          apiClient: apiClient,
          isAuthenticated: () => true,
          isTestMode: true,
          hasCustomClient: true,
          apiRestBaseUrl: 'https://api.vhunambi.test/api',
        );

        final localSeed = NotificationEntity(
          id: 'notif_local_existing',
          title: 'Welcome',
          message: 'Already read locally',
          isRead: true,
          category: NotificationCategory.system,
          createdAt: DateTime.parse('2026-11-19T12:00:00.000Z'),
        );

        final notifier = NotificationsNotifier(
          <NotificationEntity>[localSeed],
          NotificationRepository(),
          remoteRepo,
        );
        await notifier.syncFromCloud();

        expect(notifier.state.length, 2);
        final serverAlert = notifier.state.firstWhere(
          (n) => n.id == 'notif_gen_server_01',
        );
        expect(serverAlert.message, 'Your Amapiano track finished rendering.');
        final preserved = notifier.state.firstWhere(
          (n) => n.id == 'notif_local_existing',
        );
        expect(preserved.isRead, isTrue);

        notifier.markAsRead('notif_gen_server_01');
        notifier.markAllAsRead();
        notifier.removeNotification('notif_local_existing');
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(recordedRequests, contains('GET /api/notifications'));
        expect(
          recordedRequests,
          contains('PATCH /api/notifications/notif_gen_server_01/read'),
        );
        expect(
          recordedRequests,
          contains('POST /api/notifications/mark-all-read'),
        );
        expect(
          recordedRequests,
          contains('DELETE /api/notifications/notif_local_existing'),
        );
      },
    );
  });

  group('Phase 71 Group 2 (EP-P69-POST-COSIGN-REPOST-HTTP): Direct HTTP + Offline Outbox Fallback', () {
    test(
      'HttpExploreRepository hits feed, cosign, repost & comment like endpoints and avoids double-increment',
      () async {
        var shouldFailHttp = false;
        final adapter = _RecordingDioAdapter((options) async {
          if (shouldFailHttp) {
            throw DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
              message: 'Offline',
            );
          }
          if (options.path.endsWith('/explore/feed')) {
            return _jsonBody(<String, dynamic>{
              'posts': <Map<String, dynamic>>[
                <String, dynamic>{'id': 'post_feed_1', 'cosignCount': 9},
              ],
            });
          }
          if (options.path.endsWith('/explore')) {
            return _jsonBody(<String, dynamic>{
              'tracks': <Map<String, dynamic>>[],
              'posts': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'post_001',
                  'likeCount': 2222,
                  'commentCount': 33,
                  'cosignCount': 19,
                  'repostCount': 27,
                },
              ],
              'serverSeq': 42,
            });
          }
          if (options.path.endsWith('/cosign')) {
            return _jsonBody(<String, dynamic>{
              'success': true,
              'cosignCount': 25,
              'discoveryStage': 'risingBreakout',
              'graduated': true,
            });
          }
          if (options.path.endsWith('/repost')) {
            return _jsonBody(<String, dynamic>{
              'success': true,
              'repostCount': 15,
            });
          }
          if (options.path.endsWith('/like')) {
            return _jsonBody(<String, dynamic>{
              'success': true,
              'liked': true,
              'likeCount': 1841,
            });
          }
          return _jsonBody(<String, dynamic>{'success': true}, statusCode: 201);
        });

        final dio = Dio()..httpClientAdapter = adapter;
        final repo = HttpExploreRepository(
          dio: dio,
          baseUrl: 'https://api.vhunambi.test/api',
          isTestMode: true,
        );
        final outbox = SyncOutboxService(isInMemoryOnly: true);

        final feed = await repo.fetchExploreFeed(stage: 'freshCrate');
        expect(feed.length, 1);
        expect(feed.first['id'], 'post_feed_1');

        final notifier = SocialFeedPostsNotifier(
          repository: repo,
          outbox: outbox,
        );

        // Online direct HTTP succeeds -> 0 outbox records & authoritative server counts applied
        notifier.toggleLike('post_001');
        notifier.cosignPost('post_001');
        notifier.repostPost(
          originalPostId: 'post_001',
          repostPost: SocialMusicPost(
            id: 'repost_p71_1',
            creatorId: 'creator_cern',
            creatorName: 'Cern',
            creatorHandle: '@cern',
            publishedAt: DateTime.now(),
            caption: 'Fire flip!',
            track: notifier.state.first.track,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 150));

        expect(outbox.getPending(), isEmpty);
        final updatedPost = notifier.state.firstWhere((p) => p.id == 'post_001');
        expect(updatedPost.likeCount, 1841);
        expect(updatedPost.cosignCount, 25);
        expect(updatedPost.repostCount, 15);

        // refreshFromCloud hydrates likeCount & commentCount too
        final refreshed = await notifier.refreshFromCloud();
        expect(refreshed, isTrue);
        final postAfterRefresh = notifier.state.firstWhere(
          (p) => p.id == 'post_001',
        );
        expect(postAfterRefresh.likeCount, 2222);
        expect(postAfterRefresh.commentCount, 33);

        // Offline fallback -> enqueues to outbox once
        shouldFailHttp = true;
        notifier.cosignPost('post_001');
        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(outbox.getPending().length, 1);
        expect(outbox.getPending().first.action, 'cosign');
      },
    );

    test(
      'ReelsCommentsNotifier.toggleCommentLike routes Kinetic Post comments to /api/explore/comments/:id/like',
      () async {
        final adapter = _RecordingDioAdapter((options) async {
          return _jsonBody(<String, dynamic>{
            'id': 'c_kpost_1',
            'liked': true,
            'likeCount': 12,
          });
        });
        final dio = Dio()..httpClientAdapter = adapter;
        final exploreRepo = HttpExploreRepository(
          dio: dio,
          baseUrl: 'https://api.vhunambi.test/api',
          isTestMode: true,
        );

        final container = ProviderContainer(
          overrides: <Override>[
            exploreRepositoryProvider.overrideWithValue(exploreRepo),
          ],
        );
        addTearDown(container.dispose);

        final commentsNotifier = container.read(reelsCommentsProvider.notifier);
        commentsNotifier.state = ReelsCommentsState(
          commentsByClipId: <String, List<ReelComment>>{
            'post_001': <ReelComment>[
              ReelComment(
                id: 'c_kpost_1',
                clipId: 'post_001',
                userId: 'creator_thabo',
                username: 'thabo',
                displayName: 'Thabo',
                text: 'Clean bass!',
                likeCount: 11,
                createdAt: DateTime.now(),
              ),
            ],
          },
        );

        commentsNotifier.toggleCommentLike(
          clipId: 'post_001',
          commentId: 'c_kpost_1',
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(
          adapter.calls.any(
            (c) =>
                c.method == 'POST' &&
                c.path.endsWith('/explore/comments/c_kpost_1/like'),
          ),
          isTrue,
        );
      },
    );
  });

  group('Phase 71 Group 3 (EP-P37-REMIX-TREE-API): Live Remix Lineage Graph', () {
    test('HttpSocialRepository.getClipRemixes parses backend remix children', () async {
      final adapter = _RecordingDioAdapter((options) async {
        return _jsonBody(<String, dynamic>{
          'clipId': 'clip_root_1',
          'count': 1,
          'remixes': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'clip_remote_child_1',
              'trackId': 'trk_remote_child_1',
              'creatorId': 'creator_thabo',
              'creatorUsername': 'thabo_beats',
              'creatorDisplayName': 'Thabo Beats',
              'title': 'Soweto Log Drum Flip',
              'genre': 'Amapiano',
              'audioUrl': 'https://r2.vhunambi.com/audio/flip.wav',
              'coverUrl': 'https://r2.vhunambi.com/covers/flip.png',
              'remixedFromClipId': 'clip_root_1',
              'publishedAt': '2026-11-20T00:00:00.000Z',
            },
          ],
        });
      });
      final dio = Dio()..httpClientAdapter = adapter;
      final socialRepo = HttpSocialRepository(
        dio: dio,
        baseUrl: 'https://api.vhunambi.test/api',
        isTestMode: true,
      );

      final remixes = await socialRepo.getClipRemixes('clip_root_1');
      expect(remixes.length, 1);
      expect(remixes.first.id, 'clip_remote_child_1');
      expect(remixes.first.title, 'Soweto Log Drum Flip');
    });

    testWidgets(
      'RemixLineageTreeSheet renders merged live remote remix descendants',
      (tester) async {
        final remoteClip = PublishedClip(
          id: 'clip_remote_child_1',
          trackId: 'trk_remote_child_1',
          creatorId: 'creator_thabo',
          creatorUsername: 'thabo_beats',
          creatorDisplayName: 'Thabo Beats',
          title: 'Soweto Log Drum Flip',
          genre: 'Amapiano',
          audioUrl: 'https://r2.vhunambi.com/audio/flip.wav',
          coverUrl: 'https://r2.vhunambi.com/covers/flip.png',
          dna: SongMetadataDna.fromTrackInfo(
            id: 'trk_remote_child_1',
            title: 'Soweto Log Drum Flip',
            genre: 'Amapiano',
            language: 'isiZulu',
            durationSec: 180,
          ),
          publishedAt: DateTime.now(),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              remixLineageRemoteChildrenProvider('post_001').overrideWith(
                (ref) async => <PublishedClip>[remoteClip],
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: Scaffold(
                body: RemixLineageTreeSheet(
                  trackOrClipId: 'post_001',
                  clip: remoteClip,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Soweto Log Drum Flip'), findsOneWidget);
        expect(find.text('@thabo_beats'), findsOneWidget);
      },
    );
  });

  group('Phase 71 Group 4 (EP-P68-CREATOR-ALLOWANCE): Studio & Upgrade Modal Quota', () {
    testWidgets(
      'StudioActionBar shows studio_allowance_chip (0 stock Icons.*) and opens SubscriptionUpgradeModal',
      (tester) async {
        final fakeAllowance = CreatorAllowanceNotifier.withInitial(
          const CreatorAllowanceState(
            creatorId: 'creator_cern',
            freeMonthlySongsLimit: 10,
            freeMonthlySongsUsed: 3,
            freeMonthlySongsRemaining: 7,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              creatorAllowanceProvider.overrideWith((ref) => fakeAllowance),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const Scaffold(
                body: Padding(
                  padding: EdgeInsets.all(16),
                  child: StudioActionBar(),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byKey(const Key('studio_allowance_chip')), findsOneWidget);
        expect(find.text('7/10 Free Songs'), findsOneWidget);
        expect(find.byType(Icon), findsNothing);

        await tester.tap(find.byKey(const Key('studio_allowance_chip')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(
          find.byKey(const Key('upgrade_modal_allowance_card')),
          findsOneWidget,
        );
        expect(find.text('7/10 Left'), findsOneWidget);
      },
    );

    test(
      'GenerationPipelineNotifier invokes consumeOneSongOptimistically on successful dispatch',
      () async {
        final fakeAllowance = CreatorAllowanceNotifier.withInitial(
          const CreatorAllowanceState(
            creatorId: 'creator_cern',
            freeMonthlySongsLimit: 10,
            freeMonthlySongsUsed: 0,
            freeMonthlySongsRemaining: 10,
          ),
        );

        final container = ProviderContainer(
          overrides: <Override>[
            creatorAllowanceProvider.overrideWith((ref) => fakeAllowance),
            generationSubmissionServiceProvider.overrideWithValue(
              HttpGenerationSubmissionService(isTestMode: true),
            ),
            socketServiceProvider.overrideWithValue(
              FakeGenerationSocketService(stepDelay: Duration.zero),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(generationProgressProvider.notifier)
            .submitAndStartGeneration(
              trackTitle: 'Venda Sunrise',
              genre: 'Amapiano',
              language: 've',
              isInstrumental: true,
            );

        expect(container.read(creatorAllowanceProvider).freeMonthlySongsUsed, 1);
        expect(
          container.read(creatorAllowanceProvider).freeMonthlySongsRemaining,
          9,
        );
      },
    );
  });
}

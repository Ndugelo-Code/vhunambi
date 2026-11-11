import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/sync/sync_outbox_service.dart';
import 'package:vhunambi_client/features/explore/data/repositories/http_explore_repository.dart';
import 'package:vhunambi_client/features/explore/presentation/providers/explore_providers.dart';
import 'package:vhunambi_client/features/player/domain/models/stem_mixer_state.dart';
import 'package:vhunambi_client/shared/models/track.dart';

typedef _MockHandler = Future<ResponseBody> Function(RequestOptions options);

class _StubHttpClientAdapter implements HttpClientAdapter {
  _StubHttpClientAdapter(this._handler);

  final _MockHandler _handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return _handler(options);
  }
}

ResponseBody _jsonResponse(Map<String, dynamic> body, {int statusCode = 200}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

void main() {
  group('Phase 59 M59.2: Track Serialization & HttpExploreRepository', () {
    test('Track toJson/fromJson round-trip preserves stems and provenance', () {
      const original = Track(
        id: 'trk_roundtrip_1',
        title: 'Thohoyandou Bounce',
        creatorName: 'Makhadzi Wave',
        genre: 'Lekompo',
        language: 'Tshivenḓa',
        duration: Duration(minutes: 3, seconds: 25),
        audioUrl: 'https://cdn.vhunambi.za/audio/thohoyandou.mp3',
        coverUrl: 'https://cdn.vhunambi.za/covers/thohoyandou.jpg',
        likeCount: 512,
        playCount: 4200,
        isNew: true,
        trendingRank: 2,
        mood: 'Energetic',
        creatorHandle: '@makhadzi_wave',
        stemUrls: <StemType, String>{
          StemType.vocals: 'https://cdn.vhunambi.za/stems/vocals.wav',
          StemType.drums: 'https://cdn.vhunambi.za/stems/drums.wav',
          StemType.bass: 'https://cdn.vhunambi.za/stems/bass.wav',
          StemType.melody: 'https://cdn.vhunambi.za/stems/melody.wav',
        },
        provenanceType: AudioProvenanceType.liveVocalRecording,
      );

      final encoded = original.toJson();
      final decoded = Track.fromJson(encoded);

      expect(decoded.id, original.id);
      expect(decoded.title, original.title);
      expect(decoded.creatorName, original.creatorName);
      expect(decoded.genre, original.genre);
      expect(decoded.language, original.language);
      expect(decoded.duration, original.duration);
      expect(decoded.audioUrl, original.audioUrl);
      expect(decoded.coverUrl, original.coverUrl);
      expect(decoded.likeCount, original.likeCount);
      expect(decoded.playCount, original.playCount);
      expect(decoded.isNew, isTrue);
      expect(decoded.trendingRank, 2);
      expect(decoded.mood, 'Energetic');
      expect(decoded.creatorHandle, '@makhadzi_wave');
      expect(decoded.hasRealStems, isTrue);
      expect(decoded.provenanceType, AudioProvenanceType.liveVocalRecording);

      final copied = decoded.copyWith(title: 'Updated Mix', likeCount: 600);
      expect(copied.title, 'Updated Mix');
      expect(copied.likeCount, 600);
      expect(copied.genre, 'Lekompo');
    });

    test('Track.fromJson parses backend snake_case payload cleanly', () {
      final parsed = Track.fromJson(<String, dynamic>{
        'id': 'trk_cloud_99',
        'title': 'Venda Log Drum',
        'artist_name': 'Ndugelo',
        'genre': 'Amapiano',
        'duration_ms': 210000,
        'audio_url': 'https://cdn.vhunambi.za/audio/venda.mp3',
        'likesCount': 880,
        'playsCount': 9100,
        'creator_handle': '@ndugelo',
        'provenanceType': 'humanCreated',
      });

      expect(parsed.id, 'trk_cloud_99');
      expect(parsed.creatorName, 'Ndugelo');
      expect(parsed.duration, const Duration(milliseconds: 210000));
      expect(parsed.likeCount, 880);
      expect(parsed.playCount, 9100);
      expect(parsed.handleLabel, '@ndugelo');
      expect(parsed.provenanceType, AudioProvenanceType.humanDawMaster);
    });

    test(
      'HttpExploreRepository fetches bundle, tracks, radio & publishes track',
      () async {
        final capturedPaths = <String>[];
        final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000/api'));
        dio.httpClientAdapter = _StubHttpClientAdapter((options) async {
          capturedPaths.add('${options.method} ${options.path}');
          if (options.path.endsWith('/explore')) {
            return _jsonResponse(<String, dynamic>{
              'success': true,
              'serverSeq': 42,
              'tracks': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'trk_cloud_1',
                  'title': 'Sovereign Groove',
                  'artist': 'Kabza Spirit',
                  'genre': 'Amapiano',
                  'durationMs': 225000,
                  'likesCount': 1420,
                  'playsCount': 14800,
                },
              ],
              'posts': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'post_cloud_1',
                  'creatorId': 'creator_sigwa',
                  'creatorName': 'Sigwa',
                  'creatorHandle': '@sigwa',
                  'caption': 'Live from Soweto',
                  'cosignCount': 22,
                  'repostCount': 5,
                },
              ],
              'radio': <String, dynamic>{
                'genre': 'Amapiano',
                'stationTitle': 'Amapiano Sovereign Radio Rotation',
                'description': 'Anchored around 113 BPM',
                'seedBpm': 113.0,
                'rotation': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 'trk_cloud_1',
                    'title': 'Sovereign Groove',
                    'artist': 'Kabza Spirit',
                    'genre': 'Amapiano',
                    'durationMs': 225000,
                  },
                ],
              },
            });
          }
          if (options.path.endsWith('/explore/tracks') &&
              options.method == 'GET') {
            return _jsonResponse(<String, dynamic>{
              'success': true,
              'items': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'trk_cloud_2',
                  'title': 'Tzaneen Sun',
                  'artist': 'Kharishma Wave',
                  'genre': 'Lekompo',
                  'durationMs': 198000,
                },
              ],
            });
          }
          if (options.path.contains('/explore/radio/')) {
            return _jsonResponse(<String, dynamic>{
              'genre': 'Lekompo',
              'stationTitle': 'Lekompo Sovereign Radio',
              'description': 'Bolobedu rotation',
              'seedBpm': 116.0,
              'rotation': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'trk_cloud_2',
                  'title': 'Tzaneen Sun',
                  'artist': 'Kharishma Wave',
                  'genre': 'Lekompo',
                  'durationMs': 198000,
                },
              ],
            });
          }
          if (options.path.endsWith('/explore/tracks') &&
              options.method == 'POST') {
            return _jsonResponse(<String, dynamic>{
              'success': true,
              'track': <String, dynamic>{
                ...options.data as Map<String, dynamic>,
                'trendingRank': 4,
              },
            }, statusCode: 201);
          }
          return _jsonResponse(<String, dynamic>{
            'error': 'not found',
          }, statusCode: 404);
        });

        final repo = HttpExploreRepository(
          dio: dio,
          baseUrl: 'http://localhost:3000/api',
        );

        final bundle = await repo.fetchExploreBundle(genre: 'Amapiano');
        expect(bundle.isFromCloud, isTrue);
        expect(bundle.serverSeq, 42);
        expect(bundle.tracks.single.id, 'trk_cloud_1');
        expect(bundle.posts.single['id'], 'post_cloud_1');
        expect(bundle.radio?.seedBpm, 113.0);

        final tracks = await repo.fetchExploreTracks(
          genre: 'Lekompo',
          sort: 'trending',
        );
        expect(tracks.single.title, 'Tzaneen Sun');

        final radio = await repo.fetchGenreRadio('Lekompo');
        expect(radio?.stationTitle, 'Lekompo Sovereign Radio');
        expect(radio?.rotation.single.id, 'trk_cloud_2');

        const draftTrack = Track(
          id: 'trk_pub_1',
          title: 'Polokwane Rush',
          creatorName: 'Ndugelo',
          genre: 'Lekompo',
          duration: Duration(minutes: 3),
        );
        final published = await repo.publishTrack(draftTrack);
        expect(published?.trendingRank, 4);
        expect(capturedPaths.length, 4);
      },
    );

    test(
      'ExploreTracksNotifier & SocialFeedPostsNotifier hydrate & enqueue outbox',
      () async {
        final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000/api'));
        dio.httpClientAdapter = _StubHttpClientAdapter((options) async {
          if (options.path.endsWith('/explore')) {
            return _jsonResponse(<String, dynamic>{
              'tracks': const <dynamic>[],
              'posts': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'post_remote_88',
                  'creatorId': 'creator_makhadzi',
                  'creatorName': 'Makhadzi',
                  'creatorHandle': '@makhadzi',
                  'caption': 'New studio heat dropping Friday',
                  'cosignCount': 19,
                  'repostCount': 4,
                  'createdAt': DateTime.now().toIso8601String(),
                },
              ],
            });
          }
          if (options.path.endsWith('/explore/tracks') &&
              options.method == 'GET') {
            return _jsonResponse(<String, dynamic>{
              'items': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'trk_cloud_101',
                  'title': 'Durban 3-Step Horizon',
                  'artist': 'Dlala Thukzin',
                  'genre': '3-Step',
                  'durationMs': 252000,
                },
              ],
            });
          }
          if (options.path.endsWith('/explore/tracks') &&
              options.method == 'POST') {
            return _jsonResponse(<String, dynamic>{
              'success': true,
              'track': options.data,
            }, statusCode: 201);
          }
          return _jsonResponse(<String, dynamic>{});
        });

        final repo = HttpExploreRepository(
          dio: dio,
          baseUrl: 'http://localhost:3000/api',
        );
        final outbox = SyncOutboxService(isInMemoryOnly: true);
        await outbox.init();

        final tracksNotifier = ExploreTracksNotifier(
          repository: repo,
          outbox: outbox,
        );
        expect(tracksNotifier.state.length, 8);

        final hydrated = await tracksNotifier.refreshFromCloud();
        expect(hydrated, isTrue);
        expect(tracksNotifier.state.length, 9);
        expect(tracksNotifier.state.first.id, 'trk_cloud_101');

        const newDrop = Track(
          id: 'trk_local_pub_9',
          title: 'Pretoria Nightfall',
          creatorName: 'Ndugelo',
          genre: 'Amapiano',
          duration: Duration(minutes: 4),
        );
        await tracksNotifier.publishTrackToCloud(newDrop);
        expect(
          outbox.getPendingMutations().any(
            (m) => m.entityType == 'track' && m.action == 'create',
          ),
          isTrue,
        );

        final postsNotifier = SocialFeedPostsNotifier(
          outbox: outbox,
          repository: repo,
        );
        final initialCount = postsNotifier.state.length;
        final postsOk = await postsNotifier.refreshFromCloud();
        expect(postsOk, isTrue);
        expect(postsNotifier.state.length, initialCount + 1);
        expect(postsNotifier.state.first.id, 'post_remote_88');
      },
    );

    test(
      'exploreGenreRadioProvider falls back seamlessly to local catalog offline',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final station = await container.read(
          exploreGenreRadioProvider('Amapiano').future,
        );
        expect(station.genre, 'Amapiano');
        expect(station.rotation.length, 3);
        expect(
          station.rotation.every((t) => t.genre.toLowerCase() == 'amapiano'),
          isTrue,
        );
      },
    );
  });
}

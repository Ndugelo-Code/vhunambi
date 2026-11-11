import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/content_studio/data/services/cloud_video_export_service.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/content_studio_preset.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/lyric_word_timestamp.dart';
import 'package:vhunambi_client/features/content_studio/presentation/providers/master_media_object_provider.dart';
import 'package:vhunambi_client/features/home/presentation/widgets/subscription_upgrade_modal.dart';
import 'package:vhunambi_client/features/library/presentation/providers/library_providers.dart';
import 'package:vhunambi_client/features/player/domain/models/stem_mixer_state.dart';
import 'package:vhunambi_client/features/player/domain/services/i_multi_stem_audio_engine.dart';
import 'package:vhunambi_client/features/player/presentation/providers/multi_stem_audio_provider.dart';
import 'package:vhunambi_client/features/player/presentation/providers/player_provider.dart';
import 'package:vhunambi_client/features/player/presentation/providers/stem_mixer_provider.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/cloud_stack_diagnostic_card.dart';
import 'package:vhunambi_client/features/social/data/repositories/http_social_repository.dart';
import 'package:vhunambi_client/features/social/presentation/providers/creator_wallet_provider.dart';
import 'package:vhunambi_client/features/social/presentation/providers/social_repository_provider.dart';
import 'package:vhunambi_client/features/studio/data/services/fake_generation_socket_service.dart';
import 'package:vhunambi_client/features/studio/data/services/fake_stem_download_service.dart';
import 'package:vhunambi_client/features/studio/data/services/http_generation_submission_service.dart';
import 'package:vhunambi_client/features/studio/domain/models/studio_form_state.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/generation_pipeline_providers.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/mycelium_biome_provider.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/stem_download_provider.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/studio_form_provider.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/lyrics_review_modal.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/studio_action_bar.dart';
import 'package:vhunambi_client/features/track/domain/models/track_entity.dart';

typedef _MockDioHandler =
    Future<ResponseBody> Function(RequestOptions options);

class _StubDioAdapter implements HttpClientAdapter {
  _StubDioAdapter(this._handler);

  final _MockDioHandler _handler;

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

ResponseBody _jsonResponse(
  Map<String, dynamic> body, {
  int statusCode = 200,
}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

class _RecordingMultiStemEngine implements IMultiStemAudioEngine {
  final StreamController<bool> _playingController =
      StreamController<bool>.broadcast();
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();

  Map<StemType, String> loadedStemUrls = <StemType, String>{};
  String? loadedMasterUrl;
  bool _isPlaying = false;
  bool disposed = false;

  @override
  Stream<bool> get isPlayingStream => _playingController.stream;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Duration get currentPosition => Duration.zero;

  @override
  Duration get totalDuration => const Duration(minutes: 3, seconds: 30);

  @override
  bool get isPlaying => _isPlaying;

  @override
  bool get hasRealStems => loadedStemUrls.length == 4;

  @override
  Duration? get measuredDrift => Duration.zero;

  @override
  Future<void> loadFromManifest({
    required Map<StemType, String> stemUrls,
    required String masterUrl,
  }) async {
    loadedStemUrls = Map<StemType, String>.from(stemUrls);
    loadedMasterUrl = masterUrl;
  }

  @override
  Future<void> play() async {
    _isPlaying = true;
  }

  @override
  Future<void> pause() async {
    _isPlaying = false;
  }

  @override
  Future<void> seek(Duration position) async {}

  @override
  void applyMixerState(StemMixerState state) {}

  @override
  Future<void> dispose() async {
    disposed = true;
    await _playingController.close();
    await _positionController.close();
  }
}

TrackEntity _sampleCompletedTrack({
  String id = 'trk_cockpit_63',
  String title = 'Venda Night Groove',
}) {
  return TrackEntity(
    id: id,
    title: title,
    genre: 'Amapiano',
    language: 'Tshivenḓa',
    duration: const Duration(seconds: 210),
    masterMp3Url: 'https://r2.vhunambi.com/audio/$id/master.mp3',
    stemsUrl: 'https://r2.vhunambi.com/audio/$id/stems.zip',
    coverUrl: '/mock-storage/covers/$id.png',
    lyrics: '[Verse 1]\nRi tshi imbela vhufa',
    stemUrls: <StemType, String>{
      StemType.vocals: 'https://r2.vhunambi.com/audio/$id/vocals.mp3',
      StemType.drums: 'https://r2.vhunambi.com/audio/$id/drums.mp3',
      StemType.bass: 'https://r2.vhunambi.com/audio/$id/bass.mp3',
      StemType.melody: 'https://r2.vhunambi.com/audio/$id/melody.mp3',
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async => null,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('Phase 63 M63.2 (G-63-03): Studio Submission, Dual-Dialect WS & Cockpit Hydration', () {
    testWidgets(
      'StudioActionBar instrumental mode submits directly without opening LyricsReviewModal',
      (tester) async {
        final recordingEngine = _RecordingMultiStemEngine();
        final socket = FakeGenerationSocketService(
          stepDelay: Duration.zero,
          completedTrack: _sampleCompletedTrack(
            id: 'trk_instr_63',
            title: 'Limpopo Log Drum Instrumentals',
          ),
        );

        final container = ProviderContainer(
          overrides: <Override>[
            socketServiceProvider.overrideWithValue(socket),
            stemDownloadServiceProvider.overrideWithValue(
              FakeStemDownloadService(stepDelay: Duration.zero),
            ),
            multiStemAudioEngineProvider.overrideWithValue(recordingEngine),
          ],
        );

        final formNotifier = container.read(studioFormProvider.notifier);
        formNotifier.toggleInstrumental(true);
        formNotifier.setTempo(TempoBracket.fast);
        formNotifier.updatePrompt('Limpopo Log Drum Instrumental Sketch');

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const Scaffold(body: Center(child: StudioActionBar())),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Generate Song'), findsOneWidget);
        await tester.tap(find.text('Generate Song'));
        for (var i = 0; i < 8; i++) {
          await tester.pump(Duration.zero);
        }

        expect(find.byType(LyricsReviewModal), findsNothing);
        expect(container.read(studioFormProvider).phase, GenerationPhase.queued);
        expect(socket.connectCount, greaterThanOrEqualTo(1));
        expect(
          container.read(generationProgressProvider)?.currentStep,
          PipelineStep.ready,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        container.read(playerStateProvider.notifier).dismiss();
        await tester.pump();
        container.dispose();
      },
    );

    testWidgets(
      'StudioActionBar custom-lyrics mode submits directly without opening LyricsReviewModal',
      (tester) async {
        final recordingEngine = _RecordingMultiStemEngine();
        final socket = FakeGenerationSocketService(
          stepDelay: Duration.zero,
          completedTrack: _sampleCompletedTrack(
            id: 'trk_custom_lyr_63',
            title: 'My Own Stanzas',
          ),
        );

        final container = ProviderContainer(
          overrides: <Override>[
            socketServiceProvider.overrideWithValue(socket),
            stemDownloadServiceProvider.overrideWithValue(
              FakeStemDownloadService(stepDelay: Duration.zero),
            ),
            multiStemAudioEngineProvider.overrideWithValue(recordingEngine),
          ],
        );

        final formNotifier = container.read(studioFormProvider.notifier);
        formNotifier.toggleInstrumental(false);
        formNotifier.setLyricsMode(LyricsMode.myOwn);
        formNotifier.setCustomLyrics('[Verse 1]\nVhunambi ndi nungo');
        formNotifier.setTempo(TempoBracket.fast);
        formNotifier.updatePrompt('Custom Vocal Session');

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const Scaffold(body: Center(child: StudioActionBar())),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Generate Song'), findsOneWidget);
        expect(find.text('Write Lyrics First'), findsNothing);
        await tester.tap(find.text('Generate Song'));
        for (var i = 0; i < 8; i++) {
          await tester.pump(Duration.zero);
        }

        expect(find.byType(LyricsReviewModal), findsNothing);
        expect(socket.connectCount, greaterThanOrEqualTo(1));
        expect(
          container.read(generationProgressProvider)?.currentStep,
          PipelineStep.ready,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        container.read(playerStateProvider.notifier).dismiss();
        await tester.pump();
        container.dispose();
      },
    );

    test(
      'HttpGenerationSubmissionService forwards tempoBpm, musicalKey, referenceAudioUrl & pregenStemLocks',
      () async {
        Map<String, dynamic>? capturedPayload;
        final dio = Dio();
        dio.httpClientAdapter = _StubDioAdapter((options) async {
          capturedPayload = Map<String, dynamic>.from(options.data as Map);
          return _jsonResponse(<String, dynamic>{
            'success': true,
            'generationId': 'gen_http_63',
            'status': 'queued',
          });
        });
        final submissionService = HttpGenerationSubmissionService(
          dio: dio,
          baseUrl: 'https://api.vhunambi.com/v1',
          isTestMode: false,
        );
        final res = await submissionService.submitGeneration(
          trackTitle: 'Custom Vocal Session',
          genre: 'Amapiano',
          language: 'Tshivenḓa',
          lyrics: '[Verse 1]\nVhunambi ndi nungo',
          isInstrumental: false,
          tempoBpm: 124,
          musicalKey: 'D Minor',
          selectedVoiceId: 'venda_folk_elder',
          referenceAudioUrl:
              'https://api.vhunambi.com/r2/sketchpad-refs/ref1.wav',
          pregenStemLocks: const <String, String>{'drums': 'lockedPure44k'},
        );
        expect(res['generationId'], equals('gen_http_63'));
        expect(capturedPayload?['tempoBpm'], equals(124));
        expect(capturedPayload?['musicalKey'], equals('D Minor'));
        expect(
          capturedPayload?['referenceAudioUrl'],
          equals('https://api.vhunambi.com/r2/sketchpad-refs/ref1.wav'),
        );
        expect(
          capturedPayload?['pregenStemLocks'],
          equals(<String, dynamic>{'drums': 'lockedPure44k'}),
        );
      },
    );

    test(
      'PipelineSocketEvent.fromJson & stepFromString decode both DO camelCase and legacy snake_case frames',
      () {
        for (final intermediate in const [
          'queued',
          'in_queue',
          'synthesizing',
          'separating_stems',
          'uploading',
          'mastering',
          'in_progress',
        ]) {
          expect(
            PipelineSocketEvent.stepFromString(intermediate),
            isNot(PipelineStep.failed),
            reason: '$intermediate must never collapse into PipelineStep.failed',
          );
        }

        final synthCamel = PipelineSocketEvent.fromJson(<String, dynamic>{
          'generationId': 'gen_do_1',
          'status': 'synthesizing',
          'progressPct': 50,
        });
        expect(synthCamel.generationId, equals('gen_do_1'));
        expect(synthCamel.step, equals(PipelineStep.producingBeat));
        expect(synthCamel.stepIndex, equals(3));
        expect(synthCamel.progressPercent, closeTo(0.5, 0.001));

        final stemsCamel = PipelineSocketEvent.fromJson(<String, dynamic>{
          'generationId': 'gen_do_1',
          'status': 'separating_stems',
          'progressPct': 82,
        });
        expect(stemsCamel.step, equals(PipelineStep.producingBeat));
        expect(stemsCamel.progressPercent, closeTo(0.82, 0.001));

        final readyCamel = PipelineSocketEvent.fromJson(<String, dynamic>{
          'generationId': 'gen_do_1',
          'status': 'completed',
          'progressPct': 100,
          'trackTitle': 'DO Master',
          'genre': 'Amapiano',
          'masterMp3Url': 'https://r2.vhunambi.com/audio/gen_do_1/master.mp3',
          'stemsZipUrl': 'https://r2.vhunambi.com/audio/gen_do_1/stems.zip',
          'stemUrls': <String, String>{
            'vocals': 'https://r2.vhunambi.com/audio/gen_do_1/vocals.mp3',
            'drums': 'https://r2.vhunambi.com/audio/gen_do_1/drums.mp3',
            'bass': 'https://r2.vhunambi.com/audio/gen_do_1/bass.mp3',
            'melodic': 'https://r2.vhunambi.com/audio/gen_do_1/melody.mp3',
          },
          'durationSec': 195,
        });
        expect(readyCamel.step, equals(PipelineStep.ready));
        expect(readyCamel.stepIndex, equals(4));
        expect(readyCamel.progressPercent, closeTo(1.0, 0.001));
        expect(readyCamel.completedTrack, isNotNull);
        expect(readyCamel.completedTrack!.hasRealStems, isTrue);
        expect(readyCamel.completedTrack!.duration.inSeconds, equals(195));

        final readySnake = PipelineSocketEvent.fromJson(<String, dynamic>{
          'generation_id': 'gen_snk_1',
          'step': 'ready',
          'step_index': 4,
          'progress_percent': 1.0,
          'status_message': 'Done',
          'completed_track': <String, dynamic>{
            'id': 'gen_snk_1',
            'title': 'Snake Master',
            'genre': 'Gqom',
            'duration_seconds': 180,
            'master_mp3_url': 'https://r2.vhunambi.com/audio/snk/master.mp3',
          },
        });
        expect(readySnake.generationId, equals('gen_snk_1'));
        expect(readySnake.step, equals(PipelineStep.ready));
        expect(readySnake.completedTrack?.title, equals('Snake Master'));
      },
    );

    testWidgets(
      '_onGenerationComplete normalizes R2 URLs and hydrates Library, MMO, 4-Stem Mixer, MultiStemEngine & Biome',
      (tester) async {
        final recordingEngine = _RecordingMultiStemEngine();
        final completed = _sampleCompletedTrack();
        final container = ProviderContainer(
          overrides: <Override>[
            socketServiceProvider.overrideWithValue(
              FakeGenerationSocketService(
                stepDelay: Duration.zero,
                completedTrack: completed,
              ),
            ),
            stemDownloadServiceProvider.overrideWithValue(
              FakeStemDownloadService(stepDelay: Duration.zero),
            ),
            multiStemAudioEngineProvider.overrideWithValue(recordingEngine),
          ],
        );

        // Pre-warm dependent cockpit providers so state updates stay alive.
        container.read(libraryTracksProvider);
        container.read(stemMixerProvider);
        container.read(myceliumBiomeGraphProvider);

        await container
            .read(generationProgressProvider.notifier)
            .submitAndStartGeneration(
              trackTitle: completed.title,
              genre: completed.genre,
              language: completed.language,
              isInstrumental: false,
            );

        for (var i = 0; i < 8; i++) {
          await tester.pump(Duration.zero);
        }

        final progress = container.read(generationProgressProvider);
        expect(progress?.currentStep, equals(PipelineStep.ready));

        // Library Vault contains normalized cloud URLs
        final libTracks = container.read(libraryTracksProvider);
        final added = libTracks.firstWhere((t) => t.id == completed.id);
        final expectedMasterUrl = AppConstants.normalizeCloudMediaUrl(
          completed.masterMp3Url,
        );
        final expectedCoverUrl = AppConstants.normalizeCloudMediaUrl(
          completed.coverUrl!,
        );
        expect(added.remoteAudioUrl, equals(expectedMasterUrl));
        expect(added.remoteAudioUrl, isNot(contains('r2.vhunambi.com')));
        expect(added.coverImageUrl, equals(expectedCoverUrl));
        expect(added.stemPaths.length, equals(4));

        // MasterMediaObject hydrated for normalized DNA
        final normalizedDna = completed
            .copyWith(masterMp3Url: expectedMasterUrl, coverUrl: expectedCoverUrl)
            .toSongMetadataDna();
        final mmo = container.read(masterMediaObjectProvider(normalizedDna));
        expect(mmo.masterMp3Url, equals(expectedMasterUrl));
        expect(mmo.stemUrls.length, equals(4));

        // StemMixer & MultiStemAudioEngine loaded all 4 normalized stems
        expect(
          container.read(stemMixerProvider).activeTrackId,
          equals(completed.id),
        );
        expect(recordingEngine.hasRealStems, isTrue);
        expect(recordingEngine.loadedMasterUrl, equals(expectedMasterUrl));

        // Mycelium Biome remains coherent
        expect(container.read(myceliumBiomeGraphProvider).clusters, isNotEmpty);

        container.read(playerStateProvider.notifier).dismiss();
        await tester.pump();
        container.dispose();
      },
    );
  });

  group('Phase 63 M63.3 (G-63-04): PayFast SKUs, Zero Emojis & Wallet Coin Sync', () {
    testWidgets(
      'SubscriptionUpgradeModal displays canonical 500/R55, 1500/R150, 5000/R450 SKUs & zero raw emojis',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const Scaffold(body: SubscriptionUpgradeModal()),
            ),
          ),
        );
        await tester.pump();

        expect(find.byKey(const Key('coin_topup_pack_500')), findsOneWidget);
        expect(find.byKey(const Key('coin_topup_pack_1500')), findsOneWidget);
        expect(find.byKey(const Key('coin_topup_pack_5000')), findsOneWidget);
        expect(find.text('500'), findsOneWidget);
        expect(find.text('R55'), findsOneWidget);
        expect(find.text('1500'), findsOneWidget);
        expect(find.text('R150'), findsOneWidget);
        expect(find.text('5000'), findsOneWidget);
        expect(find.text('R450'), findsOneWidget);

        // STD-UIUX-001 zero raw Unicode emoji enforcement across touched Phase 63 widgets
        final emojiRegex = RegExp(
          r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
          unicode: true,
        );
        for (final relPath in const [
          'lib/features/home/presentation/widgets/subscription_upgrade_modal.dart',
          'lib/features/profile/presentation/widgets/cloud_stack_diagnostic_card.dart',
          'lib/features/explore/presentation/widgets/create_kinetic_post_sheet.dart',
        ]) {
          final file = File(relPath);
          expect(file.existsSync(), isTrue, reason: 'Missing $relPath');
          expect(
            emojiRegex.hasMatch(file.readAsStringSync()),
            isFalse,
            reason: 'Raw Unicode emoji detected in $relPath',
          );
        }

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    test(
      'CreatorWalletNotifier synchronizes userCoinsBalance via loadWallet, sandboxSettle & status poll',
      () async {
        final dio = Dio();
        dio.httpClientAdapter = _StubDioAdapter((options) async {
          final path = options.uri.path;
          if (path.endsWith('/creators/creator_cern/wallet')) {
            return _jsonResponse(<String, dynamic>{
              'creatorId': 'creator_cern',
              'balanceZar': 900.0,
              'balanceCoins': 1750,
              'totalCoinsReceived': 4750,
            });
          }
          if (path.endsWith('/payments/payfast/checkout')) {
            return _jsonResponse(<String, dynamic>{
              'checkoutId': 'chk_pf_63',
              'creatorId': 'creator_cern',
              'packId': 'pack_starter_500',
              'amountZar': 55.0,
              'coinsToCredit': 500,
              'paymentUrl': 'https://sandbox.payfast.co.za/eng/process',
              'formFields': <String, String>{},
              'signature': 'sig_63',
              'status': 'pending',
            }, statusCode: 201);
          }
          if (path.endsWith('/payments/payfast/sandbox-settle/chk_pf_63')) {
            return _jsonResponse(<String, dynamic>{
              'checkoutId': 'chk_pf_63',
              'creatorId': 'creator_cern',
              'status': 'completed',
              'settled': true,
              'idempotentReplay': false,
              'coinsCredited': 500,
              'walletBalanceCoins': 2250,
              'walletBalanceZar': 900.0,
              'pfPaymentId': 'pf_sbx_63',
            });
          }
          if (path.endsWith('/payments/payfast/status/chk_pf_63')) {
            return _jsonResponse(<String, dynamic>{
              'checkoutId': 'chk_pf_63',
              'creatorId': 'creator_cern',
              'status': 'completed',
              'settled': true,
              'coinsCredited': 500,
              'walletBalanceCoins': 2750,
              'walletBalanceZar': 900.0,
            });
          }
          return _jsonResponse(<String, dynamic>{'error': 'not_found'}, statusCode: 404);
        });

        final repo = HttpSocialRepository(
          dio: dio,
          baseUrl: 'https://api.vhunambi.com/api',
          isTestMode: false,
        );
        final container = ProviderContainer(
          overrides: <Override>[socialRepositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);

        final notifier = container.read(creatorWalletProvider.notifier);
        await notifier.loadWallet();
        expect(
          container.read(creatorWalletProvider).userCoinsBalance,
          equals(1750),
        );

        final settled = await notifier.purchaseCoinPackWithPayFast(
          packId: 'pack_starter_500',
          autoSettleSandbox: true,
        );
        expect(settled?.settled, isTrue);
        expect(
          container.read(creatorWalletProvider).userCoinsBalance,
          equals(2250),
        );

        final polled = await notifier.syncPayFastCheckout('chk_pf_63');
        expect(polled?.settled, isTrue);
        expect(
          container.read(creatorWalletProvider).userCoinsBalance,
          equals(2750),
        );
      },
    );
  });

  group('Phase 63 M63.4 (G-63-05): CloudVideoExportService HTTP POST & Async Job Poll', () {
    test(
      'CloudVideoExportService posts /v1/vision/render-video, polls GET jobId & normalizes URL',
      () async {
        final calls = <String>[];
        final dio = Dio();
        dio.httpClientAdapter = _StubDioAdapter((options) async {
          calls.add('${options.method} ${options.uri.path}');
          if (options.method == 'POST' &&
              options.uri.path.endsWith('/v1/vision/render-video')) {
            return _jsonResponse(<String, dynamic>{
              'jobId': 'vid_job_63',
              'status': 'queued',
            });
          }
          if (options.method == 'GET' &&
              options.uri.path.endsWith('/v1/vision/render-video/vid_job_63')) {
            return _jsonResponse(<String, dynamic>{
              'jobId': 'vid_job_63',
              'status': 'completed',
              'videoUrl': '/mock-storage/reels/async_reel_63.mp4',
            });
          }
          return _jsonResponse(<String, dynamic>{}, statusCode: 404);
        });

        final service = CloudVideoExportService(
          apiBaseUrl: 'https://api.vhunambi.com',
          dio: dio,
          isTestMode: false,
        );
        final progress = <double>[];
        final url = await service.exportLyricVideo(
          audioUrl: 'https://r2.vhunambi.com/audio/master.mp3',
          coverArtUrl: 'https://r2.vhunambi.com/covers/cover.png',
          words: const [
            LyricWordTimestamp(word: 'Vhunambi', start: 0.0, end: 1.0),
          ],
          startSec: 0.0,
          endSec: 15.0,
          preset: LyricTypographyPreset.kineticBounce,
          effects: const AtmosphericEffects(),
          onProgress: progress.add,
        );

        expect(
          calls,
          equals(const [
            'POST /v1/vision/render-video',
            'GET /v1/vision/render-video/vid_job_63',
          ]),
        );
        expect(url, equals('https://api.vhunambi.com/r2/reels/async_reel_63.mp4'));
        expect(progress.last, equals(1.0));
      },
    );
  });

  group('Phase 63 M63.5 (G-63-06): CloudStackDiagnosticCard & cloudPreflightProvider', () {
    testWidgets(
      'CloudStackDiagnosticCard probes /api/system/preflight and surfaces loopback warning cleanly',
      (tester) async {
        final dio = Dio();
        dio.httpClientAdapter = _StubDioAdapter((options) async {
          if (options.uri.path.endsWith('/system/preflight')) {
            return _jsonResponse(<String, dynamic>{
              'status': 'misconfigured',
              'persistenceEngine': 'supabase_cloud',
              'pillars': <String, dynamic>{
                'supabase': <String, dynamic>{
                  'status': 'healthy',
                  'mode': 'supabase_rest',
                  'summary': '19 tables live',
                },
                'r2Vault': <String, dynamic>{
                  'status': 'healthy',
                  'mode': 'r2_binding',
                  'summary': 'vhunambi-vault active',
                },
                'runpodAudio': <String, dynamic>{
                  'status': 'healthy',
                  'mode': 'runpod_serverless_gpu',
                  'summary': 'ACE-Step armed',
                },
                'runpodVision': <String, dynamic>{
                  'status': 'healthy',
                  'mode': 'comfyui_gpu',
                  'summary': 'ComfyUI armed',
                },
                'paymentAndLlm': <String, dynamic>{
                  'status': 'healthy',
                  'mode': 'payfast_sandbox',
                  'summary': 'PayFast sandbox active',
                },
                'webhookCallback': <String, dynamic>{
                  'status': 'misconfigured',
                  'mode': 'loopback_dev',
                  'summary': 'WEBHOOK_BASE_URL is localhost while RunPod is armed',
                },
              },
            });
          }
          return _jsonResponse(<String, dynamic>{}, statusCode: 404);
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              cloudPreflightProvider.overrideWith(
                (ref) => CloudPreflightNotifier(
                  dio: dio,
                  apiRestBaseUrl: 'https://api.vhunambi.com/api',
                  isTestMode: false,
                ),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const Scaffold(
                body: SingleChildScrollView(child: CloudStackDiagnosticCard()),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byKey(const Key('cloud_stack_preflight_card')), findsOneWidget);
        expect(find.byKey(const Key('cloud_stack_run_preflight_btn')), findsOneWidget);
        expect(find.textContaining('Engine: edge_hybrid'), findsOneWidget);

        await tester.tap(find.byKey(const Key('cloud_stack_run_preflight_btn')));
        await tester.pump();
        await tester.pump(Duration.zero);

        expect(find.textContaining('Engine: supabase_cloud'), findsOneWidget);
        expect(find.text('Webhook Callback Reachability'), findsOneWidget);
        expect(find.text('loopback_dev'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  });
}


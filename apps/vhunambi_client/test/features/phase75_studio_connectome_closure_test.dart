import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/content_studio/domain/utils/lyric_karaoke_sanitizer.dart';
import 'package:vhunambi_client/features/content_studio/presentation/views/kinetic_reel_studio_view.dart';
import 'package:vhunambi_client/features/mastering/presentation/providers/mastering_session_provider.dart';
import 'package:vhunambi_client/features/sound_signature/data/sound_signature_repository.dart';
import 'package:vhunambi_client/features/sound_signature/domain/models/sound_idealizer_recipe.dart';
import 'package:vhunambi_client/features/studio/data/services/fake_generation_socket_service.dart';
import 'package:vhunambi_client/features/studio/data/services/fake_lyrics_generation_service.dart';
import 'package:vhunambi_client/features/studio/data/services/fake_stem_download_service.dart';
import 'package:vhunambi_client/features/studio/data/services/http_lyrics_generation_service.dart';
import 'package:vhunambi_client/features/studio/domain/models/lyrics_review_models.dart';
import 'package:vhunambi_client/features/studio/domain/services/i_lyrics_generation_service.dart';
import 'package:vhunambi_client/features/studio/domain/services/i_voice_calibration_recorder.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/generation_pipeline_providers.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/lyrics_review_provider.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/melody_sketchpad_provider.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/sound_pack_manager_provider.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/stem_download_provider.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/vocal_identity_provider.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/generation_pipeline_card.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/lyrics_review_modal.dart';
import 'package:vhunambi_client/features/track/domain/models/track_entity.dart';
import 'package:vhunambi_client/features/track/domain/models/track_detail_models.dart';
import 'package:vhunambi_client/features/track/presentation/providers/track_providers.dart';

typedef _DioResponder =
    Future<({int statusCode, Object body, bool isBytes})> Function(
      RequestOptions options,
    );

class _FakeDioAdapter implements HttpClientAdapter {
  _FakeDioAdapter(this._responder);

  final _DioResponder _responder;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final res = await _responder(options);
    if (res.isBytes) {
      final bytes = res.body as List<int>;
      return ResponseBody.fromBytes(
        bytes,
        res.statusCode,
        headers: {
          Headers.contentTypeHeader: ['application/octet-stream'],
          Headers.contentLengthHeader: ['${bytes.length}'],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode(res.body),
      res.statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

class _SpyLyricsService implements ILyricsGenerationService {
  final FakeLyricsGenerationService _delegate = FakeLyricsGenerationService(
    latency: Duration.zero,
  );
  int refineCalls = 0;
  int storyCalls = 0;
  String? lastStoryText;
  String? lastInstruction;

  @override
  List<String> getCulturalIdioms(String language) =>
      _delegate.getCulturalIdioms(language);

  @override
  Future<LyricsReviewDraft> generateLyrics({
    required String prompt,
    required String genre,
    required String language,
  }) => _delegate.generateLyrics(
    prompt: prompt,
    genre: genre,
    language: language,
  );

  @override
  Future<LyricsReviewDraft> refineLyrics({
    required String currentLyrics,
    required String refinementInstruction,
    String? idiomToInsert,
    required String genre,
    required String language,
    String prompt = '',
  }) async {
    refineCalls++;
    lastInstruction = refinementInstruction;
    return LyricsReviewDraft.fromRawText(
      prompt: prompt,
      genre: genre,
      language: language,
      rawText:
          '[Verse 1]\nPolished Venda line one\nPolished Venda line two',
    );
  }

  @override
  Future<LyricsReviewDraft> transformStoryToLyrics({
    required String storyText,
    required String genre,
    required String language,
    List<String>? targetCognateLanguages,
    List<String>? mood,
  }) async {
    storyCalls++;
    lastStoryText = storyText;
    return LyricsReviewDraft.fromRawText(
      prompt: storyText,
      genre: genre,
      language: language,
      rawText:
          '[Verse 1]\nFrom Limpopo valleys to the stars\n[Chorus]\nSing our story loud tonight',
    );
  }
}

void main() {
  group('Phase 75 Connectome Closure (EP-P66, EP-P27, EP-P26, EP-P25, EP-P74)', () {
    test('EP-P66: HttpLyricsGenerationService sends normalized codes & parses rawLyrics/structuredLyrics', () async {
      final adapter = _FakeDioAdapter((options) async {
        if (options.path.endsWith('/lyrics/refine')) {
          return (
            statusCode: 200,
            isBytes: false,
            body: {
              'success': true,
              'rawLyrics': '[Chorus]\nRo takala rothe\nVhuhosi hashu',
            },
          );
        }
        return (
          statusCode: 200,
          isBytes: false,
          body: {
            'success': true,
            'structuredLyrics':
                '[Verse 1]\nStory rhythm line\n[Chorus]\nEchoes of Makhado',
          },
        );
      });
      final dio = Dio()..httpClientAdapter = adapter;
      final service = HttpLyricsGenerationService(
        dio: dio,
        baseUrl: 'https://api.test/v1',
        isTestMode: false,
      );

      final refined = await service.refineLyrics(
        currentLyrics: '[Chorus]\nOld line',
        refinementInstruction: 'Elevate poetic imagery',
        genre: 'Amapiano',
        language: 'Tshivenḓa',
      );
      expect(adapter.requests.first.data['language'], 've');
      expect(refined.rawText, contains('Ro takala rothe'));

      final storyDraft = await service.transformStoryToLyrics(
        storyText:
            'Growing up in Venda listening to evening drums across the misty mountains.',
        genre: 'Afro House',
        language: 'Tshivenḓa',
      );
      expect(adapter.requests.last.data['genre'], 'amapiano');
      expect(adapter.requests.last.data['baseLanguage'], 've');
      expect(storyDraft.rawText, contains('Echoes of Makhado'));
    });

    testWidgets('EP-P66 UI: LyricsReviewModal Story-to-Lyrics drawer and stanza AI Polish work deterministically', (tester) async {
      tester.view.physicalSize = const Size(1280, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (_) async => null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );

      final spy = _SpyLyricsService();
      final container = ProviderContainer(
        overrides: [lyricsGenerationServiceProvider.overrideWithValue(spy)],
      );
      addTearDown(() {
        try {
          container.dispose();
        } catch (_) {}
      });

      await container.read(lyricsReviewProvider.notifier).loadGeneratedLyrics(
        prompt: 'Sunset groove',
        genre: 'Amapiano',
        language: 'Tshivenḓa',
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(body: LyricsReviewModal()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Toggle Story-to-Lyrics drawer and verify indicator label preserved
      await tester.tap(find.byKey(const Key('lyrics_story_mode_toggle')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.textContaining('Story-to-Lyrics Mode Active'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('lyrics_story_input')),
        'A young producer in Thohoyandou turns night bus melodies into gold.',
      );
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.byKey(const Key('lyrics_story_transform_btn')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(spy.storyCalls, 1);
      expect(
        container.read(lyricsReviewProvider)?.rawText,
        contains('From Limpopo valleys to the stars'),
      );

      // Tap per-stanza AI Polish icon button on the first stanza
      final firstSection =
          container.read(lyricsReviewProvider)!.sections.first;
      final refineBtn = find.byKey(Key('stanza_refine_${firstSection.id}'));
      await tester.ensureVisible(refineBtn);
      await tester.tap(refineBtn);
      await tester.pump(const Duration(milliseconds: 100));

      expect(spy.refineCalls, 1);
      expect(
        container.read(lyricsReviewProvider)?.rawText,
        contains('Polished Venda line one'),
      );

      // Drain the 2s _showLyricsToast auto-dismiss timers before teardown.
      await tester.pump(const Duration(seconds: 3));
    });

    test('EP-P27: MelodySketchpadNotifier and SoundPackManagerNotifier sync presets & download R2 packs', () async {
      final adapter = _FakeDioAdapter((options) async {
        if (options.path.contains('/melodies/presets')) {
          return (
            statusCode: 200,
            isBytes: false,
            body: {
              'success': true,
              'presets': [
                {
                  'id': 'cloud_preset_venda',
                  'name': 'Makhado Night Log',
                  'genre': 'Amapiano',
                  'bpm': 114,
                  'musicalKey': 'F#m',
                  'scaleMode': 'naturalMinor',
                  'instrument': 'amapiano_log_drum',
                  'notes': [
                    {'step': 0, 'scaleRow': 2, 'velocity': 0.9},
                  ],
                },
              ],
            },
          );
        }
        if (options.path.contains('/melodies/sound-packs')) {
          return (
            statusCode: 200,
            isBytes: false,
            body: {
              'success': true,
              'soundPacks': [
                {
                  'id': 'pack_limpopo_cloud',
                  'name': 'Limpopo Cloud Pack',
                  'description': 'Official cloud drums',
                  'genre': 'Amapiano',
                  'sampleCount': 32,
                  'sizeMb': 14.2,
                  'downloadUrl': '/r2/packs/limpopo_cloud.zip',
                  'isBundledNative': false,
                },
              ],
            },
          );
        }
        return (
          statusCode: 200,
          isBytes: true,
          body: <int>[80, 75, 3, 4, 1, 2, 3, 4],
        );
      });

      final dio = Dio()..httpClientAdapter = adapter;
      final container = ProviderContainer(
        overrides: [
          melodySketchpadProvider.overrideWith(
            (ref) => MelodySketchpadNotifier(ref, dio: dio, isTestMode: false),
          ),
        ],
      );
      addTearDown(() {
        try {
          container.dispose();
        } catch (_) {}
      });

      final presets = await container
          .read(melodySketchpadProvider.notifier)
          .syncStarterPresetsFromCloud(genre: 'Amapiano');
      expect(presets.map((p) => p.id), contains('cloud_preset_venda'));

      final packNotifier = SoundPackManagerNotifier(
        dio: dio,
        isTestMode: false,
      );
      addTearDown(packNotifier.dispose);

      await packNotifier.syncSoundPacksFromCloud();
      expect(
        packNotifier.state.packs.map((p) => p.id),
        contains('pack_limpopo_cloud'),
      );

      final installed = await packNotifier.downloadSoundPack(
        'pack_limpopo_cloud',
      );
      expect(installed, isTrue);
      expect(
        packNotifier.state.packs
            .firstWhere((p) => p.id == 'pack_limpopo_cloud')
            .isInstalled,
        isTrue,
      );
    });

    test('EP-P26: VocalIdentityNotifier extract-calibration & SoundSignatureRepository cloud recipe sync', () async {
      final adapter = _FakeDioAdapter((options) async {
        if (options.path.endsWith('/voices/extract-calibration')) {
          return (
            statusCode: 200,
            isBytes: false,
            body: {
              'success': true,
              'script': {
                'language': 'Tshivenḓa',
                'totalEstimatedDurationSec': 12,
                'lines': [
                  {
                    'index': 0,
                    'text': 'Ro takala rothe ngei Makhado',
                    'phoneticHint': 'Dental clarity + alveolar flap',
                    'focusCategory': 'dental_closure',
                    'estimatedSec': 4,
                  },
                ],
              },
            },
          );
        }
        if (options.method == 'PATCH' &&
            options.path.contains('/voices/signatures/sig_p75/recipe')) {
          return (statusCode: 200, isBytes: false, body: {'success': true});
        }
        if (options.method == 'GET' &&
            options.path.contains('/voices/signatures/sig_p75')) {
          return (
            statusCode: 200,
            isBytes: false,
            body: {
              'success': true,
              'signature': {
                'id': 'sig_p75',
                'displayCode': 'VHU-SIG-0P75',
                'source': 'live',
                'createdAtIso': '2026-11-22T00:00:00.000Z',
                'durationSec': 6.0,
              },
            },
          );
        }
        return (statusCode: 200, isBytes: false, body: {'success': true});
      });

      final dio = Dio()..httpClientAdapter = adapter;
      final container = ProviderContainer(
        overrides: [
          voiceCalibrationRecorderProvider.overrideWithValue(
            DeterministicVoiceCalibrationRecorder(),
          ),
        ],
      );
      addTearDown(() {
        try {
          container.dispose();
        } catch (_) {}
      });

      final script = await container
          .read(vocalIdentityProvider.notifier)
          .prepareCalibrationFromLyricsAsync(
            'Ro takala rothe',
            language: 'Tshivenḓa',
            dio: dio,
          );
      expect(script.lines.first.text, 'Ro takala rothe ngei Makhado');

      const repo = SoundSignatureRepository();
      final patched = await repo.updateRecipeInCloud(
        signatureId: 'sig_p75',
        recipe: const SoundIdealizerRecipe(pitchScaleLock: 0.95),
        dio: dio,
      );
      expect(patched, isTrue);

      final fetched = await repo.fetchSignatureFromCloud('sig_p75', dio: dio);
      expect(fetched, isNotNull);
      expect(fetched!.id, 'sig_p75');
    });

    test('EP-P25: MasteringSessionNotifier honest failure on HTTP 500 + presets sync + TrackDetailNotifier 4-stem manifest', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/v1/generations/mastering/presets')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'presets': [
                {
                  'id': 'venda_log_knock',
                  'name': 'Venda Log Knock',
                  'genre': 'Amapiano',
                  'description': 'Cloud preset',
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path.contains('/master') && request.method == 'POST') {
          return http.Response('{"error":"GPU offline"}', 500);
        }
        if (request.url.path.endsWith('/v1/generations/trk_p75/manifest')) {
          return http.Response(
            jsonEncode({
              'assets': {
                'stemUrls': {
                  'vocals': 'stems/trk_p75_vocals.wav',
                  'drums': 'stems/trk_p75_drums.wav',
                  'bass': 'stems/trk_p75_bass.wav',
                  'instrumental': 'stems/trk_p75_inst.wav',
                },
              },
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      });

      final container = ProviderContainer(
        overrides: [
          masteringSessionProvider.overrideWith(
            (ref) => MasteringSessionNotifier(
              ref,
              httpClient: mockClient,
              isTestMode: false,
            ),
          ),
        ],
      );
      addTearDown(() {
        try {
          container.dispose();
        } catch (_) {}
      });

      final mastering = container.read(masteringSessionProvider.notifier);
      await mastering.syncMasteringPresetsFromCloud(
        genre: 'Amapiano',
        apiBaseUrl: 'https://api.test',
      );
      expect(
        container
            .read(masteringSessionProvider)
            .availablePresets
            .map((p) => p.id),
        contains('venda_log_knock'),
      );

      final baked = await mastering.bakeProductionMaster(
        apiBaseUrl: 'https://api.test',
      );
      expect(baked, isFalse);
      final afterFail = container.read(masteringSessionProvider);
      expect(afterFail.hasBakedMaster, isFalse);
      expect(afterFail.errorMessage, contains('HTTP 500'));
      expect(afterFail.masteredMp3Url, isNull);

      final trackNotifier = TrackDetailNotifier('trk_p75', ref: null);
      addTearDown(trackNotifier.dispose);
      await trackNotifier.separateStems(
        client: mockClient,
        apiBaseUrl: 'https://api.test',
      );
      expect(trackNotifier.state.stemState.status, StemSeparationStatus.ready);
      expect(
        trackNotifier.state.stemState.stems.map((s) => s.id).toList(),
        ['trk_p75_vocals', 'trk_p75_drums', 'trk_p75_bass', 'trk_p75_inst'],
      );
      expect(
        trackNotifier.state.stemState.stems.first.audioUrl,
        contains('/stems/trk_p75_vocals.wav'),
      );
    });

    testWidgets('EP-P74: GenerationPipelineCard Drop as Kinetic Reel launches KineticReelStudioView + LyricKaraokeSanitizer', (tester) async {
      final sanitized = LyricKaraokeSanitizer.cleanLyricsForTeleprompter(
        'Title: Makhado Sunrise\nBPM: 112\n[Intro]\n[Crisp soft shakers, airy synth pads]\n[Verse 1]\nNdi Matsheloni (x2)\n[Chorus]\nRo takala rothe',
      );
      expect(sanitized, contains('[Verse 1]'));
      expect(sanitized, contains('[Chorus]'));
      expect(sanitized, contains('Ndi Matsheloni'));
      expect(sanitized, isNot(contains('Title:')));
      expect(sanitized, isNot(contains('Crisp soft shakers')));
      expect(sanitized, isNot(contains('(x2)')));

      final track = TrackEntity(
        id: 'trk_reel_p75',
        title: 'Makhado Sunset',
        genre: 'Amapiano',
        duration: const Duration(minutes: 3, seconds: 10),
        masterMp3Url: 'audio/trk_reel_p75.mp3',
      );
      final container = ProviderContainer(
        overrides: [
          socketServiceProvider.overrideWithValue(
            FakeGenerationSocketService(
              stepDelay: Duration.zero,
              completedTrack: track,
              generatedLyrics: '[Chorus]\nRo takala',
            ),
          ),
          stemDownloadServiceProvider.overrideWithValue(
            FakeStemDownloadService(stepDelay: Duration.zero),
          ),
        ],
      );
      addTearDown(() {
        try {
          container.dispose();
        } catch (_) {}
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: SizedBox(
                width: 900,
                height: 900,
                child: SingleChildScrollView(child: GenerationPipelineCard()),
              ),
            ),
          ),
        ),
      );

      await container.read(generationProgressProvider.notifier).startGeneration(
        generationId: 'trk_reel_p75',
        trackTitle: 'Makhado Sunset',
        genre: 'Amapiano',
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      final reelBtn = find.byKey(const Key('pipeline_create_reel_btn'));
      expect(reelBtn, findsOneWidget);
      await tester.ensureVisible(reelBtn);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(reelBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(KineticReelStudioView), findsOneWidget);
    });
  });
}

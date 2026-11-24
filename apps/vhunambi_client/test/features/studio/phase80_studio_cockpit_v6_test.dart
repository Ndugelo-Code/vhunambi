import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/library/domain/models/library_models.dart';
import 'package:vhunambi_client/features/library/presentation/providers/library_providers.dart';
import 'package:vhunambi_client/features/media/data/repositories/http_media_upload_repository.dart';
import 'package:vhunambi_client/features/media/domain/models/uploaded_media_asset.dart';
import 'package:vhunambi_client/features/media/presentation/providers/media_upload_queue_provider.dart';
import 'package:vhunambi_client/features/studio/data/services/http_generation_submission_service.dart';
import 'package:vhunambi_client/features/studio/domain/models/generation_pipeline_state.dart';
import 'package:vhunambi_client/features/studio/domain/models/studio_form_state.dart';
import 'package:vhunambi_client/features/studio/domain/models/studio_genre_catalog.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/generation_pipeline_providers.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/studio_form_provider.dart';
import 'package:vhunambi_client/features/studio/presentation/views/studio_view.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/generation_pipeline_card.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/studio_past_songs_remix_shelf.dart';
import 'package:vhunambi_client/features/track/domain/models/track_entity.dart';

class _CapturingInterceptor extends Interceptor {
  Map<String, dynamic>? lastPayload;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.data is Map<String, dynamic>) {
      lastPayload = Map<String, dynamic>.from(
        options.data as Map<String, dynamic>,
      );
    }
    handler.resolve(
      Response<Map<String, dynamic>>(
        requestOptions: options,
        statusCode: 201,
        data: <String, dynamic>{
          'success': true,
          'generationId': 'gen_v6_capture_1',
          'status': 'queued',
          'resolvedEngine': 'minimax_music_3',
          'attributionTag': 'MiniMax-Music3',
        },
      ),
    );
  }
}

class _FakeMediaRepo implements IMediaUploadRepository {
  @override
  Future<UploadedMediaAsset> uploadMedia({
    required UploadedMediaAsset staged,
    required Uint8List bytes,
    void Function(int sent, int total)? onProgress,
  }) async => staged;

  @override
  Future<List<UploadedMediaAsset>> fetchUploads({
    required String creatorId,
    MediaAssetKind? kind,
  }) async => const <UploadedMediaAsset>[];

  @override
  Future<bool> deleteRemoteUpload(String assetId) async => true;
}

void main() {
  group('Phase 80 Studio Cockpit V6 & Production Contract', () {
    test('kStudioGenreCatalog covers all 42 genres across 5 regions with >=3 per region', () {
      expect(kStudioGenreCatalog.length, 42);
      for (final region in kStudioRegions) {
        final regionGenres = genresForRegion(region);
        expect(
          regionGenres.length,
          greaterThanOrEqualTo(3),
          reason: '$region must have at least 3 genres',
        );
      }
      expect(genresForRegion('Asia').map((g) => g.name), contains('K-Pop'));
    });

    test('StudioFormState V6 resolves engines & MiniMax attribution cleanly', () {
      const vocalStudio = StudioFormState();
      expect(vocalStudio.engineTier, StudioEngineTier.studioBake);
      expect(vocalStudio.resolvedEnginePreview, 'MiniMax Music 3.0');
      expect(vocalStudio.resolvedAttributionTag, 'MiniMax-Music3');
      expect(vocalStudio.durationSeconds, 30);

      final fast = vocalStudio.copyWith(engineTier: StudioEngineTier.fastDraft);
      expect(fast.resolvedEnginePreview, 'ACE-Step 1.5 XL-Turbo');
      expect(fast.resolvedAttributionTag, isNull);

      final inst = vocalStudio.copyWith(isInstrumental: true);
      expect(inst.resolvedEnginePreview, 'ACE-Step 1.5 XL-SFT');
      expect(inst.resolvedAttributionTag, isNull);

      final remix = vocalStudio.copyWith(
        referenceAudioPath: '/r2/media/beat.wav',
        audioMode: ReferenceAudioMode.remix,
      );
      expect(remix.resolvedEnginePreview, 'ACE-Step 1.5 XL-Base');
      expect(remix.resolvedAttributionTag, isNull);
    });

    test('StudioFormNotifier multi-voice cast caps at 6 and Quick Duet configures mixed duet', () {
      final notifier = StudioFormNotifier();
      notifier.applyQuickDuet();
      expect(notifier.state.vocalVoices, VocalVoices.duet);
      expect(notifier.state.vocalGender, VocalGender.mixed);
      expect(notifier.state.selectedVoiceIds.length, 2);

      for (var i = 0; i < 8; i++) {
        notifier.toggleSelectedVoiceId('voice_$i');
      }
      expect(notifier.state.selectedVoiceIds.length, 6);
    });

    test('HttpGenerationSubmissionService forwards complete V6 payload without truncation', () async {
      final interceptor = _CapturingInterceptor();
      final dio = Dio()..interceptors.add(interceptor);
      final service = HttpGenerationSubmissionService(
        dio: dio,
        baseUrl: 'https://api.vhunambi.test/v1',
        isTestMode: false,
      );

      final longPrompt =
          'Deep Durban Amapiano groove with soulful warm Rhodes chords and gospel choir lifts.';
      final res = await service.submitGeneration(
        trackTitle: 'Vhembe Horizon',
        prompt: longPrompt,
        genre: 'Private School Amapiano',
        region: 'South Africa',
        language: 'Tshivenḓa',
        lyrics: '[VERSE 1]\n[VOICE A]\nRi a tshimbila',
        isInstrumental: false,
        durationSec: 210,
        lyricsMode: 'ai_writes',
        isAutoTitle: false,
        era: 'modern',
        songStructure: 'extended',
        visibility: 'private',
        engineTier: 'studio_bake',
        batchCount: 3,
        audioMode: 'none',
        voiceCast: const <String, dynamic>{
          'ensemble': 'duet',
          'selectedVoiceIds': <String>['v1', 'v2'],
        },
      );

      expect(res['resolvedEngine'], 'minimax_music_3');
      final payload = interceptor.lastPayload!;
      expect(payload['contractVersion'], 'v6');
      expect(payload['prompt'], longPrompt);
      expect(payload['region'], 'South Africa');
      expect(payload['durationSec'], 210);
      expect(payload['batchCount'], 3);
      expect(payload['engineTier'], 'studio_bake');
      expect(payload['visibility'], 'private');
      expect(payload['voiceCast'], isA<Map<String, dynamic>>());
    });

    testWidgets('StudioView V6 renders Glass Shell in Light & Dark 360x800 without overflow', (tester) async {
      for (final theme in <ThemeData>[AppTheme.lightTheme, AppTheme.darkTheme]) {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              customMediaUploadRepositoryProvider.overrideWithValue(
                _FakeMediaRepo(),
              ),
            ],
            child: MaterialApp(theme: theme, home: const StudioView()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('studio_tab_compose')), findsOneWidget);
        expect(find.byKey(const Key('studio_tab_voice')), findsOneWidget);
        expect(find.byKey(const Key('studio_tab_crate_mpc')), findsOneWidget);
        expect(find.byKey(const Key('studio_improve_prompt_btn')), findsOneWidget);
        expect(find.byKey(const Key('dropzone_from_uploads_btn')), findsOneWidget);
        expect(find.byKey(const Key('studio_instrumental_switch')), findsOneWidget);
        expect(find.byKey(const Key('studio_engine_tier_selector')), findsOneWidget);
        expect(find.byKey(const Key('studio_batch_count_selector')), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('Improve with AI, Asia region, Recreate modes & Batch selector mutate StudioFormState', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final container = ProviderContainer(
        overrides: <Override>[
          customMediaUploadRepositoryProvider.overrideWithValue(_FakeMediaRepo()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const StudioView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('studio_improve_prompt_btn')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(container.read(studioFormProvider).prompt, isNotEmpty);

      await tester.ensureVisible(find.byKey(const Key('genre_region_asia')));
      await tester.tap(find.byKey(const Key('genre_region_asia')));
      await tester.pumpAndSettle();
      expect(find.text('K-Pop'), findsOneWidget);
      expect(find.text('Bollywood Fusion'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('studio_batch_chip_3')));
      await tester.tap(find.byKey(const Key('studio_batch_chip_3')));
      await tester.pump();
      expect(container.read(studioFormProvider).batchCount, 3);
      expect(find.text('Write Lyrics (3 Takes)'), findsOneWidget);

      container.read(studioFormProvider.notifier).setReferenceAudio('/r2/beat.wav');
      await tester.pump();
      expect(find.byKey(const Key('audio_mode_remix')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('audio_mode_remix')));
      await tester.tap(find.byKey(const Key('audio_mode_remix')));
      await tester.pump();
      expect(container.read(studioFormProvider).audioMode, ReferenceAudioMode.remix);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('GenerationPipelineCard displays BakeStage strip, MiniMax attribution & multi-take chips', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const takeTrack = TrackEntity(
        id: 'gen_multi_80',
        title: 'Thohoyandou Stars',
        genre: 'Afro Fusion',
        language: 'Tshivenḓa',
        duration: Duration(seconds: 200),
        masterMp3Url: 'https://r2.vhunambi.com/t1.mp3',
      );
      container.read(generationProgressProvider.notifier).state =
          const GenerationProgressState(
            generationId: 'gen_multi_80',
            trackTitle: 'Thohoyandou Stars',
            genre: 'Afro Fusion',
            currentStep: PipelineStep.ready,
            statusMessage: 'Your song is ready!',
            progressPercent: 1.0,
            bakeStage: BakeStage.ready,
            resolvedEngine: 'minimax_music_3',
            attributionTag: 'MiniMax-Music3',
            completedTrack: takeTrack,
            takes: <GenerationTake>[
              GenerationTake(
                takeIndex: 0,
                seed: 101,
                audioUrl: 'https://r2.vhunambi.com/t1.mp3',
              ),
              GenerationTake(
                takeIndex: 1,
                seed: 202,
                audioUrl: 'https://r2.vhunambi.com/t2.mp3',
              ),
            ],
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(body: GenerationPipelineCard()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byKey(const Key('pipeline_bake_stage_strip')), findsOneWidget);
      expect(find.byKey(const Key('pipeline_minimax_attribution_badge')), findsOneWidget);
      expect(find.text('Engine: MiniMax-Music3'), findsOneWidget);
      expect(find.byKey(const Key('pipeline_take_chip_0')), findsOneWidget);
      expect(find.byKey(const Key('pipeline_take_chip_1')), findsOneWidget);

      await tester.tap(find.byKey(const Key('pipeline_take_chip_1')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(container.read(generationProgressProvider)!.activeTakeIndex, 1);
      expect(
        container.read(generationProgressProvider)!.activeCompletedTrack!.masterMp3Url,
        'https://r2.vhunambi.com/t2.mp3',
      );
    });

    testWidgets('StudioPastSongsRemixShelf seeds Remix parameters cleanly', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(libraryTracksProvider.notifier).addTrack(
        LibraryTrack(
          id: 'trk_past_80',
          title: 'Morning Mbira',
          creatorName: 'Ndugelo',
          genre: 'Chimurenga',
          language: 'ChiShona',
          durationSeconds: 185,
          remoteAudioUrl: 'https://r2.vhunambi.com/mbira.mp3',
          createdAt: DateTime(2026, 11, 24),
        ),
      );

      var scrolled = false;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: StudioPastSongsRemixShelf(
                onRemixSelected: () => scrolled = true,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byKey(const Key('studio_past_songs_remix_shelf')), findsOneWidget);
      await tester.tap(find.byKey(const Key('past_song_remix_trk_past_80')));
      await tester.pump();

      final form = container.read(studioFormProvider);
      expect(scrolled, isTrue);
      expect(form.sourceTrackId, 'trk_past_80');
      expect(form.genre, 'Chimurenga');
      expect(form.region, 'Africa');
      expect(form.audioMode, ReferenceAudioMode.remix);
    });
  });
}

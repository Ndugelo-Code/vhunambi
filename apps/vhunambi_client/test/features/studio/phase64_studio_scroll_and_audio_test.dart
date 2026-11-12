import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/player/data/services/vhunambi_audio_handler.dart';
import 'package:vhunambi_client/features/player/domain/models/stem_mixer_state.dart';
import 'package:vhunambi_client/features/studio/domain/models/generation_pipeline_state.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/generation_pipeline_providers.dart';
import 'package:vhunambi_client/features/studio/presentation/views/studio_view.dart';
import 'package:vhunambi_client/features/track/domain/models/track_entity.dart';

void main() {
  group('Phase 64: Studio Scroll Freedom & Hardware Audio Bootstrap', () {
    testWidgets(
      'G-64-02: StudioView Compose scrolls smoothly past completed GenerationPipelineCard to AdvancedOptionsAccordion',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final container = ProviderContainer();
        addTearDown(container.dispose);

        container.read(generationProgressProvider.notifier).state =
            GenerationProgressState(
              generationId: 'gen_p64_scroll_1',
              trackTitle: 'Thohoyandou Sunrise',
              genre: 'Amapiano',
              currentStep: PipelineStep.ready,
              statusMessage: 'Studio Master Ready',
              progressPercent: 1.0,
              generatedLyrics:
                  '[INTRO]\nNdi zwone!\n\n[VERSE 1]\nMorning mist over Limpopo hills\n\n[CHORUS]\nVhunambi rising strong',
              completedTrack: const TrackEntity(
                id: 'gen_p64_scroll_1',
                title: 'Thohoyandou Sunrise',
                genre: 'Amapiano',
                language: 've',
                duration: Duration(seconds: 180),
                masterMp3Url:
                    'https://vhunambi-api.ndugelosigwadi.workers.dev/r2/gen_p64_scroll_1_master.mp3',
                stemUrls: <StemType, String>{
                  StemType.vocals:
                      'https://vhunambi-api.ndugelosigwadi.workers.dev/r2/gen_p64_scroll_1_vocals.mp3',
                  StemType.drums:
                      'https://vhunambi-api.ndugelosigwadi.workers.dev/r2/gen_p64_scroll_1_drums.mp3',
                  StemType.bass:
                      'https://vhunambi-api.ndugelosigwadi.workers.dev/r2/gen_p64_scroll_1_bass.mp3',
                  StemType.melody:
                      'https://vhunambi-api.ndugelosigwadi.workers.dev/r2/gen_p64_scroll_1_melodic.mp3',
                },
              ),
            );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const StudioView(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 120));

        expect(find.text('Thohoyandou Sunrise'), findsWidgets);
        expect(find.text('Your song is ready!'), findsOneWidget);

        final scrollable = find.byType(Scrollable).first;
        final initialCardTop = tester.getTopLeft(find.text('Result')).dy;

        await tester.drag(scrollable, const Offset(0, -600));
        await tester.pump(const Duration(milliseconds: 120));

        final scrolledCardTop = tester.getTopLeft(find.text('Result')).dy;
        expect(
          scrolledCardTop,
          lessThan(initialCardTop),
          reason:
              'GenerationPipelineCard must scroll upward inside Compose tab SingleChildScrollView rather than pinning/freezing',
        );

        await tester.scrollUntilVisible(
          find.text('Advanced Options'),
          300.0,
          scrollable: scrollable,
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Advanced Options'), findsOneWidget);
      },
    );

    test(
      'G-64-03: bootstrapPlatformAudioHandler zero-arg bootstrap & cloud media URL normalization',
      () async {
        TestWidgetsFlutterBinding.ensureInitialized();
        final handler = await bootstrapPlatformAudioHandler();
        expect(handler, isA<IVhunambiAudioHandler>());
        await handler.dispose();

        const workerOrigin = 'https://vhunambi-api.ndugelosigwadi.workers.dev';
        expect(
          AppConstants.normalizeCloudMediaUrl(
            '/r2/masters/demo.wav',
            overrideOrigin: workerOrigin,
          ),
          '$workerOrigin/r2/masters/demo.wav',
        );
        expect(
          AppConstants.normalizeCloudMediaUrl(
            '/mock-storage/audio/test.mp3',
            overrideOrigin: workerOrigin,
          ),
          '$workerOrigin/r2/audio/test.mp3',
        );
        expect(
          AppConstants.normalizeCloudMediaUrl(
            'https://r2.vhunambi.com/stems/vocals.wav',
            overrideOrigin: workerOrigin,
          ),
          '$workerOrigin/r2/stems/vocals.wav',
        );
      },
    );
  });
}


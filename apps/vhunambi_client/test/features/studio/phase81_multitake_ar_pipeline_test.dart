import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/library/domain/models/library_models.dart';
import 'package:vhunambi_client/features/library/presentation/providers/library_providers.dart';
import 'package:vhunambi_client/features/player/data/services/vhunambi_audio_handler.dart';
import 'package:vhunambi_client/features/player/presentation/providers/audio_bridge_providers.dart';
import 'package:vhunambi_client/features/player/presentation/providers/player_provider.dart';
import 'package:vhunambi_client/features/studio/domain/models/generation_pipeline_state.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/generation_pipeline_providers.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/generation_pipeline_card.dart';
import 'package:vhunambi_client/features/track/domain/models/track_entity.dart';

void main() {
  group('Phase 81 Multi-Take A&R Switcher & Vault Sync', () {
    test('GenerationTake.fromJson decodes score, engineUsed, and attribution', () {
      final take = GenerationTake.fromJson(<String, dynamic>{
        'takeIndex': 0,
        'seed': 987654321,
        'audioUrl': 'https://r2.vhunambi.com/audio/gen_81/take_0.mp3',
        'stemsZipUrl': 'https://r2.vhunambi.com/audio/gen_81/stems.zip',
        'durationSec': 210,
        'engineUsed': 'minimax_music_3',
        'score': 0.946,
        'attribution': 'MiniMax-Music3',
      });

      expect(take.takeIndex, 0);
      expect(take.seed, 987654321);
      expect(take.durationSec, 210);
      expect(take.engineUsed, 'minimax_music_3');
      expect(take.score, closeTo(0.946, 0.0001));
      expect(take.attribution, 'MiniMax-Music3');
    });

    testWidgets(
      'GenerationPipelineCard renders 44dp scored take pills without overflow at 360x800 in Light & Dark modes',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final handler = TestVhunambiAudioHandler();
        addTearDown(handler.dispose);

        final container = ProviderContainer(
          overrides: <Override>[audioHandlerProvider.overrideWithValue(handler)],
        );
        addTearDown(container.dispose);

        const track = TrackEntity(
          id: 'gen_p81_ui',
          title: 'Vhembe Horizon',
          genre: 'Afro Fusion',
          language: 'Tshivenda',
          duration: Duration(seconds: 215),
          masterMp3Url: 'https://r2.vhunambi.com/audio/gen_p81_ui/take_0.mp3',
        );

        container.read(generationProgressProvider.notifier).state =
            const GenerationProgressState(
              generationId: 'gen_p81_ui',
              trackTitle: 'Vhembe Horizon',
              genre: 'Afro Fusion',
              currentStep: PipelineStep.ready,
              statusMessage: 'Your song is ready!',
              progressPercent: 1.0,
              bakeStage: BakeStage.ready,
              resolvedEngine: 'minimax_music_3',
              attributionTag: 'MiniMax-Music3',
              completedTrack: track,
              takes: <GenerationTake>[
                GenerationTake(
                  takeIndex: 0,
                  seed: 101,
                  audioUrl:
                      'https://r2.vhunambi.com/audio/gen_p81_ui/take_0.mp3',
                  durationSec: 215,
                  engineUsed: 'minimax_music_3',
                  score: 0.95,
                  attribution: 'MiniMax-Music3',
                ),
                GenerationTake(
                  takeIndex: 1,
                  seed: 202,
                  audioUrl:
                      'https://r2.vhunambi.com/audio/gen_p81_ui/take_1.mp3',
                  durationSec: 215,
                  engineUsed: 'minimax_music_3',
                  score: 0.88,
                  attribution: 'MiniMax-Music3',
                ),
                GenerationTake(
                  takeIndex: 2,
                  seed: 303,
                  audioUrl:
                      'https://r2.vhunambi.com/audio/gen_p81_ui/take_2.mp3',
                  durationSec: 215,
                  engineUsed: 'minimax_music_3',
                  score: 0.81,
                  attribution: 'MiniMax-Music3',
                ),
              ],
            );

        for (final theme in <ThemeData>[AppTheme.lightTheme, AppTheme.darkTheme]) {
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: theme,
                home: const Scaffold(
                  body: SingleChildScrollView(child: GenerationPipelineCard()),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 50));

          expect(
            find.byKey(const Key('pipeline_minimax_attribution_badge')),
            findsOneWidget,
          );
          expect(find.text('Take 1'), findsOneWidget);
          expect(find.text('Take 2'), findsOneWidget);
          expect(find.text('Take 3'), findsOneWidget);
          expect(find.text('95%'), findsOneWidget);
          expect(find.text('88%'), findsOneWidget);
          expect(find.byIcon(PhosphorIconsFill.sparkle), findsOneWidget);

          final chip0Size = tester.getSize(
            find.byKey(const Key('pipeline_take_chip_0')),
          );
          expect(chip0Size.height, greaterThanOrEqualTo(44.0));
        }
      },
    );

    testWidgets(
      'selectActiveTake updates both playerStateProvider and libraryTracksProvider remoteAudioUrl',
      (tester) async {
        final handler = TestVhunambiAudioHandler();
        addTearDown(handler.dispose);

        final container = ProviderContainer(
          overrides: <Override>[audioHandlerProvider.overrideWithValue(handler)],
        );
        addTearDown(container.dispose);

        const trackId = 'gen_p81_vault';
        final take0Url = AppConstants.normalizeCloudMediaUrl(
          '/r2/audio/$trackId/take_0.mp3',
        );
        final take1Url = AppConstants.normalizeCloudMediaUrl(
          '/r2/audio/$trackId/take_1.mp3',
        );

        container.read(libraryTracksProvider.notifier).addTrack(
              LibraryTrack(
                id: trackId,
                title: 'Mutale Groove',
                creatorName: 'Vhunambi Studio',
                genre: 'Amapiano',
                language: 'Tshivenda',
                durationSeconds: 180,
                remoteAudioUrl: take0Url,
                createdAt: DateTime(2026, 11, 24),
              ),
            );

        container.read(generationProgressProvider.notifier).state =
            const GenerationProgressState(
              generationId: trackId,
              trackTitle: 'Mutale Groove',
              genre: 'Amapiano',
              currentStep: PipelineStep.ready,
              statusMessage: 'Your song is ready!',
              progressPercent: 1.0,
              bakeStage: BakeStage.ready,
              resolvedEngine: 'minimax_music_3',
              attributionTag: 'MiniMax-Music3',
              completedTrack: TrackEntity(
                id: trackId,
                title: 'Mutale Groove',
                genre: 'Amapiano',
                language: 'Tshivenda',
                duration: Duration(seconds: 180),
                masterMp3Url: '/r2/audio/$trackId/take_0.mp3',
              ),
              takes: <GenerationTake>[
                GenerationTake(
                  takeIndex: 0,
                  seed: 111,
                  audioUrl: '/r2/audio/$trackId/take_0.mp3',
                  durationSec: 180,
                  score: 0.94,
                ),
                GenerationTake(
                  takeIndex: 1,
                  seed: 222,
                  audioUrl: '/r2/audio/$trackId/take_1.mp3',
                  durationSec: 192,
                  score: 0.89,
                ),
              ],
            );

        container.read(generationProgressProvider.notifier).selectActiveTake(1);
        await tester.pump();

        final activePlayerTrack = container.read(playerStateProvider).currentTrack;
        expect(activePlayerTrack?.audioUrl, take1Url);

        final vaultedTrack = container
            .read(libraryTracksProvider)
            .firstWhere((t) => t.id == trackId);
        expect(vaultedTrack.remoteAudioUrl, take1Url);
        expect(vaultedTrack.durationSeconds, 192);
      },
    );
  });
}

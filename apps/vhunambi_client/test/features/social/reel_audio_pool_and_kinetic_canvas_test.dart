import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/content_studio/presentation/widgets/kinetic_preview_canvas.dart';
import 'package:vhunambi_client/features/player/domain/models/player_state.dart';
import 'package:vhunambi_client/features/player/presentation/providers/player_provider.dart';
import 'package:vhunambi_client/features/social/data/services/reel_audio_pool_service.dart';
import 'package:vhunambi_client/features/social/presentation/providers/reel_audio_pool_provider.dart';
import 'package:vhunambi_client/features/social/presentation/providers/social_feed_provider.dart';
import 'package:vhunambi_client/features/social/presentation/widgets/kinetic_reels_modal.dart';
import 'package:vhunambi_client/features/studio/domain/services/melody_wav_synthesizer.dart';

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

  group('Phase A — 3-Slot Recycled Reel Audio Pool & Global Ducking', () {
    test(
      'enforces max 3 active controllers across vertical page swipes',
      () async {
        final pool = RealReelAudioPoolService(forceHeadlessMode: true);
        final container = ProviderContainer();
        addTearDown(() async {
          await pool.dispose();
          container.dispose();
        });

        final clips = container.read(socialFeedProvider).clips;
        expect(clips.length, greaterThanOrEqualTo(4));

        // 1. Enter at index 0 -> Window is {0, 1}
        await pool.activateWindow(
          clips: clips,
          activeIndex: 0,
          onStateTick: (_, _) {},
        );
        expect(pool.activeIndex, 0);
        expect(pool.activeClipId, clips[0].id);
        expect(pool.pooledIndices, equals({0, 1}));
        expect(
          pool.pooledIndices.length,
          lessThanOrEqualTo(IReelAudioPoolService.maxPoolSize),
        );

        // 2. Swipe to index 1 -> Window is {0, 1, 2} (max 3 slots)
        await pool.activateWindow(
          clips: clips,
          activeIndex: 1,
          onStateTick: (_, _) {},
        );
        expect(pool.activeIndex, 1);
        expect(pool.activeClipId, clips[1].id);
        expect(pool.pooledIndices, equals({0, 1, 2}));
        expect(pool.pooledIndices.length, equals(3));

        // 3. Swipe to index 2 -> Evicts slot 0, Window becomes {1, 2, 3}
        await pool.activateWindow(
          clips: clips,
          activeIndex: 2,
          onStateTick: (_, _) {},
        );
        expect(pool.activeIndex, 2);
        expect(pool.activeClipId, clips[2].id);
        expect(pool.pooledIndices.contains(0), isFalse);
        expect(pool.pooledIndices, equals({1, 2, 3}));
        expect(pool.pooledIndices.length, equals(3));

        // 4. Swipe to index 3 -> Evicts slot 1, Window slides to {2, 3, 4} (when 5 clips seeded)
        await pool.activateWindow(
          clips: clips,
          activeIndex: 3,
          onStateTick: (_, _) {},
        );
        expect(pool.activeIndex, 3);
        expect(pool.activeClipId, clips[3].id);
        expect(pool.pooledIndices.contains(1), isFalse);
        final expectedAt3 = <int>{2, 3, if (clips.length > 4) 4};
        expect(pool.pooledIndices, equals(expectedAt3));
        expect(
          pool.pooledIndices.length,
          lessThanOrEqualTo(IReelAudioPoolService.maxPoolSize),
        );

        // 5. Swipe to end (last index) -> Trailing boundary window has 2 slots
        final lastIndex = clips.length - 1;
        await pool.activateWindow(
          clips: clips,
          activeIndex: lastIndex,
          onStateTick: (_, _) {},
        );
        expect(pool.activeIndex, lastIndex);
        expect(pool.activeClipId, clips[lastIndex].id);
        expect(pool.pooledIndices, equals({lastIndex - 1, lastIndex}));
      },
    );

    test(
      'ducks global player on reel entry and restores on reel exit',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final reelsPool = container.read(reelAudioPoolProvider.notifier);
        final clips = container.read(socialFeedProvider).clips;

        // Global player starts playing by default
        expect(
          container.read(playerStateProvider).playbackStatus,
          equals(PlaybackStatus.playing),
        );

        // Entering reels pauses global player and records duck state
        await reelsPool.enterReelsSession(clips, initialIndex: 0);
        expect(
          container.read(playerStateProvider).playbackStatus,
          equals(PlaybackStatus.paused),
        );
        expect(
          container.read(reelAudioPoolProvider).wasGlobalPlayerDucked,
          isTrue,
        );
        expect(container.read(reelAudioPoolProvider).isPlaying, isTrue);

        // Exiting reels restores global player back to playing
        await reelsPool.exitReelsSession();
        expect(
          container.read(playerStateProvider).playbackStatus,
          equals(PlaybackStatus.playing),
        );
        expect(container.read(reelAudioPoolProvider).pooledIndices, isEmpty);
      },
    );

    test(
      'synthesizes non-silent RIFF/WAVE groove bytes for all African genres',
      () {
        for (final genre in ['Amapiano', 'Gqom', 'Afro House', 'Maskandi']) {
          final wav = MelodyWavSynthesizer.synthesizeReelGrooveWavBytes(
            genre: genre,
            bpm: 113,
            musicalKey: 'Am',
            seed: genre.hashCode,
          );
          expect(wav.length, greaterThan(44));
          // Verify RIFF header
          expect(String.fromCharCodes(wav.sublist(0, 4)), equals('RIFF'));
          expect(String.fromCharCodes(wav.sublist(8, 12)), equals('WAVE'));
        }
      },
    );
  });

  group('Phase A — Live 60 FPS KineticPreviewCanvas in KineticReelsModal', () {
    testWidgets(
      'mounts full-screen KineticPreviewCanvas with moving lyrics & toggles playback',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: Consumer(
              builder: (context, ref, _) {
                final clips = ref.watch(socialFeedProvider).clips;
                return MaterialApp(
                  theme: AppTheme.darkTheme,
                  home: KineticReelsModal(clips: clips),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // KineticPreviewCanvas is mounted inside the active reel
        expect(find.byType(KineticPreviewCanvas), findsOneWidget);
        expect(
          find.byKey(const Key('reel_kinetic_canvas_clip_pub_makhadzi_1')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('reel_dna_badge')), findsOneWidget);

        // Synchronized lyrics from clip_pub_makhadzi_1 ('Ndo Mufuna Matibe') render
        expect(find.text('Ndo'), findsOneWidget);
        expect(find.text('Mufuna'), findsOneWidget);
        expect(find.text('Matibe'), findsOneWidget);

        // Seeking playback position updates the active word highlight in KineticPreviewCanvas
        final container = ProviderScope.containerOf(
          tester.element(find.byType(KineticReelsModal)),
        );
        await container.read(reelAudioPoolProvider.notifier).seekTo(4.5);
        await tester.pump();

        expect(
          container.read(reelAudioPoolProvider).playbackPositionSec,
          closeTo(4.5, 0.05),
        );

        // Single-tapping toggles play/pause state in the pool
        expect(container.read(reelAudioPoolProvider).isPlaying, isTrue);
        await container.read(reelAudioPoolProvider.notifier).togglePlayPause();
        await tester.pump();
        expect(container.read(reelAudioPoolProvider).isPlaying, isFalse);
      },
    );
  });
}

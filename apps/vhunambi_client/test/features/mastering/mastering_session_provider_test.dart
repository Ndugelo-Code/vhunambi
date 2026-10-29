import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vhunambi_client/features/mastering/domain/models/stem_mastering_recipe.dart';
import 'package:vhunambi_client/features/mastering/presentation/providers/mastering_session_provider.dart';
import 'package:vhunambi_client/features/player/domain/models/stem_mixer_state.dart';
import 'package:vhunambi_client/features/player/domain/services/i_multi_stem_audio_engine.dart';
import 'package:vhunambi_client/features/player/presentation/providers/multi_stem_audio_provider.dart';
import 'package:vhunambi_client/features/player/presentation/providers/stem_mixer_provider.dart';

class _FakeMultiStemEngine extends Fake implements IMultiStemAudioEngine {
  @override
  final bool hasRealStems;

  _FakeMultiStemEngine({this.hasRealStems = true});

  @override
  bool get isPlaying => false;

  @override
  Duration get currentPosition => Duration.zero;

  @override
  Duration get totalDuration => Duration.zero;

  @override
  Stream<Duration> get positionStream => Stream.value(Duration.zero);

  @override
  Stream<bool> get isPlayingStream => Stream.value(false);

  @override
  Duration? get measuredDrift => Duration.zero;

  @override
  void applyMixerState(StemMixerState state) {}
}

ProviderContainer _createTestContainer({List<Override> overrides = const []}) {
  return ProviderContainer(
    overrides: [
      multiStemAudioEngineProvider.overrideWithValue(_FakeMultiStemEngine(hasRealStems: true)),
      ...overrides,
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MasteringSessionNotifier & State (REQ-MST-DOM & REQ-MST-AUD)', () {
    test(
      'Initializes with default Amapiano master recipe and active preview',
      () async {
        final container = _createTestContainer();
        addTearDown(container.dispose);

        final state = container.read(masteringSessionProvider);

        expect(state.trackId, 'trk_active_master');
        expect(state.genre, 'Amapiano');
        expect(state.isMasteredPreviewActive, isTrue);
        expect(state.recipe.presetId, 'amapiano_club_knock');
        expect(state.isBaking, isFalse);
        expect(state.hasBakedMaster, isFalse);
      },
    );

    test('initializeForTrack sets track metadata and genre-matched recipe', () async {
      final container = _createTestContainer();
      addTearDown(container.dispose);

      final notifier = container.read(masteringSessionProvider.notifier);
      notifier.initializeForTrack(
        trackId: 'trk_maskandi_99',
        trackTitle: 'Inhlanzi Yase Goli',
        genre: 'Maskandi',
      );

      final state = container.read(masteringSessionProvider);
      expect(state.trackId, 'trk_maskandi_99');
      expect(state.trackTitle, 'Inhlanzi Yase Goli');
      expect(state.genre, 'Maskandi');
      expect(state.recipe.presetId, 'maskandi_acoustic_clarity');
      expect(state.isMasteredPreviewActive, isTrue);
    });

    test(
      'selectGenrePreset / applyPreset updates active recipe and mixer DSP',
      () async {
        final container = _createTestContainer();
        addTearDown(container.dispose);

        final notifier = container.read(masteringSessionProvider.notifier);
        notifier.applyPreset('gqom_warehouse_sub');

        final state = container.read(masteringSessionProvider);
        expect(state.recipe.presetId, 'gqom_warehouse_sub');
        expect(state.recipe.bass.subHarmonicMix, 0.7);

        // Verify stemMixerProvider DSP was updated
        final mixer = container.read(stemMixerProvider);
        expect(mixer.masterDsp.sidechainCompression, greaterThan(0.0));
      },
    );

    test('setTargetLufs sets target loudness and marks recipe as custom', () async {
      final container = _createTestContainer();
      addTearDown(container.dispose);

      final notifier = container.read(masteringSessionProvider.notifier);
      notifier.setTargetLufs(-14.0);

      final state = container.read(masteringSessionProvider);
      expect(state.recipe.targetLufs, -14.0);
      expect(state.recipe.presetId, 'custom');
    });

    test('Flavors update underlying DSP configurations deterministically', () async {
      final container = _createTestContainer();
      addTearDown(container.dispose);

      final notifier = container.read(masteringSessionProvider.notifier);

      notifier.setVocalFlavor(VocalCleanseFlavor.off);
      expect(
        container
            .read(masteringSessionProvider)
            .recipe
            .vocals
            .neuralDenoiseStrength,
        0.0,
      );

      notifier.setVocalFlavor(VocalCleanseFlavor.wideAnthem);
      expect(
        container
            .read(masteringSessionProvider)
            .recipe
            .vocals
            .compressionAmount,
        0.75,
      );

      notifier.setBassFlavor(BassCharacterFlavor.deepSub808);
      expect(
        container.read(masteringSessionProvider).recipe.bass.subHarmonicMix,
        0.75,
      );
      expect(
        container.read(masteringSessionProvider).recipe.bass.knockDriveDb,
        5.0,
      );

      notifier.setDrumFlavor(DrumCharacterFlavor.clubPunch);
      expect(
        container
            .read(masteringSessionProvider)
            .recipe
            .drums
            .transientAttackSnap,
        0.65,
      );

      notifier.setMelodicFlavor(MelodicCharacterFlavor.brightAcoustic);
      expect(
        container
            .read(masteringSessionProvider)
            .recipe
            .melodic
            .stereoWidthBoost,
        0.45,
      );
    });

    test(
      'togglePreviewBypass toggles preview and restores mixer gains on bypass',
      () async {
        final container = _createTestContainer();
        addTearDown(container.dispose);

        final notifier = container.read(masteringSessionProvider.notifier);
        expect(
          container.read(masteringSessionProvider).isMasteredPreviewActive,
          isTrue,
        );

        // Toggle off (Raw AI Bypass)
        notifier.togglePreviewBypass();
        expect(
          container.read(masteringSessionProvider).isMasteredPreviewActive,
          isFalse,
        );

        final mixerBypassed = container.read(stemMixerProvider);
        expect(mixerBypassed.channelFor(StemType.bass).gain, 1.0);
        expect(mixerBypassed.channelFor(StemType.vocals).gain, 1.0);

        // Toggle back on (Mastered Active)
        notifier.togglePreviewBypass();
        expect(
          container.read(masteringSessionProvider).isMasteredPreviewActive,
          isTrue,
        );
      },
    );

    test('Granular config updates modify state and recipe', () async {
      final container = _createTestContainer();
      addTearDown(container.dispose);

      final notifier = container.read(masteringSessionProvider.notifier);
      final current = container.read(masteringSessionProvider).recipe;

      notifier.updateVocalConfig(
        current.vocals.copyWith(neuralDenoiseStrength: 0.99),
      );
      expect(
        container
            .read(masteringSessionProvider)
            .recipe
            .vocals
            .neuralDenoiseStrength,
        0.99,
      );

      notifier.updateBassConfig(current.bass.copyWith(knockDriveDb: 8.5));
      expect(
        container.read(masteringSessionProvider).recipe.bass.knockDriveDb,
        8.5,
      );

      notifier.updateDrumConfig(current.drums.copyWith(parallelCrushMix: 0.8));
      expect(
        container.read(masteringSessionProvider).recipe.drums.parallelCrushMix,
        0.8,
      );

      notifier.updateMelodicConfig(
        current.melodic.copyWith(stereoWidthBoost: 0.9),
      );
      expect(
        container
            .read(masteringSessionProvider)
            .recipe
            .melodic
            .stereoWidthBoost,
        0.9,
      );
    });

    test('bakeMaster bakes master successfully with HTTP mock', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/master')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'masteredMp3Url':
                  'https://cdn.vhunambi.com/audio/mastered_123.mp3',
              'masteredWavUrl':
                  'https://cdn.vhunambi.com/audio/mastered_123.wav',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final container = _createTestContainer(
        overrides: [
          masteringSessionProvider.overrideWith(
            (ref) => MasteringSessionNotifier(ref, httpClient: mockClient),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(masteringSessionProvider.notifier);
      final success = await notifier.bakeMaster();

      expect(success, isTrue);
      final state = container.read(masteringSessionProvider);
      expect(state.hasBakedMaster, isTrue);
      expect(state.masteredMp3Url, contains('mastered_123.mp3'));
      expect(state.masteredWavUrl, contains('mastered_123.wav'));
    });
  });
}

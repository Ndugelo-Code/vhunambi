import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/player/data/services/headless_multi_stem_engine.dart';
import 'package:vhunambi_client/features/player/domain/models/stem_mixer_state.dart';

void main() {
  group('HeadlessMultiStemEngine Tests (REQ-STEM-AUDIO-01 .. 06)', () {
    late HeadlessMultiStemEngine engine;

    setUp(() {
      engine = HeadlessMultiStemEngine();
    });

    tearDown(() async {
      await engine.dispose();
    });

    test('Initializes with default unity volumes and center pan', () {
      expect(engine.isPlaying, isFalse);
      expect(engine.currentPosition, Duration.zero);
      expect(engine.channelVolumes[StemType.vocals], 1.0);
      expect(engine.channelVolumes[StemType.drums], 1.0);
      expect(engine.channelVolumes[StemType.bass], 1.0);
      expect(engine.channelVolumes[StemType.melody], 1.0);
      expect(engine.channelPans[StemType.vocals], 0.0);
    });

    test('play and pause emit stream events', () async {
      expectLater(engine.isPlayingStream, emitsInOrder([true, false]));

      await engine.play();
      expect(engine.isPlaying, isTrue);

      await engine.pause();
      expect(engine.isPlaying, isFalse);
    });

    test('seek updates position and emits position stream event', () async {
      const targetPos = Duration(seconds: 45);
      expectLater(engine.positionStream, emits(targetPos));

      await engine.seek(targetPos);
      expect(engine.currentPosition, targetPos);
    });

    test('applyMixerState maps mute and gain correctly', () {
      final state = const StemMixerState(
        channels: [
          StemChannel(type: StemType.vocals, name: 'Vocals', emoji: '🎤', gain: 1.2, isMuted: true),
          StemChannel(type: StemType.drums, name: 'Drums', emoji: '🥁', gain: 0.9, pan: -0.5),
          StemChannel(type: StemType.bass, name: 'Bass', emoji: '🎹', gain: 1.4),
          StemChannel(type: StemType.melody, name: 'Melody', emoji: '🎸', gain: 1.0),
        ],
      );

      engine.applyMixerState(state);

      // Vocals muted => effective volume 0.0
      expect(engine.channelVolumes[StemType.vocals], 0.0);
      // Drums unmuted => effective volume 0.9, pan -0.5
      expect(engine.channelVolumes[StemType.drums], 0.9);
      expect(engine.channelPans[StemType.drums], -0.5);
      // Bass gain 1.4
      expect(engine.channelVolumes[StemType.bass], 1.4);
    });

    test('applyMixerState enforces solo exclusivity', () {
      final state = const StemMixerState(
        channels: [
          StemChannel(type: StemType.vocals, name: 'Vocals', emoji: '🎤', gain: 1.0),
          StemChannel(type: StemType.drums, name: 'Drums', emoji: '🥁', gain: 1.1, isSolo: true),
          StemChannel(type: StemType.bass, name: 'Bass', emoji: '🎹', gain: 1.2),
          StemChannel(type: StemType.melody, name: 'Melody', emoji: '🎸', gain: 1.0),
        ],
      );

      engine.applyMixerState(state);

      // Only drums is solo => drums has 1.1, others zero
      expect(engine.channelVolumes[StemType.drums], 1.1);
      expect(engine.channelVolumes[StemType.vocals], 0.0);
      expect(engine.channelVolumes[StemType.bass], 0.0);
      expect(engine.channelVolumes[StemType.melody], 0.0);
    });

    test('loadFromManifest with empty stemUrls triggers master-only mode', () async {
      await engine.loadFromManifest(
        stemUrls: const {},
        masterUrl: 'https://r2.vhunambi.com/audio/master.mp3',
      );

      expect(engine.hasRealStems, isFalse);
      expect(engine.measuredDrift, isNull);
    });

    test('loadFromManifest with all 4 stems enables real stems mode', () async {
      await engine.loadFromManifest(
        stemUrls: const {
          StemType.vocals: 'https://r2.vhunambi.com/audio/vocals.wav',
          StemType.drums: 'https://r2.vhunambi.com/audio/drums.wav',
          StemType.bass: 'https://r2.vhunambi.com/audio/bass.wav',
          StemType.melody: 'https://r2.vhunambi.com/audio/melody.wav',
        },
        masterUrl: 'https://r2.vhunambi.com/audio/master.mp3',
      );

      expect(engine.hasRealStems, isTrue);
      expect(engine.measuredDrift, Duration.zero);

      // Verify drift setter updates measuredDrift
      engine.setMeasuredDrift(const Duration(milliseconds: 18));
      expect(engine.measuredDrift, const Duration(milliseconds: 18));
    });
  });
}

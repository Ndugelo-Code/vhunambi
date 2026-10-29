import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/player/domain/models/stem_mixer_state.dart';
import 'package:vhunambi_client/features/player/presentation/providers/stem_mixer_provider.dart';

void main() {
  group('StemChannel & StemMixerState Model', () {
    test('effectiveVolume respects mute and solo priorities', () {
      const channel = StemChannel(
        type: StemType.vocals,
        name: 'Vocals',
        emoji: '🎤',
        gain: 1.2,
      );

      // Normal state: effectiveVolume is unity or current gain
      expect(channel.effectiveVolume(false), 1.2);

      // Muted: volume drops to 0.0
      final muted = channel.copyWith(isMuted: true);
      expect(muted.effectiveVolume(false), 0.0);

      // When another channel is soloed, non-solo channel is silenced
      expect(channel.effectiveVolume(true), 0.0);

      // Soloed channel plays when solo is active
      final soloed = channel.copyWith(isSolo: true);
      expect(soloed.effectiveVolume(true), 1.2);
    });

    test('gainDecibels formats readable volume readouts', () {
      const unity = StemChannel(type: StemType.drums, name: 'Drums', emoji: '🥁', gain: 1.0);
      expect(unity.gainDecibels, '+0.0 dB');

      const boosted = StemChannel(type: StemType.drums, name: 'Drums', emoji: '🥁', gain: 1.25);
      expect(boosted.gainDecibels, contains('+3.0 dB'));

      const muted = StemChannel(type: StemType.drums, name: 'Drums', emoji: '🥁', gain: 0.0);
      expect(muted.gainDecibels, '-inf dB');
    });

    test('MasterBusDsp serializes and deserializes accurately', () {
      const dsp = MasterBusDsp(
        logDrumSaturation: 0.8,
        vocalPlateReverb: 0.65,
        sidechainCompression: 0.7,
        stereoWidth: 1.3,
      );

      final json = dsp.toJson();
      final fromJson = MasterBusDsp.fromJson(json);

      expect(fromJson.logDrumSaturation, 0.8);
      expect(fromJson.vocalPlateReverb, 0.65);
      expect(fromJson.sidechainCompression, 0.7);
      expect(fromJson.stereoWidth, 1.3);
    });
  });

  group('StemMixerNotifier & stemMixerProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state contains all 4 default channels and master DSP', () {
      final state = container.read(stemMixerProvider);
      expect(state.channels.length, 4);

      final types = state.channels.map((c) => c.type).toList();
      expect(types, containsAll([
        StemType.vocals,
        StemType.drums,
        StemType.bass,
        StemType.melody,
      ]));
      expect(state.anySoloActive, isFalse);
    });

    test('setChannelGain clamps between 0.0 and 1.5', () {
      final notifier = container.read(stemMixerProvider.notifier);

      notifier.setChannelGain(StemType.bass, 1.3);
      expect(container.read(stemMixerProvider).channelFor(StemType.bass).gain, 1.3);

      // Overshoot clamped
      notifier.setChannelGain(StemType.bass, 2.5);
      expect(container.read(stemMixerProvider).channelFor(StemType.bass).gain, 1.5);

      // Negative clamped
      notifier.setChannelGain(StemType.bass, -0.5);
      expect(container.read(stemMixerProvider).channelFor(StemType.bass).gain, 0.0);
    });

    test('toggleMute and toggleSolo update channel flags', () {
      final notifier = container.read(stemMixerProvider.notifier);

      notifier.toggleMute(StemType.vocals);
      expect(container.read(stemMixerProvider).channelFor(StemType.vocals).isMuted, isTrue);

      notifier.toggleMute(StemType.vocals);
      expect(container.read(stemMixerProvider).channelFor(StemType.vocals).isMuted, isFalse);

      notifier.toggleSolo(StemType.drums);
      expect(container.read(stemMixerProvider).channelFor(StemType.drums).isSolo, isTrue);
      expect(container.read(stemMixerProvider).anySoloActive, isTrue);
    });

    test('applyPreset updates master DSP and channel gain balance', () {
      final notifier = container.read(stemMixerProvider.notifier);

      notifier.applyPreset('Amapiano Club Banger');
      final state = container.read(stemMixerProvider);

      expect(state.masterDsp.logDrumSaturation, 0.85);
      expect(state.masterDsp.sidechainCompression, 0.75);
      expect(state.channelFor(StemType.bass).gain, 1.25);
    });

    test('bounceMasterMix renders output path and updates state', () async {
      final tempDir = await Directory.systemTemp.createTemp('stem_test_');
      try {
        final notifier = StemMixerNotifier(
          outputDirectoryResolver: () async => tempDir.path,
        );

        final result = await notifier.bounceMasterMix();
        expect(result.path, contains(tempDir.path));
        expect(result.path, endsWith('.wav'));
        expect(result.isSimulated, isTrue);
        expect(File(result.path).existsSync(), isTrue);
        expect(notifier.state.lastBouncedAudioPath, result.path);
        expect(notifier.state.isBouncing, isFalse);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('bounceMasterMix rejects re-entry while isBouncing is true', () async {
      final tempDir =
          await Directory.systemTemp.createTemp('stem_test_reentry_');
      try {
        final notifier = StemMixerNotifier(
          outputDirectoryResolver: () async => tempDir.path,
        );

        final future1 = notifier.bounceMasterMix();
        expect(() => notifier.bounceMasterMix(), throwsA(isA<StateError>()));
        await future1;
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });
}

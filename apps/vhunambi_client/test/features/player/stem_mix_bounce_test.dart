import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/player/data/services/stem_mix_bounce_service.dart';
import 'package:vhunambi_client/features/player/data/services/wav_file_writer_io.dart';
import 'package:vhunambi_client/features/player/domain/models/stem_mixer_state.dart';

void main() {
  group('StemMixBounceService Tests (REQ-MIX-01..03, Phase 37)', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('vhunambi_bounce_test_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    test('createWavFile generates valid 44-byte RIFF/WAV header', () {
      final pcmBytes = Uint8List(1000);
      final wav = StemMixBounceService.createWavFile(pcmBytes, 44100, 2);

      expect(wav.length, 1000 + 44);
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      expect(String.fromCharCodes(wav.sublist(12, 16)), 'fmt ');
      expect(String.fromCharCodes(wav.sublist(36, 40)), 'data');

      final bd = ByteData.sublistView(wav);
      expect(bd.getUint32(4, Endian.little), 1000 + 36);
      expect(bd.getUint16(20, Endian.little), 1); // PCM
      expect(bd.getUint16(22, Endian.little), 2); // stereo
      expect(bd.getUint32(24, Endian.little), 44100);
      expect(bd.getUint16(34, Endian.little), 16);
      expect(bd.getUint32(40, Endian.little), 1000);
    });

    test('bounceMixToFile writes a real file and flags it simulated when unpopulated', () async {
      final service = StemMixBounceService(writer: writeWavToFile);
      final target = '${tempDir.path}/bounces/test_bounce_simulated.wav';

      final result = await service.bounceMixToFile(
        mixerState: const StemMixerState(channels: kDefaultStemChannels),
        targetPath: target,
        duration: const Duration(seconds: 1),
      );

      expect(result.path, target);
      expect(result.isSimulated, isTrue);
      expect(File(target).existsSync(), isTrue);
      expect(File(target).lengthSync(), 44100 * 2 * 2 + 44);
    });

    test('bounceMixToFile produces real non-silent PCM when audio is synthesized (REQ-MIX-01..03)', () async {
      final service = StemMixBounceService(writer: writeWavToFile);
      final target = '${tempDir.path}/bounces/test_bounce_real.wav';

      final result = await service.bounceMixToFile(
        mixerState: const StemMixerState(channels: kDefaultStemChannels),
        targetPath: target,
        duration: const Duration(seconds: 1),
        synthesizeGrooveIfEmpty: true,
      );

      expect(result.path, target);
      expect(result.isSimulated, isFalse);
      expect(File(target).existsSync(), isTrue);
      expect(result.bouncedWavBytes, isNotNull);

      // Verify PCM contains non-zero audible samples
      final wavBytes = File(target).readAsBytesSync();
      expect(wavBytes.length, 44100 * 2 * 2 + 44);

      final pcmView = ByteData.sublistView(wavBytes, 44);
      var nonZeroCount = 0;
      var maxPeak = 0;

      for (var i = 0; i < (wavBytes.length - 44) ~/ 2; i++) {
        final sample = pcmView.getInt16(i * 2, Endian.little);
        if (sample != 0) nonZeroCount++;
        if (sample.abs() > maxPeak) maxPeak = sample.abs();
      }

      // Must have audible signal
      expect(nonZeroCount, greaterThan(100));
      // Must not exceed -1.0 dBFS true-peak limiter ceiling
      expect(maxPeak, lessThanOrEqualTo(StemMixBounceService.kMax16BitCeiling));
    });

    test('bounceMixToFile correctly sums vocalAudio with pan and fader laws', () async {
      final service = StemMixBounceService(writer: writeWavToFile);
      final target = '${tempDir.path}/bounces/test_bounce_vocal.wav';

      // 440 Hz sine wave for 0.5s
      final vocalBuffer = Float32List(22050);
      for (var i = 0; i < vocalBuffer.length; i++) {
        vocalBuffer[i] = 0.5; // DC test pulse
      }

      final result = await service.bounceMixToFile(
        mixerState: const StemMixerState(
          channels: [
            StemChannel(type: StemType.vocals, name: 'Vocals', emoji: '🎤', gain: 1.2, pan: 0.0),
            StemChannel(type: StemType.drums, name: 'Drums', emoji: '🥁', gain: 0.0),
            StemChannel(type: StemType.bass, name: 'Bass', emoji: '🔊', gain: 0.0),
            StemChannel(type: StemType.melody, name: 'Melody', emoji: '🎹', gain: 0.0),
          ],
        ),
        targetPath: target,
        duration: const Duration(milliseconds: 500),
        vocalAudio: vocalBuffer,
      );

      expect(result.isSimulated, isFalse);
      expect(File(target).existsSync(), isTrue);

      final (left, right) = StemMixBounceService.parseWavPcm16(File(target).readAsBytesSync());
      expect(left.isNotEmpty, isTrue);
      // Both channels should have received positive vocal energy
      expect(left[100], greaterThan(0.0));
      expect(right[100], greaterThan(0.0));
    });

    test('write failures propagate instead of returning a phantom path', () async {
      final service = StemMixBounceService(
        writer: (path, bytes) async => throw const FileSystemException('disk full'),
      );

      expect(
        () => service.bounceMixToFile(
          mixerState: const StemMixerState(channels: kDefaultStemChannels),
          targetPath: '${tempDir.path}/never.wav',
          duration: const Duration(seconds: 1),
        ),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('duration is clamped to maxDuration', () async {
      Uint8List? captured;
      final service = StemMixBounceService(
        writer: (path, bytes) async => captured = bytes,
      );

      final result = await service.bounceMixToFile(
        mixerState: const StemMixerState(channels: kDefaultStemChannels),
        targetPath: 'ignored.wav',
        duration: const Duration(minutes: 30),
      );

      expect(result.duration, StemMixBounceService.maxDuration);
      expect(captured, isNotNull);
    });
  });
}

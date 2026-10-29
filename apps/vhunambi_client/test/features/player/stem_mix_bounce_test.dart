import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/player/data/services/stem_mix_bounce_service.dart';
import 'package:vhunambi_client/features/player/data/services/wav_file_writer_io.dart';
import 'package:vhunambi_client/features/player/domain/models/stem_mixer_state.dart';

void main() {
  group('StemMixBounceService Tests (REQ-STEM-AUDIO-05)', () {
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

    test('bounceMixToFile writes a real file and flags it simulated', () async {
      final service = StemMixBounceService(writer: writeWavToFile);
      final target = '${tempDir.path}/bounces/test_bounce.wav';

      final result = await service.bounceMixToFile(
        mixerState: const StemMixerState(channels: kDefaultStemChannels),
        targetPath: target,
        duration: const Duration(seconds: 1),
      );

      expect(result.path, target);
      expect(result.isSimulated, isTrue);
      expect(File(target).existsSync(), isTrue);
      // 1 s * 44100 * 2 ch * 2 bytes + 44 header
      expect(File(target).lengthSync(), 44100 * 2 * 2 + 44);
    });

    test('write failures propagate instead of returning a phantom path',
        () async {
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

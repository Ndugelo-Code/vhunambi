import 'dart:typed_data';
import '../../domain/models/stem_mixer_state.dart';

/// Persists encoded WAV bytes to [path]. Injected so this service stays free of
/// `dart:io` (web-safe) and so tests can target a temp directory.
/// Implementations MUST throw on failure; the service never swallows errors.
typedef WavFileWriter = Future<void> Function(String path, Uint8List bytes);

/// Outcome of a bounce. [isSimulated] is true until real stem decoding exists
/// (needs real stems from the Tier 2 GPU worker plus a PCM decoder).
class BounceResult {
  final String path;
  final bool isSimulated;
  final Duration duration;

  const BounceResult({
    required this.path,
    required this.isSimulated,
    required this.duration,
  });
}

/// Bounces the current stem balance into a WAV file (REQ-STEM-AUDIO-05).
///
/// **SIMULATED:** no audio decoder or real stems are available in the app yet,
/// so the PCM payload is valid but SILENT. The result is flagged
/// `isSimulated: true` so UI and callers never present it as a real mixdown.
class StemMixBounceService {
  static const int sampleRate = 44100;
  static const int channels = 2;

  /// Hard cap to bound memory (PCM + WAV copies) until streaming write exists.
  static const Duration maxDuration = Duration(minutes: 3);

  final WavFileWriter writer;

  const StemMixBounceService({required this.writer});

  /// Encodes 16-bit PCM bytes into a standard 44-byte RIFF/WAV container.
  static Uint8List createWavFile(
    Uint8List pcmBytes,
    int sampleRate,
    int numChannels,
  ) {
    final byteRate = sampleRate * numChannels * 2;
    final blockAlign = numChannels * 2;
    final dataLen = pcmBytes.length;

    final header = ByteData(44)
      ..setUint8(0, 0x52) // R
      ..setUint8(1, 0x49) // I
      ..setUint8(2, 0x46) // F
      ..setUint8(3, 0x46) // F
      ..setUint32(4, dataLen + 36, Endian.little)
      ..setUint8(8, 0x57) // W
      ..setUint8(9, 0x41) // A
      ..setUint8(10, 0x56) // V
      ..setUint8(11, 0x45) // E
      ..setUint8(12, 0x66) // f
      ..setUint8(13, 0x6D) // m
      ..setUint8(14, 0x74) // t
      ..setUint8(15, 0x20) // space
      ..setUint32(16, 16, Endian.little)
      ..setUint16(20, 1, Endian.little)
      ..setUint16(22, numChannels, Endian.little)
      ..setUint32(24, sampleRate, Endian.little)
      ..setUint32(28, byteRate, Endian.little)
      ..setUint16(32, blockAlign, Endian.little)
      ..setUint16(34, 16, Endian.little)
      ..setUint8(36, 0x64) // d
      ..setUint8(37, 0x61) // a
      ..setUint8(38, 0x74) // t
      ..setUint8(39, 0x61) // a
      ..setUint32(40, dataLen, Endian.little);

    final wav = Uint8List(44 + dataLen)
      ..setRange(0, 44, header.buffer.asUint8List())
      ..setRange(44, 44 + dataLen, pcmBytes);
    return wav;
  }

  /// Writes a (currently silent) WAV to [targetPath]. Throws if the write
  /// fails; callers must handle the error rather than receive a phantom path.
  Future<BounceResult> bounceMixToFile({
    required StemMixerState mixerState,
    required String targetPath,
    Duration duration = const Duration(seconds: 5),
  }) async {
    final clamped = duration > maxDuration ? maxDuration : duration;
    final totalSamples = (sampleRate * clamped.inMilliseconds / 1000).round();
    final pcm = Uint8List(totalSamples * channels * 2); // zeros = silence

    await writer(targetPath, createWavFile(pcm, sampleRate, channels));

    return BounceResult(
      path: targetPath,
      isSimulated: true,
      duration: clamped,
    );
  }
}

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'i_audio_intake_recorder.dart';

/// Production microphone audio intake recorder using `package:record` (REQ-SIG-INTAKE-01).
///
/// Disables hardware echo cancellation, noise suppression, and auto gain control
/// to capture uncolored acoustics and natural Bantu consonant transients at 44.1 kHz.
class RealAudioIntakeRecorder implements IAudioIntakeRecorder {
  RealAudioIntakeRecorder({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  final StreamController<double> _amplitudeController =
      StreamController<double>.broadcast();

  StreamSubscription<Amplitude>? _amplitudeSub;
  bool _isRecording = false;
  String? _activeTempPath;
  DateTime? _startTime;

  @override
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  @override
  bool get isRecording => _isRecording;

  @override
  Future<void> startRecording({
    int sampleRate = 44100,
    int numChannels = 1,
  }) async {
    final hasPerm = await _recorder.hasPermission();
    if (!hasPerm) {
      throw const SocketException('Microphone permission not granted');
    }

    final tempDir = await getTemporaryDirectory();
    final tempFile = File(
      '${tempDir.path}/raw_intake_${DateTime.now().millisecondsSinceEpoch}.wav',
    );
    _activeTempPath = tempFile.path;

    const config = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 44100,
      numChannels: 1,
      echoCancel: false,
      autoGain: false,
      noiseSuppress: false,
    );

    await _recorder.start(config, path: _activeTempPath!);
    _isRecording = true;
    _startTime = DateTime.now();

    // Stream real RMS amplitude from hardware (polled at 50ms intervals)
    _amplitudeSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 50))
        .listen((amp) {
      if (!_amplitudeController.isClosed) {
        // amp.current is in dBFS (-160 .. 0 dB)
        // Map [-60 dBFS .. 0 dBFS] to normalized [0.0 .. 1.0]
        final normalized = ((amp.current + 60.0) / 60.0).clamp(0.0, 1.0);
        _amplitudeController.add(normalized);
      }
    });
  }

  @override
  Future<RawTakeResult> stopRecording() async {
    _isRecording = false;
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;

    final path = await _recorder.stop();
    final filePath = path ?? _activeTempPath;

    if (filePath == null) {
      throw StateError('RealAudioIntakeRecorder: No audio output path recorded');
    }

    final file = File(filePath);
    if (!await file.exists()) {
      throw StateError('RealAudioIntakeRecorder: Recorded audio file does not exist');
    }

    final rawBytes = await file.readAsBytes();
    final elapsedSec = _startTime != null
        ? DateTime.now().difference(_startTime!).inMilliseconds / 1000.0
        : 1.0;

    // Parse PCM16 data and synthesize a clean 44.1 kHz RIFF WAV buffer if needed
    final result = _parseWavPayload(rawBytes, math.max(0.1, elapsedSec));

    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}

    return result;
  }

  RawTakeResult _parseWavPayload(Uint8List fileBytes, double elapsedSec) {
    var pcmOffset = 0;
    var pcmLength = fileBytes.length;

    // Check for RIFF WAV header
    if (fileBytes.length >= 44 &&
        fileBytes[0] == 0x52 &&
        fileBytes[1] == 0x49 &&
        fileBytes[2] == 0x46 &&
        fileBytes[3] == 0x46) {
      // Find "data" chunk
      for (var i = 12; i < fileBytes.length - 8; i++) {
        if (fileBytes[i] == 0x64 &&
            fileBytes[i + 1] == 0x61 &&
            fileBytes[i + 2] == 0x74 &&
            fileBytes[i + 3] == 0x61) {
          pcmOffset = i + 8;
          final bd = ByteData.sublistView(fileBytes, i + 4, i + 8);
          pcmLength = math.min(bd.getUint32(0, Endian.little), fileBytes.length - pcmOffset);
          break;
        }
      }
    }

    final sampleCount = pcmLength ~/ 2;
    final pcmSamples = Float32List(sampleCount);
    final bd = ByteData.sublistView(fileBytes, pcmOffset, pcmOffset + sampleCount * 2);

    for (var i = 0; i < sampleCount; i++) {
      final s16 = bd.getInt16(i * 2, Endian.little);
      pcmSamples[i] = s16 / 32768.0;
    }

    final durationSec = sampleCount / 44100.0;

    // Build guaranteed-valid RIFF 44.1 kHz header container
    final fullWav = _build44100WavHeader(fileBytes.sublist(pcmOffset, pcmOffset + sampleCount * 2));

    return RawTakeResult(
      wavBytes: fullWav,
      pcmSamples: pcmSamples,
      durationSec: durationSec > 0.05 ? durationSec : elapsedSec,
      sampleRate: 44100,
      numChannels: 1,
    );
  }

  Uint8List _build44100WavHeader(Uint8List pcm16Data) {
    final dataSize = pcm16Data.length;
    final buffer = ByteData(44 + dataSize);

    // "RIFF"
    buffer.setUint8(0, 0x52);
    buffer.setUint8(1, 0x49);
    buffer.setUint8(2, 0x46);
    buffer.setUint8(3, 0x46);
    buffer.setUint32(4, 36 + dataSize, Endian.little);
    // "WAVEfmt "
    buffer.setUint8(8, 0x57);
    buffer.setUint8(9, 0x41);
    buffer.setUint8(10, 0x56);
    buffer.setUint8(11, 0x45);
    buffer.setUint8(12, 0x66);
    buffer.setUint8(13, 0x6D);
    buffer.setUint8(14, 0x74);
    buffer.setUint8(15, 0x20);
    buffer.setUint32(16, 16, Endian.little); // Subchunk1Size (16 for PCM)
    buffer.setUint16(20, 1, Endian.little); // AudioFormat 1 = PCM
    buffer.setUint16(22, 1, Endian.little); // NumChannels = 1 (Mono)
    buffer.setUint32(24, 44100, Endian.little); // SampleRate = 44.1 kHz
    buffer.setUint32(28, 88200, Endian.little); // ByteRate = 44100 * 1 * 2
    buffer.setUint16(32, 2, Endian.little); // BlockAlign = 1 * 2
    buffer.setUint16(34, 16, Endian.little); // BitsPerSample = 16
    // "data"
    buffer.setUint8(36, 0x64);
    buffer.setUint8(37, 0x61);
    buffer.setUint8(38, 0x74);
    buffer.setUint8(39, 0x61);
    buffer.setUint32(40, dataSize, Endian.little);

    final outBytes = buffer.buffer.asUint8List();
    outBytes.setRange(44, 44 + dataSize, pcm16Data);
    return outBytes;
  }

  @override
  void dispose() {
    _isRecording = false;
    _amplitudeSub?.cancel();
    _amplitudeController.close();
    _recorder.dispose();
  }
}


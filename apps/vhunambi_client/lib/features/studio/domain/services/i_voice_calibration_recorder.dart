import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import '../models/vocal_identity_models.dart';

/// Output produced when a 3-line voice calibration recording finishes (REQ-VOC-08).
class VoiceCalibrationRecordingResult {
  const VoiceCalibrationRecordingResult({
    required this.wavBytes,
    required this.durationSec,
    required this.timbreEmbeddingPreview,
    required this.phonemeCadenceMap,
    required this.cadenceWpm,
    required this.clarityScore,
  });

  final Uint8List wavBytes;
  final double durationSec;
  final List<double> timbreEmbeddingPreview;
  final Map<String, double> phonemeCadenceMap;
  final int cadenceWpm;
  final double clarityScore;
}

/// Injectable microphone recorder interface for 3-line zero-shot voice calibration (REQ-VOC-07).
///
/// Prevents `MissingPluginException` in headless `flutter test` runs while providing live
/// amplitude metering and valid 16-bit PCM WAV header synthesis.
abstract class IVoiceCalibrationRecorder {
  /// Stream of normalized microphone RMS amplitude values (0.0 .. 1.0).
  Stream<double> get amplitudeStream;

  /// Whether a calibration recording is currently active.
  bool get isRecording;

  /// Begins capturing microphone audio for the given [script].
  Future<void> startRecording(PhoneticCalibrationScript script);

  /// Stops capturing and computes the speaker timbre embedding & phoneme cadence ratios.
  Future<VoiceCalibrationRecordingResult> stopRecording();

  /// Releases any internal resources without leaving pending timers.
  void dispose();
}

/// Deterministic, zero-plugin-crash voice calibration recorder (REQ-VOC-07, REQ-VOC-08).
///
/// Note on headless test safety: emits an initial amplitude frame synchronously upon
/// `startRecording` and exposes `pulseAmplitude()` for UI animation without spawning
/// background `Timer.periodic` instances that could trip Flutter's pending-timer assertion.
class DeterministicVoiceCalibrationRecorder implements IVoiceCalibrationRecorder {
  final StreamController<double> _amplitudeController =
      StreamController<double>.broadcast();

  bool _isRecording = false;
  PhoneticCalibrationScript? _activeScript;
  int _stepCounter = 0;

  @override
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  @override
  bool get isRecording => _isRecording;

  @override
  Future<void> startRecording(PhoneticCalibrationScript script) async {
    _activeScript = script;
    _isRecording = true;
    _stepCounter = 1;
    if (!_amplitudeController.isClosed) {
      _amplitudeController.add(0.68);
    }
  }

  /// Advances the simulated microphone RMS waveform deterministically.
  double sampleAmplitudeAt(int barIndex) {
    if (!_isRecording) return 0.12;
    final phase = (_stepCounter + barIndex) * 0.55;
    final val = 0.35 + 0.55 * ((math.sin(phase) + 1.0) / 2.0);
    return val.clamp(0.15, 0.95);
  }

  @override
  Future<VoiceCalibrationRecordingResult> stopRecording() async {
    _isRecording = false;
    if (!_amplitudeController.isClosed) {
      _amplitudeController.add(0.0);
    }

    final script = _activeScript ??
        const PhoneticCalibrationScript(
          language: 'Tshivenḓa',
          lines: [],
          totalEstimatedDurationSec: 18,
        );

    final durationSec = math.max(15.0, script.totalEstimatedDurationSec.toDouble());
    final allText = script.lines.map((l) => l.text).join(' ');
    final seed = allText.isEmpty ? 42 : allText.codeUnits.fold<int>(0, (a, b) => a + b);

    // Deterministic 8-float preview of the 256-D speaker timbre vector
    final timbrePreview = List<double>.generate(8, (i) {
      final raw = math.sin((seed + i * 17) * 0.31) * 0.85;
      return (raw * 10000).roundToDouble() / 10000.0;
    });

    // Extract per-token cadence ratio map from the highlighted Bantu tokens
    final cadenceMap = <String, double>{};
    for (final line in script.lines) {
      for (var i = 0; i < line.highlightedTokens.length; i++) {
        final token = line.highlightedTokens[i];
        final ratio = 0.92 + ((token.length + i) % 5) * 0.06;
        cadenceMap[token] = (ratio * 100).roundToDouble() / 100.0;
      }
    }

    final wordCount = allText
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
    final cadenceWpm = math.max(92, math.min(148, ((wordCount / durationSec) * 60).round()));

    return VoiceCalibrationRecordingResult(
      wavBytes: _buildValidMinimalWavHeader(seed),
      durationSec: durationSec,
      timbreEmbeddingPreview: timbrePreview,
      phonemeCadenceMap: cadenceMap,
      cadenceWpm: cadenceWpm,
      clarityScore: 0.96,
    );
  }

  Uint8List _buildValidMinimalWavHeader(int seed) {
    const sampleCount = 64;
    const dataSize = sampleCount * 2;
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
    buffer.setUint32(16, 16, Endian.little); // PCM chunk size
    buffer.setUint16(20, 1, Endian.little); // AudioFormat = 1 (PCM)
    buffer.setUint16(22, 1, Endian.little); // NumChannels = 1 (Mono)
    buffer.setUint32(24, 24000, Endian.little); // SampleRate = 24kHz
    buffer.setUint32(28, 48000, Endian.little); // ByteRate
    buffer.setUint16(32, 2, Endian.little); // BlockAlign
    buffer.setUint16(34, 16, Endian.little); // BitsPerSample = 16
    // "data"
    buffer.setUint8(36, 0x64);
    buffer.setUint8(37, 0x61);
    buffer.setUint8(38, 0x74);
    buffer.setUint8(39, 0x61);
    buffer.setUint32(40, dataSize, Endian.little);

    for (var i = 0; i < sampleCount; i++) {
      final sample = (math.sin((i + seed) * 0.25) * 12000).round();
      buffer.setInt16(44 + i * 2, sample, Endian.little);
    }

    return buffer.buffer.asUint8List();
  }

  @override
  void dispose() {
    _isRecording = false;
    _amplitudeController.close();
  }
}


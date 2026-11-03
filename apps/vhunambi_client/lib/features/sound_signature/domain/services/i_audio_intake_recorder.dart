import 'dart:typed_data';

/// Output produced when a raw audio intake recording completes (REQ-SIG-INTAKE-01 / Design 3.1).
class RawTakeResult {
  const RawTakeResult({
    required this.wavBytes,
    required this.pcmSamples,
    required this.durationSec,
    this.sampleRate = 44100,
    this.numChannels = 1,
  });

  /// 44.1 kHz 16-bit PCM RIFF/WAVE container bytes.
  final Uint8List wavBytes;

  /// Normalized floating-point audio samples in range [-1.0 .. 1.0].
  final Float32List pcmSamples;

  /// Duration of the take in seconds.
  final double durationSec;

  /// Sampling rate (fixed at 44,100 Hz).
  final int sampleRate;

  /// Number of channels (1 = mono).
  final int numChannels;
}

/// Abstract contract for high-fidelity microphone capture (REQ-SIG-INTAKE-01).
///
/// Disables OS AGC, noise suppression, and echo cancellation so that raw physical
/// acoustics and Bantu consonant attack transients are captured uncorrupted.
abstract class IAudioIntakeRecorder {
  /// Stream of normalized real RMS amplitudes in range [0.0 .. 1.0].
  Stream<double> get amplitudeStream;

  /// Whether a microphone intake session is currently active.
  bool get isRecording;

  /// Begins capturing audio from the physical microphone.
  Future<void> startRecording({
    int sampleRate = 44100,
    int numChannels = 1,
  });

  /// Stops recording, compiles WAV buffer and Float32 PCM samples.
  Future<RawTakeResult> stopRecording();

  /// Releases recording hardware resources.
  void dispose();
}


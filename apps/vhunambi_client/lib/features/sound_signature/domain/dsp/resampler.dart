import 'dart:math' as math;
import 'dart:typed_data';

/// High-fidelity polyphase windowed-sinc resampler (REQ-SIG-ANALYSIS-01 / Design 4.1).
///
/// Converts 44.1 kHz studio intake audio down to 16 kHz for speech and formant
/// analysis with linear phase anti-aliasing filter to prevent spectral foldover.
class AudioResampler {
  const AudioResampler();

  /// Static convenience helper.
  static Float32List resample441To16k(Float32List input) =>
      const AudioResampler().resample44100To16000(input);

  /// Resamples [input] from 44,100 Hz to 16,000 Hz.
  Float32List resample44100To16000(Float32List input) {
    return resample(
      input: input,
      fromSampleRate: 44100,
      toSampleRate: 16000,
    );
  }

  /// General-purpose windowed-sinc resampler with dynamic anti-aliasing filter.
  Float32List resample({
    required Float32List input,
    required int fromSampleRate,
    required int toSampleRate,
  }) {
    if (fromSampleRate == toSampleRate || input.isEmpty) {
      return Float32List.fromList(input);
    }

    final ratio = toSampleRate / fromSampleRate;
    final outLength = (input.length * ratio).floor();
    if (outLength == 0) return Float32List(0);

    final output = Float32List(outLength);

    // Half-width of sinc kernel (taps on each side)
    const filterRadius = 16;
    final cutoff = ratio < 1.0 ? ratio * 0.95 : 0.95;

    for (var outIdx = 0; outIdx < outLength; outIdx++) {
      final inPos = outIdx / ratio;
      final centerIdx = inPos.floor();
      var sum = 0.0;
      var weightSum = 0.0;

      for (var offset = -filterRadius; offset <= filterRadius; offset++) {
        final sampleIdx = centerIdx + offset;
        if (sampleIdx >= 0 && sampleIdx < input.length) {
          final delta = inPos - sampleIdx;
          final weight = _sinc(delta * cutoff) * _blackmanWindow(delta / filterRadius);
          sum += input[sampleIdx] * weight;
          weightSum += weight;
        }
      }

      output[outIdx] = weightSum.abs() > 0.000001 ? (sum / weightSum) : 0.0;
    }

    return output;
  }

  double _sinc(double x) {
    if (x.abs() < 1e-7) return 1.0;
    final px = math.pi * x;
    return math.sin(px) / px;
  }

  double _blackmanWindow(double normalizedOffset) {
    if (normalizedOffset.abs() > 1.0) return 0.0;
    final x = (normalizedOffset + 1.0) * 0.5; // [0.0 .. 1.0]
    return 0.42 - 0.50 * math.cos(2.0 * math.pi * x) + 0.08 * math.cos(4.0 * math.pi * x);
  }
}

/// Convenience alias matching spec nomenclature.
typedef Resampler = AudioResampler;

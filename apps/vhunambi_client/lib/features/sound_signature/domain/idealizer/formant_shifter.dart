import 'dart:math' as math;
import 'dart:typed_data';
import '../dsp/fft.dart';

/// Vocal tract formant depth shifter independent of fundamental pitch (REQ-IDEAL-01 / Design 5.3).
class FormantShifter {
  FormantShifter({
    this.sampleRate = 44100,
    this.fftSize = 1024,
    this.hopSize = 256,
  }) : _fft = FastFourierTransform(fftSize);

  final int sampleRate;
  final int fftSize;
  final int hopSize;
  final FastFourierTransform _fft;

  /// Warps spectral envelope by [semitoneShift] (-3.0 .. +3.0 semitones)
  /// while preserving fundamental excitation harmonics.
  Float32List shiftFormants(Float32List inputAudio, double semitoneShift) {
    if (semitoneShift.abs() < 0.05 || inputAudio.length < fftSize) {
      return Float32List.fromList(inputAudio);
    }

    final alpha = math.pow(2.0, semitoneShift / 12.0).toDouble();
    final n = inputAudio.length;
    final frameCount = (n - fftSize) ~/ hopSize + 1;
    final half = fftSize ~/ 2;

    final output = Float32List(n);
    final weightSum = Float32List(n);

    final real = Float64List(fftSize);
    final imag = Float64List(fftSize);

    // Pre-calculate Hann window
    final window = Float64List(fftSize);
    for (var i = 0; i < fftSize; i++) {
      window[i] = 0.5 * (1.0 - math.cos(2.0 * math.pi * i / (fftSize - 1)));
    }

    for (var f = 0; f < frameCount; f++) {
      final start = f * hopSize;

      for (var i = 0; i < fftSize; i++) {
        real[i] = inputAudio[start + i] * window[i];
        imag[i] = 0.0;
      }

      _fft.forward(real, imag);

      // Compute magnitude and phase
      final mag = Float64List(half + 1);
      final phase = Float64List(half + 1);
      for (var k = 0; k <= half; k++) {
        mag[k] = math.sqrt(real[k] * real[k] + imag[k] * imag[k]);
        phase[k] = math.atan2(imag[k], real[k]);
      }

      // Extract smooth spectral envelope (moving average over ~600 Hz band)
      final binHz = sampleRate / fftSize;
      final avgRadiusBins = math.max(2, (300.0 / binHz).round());
      final envelope = Float64List(half + 1);

      for (var k = 0; k <= half; k++) {
        var sum = 0.0;
        var count = 0;
        final kMin = math.max(0, k - avgRadiusBins);
        final kMax = math.min(half, k + avgRadiusBins);
        for (var j = kMin; j <= kMax; j++) {
          sum += mag[j];
          count++;
        }
        envelope[k] = count > 0 ? sum / count : mag[k];
      }

      // Warp envelope by alpha and apply envelope ratio to original spectrum
      final warpedEnvelope = Float64List(half + 1);
      for (var k = 0; k <= half; k++) {
        final srcK = (k / alpha).clamp(0.0, half.toDouble());
        final srcK0 = srcK.floor();
        final srcK1 = math.min(half, srcK0 + 1);
        final frac = srcK - srcK0;

        warpedEnvelope[k] = envelope[srcK0] * (1.0 - frac) + envelope[srcK1] * frac;
      }

      for (var k = 0; k <= half; k++) {
        final origEnv = math.max(0.0001, envelope[k]);
        final targetEnv = math.max(0.0001, warpedEnvelope[k]);
        final ratio = (targetEnv / origEnv).clamp(0.3, 3.0);

        final newMag = mag[k] * ratio;
        real[k] = newMag * math.cos(phase[k]);
        imag[k] = newMag * math.sin(phase[k]);

        // Symmetric negative frequencies
        if (k > 0 && k < half) {
          real[fftSize - k] = real[k];
          imag[fftSize - k] = -imag[k];
        }
      }

      _fft.inverse(real, imag);

      // Overlap-add
      for (var i = 0; i < fftSize; i++) {
        final outIdx = start + i;
        if (outIdx < n) {
          final w = window[i];
          output[outIdx] += (real[i] * w).toFloat();
          weightSum[outIdx] += (w * w).toFloat();
        }
      }
    }

    // Window normalization
    final result = Float32List(n);
    for (var i = 0; i < n; i++) {
      final w = weightSum[i];
      if (w > 0.0001) {
        result[i] = (output[i] / w).clamp(-1.0, 1.0);
      } else {
        result[i] = inputAudio[i];
      }
    }

    return result;
  }
}

extension on double {
  double toFloat() => this;
}


import 'dart:math' as math;
import 'dart:typed_data';

/// Multi-stage analog-style vocal tone cleanup, enhancement, and dynamics chain (REQ-IDEAL-01 / Design 5.4).
class ToneChain {
  const ToneChain({this.sampleRate = 44100});

  final int sampleRate;

  /// Applies spectral cleanup, box notch, chest warmth, air lift, compression, and peak limiting.
  Float32List process({
    required Float32List audio,
    required double cleanupStrength, // 0.0 .. 1.0
    required double chestPowerAndAirBoost, // 0.0 .. 1.0
  }) {
    final n = audio.length;
    if (n == 0) return Float32List(0);

    var current = Float32List.fromList(audio);

    // 1. Box tone cut (notch at 450 Hz, Q=1.8) proportional to cleanupStrength
    if (cleanupStrength > 0.05) {
      final notchGainDb = -3.5 * cleanupStrength;
      current = _applyPeakingEq(
        current,
        centerHz: 450.0,
        q: 1.8,
        gainDb: notchGainDb,
      );
    }

    // 2. Low shelf for chest power (160 Hz) and high shelf for air (11.5 kHz)
    if (chestPowerAndAirBoost > 0.05) {
      final chestGainDb = 2.5 * chestPowerAndAirBoost;
      final airGainDb = 3.5 * chestPowerAndAirBoost;

      current = _applyLowShelf(current, cutoffHz: 160.0, gainDb: chestGainDb);
      current = _applyHighShelf(current, cutoffHz: 11500.0, gainDb: airGainDb);
    }

    // 3. Smooth feed-forward RMS compressor
    current = _applyCompressor(
      current,
      thresholdDb: -18.0,
      ratio: 2.5,
      attackMs: 15.0,
      releaseMs: 100.0,
    );

    // 4. Soft peak limiter with -0.3 dBFS ceiling and tanh saturation
    current = _applyLimiter(current, ceilingDb: -0.3);

    return current;
  }

  Float32List _applyPeakingEq(
    Float32List input, {
    required double centerHz,
    required double q,
    required double gainDb,
  }) {
    final a = math.pow(10.0, gainDb / 40.0).toDouble();
    final w0 = 2.0 * math.pi * centerHz / sampleRate;
    final alpha = math.sin(w0) / (2.0 * q);

    final b0 = 1.0 + alpha * a;
    final b1 = -2.0 * math.cos(w0);
    final b2 = 1.0 - alpha * a;
    final a0 = 1.0 + alpha / a;
    final a1 = -2.0 * math.cos(w0);
    final a2 = 1.0 - alpha / a;

    return _applyBiquad(input, b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0);
  }

  Float32List _applyLowShelf(
    Float32List input, {
    required double cutoffHz,
    required double gainDb,
  }) {
    final a = math.pow(10.0, gainDb / 40.0).toDouble();
    final w0 = 2.0 * math.pi * cutoffHz / sampleRate;
    final cosW0 = math.cos(w0);
    final sinW0 = math.sin(w0);
    final alpha = sinW0 / 2.0 * math.sqrt(2.0); // Q = 1/sqrt(2)

    final b0 = a * ((a + 1.0) - (a - 1.0) * cosW0 + 2.0 * math.sqrt(a) * alpha);
    final b1 = 2.0 * a * ((a - 1.0) - (a + 1.0) * cosW0);
    final b2 = a * ((a + 1.0) - (a - 1.0) * cosW0 - 2.0 * math.sqrt(a) * alpha);
    final a0 = (a + 1.0) + (a - 1.0) * cosW0 + 2.0 * math.sqrt(a) * alpha;
    final a1 = -2.0 * ((a - 1.0) + (a + 1.0) * cosW0);
    final a2 = (a + 1.0) + (a - 1.0) * cosW0 - 2.0 * math.sqrt(a) * alpha;

    return _applyBiquad(input, b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0);
  }

  Float32List _applyHighShelf(
    Float32List input, {
    required double cutoffHz,
    required double gainDb,
  }) {
    final a = math.pow(10.0, gainDb / 40.0).toDouble();
    final w0 =
        2.0 * math.pi * math.min(cutoffHz, sampleRate * 0.45) / sampleRate;
    final cosW0 = math.cos(w0);
    final sinW0 = math.sin(w0);
    final alpha = sinW0 / 2.0 * math.sqrt(2.0);

    final b0 = a * ((a + 1.0) + (a - 1.0) * cosW0 + 2.0 * math.sqrt(a) * alpha);
    final b1 = -2.0 * a * ((a - 1.0) + (a + 1.0) * cosW0);
    final b2 = a * ((a + 1.0) + (a - 1.0) * cosW0 - 2.0 * math.sqrt(a) * alpha);
    final a0 = (a + 1.0) - (a - 1.0) * cosW0 + 2.0 * math.sqrt(a) * alpha;
    final a1 = 2.0 * ((a - 1.0) - (a + 1.0) * cosW0);
    final a2 = (a + 1.0) - (a - 1.0) * cosW0 - 2.0 * math.sqrt(a) * alpha;

    return _applyBiquad(input, b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0);
  }

  Float32List _applyBiquad(
    Float32List input,
    double b0,
    double b1,
    double b2,
    double a1,
    double a2,
  ) {
    final n = input.length;
    final out = Float32List(n);
    var x1 = 0.0, x2 = 0.0;
    var y1 = 0.0, y2 = 0.0;

    for (var i = 0; i < n; i++) {
      final x0 = input[i].toDouble();
      final y0 = b0 * x0 + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;
      out[i] = y0.clamp(-2.0, 2.0);
      x2 = x1;
      x1 = x0;
      y2 = y1;
      y1 = y0;
    }
    return out;
  }

  Float32List _applyCompressor(
    Float32List input, {
    required double thresholdDb,
    required double ratio,
    required double attackMs,
    required double releaseMs,
  }) {
    final n = input.length;
    final out = Float32List(n);

    final alphaAttack = math.exp(-1.0 / (sampleRate * (attackMs / 1000.0)));
    final alphaRelease = math.exp(-1.0 / (sampleRate * (releaseMs / 1000.0)));

    var envelope = 0.0;

    for (var i = 0; i < n; i++) {
      final s = input[i].abs().toDouble();
      if (s > envelope) {
        envelope = alphaAttack * envelope + (1.0 - alphaAttack) * s;
      } else {
        envelope = alphaRelease * envelope + (1.0 - alphaRelease) * s;
      }

      final envDb = envelope > 0.00001
          ? 20.0 * math.log(envelope) / math.ln10
          : -100.0;
      var gainReductionDb = 0.0;

      if (envDb > thresholdDb) {
        gainReductionDb = (thresholdDb - envDb) * (1.0 - 1.0 / ratio);
      }

      final gain = math.pow(10.0, gainReductionDb / 20.0).toDouble();
      out[i] = (input[i] * gain).clamp(-1.5, 1.5);
    }
    return out;
  }

  Float32List _applyLimiter(Float32List input, {required double ceilingDb}) {
    final ceilingLinear = math.pow(10.0, ceilingDb / 20.0).toDouble(); // ~0.966
    final n = input.length;
    final out = Float32List(n);

    for (var i = 0; i < n; i++) {
      final s = input[i].toDouble();
      final sign = s >= 0 ? 1.0 : -1.0;
      final absS = s.abs();

      if (absS < ceilingLinear * 0.85) {
        out[i] = s;
      } else {
        // Soft tanh compression above knee
        final normalized = absS / ceilingLinear;
        final saturated = _tanh(normalized) * ceilingLinear;
        out[i] = (sign * saturated).clamp(-ceilingLinear, ceilingLinear);
      }
    }
    return out;
  }

  static double _tanh(double x) {
    if (x > 20.0) return 1.0;
    if (x < -20.0) return -1.0;
    final e2x = math.exp(2.0 * x);
    return (e2x - 1.0) / (e2x + 1.0);
  }
}

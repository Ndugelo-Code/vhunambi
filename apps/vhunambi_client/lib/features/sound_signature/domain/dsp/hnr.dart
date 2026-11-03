import 'dart:math' as math;
import 'dart:typed_data';
import 'fft.dart';

/// Harmonic analysis metrics extracted from voiced speech frames (REQ-SIG-ANALYSIS-05 / REQ-SIG-ANALYSIS-06).
class HnrResult {
  const HnrResult({
    required this.hnrDb,
    required this.harmonicPurityRatio,
    required this.glottalWarmth,
  });

  /// Harmonic-to-Noise Ratio in dB.
  final double hnrDb;

  /// Harmonic Purity Ratio in range [0.0 .. 1.0] (clamp(HNR / 30.0, 0, 1)).
  final double harmonicPurityRatio;

  /// Glottal warmth proxy in range [0.0 .. 1.0] derived from H1 - H2 harmonic differential.
  final double glottalWarmth;
}

/// Computes Harmonic-to-Noise Ratio (HNR) and glottal warmth proxy (Design 4.6).
class HnrEstimator {
  HnrEstimator({this.sampleRate = 16000}) : _fft = FastFourierTransform(512);

  final int sampleRate;
  final FastFourierTransform _fft;

  /// Computes average HNR and glottal warmth across voiced frames of [pcm16k].
  HnrResult analyze(Float32List pcm16k, {required List<double> f0ContourHz}) {
    const frameSize = 512;
    const hopSize = 256;
    final frameCount = math.min(
      (pcm16k.length - frameSize) ~/ hopSize,
      f0ContourHz.length,
    );

    if (frameCount <= 0) {
      return const HnrResult(
        hnrDb: 18.0,
        harmonicPurityRatio: 0.60,
        glottalWarmth: 0.50,
      );
    }

    var hnrSum = 0.0;
    var warmthSum = 0.0;
    var validFrameCount = 0;

    final real = Float64List(frameSize);
    final imag = Float64List(frameSize);

    for (var f = 0; f < frameCount; f++) {
      final f0 = f0ContourHz[f];
      if (f0 < 60.0 || f0 > 850.0) continue; // Skip unvoiced or out-of-range frames

      final lag = (sampleRate / f0).round();
      if (lag < 4 || lag >= frameSize ~/ 2) continue;

      final start = f * hopSize;

      // 1. Normalized autocorrelation at lag T0
      var s0 = 0.0;
      var sLag = 0.0;
      var cross = 0.0;
      final span = frameSize - lag;

      for (var i = 0; i < span; i++) {
        final x0 = pcm16k[start + i];
        final xL = pcm16k[start + i + lag];
        s0 += x0 * x0;
        sLag += xL * xL;
        cross += x0 * xL;
      }

      final denom = math.sqrt(s0 * sLag);
      if (denom < 1e-8) continue;

      final r = (cross / denom).clamp(0.01, 0.99);
      final frameHnrDb = 10.0 * math.log(r / (1.0 - r)) / math.ln10;

      // 2. Glottal warmth proxy via H1 - H2 peak differential
      for (var i = 0; i < frameSize; i++) {
        final hann = 0.5 * (1.0 - math.cos(2.0 * math.pi * i / (frameSize - 1)));
        real[i] = pcm16k[start + i] * hann;
        imag[i] = 0.0;
      }

      _fft.forward(real, imag);
      final power = _fft.powerSpectrum(real, imag);

      final binH1 = (f0 * frameSize / sampleRate).round().clamp(1, 255);
      final binH2 = (2.0 * f0 * frameSize / sampleRate).round().clamp(1, 255);

      final p1 = _peakMagnitude(power, binH1);
      final p2 = _peakMagnitude(power, binH2);

      final h1Db = 10.0 * math.log(math.max(1e-12, p1)) / math.ln10;
      final h2Db = 10.0 * math.log(math.max(1e-12, p2)) / math.ln10;
      final h1h2Diff = h1Db - h2Db; // Typically -5 dB .. +15 dB for modal speech

      final frameWarmth = ((h1h2Diff + 5.0) / 20.0).clamp(0.0, 1.0);

      hnrSum += frameHnrDb;
      warmthSum += frameWarmth;
      validFrameCount++;
    }

    if (validFrameCount == 0) {
      return const HnrResult(
        hnrDb: 18.0,
        harmonicPurityRatio: 0.60,
        glottalWarmth: 0.50,
      );
    }

    final avgHnr = (hnrSum / validFrameCount).clamp(0.0, 40.0);
    final purityRatio = (avgHnr / 30.0).clamp(0.0, 1.0);
    final avgWarmth = (warmthSum / validFrameCount).clamp(0.0, 1.0);

    return HnrResult(
      hnrDb: avgHnr,
      harmonicPurityRatio: purityRatio,
      glottalWarmth: avgWarmth,
    );
  }

  double _peakMagnitude(Float64List power, int targetBin) {
    var maxVal = power[targetBin];
    for (var k = -2; k <= 2; k++) {
      final bin = (targetBin + k).clamp(0, power.length - 1);
      if (power[bin] > maxVal) {
        maxVal = power[bin];
      }
    }
    return maxVal;
  }
}


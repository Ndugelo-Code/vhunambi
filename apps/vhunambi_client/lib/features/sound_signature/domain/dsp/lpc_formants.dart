import 'dart:math' as math;
import 'dart:typed_data';

/// Formant extraction result containing resonant frequencies and extraction health.
class LpcFormantsResult {
  const LpcFormantsResult({
    required this.formantsHz,
    required this.usableFrameCount,
    required this.fallbackFrameCount,
  });

  /// Resonant formants [F1, F2, F3, F4] in Hz.
  final List<double> formantsHz;

  /// Total vowel-like frames analyzed.
  final int usableFrameCount;

  /// Number of frames where Durand-Kerner fell back to all-pole spectrum peak-picking (Guard G2).
  final int fallbackFrameCount;

  /// Overall formant extraction confidence (0.0 .. 1.0).
  double get confidence {
    if (usableFrameCount < 5) return 0.0;
    final fallbackRatio = fallbackFrameCount / usableFrameCount;
    return (1.0 - fallbackRatio * 0.5).clamp(0.0, 1.0);
  }
}

/// Linear Predictive Coding (LPC) formant extractor with Durand-Kerner root solving
/// and all-pole spectrum fallback (REQ-SIG-ANALYSIS-03 / REQ-SIG-ANALYSIS-13 / Guard G2).
class LpcFormantExtractor {
  const LpcFormantExtractor({
    this.sampleRate = 16000,
    this.order = 18,
    this.maxIterations = 30,
    this.tolerance = 1e-5,
  });

  final int sampleRate;
  final int order;
  final int maxIterations;
  final double tolerance;

  /// Extracts median formants [F1, F2, F3, F4] across voiced vowel frames of [pcm16k].
  LpcFormantsResult extractFormants(Float32List pcm16k, {List<int>? f0CentsMidi}) {
    final frameSize = (sampleRate * 0.025).round(); // 400 samples (25ms)
    final hopSize = (sampleRate * 0.015).round(); // 240 samples (15ms)
    final frameCount = (pcm16k.length - frameSize) ~/ hopSize;

    if (frameCount < 4) {
      return const LpcFormantsResult(
        formantsHz: [500.0, 1500.0, 2500.0, 3500.0],
        usableFrameCount: 0,
        fallbackFrameCount: 0,
      );
    }

    final f1List = <double>[];
    final f2List = <double>[];
    final f3List = <double>[];
    final f4List = <double>[];

    var usableCount = 0;
    var fallbackCount = 0;

    for (var f = 0; f < frameCount; f++) {
      final start = f * hopSize;

      // Energy threshold check
      var sumSq = 0.0;
      for (var i = 0; i < frameSize; i++) {
        final s = pcm16k[start + i];
        sumSq += s * s;
      }
      final rms = math.sqrt(sumSq / frameSize);
      if (rms < 0.02) continue; // Skip quiet/unvoiced frames

      // 1. Pre-emphasis (0.97) + Hamming window
      final windowed = Float64List(frameSize);
      var prev = start > 0 ? pcm16k[start - 1] : pcm16k[start];
      for (var i = 0; i < frameSize; i++) {
        final curr = pcm16k[start + i];
        final preemph = curr - 0.97 * prev;
        prev = curr;
        final hamming = 0.54 - 0.46 * math.cos(2.0 * math.pi * i / (frameSize - 1));
        windowed[i] = preemph * hamming;
      }

      // 2. Autocorrelation (order 18)
      final r = Float64List(order + 1);
      for (var k = 0; k <= order; k++) {
        var sum = 0.0;
        for (var i = 0; i < frameSize - k; i++) {
          sum += windowed[i] * windowed[i + k];
        }
        r[k] = sum;
      }

      if (r[0] < 1e-8) continue;

      // 3. Levinson-Durbin recursion
      final a = _levinsonDurbin(r, order);
      if (a == null) continue;

      usableCount++;

      // 4. Roots via Durand-Kerner (with Guard G2 fallback)
      List<double>? candidateFormants = _durandKernerRoots(a);

      if (candidateFormants == null || candidateFormants.isEmpty) {
        // GUARD G2: Fall back to all-pole power spectrum peak-picking
        candidateFormants = _allPoleSpectrumPeaks(a);
        fallbackCount++;
      }

      // Map candidates to F1..F4 bins
      final f1 = _pickFormant(candidateFormants, 200.0, 1000.0);
      final f2 = _pickFormant(candidateFormants, 600.0, 2800.0, minDistance: f1, minGap: 180.0);
      final f3 = _pickFormant(candidateFormants, 1500.0, 3500.0, minDistance: f2, minGap: 250.0);
      final f4 = _pickFormant(candidateFormants, 2500.0, 4500.0, minDistance: f3, minGap: 300.0);

      if (f1 != null) f1List.add(f1);
      if (f2 != null) f2List.add(f2);
      if (f3 != null) f3List.add(f3);
      if (f4 != null) f4List.add(f4);
    }

    final medianF1 = _median(f1List, defaultVal: 650.0);
    final medianF2 = _median(f2List, defaultVal: 1450.0);
    final medianF3 = _median(f3List, defaultVal: 2450.0);
    final medianF4 = _median(f4List, defaultVal: 3500.0);

    return LpcFormantsResult(
      formantsHz: [medianF1, medianF2, medianF3, medianF4],
      usableFrameCount: usableCount,
      fallbackFrameCount: fallbackCount,
    );
  }

  Float64List? _levinsonDurbin(Float64List r, int p) {
    var a = Float64List(p + 1);
    a[0] = 1.0;
    var e = r[0];

    for (var i = 1; i <= p; i++) {
      var lambda = 0.0;
      for (var j = 0; j < i; j++) {
        lambda -= a[j] * r[i - j];
      }
      final k = lambda / e;
      if (k.isNaN || k.abs() >= 1.0) return null; // Unstable filter check

      final aNext = Float64List(p + 1);
      aNext[0] = 1.0;
      for (var j = 1; j < i; j++) {
        aNext[j] = a[j] + k * a[i - j];
      }
      aNext[i] = k;

      e *= (1.0 - k * k);
      if (e <= 0.0) return null;
      a = aNext;
    }

    return a;
  }

  /// Durand-Kerner simultaneous polynomial root finding for polynomial 1 + sum(a_k * z^-k).
  List<double>? _durandKernerRoots(Float64List lpcCoeffs) {
    final p = lpcCoeffs.length - 1;
    // Initial root approximations on complex circle with slight rotation
    final realRoots = Float64List(p);
    final imagRoots = Float64List(p);

    for (var i = 0; i < p; i++) {
      final angle = (2.0 * math.pi * i + 0.3) / p;
      final radius = 0.95;
      realRoots[i] = radius * math.cos(angle);
      imagRoots[i] = radius * math.sin(angle);
    }

    var converged = false;

    for (var iter = 0; iter < maxIterations; iter++) {
      var maxDelta = 0.0;

      for (var i = 0; i < p; i++) {
        // Evaluate polynomial P(z_i) = 1 + a_1*z^-1 + ...
        var pr = lpcCoeffs[0];
        var pi = 0.0;
        var zr = realRoots[i];
        var zi = imagRoots[i];
        var powR = zr;
        var powI = zi;

        for (var k = 1; k <= p; k++) {
          // Multiply by z^-1
          final magSq = zr * zr + zi * zi;
          if (magSq < 1e-12) return null; // Singularity
          final invR = zr / magSq;
          final invI = -zi / magSq;

          if (k == 1) {
            powR = invR;
            powI = invI;
          } else {
            final nextR = powR * invR - powI * invI;
            final nextI = powR * invI + powI * invR;
            powR = nextR;
            powI = nextI;
          }

          pr += lpcCoeffs[k] * powR;
          pi += lpcCoeffs[k] * powI;
        }

        // Evaluate product prod_{j != i} (z_i - z_j)
        var dr = 1.0;
        var di = 0.0;
        for (var j = 0; j < p; j++) {
          if (j == i) continue;
          final diffR = realRoots[i] - realRoots[j];
          final diffI = imagRoots[i] - imagRoots[j];
          final nextR = dr * diffR - di * diffI;
          final nextI = dr * diffI + di * diffR;
          dr = nextR;
          di = nextI;
        }

        final dMagSq = dr * dr + di * di;
        if (dMagSq < 1e-12) return null;

        // Step = P(z_i) / denominator
        final stepR = (pr * dr + pi * di) / dMagSq;
        final stepI = (pi * dr - pr * di) / dMagSq;

        realRoots[i] -= stepR;
        imagRoots[i] -= stepI;

        final delta = math.sqrt(stepR * stepR + stepI * stepI);
        if (delta.isNaN || delta.isInfinite) return null;
        if (delta > maxDelta) maxDelta = delta;
      }

      if (maxDelta < tolerance) {
        converged = true;
        break;
      }
    }

    if (!converged) return null;

    final formants = <double>[];
    for (var i = 0; i < p; i++) {
      final zr = realRoots[i];
      final zi = imagRoots[i];
      final r = math.sqrt(zr * zr + zi * zi);
      if (r >= 1.0 || r <= 0.01) continue;

      final bandwidth = (-sampleRate / math.pi) * math.log(r);
      if (bandwidth > 400.0) continue; // Wide bandwidth is not a vocal resonance

      final theta = math.atan2(zi.abs(), zr);
      final freq = (theta * sampleRate) / (2.0 * math.pi);

      if (freq > 90.0 && freq < (sampleRate / 2.0 - 200.0)) {
        formants.add(freq);
      }
    }

    formants.sort();
    return formants;
  }

  /// GUARD G2 FALLBACK: All-pole power spectrum 1 / |A(e^jw)|^2 peak-picking.
  List<double> _allPoleSpectrumPeaks(Float64List lpcCoeffs) {
    const numPoints = 256; // 0 .. Nyquist
    final spectrum = Float64List(numPoints);

    for (var k = 0; k < numPoints; k++) {
      final omega = math.pi * k / (numPoints - 1);
      var re = lpcCoeffs[0];
      var im = 0.0;

      for (var n = 1; n < lpcCoeffs.length; n++) {
        final angle = -n * omega;
        re += lpcCoeffs[n] * math.cos(angle);
        im += lpcCoeffs[n] * math.sin(angle);
      }

      final magSq = re * re + im * im;
      spectrum[k] = magSq > 1e-12 ? 1.0 / magSq : 1e12;
    }

    final peaks = <double>[];
    for (var i = 1; i < numPoints - 1; i++) {
      if (spectrum[i] > spectrum[i - 1] && spectrum[i] > spectrum[i + 1]) {
        // Parabolic peak interpolation
        final s0 = spectrum[i - 1];
        final s1 = spectrum[i];
        final s2 = spectrum[i + 1];
        final delta = (s0 - s2) / (2.0 * (s0 - 2.0 * s1 + s2));
        final peakBin = i + delta.clamp(-0.5, 0.5);
        final freq = (peakBin / (numPoints - 1)) * (sampleRate / 2.0);
        if (freq > 90.0 && freq < (sampleRate / 2.0 - 200.0)) {
          peaks.add(freq);
        }
      }
    }

    peaks.sort();
    return peaks;
  }

  double? _pickFormant(
    List<double> candidates,
    double minHz,
    double maxHz, {
    double? minDistance,
    double minGap = 150.0,
  }) {
    for (final c in candidates) {
      if (c >= minHz && c <= maxHz) {
        if (minDistance != null && (c - minDistance) < minGap) {
          continue;
        }
        return c;
      }
    }
    return null;
  }

  double _median(List<double> list, {required double defaultVal}) {
    if (list.isEmpty) return defaultVal;
    final sorted = List<double>.from(list)..sort();
    return sorted[sorted.length ~/ 2];
  }
}


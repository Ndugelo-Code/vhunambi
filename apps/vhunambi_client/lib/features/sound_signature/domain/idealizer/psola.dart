import 'dart:math' as math;
import 'dart:typed_data';
import '../models/phonetic_articulation_profile.dart';

/// Time-Domain Pitch-Synchronous Overlap-Add (TD-PSOLA) engine with Guard G4 (REQ-IDEAL-01 / Guard G4).
class TdPsolaShifter {
  const TdPsolaShifter({
    this.sampleRate = 44100,
  });

  final int sampleRate;

  /// Resynthesizes [inputAudio] at [sampleRate] with fundamental pitch shifted from
  /// [sourceF0Hz] to [targetF0Hz], while preserving unvoiced [protectedSegments] bit-exact.
  Float32List pitchShift({
    required Float32List inputAudio,
    required Float64List sourceF0Hz,
    required Float64List targetF0Hz,
    List<TimeSpanMs> protectedSegments = const [],
    int f0HopMs = 10,
  }) {
    final n = inputAudio.length;
    if (n == 0 || targetF0Hz.isEmpty) {
      return Float32List.fromList(inputAudio);
    }

    final output = Float32List(n);
    final weightSum = Float32List(n);

    // 1. Mark protected sample segments (Bantu plosives, clicks, unvoiced fricatives)
    final isProtected = List<bool>.filled(n, false);
    for (final span in protectedSegments) {
      final start = ((span.startMs * sampleRate) / 1000.0).round().clamp(0, n - 1);
      final end = ((span.endMs * sampleRate) / 1000.0).round().clamp(start, n);
      for (var i = start; i < end; i++) {
        isProtected[i] = true;
      }
    }

    // 2. Identify synthesis pitch marks spaced by target period T_s(t)
    var synthMark = 0.0;
    final samplesPerFrame = (sampleRate * f0HopMs) / 1000.0;

    while (synthMark < n) {
      final markInt = synthMark.round();
      if (markInt >= n) break;

      // Determine active F0 frame
      final frameIdx = (synthMark / samplesPerFrame).floor().clamp(0, targetF0Hz.length - 1);
      final srcF0 = (frameIdx < sourceF0Hz.length) ? sourceF0Hz[frameIdx] : 0.0;
      final tgtF0 = targetF0Hz[frameIdx];

      final isVoiced = srcF0 > 50.0 && tgtF0 > 50.0 && !isProtected[markInt];

      if (!isVoiced) {
        // Direct unvoiced / protected passthrough
        output[markInt] = inputAudio[markInt];
        weightSum[markInt] = 1.0;
        synthMark += math.max(1.0, samplesPerFrame / 2.0);
        continue;
      }

      // Calculate periods
      final ta = sampleRate / srcF0; // Analysis period
      final ts = sampleRate / tgtF0; // Synthesis period
      final s = ts / ta; // Scale factor

      // Guard G4: Analysis grain half-width L_a = ceil(T_a * max(1, s))
      final la = (ta * math.max(1.0, s)).ceil();
      final grainSize = 2 * la + 1;

      // Locate nearest epoch/peak in input audio around analysis mark
      final analysisCenter = markInt.clamp(0, n - 1);

      // Extract and apply Hanning window
      for (var k = -la; k <= la; k++) {
        final inIdx = analysisCenter + k;
        final outIdx = markInt + k;

        if (inIdx >= 0 && inIdx < n && outIdx >= 0 && outIdx < n) {
          // Hanning window
          final w = 0.5 * (1.0 - math.cos((2.0 * math.pi * (k + la)) / (grainSize - 1)));
          output[outIdx] += inputAudio[inIdx] * w;
          weightSum[outIdx] += w;
        }
      }

      // Advance synthesis mark by target period T_s
      synthMark += ts;
    }

    // 3. Normalization with Guard G4 Window-Sum Soft Floor max(W_sum[n], 0.20)
    final result = Float32List(n);
    for (var i = 0; i < n; i++) {
      if (isProtected[i]) {
        // Bit-exact unvoiced frame protection
        result[i] = inputAudio[i];
      } else {
        final w = weightSum[i];
        if (w <= 0.0001) {
          result[i] = inputAudio[i];
        } else {
          // Guard G4 soft floor prevents division by near-zero at grain edges
          final denom = math.max(w, 0.20);
          final sample = output[i] / denom;
          result[i] = sample.clamp(-1.0, 1.0);
        }
      }
    }

    // 4. Smooth 5 ms boundary crossfade between protected and voiced sections
    _applyCrossfade(
      result: result,
      original: inputAudio,
      isProtected: isProtected,
      fadeSamples: ((sampleRate * 0.005)).round(),
    );

    return result;
  }

  void _applyCrossfade({
    required Float32List result,
    required Float32List original,
    required List<bool> isProtected,
    required int fadeSamples,
  }) {
    final n = result.length;
    for (var i = 1; i < n; i++) {
      // Transition from voiced to protected or vice versa
      if (isProtected[i] != isProtected[i - 1]) {
        final start = math.max(0, i - fadeSamples ~/ 2);
        final end = math.min(n, i + fadeSamples ~/ 2);
        final span = end - start;
        if (span <= 1) continue;

        for (var j = start; j < end; j++) {
          final alpha = (j - start) / span.toDouble();
          final targetSample = isProtected[i] ? original[j] : result[j];
          final sourceSample = isProtected[i] ? result[j] : original[j];
          result[j] = sourceSample * (1.0 - alpha) + targetSample * alpha;
        }
      }
    }
  }
}


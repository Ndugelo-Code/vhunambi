import 'dart:math' as math;
import 'dart:typed_data';
import '../models/rhythmic_transient_grid.dart';

/// Syllable and transient micro-timing pocket quantizer (REQ-IDEAL-01 / Design 5.2).
class PocketQuantizer {
  const PocketQuantizer({
    this.sampleRate = 44100,
  });

  final int sampleRate;

  /// Nudges detected onsets in [audio] toward the nearest 16-step beat grid
  /// by [pocketStrength] (0.0 .. 1.0) using localized time-warping splines.
  Float32List quantizePocket({
    required Float32List audio,
    required RhythmicTransientGrid rhythmGrid,
    required double pocketStrength,
  }) {
    final n = audio.length;
    if (pocketStrength < 0.05 || rhythmGrid.onsetMs.isEmpty || n == 0) {
      return Float32List.fromList(audio);
    }

    final out = Float32List(n);
    final onsetMs = rhythmGrid.onsetMs;
    final offsets = rhythmGrid.offsetFromGridMs;
    final count = math.min(onsetMs.length, offsets.length);

    // Map time displacement for each sample index
    final shiftSamples = Float64List(n);

    for (var k = 0; k < count; k++) {
      final tOnsetMs = onsetMs[k];
      final offsetMs = offsets[k];

      // Target shift in ms = -offsetMs * pocketStrength
      // e.g. if lagging (+20 ms), shift backward (-20 * strength)
      final shiftMs = -offsetMs * pocketStrength;
      final shiftSamp = (shiftMs * sampleRate) / 1000.0;

      // Influence region around onset: 120 ms bell window
      final centerSamp = (tOnsetMs * sampleRate) ~/ 1000;
      final radiusSamp = (0.060 * sampleRate).round(); // 60 ms half-width

      final start = math.max(0, centerSamp - radiusSamp);
      final end = math.min(n, centerSamp + radiusSamp);

      for (var i = start; i < end; i++) {
        final dist = (i - centerSamp).abs();
        final weight = 0.5 * (1.0 + math.cos(math.pi * dist / radiusSamp));
        shiftSamples[i] += shiftSamp * weight;
      }
    }

    // Time-warping interpolation
    for (var i = 0; i < n; i++) {
      final srcIdx = i - shiftSamples[i];
      if (srcIdx < 0) {
        out[i] = audio[0];
      } else if (srcIdx >= n - 1) {
        out[i] = audio[n - 1];
      } else {
        final i0 = srcIdx.floor();
        final i1 = i0 + 1;
        final frac = srcIdx - i0;
        out[i] = (audio[i0] * (1.0 - frac) + audio[i1] * frac).clamp(-1.0, 1.0);
      }
    }

    return out;
  }
}


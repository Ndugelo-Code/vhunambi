import 'dart:math' as math;
import 'dart:typed_data';
import '../models/rhythmic_transient_grid.dart';

/// Syllable and transient micro-timing pocket quantizer (REQ-IDEAL-01 / Design 5.2).
class PocketQuantizer {
  const PocketQuantizer({
    this.sampleRate = 44100,
  });

  final int sampleRate;

  /// Finds `(penultimate, last)` onset index pairs for the Bantu penultimate
  /// cadence anchor (Phase 36 A3).
  ///
  /// Onsets are grouped into phrases separated by gaps of at least
  /// [phraseGapMs]. In a phrase of three or more onsets, if the duration of the
  /// penultimate syllable (penultimate onset to last onset) is at least
  /// [lengtheningRatio] times the median duration of the earlier syllables,
  /// the pair is returned: the interval between them is musically meaningful
  /// (phrase-final lengthening) and must not be compressed by quantizing.
  static List<(int, int)> penultimateAnchors(
    List<int> onsetMs, {
    int phraseGapMs = 600,
    double lengtheningRatio = 1.5,
  }) {
    final anchors = <(int, int)>[];
    if (onsetMs.length < 3) return anchors;

    var phraseStart = 0;
    for (var i = 1; i <= onsetMs.length; i++) {
      final endOfPhrase =
          i == onsetMs.length || onsetMs[i] - onsetMs[i - 1] >= phraseGapMs;
      if (!endOfPhrase) continue;

      final m = i - phraseStart;
      if (m >= 3) {
        final durations = <int>[];
        for (var k = phraseStart; k < i - 2; k++) {
          durations.add(onsetMs[k + 1] - onsetMs[k]);
        }
        durations.sort();
        final median = durations.length.isOdd
            ? durations[durations.length ~/ 2].toDouble()
            : (durations[durations.length ~/ 2 - 1] +
                    durations[durations.length ~/ 2]) /
                2.0;
        final penultimate = i - 2;
        final last = i - 1;
        final penDuration = onsetMs[last] - onsetMs[penultimate];
        if (median > 0 && penDuration >= lengtheningRatio * median) {
          anchors.add((penultimate, last));
        }
      }
      phraseStart = i;
    }
    return anchors;
  }

  /// Per-onset shift in milliseconds (negative = move earlier).
  ///
  /// With [anchorPenultimate], the final onset of an anchored phrase receives
  /// the same shift as its penultimate onset so the elongated syllable keeps
  /// its duration exactly.
  static List<double> computeShiftsMs({
    required List<int> onsetMs,
    required List<int> offsetFromGridMs,
    required double pocketStrength,
    bool anchorPenultimate = false,
  }) {
    final count = math.min(onsetMs.length, offsetFromGridMs.length);
    final shifts = List<double>.generate(
      count,
      (k) => -offsetFromGridMs[k] * pocketStrength,
    );
    if (anchorPenultimate) {
      for (final (pen, last) in penultimateAnchors(onsetMs.sublist(0, count))) {
        shifts[last] = shifts[pen];
      }
    }
    return shifts;
  }

  /// Nudges detected onsets in [audio] toward the nearest 16-step beat grid
  /// by [pocketStrength] (0.0 .. 1.0) using localized time-warping splines.
  ///
  /// When [anchorPenultimate] is true the Bantu penultimate cadence anchor
  /// (see [penultimateAnchors]) preserves phrase-final syllable lengthening.
  Float32List quantizePocket({
    required Float32List audio,
    required RhythmicTransientGrid rhythmGrid,
    required double pocketStrength,
    bool anchorPenultimate = false,
  }) {
    final n = audio.length;
    if (pocketStrength < 0.05 || rhythmGrid.onsetMs.isEmpty || n == 0) {
      return Float32List.fromList(audio);
    }

    final out = Float32List(n);
    final onsetMs = rhythmGrid.onsetMs;
    final shiftsMs = computeShiftsMs(
      onsetMs: onsetMs,
      offsetFromGridMs: rhythmGrid.offsetFromGridMs,
      pocketStrength: pocketStrength,
      anchorPenultimate: anchorPenultimate,
    );

    // Map time displacement for each sample index
    final shiftSamples = Float64List(n);

    for (var k = 0; k < shiftsMs.length; k++) {
      final tOnsetMs = onsetMs[k];

      // Target shift in ms = -offsetMs * pocketStrength
      // e.g. if lagging (+20 ms), shift backward (-20 * strength)
      final shiftSamp = (shiftsMs[k] * sampleRate) / 1000.0;

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

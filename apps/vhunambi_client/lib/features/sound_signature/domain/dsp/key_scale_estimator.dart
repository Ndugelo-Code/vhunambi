import 'dart:math' as math;
import '../../../../features/studio/domain/models/melody_sketchpad_models.dart';
import 'note_segmenter.dart';

/// Result of key and African scale mode estimation (REQ-SIG-ANALYSIS-01 / Design 4.4).
class KeyScaleEstimationResult {
  const KeyScaleEstimationResult({
    required this.rootPitchClass,
    required this.scaleMode,
    required this.confidence,
    required this.rootName,
  });

  /// Root pitch class (0..11 where 0 = C, 1 = C#, 2 = D, etc.)
  final int rootPitchClass;

  /// Inferred or best-fit African scale mode
  final AfricanScaleMode scaleMode;

  /// Confidence score in range [0.0, 1.0]
  final double confidence;

  /// Note letter name of root ('C', 'C#', etc.)
  final String rootName;

  static const List<String> pitchClassNames = [
    'C',
    'C#',
    'D',
    'D#',
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'A#',
    'B',
  ];
}

/// Evaluates pitch-class histograms of segmented notes against African modal ladders.
class KeyScaleEstimator {
  const KeyScaleEstimator();

  /// Estimates root pitch class and scale mode from [notes].
  ///
  /// Implements score(r, M) = sum_{p in S_M} h[(r+p)%12] - 0.5 * sum_{p not in S_M} h[(r+p)%12]
  KeyScaleEstimationResult estimateKeyAndScale(List<SegmentedNote> notes) {
    if (notes.isEmpty) {
      return const KeyScaleEstimationResult(
        rootPitchClass: 0,
        scaleMode: AfricanScaleMode.minorPentatonic,
        confidence: 0.0,
        rootName: 'C',
      );
    }

    // 1. Build duration- and stability-weighted pitch class histogram
    final h = List<double>.filled(12, 0.0);
    var totalWeight = 0.0;

    for (final note in notes) {
      final pc = (note.medianSemitones.round() % 12 + 12) % 12;
      final weight = note.durationMs * math.max(0.05, note.stabilityScore);
      h[pc] += weight;
      totalWeight += weight;
    }

    if (totalWeight <= 0.0) {
      return const KeyScaleEstimationResult(
        rootPitchClass: 0,
        scaleMode: AfricanScaleMode.minorPentatonic,
        confidence: 0.0,
        rootName: 'C',
      );
    }

    // 2. Score all 48 combinations: 12 roots x 4 AfricanScaleModes
    double bestScore = -double.infinity;
    double secondScore = -double.infinity;
    var bestRoot = 0;
    var bestMode = AfricanScaleMode.minorPentatonic;

    for (final mode in AfricanScaleMode.values) {
      final pitchClassSet = mode.semitoneOffsets.map((offset) => (offset % 12 + 12) % 12).toSet();

      for (var r = 0; r < 12; r++) {
        var inScaleEnergy = 0.0;
        var outOfScaleEnergy = 0.0;

        for (var p = 0; p < 12; p++) {
          final pitchClass = (r + p) % 12;
          if (pitchClassSet.contains(p)) {
            inScaleEnergy += h[pitchClass];
          } else {
            outOfScaleEnergy += h[pitchClass];
          }
        }

        final score = inScaleEnergy - (0.5 * outOfScaleEnergy);

        if (score > bestScore) {
          secondScore = bestScore;
          bestScore = score;
          bestRoot = r;
          bestMode = mode;
        } else if (score > secondScore) {
          secondScore = score;
        }
      }
    }

    // 3. Compute normalized confidence (s1 - s2) / s1
    var confidence = 0.0;
    if (bestScore > 0.0) {
      if (secondScore.isFinite && secondScore > 0.0) {
        confidence = ((bestScore - secondScore) / bestScore).clamp(0.0, 1.0);
      } else {
        confidence = 1.0;
      }
    }

    return KeyScaleEstimationResult(
      rootPitchClass: bestRoot,
      scaleMode: bestMode,
      confidence: confidence,
      rootName: KeyScaleEstimationResult.pitchClassNames[bestRoot],
    );
  }
}


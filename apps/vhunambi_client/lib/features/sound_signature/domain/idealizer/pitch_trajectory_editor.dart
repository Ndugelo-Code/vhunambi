import 'dart:math' as math;
import 'dart:typed_data';
import '../../../../features/studio/domain/models/melody_sketchpad_models.dart';
import '../dsp/note_segmenter.dart';
import '../models/pitch_contour_profile.dart';
import '../models/sound_idealizer_recipe.dart';

/// Note whose required pitch correction exceeded 7 semitones and was left unchanged (REQ-IDEAL-03).
class RefusedNote {
  const RefusedNote({
    required this.startMs,
    required this.endMs,
    required this.originalPitchMidi,
    required this.targetPitchMidi,
    required this.deviationSemitones,
  });

  final int startMs;
  final int endMs;
  final double originalPitchMidi;
  final double targetPitchMidi;
  final double deviationSemitones;
}

/// Result of non-destructive pitch trajectory editing.
class PitchEditResult {
  const PitchEditResult({
    required this.idealSemitones,
    required this.targetF0Hz,
    required this.refusedNotes,
    required this.centsCorrections,
  });

  /// Idealized pitch trajectory in continuous MIDI semitones.
  final Float64List idealSemitones;

  /// Idealized fundamental frequency contour in Hz for PSOLA epoch spacing.
  final Float64List targetF0Hz;

  /// List of notes where snapping was bypassed due to excessive interval (> 7 semitones).
  final List<RefusedNote> refusedNotes;

  /// Per-frame signed correction in cents.
  final Float64List centsCorrections;
}

/// Decomposes and idealizes fundamental frequency contours with Guard G3 segment filtering (REQ-IDEAL-01 / Guard G3).
class PitchTrajectoryEditor {
  const PitchTrajectoryEditor({
    this.frameRateHz = 100, // 10ms frame step
    this.glideSlopeThreshold = 10.0, // semitones / second
    this.minGlideDurationMs = 80,
  });

  final int frameRateHz;
  final double glideSlopeThreshold;
  final int minGlideDurationMs;

  /// Decomposes [rawF0CentsMidi] (where unvoiced = -32768) into trend, vibrato, and tremor,
  /// snaps notes to [scaleMode] rooted at [rootPitchClass], and builds the idealized trajectory.
  PitchEditResult editTrajectory({
    required List<int> rawF0CentsMidi,
    required AfricanScaleMode scaleMode,
    required int rootPitchClass,
    required SoundIdealizerRecipe recipe,
    List<SegmentedNote> notes = const [],
  }) {
    final frameCount = rawF0CentsMidi.length;
    if (frameCount == 0) {
      return PitchEditResult(
        idealSemitones: Float64List(0),
        targetF0Hz: Float64List(0),
        refusedNotes: const [],
        centsCorrections: Float64List(0),
      );
    }

    final idealSemitones = Float64List.fromList(List<double>.filled(frameCount, double.nan));
    final targetF0Hz = Float64List(frameCount);
    final centsCorrections = Float64List(frameCount);
    final refusedNotes = <RefusedNote>[];

    // 1. Convert to continuous semitone list; unvoiced frames marked with double.nan
    final semitones = Float64List(frameCount);
    for (var i = 0; i < frameCount; i++) {
      final cents = rawF0CentsMidi[i];
      if (cents == PitchContourProfile.unvoicedSentinel || cents <= 0) {
        semitones[i] = double.nan;
      } else {
        semitones[i] = cents / 100.0;
      }
    }

    // 2. Identify contiguous voiced runs and bridge unvoiced gaps < 60 ms
    // At 100 Hz, 60 ms is 6 frames
    final bridgedSemitones = Float64List.fromList(semitones);
    final isBridged = List<bool>.filled(frameCount, false);
    final maxBridgeFrames = (0.060 * frameRateHz).round();

    var unvoicedGapStart = -1;
    for (var i = 0; i < frameCount; i++) {
      if (bridgedSemitones[i].isNaN) {
        if (unvoicedGapStart == -1) unvoicedGapStart = i;
      } else {
        if (unvoicedGapStart != -1) {
          final gapLen = i - unvoicedGapStart;
          if (gapLen <= maxBridgeFrames && unvoicedGapStart > 0) {
            // Linear interpolate across the short gap in semitone space
            final startVal = bridgedSemitones[unvoicedGapStart - 1];
            final endVal = bridgedSemitones[i];
            for (var g = 0; g < gapLen; g++) {
              final frac = (g + 1) / (gapLen + 1);
              final idx = unvoicedGapStart + g;
              bridgedSemitones[idx] = startVal + frac * (endVal - startVal);
              isBridged[idx] = true;
            }
          }
          unvoicedGapStart = -1;
        }
      }
    }

    // 3. Find voiced runs (where semitones are valid)
    final voicedRuns = <(int, int)>[];
    var runStart = -1;
    for (var i = 0; i < frameCount; i++) {
      if (!bridgedSemitones[i].isNaN) {
        if (runStart == -1) runStart = i;
      } else {
        if (runStart != -1) {
          voicedRuns.add((runStart, i));
          runStart = -1;
        }
      }
    }
    if (runStart != -1) {
      voicedRuns.add((runStart, frameCount));
    }

    // 4. Allowed scale pitch set P = { root + offset + 12k }
    final scalePitchClasses = scaleMode.semitoneOffsets
        .map((offset) => (rootPitchClass + offset) % 12)
        .toSet();

    // 5. Process each voiced run independently with Guard G3 Butterworth filtering
    for (final run in voicedRuns) {
      final start = run.$1;
      final end = run.$2;
      final runLen = end - start;

      final runSemitones = Float64List(runLen);
      for (var i = 0; i < runLen; i++) {
        runSemitones[i] = bridgedSemitones[start + i];
      }

      // If run is shorter than 20 frames (200 ms), skip Butterworth split
      Float64List trend;
      Float64List vib;
      Float64List trem;

      if (runLen < 20) {
        trend = runSemitones;
        vib = Float64List(runLen);
        trem = Float64List(runLen);
      } else {
        // Guard G3: 2nd-order Butterworth zero-phase with 10-frame reflected padding
        trend = _butterworthLowpassZeroPhase(runSemitones, cutoffHz: 2.5, fs: frameRateHz.toDouble());
        final lp8 = _butterworthLowpassZeroPhase(runSemitones, cutoffHz: 8.0, fs: frameRateHz.toDouble());
        final lp4 = _butterworthLowpassZeroPhase(runSemitones, cutoffHz: 4.0, fs: frameRateHz.toDouble());

        vib = Float64List(runLen);
        trem = Float64List(runLen);
        for (var i = 0; i < runLen; i++) {
          vib[i] = lp8[i] - lp4[i]; // Bandpass 4-8 Hz
          trem[i] = runSemitones[i] - trend[i] - vib[i];
        }
      }

      // 6. Detect intentional glides: |dm/dt| > 10 st/s monotone for >= 80 ms
      final isGlide = List<bool>.filled(runLen, false);
      final glideMinFrames = (minGlideDurationMs * frameRateHz / 1000.0).round();

      for (var i = 0; i <= runLen - glideMinFrames; i++) {
        var monotone = true;
        final dir = trend[i + 1] - trend[i];
        if (dir.abs() * frameRateHz >= glideSlopeThreshold) {
          for (var k = 1; k < glideMinFrames; k++) {
            final diff = trend[i + k] - trend[i + k - 1];
            if (diff * dir <= 0 || diff.abs() * frameRateHz < (glideSlopeThreshold * 0.5)) {
              monotone = false;
              break;
            }
          }
          if (monotone) {
            for (var k = 0; k < glideMinFrames; k++) {
              isGlide[i + k] = true;
            }
          }
        }
      }

      // 7. Calculate median pitch of run for scale target
      var sum = 0.0;
      for (var i = 0; i < runLen; i++) {
        sum += runSemitones[i];
      }
      final runMedian = sum / runLen;

      // Find closest scale note p* in P
      var bestTarget = runMedian.roundToDouble();
      var minDistance = double.infinity;

      for (var midi = 24; midi <= 108; midi++) {
        final pc = (midi % 12 + 12) % 12;
        if (scalePitchClasses.contains(pc)) {
          final dist = (midi.toDouble() - runMedian).abs();
          if (dist < minDistance) {
            minDistance = dist;
            bestTarget = midi.toDouble();
          }
        }
      }

      // REQ-IDEAL-03: Refusal guard if > 7 semitones
      final rawDelta = bestTarget - runMedian;
      final isRefused = rawDelta.abs() > 7.0;

      if (isRefused) {
        refusedNotes.add(RefusedNote(
          startMs: (start * 1000) ~/ frameRateHz,
          endMs: (end * 1000) ~/ frameRateHz,
          originalPitchMidi: runMedian,
          targetPitchMidi: bestTarget,
          deviationSemitones: rawDelta,
        ));
      }

      final deltaN = isRefused ? 0.0 : rawDelta.clamp(-7.0, 7.0);
      final lambdaP = recipe.pitchScaleLock;
      final nu = recipe.vibratoAndSustainPolish;
      const kappa = 0.7;

      // 8. Reconstruct ideal trajectory
      for (var i = 0; i < runLen; i++) {
        final globalIdx = start + i;
        if (isBridged[globalIdx]) {
          // Bridged frame: do not render as voiced audio
          idealSemitones[globalIdx] = double.nan;
          targetF0Hz[globalIdx] = 0.0;
          centsCorrections[globalIdx] = 0.0;
          continue;
        }

        final g = isGlide[i] ? 1.0 : 0.0;
        final t = globalIdx / frameRateHz.toDouble();

        // Synthesized studio vibrato: 5.5 Hz, 30 cents (0.3 st)
        final vs = 0.30 * math.sin(2.0 * math.pi * 5.5 * t);

        final mTrend = trend[i];
        final mVib = vib[i];
        final mTrem = trem[i];

        final mIdeal = mTrend +
            lambdaP * (deltaN - kappa * (mTrend - runMedian)) * (1.0 - g) +
            (1.0 - nu) * mVib +
            nu * vs +
            (1.0 - nu) * mTrem * 0.1;

        idealSemitones[globalIdx] = mIdeal;
        final f0 = 440.0 * math.pow(2.0, (mIdeal - 69.0) / 12.0);
        targetF0Hz[globalIdx] = f0;

        final originalM = semitones[globalIdx];
        centsCorrections[globalIdx] = (mIdeal - originalM) * 100.0;
      }
    }

    return PitchEditResult(
      idealSemitones: idealSemitones,
      targetF0Hz: targetF0Hz,
      refusedNotes: refusedNotes,
      centsCorrections: centsCorrections,
    );
  }

  /// 2nd-order lowpass Butterworth zero-phase filter with 10-frame reflected boundary padding.
  Float64List _butterworthLowpassZeroPhase(Float64List signal, {required double cutoffHz, required double fs}) {
    final n = signal.length;
    if (n <= 3) return Float64List.fromList(signal);

    // Filter coefficients via bilinear transform
    final omega = math.tan(math.pi * cutoffHz / fs);
    final k = omega;
    final k2 = k * k;
    final sqrt2 = math.sqrt(2.0);
    final d = 1.0 + sqrt2 * k + k2;

    final b0 = k2 / d;
    final b1 = 2.0 * b0;
    final b2 = b0;
    final a1 = 2.0 * (k2 - 1.0) / d;
    final a2 = (1.0 - sqrt2 * k + k2) / d;

    const padLen = 10;
    final paddedN = n + 2 * padLen;
    final padded = Float64List(paddedN);

    // Symmetric reflection with boundary continuity
    for (var i = 0; i < padLen; i++) {
      final refIdx = math.min(n - 1, padLen - i);
      padded[i] = 2.0 * signal[0] - signal[refIdx];
    }
    for (var i = 0; i < n; i++) {
      padded[padLen + i] = signal[i];
    }
    for (var i = 0; i < padLen; i++) {
      final refIdx = math.max(0, n - 2 - i);
      padded[padLen + n + i] = 2.0 * signal[n - 1] - signal[refIdx];
    }

    // Forward pass
    final forward = Float64List(paddedN);
    var x1 = padded[0], x2 = padded[0];
    var y1 = padded[0], y2 = padded[0];

    for (var i = 0; i < paddedN; i++) {
      final x0 = padded[i];
      final y0 = b0 * x0 + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;
      forward[i] = y0;
      x2 = x1;
      x1 = x0;
      y2 = y1;
      y1 = y0;
    }

    // Backward pass
    final backward = Float64List(paddedN);
    x1 = forward[paddedN - 1];
    x2 = forward[paddedN - 1];
    y1 = forward[paddedN - 1];
    y2 = forward[paddedN - 1];

    for (var i = paddedN - 1; i >= 0; i--) {
      final x0 = forward[i];
      final y0 = b0 * x0 + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;
      backward[i] = y0;
      x2 = x1;
      x1 = x0;
      y2 = y1;
      y1 = y0;
    }

    // Crop padding
    final output = Float64List(n);
    for (var i = 0; i < n; i++) {
      output[i] = backward[padLen + i];
    }
    return output;
  }
}

import 'dart:math' as math;
import 'dart:typed_data';
import '../models/pitch_contour_profile.dart';

/// Frame analysis result from YIN fundamental pitch tracker.
class YinFrameResult {
  const YinFrameResult({
    required this.f0Hz,
    required this.f0CentsMidi,
    required this.isVoiced,
    required this.aperiodicity,
    required this.rms,
  });

  final double f0Hz;
  final int f0CentsMidi;
  final bool isVoiced;
  final double aperiodicity;
  final double rms;
}

/// Direct-form YIN pitch estimator with Viterbi continuity and Sub-Octave Guard G1 (REQ-SIG-ANALYSIS-01 / REQ-SIG-ANALYSIS-12).
class YinPitchTracker {
  YinPitchTracker({
    this.sampleRate = 16000,
    this.windowSize = 512,
    this.hopSize = 160,
    this.minFrequencyHz = 60.0,
    this.maxFrequencyHz = 850.0,
    this.voicingThreshold = 0.20,
    this.subOctaveThreshold = 0.15,
  }) : minLag = _calcMinLag(sampleRate, maxFrequencyHz, windowSize),
       maxLag = _calcMaxLag(sampleRate, minFrequencyHz, windowSize);

  static int _calcMinLag(int sr, double maxF, int ws) =>
      (sr / maxF).floor().clamp(2, ws - 2);

  static int _calcMaxLag(int sr, double minF, int ws) =>
      (sr / minF).ceil().clamp(2, ws - 1);

  final int sampleRate;
  final int windowSize;
  final int hopSize;
  final double minFrequencyHz;
  final double maxFrequencyHz;
  final double voicingThreshold;
  final double subOctaveThreshold;

  final int minLag;
  final int maxLag;

  /// Convenience alias matching spec.
  List<YinFrameResult> trackPitch(Float32List pcm16k) => analyzeFrames(pcm16k);

  /// Tracks fundamental frequency across [pcm16k] and returns a 50 Hz cents contour.
  List<YinFrameResult> analyzeFrames(Float32List pcm16k) {
    if (pcm16k.length < windowSize + maxLag) return const [];

    final frameCount = (pcm16k.length - windowSize - maxLag) ~/ hopSize;
    if (frameCount <= 0) return const [];

    // Measure overall noise floor for adaptive energy gating
    var totalSumSq = 0.0;
    for (var i = 0; i < pcm16k.length; i++) {
      totalSumSq += pcm16k[i] * pcm16k[i];
    }
    final globalRms = math.sqrt(totalSumSq / pcm16k.length);
    final noiseFloorThreshold = math.max(0.005, globalRms * 0.15);

    final rawFrames = <YinFrameResult>[];
    double? prevF0;

    for (var f = 0; f < frameCount; f++) {
      final start = f * hopSize;

      // 1. Frame RMS
      var sumSq = 0.0;
      for (var i = 0; i < windowSize; i++) {
        final s = pcm16k[start + i];
        sumSq += s * s;
      }
      final frameRms = math.sqrt(sumSq / windowSize);

      if (frameRms < noiseFloorThreshold) {
        rawFrames.add(
          YinFrameResult(
            f0Hz: 0.0,
            f0CentsMidi: PitchContourProfile.unvoicedSentinel,
            isVoiced: false,
            aperiodicity: 1.0,
            rms: frameRms,
          ),
        );
        prevF0 = null;
        continue;
      }

      // 2. Difference function d(tau)
      final d = Float64List(maxLag + 1);
      for (var tau = 1; tau <= maxLag; tau++) {
        var diffSum = 0.0;
        for (var j = 0; j < windowSize; j++) {
          final delta = pcm16k[start + j] - pcm16k[start + j + tau];
          diffSum += delta * delta;
        }
        d[tau] = diffSum;
      }

      // 3. Cumulative mean normalized difference d'(tau)
      final dPrime = Float64List(maxLag + 1);
      dPrime[0] = 1.0;
      var runningSum = 0.0;
      for (var tau = 1; tau <= maxLag; tau++) {
        runningSum += d[tau];
        dPrime[tau] = runningSum > 0 ? (d[tau] * tau / runningSum) : 1.0;
      }

      // 4. Candidate selection with Guard G1 (Sub-Octave Protection)
      final candidates = <int>[];
      int? firstBelowThreshold;

      for (var tau = minLag + 1; tau < maxLag; tau++) {
        if (dPrime[tau] < dPrime[tau - 1] && dPrime[tau] <= dPrime[tau + 1]) {
          if (dPrime[tau] < 0.35) {
            candidates.add(tau);
            if (firstBelowThreshold == null &&
                dPrime[tau] < subOctaveThreshold) {
              firstBelowThreshold = tau;
            }
          }
        }
      }

      if (candidates.isEmpty) {
        // Fall back to global minimum if under voicing threshold
        var bestTau = minLag;
        var minVal = dPrime[minLag];
        for (var tau = minLag + 1; tau <= maxLag; tau++) {
          if (dPrime[tau] < minVal) {
            minVal = dPrime[tau];
            bestTau = tau;
          }
        }
        if (minVal < voicingThreshold) {
          candidates.add(bestTau);
        }
      }

      if (candidates.isEmpty) {
        rawFrames.add(
          YinFrameResult(
            f0Hz: 0.0,
            f0CentsMidi: PitchContourProfile.unvoicedSentinel,
            isVoiced: false,
            aperiodicity: 1.0,
            rms: frameRms,
          ),
        );
        prevF0 = null;
        continue;
      }

      // 5. Viterbi emission + transition cost selection
      var bestCandidateTau = candidates.first;
      var lowestCost = double.infinity;

      for (final tau in candidates) {
        final rawAperiodicity = dPrime[tau];
        var cost = rawAperiodicity;

        // GUARD G1: First minimum below 0.15 gets a -0.05 bonus
        if (tau == firstBelowThreshold) {
          cost -= 0.05;
        }

        // Continuity penalty: lambda * |log2(f_t / f_{t-1})|
        if (prevF0 != null && prevF0 > 0.0) {
          final candF0 = sampleRate / tau;
          final octDiff = (math.log(candF0 / prevF0) / math.ln2).abs();
          cost += 0.5 * octDiff;
        }

        if (cost < lowestCost) {
          lowestCost = cost;
          bestCandidateTau = tau;
        }
      }

      final chosenTau = bestCandidateTau;
      final aperiodicity = dPrime[chosenTau];

      if (aperiodicity >= voicingThreshold) {
        rawFrames.add(
          YinFrameResult(
            f0Hz: 0.0,
            f0CentsMidi: PitchContourProfile.unvoicedSentinel,
            isVoiced: false,
            aperiodicity: aperiodicity,
            rms: frameRms,
          ),
        );
        prevF0 = null;
        continue;
      }

      // 6. Parabolic sub-sample interpolation
      final double subSampleTau;
      if (chosenTau > minLag && chosenTau < maxLag) {
        final s0 = dPrime[chosenTau - 1];
        final s1 = dPrime[chosenTau];
        final s2 = dPrime[chosenTau + 1];
        final denom = 2.0 * (s0 - 2.0 * s1 + s2);
        if (denom.abs() > 1e-7) {
          final delta = (s0 - s2) / denom;
          subSampleTau = chosenTau + delta.clamp(-0.5, 0.5);
        } else {
          subSampleTau = chosenTau.toDouble();
        }
      } else {
        subSampleTau = chosenTau.toDouble();
      }

      final f0 = sampleRate / subSampleTau;
      prevF0 = f0;

      // Convert f0 to MIDI cents: 6900 + 1200 * log2(f0 / 440)
      final midiCents = (6900.0 + 1200.0 * (math.log(f0 / 440.0) / math.ln2))
          .round();

      rawFrames.add(
        YinFrameResult(
          f0Hz: f0,
          f0CentsMidi: midiCents,
          isVoiced: true,
          aperiodicity: aperiodicity,
          rms: frameRms,
        ),
      );
    }

    // 7. Apply 5-tap median filter smoothing over voiced segments
    return _applyMedianSmoothing(rawFrames);
  }

  List<YinFrameResult> _applyMedianSmoothing(List<YinFrameResult> frames) {
    if (frames.length < 5) return frames;
    final smoothed = List<YinFrameResult>.from(frames);

    for (var i = 2; i < frames.length - 2; i++) {
      if (!frames[i].isVoiced) continue;

      final window = <int>[];
      for (var k = -2; k <= 2; k++) {
        if (frames[i + k].isVoiced) {
          window.add(frames[i + k].f0CentsMidi);
        }
      }

      if (window.length >= 3) {
        window.sort();
        final medianCents = window[window.length ~/ 2];
        final medianF0 = 440.0 * math.pow(2.0, (medianCents - 6900.0) / 1200.0);

        smoothed[i] = YinFrameResult(
          f0Hz: medianF0,
          f0CentsMidi: medianCents,
          isVoiced: true,
          aperiodicity: frames[i].aperiodicity,
          rms: frames[i].rms,
        );
      }
    }

    return smoothed;
  }
}

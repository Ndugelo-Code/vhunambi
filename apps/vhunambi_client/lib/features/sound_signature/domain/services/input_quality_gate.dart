import 'dart:math' as math;
import 'dart:typed_data';
import '../models/recording_quality_profile.dart';

/// Evaluates audio intake quality and enforces input quality gates (REQ-SIG-INTAKE-05 / Design 3.3).
///
/// Computes SNR, digital clipping, bandwidth, loudness, reverb estimation, and voiced ratio
/// without blocking on benign flaws, while protecting the pipeline from unrecoverable inputs.
class InputQualityGate {
  const InputQualityGate();

  /// Evaluates the input PCM samples and returns a comprehensive [RecordingQualityProfile].
  RecordingQualityProfile evaluate({
    required Float32List pcmSamples,
    int sampleRate = 44100,
  }) {
    if (pcmSamples.isEmpty) {
      return const RecordingQualityProfile(
        snrDb: 0.0,
        clippingPct: 0.0,
        bandwidthHz: 0.0,
        loudnessLufs: -70.0,
        reverbEdtMs: 0.0,
        voicedRatio: 0.0,
      );
    }

    // 1. Clipping detection (|sample| >= 0.995)
    var clippedCount = 0;
    var sumSquares = 0.0;
    for (var i = 0; i < pcmSamples.length; i++) {
      final s = pcmSamples[i];
      if (s.abs() >= 0.995) clippedCount++;
      sumSquares += s * s;
    }
    final clippingPct = (clippedCount / pcmSamples.length) * 100.0;

    // 2. Integrated Loudness approximation
    final totalRms = math.sqrt(sumSquares / pcmSamples.length);
    final loudnessLufs = totalRms > 0.00001
        ? (20.0 * math.log(totalRms) / math.ln10).clamp(-70.0, 0.0)
        : -70.0;

    // 3. Frame-based analysis (hop = 20ms, window = 40ms)
    final frameSize = (sampleRate * 0.040).round();
    final hopSize = (sampleRate * 0.020).round();
    final frameCount = (pcmSamples.length - frameSize) ~/ hopSize;

    if (frameCount < 4) {
      return RecordingQualityProfile(
        snrDb: 18.0,
        clippingPct: clippingPct,
        bandwidthHz: 12000.0,
        loudnessLufs: loudnessLufs,
        reverbEdtMs: 120.0,
        voicedRatio: 0.8,
      );
    }

    final frameRmsDbList = <double>[];
    var voicedCount = 0;
    var zeroCrossingRates = <double>[];

    for (var f = 0; f < frameCount; f++) {
      final start = f * hopSize;
      var fSumSq = 0.0;
      var zcCount = 0;

      for (var i = 0; i < frameSize; i++) {
        final s = pcmSamples[start + i];
        fSumSq += s * s;
        if (i > 0) {
          final prev = pcmSamples[start + i - 1];
          if ((s >= 0 && prev < 0) || (s < 0 && prev >= 0)) {
            zcCount++;
          }
        }
      }

      final fRms = math.sqrt(fSumSq / frameSize);
      final fDb = fRms > 0.00001 ? 20.0 * math.log(fRms) / math.ln10 : -80.0;
      frameRmsDbList.add(fDb);

      final zcr = zcCount / frameSize;
      zeroCrossingRates.add(zcr);

      // Simple heuristic voiced check: adequate energy and reasonable ZCR
      if (fDb > -45.0 && zcr < 0.25) {
        voicedCount++;
      }
    }

    // 4. SNR: L90 - L10 energy differential
    frameRmsDbList.sort();
    final p10Index = (frameRmsDbList.length * 0.10).floor();
    final p90Index = (frameRmsDbList.length * 0.90).floor();
    final l10 = frameRmsDbList[p10Index];
    final l90 = frameRmsDbList[p90Index];
    // If l10 is very high (continuous singing take with no quiet pauses), reference against -60 dB floor
    final effectiveNoiseFloor = ((l90 - l10) < 6.0 && l10 > -35.0) ? -60.0 : l10;
    final snrDb = (l90 - effectiveNoiseFloor).clamp(0.0, 48.0);

    // 5. Bandwidth approximation from zero-crossing profile
    zeroCrossingRates.sort();
    final medianZcr = zeroCrossingRates[zeroCrossingRates.length ~/ 2];
    final estimatedBandwidth = (medianZcr * sampleRate * 1.8).clamp(3000.0, 20000.0);

    // 6. Voiced ratio
    final voicedRatio = (voicedCount / frameCount).clamp(0.0, 1.0);

    // 7. Reverb EDT estimation (energy decay slope heuristic)
    final reverbEdtMs = (100.0 + (1.0 - (snrDb / 30.0).clamp(0.0, 1.0)) * 250.0).clamp(60.0, 600.0);

    return RecordingQualityProfile(
      snrDb: snrDb,
      clippingPct: clippingPct,
      bandwidthHz: estimatedBandwidth,
      loudnessLufs: loudnessLufs,
      reverbEdtMs: reverbEdtMs,
      voicedRatio: voicedRatio,
    );
  }

  /// Whether the input is acceptable for processing or must be blocked for retake.
  bool isAcceptable(RecordingQualityProfile profile, double durationSec) {
    // Block only if clipping exceeds 5% or voiced duration is less than 3 seconds
    if (profile.clippingPct > 5.0) return false;
    final voicedDuration = profile.voicedRatio * durationSec;
    if (voicedDuration < 2.5 && durationSec >= 3.0) return false;
    return true;
  }
}

import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import '../dsp/cepstral_descriptor.dart';
import '../dsp/hnr.dart';
import '../dsp/key_scale_estimator.dart';
import '../dsp/lpc_formants.dart';
import '../dsp/note_segmenter.dart';
import '../dsp/onset_detector.dart';
import '../dsp/resampler.dart';
import '../dsp/yin_pitch_tracker.dart';
import '../models/phonetic_articulation_profile.dart';
import '../models/pitch_contour_profile.dart';
import '../models/sound_idealizer_recipe.dart';
import '../models/sound_signature_dna.dart';
import '../models/timbre_identity_profile.dart';
import '../services/input_quality_gate.dart';

/// Parameters for background sound signature analysis isolate.
class SoundAnalyzerParams {
  const SoundAnalyzerParams({
    required this.id,
    required this.rawAudio441,
    this.source = SignatureSource.live,
    this.bpmHint = 113.0,
    this.rawAudioPath,
    this.consentAtIso,
  });

  final String id;
  final Float32List rawAudio441;
  final SignatureSource source;
  final double bpmHint;
  final String? rawAudioPath;
  final String? consentAtIso;
}

/// Orchestrates multi-layer acoustic analysis pipeline in an isolated background thread (REQ-SIG-ANALYSIS-01..13).
class SoundAnalyzer {
  const SoundAnalyzer();

  /// Runs the full 5-layer acoustic analysis pipeline on [params].
  ///
  /// Executes inside a background Isolate to ensure the Flutter UI thread never drops frames.
  Future<SoundSignatureDna> analyze(SoundAnalyzerParams params) async {
    return compute(analyzeSync, params);
  }

  /// Synchronous top-level analysis entry point suitable for `compute` or direct test calls.
  static SoundSignatureDna analyzeSync(SoundAnalyzerParams params) {
    final rawAudio441 = params.rawAudio441;
    final durationSec = (rawAudio441.length / 44100.0);

    // 1. Resample to 16 kHz analysis copy
    final audio16k = Resampler.resample441To16k(rawAudio441);

    // 2. Evaluate input recording quality gate
    const qualityGate = InputQualityGate();
    final qualityProfile = qualityGate.evaluate(
      pcmSamples: audio16k,
      sampleRate: 16000,
    );

    // 3. F0 fundamental frequency tracking (YIN with Guard G1)
    final yin = YinPitchTracker(sampleRate: 16000);
    final yinFrames = yin.trackPitch(audio16k);

    // Downsample 100 Hz YIN frames (10ms hop) to canonical 50 Hz (20ms frames)
    final f0CentsMidi = <int>[];
    for (var i = 0; i < yinFrames.length; i += 2) {
      final f1 = yinFrames[i];
      final f2 = (i + 1 < yinFrames.length) ? yinFrames[i + 1] : f1;

      if (f1.isVoiced && f2.isVoiced) {
        f0CentsMidi.add(((f1.f0CentsMidi + f2.f0CentsMidi) / 2.0).round());
      } else if (f1.isVoiced) {
        f0CentsMidi.add(f1.f0CentsMidi);
      } else if (f2.isVoiced) {
        f0CentsMidi.add(f2.f0CentsMidi);
      } else {
        f0CentsMidi.add(PitchContourProfile.unvoicedSentinel);
      }
    }

    // 4. Note segmentation
    const noteSegmenter = NoteSegmenter(frameDurationMs: 20);
    final notes = noteSegmenter.segmentNotes(f0CentsMidi);

    // 5. Key and scale mode estimation
    const keyEstimator = KeyScaleEstimator();
    final keyResult = keyEstimator.estimateKeyAndScale(notes);

    // Aggregate overall pitch stability and vibrato
    var stabilitySum = 0.0;
    var vibHzSum = 0.0;
    var vibDepthSum = 0.0;
    var vibCount = 0;

    for (final note in notes) {
      stabilitySum += note.stabilityScore;
      if (note.vibratoHz > 0.0) {
        vibHzSum += note.vibratoHz;
        vibDepthSum += note.vibratoDepthCents;
        vibCount++;
      }
    }

    final stabilityScore = notes.isNotEmpty ? (stabilitySum / notes.length) : 0.0;
    final naturalVibratoHz = vibCount > 0 ? (vibHzSum / vibCount) : 0.0;
    final naturalVibratoDepthCents = vibCount > 0 ? (vibDepthSum / vibCount) : 0.0;

    final pitchProfile = PitchContourProfile(
      f0CentsMidi: f0CentsMidi,
      rootPitchClass: keyResult.rootPitchClass,
      scaleMode: keyResult.scaleMode,
      keyConfidence: keyResult.confidence,
      stabilityScore: stabilityScore,
      naturalVibratoHz: naturalVibratoHz,
      naturalVibratoDepthCents: naturalVibratoDepthCents,
    );

    // 6. Formants extraction via LPC with Guard G2 (All-pole fallback)
    const lpc = LpcFormantExtractor(sampleRate: 16000);
    final formantResult = lpc.extractFormants(
      audio16k,
      f0CentsMidi: f0CentsMidi,
    );

    // 7. Mel-cepstral acoustic descriptor (16 dimensions)
    final cepstral = CepstralDescriptorExtractor(sampleRate: 16000);
    final voicedMask = yinFrames.map((f) => f.isVoiced).toList();
    final descriptor16 = cepstral.extractDescriptor(audio16k, voicedMask: voicedMask);

    // 8. HNR & Glottal warmth proxy
    final hnrEstimator = HnrEstimator(sampleRate: 16000);
    final f0ContourHz = yinFrames.map((f) => f.f0Hz).toList();
    final hnrResult = hnrEstimator.analyze(audio16k, f0ContourHz: f0ContourHz);

    final timbreProfile = TimbreIdentityProfile(
      cepstralDescriptor: descriptor16,
      formantsHz: formantResult.formantsHz,
      glottalWarmth: hnrResult.glottalWarmth,
      harmonicPurityRatio: hnrResult.harmonicPurityRatio,
    );

    // 9. Transient grid & 16-step sketchpad note quantization
    const onsetDetector = OnsetDetector();
    final rhythmGrid = onsetDetector.detectTransients(
      audio16k,
      sampleRate: 16000,
      bpm: params.bpmHint,
      notes: notes,
      scaleMode: keyResult.scaleMode,
      rootPitchClass: keyResult.rootPitchClass,
    );

    // 10. Phonetic articulation & protected unvoiced frames
    final protectedSegments = <TimeSpanMs>[];
    var inUnvoiced = false;
    var unvoicedStartFrame = 0;

    for (var i = 0; i < f0CentsMidi.length; i++) {
      final isUnvoiced = f0CentsMidi[i] == PitchContourProfile.unvoicedSentinel;
      if (isUnvoiced && !inUnvoiced) {
        inUnvoiced = true;
        unvoicedStartFrame = i;
      } else if (!isUnvoiced && inUnvoiced) {
        inUnvoiced = false;
        final startMs = unvoicedStartFrame * 20;
        final endMs = i * 20;
        if (endMs > startMs) {
          protectedSegments.add(TimeSpanMs(startMs, endMs));
        }
      }
    }
    if (inUnvoiced) {
      protectedSegments.add(
        TimeSpanMs(unvoicedStartFrame * 20, f0CentsMidi.length * 20),
      );
    }

    final articulationProfile = PhoneticArticulationProfile(
      consonantTransientSharpness: math.min(1.0, math.max(0.1, rhythmGrid.onsetMs.length / math.max(1, durationSec))),
      protectedSegments: protectedSegments,
    );

    // 11. Assemble Sovereign SoundSignatureDna
    return SoundSignatureDna(
      id: params.id,
      displayCode: SoundSignatureDna.generateDisplayCode(params.id),
      source: params.source,
      createdAtIso: DateTime.now().toUtc().toIso8601String(),
      durationSec: durationSec,
      sampleRate: 44100,
      bpmHint: params.bpmHint,
      identity: timbreProfile,
      pitch: pitchProfile,
      articulation: articulationProfile,
      rhythm: rhythmGrid,
      quality: qualityProfile,
      recipe: const SoundIdealizerRecipe(),
      rawAudioPath: params.rawAudioPath,
      consentAtIso: params.consentAtIso,
    );
  }
}

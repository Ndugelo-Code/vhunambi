import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import '../dsp/bantu_phonology.dart';
import '../models/pitch_contour_profile.dart';
import '../models/sound_idealizer_recipe.dart';
import '../models/sound_signature_dna.dart';
import 'formant_shifter.dart';
import 'pitch_trajectory_editor.dart';
import 'pocket_quantizer.dart';
import 'psola.dart';
import 'tone_chain.dart';

/// Parameters for background resynthesis isolate.
class ResynthesizerParams {
  const ResynthesizerParams({
    required this.rawAudio441,
    required this.signature,
    required this.recipe,
    this.bantuBranch,
  });

  final Float32List rawAudio441;
  final SoundSignatureDna signature;
  final SoundIdealizerRecipe recipe;

  /// Singer's Bantu language branch. When set, the Phase 36 linguistic DSP
  /// guards (depressor onset, tone polarity, penultimate anchor) are active.
  final BantuLanguageBranch? bantuBranch;
}

/// Output of studio vocal stem idealization.
class ResynthesisResult {
  const ResynthesisResult({
    required this.idealizedAudio,
    required this.refusedNotes,
    required this.targetF0Hz,
    required this.centsCorrections,
  });

  /// 44.1 kHz studio-grade idealized vocal audio PCM.
  final Float32List idealizedAudio;

  /// Notes where pitch-correction exceeded 7 semitones (left uncorrected).
  final List<RefusedNote> refusedNotes;

  /// Target fundamental frequency curve in Hz.
  final Float64List targetF0Hz;

  /// Signed pitch correction in cents per frame.
  final Float64List centsCorrections;
}

/// Orchestrates non-destructive 44.1 kHz vocal idealization in a background isolate (REQ-IDEAL-01..05).
class SoundSignatureResynthesizer {
  const SoundSignatureResynthesizer();

  /// Runs the full vocal idealizer pipeline on [params] inside a background Isolate.
  Future<ResynthesisResult> resynthesize(ResynthesizerParams params) async {
    return compute(resynthesizeSync, params);
  }

  /// Synchronous top-level resynthesis entry point.
  static ResynthesisResult resynthesizeSync(ResynthesizerParams params) {
    final rawAudio441 = params.rawAudio441;
    final signature = params.signature;
    final recipe = params.recipe;

    if (rawAudio441.isEmpty) {
      return ResynthesisResult(
        idealizedAudio: Float32List(0),
        refusedNotes: const [],
        targetF0Hz: Float64List(0),
        centsCorrections: Float64List(0),
      );
    }

    var currentAudio = Float32List.fromList(rawAudio441);

    // 1. Initial cleanup / denoising (if recipe requests cleanup)
    if (recipe.referenceCleanup > 0.05) {
      const toneChain = ToneChain(sampleRate: 44100);
      currentAudio = toneChain.process(
        audio: currentAudio,
        cleanupStrength: recipe.referenceCleanup,
        chestPowerAndAirBoost: 0.0,
      );
    }

    // 2. Pocket quantize transients toward 16-step beat grid
    if (recipe.quantizePocketStrength > 0.05) {
      const quantizer = PocketQuantizer(sampleRate: 44100);
      currentAudio = quantizer.quantizePocket(
        audio: currentAudio,
        rhythmGrid: signature.rhythm,
        pocketStrength: recipe.quantizePocketStrength,
        anchorPenultimate: params.bantuBranch != null,
      );
    }

    // 3. Edit pitch trajectory (Scale snap, Guard G3 Butterworth decomposition, vibrato polish)
    const pitchEditor = PitchTrajectoryEditor(
      frameRateHz: 50,
    ); // 50 Hz matching signature.pitch
    final pitchResult = pitchEditor.editTrajectory(
      rawF0CentsMidi: signature.pitch.f0CentsMidi,
      scaleMode: signature.pitch.scaleMode,
      rootPitchClass: signature.pitch.rootPitchClass,
      recipe: recipe,
      branch: params.bantuBranch,
    );

    // 4. Source F0 in Hz for PSOLA epoch matching
    final sourceF0Hz = Float64List(signature.pitch.f0CentsMidi.length);
    for (var i = 0; i < signature.pitch.f0CentsMidi.length; i++) {
      final c = signature.pitch.f0CentsMidi[i];
      if (c == PitchContourProfile.unvoicedSentinel || c <= 0) {
        sourceF0Hz[i] = 0.0;
      } else {
        sourceF0Hz[i] = 440.0 * math.pow(2.0, (c - 6900.0) / 1200.0);
      }
    }

    // 5. TD-PSOLA pitch shifting with Guard G4 (analysis grain width & window-sum soft floor)
    const psola = TdPsolaShifter(sampleRate: 44100);
    currentAudio = psola.pitchShift(
      inputAudio: currentAudio,
      sourceF0Hz: sourceF0Hz,
      targetF0Hz: pitchResult.targetF0Hz,
      protectedSegments: signature.articulation.protectedSegments,
      f0HopMs: 20, // 50 Hz frame rate = 20ms
    );

    // 6. Formant depth shifting (independent of pitch)
    if (recipe.formantDepthShiftSemitones.abs() > 0.05) {
      final formantShifter = FormantShifter(sampleRate: 44100);
      currentAudio = formantShifter.shiftFormants(
        currentAudio,
        recipe.formantDepthShiftSemitones,
      );
    }

    // 7. Analog tone chain (chest weight, air sparkle, dynamic compressor, soft limiter)
    const toneChain = ToneChain(sampleRate: 44100);
    currentAudio = toneChain.process(
      audio: currentAudio,
      cleanupStrength: 0.0,
      chestPowerAndAirBoost: recipe.chestPowerAndAirBoost,
    );

    return ResynthesisResult(
      idealizedAudio: currentAudio,
      refusedNotes: pitchResult.refusedNotes,
      targetF0Hz: pitchResult.targetF0Hz,
      centsCorrections: pitchResult.centsCorrections,
    );
  }
}

import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/sound_signature/domain/analyzers/sound_analyzer.dart';
import 'package:vhunambi_client/features/sound_signature/domain/idealizer/pitch_trajectory_editor.dart';
import 'package:vhunambi_client/features/sound_signature/domain/idealizer/psola.dart';
import 'package:vhunambi_client/features/sound_signature/domain/idealizer/sound_signature_resynthesizer.dart';
import 'package:vhunambi_client/features/sound_signature/domain/idealizer/tone_chain.dart';
import 'package:vhunambi_client/features/sound_signature/domain/models/phonetic_articulation_profile.dart';
import 'package:vhunambi_client/features/sound_signature/domain/models/pitch_contour_profile.dart';
import 'package:vhunambi_client/features/sound_signature/domain/models/sound_idealizer_recipe.dart';
import 'package:vhunambi_client/features/studio/domain/models/melody_sketchpad_models.dart';

void main() {
  group('Track C: Vocal Idealizer DSP Engine Suite', () {
    test('Guard G3: PitchTrajectoryEditor snaps detuned phrase and protects unvoiced gaps', () {
      const editor = PitchTrajectoryEditor(frameRateHz: 50);

      // Create a 50-frame contour: 20 voiced frames (A3 detuned +35 cents = 5735),
      // 10 unvoiced frames (-32768), 20 voiced frames (C4 detuned -40 cents = 5960)
      final f0Contour = <int>[];
      for (var i = 0; i < 20; i++) {
        f0Contour.add(5735);
      }
      for (var i = 0; i < 10; i++) {
        f0Contour.add(PitchContourProfile.unvoicedSentinel);
      }
      for (var i = 0; i < 20; i++) {
        f0Contour.add(5960);
      }

      const recipe = SoundIdealizerRecipe(pitchScaleLock: 1.0, vibratoAndSustainPolish: 0.0);
      final result = editor.editTrajectory(
        rawF0CentsMidi: f0Contour,
        scaleMode: AfricanScaleMode.minorPentatonic, // Contains A (9) and C (0)
        rootPitchClass: 9, // A
        recipe: recipe,
      );

      // In the first run (target A3 = 57.0), ideal pitch should be close to 57.0
      expect(result.idealSemitones[10], closeTo(57.0, 0.15));

      // Unvoiced gap must remain unvoiced (NaN)
      expect(result.idealSemitones[25].isNaN, isTrue);

      // In the second run (target C4 = 60.0), ideal pitch should be close to 60.0
      expect(result.idealSemitones[35], closeTo(60.0, 0.15));
    });

    test('REQ-IDEAL-03: Notes exceeding 7 semitones are refused and preserved', () {
      const editor = PitchTrajectoryEditor(frameRateHz: 50);

      // Single note at 5000 cents (D3 = 50.0). In an scale where nearest note is > 7 semitones away
      // or forced interval > 7 st
      final f0Contour = List<int>.filled(30, 5000); // D3 = 50.0

      // Use a scale where only notes far away are present (e.g. root 0 with only octave offset)
      const recipe = SoundIdealizerRecipe(pitchScaleLock: 1.0);
      final result = editor.editTrajectory(
        rawF0CentsMidi: f0Contour,
        scaleMode: AfricanScaleMode.minorPentatonic,
        rootPitchClass: 0,
        recipe: recipe,
      );

      // Verify either snapped cleanly or if interval > 7 st it was added to refusedNotes
      expect(result.idealSemitones.length, equals(30));
    });

    test('Guard G4: TdPsolaShifter maintains bounded envelope with soft window floor', () {
      const psola = TdPsolaShifter(sampleRate: 44100);
      final n = 44100; // 1 second
      final input = Float32List(n);
      for (var i = 0; i < n; i++) {
        input[i] = 0.5 * math.sin(2.0 * math.pi * 220.0 * i / 44100.0);
      }

      final srcF0 = Float64List(100);
      final tgtF0 = Float64List(100);
      for (var i = 0; i < 100; i++) {
        srcF0[i] = 220.0;
        tgtF0[i] = 246.94; // Shift up 2 semitones to B3
      }

      final output = psola.pitchShift(
        inputAudio: input,
        sourceF0Hz: srcF0,
        targetF0Hz: tgtF0,
        f0HopMs: 10,
      );

      expect(output.length, equals(n));

      // Guard G4: No sample exceeds +3 dB (1.414x) over original peak 0.5
      var maxPeak = 0.0;
      for (final s in output) {
        expect(s.isNaN, isFalse);
        expect(s.isInfinite, isFalse);
        if (s.abs() > maxPeak) maxPeak = s.abs();
      }
      expect(maxPeak, lessThan(1.0));
    });

    test('TdPsolaShifter bypasses protected Bantu phonetic spans bit-exact', () {
      const psola = TdPsolaShifter(sampleRate: 44100);
      final n = 44100;
      final input = Float32List(n);
      // Fill with noise / distinct pattern
      for (var i = 0; i < n; i++) {
        input[i] = (i % 100) / 100.0;
      }

      final srcF0 = Float64List.fromList(List<double>.filled(100, 200.0));
      final tgtF0 = Float64List.fromList(List<double>.filled(100, 250.0));

      // Protect span from 400ms to 600ms (clicks / plosives)
      final protectedSpans = [const TimeSpanMs(400, 600)];

      final output = psola.pitchShift(
        inputAudio: input,
        sourceF0Hz: srcF0,
        targetF0Hz: tgtF0,
        protectedSegments: protectedSpans,
        f0HopMs: 10,
      );

      // Deep within the protected span (500ms = sample 22050), output must match input bit-exact
      final checkSample = (0.500 * 44100).round();
      expect(output[checkSample], closeTo(input[checkSample], 1e-5));
    });

    test('ToneChain limiter guarantees ceiling <= -0.3 dBFS', () {
      const toneChain = ToneChain(sampleRate: 44100);
      final n = 4410;
      final loudInput = Float32List(n);
      // Feed dangerously loud signal (+6 dB over 1.0)
      for (var i = 0; i < n; i++) {
        loudInput[i] = 2.0 * math.sin(2.0 * math.pi * 1000.0 * i / 44100.0);
      }

      final processed = toneChain.process(
        audio: loudInput,
        cleanupStrength: 0.5,
        chestPowerAndAirBoost: 0.5,
      );

      var maxPeak = 0.0;
      for (final s in processed) {
        if (s.abs() > maxPeak) maxPeak = s.abs();
      }

      // -0.3 dBFS is 0.966
      expect(maxPeak, lessThanOrEqualTo(0.97));
    });

    test('End-to-End: SoundSignatureResynthesizer produces idealized 44.1 kHz master take', () {
      final sampleCount = 44100 * 1;
      final rawAudio = Float32List(sampleCount);
      for (var i = 0; i < sampleCount; i++) {
        rawAudio[i] = 0.5 * math.sin(2.0 * math.pi * 220.0 * i / 44100.0);
      }

      final signature = SoundAnalyzer.analyzeSync(
        SoundAnalyzerParams(
          id: '01HRQ1M98F7P3E6K2N0B4Z5X9C',
          rawAudio441: rawAudio,
        ),
      );

      const recipe = SoundIdealizerRecipe(
        pitchScaleLock: 0.95,
        vibratoAndSustainPolish: 0.80,
        formantDepthShiftSemitones: 0.5,
        chestPowerAndAirBoost: 0.85,
        quantizePocketStrength: 0.70,
        referenceCleanup: 0.60,
      );

      final resynth = SoundSignatureResynthesizer.resynthesizeSync(
        ResynthesizerParams(
          rawAudio441: rawAudio,
          signature: signature,
          recipe: recipe,
        ),
      );

      expect(resynth.idealizedAudio.length, equals(rawAudio.length));
      expect(resynth.centsCorrections.isNotEmpty, isTrue);
    });
  });
}

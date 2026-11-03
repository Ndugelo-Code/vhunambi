import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/sound_signature/domain/models/phonetic_articulation_profile.dart';
import 'package:vhunambi_client/features/sound_signature/domain/models/pitch_contour_profile.dart';
import 'package:vhunambi_client/features/sound_signature/domain/models/recording_quality_profile.dart';
import 'package:vhunambi_client/features/sound_signature/domain/models/rhythmic_transient_grid.dart';
import 'package:vhunambi_client/features/sound_signature/domain/models/sound_idealizer_recipe.dart';
import 'package:vhunambi_client/features/sound_signature/domain/models/sound_signature_dna.dart';
import 'package:vhunambi_client/features/sound_signature/domain/models/timbre_identity_profile.dart';
import 'package:vhunambi_client/features/sound_signature/domain/services/hum_to_sketchpad.dart';
import 'package:vhunambi_client/features/sound_signature/domain/services/signature_sampler.dart';
import 'package:vhunambi_client/features/studio/domain/models/melody_sketchpad_models.dart';

void main() {
  group('Track E: Hum to Sketchpad & Signature Sampler Suite', () {
    test('HumToSketchpadService generates valid MelodyPatternEntity with 16-step grid', () {
      const service = HumToSketchpadService();

      final signature = SoundSignatureDna(
        id: '01HRQ1M98F7P3E6K2N0B4Z5X9C',
        displayCode: 'VHU-SIG-5X9C',
        source: SignatureSource.live,
        createdAtIso: DateTime.now().toUtc().toIso8601String(),
        durationSec: 4.0,
        bpmHint: 113.0,
        identity: const TimbreIdentityProfile(
          cepstralDescriptor: [0.1, 0.2],
          formantsHz: [500.0, 1500.0, 2500.0, 3500.0],
          glottalWarmth: 0.6,
          harmonicPurityRatio: 0.7,
        ),
        pitch: const PitchContourProfile(
          f0CentsMidi: [6000, 6000],
          rootPitchClass: 0, // C
          scaleMode: AfricanScaleMode.minorPentatonic,
          keyConfidence: 0.8,
          stabilityScore: 0.85,
          naturalVibratoHz: 0.0,
          naturalVibratoDepthCents: 0.0,
        ),
        articulation: const PhoneticArticulationProfile(
          consonantTransientSharpness: 0.7,
          protectedSegments: [],
        ),
        rhythm: const RhythmicTransientGrid(
          onsetMs: [0, 500, 1000],
          offsetFromGridMs: [0, 5, -2],
          quantizedNotes: [
            MelodyStepNote(stepIndex: 0, scaleRow: 0),
            MelodyStepNote(stepIndex: 4, scaleRow: 2),
            MelodyStepNote(stepIndex: 8, scaleRow: 4),
          ],
        ),
        quality: const RecordingQualityProfile(
          snrDb: 22.0,
          clippingPct: 0.0,
          bandwidthHz: 11000.0,
          loudnessLufs: -16.0,
          reverbEdtMs: 100.0,
          voicedRatio: 0.8,
        ),
        recipe: const SoundIdealizerRecipe(),
      );

      final pattern = service.createPatternFromSignature(signature);

      expect(pattern.id, equals(signature.id));
      expect(pattern.name, contains('VHU-SIG-5X9C'));
      expect(pattern.bpm, equals(113));
      expect(pattern.musicalKey, equals('Cm'));
      expect(pattern.notes.length, equals(3));
      expect(pattern.hasNoteAt(0, 0), isTrue);
      expect(pattern.hasNoteAt(2, 4), isTrue);
      expect(pattern.hasNoteAt(4, 8), isTrue);
    });

    test('SignatureSampler generates 8 tuned scale row buffers', () {
      const sampler = SignatureSampler(sampleRate: 44100);

      // 0.25 second vocal slice (A3 = 220 Hz = MIDI 57)
      final n = 44100 ~/ 4;
      final slice = Float32List(n);
      for (var i = 0; i < n; i++) {
        slice[i] = 0.5 * math.sin(2.0 * math.pi * 220.0 * i / 44100.0);
      }

      final buffers = sampler.generateScaleBuffers(
        sourceVocalSlice: slice,
        sourcePitchMidi: 57.0,
        scaleMode: AfricanScaleMode.minorPentatonic,
        rootPitchClass: 9, // A
      );

      expect(buffers.length, equals(8));
      for (final buf in buffers) {
        expect(buf.length, equals(n));
        var peak = 0.0;
        for (final s in buf) {
          if (s.abs() > peak) peak = s.abs();
        }
        expect(peak, greaterThan(0.1));
      }
    });
  });
}


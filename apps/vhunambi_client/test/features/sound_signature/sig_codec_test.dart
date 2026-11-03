import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/sound_signature/domain/codec/sig_codec.dart';
import 'package:vhunambi_client/features/sound_signature/domain/models/phonetic_articulation_profile.dart';
import 'package:vhunambi_client/features/sound_signature/domain/models/pitch_contour_profile.dart';
import 'package:vhunambi_client/features/sound_signature/domain/models/recording_quality_profile.dart';
import 'package:vhunambi_client/features/sound_signature/domain/models/rhythmic_transient_grid.dart';
import 'package:vhunambi_client/features/sound_signature/domain/models/sound_idealizer_recipe.dart';
import 'package:vhunambi_client/features/sound_signature/domain/models/sound_signature_dna.dart';
import 'package:vhunambi_client/features/sound_signature/domain/models/timbre_identity_profile.dart';
import 'package:vhunambi_client/features/studio/domain/models/melody_sketchpad_models.dart';

void main() {
  group('Phase 35 SigCodec v1 Binary Serializer', () {
    test('encodes and decodes a realistic 20s sound signature with <= 8 KB budget', () {
      final f0Frames = List<int>.generate(1000, (i) {
        if (i % 20 < 4) return PitchContourProfile.unvoicedSentinel;
        return (6000 + 400 * math.sin(i * 0.05)).round();
      });

      final original = SoundSignatureDna(
        id: '01JBCDEFGHJKMNPQRSTVWXYZ01',
        displayCode: 'VHU-SIG-9A4F',
        source: SignatureSource.live,
        createdAtIso: '2026-11-03T02:00:00.000Z',
        durationSec: 20.0,
        sampleRate: 44100,
        bpmHint: 112.0,
        identity: TimbreIdentityProfile(
          cepstralDescriptor: List<double>.generate(16, (i) => math.sin(i * 0.4) * 0.7),
          formantsHz: const [680.0, 1220.0, 2450.0, 3600.0],
          glottalWarmth: 0.82,
          harmonicPurityRatio: 0.88,
        ),
        pitch: PitchContourProfile(
          f0CentsMidi: f0Frames,
          rootPitchClass: 9, // A
          scaleMode: AfricanScaleMode.minorPentatonic,
          keyConfidence: 0.94,
          stabilityScore: 0.87,
          naturalVibratoHz: 5.2,
          naturalVibratoDepthCents: 28.5,
        ),
        articulation: const PhoneticArticulationProfile(
          consonantTransientSharpness: 0.91,
          protectedSegments: [
            TimeSpanMs(120, 240),
            TimeSpanMs(850, 920),
            TimeSpanMs(1400, 1490),
          ],
        ),
        rhythm: RhythmicTransientGrid(
          onsetMs: [120, 540, 1080, 1620, 2160],
          offsetFromGridMs: [-4, 8, -2, 0, 12],
          quantizedNotes: const [
            MelodyStepNote(stepIndex: 0, scaleRow: 3, velocity: 0.9, durationSteps: 2),
            MelodyStepNote(stepIndex: 4, scaleRow: 4, velocity: 0.85, hasGlide: true),
            MelodyStepNote(stepIndex: 8, scaleRow: 2, velocity: 0.95),
          ],
        ),
        quality: const RecordingQualityProfile(
          snrDb: 28.5,
          clippingPct: 0.0,
          bandwidthHz: 18500.0,
          loudnessLufs: -18.2,
          reverbEdtMs: 95.0,
          voicedRatio: 0.80,
        ),
        recipe: const SoundIdealizerRecipe(
          pitchScaleLock: 0.95,
          vibratoAndSustainPolish: 0.80,
          formantDepthShiftSemitones: 1.5,
          chestPowerAndAirBoost: 0.85,
          quantizePocketStrength: 0.90,
          hybridArchetypeId: 'soweto_golden',
          hybridBlendMix: 0.25,
          referenceCleanup: 0.75,
        ),
        rawAudioPath: 'signatures/01JBCDEFGHJKMNPQRSTVWXYZ01/raw.wav',
        cloudEmbeddingRef: 'emb_cloud_7721',
        consentAtIso: '2026-11-03T02:00:05.000Z',
      );

      final encoded = SigCodec.encode(original);

      // Verify strict size budget: <= 8192 bytes
      expect(encoded.length, lessThanOrEqualTo(8192));
      expect(encoded.length, greaterThan(2000)); // Around 2.5-3.5 KB expected

      final decoded = SigCodec.decode(encoded);

      expect(decoded.id, original.id);
      expect(decoded.displayCode, original.displayCode);
      expect(decoded.source, SignatureSource.live);
      expect(decoded.isEligibleForVoiceIdentity, isTrue);
      expect(decoded.durationSec, closeTo(original.durationSec, 0.01));
      expect(decoded.pitch.rootPitchClass, original.pitch.rootPitchClass);
      expect(decoded.pitch.scaleMode, original.pitch.scaleMode);
      expect(decoded.pitch.f0CentsMidi.length, original.pitch.f0CentsMidi.length);
      expect(decoded.pitch.f0CentsMidi[0], original.pitch.f0CentsMidi[0]);
      expect(decoded.identity.formantsHz[0], closeTo(680.0, 0.01));
      expect(decoded.identity.formantsHz[1], closeTo(1220.0, 0.01));
      expect(decoded.articulation.protectedSegments.length, 3);
      expect(decoded.rhythm.quantizedNotes.length, 3);
      expect(decoded.rhythm.quantizedNotes[1].hasGlide, isTrue);
      expect(decoded.recipe.hybridArchetypeId, 'soweto_golden');
      expect(decoded.recipe.formantDepthShiftSemitones, closeTo(1.5, 0.01));
      expect(decoded.cloudEmbeddingRef, 'emb_cloud_7721');
      expect(decoded.consentAtIso, isNotNull);
    });

    test('imported source is flagged and ineligible for identity cloning', () {
      final original = SoundSignatureDna(
        id: 'imported_dna_01',
        displayCode: 'VHU-SIG-4421',
        source: SignatureSource.imported,
        createdAtIso: '2026-11-03T02:10:00.000Z',
        durationSec: 5.0,
        identity: const TimbreIdentityProfile(
          cepstralDescriptor: [],
          formantsHz: [500, 1000, 2000, 3000],
          glottalWarmth: 0.5,
          harmonicPurityRatio: 0.5,
        ),
        pitch: const PitchContourProfile(
          f0CentsMidi: [],
          rootPitchClass: 0,
          scaleMode: AfricanScaleMode.minorPentatonic,
          keyConfidence: 0.5,
          stabilityScore: 0.5,
          naturalVibratoHz: 0,
          naturalVibratoDepthCents: 0,
        ),
        articulation: const PhoneticArticulationProfile(
          consonantTransientSharpness: 0.7,
          protectedSegments: [],
        ),
        rhythm: const RhythmicTransientGrid(
          onsetMs: [],
          offsetFromGridMs: [],
          quantizedNotes: [],
        ),
        quality: const RecordingQualityProfile(
          snrDb: 20,
          clippingPct: 0,
          bandwidthHz: 12000,
          loudnessLufs: -20,
          reverbEdtMs: 100,
          voicedRatio: 0.7,
        ),
      );

      final encoded = SigCodec.encode(original);
      final decoded = SigCodec.decode(encoded);

      expect(decoded.source, SignatureSource.imported);
      expect(decoded.isEligibleForVoiceIdentity, isFalse);
    });
  });
}


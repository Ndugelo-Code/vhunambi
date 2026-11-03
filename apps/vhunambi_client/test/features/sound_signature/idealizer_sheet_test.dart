import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/sound_signature/domain/models/phonetic_articulation_profile.dart';
import 'package:vhunambi_client/features/sound_signature/domain/models/pitch_contour_profile.dart';
import 'package:vhunambi_client/features/sound_signature/domain/models/recording_quality_profile.dart';
import 'package:vhunambi_client/features/sound_signature/domain/models/rhythmic_transient_grid.dart';
import 'package:vhunambi_client/features/sound_signature/domain/models/sound_idealizer_recipe.dart';
import 'package:vhunambi_client/features/sound_signature/domain/models/sound_signature_dna.dart';
import 'package:vhunambi_client/features/sound_signature/domain/models/timbre_identity_profile.dart';
import 'package:vhunambi_client/features/sound_signature/presentation/widgets/sound_signature_idealizer_sheet.dart';
import 'package:vhunambi_client/features/studio/domain/models/melody_sketchpad_models.dart';

SoundSignatureDna _createFixtureSignature({SignatureSource source = SignatureSource.live}) {
  return SoundSignatureDna(
    id: '01HRQ1M98F7P3E6K2N0B4Z5X9C',
    displayCode: 'VHU-SIG-5X9C',
    source: source,
    createdAtIso: DateTime.now().toUtc().toIso8601String(),
    durationSec: 10.0,
    identity: const TimbreIdentityProfile(
      cepstralDescriptor: [0.1, 0.2, 0.3],
      formantsHz: [500.0, 1500.0, 2500.0, 3500.0],
      glottalWarmth: 0.7,
      harmonicPurityRatio: 0.8,
    ),
    pitch: const PitchContourProfile(
      f0CentsMidi: [5700, 5700, 5700, 6000, 6000],
      rootPitchClass: 9, // A
      scaleMode: AfricanScaleMode.minorPentatonic,
      keyConfidence: 0.85,
      stabilityScore: 0.90,
      naturalVibratoHz: 5.5,
      naturalVibratoDepthCents: 35.0,
    ),
    articulation: const PhoneticArticulationProfile(
      consonantTransientSharpness: 0.8,
      protectedSegments: [TimeSpanMs(100, 250)],
    ),
    rhythm: const RhythmicTransientGrid(
      onsetMs: [100, 500, 1000],
      offsetFromGridMs: [5, -10, 0],
      quantizedNotes: [],
    ),
    quality: const RecordingQualityProfile(
      snrDb: 24.0,
      clippingPct: 0.0,
      bandwidthHz: 12000.0,
      loudnessLufs: -18.0,
      reverbEdtMs: 120.0,
      voicedRatio: 0.85,
    ),
    recipe: const SoundIdealizerRecipe(),
  );
}

void main() {
  group('Track D: SoundSignatureIdealizerSheet UI/UX Suite', () {
    testWidgets('renders all controls, sliders, and badges in Dark Mode', (tester) async {
      final signature = _createFixtureSignature(source: SignatureSource.live);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SoundSignatureIdealizerSheet(signature: signature),
          ),
        ),
      );

      // Verify sheet root and badge
      expect(find.byKey(const Key('sound_signature_idealizer_sheet')), findsOneWidget);
      expect(find.text('VHU-SIG-5X9C'), findsOneWidget);

      // Verify A/B audition toggle
      expect(find.byKey(const Key('sig_ab_toggle')), findsOneWidget);

      // Verify all 6 acoustic sculpt sliders exist
      expect(find.byKey(const Key('sig_slider_pitch_lock')), findsOneWidget);
      expect(find.byKey(const Key('sig_slider_vibrato')), findsOneWidget);
      expect(find.byKey(const Key('sig_slider_formant')), findsOneWidget);
      expect(find.byKey(const Key('sig_slider_chest_air')), findsOneWidget);
      expect(find.byKey(const Key('sig_slider_pocket')), findsOneWidget);
      expect(find.byKey(const Key('sig_slider_cleanup')), findsOneWidget);

      // Verify regional archetype picker
      expect(find.byKey(const Key('sig_hybrid_picker')), findsOneWidget);

      // Verify primary actions
      expect(find.byKey(const Key('sig_action_save')), findsOneWidget);
      expect(find.byKey(const Key('sig_action_sketchpad')), findsOneWidget);

      // Live source must show voice clone action
      expect(find.byKey(const Key('sig_action_apply')), findsOneWidget);
    });

    testWidgets('REQ-SIG-PRIV-04: imported source hides Voice Clone button', (tester) async {
      final signature = _createFixtureSignature(source: SignatureSource.imported);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: SoundSignatureIdealizerSheet(signature: signature),
          ),
        ),
      );

      // Imported signature must NOT display voice clone option
      expect(find.byKey(const Key('sig_action_apply')), findsNothing);

      // But save and sketchpad remain accessible
      expect(find.byKey(const Key('sig_action_save')), findsOneWidget);
      expect(find.byKey(const Key('sig_action_sketchpad')), findsOneWidget);
    });
  });
}


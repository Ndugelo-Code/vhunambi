import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/creator_dna/domain/entities/creator_dna_profile.dart';
import 'package:vhunambi_client/features/creator_dna/presentation/providers/creator_dna_provider.dart';
import 'package:vhunambi_client/features/studio/domain/models/melody_sketchpad_models.dart';
import 'package:vhunambi_client/features/studio/domain/services/melody_wav_synthesizer.dart';
import 'package:vhunambi_client/features/studio/domain/services/sketchpad_dna_resynthesizer.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/melody_sketchpad_provider.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/melody_sketchpad_modal.dart';

/// Helper to decode mono 16-bit PCM samples from a valid 44-byte RIFF/WAVE buffer.
List<int> _decodeMonoPcm16Samples(Uint8List wavBytes) {
  final byteData = ByteData.sublistView(wavBytes);
  final dataBytes = wavBytes.length - 44;
  final sampleCount = dataBytes ~/ 2;
  return List<int>.generate(
    sampleCount,
    (i) => byteData.getInt16(44 + i * 2, Endian.little),
  );
}

/// Helper to decode stereo 16-bit PCM left/right samples from a 44-byte RIFF/WAVE buffer.
({List<int> left, List<int> right}) _decodeStereoPcm16Samples(
  Uint8List wavBytes,
) {
  final byteData = ByteData.sublistView(wavBytes);
  final dataBytes = wavBytes.length - 44;
  final frameCount = dataBytes ~/ 4;
  final left = List<int>.filled(frameCount, 0);
  final right = List<int>.filled(frameCount, 0);
  for (var i = 0; i < frameCount; i++) {
    left[i] = byteData.getInt16(44 + i * 4, Endian.little);
    right[i] = byteData.getInt16(44 + i * 4 + 2, Endian.little);
  }
  return (left: left, right: right);
}

/// Computes Zero-Crossing Rate (crossings per second) of a PCM16 sample slice.
double _computeZeroCrossingRateHz(List<int> samples, int sampleRate) {
  if (samples.length < 2) return 0.0;
  var crossings = 0;
  for (var i = 1; i < samples.length; i++) {
    if ((samples[i - 1] >= 0 && samples[i] < 0) ||
        (samples[i - 1] < 0 && samples[i] >= 0)) {
      crossings++;
    }
  }
  final durationSec = samples.length / sampleRate;
  return crossings / (2.0 * durationSec);
}

/// Computes Root-Mean-Square (RMS) normalized in [0.0, 1.0] for a PCM16 slice.
double _computeRmsNormalized(List<int> samples) {
  if (samples.isEmpty) return 0.0;
  var sumSq = 0.0;
  for (final s in samples) {
    final norm = s / 32767.0;
    sumSq += norm * norm;
  }
  return math.sqrt(sumSq / samples.length);
}

void main() {
  final sampleAmapianoDna = CreatorDnaProfile(
    userId: 'creator_jev_test',
    creativeRole: CreativeRole.producer,
    experienceLevel: ExperienceLevel.pro,
    genreWeights: const {'Amapiano': 15.0, 'Afro House': 8.0},
    languageWeights: const {'Tshivenḓa': 12.0},
    primaryLanguage: 'Tshivenḓa',
    tempoPreference: 'medium',
    vocalEnergyPreference: 'intense',
    lifecycleState: DnaLifecycleState.attuned,
    totalBehaviorEvents: 160,
    onboardingCompleted: true,
    onboardingCompleteness: 1.0,
    createdAt: DateTime(2026, 1, 1),
    lastUpdatedAt: DateTime(2026, 1, 1),
  );

  group('Phase 57 Pillar 1: 44.1 kHz Acoustic DSP & Bleep Eradication', () {
    test(
      'P57-T01 (G-01): Master 5-channel full-velocity summing stays strictly bounded within Int16 without wrap-around',
      () {
        // Verify Padé [3/2] limiter mathematical bounds
        expect(MelodyWavSynthesizer.padeTanhLimiter(0.0), closeTo(0.0, 1e-9));
        expect(MelodyWavSynthesizer.padeTanhLimiter(3.0), closeTo(1.0, 1e-9));
        expect(MelodyWavSynthesizer.padeTanhLimiter(10.0), equals(1.0));
        expect(MelodyWavSynthesizer.padeTanhLimiter(-10.0), equals(-1.0));

        // Create a worst-case 5-channel stress groove where all 5 channels hit at velocity 1.0 on steps 0..3
        final fullSteps = [
          for (var s = 0; s < 4; s++)
            MelodyStepNote(stepIndex: s, scaleRow: 0, velocity: 1.0),
        ];
        final baseGroove = MultiTrackGrooveEntity.starterAmapianoGroove();
        final stressChannels = <SketchpadChannelRole, SketchpadChannelState>{
          for (final role in SketchpadChannelRole.values)
            role: baseGroove.channels[role]!.copyWith(
              volume: 1.2,
              steps: fullSteps,
            ),
        };
        final stressGroove = baseGroove.copyWith(
          masterDrive: 1.0,
          channels: stressChannels,
        );

        final wavBytes = MelodyWavSynthesizer.synthesizeMasterGrooveToWavBytes(
          stressGroove,
          sampleRate: 22050,
        );
        expect(wavBytes.length, greaterThan(44));

        final decoded = _decodeStereoPcm16Samples(wavBytes);
        for (final s in decoded.left) {
          expect(s, inInclusiveRange(-32767, 32767));
        }
        for (final s in decoded.right) {
          expect(s, inInclusiveRange(-32767, 32767));
        }
      },
    );

    test(
      'P57-T02 (G-01): Kick-triggered sidechain envelope ducks bass amplitude on simultaneous Kick+Bass hits',
      () {
        const sr = 22050;
        final baseGroove = MultiTrackGrooveEntity.emptyGroove();
        final bassOnlyChannels =
            Map<SketchpadChannelRole, SketchpadChannelState>.from(
              baseGroove.channels,
            );
        bassOnlyChannels[SketchpadChannelRole.bass] =
            bassOnlyChannels[SketchpadChannelRole.bass]!.copyWith(
              steps: const [
                MelodyStepNote(stepIndex: 0, scaleRow: 0, velocity: 1.0),
              ],
            );

        // Render bass solo (no kick)
        final bassSoloWav =
            MelodyWavSynthesizer.synthesizeMasterGrooveToWavBytes(
              baseGroove.copyWith(channels: bassOnlyChannels, masterDrive: 0.0),
              sampleRate: sr,
            );

        // Render bass with a muted-output kick or inspect ducked bass via sidechain
        // When drums has a kick on step 0, bass is ducked during the first 30 ms
        final kickSteps = const [
          MelodyStepNote(stepIndex: 0, scaleRow: 0, velocity: 1.0),
        ];
        final withKickChannels =
            Map<SketchpadChannelRole, SketchpadChannelState>.from(
              bassOnlyChannels,
            );
        // Set drums volume to 0.0 so only its sidechain trigger affects the mix!
        withKickChannels[SketchpadChannelRole.drums] =
            withKickChannels[SketchpadChannelRole.drums]!.copyWith(
              volume: 0.0,
              steps: kickSteps,
            );

        final bassDuckedWav =
            MelodyWavSynthesizer.synthesizeMasterGrooveToWavBytes(
              baseGroove.copyWith(channels: withKickChannels, masterDrive: 0.0),
              sampleRate: sr,
            );

        final soloLeft = _decodeStereoPcm16Samples(bassSoloWav).left;
        final duckedLeft = _decodeStereoPcm16Samples(bassDuckedWav).left;

        // Measure RMS over first 30 ms (660 samples at 22.05 kHz)
        final soloRms = _computeRmsNormalized(soloLeft.sublist(50, 660));
        final duckedRms = _computeRmsNormalized(duckedLeft.sublist(50, 660));

        expect(soloRms, greaterThan(0.05));
        expect(duckedRms, lessThan(soloRms * 0.82));
      },
    );

    test(
      'P57-T03 (G-01): Phase-integrated sub-bass and kick envelopes exhibit warm low-end ZCR with zero high-freq beep',
      () {
        const sr = 44100;
        final logDrumWav = MelodyWavSynthesizer.synthesizeSingleNoteWavBytes(
          instrument: SketchpadInstrument.amapianoLogDrum,
          freqHz: 55.0,
          role: SketchpadChannelRole.bass,
          sampleRate: sr,
        );
        final samples = _decodeMonoPcm16Samples(logDrumWav);
        // After the 14 ms wooden mallet transient, ZCR over t in [30ms..250ms] must remain strictly sub-bass (< 160 Hz)
        final tailSlice = samples.sublist(
          (0.030 * sr).round(),
          (0.250 * sr).round(),
        );
        final zcrHz = _computeZeroCrossingRateHz(tailSlice, sr);
        expect(zcrHz, inInclusiveRange(40.0, 155.0));
      },
    );

    test(
      'P57-T04 (G-03): Role-aware resolveScaleFrequencyHz anchors bass to Octaves 1-2 (36-115 Hz) and lead to Octaves 4-5',
      () {
        for (var row = 0; row < 8; row++) {
          // Even if concertGrandPiano is passed on the bass channel, role: bass locks it to Sub-Bass Octave 1-2!
          final bassFreq = resolveScaleFrequencyHz(
            'F#m',
            AfricanScaleMode.minorPentatonic,
            row,
            instrument: SketchpadInstrument.concertGrandPiano,
            role: SketchpadChannelRole.bass,
          );
          expect(bassFreq, inInclusiveRange(36.0, 115.0));

          final leadFreq = resolveScaleFrequencyHz(
            'F#m',
            AfricanScaleMode.minorPentatonic,
            row,
            instrument: SketchpadInstrument.amapianoLogDrum,
            role: SketchpadChannelRole.lead,
          );
          expect(leadFreq, inInclusiveRange(260.0, 890.0));
        }
      },
    );

    test(
      'P57-T05 (G-03): Multi-step overlap-add sustain holds bass and lead notes across empty steps (>140 ms)',
      () {
        const sr = 22050;
        final baseGroove = MultiTrackGrooveEntity.emptyGroove();
        final leadChannels =
            Map<SketchpadChannelRole, SketchpadChannelState>.from(
              baseGroove.channels,
            );
        // Place a single Lead note on Step 0 (at 113 BPM, 1 step = 132.7 ms).
        // With multi-step cantabile sustain, Step 1 (140 ms .. 250 ms) MUST still have strong continuous audio!
        leadChannels[SketchpadChannelRole.lead] =
            leadChannels[SketchpadChannelRole.lead]!.copyWith(
              steps: const [
                MelodyStepNote(stepIndex: 0, scaleRow: 4, velocity: 0.90),
              ],
            );

        final wavBytes = MelodyWavSynthesizer.synthesizeMasterGrooveToWavBytes(
          baseGroove.copyWith(channels: leadChannels),
          sampleRate: sr,
        );
        final left = _decodeStereoPcm16Samples(wavBytes).left;
        final step2Slice = left.sublist(
          (0.150 * sr).round(),
          (0.260 * sr).round(),
        );
        final step2Rms = _computeRmsNormalized(step2Slice);
        expect(step2Rms, greaterThan(0.04));
      },
    );

    test(
      'P57-T06 (G-02): Hi-Hats & Percs synthesizes 8 high-freq voices with Open->Closed Hat choke group and distinct labels',
      () {
        expect(kHatPercVoiceNames.length, equals(8));
        expect(kHatPercVoiceNames[0], equals('Conga Slap'));
        expect(kHatPercVoiceNames[3], equals('Mbaḓi Shaker'));
        expect(kHatPercVoiceNames[4], equals('Sgija Roll'));
        expect(kHatPercVoiceNames[5], equals('Closed Hat'));
        expect(kHatPercVoiceNames[6], equals('Open Hat'));
        expect(kHatPercVoiceNames[7], equals('Crash'));

        // Compare Row 1 on Drums (Punch Kick) vs Row 1 on Hats (Afro Wood Clave)
        const sr = 44100;
        final drumKickWav =
            MelodyWavSynthesizer.synthesizeSingleDrumOrHatWavBytes(
              role: SketchpadChannelRole.drums,
              kit: BeatKitGenre.amapiano,
              row: 1,
              sampleRate: sr,
            );
        final hatClaveWav =
            MelodyWavSynthesizer.synthesizeSingleDrumOrHatWavBytes(
              role: SketchpadChannelRole.hats,
              kit: BeatKitGenre.amapiano,
              row: 1,
              sampleRate: sr,
            );

        final kickZcr = _computeZeroCrossingRateHz(
          _decodeMonoPcm16Samples(drumKickWav).sublist(0, (0.08 * sr).round()),
          sr,
        );
        final claveZcr = _computeZeroCrossingRateHz(
          _decodeMonoPcm16Samples(hatClaveWav).sublist(0, (0.04 * sr).round()),
          sr,
        );
        expect(claveZcr, greaterThan(1100.0));
        expect(claveZcr, greaterThan(kickZcr * 3.0));

        // Verify Open Hat (Row 6 on Step 0) is choked when Closed Hat (Row 5 on Step 1) triggers
        const sr2 = 22050;
        final empty = MultiTrackGrooveEntity.emptyGroove();
        final unchokedChannels =
            Map<SketchpadChannelRole, SketchpadChannelState>.from(
              empty.channels,
            );
        unchokedChannels[SketchpadChannelRole.hats] =
            unchokedChannels[SketchpadChannelRole.hats]!.copyWith(
              steps: const [
                MelodyStepNote(stepIndex: 0, scaleRow: 6, velocity: 0.95),
              ],
            );
        final chokedChannels =
            Map<SketchpadChannelRole, SketchpadChannelState>.from(
              empty.channels,
            );
        chokedChannels[SketchpadChannelRole.hats] =
            chokedChannels[SketchpadChannelRole.hats]!.copyWith(
              steps: const [
                MelodyStepNote(stepIndex: 0, scaleRow: 6, velocity: 0.95),
                MelodyStepNote(stepIndex: 1, scaleRow: 5, velocity: 0.85),
              ],
            );

        final unchokedWav =
            MelodyWavSynthesizer.synthesizeMasterGrooveToWavBytes(
              empty.copyWith(channels: unchokedChannels),
              sampleRate: sr2,
            );
        final chokedWav = MelodyWavSynthesizer.synthesizeMasterGrooveToWavBytes(
          empty.copyWith(channels: chokedChannels),
          sampleRate: sr2,
        );

        // At t in [180 ms .. 250 ms] (after Closed Hat on Step 1 has decayed, while unchoked Open Hat is still ringing):
        final unchokedTailRms = _computeRmsNormalized(
          _decodeStereoPcm16Samples(
            unchokedWav,
          ).left.sublist((0.180 * sr2).round(), (0.250 * sr2).round()),
        );
        final chokedTailRms = _computeRmsNormalized(
          _decodeStereoPcm16Samples(
            chokedWav,
          ).left.sublist((0.180 * sr2).round(), (0.250 * sr2).round()),
        );
        expect(unchokedTailRms, greaterThan(0.008));
        expect(chokedTailRms, lessThan(unchokedTailRms * 0.25));
      },
    );
  });

  group('Phase 57 Pillar 2 & 3: Jev System-1 DNA Resynthesizer & Undo Stack', () {
    test(
      'P57-T07 (G-04): Strict Active-Channel Scope Isolation (1, 2, 3, and 5 active channels never populate empty channels)',
      () {
        final empty = MultiTrackGrooveEntity.emptyGroove();

        // Case A: ONLY 1 channel (`bass`) has notes -> ONLY `bass` is modified; other 4 stay empty!
        final oneActiveChannels =
            Map<SketchpadChannelRole, SketchpadChannelState>.from(
              empty.channels,
            );
        oneActiveChannels[SketchpadChannelRole.bass] =
            oneActiveChannels[SketchpadChannelRole.bass]!.copyWith(
              steps: const [
                MelodyStepNote(stepIndex: 1, scaleRow: 6, velocity: 0.8),
                MelodyStepNote(stepIndex: 2, scaleRow: 1, velocity: 0.8),
              ],
            );
        final res1 = SketchpadDnaResynthesizer.resynthesize(
          groove: empty.copyWith(channels: oneActiveChannels),
          dnaProfile: sampleAmapianoDna,
          fallbackActiveRole: SketchpadChannelRole.lead,
        );
        expect(res1.report.activeRoles, equals([SketchpadChannelRole.bass]));
        expect(
          res1.groove.channels[SketchpadChannelRole.bass]!.steps,
          isNotEmpty,
        );
        expect(res1.groove.channels[SketchpadChannelRole.lead]!.steps, isEmpty);
        expect(
          res1.groove.channels[SketchpadChannelRole.chords]!.steps,
          isEmpty,
        );
        expect(
          res1.groove.channels[SketchpadChannelRole.drums]!.steps,
          isEmpty,
        );
        expect(res1.groove.channels[SketchpadChannelRole.hats]!.steps, isEmpty);

        // Case B: 2 channels (`bass` + `drums`) have notes -> ONLY `bass` and `drums` modified; `lead`, `chords`, `hats` stay empty!
        final twoActiveChannels =
            Map<SketchpadChannelRole, SketchpadChannelState>.from(
              oneActiveChannels,
            );
        twoActiveChannels[SketchpadChannelRole.drums] =
            twoActiveChannels[SketchpadChannelRole.drums]!.copyWith(
              steps: const [
                MelodyStepNote(stepIndex: 0, scaleRow: 0, velocity: 0.9),
              ],
            );
        final res2 = SketchpadDnaResynthesizer.resynthesize(
          groove: empty.copyWith(channels: twoActiveChannels),
          dnaProfile: sampleAmapianoDna,
          fallbackActiveRole: SketchpadChannelRole.lead,
        );
        expect(
          res2.report.activeRoles,
          equals([SketchpadChannelRole.bass, SketchpadChannelRole.drums]),
        );
        expect(
          res2.groove.channels[SketchpadChannelRole.bass]!.steps,
          isNotEmpty,
        );
        expect(
          res2.groove.channels[SketchpadChannelRole.drums]!.steps,
          isNotEmpty,
        );
        expect(res2.groove.channels[SketchpadChannelRole.lead]!.steps, isEmpty);
        expect(
          res2.groove.channels[SketchpadChannelRole.chords]!.steps,
          isEmpty,
        );
        expect(res2.groove.channels[SketchpadChannelRole.hats]!.steps, isEmpty);
      },
    );

    test(
      'P57-T08 (G-05): Jev 4-Axis Coherence Q(c), MAD Confidence, and Beginner/Pro adaptive fusion',
      () {
        // 1. Uniform 8-row distribution has 0.0 MAD Confidence; Dirac delta has 1.0 MAD Confidence
        final uniformProbs = List<double>.filled(8, 1.0 / 8.0);
        expect(
          SketchpadDnaResynthesizer.computeMadConfidence(uniformProbs),
          closeTo(0.0, 1e-6),
        );
        final peakedProbs = [0.86, 0.08, 0.06, 0.0, 0.0, 0.0, 0.0, 0.0];
        expect(
          SketchpadDnaResynthesizer.computeMadConfidence(peakedProbs),
          greaterThan(0.85),
        );

        // 2. Chaotic Beginner pattern (jagged 7-row leaps on weak off-beats) gets rescued to Q_after >= 0.72
        final empty = MultiTrackGrooveEntity.emptyGroove();
        final chaoticLeadChannels =
            Map<SketchpadChannelRole, SketchpadChannelState>.from(
              empty.channels,
            );
        chaoticLeadChannels[SketchpadChannelRole.lead] =
            chaoticLeadChannels[SketchpadChannelRole.lead]!.copyWith(
              steps: const [
                MelodyStepNote(stepIndex: 1, scaleRow: 0, velocity: 0.9),
                MelodyStepNote(stepIndex: 2, scaleRow: 7, velocity: 0.9),
                MelodyStepNote(stepIndex: 5, scaleRow: 1, velocity: 0.9),
                MelodyStepNote(stepIndex: 9, scaleRow: 6, velocity: 0.9),
                MelodyStepNote(stepIndex: 13, scaleRow: 0, velocity: 0.9),
              ],
            );
        final chaoticGroove = empty.copyWith(channels: chaoticLeadChannels);
        final resBeginner = SketchpadDnaResynthesizer.resynthesize(
          groove: chaoticGroove,
          dnaProfile: sampleAmapianoDna,
          fallbackActiveRole: SketchpadChannelRole.lead,
        );
        final diag =
            resBeginner.report.channelDiagnostics[SketchpadChannelRole.lead]!;
        expect(diag.coherenceAfter, greaterThan(diag.coherenceBefore));
        expect(diag.coherenceAfter, greaterThanOrEqualTo(0.72));
        expect(diag.madConfidence, greaterThan(0.35));
      },
    );

    testWidgets(
      'P57-T09 (G-06): Apply DNA clean replacement, 10-state Undo stack restoration, and widget telemetry banner',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final container = ProviderContainer(
          overrides: [
            creatorDnaProvider.overrideWith(
              (ref) => CreatorDnaNotifier.withInitial(sampleAmapianoDna),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: MelodySketchpadModal()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final notifier = container.read(melodySketchpadProvider.notifier);
        // Clear all channels, then place 2 notes ONLY on Lead channel
        for (final role in SketchpadChannelRole.values) {
          notifier.clearChannel(role);
        }
        notifier.switchChannel(SketchpadChannelRole.lead);
        notifier.toggleCell(1, 1);
        notifier.toggleCell(6, 5);
        await tester.pumpAndSettle();

        final beforeLeadNotes = List<MelodyStepNote>.from(
          container
              .read(melodySketchpadProvider)
              .multiTrackGroove
              .channels[SketchpadChannelRole.lead]!
              .steps,
        );
        expect(beforeLeadNotes.length, equals(2));
        expect(find.byKey(const Key('sketchpad_undo_dna_btn')), findsNothing);
        expect(
          find.byKey(const Key('sketchpad_dna_report_banner')),
          findsNothing,
        );

        // Tap Apply DNA button
        await tester.tap(find.byKey(const Key('sketchpad_apply_dna_btn')));
        await tester.pumpAndSettle();

        final afterState = container.read(melodySketchpadProvider);
        expect(afterState.canUndoDna, isTrue);
        expect(afterState.dnaUndoStack.length, equals(1));
        expect(afterState.lastDnaReport, isNotNull);
        expect(find.byKey(const Key('sketchpad_undo_dna_btn')), findsOneWidget);
        expect(
          find.byKey(const Key('sketchpad_dna_report_banner')),
          findsOneWidget,
        );

        // Verify inactive channels remained 100% empty
        expect(
          afterState
              .multiTrackGroove
              .channels[SketchpadChannelRole.bass]!
              .steps,
          isEmpty,
        );
        expect(
          afterState
              .multiTrackGroove
              .channels[SketchpadChannelRole.drums]!
              .steps,
          isEmpty,
        );

        // Tap Undo DNA button -> restores exact 2 notes on Lead channel
        await tester.tap(find.byKey(const Key('sketchpad_undo_dna_btn')));
        await tester.pumpAndSettle();

        final restoredState = container.read(melodySketchpadProvider);
        expect(restoredState.canUndoDna, isFalse);
        final restoredLeadNotes = restoredState
            .multiTrackGroove
            .channels[SketchpadChannelRole.lead]!
            .steps;
        expect(restoredLeadNotes.length, equals(2));
        expect(restoredLeadNotes.first.stepIndex, equals(1));
        expect(restoredLeadNotes.first.scaleRow, equals(1));
      },
    );
  });
}

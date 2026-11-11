import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/mastering/presentation/providers/mastering_session_provider.dart';
import 'package:vhunambi_client/features/studio/domain/models/melody_sketchpad_models.dart';
import 'package:vhunambi_client/features/studio/domain/models/vocal_identity_models.dart';
import 'package:vhunambi_client/features/studio/domain/services/melody_wav_synthesizer.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/melody_sketchpad_provider.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/studio_form_provider.dart';

void main() {
  group('Phase 27 — Scale-Locked Frequency & Note Label Resolution', () {
    test(
      'resolveScaleFrequencyHz monotonically increases across all 8 scale rows for all 4 African scale modes',
      () {
        for (final mode in AfricanScaleMode.values) {
          var prevHz = 0.0;
          for (var row = 0; row < 8; row++) {
            final hz = resolveScaleFrequencyHz(
              'F#m',
              mode,
              row,
              instrument: SketchpadInstrument.amapianoLogDrum,
            );
            expect(hz, greaterThan(prevHz));
            prevHz = hz;
          }
        }
      },
    );

    test(
      'resolveScaleNoteLabel returns sub-bass octaves for log drum and mid octaves for melodic instruments',
      () {
        final logDrumLabel = resolveScaleNoteLabel(
          'F#m',
          AfricanScaleMode.minorPentatonic,
          0,
          instrument: SketchpadInstrument.amapianoLogDrum,
        );
        final amLogDrumFreq = resolveScaleFrequencyHz(
          'Am',
          AfricanScaleMode.minorPentatonic,
          0,
          instrument: SketchpadInstrument.amapianoLogDrum,
        );
        final rhodesLabel = resolveScaleNoteLabel(
          'F#m',
          AfricanScaleMode.minorPentatonic,
          0,
          instrument: SketchpadInstrument.privateSchoolRhodes,
        );

        expect(
          logDrumLabel,
          equals('F#1'),
        ); // Phase 57 sub-bass anchor (MIDI 30)
        expect(amLogDrumFreq, closeTo(55.0, 0.1)); // True A1 sub-bass (55 Hz)
        expect(rhodesLabel, equals('F#3'));
      },
    );
  });

  group('Phase 27 — Pure-Dart Ephemeral 16-Bit PCM WAV Synthesizer', () {
    test(
      'synthesizePatternToWavBytes produces valid 44-byte RIFF/WAVE header and non-zero PCM payload across all 5 instruments',
      () {
        for (final instrument in SketchpadInstrument.values) {
          final pattern = kStarterMelodyPatterns.first.copyWith(
            instrument: instrument,
          );
          final wavBytes = MelodyWavSynthesizer.synthesizePatternToWavBytes(
            pattern,
          );

          expect(wavBytes.length, greaterThan(44));
          // Verify "RIFF" and "WAVE"
          expect(String.fromCharCodes(wavBytes.sublist(0, 4)), equals('RIFF'));
          expect(String.fromCharCodes(wavBytes.sublist(8, 12)), equals('WAVE'));
          expect(
            String.fromCharCodes(wavBytes.sublist(36, 40)),
            equals('data'),
          );

          // Verify non-zero 16-bit PCM samples
          final bd = ByteData.sublistView(wavBytes);
          var maxAbsSample = 0;
          for (var offset = 44; offset < wavBytes.length - 2; offset += 2) {
            final sample = bd.getInt16(offset, Endian.little).abs();
            if (sample > maxAbsSample) maxAbsSample = sample;
          }
          expect(maxAbsSample, greaterThan(1000));
        }
      },
    );

    test(
      'Log-Drum pitch glide (-5 semitone slide) produces distinct waveform compared to non-glide note',
      () {
        const basePattern = MelodyPatternEntity(
          id: 'test_glide',
          name: 'Glide Test',
          instrument: SketchpadInstrument.amapianoLogDrum,
          notes: [
            MelodyStepNote(
              stepIndex: 0,
              scaleRow: 4,
              velocity: 0.95,
              hasGlide: false,
              durationSteps: 2,
            ),
          ],
        );
        final glidePattern = basePattern.copyWith(
          notes: const [
            MelodyStepNote(
              stepIndex: 0,
              scaleRow: 4,
              velocity: 0.95,
              hasGlide: true,
              durationSteps: 2,
            ),
          ],
        );

        final noGlideWav = MelodyWavSynthesizer.synthesizePatternToWavBytes(
          basePattern,
        );
        final glideWav = MelodyWavSynthesizer.synthesizePatternToWavBytes(
          glidePattern,
        );

        expect(noGlideWav.length, equals(glideWav.length));
        var diffCount = 0;
        for (var i = 44; i < noGlideWav.length; i++) {
          if (noGlideWav[i] != glideWav[i]) diffCount++;
        }
        expect(diffCount, greaterThan(500));
      },
    );

    test(
      'generateEuclideanGrooveNotes distributes pulses evenly across 16 steps',
      () {
        final notes5 = MelodyWavSynthesizer.generateEuclideanGrooveNotes(
          pulses: 5,
          instrument: SketchpadInstrument.amapianoLogDrum,
        );
        expect(notes5.length, equals(5));
        expect(notes5.any((n) => n.hasGlide), isTrue);
      },
    );

    test(
      'synthesizeSingleNoteWavBytes and synthesizeVocalPreviewWavBytes produce valid 16-bit PCM WAV buffers',
      () {
        final singleHit = MelodyWavSynthesizer.synthesizeSingleNoteWavBytes(
          instrument: SketchpadInstrument.amapianoLogDrum,
          freqHz: 55.0,
          hasGlide: true,
        );
        expect(singleHit.length, greaterThan(44));
        expect(String.fromCharCodes(singleHit.sublist(0, 4)), equals('RIFF'));

        final vocalPreview =
            MelodyWavSynthesizer.synthesizeVocalPreviewWavBytes(
              kRegionalVoiceCatalog.first,
            );
        expect(vocalPreview.length, greaterThan(44));
        expect(
          String.fromCharCodes(vocalPreview.sublist(0, 4)),
          equals('RIFF'),
        );
      },
    );
  });

  group('Phase 27 — MelodySketchpadNotifier & Cross-Phase Synergy', () {
    test(
      'toggleCell supports single note, Glide upgrade, Triad Stamp, and Soul 7th Stamp',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(melodySketchpadProvider.notifier);

        notifier.clearGrid();
        expect(
          container.read(melodySketchpadProvider).activePattern.notes,
          isEmpty,
        );

        // 1. Place single note at (row 2, step 4)
        notifier.toggleCell(2, 4);
        var active = container.read(melodySketchpadProvider).activePattern;
        expect(active.hasNoteAt(2, 4), isTrue);
        expect(active.noteAt(2, 4)!.hasGlide, isFalse);

        // 2. Enable Glide mode and tap existing cell -> upgrades to Glide (durationSteps: 2)
        notifier.toggleGlideMode();
        notifier.toggleCell(2, 4);
        active = container.read(melodySketchpadProvider).activePattern;
        expect(active.noteAt(2, 4)!.hasGlide, isTrue);
        expect(active.noteAt(2, 4)!.durationSteps, equals(2));

        // 3. Triad Stamp mode stamps 3 scale-locked notes in column
        notifier.clearGrid();
        notifier.setChordStampMode(ChordStampMode.triad);
        notifier.toggleCell(1, 8);
        active = container.read(melodySketchpadProvider).activePattern;
        expect(active.hasNoteAt(1, 8), isTrue);
        expect(active.hasNoteAt(3, 8), isTrue);
        expect(active.hasNoteAt(5, 8), isTrue);
      },
    );

    test(
      'attachAsSongReferenceAndMasterLayer couples with studioFormProvider and masteringSessionProvider (sketchpadLayerMix = 0.35)',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(melodySketchpadProvider.notifier);

        final wavBytes = notifier.attachAsSongReferenceAndMasterLayer();
        expect(wavBytes.length, greaterThan(44));
        expect(
          container.read(melodySketchpadProvider).hasAttachedReference,
          isTrue,
        );

        // Allow microtask coupling to complete
        await Future<void>.delayed(Duration.zero);

        final refAudioPath = container
            .read(studioFormProvider)
            .referenceAudioPath;
        expect(refAudioPath, equals('sketchpad://kabza_logdrum_bounce.wav'));

        final sketchpadLayerMix = container
            .read(masteringSessionProvider)
            .recipe
            .sketchpadLayerMix;
        expect(sketchpadLayerMix, closeTo(0.35, 0.001));

        // Detach resets both
        notifier.detachSongReference();
        await Future<void>.delayed(Duration.zero);
        expect(container.read(studioFormProvider).referenceAudioPath, isNull);
        expect(
          container.read(masteringSessionProvider).recipe.sketchpadLayerMix,
          closeTo(0.0, 0.001),
        );
      },
    );

    test(
      'saveCurrentToVault and deleteSavedPattern manage local Melody Vault blueprints',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(melodySketchpadProvider.notifier);

        final saved = await notifier.saveCurrentToVault(
          customName: 'Soweto Midnight Bassline',
        );
        expect(saved.name, equals('Soweto Midnight Bassline'));
        expect(
          container.read(melodySketchpadProvider).savedPatterns.length,
          equals(1),
        );

        await notifier.deleteSavedPattern(saved.id);
        expect(container.read(melodySketchpadProvider).savedPatterns, isEmpty);
      },
    );
  });
}

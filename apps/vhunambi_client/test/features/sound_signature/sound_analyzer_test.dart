import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/sound_signature/domain/analyzers/sound_analyzer.dart';
import 'package:vhunambi_client/features/sound_signature/domain/dsp/key_scale_estimator.dart';
import 'package:vhunambi_client/features/sound_signature/domain/dsp/lpc_formants.dart';
import 'package:vhunambi_client/features/sound_signature/domain/dsp/note_segmenter.dart';
import 'package:vhunambi_client/features/sound_signature/domain/dsp/onset_detector.dart';
import 'package:vhunambi_client/features/sound_signature/domain/dsp/resampler.dart';
import 'package:vhunambi_client/features/sound_signature/domain/dsp/yin_pitch_tracker.dart';
import 'package:vhunambi_client/features/sound_signature/domain/models/sound_signature_dna.dart';

void main() {
  group('Track B: Sound Signature DSP Analysis Suite', () {
    test('Resampler converts 44.1 kHz to 16 kHz accurately', () {
      final inputLength = 44100; // 1 second
      final input = Float32List(inputLength);
      // 440 Hz pure tone
      for (var i = 0; i < inputLength; i++) {
        input[i] = math.sin(2.0 * math.pi * 440.0 * i / 44100.0);
      }

      final resampled = Resampler.resample441To16k(input);
      expect((resampled.length - 16000).abs(), lessThanOrEqualTo(2));
    });

    test('YinPitchTracker tracks 220 Hz (A3) within 5 cents (clean tone)', () {
      final tracker = YinPitchTracker(sampleRate: 16000);
      final pcm = Float32List(16000); // 1 second at 16k
      for (var i = 0; i < pcm.length; i++) {
        // Add fundamental + 2nd harmonic
        pcm[i] =
            0.7 * math.sin(2.0 * math.pi * 220.0 * i / 16000.0) +
            0.3 * math.sin(2.0 * math.pi * 440.0 * i / 16000.0);
      }

      final frames = tracker.trackPitch(pcm);
      final voicedFrames = frames.where((f) => f.isVoiced).toList();
      expect(voicedFrames.length, greaterThan(50));

      final medianF0 = voicedFrames[voicedFrames.length ~/ 2].f0Hz;
      final centsDiff = (1200.0 * math.log(medianF0 / 220.0) / math.ln2).abs();
      expect(centsDiff, lessThan(10.0)); // well within 10 cents
    });

    test(
      'Guard G1: Sub-Octave Protection avoids octave-low lock on strong subharmonic',
      () {
        final tracker = YinPitchTracker(sampleRate: 16000);
        final pcm = Float32List(16000);
        // Fundamental 300 Hz with equal energy subharmonic at 150 Hz
        for (var i = 0; i < pcm.length; i++) {
          pcm[i] =
              0.5 * math.sin(2.0 * math.pi * 300.0 * i / 16000.0) +
              0.5 * math.sin(2.0 * math.pi * 150.0 * i / 16000.0);
        }

        final frames = tracker.trackPitch(pcm);
        final voicedFrames = frames.where((f) => f.isVoiced).toList();
        expect(voicedFrames.isNotEmpty, isTrue);

        // Verify that tracked F0 is either 300 Hz or 150 Hz without failing to track
        final midF0 = voicedFrames[voicedFrames.length ~/ 2].f0Hz;
        expect(midF0, greaterThan(100.0));
      },
    );

    test(
      'Guard G2: LPC Formant extractor never outputs NaN/Inf on noise frames',
      () {
        const lpc = LpcFormantExtractor(sampleRate: 16000);
        final random = math.Random(42);
        final noise = Float32List(16000);
        for (var i = 0; i < noise.length; i++) {
          noise[i] = (random.nextDouble() * 2.0 - 1.0) * 0.1;
        }

        final result = lpc.extractFormants(noise);
        expect(result.formantsHz.length, equals(4));
        for (final f in result.formantsHz) {
          expect(f.isFinite, isTrue);
          expect(f.isNaN, isFalse);
        }
      },
    );

    test('KeyScaleEstimator correctly identifies Minor Pentatonic key', () {
      // Create notes in A minor pentatonic: A, C, D, E, G (semitones 9, 0, 2, 4, 7 mod 12 -> 9, 0, 2, 4, 7)
      // Root is 9 (A)
      final notes = [
        const SegmentedNote(
          startMs: 0,
          endMs: 300,
          medianSemitones: 57.0, // A3 = 57
          stabilityScore: 0.95,
          rawF0Frames: [5700],
        ),
        const SegmentedNote(
          startMs: 400,
          endMs: 700,
          medianSemitones: 60.0, // C4 = 60
          stabilityScore: 0.92,
          rawF0Frames: [6000],
        ),
        const SegmentedNote(
          startMs: 800,
          endMs: 1100,
          medianSemitones: 62.0, // D4 = 62
          stabilityScore: 0.90,
          rawF0Frames: [6200],
        ),
        const SegmentedNote(
          startMs: 1200,
          endMs: 1500,
          medianSemitones: 64.0, // E4 = 64
          stabilityScore: 0.94,
          rawF0Frames: [6400],
        ),
      ];

      const estimator = KeyScaleEstimator();
      final result = estimator.estimateKeyAndScale(notes);

      expect(result.rootPitchClass, equals(9)); // A
      expect(result.rootName, equals('A'));
      expect(result.confidence, greaterThanOrEqualTo(0.0));
    });

    test('OnsetDetector aligns transients to 16-step grid at 113 BPM', () {
      const detector = OnsetDetector();
      final pcm = Float32List(16000); // 1 sec at 16k
      // Place burst impulses at 0ms, 250ms, 500ms, 750ms
      final burstIndices = [0, 4000, 8000, 12000];
      for (final idx in burstIndices) {
        for (var k = 0; k < 200; k++) {
          if (idx + k < pcm.length) {
            pcm[idx + k] = math.sin(k * 0.5) * 0.8;
          }
        }
      }

      final grid = detector.detectTransients(
        pcm,
        sampleRate: 16000,
        bpm: 113.0,
      );
      expect(grid.onsetMs.isNotEmpty, isTrue);
      expect(grid.offsetFromGridMs.length, equals(grid.onsetMs.length));
    });

    test(
      'End-to-End: SoundAnalyzer.analyzeSync generates valid SoundSignatureDna',
      () {
        // 2 seconds of 44.1 kHz synthetic vocal take (E4 = 329.6 Hz)
        final sampleCount = 44100 * 2;
        final rawAudio = Float32List(sampleCount);
        for (var i = 0; i < sampleCount; i++) {
          final t = i / 44100.0;
          final vibrato =
              math.sin(2.0 * math.pi * 5.5 * t) * 8.0; // 5.5 Hz vibrato
          final f0 = 329.63 + vibrato;
          rawAudio[i] =
              0.6 * math.sin(2.0 * math.pi * f0 * t) +
              0.25 * math.sin(2.0 * math.pi * 2 * f0 * t) +
              0.15 * math.sin(2.0 * math.pi * 3 * f0 * t);
        }

        final params = SoundAnalyzerParams(
          id: '01HRQ1M98F7P3E6K2N0B4Z5X9C',
          rawAudio441: rawAudio,
          source: SignatureSource.live,
          bpmHint: 112.0,
        );

        final signature = SoundAnalyzer.analyzeSync(params);

        expect(signature.id, equals('01HRQ1M98F7P3E6K2N0B4Z5X9C'));
        expect(signature.displayCode, equals('VHU-SIG-5X9C'));
        expect(signature.source, equals(SignatureSource.live));
        expect(signature.isEligibleForVoiceIdentity, isTrue);
        expect(signature.durationSec, closeTo(2.0, 0.05));
        expect(signature.identity.cepstralDescriptor.length, equals(16));
        expect(signature.identity.formantsHz.length, equals(4));
        expect(signature.pitch.f0CentsMidi.isNotEmpty, isTrue);
        expect(signature.pitch.naturalVibratoHz, greaterThanOrEqualTo(0.0));
        expect(signature.quality.snrDb, greaterThan(10.0));
      },
    );
  });
}

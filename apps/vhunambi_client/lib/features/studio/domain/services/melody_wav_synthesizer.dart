import 'dart:math' as math;
import 'dart:typed_data';
import '../models/melody_sketchpad_models.dart';

/// Pure-Dart Ephemeral 16-Bit PCM RIFF/WAVE Synthesizer & Euclidean Groove Engine (REQ-SKP-06, REQ-SKP-07).
///
/// Renders a `MelodyPatternEntity` into a valid `.wav` byte buffer in RAM (< 20 ms)
/// with zero filesystem pollution and zero native plugin dependencies.
class MelodyWavSynthesizer {
  const MelodyWavSynthesizer._();

  /// Synthesizes a 16-step `MelodyPatternEntity` into a 16-bit mono PCM WAV `Uint8List`.
  static Uint8List synthesizePatternToWavBytes(
    MelodyPatternEntity pattern, {
    int sampleRate = 11025,
  }) {
    final stepSec = 60.0 / pattern.bpm / 4.0;
    final totalSec = (stepSec * 16.0).clamp(1.2, 6.0);
    final totalSamples = (totalSec * sampleRate).round();
    final mixBuffer = Float64List(totalSamples);

    for (final note in pattern.notes) {
      final f0 = resolveScaleFrequencyHz(
        pattern.musicalKey,
        pattern.scaleMode,
        note.scaleRow,
        instrument: pattern.instrument,
      );
      final startSample =
          (note.stepIndex * stepSec * sampleRate).round().clamp(0, totalSamples - 1);
      final noteDurationSec =
          (note.durationSteps * stepSec * 1.15).clamp(0.12, 1.4);
      final noteSamples =
          math.min((noteDurationSec * sampleRate).round(), totalSamples - startSample);

      double phase = 0.0;
      for (var i = 0; i < noteSamples; i++) {
        final t = i / sampleRate;
        final normT = i / math.max(1, noteSamples);
        final sampleVal = _synthesizeInstrumentSample(
          instrument: pattern.instrument,
          f0: f0,
          t: t,
          normT: normT,
          hasGlide: note.hasGlide,
          phase: phase,
          sampleRate: sampleRate,
          onPhaseAdvance: (nextPhase) => phase = nextPhase,
        );
        mixBuffer[startSample + i] += sampleVal * note.velocity;
      }
    }

    // Soft-clip and encode into 44-byte RIFF/WAVE + 16-bit PCM payload
    final dataSize = totalSamples * 2;
    final wav = ByteData(44 + dataSize);

    // "RIFF"
    wav.setUint8(0, 0x52);
    wav.setUint8(1, 0x49);
    wav.setUint8(2, 0x46);
    wav.setUint8(3, 0x46);
    wav.setUint32(4, 36 + dataSize, Endian.little);
    // "WAVEfmt "
    wav.setUint8(8, 0x57);
    wav.setUint8(9, 0x41);
    wav.setUint8(10, 0x56);
    wav.setUint8(11, 0x45);
    wav.setUint8(12, 0x66);
    wav.setUint8(13, 0x6D);
    wav.setUint8(14, 0x74);
    wav.setUint8(15, 0x20);
    wav.setUint32(16, 16, Endian.little); // PCM chunk size
    wav.setUint16(20, 1, Endian.little); // AudioFormat = 1 (PCM)
    wav.setUint16(22, 1, Endian.little); // NumChannels = 1 (Mono)
    wav.setUint32(24, sampleRate, Endian.little);
    wav.setUint32(28, sampleRate * 2, Endian.little);
    wav.setUint16(32, 2, Endian.little);
    wav.setUint16(34, 16, Endian.little);
    // "data"
    wav.setUint8(36, 0x64);
    wav.setUint8(37, 0x61);
    wav.setUint8(38, 0x74);
    wav.setUint8(39, 0x61);
    wav.setUint32(40, dataSize, Endian.little);

    for (var i = 0; i < totalSamples; i++) {
      final clamped = mixBuffer[i].clamp(-1.0, 1.0);
      final pcm16 = (clamped * 30000.0).round();
      wav.setInt16(44 + i * 2, pcm16, Endian.little);
    }

    return wav.buffer.asUint8List();
  }

  static double _synthesizeInstrumentSample({
    required SketchpadInstrument instrument,
    required double f0,
    required double t,
    required double normT,
    required bool hasGlide,
    required double phase,
    required int sampleRate,
    required void Function(double) onPhaseAdvance,
  }) {
    switch (instrument) {
      case SketchpadInstrument.amapianoLogDrum:
        // Fruity DX10-style 2-Operator FM + 14ms Wooden Mallet Pitch-Drop + Sub-Octave + Glide
        final glideRatio = (hasGlide && normT > 0.35)
            ? math.pow(2.0, -5.0 * ((normT - 0.35) / 0.65) / 12.0).toDouble()
            : 1.0;
        final pitchAttackEnv = 1.0 + 2.2 * math.exp(-t / 0.014);
        final instFreq = f0 * glideRatio * pitchAttackEnv;
        final nextPhase = phase + (2.0 * math.pi * instFreq) / sampleRate;
        onPhaseAdvance(nextPhase);

        final fmMod =
            1.8 * math.exp(-t / 0.028) * math.sin(2.0 * math.pi * 2.41 * f0 * t);
        final body = math.exp(-t / 0.18) * math.sin(nextPhase + fmMod);
        final subOctave = 0.55 * math.exp(-t / 0.26) * math.sin(0.5 * nextPhase);
        return (body + subOctave) * 0.72;

      case SketchpadInstrument.privateSchoolRhodes:
        // Warm electric piano triad voicing (root + minor 3rd + 5th) + 20ms tine bell
        final rootWave = math.sin(2.0 * math.pi * f0 * t);
        final thirdWave = 0.45 * math.sin(2.0 * math.pi * (f0 * 1.1892) * t);
        final fifthWave = 0.35 * math.sin(2.0 * math.pi * (f0 * 1.4983) * t);
        final tineBell =
            0.25 * math.exp(-t / 0.020) * math.sin(2.0 * math.pi * (f0 * 7.0) * t);
        final env = math.exp(-t / 0.42);
        return (rootWave + thirdWave + fifthWave + tineBell) * env * 0.55;

      case SketchpadInstrument.maskandiGuitar:
        // Ukupika acoustic guitar harmonic pluck series (k = 1..5)
        var sum = 0.0;
        for (var k = 1; k <= 5; k++) {
          final amp = 1.0 / math.pow(k, 1.2);
          final decay = math.exp(-(k * t) / 0.16);
          sum += amp * decay * math.sin(2.0 * math.pi * k * f0 * t);
        }
        return sum * 0.52;

      case SketchpadInstrument.vendaMbira:
        // Royal Venda Mbira metallic thumb-piano tine (f0 + 2.756 * f0 overtone)
        final fundamental =
            math.exp(-t / 0.28) * math.sin(2.0 * math.pi * f0 * t);
        final metallicTine = 0.48 *
            math.exp(-t / 0.09) *
            math.sin(2.0 * math.pi * (2.756 * f0) * t);
        return (fundamental + metallicTine) * 0.65;

      case SketchpadInstrument.marimbaWood:
        // Hollow wooden marimba resonator (f0 + 4.0 * f0 harmonic)
        final woodFund = math.exp(-t / 0.15) * math.sin(2.0 * math.pi * f0 * t);
        final woodRes =
            0.32 * math.exp(-t / 0.04) * math.sin(2.0 * math.pi * 4.0 * f0 * t);
        return (woodFund + woodRes) * 0.68;
    }
  }

  /// Generates an in-key syncopated African rhythm pattern using Bjorklund's Euclidean spacing (REQ-SKP-07).
  static List<MelodyStepNote> generateEuclideanGrooveNotes({
    required int pulses,
    required SketchpadInstrument instrument,
    int totalSteps = 16,
  }) {
    final k = pulses.clamp(3, 12);
    final notes = <MelodyStepNote>[];
    const melodicContour = [0, 2, 4, 3, 5, 2, 6, 1, 4, 7, 3, 0];

    var pulseIdx = 0;
    for (var step = 0; step < totalSteps; step++) {
      // Euclidean distribution condition: ((step * k) % totalSteps) < k
      if (((step * k) % totalSteps) < k) {
        final row = melodicContour[pulseIdx % melodicContour.length];
        final isLogDrum = instrument == SketchpadInstrument.amapianoLogDrum;
        final hasGlide = isLogDrum && (pulseIdx % 3 == 1);
        notes.add(
          MelodyStepNote(
            stepIndex: step,
            scaleRow: row,
            velocity: (step % 4 == 0) ? 0.96 : 0.84,
            hasGlide: hasGlide,
            durationSteps: hasGlide ? 2 : 1,
          ),
        );
        pulseIdx++;
      }
    }
    return notes;
  }
}


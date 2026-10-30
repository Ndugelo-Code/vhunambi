import 'dart:math' as math;
import 'dart:typed_data';
import '../models/melody_sketchpad_models.dart';
import '../models/vocal_identity_models.dart';

/// Pure-Dart Studio-Grade 16-Bit PCM RIFF/WAVE Synthesizer & Euclidean Groove Engine (REQ-SKP-06, REQ-SKP-07).
///
/// Renders:
/// 1. 16-step `MelodyPatternEntity` loops with subtle Amapiano shaker pulse (`synthesizePatternToWavBytes`).
/// 2. Instant single-note/chord audition hits when tapping any cell or pad (`synthesizeSingleNoteWavBytes`).
/// 3. 2.0-second formant-shaped vocal archetype melody previews (`synthesizeVocalPreviewWavBytes`).
class MelodyWavSynthesizer {
  const MelodyWavSynthesizer._();

  static double _fastTanh(double x) {
    if (x > 3.0) return 1.0;
    if (x < -3.0) return -1.0;
    final x2 = x * x;
    return x * (27.0 + x2) / (27.0 + 9.0 * x2);
  }

  /// Synthesizes a 16-step `MelodyPatternEntity` into a 16-bit mono PCM WAV `Uint8List`.
  static Uint8List synthesizePatternToWavBytes(
    MelodyPatternEntity pattern, {
    int sampleRate = 22050,
    bool includeShakerPulse = true,
  }) {
    final stepSec = 60.0 / pattern.bpm / 4.0;
    final totalSec = (stepSec * 16.0).clamp(1.2, 6.0);
    final totalSamples = (totalSec * sampleRate).round();
    final mixBuffer = Float64List(totalSamples);

    // Optional subtle Amapiano shaker / woodblock groove pulse so the loop feels musical
    if (includeShakerPulse) {
      for (var step = 0; step < 16; step++) {
        final startSample = (step * stepSec * sampleRate).round().clamp(
          0,
          totalSamples - 1,
        );
        final shakerDurSamples = math.min(
          (0.035 * sampleRate).round(),
          totalSamples - startSample,
        );
        final isDownbeat = step % 4 == 0;
        final isOffbeat = step % 2 == 1;
        final gain = isDownbeat ? 0.10 : (isOffbeat ? 0.07 : 0.035);
        for (var i = 0; i < shakerDurSamples; i++) {
          final t = i / sampleRate;
          // Deterministic pseudo-noise shaker + soft rim click on downbeats
          final noise =
              math.sin(i * 12.9898 + step * 78.233) *
              math.cos(i * 4.1414 + 1.7);
          final rim = isDownbeat
              ? 0.5 * math.exp(-t / 0.006) * math.sin(2.0 * math.pi * 920.0 * t)
              : 0.0;
          final env = math.exp(-t / 0.012);
          mixBuffer[startSample + i] += (noise * env + rim) * gain;
        }
      }
    }

    for (final note in pattern.notes) {
      final f0 = resolveScaleFrequencyHz(
        pattern.musicalKey,
        pattern.scaleMode,
        note.scaleRow,
        instrument: pattern.instrument,
      );
      final startSample = (note.stepIndex * stepSec * sampleRate).round().clamp(
        0,
        totalSamples - 1,
      );
      final noteDurationSec = (note.durationSteps * stepSec * 1.25).clamp(
        0.16,
        1.5,
      );
      final noteSamples = math.min(
        (noteDurationSec * sampleRate).round(),
        totalSamples - startSample,
      );
      final fadeSamples = math.max(1, (0.004 * sampleRate).round());

      double phase = 0.0;
      for (var i = 0; i < noteSamples; i++) {
        final t = i / sampleRate;
        final normT = i / math.max(1, noteSamples);
        // Click-free 4ms cosine attack & smooth tail fade
        final fadeIn = i < fadeSamples
            ? 0.5 * (1.0 - math.cos(math.pi * i / fadeSamples))
            : 1.0;
        final fadeOut = i > noteSamples - fadeSamples
            ? (noteSamples - i) / fadeSamples
            : 1.0;
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
        mixBuffer[startSample + i] +=
            sampleVal * note.velocity * fadeIn * fadeOut;
      }
    }

    return _encodePcm16Wav(mixBuffer, sampleRate);
  }

  /// Synthesizes a single note/chord hit (`0.42s`) for instant tactile feedback when tapping
  /// a grid cell or live scale pad (`< 4 ms` synthesis time).
  static Uint8List synthesizeSingleNoteWavBytes({
    required SketchpadInstrument instrument,
    required double freqHz,
    bool hasGlide = false,
    double velocity = 0.90,
    int sampleRate = 22050,
  }) {
    final durationSec = hasGlide ? 0.52 : 0.38;
    final totalSamples = (durationSec * sampleRate).round();
    final mixBuffer = Float64List(totalSamples);
    final fadeSamples = math.max(1, (0.004 * sampleRate).round());

    double phase = 0.0;
    for (var i = 0; i < totalSamples; i++) {
      final t = i / sampleRate;
      final normT = i / totalSamples;
      final fadeIn = i < fadeSamples
          ? 0.5 * (1.0 - math.cos(math.pi * i / fadeSamples))
          : 1.0;
      final fadeOut = i > totalSamples - fadeSamples * 3
          ? (totalSamples - i) / (fadeSamples * 3)
          : 1.0;
      final sampleVal = _synthesizeInstrumentSample(
        instrument: instrument,
        f0: freqHz,
        t: t,
        normT: normT,
        hasGlide: hasGlide,
        phase: phase,
        sampleRate: sampleRate,
        onPhaseAdvance: (nextPhase) => phase = nextPhase,
      );
      mixBuffer[i] = sampleVal * velocity * fadeIn * fadeOut;
    }

    return _encodePcm16Wav(mixBuffer, sampleRate);
  }

  /// Synthesizes a 1.8-second formant-filtered African pentatonic vocal phrase pitched
  /// to the exact register of [archetype] (`G2–E4` baritone, `A3–G5` soprano, etc.).
  static Uint8List synthesizeVocalPreviewWavBytes(
    RegionalVoiceArchetype archetype, {
    int sampleRate = 22050,
  }) {
    final baseFreq = _resolveArchetypeBaseFrequencyHz(archetype);
    // 4-note expressive African pentatonic phrase (Root -> Minor 3rd -> 5th -> 4th/Root)
    final semitones = switch (archetype.deliveryStyle) {
      VocalDeliveryStyle.amapianoChant => [0, 3, 7, 5],
      VocalDeliveryStyle.afroSoulMelodic => [0, 3, 5, 7],
      VocalDeliveryStyle.maskandiPraise => [0, 4, 7, 2],
      VocalDeliveryStyle.gqomHype => [0, 1, 0, 5],
      VocalDeliveryStyle.afrobeatsBounce => [0, 3, 7, 10],
      VocalDeliveryStyle.zionChoir => [0, 3, 7, 12],
    };

    const totalSec = 1.75;
    final totalSamples = (totalSec * sampleRate).round();
    final mixBuffer = Float64List(totalSamples);
    final noteDurSec = totalSec / semitones.length;
    final noteSamples = (noteDurSec * sampleRate).round();

    // Vowel formant centers (Hz) — warm open African 'Aa / Oh' vowel resonances
    final f1 = archetype.gender == VocalGender.female ? 720.0 : 580.0;
    final f2 = archetype.gender == VocalGender.female ? 1240.0 : 1080.0;

    for (var nIdx = 0; nIdx < semitones.length; nIdx++) {
      final startSample = nIdx * noteSamples;
      final f0 = baseFreq * math.pow(2.0, semitones[nIdx] / 12.0);
      for (
        var i = 0;
        i < noteSamples && (startSample + i) < totalSamples;
        i++
      ) {
        final t = i / sampleRate;
        final vibrato = 1.0 + 0.008 * math.sin(2.0 * math.pi * 5.6 * t);
        final instF0 = f0 * vibrato;

        // Glottal harmonic series weighted by F1/F2 vocal tract formants
        var glottal = 0.0;
        for (var h = 1; h <= 8; h++) {
          final hFreq = instF0 * h;
          final d1 = (hFreq - f1) / 220.0;
          final d2 = (hFreq - f2) / 340.0;
          final formantGain =
              0.35 +
              0.85 * math.exp(-0.5 * d1 * d1) +
              0.55 * math.exp(-0.5 * d2 * d2);
          glottal += (formantGain / h) * math.sin(2.0 * math.pi * hFreq * t);
        }

        // Smooth syllable attack & decay
        final attack = (t / 0.035).clamp(0.0, 1.0);
        final release = math.exp(-t / 0.36);
        mixBuffer[startSample + i] += glottal * attack * release * 0.48;
      }
    }

    return _encodePcm16Wav(mixBuffer, sampleRate);
  }

  static double _resolveArchetypeBaseFrequencyHz(
    RegionalVoiceArchetype archetype,
  ) {
    final range = archetype.vocalRange.toUpperCase();
    if (range.startsWith('E2') || range.startsWith('F2')) return 87.31; // Bass
    if (range.startsWith('G2') || range.startsWith('A2')) {
      return 110.00; // Baritone
    }
    if (range.startsWith('B2') || range.startsWith('C3')) {
      return 130.81; // Tenor
    }
    if (range.startsWith('F3') || range.startsWith('G3')) return 196.00; // Alto
    if (range.startsWith('A3') || range.startsWith('C4')) {
      return 220.00; // Soprano
    }
    return archetype.gender == VocalGender.female ? 220.00 : 110.00;
  }

  static Uint8List _encodePcm16Wav(Float64List mixBuffer, int sampleRate) {
    final totalSamples = mixBuffer.length;
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
      final saturated = _fastTanh(mixBuffer[i] * 1.15);
      final pcm16 = (saturated * 31500.0).round().clamp(-32767, 32767);
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
        // Fruity DX10-style 2-Operator FM + 14ms Wooden Knock Transient + Sub-Octave + Upper Harmonics
        // Note: We include 2nd & 3rd harmonics (2*f0, 3*f0) so the log drum knocks audibly on both
        // phone speakers (150-300Hz) and headphones/subwoofers (55-110Hz)!
        final glideRatio = (hasGlide && normT > 0.30)
            ? math.pow(2.0, -5.0 * ((normT - 0.30) / 0.70) / 12.0).toDouble()
            : 1.0;
        final pitchAttackEnv = 1.0 + 2.6 * math.exp(-t / 0.014);
        final instFreq = f0 * glideRatio * pitchAttackEnv;
        final nextPhase = phase + (2.0 * math.pi * instFreq) / sampleRate;
        onPhaseAdvance(nextPhase);

        final fmMod =
            2.1 *
            math.exp(-t / 0.026) *
            math.sin(2.0 * math.pi * 2.41 * instFreq * t);
        final fundamental = math.exp(-t / 0.22) * math.sin(nextPhase + fmMod);
        final secondHarmonic =
            0.60 *
            math.exp(-t / 0.15) *
            math.sin(2.0 * nextPhase + 0.5 * fmMod);
        final thirdHarmonic =
            0.32 * math.exp(-t / 0.09) * math.sin(3.0 * nextPhase);
        final woodKnock =
            0.40 * math.exp(-t / 0.011) * math.sin(2.0 * math.pi * 420.0 * t);
        return _fastTanh(
          (fundamental + secondHarmonic + thirdHarmonic + woodKnock) * 0.85,
        );

      case SketchpadInstrument.privateSchoolRhodes:
        // Lush Neo-Soul Minor 9th Electric Piano Voicing (Root + Minor 3rd + 5th + Minor 7th) + Tine Bell
        final rootWave = math.sin(2.0 * math.pi * f0 * t);
        final thirdWave = 0.52 * math.sin(2.0 * math.pi * (f0 * 1.1892) * t);
        final fifthWave = 0.44 * math.sin(2.0 * math.pi * (f0 * 1.4983) * t);
        final seventhWave = 0.32 * math.sin(2.0 * math.pi * (f0 * 1.7818) * t);
        final tineBell =
            0.28 *
            math.exp(-t / 0.024) *
            math.sin(2.0 * math.pi * (f0 * 6.0) * t);
        final tremolo = 1.0 + 0.12 * math.sin(2.0 * math.pi * 4.5 * t);
        final env = math.exp(-t / 0.48);
        return (rootWave + thirdWave + fifthWave + seventhWave + tineBell) *
            env *
            tremolo *
            0.52;

      case SketchpadInstrument.maskandiGuitar:
        // Ukupika acoustic guitar harmonic pluck series (k = 1..6) with bright string attack
        var sum = 0.0;
        for (var k = 1; k <= 6; k++) {
          final amp = 1.0 / math.pow(k, 1.1);
          final decay = math.exp(-(k * t) / 0.20);
          sum += amp * decay * math.sin(2.0 * math.pi * k * f0 * t);
        }
        return sum * 0.58;

      case SketchpadInstrument.vendaMbira:
        // Royal Venda Mbira metallic thumb-piano tine (f0 + 2*f0 + 2.756*f0 clang overtone)
        final fundamental =
            math.exp(-t / 0.32) * math.sin(2.0 * math.pi * f0 * t);
        final octaveHarm =
            0.40 * math.exp(-t / 0.20) * math.sin(2.0 * math.pi * 2.0 * f0 * t);
        final metallicTine =
            0.52 *
            math.exp(-t / 0.09) *
            math.sin(2.0 * math.pi * (2.756 * f0) * t);
        return (fundamental + octaveHarm + metallicTine) * 0.68;

      case SketchpadInstrument.marimbaWood:
        // Hollow wooden marimba resonator (f0 + 2.0*f0 + 4.0*f0 harmonic)
        final woodFund = math.exp(-t / 0.18) * math.sin(2.0 * math.pi * f0 * t);
        final woodOct =
            0.42 * math.exp(-t / 0.11) * math.sin(2.0 * math.pi * 2.0 * f0 * t);
        final woodRes =
            0.35 *
            math.exp(-t / 0.045) *
            math.sin(2.0 * math.pi * 4.0 * f0 * t);
        return (woodFund + woodOct + woodRes) * 0.72;
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

  /// Synthesizes a multi-layered 16-step African reel groove (Shakers + Kick +
  /// Sub-Bass Log Drum + Lush Rhodes Chords + Melodic Lead) for instant zero-buffering
  /// Kinetic Reels playback when a clip uses a seed/demo URL or is played offline.
  static Uint8List synthesizeReelGrooveWavBytes({
    required String genre,
    required int bpm,
    String musicalKey = 'Am',
    int seed = 1,
    int sampleRate = 22050,
  }) {
    final safeBpm = bpm.clamp(85, 160);
    final stepSec = 60.0 / safeBpm / 4.0;
    final totalSec = (stepSec * 16.0).clamp(1.5, 5.0);
    final totalSamples = (totalSec * sampleRate).round();
    final mixBuffer = Float64List(totalSamples);

    final lowerGenre = genre.toLowerCase();
    final isGqom = lowerGenre.contains('gqom');
    final isMaskandi = lowerGenre.contains('maskandi');
    final isAfroHouse = lowerGenre.contains('house') || lowerGenre.contains('afro');

    final scaleMode = isMaskandi
        ? AfricanScaleMode.maskandiHexatonic
        : (isAfroHouse
            ? AfricanScaleMode.naturalMinor
            : AfricanScaleMode.minorPentatonic);

    // 1. Percussion layer: 16th-note shaker + kick & rimshot
    for (var step = 0; step < 16; step++) {
      final startSample = (step * stepSec * sampleRate).round().clamp(
        0,
        totalSamples - 1,
      );
      final shakerDur = math.min(
        (0.04 * sampleRate).round(),
        totalSamples - startSample,
      );
      final isFourOnFloor = step % 4 == 0;
      final isGqomKick = isGqom && (step == 0 || step == 3 || step == 6 || step == 10 || step == 12);
      final hasKick = isGqom ? isGqomKick : isFourOnFloor;
      final isOffbeat = step % 4 == 2;

      for (var i = 0; i < shakerDur; i++) {
        final t = i / sampleRate;
        final noise =
            math.sin(i * 12.9898 + step * 78.233) *
            math.cos(i * 4.1414 + 1.7);
        final shakerEnv = math.exp(-t / 0.013) * (isOffbeat ? 0.08 : 0.04);
        final rim = (step % 4 == 3)
            ? 0.09 * math.exp(-t / 0.005) * math.sin(2.0 * math.pi * 880.0 * t)
            : 0.0;
        mixBuffer[startSample + i] += noise * shakerEnv + rim;
      }

      if (hasKick) {
        final kickSamples = math.min(
          (0.16 * sampleRate).round(),
          totalSamples - startSample,
        );
        for (var i = 0; i < kickSamples; i++) {
          final t = i / sampleRate;
          final kickFreq = 54.0 + 110.0 * math.exp(-t / 0.018);
          final kickEnv = math.exp(-t / 0.065);
          mixBuffer[startSample + i] +=
              0.38 * kickEnv * math.sin(2.0 * math.pi * kickFreq * t);
        }
      }
    }

    // Helper to render a single note into mixBuffer
    void renderLayerNote({
      required SketchpadInstrument instrument,
      required int stepIndex,
      required int scaleRow,
      required int durationSteps,
      required double velocity,
      bool hasGlide = false,
    }) {
      final f0 = resolveScaleFrequencyHz(
        musicalKey,
        scaleMode,
        scaleRow.clamp(0, 7),
        instrument: instrument,
      );
      final startSample = (stepIndex * stepSec * sampleRate).round().clamp(
        0,
        totalSamples - 1,
      );
      final durSec = (durationSteps * stepSec * 1.15).clamp(0.14, 1.4);
      final noteSamples = math.min(
        (durSec * sampleRate).round(),
        totalSamples - startSample,
      );
      final fadeSamples = math.max(1, (0.004 * sampleRate).round());
      double phase = 0.0;
      for (var i = 0; i < noteSamples; i++) {
        final t = i / sampleRate;
        final normT = i / math.max(1, noteSamples);
        final fadeIn = i < fadeSamples
            ? 0.5 * (1.0 - math.cos(math.pi * i / fadeSamples))
            : 1.0;
        final fadeOut = i > noteSamples - fadeSamples
            ? (noteSamples - i) / fadeSamples
            : 1.0;
        final s = _synthesizeInstrumentSample(
          instrument: instrument,
          f0: f0,
          t: t,
          normT: normT,
          hasGlide: hasGlide,
          phase: phase,
          sampleRate: sampleRate,
          onPhaseAdvance: (next) => phase = next,
        );
        mixBuffer[startSample + i] += s * velocity * fadeIn * fadeOut;
      }
    }

    // 2. Sub-bass Log Drum layer (signature syncopated pattern varied by seed)
    final logSteps = isGqom
        ? const [0, 3, 6, 8, 11, 14]
        : const [0, 3, 6, 7, 10, 12, 14];
    final logRows = const [0, 0, 2, 1, 3, 0, 4];
    for (var idx = 0; idx < logSteps.length; idx++) {
      final step = logSteps[idx];
      final row = (logRows[idx % logRows.length] + (seed.abs() % 2)) % 5;
      renderLayerNote(
        instrument: SketchpadInstrument.amapianoLogDrum,
        stepIndex: step,
        scaleRow: row,
        durationSteps: (step == 6 || step == 14) ? 2 : 1,
        velocity: 0.72,
        hasGlide: step == 6 || step == 14,
      );
    }

    // 3. Warm Rhodes Chords layer on steps 0, 6, 8, 12
    const chordSteps = [0, 6, 8, 12];
    const chordRows = [0, 2, 3, 1];
    for (var i = 0; i < chordSteps.length; i++) {
      renderLayerNote(
        instrument: SketchpadInstrument.privateSchoolRhodes,
        stepIndex: chordSteps[i],
        scaleRow: chordRows[(i + seed.abs()) % chordRows.length],
        durationSteps: 3,
        velocity: 0.42,
      );
    }

    // 4. Melodic African Lead (Maskandi Guitar, Venda Mbira, or Marimba Wood)
    final leadInstrument = isMaskandi
        ? SketchpadInstrument.maskandiGuitar
        : (isAfroHouse
            ? SketchpadInstrument.marimbaWood
            : SketchpadInstrument.vendaMbira);
    const leadSteps = [0, 2, 4, 7, 9, 11, 13, 15];
    for (var i = 0; i < leadSteps.length; i++) {
      final row = 2 + ((i * 2 + seed.abs()) % 5);
      renderLayerNote(
        instrument: leadInstrument,
        stepIndex: leadSteps[i],
        scaleRow: row,
        durationSteps: 1,
        velocity: 0.48,
      );
    }

    return _encodePcm16Wav(mixBuffer, sampleRate);
  }
}

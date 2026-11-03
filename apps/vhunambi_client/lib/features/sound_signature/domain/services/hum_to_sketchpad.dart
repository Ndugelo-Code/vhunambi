import '../../../../features/studio/domain/models/melody_sketchpad_models.dart';
import '../models/sound_signature_dna.dart';

/// Bridges acoustic SoundSignatureDna takes into the Phase 32 5-channel sketchpad (REQ-SIG-SKP-01 / Design 6.1).
class HumToSketchpadService {
  const HumToSketchpadService();

  /// Converts a [SoundSignatureDna] intake into a ready-to-load [MelodyPatternEntity].
  MelodyPatternEntity createPatternFromSignature(
    SoundSignatureDna signature, {
    String? name,
    SketchpadInstrument instrument = SketchpadInstrument.amapianoLogDrum,
  }) {
    final rootPc = signature.pitch.rootPitchClass;
    final rootName = rootPc < 12
        ? [
            'C',
            'C#',
            'D',
            'D#',
            'E',
            'F',
            'F#',
            'G',
            'G#',
            'A',
            'A#',
            'B'
          ][rootPc]
        : 'C';
    final key = '${rootName}m';

    return MelodyPatternEntity(
      id: signature.id,
      name: name ?? 'Hum Sketch (${signature.displayCode})',
      genre: 'Amapiano',
      instrument: instrument,
      musicalKey: key,
      scaleMode: signature.pitch.scaleMode,
      bpm: signature.bpmHint.round(),
      conditioningStrength: 0.75,
      notes: signature.rhythm.quantizedNotes,
    );
  }
}


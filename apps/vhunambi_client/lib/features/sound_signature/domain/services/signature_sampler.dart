import 'dart:math' as math;
import 'dart:typed_data';
import '../../../../features/studio/domain/models/melody_sketchpad_models.dart';
import '../idealizer/psola.dart';

/// Generates 8 chromatic/modal audio slices from an idealized voice take (REQ-SIG-SKP-02 / Design 6.2).
///
/// Enables `SketchpadInstrument.customSoundSignature` to be played dynamically across
/// all 8 piano roll rails in the Phase 32 5-channel sketchpad.
class SignatureSampler {
  const SignatureSampler({
    this.sampleRate = 44100,
  });

  final int sampleRate;

  /// Creates 8 tuned Float32List audio buffers corresponding to the 8 rows of [scaleMode]
  /// rooted at [rootPitchClass].
  List<Float32List> generateScaleBuffers({
    required Float32List sourceVocalSlice,
    required double sourcePitchMidi,
    required AfricanScaleMode scaleMode,
    required int rootPitchClass,
  }) {
    if (sourceVocalSlice.isEmpty) {
      return List.generate(8, (_) => Float32List(0));
    }

    const psola = TdPsolaShifter(sampleRate: 44100);
    final buffers = <Float32List>[];

    final n = sourceVocalSlice.length;
    final hopMs = 10;
    final frameCount = (n / ((sampleRate * hopMs) / 1000.0)).ceil();

    final srcF0 = 440.0 * math.pow(2.0, (sourcePitchMidi - 69.0) / 12.0);
    final sourceF0List = Float64List.fromList(List<double>.filled(frameCount, srcF0));

    // Base octave MIDI anchor for vocals (Octave 3: MIDI 48 + root)
    final baseMidi = 48 + rootPitchClass;

    for (var row = 0; row < 8; row++) {
      final offset = (row < scaleMode.semitoneOffsets.length)
          ? scaleMode.semitoneOffsets[row]
          : scaleMode.semitoneOffsets.last;

      final targetMidi = baseMidi + offset;
      final tgtF0 = 440.0 * math.pow(2.0, (targetMidi - 69.0) / 12.0);
      final targetF0List = Float64List.fromList(List<double>.filled(frameCount, tgtF0));

      final tunedBuffer = psola.pitchShift(
        inputAudio: sourceVocalSlice,
        sourceF0Hz: sourceF0List,
        targetF0Hz: targetF0List,
        f0HopMs: hopMs,
      );

      buffers.add(tunedBuffer);
    }

    return buffers;
  }
}

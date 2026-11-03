import '../../../../features/studio/domain/models/melody_sketchpad_models.dart';

/// Rhythmic pocket and transient layer of SoundSignatureDna (REQ-SIG-DNA-01 / Design 2.1).
///
/// Encapsulates detected audio onsets, their signed deviations from the 16-step BPM grid,
/// and quantized [MelodyStepNote]s ready for the Phase 32 5-channel sketchpad.
class RhythmicTransientGrid {
  const RhythmicTransientGrid({
    required this.onsetMs,
    required this.offsetFromGridMs,
    required this.quantizedNotes,
  });

  /// Detected note and syllable onset timestamps in milliseconds.
  final List<int> onsetMs;

  /// Signed deviations from the nearest 16-step beat grid step in milliseconds.
  /// Positive = lagging behind the grid; negative = rushing ahead.
  final List<int> offsetFromGridMs;

  /// Quantized notes mapped across 16 steps and 8 scale rows.
  final List<MelodyStepNote> quantizedNotes;

  RhythmicTransientGrid copyWith({
    List<int>? onsetMs,
    List<int>? offsetFromGridMs,
    List<MelodyStepNote>? quantizedNotes,
  }) {
    return RhythmicTransientGrid(
      onsetMs: onsetMs ?? this.onsetMs,
      offsetFromGridMs: offsetFromGridMs ?? this.offsetFromGridMs,
      quantizedNotes: quantizedNotes ?? this.quantizedNotes,
    );
  }

  Map<String, dynamic> toJson() => {
        'onsetMs': onsetMs,
        'offsetFromGridMs': offsetFromGridMs,
        'quantizedNotes': quantizedNotes.map((n) => n.toJson()).toList(),
      };

  factory RhythmicTransientGrid.fromJson(Map<String, dynamic> json) {
    return RhythmicTransientGrid(
      onsetMs: (json['onsetMs'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      offsetFromGridMs: (json['offsetFromGridMs'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      quantizedNotes: (json['quantizedNotes'] as List<dynamic>?)
              ?.map((e) => MelodyStepNote.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}


import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// 5 Sovereign African Sketchpad Instruments (REQ-SKP-01).
enum SketchpadInstrument {
  amapianoLogDrum('Amapiano Log Drum', 'amapiano_log_drum', '🥁'),
  privateSchoolRhodes('Private School Rhodes', 'private_school_rhodes', '🎹'),
  maskandiGuitar('Maskandi Guitar', 'maskandi_guitar', '🎸'),
  vendaMbira('Venda Mbira', 'venda_mbira', '🎼'),
  marimbaWood('Wooden Marimba', 'marimba_wood', '🪵');

  const SketchpadInstrument(this.label, this.wireValue, this.emoji);
  final String label;
  final String wireValue;
  final String emoji;

  static SketchpadInstrument fromWire(String? wire) {
    if (wire == null) return SketchpadInstrument.amapianoLogDrum;
    return SketchpadInstrument.values.firstWhere(
      (i) => i.wireValue == wire || i.name == wire,
      orElse: () => SketchpadInstrument.amapianoLogDrum,
    );
  }
}

/// 4 Scale-Locked Modal Ladders guaranteeing zero wrong notes (REQ-SKP-02).
enum AfricanScaleMode {
  minorPentatonic(
    'Minor Pentatonic',
    'minor_pentatonic',
    [0, 3, 5, 7, 10, 12, 15, 17],
  ),
  naturalMinor(
    'Natural Minor (Soul)',
    'natural_minor',
    [0, 2, 3, 5, 7, 8, 10, 12],
  ),
  maskandiHexatonic(
    'Maskandi Hexatonic',
    'maskandi_hexatonic',
    [0, 2, 4, 5, 7, 9, 12, 14],
  ),
  gqomPhrygianDark(
    'Gqom Phrygian Dark',
    'gqom_phrygian_dark',
    [0, 1, 5, 7, 8, 10, 12, 13],
  );

  const AfricanScaleMode(this.label, this.wireValue, this.semitoneOffsets);
  final String label;
  final String wireValue;
  final List<int> semitoneOffsets;

  static AfricanScaleMode fromWire(String? wire) {
    if (wire == null) return AfricanScaleMode.minorPentatonic;
    return AfricanScaleMode.values.firstWhere(
      (s) => s.wireValue == wire || s.name == wire,
      orElse: () => AfricanScaleMode.minorPentatonic,
    );
  }
}

/// Desktop & Pro Chord Voicing Stamp Mode (REQ-SKP-09).
enum ChordStampMode {
  single('Single Note'),
  triad('Triad Chord'),
  seventh('Soul 7th');

  const ChordStampMode(this.label);
  final String label;
}

const List<String> kChromaticNoteNames = [
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
  'B',
];

const Map<String, int> _rootKeyToSemitone = {
  'C': 0,
  'C#': 1,
  'Db': 1,
  'D': 2,
  'D#': 3,
  'Eb': 3,
  'E': 4,
  'F': 5,
  'F#': 6,
  'Gb': 6,
  'G': 7,
  'G#': 8,
  'Ab': 8,
  'A': 9,
  'A#': 10,
  'Bb': 10,
  'B': 11,
};

/// Resolves the exact fundamental frequency (Hz) for a scale row (0..7) (REQ-SKP-02).
///
/// - `amapianoLogDrum`: Anchored in sub-bass Octave 1–2 (`49.0 Hz – 220.0 Hz`, e.g. `A1 = 55.0 Hz`, `F#2 = 92.5 Hz`).
/// - Melodic instruments (`privateSchoolRhodes`, `maskandiGuitar`, `vendaMbira`, `marimbaWood`):
///   Anchored in warm mid Octave 2–4 (`110.0 Hz – 493.9 Hz`).
double resolveScaleFrequencyHz(
  String musicalKey,
  AfricanScaleMode scaleMode,
  int scaleRow, {
  SketchpadInstrument instrument = SketchpadInstrument.amapianoLogDrum,
}) {
  final cleanRoot = musicalKey
      .replaceAll(RegExp(r'm(in(or)?)?$', caseSensitive: false), '')
      .trim();
  final rawRoot = _rootKeyToSemitone[cleanRoot] ?? 6; // Default F#
  // Wrap G, G#, A, A#, B down by 12 semitones so Amapiano keys like Am sit at 55Hz (A1) instead of 110Hz/440Hz
  final effectiveRoot = rawRoot >= 7 ? rawRoot - 12 : rawRoot;
  final baseMidi =
      instrument == SketchpadInstrument.amapianoLogDrum ? 36 : 48; // C2 vs C3
  final clampedRow = scaleRow.clamp(0, 7);
  final midiNote =
      baseMidi + effectiveRoot + scaleMode.semitoneOffsets[clampedRow];
  final freq = 440.0 * math.pow(2.0, (midiNote - 69.0) / 12.0);
  return (freq * 100.0).roundToDouble() / 100.0;
}

/// Resolves a human-readable note name + octave (e.g., `A1`, `F#2`, `F#3`) for piano roll rails.
String resolveScaleNoteLabel(
  String musicalKey,
  AfricanScaleMode scaleMode,
  int scaleRow, {
  SketchpadInstrument instrument = SketchpadInstrument.amapianoLogDrum,
}) {
  final cleanRoot = musicalKey
      .replaceAll(RegExp(r'm(in(or)?)?$', caseSensitive: false), '')
      .trim();
  final rawRoot = _rootKeyToSemitone[cleanRoot] ?? 6;
  final effectiveRoot = rawRoot >= 7 ? rawRoot - 12 : rawRoot;
  final baseMidi =
      instrument == SketchpadInstrument.amapianoLogDrum ? 36 : 48;
  final clampedRow = scaleRow.clamp(0, 7);
  final midiNote =
      baseMidi + effectiveRoot + scaleMode.semitoneOffsets[clampedRow];
  final noteName = kChromaticNoteNames[midiNote % 12];
  final octave = (midiNote ~/ 12) - 1;
  return '$noteName$octave';
}

/// A single active note on the 8-row × 16-step sequencer grid (REQ-SKP-03).
@immutable
class MelodyStepNote {
  const MelodyStepNote({
    required this.stepIndex,
    required this.scaleRow,
    this.velocity = 0.88,
    this.hasGlide = false,
    this.durationSteps = 1,
  });

  final int stepIndex; // 0..15
  final int scaleRow; // 0..7
  final double velocity; // 0.05..1.0
  final bool hasGlide; // -5 semitone Amapiano log-drum slide
  final int durationSteps; // 1..4

  MelodyStepNote copyWith({
    int? stepIndex,
    int? scaleRow,
    double? velocity,
    bool? hasGlide,
    int? durationSteps,
  }) {
    return MelodyStepNote(
      stepIndex: stepIndex ?? this.stepIndex,
      scaleRow: scaleRow ?? this.scaleRow,
      velocity: velocity ?? this.velocity,
      hasGlide: hasGlide ?? this.hasGlide,
      durationSteps: durationSteps ?? this.durationSteps,
    );
  }

  Map<String, dynamic> toJson() => {
        'stepIndex': stepIndex,
        'scaleRow': scaleRow,
        'velocity': velocity,
        'hasGlide': hasGlide,
        'durationSteps': durationSteps,
      };

  factory MelodyStepNote.fromJson(Map<String, dynamic> json) {
    return MelodyStepNote(
      stepIndex: (json['stepIndex'] as num?)?.toInt().clamp(0, 15) ?? 0,
      scaleRow: (json['scaleRow'] as num?)?.toInt().clamp(0, 7) ?? 0,
      velocity:
          (json['velocity'] as num?)?.toDouble().clamp(0.05, 1.0) ?? 0.88,
      hasGlide: (json['hasGlide'] as bool?) ?? false,
      durationSteps: (json['durationSteps'] as num?)?.toInt().clamp(1, 4) ?? 1,
    );
  }
}

/// Immutable 16-Step Melody, Chord & Log-Drum Pattern Blueprint (< 2 KB in Hive) (REQ-SKP-05).
@immutable
class MelodyPatternEntity {
  const MelodyPatternEntity({
    required this.id,
    required this.name,
    this.genre = 'Amapiano',
    this.instrument = SketchpadInstrument.amapianoLogDrum,
    this.musicalKey = 'F#m',
    this.scaleMode = AfricanScaleMode.minorPentatonic,
    this.bpm = 113,
    this.conditioningStrength = 0.70,
    this.notes = const [],
  });

  final String id;
  final String name;
  final String genre;
  final SketchpadInstrument instrument;
  final String musicalKey;
  final AfricanScaleMode scaleMode;
  final int bpm;
  final double conditioningStrength;
  final List<MelodyStepNote> notes;

  bool hasNoteAt(int scaleRow, int stepIndex) {
    return notes.any(
      (n) => n.scaleRow == scaleRow && n.stepIndex == stepIndex,
    );
  }

  MelodyStepNote? noteAt(int scaleRow, int stepIndex) {
    for (final n in notes) {
      if (n.scaleRow == scaleRow && n.stepIndex == stepIndex) return n;
    }
    return null;
  }

  MelodyPatternEntity copyWith({
    String? id,
    String? name,
    String? genre,
    SketchpadInstrument? instrument,
    String? musicalKey,
    AfricanScaleMode? scaleMode,
    int? bpm,
    double? conditioningStrength,
    List<MelodyStepNote>? notes,
  }) {
    return MelodyPatternEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      genre: genre ?? this.genre,
      instrument: instrument ?? this.instrument,
      musicalKey: musicalKey ?? this.musicalKey,
      scaleMode: scaleMode ?? this.scaleMode,
      bpm: bpm ?? this.bpm,
      conditioningStrength: conditioningStrength ?? this.conditioningStrength,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'genre': genre,
        'instrument': instrument.wireValue,
        'musicalKey': musicalKey,
        'scaleMode': scaleMode.wireValue,
        'bpm': bpm,
        'conditioningStrength': conditioningStrength,
        'notes': notes.map((n) => n.toJson()).toList(),
      };

  factory MelodyPatternEntity.fromJson(Map<String, dynamic> json) {
    final rawNotes = (json['notes'] as List<dynamic>? ?? const [])
        .map(
          (e) => MelodyStepNote.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();

    return MelodyPatternEntity(
      id: (json['id'] as String?) ?? 'skp_default',
      name: (json['name'] as String?) ?? 'Custom Sketch',
      genre: (json['genre'] as String?) ?? 'Amapiano',
      instrument: SketchpadInstrument.fromWire(json['instrument'] as String?),
      musicalKey: (json['musicalKey'] as String?) ?? 'F#m',
      scaleMode: AfricanScaleMode.fromWire(json['scaleMode'] as String?),
      bpm: (json['bpm'] as num?)?.toInt().clamp(60, 180) ?? 113,
      conditioningStrength:
          (json['conditioningStrength'] as num?)?.toDouble().clamp(0.1, 1.0) ??
              0.70,
      notes: rawNotes,
    );
  }
}

/// 6 Iconic African Starter Melody & Log-Drum Patterns (REQ-SKP-04).
const List<MelodyPatternEntity> kStarterMelodyPatterns = [
  MelodyPatternEntity(
    id: 'kabza_logdrum_bounce',
    name: 'Soweto Log-Drum Knock & Slide',
    genre: 'Amapiano',
    instrument: SketchpadInstrument.amapianoLogDrum,
    musicalKey: 'F#m',
    scaleMode: AfricanScaleMode.minorPentatonic,
    bpm: 113,
    conditioningStrength: 0.72,
    notes: [
      MelodyStepNote(stepIndex: 0, scaleRow: 0, velocity: 0.95),
      MelodyStepNote(
        stepIndex: 3,
        scaleRow: 2,
        velocity: 0.90,
        hasGlide: true,
        durationSteps: 2,
      ),
      MelodyStepNote(stepIndex: 6, scaleRow: 0, velocity: 0.85),
      MelodyStepNote(stepIndex: 8, scaleRow: 3, velocity: 0.98),
      MelodyStepNote(
        stepIndex: 11,
        scaleRow: 4,
        velocity: 1.0,
        hasGlide: true,
        durationSteps: 2,
      ),
      MelodyStepNote(stepIndex: 14, scaleRow: 1, velocity: 0.88),
    ],
  ),
  MelodyPatternEntity(
    id: 'private_school_rhodes_lush',
    name: 'Kelvin-Style Soulful Rhodes 7ths',
    genre: 'Private School Amapiano',
    instrument: SketchpadInstrument.privateSchoolRhodes,
    musicalKey: 'Am',
    scaleMode: AfricanScaleMode.naturalMinor,
    bpm: 112,
    conditioningStrength: 0.65,
    notes: [
      MelodyStepNote(stepIndex: 0, scaleRow: 0, velocity: 0.82, durationSteps: 4),
      MelodyStepNote(stepIndex: 4, scaleRow: 3, velocity: 0.78, durationSteps: 4),
      MelodyStepNote(stepIndex: 8, scaleRow: 5, velocity: 0.85, durationSteps: 4),
      MelodyStepNote(stepIndex: 12, scaleRow: 4, velocity: 0.80, durationSteps: 4),
    ],
  ),
  MelodyPatternEntity(
    id: 'maskandi_ukupika_turnaround',
    name: 'KZN Ukupika Acoustic Guitar Picking',
    genre: 'Maskandi',
    instrument: SketchpadInstrument.maskandiGuitar,
    musicalKey: 'G',
    scaleMode: AfricanScaleMode.maskandiHexatonic,
    bpm: 124,
    conditioningStrength: 0.75,
    notes: [
      MelodyStepNote(stepIndex: 0, scaleRow: 0, velocity: 0.92),
      MelodyStepNote(stepIndex: 2, scaleRow: 2, velocity: 0.84),
      MelodyStepNote(stepIndex: 4, scaleRow: 4, velocity: 0.90),
      MelodyStepNote(stepIndex: 6, scaleRow: 5, velocity: 0.86),
      MelodyStepNote(stepIndex: 8, scaleRow: 7, velocity: 0.95),
      MelodyStepNote(stepIndex: 10, scaleRow: 4, velocity: 0.84),
      MelodyStepNote(stepIndex: 12, scaleRow: 2, velocity: 0.88),
      MelodyStepNote(stepIndex: 14, scaleRow: 1, velocity: 0.82),
    ],
  ),
  MelodyPatternEntity(
    id: 'venda_domba_mbira',
    name: 'Vhembe Royal Mbira Ostinato',
    genre: 'Afro Soul',
    instrument: SketchpadInstrument.vendaMbira,
    musicalKey: 'Dm',
    scaleMode: AfricanScaleMode.minorPentatonic,
    bpm: 108,
    conditioningStrength: 0.68,
    notes: [
      MelodyStepNote(stepIndex: 0, scaleRow: 4, velocity: 0.88),
      MelodyStepNote(stepIndex: 3, scaleRow: 2, velocity: 0.82),
      MelodyStepNote(stepIndex: 6, scaleRow: 5, velocity: 0.90),
      MelodyStepNote(stepIndex: 8, scaleRow: 0, velocity: 0.94),
      MelodyStepNote(stepIndex: 11, scaleRow: 3, velocity: 0.85),
      MelodyStepNote(stepIndex: 14, scaleRow: 6, velocity: 0.89),
    ],
  ),
  MelodyPatternEntity(
    id: 'gqom_dark_sub_pulse',
    name: 'eThekwini Broken-Beat Sub Pulse',
    genre: 'Gqom',
    instrument: SketchpadInstrument.amapianoLogDrum,
    musicalKey: 'Cm',
    scaleMode: AfricanScaleMode.gqomPhrygianDark,
    bpm: 127,
    conditioningStrength: 0.78,
    notes: [
      MelodyStepNote(stepIndex: 0, scaleRow: 0, velocity: 1.0),
      MelodyStepNote(
        stepIndex: 3,
        scaleRow: 1,
        velocity: 0.95,
        hasGlide: true,
        durationSteps: 2,
      ),
      MelodyStepNote(stepIndex: 7, scaleRow: 0, velocity: 0.92),
      MelodyStepNote(
        stepIndex: 10,
        scaleRow: 3,
        velocity: 0.96,
        hasGlide: true,
        durationSteps: 2,
      ),
      MelodyStepNote(stepIndex: 13, scaleRow: 1, velocity: 0.90),
    ],
  ),
  MelodyPatternEntity(
    id: 'afro_house_marimba_arp',
    name: 'Horizon Wooden Marimba Arpeggio',
    genre: 'Afro House',
    instrument: SketchpadInstrument.marimbaWood,
    musicalKey: 'Em',
    scaleMode: AfricanScaleMode.minorPentatonic,
    bpm: 120,
    conditioningStrength: 0.64,
    notes: [
      MelodyStepNote(stepIndex: 0, scaleRow: 0, velocity: 0.86),
      MelodyStepNote(stepIndex: 2, scaleRow: 3, velocity: 0.80),
      MelodyStepNote(stepIndex: 4, scaleRow: 4, velocity: 0.90),
      MelodyStepNote(stepIndex: 7, scaleRow: 6, velocity: 0.88),
      MelodyStepNote(stepIndex: 10, scaleRow: 4, velocity: 0.82),
      MelodyStepNote(stepIndex: 12, scaleRow: 2, velocity: 0.85),
      MelodyStepNote(stepIndex: 15, scaleRow: 5, velocity: 0.91),
    ],
  ),
];


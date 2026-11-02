import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// Sovereign African & Studio Sketchpad Instruments (REQ-SKP-01, Phase 32).
enum SketchpadInstrument {
  amapianoLogDrum('Amapiano Log Drum', 'amapiano_log_drum', '🥁'),
  privateSchoolRhodes('Private School Rhodes', 'private_school_rhodes', '🎹'),
  maskandiGuitar('Maskandi Guitar', 'maskandi_guitar', '🎸'),
  vendaMbira('Venda Mbira', 'venda_mbira', '🎼'),
  marimbaWood('Wooden Marimba', 'marimba_wood', '🪵'),
  // Phase 32 Studio-Grade Core Kit
  concertGrandPiano('Concert Grand Piano', 'concert_grand_piano', '🎹'),
  classicPiano('Classic Upright Piano', 'classic_piano', '🎹'),
  nylonGuitar('Nylon Acoustic Guitar', 'nylon_guitar', '🎸'),
  electricGuitar('Clean Electric Guitar', 'electric_guitar', '🎸'),
  bambooFlute('African Bamboo Flute', 'bamboo_flute', '🪈'),
  sopranoSax('Soprano Saxophone', 'soprano_sax', '🎷'),
  soloViolin('Solo Violin', 'solo_violin', '🎻'),
  hipHop808Sub('Hip-Hop 808 Sub', 'hiphop_808_sub', '🔊'),
  gqomDarkSub('Gqom Dark Sub', 'gqom_dark_sub', '🔊'),
  neoSoulPad('Warm Neo-Soul Pad', 'neo_soul_pad', '✨'),
  mbaqangaOrgan('Mbaqanga Organ', 'mbaqanga_organ', '🎹');

  const SketchpadInstrument(this.label, this.wireValue, this.emoji);
  final String label;
  final String wireValue;
  final String emoji;

  bool get isSubBass =>
      this == SketchpadInstrument.amapianoLogDrum ||
      this == SketchpadInstrument.hipHop808Sub ||
      this == SketchpadInstrument.gqomDarkSub;

  bool get isHighLead =>
      this == SketchpadInstrument.soloViolin ||
      this == SketchpadInstrument.bambooFlute ||
      this == SketchpadInstrument.sopranoSax;

  static SketchpadInstrument fromWire(String? wire) {
    if (wire == null) return SketchpadInstrument.amapianoLogDrum;
    return SketchpadInstrument.values.firstWhere(
      (i) => i.wireValue == wire || i.name == wire,
      orElse: () => SketchpadInstrument.amapianoLogDrum,
    );
  }
}

/// The 5 synchronized channel tracks of the FL Studio Master Groove Engine (Phase 32).
enum SketchpadChannelRole {
  lead('Lead Melody', 'lead', 0),
  chords('Chords & Keys', 'chords', 1),
  bass('Bass & Sub', 'bass', 2),
  drums('Beat & Drums', 'drums', 3),
  hats('Hi-Hats & Percs', 'hats', 4);

  const SketchpadChannelRole(this.label, this.wireValue, this.channelIndex);
  final String label;
  final String wireValue;
  final int channelIndex;

  static SketchpadChannelRole fromWire(String? wire) {
    if (wire == null) return SketchpadChannelRole.lead;
    return SketchpadChannelRole.values.firstWhere(
      (r) => r.wireValue == wire || r.name == wire,
      orElse: () => SketchpadChannelRole.lead,
    );
  }
}

/// 6 Dedicated Genre Drum & Beat Kits (Phase 32).
enum BeatKitGenre {
  amapiano('Amapiano Groove Kit', 'amapiano'),
  hipHop('Hip-Hop Trap Kit', 'hiphop'),
  gqom('Durban Gqom Kit', 'gqom'),
  afrobeats('Lagos Afrobeats Kit', 'afrobeats'),
  house('Deep House 4x4 Kit', 'house'),
  pop('Studio Pop Kit', 'pop');

  const BeatKitGenre(this.label, this.wireValue);
  final String label;
  final String wireValue;

  static BeatKitGenre fromWire(String? wire) {
    if (wire == null) return BeatKitGenre.amapiano;
    return BeatKitGenre.values.firstWhere(
      (k) => k.wireValue == wire || k.name == wire,
      orElse: () => BeatKitGenre.amapiano,
    );
  }
}

/// 8 Dedicated Studio Drum Voices per Beat Kit.
const List<String> kDrumRackVoiceNames = [
  'Sub 808 / Log Kick',
  'Studio Punch Kick',
  'Crisp Snare',
  'Rimshot / Clack',
  'Club Clap',
  'Closed Hi-Hat',
  'Open Shimmer Hat',
  'Mbaḓi Shaker / Conga',
];

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
  final baseMidi = instrument.isSubBass
      ? 36
      : (instrument.isHighLead ? 60 : 48); // C2 vs C4 vs C3
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
  final baseMidi = instrument.isSubBass
      ? 36
      : (instrument.isHighLead ? 60 : 48);
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

/// A single channel track within the 5-channel Master Groove Engine (Phase 32).
@immutable
class SketchpadChannelTrack {
  final SketchpadChannelRole role;
  final SketchpadInstrument instrument;
  final BeatKitGenre beatKit;
  final List<MelodyStepNote> steps;
  final double volume; // 0.0 to 1.2
  final double pan; // -1.0 to 1.0
  final bool isMuted;
  final bool isSolo;

  const SketchpadChannelTrack({
    required this.role,
    required this.instrument,
    this.beatKit = BeatKitGenre.amapiano,
    this.steps = const [],
    this.volume = 1.0,
    this.pan = 0.0,
    this.isMuted = false,
    this.isSolo = false,
  });

  bool get hasNotes => steps.isNotEmpty;

  SketchpadChannelTrack copyWith({
    SketchpadChannelRole? role,
    SketchpadInstrument? instrument,
    BeatKitGenre? beatKit,
    List<MelodyStepNote>? steps,
    double? volume,
    double? pan,
    bool? isMuted,
    bool? isSolo,
  }) {
    return SketchpadChannelTrack(
      role: role ?? this.role,
      instrument: instrument ?? this.instrument,
      beatKit: beatKit ?? this.beatKit,
      steps: steps ?? this.steps,
      volume: volume ?? this.volume,
      pan: pan ?? this.pan,
      isMuted: isMuted ?? this.isMuted,
      isSolo: isSolo ?? this.isSolo,
    );
  }

  Map<String, dynamic> toJson() => {
        'role': role.wireValue,
        'instrument': instrument.wireValue,
        'beatKit': beatKit.wireValue,
        'steps': steps.map((s) => s.toJson()).toList(),
        'volume': volume,
        'pan': pan,
        'isMuted': isMuted,
        'isSolo': isSolo,
      };

  factory SketchpadChannelTrack.fromJson(Map<String, dynamic> json) {
    return SketchpadChannelTrack(
      role: SketchpadChannelRole.fromWire(json['role'] as String?),
      instrument: SketchpadInstrument.fromWire(json['instrument'] as String?),
      beatKit: BeatKitGenre.fromWire(json['beatKit'] as String?),
      steps: (json['steps'] as List<dynamic>? ?? const [])
          .map((e) => MelodyStepNote.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
      pan: (json['pan'] as num?)?.toDouble() ?? 0.0,
      isMuted: (json['isMuted'] as bool?) ?? false,
      isSolo: (json['isSolo'] as bool?) ?? false,
    );
  }
}

/// A unified 5-channel FL Studio-style Master Groove (Phase 32).
@immutable
class MultiTrackGrooveEntity {
  final String id;
  final String name;
  final int bpm;
  final String musicalKey;
  final AfricanScaleMode scaleMode;
  final Map<SketchpadChannelRole, SketchpadChannelTrack> channels;
  final double masterDriveAmount;
  final double swingPercent;

  const MultiTrackGrooveEntity({
    required this.id,
    required this.name,
    required this.bpm,
    required this.musicalKey,
    required this.scaleMode,
    required this.channels,
    this.masterDriveAmount = 0.20,
    this.swingPercent = 12.0,
  });

  /// Factory creating an empty or initialized default 5-channel master groove.
  factory MultiTrackGrooveEntity.createDefault({
    String id = 'groove_default',
    String name = 'Master Groove Session',
    int bpm = 113,
    String musicalKey = 'F#m',
    AfricanScaleMode scaleMode = AfricanScaleMode.minorPentatonic,
    SketchpadInstrument leadInstrument = SketchpadInstrument.concertGrandPiano,
    List<MelodyStepNote> initialLeadNotes = const [],
  }) {
    return MultiTrackGrooveEntity(
      id: id,
      name: name,
      bpm: bpm,
      musicalKey: musicalKey,
      scaleMode: scaleMode,
      channels: {
        SketchpadChannelRole.lead: SketchpadChannelTrack(
          role: SketchpadChannelRole.lead,
          instrument: leadInstrument,
          steps: initialLeadNotes,
        ),
        SketchpadChannelRole.chords: const SketchpadChannelTrack(
          role: SketchpadChannelRole.chords,
          instrument: SketchpadInstrument.privateSchoolRhodes,
        ),
        SketchpadChannelRole.bass: const SketchpadChannelTrack(
          role: SketchpadChannelRole.bass,
          instrument: SketchpadInstrument.amapianoLogDrum,
        ),
        SketchpadChannelRole.drums: const SketchpadChannelTrack(
          role: SketchpadChannelRole.drums,
          instrument: SketchpadInstrument.amapianoLogDrum,
          beatKit: BeatKitGenre.amapiano,
        ),
        SketchpadChannelRole.hats: const SketchpadChannelTrack(
          role: SketchpadChannelRole.hats,
          instrument: SketchpadInstrument.amapianoLogDrum,
          beatKit: BeatKitGenre.amapiano,
        ),
      },
    );
  }

  /// Extracts single-channel pattern for Phase 27 backward compatibility.
  MelodyPatternEntity toLegacyPattern([
    SketchpadChannelRole role = SketchpadChannelRole.lead,
  ]) {
    final channel = channels[role] ?? channels[SketchpadChannelRole.lead]!;
    return MelodyPatternEntity(
      id: id,
      name: name,
      bpm: bpm,
      musicalKey: musicalKey,
      scaleMode: scaleMode,
      instrument: channel.instrument,
      notes: channel.steps,
    );
  }

  MultiTrackGrooveEntity copyWith({
    String? id,
    String? name,
    int? bpm,
    String? musicalKey,
    AfricanScaleMode? scaleMode,
    Map<SketchpadChannelRole, SketchpadChannelTrack>? channels,
    double? masterDriveAmount,
    double? swingPercent,
  }) {
    return MultiTrackGrooveEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      bpm: bpm ?? this.bpm,
      musicalKey: musicalKey ?? this.musicalKey,
      scaleMode: scaleMode ?? this.scaleMode,
      channels: channels ?? this.channels,
      masterDriveAmount: masterDriveAmount ?? this.masterDriveAmount,
      swingPercent: swingPercent ?? this.swingPercent,
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


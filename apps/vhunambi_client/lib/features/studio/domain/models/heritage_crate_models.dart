import 'package:flutter/foundation.dart';

/// Categories of authentic indigenous African instruments for crate digging.
enum HeritageCrateCategory {
  all('All Instruments', '🌍'),
  percussion('Drums & Percussion', '🥁'),
  pluckedStrings('Plucked Strings', '🪕'),
  melodicIdiophones('Idiophones & Mbira', '🎹'),
  traditionalPipes('Flutes & Horns', '🎷'),
  chants('Ancestral Chants', '🗣️');

  final String label;
  final String emoji;
  const HeritageCrateCategory(this.label, this.emoji);
}

/// An individual authentic African indigenous sound sample in the crate archive.
@immutable
class HeritageSampleEntity {
  final String id;
  final String name;
  final String instrument;
  final String cultureRegion;
  final String audioUrl;
  final int bpm;
  final String rootKey;
  final double durationSec;
  final List<String> tags;
  final bool isFavorite;
  final List<double> waveformPeaks;

  const HeritageSampleEntity({
    required this.id,
    required this.name,
    required this.instrument,
    required this.cultureRegion,
    required this.audioUrl,
    required this.bpm,
    required this.rootKey,
    required this.durationSec,
    required this.tags,
    this.isFavorite = false,
    this.waveformPeaks = const [0.3, 0.6, 0.9, 0.4, 0.7, 0.8, 0.5, 0.2],
  });

  HeritageSampleEntity copyWith({bool? isFavorite}) {
    return HeritageSampleEntity(
      id: id,
      name: name,
      instrument: instrument,
      cultureRegion: cultureRegion,
      audioUrl: audioUrl,
      bpm: bpm,
      rootKey: rootKey,
      durationSec: durationSec,
      tags: tags,
      isFavorite: isFavorite ?? this.isFavorite,
      waveformPeaks: waveformPeaks,
    );
  }
}

/// Seeded catalog of authentic, royalty-free African folk instruments.
const List<HeritageSampleEntity> kSeededHeritageSamples = [
  HeritageSampleEntity(
    id: 'sample_mbira_01',
    name: 'Mbira DzaVadzimu Spiritual Ostinato',
    instrument: 'Mbira (Thumb Piano)',
    cultureRegion: 'Zimbabwe (Shona)',
    audioUrl: 'https://audio.vhunambi.com/samples/mbira_shona_112bpm.wav',
    bpm: 112,
    rootKey: 'F# min',
    durationSec: 16.0,
    tags: ['mbira', 'shona', 'ancestral', 'ostinato', 'sacred'],
    waveformPeaks: [0.2, 0.5, 0.8, 0.9, 0.6, 0.8, 0.4, 0.7, 0.3, 0.6],
  ),
  HeritageSampleEntity(
    id: 'sample_kora_01',
    name: 'Mande Griot 21-String Harping',
    instrument: 'Kora Harp',
    cultureRegion: 'West Africa (Gambia/Mali)',
    audioUrl: 'https://audio.vhunambi.com/samples/kora_mande_118bpm.wav',
    bpm: 118,
    rootKey: 'C maj',
    durationSec: 12.0,
    tags: ['kora', 'mande', 'griot', 'harp', 'acoustic'],
    waveformPeaks: [0.3, 0.7, 0.6, 0.8, 0.9, 0.5, 0.4, 0.7, 0.6, 0.3],
  ),
  HeritageSampleEntity(
    id: 'sample_talkingdrum_01',
    name: 'Yoruba Gangan Talking Drum Poly-Rhythm',
    instrument: 'Talking Drum (Gangan)',
    cultureRegion: 'Nigeria (Yoruba)',
    audioUrl: 'https://audio.vhunambi.com/samples/talkingdrum_yoruba_115bpm.wav',
    bpm: 115,
    rootKey: 'A min',
    durationSec: 8.0,
    tags: ['talking-drum', 'yoruba', 'percussion', 'pitch-bend'],
    waveformPeaks: [0.5, 0.9, 0.7, 0.8, 0.9, 0.6, 0.8, 0.7, 0.4, 0.8],
  ),
  HeritageSampleEntity(
    id: 'sample_marimba_01',
    name: 'Kilimanjaro Hardwood Marimba Loop',
    instrument: 'African Marimba',
    cultureRegion: 'East & Southern Africa',
    audioUrl: 'https://audio.vhunambi.com/samples/marimba_wood_114bpm.wav',
    bpm: 114,
    rootKey: 'E min',
    durationSec: 14.0,
    tags: ['marimba', 'wooden', 'idiophone', 'amapiano-core'],
    waveformPeaks: [0.4, 0.6, 0.7, 0.8, 0.9, 0.7, 0.8, 0.5, 0.3, 0.6],
  ),
  HeritageSampleEntity(
    id: 'sample_uhadi_01',
    name: 'Xhosa Calabash Uhadi Resonance Bow',
    instrument: 'Uhadi Musical Bow',
    cultureRegion: 'South Africa (Xhosa)',
    audioUrl: 'https://audio.vhunambi.com/samples/uhadi_xhosa_110bpm.wav',
    bpm: 110,
    rootKey: 'G maj',
    durationSec: 10.0,
    tags: ['uhadi', 'bow', 'calabash', 'overtone', 'xhosa'],
    waveformPeaks: [0.2, 0.4, 0.6, 0.7, 0.5, 0.6, 0.4, 0.5, 0.3, 0.2],
  ),
  HeritageSampleEntity(
    id: 'sample_chants_01',
    name: 'Venda Domba Sacred Choral Echo',
    instrument: 'Ancestral Vocal Chant',
    cultureRegion: 'Limpopo, South Africa (Venda)',
    audioUrl: 'https://audio.vhunambi.com/samples/venda_domba_112bpm.wav',
    bpm: 112,
    rootKey: 'D min',
    durationSec: 16.0,
    tags: ['domba', 'venda', 'sacred', 'limpopo', 'voices'],
    waveformPeaks: [0.6, 0.8, 0.9, 0.7, 0.9, 0.8, 0.7, 0.6, 0.5, 0.4],
  ),
];

/// A single pad slice in the 8-Pad AI MPC Slicer.
@immutable
class MpcPadEntity {
  final String id;
  final int index; // 0 to 7
  final String label;
  final String sourceAudioUrl;
  final double startSec;
  final double endSec;
  final int pitchShiftSemitones; // -12 to +12
  final bool isReversed;
  final double volume; // 0.0 to 1.5
  final bool isMuted;
  final bool isTriggered;

  const MpcPadEntity({
    required this.id,
    required this.index,
    required this.label,
    required this.sourceAudioUrl,
    required this.startSec,
    required this.endSec,
    this.pitchShiftSemitones = 0,
    this.isReversed = false,
    this.volume = 1.0,
    this.isMuted = false,
    this.isTriggered = false,
  });

  MpcPadEntity copyWith({
    int? pitchShiftSemitones,
    bool? isReversed,
    double? volume,
    bool? isMuted,
    bool? isTriggered,
  }) {
    return MpcPadEntity(
      id: id,
      index: index,
      label: label,
      sourceAudioUrl: sourceAudioUrl,
      startSec: startSec,
      endSec: endSec,
      pitchShiftSemitones: pitchShiftSemitones ?? this.pitchShiftSemitones,
      isReversed: isReversed ?? this.isReversed,
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
      isTriggered: isTriggered ?? this.isTriggered,
    );
  }
}

/// State of the 8-Pad AI MPC Slicer instrument.
@immutable
class MpcSlicerState {
  final List<MpcPadEntity> pads;
  final int selectedPadIndex;
  final String sourceTitle;
  final int bpm;
  final double timeStretchRatio; // 0.5 to 2.0
  final bool isPlaying;
  final String? lastBouncedChopPath;

  const MpcSlicerState({
    required this.pads,
    this.selectedPadIndex = 0,
    this.sourceTitle = 'Mbira DzaVadzimu',
    this.bpm = 112,
    this.timeStretchRatio = 1.0,
    this.isPlaying = false,
    this.lastBouncedChopPath,
  });

  MpcPadEntity get selectedPad =>
      pads.isEmpty ? defaultPads.first : pads[selectedPadIndex.clamp(0, pads.length - 1)];

  MpcSlicerState copyWith({
    List<MpcPadEntity>? pads,
    int? selectedPadIndex,
    String? sourceTitle,
    int? bpm,
    double? timeStretchRatio,
    bool? isPlaying,
    String? lastBouncedChopPath,
  }) {
    return MpcSlicerState(
      pads: pads ?? this.pads,
      selectedPadIndex: selectedPadIndex ?? this.selectedPadIndex,
      sourceTitle: sourceTitle ?? this.sourceTitle,
      bpm: bpm ?? this.bpm,
      timeStretchRatio: timeStretchRatio ?? this.timeStretchRatio,
      isPlaying: isPlaying ?? this.isPlaying,
      lastBouncedChopPath: lastBouncedChopPath ?? this.lastBouncedChopPath,
    );
  }

  /// Default 8-pad configuration for clean initial render.
  static final List<MpcPadEntity> defaultPads = List.generate(8, (i) {
    return MpcPadEntity(
      id: 'pad_$i',
      index: i,
      label: 'PAD ${i + 1}',
      sourceAudioUrl: 'https://audio.vhunambi.com/samples/mbira_shona_112bpm.wav',
      startSec: i * 0.5,
      endSec: (i + 1) * 0.5,
    );
  });
}

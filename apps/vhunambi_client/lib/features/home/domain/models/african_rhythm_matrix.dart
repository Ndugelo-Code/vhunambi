import 'package:flutter/foundation.dart';

/// Single regional African rhythm preset in the 7-day indigenous rotation matrix.
@immutable
class AfricanRhythmSpotlight {
  final int weekday; // 1 (Monday) .. 7 (Sunday)
  final String dayName;
  final String genre;
  final String title;
  final String description;
  final int bpm;
  final String musicalKey;
  final String samplePrompt;

  const AfricanRhythmSpotlight({
    required this.weekday,
    required this.dayName,
    required this.genre,
    required this.title,
    required this.description,
    required this.bpm,
    required this.musicalKey,
    required this.samplePrompt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AfricanRhythmSpotlight &&
          runtimeType == other.runtimeType &&
          weekday == other.weekday &&
          dayName == other.dayName &&
          genre == other.genre &&
          title == other.title &&
          description == other.description &&
          bpm == other.bpm &&
          musicalKey == other.musicalKey &&
          samplePrompt == other.samplePrompt;

  @override
  int get hashCode => Object.hash(
    weekday,
    dayName,
    genre,
    title,
    description,
    bpm,
    musicalKey,
    samplePrompt,
  );
}

/// 7-day cyclical African Rhythm Matrix (REQ-HOME-RHYTHM-01).
///
/// Maps each weekday to an authentic regional genre, musical key,
/// tempo, and evocative prompt preset.
abstract final class AfricanRhythmMatrix {
  static const List<AfricanRhythmSpotlight> schedule = [
    AfricanRhythmSpotlight(
      weekday: 1,
      dayName: 'Monday',
      genre: 'Amapiano',
      title: 'Amapiano Private School Rhodes',
      description:
          'Lush jazzy Rhodes progressions with deep, warm log-drum syncopation.',
      bpm: 113,
      musicalKey: 'F# Minor',
      samplePrompt:
          'Deep soulful Amapiano with warm Rhodes piano and private school log drums',
    ),
    AfricanRhythmSpotlight(
      weekday: 2,
      dayName: 'Tuesday',
      genre: 'Gqom',
      title: 'Durban Gqom Broken Beat',
      description:
          'Raw, heavy kick triplets, atmospheric synths, and Durban street pulse.',
      bpm: 127,
      musicalKey: 'C Minor',
      samplePrompt:
          'Raw Durban Gqom club banger with heavy 808 sub kick and syncopated snare',
    ),
    AfricanRhythmSpotlight(
      weekday: 3,
      dayName: 'Wednesday',
      genre: 'Afro-Indigenous',
      title: 'Tshivenḓa Malende Pulse',
      description:
          'Poly-rhythmic ngoma drums, indigenous bamboo flutes, and Limpopo cadence.',
      bpm: 108,
      musicalKey: 'G Minor',
      samplePrompt:
          'Indigenous Tshivenḓa Malende rhythm with traditional ngoma drums and tribal chants',
    ),
    AfricanRhythmSpotlight(
      weekday: 4,
      dayName: 'Thursday',
      genre: 'Maskandi',
      title: 'Maskandi Ukupika Tuning',
      description:
          'Zulu finger-picking guitar syncopation with native acoustic tuning.',
      bpm: 122,
      musicalKey: 'D Major',
      samplePrompt:
          'Maskandi acoustic guitar rhythm with Zulu fingerpicking and driving bassline',
    ),
    AfricanRhythmSpotlight(
      weekday: 5,
      dayName: 'Friday',
      genre: 'Kwaito',
      title: 'Soweto 90s Kwaito Groove',
      description:
          'Slow-tempo house shuffle, deep basslines, and authentic Mzansi street attitude.',
      bpm: 110,
      musicalKey: 'A Minor',
      samplePrompt:
          'Classic 90s Soweto Kwaito with slow house kick and heavy rolling baseline',
    ),
    AfricanRhythmSpotlight(
      weekday: 6,
      dayName: 'Saturday',
      genre: 'Afro-Tech',
      title: 'Lagos Afro-Tech Energy',
      description:
          'Driving 4/4 tribal percussion, hypnotic synth stabs, and continental club power.',
      bpm: 124,
      musicalKey: 'E Minor',
      samplePrompt:
          'Hypnotic Lagos Afro-Tech with driving tribal percussion and atmospheric synth stabs',
    ),
    AfricanRhythmSpotlight(
      weekday: 7,
      dayName: 'Sunday',
      genre: 'Gospel',
      title: 'African Gospel Choral Harmonies',
      description:
          'Rich vocal polyphony, uplifting Hammond organ, and traditional handclaps.',
      bpm: 78,
      musicalKey: 'C Major',
      samplePrompt:
          'Inspiring South African Gospel chorus with rich layered harmonies and warm organ',
    ),
  ];

  /// Returns the spotlight scheduled for [weekday] (1..7).
  ///
  /// If [weekday] is omitted, defaults to [DateTime.now().weekday].
  static AfricanRhythmSpotlight forWeekday([int? weekday]) {
    final day = weekday ?? DateTime.now().weekday;
    final clamped = (day >= 1 && day <= 7) ? day : 1;
    return schedule.firstWhere(
      (s) => s.weekday == clamped,
      orElse: () => schedule.first,
    );
  }
}

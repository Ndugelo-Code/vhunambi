import 'package:flutter/widgets.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

/// Immutable catalog entry for a Vhunambi Studio V6 genre (`42` total across `5` regions).
@immutable
class StudioGenreEntry {
  final String name;
  final String region;
  final IconData icon;
  final int defaultBpm;
  final String shortTag;

  const StudioGenreEntry({
    required this.name,
    required this.region,
    required this.icon,
    required this.defaultBpm,
    required this.shortTag,
  });
}

/// Ordered regional tabs matching `RegionalGenreSelector` & `GENRE_PRESETS`.
const List<String> kStudioRegions = <String>[
  'South Africa',
  'Africa',
  'Americas',
  'Global',
  'Asia',
];

/// Canonical `42`-genre Studio V6 catalog (`14` SA + `15` Africa + `5` Americas + `5` Global + `3` Asia).
/// Uses Phosphor vector glyphs strictly (zero raw emojis per `STD-UIUX-001`).
const List<StudioGenreEntry> kStudioGenreCatalog = <StudioGenreEntry>[
  // --- South Africa (14) ---
  StudioGenreEntry(
    name: 'Amapiano',
    region: 'South Africa',
    icon: PhosphorIconsFill.musicNotes,
    defaultBpm: 112,
    shortTag: 'Log drum & Rhodes',
  ),
  StudioGenreEntry(
    name: 'Private School Amapiano',
    region: 'South Africa',
    icon: PhosphorIconsFill.pianoKeys,
    defaultBpm: 111,
    shortTag: 'Jazz chords & sax',
  ),
  StudioGenreEntry(
    name: 'Sgija',
    region: 'South Africa',
    icon: PhosphorIconsFill.waveform,
    defaultBpm: 114,
    shortTag: 'Staccato log drum',
  ),
  StudioGenreEntry(
    name: 'Bacardi',
    region: 'South Africa',
    icon: PhosphorIconsFill.speakerHigh,
    defaultBpm: 115,
    shortTag: 'Rolling Tshwane bounce',
  ),
  StudioGenreEntry(
    name: 'Gqom',
    region: 'South Africa',
    icon: PhosphorIconsFill.lightning,
    defaultBpm: 128,
    shortTag: 'Dark Durban sub',
  ),
  StudioGenreEntry(
    name: 'Maskandi',
    region: 'South Africa',
    icon: PhosphorIconsFill.guitar,
    defaultBpm: 128,
    shortTag: 'Fingerpicked acoustic',
  ),
  StudioGenreEntry(
    name: 'Kwaito',
    region: 'South Africa',
    icon: PhosphorIconsFill.vinylRecord,
    defaultBpm: 100,
    shortTag: '90s township groove',
  ),
  StudioGenreEntry(
    name: 'Afro House',
    region: 'South Africa',
    icon: PhosphorIconsFill.globeHemisphereEast,
    defaultBpm: 123,
    shortTag: 'Ancestral congas',
  ),
  StudioGenreEntry(
    name: 'Gospel',
    region: 'South Africa',
    icon: PhosphorIconsFill.sparkle,
    defaultBpm: 105,
    shortTag: 'Organ & choir lift',
  ),
  StudioGenreEntry(
    name: 'Mbaqanga',
    region: 'South Africa',
    icon: PhosphorIconsFill.disc,
    defaultBpm: 118,
    shortTag: 'Township jive horns',
  ),
  StudioGenreEntry(
    name: 'Marabi',
    region: 'South Africa',
    icon: PhosphorIconsRegular.pianoKeys,
    defaultBpm: 114,
    shortTag: 'Golden era jazz',
  ),
  StudioGenreEntry(
    name: 'Bubblegum',
    region: 'South Africa',
    icon: PhosphorIconsRegular.starFour,
    defaultBpm: 118,
    shortTag: '80s synth boogie',
  ),
  StudioGenreEntry(
    name: 'Isicathamiya',
    region: 'South Africa',
    icon: PhosphorIconsRegular.usersThree,
    defaultBpm: 80,
    shortTag: 'Close-harmony choir',
  ),
  StudioGenreEntry(
    name: 'Mbube',
    region: 'South Africa',
    icon: PhosphorIconsFill.microphone,
    defaultBpm: 86,
    shortTag: 'Choral call-response',
  ),

  // --- Africa (15) ---
  StudioGenreEntry(
    name: 'Afrobeats',
    region: 'Africa',
    icon: PhosphorIconsFill.sun,
    defaultBpm: 104,
    shortTag: 'Lagos plucked pocket',
  ),
  StudioGenreEntry(
    name: 'Afro Fusion',
    region: 'Africa',
    icon: PhosphorIconsFill.fire,
    defaultBpm: 105,
    shortTag: 'Guitars & wide choir',
  ),
  StudioGenreEntry(
    name: 'Afro Soul',
    region: 'Africa',
    icon: PhosphorIconsFill.heart,
    defaultBpm: 86,
    shortTag: 'Velvet vocal runs',
  ),
  StudioGenreEntry(
    name: 'Afro Jazz',
    region: 'Africa',
    icon: PhosphorIconsRegular.musicNote,
    defaultBpm: 104,
    shortTag: 'Cape & Joburg brass',
  ),
  StudioGenreEntry(
    name: 'Highlife',
    region: 'Africa',
    icon: PhosphorIconsRegular.guitar,
    defaultBpm: 110,
    shortTag: 'Twin guitars & horns',
  ),
  StudioGenreEntry(
    name: 'Rumba',
    region: 'Africa',
    icon: PhosphorIconsRegular.vinylRecord,
    defaultBpm: 106,
    shortTag: 'Congolese sebene',
  ),
  StudioGenreEntry(
    name: 'Soukous',
    region: 'Africa',
    icon: PhosphorIconsFill.equalizer,
    defaultBpm: 126,
    shortTag: 'Fast Kinshasa dance',
  ),
  StudioGenreEntry(
    name: 'Chimurenga',
    region: 'Africa',
    icon: PhosphorIconsRegular.sparkle,
    defaultBpm: 116,
    shortTag: 'Electric mbira weave',
  ),
  StudioGenreEntry(
    name: 'Kuduro',
    region: 'Africa',
    icon: PhosphorIconsRegular.lightning,
    defaultBpm: 134,
    shortTag: 'Luanda club pulse',
  ),
  StudioGenreEntry(
    name: 'Kizomba',
    region: 'Africa',
    icon: PhosphorIconsRegular.heart,
    defaultBpm: 94,
    shortTag: 'Lusophone slow duet',
  ),
  StudioGenreEntry(
    name: 'Gengetone',
    region: 'Africa',
    icon: PhosphorIconsRegular.speakerHigh,
    defaultBpm: 105,
    shortTag: 'Nairobi bounce',
  ),
  StudioGenreEntry(
    name: 'Ethio-Jazz',
    region: 'Africa',
    icon: PhosphorIconsRegular.broadcast,
    defaultBpm: 96,
    shortTag: 'Tizita organ & horns',
  ),
  StudioGenreEntry(
    name: 'Coupé-Décalé',
    region: 'Africa',
    icon: PhosphorIconsRegular.flame,
    defaultBpm: 122,
    shortTag: 'Abidjan snare rolls',
  ),
  StudioGenreEntry(
    name: 'Bongo Flava',
    region: 'Africa',
    icon: PhosphorIconsRegular.musicNotesSimple,
    defaultBpm: 100,
    shortTag: 'Coastal East Africa',
  ),
  StudioGenreEntry(
    name: 'Afro Drill',
    region: 'Africa',
    icon: PhosphorIconsRegular.waveform,
    defaultBpm: 140,
    shortTag: 'Sliding 808 + log drum',
  ),

  // --- Americas (5) ---
  StudioGenreEntry(
    name: 'Reggae',
    region: 'Americas',
    icon: PhosphorIconsRegular.sunHorizon,
    defaultBpm: 78,
    shortTag: 'Roots one-drop pocket',
  ),
  StudioGenreEntry(
    name: 'Dancehall',
    region: 'Americas',
    icon: PhosphorIconsRegular.speakerHigh,
    defaultBpm: 102,
    shortTag: 'Dembow & sub 808',
  ),
  StudioGenreEntry(
    name: 'Samba',
    region: 'Americas',
    icon: PhosphorIconsRegular.disc,
    defaultBpm: 104,
    shortTag: 'Rio cavaquinho swing',
  ),
  StudioGenreEntry(
    name: 'Afro-Cuban',
    region: 'Americas',
    icon: PhosphorIconsRegular.pianoKeys,
    defaultBpm: 106,
    shortTag: 'Montuno & clave brass',
  ),
  StudioGenreEntry(
    name: 'Gospel Soul',
    region: 'Americas',
    icon: PhosphorIconsFill.crown,
    defaultBpm: 84,
    shortTag: 'Hammond & choir belt',
  ),

  // --- Global (5) ---
  StudioGenreEntry(
    name: 'Hip Hop',
    region: 'Global',
    icon: PhosphorIconsFill.headphones,
    defaultBpm: 92,
    shortTag: 'Crisp drums & 808',
  ),
  StudioGenreEntry(
    name: 'R&B',
    region: 'Global',
    icon: PhosphorIconsRegular.headphones,
    defaultBpm: 82,
    shortTag: 'Silk Rhodes harmonies',
  ),
  StudioGenreEntry(
    name: 'Pop',
    region: 'Global',
    icon: PhosphorIconsRegular.radio,
    defaultBpm: 114,
    shortTag: 'Anthem chorus hooks',
  ),
  StudioGenreEntry(
    name: 'Electronic',
    region: 'Global',
    icon: PhosphorIconsFill.slidersHorizontal,
    defaultBpm: 126,
    shortTag: 'Sidechain synth groove',
  ),
  StudioGenreEntry(
    name: 'Lo-Fi Chill',
    region: 'Global',
    icon: PhosphorIconsRegular.moon,
    defaultBpm: 78,
    shortTag: 'Dusty tape & kalimba',
  ),

  // --- Asia (3) ---
  StudioGenreEntry(
    name: 'K-Pop',
    region: 'Asia',
    icon: PhosphorIconsFill.star,
    defaultBpm: 118,
    shortTag: 'Glossy beat switches',
  ),
  StudioGenreEntry(
    name: 'Bollywood Fusion',
    region: 'Asia',
    icon: PhosphorIconsRegular.musicNotes,
    defaultBpm: 106,
    shortTag: 'Tabla & bansuri',
  ),
  StudioGenreEntry(
    name: 'Afro-Asian Lo-Fi',
    region: 'Asia',
    icon: PhosphorIconsRegular.moonStars,
    defaultBpm: 82,
    shortTag: 'Koto & mbira weave',
  ),
];

/// Returns all genres belonging to [region] (case-insensitive).
List<StudioGenreEntry> genresForRegion(String region) {
  final target = region.trim().toLowerCase();
  return kStudioGenreCatalog
      .where((entry) => entry.region.toLowerCase() == target)
      .toList(growable: false);
}

/// Resolves region for [genre], falling back to `'South Africa'` if custom.
String regionForGenre(String genre) {
  final target = genre.trim().toLowerCase();
  for (final entry in kStudioGenreCatalog) {
    if (entry.name.toLowerCase() == target) return entry.region;
  }
  return 'South Africa';
}

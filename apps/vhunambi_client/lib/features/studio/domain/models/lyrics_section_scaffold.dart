import 'package:flutter/foundation.dart';

import 'lyrics_review_models.dart';

/// Atmosphere descriptor for a specific genre + section type combination,
/// powering 1-tap stanza suggestions in the Guided Lyrics Composer
/// (M10 / REQ-GLC-03).
@immutable
class AtmosphereDescriptor {
  final String label;
  final String emoji;

  const AtmosphereDescriptor({required this.label, required this.emoji});
}

/// Guided composer section configuration: section type, title, prompt copy
/// (M10 / REQ-GLC-02).
@immutable
class LyricsSectionScaffold {
  final LyricsSectionType type;
  final String title;

  /// Coaching copy shown under the section title.
  final String guidanceText;

  /// `true` when the creator may skip this section without harming the song.
  final bool isOptional;

  const LyricsSectionScaffold({
    required this.type,
    required this.title,
    required this.guidanceText,
    this.isOptional = false,
  });
}

/// Fixed sequence of guided composer sections (6 total — REQ-GLC-02).
const List<LyricsSectionScaffold> kGuidedComposerScaffold =
    <LyricsSectionScaffold>[
  LyricsSectionScaffold(
    type: LyricsSectionType.intro,
    title: 'Intro',
    guidanceText: 'Set the scene. Introduce the mood and atmosphere.',
  ),
  LyricsSectionScaffold(
    type: LyricsSectionType.verse,
    title: 'Verse 1',
    guidanceText: 'Tell your story. Develop the narrative.',
  ),
  LyricsSectionScaffold(
    type: LyricsSectionType.chorus,
    title: 'Chorus',
    guidanceText: 'Your hook. The part everyone will remember.',
  ),
  LyricsSectionScaffold(
    type: LyricsSectionType.verse,
    title: 'Verse 2',
    guidanceText: 'Deepen the story. Reveal something new.',
    isOptional: true,
  ),
  LyricsSectionScaffold(
    type: LyricsSectionType.bridge,
    title: 'Bridge',
    guidanceText: 'The emotional turning point. Contrast with the chorus.',
    isOptional: true,
  ),
  LyricsSectionScaffold(
    type: LyricsSectionType.outro,
    title: 'Outro',
    guidanceText: 'Bring it home. Close the song with intention.',
  ),
];

/// Pre-seeded genre atmosphere suggestions keyed by genre → section key →
/// descriptor list (M10 / REQ-GLC-03).
///
/// The composer falls back to the `Amapiano` entry for genres without a
/// dedicated bank.
const Map<String, Map<String, List<AtmosphereDescriptor>>>
    kGenreAtmosphereLibrary =
    <String, Map<String, List<AtmosphereDescriptor>>>{
  'Amapiano': <String, List<AtmosphereDescriptor>>{
    'intro': <AtmosphereDescriptor>[
      AtmosphereDescriptor(label: 'Deep log drum opening', emoji: '🥁'),
      AtmosphereDescriptor(label: 'Soft piano arpeggios', emoji: '🎹'),
      AtmosphereDescriptor(label: 'Township ambient sound bed', emoji: '🏙️'),
      AtmosphereDescriptor(label: 'Gentle fade-in bass pulse', emoji: '🎵'),
    ],
    'verse': <AtmosphereDescriptor>[
      AtmosphereDescriptor(label: 'Rhythmic log drum groove', emoji: '🥁'),
      AtmosphereDescriptor(label: 'Jazz chord stabs', emoji: '🎷'),
      AtmosphereDescriptor(label: 'Steady 4-on-the-floor kick', emoji: '👟'),
    ],
    'chorus': <AtmosphereDescriptor>[
      AtmosphereDescriptor(label: 'Full choir call-and-response', emoji: '🎵'),
      AtmosphereDescriptor(label: 'Log drum build with brass stab', emoji: '🎺'),
      AtmosphereDescriptor(label: 'Melodic vocal hook repeat', emoji: '🎤'),
    ],
    'bridge': <AtmosphereDescriptor>[
      AtmosphereDescriptor(label: 'Stripped-back bass breakdown', emoji: '🎸'),
      AtmosphereDescriptor(label: 'Airy synth pad swell', emoji: '🌌'),
    ],
    'outro': <AtmosphereDescriptor>[
      AtmosphereDescriptor(label: 'Fade-out log drum roll', emoji: '🥁'),
      AtmosphereDescriptor(label: 'Piano resolution chord', emoji: '🎹'),
    ],
  },
  'Gqom': <String, List<AtmosphereDescriptor>>{
    'intro': <AtmosphereDescriptor>[
      AtmosphereDescriptor(label: '808 sub bass build', emoji: '💥'),
      AtmosphereDescriptor(label: 'Dark synth swell', emoji: '🌑'),
      AtmosphereDescriptor(label: 'Metallic clap pattern', emoji: '⚡'),
    ],
    'verse': <AtmosphereDescriptor>[
      AtmosphereDescriptor(label: 'Off-beat drum loop', emoji: '🥁'),
      AtmosphereDescriptor(label: 'Repetitive vocal chant', emoji: '🗣️'),
    ],
    'chorus': <AtmosphereDescriptor>[
      AtmosphereDescriptor(label: 'Distorted bass drop', emoji: '🔊'),
      AtmosphereDescriptor(label: 'Stadium hype chant stack', emoji: '🏟️'),
    ],
    'bridge': <AtmosphereDescriptor>[
      AtmosphereDescriptor(label: 'Sparse siren sweep', emoji: '🚨'),
    ],
    'outro': <AtmosphereDescriptor>[
      AtmosphereDescriptor(label: 'Filtered drum fade', emoji: '🎚️'),
    ],
  },
  'Afrobeats': <String, List<AtmosphereDescriptor>>{
    'intro': <AtmosphereDescriptor>[
      AtmosphereDescriptor(label: 'Bright electric guitar plucks', emoji: '🪕'),
      AtmosphereDescriptor(label: 'Shaker groove build-up', emoji: '🪇'),
    ],
    'verse': <AtmosphereDescriptor>[
      AtmosphereDescriptor(label: 'Afro percussion bounce', emoji: '🥁'),
      AtmosphereDescriptor(label: 'Warm bassline walk', emoji: '🎸'),
    ],
    'chorus': <AtmosphereDescriptor>[
      AtmosphereDescriptor(label: 'Call-and-response hook', emoji: '🎤'),
      AtmosphereDescriptor(label: 'Brass section stab', emoji: '🎺'),
    ],
    'bridge': <AtmosphereDescriptor>[
      AtmosphereDescriptor(label: 'Island percussion break', emoji: '🏝️'),
    ],
    'outro': <AtmosphereDescriptor>[
      AtmosphereDescriptor(label: 'Guitar riff fade-out', emoji: '🪕'),
    ],
  },
  'Maskandi': <String, List<AtmosphereDescriptor>>{
    'intro': <AtmosphereDescriptor>[
      AtmosphereDescriptor(label: 'Solo acoustic guitar picking', emoji: '🎸'),
      AtmosphereDescriptor(label: 'Rolling hills ambience', emoji: '⛰️'),
    ],
    'verse': <AtmosphereDescriptor>[
      AtmosphereDescriptor(label: 'Fast guitar fingerstyle', emoji: '🎸'),
      AtmosphereDescriptor(label: 'Bass guitar gallop', emoji: '🎼'),
    ],
    'chorus': <AtmosphereDescriptor>[
      AtmosphereDescriptor(label: 'Melodic call-and-response', emoji: '🗣️'),
      AtmosphereDescriptor(label: 'Accordion harmony layer', emoji: '🪗'),
    ],
    'bridge': <AtmosphereDescriptor>[
      AtmosphereDescriptor(label: 'Praise-poetry breakdown', emoji: '📜'),
    ],
    'outro': <AtmosphereDescriptor>[
      AtmosphereDescriptor(label: 'Guitar harmonics close', emoji: '✨'),
    ],
  },
  'Gospel': <String, List<AtmosphereDescriptor>>{
    'intro': <AtmosphereDescriptor>[
      AtmosphereDescriptor(label: 'Pipe organ chord swell', emoji: '⛪'),
      AtmosphereDescriptor(label: 'Soft hummed harmony bed', emoji: '🕊️'),
    ],
    'verse': <AtmosphereDescriptor>[
      AtmosphereDescriptor(label: 'Testimony-style lead vocal', emoji: '🎤'),
      AtmosphereDescriptor(label: 'Piano gospel run', emoji: '🎹'),
    ],
    'chorus': <AtmosphereDescriptor>[
      AtmosphereDescriptor(label: 'Full SATB choir stack', emoji: '🎵'),
      AtmosphereDescriptor(label: 'Hand-clap rhythm section', emoji: '👏'),
    ],
    'bridge': <AtmosphereDescriptor>[
      AtmosphereDescriptor(label: 'Key change upward lift', emoji: '📈'),
    ],
    'outro': <AtmosphereDescriptor>[
      AtmosphereDescriptor(label: 'Sustained amen harmony', emoji: '🙌'),
    ],
  },
};

/// (`verse`, `chorus`).
String atmosphereLibraryKeyFor(String scaffoldTitle) {
  final normalized = scaffoldTitle.trim().toLowerCase();
  if (normalized.startsWith('verse')) return 'verse';
  if (normalized.startsWith('chorus')) return 'chorus';
  if (normalized.startsWith('intro')) return 'intro';
  if (normalized.startsWith('bridge')) return 'bridge';
  if (normalized.startsWith('outro')) return 'outro';
  return normalized;
}

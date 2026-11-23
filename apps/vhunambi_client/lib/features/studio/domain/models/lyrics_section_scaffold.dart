import 'package:flutter/widgets.dart';

import '../../../../core/design_system/tokens/app_icons.dart';
import 'lyrics_review_models.dart';

/// Atmosphere descriptor for a specific genre + section type combination,
/// powering 1-tap stanza suggestions in the Guided Lyrics Composer
/// (M10 / REQ-GLC-03).
@immutable
class AtmosphereDescriptor {
  final String label;
  final IconData icon;

  const AtmosphereDescriptor({required this.label, required this.icon});
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
      AtmosphereDescriptor(label: 'Deep log drum opening', icon: AppIcons.drums),
      AtmosphereDescriptor(label: 'Soft piano arpeggios', icon: AppIcons.piano),
      AtmosphereDescriptor(label: 'Township ambient sound bed', icon: AppIcons.waveform),
      AtmosphereDescriptor(label: 'Gentle fade-in bass pulse', icon: AppIcons.songs),
    ],
    'verse': <AtmosphereDescriptor>[
      AtmosphereDescriptor(label: 'Rhythmic log drum groove', icon: AppIcons.drums),
      AtmosphereDescriptor(label: 'Jazz chord stabs', icon: AppIcons.piano),
      AtmosphereDescriptor(label: 'Steady 4-on-the-floor kick', icon: AppIcons.lightning),
    ],
    'chorus': <AtmosphereDescriptor>[
      AtmosphereDescriptor(label: 'Full choir call-and-response', icon: AppIcons.users),
      AtmosphereDescriptor(label: 'Log drum build with brass stab', icon: AppIcons.drums),
      AtmosphereDescriptor(label: 'Melodic vocal hook repeat', icon: AppIcons.vocals),
    ],
    'bridge': <AtmosphereDescriptor>[
      AtmosphereDescriptor(label: 'Stripped-back bass breakdown', icon: AppIcons.guitar),
      AtmosphereDescriptor(label: 'Airy synth pad swell', icon: AppIcons.sparkle),
    ],
    'outro': <AtmosphereDescriptor>[
      AtmosphereDescriptor(label: 'Fade-out log drum roll', icon: AppIcons.drums),
      AtmosphereDescriptor(label: 'Piano resolution chord', icon: AppIcons.piano),
    ],
  },
  'Gqom': <String, List<AtmosphereDescriptor>>{
    'intro': <AtmosphereDescriptor>[
      AtmosphereDescriptor(label: '808 sub bass build', icon: AppIcons.flame),
      AtmosphereDescriptor(label: 'Dark synth swell', icon: AppIcons.waveform),
      AtmosphereDescriptor(label: 'Metallic clap pattern', icon: AppIcons.lightning),
    ],
    'verse': <AtmosphereDescriptor>[
      AtmosphereDescriptor(label: 'Off-beat drum loop', icon: AppIcons.drums),
      AtmosphereDescriptor(label: 'Repetitive vocal chant', icon: AppIcons.mic),
    ],
    'chorus': <AtmosphereDescriptor>[
      AtmosphereDescriptor(label: 'Distorted bass drop', icon: AppIcons.volumeHigh),
      AtmosphereDescriptor(label: 'Stadium hype chant stack', icon: AppIcons.flame),
    ],
    'bridge': <AtmosphereDescriptor>[
      AtmosphereDescriptor(label: 'Sparse siren sweep', icon: AppIcons.lightning),
    ],
    'outro': <AtmosphereDescriptor>[
      AtmosphereDescriptor(label: 'Filtered drum fade', icon: AppIcons.sliders),
    ],
  },
  'Afrobeats': <String, List<AtmosphereDescriptor>>{
    'intro': <AtmosphereDescriptor>[
      AtmosphereDescriptor(label: 'Bright electric guitar plucks', icon: AppIcons.guitar),
      AtmosphereDescriptor(label: 'Shaker groove build-up', icon: AppIcons.drums),
    ],
    'verse': <AtmosphereDescriptor>[
      AtmosphereDescriptor(label: 'Afro percussion bounce', icon: AppIcons.drums),
      AtmosphereDescriptor(label: 'Warm bassline walk', icon: AppIcons.guitar),
    ],
    'chorus': <AtmosphereDescriptor>[
      AtmosphereDescriptor(label: 'Call-and-response hook', icon: AppIcons.vocals),
      AtmosphereDescriptor(label: 'Brass section stab', icon: AppIcons.songs),
    ],
    'bridge': <AtmosphereDescriptor>[
      AtmosphereDescriptor(label: 'Island percussion break', icon: AppIcons.waveform),
    ],
    'outro': <AtmosphereDescriptor>[
      AtmosphereDescriptor(label: 'Guitar riff fade-out', icon: AppIcons.guitar),
    ],
  },
  'Maskandi': <String, List<AtmosphereDescriptor>>{
    'intro': <AtmosphereDescriptor>[
      AtmosphereDescriptor(label: 'Solo acoustic guitar picking', icon: AppIcons.guitar),
      AtmosphereDescriptor(label: 'Rolling hills ambience', icon: AppIcons.waveform),
    ],
    'verse': <AtmosphereDescriptor>[
      AtmosphereDescriptor(label: 'Fast guitar fingerstyle', icon: AppIcons.guitar),
      AtmosphereDescriptor(label: 'Bass guitar gallop', icon: AppIcons.songsOutline),
    ],
    'chorus': <AtmosphereDescriptor>[
      AtmosphereDescriptor(label: 'Melodic call-and-response', icon: AppIcons.vocals),
      AtmosphereDescriptor(label: 'Accordion harmony layer', icon: AppIcons.piano),
    ],
    'bridge': <AtmosphereDescriptor>[
      AtmosphereDescriptor(label: 'Praise-poetry breakdown', icon: AppIcons.voiceClone),
    ],
    'outro': <AtmosphereDescriptor>[
      AtmosphereDescriptor(label: 'Guitar harmonics close', icon: AppIcons.sparkle),
    ],
  },
  'Gospel': <String, List<AtmosphereDescriptor>>{
    'intro': <AtmosphereDescriptor>[
      AtmosphereDescriptor(label: 'Pipe organ chord swell', icon: AppIcons.piano),
      AtmosphereDescriptor(label: 'Soft hummed harmony bed', icon: AppIcons.songsOutline),
    ],
    'verse': <AtmosphereDescriptor>[
      AtmosphereDescriptor(label: 'Testimony-style lead vocal', icon: AppIcons.mic),
      AtmosphereDescriptor(label: 'Piano gospel run', icon: AppIcons.piano),
    ],
    'chorus': <AtmosphereDescriptor>[
      AtmosphereDescriptor(label: 'Full SATB choir stack', icon: AppIcons.users),
      AtmosphereDescriptor(label: 'Hand-clap rhythm section', icon: AppIcons.drums),
    ],
    'bridge': <AtmosphereDescriptor>[
      AtmosphereDescriptor(label: 'Key change upward lift', icon: AppIcons.analytics),
    ],
    'outro': <AtmosphereDescriptor>[
      AtmosphereDescriptor(label: 'Sustained amen harmony', icon: AppIcons.sparkle),
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

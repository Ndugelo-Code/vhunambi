import 'package:flutter/foundation.dart';

/// Standardized micro-preview metadata anchored to a complex studio option
/// (M10 / REQ-OPT-01 → REQ-OPT-04).
@immutable
class OptionPreviewDescriptor {
  /// Thematic emoji representing the acoustic character of the option.
  final String emoji;

  /// Human readable headline, e.g. `Slow (60–80 BPM)`.
  final String title;

  /// Max 2 sentences describing what the option does sonically.
  final String description;

  /// 2–3 genres this option suits best (`['Any']` for universal options).
  final List<String> bestForGenres;

  const OptionPreviewDescriptor({
    required this.emoji,
    required this.title,
    required this.description,
    required this.bestForGenres,
  });
}

/// Compile-time constant library of all studio option previews (M10).
///
/// Keys follow the `<group>_<enumName>` convention (`tempo_slow`,
/// `vocalMode_rap`, `vocalEnergy_soft`, `structure_loop`,
/// `lyricsMode_myOwn`) so widget keys and provider values stay traceable.
const Map<String, OptionPreviewDescriptor> kStudioOptionPreviews =
    <String, OptionPreviewDescriptor>{
  // ── TempoBracket ────────────────────────────────────────────
  'tempo_slow': OptionPreviewDescriptor(
    emoji: '🌊',
    title: 'Slow (60–80 BPM)',
    description: 'Relaxed, introspective pace giving vocals space to breathe. '
        'Ideal for soulful ballads and spiritual reflection.',
    bestForGenres: ['Maskandi', 'Afro Soul', 'Gospel'],
  ),
  'tempo_medium': OptionPreviewDescriptor(
    emoji: '🎵',
    title: 'Medium (80–120 BPM)',
    description: 'The sweet spot for most African popular music. '
        'Energetic yet comfortable for melodic phrasing and hook delivery.',
    bestForGenres: ['Amapiano', 'Afrobeats', 'R&B'],
  ),
  'tempo_fast': OptionPreviewDescriptor(
    emoji: '⚡',
    title: 'Fast (120–145 BPM)',
    description: 'High-energy club tempo driving dancefloor movement. '
        'Vocals need tight delivery with minimal breath pauses.',
    bestForGenres: ['Afro House', 'Kwaito', 'Dancehall'],
  ),
  'tempo_veryFast': OptionPreviewDescriptor(
    emoji: '🔥',
    title: 'Hyperspeed (145+ BPM)',
    description: 'Extreme BPM for percussion-heavy electronic club bangers. '
        'Vocals are often chanted, not sung.',
    bestForGenres: ['Gqom', 'Electronic', 'Hip Hop'],
  ),

  // ── VocalMode ────────────────────────────────────────────────
  'vocalMode_auto': OptionPreviewDescriptor(
    emoji: '✦',
    title: 'Auto',
    description: 'The AI selects the most genre-appropriate vocal delivery '
        'style. Best for beginners or when you want the system to decide.',
    bestForGenres: ['Any'],
  ),
  'vocalMode_melodic': OptionPreviewDescriptor(
    emoji: '🎤',
    title: 'Melodic Singing',
    description: 'Traditional sustained notes and melodic phrasing with '
        'vibrato and runs. The most expressive delivery mode.',
    bestForGenres: ['Amapiano', 'Afro Soul', 'Gospel'],
  ),
  'vocalMode_rap': OptionPreviewDescriptor(
    emoji: '🎙️',
    title: 'Rap / Flow',
    description: 'Rhythmic syllabic delivery emphasizing timing, rhyme, and '
        'lyrical density. Sits in the pocket of the beat.',
    bestForGenres: ['Hip Hop', 'Gqom', 'Afrobeats'],
  ),
  'vocalMode_spokenWord': OptionPreviewDescriptor(
    emoji: '📢',
    title: 'Spoken Word',
    description: 'Rhythmic non-melodic delivery close to traditional oral '
        'storytelling (izibongo). Powerful for praise singing.',
    bestForGenres: ['Maskandi', 'Afro Soul', 'Any'],
  ),
  'vocalMode_choir': OptionPreviewDescriptor(
    emoji: '🎵',
    title: 'Choir / Harmonies',
    description: 'Multi-part harmonic vocal stacking simulating a full gospel '
        'or traditional choir. Rich, layered, and communal.',
    bestForGenres: ['Gospel', 'Afro Soul', 'Maskandi'],
  ),

  // ── VocalEnergy ──────────────────────────────────────────────
  'vocalEnergy_soft': OptionPreviewDescriptor(
    emoji: '🌙',
    title: 'Soft / Intimate',
    description: 'Breathy, close-mic delivery evoking vulnerability and '
        'intimacy. Perfect for late-night reflective tracks.',
    bestForGenres: ['Afro Soul', 'R&B', 'Amapiano'],
  ),
  'vocalEnergy_mid': OptionPreviewDescriptor(
    emoji: '🎤',
    title: 'Balanced',
    description: 'Versatile mid-energy delivery that works across most '
        'genres and moods. Neither too restrained nor too intense.',
    bestForGenres: ['Amapiano', 'Afrobeats', 'Any'],
  ),
  'vocalEnergy_intense': OptionPreviewDescriptor(
    emoji: '🔥',
    title: 'High Intensity',
    description: 'Full-projection powerful delivery with grit and urgency. '
        'Best for anthems, hype tracks, and praise songs.',
    bestForGenres: ['Gqom', 'Gospel', 'Hip Hop'],
  ),

  // ── SongStructure ────────────────────────────────────────────
  'structure_standard': OptionPreviewDescriptor(
    emoji: '📋',
    title: 'Standard',
    description: 'Classic Intro → Verse → Chorus → Verse → Chorus → Outro '
        'structure. The most radio-friendly format.',
    bestForGenres: ['Amapiano', 'Afrobeats', 'R&B'],
  ),
  'structure_extended': OptionPreviewDescriptor(
    emoji: '⏱️',
    title: 'Extended',
    description: 'Adds a Bridge and additional verse for a longer narrative '
        'arc. Good for concept songs and storytelling.',
    bestForGenres: ['Maskandi', 'Gospel', 'Afro Soul'],
  ),
  'structure_freestyle': OptionPreviewDescriptor(
    emoji: '🌊',
    title: 'Freestyle',
    description: 'Unstructured flow — the AI generates sections dynamically '
        'based on lyrical energy. Experimental.',
    bestForGenres: ['Hip Hop', 'Electronic', 'Any'],
  ),
  'structure_loop': OptionPreviewDescriptor(
    emoji: '🔁',
    title: 'Loop',
    description: 'Single repeated section with variation — great for DJ '
        'tools, hooklines, and interludes. Typically 30–60 seconds.',
    bestForGenres: ['Gqom', 'Afro House', 'Electronic'],
  ),

  // ── LyricsMode ───────────────────────────────────────────────
  'lyricsMode_aiWrite': OptionPreviewDescriptor(
    emoji: '✨',
    title: 'AI Writes',
    description: 'The AI generates culturally relevant lyrics from your '
        'prompt and genre. You review and edit before generation.',
    bestForGenres: ['Any'],
  ),
  'lyricsMode_myOwn': OptionPreviewDescriptor(
    emoji: '✍️',
    title: 'My Own Lyrics',
    description: 'You write every lyric line — freeform or with the '
        'step-by-step Guided Composer. Full creative control.',
    bestForGenres: ['Any'],
  ),
  'lyricsMode_fromPhoto': OptionPreviewDescriptor(
    emoji: '📷',
    title: 'From Photo',
    description: 'Import lyrics from a handwritten or printed page via '
        'camera capture. OCR extracts the text automatically.',
    bestForGenres: ['Any'],
  ),
  'lyricsMode_instrumental': OptionPreviewDescriptor(
    emoji: '🎹',
    title: 'Instrumental',
    description: 'No vocals — pure instrumental arrangement based on genre, '
        'tempo, and mood. Perfect for beats and stems.',
    bestForGenres: ['Amapiano', 'Gqom', 'Afro House'],
  ),
};

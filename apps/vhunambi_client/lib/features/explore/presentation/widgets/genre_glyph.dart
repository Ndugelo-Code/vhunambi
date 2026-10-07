import 'package:flutter/material.dart';

/// Maps an African genre to its centered instrument glyph token.
/// Reference: `docs/foundation_blueprints/01_EXPLORE_PAGE_SPEC.md` §5 Section B.
IconData exploreGenreGlyph(String genre) {
  return switch (genre.toLowerCase().trim()) {
    'amapiano' => Icons.piano_rounded,
    'kwaito' => Icons.graphic_eq_rounded,
    'gqom' => Icons.waves_rounded,
    'maskandi' => Icons.music_note_rounded,
    'mbaqanga' => Icons.audiotrack_rounded,
    'marabi' => Icons.piano_rounded,
    'bubblegum' => Icons.album_rounded,
    'afro house' || 'afrohouse' => Icons.nightlife_rounded,
    'afrobeats' => Icons.speaker_rounded,
    'afro jazz' || 'afrojazz' => Icons.piano_rounded,
    'afro soul' || 'afrosoul' => Icons.mic_rounded,
    'afro-arabic' || 'afro arabic' => Icons.graphic_eq_rounded,
    'instrumental' => Icons.graphic_eq_rounded,
    _ => Icons.music_note_rounded,
  };
}

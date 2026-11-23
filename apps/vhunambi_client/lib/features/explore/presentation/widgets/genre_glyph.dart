import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

/// Maps an African genre to its centered instrument glyph token.
/// Reference: `docs/foundation_blueprints/01_EXPLORE_PAGE_SPEC.md` §5 Section B.
IconData exploreGenreGlyph(String genre) {
  return switch (genre.toLowerCase().trim()) {
    'amapiano' => PhosphorIconsRegular.pianoKeys,
    'kwaito' => PhosphorIconsRegular.waveform,
    'gqom' => PhosphorIconsRegular.waves,
    'maskandi' => PhosphorIconsRegular.musicNote,
    'mbaqanga' => PhosphorIconsRegular.musicNotesSimple,
    'marabi' => PhosphorIconsRegular.pianoKeys,
    'bubblegum' => PhosphorIconsRegular.vinylRecord,
    'afro house' || 'afrohouse' => PhosphorIconsRegular.disc,
    'afrobeats' => PhosphorIconsRegular.speakerHigh,
    'afro jazz' || 'afrojazz' => PhosphorIconsRegular.pianoKeys,
    'afro soul' || 'afrosoul' => PhosphorIconsRegular.microphoneStage,
    'afro-arabic' || 'afro arabic' => PhosphorIconsRegular.waveform,
    'instrumental' => PhosphorIconsRegular.waveform,
    _ => PhosphorIconsRegular.musicNote,
  };
}

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/repositories/in_memory_beat_repository.dart';
import '../domain/models/producer_beat_entity.dart';

/// Genre + musical key catalogs and the regional artwork gradient used by the
/// Producer Beats Vault (Blueprint 14 §2.1 / Blueprint 05 §2.2).

/// Twelve curated African genres backing the beat authoring dropdown.
const List<String> beatGenreCatalog = <String>[
  'Amapiano',
  'Kwaito',
  'Gqom',
  'Maskandi',
  'Mbaqanga',
  'Marabi',
  'Bubblegum',
  'Afro House',
  'Afrobeats',
  'Afro Jazz',
  'Afro Soul',
  'Afro-Arabic',
];

/// Musical keys offered by the authoring dialog (12 roots × 2 modes).
const List<String> beatMusicalKeyCatalog = <String>[
  'F# Minor',
  'A Minor',
  'C Major',
  'G Minor',
  'D Minor',
  'E Minor',
  'B Minor',
  'Eb Minor',
  'Ab Major',
  'Bb Major',
  'D Major',
  'G Major',
];

/// Credit price presets surfaced by the authoring dialog.
const List<int> beatPricePresets = <int>[5, 10, 15, 20, 30, 50];

/// Regional genre gradient rendered by `BeatCard` and the cockpit hero.
///
/// Every stop resolves through `AppColors` so the vault never emits a raw hex
/// value (Blueprint 14 §3).
List<Color> beatGenreGradient(String genre) {
  return switch (genre) {
    'Amapiano' => const <Color>[AppColors.brandPrimary, AppColors.amberInset],
    'Kwaito' => const <Color>[AppColors.coinGold, AppColors.amberInset],
    'Gqom' => const <Color>[AppColors.badgeCyan, AppColors.badgeCyanBg],
    'Maskandi' => const <Color>[AppColors.success, AppColors.surfaceSecondary],
    'Mbaqanga' => const <Color>[AppColors.brandPrimaryDark, AppColors.amberInset],
    'Marabi' => const <Color>[AppColors.coinGold, AppColors.surfaceSecondary],
    'Bubblegum' => const <Color>[AppColors.brandPrimary, AppColors.surfaceSecondary],
    'Afro House' => const <Color>[AppColors.brandPrimaryDark, AppColors.badgeCyanBg],
    'Afrobeats' => const <Color>[AppColors.coinGold, AppColors.brandPrimaryDark],
    'Afro Jazz' => const <Color>[AppColors.badgeCyan, AppColors.surfaceSecondary],
    'Afro Soul' => const <Color>[AppColors.success, AppColors.badgeCyanBg],
    'Afro-Arabic' => const <Color>[AppColors.brandPrimary, AppColors.badgeCyanBg],
    _ => const <Color>[AppColors.borderActive, AppColors.surfaceSecondary],
  };
}

/// Clamps a free-text / tap-tempo BPM into the supported 40–260 range.
int clampBeatBpm(int bpm) {
  if (bpm < minBeatBpm) return minBeatBpm;
  if (bpm > maxBeatBpm) return maxBeatBpm;
  return bpm;
}

/// Splits a comma separated tag field into trimmed, de-duplicated tags.
List<String> parseBeatTags(String raw) {
  final seen = <String>{};
  final tags = <String>[];
  for (final part in raw.split(',')) {
    final tag = part.trim();
    if (tag.isEmpty) continue;
    if (seen.add(tag.toLowerCase())) tags.add(tag);
  }
  return List<String>.unmodifiable(tags);
}

/// CDN origin for previews authored inside the Producer Beats Vault.
const String beatPreviewOrigin = beatCdnOrigin;

/// Deterministic CDN preview URL derived from the beat title (REQ-BEAT-18).
String beatPreviewUrlFor(String title) {
  final slug = title
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return '$beatPreviewOrigin/${slug.isEmpty ? 'untitled-beat' : slug}.mp3';
}

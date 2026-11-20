import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/design_system/tokens/design_enums.dart';

/// Canonical 6-mood wire taxonomy unifying `design_enums.dart`, `StudioFormState`,
/// `exploreMoodFilterProvider`, `TrackDetailEntity`, and `apps/vhunambi_api`
/// (`EP-P70-MOOD-TAXONOMY`, `REQ-P70-MOOD-01..03`).
enum VhunambiMood {
  uplifting(
    moodId: 'uplifting',
    label: 'Uplifting',
    icon: PhosphorIconsFill.sunHorizon,
    accentColor: Color(0xFFF59E0B),
  ),
  soulful(
    moodId: 'soulful',
    label: 'Soulful',
    icon: PhosphorIconsFill.heartHalf,
    accentColor: Color(0xFFD97706),
  ),
  energetic(
    moodId: 'energetic',
    label: 'Energetic',
    icon: PhosphorIconsFill.lightning,
    accentColor: Color(0xFFEF4444),
  ),
  chill(
    moodId: 'chill',
    label: 'Chill',
    icon: PhosphorIconsFill.moonStars,
    accentColor: Color(0xFF0EA5E9),
  ),
  hypnotic(
    moodId: 'hypnotic',
    label: 'Hypnotic',
    icon: PhosphorIconsFill.spiral,
    accentColor: Color(0xFF7C3AED),
  ),
  romantic(
    moodId: 'romantic',
    label: 'Romantic',
    icon: PhosphorIconsFill.sparkle,
    accentColor: Color(0xFFEC4899),
  );

  final String moodId;
  final String label;
  final IconData icon;
  final Color accentColor;

  const VhunambiMood({
    required this.moodId,
    required this.label,
    required this.icon,
    required this.accentColor,
  });

  /// Lossless normalizer absorbing all legacy Studio, Explore, Design Enum,
  /// and backend (`edge_persistence_bridge.ts`) mood strings (`REQ-P70-MOOD-02`).
  static VhunambiMood normalize(String? raw) {
    return tryNormalize(raw) ?? VhunambiMood.uplifting;
  }

  /// Strict variant returning `null` for empty or unrecognized mood labels
  /// (e.g. `'Angry'`, `'Mysterious'`) so catalog filters do not alias them to
  /// `'Uplifting'`.
  static VhunambiMood? tryNormalize(String? raw) {
    final cleaned = (raw ?? '').trim().toLowerCase();
    if (cleaned.isEmpty) return null;

    return switch (cleaned) {
      'uplifting' || 'vibrant' || 'joyful' || 'happy' || 'celebratory' =>
        VhunambiMood.uplifting,
      'soulful' ||
      'soulful & nostalgic' ||
      'nostalgic' ||
      'melancholic' ||
      'warm' ||
      'reflective' =>
        VhunambiMood.soulful,
      'energetic' || 'electrifying' || 'party' || 'hype' || 'club' =>
        VhunambiMood.energetic,
      'chill' || 'peaceful' || 'calm' || 'relaxed' || 'laid-back' =>
        VhunambiMood.chill,
      'hypnotic' || 'deep' || 'dark' || 'atmospheric' || 'minimal' =>
        VhunambiMood.hypnotic,
      'romantic' || 'sensual' || 'intimate' || 'love' =>
        VhunambiMood.romantic,
      _ => _fuzzyMatch(cleaned),
    };
  }

  static VhunambiMood? _fuzzyMatch(String cleaned) {
    if (cleaned.contains('soul') ||
        cleaned.contains('nostalg') ||
        cleaned.contains('melanchol')) {
      return VhunambiMood.soulful;
    }
    if (cleaned.contains('energ') ||
        cleaned.contains('party') ||
        cleaned.contains('electr')) {
      return VhunambiMood.energetic;
    }
    if (cleaned.contains('chill') ||
        cleaned.contains('calm') ||
        cleaned.contains('peace')) {
      return VhunambiMood.chill;
    }
    if (cleaned.contains('hypno') ||
        cleaned.contains('deep') ||
        cleaned.contains('dark') ||
        cleaned.contains('atmos')) {
      return VhunambiMood.hypnotic;
    }
    if (cleaned.contains('roman')) {
      return VhunambiMood.romantic;
    }
    return null;
  }

  /// Bridges legacy onboarding [Mood] enum values into canonical [VhunambiMood].
  static VhunambiMood fromLegacyMood(Mood legacy) {
    return switch (legacy) {
      Mood.joyful => VhunambiMood.uplifting,
      Mood.melancholic => VhunambiMood.soulful,
      Mood.energetic => VhunambiMood.energetic,
      Mood.calm => VhunambiMood.chill,
      Mood.romantic => VhunambiMood.romantic,
    };
  }

  /// Projects canonical [VhunambiMood] back onto legacy [Mood] for `MoodColorChip`.
  Mood toLegacyMood() {
    return switch (this) {
      VhunambiMood.uplifting => Mood.joyful,
      VhunambiMood.soulful => Mood.melancholic,
      VhunambiMood.energetic => Mood.energetic,
      VhunambiMood.chill => Mood.calm,
      VhunambiMood.hypnotic => Mood.calm,
      VhunambiMood.romantic => Mood.romantic,
    };
  }
}

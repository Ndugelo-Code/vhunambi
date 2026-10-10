import 'package:flutter/foundation.dart';

/// Selectable typography animation styles for the karaoke lyrics overlay.
enum LyricTypographyPreset {
  kineticBounce,
  luminousGlow,
  minimalSubtitle,
  bantuCalligraphy;

  String get label => switch (this) {
        LyricTypographyPreset.kineticBounce => 'Kinetic Bounce',
        LyricTypographyPreset.luminousGlow => 'Luminous Glow',
        LyricTypographyPreset.minimalSubtitle => 'Minimal Subtitle',
        LyricTypographyPreset.bantuCalligraphy => 'Bantu Calligraphy',
      };

  String get description => switch (this) {
        LyricTypographyPreset.kineticBounce =>
          'High-energy 1.15x word pop with Brand Amber glow',
        LyricTypographyPreset.luminousGlow =>
          'Radial atmospheric blur glow in title case',
        LyricTypographyPreset.minimalSubtitle =>
          'Crisp lower-third glass banner with karaoke sweep',
        LyricTypographyPreset.bantuCalligraphy =>
          'Stylized serif headline with dynamic underline',
      };
}

/// Duration bracket presets for short-form social video export.
enum DurationPreset {
  hook15s,
  reel30s,
  fullTrack;

  int get targetSeconds => switch (this) {
        DurationPreset.hook15s => 15,
        DurationPreset.reel30s => 30,
        DurationPreset.fullTrack => 180,
      };

  String get label => switch (this) {
        DurationPreset.hook15s => '15s Hook',
        DurationPreset.reel30s => '30s Reel',
        DurationPreset.fullTrack => 'Full Track',
      };
}

/// Visual overlay shaders and atmospheric enhancements.
@immutable
class AtmosphericEffects {
  final bool filmGrain;
  final bool bassPulse;
  final bool kenBurnsMotion;

  const AtmosphericEffects({
    this.filmGrain = true,
    this.bassPulse = true,
    this.kenBurnsMotion = true,
  });

  AtmosphericEffects copyWith({
    bool? filmGrain,
    bool? bassPulse,
    bool? kenBurnsMotion,
  }) =>
      AtmosphericEffects(
        filmGrain: filmGrain ?? this.filmGrain,
        bassPulse: bassPulse ?? this.bassPulse,
        kenBurnsMotion: kenBurnsMotion ?? this.kenBurnsMotion,
      );

  Map<String, dynamic> toJson() => {
        'filmGrain': filmGrain,
        'bassPulse': bassPulse,
        'kenBurnsMotion': kenBurnsMotion,
      };

  factory AtmosphericEffects.fromJson(Map<String, dynamic> json) =>
      AtmosphericEffects(
        filmGrain: json['filmGrain'] as bool? ?? true,
        bassPulse: json['bassPulse'] as bool? ?? true,
        kenBurnsMotion: json['kenBurnsMotion'] as bool? ?? true,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AtmosphericEffects &&
          runtimeType == other.runtimeType &&
          filmGrain == other.filmGrain &&
          bassPulse == other.bassPulse &&
          kenBurnsMotion == other.kenBurnsMotion;

  @override
  int get hashCode => Object.hash(filmGrain, bassPulse, kenBurnsMotion);
}

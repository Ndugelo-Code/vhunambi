import 'package:flutter/material.dart';
import 'contrast_utils.dart';

/// Immutable design token holding a complete color set for a Genre or Mood.
///
/// All fields are [Color] values derived from the Vhunambi design system
/// (see `docs/foundation_blueprints/00_SYSTEM_DESIGN_TOKENS.md`).
@immutable
class ColorToken {
  /// Primary accent color used for emphasis and selected states.
  final Color accent;

  /// Surface tint color applied to backgrounds to indicate state.
  final Color surfaceTint;

  /// Glow color used for visual effects like shadows and highlights.
  final Color glow;

  /// Text color computed for WCAG AA contrast against [surfaceTint].
  final Color textColor;

  const ColorToken({
    required this.accent,
    required this.surfaceTint,
    required this.glow,
    required this.textColor,
  });

  /// Creates a [ColorToken] with automatic [textColor] calculation based on
  /// the luminance of [accent]. Light accents get dark text, dark accents
  /// get light text.
  factory ColorToken.auto({
    required Color accent,
    required Color surfaceTint,
    required Color glow,
  }) {
    final luminance = ContrastUtils.relativeLuminance(accent);
    final textColor = luminance > 0.5 ? Colors.black : Colors.white;
    return ColorToken(
      accent: accent,
      surfaceTint: surfaceTint,
      glow: glow,
      textColor: textColor,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ColorToken &&
          runtimeType == other.runtimeType &&
          accent == other.accent &&
          surfaceTint == other.surfaceTint &&
          glow == other.glow &&
          textColor == other.textColor;

  @override
  int get hashCode => Object.hash(accent, surfaceTint, glow, textColor);

  @override
  String toString() =>
      'ColorToken(accent: $accent, surfaceTint: $surfaceTint, '
      'glow: $glow, textColor: $textColor)';
}
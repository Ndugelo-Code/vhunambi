import 'package:flutter/material.dart';

/// Vhunambi Design System Color Tokens supporting both the "Obsidian Studio"
/// Dark Palette and the "Warm African Daylight" Light Palette.
/// Reference: docs/foundation_blueprints/00_SYSTEM_DESIGN_TOKENS.md
abstract final class AppColors {
  // Current active brightness state (defaults to Dark Mode)
  static Brightness _currentBrightness = Brightness.dark;

  /// Synchronizes dynamic color tokens with the active [brightness].
  static void syncWithBrightness(Brightness brightness) {
    _currentBrightness = brightness;
  }

  /// Whether the active resolved palette is in dark mode.
  static bool get isDark => _currentBrightness == Brightness.dark;

  /// Active resolved brightness.
  static Brightness get currentBrightness => _currentBrightness;

  // --------------------------------------------------------------------------
  // Explicit Palette Definitions (Obsidian Studio vs Warm African Daylight)
  // --------------------------------------------------------------------------

  // Dark Palette ("Obsidian Studio")
  static const Color darkSurfaceCanvas = Color(
    0xFF0A0A0C,
  ); // Pitch Black canvas
  static const Color darkSurfaceElevated = Color(
    0xFF141418,
  ); // Dark Charcoal elevated card
  static const Color darkSurfaceSecondary = Color(
    0xFF1B1B22,
  ); // Inset container / chips
  static const Color darkSurfaceModal = Color(
    0xFF16161C,
  ); // Modal sheet / popover surface
  static const Color darkBorderSubtle = Color(
    0xFF2D2D38,
  ); // Standard 1px card/divider border
  static const Color darkBorderActive = Color(
    0xFF4B4B5A,
  ); // Focused input / hover outline
  static const Color darkTextPrimary = Color(
    0xFFFFFFFF,
  ); // High-contrast headers & titles
  static const Color darkTextSecondary = Color(
    0xFFA1A1AA,
  ); // Slate muted metadata & creators
  static const Color darkTextTertiary = Color(
    0xFF6B7280,
  ); // Placeholder hints & timestamps

  // Light Palette ("Warm African Daylight")
  static const Color lightSurfaceCanvas = Color(
    0xFFF7F5F0,
  ); // Warm Ivory Canvas
  static const Color lightSurfaceElevated = Color(
    0xFFFFFFFF,
  ); // Crisp White Card
  static const Color lightSurfaceSecondary = Color(
    0xFFEDEAE2,
  ); // Soft Sand Inset / Chips
  static const Color lightSurfaceModal = Color(0xFFFAF8F5); // Light Warm Modal
  static const Color lightBorderSubtle = Color(0xFFDFDBD0); // Warm Stone Border
  static const Color lightBorderActive = Color(0xFFB5B0A2); // Active Border
  static const Color lightTextPrimary = Color(0xFF121216); // Deep Charcoal Text
  static const Color lightTextSecondary = Color(0xFF52525E); // Slate Muted Text
  static const Color lightTextTertiary = Color(
    0xFF8A8A96,
  ); // Warm Muted Hint Text

  // --------------------------------------------------------------------------
  // Surfaces & Canvases (Compile-Time Const Defaults)
  // --------------------------------------------------------------------------
  static const Color surfaceCanvas    = darkSurfaceCanvas;
  static const Color surfaceElevated  = darkSurfaceElevated;
  static const Color surfaceSecondary = darkSurfaceSecondary;
  static const Color surfaceModal     = darkSurfaceModal;

  // --------------------------------------------------------------------------
  // Borders & Dividers (Compile-Time Const Defaults)
  // --------------------------------------------------------------------------
  static const Color borderSubtle     = darkBorderSubtle;
  static const Color borderActive     = darkBorderActive;

  // --------------------------------------------------------------------------
  // Text Tokens (Compile-Time Const Defaults)
  // --------------------------------------------------------------------------
  static const Color textPrimary      = darkTextPrimary;
  static const Color textSecondary    = darkTextSecondary;
  static const Color textTertiary     = darkTextTertiary;

  // --------------------------------------------------------------------------
  // Contextual Dynamic Adapters (Auto-Switching based on Theme)
  // --------------------------------------------------------------------------
  static Color surfaceCanvasOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkSurfaceCanvas
          : lightSurfaceCanvas;

  static Color surfaceElevatedOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkSurfaceElevated
          : lightSurfaceElevated;

  static Color surfaceSecondaryOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkSurfaceSecondary
          : lightSurfaceSecondary;

  static Color surfaceModalOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkSurfaceModal
          : lightSurfaceModal;

  static Color borderSubtleOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkBorderSubtle
          : lightBorderSubtle;

  static Color textPrimaryOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkTextPrimary
          : lightTextPrimary;

  static Color textSecondaryOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkTextSecondary
          : lightTextSecondary;

  // --------------------------------------------------------------------------
  // Invariant Brand Accents & Tokens (Vibrant in both modes)
  // --------------------------------------------------------------------------
  static const Color brandPrimary = Color(0xFFF97316); // Vibrant Amber / Orange
  static const Color brandPrimaryDark = Color(
    0xFFEA580C,
  ); // Pressed / Hovered state
  static const Color brandContrast = Color(
    0xFF000000,
  ); // Pure black on brandPrimary CTAs

  // Badges & Status
  static const Color badgeCyan = Color(0xFF22D3EE); // "NEW" Drop text & border
  static const Color badgeCyanBg = Color(
    0xFF0E3842,
  ); // "NEW" Drop pill background
  static const Color streakFire = Color(
    0xFFEA580C,
  ); // Gamification streak flame
  static const Color coinGold = Color(
    0xFFF59E0B,
  ); // Marketplace credit coin emblem
  static const Color success = Color(0xFF10B981); // Live status indicator
  static const Color error = Color(0xFFEF4444); // Error / destructive action
  static const Color textInverse = Color(
    0xFF000000,
  ); // Inverse text on solid orange

  // Amber Glow for Callouts & Banners
  static const Color amberGlow = Color(0x1AF97316);
  static const Color amberInset = Color(0xFF3A2508);

  // Semantic Accent Tokens (M8 Notifications / Foundation Blueprint §1.2)
  static const Color accentElectric = Color(
    0xFF8B5CF6,
  ); // Social / Electric Purple
  static const Color accentGold = Color(0xFFF59E0B); // System / Warm Gold
  static const Color accentSuccess = Color(
    0xFF10B981,
  ); // Algorithmic / Mint Green
}

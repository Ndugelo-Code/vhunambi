import 'package:flutter/material.dart';

/// Vhunambi Design System Color Tokens extracted from production at https://vhunambi.com
/// Reference: docs/foundation_blueprints/00_SYSTEM_DESIGN_TOKENS.md
abstract final class AppColors {
  // Surfaces & Canvases
  static const Color surfaceCanvas    = Color(0xFF0A0A0C); // Pitch Black canvas
  static const Color surfaceElevated  = Color(0xFF141418); // Dark Charcoal elevated card
  static const Color surfaceSecondary = Color(0xFF1B1B22); // Inset container / chips
  static const Color surfaceModal     = Color(0xFF16161C); // Modal sheet / popover surface

  // Borders & Dividers
  static const Color borderSubtle     = Color(0xFF2D2D38); // Standard 1px card/divider border
  static const Color borderActive     = Color(0xFF4B4B5A); // Focused input / hover outline

  // Brand Accents
  static const Color brandPrimary     = Color(0xFFF97316); // Vibrant Amber / Orange
  static const Color brandPrimaryDark = Color(0xFFEA580C); // Pressed / Hovered state
  static const Color brandContrast    = Color(0xFF000000); // Pure black on brandPrimary CTAs

  // Badges & Status
  static const Color badgeCyan        = Color(0xFF22D3EE); // "NEW" Drop text & border
  static const Color badgeCyanBg      = Color(0xFF0E3842); // "NEW" Drop pill background
  static const Color streakFire       = Color(0xFFEA580C); // Gamification streak flame
  static const Color coinGold         = Color(0xFFF59E0B); // Marketplace credit coin emblem
  static const Color success          = Color(0xFF10B981); // Live status indicator
  static const Color error            = Color(0xFFEF4444); // Error / destructive action

  // Text Colors
  static const Color textPrimary      = Color(0xFFFFFFFF); // High-contrast headers & titles
  static const Color textSecondary    = Color(0xFF9CA3AF); // Slate muted metadata & creators
  static const Color textTertiary     = Color(0xFF6B7280); // Placeholder hints & timestamps
  static const Color textInverse      = Color(0xFF000000); // Inverse text on solid orange

  // Amber Glow for Callouts & Banners
  static const Color amberGlow        = Color(0x1AF97316);
  static const Color amberInset       = Color(0xFF3A2508);
}

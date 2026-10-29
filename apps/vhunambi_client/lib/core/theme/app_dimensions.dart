import 'package:flutter/material.dart';

/// Corner Radii, Elevation & Padding Tokens
/// Reference: docs/foundation_blueprints/00_SYSTEM_DESIGN_TOKENS.md
abstract final class AppRadius {
  static const double pill  = 9999.0;
  static const double modal = 24.0;
  static const double card  = 16.0;
  static const double input = 12.0;
  static const double thumb = 8.0;
  static const double sm    = 6.0;

  /// 48x48 vault empty-state glyph squircle container (Blueprint 04 §3.1).
  static const double squircle = 14.0;

  static const BorderRadius pillBorder  = BorderRadius.all(Radius.circular(pill));
  static const BorderRadius modalBorder = BorderRadius.vertical(top: Radius.circular(modal));
  static const BorderRadius cardBorder  = BorderRadius.all(Radius.circular(card));
  static const BorderRadius inputBorder = BorderRadius.all(Radius.circular(input));
  static const BorderRadius buttonBorder = inputBorder;
  static const BorderRadius thumbBorder = BorderRadius.all(Radius.circular(thumb));
  static const BorderRadius squircleBorder = BorderRadius.all(Radius.circular(squircle));
}

abstract final class AppSpacing {
  static const double xxs     = 4.0;
  static const double xs      = 8.0;
  static const double sm      = 12.0;
  static const double md      = 16.0;
  static const double lg      = 20.0;
  static const double xl      = 24.0;
  static const double xxl     = 32.0;
  static const double section = 40.0;
}

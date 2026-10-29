import 'dart:math' as math;
import 'package:flutter/material.dart';

/// WCAG contrast ratio calculation utilities.
///
/// Provides pure functions for computing contrast ratios between colors
/// following the WCAG 2.1 formula. No widget or platform dependencies.
abstract final class ContrastUtils {
  /// Calculates the contrast ratio between foreground and background colors
  /// (returns a value from 1.0 to 21.0).
  ///
  /// Follows the WCAG 2.1 relative luminance formula:
  /// (L1 + 0.05) / (L2 + 0.05) where L1 is the lighter luminance.
  static double calculateContrastRatio(Color foreground, Color background) {
    final l1 = relativeLuminance(foreground);
    final l2 = relativeLuminance(background);
    final lighter = math.max(l1, l2);
    final darker = math.min(l1, l2);
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Computes the relative luminance of a color (0.0 to 1.0).
  static double relativeLuminance(Color color) {
    return color.computeLuminance();
  }

}
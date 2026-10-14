import 'dart:math' as math;
import 'package:flutter/material.dart';

/// WCAG compliance rating for text-to-background contrast.
enum WCAGLevel {
  aaa,
  aa,
  aaLarge,
  fail;

  String get label => switch (this) {
        WCAGLevel.aaa => 'AAA (≥7.0)',
        WCAGLevel.aa => 'AA (≥4.5)',
        WCAGLevel.aaLarge => 'AA Large (≥3.0)',
        WCAGLevel.fail => 'FAIL (<3.0)',
      };

  Color get color => switch (this) {
        WCAGLevel.aaa => Colors.green,
        WCAGLevel.aa => Colors.lightGreen,
        WCAGLevel.aaLarge => Colors.amber,
        WCAGLevel.fail => Colors.red,
      };

  bool get isCompliant => this != WCAGLevel.fail;
}

/// Utility for validating WCAG color contrast ratios.
abstract final class ContrastChecker {
  /// Calculates the contrast ratio between foreground and background colors (1.0 to 21.0).
  static double calculateContrastRatio(Color foreground, Color background) {
    final l1 = _relativeLuminance(foreground);
    final l2 = _relativeLuminance(background);
    final lighter = math.max(l1, l2);
    final darker = math.min(l1, l2);
    return (lighter + 0.05) / (darker + 0.05);
  }

  static double _relativeLuminance(Color color) {
    final r = _luminanceChannel((color.r * 255.0).round() / 255.0);
    final g = _luminanceChannel((color.g * 255.0).round() / 255.0);
    final b = _luminanceChannel((color.b * 255.0).round() / 255.0);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  static double _luminanceChannel(double channel) {
    return channel <= 0.03928
        ? channel / 12.92
        : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
  }

  /// Classifies a contrast ratio into its WCAG level.
  static WCAGLevel getWCAGLevel(double ratio) {
    if (ratio >= 7.0) return WCAGLevel.aaa;
    if (ratio >= 4.5) return WCAGLevel.aa;
    if (ratio >= 3.0) return WCAGLevel.aaLarge;
    return WCAGLevel.fail;
  }
}

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Centralized accessibility service for the Vhunambi design system.
///
/// Provides reduce-motion detection, touch target enforcement, semantic
/// label generation, and other accessibility utilities. All methods are
/// static and platform-abstracted for testability.
class AccessibilityService {
  AccessibilityService._();

  /// Returns whether the user has requested reduced motion.
  ///
  /// Reads `MediaQuery.of(context).reduceMotion` and respects the system
  /// accessibility preference.
  static bool isReduceMotionEnabled(BuildContext context) {
    return MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  /// Returns the animation duration respecting reduce-motion preference.
  ///
  /// Returns [Duration.zero] when reduce motion is enabled, otherwise
  /// returns [normalDuration].
  static Duration animationDuration({
    required BuildContext context,
    required Duration normalDuration,
  }) {
    return isReduceMotionEnabled(context) ? Duration.zero : normalDuration;
  }

  /// Wraps [child] to guarantee a minimum 48×48 dp touch target per WCAG
  /// 2.5.5 and Apple HIG.
  ///
  /// If [childSize] is smaller than 48×48, padding is added to reach the
  /// minimum. The [onTap] callback is invoked when the wrapped area is
  /// tapped.
  static Widget ensureTouchTarget({
    required Size childSize,
    required VoidCallback onTap,
    required Widget child,
    double minSize = 48.0,
  }) {
    final width = math.max(childSize.width, minSize);
    final height = math.max(childSize.height, minSize);
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: width,
        minHeight: height,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Center(
            widthFactor: 1.0,
            heightFactor: 1.0,
            child: child,
          ),
        ),
      ),
    );
  }

  /// Generates a semantic label for a genre chip.
  static String genreChipLabel(String genreName, bool isSelected) {
    return '$genreName${isSelected ? ', selected' : ''}';
  }

  /// Generates a semantic label for a mood chip.
  static String moodChipLabel(String moodName, bool isSelected) {
    return '$moodName${isSelected ? ', selected' : ''}';
  }

  /// Generates a semantic label for a toggle switch.
  static String toggleLabel(String label, bool isOn) {
    return '$label, ${isOn ? 'on' : 'off'}';
  }
}
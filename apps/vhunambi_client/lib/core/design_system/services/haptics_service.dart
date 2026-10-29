import 'dart:io';
import 'package:flutter/services.dart';

/// Platform-abstracted haptic feedback service.
///
/// Provides named haptic patterns instead of raw `HapticFeedback` calls,
/// making haptics testable and consistent across the app. All methods
/// gracefully degrade on platforms that don't support haptics (web,
/// headless CI, older Android versions).
class HapticsService {
  /// Whether haptic feedback is enabled. Can be toggled to respect user
  /// preferences or accessibility settings.
  bool enabled = true;

  /// Triggers a light impact haptic (selection click).
  ///
  /// Use for: option chip selection, stanza addition, language change,
  /// toggle switches.
  void lightImpact() {
    if (!enabled) return;
    _safe(() => HapticFeedback.lightImpact());
  }

  /// Triggers a medium impact haptic.
  ///
  /// Use for: tab changes, button presses, control interactions.
  void mediumImpact() {
    if (!enabled) return;
    _safe(() => HapticFeedback.mediumImpact());
  }

  /// Triggers a heavy impact haptic.
  ///
  /// Use for: initiating audio generation, stem bouncing, MPC slicing,
  /// destructive actions.
  void heavyImpact() {
    if (!enabled) return;
    _safe(() => HapticFeedback.heavyImpact());
  }

  /// Triggers a selection click haptic.
  ///
  /// Use for: scroll selection, picker changes.
  void selectionClick() {
    if (!enabled) return;
    _safe(() => HapticFeedback.selectionClick());
  }

  /// Executes [action] safely, catching platform exceptions on unsupported
  /// platforms (web, headless tests).
  static void _safe(void Function() action) {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        action();
      }
    } catch (_) {
      // Haptics unavailable on this platform — silently degrade.
    }
  }
}
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Centralized, platform-safe haptic dispatcher for Studio micro-interactions
/// (M10 / "The Sensory Playground", REQ-KIN-01).
///
/// Every method:
/// - Silently no-ops on Web (`kIsWeb`) and when disabled via [setEnabled].
/// - Wraps the underlying `HapticFeedback` call in an awaited `try/catch` so
///   a missing plugin channel never throws in headless VM / CI test runners
///   (mirrors the proven `NotificationsHaptics` pattern).
abstract final class StudioHaptics {
  static bool _enabled = true;

  /// Globally toggle haptics (settings / reduced-motion preferences).
  static void setEnabled(bool enabled) => _enabled = enabled;

  /// `true` while haptic feedback is globally enabled.
  static bool get isEnabled => _enabled;

  static Future<void> _guard(Future<void> Function() action) async {
    if (!_enabled || kIsWeb) return;
    try {
      await action();
    } catch (_) {
      // Headless runner / unsupported platform — swallow silently.
    }
  }

  /// Heavy impact — generative model ignition, stem splitting, MPC slicing.
  static Future<void> ignitionThump() =>
      _guard(() => HapticFeedback.heavyImpact());

  /// Medium impact — deck/tab changes, accordion toggles, stanza additions.
  static Future<void> deckSwitch() =>
      _guard(() => HapticFeedback.mediumImpact());

  /// Light impact — option chip selection, language toggle, card taps.
  static Future<void> chipSnap() => _guard(() => HapticFeedback.lightImpact());

  /// Selection click — slider scrubbing, detent snaps, fine increments.
  static Future<void> sliderTick() =>
      _guard(() => HapticFeedback.selectionClick());

  /// Celebratory double pulse — ghost session restore, prompt refinement.
  static Future<void> successPulse() async {
    await _guard(() async {
      await HapticFeedback.mediumImpact();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.lightImpact();
    });
  }
}
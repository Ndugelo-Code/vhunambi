import 'package:flutter/foundation.dart';
import 'package:vhunambi_client/core/design_system/services/haptics_service.dart';

/// Centralized, platform-safe haptic dispatcher for Studio micro-interactions
/// (M10 / "The Sensory Playground", REQ-KIN-01).
///
/// Delegates to the design system [HapticsService] for platform-abstracted
/// haptic feedback. All methods gracefully degrade on Web and headless CI.
abstract final class StudioHaptics {
  static final HapticsService _haptics = HapticsService();

  static bool _enabled = true;

  /// Globally toggle haptics (settings / reduced-motion preferences).
  static void setEnabled(bool enabled) {
    _enabled = enabled;
    _haptics.enabled = enabled;
  }

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
  static Future<void> ignitionThump() => _guard(
        () async {
          _haptics.heavyImpact();
        },
      );

  /// Medium impact — deck/tab changes, accordion toggles, stanza additions.
  static Future<void> deckSwitch() => _guard(
        () async {
          _haptics.mediumImpact();
        },
      );

  /// Light impact — option chip selection, language toggle, card taps.
  static Future<void> chipSnap() => _guard(
        () async {
          _haptics.lightImpact();
        },
      );

  /// Selection click — slider scrubbing, detent snaps, fine increments.
  static Future<void> sliderTick() => _guard(
        () async {
          _haptics.selectionClick();
        },
      );

  /// Celebratory double pulse — ghost session restore, prompt refinement.
  static Future<void> successPulse() async {
    await _guard(() async {
      _haptics.mediumImpact();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      _haptics.lightImpact();
    });
  }
}
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Centralized, platform-safe haptic dispatcher for the Notifications Center
/// ("The Sensory Station").
///
/// Every method:
/// - Silently no-ops on Web (`kIsWeb`) and unsupported platforms.
/// - Wraps the underlying `HapticFeedback` call in a `try/catch` so a missing
///   plugin channel never throws in headless VM / CI test runners.
///
/// Reference: CLINE_HANDOFF_PHASE_NOTIFICATIONS.md §4 Step 6 and the
/// notifications blueprint §8.1.
abstract final class NotificationsHaptics {
  static Future<void> _guard(Future<void> Function() action) async {
    if (kIsWeb) return;
    try {
      await action();
    } catch (_) {
      // Headless runner / unsupported platform — swallow silently.
    }
  }

  /// Light double-tick when the bell trigger is tapped.
  static Future<void> bellRing() async {
    await _guard(() async {
      await HapticFeedback.lightImpact();
      await Future<void>.delayed(const Duration(milliseconds: 90));
      await HapticFeedback.lightImpact();
    });
  }

  /// Medium crisp snap when a swipe crosses the 80px dismiss threshold.
  static Future<void> dismissSnap() =>
      _guard(() => HapticFeedback.mediumImpact());

  /// Selection click on category chip / tab change.
  static Future<void> categorySwitch() =>
      _guard(() => HapticFeedback.selectionClick());

  /// Celebratory dual pulse when all alerts are marked read.
  static Future<void> markAllReadPulse() async {
    await _guard(() async {
      await HapticFeedback.mediumImpact();
      await Future<void>.delayed(const Duration(milliseconds: 90));
      await HapticFeedback.lightImpact();
    });
  }

  /// Crisp selection click when opening a notification deep link.
  static Future<void> itemTap() =>
      _guard(() => HapticFeedback.selectionClick());
}

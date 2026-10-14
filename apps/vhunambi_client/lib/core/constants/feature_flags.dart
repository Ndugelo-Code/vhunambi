import 'package:flutter/foundation.dart';

/// Centralized runtime and configuration feature flags for VHUNAMBI.
///
/// ## Rollback Procedure
/// If critical runtime issues or unforeseen device-specific regressions arise in the
/// enhanced profile error handling or resilient cache subsystems:
/// 1. Set [useEnhancedErrorHandling] to `false` (either dynamically or via remote config).
/// 2. Profile views will bypass background retry overlays and fall back to legacy
///    immediate-throw state paths without breaking the underlying [ArtistProfileEntity] contracts.
/// 3. To re-enable once resolved, restore [useEnhancedErrorHandling] to `true`.
abstract final class FeatureFlags {
  /// Controls whether enhanced profile error handling, network retries, and offline
  /// state indicators are active. Defaults to `true`.
  static bool useEnhancedErrorHandling = true;

  /// Controls whether skeleton screens are used during profile loading.
  static bool useSkeletonScreens = true;

  /// Controls whether accessibility enhancements (touch target enforcement, semantic wrappers) are active.
  static bool useAccessibilityEnhancements = true;

  /// Controls whether debug developer utilities are active.
  static bool enableDebugMode = kDebugMode;

  /// Controls whether the developer Accessibility Audit overlay is active.
  /// When active, highlights touch target sizes, contrast metrics, missing semantics,
  /// and simulated screen reader announcements.
  static bool enableA11yAuditMode = false;

  /// Resets feature flags to their default production values. Useful in automated tests.
  static void reset() {
    useEnhancedErrorHandling = true;
    useSkeletonScreens = true;
    useAccessibilityEnhancements = true;
    enableDebugMode = kDebugMode;
    enableA11yAuditMode = false;
  }
}

import 'package:flutter/material.dart';

/// Responsive Breakpoint Utilities
/// Reference: docs/foundation_blueprints/01_EXPLORE_PAGE_SPEC.md
abstract final class ResponsiveUtils {
  static const double mobileBreakpoint = 768.0;
  static const double desktopBreakpoint = 1024.0;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobileBreakpoint;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= mobileBreakpoint && width <= desktopBreakpoint;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width > desktopBreakpoint;

  static int gridColumns(BuildContext context) =>
      isDesktop(context) ? 6 : 2;

  static double trackAspectRatio(BuildContext context) =>
      isDesktop(context) ? 0.72 : 0.75;
}

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/responsive_utils.dart';

/// Shared top-bar geometry, surface and affordances for the Vhunambi shell.
///
/// Centralizes the safe-area math so every custom `PreferredSize` header
/// reserves `statusBarInset + toolbarHeight` instead of a fixed `56px` box
/// that squishes content on notched / island / punch-hole devices.
///
/// Reference: docs/audits/TOP_BAR_NAVIGATION_AUDIT_PROMPT.md (Dimension 2).
abstract final class VhunambiTopBarMetrics {
  /// Status-bar / camera-cutout inset. `0` on desktop and in bare test envs.
  static double topInset(BuildContext context) =>
      MediaQuery.paddingOf(context).top;

  /// Constant interactive row height — invariant across device cutouts so the
  /// content never squishes; only the inset region above it grows.
  static double toolbarHeight(BuildContext context) =>
      ResponsiveUtils.isDesktop(context) ? 64 : 56;

  /// Total height a `PreferredSize` must reserve for a [VhunambiTopBarSurface]:
  /// the status-bar inset plus the constant interactive toolbar.
  static double totalHeight(BuildContext context, {double? toolbarHeight}) =>
      topInset(context) +
      (toolbarHeight ?? VhunambiTopBarMetrics.toolbarHeight(context));
}

/// Decorated top-bar surface that paints the status-bar inset region in the
/// same colour as the toolbar (one continuous surface) and pins the
/// interactive content to a constant [toolbarHeight] so it never squishes.
///
/// Replaces the `Container(height: X) + SafeArea(bottom: false)` anti-pattern.
class VhunambiTopBarSurface extends StatelessWidget {
  /// The interactive row. Provide it already horizontally padded if desired.
  final Widget child;

  /// Interactive row height. Defaults to [VhunambiTopBarMetrics.toolbarHeight].
  final double? toolbarHeight;

  /// Custom decoration; defaults to the canvas surface + bottom hairline.
  final BoxDecoration? decoration;

  const VhunambiTopBarSurface({
    super.key,
    required this.child,
    this.toolbarHeight,
    this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    final bar = toolbarHeight ?? VhunambiTopBarMetrics.toolbarHeight(context);
    return Container(
      width: double.infinity,
      decoration:
          decoration ??
          const BoxDecoration(
            color: AppColors.surfaceCanvas,
            border: Border(
              bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
            ),
          ),
      child: Padding(
        padding: EdgeInsets.only(top: VhunambiTopBarMetrics.topInset(context)),
        child: SizedBox(
          height: bar,
          width: double.infinity,
          child: child,
        ),
      ),
    );
  }
}

/// Canonical back affordance for pushed routes.
///
/// Uses a single glyph (`chevron_left_rounded`) with a 44x44 minimum touch
/// target (Apple HIG / WCAG 2.5.5) and defaults to `Navigator.maybePop()`.
class VhunambiBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color? color;
  final String tooltip;

  const VhunambiBackButton({
    super.key,
    this.onPressed,
    this.color,
    this.tooltip = 'Back',
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: const Icon(Icons.chevron_left_rounded),
      color: color ?? AppColors.textPrimary,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
    );
  }
}

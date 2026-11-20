import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';

/// Visual elevation tier for [VhunambiGlassSurface] (`REQ-P70-GLASS-01`).
enum VhunambiGlassVariant {
  /// Standard frosted card for content sections (telemetry, bio, song rows).
  card,

  /// Interactive pill or chip with elevated contrast for Light & Dark modes.
  pill,

  /// Elevated chrome surface (sticky header / hero floating capsule).
  chrome,
}

/// Dual-theme 3-layer glassmorphism primitive calibrated for Warm African Daylight
/// ("Morning Mist") and Obsidian Studio ("Obsidian Night") (`EP-P70-GLASS-SURFACE`).
///
/// Android 60 FPS Guardrail (`REQ-P70-GLASS-02`):
/// - [enableLiveBlur] defaults to `false` so repeating list/grid cards never
///   allocate per-item `BackdropFilter` offscreen render targets.
/// - Opt-in live blur clamps [blurSigma] to `[0.0, 16.0]` inside a `ClipRRect`
///   and `RepaintBoundary`.
class VhunambiGlassSurface extends StatelessWidget {
  final Widget child;
  final VhunambiGlassVariant variant;
  final BorderRadiusGeometry? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool enableLiveBlur;
  final double blurSigma;
  final Color? tintAccent;
  final Color? borderColorOverride;
  final double borderWidth;
  final double? width;
  final double? height;
  final BoxConstraints? constraints;

  const VhunambiGlassSurface({
    super.key,
    required this.child,
    this.variant = VhunambiGlassVariant.card,
    this.borderRadius,
    this.padding,
    this.margin,
    this.enableLiveBlur = false,
    this.blurSigma = 14.0,
    this.tintAccent,
    this.borderColorOverride,
    this.borderWidth = 1.0,
    this.width,
    this.height,
    this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedRadius =
        borderRadius ??
        switch (variant) {
          VhunambiGlassVariant.card => AppRadius.cardBorder,
          VhunambiGlassVariant.pill => AppRadius.pillBorder,
          VhunambiGlassVariant.chrome => AppRadius.cardBorder,
        };

    final LinearGradient fillGradient = _buildGradient(isDark);
    final Color strokeColor = borderColorOverride ?? _resolveBorder(isDark);
    final List<BoxShadow> shadows = _resolveShadows(isDark);

    final Widget decorated = Container(
      width: width,
      height: height,
      constraints: constraints,
      padding: padding,
      decoration: BoxDecoration(
        gradient: fillGradient,
        borderRadius: resolvedRadius,
        border: Border.all(color: strokeColor, width: borderWidth),
        boxShadow: shadows,
      ),
      child: child,
    );

    if (!enableLiveBlur) {
      if (margin != null) {
        return Padding(padding: margin!, child: decorated);
      }
      return decorated;
    }

    final clampedSigma = blurSigma.clamp(0.0, 16.0);
    final Widget blurred = RepaintBoundary(
      child: ClipRRect(
        borderRadius: resolvedRadius is BorderRadius
            ? resolvedRadius
            : AppRadius.cardBorder,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: clampedSigma,
            sigmaY: clampedSigma,
          ),
          child: decorated,
        ),
      ),
    );

    if (margin != null) {
      return Padding(padding: margin!, child: blurred);
    }
    return blurred;
  }

  LinearGradient _buildGradient(bool isDark) {
    if (variant == VhunambiGlassVariant.pill) {
      final base = isDark
          ? AppColors.darkSurfaceSecondary
          : AppColors.lightSurfaceSecondary;
      final topColor = tintAccent != null
          ? Color.alphaBlend(
              tintAccent!.withValues(alpha: isDark ? 0.16 : 0.12),
              base.withValues(alpha: 0.88),
            )
          : base.withValues(alpha: 0.88);
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[topColor, base.withValues(alpha: isDark ? 0.78 : 0.80)],
      );
    }

    if (isDark) {
      final topBase = AppColors.darkSurfaceSecondary.withValues(alpha: 0.74);
      final bottomBase = AppColors.darkSurfaceElevated.withValues(alpha: 0.58);
      final top = tintAccent != null
          ? Color.alphaBlend(tintAccent!.withValues(alpha: 0.10), topBase)
          : topBase;
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[top, bottomBase],
      );
    }

    final topBase = AppColors.lightSurfaceElevated.withValues(alpha: 0.78);
    final bottomBase = AppColors.lightSurfaceModal.withValues(alpha: 0.62);
    final top = tintAccent != null
        ? Color.alphaBlend(tintAccent!.withValues(alpha: 0.08), topBase)
        : topBase;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[top, bottomBase],
    );
  }

  Color _resolveBorder(bool isDark) {
    if (isDark) {
      return Color.alphaBlend(
        Colors.white.withValues(alpha: 0.12),
        AppColors.darkBorderSubtle,
      );
    }
    return Color.alphaBlend(
      Colors.white.withValues(alpha: 0.65),
      AppColors.lightBorderSubtle,
    );
  }

  List<BoxShadow> _resolveShadows(bool isDark) {
    if (variant == VhunambiGlassVariant.pill) {
      return const <BoxShadow>[];
    }
    return <BoxShadow>[
      BoxShadow(
        color: isDark
            ? Colors.black.withValues(alpha: 0.28)
            : const Color(0xFF121216).withValues(alpha: 0.06),
        blurRadius: isDark ? 20 : 16,
        offset: const Offset(0, 6),
      ),
    ];
  }
}

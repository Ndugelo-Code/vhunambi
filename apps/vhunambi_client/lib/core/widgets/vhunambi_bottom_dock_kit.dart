import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

/// Shared bottom-dock geometry for the Vhunambi mobile shell — the counterpart
/// to `VhunambiTopBarMetrics`.
///
/// Centralizes the floating mini-player height and the dynamic scroll inset so
/// every scrollable tab clears the persistent transport without magic numbers.
///
/// Reference: docs/audits/BOTTOM_NAV_AND_AUDIO_TRANSPORT_AUDIT_PROMPT.md (Dim 4).
abstract final class VhunambiBottomDockMetrics {
  /// Standard `BottomNavigationBar` height. Reserved by the Scaffold slot, so
  /// scroll content must NOT pad for it again (avoids double-counting).
  static const double navBarHeight = 56;

  /// Floating mini-player pill height (raised from 60 to house 44px targets).
  static const double miniPlayerHeight = 64;

  /// Gap between the pill and the bottom nav bar (and its side margins).
  static const double floatingMargin = 8;

  /// Aesthetic breathing room below the last item when no track is active.
  static const double idleBottomGap = 16;

  /// Device bottom safe-area inset (home indicator / gesture bar).
  static double bottomSafeArea(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom;

  /// Extra bottom padding a scroll view must add so its last item clears the
  /// floating mini player. Collapses to [idleBottomGap] when idle, eliminating
  /// the dead space that hardcoded 100–120px paddings produced.
  static double scrollInset({required bool hasActiveTrack}) =>
      hasActiveTrack ? miniPlayerHeight + floatingMargin * 2 : idleBottomGap;
}

/// Frosted "floating island" surface for the persistent mini player.
///
/// Mirrors `VhunambiTopBarSurface`: ambient blur, translucent modal surface,
/// hairline border, soft elevation and an optional genre-tinted ambient glow.
class VhunambiFloatingTransportSurface extends StatelessWidget {
  final Widget child;
  final double height;

  /// Optional ambient glow colour (e.g. sampled from the track's genre
  /// gradient) that bleeds softly behind the pill.
  final Color? glow;

  const VhunambiFloatingTransportSurface({
    super.key,
    required this.child,
    this.height = VhunambiBottomDockMetrics.miniPlayerHeight,
    this.glow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: AppRadius.inputBorder,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(90),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          if (glow != null)
            BoxShadow(
              color: glow!.withAlpha(70),
              blurRadius: 28,
              spreadRadius: -2,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: AppRadius.inputBorder,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceModal.withAlpha(210),
              borderRadius: AppRadius.inputBorder,
              border: Border.all(color: AppColors.borderSubtle, width: 1),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Frosted backdrop surface for the root shell's [BottomNavigationBar].
///
/// Mirrors [VhunambiTopBarSurface] with an 18-sigma backdrop blur, subtle top
/// hairline border, and safe-area inset preservation.
class VhunambiBottomDockSurface extends StatelessWidget {
  final Widget child;

  const VhunambiBottomDockSurface({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.transparent,
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            color: AppColors.surfaceCanvas.withAlpha(215),
            child: child,
          ),
        ),
      ),
    );
  }
}

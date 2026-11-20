import 'package:flutter/material.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';

/// Static ambient radial mesh backdrop painted behind scrollable glass screens
/// (`TrackDetailView`, `ArtistProfileView`).
///
/// Wrapped in a [RepaintBoundary] so scrolling content above it never triggers
/// radial shader re-rasterization on mid-range Android GPUs (`REQ-P70-GLASS-03`).
class VhunambiAmbientMeshBackdrop extends StatelessWidget {
  final Color primaryGlow;
  final Color secondaryGlow;
  final Widget child;

  const VhunambiAmbientMeshBackdrop({
    super.key,
    this.primaryGlow = AppColors.brandPrimary,
    this.secondaryGlow = const Color(0xFF38BDF8),
    required this.child,
  });

  /// Deterministically maps a genre string to a curated ambient glow pair.
  factory VhunambiAmbientMeshBackdrop.forGenre({
    Key? key,
    required String genre,
    required Widget child,
  }) {
    final g = genre.trim().toLowerCase();
    final (Color primary, Color secondary) = switch (g) {
      'amapiano' => (const Color(0xFFF59E0B), const Color(0xFFD97706)),
      'gqom' => (const Color(0xFF6366F1), const Color(0xFF312E81)),
      'maskandi' => (const Color(0xFF10B981), const Color(0xFF065F46)),
      'afro house' || 'afro-house' => (
        const Color(0xFFEA580C),
        const Color(0xFF7C2D12),
      ),
      'afro jazz' || 'afro-jazz' => (
        const Color(0xFF3B82F6),
        const Color(0xFF1E3A8A),
      ),
      'kwaito' => (const Color(0xFFEF4444), const Color(0xFF991B1B)),
      _ => (AppColors.brandPrimary, const Color(0xFFF59E0B)),
    };
    return VhunambiAmbientMeshBackdrop(
      key: key,
      primaryGlow: primary,
      secondaryGlow: secondary,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canvas = AppColors.surfaceCanvasOf(context);
    final primaryAlpha = isDark ? 0.22 : 0.16;
    final secondaryAlpha = isDark ? 0.16 : 0.12;

    return ColoredBox(
      color: canvas,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.75, -0.82),
                      radius: 1.05,
                      colors: <Color>[
                        primaryGlow.withValues(alpha: primaryAlpha),
                        canvas.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0.85, 0.25),
                        radius: 1.15,
                        colors: <Color>[
                          secondaryGlow.withValues(alpha: secondaryAlpha),
                          canvas.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

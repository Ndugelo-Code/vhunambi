import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Touch ripple record capturing location and creation timestamp.
class TouchRipple {
  final Offset position;
  final DateTime createdAt;

  const TouchRipple({
    required this.position,
    required this.createdAt,
  });
}

/// 60 FPS Living Procedural Canvas inspired by geometric motion reference (REQ-P47-CANVAS-01..05).
///
/// Features 4 chromatic orbiting nodes (Amber, Cyan, Emerald, Gold), satellite particle
/// fission/fusion, velocity-based pill capsule stretching, and ambient soundwave ribbons.
class OnboardingProceduralBackdropCanvas extends StatelessWidget {
  final Animation<double> animation;
  final double pageOffset;
  final List<TouchRipple> touchRipples;

  const OnboardingProceduralBackdropCanvas({
    super.key,
    required this.animation,
    required this.pageOffset,
    this.touchRipples = const [],
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return CustomPaint(
          size: Size.infinite,
          painter: _ConstellationBackdropPainter(
            time: animation.value,
            pageOffset: pageOffset,
            isDark: isDark,
            ripples: touchRipples,
          ),
        );
      },
    );
  }
}

class _ConstellationBackdropPainter extends CustomPainter {
  final double time;
  final double pageOffset;
  final bool isDark;
  final List<TouchRipple> ripples;

  // Cached Paint objects to guarantee 60 FPS without per-frame allocations (REQ-P47-CANVAS-01)
  final Paint _fillPaint = Paint()..style = PaintingStyle.fill;
  final Paint _strokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint _glowPaint = Paint()
    ..style = PaintingStyle.fill
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);

  _ConstellationBackdropPainter({
    required this.time,
    required this.pageOffset,
    required this.isDark,
    required this.ripples,
  });

  // 4 Primary Chromatic Nodes (REQ-P47-CANVAS-02)
  static const _nodeColors = [
    Color(0xFFF97316), // Node 1: Amber / Highveld Sunset
    Color(0xFF06B6D4), // Node 2: Cyan / Electro Log Drum
    Color(0xFF10B981), // Node 3: Emerald / Heritage Roots
    Color(0xFFF59E0B), // Node 4: Gold / Sovereign Royalty
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final center = Offset(size.width * 0.5, size.height * 0.38);
    final minDim = math.min(size.width, size.height);

    // 1. Draw Subtle Ambient Vignette & Radial Atmosphere
    final bgGlow = RadialGradient(
      center: Alignment(0, (pageOffset - 1.5) * 0.2),
      radius: 0.95,
      colors: [
        isDark ? const Color(0x18F97316) : const Color(0x10EA580C),
        isDark ? const Color(0x0C06B6D4) : const Color(0x080891B2),
        Colors.transparent,
      ],
      stops: const [0.0, 0.55, 1.0],
    );
    _fillPaint.shader = bgGlow.createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, _fillPaint);
    _fillPaint.shader = null;

    // 2. Draw Ambient Acoustic Waveform Ribbon across canvas
    _paintAcousticWaveRibbon(canvas, size);

    // 3. Draw Touch Ripple Concentric Rings
    _paintTouchRipples(canvas);

    // 4. Draw 4-Node Chromatic Constellation with Capsule Stretching & Satellites
    _paintConstellation(canvas, center, minDim);
  }

  void _paintAcousticWaveRibbon(Canvas canvas, Size size) {
    final wavePath = Path();
    final waveY = size.height * 0.72;
    final waveAmplitude = 14.0 + (math.sin(time * 2 * math.pi) * 6.0);
    final frequency = 0.015 + (pageOffset * 0.004);

    wavePath.moveTo(0, waveY);
    for (double x = 0; x <= size.width; x += 6.0) {
      final y = waveY +
          math.sin((x * frequency) + (time * 4 * math.pi)) * waveAmplitude +
          math.cos((x * frequency * 0.5) - (time * 2 * math.pi)) * (waveAmplitude * 0.4);
      wavePath.lineTo(x, y);
    }

    _strokePaint
      ..shader = LinearGradient(
        colors: [
          _nodeColors[0].withValues(alpha: isDark ? 0.20 : 0.12),
          _nodeColors[1].withValues(alpha: isDark ? 0.30 : 0.18),
          _nodeColors[2].withValues(alpha: isDark ? 0.20 : 0.12),
        ],
      ).createShader(Rect.fromLTWH(0, waveY - 30, size.width, 60))
      ..strokeWidth = 1.8;

    canvas.drawPath(wavePath, _strokePaint);
    _strokePaint.shader = null;
  }

  void _paintTouchRipples(Canvas canvas) {
    final now = DateTime.now();
    for (final ripple in ripples) {
      final elapsedMs = now.difference(ripple.createdAt).inMilliseconds;
      if (elapsedMs > 800) continue;

      final progress = (elapsedMs / 800.0).clamp(0.0, 1.0);
      final radius = 12.0 + (progress * 140.0);
      final opacity = (1.0 - progress) * 0.35;

      _strokePaint
        ..color = _nodeColors[1].withValues(alpha: opacity)
        ..strokeWidth = 1.6 * (1.0 - progress);

      canvas.drawCircle(ripple.position, radius, _strokePaint);
    }
  }

  void _paintConstellation(Canvas canvas, Offset center, double minDim) {
    final baseRadius = minDim * 0.28;
    final speed = time * 2 * math.pi;

    // Parallax & Stage Deformation Factor derived from active page
    final stageMorph = (pageOffset - pageOffset.floor()).clamp(0.0, 1.0);
    final stretchFactor = 1.0 + (math.sin(stageMorph * math.pi) * 1.8); // 1.0 to 2.8x capsule stretch

    final nodePositions = <Offset>[];

    for (int i = 0; i < 4; i++) {
      final angle = speed + (i * math.pi * 0.5);
      final ellipseX = baseRadius * (1.15 + (i % 2 == 0 ? 0.15 : -0.15));
      final ellipseY = baseRadius * 0.68;

      final nx = center.dx + (math.cos(angle) * ellipseX);
      final ny = center.dy + (math.sin(angle) * ellipseY);
      final pos = Offset(nx, ny);
      nodePositions.add(pos);

      final color = _nodeColors[i];

      // Draw Orbiting Satellite Sub-particles (Fission & Fusion)
      for (int s = 0; s < 2; s++) {
        final satAngle = -(speed * 2.2) + (s * math.pi);
        final satDist = 22.0 + (s * 8.0);
        final sx = nx + (math.cos(satAngle) * satDist);
        final sy = ny + (math.sin(satAngle) * satDist);

        _fillPaint.color = color.withValues(alpha: isDark ? 0.45 : 0.30);
        canvas.drawCircle(Offset(sx, sy), 2.5, _fillPaint);
      }

      // Draw Chromatic Halo Glow
      _glowPaint.color = color.withValues(alpha: isDark ? 0.28 : 0.18);
      canvas.drawCircle(pos, 22.0 * stretchFactor, _glowPaint);

      // Draw Capsule vs Circle based on stretchFactor (REQ-P47-CANVAS-03)
      if (stretchFactor > 1.25) {
        final capsuleWidth = 18.0 * stretchFactor;
        const capsuleHeight = 14.0;
        final rect = Rect.fromCenter(center: pos, width: capsuleWidth, height: capsuleHeight);
        final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(7.0));

        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(angle + (math.pi * 0.25));
        canvas.translate(-pos.dx, -pos.dy);

        _fillPaint.color = color.withValues(alpha: isDark ? 0.85 : 0.75);
        canvas.drawRRect(rrect, _fillPaint);

        canvas.restore();
      } else {
        _fillPaint.color = color.withValues(alpha: isDark ? 0.90 : 0.80);
        canvas.drawCircle(pos, 8.5, _fillPaint);

        // Core white highlight
        _fillPaint.color = Colors.white.withValues(alpha: 0.90);
        canvas.drawCircle(pos, 3.0, _fillPaint);
      }
    }

    // Connect nodes with delicate geometric constellation lines
    _strokePaint
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08)
      ..strokeWidth = 1.0;

    for (int i = 0; i < nodePositions.length; i++) {
      final next = nodePositions[(i + 1) % nodePositions.length];
      canvas.drawLine(nodePositions[i], next, _strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConstellationBackdropPainter oldDelegate) {
    return oldDelegate.time != time ||
        oldDelegate.pageOffset != pageOffset ||
        oldDelegate.ripples.length != ripples.length;
  }
}


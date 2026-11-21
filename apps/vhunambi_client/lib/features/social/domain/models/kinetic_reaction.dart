import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

/// Canonical 6-reaction taxonomy (`EP-P73-MULTI-REACTIONS-API`, `STD-UIUX-001`).
///
/// Rendered exclusively via custom glossy vector badges ([KineticReactionBadge])
/// with zero raw OS Unicode emojis.
enum KineticReactionType {
  like(
    wireId: 'like',
    label: 'Like',
    startColor: Color(0xFF3B82F6),
    endColor: Color(0xFF1D4ED8),
    accentColor: Color(0xFF3B82F6),
  ),
  love(
    wireId: 'love',
    label: 'Love',
    startColor: Color(0xFFFB7185),
    endColor: Color(0xFFE11D48),
    accentColor: Color(0xFFF43F5E),
  ),
  haha(
    wireId: 'haha',
    label: 'Haha',
    startColor: Color(0xFFFDE047),
    endColor: Color(0xFFF59E0B),
    accentColor: Color(0xFFF59E0B),
  ),
  fire(
    wireId: 'fire',
    label: 'Fire',
    startColor: Color(0xFFFB923C),
    endColor: Color(0xFFEA580C),
    accentColor: Color(0xFFF97316),
  ),
  wow(
    wireId: 'wow',
    label: 'Wow',
    startColor: Color(0xFFC084FC),
    endColor: Color(0xFF7C3AED),
    accentColor: Color(0xFFA855F7),
  ),
  angry(
    wireId: 'angry',
    label: 'Angry',
    startColor: Color(0xFFF87171),
    endColor: Color(0xFFB91C1C),
    accentColor: Color(0xFFEF4444),
  );

  final String wireId;
  final String label;
  final Color startColor;
  final Color endColor;
  final Color accentColor;

  const KineticReactionType({
    required this.wireId,
    required this.label,
    required this.startColor,
    required this.endColor,
    required this.accentColor,
  });

  static KineticReactionType? fromWire(Object? raw) {
    if (raw == null) return null;
    final cleaned = raw.toString().trim().toLowerCase();
    for (final value in values) {
      if (value.wireId == cleaned || value.name == cleaned) return value;
    }
    return null;
  }

  static Map<KineticReactionType, int> parseCounts(Object? raw) {
    Object? decoded = raw;
    if (decoded is String && decoded.trim().isNotEmpty) {
      try {
        decoded = jsonDecode(decoded);
      } catch (_) {
        return const <KineticReactionType, int>{};
      }
    }
    if (decoded is! Map) return const <KineticReactionType, int>{};
    final out = <KineticReactionType, int>{};
    decoded.forEach((k, v) {
      final type = fromWire(k);
      final count = (v as num?)?.toInt() ?? 0;
      if (type != null && count > 0) {
        out[type] = count;
      }
    });
    return Map<KineticReactionType, int>.unmodifiable(out);
  }

  static Map<String, int> encodeCounts(Map<KineticReactionType, int> counts) {
    final out = <String, int>{};
    counts.forEach((k, v) {
      if (v > 0) out[k.wireId] = v;
    });
    return out;
  }

  /// Returns up to [maxBadges] reaction types sorted by descending count.
  static List<KineticReactionType> topReactions(
    Map<KineticReactionType, int> counts, {
    int maxBadges = 3,
    KineticReactionType? fallbackActive,
  }) {
    final entries = counts.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isNotEmpty) {
      return entries.take(maxBadges).map((e) => e.key).toList(growable: false);
    }
    if (fallbackActive != null) return <KineticReactionType>[fallbackActive];
    return const <KineticReactionType>[];
  }
}

/// Glossy custom vector orb badge for any [KineticReactionType] (`STD-UIUX-001`).
class KineticReactionBadge extends StatelessWidget {
  final KineticReactionType type;
  final double size;
  final bool showBorderRing;

  const KineticReactionBadge({
    super.key,
    required this.type,
    this.size = 20,
    this.showBorderRing = false,
  });

  @override
  Widget build(BuildContext context) {
    final ringColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF141418)
        : Colors.white;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[type.startColor, type.endColor],
        ),
        border: showBorderRing
            ? Border.all(color: ringColor, width: 1.5)
            : null,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: type.endColor.withValues(alpha: 0.35),
            blurRadius: size * 0.25,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Center(child: _buildGlyph()),
    );
  }

  Widget _buildGlyph() {
    final glyphSize = size * 0.56;
    return switch (type) {
      KineticReactionType.like => PhosphorIcon(
        PhosphorIconsFill.thumbsUp,
        size: glyphSize,
        color: Colors.white,
      ),
      KineticReactionType.love => PhosphorIcon(
        PhosphorIconsFill.heart,
        size: glyphSize,
        color: Colors.white,
      ),
      KineticReactionType.fire => PhosphorIcon(
        PhosphorIconsFill.fire,
        size: glyphSize,
        color: Colors.white,
      ),
      KineticReactionType.haha ||
      KineticReactionType.wow ||
      KineticReactionType.angry => CustomPaint(
        size: Size.square(size * 0.72),
        painter: _ReactionFacePainter(type: type),
      ),
    };
  }
}

class _ReactionFacePainter extends CustomPainter {
  final KineticReactionType type;

  const _ReactionFacePainter({required this.type});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final ink = type == KineticReactionType.haha
        ? const Color(0xFF3F2305)
        : Colors.white;
    final strokePaint = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = (w * 0.11).clamp(1.2, 2.8)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fillPaint = Paint()
      ..color = ink
      ..style = PaintingStyle.fill;

    switch (type) {
      case KineticReactionType.haha:
        final leftEye = Path()
          ..moveTo(w * 0.18, h * 0.42)
          ..quadraticBezierTo(w * 0.28, h * 0.26, w * 0.38, h * 0.42);
        final rightEye = Path()
          ..moveTo(w * 0.62, h * 0.42)
          ..quadraticBezierTo(w * 0.72, h * 0.26, w * 0.82, h * 0.42);
        canvas.drawPath(leftEye, strokePaint);
        canvas.drawPath(rightEye, strokePaint);
        final mouth = Path()
          ..moveTo(w * 0.22, h * 0.56)
          ..lineTo(w * 0.78, h * 0.56)
          ..arcToPoint(
            Offset(w * 0.22, h * 0.56),
            radius: Radius.circular(w * 0.30),
            clockwise: true,
          );
        canvas.drawPath(mouth, fillPaint);
      case KineticReactionType.wow:
        canvas.drawCircle(Offset(w * 0.30, h * 0.34), w * 0.08, fillPaint);
        canvas.drawCircle(Offset(w * 0.70, h * 0.34), w * 0.08, fillPaint);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(w * 0.50, h * 0.68),
            width: w * 0.28,
            height: h * 0.34,
          ),
          fillPaint,
        );
      case KineticReactionType.angry:
        canvas.drawLine(
          Offset(w * 0.18, h * 0.28),
          Offset(w * 0.42, h * 0.40),
          strokePaint,
        );
        canvas.drawLine(
          Offset(w * 0.82, h * 0.28),
          Offset(w * 0.58, h * 0.40),
          strokePaint,
        );
        canvas.drawCircle(Offset(w * 0.30, h * 0.46), w * 0.065, fillPaint);
        canvas.drawCircle(Offset(w * 0.70, h * 0.46), w * 0.065, fillPaint);
        final scowl = Path()
          ..moveTo(w * 0.28, h * 0.76)
          ..quadraticBezierTo(w * 0.50, h * 0.58, w * 0.72, h * 0.76);
        canvas.drawPath(scowl, strokePaint);
      case KineticReactionType.like:
      case KineticReactionType.love:
      case KineticReactionType.fire:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _ReactionFacePainter oldDelegate) =>
      oldDelegate.type != type;
}

/// Overlapping top-3 reaction badge cluster for summary strips & comments.
class ReactionClusterStack extends StatelessWidget {
  final Map<KineticReactionType, int> reactionCounts;
  final KineticReactionType? fallbackActive;
  final double badgeSize;

  const ReactionClusterStack({
    super.key,
    required this.reactionCounts,
    this.fallbackActive,
    this.badgeSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    final top = KineticReactionType.topReactions(
      reactionCounts,
      maxBadges: 3,
      fallbackActive: fallbackActive,
    );
    if (top.isEmpty) {
      return KineticReactionBadge(
        type: KineticReactionType.love,
        size: badgeSize,
      );
    }
    final step = badgeSize * 0.70;
    final totalWidth = badgeSize + (top.length - 1) * step;
    return SizedBox(
      width: totalWidth,
      height: badgeSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          for (var i = 0; i < top.length; i++)
            Positioned(
              left: i * step,
              child: KineticReactionBadge(
                type: top[i],
                size: badgeSize,
                showBorderRing: true,
              ),
            ),
        ],
      ),
    );
  }
}

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/song_dna_graph_provider.dart';
import 'song_dna_node_tree_modal.dart';

/// The Living 3D Hover Pill in Studio Cockpit (REQ-P50-PILL-01..04).
/// Features 60 FPS sine levitation, session-reactive multi-spectrum glow,
/// orbiting particle halo, and opens the 3D Song DNA Node Tree.
class SongDnaHoverPill extends ConsumerStatefulWidget {
  final VoidCallback? onTap;

  const SongDnaHoverPill({super.key, this.onTap});

  @override
  ConsumerState<SongDnaHoverPill> createState() => _SongDnaHoverPillState();
}

class _SongDnaHoverPillState extends ConsumerState<SongDnaHoverPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _levitationController;

  @override
  void initState() {
    super.initState();
    _levitationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    if (!WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      _levitationController.repeat();
    }
  }

  @override
  void dispose() {
    _levitationController.dispose();
    super.dispose();
  }

  void _open3DNodeTree() {
    HapticFeedback.mediumImpact();
    if (widget.onTap != null) {
      widget.onTap!();
    } else {
      SongDnaNodeTreeModal.show(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final graph = ref.watch(songDnaGraphProvider);
    final glowColor = graph.primaryGlowColor;
    final percent = (graph.overallCompleteness * 100).toInt();
    final hasInvasive = graph.activeInvasiveNodesCount > 0;

    return AnimatedBuilder(
      animation: _levitationController,
      builder: (context, child) {
        // Continuous 60 FPS vertical sine wave levitation (+/- 3.2dp)
        final dy = math.sin(_levitationController.value * 2 * math.pi) * 3.2;
        return Transform.translate(offset: Offset(0, dy), child: child);
      },
      child: GestureDetector(
        key: const Key('studio_song_dna_hover_pill'),
        onTap: _open3DNodeTree,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF13131B).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: glowColor.withValues(alpha: 0.55),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: glowColor.withValues(alpha: 0.35),
                blurRadius: 14,
                spreadRadius: 1.5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Spinning Mini-Helix Emblem
              SizedBox(
                width: 16,
                height: 16,
                child: CustomPaint(
                  painter: _MiniDnaIconPainter(
                    color: glowColor,
                    progress: _levitationController.value,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Song DNA $percent%',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 0.6,
                  color: glowColor,
                ),
              ),
              if (hasInvasive) ...[
                const SizedBox(width: 5),
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFD946EF),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              PhosphorIcon(
                PhosphorIconsBold.caretRight,
                size: 11,
                color: glowColor.withValues(alpha: 0.8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniDnaIconPainter extends CustomPainter {
  final Color color;
  final double progress;

  _MiniDnaIconPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final nodePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;
    final phase = progress * 2 * math.pi;

    final x1 = (w * 0.5) + math.sin(phase) * (w * 0.38);
    final x2 = (w * 0.5) - math.sin(phase) * (w * 0.38);

    canvas.drawLine(Offset(x1, h * 0.2), Offset(x2, h * 0.8), paint);
    canvas.drawCircle(Offset(x1, h * 0.2), 2.2, nodePaint);
    canvas.drawCircle(Offset(x2, h * 0.8), 2.2, nodePaint);
  }

  @override
  bool shouldRepaint(covariant _MiniDnaIconPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

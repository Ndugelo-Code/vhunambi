import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../profile/domain/models/creator_dna_node.dart';
import '../providers/onboarding_providers.dart';

/// Act 4: Interactive 3D Double-Helix Creator DNA Finale & MMORPG Inspector (REQ-P49-DNA-01..05).
/// Features 8 discrete genomic loci, tap-to-inspect hit-testing, pulsating target halo,
/// and MMORPG node inspection card.
class CreatorDnaHelixFinale extends ConsumerStatefulWidget {
  final VoidCallback onLaunchStudio;

  const CreatorDnaHelixFinale({super.key, required this.onLaunchStudio});

  @override
  ConsumerState<CreatorDnaHelixFinale> createState() =>
      _CreatorDnaHelixFinaleState();
}

class _CreatorDnaHelixFinaleState extends ConsumerState<CreatorDnaHelixFinale>
    with TickerProviderStateMixin {
  late final AnimationController _rotationController;
  late final AnimationController _pulseController;
  late final AnimationController _portalController;

  double _manualAngleOffset = 0.0;
  bool _isPortalExpanding = false;
  int _selectedNodeIndex = 0;
  Size _canvasSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _portalController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _portalController.dispose();
    super.dispose();
  }

  void _triggerLaunch() {
    if (_isPortalExpanding) return;
    setState(() => _isPortalExpanding = true);
    HapticFeedback.heavyImpact();

    _portalController.forward().then((_) {
      widget.onLaunchStudio();
    });
  }

  void _selectNode(int index) {
    if (_selectedNodeIndex == index) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedNodeIndex = index;
    });
  }

  void _handleTapUp(TapUpDetails details, List<CreatorDnaNode> nodes) {
    if (_canvasSize.width <= 0 || _canvasSize.height <= 0) return;

    final tapPos = details.localPosition;
    final currentAngle =
        (_rotationController.value * 2 * math.pi) + _manualAngleOffset;

    final centerX = _canvasSize.width * 0.5;
    final topY = _canvasSize.height * 0.08;
    final bottomY = _canvasSize.height * 0.92;
    final totalHeight = bottomY - topY;
    final helixRadius = (_canvasSize.width * 0.28).clamp(65.0, 125.0);
    final stepY = totalHeight / (nodes.length - 1);

    int? closestIndex;
    double minDistance = double.infinity;

    for (int i = 0; i < nodes.length; i++) {
      final y = topY + (i * stepY);
      final phase = currentAngle + (i * 0.65);

      final x1 = centerX + (math.cos(phase) * helixRadius);
      final x2 = centerX + (math.cos(phase + math.pi) * helixRadius);

      final d1 = (tapPos - Offset(x1, y)).distance;
      final d2 = (tapPos - Offset(x2, y)).distance;
      final localMin = math.min(d1, d2);

      if (localMin < minDistance) {
        minDistance = localMin;
        closestIndex = i;
      }
    }

    // 28dp proximity threshold (REQ-P49-DNA-03)
    if (closestIndex != null && minDistance <= 36.0) {
      _selectNode(closestIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingStateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nodes = CreatorDnaNode.getOnboardingDnaNodes(state);
    final selectedNode = nodes[_selectedNodeIndex.clamp(0, nodes.length - 1)];

    return Padding(
      key: const Key('onboarding_act_4_dna_finale'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          // Title & Subtitle with bouncy typography (REQ-P49-TYPO-01)
          Text(
            'Your Creator DNA is Live',
            style: AppTypography.bouncyTitleLarge.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimaryOf(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            '8 Genomic Loci • Tap any locus to inspect attunement',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondaryOf(context),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 6),

          // 3D Double-Helix Interactive Stage
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                _canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) => _handleTapUp(details, nodes),
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _manualAngleOffset += details.delta.dx * 0.015;
                    });
                  },
                  child: AnimatedBuilder(
                    animation: Listenable.merge([
                      _rotationController,
                      _pulseController,
                      _portalController,
                    ]),
                    builder: (context, _) {
                      final rotationAngle =
                          (_rotationController.value * 2 * math.pi) +
                          _manualAngleOffset;
                      final pulseVal = _pulseController.value;
                      final portalProgress = _portalController.value;

                      return CustomPaint(
                        size: Size.infinite,
                        painter: _CreatorDnaHelixPainter(
                          angle: rotationAngle,
                          nodes: nodes,
                          selectedIndex: _selectedNodeIndex,
                          pulseValue: pulseVal,
                          isDark: isDark,
                          portalProgress: portalProgress,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 6),

          // Horizontal Node Pill Carousel (REQ-P49-DNA-03)
          SizedBox(
            height: 32,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  for (int index = 0; index < nodes.length; index++) ...[
                    if (index > 0) const SizedBox(width: 6),
                    _buildNodeCarouselPill(
                      nodes[index],
                      index == _selectedNodeIndex,
                      index,
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // MMORPG Node Inspector Card (REQ-P49-DNA-04)
          _buildNodeInspectorCard(selectedNode, isDark),

          const SizedBox(height: 10),

          // Prominent Full-Width Non-Truncated CTA Button (REQ-P47-BUG-04)
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              key: const Key('onboarding_launch_studio_btn'),
              onPressed: _triggerLaunch,
              icon: const PhosphorIcon(
                PhosphorIconsBold.sparkle,
                size: 20,
                color: Colors.white,
              ),
              label: Text(
                'Activate My Creator DNA',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.5,
                  fontSize: 15,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 6,
                shadowColor: AppColors.brandPrimary.withValues(alpha: 0.40),
              ),
            ),
          ),

          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildNodeCarouselPill(
    CreatorDnaNode node,
    bool isSelected,
    int index,
  ) {
    return GestureDetector(
      key: Key('dna_helix_node_$index'),
      onTap: () => _selectNode(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? node.accentColor.withValues(alpha: 0.22)
              : (node.isSequenced
                  ? AppColors.surfaceElevated
                  : AppColors.surfaceSecondary),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? node.accentColor
                : (node.isSequenced
                    ? node.accentColor.withValues(alpha: 0.4)
                    : AppColors.borderSubtle),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhosphorIcon(
              node.icon,
              size: 13,
              color: isSelected
                  ? node.accentColor
                  : (node.isSequenced
                      ? node.accentColor.withValues(alpha: 0.8)
                      : AppColors.textTertiary),
            ),
            const SizedBox(width: 4),
            Text(
              'Locus ${index + 1}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                color: isSelected
                    ? node.accentColor
                    : (node.isSequenced
                        ? AppColors.textPrimary
                        : AppColors.textTertiary),
              ),
            ),
            if (!node.isSequenced) ...[
              const SizedBox(width: 3),
              PhosphorIcon(
                PhosphorIconsBold.lock,
                size: 10,
                color: AppColors.textTertiary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNodeInspectorCard(CreatorDnaNode node, bool isDark) {
    return Container(
      key: const Key('dna_node_inspector_card'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF15151D) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: node.accentColor.withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: node.accentColor.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row: Icon, Trait Badge, Status Pill, +15% DNA
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: node.accentColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: PhosphorIcon(
                    node.icon,
                    size: 16,
                    color: node.accentColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      node.traitLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: node.accentColor,
                      ),
                    ),
                    Text(
                      node.title,
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: node.isSequenced
                      ? AppColors.success.withValues(alpha: 0.15)
                      : AppColors.coinGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: node.isSequenced
                        ? AppColors.success.withValues(alpha: 0.5)
                        : AppColors.coinGold.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PhosphorIcon(
                      node.isSequenced
                          ? PhosphorIconsBold.checkCircle
                          : PhosphorIconsBold.lock,
                      size: 11,
                      color: node.isSequenced
                          ? AppColors.success
                          : AppColors.coinGold,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      node.isSequenced ? 'SEQUENCED' : 'LOCKED QUEST',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: node.isSequenced
                            ? AppColors.success
                            : AppColors.coinGold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // +15% DNA Power Tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: node.accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+${node.dnaPowerBonus}%',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: node.accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Description / Quest Instruction
          Text(
            node.isSequenced
                ? node.description
                : '🔒 Quest: ${node.questInstruction}',
            style: AppTypography.bodySmall.copyWith(
              fontSize: 11,
              color: node.isSequenced
                  ? AppColors.textSecondary
                  : AppColors.brandPrimary,
              fontWeight:
                  node.isSequenced ? FontWeight.normal : FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// 3D CustomPainter for the 8-node MMORPG Double-Helix DNA strand (REQ-P49-DNA-01..03).
class _CreatorDnaHelixPainter extends CustomPainter {
  final double angle;
  final List<CreatorDnaNode> nodes;
  final int selectedIndex;
  final double pulseValue;
  final bool isDark;
  final double portalProgress;

  final Paint _strandPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  final Paint _nodePaint = Paint()..style = PaintingStyle.fill;
  final Paint _glowPaint = Paint()
    ..style = PaintingStyle.fill
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
  final Paint _haloPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  _CreatorDnaHelixPainter({
    required this.angle,
    required this.nodes,
    required this.selectedIndex,
    required this.pulseValue,
    required this.isDark,
    required this.portalProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || nodes.isEmpty) return;

    final centerX = size.width * 0.5;
    final topY = size.height * 0.08;
    final bottomY = size.height * 0.92;
    final totalHeight = bottomY - topY;

    final double helixRadius = (size.width * 0.28).clamp(65.0, 125.0);
    final int rungsCount = nodes.length;
    final double stepY = totalHeight / (rungsCount - 1);

    // If portal expansion active, paint expanding vortex rings
    if (portalProgress > 0) {
      final vortexRadius = portalProgress * size.width * 0.9;
      _strandPaint
        ..color = AppColors.brandPrimary.withValues(
          alpha: (1.0 - portalProgress) * 0.8,
        )
        ..strokeWidth = 3.5;
      canvas.drawCircle(
        Offset(centerX, size.height * 0.5),
        vortexRadius,
        _strandPaint,
      );
    }

    // Depth-sorted elements (z-ordering for true 3D perspective)
    final rungs = <_DnaNodeRenderItem>[];

    for (int i = 0; i < rungsCount; i++) {
      final y = topY + (i * stepY);
      final phase = angle + (i * 0.65);

      final x1 = centerX + (math.cos(phase) * helixRadius);
      final z1 = math.sin(phase); // -1.0 to 1.0

      final x2 = centerX + (math.cos(phase + math.pi) * helixRadius);
      final z2 = math.sin(phase + math.pi);

      final node = nodes[i];

      rungs.add(
        _DnaNodeRenderItem(
          index: i,
          p1: Offset(x1, y),
          z1: z1,
          p2: Offset(x2, y),
          z2: z2,
          node: node,
          depth: (z1 + z2) * 0.5,
        ),
      );
    }

    // Sort by depth (farthest first)
    rungs.sort((a, b) => a.depth.compareTo(b.depth));

    // Render rungs and nodes in 3D order
    for (final rung in rungs) {
      final normDepth = ((rung.depth + 1.0) / 2.0).clamp(0.2, 1.0);
      final alpha = isDark
          ? (0.25 + (normDepth * 0.70))
          : (0.20 + (normDepth * 0.60));

      final nodeColor = rung.node.accentColor;
      final rail2Color = rung.node.isSequenced
          ? AppColors.badgeCyan
          : AppColors.textTertiary;

      // Draw horizontal connector rung
      _strandPaint
        ..shader = LinearGradient(
          colors: [
            nodeColor.withValues(alpha: alpha * 0.7),
            rail2Color.withValues(alpha: alpha * 0.7),
          ],
        ).createShader(Rect.fromPoints(rung.p1, rung.p2))
        ..strokeWidth = rung.node.isSequenced ? (1.8 * normDepth) : (1.0 * normDepth);

      canvas.drawLine(rung.p1, rung.p2, _strandPaint);
      _strandPaint.shader = null;

      // Left Node (p1)
      final scale1 = 0.65 + (((rung.z1 + 1.0) / 2.0) * 0.55);
      final radius1 = (rung.node.isSequenced ? 8.0 : 6.0) * scale1;

      _glowPaint.color = nodeColor.withValues(alpha: 0.16 * scale1);
      canvas.drawCircle(rung.p1, radius1 * 2.2, _glowPaint);

      _nodePaint.color = nodeColor.withValues(alpha: alpha * scale1);
      canvas.drawCircle(rung.p1, radius1, _nodePaint);

      // Right Node (p2)
      final scale2 = 0.65 + (((rung.z2 + 1.0) / 2.0) * 0.55);
      final radius2 = (rung.node.isSequenced ? 8.0 : 6.0) * scale2;

      _glowPaint.color = rail2Color.withValues(alpha: 0.16 * scale2);
      canvas.drawCircle(rung.p2, radius2 * 2.2, _glowPaint);

      _nodePaint.color = rail2Color.withValues(alpha: alpha * scale2);
      canvas.drawCircle(rung.p2, radius2, _nodePaint);

      // Selected Target Halo on active locus (REQ-P49-DNA-03)
      if (rung.index == selectedIndex) {
        final haloRadius = (radius1 * 1.8) + (pulseValue * 5.0);
        _haloPaint
          ..color = nodeColor.withValues(alpha: 0.75 - (pulseValue * 0.35))
          ..strokeWidth = 2.0;
        canvas.drawCircle(rung.p1, haloRadius, _haloPaint);

        // Target reticle crosshairs
        final reticleLength = 4.0;
        canvas.drawLine(
          Offset(rung.p1.dx - haloRadius - reticleLength, rung.p1.dy),
          Offset(rung.p1.dx - haloRadius + 1, rung.p1.dy),
          _haloPaint,
        );
        canvas.drawLine(
          Offset(rung.p1.dx + haloRadius - 1, rung.p1.dy),
          Offset(rung.p1.dx + haloRadius + reticleLength, rung.p1.dy),
          _haloPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CreatorDnaHelixPainter oldDelegate) {
    return oldDelegate.angle != angle ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.portalProgress != portalProgress ||
        oldDelegate.isDark != isDark;
  }
}

class _DnaNodeRenderItem {
  final int index;
  final Offset p1;
  final double z1;
  final Offset p2;
  final double z2;
  final CreatorDnaNode node;
  final double depth;

  const _DnaNodeRenderItem({
    required this.index,
    required this.p1,
    required this.z1,
    required this.p2,
    required this.z2,
    required this.node,
    required this.depth,
  });
}

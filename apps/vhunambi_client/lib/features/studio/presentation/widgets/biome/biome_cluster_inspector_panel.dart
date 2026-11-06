import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import '../../../domain/models/mycelium_biome_models.dart';

class BiomeClusterInspectorPanel extends ConsumerWidget {
  final MushroomFruitingBody cluster;
  final double animationPhase;
  final VoidCallback onClose;
  final ValueChanged<MyceliumClusterDomain> onSelectPartnerCluster;
  final VoidCallback onExploreDetails;
  final VoidCallback onToggleStemLock;

  const BiomeClusterInspectorPanel({
    super.key = const Key('biome_cluster_inspector_panel'),
    required this.cluster,
    required this.animationPhase,
    required this.onClose,
    required this.onSelectPartnerCluster,
    required this.onExploreDetails,
    required this.onToggleStemLock,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clusterColor = Color(cluster.domain.hexColor);

    return Container(
      width: 290,
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: clusterColor.withValues(alpha: 0.55),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: clusterColor.withValues(alpha: 0.22),
            blurRadius: 22,
            spreadRadius: 1,
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row
          Row(
            children: [
              PhosphorIcon(
                PhosphorIconsBold.waveform,
                color: clusterColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  cluster.domain.displayName,
                  style: AppTypography.titleMedium.copyWith(
                    color: clusterColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              GestureDetector(
                key: const Key('biome_inspector_close_btn'),
                onTap: onClose,
                child: const PhosphorIcon(
                  PhosphorIconsBold.x,
                  color: Colors.white70,
                  size: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            cluster.domain.roleSubtitle,
            style: AppTypography.caption.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 12),

          // Live 28-Bar Audio Waveform Canvas
          SizedBox(
            key: const Key('biome_inspector_waveform'),
            height: 44,
            width: double.infinity,
            child: CustomPaint(
              painter: _InspectorWaveformPainter(
                color: clusterColor,
                phase: animationPhase,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 3 Metrics Row: Intensity, Complexity, Influence
          Row(
            children: [
              Expanded(child: _buildMetricColumn('Intensity', '${cluster.intensityPercent}%')),
              Expanded(child: _buildMetricColumn('Complexity', '${cluster.complexityPercent}%')),
              Expanded(child: _buildMetricColumn('Influence', '${cluster.influencePercent}%')),
            ],
          ),
          const SizedBox(height: 12),

          // Live 2D Telemetry Summary & Stem Authority Control (REQ-P54-TELE-01)
          if (cluster.liveTelemetrySummary.isNotEmpty) ...[
            Text(
              cluster.liveTelemetrySummary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
          ],
          GestureDetector(
            key: const Key('biome_inspector_stem_lock_btn'),
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              onToggleStemLock();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: cluster.isStemLocked
                    ? clusterColor.withValues(alpha: 0.22)
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: cluster.isStemLocked
                      ? clusterColor
                      : Colors.white24,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PhosphorIcon(
                    cluster.isStemLocked
                        ? PhosphorIconsBold.lockKey
                        : PhosphorIconsBold.sparkle,
                    size: 13,
                    color: cluster.isStemLocked ? clusterColor : Colors.white70,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      cluster.isStemLocked
                          ? 'Stem-Locked (Pure 44.1 kHz)'
                          : 'Guided AI Inpaint Active',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 10),

          // Related Intersecting Nodes
          Text(
            'Related Nodes',
            style: AppTypography.caption.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: cluster.connectedDomains.map((partner) {
              final pColor = Color(partner.hexColor);
              return GestureDetector(
                key: Key('biome_related_chip_${partner.name}'),
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelectPartnerCluster(partner);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: pColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: pColor.withValues(alpha: 0.45)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: pColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        partner.shortLabel,
                        style: AppTypography.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Explore Details / Studio Cockpit Mutator Trigger
          SizedBox(
            width: double.infinity,
            height: 38,
            child: OutlinedButton(
              key: const Key('biome_explore_details_btn'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: clusterColor.withValues(alpha: 0.75)),
                backgroundColor: clusterColor.withValues(alpha: 0.14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: onExploreDetails,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Explore Details',
                    style: AppTypography.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const PhosphorIcon(
                    PhosphorIconsBold.arrowRight,
                    color: Colors.white,
                    size: 14,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: Colors.white60,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.titleMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _InspectorWaveformPainter extends CustomPainter {
  final Color color;
  final double phase;

  const _InspectorWaveformPainter({required this.color, required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    const int bars = 32;
    final step = size.width / bars;
    final midY = size.height * 0.5;

    for (int i = 0; i < bars; i++) {
      final x = (i + 0.5) * step;
      final env = math.sin((i / bars) * math.pi);
      final wave = (0.25 + 0.75 * math.sin(phase * 2.0 * math.pi + i * 0.45).abs()) * env;
      final halfH = (size.height * 0.46 * wave).clamp(2.0, size.height * 0.48);

      paint.color = Color.lerp(color, const Color(0xFFF72585), i / bars)!
          .withValues(alpha: 0.88);
      canvas.drawLine(Offset(x, midY - halfH), Offset(x, midY + halfH), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _InspectorWaveformPainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.color != color;
}

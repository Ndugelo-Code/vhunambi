import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../profile/domain/models/creator_dna_node.dart';
import '../../../profile/presentation/widgets/creator_dna_helix_lab_sheet.dart';
import '../providers/creator_dna_provider.dart';
import '../../domain/entities/creator_dna_profile.dart';
import 'dna_genre_badge.dart';
import 'dna_strength_meter.dart';

/// Full-fidelity Creator DNA card rendered in Owner and Artist profiles,
/// showcasing sound signature metrics, 3D interactive double-helix preview,
/// genre affinities, on-device privacy status, and DNA Lab launcher (REQ-P49-LAB-01).
class CreatorDnaProfileCard extends ConsumerWidget {
  final bool isOwner;
  final CreatorDnaProfile? customDna;

  const CreatorDnaProfileCard({super.key, this.isOwner = true, this.customDna});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CreatorDnaProfile dna = customDna ?? ref.watch(creatorDnaProvider);

    return Container(
      key: const Key('creator_dna_profile_card'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Text('🧬', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        'Creator DNA',
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: AppRadius.pillBorder,
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Text(
                  dna.lifecycleState.name.toUpperCase(),
                  style: AppTypography.caption.copyWith(
                    color: DnaStrengthMeter.zoneColor(dna.strengthPercent),
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Strength & Meter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Sound Signature Attunement',
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '${dna.strengthPercent}%',
                style: AppTypography.bodySmall.copyWith(
                  color: DnaStrengthMeter.zoneColor(dna.strengthPercent),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          DnaStrengthMeter(strengthPercent: dna.strengthPercent),

          const SizedBox(height: AppSpacing.md),

          // 3D Mini-Helix Interactive Preview (REQ-P49-LAB-01)
          _MiniDnaHelixPreview(dna: dna),

          const SizedBox(height: AppSpacing.sm),

          // Open 3D DNA Lab Action Button (REQ-P49-LAB-01)
          SizedBox(
            width: double.infinity,
            height: 38,
            child: OutlinedButton.icon(
              key: const Key('open_3d_dna_lab_btn'),
              onPressed: () =>
                  CreatorDnaHelixLabSheet.show(context, profile: dna),
              icon: const Text('🧬', style: TextStyle(fontSize: 14)),
              label: Text(
                'Open 3D DNA Lab',
                style: AppTypography.caption.copyWith(
                  color: AppColors.brandPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: AppColors.brandPrimary.withValues(alpha: 0.5),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.pillBorder,
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Top Genres
          if (dna.genreWeights.isNotEmpty) ...[
            Text(
              'Affinities & Heritage',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: dna.topGenres(4).asMap().entries.map((entry) {
                return DnaGenreBadge(genre: entry.value, rank: entry.key + 1);
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Sound signature specs
          Row(
            children: [
              Expanded(
                child: _buildSpecTile(
                  'Rhythm',
                  dna.tempoPreference.toUpperCase(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _buildSpecTile(
                  'Vocal Energy',
                  dna.vocalEnergyPreference.toUpperCase(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _buildSpecTile('Language', dna.primaryLanguage)),
            ],
          ),

          if (isOwner) ...[
            const SizedBox(height: AppSpacing.md),
            Divider(color: AppColors.borderSubtle),
            const SizedBox(height: AppSpacing.xs),

            // Privacy Guarantee & Reset Action
            Row(
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 14,
                  color: AppColors.success,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Stored 100% locally on your device',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 10,
                    ),
                  ),
                ),
                TextButton(
                  key: const Key('reset_dna_button'),
                  onPressed: () => _confirmReset(context, ref),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(
                    'Reset DNA',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSpecTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surfaceModal,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardBorder,
          side: BorderSide(color: AppColors.borderSubtle),
        ),
        title: const Text(
          'Reset Creator DNA?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'This will erase your on-device taste weights, prompt pre-fills, and telemetry log. This action cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            key: const Key('confirm_reset_dna_button'),
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              await ref.read(creatorDnaProvider.notifier).resetDna();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Creator DNA has been reset to defaults'),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

/// Lightweight 3D Mini-Helix preview embedded in profile card (REQ-P49-LAB-01).
class _MiniDnaHelixPreview extends StatefulWidget {
  final CreatorDnaProfile dna;

  const _MiniDnaHelixPreview({required this.dna});

  @override
  State<_MiniDnaHelixPreview> createState() => _MiniDnaHelixPreviewState();
}

class _MiniDnaHelixPreviewState extends State<_MiniDnaHelixPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;

  bool get _shouldAnimate {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final isTestBinding =
        const bool.fromEnvironment('FLUTTER_TEST') ||
        WidgetsBinding.instance.runtimeType.toString().contains(
          'TestWidgetsFlutterBinding',
        );
    return !disableAnimations && !isTestBinding;
  }

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_shouldAnimate) {
      if (!_rotationController.isAnimating) {
        _rotationController.repeat();
      }
    } else {
      if (_rotationController.isAnimating) {
        _rotationController.stop();
      }
      _rotationController.value = 0.25;
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nodes = CreatorDnaNode.fromCreatorDnaProfile(widget.dna);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => CreatorDnaHelixLabSheet.show(context, profile: widget.dna),
      child: Container(
        height: 110,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF101017) : const Color(0xFFF7F7FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.brandPrimary.withValues(alpha: 0.18),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AnimatedBuilder(
            animation: _rotationController,
            builder: (context, _) {
              final angle = _rotationController.value * 2 * math.pi;
              return CustomPaint(
                size: Size.infinite,
                painter: _MiniHelixPainter(
                  angle: angle,
                  nodes: nodes,
                  isDark: isDark,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MiniHelixPainter extends CustomPainter {
  final double angle;
  final List<CreatorDnaNode> nodes;
  final bool isDark;

  final Paint _strandPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  final Paint _nodePaint = Paint()..style = PaintingStyle.fill;

  _MiniHelixPainter({
    required this.angle,
    required this.nodes,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || nodes.isEmpty) return;

    final centerX = size.width * 0.5;
    final topY = size.height * 0.12;
    final bottomY = size.height * 0.88;
    final totalHeight = bottomY - topY;

    final helixRadius = (size.width * 0.22).clamp(40.0, 75.0);
    final int count = nodes.length;
    final double stepY = totalHeight / (count - 1);

    for (int i = 0; i < count; i++) {
      final y = topY + (i * stepY);
      final phase = angle + (i * 0.7);

      final x1 = centerX + (math.cos(phase) * helixRadius);
      final z1 = math.sin(phase);

      final x2 = centerX + (math.cos(phase + math.pi) * helixRadius);
      final z2 = math.sin(phase + math.pi);

      final node = nodes[i];
      final normDepth = (((z1 + z2) * 0.5 + 1.0) / 2.0).clamp(0.2, 1.0);
      final alpha = isDark
          ? (0.20 + (normDepth * 0.65))
          : (0.15 + (normDepth * 0.55));

      _strandPaint
        ..color = node.accentColor.withValues(alpha: alpha * 0.6)
        ..strokeWidth = 1.2 * normDepth;
      canvas.drawLine(Offset(x1, y), Offset(x2, y), _strandPaint);

      // Node circles
      final scale1 = 0.6 + (((z1 + 1.0) / 2.0) * 0.4);
      _nodePaint.color = node.accentColor.withValues(alpha: alpha * scale1);
      canvas.drawCircle(Offset(x1, y), 5.0 * scale1, _nodePaint);

      final scale2 = 0.6 + (((z2 + 1.0) / 2.0) * 0.4);
      _nodePaint.color =
          (node.isSequenced ? AppColors.badgeCyan : AppColors.textTertiary)
              .withValues(alpha: alpha * scale2);
      canvas.drawCircle(Offset(x2, y), 5.0 * scale2, _nodePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniHelixPainter oldDelegate) {
    return oldDelegate.angle != angle || oldDelegate.isDark != isDark;
  }
}

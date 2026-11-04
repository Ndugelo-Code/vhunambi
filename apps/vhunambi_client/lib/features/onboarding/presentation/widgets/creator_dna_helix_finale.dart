import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/onboarding_providers.dart';

/// Act 4: Interactive 3D Double-Helix Creator DNA & Particle Genesis (REQ-P47-ACT4-01..04).
/// Replaces the static form with a 3D spinning DNA helix and non-truncated CTA button.
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
  late final AnimationController _portalController;
  double _manualAngleOffset = 0.0;
  bool _isPortalExpanding = false;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _portalController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingStateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Build DNA trait descriptors from selected state
    final traits = <_DnaTrait>[
      _DnaTrait(
        label: state.creativeRole.name.toUpperCase(),
        color: const Color(0xFFF97316),
      ),
      _DnaTrait(
        label: state.tempoPreference.toUpperCase(),
        color: const Color(0xFF06B6D4),
      ),
      ...state.selectedGenres
          .take(4)
          .map((g) => _DnaTrait(label: g, color: const Color(0xFF10B981))),
      ...state.selectedLanguages
          .take(3)
          .map((l) => _DnaTrait(label: l, color: const Color(0xFFF59E0B))),
      _DnaTrait(label: '85% SOVEREIGN', color: const Color(0xFFEC4899)),
    ];

    return Padding(
      key: const Key('onboarding_act_4_dna_finale'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: [
          // Title & Subtitle
          Text(
            'Your Creator DNA is Live',
            style: AppTypography.displayLarge.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 24,
              color: AppColors.textPrimaryOf(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Drag to inspect your rotating 3D genomic synthesis strand',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondaryOf(context),
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 10),

          // 3D Double-Helix Interactive Stage
          Expanded(
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _manualAngleOffset += details.delta.dx * 0.015;
                });
              },
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _rotationController,
                  _portalController,
                ]),
                builder: (context, _) {
                  final rotationAngle =
                      (_rotationController.value * 2 * math.pi) +
                      _manualAngleOffset;
                  final portalProgress = _portalController.value;

                  return CustomPaint(
                    size: Size.infinite,
                    painter: _CreatorDnaHelixPainter(
                      angle: rotationAngle,
                      traits: traits,
                      isDark: isDark,
                      portalProgress: portalProgress,
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Trait Pills Summary Row
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildTraitChip(
                PhosphorIconsRegular.user,
                state.creativeRole.name.toUpperCase(),
                AppColors.brandPrimary,
              ),
              _buildTraitChip(
                PhosphorIconsRegular.disc,
                state.selectedGenres.isNotEmpty
                    ? state.selectedGenres.first
                    : 'Amapiano',
                AppColors.badgeCyan,
              ),
              _buildTraitChip(
                PhosphorIconsRegular.translate,
                state.primaryLanguage,
                AppColors.success,
              ),
              _buildTraitChip(
                PhosphorIconsRegular.shieldCheck,
                'Sovereign IP',
                AppColors.coinGold,
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Prominent Full-Width Non-Truncated CTA Button (REQ-P47-BUG-04)
          SizedBox(
            width: double.infinity,
            height: 54,
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
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 8,
                shadowColor: AppColors.brandPrimary.withValues(alpha: 0.45),
              ),
            ),
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildTraitChip(PhosphorIconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PhosphorIcon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DnaTrait {
  final String label;
  final Color color;

  const _DnaTrait({required this.label, required this.color});
}

/// 3D CustomPainter for the spinning Double-Helix DNA strand (REQ-P47-ACT4-01..03).
class _CreatorDnaHelixPainter extends CustomPainter {
  final double angle;
  final List<_DnaTrait> traits;
  final bool isDark;
  final double portalProgress;

  final Paint _strandPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  final Paint _nodePaint = Paint()..style = PaintingStyle.fill;
  final Paint _glowPaint = Paint()
    ..style = PaintingStyle.fill
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

  _CreatorDnaHelixPainter({
    required this.angle,
    required this.traits,
    required this.isDark,
    required this.portalProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final centerX = size.width * 0.5;
    final topY = size.height * 0.08;
    final bottomY = size.height * 0.92;
    final totalHeight = bottomY - topY;

    final double helixRadius = (size.width * 0.28).clamp(70.0, 130.0);
    const int rungsCount = 14;
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
    final rungs = <_DnaRungRenderItem>[];

    for (int i = 0; i < rungsCount; i++) {
      final y = topY + (i * stepY);
      final phase = angle + (i * 0.45);

      final x1 = centerX + (math.cos(phase) * helixRadius);
      final z1 = math.sin(phase); // -1.0 to 1.0

      final x2 = centerX + (math.cos(phase + math.pi) * helixRadius);
      final z2 = math.sin(phase + math.pi);

      final trait = traits[i % traits.length];

      rungs.add(
        _DnaRungRenderItem(
          p1: Offset(x1, y),
          z1: z1,
          p2: Offset(x2, y),
          z2: z2,
          trait: trait,
          depth: (z1 + z2) * 0.5,
        ),
      );
    }

    // Sort by depth (farthest first)
    rungs.sort((a, b) => a.depth.compareTo(b.depth));

    // Render rungs and nodes in 3D order
    for (final rung in rungs) {
      final normDepth = ((rung.depth + 1.0) / 2.0).clamp(
        0.2,
        1.0,
      ); // 0.2 to 1.0
      final alpha = isDark
          ? (0.25 + (normDepth * 0.70))
          : (0.20 + (normDepth * 0.60));

      // Draw horizontal connector rung
      _strandPaint
        ..shader = LinearGradient(
          colors: [
            rung.trait.color.withValues(alpha: alpha * 0.7),
            AppColors.badgeCyan.withValues(alpha: alpha * 0.7),
          ],
        ).createShader(Rect.fromPoints(rung.p1, rung.p2))
        ..strokeWidth = 1.6 * normDepth;

      canvas.drawLine(rung.p1, rung.p2, _strandPaint);
      _strandPaint.shader = null;

      // Draw Left Node (p1)
      final scale1 = 0.65 + (((rung.z1 + 1.0) / 2.0) * 0.55);
      final radius1 = 7.0 * scale1;

      _glowPaint.color = rung.trait.color.withValues(alpha: (0.15 * scale1));
      canvas.drawCircle(rung.p1, radius1 * 2.2, _glowPaint);

      _nodePaint.color = rung.trait.color.withValues(alpha: (alpha * scale1));
      canvas.drawCircle(rung.p1, radius1, _nodePaint);

      // Draw Right Node (p2)
      final scale2 = 0.65 + (((rung.z2 + 1.0) / 2.0) * 0.55);
      final radius2 = 7.0 * scale2;

      _glowPaint.color = AppColors.badgeCyan.withValues(alpha: (0.15 * scale2));
      canvas.drawCircle(rung.p2, radius2 * 2.2, _glowPaint);

      _nodePaint.color = AppColors.badgeCyan.withValues(
        alpha: (alpha * scale2),
      );
      canvas.drawCircle(rung.p2, radius2, _nodePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CreatorDnaHelixPainter oldDelegate) {
    return oldDelegate.angle != angle ||
        oldDelegate.portalProgress != portalProgress ||
        oldDelegate.isDark != isDark;
  }
}

class _DnaRungRenderItem {
  final Offset p1;
  final double z1;
  final Offset p2;
  final double z2;
  final _DnaTrait trait;
  final double depth;

  const _DnaRungRenderItem({
    required this.p1,
    required this.z1,
    required this.p2,
    required this.z2,
    required this.trait,
    required this.depth,
  });
}

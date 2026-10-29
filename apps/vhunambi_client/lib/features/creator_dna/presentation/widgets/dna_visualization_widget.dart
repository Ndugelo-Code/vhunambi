import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vhunambi_client/core/design_system/design_system.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/features/creator_dna/domain/entities/creator_dna_profile.dart';

/// Animated visual representation of the user's Creator DNA.
///
/// Renders a radial/orbital graphic where nodes light up one by one in a
/// build-up sequence over 1800ms. Node colors are derived from the user's
/// onboarding selections (genre, mood, role). When reduce-motion is enabled,
/// displays a static version with all nodes illuminated and no animation.
///
/// Satisfies REQ-VH011-01 through REQ-VH011-08.
class DnaVisualizationWidget extends StatefulWidget {
  final CreativeRole creativeRole;
  final List<String> genres;
  final List<String> moods;
  final String tempoPreference;
  final bool reduceMotion;

  const DnaVisualizationWidget({
    super.key,
    required this.creativeRole,
    required this.genres,
    required this.moods,
    required this.tempoPreference,
    this.reduceMotion = false,
  });

  @override
  State<DnaVisualizationWidget> createState() => _DnaVisualizationWidgetState();
}

class _DnaVisualizationWidgetState extends State<DnaVisualizationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _buildUpAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _buildUpAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    if (!widget.reduceMotion) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant DnaVisualizationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reduceMotion != oldWidget.reduceMotion) {
      if (widget.reduceMotion) {
        _controller.value = 1.0;
        _controller.stop();
      } else {
        _controller.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _genreColor(String genreName) {
    try {
      final genre = Genre.values.firstWhere(
        (g) => g.displayName.toLowerCase() == genreName.toLowerCase(),
      );
      return DesignTokenRegistry.getGenreAccent(genre);
    } catch (_) {
      return AppColors.brandPrimary;
    }
  }

  Color _moodColor(String moodName) {
    try {
      final mood = Mood.values.firstWhere(
        (m) => m.displayName.toLowerCase() == moodName.toLowerCase(),
      );
      return DesignTokenRegistry.getMoodAccent(mood);
    } catch (_) {
      return AppColors.brandPrimary;
    }
  }

  Color _roleColor(CreativeRole role) {
    switch (role) {
      case CreativeRole.producer:
        return AppColors.brandPrimary;
      case CreativeRole.vocalist:
        return AppColors.accentElectric;
      case CreativeRole.songwriter:
        return AppColors.accentGold;
      case CreativeRole.multiHyphenate:
        return AppColors.accentSuccess;
      case CreativeRole.musicLover:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Creator DNA visualization built from your role, genres, tempo, vocal feel, and mood choices',
      child: SizedBox(
        width: double.infinity,
        height: 260,
        child: AnimatedBuilder(
          animation: _buildUpAnimation,
          builder: (context, child) {
            return CustomPaint(
              size: Size.infinite,
              painter: DnaPainter(
                buildUp: widget.reduceMotion ? 1.0 : _buildUpAnimation.value,
                roleColor: _roleColor(widget.creativeRole),
                genreColors: widget.genres.map(_genreColor).toList(),
                moodColors: widget.moods.map(_moodColor).toList(),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Custom painter that renders the radial/orbital DNA visualization.
class DnaPainter extends CustomPainter {
  final double buildUp;
  final Color roleColor;
  final List<Color> genreColors;
  final List<Color> moodColors;

  const DnaPainter({
    required this.buildUp,
    required this.roleColor,
    required this.genreColors,
    required this.moodColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.35;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (int i = 0; i < 3; i++) {
      final ringRadius = radius * (0.3 + i * 0.25);
      ringPaint.color = AppColors.borderSubtle.withValues(alpha: 0.3);
      canvas.drawCircle(center, ringRadius, ringPaint);
    }

    final allColors = <Color>[];
    allColors.add(roleColor);
    allColors.addAll(genreColors);
    allColors.addAll(moodColors);

    final nodeCount = allColors.length;
    if (nodeCount == 0) return;

    for (int i = 0; i < nodeCount; i++) {
      final angle = (2 * math.pi * i / nodeCount) - (math.pi / 2);
      final nodeRadius = radius * 0.6;
      final nodeOffset = Offset(
        center.dx + nodeRadius * math.cos(angle),
        center.dy + nodeRadius * math.sin(angle),
      );

      final threshold = i / nodeCount;
      final lit = buildUp > threshold;

      if (lit) {
        final nodePaint = Paint()
          ..color = allColors[i]
          ..style = PaintingStyle.fill;
        canvas.drawCircle(nodeOffset, 6.0, nodePaint);

        final glowPaint = Paint()
          ..color = allColors[i].withValues(alpha: 0.4)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(
            BlurStyle.normal,
            6.0,
          );
        canvas.drawCircle(nodeOffset, 6.0, glowPaint);
      } else {
        final unlitPaint = Paint()
          ..color = AppColors.borderSubtle.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawCircle(nodeOffset, 5.0, unlitPaint);
      }
    }

    final centerPaint = Paint()
      ..color = roleColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 8.0, centerPaint);

    final centerGlow = Paint()
      ..color = roleColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
    canvas.drawCircle(center, 8.0, centerGlow);
  }

  @override
  bool shouldRepaint(covariant DnaPainter oldDelegate) =>
      oldDelegate.buildUp != buildUp ||
      oldDelegate.roleColor != roleColor ||
      oldDelegate.genreColors != genreColors ||
      oldDelegate.moodColors != moodColors;
}

/// Growth path explanation widget showing three explanation beats below
/// the DNA visualization.
class DnaGrowthPathWidget extends StatelessWidget {
  const DnaGrowthPathWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildExplanationBeat(
          'Built from your choices:',
          'your roles, genres, tempo, vocal feel, mood',
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildExplanationBeat(
          'Shapes every song:',
          'pre-fills the cockpit and steers generation toward your sound',
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildExplanationBeat(
          'Grows with you:',
          'every song you make, keep, or edit sharpens it',
        ),
      ],
    );
  }

  Widget _buildExplanationBeat(String lead, String rest) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 6, right: 8),
          decoration: const BoxDecoration(
            color: AppColors.brandPrimary,
            shape: BoxShape.circle,
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lead,
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                rest,
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

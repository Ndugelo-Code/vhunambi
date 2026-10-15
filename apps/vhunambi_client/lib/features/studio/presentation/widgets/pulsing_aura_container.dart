import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';

/// Animated container with a breathing gradient glow aura (M10 / REQ-KIN-04).
///
/// While [isPulsing] is `true`, a 1.5s sine-like oscillation breathes a
/// `AppColors.brandPrimary` glow around the child — used to signal AI prompt
/// refinement and active generation. Stops cleanly when [isPulsing] flips
/// back to `false` and on dispose.
class PulsingAuraContainer extends StatefulWidget {
  const PulsingAuraContainer({
    super.key,
    required this.child,
    this.isPulsing = false,
    this.borderRadius = AppRadius.cardBorder,
  });

  final Widget child;
  final bool isPulsing;
  final BorderRadius borderRadius;

  @override
  State<PulsingAuraContainer> createState() => _PulsingAuraContainerState();
}

class _PulsingAuraContainerState extends State<PulsingAuraContainer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.isPulsing) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(PulsingAuraContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPulsing == oldWidget.isPulsing) return;
    if (widget.isPulsing) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.animateTo(0, duration: const Duration(milliseconds: 300));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (!widget.isPulsing || disableAnimations) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        // Sine-like breathing: -cos maps the 0→1 controller onto a smooth
        // 0→1→0 cycle peaking mid-sweep.
        final wave = (math.sin(_controller.value * 2 * math.pi - math.pi / 2) +
                1) /
            2;
        return Container(
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            boxShadow: [
              BoxShadow(
                color: AppColors.brandPrimary.withValues(alpha: 0.08 + 0.25 * wave),
                blurRadius: 12 + 8 * wave,
                spreadRadius: 1 + 2 * wave,
              ),
            ],
          ),
          child: child,
        );
      },
    );
  }
}
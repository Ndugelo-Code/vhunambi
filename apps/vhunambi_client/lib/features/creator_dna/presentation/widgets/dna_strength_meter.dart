import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Animated visual meter displaying the creator's DNA model confidence percentage.
class DnaStrengthMeter extends StatefulWidget {
  final int strengthPercent;
  final bool animated;
  final double height;

  const DnaStrengthMeter({
    super.key,
    required this.strengthPercent,
    this.animated = true,
    this.height = 8.0,
  });

  static Color zoneColor(int percent) {
    if (percent >= 70) return AppColors.success;
    if (percent >= 40) return AppColors.coinGold;
    return AppColors.badgeCyan;
  }

  @override
  State<DnaStrengthMeter> createState() => _DnaStrengthMeterState();
}

class _DnaStrengthMeterState extends State<DnaStrengthMeter>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _animation;

  @override
  void initState() {
    super.initState();
    if (widget.animated) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 800),
      );
      _animation = CurvedAnimation(
        parent: _controller!,
        curve: Curves.easeOut,
      );
      _controller!.forward();
    }
  }

  @override
  void didUpdateWidget(covariant DnaStrengthMeter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animated && _controller != null) {
      _controller!.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final targetFraction = (widget.strengthPercent / 100.0).clamp(0.0, 1.0);
    final color = DnaStrengthMeter.zoneColor(widget.strengthPercent);

    return Semantics(
      label: 'Creator DNA Strength: ${widget.strengthPercent}%',
      child: Container(
        key: const Key('dna_strength_meter'),
        height: widget.height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(widget.height / 2),
        ),
        child: widget.animated && _animation != null
            ? AnimatedBuilder(
                animation: _animation!,
                builder: (context, _) {
                  return FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (_animation!.value * targetFraction).clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(widget.height / 2),
                      ),
                    ),
                  );
                },
              )
            : FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: targetFraction,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(widget.height / 2),
                  ),
                ),
              ),
      ),
    );
  }
}

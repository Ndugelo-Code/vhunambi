import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class WaveformBars extends StatefulWidget {
  final bool isPlaying;
  final int barCount;
  final double maxHeight;

  const WaveformBars({
    super.key,
    required this.isPlaying,
    this.barCount = 8,
    this.maxHeight = 22.0,
  });

  @override
  State<WaveformBars> createState() => _WaveformBarsState();
}

class _WaveformBarsState extends State<WaveformBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant WaveformBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(widget.barCount, (index) {
            final phase = (index / widget.barCount) * 3.14159;
            final dynamicFactor = widget.isPlaying
                ? ((_controller.value + phase).remainder(1.0))
                : 0.35;
            final height = 6.0 + (widget.maxHeight - 6.0) * dynamicFactor;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 3,
              height: height,
              decoration: BoxDecoration(
                color: AppColors.brandPrimary,
                borderRadius: BorderRadius.circular(1.5),
              ),
            );
          }),
        );
      },
    );
  }
}

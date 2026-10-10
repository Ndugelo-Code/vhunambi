import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';

/// Base shimmering placeholder box (token-disciplined, hydration/headless safe).
class ShimmerBox extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius borderRadius;
  final bool animate;

  const ShimmerBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = AppRadius.thumbBorder,
    this.animate = true,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _opacity;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1000),
      )..repeat(reverse: true);
      _opacity = _controller!.drive(
        Tween<double>(begin: 0.35, end: 0.85)
            .chain(CurveTween(curve: Curves.easeInOut)),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: widget.borderRadius,
      ),
    );

    if (_opacity != null) {
      return FadeTransition(
        opacity: _opacity!,
        child: box,
      );
    }

    return box;
  }
}

/// Shimmer skeleton row representing a list tile (e.g. Asset Vault or Track list).
class TrackTileSkeleton extends StatelessWidget {
  final bool animate;

  const TrackTileSkeleton({super.key, this.animate = true});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          ShimmerBox(
            width: 48,
            height: 48,
            borderRadius: AppRadius.cardBorder,
            animate: animate,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(
                  width: 140,
                  height: 14,
                  borderRadius: AppRadius.thumbBorder,
                  animate: animate,
                ),
                const SizedBox(height: 6),
                ShimmerBox(
                  width: 90,
                  height: 10,
                  borderRadius: AppRadius.thumbBorder,
                  animate: animate,
                ),
              ],
            ),
          ),
          ShimmerBox(
            width: 32,
            height: 12,
            borderRadius: AppRadius.thumbBorder,
            animate: animate,
          ),
        ],
      ),
    );
  }
}

/// Shimmer skeleton representing a 1:1 artwork grid card (e.g. Explore/Vault grids).
class TrackGridCardSkeleton extends StatelessWidget {
  final bool animate;

  const TrackGridCardSkeleton({super.key, this.animate = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ShimmerBox(
            width: double.infinity,
            height: double.infinity,
            borderRadius: AppRadius.cardBorder,
            animate: animate,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        ShimmerBox(
          width: 110,
          height: 12,
          borderRadius: AppRadius.thumbBorder,
          animate: animate,
        ),
        const SizedBox(height: 4),
        ShimmerBox(
          width: 70,
          height: 10,
          borderRadius: AppRadius.thumbBorder,
          animate: animate,
        ),
      ],
    );
  }
}

/// Shimmer skeleton representing an entire shelf section with header and grid cards.
class ShelfSectionSkeleton extends StatelessWidget {
  final int cardCount;
  final bool animate;

  const ShelfSectionSkeleton({
    super.key,
    this.cardCount = 4,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBox(
            width: 150,
            height: 18,
            borderRadius: AppRadius.thumbBorder,
            animate: animate,
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: cardCount,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (_, _) => SizedBox(
                width: 140,
                child: TrackGridCardSkeleton(animate: animate),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

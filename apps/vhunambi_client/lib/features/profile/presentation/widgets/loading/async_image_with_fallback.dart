import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../shared/widgets/shimmer_skeleton.dart';

enum ImageLoadingState { loading, loaded, error }

/// Image widget with shimmer loading state and monogram gradient fallback on failure or null URL.
class AsyncImageWithFallback extends StatefulWidget {
  final String? imageUrl;
  final String monogram;
  final double size;
  final BorderRadius? borderRadius;

  const AsyncImageWithFallback({
    super.key,
    this.imageUrl,
    required this.monogram,
    required this.size,
    this.borderRadius,
  });

  @override
  State<AsyncImageWithFallback> createState() => _AsyncImageWithFallbackState();
}

class _AsyncImageWithFallbackState extends State<AsyncImageWithFallback> {
  ImageLoadingState _loadingState = ImageLoadingState.loading;

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(widget.size / 2);

    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) {
      return _buildMonogramFallback(radius);
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            if (_loadingState == ImageLoadingState.loading)
              ShimmerBox(
                width: widget.size,
                height: widget.size,
                borderRadius: radius,
              ),
            if (_loadingState == ImageLoadingState.error)
              _buildMonogramFallback(radius),
            if (_loadingState != ImageLoadingState.error)
              Image.network(
                widget.imageUrl!,
                width: widget.size,
                height: widget.size,
                fit: BoxFit.cover,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded || frame != null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && _loadingState != ImageLoadingState.loaded) {
                        setState(() => _loadingState = ImageLoadingState.loaded);
                      }
                    });
                    return child;
                  }
                  return const SizedBox.shrink();
                },
                errorBuilder: (context, error, stackTrace) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _loadingState != ImageLoadingState.error) {
                      setState(() => _loadingState = ImageLoadingState.error);
                    }
                  });
                  return const SizedBox.shrink();
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) {
                    return child;
                  }
                  return const SizedBox.shrink();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonogramFallback(BorderRadius radius) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        gradient: generateMonogramGradient(widget.monogram),
        borderRadius: radius,
      ),
      child: Center(
        child: Text(
          widget.monogram,
          style: TextStyle(
            fontSize: widget.size * 0.4,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Generates a deterministic dual-stop gradient based on a seed string hash.
LinearGradient generateMonogramGradient(String seed) {
  final hash = seed.hashCode.abs();
  final hues = [
    [AppColors.brandPrimary, AppColors.coinGold],
    [AppColors.badgeCyan, const Color(0xFF6366F1)],
    [const Color(0xFF8B5CF6), const Color(0xFFEC4899)],
    [AppColors.success, const Color(0xFF06B6D4)],
    [const Color(0xFFF43F5E), AppColors.brandPrimary],
  ];
  final pair = hues[hash % hues.length];

  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: pair,
  );
}

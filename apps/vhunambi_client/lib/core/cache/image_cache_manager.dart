import 'package:flutter/widgets.dart';

/// Configures and manages the memory footprint of Flutter's image cache.
/// Limits in-memory decoded image cache to 50 items with LRU eviction and handles low-memory cleanup.
abstract final class ImageCacheManager {
  static const int maxImages = 50;
  static const int maxSizeBytes = 50 * 1024 * 1024; // 50 MB

  /// Initializes the image cache boundaries according to performance specifications.
  static void configure() {
    final imageCache = PaintingBinding.instance.imageCache;
    imageCache.maximumSize = maxImages;
    imageCache.maximumSizeBytes = maxSizeBytes;
  }

  /// Clears in-memory image caches on low-memory warnings or heavy route transitions.
  static void clear() {
    final imageCache = PaintingBinding.instance.imageCache;
    imageCache.clear();
    imageCache.clearLiveImages();
  }

  /// Number of images currently stored in the cache.
  static int get currentSize => PaintingBinding.instance.imageCache.currentSize;

  /// Memory consumed by the image cache in bytes.
  static int get currentSizeBytes => PaintingBinding.instance.imageCache.currentSizeBytes;
}

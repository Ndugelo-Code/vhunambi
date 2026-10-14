import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/cache/image_cache_manager.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  group('ImageCacheManager', () {
    test('configure() sets image cache maximum bounds to 50 items and 50MB', () {
      ImageCacheManager.configure();

      final cache = PaintingBinding.instance.imageCache;
      expect(cache.maximumSize, equals(50));
      expect(cache.maximumSizeBytes, equals(50 * 1024 * 1024));
    });

    test('clear() clears images without throwing', () {
      expect(() => ImageCacheManager.clear(), returnsNormally);
      expect(ImageCacheManager.currentSize, equals(0));
    });
  });
}

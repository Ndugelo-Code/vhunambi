import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/cache/cache_entry.dart';

void main() {
  group('CacheEntry', () {
    test('CacheEntry.now creates entry with current timestamp', () {
      final before = DateTime.now();
      final entry = CacheEntry.now('payload');
      final after = DateTime.now();

      expect(entry.data, 'payload');
      expect(entry.timestamp.isAfter(before.subtract(const Duration(milliseconds: 50))), isTrue);
      expect(entry.timestamp.isBefore(after.add(const Duration(milliseconds: 50))), isTrue);
    });

    test('age getter returns elapsed duration', () async {
      final entry = CacheEntry(
        data: 42,
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      );

      expect(entry.age.inHours, greaterThanOrEqualTo(2));
    });

    test('isStale returns true when older than 24 hours', () {
      final fresh = CacheEntry(
        data: 'fresh',
        timestamp: DateTime.now().subtract(const Duration(hours: 23)),
      );
      final stale = CacheEntry(
        data: 'stale',
        timestamp: DateTime.now().subtract(const Duration(hours: 25)),
      );

      expect(fresh.isStale, isFalse);
      expect(stale.isStale, isTrue);
    });

    test('isStaleWithThreshold allows custom durations', () {
      final entry = CacheEntry(
        data: 'custom',
        timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
      );

      expect(entry.isStaleWithThreshold(const Duration(minutes: 15)), isFalse);
      expect(entry.isStaleWithThreshold(const Duration(minutes: 5)), isTrue);
    });
  });
}

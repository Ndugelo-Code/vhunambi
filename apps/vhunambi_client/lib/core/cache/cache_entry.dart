import 'package:flutter/foundation.dart';

/// Generic cache entry wrapping stored data with a timestamp for staleness detection.
@immutable
class CacheEntry<T> {
  final T data;
  final DateTime timestamp;

  const CacheEntry({
    required this.data,
    required this.timestamp,
  });

  /// Creates a cache entry stamped with the current time.
  factory CacheEntry.now(T data) => CacheEntry(
        data: data,
        timestamp: DateTime.now(),
      );

  /// Time elapsed since the data was cached.
  Duration get age => DateTime.now().difference(timestamp);

  /// Default staleness threshold is 24 hours.
  bool get isStale => isStaleWithThreshold(const Duration(hours: 24));

  /// Checks staleness against a custom threshold.
  bool isStaleWithThreshold(Duration threshold) => age > threshold;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CacheEntry<T> &&
          runtimeType == other.runtimeType &&
          data == other.data &&
          timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(data, timestamp);
}

import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/network/retry_strategy.dart';

void main() {
  group('RetryStrategy', () {
    test('delayFor returns Duration.zero for attempt <= 0', () {
      const strategy = RetryStrategy();
      expect(strategy.delayFor(0), Duration.zero);
      expect(strategy.delayFor(-1), Duration.zero);
    });

    test('calculates exponential backoff for attempts 1 through 5', () {
      const strategy = RetryStrategy(
        initialDelay: Duration(seconds: 1),
        maxDelay: Duration(seconds: 30),
        multiplier: 2.0,
      );

      expect(strategy.delayFor(1), const Duration(seconds: 1));
      expect(strategy.delayFor(2), const Duration(seconds: 2));
      expect(strategy.delayFor(3), const Duration(seconds: 4));
      expect(strategy.delayFor(4), const Duration(seconds: 8));
      expect(strategy.delayFor(5), const Duration(seconds: 16));
    });

    test('enforces maxDelay cap when calculated delay exceeds it', () {
      const strategy = RetryStrategy(
        initialDelay: Duration(seconds: 1),
        maxDelay: Duration(seconds: 10),
        multiplier: 2.0,
      );

      expect(strategy.delayFor(4), const Duration(seconds: 8));
      expect(strategy.delayFor(5), const Duration(seconds: 10)); // 16 capped to 10
      expect(strategy.delayFor(6), const Duration(seconds: 10));
    });

    test('supports custom multiplier and initial delay', () {
      const strategy = RetryStrategy(
        initialDelay: Duration(milliseconds: 500),
        maxDelay: Duration(seconds: 5),
        multiplier: 3.0,
      );

      expect(strategy.delayFor(1), const Duration(milliseconds: 500));
      expect(strategy.delayFor(2), const Duration(milliseconds: 1500));
      expect(strategy.delayFor(3), const Duration(milliseconds: 4500));
      expect(strategy.delayFor(4), const Duration(seconds: 5)); // capped
    });
  });
}

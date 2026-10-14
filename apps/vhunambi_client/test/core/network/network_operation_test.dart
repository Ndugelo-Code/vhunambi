import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/network/error_handler.dart';
import 'package:vhunambi_client/core/network/network_operation.dart';
import 'package:vhunambi_client/core/network/retry_strategy.dart';

void main() {
  group('NetworkOperation', () {
    test('successful execution returns SuccessResult immediately', () async {
      int calls = 0;
      final op = NetworkOperation<String>(
        execute: () async {
          calls++;
          return 'ok';
        },
      );

      final result = await op();
      expect(result.isSuccess, isTrue);
      expect(result.data, 'ok');
      expect(calls, 1);
    });

    test('retries on retryable error until success', () async {
      int calls = 0;
      final delays = <Duration>[];

      final op = NetworkOperation<String>(
        execute: () async {
          calls++;
          if (calls < 3) {
            throw const ApiException(statusCode: 503, message: 'Unavailable');
          }
          return 'recovered';
        },
        retryStrategy: const RetryStrategy(maxAttempts: 3),
        delayFn: (d) async => delays.add(d),
      );

      final result = await op();
      expect(result.isSuccess, isTrue);
      expect(result.data, 'recovered');
      expect(calls, 3);
      expect(delays.length, 2);
    });

    test('stops retry immediately on non-retryable error (e.g. 401)', () async {
      int calls = 0;
      final delays = <Duration>[];

      final op = NetworkOperation<String>(
        execute: () async {
          calls++;
          throw const ApiException(statusCode: 401, message: 'Unauthorized');
        },
        retryStrategy: const RetryStrategy(maxAttempts: 3),
        delayFn: (d) async => delays.add(d),
      );

      final result = await op();
      expect(result.isFailure, isTrue);
      expect(calls, 1);
      expect(delays, isEmpty);
      expect(result.errorMessage, contains('Authentication required'));
    });

    test('stops after reaching maxAttempts on persistent retryable error', () async {
      int calls = 0;
      final delays = <Duration>[];

      final op = NetworkOperation<String>(
        execute: () async {
          calls++;
          throw const ApiException(statusCode: 500, message: 'Server down');
        },
        retryStrategy: const RetryStrategy(maxAttempts: 3),
        delayFn: (d) async => delays.add(d),
      );

      final result = await op();
      expect(result.isFailure, isTrue);
      expect(calls, 3);
      expect(delays.length, 2);
      expect(result.attemptCount, 3);
      expect(result.errorMessage, contains('Server error'));
    });

    test('times out if execution exceeds timeout duration', () async {
      final op = NetworkOperation<String>(
        execute: () async {
          await Future.delayed(const Duration(milliseconds: 100));
          return 'late';
        },
        timeoutDuration: const Duration(milliseconds: 10),
        retryStrategy: const RetryStrategy(maxAttempts: 1),
      );

      final result = await op();
      expect(result.isFailure, isTrue);
      expect(result.errorMessage, contains('timed out'));
    });
  });
}

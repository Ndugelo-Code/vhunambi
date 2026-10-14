import 'dart:async';
import 'error_handler.dart';
import 'operation_result.dart';
import 'retry_strategy.dart';

/// Generic wrapper for async network operations with retry support and timeout handling.
class NetworkOperation<T> {
  final Future<T> Function() execute;
  final RetryStrategy retryStrategy;
  final NetworkErrorHandler errorHandler;
  final Duration timeoutDuration;
  final Future<void> Function(Duration delay)? delayFn;

  const NetworkOperation({
    required this.execute,
    RetryStrategy? retryStrategy,
    NetworkErrorHandler? errorHandler,
    Duration? timeoutDuration,
    this.delayFn,
  })  : retryStrategy = retryStrategy ?? const RetryStrategy(),
        errorHandler = errorHandler ?? const NetworkErrorHandler(),
        timeoutDuration = timeoutDuration ?? const Duration(seconds: 10);

  /// Execute the operation with automatic retry on retryable failure.
  Future<OperationResult<T>> call() async {
    int attemptCount = 0;
    Exception? lastError;

    while (attemptCount < retryStrategy.maxAttempts) {
      try {
        final result = await execute().timeout(
          timeoutDuration,
          onTimeout: () => throw TimeoutException('Operation timed out'),
        );
        return OperationResult.success(result);
      } on Exception catch (e) {
        lastError = e;
        attemptCount++;

        final errorType = errorHandler.classify(e);
        if (!errorType.isRetryable || attemptCount >= retryStrategy.maxAttempts) {
          break;
        }

        final delay = retryStrategy.delayFor(attemptCount);
        if (delayFn != null) {
          await delayFn!(delay);
        } else {
          await Future.delayed(delay);
        }
      }
    }

    final fallbackError = lastError ?? Exception('Unknown operation error');
    return OperationResult.failure(
      errorHandler.toUserMessage(fallbackError),
      fallbackError,
      attemptCount,
    );
  }
}

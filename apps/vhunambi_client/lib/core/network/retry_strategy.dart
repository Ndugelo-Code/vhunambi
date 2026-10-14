import 'dart:math' as math;

/// Exponential backoff retry strategy with configurable parameters.
class RetryStrategy {
  final int maxAttempts;
  final Duration initialDelay;
  final Duration maxDelay;
  final double multiplier;

  const RetryStrategy({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 16),
    this.multiplier = 2.0,
  });

  /// Calculate delay for the given attempt number (1-indexed).
  Duration delayFor(int attempt) {
    if (attempt <= 0) return Duration.zero;

    final factor = math.pow(multiplier, attempt - 1).toDouble();
    final calculatedMs = (initialDelay.inMilliseconds * factor).round();
    final exponentialDelay = Duration(milliseconds: calculatedMs);

    return exponentialDelay > maxDelay ? maxDelay : exponentialDelay;
  }
}

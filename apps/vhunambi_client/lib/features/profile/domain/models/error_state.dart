import 'package:flutter/foundation.dart';
import 'profile_operation_type.dart';

/// Structured error context for a failed profile operation.
@immutable
class ErrorState {
  final String message;
  final ProfileOperationType operationType;
  final DateTime timestamp;
  final int attemptCount;
  final bool isRetryable;
  final String? context;

  const ErrorState({
    required this.message,
    required this.operationType,
    required this.timestamp,
    this.attemptCount = 1,
    this.isRetryable = false,
    this.context,
  });

  /// Factory helper for creating an ErrorState now.
  factory ErrorState.now({
    required String message,
    required ProfileOperationType operationType,
    int attemptCount = 1,
    bool isRetryable = false,
    String? context,
  }) =>
      ErrorState(
        message: message,
        operationType: operationType,
        timestamp: DateTime.now(),
        attemptCount: attemptCount,
        isRetryable: isRetryable,
        context: context,
      );

  /// Determines if a retry button should be offered to the user.
  bool get shouldShowRetry => isRetryable && attemptCount < 3;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ErrorState &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          operationType == other.operationType &&
          attemptCount == other.attemptCount &&
          isRetryable == other.isRetryable &&
          context == other.context;

  @override
  int get hashCode => Object.hash(
        message,
        operationType,
        attemptCount,
        isRetryable,
        context,
      );
}

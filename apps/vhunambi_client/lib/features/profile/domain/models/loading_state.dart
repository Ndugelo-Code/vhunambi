import 'package:flutter/foundation.dart';

/// Represents loading state for a specific async profile operation.
@immutable
class LoadingState {
  final bool isLoading;
  final int? retryAttempt;
  final DateTime? startTime;

  const LoadingState({
    required this.isLoading,
    this.retryAttempt,
    this.startTime,
  });

  /// Idle state indicating no active operation.
  const LoadingState.idle()
      : isLoading = false,
        retryAttempt = null,
        startTime = null;

  /// Active loading state with optional retry counter and start timestamp.
  factory LoadingState.loading({
    int? retryAttempt,
    DateTime? startTime,
  }) =>
      LoadingState(
        isLoading: true,
        retryAttempt: retryAttempt,
        startTime: startTime ?? DateTime.now(),
      );

  /// User-facing retry indicator string.
  String get retryLabel {
    if (retryAttempt != null && retryAttempt! > 0) {
      return 'Retrying... ($retryAttempt/3)';
    }
    return '';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoadingState &&
          runtimeType == other.runtimeType &&
          isLoading == other.isLoading &&
          retryAttempt == other.retryAttempt &&
          startTime == other.startTime;

  @override
  int get hashCode => Object.hash(isLoading, retryAttempt, startTime);
}

/// Result type for network operations, containing either success or failure.
sealed class OperationResult<T> {
  const OperationResult();

  factory OperationResult.success(T data) = SuccessResult<T>;
  factory OperationResult.failure(
    String message,
    Exception error, [
    int attemptCount,
  ]) = FailureResult<T>;

  bool get isSuccess => this is SuccessResult<T>;
  bool get isFailure => this is FailureResult<T>;

  T? get data => switch (this) {
        SuccessResult(data: final d) => d,
        _ => null,
      };

  String? get errorMessage => switch (this) {
        FailureResult(message: final m) => m,
        _ => null,
      };

  Exception? get error => switch (this) {
        FailureResult(error: final e) => e,
        _ => null,
      };

  int get attemptCount => switch (this) {
        FailureResult(attemptCount: final c) => c,
        _ => 1,
      };
}

class SuccessResult<T> extends OperationResult<T> {
  @override
  final T data;
  const SuccessResult(this.data);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SuccessResult<T> &&
          runtimeType == other.runtimeType &&
          data == other.data;

  @override
  int get hashCode => data.hashCode;
}

class FailureResult<T> extends OperationResult<T> {
  final String message;
  @override
  final Exception error;
  @override
  final int attemptCount;

  const FailureResult(this.message, this.error, [this.attemptCount = 1]);

  bool get wasRetried => attemptCount > 1;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FailureResult<T> &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          attemptCount == other.attemptCount;

  @override
  int get hashCode => Object.hash(message, attemptCount);
}

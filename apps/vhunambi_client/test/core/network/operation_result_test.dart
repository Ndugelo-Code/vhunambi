import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/network/operation_result.dart';

void main() {
  group('OperationResult', () {
    test('OperationResult.success creates SuccessResult with data', () {
      final result = OperationResult.success('test_data');

      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.data, 'test_data');
      expect(result.errorMessage, isNull);
      expect(result.error, isNull);
    });

    test('OperationResult.failure creates FailureResult with error details', () {
      final exception = Exception('Boom');
      final result = OperationResult<String>.failure('Operation failed', exception, 3);

      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(result.data, isNull);
      expect(result.errorMessage, 'Operation failed');
      expect(result.error, exception);
      expect(result.attemptCount, 3);

      final failure = result as FailureResult<String>;
      expect(failure.wasRetried, isTrue);
    });

    test('FailureResult with attemptCount 1 has wasRetried = false', () {
      final exception = Exception('Boom');
      final failure = FailureResult<String>('Failed', exception, 1);

      expect(failure.wasRetried, isFalse);
      expect(failure.attemptCount, 1);
    });
  });
}

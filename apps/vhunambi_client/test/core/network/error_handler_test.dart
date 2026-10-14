import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/network/error_handler.dart';

void main() {
  group('NetworkErrorHandler', () {
    const handler = NetworkErrorHandler();

    test('classifies TimeoutException as ErrorType.timeout and retryable', () {
      final error = TimeoutException('Request timed out');
      expect(handler.classify(error), ErrorType.timeout);
      expect(handler.classify(error).isRetryable, isTrue);
      expect(handler.toUserMessage(error), contains('timed out'));
    });

    test('classifies SocketException as ErrorType.noConnection and retryable', () {
      const error = SocketException('Failed host lookup');
      expect(handler.classify(error), ErrorType.noConnection);
      expect(handler.classify(error).isRetryable, isTrue);
      expect(handler.toUserMessage(error), contains('internet connection'));
    });

    test('classifies 5xx ApiException as ErrorType.serverError and retryable', () {
      const error500 = ApiException(statusCode: 500, message: 'Internal Server Error');
      const error503 = ApiException(statusCode: 503, message: 'Service Unavailable');

      expect(handler.classify(error500), ErrorType.serverError);
      expect(handler.classify(error500).isRetryable, isTrue);
      expect(handler.toUserMessage(error500), contains('Server error'));

      expect(handler.classify(error503), ErrorType.serverError);
      expect(handler.classify(error503).isRetryable, isTrue);
    });

    test('classifies 401 ApiException as ErrorType.unauthorized and not retryable', () {
      const error = ApiException(statusCode: 401, message: 'Unauthorized');
      expect(handler.classify(error), ErrorType.unauthorized);
      expect(handler.classify(error).isRetryable, isFalse);
      expect(handler.toUserMessage(error), contains('Authentication required'));
    });

    test('classifies 403 ApiException as ErrorType.forbidden and not retryable', () {
      const error = ApiException(statusCode: 403, message: 'Forbidden');
      expect(handler.classify(error), ErrorType.forbidden);
      expect(handler.classify(error).isRetryable, isFalse);
      expect(handler.toUserMessage(error), contains('permission'));
    });

    test('classifies 404 ApiException as ErrorType.notFound and not retryable', () {
      const error = ApiException(statusCode: 404, message: 'Not Found');
      expect(handler.classify(error), ErrorType.notFound);
      expect(handler.classify(error).isRetryable, isFalse);
      expect(handler.toUserMessage(error), contains('not found'));
    });

    test('classifies other 4xx ApiException as ErrorType.clientError and not retryable', () {
      const error = ApiException(statusCode: 422, message: 'Unprocessable Entity');
      expect(handler.classify(error), ErrorType.clientError);
      expect(handler.classify(error).isRetryable, isFalse);
      expect(handler.toUserMessage(error), contains('Invalid request'));
    });

    test('classifies unrecognized exception as ErrorType.unknown and not retryable', () {
      final error = Exception('Some bizarre error');
      expect(handler.classify(error), ErrorType.unknown);
      expect(handler.classify(error).isRetryable, isFalse);
      expect(handler.toUserMessage(error), contains('unexpected error'));
    });
  });
}

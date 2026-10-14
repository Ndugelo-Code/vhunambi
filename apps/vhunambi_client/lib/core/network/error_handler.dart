import 'dart:async';
import 'dart:io';

/// Custom API exception with an HTTP status code and message.
class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException({
    required this.statusCode,
    this.message = '',
  });

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Categorized error types for network operations.
enum ErrorType {
  timeout,
  noConnection,
  serverError,
  unauthorized,
  forbidden,
  notFound,
  clientError,
  unknown;

  bool get isRetryable => switch (this) {
        ErrorType.timeout => true,
        ErrorType.noConnection => true,
        ErrorType.serverError => true,
        _ => false,
      };
}

/// Classifies network errors and generates user-friendly messages.
class NetworkErrorHandler {
  const NetworkErrorHandler();

  /// Classify error into categorized ErrorType.
  ErrorType classify(Exception error) {
    if (error is TimeoutException) {
      return ErrorType.timeout;
    }
    if (error is SocketException) {
      return ErrorType.noConnection;
    }
    if (error is ApiException) {
      final statusCode = error.statusCode;
      if (statusCode >= 500) return ErrorType.serverError;
      if (statusCode == 401) return ErrorType.unauthorized;
      if (statusCode == 403) return ErrorType.forbidden;
      if (statusCode == 404) return ErrorType.notFound;
      if (statusCode >= 400 && statusCode < 500) return ErrorType.clientError;
      return ErrorType.unknown;
    }
    if (error is HttpException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('timeout')) return ErrorType.timeout;
      if (msg.contains('connection') || msg.contains('network')) {
        return ErrorType.noConnection;
      }
      return ErrorType.serverError;
    }
    return ErrorType.unknown;
  }

  /// Convert exception to user-friendly message.
  String toUserMessage(Exception error) {
    final type = classify(error);
    return switch (type) {
      ErrorType.timeout =>
        'Request timed out. Please check your connection and try again.',
      ErrorType.noConnection =>
        'No internet connection. Please check your network settings.',
      ErrorType.serverError =>
        'Server error. We\'re working to fix this. Please try again later.',
      ErrorType.unauthorized =>
        'Authentication required. Please log in again.',
      ErrorType.forbidden =>
        'You don\'t have permission to perform this action.',
      ErrorType.notFound => 'The requested resource was not found.',
      ErrorType.clientError =>
        'Invalid request. Please check your input and try again.',
      ErrorType.unknown =>
        'An unexpected error occurred. Please try again.',
    };
  }
}

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:vhunambi_client/core/auth/sovereign_auth_session.dart';

/// Authenticated Sovereign HTTP client & Dio interceptor with single-flight `401`
/// refresh-token deduplication (`Phase 61`).
///
/// Guarantees that if multiple concurrent API requests receive HTTP `401 Unauthorized`,
/// only a single `/api/auth/refresh` call is issued while concurrent requests await
/// the same [Completer<SovereignAuthSession?>] before replaying with the rotated JWT.
class SovereignApiClient {
  final http.Client _innerClient;
  final SovereignAuthSession Function() _readSession;
  final Future<SovereignAuthSession?> Function() _refreshSession;
  final Future<void> Function()? _onRefreshFailure;

  Completer<SovereignAuthSession?>? _refreshInFlight;

  SovereignApiClient({
    http.Client? httpClient,
    required this._readSession,
    required this._refreshSession,
    this._onRefreshFailure,
  }) : _innerClient = httpClient ?? http.Client();

  /// Coordinates at most one active refresh-token exchange at any instant.
  Future<SovereignAuthSession?> singleFlightRefresh() async {
    final existing = _refreshInFlight;
    if (existing != null && !existing.isCompleted) {
      return existing.future;
    }

    final completer = Completer<SovereignAuthSession?>();
    _refreshInFlight = completer;

    try {
      final refreshed = await _refreshSession();
      if (refreshed == null || !refreshed.isAuthenticated) {
        await _onRefreshFailure?.call();
      }
      if (!completer.isCompleted) {
        completer.complete(refreshed);
      }
      return refreshed;
    } catch (_) {
      await _onRefreshFailure?.call();
      if (!completer.isCompleted) {
        completer.complete(null);
      }
      return null;
    } finally {
      if (identical(_refreshInFlight, completer)) {
        _refreshInFlight = null;
      }
    }
  }

  /// Returns auth + canonical tenant headers for the active session,
  /// proactively refreshing when the access token is about to expire.
  Future<Map<String, String>> resolveHeaders({
    Map<String, String>? extraHeaders,
    bool proactiveRefresh = true,
  }) async {
    var session = _readSession();
    if (proactiveRefresh &&
        session.isAuthenticated &&
        session.isExpiringSoon &&
        session.refreshToken.isNotEmpty) {
      final refreshed = await singleFlightRefresh();
      if (refreshed != null) {
        session = refreshed;
      }
    }

    return <String, String>{...?extraHeaders, ...session.authHeaders};
  }

  /// Sends an HTTP request built by [requestBuilder], automatically attaching
  /// Bearer + tenant headers and performing a single-flight refresh & 1x replay
  /// upon receiving `401 Unauthorized`.
  Future<http.Response> send(
    http.Request Function(Map<String, String> authHeaders) requestBuilder, {
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final initialHeaders = await resolveHeaders();
    final firstReq = requestBuilder(initialHeaders);
    final streamed = await _innerClient.send(firstReq).timeout(timeout);
    final firstResponse = await http.Response.fromStream(streamed);

    if (firstResponse.statusCode != 401) {
      return firstResponse;
    }

    final currentSession = _readSession();
    if (currentSession.refreshToken.isEmpty) {
      return firstResponse;
    }

    final refreshed = await singleFlightRefresh();
    if (refreshed == null || !refreshed.isAuthenticated) {
      return firstResponse;
    }

    final retryReq = requestBuilder(refreshed.authHeaders);
    final retryStreamed = await _innerClient.send(retryReq).timeout(timeout);
    return http.Response.fromStream(retryStreamed);
  }

  Future<http.Response> get(
    Uri uri, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 6),
  }) {
    return send((authHeaders) {
      final req = http.Request('GET', uri);
      req.headers.addAll(<String, String>{
        'Accept': 'application/json',
        ...?headers,
        ...authHeaders,
      });
      return req;
    }, timeout: timeout);
  }

  Future<http.Response> post(
    Uri uri, {
    Map<String, String>? headers,
    String? body,
    Duration timeout = const Duration(seconds: 6),
  }) {
    return send((authHeaders) {
      final req = http.Request('POST', uri);
      req.headers.addAll(<String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...?headers,
        ...authHeaders,
      });
      if (body != null) req.body = body;
      return req;
    }, timeout: timeout);
  }

  Future<http.Response> put(
    Uri uri, {
    Map<String, String>? headers,
    String? body,
    Duration timeout = const Duration(seconds: 6),
  }) {
    return send((authHeaders) {
      final req = http.Request('PUT', uri);
      req.headers.addAll(<String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...?headers,
        ...authHeaders,
      });
      if (body != null) req.body = body;
      return req;
    }, timeout: timeout);
  }

  Future<http.Response> delete(
    Uri uri, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 6),
  }) {
    return send((authHeaders) {
      final req = http.Request('DELETE', uri);
      req.headers.addAll(<String, String>{
        'Accept': 'application/json',
        ...?headers,
        ...authHeaders,
      });
      return req;
    }, timeout: timeout);
  }

  /// Creates a [Dio] [Interceptor] that injects Bearer/tenant headers and
  /// replays 401 responses once after single-flight refresh.
  Interceptor buildDioInterceptor({Dio? retryDio}) {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        final headers = await resolveHeaders();
        options.headers.addAll(headers);
        handler.next(options);
      },
      onError: (error, handler) async {
        final status = error.response?.statusCode;
        final alreadyRetried =
            error.requestOptions.extra['_p61Retried'] == true;
        final session = _readSession();
        if (status == 401 &&
            !alreadyRetried &&
            session.refreshToken.isNotEmpty) {
          final refreshed = await singleFlightRefresh();
          if (refreshed != null && refreshed.isAuthenticated) {
            final opts = error.requestOptions;
            opts.extra['_p61Retried'] = true;
            opts.headers.addAll(refreshed.authHeaders);
            try {
              final client = retryDio ?? Dio();
              final replayed = await client.fetch<dynamic>(opts);
              return handler.resolve(replayed);
            } on DioException catch (replayErr) {
              return handler.next(replayErr);
            }
          }
        }
        handler.next(error);
      },
    );
  }
}

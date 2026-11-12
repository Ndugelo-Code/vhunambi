import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:vhunambi_client/core/auth/sovereign_auth_session.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/core/storage/sovereign_domain_repositories.dart';
import 'package:vhunambi_client/core/utils/creator_id_utils.dart';

/// Structured authentication error returned from Sovereign auth endpoints or offline guards.
class SovereignAuthException implements Exception {
  final int statusCode;
  final String code;
  final String message;

  const SovereignAuthException({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  @override
  String toString() => 'SovereignAuthException($statusCode $code: $message)';
}

/// Persists & manages [SovereignAuthSession] inside AES-256 encrypted Tier-0 box
/// `vhunambi_tokens` (`AppConstants.tokenBoxKey`) and communicates with `/api/auth/*`.
class SovereignAuthRepository {
  static const String sessionStorageKey = 'sovereign_auth_session_v1';

  static SovereignAuthSession? _memorySession;

  final http.Client _httpClient;
  final String _apiRootUrl;
  final bool isTestMode;
  final bool _hasCustomHttpClient;
  final Box<dynamic>? _boxOverride;

  SovereignAuthRepository({
    Box<dynamic>? tokenBox,
    http.Client? httpClient,
    String? apiRootUrl,
    bool? isTestMode,
  }) : _boxOverride = tokenBox,
       _httpClient = httpClient ?? http.Client(),
       _apiRootUrl = apiRootUrl ?? AppConstants.resolveApiRootUrl(),
       isTestMode = isTestMode ?? _detectTestMode(),
       _hasCustomHttpClient = httpClient != null;

  bool get _shouldSkipNetwork => isTestMode && !_hasCustomHttpClient;

  static bool _detectTestMode() {
    if (const bool.fromEnvironment('FLUTTER_TEST')) return true;
    try {
      if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  Box<dynamic>? _resolveTokenBox() {
    if (_boxOverride != null && _boxOverride.isOpen) return _boxOverride;
    if (kIsWeb) return null;
    try {
      if (Hive.isBoxOpen(AppConstants.tokenBoxKey)) {
        final box = Hive.box<dynamic>(AppConstants.tokenBoxKey);
        if (box.isOpen) return box;
      }
    } catch (_) {}
    return null;
  }

  /// Clears static L1 auth session memory cleanly on sign-out/tenant change.
  static void clearSessionMemory() {
    _memorySession = null;
  }

  /// Synchronously loads the persisted [SovereignAuthSession], returning
  /// [SovereignAuthSession.guestDefault()] when absent or corrupted.
  SovereignAuthSession loadSession() {
    if (!SovereignDomainStorageMode.canHydrateFromStorage(
      AppConstants.tokenBoxKey,
    )) {
      return SovereignAuthSession.guestDefault();
    }

    final box = _resolveTokenBox();
    if (box != null) {
      final raw = box.get(sessionStorageKey);
      if (raw is String && raw.isNotEmpty) {
        try {
          final parsed = SovereignAuthSession.fromJson(
            Map<String, dynamic>.from(jsonDecode(raw) as Map<dynamic, dynamic>),
          );
          _memorySession = parsed;
          return parsed;
        } catch (_) {}
      } else if (raw is Map) {
        try {
          final parsed = SovereignAuthSession.fromJson(
            Map<String, dynamic>.from(raw),
          );
          _memorySession = parsed;
          return parsed;
        } catch (_) {}
      }
    }

    return _memorySession ?? SovereignAuthSession.guestDefault();
  }

  /// Persists [session] into encrypted `vhunambi_tokens` box without disturbing
  /// onboarding state (`onboarding_state_v1`).
  Future<void> saveSession(SovereignAuthSession session) async {
    _memorySession = session;
    final box = _resolveTokenBox();
    if (box != null) {
      await box.put(sessionStorageKey, jsonEncode(session.toJson()));
    }
  }

  /// Clears the persisted auth session while leaving onboarding state intact.
  Future<void> clearSession() async {
    _memorySession = SovereignAuthSession.guestDefault();
    final box = _resolveTokenBox();
    if (box != null) {
      await box.delete(sessionStorageKey);
    }
  }

  /// Registers a new creator account via `POST /api/auth/register`.
  Future<SovereignAuthSession> register({
    required String handle,
    required String email,
    required String password,
    String? displayName,
    String deviceLabel = 'vhunambi_client',
  }) async {
    if (_shouldSkipNetwork) {
      throw const SovereignAuthException(
        statusCode: 503,
        code: 'AUTH_OFFLINE',
        message: 'Network auth unavailable in offline test sandbox.',
      );
    }

    final res = await _httpClient
        .post(
          Uri.parse('$_apiRootUrl/api/auth/register'),
          headers: const <String, String>{
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(<String, dynamic>{
            'handle': handle.trim(),
            'email': email.trim(),
            'password': password,
            if (displayName != null && displayName.trim().isNotEmpty)
              'displayName': displayName.trim(),
            'deviceLabel': deviceLabel,
          }),
        )
        .timeout(const Duration(seconds: 15));

    final decoded = _decodeJsonMap(res.body);
    if (res.statusCode == 201 ||
        res.statusCode == 200 ||
        (res.statusCode == 202 &&
            (decoded['accessToken']?.toString().isNotEmpty ?? false))) {
      final session = parseAuthBundleJson(decoded);
      await saveSession(session);
      return session;
    }

    throw SovereignAuthException(
      statusCode: res.statusCode,
      code: (decoded['code'] ?? 'AUTH_REGISTER_FAILED').toString(),
      message: (decoded['message'] ?? decoded['error'] ?? 'Registration failed')
          .toString(),
    );
  }

  /// Authenticates an existing creator via `POST /api/auth/login`.
  Future<SovereignAuthSession> login({
    required String identifier,
    required String password,
    String deviceLabel = 'vhunambi_client',
  }) async {
    if (_shouldSkipNetwork) {
      throw const SovereignAuthException(
        statusCode: 503,
        code: 'AUTH_OFFLINE',
        message: 'Network auth unavailable in offline test sandbox.',
      );
    }

    final res = await _httpClient
        .post(
          Uri.parse('$_apiRootUrl/api/auth/login'),
          headers: const <String, String>{
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(<String, dynamic>{
            'identifier': identifier.trim(),
            'password': password,
            'deviceLabel': deviceLabel,
          }),
        )
        .timeout(const Duration(seconds: 15));

    final decoded = _decodeJsonMap(res.body);
    if (res.statusCode == 200 ||
        (res.statusCode == 202 &&
            (decoded['accessToken']?.toString().isNotEmpty ?? false))) {
      final session = parseAuthBundleJson(decoded);
      await saveSession(session);
      return session;
    }

    throw SovereignAuthException(
      statusCode: res.statusCode,
      code: (decoded['code'] ?? 'AUTH_INVALID_CREDENTIALS').toString(),
      message: (decoded['message'] ??
              decoded['error'] ??
              'Invalid handle, email, or password')
          .toString(),
    );
  }

  /// Rotates the active refresh token via `POST /api/auth/refresh`.
  /// Throws [SovereignAuthException] when the server explicitly rejects (401/403).
  Future<SovereignAuthSession?> refresh(String refreshToken) async {
    if (refreshToken.trim().isEmpty || _shouldSkipNetwork) return null;

    final res = await _httpClient
        .post(
          Uri.parse('$_apiRootUrl/api/auth/refresh'),
          headers: const <String, String>{
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(<String, dynamic>{'refreshToken': refreshToken}),
        )
        .timeout(const Duration(seconds: 6));

    final decoded = _decodeJsonMap(res.body);
    if (res.statusCode == 200) {
      final session = parseAuthBundleJson(decoded);
      await saveSession(session);
      return session;
    }

    if (res.statusCode == 401 || res.statusCode == 403) {
      throw SovereignAuthException(
        statusCode: res.statusCode,
        code: (decoded['code'] ?? 'AUTH_REFRESH_REJECTED').toString(),
        message: (decoded['message'] ?? 'Refresh session revoked or expired').toString(),
      );
    }

    return null;
  }

  /// Revokes the active session on the backend via `POST /api/auth/logout`.
  Future<void> logout({
    required String accessToken,
    String? refreshToken,
  }) async {
    if (!_shouldSkipNetwork &&
        (accessToken.isNotEmpty || (refreshToken ?? '').isNotEmpty)) {
      try {
        await _httpClient
            .post(
              Uri.parse('$_apiRootUrl/api/auth/logout'),
              headers: <String, String>{
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                if (accessToken.isNotEmpty)
                  'Authorization': 'Bearer $accessToken',
              },
              body: jsonEncode(<String, dynamic>{
                if (refreshToken != null && refreshToken.isNotEmpty)
                  'refreshToken': refreshToken,
              }),
            )
            .timeout(const Duration(seconds: 4));
      } catch (_) {}
    }
    await clearSession();
  }

  /// Fetches `/api/auth/me` using the supplied [accessToken].
  Future<Map<String, dynamic>?> fetchMe(String accessToken) async {
    if (_shouldSkipNetwork || accessToken.isEmpty) return null;
    try {
      final res = await _httpClient
          .get(
            Uri.parse('$_apiRootUrl/api/auth/me'),
            headers: <String, String>{
              'Accept': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
          )
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        return _decodeJsonMap(res.body);
      }
    } catch (_) {}
    return null;
  }

  /// Fetches active device sessions via `GET /api/auth/sessions`.
  Future<List<Map<String, dynamic>>> fetchSessions(String accessToken) async {
    if (_shouldSkipNetwork || accessToken.isEmpty) return const <Map<String, dynamic>>[];
    try {
      final res = await _httpClient
          .get(
            Uri.parse('$_apiRootUrl/api/auth/sessions'),
            headers: <String, String>{
              'Accept': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
          )
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final decoded = _decodeJsonMap(res.body);
        final raw = decoded['sessions'] as List<dynamic>? ?? const <dynamic>[];
        return raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      }
    } catch (_) {}
    return const <Map<String, dynamic>>[];
  }

  /// Converts a backend `/api/auth/*` token bundle JSON payload into [SovereignAuthSession].
  static SovereignAuthSession parseAuthBundleJson(Map<String, dynamic> json) {
    final rawUser = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : const <String, dynamic>{};
    final rawSession = json['session'] is Map
        ? Map<String, dynamic>.from(json['session'] as Map)
        : const <String, dynamic>{};

    final creatorId = canonicalizeCreatorId(
      rawUser['creatorId']?.toString() ?? json['creatorId']?.toString(),
    );
    final rawHandle = (rawUser['handle'] ?? json['handle'] ?? '')
        .toString()
        .trim();
    final handle = rawHandle.isNotEmpty
        ? (rawHandle.startsWith('@') ? rawHandle : '@$rawHandle')
        : handleFromCreatorId(creatorId);
    final displayName =
        (rawUser['displayName'] ??
                json['displayName'] ??
                extractRawCreatorId(creatorId))
            .toString()
            .trim();

    return SovereignAuthSession(
      userId: (rawUser['userId'] ?? json['userId'] ?? 'usr_$creatorId')
          .toString(),
      creatorId: creatorId,
      handle: handle,
      displayName: displayName,
      email: (rawUser['email'] ?? json['email'] ?? '').toString(),
      role: (rawUser['role'] ?? 'creator').toString(),
      sessionId: (rawSession['sessionId'] ?? json['sessionId'] ?? '').toString(),
      accessToken: (json['accessToken'] ?? '').toString(),
      refreshToken: (json['refreshToken'] ?? '').toString(),
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'].toString())
          : null,
      isGuest: (json['accessToken'] ?? '').toString().isEmpty,
    );
  }

  static Map<String, dynamic> _decodeJsonMap(String body) {
    if (body.trim().isEmpty) return const <String, dynamic>{};
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return const <String, dynamic>{};
  }
}

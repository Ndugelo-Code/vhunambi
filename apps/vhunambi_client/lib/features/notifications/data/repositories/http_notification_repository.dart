import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:vhunambi_client/core/auth/auth_providers.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/core/network/sovereign_api_client.dart';
import 'package:vhunambi_client/features/notifications/domain/models/notification_entity.dart';

/// HTTP repository bridging `/api/notifications*` (`EP-P67-NOTIF-API`) with
/// `SovereignApiClient` Bearer auth and headless test guards.
class HttpNotificationRepository {
  final SovereignApiClient apiClient;
  final String _apiRestBaseUrl;
  final bool Function() isAuthenticated;
  final bool isTestMode;
  final bool hasCustomClient;

  HttpNotificationRepository({
    required this.apiClient,
    required this.isAuthenticated,
    String? apiRestBaseUrl,
    bool? isTestMode,
    this.hasCustomClient = false,
  }) : _apiRestBaseUrl = apiRestBaseUrl ?? AppConstants.apiRestBaseUrl,
       isTestMode = isTestMode ?? _detectTestMode();

  bool get shouldSkipNetwork =>
      (isTestMode && !hasCustomClient) || !isAuthenticated();

  static bool _detectTestMode() {
    if (const bool.fromEnvironment('FLUTTER_TEST')) return true;
    try {
      if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Fetches server-stored & server-emitted alerts via `GET /api/notifications`.
  /// Returns `null` when skipped/offline so local Hive entries remain intact.
  Future<List<NotificationEntity>?> fetchNotifications() async {
    if (shouldSkipNetwork) return null;
    try {
      final uri = Uri.parse('$_apiRestBaseUrl/notifications');
      final response = await apiClient.get(
        uri,
        timeout: const Duration(seconds: 6),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final rawList =
              decoded['notifications'] as List<dynamic>? ?? const <dynamic>[];
          final parsed = <NotificationEntity>[];
          for (final item in rawList.whereType<Map>()) {
            final map = Map<String, dynamic>.from(item);
            map['message'] = (map['message'] as String?)?.isNotEmpty == true
                ? map['message']
                : (map['body'] ?? '');
            final entity = NotificationEntity.fromJson(map);
            if (entity.id.isNotEmpty) {
              parsed.add(entity);
            }
          }
          return parsed;
        }
      }
    } catch (e) {
      debugPrint('[HttpNotificationRepository] fetchNotifications fallback: $e');
    }
    return null;
  }

  /// Mirrors a local notification to `POST /api/notifications`.
  Future<bool> upsertNotification(NotificationEntity entity) async {
    if (shouldSkipNetwork || entity.id.isEmpty) return false;
    try {
      final uri = Uri.parse('$_apiRestBaseUrl/notifications');
      final payload = <String, dynamic>{
        'id': entity.id,
        'title': entity.title,
        'message': entity.message,
        'body': entity.message,
        'category': entity.category.name,
        'subtype': entity.subtype,
        'priority': entity.priority.name,
        'isRead': entity.isRead,
        'targetRoute': entity.targetRoute,
        'targetEntityId': entity.targetEntityId ?? entity.targetTrackId,
        'targetTrackId': entity.targetTrackId,
        'ctaLabel': entity.ctaLabel,
        'metadata': entity.metadata,
        'createdAt': entity.createdAt.toIso8601String(),
      };
      final response = await apiClient.post(
        uri,
        body: jsonEncode(payload),
        timeout: const Duration(seconds: 6),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('[HttpNotificationRepository] upsertNotification fallback: $e');
      return false;
    }
  }

  /// Marks a single notification read via `PATCH /api/notifications/:id/read`.
  Future<bool> markRead(String id) async {
    if (shouldSkipNetwork || id.isEmpty) return false;
    try {
      final uri = Uri.parse(
        '$_apiRestBaseUrl/notifications/${Uri.encodeComponent(id)}/read',
      );
      final response = await apiClient.send(
        (headers) => http.Request('PATCH', uri)
          ..headers.addAll(<String, String>{
            'Accept': 'application/json',
            ...headers,
          }),
        timeout: const Duration(seconds: 6),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('[HttpNotificationRepository] markRead fallback: $e');
      return false;
    }
  }

  /// Marks all notifications read via `POST /api/notifications/mark-all-read`.
  Future<bool> markAllRead() async {
    if (shouldSkipNetwork) return false;
    try {
      final uri = Uri.parse('$_apiRestBaseUrl/notifications/mark-all-read');
      final response = await apiClient.post(
        uri,
        body: jsonEncode(const <String, dynamic>{}),
        timeout: const Duration(seconds: 6),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('[HttpNotificationRepository] markAllRead fallback: $e');
      return false;
    }
  }

  /// Deletes a notification via `DELETE /api/notifications/:id`.
  Future<bool> deleteNotification(String id) async {
    if (shouldSkipNetwork || id.isEmpty) return false;
    try {
      final uri = Uri.parse(
        '$_apiRestBaseUrl/notifications/${Uri.encodeComponent(id)}',
      );
      final response = await apiClient.delete(
        uri,
        timeout: const Duration(seconds: 6),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('[HttpNotificationRepository] deleteNotification fallback: $e');
      return false;
    }
  }
}

final httpNotificationRepositoryProvider = Provider<HttpNotificationRepository>((
  ref,
) {
  final apiClient = ref.watch(sovereignApiClientProvider);
  final overrideRoot = ref.watch(sovereignAuthApiRootUrlProvider);
  final restBase = overrideRoot != null
      ? '${AppConstants.normalizeOriginUrl(overrideRoot)}/api'
      : AppConstants.apiRestBaseUrl;
  return HttpNotificationRepository(
    apiClient: apiClient,
    isAuthenticated: () => ref.read(authSessionProvider).isAuthenticated,
    apiRestBaseUrl: restBase,
  );
});

import 'dart:convert';

import 'package:vhunambi_client/core/resilience/vhunambi_crash_shield.dart';

/// Null-safe, non-throwing JSON decoding and coercion helpers (REQ-P65-L4-01).
abstract final class JsonSafe {
  /// Decodes a JSON string into a `Map<String, dynamic>`, returning `null`
  /// and recording a breadcrumb if [raw] is null, empty, or malformed.
  static Map<String, dynamic>? decodeMap(
    Object? raw, {
    String source = 'json_safe:decodeMap',
  }) {
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map) {
          return decoded.map((k, v) => MapEntry(k.toString(), v));
        }
      } catch (error, stackTrace) {
        VhunambiCrashShield.recordBreadcrumb(
          source: source,
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    return null;
  }

  /// Decodes a JSON string into a `List<dynamic>`, returning `null` on failure.
  static List<dynamic>? decodeList(
    Object? raw, {
    String source = 'json_safe:decodeList',
  }) {
    if (raw == null) return null;
    if (raw is List<dynamic>) return raw;
    if (raw is List) return List<dynamic>.from(raw);
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) return List<dynamic>.from(decoded);
      } catch (error, stackTrace) {
        VhunambiCrashShield.recordBreadcrumb(
          source: source,
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    return null;
  }

  static Map<String, dynamic> asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return const <String, dynamic>{};
  }

  static List<dynamic> asList(Object? value) {
    if (value is List<dynamic>) return value;
    if (value is List) return List<dynamic>.from(value);
    return const <dynamic>[];
  }

  static String asString(Object? value, [String fallback = '']) {
    if (value == null) return fallback;
    if (value is String) return value;
    return value.toString();
  }

  static int asInt(Object? value, [int fallback = 0]) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? fallback;
    return fallback;
  }

  static double asDouble(Object? value, [double fallback = 0.0]) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim()) ?? fallback;
    return fallback;
  }

  static bool asBool(Object? value, [bool fallback = false]) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.trim().toLowerCase();
      if (lower == 'true' || lower == '1') return true;
      if (lower == 'false' || lower == '0') return false;
    }
    return fallback;
  }
}
